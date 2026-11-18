---
title: "Rate Response"
sidebar_label: "Rate Response"
sidebar_position: 80
documentation_status: reviewed
source: app/pages/rates_advanced.lua
---

# Rate Response

How the steering setpoint responds to the stick (MSP_RC_TUNING): smoothing, boost and
the steering dynamics. Only the steering (yaw) values are shown.

## Where to find it

*Configuration* → *Tuning* → *Rate Response* (under the *Advanced* group)

Requires a running background task and a flight controller connection.

The values belong to the current rate profile: the page title shows it (for example
*Rate Response #1*), and the page reloads when the rate profile changes.

## Settings

| Setting | What it does |
| --- | --- |
| Response Time | Smooths steering inputs. Larger values smooth more. |
| Accel Limit | Limits how fast the steering setpoint may change; 0 is no limit. Not shown on the Configurator, still used by the firmware. |
| Setpoint Boost Gain | Boosts steering inputs for a snappier feel. |
| Setpoint Boost Cutoff | Cutoff of the boost, in Hz. |
| Dynamic Ceiling Gain | Reduces the stick travel needed for full steering rate while the stick moves quickly towards full lock. |
| Dynamic Deadband Gain | Widens the steering deadband while the stick moves quickly back towards centre. |
| Dynamic Deadband Filter | Smoothing for the stick speed that drives the dynamic ceiling and deadband. |

## Notes

- The roll and pitch values are not shown; the page writes them back unchanged.


## Source

[Page implementation](../../../src/grsuite/app/pages/rates_advanced.lua). Menu conditions come from `app/tool.lua`.

*Documented against GRSuite Ethos 2.3.1.*
