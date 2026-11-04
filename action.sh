#!/system/bin/sh
MODDIR=${0%/*}
ROOT=/data/adb/aosp_idle_manager
PORT=18765
BB=/data/adb/magisk/busybox

say() { echo "[AOSP Idle Manager] $*"; }

# KernelSU already serves webroot/index.html inside its Manager WebView.
# Never start a second HTTP/CGI server under KernelSU.
if [ -d /data/adb/ksu ] || [ -x /data/adb/ksu/bin/busybox ]; then
  say "KernelSU detected."
  say "Open the module details page and tap its WebUI button/icon."
  say "The Action button is not used for the KernelSU native WebUI."
  exit 0
fi

mkdir -p "$ROOT" || { say "ERROR: Cannot create $ROOT"; exit 1; }
chmod 0700 "$ROOT" 2>/dev/null

# Magisk normally ships BusyBox at this path. Keep fallbacks for compatible root setups.
if [ ! -x "$BB" ]; then
  BB=$(command -v busybox 2>/dev/null)
fi
if [ -z "$BB" ] || [ ! -x "$BB" ]; then
  say "ERROR: BusyBox was not found. Reinstall/update Magisk and reboot."
  exit 1
fi
if ! "$BB" httpd --help >/dev/null 2>&1; then
  say "ERROR: This BusyBox build does not include the httpd applet."
  exit 1
fi

# Create a fresh 256-bit session token, using Magisk BusyBox's od applet.
TOKEN=$("$BB" od -An -N32 -tx1 /dev/urandom 2>/dev/null | "$BB" tr -d ' \n')
if [ "${#TOKEN}" -lt 64 ]; then
  say "ERROR: Could not generate a secure WebUI session token."
  exit 1
fi
printf '%s\n' "$TOKEN" > "$ROOT/web_token"
chmod 0600 "$ROOT/web_token"

say "Starting local WebUI server on 127.0.0.1:$PORT ..."
if ! "$MODDIR/webserver.sh"; then
  say "ERROR: WebUI server failed to start. Details: $ROOT/webserver.log"
  if [ -f "$ROOT/webserver.log" ]; then
    tail -n 12 "$ROOT/webserver.log" 2>/dev/null
  fi
  exit 1
fi

URL="http://127.0.0.1:$PORT/#token=$TOKEN"
say "Server is ready. Opening your browser ..."
START_OUTPUT=$(am start -a android.intent.action.VIEW -d "$URL" 2>&1)
START_RC=$?
[ -n "$START_OUTPUT" ] && say "$START_OUTPUT"
if [ "$START_RC" -ne 0 ]; then
  say "ERROR: Android could not open a browser automatically."
  say "Open this exact session URL in your phone browser:"
  say "$URL"
  exit 1
fi
say "AOSP Idle Manager v1.1.0 is running. You can close this Action window."
exit 0
