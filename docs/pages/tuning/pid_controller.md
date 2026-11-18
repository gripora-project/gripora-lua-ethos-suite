---
title: "PID Controller"
sidebar_label: "PID Controller"
sidebar_position: 40
documentation_status: reviewed
source: app/pages/pid_controller.lua
---

# PID Controller

Steering PID controller settings (MSP_PID_PROFILE), as on gripora-configurator's PID
Controller Settings panel.

## Where to find it

*Configuration* → *Tuning* → *PID Controller* (under the *Advanced* group)

Requires a running background task and a flight controller connection.

The values belong to the current PID profile: the page title shows the profile it edits (for example *PID Controller #1*), and the page reloads when the profile changes.

## Settings

| Setting | What it does |
| --- | --- |
| I-Term Decay Max Rate | Maximum speed, in °/s, at which accumulated I-term error bleeds off. Only matters for large accumulated errors; leave at the default. The decay time is on *Driving Feel*. |
| I-Term Relax Level | Steering movement, in °/s (default 22), at which I-term build-up is fully suppressed during a fast move. Lower values suppress more strongly. The main setting is Relax on *Driving Feel*; leave the level at the default unless that is not enough. |
| Error Limit | Hard limit, in °, for the steering error in the PID loop. The error, and so the I-term, never goes above it. |

## Notes

- The roll and pitch values and the cross-axis, snap and prop-hang relax settings are
  not shown (a car only stabilises yaw); the page writes them back unchanged.


## Source

[Page implementation](../../../src/grsuite/app/pages/pid_controller.lua). Menu conditions come from `app/tool.lua`.

*Documented against GRSuite Ethos 2.3.1.*
