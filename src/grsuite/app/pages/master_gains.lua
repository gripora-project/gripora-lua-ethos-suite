-- Driving Feel page (file name kept from its Master Gains origin). Loaded on
-- demand from Tuning -> Driving Feel.
--
-- Edits the same MSP_PID_PROFILE / MSP_SET_PID_PROFILE command (cmd
-- 94/95, see lib/msp_pid_profile.lua) as app/pages/pid_controller.lua --
-- a second page sharing one codec, same as every field that page itself
-- doesn't build a widget for already round-trips unchanged on every save
-- (see that file's own header comment). Steering Gain (master_gain_2),
-- Decay (iterm_decay_time_2), Relax (bounceback_2), Throttle Gain
-- (fw_tpa_gain) and Speed Gain (fw_spa_gain), one per line. Only yaw is stabilised, so the roll and pitch rows
-- (master_gain_0/1, iterm_decay_time_0/1, bounceback_0/1) are not shown;
-- they are written back unchanged.
--
-- Gain curves (gain_curve_0-2/fw_tpa_curve/fw_spa_curve) are assigned on
-- app/pages/gain_curves.lua under Advanced, since they are an advanced
-- shaping tool. Every other MSP_PID_PROFILE field is still read and
-- written back unchanged every round-trip here -- this page just doesn't
-- build a widget for it.

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local pidProfile = requireModule("lib/msp_pid_profile.lua")

local PAGE_TITLE = "@i18n(app.modules.master_gains.name)@"

-- One setting per line. The Configurator shows these as a Steering/Throttle/
-- Speed table, but on the radio a table whose Throttle and Speed rows have only
-- one of three cells reads worse than plain lines. I-term Decay is the other
-- half of how "locked" the steering feels: Gain sets how hard it pushes back,
-- Decay how long it remembers the disturbance. Relax is a 1-10 score (higher =
-- more relax, less bounce-back). Curves are assigned on app/pages/gain_curves.lua.
local FIELDS = {
  {label = "@i18n(app.modules.master_gains.steering_gain)@", key = "master_gain_2"},
  {label = "@i18n(app.modules.master_gains.lock)@", key = "iterm_decay_time_2"},
  {label = "@i18n(app.modules.master_gains.bounceback)@", key = "bounceback_2"},
  {label = "@i18n(app.modules.master_gains.throttle_gain)@", key = "fw_tpa_gain"},
  {label = "@i18n(app.modules.master_gains.speed_gain)@", key = "fw_spa_gain"},
}

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "mastergains",
    mspModule = pidProfile,
    opts = opts,
    unloadPackageKeys = {"grsuite.lib.msp_pid_profile"},
  })

  form.clear()
  runtime:buildChrome()

  for _, field in ipairs(FIELDS) do
    fieldLayout.buildSingle(runtime, field.label, {key = field.key})
  end

  runtime:loadInitial()
end

return {open = open}
