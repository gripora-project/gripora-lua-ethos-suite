-- Setup Wizard step: Model. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of gripora-configurator's StepAirframe.svelte and the
-- Mixer tab's car setup (CarOptionsForm.svelte): Car or Custom. Car writes
-- the car mixer preset (lib/setup_wizard_mix.lua, a port of carMixer.js):
-- steering on S1 and a reversible ESC on M1, with optional rear steering on
-- S2 and a second ESC on M2. Custom keeps the rules as they are; they are
-- edited in Mixer Rules. One question per screen, with a picture of the car:
--
--   current   what the car has now; Car (set it up) or Custom, Next keeps it
--   rear      rear steering: none, opposite to the front wheels, the same way
--   amount    how far the rear wheels turn compared with the front ones
--   second    a second ESC?
--   review    the outputs this sets, a warning when the board has fewer
--             servo outputs, and Apply
--
-- Applying also makes sure the stabilized throttle keeps its negative half
-- (brake and reverse), as the configurator's setup dialog does.

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local ui = requireModule("app/setup_wizard_ui.lua")
-- Freed when the step closes (app/setup_wizard_ui.lua's notLoaded()).
local OWNED = ui.notLoaded({"grsuite.lib.setup_wizard_mix"})
local art = requireModule("app/setup_wizard_art.lua")
local mix = requireModule("lib/setup_wizard_mix.lua")
local surfacesLib = requireModule("lib/setup_wizard_surfaces.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.air_title)@",
  intro = "@i18n(app.modules.setup_wizard.air_intro)@",
  current = "@i18n(app.modules.setup_wizard.air_current_fmt)@",
  custom = "@i18n(app.modules.setup_wizard.air_custom)@",
  edited = "@i18n(app.modules.setup_wizard.air_edited)@",
  none = "@i18n(app.modules.setup_wizard.air_no_surfaces)@",
  car = "@i18n(app.modules.setup_wizard.air_type_car)@",
  customType = "@i18n(app.modules.setup_wizard.air_type_custom)@",
  options = "@i18n(app.modules.setup_wizard.air_options)@",
  rearQ = "@i18n(app.modules.setup_wizard.air_q_rear)@",
  rearNone = "@i18n(app.modules.setup_wizard.air_rear_none)@",
  rearOpposite = "@i18n(app.modules.setup_wizard.air_rear_opposite)@",
  rearSame = "@i18n(app.modules.setup_wizard.air_rear_same)@",
  rearHelp = "@i18n(app.modules.setup_wizard.air_rear_help)@",
  amountQ = "@i18n(app.modules.setup_wizard.air_q_amount_fmt)@",
  secondQ = "@i18n(app.modules.setup_wizard.air_q_second_esc)@",
  review = "@i18n(app.modules.setup_wizard.air_review_fmt)@",
  tooFew = "@i18n(app.modules.setup_wizard.air_too_few_fmt)@",
  apply = "@i18n(app.modules.setup_wizard.air_apply)@",
  applied = "@i18n(app.modules.setup_wizard.air_applied)@",
  yes = "@i18n(app.modules.setup_wizard.btn_yes)@",
  no = "@i18n(app.modules.setup_wizard.btn_no)@",
  esc = "@i18n(app.modules.setup_wizard.air_esc_fmt)@",
}

-- The rear steering amount moves in these steps (the configurator's slider
-- steps by 5).
local AMOUNT_STEP = 5

-- The car's outputs as "S1 Steering, M1 ESC, ...", from a rule table.
local function describe(wiz, rules)
  local parts = {}
  for _, s in ipairs(surfacesLib.surfacesFromRules(rules, 26)) do
    parts[#parts + 1] = "S" .. (s.servo + 1) .. " " .. wiz.kindName(s.kind)
  end
  for _, m in ipairs(mix.escOutputs(rules)) do parts[#parts + 1] = string.format(T.esc, m) end
  return #parts > 0 and table.concat(parts, ", ") or T.none
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)

  local screen = "current"
  local options = nil

  local function go(name)
    screen = name
    wiz.rebuild()
  end

  local function startCar()
    -- Start from what the car has, when the rules are the car preset.
    options = mix.carOptionsFromRules(wiz.rules()) or mix.carOptions(nil)
    go("rear")
  end

  local function chooseCustom()
    wiz.setModelType(mix.MODEL_TYPE_CUSTOM)
    wiz.rebuild()
  end

  local function preview()
    local rules = mix.buildCarRules(options)
    return art.layout(surfacesLib.surfacesFromRules(rules, 26), nil), rules
  end

  -- A question's row: Back to the previous screen, then the answers, which
  -- are the way forward (the focus starts on the answer it has).
  local function question(back, specs)
    return scr:row(function() go(back) end, specs, false)
  end

  function self.build()
    scr:begin()
    local cfg = wiz.mixConfig()

    if screen == "current" then
      local isCar = (cfg and cfg.model_type or mix.MODEL_TYPE_CAR) == mix.MODEL_TYPE_CAR
      local rules = wiz.rules() or {}
      local note
      if not isCar then
        note = T.custom
      elseif #wiz.surfaces() > 0 and not mix.carOptionsFromRules(rules) then
        note = T.edited
      end
      local body = T.intro .. " " .. string.format(T.current, isCar and T.car or T.customType, describe(wiz, rules))
      scr:text(T.title, body, note)
      scr:picture(art.layout(wiz.surfaces(), nil))
      -- Next keeps the mix; with nothing mixed yet the focus is on Car.
      local hasSurfaces = #wiz.surfaces() > 0
      return scr:row(nil, {
        {text = isCar and hasSurfaces and T.options or T.car, primary = not hasSurfaces, press = startCar},
        {text = T.customType, small = true, disabled = not isCar, press = chooseCustom},
      })

    elseif screen == "rear" then
      local layout = preview()
      scr:text(T.car, T.rearQ, T.rearHelp, true)
      scr:picture(layout)
      local function rear(on, mode)
        return function()
          options = mix.carOptions({rearSteering = on, rearMode = mode or options.rearMode,
            rearPercent = options.rearPercent, secondEsc = options.secondEsc})
          go(on and "amount" or "second")
        end
      end
      return question("current", {
        {text = T.rearNone, small = true, primary = not options.rearSteering, press = rear(false)},
        {text = T.rearOpposite, small = true, primary = options.rearSteering and options.rearMode == "opposite",
          press = rear(true, "opposite")},
        {text = T.rearSame, small = true, primary = options.rearSteering and options.rearMode == "same",
          press = rear(true, "same")},
      })

    elseif screen == "amount" then
      local layout = preview()
      scr:text(T.car, string.format(T.amountQ, options.rearPercent), nil, true)
      scr:picture(layout)
      local function nudge(delta)
        return function()
          options = mix.carOptions({rearSteering = true, rearMode = options.rearMode,
            rearPercent = options.rearPercent + delta, secondEsc = options.secondEsc})
          go("amount")
        end
      end
      return scr:row(function() go("rear") end, {
        {text = "-", weight = 0.5, disabled = options.rearPercent <= mix.REAR_PERCENT_MIN, press = nudge(-AMOUNT_STEP)},
        {text = "+", weight = 0.5, disabled = options.rearPercent >= mix.REAR_PERCENT_MAX, press = nudge(AMOUNT_STEP)},
      }, {text = "@i18n(app.modules.setup_wizard.btn_next)@", press = function() go("second") end})

    elseif screen == "second" then
      local layout = preview()
      scr:text(T.car, T.secondQ, nil, true)
      scr:picture(layout)
      local function second(on)
        return function()
          options = mix.carOptions({rearSteering = options.rearSteering, rearMode = options.rearMode,
            rearPercent = options.rearPercent, secondEsc = on})
          go("review")
        end
      end
      return question(options.rearSteering and "amount" or "rear", {
        {text = T.no, primary = not options.secondEsc, press = second(false)},
        {text = T.yes, primary = options.secondEsc, press = second(true)},
      })

    elseif screen == "review" then
      local layout, rules = preview()
      local used = mix.servosUsed(rules)
      local warn
      if used > wiz.servoCount() then warn = string.format(T.tooFew, used, wiz.servoCount()) end
      scr:text(T.car, string.format(T.review, describe(wiz, rules)), warn, true)
      scr:picture(layout)
      return scr:row(function() go("second") end, nil, {text = T.apply, press = function()
        wiz.setMix(mix.ruleTable(options), mix.MODEL_TYPE_CAR)
        wiz.ensureSignedThrottle()
        go("applied")
      end})
    end

    -- applied
    scr:text(T.title, T.applied .. " " .. describe(wiz, wiz.rules()))
    scr:picture(art.layout(wiz.surfaces(), nil))
    return scr:row(function() go("review") end)
  end

  function self.paint() scr:paint() end
  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}
