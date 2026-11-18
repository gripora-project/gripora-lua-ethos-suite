---
title: Pages
sidebar_label: Pages
---

# Configuration pages

Reference documentation for each configuration and settings page reachable
within the GRSuite Ethos system tool.

**Coverage:** 79 reachable pages in navigation hierarchy. Drafts require review.

The *Conditions* column names what hides, greys out or locks a page; the sentences
and structure follow [_template.md](../_template.md).

Pages are filled in as changes reach them: a pull request that changes a page brings
that page's file with it, or says on a line of its own why it needs no documentation
change. The `Documentation rule` job in `.github/workflows/pr.yml` fails when neither
is there. The rule is in [.agents/rules/documentation.md](../../.agents/rules/documentation.md).

## Configuration → Tuning

| Page | File | Conditions | Status |
| --- | --- | --- | --- |
| PIDs | [tuning/pids.md](tuning/pids.md) | Requires a running background task and a flight controller connection. | reviewed |
| Rates | [tuning/rates.md](tuning/rates.md) | Requires a running background task and a flight controller connection. | reviewed |
| Driving Feel | [tuning/master_gains.md](tuning/master_gains.md) | Requires a running background task and a flight controller connection. | reviewed |
| ABS | [tuning/drive_aids_abs.md](tuning/drive_aids_abs.md) | Requires a running background task and a flight controller connection. | reviewed |
| Traction | [tuning/drive_aids_tc.md](tuning/drive_aids_tc.md) | Requires a running background task and a flight controller connection. | reviewed |
| Filters | [tuning/filters.md](tuning/filters.md) | Requires a running background task and a flight controller connection. | draft |
| PID Controller | [tuning/pid_controller.md](tuning/pid_controller.md) | Requires a running background task and a flight controller connection. | reviewed |
| PID Bandwidth | [tuning/pid_bandwidth.md](tuning/pid_bandwidth.md) | Requires a running background task and a flight controller connection. | reviewed |
| Gain Curves | [tuning/gain_curves.md](tuning/gain_curves.md) | Requires a running background task and a flight controller connection. | reviewed |
| Rate Response | [tuning/rates_advanced.md](tuning/rates_advanced.md) | Requires a running background task and a flight controller connection. | reviewed |

## Configuration → Setup

| Page | File | Conditions | Status |
| --- | --- | --- | --- |
| Configuration | [setup/configuration.md](setup/configuration.md) | Requires a running background task and a flight controller connection. | draft |
| Ports | [setup/ports.md](setup/ports.md) | Requires a running background task and a flight controller connection. | draft |
| Radio Config | [setup/radio_config.md](setup/radio_config.md) | Requires a running background task and a flight controller connection. | draft |
| Telemetry | [setup/telemetry.md](setup/telemetry.md) | Requires a running background task and a flight controller connection. | draft |
| Modes | [setup/modes.md](setup/modes.md) | Requires a running background task and a flight controller connection. | draft |
| Adjustments | [setup/adjustments.md](setup/adjustments.md) | Requires a running background task and a flight controller connection. | draft |
| Ch. Fallback | [setup/failsafe.md](setup/failsafe.md) | Requires a running background task and a flight controller connection. | draft |
| Stage 2 | [setup/failsafe_procedure.md](setup/failsafe_procedure.md) | Requires a running background task and a flight controller connection. | reviewed |
| Configuration | [setup/beepers_configuration.md](setup/beepers_configuration.md) | Requires a running background task and a flight controller connection. | draft |
| ESC Beacon | [setup/beepers_dshot.md](setup/beepers_dshot.md) | Requires a running background task and a flight controller connection. | draft |
| Configuration | [setup/blackbox_configuration.md](setup/blackbox_configuration.md) | Requires a running background task and a flight controller connection. | draft |
| Logging | [setup/blackbox_logging.md](setup/blackbox_logging.md) | Requires a running background task and a flight controller connection. | draft |
| Status | [setup/blackbox_status.md](setup/blackbox_status.md) | Requires a running background task and a flight controller connection. | draft |
| Stats | [setup/stats.md](setup/stats.md) | Requires a running background task and a flight controller connection. | draft |
| Accelerometer | [setup/accelerometer.md](setup/accelerometer.md) | Requires a running background task and a flight controller connection. | draft |
| Alignment | [setup/alignment.md](setup/alignment.md) | Requires a running background task and a flight controller connection. | draft |
| Mixer | [setup/mixer_config.md](setup/mixer_config.md) | Requires a running background task and a flight controller connection. | reviewed |
| Mixer Rules | [setup/mixer_rules.md](setup/mixer_rules.md) | Requires a running background task and a flight controller connection. | reviewed |
| Curves | [setup/curves.md](setup/curves.md) | Requires a running background task and a flight controller connection. | reviewed |
| Servos | [setup/servos.md](setup/servos.md) | Requires a running background task and a flight controller connection. | reviewed |
| Battery | [setup/power_battery.md](setup/power_battery.md) | Requires a running background task and a flight controller connection. | draft |
| Alerts | [setup/power_alerts.md](setup/power_alerts.md) | Requires a running background task and a flight controller connection. | draft |
| Sources | [setup/power_source.md](setup/power_source.md) | Requires a running background task and a flight controller connection. | draft |
| SmartFuel | [setup/power_smartfuel.md](setup/power_smartfuel.md) | Requires a running background task and a flight controller connection. | draft |
| Preferences | [setup/power_preferences.md](setup/power_preferences.md) | Requires a running background task and a flight controller connection. | reviewed |
| Motor Override | [setup/motor_override.md](setup/motor_override.md) | Requires a running background task and a flight controller connection. | reviewed |
| Throttle | [setup/esc_motors_throttle.md](setup/esc_motors_throttle.md) | Requires a running background task and a flight controller connection. | draft |
| Drive | [setup/esc_motors_drive.md](setup/esc_motors_drive.md) | Requires a running background task and a flight controller connection. | reviewed |
| Telemetry | [setup/esc_motors_telemetry.md](setup/esc_motors_telemetry.md) | Requires a running background task and a flight controller connection. | draft |
| SRXL2 ESC | [setup/esc_motors_srxl2.md](setup/esc_motors_srxl2.md) | Requires a running background task and a flight controller connection. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 14). If that read fails, it is retried every 5 seconds. | reviewed |
| RPM | [setup/esc_motors_rpm.md](setup/esc_motors_rpm.md) | Requires a running background task and a flight controller connection. | draft |
| Hobbywing V5 | [setup/esc_forward_hw5.md](setup/esc_forward_hw5.md) | Requires a running background task and a flight controller connection. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 3). If that read fails, it is retried every 5 seconds. | reviewed |
| AM32 | [setup/esc_forward_am32.md](setup/esc_forward_am32.md) | Requires a running background task and a flight controller connection. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 1). If that read fails, it is retried every 5 seconds. | draft |
| BLHeli_S | [setup/esc_forward_blheli_s.md](setup/esc_forward_blheli_s.md) | Requires a running background task and a flight controller connection. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 1). If that read fails, it is retried every 5 seconds. | draft |
| Bluejay | [setup/esc_forward_bluejay.md](setup/esc_forward_bluejay.md) | Requires a running background task and a flight controller connection. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 1). If that read fails, it is retried every 5 seconds. | draft |
| FLYROTOR | [setup/esc_forward_flyrotor.md](setup/esc_forward_flyrotor.md) | Requires a running background task and a flight controller connection. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 10). If that read fails, it is retried every 5 seconds. | draft |
| OMP | [setup/esc_forward_omp.md](setup/esc_forward_omp.md) | Requires a running background task and a flight controller connection. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 6). If that read fails, it is retried every 5 seconds. | draft |
| Scorpion | [setup/esc_forward_scorpion.md](setup/esc_forward_scorpion.md) | Requires a running background task and a flight controller connection. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 4). If that read fails, it is retried every 5 seconds. | draft |
| XDFLY | [setup/esc_forward_xdfly.md](setup/esc_forward_xdfly.md) | Requires a running background task and a flight controller connection. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 12). If that read fails, it is retried every 5 seconds. | draft |
| YGE | [setup/esc_forward_yge.md](setup/esc_forward_yge.md) | Requires a running background task and a flight controller connection. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 9). If that read fails, it is retried every 5 seconds. | draft |
| ZTW | [setup/esc_forward_ztw.md](setup/esc_forward_ztw.md) | Requires a running background task and a flight controller connection. Lit only while the flight controller reports this ESC telemetry protocol (Protocol ID: 7). If that read fails, it is retried every 5 seconds. | draft |

## System → Tools

| Page | File | Conditions | Status |
| --- | --- | --- | --- |
| Setup Wizard | [tools/setup_wizard.md](tools/setup_wizard.md) | Requires a running background task and a flight controller connection. | reviewed |
| Copy Profiles | [tools/copy_profiles.md](tools/copy_profiles.md) | Requires a running background task and a flight controller connection. | draft |
| Select Profile | [tools/profile_select.md](tools/profile_select.md) | Requires a running background task and a flight controller connection. | draft |
| Status | [tools/diagnostics_rfstatus.md](tools/diagnostics_rfstatus.md) | Available without a flight controller connection; the background task must be running. | draft |
| ELRS Telemetry | [tools/diagnostics_elrs_link.md](tools/diagnostics_elrs_link.md) | Requires a running background task and a flight controller connection. | draft |
| FC Status | [tools/diagnostics_fblstatus.md](tools/diagnostics_fblstatus.md) | Requires a running background task and a flight controller connection. | draft |
| Rx Backup | [tools/diagnostics_rx_input_backup.md](tools/diagnostics_rx_input_backup.md) | Requires a running background task and a flight controller connection. | reviewed |
| Info | [tools/diagnostics_info.md](tools/diagnostics_info.md) | Available without a flight controller connection; the background task must be running. | draft |
| MSP Speed | [tools/developer_msp_speed.md](tools/developer_msp_speed.md) | Requires a running background task and a flight controller connection. Hidden until *System* → *Settings* → *Developer* mode is active. | draft |
| MSP Exp. | [tools/developer_msp_exp.md](tools/developer_msp_exp.md) | Requires a running background task and a flight controller connection. Hidden until *System* → *Settings* → *Developer* mode is active. | draft |

## System → Logs

| Page | File | Conditions | Status |
| --- | --- | --- | --- |
| Logs | [logs.md](logs.md) | Available without a flight controller connection; the background task must be running. | draft |

## System → Settings

| Page | File | Conditions | Status |
| --- | --- | --- | --- |
| General | [settings/settings_general.md](settings/settings_general.md) | Available without a flight controller connection; the background task must be running. | draft |
| Themes | [settings/settings_dashboard_theme.md](settings/settings_dashboard_theme.md) | Available without a flight controller connection; the background task must be running. | draft |
| Settings | [settings/settings_dashboard_settings.md](settings/settings_dashboard_settings.md) | Available without a flight controller connection; the background task must be running. | draft |
| Settings | [settings/settings_activelook_settings.md](settings/settings_activelook_settings.md) | Available without a flight controller connection; the background task must be running. | draft |
| Before Run | [settings/settings_activelook_preflight.md](settings/settings_activelook_preflight.md) | Available without a flight controller connection; the background task must be running. | draft |
| During Run | [settings/settings_activelook_inflight.md](settings/settings_activelook_inflight.md) | Available without a flight controller connection; the background task must be running. | draft |
| After Run | [settings/settings_activelook_postflight.md](settings/settings_activelook_postflight.md) | Available without a flight controller connection; the background task must be running. | draft |
| Voltage | [settings/settings_audio_events_voltage.md](settings/settings_audio_events_voltage.md) | Available without a flight controller connection; the background task must be running. | reviewed |
| ESC temp | [settings/settings_audio_events_esc.md](settings/settings_audio_events_esc.md) | Available without a flight controller connection; the background task must be running. | reviewed |
| Fuel | [settings/settings_audio_events_fuel.md](settings/settings_audio_events_fuel.md) | Available without a flight controller connection; the background task must be running. | reviewed |
| State callouts | [settings/settings_audio_events_state.md](settings/settings_audio_events_state.md) | Available without a flight controller connection; the background task must be running. | reviewed |
| FC status | [settings/settings_audio_events_status.md](settings/settings_audio_events_status.md) | Available without a flight controller connection; the background task must be running. | reviewed |
| Link | [settings/settings_audio_events_link.md](settings/settings_audio_events_link.md) | Available without a flight controller connection; the background task must be running. | reviewed |
| Model callout | [settings/settings_audio_events_announcement.md](settings/settings_audio_events_announcement.md) | Available without a flight controller connection; the background task must be running. | reviewed |
| Switches | [settings/settings_audio_switches.md](settings/settings_audio_switches.md) | Available without a flight controller connection; the background task must be running. | draft |
| Timer | [settings/settings_audio_timer.md](settings/settings_audio_timer.md) | Available without a flight controller connection; the background task must be running. | draft |
| Developer | [settings/developer_settings.md](settings/developer_settings.md) | Available without a flight controller connection; the background task must be running. | draft |
