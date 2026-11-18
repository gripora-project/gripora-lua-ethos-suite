-- Setup Wizard step: Gyro direction. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of gripora-configurator's StepGyro.svelte. No
-- overrides: the stabilizer drives the steering (the PID runs while
-- disarmed too). Only yaw is stabilised (yaw-rate gyro steering), so yaw is
-- the only check: with the wheels off the ground, turn the car by hand around
-- its vertical axis, and the steering should push against the movement.
--
-- A wrong answer, with the steering direction already right (Direction
-- step), means the gyro reads the car's turning backwards for this mounting.
-- yaw_gyro_reverse (firmware pidConfig_t, sent with MSP_SET_MIXER_CONFIG from
-- API 33.0) negates the yaw rate the steering loop uses and nothing else; it
-- works at once, so the check is simply done again, and Save writes it.
-- Servo reverse or the steering invert would also reverse the stick, so
-- neither can fix this. Firmware without yaw_gyro_reverse gets the
-- update-the-firmware note.
--
-- Drive state (MSP2_GRIPORA_DRIVE_CONFIG/STATUS, lib/msp_drive_config.lua):
-- reverse needs no setup, the firmware turns the gyro correction round
-- while the car drives backwards. With motor RPM the correction is faded
-- out below gyro_min_speed, so at a standstill turning the car by hand moves
-- nothing: the step says so, or the check reads as wrong. Firmware without
-- drive state leaves both notes out.

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local ui = requireModule("app/setup_wizard_ui.lua")
-- Freed when the step closes (app/setup_wizard_ui.lua's notLoaded()).
local OWNED = ui.notLoaded({"grsuite.lib.msp_drive_config", "grsuite.lib.msp_drive_status"})
local art = requireModule("app/setup_wizard_art.lua")
local mixerConfig = requireModule("lib/msp_mixer_config.lua")
local driveConfig = requireModule("lib/msp_drive_config.lua")
local driveStatus = requireModule("lib/msp_drive_status.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.gyr_title)@",
  intro = "@i18n(app.modules.setup_wizard.gyr_intro)@",
  reverseAuto = "@i18n(app.modules.setup_wizard.gyr_reverse_auto)@",
  standstill = "@i18n(app.modules.setup_wizard.gyr_standstill_fmt)@",
  check = "@i18n(app.modules.setup_wizard.gyr_yaw)@",
  steering = "@i18n(app.modules.setup_wizard.axis_steering)@",
  q = "@i18n(app.modules.setup_wizard.dir_q_match)@",
  wrong = "@i18n(app.modules.setup_wizard.gyr_wrong)@",
  wrongOld = "@i18n(app.modules.setup_wizard.gyr_wrong_old)@",
  reverseOn = "@i18n(app.modules.setup_wizard.gyr_reverse_on)@",
  reverseOff = "@i18n(app.modules.setup_wizard.gyr_reverse_off)@",
  reversedNow = "@i18n(app.modules.setup_wizard.gyr_reversed_now)@",
  normalNow = "@i18n(app.modules.setup_wizard.gyr_normal_now)@",
  checkAgain = "@i18n(app.modules.setup_wizard.gyr_check_again)@",
  doneTitle = "@i18n(app.modules.setup_wizard.gyr_done_title)@",
  done = "@i18n(app.modules.setup_wizard.gyr_done)@",
  start = "@i18n(app.modules.setup_wizard.btn_start)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  like = "@i18n(app.modules.setup_wizard.dir_like)@",
  unlike = "@i18n(app.modules.setup_wizard.dir_unlike)@",
  again = "@i18n(app.modules.setup_wizard.btn_again)@",
  fromAbove = "@i18n(app.modules.setup_wizard.dir_from_above)@",
}

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)
  local hasYaw = false
  for _, s in ipairs(wiz.surfaces()) do
    if s.axes.yaw then hasYaw = true; break end
  end

  local screen = "intro"
  local toggled = false          -- reversed or put back on this visit
  local driveSupported = false
  local standstillNote = nil     -- built once from the drive config and status

  wiz.fetch({
    config = function(ok, err) return driveConfig.buildReadMessage(ok, err) end,
    status = function(ok, err) return driveStatus.buildReadMessage(ok, err) end,
  }, function(results)
    driveSupported = results.config ~= nil
    local st = results.status
    if driveSupported and st and st.speed_known and st.correction == 0 then
      standstillNote = string.format(T.standstill, (results.config.gyro_min_speed or 0) / 10)
    end
    wiz.rebuild()
  end)

  local function canReverse()
    local cfg = wiz.mixConfig()
    return cfg ~= nil and cfg.yaw_gyro_reverse ~= nil and cfg.servo_pwm_rate ~= nil
  end

  local function reversed()
    local cfg = wiz.mixConfig()
    return cfg ~= nil and (cfg.yaw_gyro_reverse or 0) ~= 0
  end

  local function send(cfg)
    bus.publish("msp.request", mixerConfig.buildWriteMessage(cfg))
  end

  local function toggleReverse()
    local cfg = wiz.mixConfig()
    if not canReverse() then return end
    wiz.change("yaw_gyro_reverse", cfg.yaw_gyro_reverse, function(o)
      cfg.yaw_gyro_reverse = o
      send(cfg)
    end)
    cfg.yaw_gyro_reverse = reversed() and 0 or 1
    send(cfg)
    toggled = true
    wiz.rebuild()
  end

  local function go(name)
    screen = name
    wiz.rebuild()
  end

  local function introText()
    if driveSupported then return T.intro .. " " .. T.reverseAuto end
    return T.intro
  end

  function self.build()
    scr:begin()
    if screen == "intro" then
      scr:text(T.title, introText(), standstillNote)
      scr:picture(art.layout(wiz.surfaces(), nil))
      return scr:row(nil, {
        {text = T.start, primary = true, press = function() go(hasYaw and "check" or "done") end},
      })

    elseif screen == "check" then
      local now = canReverse() and (reversed() and T.reversedNow or T.normalNow) or nil
      scr:text(T.steering, T.check .. " " .. T.q, toggled and T.checkAgain or (standstillNote or now), true)
      scr:picture(art.layout(wiz.surfaces(), "yaw", true), T.fromAbove)
      return scr:row(function() go("intro") end, {
        {text = T.unlike, press = function() go("wrong") end},
        {text = T.like, primary = true, press = function() go("done") end},
      }, false)

    elseif screen == "wrong" then
      if not canReverse() then
        scr:text(T.steering, T.wrongOld, nil, true)
        return scr:row(function() go("check") end, nil, {text = T.next, press = function() go("done") end})
      end
      scr:text(T.steering, T.wrong, reversed() and T.reversedNow or T.normalNow, true)
      return scr:row(function() go("check") end, {
        {text = reversed() and T.reverseOff or T.reverseOn, primary = true, press = function()
          toggleReverse()
          go("check")
        end},
      }, false)
    end

    scr:text(T.doneTitle, T.done, reversed() and T.reversedNow or nil)
    scr:picture(art.layout(wiz.surfaces(), nil))
    return scr:row(function() go(hasYaw and "check" or "intro") end, {
      {text = T.again, press = function() go(hasYaw and "check" or "intro") end},
    })
  end

  function self.paint() scr:paint() end

  local lastCanMove = nil
  function self.wakeup()
    local canMove = wiz.canMove()
    if canMove ~= lastCanMove then
      lastCanMove = canMove
      scr:refresh()
    end
  end

  function self.released() scr:refresh() end

  return self
end

return {new = new, owned = OWNED}
