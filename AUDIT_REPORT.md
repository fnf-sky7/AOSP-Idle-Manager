# AOSP Idle Manager v1.1.0 — release audit

Developer: Yuuki

## Source and package checks

- Reviewed module metadata, installer entry point, `customize.sh`, boot service, KernelSU hot-install hook, Action launcher, daemon lifecycle controller, uninstall cleanup, privileged backends, WebUI, and static assets.
- Verified required module paths and executable permissions.
- Verified all text scripts and metadata use LF line endings.
- Verified the module does not contain a `system/` overlay, `sepolicy.rule`, or system property modifications.

## Automated checks completed

- Shell syntax check for all module scripts, installer entry point, and CGI endpoint using host shell and BusyBox ash.
- JavaScript syntax check for the embedded WebUI script.
- KernelSU official ES-module bridge mock using the documented `pm` object shape (`pm.listPackages` and `pm.getPackagesInfo`), Promise-based `exec`, localized labels, and module information.
- WebUI-Next synchronous and callback-style global bridge mocks.
- KernelSU backend mock tests for status, config read, per-app save, global toggle, reset, protected package rejection, and stale-lock recovery.
- Daemon policy simulation for background kill, force-stop after the 10-minute threshold, Full Kill, foreground protection, and TERM cleanup.
- Foreground component parser checks for resumed activity, top-resumed activity, and focused window formats.
- Daemon lifecycle simulation for start, duplicate prevention, stop, and lock cleanup.
- BusyBox HTTP/CGI integration smoke test for loopback-only serving, status, app list, unauthorized rejection, policy save and reset; the separate webserver start/health/stop lifecycle also passed.
- Session handling review: no unauthenticated token-bootstrap endpoint; token is carried in the page fragment (not sent to the HTTP server) and sent in a custom request header.
- ZIP archive test and SHA-256 checksum generation.

## Not verified on physical hardware

This development environment cannot reproduce a particular phone's KernelSU Manager build, Android Package Manager state, SELinux policy, OEM `dumpsys deviceidle`/`dumpsys activity` output, CPU suspend timing, notification behavior, alarms, or real Deep Doze transitions. No physical device test was performed for this release. Publish as a preview/beta until testers complete the checklist in `PUBLIC_RELEASE_CHECKLIST.md`.

## Important behavior notes

- Policies run only when Android reports Deep Doze `IDLE` or `IDLE_MAINTENANCE`; screen-off alone is not treated as idle.
- `Kill Background Process` uses Android's safe background process kill command.
- `Kill After 10 Minutes` counts from the daemon's detected Deep Doze transition; CPU suspend/scheduling may delay execution.
- `Full Kill` uses Android force-stop and avoids a force-stop when the daemon can parse the selected package as foreground. If no valid foreground component can be parsed, force-stop is skipped for safety.
- Force-stop is not a permanent autostart ban and can disrupt notifications, alarms, accessibility, VPN and other services.
