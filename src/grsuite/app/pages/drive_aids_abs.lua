-- Flight Tuning -> Drive Aids -> ABS: the ABS settings of the drive aids
-- (MSP2_GRIPORA_DRIVE_AIDS_CONFIG, lib/msp_drive_aids_config.lua). Firmware
-- without the message refuses the read, which the runtime shows as a failed
-- load. The firmware reads these settings live, so saving needs no reboot.
--
-- The settings are stored per PID profile and the MSP message reads and writes
-- the current one, so the page uses page_runtime's default profile scope
-- (profileField "pidProfile"): the header shows "ABS #<profile>" and the page
-- reloads when the profile changes.
--
-- The two DYNAMIC-only fields are greyed out unless Mode is Dynamic. The
-- check runs from the wakeup tick but only touches the fields when the mode
-- actually changes (see syncDynamic()).

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local driveAidsConfig = requireModule("lib/msp_drive_aids_config.lua")

local PAGE_TITLE = "@i18n(app.modules.drive_aids.abs_name)@"
local ABS_MODE_DYNAMIC = driveAidsConfig.ABS_MODE_DYNAMIC
local DYNAMIC_KEYS = {"abs_dyn_freq", "abs_dyn_hold"}

local function open(opts)
  local runtime
  -- nil = not applied since the last load, so the next loaded tick applies it.
  local lastDynamic = nil

  local function syncDynamic(rt)
    if not rt.loaded then
      lastDynamic = nil
      return
    end
    local dynamic = rt.data.abs_mode == ABS_MODE_DYNAMIC
    if dynamic == lastDynamic then return end
    lastDynamic = dynamic
    for i = 1, #DYNAMIC_KEYS do
      local field = rt.fields[DYNAMIC_KEYS[i]]
      if field then field:enable(dynamic) end
    end
  end

  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "drive_aids_abs",
    mspModule = driveAidsConfig,
    isMspPage = true,
    opts = opts,
    unloadPackageKeys = {"grsuite.lib.msp_drive_aids_config"},
    -- A load enables every field; re-apply the Dynamic greying on top.
    onLoaded = function()
      lastDynamic = nil
      syncDynamic(runtime)
    end,
    onWakeup = syncDynamic,
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.abs_mode)@", {
    key = "abs_mode",
    choices = driveAidsConfig.ABS_MODE_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.abs_trigger)@", {key = "abs_trigger"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.abs_freq)@", {key = "abs_freq"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.abs_floor)@", {key = "abs_floor"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.abs_hold)@", {key = "abs_hold"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.abs_dyn_freq)@", {key = "abs_dyn_freq"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.abs_dyn_hold)@", {key = "abs_dyn_hold"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.abs_corner_freq)@", {key = "abs_corner_freq"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.abs_corner_hold)@", {key = "abs_corner_hold"})

  runtime:loadInitial()
end

return {open = open}
