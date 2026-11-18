-- MSP2_GRIPORA_DRIVE_STATUS helper (0x5F3E, read only): the live drive
-- state, firmware flight/drive.c.
--
-- Reply (gripora-firmware msp.c, MSP2_GRIPORA_DRIVE_STATUS):
--   U8 esc_mode (the resolved driveEscMode_e), U8 esc_state
--   (driveEscState_e: neutral, forward, brake, reverse), S8 direction
--   (-1 reverse, 1 forward), U8 speed_known (motor RPM gives the
--   wheel speed), U16 speed (0.1 km/h), U8 correction (steering correction
--   scale, %)                                                      = 7 bytes
-- A shorter reply is refused (firmware without drive state).

if package.loaded["grsuite.lib.msp_drive_status"] then
  return package.loaded["grsuite.lib.msp_drive_status"]
end

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 0x5F3E
local REPLY_LENGTH = 7

-- Resolved AUTO (FWD_BRK_REV), neutral, forward, no RPM, 0 km/h, full correction.
local SIMULATOR_RESPONSE = {1, 0, 1, 0, 0, 0, 100}

local msp_drive_status = {
  READ_COMMAND = READ_COMMAND,
  REPLY_LENGTH = REPLY_LENGTH,
}

function msp_drive_status.decode(buf)
  local length = #buf
  if length < REPLY_LENGTH then
    return nil, "drive status reply is " .. length .. " bytes, expected " .. REPLY_LENGTH, true
  end
  buf.offset = 1
  local data = {}
  data.esc_mode = mspcodec.readU8(buf)
  data.esc_state = mspcodec.readU8(buf)
  local direction = mspcodec.readU8(buf)
  data.direction = direction >= 128 and direction - 256 or direction
  data.speed_known = mspcodec.readU8(buf) ~= 0
  data.speed = mspcodec.readU16(buf)
  data.correction = mspcodec.readU8(buf)
  return data
end

function msp_drive_status.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      local data, reason, refused = msp_drive_status.decode(buf)
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

package.loaded["grsuite.lib.msp_drive_status"] = msp_drive_status
return msp_drive_status
