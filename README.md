# AOSP Idle Manager

**Developer:** Yuuki  
**Version:** 1.1.0  
**Target:** AOSP-based Android ROMs with KernelSU or Magisk.

A per-app policy engine that acts only while Android reports Deep Doze `IDLE` or `IDLE_MAINTENANCE`. Screen-off alone does not start policies.

## Features

- Native KernelSU WebUI using the official `kernelsu` JavaScript module and its `pm` package-manager object; compatibility fallback for WebUI-Next's global `ksu` bridge.
- Magisk-only localhost WebUI launched from the module Action button.
- Installed package list, app-label/package-name search, System/User/Configured filters.
- Per-app policies, global enable switch and Reset.
- Lightweight status polling without repeatedly rebuilding the complete package list.
- Persistent settings stored under `/data/adb/aosp_idle_manager`.

## Policies

- **Default:** AOSP manages the app normally; this module takes no action.
- **Kill Background Process:** runs `am kill --user USER_ID PACKAGE` once per minute while Deep Doze is active. Android decides which package processes are safe to kill; the app can restart later.
- **Kill After 10 Minutes:** after 600 seconds of continuous detected Deep Doze, runs `am force-stop --user USER_ID PACKAGE`.
- **Full Kill:** runs `am force-stop --user USER_ID PACKAGE` during Deep Doze as soon as the daemon detects the idle state.

Force-stop places a package in Android's stopped state. It generally prevents automatic background starts until a direct user/system launch clears the state. It is not a permanent autostart ban, does not disable/uninstall the app, and cannot override explicit user/system launches.

For `after10` and `full`, the daemon parses the package component from Android's resumed/focused activity records. It force-stops only when at least one valid foreground package can be parsed and the selected package is not foreground. If foreground state is unavailable or ambiguous, force-stop is skipped for that cycle. This deliberate safety trade-off can delay or skip a force-stop on ROMs with unusual `dumpsys activity` output.

## Install

### KernelSU

1. Install the module ZIP in KernelSU Manager.
2. Use the module's **WebUI** button/icon (not Action) to open the interface.
3. The module requests KernelSU hot installation because it does not mount or modify system files. Its hot-install hook stops the previous daemon and starts the new one. If KernelSU reports hot installation unavailable or the hook exits during early boot, reboot after installation.

The WebUI uses the official `kernelsu` ES-module API and official `pm.listPackages()` / `pm.getPackagesInfo()` methods when available. A global `ksu` bridge is supported for WebUI-Next. Unsupported managers show an error rather than treating shell output as JSON.

### Magisk

1. Install the module ZIP in Magisk Manager and reboot.
2. Open the module's **Action** button.
3. The module starts BusyBox `httpd` bound only to `127.0.0.1:18765` and opens the local page in the browser.
4. The Magisk fallback displays package IDs rather than localized labels; search by package name.

The session token is passed in the page URL fragment and sent to the CGI API using a custom request header. No unauthenticated token-bootstrap endpoint is provided. The server listens on loopback only.

## Runtime and diagnostics

- Policies: `/data/adb/aosp_idle_manager/policies.tsv`
- Global enable flag: `/data/adb/aosp_idle_manager/enabled` (`1` enabled, `0` disabled)
- Daemon log: `/data/adb/aosp_idle_manager/daemon.log`
- Magisk WebUI log: `/data/adb/aosp_idle_manager/webserver.log`

No system partition files are mounted or modified. The module does not add sepolicy rules or change system properties.

## Safety and known limitations

- Force-stop may interrupt messaging, alarms, accessibility, VPN, device automation, Bluetooth companion apps, location-related services, syncing and notifications.
- Core Android packages are protected, but the protected list cannot identify every OEM- or ROM-specific critical package. Review each selected package yourself.
- Do not apply `Full Kill` or `Kill After 10 Minutes` to emergency, security, accessibility, phone, launcher, keyboard, alarm or authentication apps.
- Reset removes policies but does not automatically restart packages previously force-stopped by Android. Open those apps directly.
- Doze entry and `dumpsys` output vary by Android version and ROM. The daemon polls every 30 seconds; `after10` can run later than the 10-minute threshold because the CPU may be suspended or the daemon scheduled only during a maintenance window.
- A root shell daemon cannot guarantee a precisely timed action while Android is suspending CPU execution in deep idle. This module applies policies when its daemon next gets execution time.
- The Magisk fallback lists package IDs; localized app labels are provided by the KernelSU package API only.

## Test status

Shell syntax, WebUI JavaScript syntax, ZIP structure, official KernelSU package-manager mock, WebUI-Next bridge mocks, backend policy tests, daemon policy/foreground-safety simulations, lifecycle simulations, and a local BusyBox HTTP/CGI smoke test were completed during development. These tests do not prove compatibility with every ROM and are not a substitute for physical-device testing. Before broad public distribution, test on the exact KernelSU Manager/KernelSU version, Android ROM, and Magisk device you intend to claim as supported. Verify actual Deep Doze transitions, notifications, alarms, manual relaunch, module disable, hot update and uninstall.

## Copyright and license

Copyright (c) 2026 Yuuki.

Licensed under the MIT License. Redistribution and modification are permitted provided the copyright and license notice are retained. The software is provided **AS IS**, without warranty of any kind. See `LICENSE` for the full terms.
