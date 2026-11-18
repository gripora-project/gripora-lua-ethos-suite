-- Run from the repository root with Lua 5.3+: lua bin/tests/setup_wizard_surfaces.lua
-- lib/setup_wizard_surfaces.lua is a car-only port of the configurator's
-- src/tabs/setup_wizard/surfaces.js. The reach, trim and scale cases are
-- those of the configurator's scripts/tests/setup-wizard-surfaces.test.mjs,
-- with the same inputs and expected values, moved onto the steering (yaw)
-- axis; the aircraft surface kinds and the flap channel are gone here.

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

local S = assert(loadfile(ROOT .. "lib/setup_wizard_surfaces.lua"))()

local SET, ADD = 1, 2
-- rule(oper, src, dst, weight, weightNeg) as in the JS test; dst is the mixer
-- output (servo + 1).
local function rule(oper, src, dst, weight, weightNeg)
  return {oper = oper, input = src, output = dst, weight = weight, weightNeg = weightNeg or weight}
end
local function servo(overrides)
  local s = {mid = 1520, min = -500, max = 500, rneg = 500, rpos = 500, flags = 0}
  for k, v in pairs(overrides or {}) do s[k] = v end
  return s
end
local gains = {roll = 1, pitch = 1, yaw = 1}
local function near(a, b) return math.abs(a - b) < 1e-9 end

-- the car preset: steering on S1 and rear steering on S2, the ESC is no servo
do
  local surfaces = S.surfacesFromRules({
    rule(SET, 3, 1, 1000), rule(SET, 3, 2, -500),
    rule(SET, 4, 27, 1000), -- throttle to the ESC, not a servo
  }, 8)
  local got = {}
  for i, s in ipairs(surfaces) do got[i] = s.servo .. ":" .. s.kind end
  got = table.concat(got, " ")
  check("car preset: kinds", got == "0:steering 1:steering", got)
  check("car preset: steering primary axis is yaw", S.primaryAxis(surfaces[1]) == "yaw")
end

-- a servo on an axis the car leaves at zero, or on two axes, is mixed
do
  local surfaces = S.surfacesFromRules({
    rule(SET, 2, 1, 1000), -- pitch alone
    rule(SET, 2, 2, 1000), rule(ADD, 1, 2, 1000), -- pitch and roll
    rule(SET, 3, 3, 1000), rule(ADD, 2, 3, 500), -- yaw with pitch on top
  }, 8)
  check("pitch alone is mixed", surfaces[1].kind == "mixed", surfaces[1].kind)
  check("pitch and roll is mixed, built on pitch", surfaces[2].kind == "mixed"
    and S.primaryAxis(surfaces[2]) == "pitch", S.primaryAxis(surfaces[2]))
  check("steering with pitch on top is mixed, built on yaw", surfaces[3].kind == "mixed"
    and S.primaryAxis(surfaces[3]) == "yaw", S.primaryAxis(surfaces[3]))
  local reach = S.travelReach(surfaces[2], servo({max = 450, min = -450}), gains)
  check("two axes sum: pos reach 1000 us", near(reach.pos.us, 1000), reach.pos.us)
  check("two axes sum: pos fraction 1000/450", near(reach.pos.fraction, 1000 / 450), reach.pos.fraction)
  check("two axes sum: neg fraction > 2", reach.neg.fraction > 2, reach.neg.fraction)
end

-- a later SET replaces earlier rules on the same output and axis
do
  local surface = S.surfacesFromRules({rule(SET, 3, 1, 1000), rule(SET, 3, 1, 600)}, 8)[1]
  check("later SET replaces", near(surface.axes.yaw.pos, 0.6), surface.axes.yaw.pos)
end

-- differential weights give different reach per side
do
  local steering = S.surfacesFromRules({rule(SET, 3, 1, 1000, 500)}, 8)[1]
  check("differential: +1 stick", near(S.outputForAxis(steering, "yaw", 1, gains), 1))
  check("differential: -1 stick", near(S.outputForAxis(steering, "yaw", -1, gains), -0.5))
  local reach = S.travelReach(steering, servo(), gains)
  check("differential: pos 500 us", near(reach.pos.us, 500), reach.pos.us)
  check("differential: neg 250 us", near(reach.neg.us, 250), reach.neg.us)
end

-- servo reverse moves the output to the other side
do
  check("servoSide: not reversed", S.servoSide(0.8, false) == "pos")
  check("servoSide: reversed", S.servoSide(0.8, true) == "neg")
  local steering = S.surfacesFromRules({rule(SET, 3, 1, 1000, 500)}, 8)[1]
  local reach = S.travelReach(steering, servo({flags = 1}), gains)
  check("reversed: pos 250 us", near(reach.pos.us, 250), reach.pos.us)
  check("reversed: neg 500 us", near(reach.neg.us, 500), reach.neg.us)
end

-- axis gain scales the reach
do
  local steering = S.surfacesFromRules({rule(SET, 3, 1, 1000)}, 8)[1]
  local reach = S.travelReach(steering, servo(), {roll = 1, pitch = 1, yaw = 0.5})
  check("axis gain scales reach", near(reach.pos.fraction, 0.5), reach.pos.fraction)
end

-- the limit is the travel the output can use at this centre
do
  local lo, hi = S.usableTravel({mid = 1500, min = -600, max = 600})
  check("usable travel: the defaults are used in full", lo == -600 and hi == 600, lo .. "/" .. hi)
  lo, hi = S.usableTravel({mid = 1700, min = -900, max = 600})
  check("usable travel: held to the signal range at centre 1700", lo == -820 and hi == 459, lo .. "/" .. hi)
  local steering = S.surfacesFromRules({rule(SET, 3, 1, 1000)}, 8)[1]
  local reach = S.travelReach(steering, servo({mid = 1700, min = -600, max = 600}), gains)
  check("reach: pos limit is the usable 459", reach.pos.limit == 459, reach.pos.limit)
  check("reach: neg limit is the stored 600", reach.neg.limit == 600, reach.neg.limit)
  check("reach: pos fraction against the usable travel", near(reach.pos.fraction, reach.pos.us / 459),
    reach.pos.fraction)
end

-- a saved trim takes travel from one side and gives it to the other
do
  local lo, hi = S.usableTravel({mid = 1500, min = -500, max = 500, rneg = 500, rpos = 500}, 100)
  check("usable travel: +100 trim leaves 400 above and 600 below", lo == -600 and hi == 400, lo .. "/" .. hi)
  local steering = S.surfacesFromRules({rule(SET, 3, 1, 1000)}, 8)[1]
  local reach = S.travelReach(steering, servo({mid = 1500, min = -500, max = 500}), gains, 100)
  check("reach: full stick of 500 against 400 clips", reach.pos.limit == 400 and reach.pos.fraction > 1,
    reach.pos.fraction)
  check("reach: and has room on the other side", reach.neg.limit == 600 and reach.neg.fraction < 1,
    reach.neg.fraction)
  reach = S.travelReach(steering, servo({mid = 1500, min = -500, max = 500}), gains)
  check("reach: no trim given is no trim", reach.pos.limit == 500 and reach.neg.limit == 500)
end

-- a saved trim larger than a fifth of the larger scale is applied as that fifth
do
  local cfg = {mid = 1500, min = -300, max = 300, rneg = 250, rpos = 250}
  check("applied trim: 100 against scale 250 is 50", S.appliedTrim(cfg, 100) == 50, S.appliedTrim(cfg, 100))
  check("applied trim: either sign", S.appliedTrim(cfg, -100) == -50)
  check("applied trim: the larger scale counts",
    S.appliedTrim({mid = 1500, min = -300, max = 300, rneg = 250, rpos = 500}, 100) == 100)
  check("applied trim: none saved is none", S.appliedTrim(cfg, nil) == 0)
  local lo, hi = S.usableTravel(cfg, 100)
  check("usable travel: uses the applied trim", lo == -350 and hi == 250, lo .. "/" .. hi)
end

-- a side with no travel at all clips as soon as it is asked to move
do
  local steering = S.surfacesFromRules({rule(SET, 3, 1, 1000)}, 8)[1]
  local reach = S.travelReach(steering, servo({mid = 1500, min = -500, max = 0}), gains)
  check("zero limit: asked to move, so it clips", reach.pos.fraction > 1 and reach.pos.fraction < 10,
    reach.pos.fraction)
  check("zero limit: the other side is unaffected", near(reach.neg.fraction, 1), reach.neg.fraction)
  reach = S.travelReach(steering, servo({mid = 1500, min = -500, max = 0}), {roll = 1, pitch = 1, yaw = 0})
  check("zero limit: nothing asked, nothing clips", reach.pos.fraction == 0, reach.pos.fraction)
end

-- largest scale that keeps full stick inside the binding limit
do
  check("maxScale(1, 700)", S.maxScale(1, 700) == 700)
  check("maxScale(0.83, 700): larger with axis gain 83%", S.maxScale(0.83, 700) == 843, S.maxScale(0.83, 700))
  check("maxScale(-0.83, 700): either side", S.maxScale(-0.83, 700) == 843)
  check("maxScale(0.5, 700): never past the travel limit", S.maxScale(0.5, 700) == 1000)
  check("maxScale(1, 20): never below the minimum", S.maxScale(1, 20) == 50)
  check("maxScale(0, 700): axis gain 0 limits nothing", S.maxScale(0, 700) == 1000)
end

-- Lua-only: the rule shape and orderings the port has to get right itself.
do
  local surfaces = S.surfacesFromRules({
    rule(SET, 3, 2, 1000), rule(ADD, 1, 2, 500), -- roll+yaw, yaw rule first
    rule(SET, 13, 1, 1000), rule(SET, 3, 1, 1000), -- an AUX channel is no axis
    rule(3, 1, 3, 1000),                       -- MUL: ignored
    rule(SET, 2, 9, 1000),                     -- past the board's 4 servos
    rule(SET, 13, 4, 1000),                    -- an AUX channel alone: no surface
  }, 4)
  check("sorted by servo", surfaces[1].servo == 0 and surfaces[2].servo == 1)
  check("an AUX channel adds nothing to steering", surfaces[1].kind == "steering"
    and surfaces[1].flap == nil, surfaces[1].kind)
  check("mixed surface falls back to its first axis", surfaces[2].kind == "mixed"
    and S.primaryAxis(surfaces[2]) == "yaw", S.primaryAxis(surfaces[2]))
  check("MUL rule and AUX channel make no surface", #surfaces == 2, #surfaces)
  check("no flap helpers left", S.FLAP_INPUT == nil and S.outputForFlap == nil)
  local past = S.servosPastCount({rule(SET, 2, 9, 1000), rule(SET, 2, 6, 1000), rule(SET, 2, 6, 0)}, 4, 8)
  check("servosPastCount: in slots only, once each", table.concat(past, ",") == "6", table.concat(past, ","))
  -- The wizard's own call: 24 servo slots (MSP API 22.16). Outputs 25 and 26
  -- are reserved and 27 is a motor, so none of them is a missing servo.
  past = S.servosPastCount({rule(SET, 2, 24, 1000), rule(SET, 2, 9, 1000), rule(SET, 2, 25, 1000),
    rule(SET, 2, 26, 1000), rule(SET, 2, 27, 1000)}, 8, 24)
  check("servosPastCount: 24 slots, the reserved outputs and the motors left out",
    table.concat(past, ",") == "9,24", table.concat(past, ","))
  local bus = S.surfacesFromRules({rule(SET, 1, 9, 1000), rule(SET, 2, 24, 1000)}, 24)
  check("a servo on a bus channel only is a surface like any other",
    #bus == 2 and bus[1].servo == 8 and bus[2].servo == 23, #bus)
  local g = S.axisGainsFromRates({roll = 830, pitch = -1000})
  check("axis gains from rates", near(g.roll, 0.83) and near(g.pitch, -1) and near(g.yaw, 1))
end

print(string.format("%d checks, %d failed", checks, failures))
os.exit(failures == 0 and 0 or 1)
