---
title: "PID Bandwidth"
sidebar_label: "PID Bandwidth"
sidebar_position: 50
documentation_status: reviewed
source: app/pages/pid_bandwidth.lua
---

# PID Bandwidth

The steering loop's filter cutoffs (MSP_PID_PROFILE). Only the steering (yaw) values
are shown, as on gripora-configurator's PID Controller Bandwidth panel.

## Where to find it

*Configuration* → *Tuning* → *PID Bandwidth* (under the *Advanced* group)

Requires a running background task and a flight controller connection.

The values belong to the current PID profile: the page title shows the profile it edits (for example *PID Bandwidth #1*), and the page reloads when the profile changes.

## Settings

| Setting | What it does |
| --- | --- |
| Gyro Cutoff | Steering PID loop overall bandwidth, in Hz. |
| D-term Cutoff | Steering D-term cutoff frequency, in Hz. |
| B-term Cutoff | Steering B-term cutoff frequency, in Hz. |

## Notes

- The roll and pitch cutoffs are not shown; the page writes them back unchanged.


## Source

[Page implementation](../../../src/grsuite/app/pages/pid_bandwidth.lua). Menu conditions come from `app/tool.lua`.

*Documented against GRSuite Ethos 2.3.1.*
