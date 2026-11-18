-- The drive status telemetry word: gripora-firmware's TELEM_DRIVE_STATUS (sensor 93, CRSF custom
-- 0x1205, S.Port 0x5125; telemetryDriveStatus() in src/main/telemetry/sensors.c).
--
--   bits 0-6  the drive aids flags (driveAidsGetFlags(), src/main/flight/drive_aids.h): aids on,
--             ABS armed, ABS releasing, TC armed, TC holding back, launch staged, launching
--   bit 8     GYRO OFF (stabilisation bypassed)      bit 9   DRIFT
--   bit 10    LAUNCH switch on                        bit 11  DRIVE AIDS OFF switch on
--   bit 12    reversing                               bit 13  speed known
--
-- state(raw) reduces the word to the one thing a dashboard tile or the ActiveLook glasses show,
-- most urgent first. Stateless; shared by widgets/dashboard/objects/text/driveaids.lua and
-- widgets/activelook.lua.

if package.loaded["grsuite.lib.drive_status"] then
  return package.loaded["grsuite.lib.drive_status"]
end

local floor = math.floor

local AIDS_ON = 1 << 0
local ABS_ARMED = 1 << 1
local ABS_ACTIVE = 1 << 2
local TC_ARMED = 1 << 3
local TC_ACTIVE = 1 << 4
local LC_STAGED = 1 << 5
local LC_ACTIVE = 1 << 6
local GYRO_OFF = 1 << 8
local DRIFT = 1 << 9
local AIDS_OFF = 1 << 11
local REVERSING = 1 << 12
local SPEED_KNOWN = 1 << 13

local drive_status = {}

-- state -> text. ABS, TC and LAUNCH each have two states (watching / acting) with the same word:
-- the colour tells them apart.
drive_status.TEXT = {
  gyro_off = "@i18n(widgets.driveaids.GYRO_OFF)@",
  abs = "@i18n(widgets.driveaids.ABS)@",
  tc = "@i18n(widgets.driveaids.TC)@",
  launch = "@i18n(widgets.driveaids.LAUNCH)@",
  launch_staged = "@i18n(widgets.driveaids.LAUNCH)@",
  drift = "@i18n(widgets.driveaids.DRIFT)@",
  aids_off = "@i18n(widgets.driveaids.AIDS_OFF)@",
  abs_armed = "@i18n(widgets.driveaids.ABS)@",
  tc_armed = "@i18n(widgets.driveaids.TC)@",
  aids_on = "@i18n(widgets.driveaids.AIDS_ON)@",
  off = "@i18n(widgets.driveaids.OFF)@",
}

-- state -> level, which a display maps to a colour:
--   off     stabilisation or the aids switched off by the driver
--   active  an aid acting on the throttle or brake right now
--   staged  launch control waiting for the throttle
--   mode    DRIFT
--   on      the aids running (and ABS or TC watching)
--   idle    aids not running: disarmed, failsafe
drive_status.LEVEL = {
  gyro_off = "off",
  abs = "active",
  tc = "active",
  launch = "active",
  launch_staged = "staged",
  drift = "mode",
  aids_off = "off",
  abs_armed = "on",
  tc_armed = "on",
  aids_on = "on",
  off = "idle",
}

-- The state for a raw word, or nil when there is no reading.
function drive_status.state(raw)
  raw = tonumber(raw)
  if raw == nil then return nil end
  raw = floor(raw)
  if raw & GYRO_OFF ~= 0 then return "gyro_off" end
  if raw & ABS_ACTIVE ~= 0 then return "abs" end
  if raw & TC_ACTIVE ~= 0 then return "tc" end
  if raw & LC_ACTIVE ~= 0 then return "launch" end
  if raw & LC_STAGED ~= 0 then return "launch_staged" end
  if raw & DRIFT ~= 0 then return "drift" end
  if raw & AIDS_OFF ~= 0 then return "aids_off" end
  if raw & ABS_ARMED ~= 0 then return "abs_armed" end
  if raw & TC_ARMED ~= 0 then return "tc_armed" end
  if raw & AIDS_ON ~= 0 then return "aids_on" end
  return "off"
end

function drive_status.reversing(raw)
  raw = tonumber(raw)
  return raw ~= nil and floor(raw) & REVERSING ~= 0
end

-- False only when the word says the firmware has no speed source (no motor RPM or no gear
-- ratio/tyre size): its speed sensor then reads 0, which is not a speed.
function drive_status.speedKnown(raw)
  raw = tonumber(raw)
  if raw == nil then return true end
  return floor(raw) & SPEED_KNOWN ~= 0
end

package.loaded["grsuite.lib.drive_status"] = drive_status
return drive_status
