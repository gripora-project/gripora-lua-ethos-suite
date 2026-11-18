-- MSP2_GRIPORA_DRIFT_CONFIG helper (0x5F42 read / 0x5F43 write): the drift
-- mode settings of the current PID profile, firmware pg/drift.h.
--
-- Read reply (gripora-firmware msp.c, MSP2_GRIPORA_DRIFT_CONFIG):
--   U8 gain (%), U16 allow (deg/s), U8 limit (%)                  = 4 bytes
-- A longer reply is a later firmware that appended more: only these are read,
-- and the write sends these four. Shorter than four is refused.
-- The write (MSP2_GRIPORA_SET_DRIFT_CONFIG) sends the same 4 bytes; the
-- firmware refuses the whole write if any value is out of range
-- (DRIFT_GAIN_MAX, DRIFT_ALLOW_MAX, DRIFT_LIMIT_MIN/MAX), so FIELD_META's
-- ranges match its checks.
--
-- Firmware without drift mode answers the read as unsupported (the MSP error
-- flag, which reaches onError as `true`). That is not a failed read: onData
-- gets {supported = false}, so the page loads and greys its fields out, the
-- way the drive aids pages treat a reply without their fields. Such data
-- builds no write (buildWriteMessage() returns nil).
-- The settings are stored per PID profile; both messages act on the current
-- profile. They are read live by the firmware: no reboot after saving.

if package.loaded["grsuite.lib.msp_drift_config"] then
  return package.loaded["grsuite.lib.msp_drift_config"]
end

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 0x5F42
local WRITE_COMMAND = 0x5F43
local REPLY_LENGTH = 4

-- Ranges and defaults from pg/drift.h / pg/drift.c.
local FIELD_META = {
  gain = {min = 0, max = 200, default = 100, suffix = "%"},
  allow = {min = 0, max = 720, default = 30, suffix = "°/s", step = 5},
  limit = {min = 10, max = 100, default = 100, suffix = "%"},
}

-- The firmware defaults: 100 %, 30 deg/s, 100 %.
local SIMULATOR_RESPONSE = {100, 30, 0, 100}

local msp_drift_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  REPLY_LENGTH = REPLY_LENGTH,
  FIELDS = {"gain", "allow", "limit"},
  FIELD_META = FIELD_META,
}

-- Whether an onError reason is the firmware answering the command as
-- unsupported (the MSP error flag; tasks/msp/queue.lua reports it as true).
function msp_drift_config.unsupported(reason)
  return reason == true
end

-- Returns the fields, or nil, a reason, and true when the reply was REFUSED.
function msp_drift_config.decode(buf)
  local length = #buf
  if length < REPLY_LENGTH then
    return nil, "drift config reply is " .. length .. " bytes, expected at least " .. REPLY_LENGTH, true
  end
  buf.offset = 1
  return {
    supported = true,
    gain = mspcodec.readU8(buf),
    allow = mspcodec.readU16(buf),
    limit = mspcodec.readU8(buf),
  }
end

-- A missing field is written as its firmware default.
function msp_drift_config.encode(data)
  data = data or {}
  local payload = {}
  mspcodec.writeU8(payload, data.gain or FIELD_META.gain.default)
  mspcodec.writeU16(payload, data.allow or FIELD_META.allow.default)
  mspcodec.writeU8(payload, data.limit or FIELD_META.limit.default)
  return payload
end

function msp_drift_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      local data, reason, refused = msp_drift_config.decode(buf)
      if not data then
        if onError then onError(reason, refused) end
        return
      end
      onData(data)
    end,
    errorHandler = function(reason)
      if msp_drift_config.unsupported(reason) then
        onData({supported = false})
      elseif onError then
        onError(reason)
      end
    end,
    simulatorResponse = SIMULATOR_RESPONSE,
  }
end

-- nil for firmware without drift mode: there is nothing to write.
function msp_drift_config.buildWriteMessage(data, onWritten, onError)
  if not (data and data.supported) then return nil end
  return {
    command = WRITE_COMMAND,
    payload = msp_drift_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["grsuite.lib.msp_drift_config"] = msp_drift_config
return msp_drift_config
