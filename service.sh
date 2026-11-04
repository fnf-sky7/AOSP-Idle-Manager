#!/system/bin/sh
MODDIR=${0%/*}
COUNT=0
while [ "$(getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
  sleep 2
  COUNT=$((COUNT + 1))
  [ "$COUNT" -lt 180 ] || exit 0
  [ -f "$MODDIR/disable" ] && exit 0
  [ -f "$MODDIR/remove" ] && exit 0
done
"$MODDIR/daemonctl.sh" start
