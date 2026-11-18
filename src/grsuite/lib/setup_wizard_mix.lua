-- The Setup Wizard's Model step: the car mixer preset and the rules it gets.
--
-- A port of gripora-configurator src/js/carMixer.js (buildCarRules(),
-- carOptions(), carOptionsFromRules(), ensureSignedThrottle()) and the model
-- types of Mixer.js. Keep the two in step; bin/tests/setup_wizard_mix.lua
-- carries the configurator's car-mixer.test.mjs cases. Rules come out in
-- lib/msp_mixer_rules.lua's shape (input/output, where the JS has src/dst).
--
-- The default car (gripora-firmware pg/mixer.c) is steering on S1 and a
-- reversible ESC on M1. Optional extras: a rear steering servo on S2 and a
-- second ESC on M2.

if package.loaded["grsuite.lib.setup_wizard_mix"] then
  return package.loaded["grsuite.lib.setup_wizard_mix"]
end

local M = {}

M.RULE_COUNT = 32
M.MOTOR_OUTPUT_OFFSET = 27

-- mixerConfig_t.model_type (firmware pg/mixer.h)
M.MODEL_TYPE_CAR = 0
M.MODEL_TYPE_CUSTOM = 1

local OP_SET = 1

-- Mixer inputs (firmware pg/mixer.h MIXER_IN_*)
M.CAR_INPUT_STEERING = 3   -- MIXER_IN_STABILIZED_YAW
M.CAR_INPUT_THROTTLE = 4   -- MIXER_IN_STABILIZED_THROTTLE, -1000..1000

-- Mixer outputs (firmware flight/mixer.h): S1 = 1, M1 = 27
M.CAR_OUTPUT_STEERING = 1
M.CAR_OUTPUT_REAR_STEERING = 2
M.CAR_OUTPUT_ESC = 27
M.CAR_OUTPUT_SECOND_ESC = 28

local FULL_WEIGHT = 1000

M.REAR_PERCENT_MIN = 0
M.REAR_PERCENT_MAX = 100

-- rearMode "opposite": the rear wheels steer against the front ones (tighter
-- turns), a negative weight. "same": with them (crab), a positive weight.
M.DEFAULT_OPTIONS = {rearSteering = false, rearMode = "opposite", rearPercent = 50, secondEsc = false}

-- options merged over the defaults and cleaned up: a fresh table.
function M.carOptions(options)
  options = options or {}
  local d = M.DEFAULT_OPTIONS
  local function pick(key)
    if options[key] == nil then return d[key] end
    return options[key]
  end
  local percent = tonumber(pick("rearPercent"))
  if percent and percent == percent and percent ~= math.huge and percent ~= -math.huge then
    percent = math.floor(percent + 0.5)
    if percent < M.REAR_PERCENT_MIN then percent = M.REAR_PERCENT_MIN end
    if percent > M.REAR_PERCENT_MAX then percent = M.REAR_PERCENT_MAX end
  else
    percent = d.rearPercent
  end
  return {
    rearSteering = pick("rearSteering") and true or false,
    rearMode = pick("rearMode") == "same" and "same" or "opposite",
    rearPercent = percent,
    secondEsc = pick("secondEsc") and true or false,
  }
end

local function setRule(input, output, weight)
  return {oper = OP_SET, input = input, output = output, offset = 0, weight = weight, weightNeg = weight,
    speed = 0, curve = 0, condition = 0, role = 0}
end

-- Rules for a car with these options, in table order. Steering and throttle
-- weights stay positive: which way a servo turns is the servo's reverse.
-- Throttle is a plain SET of the signed stabilized throttle, so brake and
-- reverse (below neutral) reach the ESC untouched.
function M.buildCarRules(options)
  local o = M.carOptions(options)
  local rules = {
    setRule(M.CAR_INPUT_STEERING, M.CAR_OUTPUT_STEERING, FULL_WEIGHT),
    setRule(M.CAR_INPUT_THROTTLE, M.CAR_OUTPUT_ESC, FULL_WEIGHT),
  }
  if o.rearSteering then
    local sign = o.rearMode == "opposite" and -1 or 1
    rules[#rules + 1] = setRule(M.CAR_INPUT_STEERING, M.CAR_OUTPUT_REAR_STEERING, sign * o.rearPercent * 10)
  end
  if o.secondEsc then
    rules[#rules + 1] = setRule(M.CAR_INPUT_THROTTLE, M.CAR_OUTPUT_SECOND_ESC, FULL_WEIGHT)
  end
  return rules
end

local RULE_FIELDS = {"oper", "input", "output", "offset", "weight", "weightNeg", "speed", "curve", "condition", "role"}

local function isNullRule(rule)
  for i = 1, #RULE_FIELDS do
    local v = rule[RULE_FIELDS[i]]
    if v ~= nil and v ~= 0 then return false end
  end
  return true
end

local function sameRule(a, b)
  for i = 1, #RULE_FIELDS do
    local f = RULE_FIELDS[i]
    if (a[f] or 0) ~= (b[f] or 0) then return false end
  end
  return true
end

-- The options buildCarRules() would have been given to produce `rules`
-- (null rules anywhere are ignored), or nil when the rules are anything
-- else: hand-edited, from Custom, or reordered.
function M.carOptionsFromRules(rules)
  local used = {}
  for _, rule in ipairs(rules or {}) do
    if not isNullRule(rule) then used[#used + 1] = rule end
  end
  local rear, second = nil, false
  for _, rule in ipairs(used) do
    if rule.oper == OP_SET and rule.input == M.CAR_INPUT_STEERING and rule.output == M.CAR_OUTPUT_REAR_STEERING then
      rear = rear or rule
    end
    if rule.oper == OP_SET and rule.input == M.CAR_INPUT_THROTTLE and rule.output == M.CAR_OUTPUT_SECOND_ESC then
      second = true
    end
  end
  local options = M.carOptions({
    rearSteering = rear ~= nil,
    rearMode = (rear and (rear.weight or 0) > 0) and "same" or "opposite",
    rearPercent = rear and math.abs(rear.weight or 0) / 10 or M.DEFAULT_OPTIONS.rearPercent,
    secondEsc = second,
  })
  local expected = M.buildCarRules(options)
  if #expected ~= #used then return nil end
  for i = 1, #expected do
    if not sameRule(expected[i], used[i]) then return nil end
  end
  return options
end

-- Stabilized throttle must keep its negative half (brake/reverse). Puts the
-- input's min back to -1000 if something clamped it at or above 0; returns
-- whether it changed anything. `input` is the throttle mixer input record
-- (lib/msp_mixer_input.lua's min_stabilized_throttle field).
function M.ensureSignedThrottle(input, minKey)
  if not input then return false end
  local key = minKey or "min"
  if (input[key] or 0) < 0 then return false end
  input[key] = -1000
  return true
end

-- The full RULE_COUNT table: the car rules, then unused slots.
function M.ruleTable(options)
  local generated = M.buildCarRules(options)
  local out = {}
  for i = 1, M.RULE_COUNT do
    out[i] = generated[i] or {oper = 0, input = 0, output = 0, offset = 0, weight = 0, weightNeg = 0,
      speed = 0, curve = 0, condition = 0, role = 0}
  end
  return out
end

-- Highest servo number (1-based) the rules use, for the board check.
function M.servosUsed(rules)
  local most = 0
  for _, r in ipairs(rules) do
    if r.oper ~= 0 and r.output >= 1 and r.output < M.MOTOR_OUTPUT_OFFSET and r.output > most then
      most = r.output
    end
  end
  return most
end

-- ESC outputs (1-based motor numbers) the rules drive from throttle.
function M.escOutputs(rules)
  local seen, list = {}, {}
  for _, r in ipairs(rules or {}) do
    if r.oper ~= 0 and r.input == M.CAR_INPUT_THROTTLE and r.output >= M.MOTOR_OUTPUT_OFFSET then
      local m = r.output - M.MOTOR_OUTPUT_OFFSET + 1
      if not seen[m] then
        seen[m] = true
        list[#list + 1] = m
      end
    end
  end
  table.sort(list)
  return list
end

package.loaded["grsuite.lib.setup_wizard_mix"] = M
return M
