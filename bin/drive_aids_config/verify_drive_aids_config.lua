-- Behaviour check for the drive aids config codec (lib/msp_drive_aids_config.lua)
-- and the ABS page and menu row that use it.
--
-- Run it:
--     lua5.4 bin/drive_aids_config/verify_drive_aids_config.lua
--
-- The wire layout is transcribed from the firmware handler (gripora-firmware
-- msp.c, pg/drive_aids.h): MSP2_GRIPORA_DRIVE_AIDS_CONFIG (0x5F3F) replies nine
-- U8 fields -- abs_mode, abs_freq, abs_floor, abs_hold, abs_trigger,
-- abs_dyn_freq, abs_dyn_hold, abs_corner_freq, abs_corner_hold. Later aids
-- append fields, so a longer reply is read for its first nine; a shorter one is
-- refused. MSP2_GRIPORA_SET_DRIVE_AIDS_CONFIG (0x5F40) takes exactly those nine,
-- and the firmware refuses the whole write if any is out of range, so the
-- FIELD_META ranges are pinned to its checks.
-- The settings are stored per PID profile; both messages act on the current one.
-- Traction control (API 33.x): U8 tc_mode, U16 tc_ramp_time follow the nine ABS
-- bytes (12 in all); a nine-byte reply is older firmware and is written back as nine.

local function scriptDir()
  local src = debug.getinfo(1, "S").source
  local path = src:sub(1, 1) == "@" and src:sub(2) or src
  return (path:match("^(.*)[/\\][^/\\]*$")) or "."
end

local ROOT = scriptDir() .. "/../.."
local SUITE = ROOT .. "/src/grsuite"

local failures = 0
local checks = 0

local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print(string.format("  ok    %s", label))
  else
    failures = failures + 1
    print(string.format("  FAIL  %s", label))
    if detail ~= nil then print("        " .. tostring(detail)) end
  end
end

package.loaded["grsuite.lib.require"] = function(name)
  local key = "grsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  local cached = package.loaded[key]
  if cached ~= nil then return cached end
  local chunk, err = loadfile(SUITE .. "/" .. name)
  if not chunk then error(err) end
  local ok, result = pcall(chunk)
  if not ok then error(result) end
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end

local requireModule = package.loaded["grsuite.lib.require"]
local codec = requireModule("lib/msp_drive_aids_config.lua")

local function readFile(path)
  local f = io.open(path, "rb")
  if not f then return nil end
  local text = f:read("a")
  f:close()
  return text
end

local function copy(t)
  local out = {}
  for i = 1, #t do out[i] = t[i] end
  return out
end

local function read(buf)
  local got, reason, refused
  local errored = false
  codec.buildReadMessage(
    function(d) got = d end,
    function(r, ref) errored = true; reason = r; refused = ref end
  ).processReply(nil, copy(buf))
  return got, errored, reason, refused
end

local ORDER = {
  "abs_mode", "abs_freq", "abs_floor", "abs_hold", "abs_trigger",
  "abs_dyn_freq", "abs_dyn_hold", "abs_corner_freq", "abs_corner_hold",
}
-- DYNAMIC, 12 Hz, floor 35 %, hold 25 ms, trigger 20 %, 18 Hz, 5 ms, 4 Hz, 10 ms:
-- the nine ABS bytes older firmware replies.
local REPLY = {2, 12, 35, 25, 20, 18, 5, 4, 10}
-- The same plus traction control: RAMP, 750 ms (U16 LE 0x02EE).
local REPLY_TC = {2, 12, 35, 25, 20, 18, 5, 4, 10, 1, 0xEE, 0x02}

-- ---------------------------------------------------------------------------
print("case 1: commands and field order match the firmware handler")

check("read is 0x5F3F", codec.READ_COMMAND == 0x5F3F, codec.READ_COMMAND)
check("write is 0x5F40", codec.WRITE_COMMAND == 0x5F40, codec.WRITE_COMMAND)
check("nine fields", codec.FIELD_COUNT == 9 and #codec.FIELDS == 9, #codec.FIELDS)
local sameOrder = true
for i = 1, #ORDER do sameOrder = sameOrder and codec.FIELDS[i] == ORDER[i] end
check("field order", sameOrder, table.concat(codec.FIELDS, ","))

-- ---------------------------------------------------------------------------
print("case 2: FIELD_META ranges and defaults match pg/drive_aids.h/.c")

local EXPECT = {
  abs_freq = {2, 33, 10}, abs_floor = {0, 100, 40}, abs_hold = {0, 100, 20},
  abs_trigger = {5, 100, 30}, abs_dyn_freq = {2, 33, 15}, abs_dyn_hold = {0, 100, 0},
  abs_corner_freq = {0, 10, 0}, abs_corner_hold = {0, 100, 0},
  tc_ramp_time = {50, 2000, 500},
}
for key, e in pairs(EXPECT) do
  local m = codec.FIELD_META[key]
  check(key .. " range/default", m and m.min == e[1] and m.max == e[2] and m.default == e[3],
    m and (m.min .. ".." .. m.max .. " d" .. tostring(m.default)))
end
local choices = codec.FIELD_META.abs_mode.choices
check("mode choices Off/Static/Dynamic = 0/1/2",
  #choices == 3 and choices[1][2] == 0 and choices[2][2] == 1 and choices[3][2] == 2)
local tcChoices = codec.FIELD_META.tc_mode.choices
check("TC mode choices Off/Ramp = 0/1",
  #tcChoices == 2 and tcChoices[1][2] == 0 and tcChoices[2][2] == 1)

-- ---------------------------------------------------------------------------
print("case 3: decode/encode round-trip")

local sim = codec.buildReadMessage(function() end, function() end).simulatorResponse
local simData, simErrored = read(sim)
check("simulatorResponse decodes", simData ~= nil and not simErrored)
if simData then
  local defaults = simData.abs_mode == 0 and simData.tc_mode == 0 and simData.has_tc == true
  for key, e in pairs(EXPECT) do defaults = defaults and simData[key] == e[3] end
  check("simulatorResponse is the firmware defaults (12 bytes, with TC)", #sim == 12 and defaults)
end

local data, errored = read(REPLY)
check("a valid reply reaches onData", data ~= nil and not errored)
if data then
  local ok = true
  for i = 1, #ORDER do ok = ok and data[ORDER[i]] == REPLY[i] end
  check("every field decoded in order", ok)
  local msg = codec.buildWriteMessage(data, function() end, function() end)
  check("write uses 0x5F40", msg.command == 0x5F40, msg.command)
  local same = #msg.payload == 9
  for i = 1, 9 do same = same and msg.payload[i] == REPLY[i] end
  check("a nine-byte reply encodes exactly the nine reply bytes", same, table.concat(msg.payload, ","))
  check("a nine-byte reply has no TC (older firmware)", data.has_tc == false and data.tc_mode == nil)
end

data, errored = read(REPLY_TC)
check("a 12-byte reply reaches onData", data ~= nil and not errored)
if data then
  check("TC fields decoded", data.has_tc == true and data.tc_mode == 1 and data.tc_ramp_time == 750,
    tostring(data.tc_mode) .. "/" .. tostring(data.tc_ramp_time))
  local payload = codec.encode(data)
  local same = #payload == 12
  for i = 1, 12 do same = same and payload[i] == REPLY_TC[i] end
  check("a 12-byte reply encodes exactly the twelve reply bytes", same, table.concat(payload, ","))
end
local empty = codec.encode({})
check("encode of an empty table is 9 bytes of defaults",
  #empty == 9 and empty[1] == 0 and empty[2] == 10 and empty[5] == 30, table.concat(empty, ","))

-- ---------------------------------------------------------------------------
print("case 4: a longer reply (later aids appended) reads the known twelve")

local long = copy(REPLY_TC); long[13] = 7; long[14] = 99
data, errored = read(long)
check("14-byte reply reaches onData", data ~= nil and not errored)
if data then
  check("abs_corner_hold is byte 9", data.abs_corner_hold == 10, data.abs_corner_hold)
  check("tc_ramp_time is bytes 11-12, not an appended byte", data.tc_ramp_time == 750, data.tc_ramp_time)
  check("write stays twelve bytes", #codec.encode(data) == 12, #codec.encode(data))
end
-- A 10- or 11-byte reply cannot hold the TC fields: ABS only.
data = read({2, 12, 35, 25, 20, 18, 5, 4, 10, 1})
check("10-byte reply decodes ABS only", data ~= nil and data.has_tc == false and #codec.encode(data) == 9)

-- ---------------------------------------------------------------------------
print("case 5: a short reply is refused")

local short = {2, 12, 35, 25, 20, 18, 5, 4}
local got, err, reason, refused = read(short)
check("8-byte reply does not reach onData", got == nil)
check("8-byte reply is reported through onError as refused", err and refused == true, reason)

-- ---------------------------------------------------------------------------
print("case 6: the page and its menu row")

local page = readFile(SUITE .. "/app/pages/drive_aids_abs.lua")
check("page file readable", page ~= nil)
if page then
  check("page uses this codec", page:find("lib/msp_drive_aids_config.lua", 1, true) ~= nil)
  check("page is an MSP page (save refused while armed)", page:find("isMspPage%s*=%s*true") ~= nil)
  check("page does not reboot after save", page:find("rebootAfterSave") == nil)
  -- Stored per PID profile; the message reads/writes the current one, so the page
  -- keeps page_runtime's default profile scope (title "#n", reload on change).
  check("page is PID-profile scoped (no profileField override)", page:find("profileField%s*=") == nil)
  for i = 1, #ORDER do
    check("page builds " .. ORDER[i], page:find('key = "' .. ORDER[i] .. '"', 1, true) ~= nil)
  end
  check("page builds tc_mode", page:find('key = "tc_mode"', 1, true) ~= nil)
  check("page builds tc_ramp_time", page:find('key = "tc_ramp_time"', 1, true) ~= nil)
  check("page title is Drive Aids", page:find('PAGE_TITLE = "@i18n(app.modules.drive_aids.name)@"', 1, true) ~= nil)
end

local tool = readFile(SUITE .. "/app/tool.lua")
local row = tool and tool:match("[^\n]*app/pages/drive_aids_abs%.lua[^\n]*")
check("menu row present in app/tool.lua", row ~= nil)
if row then
  local icon = row:match('lcd%.loadMask%("([^"]+)"%)')
  check("menu row icon exists", icon ~= nil and readFile(SUITE .. "/" .. icon) ~= nil, icon)
  check("menu row is in the Drive Aids group", row:find("app.menu_section_drive_aids", 1, true) ~= nil)
  check("menu tile is titled Drive Aids", row:find("app.modules.drive_aids.name", 1, true) ~= nil)
end

-- ---------------------------------------------------------------------------

print("")
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.exit(0)
else
  print(string.format("%d of %d checks FAILED", failures, checks))
  os.exit(1)
end
