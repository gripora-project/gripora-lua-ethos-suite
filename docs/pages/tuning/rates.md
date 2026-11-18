---
title: "Rates"
sidebar_label: "Rates"
sidebar_position: 20
documentation_status: reviewed
source: app/pages/rates.lua
---

# Rates

The steering rate curve: how far and how fast the car is asked to turn for a given
steering stick (MSP_RC_TUNING). Only the steering row is shown.

## Where to find it

*Configuration* → *Tuning* → *Rates* (under the *Steering* group)

Requires a running background task and a flight controller connection.

The values belong to the current rate profile: the page title shows it (for example
*Rates #1*), and the page reloads when the rate profile changes.

## Settings

| Setting | What it does |
| --- | --- |
| RC Rate | Steering rate around centre stick. |
| Rate | Steering rate at full stick. |
| RC Expo | Softens the stick around centre. |

## Notes

- The largest value of each field is set by the firmware, not by the page: RC Rate
  up to 200, Rate and RC Expo up to 100 (`src/main/fc/rc_rates.h:25-27`). A value saved
  above the limit is cut to the limit at the next boot.
- The roll and pitch rates are not shown; the page writes them back unchanged.


## Source

[Page implementation](../../../src/grsuite/app/pages/rates.lua). Menu conditions come from `app/tool.lua`.

*Documented against GRSuite Ethos 2.3.1.*
