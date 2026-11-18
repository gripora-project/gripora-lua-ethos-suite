-- Tuning -> Launch (Drive Aids group): the launch control of the current PID
-- profile, the Launch Control section of gripora-configurator's Drive aids
-- panel. Same MSP message and codec as app/pages/drive_aids_abs.lua and
-- app/pages/drive_aids_tc.lua (MSP2_GRIPORA_DRIVE_AIDS_CONFIG,
-- lib/msp_drive_aids_config.lua); this page builds only the three LC fields,
-- and the codec writes the ABS and TC fields back as read. Per PID profile:
-- the header shows "Launch Control #<profile>" and the page reloads when the
-- profile changes. No reboot.
--
-- With Mode Switch, the LAUNCH mode (Modes page) stages a launch; the first
-- forward throttle is held to the start throttle and rises to full over the
-- ramp time.
--
-- Greyed out: the start throttle and ramp time unless Mode is Switch, and all
-- three fields on firmware whose reply has no launch control (has_lc false;
-- the save then sends what that firmware sent). The check runs from the wakeup
-- tick but only touches the fields when that changes (see syncEnabled()).

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local driveAidsConfig = requireModule("lib/msp_drive_aids_config.lua")

local PAGE_TITLE = "@i18n(app.modules.drive_aids.lc_name)@"
local LC_MODE_SWITCH = driveAidsConfig.LC_MODE_SWITCH

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
    local hasLc = data.has_lc == true
    local switch = hasLc and data.lc_mode == LC_MODE_SWITCH
    -- One number for both flags, so the unchanged case allocates nothing.
    local state = (hasLc and 1 or 0) + (switch and 2 or 0)
    if state == lastState then return end
    lastState = state
    setEnabled(rt, "lc_mode", hasLc)
    setEnabled(rt, "lc_throttle", switch)
    setEnabled(rt, "lc_ramp_time", switch)
  end

  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "drive_aids_lc",
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

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.lc_mode)@", {
    key = "lc_mode",
    choices = driveAidsConfig.LC_MODE_CHOICES,
  })
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.lc_throttle)@", {key = "lc_throttle"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drive_aids.lc_ramp_time)@", {key = "lc_ramp_time"})

  runtime:loadInitial()
end

return {open = open}
