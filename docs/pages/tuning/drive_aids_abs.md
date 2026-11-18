---
title: "ABS"
sidebar_label: "ABS"
sidebar_position: 30
documentation_status: reviewed
source: app/pages/drive_aids_abs.lua
---

# ABS

Gripora's timed ABS for the current PID profile, as in the ABS section of
gripora-configurator's Drive aids panel. Past the trigger, ABS pulses the brake: each cycle holds the full brake command
for half the cycle plus the hold time, then eases it down to the release floor for the
rest of the cycle. It acts only while the ESC is braking a car that is still rolling, and
never releases below 10% brake, so a brake-then-reverse ESC never sees neutral in the
middle of a stop and does not drop into reverse.

The drive aids shape the throttle and brake you give before they reach the ESC. A switch
assigned to the *DRIVE AIDS OFF* mode on the Modes page turns ABS, traction control and
launch control off; they are also off while disarmed and in failsafe. The ESC's mixer rule must take the
stabilized throttle, as the car mixer preset does; a rule fed straight from the RC
throttle bypasses them.

## Where to find it

*Configuration* → *Tuning* → *ABS* (under the *Drive Aids* group)

Requires a running background task and a flight controller connection.

The settings belong to the current PID profile: the page title shows the profile it
edits (for example *ABS #1*), and the page reloads when the profile changes.

## Settings

| Setting | What it does |
| --- | --- |
| Mode | *Off*: no ABS. *Static*: fixed pulse rate, floor and hold. *Dynamic*: the rate, floor and hold move with brake depth, from the values below at the trigger towards the *Full Brake* rate and hold at full brake (the floor drops to 60% of its value at full brake). Default: Off. |
| Trigger | ABS runs once the brake command passes this point. Range: 5 to 100%. Default: 30%. |
| Release Floor | Brake kept during the release part of each pulse, as a percentage of the brake command (never below 10% brake). Range: 0 to 100%. Default: 40%. |
| Pulse: Rate | Brake pulses per second. Range: 2 to 33 Hz. Default: 10 Hz. |
| Pulse: Hold | Extra full-brake time per pulse beyond half the cycle. Range: 0 to 100 ms. Default: 20 ms. |
| Full Brake: Rate | *Dynamic* only (greyed out otherwise): the pulse rate at full brake. Range: 2 to 33 Hz. Default: 15 Hz. |
| Full Brake: Hold | *Dynamic* only (greyed out otherwise): the hold at full brake. It can only shorten *Hold*; 0 keeps *Hold* throughout. Range: 0 to 100 ms. Default: 0 (off). |
| At Full Lock: Rate | Pulse rate added at full steering lock, scaled with steering; 0 turns it off. Range: 0 to 10 Hz. Default: 0 (off). |
| At Full Lock: Hold | The hold at full steering lock, scaled with steering. It can only shorten the hold; 0 turns it off. Where this and the *Full Brake* hold both apply, the shorter hold wins. Range: 0 to 100 ms. Default: 0 (off). |

## Notes

- Saving writes the settings to the flight controller EEPROM. The firmware uses them
  at once; no reboot.
- Save is refused while the model is armed.
- Each PID profile has its own drive aids settings. Copying a profile copies them, and
  resetting the current PID profile resets them to the defaults.
- ABS, traction control and launch control are one MSP message
  (MSP2_GRIPORA_DRIVE_AIDS_CONFIG): saving any of the three pages writes the other
  pages' settings back as they were read.
- Firmware without the message refuses the read, and the page shows a failed load. The
  firmware refuses the whole save if any value is out of range.
- Each rate and its hold share a line: *Pulse*, *Full Brake* and *At Full Lock*.

## Source

[Page implementation](../../../src/grsuite/app/pages/drive_aids_abs.lua), codec `lib/msp_drive_aids_config.lua` (MSP2_GRIPORA_DRIVE_AIDS_CONFIG /
MSP2_GRIPORA_SET_DRIVE_AIDS_CONFIG, 0x5F3F / 0x5F40). Menu conditions come from
`app/tool.lua`.

*Documented against GRSuite Ethos 2.3.1.*
