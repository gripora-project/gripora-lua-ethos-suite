<p align="center">
  <picture>
    <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/gripora-project/gripora-website/master/branding/gripora_logo_white.svg">
    <img src="https://raw.githubusercontent.com/gripora-project/gripora-website/master/branding/gripora_logo_dark.svg" alt="Gripora" width="420">
  </picture>
</p>

# Gripora Lua Suite for Ethos

GRSuite puts a [Gripora](https://github.com/gripora-project/gripora-firmware) flight controller's
settings on a FrSky Ethos radio. At the field you can set up a model, retune it, read its logs and
check its status without a computer. Gripora is open-source flight controller firmware for
fixed-wing aircraft.

**[User guide](https://doc.gripora.org/ethos-suite/)** ·
**[Installing](https://doc.gripora.org/ethos-suite/installing/)** ·
**[Releases](https://github.com/gripora-project/gripora-lua-ethos-suite/releases)** ·
**[Discord](https://discord.gg/aEyyAJTXRw)**

| | |
| --- | --- |
| ![The dashboard widget](https://raw.githubusercontent.com/gripora-project/gripora-docs/main/docs/assets/images/ethos-suite/home-dashboard.png) | ![The app's main menu](https://raw.githubusercontent.com/gripora-project/gripora-docs/main/docs/assets/images/ethos-suite/root-menu.png) |
| ![The PID page](https://raw.githubusercontent.com/gripora-project/gripora-docs/main/docs/assets/images/ethos-suite/pids.png) | ![A flight log graph](https://raw.githubusercontent.com/gripora-project/gripora-docs/main/docs/assets/images/ethos-suite/logs-graph.png) |


## What it installs

- **The Gripora app**, opened from the radio's System menu. Its pages read settings from the
  flight controller over telemetry, let you change them and save them back.
- **A dashboard widget** for the model's home screen: arming state, battery, fuel, RPM, profile
  and flight count, with a choice of [themes](docs/dashboard-themes.md).
- **A background task** that keeps the link to the flight controller and plays callouts and
  alerts.


## What the app does

- **Flight tuning:** PIDs, rates, flight feel, filters, gain curves, flight modes and thrust
  vectoring
- **Tune Advisor:** reads your recent flights and suggests one gain change at a time
- **Setup:** ports, receiver, telemetry and controls; sensors and GPS navigation; mixer, curves
  and servos; power, ESCs, motors and the governor
- **Tools:** a setup wizard, profile copy and select, diagnostics and flight logs
- **Settings:** audio callouts, dashboard themes and radio preferences

The [user guide](https://doc.gripora.org/ethos-suite/) has a screen for every menu.


## Requirements

- A FrSky radio running **Ethos 1.6.2 or later**: X10, X12, X14, X18, X20 or Twin X Lite
- A receiver that carries telemetry to the radio:
  - FrSky, over S.Port or F.Port (ACCESS, ACCST, TD or TW receivers), or
  - ExpressLRS, on a module Ethos supports
- A suite version that matches your firmware. Each release says which firmware it is for.


## Installation

**With the updater.** The
[Gripora Radio Updater](https://github.com/gripora-project/gripora-lua-ethos-suite-updater/releases)
for Windows, macOS and Linux downloads the suite and copies it to the radio.

**By hand.** Download the zip for your language from the
[releases page](https://github.com/gripora-project/gripora-lua-ethos-suite/releases). Install it with
Ethos Suite (*Lua Development Tools* → *Install Lua Scripts*), or unzip it and copy the `grsuite`
folder into the radio's `scripts` folder.

Then turn on **Gripora [Background]** in the model's Lua page. The full steps are in
[Installing](https://doc.gripora.org/ethos-suite/installing/).


## Development

See [docs/dev-environment.md](docs/dev-environment.md) for the full setup. In short:

- Visual Studio Code with the `Ethos` extension
- Python 3; the deploy tasks install missing libraries on first run, or install them yourself:

  ```bash
  python -m pip install -r requirements.txt
  ```

VS Code tasks:

- **Deploy & Launch [SIM]** pushes the scripts to the simulator and starts it
- **Deploy Radio** pushes them to a connected radio
- **Deploy Radio + Serial Debug** does the same and opens the serial console

Contributor documentation is in [docs/](docs/README.md): system architecture, the MSP layer,
dashboard themes, translations and a [reference for every page](docs/pages/README.md).
[AGENTS.md](AGENTS.md) holds the rules for changing the code.


## Contributing

Gripora is a community project. You can help by:

- testing new versions and [reporting bugs](https://github.com/gripora-project/gripora-lua-ethos-suite/issues)
- helping other pilots on [Discord](https://discord.gg/aEyyAJTXRw)
- translating the suite, or keeping a translation up to date
- fixing bugs and adding features


## Origins

Gripora is open source and free of charge, with no warranty.

GRSuite is based on the [Wingflight Lua suite for Ethos](https://github.com/WingFlight/wingflight-lua-ethos-suite),
itself a fork of the [Rotorflight Lua suite for Ethos](https://github.com/rotorflight/rotorflight-lua-ethos-suite).
Thank you to everyone who contributed along the way.
