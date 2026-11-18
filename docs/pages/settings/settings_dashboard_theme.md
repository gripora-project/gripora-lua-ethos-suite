---
title: "Themes"
sidebar_label: "Themes"
sidebar_position: 10
documentation_status: draft
source: app/pages/settings_dashboard_theme.lua
---

# Themes

> Draft scaffold. Extracted labels may be incomplete or out of order. Behaviour,
> displayed units, defaults and save effects require source review.

TODO: Explain what this page controls and when a driver would use it.

## Where to find it

*System* → *Settings* → *Dashboard* → *Themes*

Available without a flight controller connection; the background task must be running.

## Settings

| Setting | What it does |
| --- | --- |
| TODO | Inspect the page and its helpers; automatic extraction found no controls. |

## Notes

- If the settings file cannot be written, a *Save failed* dialog is shown and the page
  stays unsaved, so *Save* remains available for a second attempt (rotorflight-lua-ethos-suite
  Issue #2500).
- The page writes two files: the radio's global settings, then the model's dashboard
  override. If only the model's copy cannot be written, the global part is already saved;
  the dialog says so and names the model, rather than reporting the whole save as lost.

TODO: Verify persistence, reboot behaviour, profile scope and any restrictions in
this page and its shared helpers. Codec defaults may be UI fallbacks rather than
firmware defaults; wire values may need scaling before display.

## User themes

Themes in folders under `SCRIPTS:/grsuite.user/dashboard/<folder>/` are listed
after the shipped themes, under their folder names, in every theme field on this
page. The folder is read again each time the page opens. A user theme that
cannot be loaded is drawn as **Default**. This page shows **Default** for a
theme whose folder is gone, and saving the page stores that. See
[Dashboard themes](../../dashboard-themes.md) for the folder layout.

## KSE4 and KSE5

**KSE4** (`system/kse4`) and **KSE5** (`system/kse5`) follow the layouts of
Kyle Stacy's [KSE dashboards](https://github.com/kylestacy2/KSE-Dashboards).
They draw every tile in the Ethos theme's colours, so the radio's theme picks
the palette. Each has its own screen for before, during and after a run.

**KSE4** is a tile dashboard.

- **Before a run**: model image and run count, a large RPM tile beside the
  run timer, and a strip with current, pack voltage, BEC voltage and ESC
  temperature. The bottom row has the arming state and a battery or fuel bar.
- **During a run**: large RPM and timer tiles, a strip with current, cell voltage,
  ESC temperature and throttle, then the arming state and the fuel bar.
- **After a run**: run time, consumed mAh and remaining fuel across the top,
  then the run's peaks and lows: maximum RPM, current, power, throttle and
  ESC temperature, and minimum cell voltage, BEC voltage and link.

**KSE5** is a ring dashboard.

- **Before a run**: four rings for battery or fuel, RPM, current and ESC
  temperature. Below them are the model image, the run count, and tiles for
  the arming state, BEC voltage, cell voltage and consumed mAh.
- **During a run**: a large battery or fuel ring, smaller RPM and ESC temperature
  rings with the timer and arming state below them, and a row with current, cell
  voltage, BEC voltage and throttle.
- **After a run**: rings for the lowest fuel and the highest RPM, current and
  ESC temperature, then run time, consumed mAh, minimum cell and BEC
  voltage, maximum power and minimum link.

Set the full-scale RPM, current and ESC temperature of the KSE5 rings in
[Dashboard Settings](settings_dashboard_settings.md). The after-run figures fill
in once a run has been recorded.

## Source

[Page implementation](../../../src/grsuite/app/pages/settings_dashboard_theme.lua). Menu conditions come from `app/tool.lua`.

*Scaffolded against GRSuite Ethos 2.3.1; content awaiting review.*
