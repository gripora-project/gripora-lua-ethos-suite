-- Behaviour check for the drift config codec (lib/msp_drift_config.lua), the
-- Drift page and menu row that use it, and the DRIFT mode entries.
--
-- Run it:
--     lua5.4 bin/drift_config/verify_drift_config.lua
--
-- The wire layout is transcribed from the firmware handler (gripora-firmware
-- msp.c, pg/drift.h): MSP2_GRIPORA_DRIFT_CONFIG (0x5F42) replies U8 gain (%),
-- U16 allow (deg/s), U8 limit (%) -- 4 bytes -- for the current PID profile.
-- MSP2_GRIPORA_SET_DRIFT_CONFIG (0x5F43) takes the same 4 bytes and refuses the
-- whole write if any value is out of range (gain 0..200, allow 0..720, limit
-- 10..100), so the FIELD_META ranges are pinned to its checks. Firmware without
-- drift mode answers the command as unsupported (the MSP error flag): the page
-- loads with supported = false, greys its fields out and writes nothing.
-- DRIFT is permanent mode id 68 (msp_box.c).

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
local codec = requireModule("lib/msp_drift_config.lua")

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

-- The read's errorHandler with `reason`, as tasks/msp/queue.lua calls it.
local function readError(reason)
  local got, errReason
  local errored = false
  codec.buildReadMessage(
    function(d) got = d end,
    function(r) errored = true; errReason = r end
  ).errorHandler(reason)
  return got, errored, errReason
end

-- 150 %, 90 deg/s (U16 LE 0x005A), limit 60 %.
local REPLY = {150, 0x5A, 0x00, 60}

-- ---------------------------------------------------------------------------
print("case 1: commands and field order match the firmware handler")

check("read is 0x5F42", codec.READ_COMMAND == 0x5F42, codec.READ_COMMAND)
check("write is 0x5F43", codec.WRITE_COMMAND == 0x5F43, codec.WRITE_COMMAND)
check("reply is four bytes", codec.REPLY_LENGTH == 4, codec.REPLY_LENGTH)
check("fields gain, allow, limit", table.concat(codec.FIELDS, ",") == "gain,allow,limit",
  table.concat(codec.FIELDS, ","))

-- ---------------------------------------------------------------------------
print("case 2: FIELD_META ranges and defaults match pg/drift.h/.c and msp.c's checks")

local EXPECT = {gain = {0, 200, 100, "%"}, allow = {0, 720, 30, "°/s"}, limit = {10, 100, 100, "%"}}
for key, e in pairs(EXPECT) do
  local m = codec.FIELD_META[key]
  check(key .. " range/default/unit", m and m.min == e[1] and m.max == e[2] and m.default == e[3] and m.suffix == e[4],
    m and (m.min .. ".." .. m.max .. " d" .. tostring(m.default) .. " " .. tostring(m.suffix)))
end

-- ---------------------------------------------------------------------------
print("case 3: decode/encode round-trip")

local sim = codec.buildReadMessage(function() end, function() end).simulatorResponse
local simData, simErrored = read(sim)
check("simulatorResponse decodes", simData ~= nil and not simErrored)
if simData then
  check("simulatorResponse is the firmware defaults (100 %, 30 deg/s, 100 %)",
    #sim == 4 and simData.gain == 100 and simData.allow == 30 and simData.limit == 100 and simData.supported == true)
end

local data, errored = read(REPLY)
check("a valid reply reaches onData", data ~= nil and not errored)
if data then
  check("every field decoded", data.gain == 150 and data.allow == 90 and data.limit == 60 and data.supported == true,
    tostring(data.gain) .. "/" .. tostring(data.allow) .. "/" .. tostring(data.limit))
  local msg = codec.buildWriteMessage(data, function() end, function() end)
  check("write uses 0x5F43", msg and msg.command == 0x5F43, msg and msg.command)
  local same = msg and #msg.payload == 4
  for i = 1, 4 do same = same and msg.payload[i] == REPLY[i] end
  check("the write is exactly the four reply bytes", same, msg and table.concat(msg.payload, ","))
end
local big = codec.encode({gain = 200, allow = 720, limit = 10, supported = true})
check("allow is a U16, little-endian (720 = 0xD0 0x02)", table.concat(big, ",") == "200,208,2,10", table.concat(big, ","))
local empty = codec.encode({})
check("encode of an empty table is the defaults", table.concat(empty, ",") == "100,30,0,100", table.concat(empty, ","))

-- ---------------------------------------------------------------------------
print("case 4: a longer reply reads the known four; a short one is refused")

local long = copy(REPLY); long[5] = 7; long[6] = 9
data, errored = read(long)
check("6-byte reply reaches onData", data ~= nil and not errored)
check("limit is byte 4, not an appended byte", data and data.limit == 60, data and data.limit)
check("write stays four bytes", data and #codec.encode(data) == 4)
local got, err, reason, refused = read({150, 0x5A, 0x00})
check("3-byte reply does not reach onData", got == nil)
check("3-byte reply is reported through onError as refused", err and refused == true, reason)

-- ---------------------------------------------------------------------------
print("case 5: firmware without drift mode")

got, err = readError(true)
check("an unsupported answer (MSP error flag) is data, not a failed read", got ~= nil and not err)
check("with supported = false and no values", got and got.supported == false and got.gain == nil)
check("and builds no write", codec.buildWriteMessage(got, function() end, function() end) == nil)
local _, timeoutErr, timeoutReason = readError("timeout")
check("a timeout is still a failed read", timeoutErr and timeoutReason == "timeout", timeoutReason)

-- ---------------------------------------------------------------------------
print("case 6: the page, its menu row and the DRIFT mode")

local page = readFile(SUITE .. "/app/pages/drift.lua")
check("drift.lua readable", page ~= nil)
if page then
  check("uses this codec", page:find("lib/msp_drift_config.lua", 1, true) ~= nil)
  check("is an MSP page (save refused while armed)", page:find("isMspPage%s*=%s*true") ~= nil)
  check("does not reboot after save", page:find("rebootAfterSave") == nil)
  -- Stored per PID profile; the message reads/writes the current one.
  check("is PID-profile scoped (no profileField override)", page:find("profileField%s*=") == nil)
  for _, key in ipairs({"gain", "allow", "limit"}) do
    check("builds " .. key, page:find('key = "' .. key .. '"', 1, true) ~= nil)
  end
  check("greys the fields out on firmware without drift mode", page:find("supported", 1, true) ~= nil
    and page:find(":enable(supported)", 1, true) ~= nil)
  check("says the DRIFT switch turns it on", page:find("@i18n(app.modules.drift.note)@", 1, true) ~= nil)
  check("title is app.modules.drift.name", page:find('PAGE_TITLE = "@i18n(app.modules.drift.name)@"', 1, true) ~= nil)
end

local tool = readFile(SUITE .. "/app/tool.lua")
local row = tool and tool:match('[^\n]*app/pages/drift%.lua[^\n]*')
check("menu row present", row ~= nil)
if row then
  local icon = row:match('lcd%.loadMask%("([^"]+)"%)')
  check("menu row icon exists", icon ~= nil and readFile(SUITE .. "/" .. icon) ~= nil, icon)
  local tuningAt = tool:find("tuning_menu = {", 1, true)
  check("is in the Tuning menu", tuningAt ~= nil and tool:find(row, 1, true) > tuningAt)
  check("is in the Steering group", row:find("app.menu_section_steering", 1, true) ~= nil)
end

local modes = readFile(SUITE .. "/app/pages/modes.lua")
check("modes page names id 68 DRIFT", modes and modes:find('[68] = "DRIFT"', 1, true) ~= nil)
check("modes page orders DRIFT with the driving modes",
  modes and modes:find('"GYRO OFF", "DRIVE AIDS OFF", "LAUNCH", "DRIFT"', 1, true) ~= nil)
local wizard = readFile(SUITE .. "/app/pages/setup_wizard_modes.lua")
check("the wizard's modes step offers DRIFT (68), optional, with help",
  wizard and wizard:find('{id = 68, names = {"DRIFT"}, help = "@i18n(app.modules.setup_wizard.mod_help_drift)@"}', 1, true) ~= nil)

-- ---------------------------------------------------------------------------

print("")
if failures == 0 then
  print(string.format("all %d checks passed", checks))
  os.exit(0)
else
  print(string.format("%d of %d checks FAILED", failures, checks))
  os.exit(1)
end
