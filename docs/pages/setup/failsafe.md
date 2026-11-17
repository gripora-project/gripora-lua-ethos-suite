---
title: "Ch. Fallback"
sidebar_label: "Ch. Fallback"
sidebar_position: 10
documentation_status: draft
source: app/pages/failsafe.lua
---

# Ch. Fallback

> Draft scaffold. Extracted labels may be incomplete or out of order. Behaviour,
> displayed units, defaults and save effects require source review.

TODO: Explain what this page controls and when a pilot would use it.

## Where to find it

*Configuration* → *Setup* → *Controls* → *Failsafe* → *Ch. Fallback*

Requires a running background task and a flight controller connection.

## Settings

| Setting | What it does |
| --- | --- |
| Steering, Throttle, AUX 1–4, CH #9–#24 | One row per function: the fallback mode (Auto, Hold or Set) and, for Set, the value in µs. Steering, Throttle and AUX 1–4 are functions, whatever receiver channel the channel map puts them on; from CH #9 the rows are receiver channels. Roll and pitch, which a car doesn't use, have no row: their settings are kept as they are. |

## Notes

TODO: Verify persistence, reboot behaviour, profile scope and any restrictions in
this page and its shared helpers. Codec defaults may be UI fallbacks rather than
firmware defaults; wire values may need scaling before display.

## Source

[Page implementation](../../../src/grsuite/app/pages/failsafe.lua). Menu conditions come from `app/tool.lua`.

*Scaffolded against GRSuite Ethos 2.3.1; content awaiting review.*
