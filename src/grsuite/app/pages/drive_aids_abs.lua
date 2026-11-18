-- Tuning -> Drive Aids: the drive aids of the current PID profile, ABS and
-- traction control (MSP2_GRIPORA_DRIVE_AIDS_CONFIG, lib/msp_drive_aids_config.lua),
-- with an "ABS" and a "Traction Control" section, as gripora-configurator's
-- Drive aids panel and the EdgeTX suite's Drive Aids page have. (The file name
-- is kept from when the page was ABS only.) Firmware without the message
-- refuses the read, which the runtime shows as a failed load. The firmware
-- reads these settings live, so saving needs no reboot.
--
-- The settings are stored per PID profile and the MSP message reads and writes
-- the current one, so the page uses page_runtime's default profile scope
-- (profileField "pidProfile"): the header shows "Drive Aids #<profile>" and
-- the page reloads when the profile changes.
--
-- Greyed-out fields: the two DYNAMIC-only ABS fields unless ABS Mode is
-- Dynamic, the ramp time unless TC Mode is Ramp, and both TC fields on
-- firmware whose reply has no traction control (has_tc false; the save then
-- sends the nine ABS bytes only). The check runs from the wakeup tick but only
-- touches the fields when that state changes (see syncEnabled()).

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local driveAidsConfig = requireModule("lib/msp_drive_aids_config.lua")

local PAGE_TITLE = "@i18n(app.modules.drive_aids.name)@"
local ABS_MODE_DYNAMIC = driveAidsConfig.ABS_MODE_DYNAMIC
local TC_MODE_RAMP = driveAidsConfig.TC_MODE_RAMP
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
    local hasTc = data.has_tc == true
    local ramp = hasTc and data.tc_mode == TC_MODE_RAMP
    -- One number for the three flags, so the unchanged case allocates nothing.
    local state = (dynamic and 1 or 0) + (hasTc and 2 or 0) + (ramp and 4 or 0)
    if state == lastState then return end
    lastState = state
    for i = 1, #DYNAMIC_KEYS do setEnabled(rt, DYNAMIC_KEYS[i], dynamic) end
    setEnabled(rt, "tc_mode", hasTc)
    setEnabled(rt, "tc_ramp_time", ramp)
  end

  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "drive_aids",
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

  form.addLine("@i18n(app.modules.drive_aids.abs_name)@")
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

  form.addLine("@i18n(app.modules.drive_aids.tc_name)@")
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.tc_mode)@", {
    key = "tc_mode",
    choices = driveAidsConfig.TC_MODE_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.tc_ramp_time)@", {key = "tc_ramp_time"})

  runtime:loadInitial()
end

return {open = open}
