---
title: "Setup Wizard"
sidebar_label: "Setup Wizard"
sidebar_position: 90
documentation_status: reviewed
source: app/pages/setup_wizard.lua
---

# Setup Wizard

> **Put the car on a stand with its wheels off the ground.** The wizard turns the
> steering itself, and the ESC step runs the motor forward and in reverse. It puts
> the controller in its setup state, which blocks arming while the wizard is open.

Sets a car up from the radio, step by step, at the track and without a computer.
It is the radio's copy of the Configurator's car Setup Wizard: the same questions
and the same rules, as a guided sequence for a radio screen. Each screen asks one
thing, with a picture or a live value and one or two big buttons.

The pictures show the car seen from above, nose up, with its front wheels and,
when the mix has rear steering, its rear wheels. A check lights the steering
wheels in orange, turns them the way they should go and draws an arrow ahead of
them; the gyro check also draws how you turn the car by hand. On a screen with a
picture the picture is on the left and the words on the right. Where there is
room, mostly on the bigger radios, the text is larger. A choice such as the servo
type, the ESC protocol or how the ESC reverses is a list: each option has its own
button with what it means beside it, and the current one is lit. The Sensors step
shows a 3D car. The Receiver step draws steering across and throttle up and down
in one square, with the corner to go to marked; on a small screen it shows only
the bars.

## Where to find it

*System* → *Tools* → *Setup Wizard*

Requires a running background task and a controller connection. The controller
firmware must support MSP API 33.0 or newer, as the whole suite does; it refuses
older firmware when it connects.

The wizard works on every servo in use, up to 24, whether it is on a PWM output,
a bus channel (SBUS, F.Bus) or both.

## Moving around

The title shows the step number and name. An amber notice line appears under it
only when something stops the wizard moving the steering (see below), including
**Switch GYRO OFF mode off**.

- Every screen has one row of buttons along the bottom, always in the same
  order. **Back** (‹) is a small button at the left end: the screen before, or
  the step before from a step's first screen (step 1 has none). The screen's
  own buttons (**Start**, the ± steps, answers) are in the middle, set apart
  from the two ends. The way forward is at the right end: **Next** (›), which
  becomes **Save and continue** once something has changed (it writes the
  changes to EEPROM and opens the next step), **Save and restart** where the
  change needs a restart, and **Save and finish** on the last step. **Next** on
  a step's first screen leaves that step as it is. On a screen that asks a
  question, the answers are the way forward.
- The **checklist** button in the header opens the list of all 15 steps; tap one
  to go to it. Back from the list returns to the step.
- **Save** in the header writes the changes at any time.
- **Save and restart** (steps whose settings apply after a restart) shows a
  *Restarting...* dialog while the controller restarts. Its bar fills and its
  message counts down the seconds left (at most 20). The dialog closes as soon as
  the controller is back, and the wizard reloads on the same step.
- The wizard reopens on the step it was on, for the rest of the radio session.
- A step whose change still needs a restart (Servo bus, ESC, ESC telemetry) keeps
  offering **Save and restart** until the wizard has restarted the controller,
  also after you leave the step or the wizard and come back. Until then it does
  not check the ESC or the wiring.
- A step that works on the steering servos, on a car with none mixed yet, offers
  **Set up the model** instead.

## The steps

| Step | What happens |
| --- | --- |
| 1. Sensors and level | Calibrate the accelerometer (hold the car level and still), find the board orientation automatically (flat, Start, lift the rear 20°: a picture of the car shows the lift), check it on a live 3D car that must follow the car as you tilt it, and set level automatically (the car on its wheels on a level surface). Board orientation applies after a restart: the step ends with **Save and restart**, and the wizard reopens on this step when the controller is back. |
| 2. Receiver | Checks steering and throttle, the only two controls a car has: wheel full left and trigger at full brake, and both bars should go left. The text says which channels they are on. When the order is not the car order (CH1 steering, CH2 throttle, as car radios send), **Car order** sets it. **Bars are wrong** finds the order by turning the wheel, then pulling the trigger, and writes the RX map. Aux 1-4 take the lowest of CH1-CH8 left over, and roll and pitch, which a car doesn't use, are parked on the two highest (CH7 and CH8 with the car order). A reversed bar is fixed on the radio. Receiver port and protocol setup stays in the Configurator, because the radio talks to the controller through the receiver. |
| 3. Servo bus | Optional, for servos on an F.Bus or SBUS line plugged into a serial port, which gives the car more servos than the board has servo pins for. Servo 1 is channel 1 on the bus, servo 2 is channel 2, and so on. Choose **None** or a free port; on boards with a connector labelled S.BUS that port is where the selection starts. Then choose **F.Bus** or **SBUS** and how many channels the bus carries. A port or protocol change applies after a restart (**Save and restart**), and the wizard reopens on this step. For F.Bus it then shows how many servos and sensors answer on the bus: only devices that have answered in the last couple of seconds count, so one that was unplugged drops out. If none answers, press **Detect wiring** with the bus powered: the controller tries each pin of the port and both signal polarities until a device answers, which takes a few seconds; **Stop** ends it early. A wiring found this way is in use at once and needs no restart: the way forward becomes **Save and continue**, and Discard puts the old wiring back. The controller refuses the test while armed and on boards with an F.Bus mux. On firmware without wiring detection the button becomes **Use the other pin**, which needs **Save and restart**. SBUS is one-way, so it is checked in the later steps, where each servo is moved. |
| 4. Model | **Car** or **Custom**. Shows what the car has (steering on S1, the ESC on M1, and any rear steering or second ESC). **Car** (or **Change options** when the car preset is already there) asks about rear steering (**None**, **Opposite** to the front wheels for tighter turns, or the **Same way** for crab steering, and how far the rear wheels turn, in 5 % steps) and a second ESC on M2 (same throttle as M1, forward, brake and reverse), with a picture of the result, then **Apply** writes the whole mix and the model type. Applying also puts the stabilized throttle's lower limit back to -1000 if it was clamped, so brake and reverse reach the ESC. Steering and throttle weights stay positive: a wheel that turns the wrong way is fixed on the Steering direction step. The servos the mix assigns are named, as the Configurator does; a name the wizard gave to a servo the new mix no longer uses is cleared, a name you typed there is kept, and leaving without saving puts the names back. **Custom** keeps the rules as they are (they are edited in Mixer Rules) and only sets the model type. Rules changed by hand are flagged. |
| 5. Servo type | Analog (50 Hz) or digital (333 Hz) for the steering servo. It sets the one PWM update rate of every PWM servo output, the same setting as **PWM update rate** on the Servos page, and changes no servo's centre, limits or scale. Digital is for digital servos only: check that your servo supports it. Applies after a restart (**Save and restart**). |
| 6. ESC | Standard PWM, DShot150 or DShot300, or any other protocol from the **Other** drop-down (No motor, DShot600, OneShot, ProShot, Castle Link, SRXL2, ...). DShot150 has no bidirectional DShot RPM telemetry: choosing it in the wizard also turns bidirectional DShot off, and while it is set the step notes that motor RPM needs DShot300 or an RPM or ESC telemetry source. A protocol change applies after a restart (**Save and restart**). **Check ESC**, once the protocol in use is the one set: first how the ESC reverses (**Automatic**, **Brake, then reverse**, **Reverse directly**, **Forward and brake only**; Automatic says what it picks for the protocol), written straight away with no restart; firmware without drive state skips this screen. Without motor RPM the screen notes that the gyro stays fully active at a standstill. Then confirm the wheels are off the ground, and check neutral: the controller sends neutral to the ESC as the middle of the throttle range, and the live throttle stick reading shows whether it is at centre (it is lit while off centre). Calibrate the ESC to that neutral. Last, the direction check: **Forward** or **Reverse** runs one motor at 5, 10 or 20 % for 3 seconds and stops by itself, and **Stop** ends it early; many ESCs brake first, so run **Reverse** again. On a car with more than one motor a **Motor 1** button picks which one runs. Stop, Back, the step list, Save, leaving the step, arming and a lost link all drop the output to zero. |
| 7. ESC telemetry | Optional, for an ESC with a telemetry wire plugged into a serial port. Choose **Not used** or the ESC's telemetry protocol from the drop-down, then the port the wire is on: only free ports can be chosen, and the one in use now is lit. A change applies after a restart (**Save and restart**), and the wizard reopens on this step, on the wiring screen. There, power the ESC and press **Detect wiring**: the controller tries each way the wire can be connected until the ESC answers. If the ESC answers on a different wiring than the one set, the wizard writes it and asks for **Save and restart** again. The last screen asks whether the battery voltage, and the current and mAh used, come from the ESC. **Not used** turns ESC telemetry off, frees its port and takes the battery meters off the ESC. FrSky F.BUS and SRXL2 telemetry don't use an ESC telemetry port; with the Castle Link protocol the telemetry is read on the throttle wire. A car with no motor set up has nothing to set up here. |
| 8. Center | The steering is held at center. One screen per steering servo: −10/−1/+1/+10 µs until the wheels point straight ahead. **Identify** rocks only the selected servo gently either side of center for 3 seconds, then centers it again; adjusting or leaving stops it early. More than 100 µs from the normal centre, 1500 µs, is flagged: move the horn instead. |
| 9. Steering direction | The wizard turns the steering itself and asks **Like this** / **Not like this** against a picture of the car seen from above. See below. |
| 10. Binding limits | One screen per side of each steering servo (servo 1 Min, servo 1 Max, servo 2 Min, ...), counted together. The intro pictures the method on three servo dials: step until the steering binds, back off one step, **Set**. On each screen the servo is held by a probe that ignores the stored limits, and a dial shows its horn. Step it with −50/−10/+10/+50 µs; **Set** saves this side only and moves to the next screen. **Next** skips the side and keeps its old limit. These limits protect the servo from binding; how far the wheels turn is set in Mixer Rules. |
| 11. Gyro direction | No override: the gyro drives the steering. With the wheels off the ground, turn the car clockwise by hand (nose to the right, seen from above): the front wheels should steer left, against the turn. If the steering was right on the Steering direction step but corrects the wrong way here, **Reverse the gyro** sets `yaw_gyro_reverse`, which reverses only the yaw rate the steering loop uses and works at once: check again. Firmware without it says to update the firmware. Reverse needs no setup: the controller turns the correction round by itself while the car drives backwards. With motor RPM the gyro only corrects once the car is moving, so at a standstill the step says why the steering doesn't answer. |
| 12. Trim and gain | Steering trim: trim buttons on one channel (the controller keeps the trim), a trim channel (the radio keeps it), or no trim channel. The screen says what to set up in the radio's mixes (the VX10's steering trim is T1), then **Detect** finds the channel when you press the trim. Gain: one knob or none (a knob per axis from an earlier setup is shown and kept); turn the knob end to end to find it (0–150 %, centre 75 %). Only the steering is set up; roll and pitch adjustments are left as they are. |
| 13. Mode switches | One screen per mode the controller offers (ARM, GYRO OFF, DRIVE AIDS OFF): **Assign** / **Change**, then flick the switch to its on position; **Remove** clears it. Only ARM is required. |
| 14. Driving style | Beginner, Sport or Drift: the steering rate (°/s at full steering, expo) and I-term relax for steering, on the current rate and PID profiles. Roll and pitch are left as they are. |
| 15. Finish | What the wizard set (model, steering servos, ESC protocol, ESC telemetry, driving style, ARM switch), then the checks before the first run, and **Save and finish**. |

## Steering direction

The picture is the car **seen from above**, nose up. The steering wheels are
lit and turned the way they should go, with an arrow ahead of them. The wizard
flicks the steering between centre and the test movement (25 %, or 35, 50 or
15 % with **Move**): *Steer right*. The front wheels should steer right; rear
wheels steer left when set to opposite, or right when set to the same way.

**Not like this** with more than one steering servo asks **All of them** or
**Only some**. *Only some* wiggles each servo in turn and asks whether it moved
the wrong way (focus starts on **No**). Then, as in the Configurator:

- one servo wrong on steering alone: its servo is reversed;
- every steering servo wrong: the steering is inverted (its Axis Throw negated);
- a wrong servo that also works another axis is left alone and the screen says
  to change its mix in Mixer Rules.

After a fix the same check runs again. The last screen lists what changed.

## How it stays safe

**Everything the wizard holds lapses on its own.** The setup state, mixer and
servo overrides, and the Binding-limits probe are all sent with a timeout and
re-sent by the suite's override keepalive (`lib/override_keepalive.lua`): a 10 s
timeout, refreshed every 3 s. A radio that is switched off, or a link that drops,
lets the controller drop them within 10 s. The motor run re-sends four times a
second against the firmware's own one-second deadline, and stops after 3 seconds.

**An armed car is never moved.** The setup state blocks arming while the wizard
is open; the controller ignores overrides while armed and refuses the setup
state. If the car is armed, or the setup state is refused, the wizard lets
everything go, greys out the buttons that move things, and the notice says why.

**GYRO OFF is flagged** when you switch it on yourself, since it puts the sticks
straight on the outputs.

**Every way out lets go.** Back, the close key, a step change and closing the tool
all release everything the wizard holds. On opening, it also clears overrides left
on by other pages.

## Saving

Changes go to the controller as you make them, so the steering moves straight
away. They are lost at the next power cycle until you save them. Leaving the
wizard with unsaved changes asks whether to **Save** them or **Discard** them;
Discard writes back what was there before every change since the last save.
Closing the tool cannot ask, so it leaves them on the controller, unsaved, as
other pages do.

## Source

[Page implementation](../../../src/grsuite/app/pages/setup_wizard.lua) and one
`app/pages/setup_wizard_<step>.lua` per step. The screens are built by
[app/setup_wizard_ui.lua](../../../src/grsuite/app/setup_wizard_ui.lua) and the
pictures drawn by [app/setup_wizard_art.lua](../../../src/grsuite/app/setup_wizard_art.lua).
The rules are ports of the Configurator's: `lib/setup_wizard_surfaces.lua`
(`surfaces.js`), `lib/setup_wizard_controls.lua` (`receiver.js`, `modeRanges.js`,
`trimGain.js`), `lib/setup_wizard_styles.lua` (`styles.js`), `lib/setup_wizard_bus.lua`
(`busOutput.js`) and `lib/setup_wizard_mix.lua` (`carMixer.js`). The ESC step's
behaviour and the gyro step's notes use `lib/msp_drive_config.lua` and
`lib/msp_drive_status.lua` (MSP2_GRIPORA_DRIVE_CONFIG / DRIVE_STATUS). Menu
conditions come from `app/tool.lua`.

*Documented against GRSuite Ethos 2.3.1.*
