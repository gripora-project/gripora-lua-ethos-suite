---
title: "Driving Feel"
sidebar_label: "Driving Feel"
sidebar_position: 30
documentation_status: reviewed
source: app/pages/master_gains.lua
---

# Driving Feel

How the steering gyro feels: how hard it corrects, how long it holds a correction and
how firmly it stops at the end of a turn, plus the throttle and GPS speed gain
attenuation. The same panel as *Driving Feel* on gripora-configurator's Profiles tab.

## Where to find it

*Configuration* → *Tuning* → *Driving Feel* (under the *Steering* group)

Requires a running background task and a flight controller connection.

The values belong to the current PID profile: the page title shows the profile it edits (for example *Driving Feel #1*), and the page reloads when the profile changes.

## Settings

| Setting | What it does |
| --- | --- |
| Gain (Steering) | Master gain, 0-200 % (default 100): how hard the car fights unwanted yaw. Raise it if the car wanders or feels soft; lower it if the steering wobbles or buzzes. Scales P, I, D and F together; 0 % turns the gyro correction off. |
| Decay (Steering) | I-term decay time, 0.01-1.00 s (default 0.60): how long the car holds its line after a bump. Longer feels more locked in; shorter feels freer and suits drifting. |
| Relax (Steering) | I-term Relax, 1-10 (default 5): how firmly it stops at the end of a fast turn or slide. Raise it if the car kicks back; lower it if long turns lose rate. |
| Gain (Throttle) | Throttle attenuation, 25-200 % (default 100): changes the steering gain with throttle, for example to reduce it at high throttle if the steering wobbles at speed. Optionally shaped by a Throttle curve on *Gain Curves*. GYRO OFF is not affected. |
| Gain (Speed) | GPS speed attenuation, 25-200 % (default 100): lowers gain as GPS speed rises, so a tune that is right at low speed does not wobble on a fast straight. Does nothing on its own: assign a Speed curve and set its speed range on *Gain Curves*. Needs a GPS with a fix. Throttle and Speed together never go below 25 %. |

## Notes

- The roll and pitch rows are not shown; the page writes them back unchanged.
- Saving writes the PID profile to the flight controller EEPROM. No reboot.


## Source

[Page implementation](../../../src/grsuite/app/pages/master_gains.lua). Menu conditions come from `app/tool.lua`.

*Documented against GRSuite Ethos 2.3.1.*
