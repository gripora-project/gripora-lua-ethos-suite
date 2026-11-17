# 3rd Party widget hooks provided by grsuite

This document explains the various hooks and APIs provided by **grsuite** for developing widgets and extensions for Rotorflight. It covers the lifecycle functions you can implement, how to register your widget, and how to leverage the grsuite session, tasks, telemetry, MSP, and utility APIs.

---

## Table of Contents

1. [grsuite APIs](#grsuite-apis)
2. [Example Widget](#example-widget)
3. [License](#license)

## grsuite APIs

grsuite exposes several subsystems under the global `grsuite` table.

### Session Data

* **Access**: `grsuite.session` contains read-only session info.

  * `craftName`, `modelID`, `apiVersion`, etc.

```lua
local name = grsuite.session.craftName or "-"
```

### Tasks API

* **Check active**: `grsuite.tasks.active()` returns `true` when grsuite is initialized.

### Telemetry API

* **Get source**: `grsuite.tasks.telemetry.getSensorSource(id)` returns a source object (if available).
* **Read value**: `source:value()` to fetch the latest reading.
* **Get value directly**: `grsuite.tasks.telemetry.getSensor(id)` returns `(value, unit, minor)` and can optionally accept `min/max/thresholds` overrides.


```lua
local grsuite = require("grsuite")
local rpmSensor = grsuite.tasks.telemetry.getSensorSource("rpm")
local rpm = rpmSensor and rpmSensor:value()
```

### MSP API

Use MSP to query the flight controller:

```lua
local grsuite = require("grsuite")
local API = grsuite.tasks.msp.api.load("GOVERNOR_CONFIG")
API.setCompleteHandler(function(self, buf)
  local mode = API.readValue("gov_mode")
  -- process mode
end)
API.setUUID("550e8400-e29b-41d4-a716-446655440000")
API.read()
```

* **Queue check**: `grsuite.tasks.msp.mspQueue:isProcessed()` to ensure no backlog.
* **Enqueue result**: MSP API `read()` / `write()` return queue status from `mspQueue:add(...)`:
  * `true, "queued", qid, pending`
  * `true, "queued_busy", qid, pending` (advisory pressure signal; request still queued)
  * `false, "duplicate", nil, pending`
  * `false, "busy", nil, pending` (only when hard cap is enabled)
* **Backoff guidance**:
  * Always set a stable UUID for periodic/retriggerable requests.
  * Treat `duplicate` / `busy` as explicit "back off and retry later".
  * For direct queue usage (outside API wrappers), check `ok, reason` and avoid advancing state when enqueue fails.

**MSP API delta cache (RAM vs delta writes)**:

* Enabled: keeps raw buffers and position maps (allows delta payloads).
* Disabled: keeps only parsed values (no delta payloads, lower RAM).

Defaults to disabled when the app GUI is not running. Override per API:

```lua
local API = grsuite.tasks.msp.api.load("STATUS")
API.enableDeltaCache(false)
```

Boolean semantics:

* `API.enableDeltaCache(true)` → delta cache enabled
* `API.enableDeltaCache(false)` → delta cache disabled

Or per-page via `apidata`:

```lua
local apidata = {
  api = {
    {id = 1, name = "STATUS", enableDeltaCache = false, rebuildOnWrite = true},
    {name = "RC_TUNING"}
  },
  formdata = {labels = {}, fields = {...}}
}
```

* `rebuildOnWrite = true` forces full payload writes for that API during `saveSettings`.
* `id = <number>` lets `mspapi = <number>` map by id instead of list order.

### Utilities

* **Logging**: `grsuite.utils.log(message, level)` where `level` is `"info"`, `"warn"`, or `"error"`.

```lua
local grsuite = require("grsuite")
grsuite.utils.log("Headspeed: " .. rpm, "info")
```

## Example Widget

Below is a widget that logs session info and telemetry every 5 seconds, using the full example code:

```lua
--[[
 * Copyright (C) Rotorflight Project
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3.
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
 *
 * Note: Some icons have been sourced from https://www.flaticon.com/
 *
 * This script is a simple widget that shows how you can access various
 * session variables from Rotorflight.
]]--
local grsuite = require("grsuite")

local environment = system.getVersion()
local lastPrintTime = 0
local printInterval = 5

local apiValue = nil

local function create()
    -- Create the widget
    local widget = {}
    return widget
end

local function configure(widget)
    -- Configure the widget (called by Ethos forms)
end

local function paint(widget)
    -- Paint the widget (on screen)
end

local function wakeup(widget)
    -- Handle the main loop
    local currentTime = os.clock()

    if currentTime - lastPrintTime >= printInterval then
        if grsuite and grsuite.tasks.active() then
            -- Log Rotorflight session information
            grsuite.utils.log("Craft Name: " .. (grsuite.session.craftName or "-"), "info")
            grsuite.utils.log("API Version: " .. (grsuite.session.apiVersion or "-"), "info")

            -- Read telemetry sensors
            local armflags = grsuite.tasks.telemetry.getSensorSource("armflags")
            grsuite.utils.log("Arm Flags: " .. (armflags:value() or "-"), "info")

            local rpm = grsuite.tasks.telemetry.getSensorSource("rpm")
            grsuite.utils.log("Headspeed: " .. (rpm:value() or "-"), "info")

            local voltage = grsuite.tasks.telemetry.getSensorSource("voltage")
            grsuite.utils.log("Voltage: " .. (voltage:value() or "-"), "info")

            -- MSP API - synchronous check example
            if apiValue == nil then
                local API = grsuite.tasks.msp.api.load("GOVERNOR_CONFIG")
                API.setCompleteHandler(function(self, buf)
                    local governorMode = API.readValue("gov_mode")
                    grsuite.utils.log("API Value: " .. governorMode, "info")
                    apiValue = governorMode
                end)
                API.setUUID("550e8400-e29b-41d4-a716-446655440000")
                API.read()
            else
                grsuite.utils.log("API Value: " .. (apiValue or "-"), "info")
            end
        else
            grsuite.utils.log("Init...", "info")
        end

        lastPrintTime = currentTime
    end
end

local function init()
    -- Register the widget
    local key = "rfgbss"
    local name = "Rotorflight API Demo"

    system.registerWidget({
        key = key,
        name = name,
        create = create,
        configure = configure,
        paint = paint,
        wakeup = wakeup,
        read = read,
        write = write,
        event = event,
        menu = menu,
        persistent = false,
    })
end

return { init = init }
```

## License

This widget framework is licensed under GPLv3. See [LICENSE](https://www.gnu.org/licenses/gpl-3.0.en.html) for details.
