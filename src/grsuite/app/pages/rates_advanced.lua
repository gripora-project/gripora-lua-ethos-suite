-- Rates Advanced editor page. Loaded on demand (plain loadfile) only when
-- the user opens Tuning -> Advanced -> Rate Response -- see app/tool.lua.
--
-- Same MSP_RC_TUNING command as app/pages/rates.lua (see
-- lib/msp_rc_tuning.lua), a different field subset: response time, accel
-- limit, setpoint boost gain/cutoff and the three yaw dynamic fields
-- (ceiling gain, deadband gain, deadband filter).
--
-- Only yaw is stabilised (steering), so only the yaw values are shown, one
-- per line, as on gripora-configurator's Rates dynamics panel (which also
-- shows yaw only). The roll and pitch values (response_time_1/2,
-- accel_limit_1/2, setpoint_boost_*_1/2) are written back unchanged.
-- The Configurator does not show the accel limit; the firmware still uses
-- it (setpoint.c), so it stays here.
--
-- Every field here is a plain raw value with no rates_type-dependent
-- scaling. Everything else -- dialog/busy/save/reload/confirm state,
-- long-press-save, profile-switch-reload -- comes from app/page_runtime.lua.

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local rcTuning = requireModule("lib/msp_rc_tuning.lua")

local PAGE_TITLE = "@i18n(app.modules.rates_advanced.name)@"

local YAW = 3

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler: see app/menu_container.lua
-- and app/tool.lua for how Ethos's event()/wakeup()/close() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "ratesadvanced",
    mspModule = rcTuning,
    opts = opts,
    -- "Rates Advanced #<profile>" title suffix + auto-reload-on-profile-
    -- switch -- see app/pages/rates.lua's own comment on profileField for
    -- why this is "rateProfile", not the default "pidProfile".
    profileField = "rateProfile",
    unloadPackageKeys = {"grsuite.lib.msp_rc_tuning"},
  })

  form.clear()
  runtime:buildChrome()

  fieldLayout.buildSingle(runtime, "@i18n(app.modules.rates_advanced.response_time)@", {key = "response_time_" .. YAW})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.rates_advanced.accel_limit)@", {key = "accel_limit_" .. YAW})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.rates_advanced.setpoint_boost_gain)@", {key = "setpoint_boost_gain_" .. YAW})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.rates_advanced.setpoint_boost_cutoff)@", {key = "setpoint_boost_cutoff_" .. YAW})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.rates_advanced.dyn_ceiling_gain)@", {key = "yaw_dynamic_ceiling_gain"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.rates_advanced.dyn_deadband_gain)@", {key = "yaw_dynamic_deadband_gain"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.rates_advanced.dyn_deadband_filter)@", {key = "yaw_dynamic_deadband_filter"})

  runtime:loadInitial()
end

return {open = open}
