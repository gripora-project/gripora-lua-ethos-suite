# 0.0.4

First Gripora release of the Ethos suite, for RC cars. Require MSP API 33.0 (the 0.0.2 firmware and later; the 0.0.4 firmware for the drive telemetry); WingFlight and Gripora 0.0.1 firmware are refused. It installs to SCRIPTS:/grsuite, so it can sit beside the WingFlight suite.
Add the drive aids under Tuning, per PID profile: ABS (with each pulse rate beside its hold), Traction and Launch (Off/Switch, Start Throttle, Ramp Time).
Add a Drift page under Tuning > Steering: Counter Gain, Allowed Rate and Counter Limit. Firmware without drift mode shows it greyed out.
Add a Drive page under ESC & Motors.
Add the DRIFT, LAUNCH and DRIVE AIDS OFF modes to the Modes page and the Setup Wizard's modes step. Fix the wizard saving GYRO OFF to a mode the firmware no longer has.
Add the Drive Status and Wheel Speed telemetry sensors (0.0.4 firmware), in place of altitude and variometer in the default sensor list.
Change the dashboards for a car: a drive aids tile (GYRO OFF, ABS, TC, LAUNCH, DRIFT, AIDS OFF) replaces the governor, a car tilt view replaces the artificial horizon, and Top Speed replaces Altitude Max. ActiveLook gets Speed, Top Speed and Drive Aids.

Change the menus to match the Gripora Configurator: Tuning has Steering (PIDs, Rates, Driving Feel, Drift), Drive Aids and Advanced, with steering only. Remove Tune Advisor, Autolevel, Thrust Vector, Governor, GPS Navigation and GPS Rescue.
Change the Setup Wizard for a car: the car channel order (CH1 steering, CH2 throttle), detected from the wheel and then the trigger; steering servos only, named STEER, F STEER / R STEER; no aircraft throws and travel steps.
Show a low-poly car on the Alignment page and in the wizard's Sensors step.
Name receiver functions Steering, Throttle and AUX 1-4 on the Failsafe and Mixer Rules pages; Mixer Rules offers only None as a rule role.
Set motor override to -100..+100 for reversible ESCs, and the speed attenuation top speed to 10..300 km/h (default 60).
Rename the telemetry sensors the suite creates to Steering Control and Drive Mode (were Yaw Control and Flight Mode); sensors already on the radio keep their names.
Change the wording throughout for a car: controller, car name, and runs instead of flights.
Show each submenu's own title in its header, and plain page titles instead of paths.
Fix "Max instructions count reached" on the dashboard at first boot.
