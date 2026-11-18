---
title: "State callouts"
sidebar_label: "State callouts"
sidebar_position: 40
documentation_status: reviewed
source: app/pages/settings_audio_events_state.lua
---

# State callouts

Callouts triggered when a discrete state or mode changes on the car or transmitter.

## Where to find it

*System* → *Settings* → *Audio* → *Events* → *State callouts*

Available without a flight controller connection; the background task must be running.

## Settings

| Setting | What it does |
| --- | --- |
| *Arming flags* | Calls out reasons why the car cannot arm when arming is attempted. |
| *Mode state* | Calls out mode changes: *Gyro off* when GYRO OFF is switched on, *Failsafe*, and *Normal* when they end. |
| *GPS fix* | Calls out when GPS lock is acquired or lost. |
| *PID profile* | Calls out changes to the active PID profile index. |
| *Rate profile* | Calls out changes to the active Rate profile index. |
| *Battery profile* | Announces the selected battery profile (capacity and cell count). |
| *Adjustment function* | Calls out the name of the adjustment function being changed while driving, followed by its value. |
| *Adjustment value* | Calls out the value an adjustment has settled on. |

## Notes

- Changes are saved to the radio's settings store, not to the flight controller.
- These events are triggered on transition edges rather than periodically.
- **Adjustments** are called out once the value has stopped changing for about a third of a second. A burst of trim clicks therefore says one number, the one the car ended up with, rather than each step. Nothing is said while the value is still moving. A change that settles while the previous callout is still playing is called out after it.
- **Several changes at once** are spoken one after another, not on top of each other. The arming, PID profile, rate profile and battery profile callouts each wait until the previous one has finished. A change that has to wait is spoken then, once, and is not dropped.

## Source

[Page implementation](../../../src/grsuite/app/pages/settings_audio_events_state.lua). Menu conditions come from `app/tool.lua`.
