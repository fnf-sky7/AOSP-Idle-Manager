#!/system/bin/sh
MODDIR=${0%/*}
ROOT=/data/adb/aosp_idle_manager
PORT=18765
BB=/data/adb/magisk/busybox
LOG="$ROOT/webserver.log"

mkdir -p "$ROOT"
if [ ! -x "$BB" ]; then BB=$(command -v busybox 2>/dev/null); fi
[ -n "$BB" ] && [ -x "$BB" ] || { echo "BusyBox not found" >> "$LOG"; exit 1; }
"$BB" httpd --help >/dev/null 2>&1 || { echo "BusyBox httpd applet missing" >> "$LOG"; exit 1; }

health_check() {
  RESULT=$("$BB" wget -q -T 2 -O - "http://127.0.0.1:$PORT/health.txt" 2>/dev/null | head -n 1)
  [ "$RESULT" = "AOSP Idle Manager v1.1.0 local WebUI endpoint" ]
}

# Reuse only our own known endpoint; otherwise refuse to interfere with another service.
if health_check; then exit 0; fi

# Remove stale pid metadata only. Never kill an unknown process occupying the port.
rm -f "$ROOT/httpd.pid"
: > "$LOG"

# Detach the server from the Magisk Action console so it survives when that screen closes.
"$BB" setsid "$BB" httpd -f -p "127.0.0.1:$PORT" -h "$MODDIR/webroot" \
  </dev/null >> "$LOG" 2>&1 &
SERVER_PID=$!
printf '%s\n' "$SERVER_PID" > "$ROOT/httpd.pid"
chmod 0600 "$ROOT/httpd.pid"

COUNT=0
while [ "$COUNT" -lt 10 ]; do
  if health_check; then
    echo "WebUI HTTP server ready on 127.0.0.1:$PORT (pid=$SERVER_PID)" >> "$LOG"
    exit 0
  fi
  COUNT=$((COUNT + 1))
  sleep 1
done

echo "WebUI health check failed on port $PORT" >> "$LOG"
if [ -f "$ROOT/httpd.pid" ]; then
  kill "$SERVER_PID" 2>/dev/null
  rm -f "$ROOT/httpd.pid"
fi
exit 1
