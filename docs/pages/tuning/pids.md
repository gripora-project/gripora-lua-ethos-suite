---
title: "PIDs"
sidebar_label: "PIDs"
sidebar_position: 10
documentation_status: reviewed
source: app/pages/pids.lua
---

# PIDs

The steering loop's PID gains. Only the steering (yaw) is stabilised on a car, so the
page shows one row, *Steering*, with the P, I, D, F and B gains (MSP_PID_TUNING).

## Where to find it

*Configuration* → *Tuning* → *PIDs* (under the *Steering* group)

Requires a running background task and a flight controller connection.

The values belong to the current PID profile: the page title shows the profile it edits (for example *PIDs #1*), and the page reloads when the profile changes.

## Settings

| Setting | What it does |
| --- | --- |
| P | How hard the gyro corrects a yaw error. |
| I | Corrects a steady yaw error over time, so the car holds its line. |
| D | Damps fast yaw movement. |
| F | Feed-forward from the steering stick; the firmware keeps it at 50 or more. |
| B | Boost on fast steering inputs. |

## Notes

- The roll and pitch gains are not shown; the page writes them back unchanged.
- Saving writes the PID profile to the flight controller EEPROM. No reboot.


## Source

[Page implementation](../../../src/grsuite/app/pages/pids.lua). Menu conditions come from `app/tool.lua`.

*Documented against GRSuite Ethos 2.3.1.*
