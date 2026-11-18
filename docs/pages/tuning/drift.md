---
title: "Drift"
sidebar_label: "Drift"
sidebar_position: 29
documentation_status: reviewed
source: app/pages/drift.lua
---

# Drift

Gripora's drift mode settings for the current PID profile, as in the Drift panel of
gripora-configurator's PID Profiles tab.

Drift mode is turned on by a switch: put the *DRIFT* mode on a switch on the Modes page.
While DRIFT is on, the steering wheel steers the wheels directly, as with GYRO OFF, so you
set the wheel angle. The gyro only catches over-rotation: it counter-steers against the
turn rate beyond the allowed rate, which lets the car hold a slip angle and catches it
when it spins further. There is no heading hold (no I-term), so leaving DRIFT starts
clean. The throttle and speed attenuation and the standstill and reverse handling apply
as they do normally. GYRO OFF and failsafe take precedence over DRIFT.

## Where to find it

*Configuration* → *Tuning* → *Drift* (under the *Steering* group)

Requires a running background task and a flight controller connection.

The settings belong to the current PID profile: the page title shows the profile it
edits (for example *Drift #1*), and the page reloads when the profile changes.

## Settings

| Setting | What it does |
| --- | --- |
| Counter Gain | How hard the gyro counter-steers once the car turns faster than the allowed rate. At 100 % it gives full lock 360 °/s past the allowance; 200 % gets there twice as soon, and 0 % turns the counter-steer off (DRIFT is then the same as GYRO OFF). Range: 0 to 200 %. Default: 100 %. |
| Allowed Rate | The turn rate the gyro leaves alone, so the car can hold a slip angle. Raise it to hold more angle, lower it for the gyro to catch the car sooner. Range: 0 to 720 °/s. Default: 30 °/s. |
| Counter Limit | The most lock the gyro adds, as a share of full lock. Lower it if the counter-steer snaps the car straight. Range: 10 to 100 %. Default: 100 %. |

A line under the fields reminds you that the DRIFT switch (Modes page) turns drift mode on.

## Notes

- Saving writes the settings to the flight controller EEPROM. The firmware uses them
  at once; no reboot.
- Save is refused while the model is armed.
- Each PID profile has its own drift settings. Copying a profile copies them, and
  resetting the current PID profile resets them to the defaults.
- The firmware refuses the whole save if any value is out of range.
- Firmware without drift mode answers the message as unsupported: the page still opens,
  with all three fields greyed out, and saves nothing.

## Source

[Page implementation](../../../src/grsuite/app/pages/drift.lua), codec `lib/msp_drift_config.lua` (MSP2_GRIPORA_DRIFT_CONFIG /
MSP2_GRIPORA_SET_DRIFT_CONFIG, 0x5F42 / 0x5F43). Menu conditions come from
`app/tool.lua`.

*Documented against GRSuite Ethos 2.3.1.*
