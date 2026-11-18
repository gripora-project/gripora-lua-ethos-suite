-- Tuning -> Traction (Drive Aids group): the timed traction control of the
-- current PID profile, the Traction Control section of gripora-configurator's
-- Drive aids panel. Same MSP message and codec as app/pages/drive_aids_abs.lua
-- (MSP2_GRIPORA_DRIVE_AIDS_CONFIG, lib/msp_drive_aids_config.lua); this page
-- builds only the two TC fields, and the codec writes the ABS and launch
-- control (app/pages/drive_aids_lc.lua) fields back as read. Per PID profile,
-- like ABS: the header shows "Traction Control #<profile>" and the page
-- reloads when the profile changes. No reboot.
--
-- Greyed out: the ramp time unless Mode is Ramp, and both fields on firmware
-- whose reply has no traction control (has_tc false; the save then sends the
-- nine ABS bytes only). The check runs from the wakeup tick but only touches
-- the fields when that changes (see syncEnabled()).

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local driveAidsConfig = requireModule("lib/msp_drive_aids_config.lua")

local PAGE_TITLE = "@i18n(app.modules.drive_aids.tc_name)@"
local TC_MODE_RAMP = driveAidsConfig.TC_MODE_RAMP

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
    local hasTc = data.has_tc == true
    local ramp = hasTc and data.tc_mode == TC_MODE_RAMP
    -- One number for both flags, so the unchanged case allocates nothing.
    local state = (hasTc and 1 or 0) + (ramp and 2 or 0)
    if state == lastState then return end
    lastState = state
    setEnabled(rt, "tc_mode", hasTc)
    setEnabled(rt, "tc_ramp_time", ramp)
  end

  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "drive_aids_tc",
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

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.tc_mode)@", {
    key = "tc_mode",
    choices = driveAidsConfig.TC_MODE_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.tc_ramp_time)@", {key = "tc_ramp_time"})

  runtime:loadInitial()
end

return {open = open}
