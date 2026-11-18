-- MSP2_GRIPORA_DRIVE_AIDS_CONFIG helper (0x5F3F read / 0x5F40 write): the
-- drive aids settings of the current PID profile, firmware pg/drive_aids.h.
-- ABS and traction control; later aids append their fields.
--
-- Read reply (gripora-firmware msp.c, MSP2_GRIPORA_DRIVE_AIDS_CONFIG):
--   U8 abs_mode, abs_freq, abs_floor, abs_hold, abs_trigger, abs_dyn_freq,
--   abs_dyn_hold, abs_corner_freq, abs_corner_hold                = 9 bytes
--   U8 tc_mode, U16 tc_ramp_time (ms)                             = 12 bytes
-- Older firmware replies the nine ABS bytes only: the TC fields are then left
-- nil (has_tc false) and the write sends nine bytes. A longer reply is a later
-- firmware that appended more: only these are read. Shorter than nine is
-- refused.
-- The write (MSP2_GRIPORA_SET_DRIVE_AIDS_CONFIG) sends the same 9 or 12 bytes;
-- the firmware takes the TC fields only from a request of 12 bytes or more,
-- leaves fields it was not sent unchanged and refuses the whole write if any
-- value is out of range, so FIELD_META's ranges match its checks.
-- The settings are stored per PID profile; both messages act on the current
-- profile. They are read live by the firmware: no reboot after saving.

if package.loaded["grsuite.lib.msp_drive_aids_config"] then
  return package.loaded["grsuite.lib.msp_drive_aids_config"]
end

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 0x5F3F
local WRITE_COMMAND = 0x5F40
local FIELD_COUNT = 9
local TC_REPLY_LENGTH = 12

-- Wire order.
local FIELDS = {
  "abs_mode", "abs_freq", "abs_floor", "abs_hold", "abs_trigger",
  "abs_dyn_freq", "abs_dyn_hold", "abs_corner_freq", "abs_corner_hold",
}

-- driveAbsMode_e
local ABS_MODE_OFF = 0
local ABS_MODE_STATIC = 1
local ABS_MODE_DYNAMIC = 2

-- driveTcMode_e
local TC_MODE_OFF = 0
local TC_MODE_RAMP = 1

local TC_MODE_CHOICES = {
  {"@i18n(api.DRIVE_AIDS_CONFIG.tbl_off)@", TC_MODE_OFF},
  {"@i18n(api.DRIVE_AIDS_CONFIG.tbl_ramp)@", TC_MODE_RAMP},
}

local ABS_MODE_CHOICES = {
  {"@i18n(api.DRIVE_AIDS_CONFIG.tbl_off)@", ABS_MODE_OFF},
  {"@i18n(api.DRIVE_AIDS_CONFIG.tbl_static)@", ABS_MODE_STATIC},
  {"@i18n(api.DRIVE_AIDS_CONFIG.tbl_dynamic)@", ABS_MODE_DYNAMIC},
}

-- Ranges and defaults from pg/drive_aids.h / pg/drive_aids.c.
local FIELD_META = {
  abs_mode = {choices = ABS_MODE_CHOICES},
  abs_freq = {min = 2, max = 33, default = 10, suffix = "Hz"},
  abs_floor = {min = 0, max = 100, default = 40, suffix = "%"},
  abs_hold = {min = 0, max = 100, default = 20, suffix = "ms"},
  abs_trigger = {min = 5, max = 100, default = 30, suffix = "%"},
  abs_dyn_freq = {min = 2, max = 33, default = 15, suffix = "Hz"},
  abs_dyn_hold = {min = 0, max = 100, default = 0, suffix = "ms"},
  abs_corner_freq = {min = 0, max = 10, default = 0, suffix = "Hz"},
  abs_corner_hold = {min = 0, max = 100, default = 0, suffix = "ms"},
  tc_mode = {choices = TC_MODE_CHOICES},
  tc_ramp_time = {min = 50, max = 2000, default = 500, suffix = "ms", step = 10},
}

local SIMULATOR_RESPONSE = {0, 10, 40, 20, 30, 15, 0, 0, 0, 0, 244, 1}

local msp_drive_aids_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  FIELD_COUNT = FIELD_COUNT,
  TC_REPLY_LENGTH = TC_REPLY_LENGTH,
  FIELDS = FIELDS,
  FIELD_META = FIELD_META,
  ABS_MODE_OFF = ABS_MODE_OFF,
  ABS_MODE_STATIC = ABS_MODE_STATIC,
  ABS_MODE_DYNAMIC = ABS_MODE_DYNAMIC,
  ABS_MODE_CHOICES = ABS_MODE_CHOICES,
  TC_MODE_OFF = TC_MODE_OFF,
  TC_MODE_RAMP = TC_MODE_RAMP,
  TC_MODE_CHOICES = TC_MODE_CHOICES,
}

-- Returns the fields, or nil, a reason, and true when the reply was REFUSED.
function msp_drive_aids_config.decode(buf)
  local length = #buf
  if length < FIELD_COUNT then
    return nil, "drive aids config reply is " .. length .. " bytes, expected at least " .. FIELD_COUNT, true
  end
  buf.offset = 1
  local data = {}
  for i = 1, FIELD_COUNT do
    data[FIELDS[i]] = mspcodec.readU8(buf)
  end
  data.has_tc = length >= TC_REPLY_LENGTH
  if data.has_tc then
    data.tc_mode = mspcodec.readU8(buf)
    data.tc_ramp_time = mspcodec.readU16(buf)
  end
  return data
end

-- A missing ABS field is written as its firmware default. The TC fields are
-- sent only when the reply carried them (has_tc), so older firmware gets the
-- nine bytes it knows.
function msp_drive_aids_config.encode(data)
  data = data or {}
  local payload = {}
  for i = 1, FIELD_COUNT do
    local key = FIELDS[i]
    local value = data[key]
    if value == nil then value = FIELD_META[key].default or 0 end
    mspcodec.writeU8(payload, value)
  end
  if data.has_tc then
    mspcodec.writeU8(payload, data.tc_mode or TC_MODE_OFF)
    mspcodec.writeU16(payload, data.tc_ramp_time or FIELD_META.tc_ramp_time.default)
  end
  return payload
end

function msp_drive_aids_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      local data, reason, refused = msp_drive_aids_config.decode(buf)
      if not data then
        if onError then onError(reason, refused) end
        return
      end
      onData(data)
    end,
    errorHandler = onError,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

function msp_drive_aids_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_drive_aids_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["grsuite.lib.msp_drive_aids_config"] = msp_drive_aids_config
return msp_drive_aids_config
