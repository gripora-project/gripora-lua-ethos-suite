-- Tuning -> ABS (Drive Aids group): the timed ABS of the current PID profile
-- (MSP2_GRIPORA_DRIVE_AIDS_CONFIG, lib/msp_drive_aids_config.lua), the ABS
-- section of gripora-configurator's Drive aids panel. Traction control, in the
-- same MSP message, is on app/pages/drive_aids_tc.lua; this page does not build
-- its fields, and the codec writes them back as read. Firmware without the
-- message refuses the read, which the runtime shows as a failed load. The
-- firmware reads these settings live, so saving needs no reboot.
--
-- The settings are stored per PID profile and the MSP message reads and writes
-- the current one, so the page uses page_runtime's default profile scope
-- (profileField "pidProfile"): the header shows "ABS #<profile>" and the page
-- reloads when the profile changes.
--
-- Each rate and its hold time share a line (Pulse, Full Brake, At Full Lock).
-- The two Full Brake fields are greyed out unless Mode is Dynamic; the check
-- runs from the wakeup tick but only touches the fields when that changes (see
-- syncEnabled()).

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local driveAidsConfig = requireModule("lib/msp_drive_aids_config.lua")

local PAGE_TITLE = "@i18n(app.modules.drive_aids.abs_name)@"
local ABS_MODE_DYNAMIC = driveAidsConfig.ABS_MODE_DYNAMIC
local DYNAMIC_KEYS = {"abs_dyn_freq", "abs_dyn_hold"}

local function setEnabled(rt, key, enabled)
  local field = rt.fields[key]
  if field then field:enable(enabled) end
end

local function open(opts)
  local runtime
  -- nil = not applied since the last load, so the next loaded tick applies it.
  local lastState = nil

  local function syncEnabled(rt)
    if not rt.loaded then
      lastState = nil
      return
    end
    local data = rt.data
    local dynamic = data.abs_mode == ABS_MODE_DYNAMIC
    if dynamic == lastState then return end
    lastState = dynamic
    for i = 1, #DYNAMIC_KEYS do setEnabled(rt, DYNAMIC_KEYS[i], dynamic) end
  end

  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "drive_aids_abs",
    mspModule = driveAidsConfig,
    isMspPage = true,
    opts = opts,
    unloadPackageKeys = {"grsuite.lib.msp_drive_aids_config"},
    -- A load enables every field; re-apply the greying on top.
    onLoaded = function()
      lastState = nil
      syncEnabled(runtime)
    end,
    onWakeup = syncEnabled,
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.abs_mode)@", {
    key = "abs_mode",
    choices = driveAidsConfig.ABS_MODE_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.abs_trigger)@", {key = "abs_trigger"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.abs_floor)@", {key = "abs_floor"})
  local RATE = "@i18n(app.modules.drive_aids.rate)@"
  local HOLD = "@i18n(app.modules.drive_aids.abs_hold)@"
  fieldLayout.buildGroup(runtime, "@i18n(app.modules.drive_aids.pulse)@", {
    {title = RATE, spec = {key = "abs_freq"}},
    {title = HOLD, spec = {key = "abs_hold"}},
  })
  fieldLayout.buildGroup(runtime, "@i18n(app.modules.drive_aids.full_brake)@", {
    {title = RATE, spec = {key = "abs_dyn_freq"}},
    {title = HOLD, spec = {key = "abs_dyn_hold"}},
  })
  fieldLayout.buildGroup(runtime, "@i18n(app.modules.drive_aids.at_lock)@", {
    {title = RATE, spec = {key = "abs_corner_freq"}},
    {title = HOLD, spec = {key = "abs_corner_hold"}},
  })

  runtime:loadInitial()
end

return {open = open}
