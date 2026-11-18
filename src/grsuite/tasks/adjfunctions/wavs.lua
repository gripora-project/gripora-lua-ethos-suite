-- Adjustment-function ID -> spoken-word-token spec, used by
-- tasks/audio_events.lua's speakAdjFunction() to announce adjustment-range
-- changes while driving (each space-separated token plays one "<token>.wav"
-- from the "adjfunctions" soundpack folder -- word clips, not one recording
-- per function).
--
-- IDs match gripora-firmware's adjustmentFunc_e enum
-- (src/main/fc/rc_adjustments.h). Only the functions the Adjustments page
-- offers a car are listed (app/pages/adjustments.lua, the same set
-- gripora-configurator's functions.js leaves visible): steering (yaw) only,
-- no roll/pitch, leveling, governor or heli functions. The steering
-- functions are spoken with the pack's "yaw" word clip until a "steering"
-- clip is recorded. Functions with no word clips for their name (master
-- gain, I-term decay/relax, servo trim, the mixer role gains) stay silent;
-- the profile switches are announced elsewhere.
return {
  [7] = "yaw rate",
  [10] = "yaw rc rate",
  [13] = "yaw rc expo",
  [22] = "yaw p gain",
  [23] = "yaw i gain",
  [24] = "yaw d gain",
  [25] = "yaw f gain",
  [35] = "yaw gyro cutoff",
  [38] = "yaw dterm cutoff",
  [58] = "yaw b gain",
  [70] = "yaw setpoint boost gain",
  [72] = "yaw dyn ceiling gain",
  [73] = "yaw dyn deadband gain",
  [74] = "yaw dyn deadband filter",
  [91] = "yaw trim",
  [82] = "battery profile",
}
