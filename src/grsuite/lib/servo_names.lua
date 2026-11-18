-- Servo names a mixer setup gives the servos it assigns, and servo labels
-- with the name. A port of gripora-configurator's src/js/ServoNames.js
-- (namesFromRules(), assignServoNames(), withServoName()); the names are the
-- same so a model set up from either side reads the same in both. When one
-- changes, change the other, and bin/tests/servo_names.lua with them.
--
-- Each servo the mix drives is named after what it does
-- (lib/setup_wizard_surfaces.lua's surfaceKind()): a servo on yaw alone is
-- steering (STEER), anything else mixed (MIX). One alone has no prefix, a
-- pair of steering servos is front and rear (the car setup puts the front on
-- S1), any other pair left and right in servo order, and more are numbered.

if package.loaded["grsuite.lib.servo_names"] then
  return package.loaded["grsuite.lib.servo_names"]
end

local requireModule = package.loaded["grsuite.lib.require"] or assert(loadfile("lib/require.lua"))()
local surfacesLib = requireModule("lib/setup_wizard_surfaces.lua")

local M = {}

-- Every servo the firmware has a name for (MAX_SUPPORTED_SERVOS)
M.SERVO_COUNT = 24

local ABBREVIATIONS = {
  steering = "STEER",
  mixed = "MIX",
}

-- Names earlier versions generated (and the aircraft mixes of the
-- WingFlight setup this was forked from), still cleared when the mix moves
-- on: after the optional side prefix and number, as the generated names.
local LEGACY_NAMES = {"RUDDER", "AIL", "FLPRN", "ELEVON", "VTAIL", "ELEV", "FLAP"}
-- Whole names, as thrust-vector servos were named after their axis.
local LEGACY_WHOLE = {"TV ROLL", "TV PITCH", "TV YAW"}

-- Names for the servos `rules` drives: names[servo] (0-based).
function M.namesFromRules(rules)
  local names = {}
  local byKind, kinds = {}, {}
  for _, surface in ipairs(surfacesLib.surfacesFromRules(rules, M.SERVO_COUNT)) do
    local list = byKind[surface.kind]
    if not list then
      list = {}
      byKind[surface.kind] = list
      kinds[#kinds + 1] = surface.kind
    end
    list[#list + 1] = surface.servo
  end
  for _, kind in ipairs(kinds) do
    local servos = byKind[kind]
    local abbr = ABBREVIATIONS[kind] or ABBREVIATIONS.mixed
    for i, servo in ipairs(servos) do
      if #servos == 1 then
        names[servo] = abbr
      elseif #servos == 2 and kind == "steering" then
        names[servo] = (i == 1 and "F " or "R ") .. abbr
      elseif #servos == 2 then
        names[servo] = (i == 1 and "L " or "R ") .. abbr
      else
        names[servo] = abbr .. " " .. i
      end
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
  for _, abbr in pairs(ABBREVIATIONS) do
    if body == abbr then return true end
  end
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
