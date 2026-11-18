-- Mixer Config page. Loaded on demand from Setup -> Mixer.
--
-- Scales/inverts the stabilized steering (yaw) axis that every mixer rule
-- reads from, via MSP_GET_MIXER_INPUT/MSP_SET_MIXER_INPUT (cmd 174/171, one
-- index per axis -- see lib/msp_mixer_input.lua), and sets the steering gyro
-- direction (yaw_gyro_reverse on MSP_MIXER_CONFIG, API 33.0), as
-- gripora-configurator's Mixer tab does. A car only stabilises yaw, so the
-- roll and pitch inputs are not shown or written.
--
-- The input's single wire field (`rate`, signed S16) is split into two
-- widgets: Throw (0-200%, |rate|/10) and Invert (rate's sign). `min`/`max`
-- are read and written back unchanged.
--
-- Not profile-scoped (`profileField = "none"`): a per-car geometry setting.
-- yaw_gyro_reverse is read live by the firmware, so no reboot.

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local pageRuntime = requireModule("app/page_runtime.lua")
local mixerInput = requireModule("lib/msp_mixer_input.lua")
local mixerConfig = requireModule("lib/msp_mixer_config.lua")

local PAGE_TITLE = "@i18n(app.modules.mixer.name)@"
local GAIN_MAX = 200
local GAIN_STEP = 5

local INVERT_OPTIONS = {
  {"@i18n(app.modules.mixer.normal)@", 0},
  {"@i18n(app.modules.mixer.inverted)@", 1},
}

-- key: source key (also lib/msp_mixer_input.lua's factory name).
-- rateKey: the field name that factory's decode()/encode() uses.
-- A car only stabilises yaw (steering), so only the yaw input is shown and
-- read/written, as on gripora-configurator's Mixer tab; the roll and pitch
-- inputs are separate MSP indices and are left untouched.
local AXES = {
  {key = "yaw", label = "@i18n(app.modules.pids.steering)@", rateKey = "rate_stabilized_yaw"},
}

local GYRO_OPTIONS = {
  {"@i18n(app.modules.mixer.normal)@", 0},
  {"@i18n(app.modules.mixer.inverted)@", 1},
}

local function gainFromRate(rate)
  rate = rate or 0
  local gain = (rate < 0 and -rate or rate) // 10
  if gain > GAIN_MAX then gain = GAIN_MAX end
  return gain
end

local function invertFromRate(rate)
  return ((rate or 0) < 0) and 1 or 0
end

local function open(opts)
  local controlRefHolder = {}
  local sources = {}
  for _, axis in ipairs(AXES) do
    sources[#sources + 1] = {key = axis.key, mspModule = mixerInput[axis.key]()}
  end
  -- MSP_MIXER_CONFIG, for yaw_gyro_reverse (API 33.0). Every other field is
  -- written back as read.
  sources[#sources + 1] = {key = "config", mspModule = mixerConfig}

  local runtime = pageRuntime.new({
    pageTitle = PAGE_TITLE,
    logTag = "mixerconfig",
    sources = sources,
    opts = opts,
    profileField = "none",
    unloadPackageKeys = {"grsuite.lib.msp_mixer_input", "grsuite.lib.msp_mixer_config"},
    -- Firmware older than API 33.0 does not report the gyro direction.
    onLoaded = function()
      local rt = controlRefHolder.ref and controlRefHolder.ref.runtime
      local config = rt and rt.data and rt.data.config
      local field = rt and rt.fields.gyro_reverse
      if field and not (config and config.yaw_gyro_reverse ~= nil) then field:enable(false) end
    end,
  })

  form.clear()
  runtime:buildChrome()
  -- Captured instead of closing over `runtime` directly in each field
  -- setter below -- matching app/pages/pids.lua's own dataRef convention
  -- (see its comment): Ethos retains some form callback closures past
  -- this page's own lifetime, and controlRef.runtime gets nilled on
  -- dispose (app/page_runtime.lua's own PageRuntime:dispose()), so
  -- whatever gets retained here stays small instead of pinning the whole
  -- disposed PageRuntime.
  local controlRef = runtime.controlRef
  controlRefHolder.ref = controlRef
  local function markDirty()
    local rt = controlRef.runtime
    if rt then rt:markDirty() end
  end
  local function axisData(axisKey)
    local rt = controlRef.runtime
    return rt and rt.data and rt.data[axisKey] or nil
  end

  local headerLine = form.addLine(" ")
  local headerSlots = form.getFieldSlots(headerLine, {0, 0})
  form.addStaticText(headerLine, headerSlots[1], "@i18n(app.modules.mixer.gain)@", RIGHT)
  form.addStaticText(headerLine, headerSlots[2], "@i18n(app.modules.mixer.invert)@", RIGHT)

  for _, axis in ipairs(AXES) do
    local line = form.addLine(axis.label)
    local slots = form.getFieldSlots(line, {0, 0})

    local gainField = form.addNumberField(line, slots[1], 0, GAIN_MAX,
      function()
        local data = axisData(axis.key)
        return gainFromRate(data and data[axis.rateKey])
      end,
      function(value)
        local data = axisData(axis.key)
        if not data then return end
        markDirty()
        local invert = invertFromRate(data[axis.rateKey])
        local rate = (tonumber(value) or 0) * 10
        if invert == 1 then rate = -rate end
        data[axis.rateKey] = rate
      end)
    gainField:suffix("%")
    if gainField.step then gainField:step(GAIN_STEP) end
    runtime:registerField(axis.key .. "_gain", gainField)

    local invertField = form.addChoiceField(line, slots[2], INVERT_OPTIONS,
      function()
        local data = axisData(axis.key)
        return invertFromRate(data and data[axis.rateKey])
      end,
      function(value)
        local data = axisData(axis.key)
        if not data then return end
        markDirty()
        local gain = gainFromRate(data[axis.rateKey])
        local rate = gain * 10
        if (tonumber(value) or 0) ~= 0 then rate = -rate end
        data[axis.rateKey] = rate
      end)
    runtime:registerField(axis.key .. "_invert", invertField)
  end

  -- Steering gyro direction (mixerGyroReverseTitle on the Configurator).
  local gyroLine = form.addLine("@i18n(app.modules.mixer.gyro_direction)@")
  local gyroField = form.addChoiceField(gyroLine, nil, GYRO_OPTIONS,
    function()
      local data = axisData("config")
      return (data and data.yaw_gyro_reverse) or 0
    end,
    function(value)
      local data = axisData("config")
      if not data or data.yaw_gyro_reverse == nil then return end
      markDirty()
      data.yaw_gyro_reverse = (tonumber(value) or 0) ~= 0 and 1 or 0
    end)
  runtime:registerField("gyro_reverse", gyroField)

  runtime:loadInitial()
end

return {open = open}
