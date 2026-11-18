-- Tuning -> Drift (Steering group): the drift mode settings of the current PID
-- profile, the Drift panel of gripora-configurator's PID Profiles tab
-- (MSP2_GRIPORA_DRIFT_CONFIG, lib/msp_drift_config.lua). Per PID profile: the
-- header shows "Drift #<profile>" and the page reloads when the profile
-- changes. No reboot.
--
-- The DRIFT mode (Modes page) turns drift mode on: the steering wheel steers
-- the wheels directly, as with GYRO OFF, and the gyro only counter-steers turn
-- rate beyond the allowed rate (gripora-firmware pidApplyDrift()). A note
-- under the fields says so.
--
-- Greyed out: all three fields on firmware without drift mode, which answers
-- the command as unsupported (the codec's supported = false; nothing is
-- written back). The check runs from the wakeup tick but only touches the
-- fields when that changes (see syncEnabled()).

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local driftConfig = requireModule("lib/msp_drift_config.lua")

local PAGE_TITLE = "@i18n(app.modules.drift.name)@"
local KEYS = driftConfig.FIELDS

local function open(opts)
  local runtime
  -- nil = not applied since the last load, so the next loaded tick applies it.
  local lastSupported = nil

  local function syncEnabled(rt)
    if not rt.loaded then
      lastSupported = nil
      return
    end
    local supported = rt.data.supported == true
    if supported == lastSupported then return end
    lastSupported = supported
    for i = 1, #KEYS do
      local field = rt.fields[KEYS[i]]
      if field then field:enable(supported) end
    end
  end

  runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "drift",
    mspModule = driftConfig,
    isMspPage = true,
    opts = opts,
    unloadPackageKeys = {"grsuite.lib.msp_drift_config"},
    -- A load enables every field; re-apply the greying on top.
    onLoaded = function()
      lastSupported = nil
      syncEnabled(runtime)
    end,
    onWakeup = syncEnabled,
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drift.gain)@", {key = "gain"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drift.allow)@", {key = "allow"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.drift.limit)@", {key = "limit"})
  -- The note is a line of its own with no field (check-fit measures it as a
  -- note: the full width).
  form.addLine("@i18n(app.modules.drift.note)@")

  runtime:loadInitial()
end

return {open = open}
