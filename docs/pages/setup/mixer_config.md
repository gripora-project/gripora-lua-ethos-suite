---
title: "Mixer"
sidebar_label: "Mixer"
sidebar_position: 80
documentation_status: reviewed
source: app/pages/mixer_config.lua
---

# Mixer

Scale or invert the stabilized steering before mixer rules use it, and set the steering gyro direction. Scaling changes every rule that reads the stabilized steering. A car only stabilises yaw, so roll and pitch are not shown.

## Where to find it

*Configuration* → *Setup* → *Mixer*

Requires a running background task and a flight controller connection.

## Settings

| Setting | What it does |
| --- | --- |
| Steering: Throw | Steering input gain, 0–200%, adjusted in steps of 5%. |
| Steering: Invert | Normal or Inverted: changes the sign of the steering input. |
| Gyro Direction | Normal or Inverted: reverses the steering gyro (yaw_gyro_reverse), for a controller whose gyro corrects the wrong way. Greyed out on firmware older than MSP API 33.0. |

## Notes

Save writes the steering input and the mixer config (with the gyro direction) and commits them to EEPROM. These are car-wide settings, independent of the selected PID or rate profile. This page does not request a reboot.

The roll and pitch inputs are not written. The stored input limits and the other mixer config fields are preserved when saving. To edit which outputs receive an input, use [Mixer Rules](mixer_rules.md).

## Source

[Page implementation](../../../src/grsuite/app/pages/mixer_config.lua). Menu conditions come from `app/tool.lua`.

*Reviewed against GRSuite Ethos 2.3.1 page and shared-runtime source; not radio-tested.*
