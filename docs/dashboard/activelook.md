# ActiveLook

The Gripora ActiveLook widget displays up to four values on the EnGo 2's
304 x 256 pixel display. Each run phase (before, during and after a run) has
its own layout and slot
assignments. ActiveLook preferences are stored on the transmitter in
`SCRIPTS:/grsuite.user/settings.ini`; they are not flight-controller EEPROM
settings.

## Configure

Open **System -> Settings -> ActiveLook** on the transmitter. All four pages
are available offline.

The **Settings** page enables the widget, chooses an optional switch to blank
the display, and sets horizontal and vertical offsets from -20 to +20 pixels.
The **Before Run**, **During Run** and **After Run** pages each select one of five
layouts and assign values to up to four slots. Layouts are Two Top + One
Bottom, Two Top + Two Bottom, Single Centered, One Top + Two Bottom, and
Stacked Large + Large + Small. Layouts that use fewer than four positions
disable the unused slots.

Selectable values include the run phase (PRE, RUN, POST), timer, arm status,
ESC and MCU temperature, link, fuel, current, voltage, cell voltage, motor
RPM, and consumed capacity. Min/max slots are available for fuel, current,
voltage, RPM and link; maximum-only slots are available for ESC and MCU
temperature.

## Run phases and statistics

The widget starts before a run. A fresh disarmed-to-armed transition starts a
new one; the run begins when the car is armed and connected and the flight
controller's System Status reports it running (set once the throttle has left
neutral, held until disarm). Without the System Status sensor, the mapped
transmitter throttle more than 10% away from neutral, forward or reverse,
starts the run; FC `throttle_percent` is the fallback until RX_MAP is available.

Once a run has begun, the phase stays there while the car remains armed, even
if the throttle returns to neutral or telemetry briefly drops out. Disarming
after a run shows the after-run page. Losing the connection during a run also
changes the display to the after-run page.

Min/max statistics are collected only during a run. They reset when a new run
begins and remain available after it. Select a Min/Max slot to display an
extreme value.

## Simulator preview

Run **ActiveLook Preview** from the VS Code task or launch configuration. It
reads sensor profiles from the configured Ethos simulator's
`scripts/grsuite/sim/sensors` folder and loads/saves phase layouts and slots in
`scripts/grsuite.user/settings.ini`. If the settings file does not exist yet,
the first preview save creates it. Saving preserves unrelated INI sections and
rejects stale edits if the file changes concurrently.

The preview uses Gripora slot IDs, including `rpm`, `rpm_min` and `rpm_max`.
For profiles that return `math.random(...)`, it samples the configured range;
it cannot read the exact random sample currently held by the simulator. The
preview edits layouts and slots, not the widget enable switch or display
offsets.

## Source

Widget logic: `src/grsuite/widgets/activelook.lua`. The run phase comes from the session
(`src/grsuite/lib/flight_stats.lua`), the same one the dashboard shows. Settings and slot definitions:
`src/grsuite/lib/activelook_config.lua`. Simulator preview:
`bin/activelook_preview/`.