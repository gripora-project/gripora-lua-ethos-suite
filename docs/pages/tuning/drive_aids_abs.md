---
title: "Drive Aids"
sidebar_label: "Drive Aids"
sidebar_position: 50
documentation_status: reviewed
source: app/pages/drive_aids_abs.lua
---

# Drive Aids

Sets up Gripora's drive aids for the current PID profile: timed ABS and traction control,
in an *ABS* and a *Traction Control* section, as on gripora-configurator's Drive aids
panel. They shape the throttle and brake you give before they reach the ESC. A switch
assigned to the *DRIVE AIDS OFF* mode on the Modes page turns both off; they are also off
while disarmed and in failsafe. The ESC's mixer rule must take the stabilized throttle, as
the car mixer preset does; a rule fed straight from the RC throttle bypasses them.

**ABS.** Past the trigger, ABS pulses the brake: each cycle holds the full brake command
for half the cycle plus the hold time, then eases it down to the release floor for the
rest of the cycle. It acts only while the ESC is braking a car that is still rolling, and
never releases below 10% brake, so a brake-then-reverse ESC never sees neutral in the
middle of a stop and does not drop into reverse.

**Traction control.** Stops the wheels spinning up when you pull the trigger hard: the
forward throttle may only rise at a limited rate, zero to full in the ramp time. Letting
off is instant, and the brake and reverse are never touched. It works from the trigger
and time only, with no sensors.

## Where to find it

*Configuration* → *Tuning* → *Drive Aids* (under the *Drive Aids* group)

Requires a running background task and a flight controller connection.

The settings belong to the current PID profile: the page title shows the profile it
edits (for example *Drive Aids #1*), and the page reloads when the profile changes.

## Settings

| Setting | What it does |
| --- | --- |
| **ABS** | |
| Mode | *Off*: no ABS. *Static*: fixed pulse rate, floor and hold. *Dynamic*: the rate, floor and hold move with brake depth, from the values below at the trigger towards the *Full Brake* values at full brake (the floor drops to 60% of its value at full brake). Default: Off. |
| Trigger | ABS runs once the brake command passes this point. Range: 5 to 100%. Default: 30%. |
| Pulse Rate | Brake pulses per second. Range: 2 to 33 Hz. Default: 10 Hz. |
| Release Floor | Brake kept during the release part of each pulse, as a percentage of the brake command (never below 10% brake). Range: 0 to 100%. Default: 40%. |
| Hold | Extra full-brake time per pulse beyond half the cycle. Range: 0 to 100 ms. Default: 20 ms. |
| Full Brake Rate | *Dynamic* only (greyed out otherwise): the pulse rate at full brake. Range: 2 to 33 Hz. Default: 15 Hz. |
| Full Brake Hold | *Dynamic* only (greyed out otherwise): the hold at full brake. It can only shorten *Hold*; 0 keeps *Hold* throughout. Range: 0 to 100 ms. Default: 0 (off). |
| Rate Added at Lock | Pulse rate added at full steering lock, scaled with steering; 0 turns it off. Range: 0 to 10 Hz. Default: 0 (off). |
| Hold at Lock | The hold at full steering lock, scaled with steering. It can only shorten the hold; 0 turns it off. Where this and *Full Brake Hold* both apply, the shorter hold wins. Range: 0 to 100 ms. Default: 0 (off). |
| **Traction Control** | |
| Mode | *Off*: the throttle goes to the ESC as you give it. *Ramp*: the throttle rises no faster than zero to full in the ramp time; after a brake or a let-off it rises again from where the throttle is. Default: Off. |
| Ramp Time | *Ramp* only (greyed out otherwise): the quickest the throttle may go from zero to full. Longer is gentler: try longer on a slippery surface, shorter on high grip. Range: 50 to 2000 ms. Default: 500 ms. |

## Notes

- Saving writes the settings to the flight controller EEPROM. The firmware uses them
  at once; no reboot.
- Save is refused while the model is armed.
- Each PID profile has its own drive aids settings. Copying a profile copies them, and
  resetting the current PID profile resets them to the defaults.
- Firmware without MSP2_GRIPORA_DRIVE_AIDS_CONFIG refuses the read, and the page shows a
  failed load. The firmware refuses the whole save if any value is out of range.
- Firmware from before traction control replies without the TC fields: both TC
  fields are greyed out, and the save sends the ABS settings only.

## Source

[Page implementation](../../../src/grsuite/app/pages/drive_aids_abs.lua), codec
`lib/msp_drive_aids_config.lua` (MSP2_GRIPORA_DRIVE_AIDS_CONFIG /
MSP2_GRIPORA_SET_DRIVE_AIDS_CONFIG, 0x5F3F / 0x5F40). Menu conditions come from
`app/tool.lua`.

*Documented against GRSuite Ethos 2.3.1.*
