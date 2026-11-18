-- Servo names a mixer setup gives the servos it assigns, and servo labels
-- with the name. A port of gripora-configurator's src/js/ServoNames.js
-- (namesFromRules(), assignServoNames(), withServoName()); the names are the
-- same so a model set up from either side reads the same in both. When one
-- changes, change the other, and bin/tests/servo_names.lua with them.
--
-- Every servo stabilized yaw drives (lib/setup_wizard_surfaces.lua's
-- surfacesFromRules()) is a steering servo, STEER: one alone has no prefix,
-- a pair is front and rear in servo order (the car setup puts the front on
-- S1), and more are numbered. Servos on any other input are not named.

if package.loaded["grsuite.lib.servo_names"] then
  return package.loaded["grsuite.lib.servo_names"]
end

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local surfacesLib = requireModule("lib/setup_wizard_surfaces.lua")

local M = {}

-- Every servo the firmware has a name for (MAX_SUPPORTED_SERVOS)
M.SERVO_COUNT = 24

local STEER = "STEER"

-- Names earlier versions generated (the aircraft surface names of the
-- WingFlight setup this was forked from, and MIX, among them), still cleared
-- when the mix moves on: after the optional side prefix and number, as the
-- generated names.
local LEGACY_NAMES = {"RUDDER", "AIL", "FLPRN", "ELEVON", "VTAIL", "ELEV", "FLAP", "MIX"}
-- Whole names, as thrust-vector servos were named after their axis.
local LEGACY_WHOLE = {"TV ROLL", "TV PITCH", "TV YAW"}

-- Names for the servos `rules` drives: names[servo] (0-based).
function M.namesFromRules(rules)
  local names = {}
  local surfaces = surfacesLib.surfacesFromRules(rules, M.SERVO_COUNT)
  for i, surface in ipairs(surfaces) do
    if #surfaces == 1 then
      names[surface.servo] = STEER
    elseif #surfaces == 2 then
      names[surface.servo] = (i == 1 and "F " or "R ") .. STEER
    else
      names[surface.servo] = STEER .. " " .. i
    end
  end
  return names
end

-- True for a name namesFromRules() could have given, so one left on a servo
-- a new mix no longer drives can be told from a name the pilot typed.
function M.isGenerated(name)
  if not name or name == "" then return false end
  for _, whole in ipairs(LEGACY_WHOLE) do
    if name == whole then return true end
  end
  local body = name:gsub("^[LRF] ", ""):gsub(" %d+$", "")
  if body == STEER then return true end
  for _, abbr in ipairs(LEGACY_NAMES) do
    if body == abbr then return true end
  end
  return false
end

-- After a mixer setup has replaced the mix: names every servo `rules` drives
-- in `names` (0-based, "" for none), and clears a generated name from a
-- servo it no longer drives; a typed name there is kept. Returns the list of
-- servos whose name changed, for the caller to send.
function M.assign(names, rules)
  local wanted = M.namesFromRules(rules)
  local changed = {}
  for servo = 0, M.SERVO_COUNT - 1 do
    local current = names[servo] or ""
    local nextName = wanted[servo]
    if not nextName then
      nextName = M.isGenerated(current) and "" or current
    end
    if nextName ~= current then
      names[servo] = nextName
      changed[#changed + 1] = servo
    end
  end
  return changed
end

-- `label` with servo `servo`'s (0-based) name after it, e.g.
-- "Servo 1 (STEER)". names may be nil (firmware without names).
function M.withName(label, names, servo)
  local name = names and names[servo]
  if name and name ~= "" then
    return label .. " (" .. name .. ")"
  end
  return label
end

package.loaded["grsuite.lib.servo_names"] = M
return M
