-- Setup Wizard step: Steering direction. Opened by app/pages/setup_wizard.lua.
--
-- Checks that the steering turns the right way. It asks the same question
-- as the Configurator's src/tabs/setup_wizard/StepDirection.svelte and fixes
-- things by the same rules, but as a guided sequence for a radio screen: one
-- question per screen, a picture of the car seen from above
-- (app/setup_wizard_art.lua) with the wheels turned the way they should go,
-- and two big answer buttons. The wizard moves the steering itself: it flicks
-- it between centre and the test movement, so the direction is easy to see.
-- Only steering (stabilized yaw) is checked on a car.
--
-- Screens:
--   intro    what is about to happen, Start
--   check    one axis: picture, "Like this" / "Not like this"
--   all      several surfaces and one was wrong: all of them, or only some?
--   identify only some: each surface's servo wiggles in turn, "this one?"
--   done     what the wizard changed; check again, or save and go on
--
-- The fixes, as in the Configurator: a wrong servo has its servo reversed;
-- when every steering servo is wrong the steering is inverted (its Axis
-- Throw negated). After a fix the same check runs again.
--
-- Yaw + is a left turn, since RC yaw is negated once in the firmware's
-- setpoint.c, so steering right is -1.

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local surfacesLib = requireModule("lib/setup_wizard_surfaces.lua")
local art = requireModule("app/setup_wizard_art.lua")
local ui = requireModule("app/setup_wizard_ui.lua")

local CHECKS = {
  {axis = "yaw", sign = -1,
    title = "@i18n(app.modules.setup_wizard.dir_check_yaw)@",
    expect = "@i18n(app.modules.setup_wizard.dir_expect_yaw)@"},
}

local AXIS_NAMES = {
  yaw = "@i18n(app.modules.setup_wizard.dir_axis_yaw)@",
}

local FROM_ABOVE = "@i18n(app.modules.setup_wizard.dir_from_above)@"

-- Test movement, percent of full steering: the Move button steps through
-- these (the configurator's Small, Medium, Large and Half stick).
local DEFLECTIONS = {25, 35, 50, 15}

-- The checked axis flicks between centre and the test movement.
local FLICK_INTERVAL = 0.8
-- Identify: the servo wiggles +-WIGGLE_RAW around its centre.
local WIGGLE_RAW = 300
local WIGGLE_INTERVAL = 0.3

-- Whether this check moves the servo.
local function movedBy(surface, check)
  return surface.axes[check.axis] ~= nil
end

local function servoList(list)
  local names = {}
  for i = 1, #list do names[i] = tostring(list[i].servo + 1) end
  return table.concat(names, ", ")
end

local function new(wiz)
  local self = {}

  local checks = {}
  do
    local surfaces = wiz.surfaces()
    for i = 1, #CHECKS do
      for j = 1, #surfaces do
        if movedBy(surfaces[j], CHECKS[i]) then
          checks[#checks + 1] = CHECKS[i]
          break
        end
      end
    end
  end

  local screen = "intro"
  local ci = 1                 -- index into checks
  local deflectionIndex = 1
  local status = nil           -- line shown on the check screen after a fix
  local moved = {}             -- surfaces the current check moves
  local identifyIndex, wrongOnes = 1, {}
  local reversed = {}          -- servo -> true when reversed an odd number of times
  local inverted = {}          -- axis -> true when inverted an odd number of times

  local scr = ui.new(wiz)

  -- Motion: "axis" flicks the checked axis, "servo" wiggles one servo.
  local motion, motionServo, phase, nextMoveAt = nil, nil, false, 0

  local function check() return checks[ci] end

  local function stopMotion()
    if motion == "servo" and motionServo then wiz.releaseServo(motionServo) end
    if motion == "axis" then wiz.releaseAxes() end
    motion, motionServo = nil, nil
  end

  local function startAxisMotion()
    stopMotion()
    -- Every other axis at centre, so a mix does not hide the one being
    -- checked; then only the checked one moves.
    if wiz.holdAxes({roll = 0, pitch = 0, yaw = 0}) then
      motion, phase, nextMoveAt = "axis", false, 0
    end
  end

  local function startServoMotion(servo)
    stopMotion()
    motion, motionServo, phase, nextMoveAt = "servo", servo, false, 0
  end

  local function collectMoved()
    moved = {}
    local surfaces = wiz.surfaces()
    for i = 1, #surfaces do
      if movedBy(surfaces[i], check()) then moved[#moved + 1] = surfaces[i] end
    end
  end

  local function reverse(surface)
    wiz.editServo(surface.servo, function(config)
      config.flags = (config.flags or 0) ~ surfacesLib.SERVO_FLAG_REVERSE
    end)
    reversed[surface.servo] = not reversed[surface.servo] or nil
  end

  local function go(name)
    screen = name
    wiz.rebuild()
  end

  local function nextCheck()
    status = nil
    if ci < #checks then
      ci = ci + 1
      go("check")
    else
      go("done")
    end
  end

  -- Reverse the wrong ones, then check again.
  local function fix(list)
    for i = 1, #list do reverse(list[i]) end
    if #list > 0 then
      status = string.format("@i18n(app.modules.setup_wizard.dir_status_reversed_fmt)@", servoList(list))
    else
      status = "@i18n(app.modules.setup_wizard.dir_status_none)@"
    end
    go("check")
  end

  local function allWrong()
    wiz.invertAxis(check().axis)
    inverted[check().axis] = not inverted[check().axis] or nil
    status = "@i18n(app.modules.setup_wizard.dir_status_inverted)@"
    go("check")
  end

  local function answerIdentify(wrong)
    if wrong then wrongOnes[#wrongOnes + 1] = moved[identifyIndex] end
    if identifyIndex < #moved then
      identifyIndex = identifyIndex + 1
      go("identify")
    else
      fix(wrongOnes)
    end
  end

  local function notLikeThis()
    if #moved == 1 then
      fix(moved)
    else
      go("all")
    end
  end

  local function deflection() return DEFLECTIONS[deflectionIndex] end

  -- Returns the field to focus.
  function self.build()
    scr:begin()
    local c = check()
    local focus

    -- The answer screens: Back to the check before; the answers are the way
    -- forward.
    local function backFromCheck()
      status = nil
      if ci > 1 then
        ci = ci - 1
        go("check")
      else
        go("intro")
      end
    end

    if screen == "intro" then
      stopMotion()
      scr:text("@i18n(app.modules.setup_wizard.dir_intro_title)@", "@i18n(app.modules.setup_wizard.dir_intro)@")
      scr:picture(art.layout(wiz.surfaces(), nil))
      focus = scr:row(nil, {
        {text = "@i18n(app.modules.setup_wizard.dir_start)@", primary = true, needsMotion = true,
          press = function() ci = 1; go("check") end},
      })

    elseif screen == "check" then
      collectMoved()
      startAxisMotion()
      scr:text(c.title, c.expect .. " " .. "@i18n(app.modules.setup_wizard.dir_q_match)@", status,
        string.format("@i18n(app.modules.setup_wizard.progress_fmt)@", ci, #checks))
      scr:picture(art.layout(wiz.surfaces(), c.axis), FROM_ABOVE)
      focus = scr:row(backFromCheck, {
        {text = string.format("@i18n(app.modules.setup_wizard.dir_move_fmt)@", deflection()), weight = 0.6,
          small = true, needsMotion = true,
          press = function()
            deflectionIndex = deflectionIndex % #DEFLECTIONS + 1
            go("check")
          end},
        {text = "@i18n(app.modules.setup_wizard.dir_unlike)@", needsMotion = true, press = notLikeThis},
        {text = "@i18n(app.modules.setup_wizard.dir_like)@", primary = true, needsMotion = true, press = nextCheck},
      }, false)

    elseif screen == "all" then
      scr:text(c.title, "@i18n(app.modules.setup_wizard.dir_q_all)@", nil, true)
      scr:picture(art.layout(wiz.surfaces(), c.axis), FROM_ABOVE)
      focus = scr:row(function() go("check") end, {
        {text = "@i18n(app.modules.setup_wizard.dir_some)@", press = function()
          identifyIndex, wrongOnes = 1, {}
          go("identify")
        end},
        {text = "@i18n(app.modules.setup_wizard.dir_all)@", primary = true, press = allWrong},
      }, false)

    elseif screen == "identify" then
      local surface = moved[identifyIndex]
      startServoMotion(surface.servo)
      scr:text(c.title, string.format("@i18n(app.modules.setup_wizard.dir_identify_fmt)@", surface.servo + 1,
        wiz.kindName(surface.kind), identifyIndex, #moved), nil, true)
      scr:picture(art.layout(wiz.surfaces(), c.axis), FROM_ABOVE)
      focus = scr:row(function() go("check") end, {
        -- Focus starts on No: a stray press must not reverse a servo.
        {text = "@i18n(app.modules.setup_wizard.dir_no)@", primary = true, needsMotion = true,
          press = function() answerIdentify(false) end},
        {text = "@i18n(app.modules.setup_wizard.dir_yes)@", needsMotion = true,
          press = function() answerIdentify(true) end},
      }, false)

    else -- done
      stopMotion()
      local changes = {}
      for servo in pairs(reversed) do
        changes[#changes + 1] = string.format("@i18n(app.modules.setup_wizard.dir_change_servo_fmt)@", servo + 1)
      end
      table.sort(changes)
      for i = 1, #checks do
        local axis = checks[i].axis
        if inverted[axis] then
          changes[#changes + 1] = string.format("@i18n(app.modules.setup_wizard.dir_change_axis_fmt)@",
            AXIS_NAMES[axis])
        end
      end
      local body
      if #changes == 0 then
        body = "@i18n(app.modules.setup_wizard.dir_done_ok)@"
      else
        body = "@i18n(app.modules.setup_wizard.dir_done_changes)@ " .. table.concat(changes, ", ") .. "."
      end
      scr:text("@i18n(app.modules.setup_wizard.dir_done_title)@", body)
      scr:picture(art.layout(wiz.surfaces(), nil))
      focus = scr:row(function() ci, status = math.max(1, #checks), nil; go("check") end, {
        {text = "@i18n(app.modules.setup_wizard.dir_again)@", press = function()
          ci, status = 1, nil
          go("check")
        end},
      })
    end

    return focus
  end

  function self.paint() scr:paint() end

  local lastCanMove = nil

  function self.wakeup(now)
    local canMove = wiz.canMove()
    if canMove ~= lastCanMove then
      lastCanMove = canMove
      scr:refresh()
      if canMove and screen == "check" and motion == nil then startAxisMotion() end
      if canMove and screen == "identify" and motion == nil then startServoMotion(moved[identifyIndex].servo) end
    end
    if not motion or now < nextMoveAt then return end
    phase = not phase
    if motion == "axis" then
      local c = check()
      local ok = wiz.holdAxis(c.axis, phase and c.sign * deflection() / 100 or 0)
      nextMoveAt = now + FLICK_INTERVAL
      if not ok then motion = nil end
    else
      local ok = wiz.holdServo(motionServo, phase and WIGGLE_RAW or -WIGGLE_RAW)
      nextMoveAt = now + WIGGLE_INTERVAL
      if not ok then motion = nil end
    end
  end

  -- The shell let go of everything (armed, link lost, refused).
  function self.released()
    motion, motionServo = nil, nil
    scr:refresh()
  end

  function self.leave()
    stopMotion()
  end

  return self
end

return {new = new}
