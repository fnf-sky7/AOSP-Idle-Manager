#!/system/bin/sh
MODDIR=${0%/*}
ROOT=/data/adb/aosp_idle_manager
if [ -x "$MODDIR/daemonctl.sh" ]; then
  if ! "$MODDIR/daemonctl.sh" stop; then
    echo "AOSP Idle Manager: warning: a background process could not be confirmed stopped; preserving runtime data." >&2
    exit 0
  fi
fi
N=0
while [ "$N" -lt 5 ] && { [ -d "$ROOT/daemon.lock" ] || [ -f "$ROOT/httpd.pid" ]; }; do
  sleep 1
  N=$((N + 1))
done
if [ -d "$ROOT/daemon.lock" ] || [ -f "$ROOT/httpd.pid" ]; then
  echo "AOSP Idle Manager: warning: runtime process metadata remains; runtime data was preserved." >&2
  exit 0
fi
rm -rf "$ROOT"
