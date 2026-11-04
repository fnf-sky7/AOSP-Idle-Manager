#!/system/bin/sh
# Lifecycle controller for AOSP Idle Manager background processes.
MODDIR=${0%/*}
ROOT=/data/adb/aosp_idle_manager
PATH=/system/bin:/system/xbin:/vendor/bin:/vendor/xbin:/sbin

same_daemon() {
  PID="$1"
  case "$PID" in ''|*[!0-9]*) return 1 ;; esac
  [ -r "/proc/$PID/cmdline" ] || return 1
  CMD=$(tr '\000' ' ' < "/proc/$PID/cmdline" 2>/dev/null)
  case "$CMD" in *"/aosp_idle_manager/idle-daemon.sh"*) return 0 ;; esac
  return 1
}
same_httpd() {
  PID="$1"
  case "$PID" in ''|*[!0-9]*) return 1 ;; esac
  [ -r "/proc/$PID/cmdline" ] || return 1
  CMD=$(tr '\000' ' ' < "/proc/$PID/cmdline" 2>/dev/null)
  case "$CMD" in *"httpd -f -p 127.0.0.1:18765"*"/aosp_idle_manager/webroot"*) return 0 ;; esac
  return 1
}
stop_one() {
  PIDFILE="$1"
  KIND="$2"
  [ -f "$PIDFILE" ] || return 0
  PID=$(cat "$PIDFILE" 2>/dev/null)
  VALID=0
  case "$KIND" in daemon) same_daemon "$PID" && VALID=1 ;; httpd) same_httpd "$PID" && VALID=1 ;; esac
  if [ "$VALID" -eq 1 ]; then
    kill "$PID" 2>/dev/null
    N=0
    while [ "$N" -lt 8 ]; do
      case "$KIND" in daemon) same_daemon "$PID" || break ;; httpd) same_httpd "$PID" || break ;; esac
      sleep 1
      N=$((N + 1))
    done
    case "$KIND" in daemon) if same_daemon "$PID"; then kill -9 "$PID" 2>/dev/null; fi ;; httpd) if same_httpd "$PID"; then kill -9 "$PID" 2>/dev/null; fi ;; esac
    sleep 1
    case "$KIND" in
      daemon) if same_daemon "$PID"; then echo "Could not stop idle daemon PID $PID" >&2; return 1; fi ;;
      httpd) if same_httpd "$PID"; then echo "Could not stop local WebUI server PID $PID" >&2; return 1; fi ;;
    esac
  fi
  rm -f "$PIDFILE"
  return 0
}
stop_all() {
  # A fresh daemon creates its lock directory just before writing pid. Give
  # that tiny startup window time to complete rather than deleting a live lock.
  if [ -d "$ROOT/daemon.lock" ] && [ ! -f "$ROOT/daemon.lock/pid" ]; then
    N=0
    while [ "$N" -lt 4 ] && [ ! -f "$ROOT/daemon.lock/pid" ]; do sleep 1; N=$((N + 1)); done
    if [ ! -f "$ROOT/daemon.lock/pid" ]; then rm -rf "$ROOT/daemon.lock"; fi
  fi
  stop_one "$ROOT/daemon.lock/pid" daemon || return 1
  stop_one "$ROOT/httpd.pid" httpd || return 1
  PID=$(cat "$ROOT/daemon.lock/pid" 2>/dev/null)
  if ! same_daemon "$PID"; then rm -rf "$ROOT/daemon.lock"; fi
  return 0
}

case "$1" in
  stop)
    stop_all
    ;;
  stop-web)
    stop_one "$ROOT/httpd.pid" httpd
    ;;
  start)
    mkdir -p "$ROOT" || exit 1
    stop_all || exit 1
    PID=$(cat "$ROOT/daemon.lock/pid" 2>/dev/null)
    if same_daemon "$PID"; then
      echo "An existing idle daemon could not be stopped; refusing to start a duplicate." >&2
      exit 1
    fi
    rm -rf "$ROOT/daemon.lock"
    "$MODDIR/idle-daemon.sh" >/dev/null 2>&1 &
    N=0
    while [ "$N" -lt 5 ] && [ ! -f "$ROOT/daemon.lock/pid" ]; do sleep 1; N=$((N + 1)); done
    if [ ! -f "$ROOT/daemon.lock/pid" ] || ! kill -0 "$(cat "$ROOT/daemon.lock/pid" 2>/dev/null)" 2>/dev/null; then
      echo "Idle daemon failed to create its PID lock." >&2
      exit 1
    fi
    ;;
  *)
    echo "Usage: daemonctl.sh {start|stop|stop-web}" >&2
    exit 2
    ;;
esac
exit 0
