-- Behaviour check for the car's drive telemetry on the dashboard.
--
-- Run it:
--     lua5.4 bin/drive_status/verify_drive_status.lua [--self-test]
--
-- What it drives, and why:
--   * lib/drive_status.lua, real: the drive status word (gripora-firmware TELEM_DRIVE_STATUS,
--     sensor 93) reduced to the one state a tile shows, most urgent first.
--   * The sensor tables, real: sensors 93 and 94 are in the default list in place of altitude and
--     variometer (the firmware's own default, src/main/pg/telemetry.c), both protocols map them to
--     their appIds, and the CRSF decoder reads the status as a U16 (the heli governor's U8 there
--     would throw the rest of a custom-telemetry frame off).
--   * widgets/dashboard/context.lua and lib/live_sensors.lua, real: drive_speed in km/h, nothing
--     when the firmware has no speed source; lib/flight_stats.lua records the top speed.
--   * widgets/dashboard/objects/text/driveaids.lua and governor.lua, real: the word and colour a
--     tile shows, and the inherited governor subtype showing the same.
--
-- --self-test swaps two states' priority in a copy of lib/drive_status.lua and requires the
-- checks to go red.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/grsuite"

local selfTest = false
for _, a in ipairs(arg or {}) do
  if a == "--self-test" then selfTest = true end
end

local function readFile(path)
  local f = assert(io.open(path, "rb"))
  local s = f:read("a")
  f:close()
  return s
end

local function resolvePath(name)
  local f = io.open(name, "r")
  if f then f:close() return name end
  return SUITE .. "/" .. name
end

-- With --self-test, lib/drive_status.lua is loaded with ABS releasing ranked below DRIFT.
local MUTATIONS = {}
if selfTest then
  local source = readFile(SUITE .. "/lib/drive_status.lua")
  local absLine = '  if raw & ABS_ACTIVE ~= 0 then return "abs" end\n'
  local driftLine = '  if raw & DRIFT ~= 0 then return "drift" end\n'
  source = source:gsub("\r\n", "\n")
  local a = source:find(absLine, 1, true)
  local d = source:find(driftLine, 1, true)
  assert(a and d, "self-test: the priority lines were not found in lib/drive_status.lua")
  source = source:gsub(absLine:gsub("%p", "%%%0"), "", 1)
  source = source:gsub(driftLine:gsub("%p", "%%%0"), driftLine .. absLine, 1)
  MUTATIONS["lib/drive_status.lua"] = source
end

local realLoadfile = loadfile
loadfile = function(path, mode, env)
  if type(path) == "string" then
    local mutated = MUTATIONS[path] or MUTATIONS[path:gsub("^.*src/grsuite/", "")]
    if mutated then return load(mutated, "@" .. path, "t", env or _G) end
    path = resolvePath(path)
  end
  if env ~= nil then return realLoadfile(path, mode, env)
  elseif mode ~= nil then return realLoadfile(path, mode)
  else return realLoadfile(path) end
end

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail then print("        " .. tostring(detail)) end
  end
end

local function anyStub()
  return setmetatable({}, {__index = function() return function() return anyStub() end end,
    __call = function() return anyStub() end})
end

local function requireModule(name)
  local key = "grsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(name)
  if not chunk then error(err) end
  local result = chunk()
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end
package.loaded["grsuite.lib.require"] = requireModule

lcd = anyStub()
lcd.RGB = function(r, g, b) return r * 65536 + g * 256 + b end
system = anyStub()
model = anyStub()

-- ---------------------------------------------------------------------------
-- 1. The status word
-- ---------------------------------------------------------------------------
print("lib/drive_status.lua")
local ds = requireModule("lib/drive_status.lua")
local SPEED = 1 << 13
local CASES = {
  {"no reading", nil, nil},
  {"disarmed: nothing running", SPEED, "off"},
  {"aids on, coasting", SPEED | 1, "aids_on"},
  {"braking with ABS set up", SPEED | 1 | 2, "abs_armed"},
  {"ABS releasing", SPEED | 1 | 2 | 4, "abs"},
  {"driving with TC set up", SPEED | 1 | 8, "tc_armed"},
  {"TC holding back", SPEED | 1 | 8 | 16, "tc"},
  {"launch staged", SPEED | 1 | 32 | 1024, "launch_staged"},
  {"launching", SPEED | 1 | 64 | 1024, "launch"},
  {"DRIFT", SPEED | 1 | 512, "drift"},
  {"ABS releasing in DRIFT shows ABS", SPEED | 1 | 2 | 4 | 512, "abs"},
  {"DRIVE AIDS OFF", SPEED | 2048, "aids_off"},
  {"GYRO OFF beats everything", SPEED | 1 | 4 | 16 | 64 | 256 | 512 | 2048, "gyro_off"},
  {"a float reading is floored", 8193.4, "aids_on"},
}
for _, c in ipairs(CASES) do
  local got = ds.state(c[2])
  check(c[1] .. " -> " .. tostring(c[3]), got == c[3], "got " .. tostring(got))
end
local covered = true
for _, c in ipairs(CASES) do
  if c[3] and (ds.TEXT[c[3]] == nil or ds.LEVEL[c[3]] == nil) then covered = false end
end
check("every state has a text and a level", covered)
check("ABS watching and acting share a word, not a level",
  ds.TEXT.abs == ds.TEXT.abs_armed and ds.LEVEL.abs ~= ds.LEVEL.abs_armed)
check("speed known from bit 13", ds.speedKnown(SPEED) and not ds.speedKnown(1) and ds.speedKnown(nil))
check("reversing from bit 12", ds.reversing(4096) and not ds.reversing(SPEED))

-- ---------------------------------------------------------------------------
-- 2. The sensor tables
-- ---------------------------------------------------------------------------
print("sensor tables")
CATEGORY_TELEMETRY_SENSOR = 0
UNIT_RAW, UNIT_KILOMETER_PER_HOUR = 1, 2
local catalog = requireModule("lib/telemetry_sensor_catalog.lua")
local FIRMWARE_DEFAULT = {3, 4, 5, 6, 15, 43, 50, 52, 60, 89, 91, 93, 94, 99, 120, 121}
check("the default list is the firmware's own", table.concat(catalog.DEFAULT_IDS, ",") == table.concat(FIRMWARE_DEFAULT, ","),
  table.concat(catalog.DEFAULT_IDS, ","))
check("drive status and speed are listed", catalog.SENSOR_LIST[93] ~= nil and catalog.SENSOR_LIST[94] ~= nil)
local elrsSid = requireModule("lib/elrs_sid_lookup.lua")
local frskySid = requireModule("lib/frsky_sid_lookup.lua")
check("CRSF ids 0x1205 / 0x1206", elrsSid[93] and elrsSid[93][1] == 0x1205 and elrsSid[94] and elrsSid[94][1] == 0x1206)
check("S.Port ids 0x5125 / 0x5126", frskySid[93] and frskySid[93][1] == 0x5125 and frskySid[94] and frskySid[94][1] == 0x5126)
local decoders = setmetatable({}, {__index = function(_, k) return k end})
local elrsTable = assert(loadfile("lib/elrs_sensor_table.lua"))()(decoders)
check("the CRSF status is a U16", elrsTable[0x1205] and elrsTable[0x1205].dec == "decU16",
  elrsTable[0x1205] and elrsTable[0x1205].dec)
check("the CRSF speed is an S16 with one decimal", elrsTable[0x1206] and elrsTable[0x1206].dec == "decS16"
  and elrsTable[0x1206].prec == 1)

-- ---------------------------------------------------------------------------
-- 3. Speed on the dashboard and in the run record
-- ---------------------------------------------------------------------------
print("drive_speed")
local context = requireModule("widgets/dashboard/context.lua")
local function speed(widget)
  context.setWidget(widget)
  return (context.tasks.telemetry.getSensor("drive_speed"))
end
check("the session's speed, in km/h", speed({connected = true, driveSpeed = 42.5, driveStatus = SPEED | 1}) == 42.5)
check("negative while reversing", speed({connected = true, driveSpeed = -6.1, driveStatus = SPEED | 4096}) == -6.1)
check("nothing without a speed source", speed({connected = true, driveStatus = 1}) == nil)
check("nothing with the link down", speed({connected = false, driveSpeed = 42.5}) == nil)

local liveSensors = requireModule("lib/live_sensors.lua")
local record = requireModule("lib/flight_stats.lua").new()
local run = {connected = true, isArmed = true, systemStatus = {running = true}, mcuId = "car", driveStatus = SPEED | 1}
for _, v in ipairs({0, 12.0, 38.4, 21.0, -7.5}) do
  run.driveSpeed = v
  record:update(run, liveSensors.read)
end
local entry = record.stats.drive_speed
check("the run records the top speed", entry and entry.max == 38.4, entry and entry.max)
check("and the fastest in reverse", entry and entry.min == -7.5, entry and entry.min)

-- ---------------------------------------------------------------------------
-- 4. The tile
-- ---------------------------------------------------------------------------
print("text/driveaids and text/governor")
local utils = context.widgets.dashboard.utils
utils.isModelPrefsReady = function() return true end
local function tile(path, word, params)
  local render = assert(loadfile(path))()
  local box = params or {}
  context.setWidget({connected = true, driveStatus = word})
  render.wakeup(box)
  return box._currentDisplayValue, box._dynamicTextColor, render, box
end
local red = utils.resolveColor("red")
local orange = utils.resolveColor("orange")
local green = utils.resolveColor("green")
local text, color = tile("widgets/dashboard/objects/text/driveaids.lua", SPEED | 1 | 8 | 16)
check("TC holding back: TC in the active colour", text == ds.TEXT.tc and color == orange, tostring(text) .. " " .. tostring(color))
text, color = tile("widgets/dashboard/objects/text/driveaids.lua", SPEED | 1 | 8)
check("TC watching: TC in the on colour", text == ds.TEXT.tc and color == green, tostring(text) .. " " .. tostring(color))
text, color = tile("widgets/dashboard/objects/text/driveaids.lua", SPEED | 256, {offcolor = "magenta"})
check("a theme's colour for GYRO OFF", text == ds.TEXT.gyro_off and color == utils.resolveColor("magenta"))
text, color = tile("widgets/dashboard/objects/text/driveaids.lua", SPEED | 2048,
  {thresholds = {{value = ds.TEXT.aids_off, textcolor = "blue"}}})
check("a theme's threshold wins", text == ds.TEXT.aids_off and color == utils.resolveColor("blue"))
local _, _, render, box = tile("widgets/dashboard/objects/text/driveaids.lua", SPEED | 1 | 8)
render.dirty(box)
context.setWidget({connected = true, driveStatus = SPEED | 1 | 8 | 16})
render.wakeup(box)
check("watching -> acting repaints though the word stays", render.dirty(box) == true)
text, color = tile("widgets/dashboard/objects/text/governor.lua", SPEED | 256)
check("the governor subtype shows the drive aids", text == ds.TEXT.gyro_off and color == red, tostring(text))

print(string.format("\n%d checks, %d failed", checks, failures))
if selfTest then
  if failures > 0 then
    print("self-test passed: the swapped priority turned " .. failures .. " check(s) red")
    os.exit(0)
  end
  print("self-test FAILED: the swapped priority went unnoticed")
  os.exit(1)
end
os.exit(failures == 0 and 0 or 1)
