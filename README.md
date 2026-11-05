# AOSP Idle Manager

**Per-app background process policies for Android Deep Doze**

**Developer:** Yuuki  
**Version:** 1.1.0  
**License:** MIT  
**Root solutions:** KernelSU and Magisk  
**Target:** AOSP-based Android ROMs

> AOSP Idle Manager is a root module—not a custom ROM. It lets you choose how selected applications are handled while Android is in Deep Doze.

---

## Overview

AOSP Idle Manager is a lightweight, per-app idle policy manager for AOSP-based Android ROMs. It provides a WebUI where you can view installed packages, search for apps, and choose an idle behavior for each app.

The policy engine waits for Android to report Deep Doze as `IDLE` or `IDLE_MAINTENANCE`. Turning the screen off does **not** immediately trigger the policies. Android itself decides when the device enters and exits Deep Doze.

The module is designed to work with **KernelSU** and **Magisk**. KernelSU uses its native WebUI integration. Magisk uses a small HTTP server bound to the device's loopback interface and opened through the module's Action button.

## Features

- **Per-app idle policies:** Choose a separate behavior for each installed package.
- **Installed app list:** Browse detected System and User packages.
- **Search:** Find apps by their visible app label and package name where the manager API provides labels. On the Magisk fallback, search by package name.
- **App filters:** Show All apps, System apps, User apps, or only Configured apps.
- **Deep Doze status:** View whether Android is Active/not idle, in `IDLE`, in `IDLE_MAINTENANCE`, or whether the state is unavailable.
- **Global enable switch:** Pause or resume all configured policies without deleting them.
- **Reset:** Remove all saved per-app policies.
- **Persistent configuration:** Saved settings remain under `/data/adb/aosp_idle_manager` across reboots and module updates.
- **Protected core packages:** A predefined list of important Android packages cannot be assigned a destructive policy through the UI or backend.
- **Local-only Magisk WebUI:** The HTTP server listens on `127.0.0.1:18765`, not on the device's network interfaces.
- **No system partition modifications:** The module does not install a system overlay, change system properties, or add SELinux policy rules.

## Policy Modes

Each app has one of the following policies:

| Policy | What it does | Important details |
|---|---|---|
| **Default** | Leaves the app alone. Android manages it normally. | The module takes no action for that app. |
| **Kill Background Process** | Runs Android's `am kill` command for the selected package while Deep Doze is active. | Android decides which background processes are safe to kill. The app may start again later. The module checks this policy approximately once per minute while idle. |
| **Kill After 10 Minutes** | Force-stops the selected package after 10 minutes of continuously detected Deep Doze. | The timer starts when the daemon detects `IDLE`/`IDLE_MAINTENANCE`, not when the screen turns off. Actual execution can be delayed by CPU suspension or Android scheduling. |
| **Full Kill** | Force-stops the selected package on the first eligible policy check after Deep Doze is detected. | Android places the package in the stopped state. This is not a permanent autostart ban and does not disable or uninstall the app. A direct user/system launch can start it again. |

### How Force-Stop Safety Works

`Kill After 10 Minutes` and `Full Kill` use Android's `am force-stop` command. Before force-stopping, the daemon tries to identify the currently resumed/focused app from Android's ActivityManager and WindowManager output.

- If the selected package is identified as the foreground app, it is **not** force-stopped.
- If a different foreground package is successfully identified, the policy may proceed.
- If the ROM does not expose a usable foreground package, the daemon skips force-stop for that check rather than guessing.

This is a deliberate safety trade-off. On ROMs with unusual `dumpsys activity` or window output, a force-stop can be delayed or skipped.

## Requirements and Compatibility

- An AOSP-based Android ROM.
- Root access through KernelSU or Magisk.
- A compatible manager build that supports the module installation format and its WebUI/Action integration.
- For the Magisk WebUI, a BusyBox build that includes the `httpd` applet. The module checks for Magisk's BusyBox at `/data/adb/magisk/busybox` and then tries the available `busybox` command.

**Compatibility note:** Android ROMs, KernelSU forks, manager versions, and OEM `dumpsys` output differ. The module has development-time shell, JavaScript, bridge, backend, lifecycle, and local HTTP/CGI tests, but it has not been physically tested on every device or ROM.

## Installation

### KernelSU

1. Download the module ZIP from the repository's **Releases** section.
2. Open KernelSU Manager.
3. Go to **Modules** and choose **Install from storage** (wording may vary by Manager version).
4. Select the AOSP Idle Manager ZIP and complete installation.
5. If KernelSU completes the module's hot-install hook successfully, a reboot may not be required. If the Manager reports that hot installation is unavailable, or the hook exits during early boot, reboot the device.
6. Open the module details page and tap its **WebUI** button/icon. Do not use Action to open the KernelSU interface.

### Magisk

1. Download the module ZIP from the repository's **Releases** section.
2. Open Magisk Manager.
3. Go to **Modules** → **Install from storage**.
4. Select the AOSP Idle Manager ZIP and complete installation.
5. Reboot the device so the background daemon starts through the boot service.
6. Open the module's **Action** button. It starts the local WebUI server and attempts to open the browser automatically.

The Magisk WebUI server binds only to `127.0.0.1:18765`. If Android cannot open a browser automatically, the Action output prints the local session URL. Keep that session URL private while it is active.

## How to Use the WebUI

1. Open the module's WebUI (KernelSU) or Action (Magisk) using the steps above.
2. Wait for the installed package list and Deep Doze status to load.
3. Use the search field to find an app. Search supports app labels and package names where labels are available; on Magisk, use the package name.
4. Use the filters to narrow the list:
   - **All apps** — all detected packages.
   - **System** — packages classified as system apps.
   - **User** — packages classified as user-installed apps.
   - **Configured** — packages that already have a non-default policy.
5. Select the desired policy from the dropdown beside an app.
6. Confirm the warning when choosing **Kill After 10 Minutes** or **Full Kill**.
7. The selected policy is saved persistently. Reopen or refresh the WebUI to check the saved configuration.
8. Use the global **Enabled** switch to pause or resume policy enforcement. Disabling the engine does not erase the saved policies.
9. Use **Reset** to clear all per-app policies and return all apps to Default.

## Understanding Deep Doze Status

The status panel reflects Android's reported deep-idle state:

- **Active / not idle:** Android has not reported Deep Doze. No app policies are being applied.
- **IDLE:** Deep Doze is active. Configured policies may run.
- **IDLE_MAINTENANCE:** Android is in a Doze maintenance window. Configured policies remain eligible to run.
- **Unavailable:** The ROM did not expose a state the module could recognize. The daemon will not treat an unknown state as Deep Doze.

The daemon checks the state periodically (approximately every 30 seconds). The `Kill Background Process` and force-stop policies are throttled to eligible checks approximately once per minute.

## Configuration and Logs

The module stores its runtime configuration under:

```text
/data/adb/aosp_idle_manager/
```

| File | Purpose |
|---|---|
| `enabled` | Global policy-engine state (`1` = enabled, `0` = disabled). |
| `policies.tsv` | Saved per-app policy mappings. |
| `daemon.log` | Background daemon activity and diagnostics. |
| `webserver.log` | Magisk local WebUI server diagnostics. |
| `web_token` | Temporary Magisk WebUI session token. |

The module restricts the runtime directory and configuration files to root access. Do not publish logs without reviewing them for private package names or other device-specific details.

## Troubleshooting

### KernelSU WebUI Does Not Open or Apps Do Not Load

- Open the module details page and use **WebUI**, not Action.
- Update KernelSU Manager to a build that supports the documented WebUI and package-manager APIs.
- Close and reopen the WebUI after updating the Manager.
- Confirm that the module is enabled and installed successfully.

### Magisk Action Reports That BusyBox or `httpd` Is Missing

- Confirm that Magisk is installed correctly and its BusyBox binary is present.
- Reinstall/update Magisk if its BusyBox applets are unavailable.
- Reboot and try Action again.
- Check `/data/adb/aosp_idle_manager/webserver.log` for server diagnostics.

### Deep Doze Status Shows Unavailable

- Some ROMs expose a different `dumpsys deviceidle` format.
- Confirm that the ROM supports Android Device Idle/Doze and that `dumpsys deviceidle` is available to root.
- Unknown state is treated conservatively; policies are not run while the state is unavailable.

### Policies Do Not Run Immediately After Screen-Off

This is expected. Screen-off is not the trigger. Wait until Android reports `IDLE` or `IDLE_MAINTENANCE`. Android controls when Deep Doze begins, and battery, motion, charging, and system conditions can affect entry into Doze.

### A Force-Stop Happens Later Than 10 Minutes

The 10-minute timer starts when the daemon detects Deep Doze. Android may suspend the CPU or delay daemon execution, so the action is best-effort and is not a real-time deadline.

### An App Is Not Force-Stopped

- Check whether the app is currently foreground.
- The daemon skips force-stop if it cannot reliably parse the foreground package from system diagnostics.
- Confirm that the app is not in the protected core-package list.
- Review `daemon.log` and the ROM's ActivityManager/WindowManager output when debugging.

### Reset Did Not Restart an App

Reset only clears the module's saved policies. It does not automatically restart packages that Android has already force-stopped. Open the affected app directly.

## Safety Recommendations

Use destructive policies carefully. Force-stopping an app can interrupt or prevent timely delivery of:

- Messaging and email notifications.
- Alarms, reminders, and scheduled tasks.
- Accessibility services and automation tools.
- VPN, firewall, and network-monitoring services.
- Bluetooth companion apps and connected-device features.
- Location tracking, synchronization, backup, and other background work.

Avoid `Kill After 10 Minutes` and `Full Kill` for your launcher, keyboard, phone/dialer, emergency, security/authentication, accessibility, alarm, VPN, and other critical apps. The module protects a predefined set of core Android package names, but that list cannot cover every OEM- or ROM-specific critical component. Always review the package before assigning a policy, and test one app at a time.

## Uninstallation

1. Remove or uninstall AOSP Idle Manager from KernelSU Manager or Magisk Manager.
2. The module's uninstall cleanup attempts to stop its daemon and, on Magisk, its local WebUI server.
3. If a process cannot be confirmed stopped, runtime data is preserved rather than being deleted while a process may still be using it.
4. After uninstalling, check that the module is no longer listed and that its daemon is no longer running.

The module does not modify system partitions or change system properties. It does not add SELinux rules.

## Privacy

- The module stores its policies and logs locally on the device.
- The Magisk WebUI server listens on loopback (`127.0.0.1`) only.
- The Magisk API requires a session token; the token is placed in the URL fragment and sent to the API in a request header.
- The WebUI does not bundle remote assets or third-party JavaScript libraries.

## Testing Status

The v1.1.0 development audit included:

- Shell syntax checks for module scripts and the CGI endpoint.
- WebUI JavaScript syntax checks.
- KernelSU official ES-module and package-manager bridge mocks.
- WebUI-Next bridge mocks.
- Backend tests for status, policy save, global toggle, reset, protected-package rejection, and stale-lock handling.
- Daemon simulations for all three policies, foreground protection, timer handling, and lifecycle cleanup.
- Local BusyBox HTTP/CGI smoke tests, including loopback binding and rejection of requests without a valid session token.
- ZIP structure, required files, and executable-permission checks.

These are development-environment tests, not proof of compatibility with every physical device. Before calling a ROM/device combination supported, test installation, WebUI app listing, policy persistence, real Deep Doze entry/exit, notifications, alarms, foreground protection, manual relaunch, global disable/enable, update, module disable, reboot, and uninstall on that exact setup.

## Copyright and License

Copyright (c) 2026 Yuuki.

AOSP Idle Manager is licensed under the **MIT License**. You may use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the software, provided that the copyright notice and permission notice are included in all copies or substantial portions of the software.

The software is provided **AS IS**, without warranty of any kind. See [`LICENSE`](LICENSE) for the full license text.

---
