---
title: "Gain Curves"
sidebar_label: "Gain Curves"
sidebar_position: 70
documentation_status: reviewed
source: app/pages/gain_curves.lua
---

# Gain Curves

Assigns a gain curve to the steering Driving Feel Gain, to Throttle and to Speed. A
curve shapes Gain by steering stick deflection on the Steering row, by throttle on the
Throttle row, and by GPS speed on the Speed row. The curve shapes are edited on *Curves*.

## Where to find it

*Configuration* → *Tuning* → *Gain Curves* (under the *Advanced* group)

Requires a running background task and a flight controller connection.

The values belong to the current PID profile: the page title shows the profile it edits (for example *Gain Curves #1*), and the page reloads when the profile changes.

## Settings

| Setting | What it does |
| --- | --- |
| Steering | Gain curve slot (None, Curve 1-8) that shapes the steering Gain by stick deflection (the same both ways). None applies Gain as set. |
| Throttle | Gain curve slot that shapes the Throttle gain by throttle. |
| Speed | Gain curve slot that shapes the Speed gain by GPS speed. None turns it off. Needs a GPS with a fix; if the fix is lost the attenuation holds for 3 s, then eases back to 100 %. |
| Speed Range | GPS speed, in km/h (10-300, default 60), at the right edge of the Speed curve. Faster than this uses the curve's last point. |

## Notes

- The roll and pitch curve assignments are not shown; the page writes them back unchanged.


## Source

[Page implementation](../../../src/grsuite/app/pages/gain_curves.lua). Menu conditions come from `app/tool.lua`.

*Documented against GRSuite Ethos 2.3.1.*
