-- Setup -> ESC & Motors -> Drive: the drive state settings
-- (MSP2_GRIPORA_DRIVE_CONFIG, lib/msp_drive_config.lua), as on
-- gripora-configurator's Drive panel (Motors tab): how the ESC treats a
-- command below neutral, the driven tyre diameter, and how the steering gyro
-- fades in with speed and works in reverse. Not profile-scoped; the firmware
-- reads these live, so saving needs no reboot. The firmware refuses the whole
-- write when a value is out of range or the full-on speed is not above the
-- start speed; the page then shows the usual save error. Firmware without the
-- message refuses the read, which the runtime shows as a failed load.
--
-- The gear ratio the Configurator shows beside the tyre diameter is part of the
-- motor config (MSP_MOTOR_CONFIG), edited on the RPM page.

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local driveConfig = requireModule("lib/msp_drive_config.lua")

local PAGE_TITLE = "@i18n(app.modules.drive.name)@"

-- driveEscMode_e order (lib/msp_drive_config.lua ESC_MODES).
local ESC_MODE_CHOICES = {
  {"@i18n(app.modules.drive.esc_auto)@", 0},
  {"@i18n(app.modules.drive.esc_fwd_brk_rev)@", 1},
  {"@i18n(app.modules.drive.esc_fwd_rev)@", 2},
  {"@i18n(app.modules.drive.esc_fwd_brk)@", 3},
}
local OFF_ON = {
  {"@i18n(app.modules.drive.off)@", 0},
  {"@i18n(app.modules.drive.on)@", 1},
}
-- Speeds are 0.1 km/h on the wire: shown with one decimal.
local SPEED = {decimals = 1, scale = 10, suffix = "km/h"}

local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "drive",
    mspModule = driveConfig,
    isMspPage = true,
    opts = opts,
    profileField = "none",
    unloadPackageKeys = {"grsuite.lib.msp_drive_config"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive.esc_mode)@", {key = "esc_mode", choices = ESC_MODE_CHOICES})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive.wheel_diameter)@", {key = "wheel_diameter"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive.gyro_min_speed)@",
    {key = "gyro_min_speed", decimals = SPEED.decimals, scale = SPEED.scale, suffix = SPEED.suffix})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive.gyro_full_speed)@",
    {key = "gyro_full_speed", decimals = SPEED.decimals, scale = SPEED.scale, suffix = SPEED.suffix})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive.gyro_reverse)@", {key = "gyro_reverse", choices = OFF_ON})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive.gyro_reverse_gain)@", {key = "gyro_reverse_gain"})

  runtime:loadInitial()
end

return {open = open}
