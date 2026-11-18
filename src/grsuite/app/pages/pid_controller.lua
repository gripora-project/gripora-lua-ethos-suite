-- PID Controller profile editor page. Loaded on demand (plain loadfile) only when the user opens "PID Controller" from the
-- system tool's main menu -- see app/tool.lua.
--
-- Edits the MSP_PID_PROFILE / MSP_SET_PID_PROFILE command (cmd 94/95, see
-- lib/msp_pid_profile.lua) -- a *different* command from app/pages/pids.lua's
-- MSP_PID_TUNING (cmd 112/202), even though both are scoped to the same
-- active PID profile on the flight controller. Only yaw is stabilised
-- (steering), so this exposes the I-term decay limit (the decay time is on
-- Driving Feel), the yaw I-term relax level and the yaw error limit. The
-- roll/pitch values, cross-axis, snap and prop-hang relax are not shown
-- (the firmware no longer uses them); they are written back unchanged.
-- master_gain_0-2/gain_curve_0-2/fw_tpa_gain/fw_tpa_curve (the "Master
-- Gains" table -- per-axis live P/I/D/F scale plus which
-- app/pages/curves.lua gain-curve slot shapes it) live on their own
-- app/pages/master_gains.lua page instead, sharing this same codec --
-- see that file's own header for why.
-- The other fields in that MSP command (gyro/dterm/bterm cutoffs,
-- removed leveling fields, etc.) are still read and
-- written back unchanged every round-trip -- lib/msp_pid_profile.lua's
-- codec always handles the full struct -- this page just doesn't build an
-- editable widget for them yet (most belong on dedicated pages once those
-- features are ported). Every dead heli-only field (see
-- lib/msp_pid_profile.lua's FIELDS list) never gets a widget at all.
--
-- Everything else -- dialog/busy/save/reload/confirm state, long-press-
-- save, profile-switch-reload -- comes from app/page_runtime.lua, shared
-- with every page. Field/row building (single-field lines, grouped inline
-- label+field rows) comes from app/field_layout.lua, promoted out of this
-- file once app/pages/tail_rotor.lua needed the identical helpers. This
-- file now only owns the MSP_PID_PROFILE codec and which fields to show.

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local pidProfile = requireModule("lib/msp_pid_profile.lua")

local PAGE_TITLE = "@i18n(app.modules.pid_controller.name)@"

-- opts.onBack: called to return to the menu (the header's Menu button or
-- the physical Back key -- see app/page_runtime.lua's buildChrome()).
-- opts.setEventHandler/opts.setWakeupHandler: see app/menu_container.lua
-- and app/tool.lua for how Ethos's event()/wakeup() reach a page.
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "pidctrl",
    mspModule = pidProfile,
    opts = opts,
    unloadPackageKeys = {"grsuite.lib.msp_pid_profile"},
  })

  form.clear()
  runtime:buildChrome()

  -- Steering only, as on gripora-configurator's PID Controller Settings panel:
  -- I-term decay limit, the yaw I-term relax level (its Relax score is on
  -- Driving Feel) and the yaw error limit.
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.pid_controller.inflight_error_decay)@", {key = "iterm_decay_limit"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.pid_controller.iterm_relax_level)@", {key = "iterm_relax_level_2"})
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.pid_controller.error_limit)@", {key = "error_limit_2"})

  runtime:loadInitial()
end

return {open = open}
