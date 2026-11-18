---
title: "Launch Control"
sidebar_label: "Launch Control"
sidebar_position: 32
documentation_status: reviewed
source: app/pages/drive_aids_lc.lua
---

# Launch Control

Gripora's launch control for the current PID profile, as in the Launch Control section
of gripora-configurator's Drive aids panel. A clean start from a standing line: the first
pull of the trigger is held to the start throttle and rises to full over the ramp time,
so the wheels don't spin up off the line.

With Mode *Switch*, put the *LAUNCH* mode on a switch on the Modes page. At the line,
with the throttle at neutral or on the brake, turn LAUNCH on: the launch is staged and
the brake (and ABS) work as usual. The first forward throttle launches the car. The
launch ends at the end of the ramp, when you let off or brake, or when LAUNCH goes off,
and it runs once: turn LAUNCH off and on again for the next one. Turning LAUNCH on with
the throttle already forward stages nothing, and a brake from reverse never launches.
Traction control waits until the launch is over and carries on from the throttle it
reached.

The drive aids shape the throttle and brake you give before they reach the ESC. A switch
assigned to the *DRIVE AIDS OFF* mode on the Modes page turns ABS, traction control and
launch control off; they are also off while disarmed and in failsafe. The ESC's mixer
rule must take the stabilized throttle, as the car mixer preset does; a rule fed straight
from the RC throttle bypasses them.

## Where to find it

*Configuration* → *Tuning* → *Launch* (under the *Drive Aids* group)

Requires a running background task and a flight controller connection.

The settings belong to the current PID profile: the page title shows the profile it
edits (for example *Launch Control #1*), and the page reloads when the profile changes.

## Settings

| Setting | What it does |
| --- | --- |
| Mode | *Off*: the LAUNCH switch does nothing; the throttle goes to the ESC as you give it. *Switch*: the LAUNCH mode stages a launch as described above. Default: Off. |
| Start Throttle | *Switch* only (greyed out otherwise): the most throttle the car gets the moment it launches, however far you pull. Lower is gentler: try lower on a slippery surface, higher on high grip. Range: 10 to 100 %. Default: 50 %. |
| Ramp Time | *Switch* only (greyed out otherwise): the time the throttle takes to rise from the start throttle to full. Range: 100 to 5000 ms. Default: 1000 ms. |

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
- The tile is labelled *Launch* so it fits on the smallest screens.
- Firmware from before launch control replies without the LC fields: all three fields
  are greyed out, and saving sends only the settings that firmware has.

## Source

[Page implementation](../../../src/grsuite/app/pages/drive_aids_lc.lua), codec `lib/msp_drive_aids_config.lua` (MSP2_GRIPORA_DRIVE_AIDS_CONFIG /
MSP2_GRIPORA_SET_DRIVE_AIDS_CONFIG, 0x5F3F / 0x5F40). Menu conditions come from
`app/tool.lua`.

*Documented against GRSuite Ethos 2.3.1.*
