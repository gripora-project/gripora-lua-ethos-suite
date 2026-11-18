---
title: "RPM"
sidebar_label: "RPM"
sidebar_position: 60
documentation_status: draft
source: app/pages/esc_motors_rpm.lua
---

# RPM

> Draft scaffold. Extracted labels may be incomplete or out of order. Behaviour,
> displayed units, defaults and save effects require source review.

TODO: Explain what this page controls and when a pilot would use it.

## Where to find it

*Configuration* → *Setup* → *ESC & Motors* → *RPM*

Requires a running background task and a flight controller connection.

## Settings

| Setting | What it does |
| --- | --- |
| RPM Sensor | TODO: explain behaviour, displayed units, range and conditions. |
| DShot RPM Telemetry | TODO: explain behaviour, displayed units, range and conditions. |
| Motor 1 Gear Ratio (Motor) | TODO: explain behaviour, displayed units, range and conditions. |
| Motor 1 Gear Ratio (Wheel) | TODO: explain behaviour, displayed units, range and conditions. |
| Motor 2 Gear Ratio (Motor) | TODO: explain behaviour, displayed units, range and conditions. |
| Motor 2 Gear Ratio (Wheel) | TODO: explain behaviour, displayed units, range and conditions. |
| Motor Pole Count | TODO: explain behaviour, displayed units, range and conditions. |

## Notes

TODO: Verify persistence, reboot behaviour, profile scope and any restrictions in
this page and its shared helpers. Codec defaults may be UI fallbacks rather than
firmware defaults; wire values may need scaling before display.

## Source

[Page implementation](../../../src/grsuite/app/pages/esc_motors_rpm.lua). Menu conditions come from `app/tool.lua`.

*Scaffolded against GRSuite Ethos 2.3.1; content awaiting review.*
