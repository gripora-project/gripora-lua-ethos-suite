-- Run from the repository root with Lua 5.4: lua5.4 bin/tests/servo_names.lua
-- lib/servo_names.lua is a car-only port of gripora-configurator's
-- src/js/ServoNames.js: steering (STEER) and mixed (MIX) servos, with the
-- aircraft names the configurator still generates kept only as names to
-- clear. The rule sets are carried as oper,input,output,weight,weightNeg,role.
-- Also covers lib/msp_servo_names.lua's wire format.

local ROOT = "src/grsuite/"

local failures, checks = 0, 0
local function check(label, ok, detail)
  checks = checks + 1
  if ok then
    print("  ok    " .. label)
  else
    failures = failures + 1
    print("  FAIL  " .. label)
    if detail then print("        " .. tostring(detail)) end
  end
end

-- lib/require.lua resolves "lib/x.lua" from the script root on the radio.
-- Here every module is loaded from src/grsuite/ instead.
package.loaded["grsuite.lib.require"] = function(path)
  local key = "grsuite." .. path:gsub("%.lua$", ""):gsub("/", ".")
  if package.loaded[key] then return package.loaded[key] end
  local mod = assert(loadfile(ROOT .. path))()
  package.loaded[key] = mod
  return mod
end

-- "oper,input,output,weight,weightNeg,role;..." to rules.
local function parseRules(text)
  local rules = {}
  for item in text:gmatch("[^;]+") do
    local f = {}
    for n in item:gmatch("[^,]+") do f[#f + 1] = tonumber(n) end
    rules[#rules + 1] = {oper = f[1], input = f[2], output = f[3], offset = 0, weight = f[4], weightNeg = f[5],
      speed = 0, curve = 0, condition = 0, role = f[6]}
  end
  return rules
end

local RULES = {
  car = "1,3,1,1000,1000,0;1,4,27,1000,1000,0",
  carRear = "1,3,1,1000,1000,0;1,4,27,1000,1000,0;1,3,2,-500,-500,0",
  carRearTwoEsc = "1,3,1,1000,1000,0;1,4,27,1000,1000,0;1,3,2,500,500,0;1,4,28,1000,1000,0",
  -- What the car leaves at zero still mixes: one servo each, then a pair.
  pitchServo = "1,3,1,1000,1000,0;1,2,2,1000,1000,0;1,4,27,1000,1000,0",
  mixedPair = "1,3,1,1000,1000,0;2,2,1,500,500,0;1,3,2,1000,1000,0;2,2,2,-500,-500,0",
  -- Thrust-vector and flap inputs name nothing now.
  oldInputs = "1,3,1,1000,1000,0;1,28,2,1000,1000,0;1,13,3,1000,1000,0",
}
local names = package.loaded["grsuite.lib.require"]("lib/servo_names.lua")
local codec = package.loaded["grsuite.lib.require"]("lib/msp_servo_names.lua")

local function render(map)
  local servos = {}
  for servo in pairs(map) do servos[#servos + 1] = servo end
  table.sort(servos)
  local out = {}
  for i, servo in ipairs(servos) do out[i] = servo .. "=" .. map[servo] end
  return table.concat(out, ";")
end

local CASES = {
  {name = "car", names = "0=STEER"},
  {name = "carRear", names = "0=F STEER;1=R STEER"},
  {name = "carRearTwoEsc", names = "0=F STEER;1=R STEER"},
  {name = "pitchServo", names = "0=STEER;1=MIX"},
  {name = "mixedPair", names = "0=L MIX;1=R MIX"},
  {name = "oldInputs", names = "0=STEER"},
}

for _, case in ipairs(CASES) do
  local got = render(names.namesFromRules(parseRules(RULES[case.name])))
  check(case.name .. " names", got == case.names, got)
end

-- Three of a kind are numbered.
local three = {}
for s = 1, 3 do three[s] = {oper = 1, input = 3, output = s, weight = 1000, weightNeg = 1000} end
check("three of a kind numbered",
  render(names.namesFromRules(three)) == "0=STEER 1;1=STEER 2;2=STEER 3",
  render(names.namesFromRules(three)))

-- assign(): assigned servos are named (a typed name there too), a generated
-- name on a servo the mix no longer drives is cleared, a typed one is kept.
local current = {}
for s = 0, names.SERVO_COUNT - 1 do current[s] = "" end
current[3] = "MYSERVO"
current[5] = "TOWHOOK"
current[6] = "L FLAP"
current[7] = "TV ROLL"
current[2] = "L AIL"
local changed = names.assign(current, parseRules(RULES.carRear))
check("assign names the mix, over a typed name too",
  current[0] == "F STEER" and current[1] == "R STEER" and current[3] == "MYSERVO", render(current))
check("assign keeps a typed name off the mix", current[5] == "TOWHOOK", current[5])
check("assign clears generated and old aircraft names off the mix",
  current[2] == "" and current[6] == "" and current[7] == "", current[2] .. "|" .. current[6] .. "|" .. current[7])
check("assign reports exactly the changed servos", table.concat(changed, ",") == "0,1,2,6,7", table.concat(changed, ","))
check("assign again changes nothing", #names.assign(current, parseRules(RULES.carRear)) == 0)

check("isGenerated", names.isGenerated("R MIX") and names.isGenerated("STEER 3")
  and names.isGenerated("R ELEVON") and names.isGenerated("AIL 3") and names.isGenerated("TV YAW")
  and not names.isGenerated("AILX") and not names.isGenerated("") and not names.isGenerated("L TOW"))

-- A pair of steering servos is front and rear (gripora-configurator
-- ServoNames.js); RUDDER, the name earlier versions gave, still counts as
-- generated so it is cleared when the mix moves on.
local steerPair = {
  {oper = 1, input = 3, output = 1, weight = 1000, weightNeg = 1000},
  {oper = 1, input = 3, output = 2, weight = -500, weightNeg = -500},
}
check("steering pair named front and rear",
  render(names.namesFromRules(steerPair)) == "0=F STEER;1=R STEER",
  render(names.namesFromRules(steerPair)))
check("legacy RUDDER names count as generated",
  names.isGenerated("RUDDER") and names.isGenerated("L RUDDER") and names.isGenerated("F STEER"))

check("withName adds the name", names.withName("Servo 1", {[0] = "L AIL"}, 0) == "Servo 1 (L AIL)")
check("withName leaves an unnamed servo", names.withName("Servo 2", {[0] = "L AIL", [1] = ""}, 1) == "Servo 2")
check("withName without names", names.withName("Servo 1", nil, 0) == "Servo 1")

-- Wire format (firmware msp.c, MSP2_GRIPORA_SERVO_NAMES / SET_SERVO_NAME)
check("clean trims, drops non-printables, caps at 8",
  codec.clean("  Elevator!xyz") == "Elevator" and codec.clean("L\1 AIL ") == "L AIL"
  and codec.clean(nil) == "" and codec.clean("ABCDEFG HIJ") == "ABCDEFG", codec.clean("ABCDEFG HIJ"))
local payload = codec.encode(2, " ELEV ")
check("encode: servo then the cleaned name", table.concat(payload, ",") == "2,69,76,69,86", table.concat(payload, ","))
check("encode: an empty name clears", table.concat(codec.encode(5, ""), ",") == "5")

local msg = codec.buildReadMessage()
local buf = {}
for i, b in ipairs(msg.simulatorResponse) do buf[i] = b end
local decoded, count = codec.decode(buf)
check("decode the simulator response", count == 24 and decoded[0] == "STEER" and decoded[3] == ""
  and decoded[4] == "" and decoded[23] == "", tostring(count) .. " " .. tostring(decoded[0]))
local full = {1, 8, 65, 66, 67, 68, 69, 70, 71, 72}
decoded = codec.decode(full)
check("decode an 8-character name", decoded[0] == "ABCDEFGH", decoded[0])

print(string.format("%d checks, %d failures", checks, failures))
os.exit(failures == 0 and 0 or 1)
