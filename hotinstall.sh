#!/system/bin/sh
# KernelSU hot-install hook: stop the old daemon and start the new module copy.
case "$0" in */*) MODDIR=${0%/*} ;; *) MODDIR=$PWD ;; esac
COUNT=0
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
  sleep 2
  COUNT=$((COUNT + 1))
  # KernelSU waits at most 30 seconds for the hot-install hook. service.sh
  # will start the daemon after boot if this hook exits during early boot.
  [ "$COUNT" -lt 10 ] || exit 0
done
if ! "$MODDIR/daemonctl.sh" stop; then
  echo "AOSP Idle Manager: could not stop the previous daemon; refusing to start a duplicate." >&2
  exit 1
fi
"$MODDIR/daemonctl.sh" start
