-- Setup Wizard step: ESC. Opened by app/pages/setup_wizard.lua.
--
-- The radio's copy of gripora-configurator's StepMotor.svelte for a car:
--
--   protocol  Standard PWM, DShot150 or DShot300, or any other protocol
--             (No motor, DShot600, OneShot, ...) from the Other drop-down.
--             DShot150 has no bidirectional DShot RPM telemetry, so
--             choosing it also turns bidirectional DShot off in the same
--             write (an ESC that doesn't answer may not arm), and while it
--             is set the step says RPM needs DShot300 or a telemetry source.
--             A change applies after a restart, so it ends with Save and
--             restart. That a restart is needed is kept by the shell
--             (wiz.needRestart()): the ESC is not checked on a protocol that
--             is not in use yet, also after the step is closed and opened
--             again.
--   escmode   how the ESC reverses (drive_esc_mode, MSP2_GRIPORA_DRIVE_CONFIG,
--             lib/msp_drive_config.lua), so the controller knows when the car
--             is reversing. Firmware without drive state skips the screen.
--             Sent straight away; no restart needed.
--   wheels    the car's wheels must be off the ground before anything runs
--   neutral   the throttle stick at centre must be neutral at the ESC: the
--             controller sends neutral as the middle of the throttle range,
--             (minthrottle + maxthrottle) / 2, so the ESC is calibrated to
--             that. A live reading of the throttle channel against rc_center.
--   spin      one motor at a time, forward or reverse, so two ESCs show which
--             is which and each one's direction can be checked: pick the
--             motor (only with more than one) and 5, 10 or 20 %, and Forward
--             or Reverse runs it for SPIN_SECONDS and stops by itself; Stop
--             ends it early.
--
-- The motor output, from the firmware (flight/motors.c and motors.h): an
-- override is -1000..1000 (signed: the car's ESC is reversible, 0 is neutral
-- and below it is brake/reverse). It is dropped a second after the last write
-- (MOTOR_OVERRIDE_TIMEOUT) and ignored while armed, so the step re-sends it
-- every quarter second, as app/pages/motor_override.lua does, and a lost link
-- stops the motor. Stop, Back, the step list, Save, leaving the step, arming
-- and a lost link all write zero to every motor.
--
-- The configurator runs while a button is held; a radio button can't be
-- held, so here a press runs for a few seconds.

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local bus = requireModule("lib/bus.lua")
local ui = requireModule("app/setup_wizard_ui.lua")
-- Freed when the step closes (app/setup_wizard_ui.lua's notLoaded()).
local OWNED = ui.notLoaded({"grsuite.lib.msp_motor_config", "grsuite.lib.msp_motor_override",
  "grsuite.lib.msp_drive_config", "grsuite.lib.msp_drive_status", "grsuite.lib.msp_rc_config"})
local motorConfig = requireModule("lib/msp_motor_config.lua")
local motorOverride = requireModule("lib/msp_motor_override.lua")
local driveConfig = requireModule("lib/msp_drive_config.lua")
local driveStatus = requireModule("lib/msp_drive_status.lua")
local rcConfig = requireModule("lib/msp_rc_config.lua")

local T = {
  title = "@i18n(app.modules.setup_wizard.mot_title)@",
  intro = "@i18n(app.modules.setup_wizard.mot_intro)@",
  other = "@i18n(app.modules.setup_wizard.mot_other)@",
  otherHelp = "@i18n(app.modules.setup_wizard.mot_other_help)@",
  changed = "@i18n(app.modules.setup_wizard.mot_changed)@",
  noRpm = "@i18n(app.modules.setup_wizard.mot_dshot150_rpm)@",
  escModeTitle = "@i18n(app.modules.setup_wizard.mot_esc_mode_title)@",
  escModeTell = "@i18n(app.modules.setup_wizard.mot_esc_mode_tell)@",
  escModeNow = "@i18n(app.modules.setup_wizard.mot_esc_mode_now_fmt)@",
  noRpmNote = "@i18n(app.modules.setup_wizard.mot_no_rpm_note)@",
  wheelsTitle = "@i18n(app.modules.setup_wizard.mot_wheels_title)@",
  wheelsText = "@i18n(app.modules.setup_wizard.mot_wheels_text)@",
  wheelsOff = "@i18n(app.modules.setup_wizard.mot_wheels_off)@",
  neutralTitle = "@i18n(app.modules.setup_wizard.mot_neutral_title)@",
  neutralIntro = "@i18n(app.modules.setup_wizard.mot_neutral_intro_fmt)@",
  neutralReading = "@i18n(app.modules.setup_wizard.mot_neutral_reading_fmt)@",
  neutralNoSignal = "@i18n(app.modules.setup_wizard.mot_neutral_no_signal)@",
  neutralCentred = "@i18n(app.modules.setup_wizard.mot_neutral_centred)@",
  neutralCheck = "@i18n(app.modules.setup_wizard.mot_neutral_check)@",
  stick = "@i18n(app.modules.setup_wizard.mot_neutral_stick)@",
  spinTitle = "@i18n(app.modules.setup_wizard.mot_spin_title)@",
  spinText = "@i18n(app.modules.setup_wizard.mot_spin_text)@",
  spinTwin = "@i18n(app.modules.setup_wizard.mot_spin_twin)@",
  motor = "@i18n(app.modules.setup_wizard.mot_motor_fmt)@",
  next = "@i18n(app.modules.setup_wizard.btn_next)@",
  spinning = "@i18n(app.modules.setup_wizard.mot_spinning)@",
  forward = "@i18n(app.modules.setup_wizard.mot_forward)@",
  reverse = "@i18n(app.modules.setup_wizard.mot_reverse)@",
  stop = "@i18n(app.modules.setup_wizard.mot_stop)@",
  test = "@i18n(app.modules.setup_wizard.mot_test)@",
  noMotor = "@i18n(app.modules.setup_wizard.mot_no_outputs)@",
  saveRestart = "@i18n(app.modules.setup_wizard.btn_save_restart)@",
}

-- Both notes at once, built once: the restart note and DShot150's RPM note.
T.changedNoRpm = T.changed .. " " .. T.noRpm

-- DShot150 never carries bidirectional DShot RPM telemetry.
local DSHOT150 = 5
-- DShot150, 300, 600 and ProShot (firmware checkMotorProtocolDshot()): what
-- drive_esc_mode AUTO treats as DShot.
local DSHOT_FIRST, DSHOT_LAST = 5, 8

local CHOICES = {
  {protocol = 0, name = "@i18n(app.modules.setup_wizard.mot_pwm)@",
    help = "@i18n(app.modules.setup_wizard.mot_pwm_help)@"},
  {protocol = DSHOT150, name = "@i18n(app.modules.setup_wizard.mot_dshot150)@",
    help = "@i18n(app.modules.setup_wizard.mot_dshot150_help)@"},
  {protocol = 6, name = "@i18n(app.modules.setup_wizard.mot_dshot300)@",
    help = "@i18n(app.modules.setup_wizard.mot_dshot300_help)@"},
}

-- The Other drop-down: every protocol the codec offers that has no row, by
-- name, after an "Other" entry shown while a row's protocol is set.
local OTHER_NONE = -1
local OTHER_NAMES = {
  [1] = "OneShot125",
  [2] = "OneShot42",
  [3] = "MultiShot",
  [7] = "@i18n(app.modules.setup_wizard.mot_dshot600)@",
  [8] = "ProShot1000",
  [motorConfig.CASTLE_PROTOCOL] = "Castle Link",
  [motorConfig.SRXL2_PROTOCOL] = "SRXL2",
  [motorConfig.DISABLED_PROTOCOL] = "@i18n(app.modules.setup_wizard.mot_none)@",
}
local OTHER_VALUES = {{T.other, OTHER_NONE}}
do
  local inRow = {}
  for _, c in ipairs(CHOICES) do inRow[c.protocol] = true end
  for _, entry in ipairs(motorConfig.BASE_PROTOCOL_CHOICES) do
    local protocol = entry[2]
    if not inRow[protocol] then
      OTHER_VALUES[#OTHER_VALUES + 1] = {OTHER_NAMES[protocol] or entry[1], protocol}
    end
  end
end

-- drive_esc_mode, in driveEscMode_e order.
local ESC_MODES = {
  {mode = 0, name = "@i18n(app.modules.setup_wizard.mot_esc_mode_auto)@",
    help = "@i18n(app.modules.setup_wizard.mot_esc_mode_auto_help)@"},
  {mode = 1, name = "@i18n(app.modules.setup_wizard.mot_esc_mode_fwd_brk_rev)@",
    help = "@i18n(app.modules.setup_wizard.mot_esc_mode_fwd_brk_rev_help)@"},
  {mode = 2, name = "@i18n(app.modules.setup_wizard.mot_esc_mode_fwd_rev)@",
    help = "@i18n(app.modules.setup_wizard.mot_esc_mode_fwd_rev_help)@"},
  {mode = 3, name = "@i18n(app.modules.setup_wizard.mot_esc_mode_fwd_brk)@",
    help = "@i18n(app.modules.setup_wizard.mot_esc_mode_fwd_brk_help)@"},
}

local TEST_THROTTLES = {5, 10, 20}
local SPIN_SECONDS = 3
local REFRESH = 0.25
-- Within the usual stick deadband of centre.
local CENTRE_TOLERANCE_US = 25

local function copy(t)
  local out = {}
  for k, v in pairs(t) do out[k] = v end
  return out
end

local function new(wiz)
  local self = {}
  local scr = ui.new(wiz)

  local screen = "protocol"
  local config = nil
  local original = nil
  local drive = nil         -- lib/msp_drive_config.lua's data; nil without drive state
  local speedKnown = true   -- motor 1 has an RPM source (MSP2_GRIPORA_DRIVE_STATUS)
  local rcCenter = 1500

  -- What is driving the motors now: nil or "spin".
  local output = nil
  local outMotor, outValue = 0, 0
  local nextWriteAt = 0

  local spinMotor = 0       -- 0-based, as the wire numbers them
  local spinDirection = 1   -- 1 forward, -1 reverse
  local throttleIndex = 2
  local spinUntil = nil
  local left = false

  -- The neutral screen's reading, rebuilt only when the stick moves.
  local lastThrottle = nil
  local readingRows = nil

  wiz.fetch({
    config = function(ok, err) return motorConfig.buildReadMessage(ok, err) end,
    drive = function(ok, err) return driveConfig.buildReadMessage(ok, err) end,
    status = function(ok, err) return driveStatus.buildReadMessage(ok, err) end,
    rc = function(ok, err) return rcConfig.buildReadMessage(ok, err) end,
  }, function(results)
    config = results.config
    original = config
    drive = results.drive
    if results.status then speedKnown = results.status.speed_known end
    if results.rc and results.rc.rc_center then rcCenter = results.rc.rc_center end
    wiz.rebuild()
  end)

  local function isDshot()
    local p = config and config.motor_pwm_protocol
    return p ~= nil and p >= DSHOT_FIRST and p <= DSHOT_LAST
  end

  -- Motor output.

  local function lastMotor()
    return math.max(wiz.motorCount(), 1) - 1
  end

  local function writeMotors(first, last, value)
    for i = first, last do
      bus.publish("msp.request", motorOverride.buildWriteMessage(i, value))
    end
  end

  -- Zero on every motor, whichever was held.
  local function stopOutput()
    if not output then return end
    output = nil
    spinUntil = nil
    writeMotors(0, lastMotor(), motorOverride.OVERRIDE_OFF)
  end

  local function startSpin(direction)
    if output or wiz.armed() or not wiz.canMove() then return end
    spinDirection = direction
    spinUntil = os.clock() + SPIN_SECONDS
    output, outMotor = "spin", spinMotor
    outValue = direction * math.floor(TEST_THROTTLES[throttleIndex] * motorOverride.OVERRIDE_MAX / 100)
    nextWriteAt = os.clock() + REFRESH
    writeMotors(outMotor, outMotor, outValue)
    wiz.rebuild()
  end

  local function stopSpin()
    if output ~= "spin" then return end
    stopOutput()
    if not left then wiz.rebuild() end
  end

  local function choose(protocol)
    if protocol == nil or protocol == OTHER_NONE or config.motor_pwm_protocol == protocol then return end
    wiz.change("motor_config", original, function(o)
      bus.publish("msp.request", motorConfig.buildWriteMessage(o))
    end)
    local nextConfig = copy(config)
    nextConfig.motor_pwm_protocol = protocol
    -- No bidirectional DShot on DShot150: an ESC that doesn't answer the
    -- telemetry request may not arm, so it goes off in the same write.
    if protocol == DSHOT150 then nextConfig.use_dshot_telemetry = 0 end
    config = nextConfig
    bus.publish("msp.request", motorConfig.buildWriteMessage(config))
    wiz.needRestart()
    wiz.rebuild()
  end

  local function chooseEscMode(mode)
    if not drive or drive.esc_mode == mode then return end
    wiz.change("drive_config", drive, function(o)
      bus.publish("msp.request", driveConfig.buildWriteMessage(o))
    end)
    drive = copy(drive)
    drive.esc_mode = mode
    bus.publish("msp.request", driveConfig.buildWriteMessage(drive))
    wiz.rebuild()
  end

  local function go(name)
    stopOutput()
    screen = name
    if name == "neutral" then lastThrottle, readingRows = nil, nil end
    wiz.rebuild()
  end

  local function throttleUs()
    return wiz.rc[4] or 0
  end

  local function neutralUs()
    return math.floor(((config.minthrottle or 1000) + (config.maxthrottle or 2000)) / 2 + 0.5)
  end

  local function centred(us)
    return us > 0 and math.abs(us - rcCenter) <= CENTRE_TOLERANCE_US
  end

  -- The reading, and "Centred" after it while the stick is at centre.
  local function readingText(us)
    if us <= 0 then return T.neutralNoSignal end
    local text = string.format(T.neutralReading, us, rcCenter)
    if centred(us) then text = text .. "  " .. T.neutralCentred end
    return text
  end

  function self.build()
    scr:begin()
    self.liveRc = nil
    if not config then
      scr:text(T.title, "@i18n(app.msg_loading)@")
      return nil
    end

    if screen == "protocol" then
      local current
      for _, c in ipairs(CHOICES) do
        if c.protocol == config.motor_pwm_protocol then current = c end
      end
      local dshot150 = config.motor_pwm_protocol == DSHOT150
      local note
      if wiz.restartNeeded() then
        note = dshot150 and T.changedNoRpm or T.changed
      elseif wiz.motorCount() == 0 then
        note = T.noMotor
      elseif dshot150 then
        note = T.noRpm
      end
      scr:text(T.title, T.intro, note)
      -- One row per protocol, what it means beside it, the current one lit;
      -- the rest in the Other drop-down, which shows the protocol set when
      -- it is one of them.
      local specs = {}
      for _, c in ipairs(CHOICES) do
        specs[#specs + 1] = {text = c.name, help = c.help, current = current == c,
          press = function() choose(c.protocol) end}
      end
      specs[#specs + 1] = {values = OTHER_VALUES, help = T.otherHelp, current = current == nil,
        get = function() return current and OTHER_NONE or config.motor_pwm_protocol end,
        set = function(value) choose(tonumber(value)) end}
      local disabled = config.motor_pwm_protocol == motorConfig.DISABLED_PROTOCOL
      -- A new protocol needs a restart; the ESC behaviour and the test use
      -- the protocol the motor runs now, so they wait until then.
      -- The list first: the encoder visits fields in the order they are made.
      local focus = scr:choices(specs)
      local forward = scr:row(nil, (not wiz.restartNeeded()) and {
        {text = T.test, disabled = disabled or (wiz.motorCount() == 0 and not drive),
          press = function() go(drive and "escmode" or "wheels") end},
      } or nil, wiz.restartNeeded() and {text = T.saveRestart, press = function() wiz.saveAndReboot() end} or nil)
      return focus or forward

    elseif screen == "escmode" then
      local auto = driveConfig.resolveEscMode(0, isDshot())
      local autoName = ESC_MODES[auto + 1].name
      scr:text(T.escModeTitle, nil, (not speedKnown) and T.noRpmNote or T.escModeTell)
      local specs = {}
      for _, m in ipairs(ESC_MODES) do
        local help = m.help
        if m.mode == 0 then help = help .. " " .. string.format(T.escModeNow, autoName) end
        specs[#specs + 1] = {text = m.name, help = help, current = drive.esc_mode == m.mode,
          press = function() chooseEscMode(m.mode) end}
      end
      local focus = scr:choices(specs)
      local forward = scr:row(function() go("protocol") end, nil, wiz.motorCount() > 0
        and {text = T.next, press = function() go("wheels") end} or nil)
      return focus or forward

    elseif screen == "wheels" then
      scr:text(T.wheelsTitle, T.wheelsText)
      return scr:row(function() go(drive and "escmode" or "protocol") end, nil,
        {text = T.wheelsOff, press = function() go("neutral") end})

    elseif screen == "neutral" then
      self.liveRc = "rc"
      local us = throttleUs()
      lastThrottle = us
      scr:text(T.neutralTitle, string.format(T.neutralIntro, neutralUs()) .. " " .. T.neutralCheck)
      readingRows = {{T.stick, readingText(us), not centred(us)}}
      scr:rows(readingRows)
      return scr:row(function() go("wheels") end, nil, {text = T.next, press = function() go("spin") end})
    end

    -- spin
    local spinning = output == "spin"
    local count = wiz.motorCount()
    if spinMotor >= count then spinMotor = 0 end
    scr:text(T.spinTitle, T.spinText, spinning and T.spinning or (count > 1 and T.spinTwin or nil))
    local specs = {}
    if count > 1 then
      specs[#specs + 1] = {text = string.format(T.motor, spinMotor + 1), weight = 0.8, small = true,
        disabled = spinning, press = function()
          spinMotor = (spinMotor + 1) % count
          wiz.rebuild()
        end}
    end
    specs[#specs + 1] = {text = string.format("%d%%", TEST_THROTTLES[throttleIndex]), weight = 0.55, small = true,
      disabled = spinning, press = function()
        throttleIndex = throttleIndex % #TEST_THROTTLES + 1
        wiz.rebuild()
      end}
    if spinning then
      specs[#specs + 1] = {text = T.stop, primary = true, small = true, press = stopSpin}
    else
      specs[#specs + 1] = {text = T.forward, primary = true, small = true, needsMotion = true,
        press = function() startSpin(1) end}
      specs[#specs + 1] = {text = T.reverse, small = true, needsMotion = true,
        press = function() startSpin(-1) end}
    end
    -- Next waits for the run to end; Back stops it (go() does).
    local forward = wiz.forward(function() go("protocol"); wiz.finishStep() end)
    forward.disabled = spinning
    return scr:row(function() go("neutral") end, specs, forward)
  end

  function self.paint() scr:paint() end

  function self.wakeup(now)
    if screen == "neutral" and readingRows then
      local us = throttleUs()
      -- Only when the stick moved: the reading is a new string each time.
      if us ~= lastThrottle then
        lastThrottle = us
        scr:setRow(1, readingText(us), not centred(us))
        wiz.invalidate()
      end
    end
    if not output then return end
    if not wiz.canMove() then
      -- Armed, or the link is gone: the writes would not arrive anyway.
      stopSpin()
    elseif spinUntil and now >= spinUntil then
      stopSpin()
    elseif now >= nextWriteAt then
      nextWriteAt = now + REFRESH
      writeMotors(outMotor, outMotor, outValue)
    end
  end

  -- The step list, Save and Back: nothing runs behind them.
  function self.pause() stopSpin() end

  function self.released()
    stopSpin()
    scr:refresh()
  end

  function self.leave()
    left = true
    stopSpin()
  end

  return self
end

return {new = new, owned = OWNED}
