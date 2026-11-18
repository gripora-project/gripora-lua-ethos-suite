---
title: "Drive"
sidebar_label: "Drive"
sidebar_position: 30
documentation_status: reviewed
source: app/pages/esc_motors_drive.lua
---

# Drive

How the controller works out which way the car is travelling and how fast, and how the
steering gyro uses that: what the ESC does below neutral, the driven tyre size, and how
the gyro fades in with speed and works in reverse. The same settings as the *Drive* panel
on gripora-configurator's Motors tab (MSP2_GRIPORA_DRIVE_CONFIG).

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *Drive*

Requires a running background task and a flight controller connection.

## Settings

| Setting | What it does |
| --- | --- |
| ESC behaviour | What the ESC does when the throttle goes below neutral, so the controller can tell when the car is reversing. *Automatic* chooses from the ESC protocol (DShot reverses directly, PWM brakes first). *Brake, then reverse*: most car ESCs. *Reverse directly*: AM32 in its default bidirectional mode and DShot ESCs. *Forward and brake only*: the car never reverses. Default: Automatic. |
| Tyre diameter | Outside diameter of the driven tyres, 20-300 mm (default 100). With the gear ratio (on *RPM*) it turns motor RPM into the car's speed. |
| Gyro starts at | Below this speed, in km/h (1.0-199.9, default 2.0), the gyro doesn't correct the steering, so at a standstill the steering follows the stick alone. Needs motor RPM. |
| Gyro fully on at | The gyro correction rises from nothing at the start speed to full at this speed, in km/h (1.1-200.0, default 6.0). It must be above the start speed. |
| Gyro in reverse | On: the gyro corrects the steering while the car reverses (the controller turns the correction round by itself). Off: steer by the stick alone in reverse. Default: On. |
| Reverse gyro gain | Gyro correction while reversing, 0-100 % of the forward correction (default 50 %). |

## Notes

- Saving writes the settings to the flight controller EEPROM. The firmware uses them at
  once; no reboot. Save is refused while the model is armed.
- The firmware refuses the whole save if a value is out of range or *Gyro fully on at*
  is not above *Gyro starts at*; the page shows the save error and nothing changes.
- Not part of a PID or rate profile.
- Firmware without MSP2_GRIPORA_DRIVE_CONFIG refuses the read, and the page shows a
  failed load.

## Source

[Page implementation](../../../src/grsuite/app/pages/esc_motors_drive.lua), codec
`lib/msp_drive_config.lua` (MSP2_GRIPORA_DRIVE_CONFIG / MSP2_GRIPORA_SET_DRIVE_CONFIG,
0x5F3C / 0x5F3D). Menu conditions come from `app/tool.lua`.

*Documented against GRSuite Ethos 2.3.1.*
