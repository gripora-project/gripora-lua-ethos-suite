-- Tuning -> Advanced -> Gain Curves.
--
-- Assigns a gain curve (one of app/pages/curves.lua's 8 shared pool slots)
-- to the steering Driving Feel Gain, to Throttle and to GPS Speed (plus the
-- speed at the Speed curve's right edge). Only yaw is stabilised, so the
-- roll and pitch assignments (gain_curve_0/1) are not shown; they are written
-- back unchanged. Kept off the Driving Feel
-- page (app/pages/master_gains.lua) because curves are an advanced shaping
-- tool; shape editing lives on app/pages/curves.lua. Same MSP_PID_PROFILE
-- codec as Driving Feel and PID Controller.

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local fieldLayout = requireModule("app/field_layout.lua")
local pidProfile = requireModule("lib/msp_pid_profile.lua")
local curveSlotLabels = requireModule("app/curve_slot_labels.lua")

local PAGE_TITLE = "@i18n(app.modules.gain_curves.name)@"

-- "None"/"Curve 1".."Curve 8"
local CURVE_SLOT_OPTIONS = curveSlotLabels.optionsTable(8)

local ROWS = {
  {label = "@i18n(app.modules.pids.steering)@", key = "gain_curve_2"},
  {label = "@i18n(app.modules.master_gains.axis_throttle)@", key = "fw_tpa_curve"},
  {label = "@i18n(app.modules.master_gains.axis_speed)@", key = "fw_spa_curve"},
}

-- opts.onBack: called to return to the menu (see app/page_runtime.lua's
-- buildChrome()).
local function open(opts)
  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "gaincurves",
    mspModule = pidProfile,
    opts = opts,
    unloadPackageKeys = {"grsuite.lib.msp_pid_profile"},
  })

  form.clear()
  runtime:buildChrome()

  for _, row in ipairs(ROWS) do
    fieldLayout.buildSingle(runtime, row.label, {key = row.key, choices = CURVE_SLOT_OPTIONS})
  end
  fieldLayout.buildSingle(runtime, "@i18n(app.modules.gain_curves.speed_max)@", {key = "fw_spa_speed_max"})

  runtime:loadInitial()
end

return {open = open}
