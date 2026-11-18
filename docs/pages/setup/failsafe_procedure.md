---
title: "Stage 2"
sidebar_label: "Stage 2"
sidebar_position: 20
documentation_status: reviewed
source: app/pages/failsafe_procedure.lua
---

# Stage 2

Choose the Stage 2 response and its timing after receiver fallback. Per-channel fallback is configured separately.

## Where to find it

*Configuration* → *Setup* → *Controls* → *Failsafe* → *Stage 2*

Requires a running background task and a flight controller connection.

## Settings

| Setting | What it does |
| --- | --- |
| Procedure | Stop (the motor goes to the failsafe throttle, then off) or Drop (motor off at once). GPS Rescue is removed from the firmware. |
| Switch Mode | Select Stage 1, Kill or Stage 2 for the failsafe switch behaviour. |
| Guard Delay | Delay before Stage 2, 2–200 units of 0.1 s. |
| Motor Off Delay | Time in the Stop stage before the motor is turned off and the car is disarmed, 0–200 units of 0.1 s. |
| Low Thr. Delay | Low-throttle delay setting, 0–300 units of 0.1 s. |
| Failsafe Throttle | Throttle sent during Stop, 750–2250 µs in steps of 5 µs (1500 = neutral). |
| Recovery Delay | Recovery delay setting, 0–200 units of 0.1 s. |

## Notes

The delay fields display counts of 0.1 seconds: a value of 10 means one second.
Save writes the complete failsafe configuration and commits to EEPROM; the page does not request a reboot or select a PID/rate profile.

See [Ch. Fallback](failsafe.md) for Stage 1.

## Source

[Page implementation](../../../src/grsuite/app/pages/failsafe_procedure.lua). Menu conditions come from `app/tool.lua`.

*Reviewed against GRSuite Ethos 2.3.1 page and shared-runtime source; not radio-tested.*
