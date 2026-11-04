# Changelog

## v1.1.0 — public preview / release candidate
- Added the official KernelSU `kernelsu` ES-module bridge and its documented `pm` object (`pm.listPackages`, `pm.getPackagesInfo`) while retaining WebUI-Next's global `ksu` bridge.
- Corrected current KernelSU PackageManager access to use the documented exported `pm` object; normalized app labels to safe strings.
- Corrected bridge selection and removed the previous double-execution risk when a command returns no synchronous result.
- Added dedicated lightweight status polling; the complete package list is no longer reloaded every 20 seconds.
- Added clear confirmation prompts before `Full Kill` and `Kill After 10 Minutes` policies are saved.
- Hardened foreground component parsing across ActivityManager and WindowManager dumps; exact package matching is required and force-stop is skipped if no valid foreground package can be parsed.
- Fixed daemon TERM handling so the process exits and releases its lock.
- Added a shared lifecycle controller for service start, update, uninstall and localhost server cleanup.
- Added the KernelSU hot-install hook to stop the previous daemon and start the new one after a hot update.
- Added module-disable/remove checks to stop the daemon promptly.
- Scoped daemon and HTTP-server process matching to this module ID to avoid stopping unrelated root processes.
- Kept the KernelSU hot-install hook within the documented hook wait budget; boot service handles early-boot fallback.
- Improved atomic config writes, stale config-lock recovery and persistent data permissions.
- Added more core Android packages to the protected-package list.
- Magisk local API now has a lightweight status endpoint, strict request-token header validation, and no unauthenticated token-bootstrap endpoint; the token is passed in the URL fragment, not the HTTP request URL.
- Removed unauthenticated Magisk token bootstrap and moved the session token from the HTTP query string into a fragment plus a custom API header.
- Added `skip_mount`; the module does not modify system partitions.

## v1.0.3
- Added compatibility for synchronous, Promise-based and callback-based KernelSU bridge forms.
- Improved package enumeration and active-user handling.

## v1.0.2
- Switched KernelSU to the native WebUI bridge and package APIs.

## v1.0.1
- Added Action startup diagnostics and Magisk local WebUI bootstrap.
