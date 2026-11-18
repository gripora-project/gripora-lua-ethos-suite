-- Run from the repository root with Lua 5.4: lua5.4 bin/tests/setup_wizard_mix.lua
-- lib/setup_wizard_mix.lua is a port of the configurator's car mixer preset
-- (src/js/carMixer.js). These are the configurator's own cases, from
-- scripts/tests/car-mixer.test.mjs, on the Lua rule shape (input/output where
-- the JS has src/dst). When carMixer.js changes, port the change and its
-- test here.

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

package.loaded["grsuite.lib.require"] = function(name)
  local key = "grsuite." .. name:gsub("%.lua$", ""):gsub("/", ".")
  if package.loaded[key] ~= nil then return package.loaded[key] end
  local result = assert(loadfile(ROOT .. name))()
  package.loaded[key] = (result == nil) and true or result
  return package.loaded[key]
end

local M = assert(loadfile(ROOT .. "lib/setup_wizard_mix.lua"))()
local surfacesLib = package.loaded["grsuite.lib.require"]("lib/setup_wizard_surfaces.lua")

local SET = 1
local YAW, THROTTLE = 3, 4
local S1, S2, M1, M2 = 1, 2, 27, 28

local function nul()
  return {oper = 0, input = 0, output = 0, offset = 0, weight = 0, weightNeg = 0, speed = 0, curve = 0,
    condition = 0, role = 0}
end

local function brief(rules)
  local out = {}
  for i, r in ipairs(rules) do out[i] = table.concat({r.oper, r.input, r.output, r.weight, r.weightNeg}, ",") end
  return table.concat(out, ";")
end

local function same(a, b)
  for _, k in ipairs({"rearSteering", "rearMode", "rearPercent", "secondEsc"}) do
    if a[k] ~= b[k] then return false end
  end
  return true
end

-- base car: steering on S1 and a reversible ESC on M1, as the firmware defaults
do
  local rules = M.buildCarRules(M.DEFAULT_OPTIONS)
  check("base car: steering S1, ESC M1", brief(rules) == "1,3,1,1000,1000;1,4,27,1000,1000", brief(rules))
  local plain = true
  for _, r in ipairs(rules) do plain = plain and r.offset == 0 and r.curve == 0 and r.condition == 0 end
  check("base car: nothing bends or clamps the signed throttle", plain)
end

-- rear steering opposite: negative weight on S2 at the chosen percentage
do
  local rules = M.buildCarRules({rearSteering = true, rearMode = "opposite", rearPercent = 50})
  check("rear opposite: -500 on S2", #rules == 3 and brief({rules[3]}) == "1,3,2,-500,-500", brief(rules))
end

-- rear steering same direction: positive weight on S2
do
  local rules = M.buildCarRules({rearSteering = true, rearMode = "same", rearPercent = 30})
  check("rear same: +300 on S2", brief({rules[3]}) == "1,3,2,300,300", brief(rules))
end

-- rear steering percentage is clamped to 0..100 and 0% is not -0
do
  check("rear 150% clamps to -1000", M.buildCarRules({rearSteering = true, rearPercent = 150})[3].weight == -1000)
  local zero = M.buildCarRules({rearSteering = true, rearPercent = -5})[3]
  check("rear -5% is 0, not -0", zero.weight == 0 and math.type(zero.weight) == "integer"
    and 1 / zero.weight > 0, tostring(zero.weight))
  check("a rear percentage that isn't a number keeps the default",
    M.carOptions({rearPercent = "x"}).rearPercent == M.DEFAULT_OPTIONS.rearPercent)
end

-- second ESC: throttle also on M2, after rear steering
do
  local rules = M.buildCarRules({secondEsc = true, rearSteering = true})
  check("second ESC after rear steering",
    brief(rules) == "1,3,1,1000,1000;1,4,27,1000,1000;1,3,2,-500,-500;1,4,28,1000,1000", brief(rules))
end

-- options round-trip through the rules, with null rules in between
do
  local cases = {
    M.DEFAULT_OPTIONS,
    {rearSteering = true, rearMode = "opposite", rearPercent = 50, secondEsc = false},
    {rearSteering = true, rearMode = "same", rearPercent = 75, secondEsc = true},
    {rearSteering = false, rearMode = "opposite", rearPercent = 50, secondEsc = true},
  }
  for i, options in ipairs(cases) do
    local t = M.buildCarRules(options)
    t[#t + 1] = nul()
    t[#t + 1] = nul()
    table.insert(t, 2, nul())
    local back = M.carOptionsFromRules(t)
    check("round trip " .. i, back ~= nil and same(back, M.carOptions(options)))
  end
end

-- hand-edited or aircraft rules are not a car setup
do
  local edited = M.buildCarRules(M.DEFAULT_OPTIONS)
  edited[1].weight = 800
  check("edited weight is not a car", M.carOptionsFromRules(edited) == nil)
  local extra = M.buildCarRules(M.DEFAULT_OPTIONS)
  extra[#extra + 1] = {oper = SET, input = 1, output = 3, offset = 0, weight = 1000, weightNeg = 1000,
    speed = 0, curve = 0, condition = 0, role = 0}
  check("an extra rule is not a car", M.carOptionsFromRules(extra) == nil)
  local swapped = M.buildCarRules(M.DEFAULT_OPTIONS)
  swapped[1], swapped[2] = swapped[2], swapped[1]
  check("reordered rules are not a car", M.carOptionsFromRules(swapped) == nil)
  check("no rules is not a car", M.carOptionsFromRules({}) == nil)
end

-- the wizard sees the steering servos and not the ESCs
do
  local rules = M.buildCarRules({rearSteering = true, secondEsc = true})
  local surfaces = surfacesLib.surfacesFromRules(rules, 8)
  check("two steering servos, no ESCs", #surfaces == 2 and surfaces[1].servo == 0 and surfaces[1].kind == "rudder"
    and surfaces[2].servo == 1 and surfaces[2].kind == "rudder")
  check("rear servo at -0.5 on yaw", surfaces[2] and surfaces[2].axes.yaw.pos == -0.5)
  local escs = M.escOutputs(rules)
  check("ESC outputs M1 and M2", #escs == 2 and escs[1] == 1 and escs[2] == 2)
end

-- a throttle input clamped to 0..1000 gets its reverse half back
do
  local input = {rate_stabilized_throttle = 1000, min_stabilized_throttle = 0, max_stabilized_throttle = 1000}
  check("clamped throttle gets -1000", M.ensureSignedThrottle(input, "min_stabilized_throttle") == true
    and input.min_stabilized_throttle == -1000)
  check("a signed throttle is left alone", M.ensureSignedThrottle(input, "min_stabilized_throttle") == false)
end

-- The full table: car rules, then unused slots.
do
  local t = M.ruleTable({rearSteering = true})
  check("ruleTable pads to 32 slots", #t == 32 and t[4].oper == 0 and t[2].output == M1 and t[3].output == S2)
  check("servosUsed counts servos, not motors", M.servosUsed(t) == 2)
  check("model types: car 0, custom 1", M.MODEL_TYPE_CAR == 0 and M.MODEL_TYPE_CUSTOM == 1)
end

print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
