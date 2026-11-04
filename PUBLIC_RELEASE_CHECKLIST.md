# Public release device-test checklist

Do not describe the module as stable for a ROM until these checks pass on that ROM/device.

## KernelSU
- Record KernelSU kernel version, Manager version, Android version and ROM build.
- Install from ZIP, confirm WebUI opens and shows localized labels, package IDs, System/User filters and current Deep Doze status.
- Save each policy, close/reopen WebUI, and confirm the saved selection persists.
- Confirm global disable pauses enforcement and global enable resumes it.
- Test a harmless user app with `Kill Background Process` while Deep Doze is active.
- Test `Kill After 10 Minutes` and verify elapsed idle time, force-stop and direct user relaunch.
- Test `Full Kill`; verify it does not stop the app while that app is foreground, and verify direct user launch works.
- Test app notifications, alarm apps, messaging and VPN with policies removed/restored.
- Test hot update, module disable, reboot, and uninstall; confirm no daemon remains.

## Magisk
- Repeat the same tests after a clean install and reboot.
- Confirm Action starts the local WebUI and the API rejects requests without the session token.
- Confirm server binds only to `127.0.0.1:18765` and stops on uninstall/module disable.

## Release report
- Attach `daemon.log` and `webserver.log` for failures (remove private package names before sharing).
- Publish the exact Android version, ROM build, root solution/version and device model tested.
- Do not claim support for configurations that were not tested.
