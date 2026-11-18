-- MSP2_GRIPORA_DRIVE_CONFIG helper (0x5F3C read / 0x5F3D write): the drive
-- state settings, firmware pg/drive.h: how the ESC treats a command below
-- neutral, the driven tyre size, and how the steering gyro fades in with
-- speed and works in reverse. Not profile-scoped; read live (no reboot).
--
-- Reply and write (gripora-firmware msp.c, MSP2_GRIPORA_DRIVE_CONFIG /
-- MSP2_GRIPORA_SET_DRIVE_CONFIG), the same six fields:
--   U8 esc_mode (driveEscMode_e), U16 wheel_diameter (mm),
--   U16 gyro_min_speed, U16 gyro_full_speed (0.1 km/h), U8 gyro_reverse (0/1),
--   U8 gyro_reverse_gain (%)                                       = 9 bytes
-- The firmware refuses the whole write if any value is out of range, or if
-- gyro_full_speed is not above gyro_min_speed. A reply shorter than 9 bytes
-- is refused (firmware without drive state), so the Setup Wizard can hide
-- what needs it, as the configurator's loadDriveConfig() does.

if package.loaded["grsuite.lib.msp_drive_config"] then
  return package.loaded["grsuite.lib.msp_drive_config"]
end

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local mspcodec = requireModule("lib/mspcodec.lua")

local READ_COMMAND = 0x5F3C
local WRITE_COMMAND = 0x5F3D
local REPLY_LENGTH = 9

-- driveEscMode_e (firmware pg/drive.h)
local ESC_MODES = {"AUTO", "FWD_BRK_REV", "FWD_REV", "FWD_BRK"}

local FIELD_META = {
  esc_mode = {min = 0, max = 3, default = 0},
  wheel_diameter = {min = 20, max = 300, default = 100, suffix = "mm"},
  gyro_min_speed = {min = 10, max = 1999, default = 20},
  gyro_full_speed = {min = 11, max = 2000, default = 60},
  gyro_reverse = {min = 0, max = 1, default = 1},
  gyro_reverse_gain = {min = 0, max = 100, default = 50, suffix = "%"},
}

-- pg/drive.c reset template: AUTO, 100 mm, 20, 60, 1, 50.
local SIMULATOR_RESPONSE = {0, 100, 0, 20, 0, 60, 0, 1, 50}

local msp_drive_config = {
  READ_COMMAND = READ_COMMAND,
  WRITE_COMMAND = WRITE_COMMAND,
  REPLY_LENGTH = REPLY_LENGTH,
  ESC_MODES = ESC_MODES,
  ESC_AUTO = 0,
  ESC_FWD_BRK_REV = 1,
  ESC_FWD_REV = 2,
  ESC_FWD_BRK = 3,
  FIELD_META = FIELD_META,
}

-- What AUTO picks (firmware flight/drive.c): DShot reverses directly, every
-- other protocol brakes first.
function msp_drive_config.resolveEscMode(mode, isDshot)
  if mode ~= 0 then return mode end
  return isDshot and 2 or 1
end

-- Returns the fields, or nil, a reason, and true when the reply was REFUSED.
function msp_drive_config.decode(buf)
  local length = #buf
  if length < REPLY_LENGTH then
    return nil, "drive config reply is " .. length .. " bytes, expected " .. REPLY_LENGTH, true
  end
  buf.offset = 1
  return {
    esc_mode = mspcodec.readU8(buf),
    wheel_diameter = mspcodec.readU16(buf),
    gyro_min_speed = mspcodec.readU16(buf),
    gyro_full_speed = mspcodec.readU16(buf),
    gyro_reverse = mspcodec.readU8(buf),
    gyro_reverse_gain = mspcodec.readU8(buf),
  }
end

-- Writes back what decode() returned, with any field changed: a missing
-- field is written as its firmware default.
function msp_drive_config.encode(data)
  data = data or {}
  local function v(key) return data[key] or FIELD_META[key].default end
  local payload = {}
  mspcodec.writeU8(payload, v("esc_mode"))
  mspcodec.writeU16(payload, v("wheel_diameter"))
  mspcodec.writeU16(payload, v("gyro_min_speed"))
  mspcodec.writeU16(payload, v("gyro_full_speed"))
  mspcodec.writeU8(payload, v("gyro_reverse") ~= 0 and 1 or 0)
  mspcodec.writeU8(payload, v("gyro_reverse_gain"))
  return payload
end

function msp_drive_config.buildReadMessage(onData, onError)
  return {
    command = READ_COMMAND,
    processReply = function(_, buf)
      local data, reason, refused = msp_drive_config.decode(buf)
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

function msp_drive_config.buildWriteMessage(data, onWritten, onError)
  return {
    command = WRITE_COMMAND,
    payload = msp_drive_config.encode(data),
    isWrite = true,
    processReply = function()
      if onWritten then onWritten() end
    end,
    errorHandler = onError,
    simulatorResponse = {},
  }
end

package.loaded["grsuite.lib.msp_drive_config"] = msp_drive_config
return msp_drive_config
