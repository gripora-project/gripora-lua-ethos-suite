---
title: "Traction Control"
sidebar_label: "Traction Control"
sidebar_position: 31
documentation_status: reviewed
source: app/pages/drive_aids_tc.lua
---

# Traction Control

Gripora's traction control for the current PID profile, as in the Traction Control
section of gripora-configurator's Drive aids panel. Stops the wheels spinning up when you pull the trigger hard: the
forward throttle may only rise at a limited rate, zero to full in the ramp time. Letting
off is instant, and the brake and reverse are never touched. It works from the trigger
and time only, with no sensors.

The drive aids shape the throttle and brake you give before they reach the ESC. A switch
assigned to the *DRIVE AIDS OFF* mode on the Modes page turns ABS and traction control
off; they are also off while disarmed and in failsafe. The ESC's mixer rule must take the
stabilized throttle, as the car mixer preset does; a rule fed straight from the RC
throttle bypasses them.

## Where to find it

*Configuration* → *Tuning* → *Traction* (under the *Drive Aids* group)

Requires a running background task and a flight controller connection.

The settings belong to the current PID profile: the page title shows the profile it
edits (for example *Traction Control #1*), and the page reloads when the profile changes.

## Settings

| Setting | What it does |
| --- | --- |
| Mode | *Off*: the throttle goes to the ESC as you give it. *Ramp*: the throttle rises no faster than zero to full in the ramp time; after a brake or a let-off it rises again from where the throttle is. Default: Off. |
| Ramp Time | *Ramp* only (greyed out otherwise): the quickest the throttle may go from zero to full. Longer is gentler: try longer on a slippery surface, shorter on high grip. Range: 50 to 2000 ms. Default: 500 ms. |

## Notes

- Saving writes the settings to the flight controller EEPROM. The firmware uses them
  at once; no reboot.
- Save is refused while the model is armed.
- Each PID profile has its own drive aids settings. Copying a profile copies them, and
  resetting the current PID profile resets them to the defaults.
- ABS and traction control are one MSP message (MSP2_GRIPORA_DRIVE_AIDS_CONFIG): saving
  either page writes the other page's settings back as they were read.
- Firmware without the message refuses the read, and the page shows a failed load. The
  firmware refuses the whole save if any value is out of range.
- The tile is labelled *Traction* so it fits on the smallest screens.
- Firmware from before traction control replies without the TC fields: both fields
  are greyed out, and saving sends the ABS settings only.

## Source

[Page implementation](../../../src/grsuite/app/pages/drive_aids_tc.lua), codec `lib/msp_drive_aids_config.lua` (MSP2_GRIPORA_DRIVE_AIDS_CONFIG /
MSP2_GRIPORA_SET_DRIVE_AIDS_CONFIG, 0x5F3F / 0x5F40). Menu conditions come from
`app/tool.lua`.

*Documented against GRSuite Ethos 2.3.1.*
