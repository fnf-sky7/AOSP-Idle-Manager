#!/system/bin/sh
# AOSP Idle Manager — per-app Deep Doze policy engine
# Copyright (c) 2026 Yuuki. Licensed under MIT.
MODDIR=${0%/*}
ROOT=/data/adb/aosp_idle_manager
CONFIG="$ROOT/policies.tsv"
ENABLED="$ROOT/enabled"
LOG="$ROOT/daemon.log"
PATH=/system/bin:/system/xbin:/vendor/bin:/vendor/xbin:/sbin
umask 077
mkdir -p "$ROOT" || exit 1
chmod 0700 "$ROOT" 2>/dev/null
LOCK="$ROOT/daemon.lock"

# Refuse to start a second copy. Reclaim only a stale lock.
if ! mkdir "$LOCK" 2>/dev/null; then
  OLD_PID=$(cat "$LOCK/pid" 2>/dev/null)
  OLD_CMD=
  case "$OLD_PID" in
    ''|*[!0-9]*) : ;;
    *)
      if kill -0 "$OLD_PID" 2>/dev/null; then
        OLD_CMD=$(tr '\000' ' ' < "/proc/$OLD_PID/cmdline" 2>/dev/null)
      fi
      ;;
  esac
  case "$OLD_CMD" in
    *"/aosp_idle_manager/idle-daemon.sh"*) exit 0 ;;
  esac
  rm -rf "$LOCK"
  mkdir "$LOCK" 2>/dev/null || exit 0
fi
printf '%s\n' "$$" > "$LOCK/pid"
chmod 0600 "$LOCK/pid" 2>/dev/null

log_msg() {
  echo "$(date '+%Y-%m-%d %H:%M:%S' 2>/dev/null) $*" >> "$LOG"
  SIZE=$(wc -c < "$LOG" 2>/dev/null)
  if [ -n "$SIZE" ] && [ "$SIZE" -gt 65536 ] 2>/dev/null; then
    tail -n 250 "$LOG" > "$LOG.tmp" 2>/dev/null && mv "$LOG.tmp" "$LOG"
  fi
}
cleanup() { rm -rf "$LOCK"; }
stop_daemon() { log_msg "Stop signal received; daemon exiting."; exit 0; }
trap cleanup EXIT
trap stop_daemon HUP INT TERM

valid_package() {
  printf '%s\n' "$1" | grep -Eq '^(android|[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+)$'
}
protected_package() {
  case "$1" in
    android|com.android.systemui|com.android.settings|com.android.phone|com.android.server.telecom|com.android.providers.settings|com.android.providers.contacts|com.android.providers.telephony|com.android.permissioncontroller|com.google.android.permissioncontroller|com.android.packageinstaller|com.google.android.packageinstaller|com.android.launcher3|com.google.android.apps.nexuslauncher|com.android.inputmethod.latin|com.google.android.inputmethod.latin|com.android.networkstack|com.android.networkstack.tethering|com.android.bluetooth|com.android.nfc|com.android.location.fused|com.android.cellbroadcastservice)
      return 0 ;;
    *) return 1 ;;
  esac
}
get_uptime() { cut -d. -f1 /proc/uptime 2>/dev/null; }
get_current_user() {
  CURRENT=$(/system/bin/am get-current-user 2>/dev/null | tail -n 1 | tr -cd '0-9')
  [ -n "$CURRENT" ] || CURRENT=0
  printf '%s\n' "$CURRENT"
}
get_deep_state() {
  RAW=$(/system/bin/dumpsys deviceidle get deep 2>/dev/null | tr '\r\n' '  ' | tr '[:lower:]' '[:upper:]')
  case "$RAW" in
    *IDLE_MAINTENANCE*) printf 'IDLE_MAINTENANCE\n'; return ;;
    *IDLE_PENDING*|*WAITING_FOR_NETWORK*) printf 'ACTIVE\n'; return ;;
    *IDLE*) printf 'IDLE\n'; return ;;
    *ACTIVE*|*INACTIVE*|*SENSING*|*LOCATING*) printf 'ACTIVE\n'; return ;;
  esac
  RAW=$(/system/bin/dumpsys deviceidle 2>/dev/null | tr '[:lower:]' '[:upper:]')
  STATE=$(printf '%s\n' "$RAW" | sed -n 's/.*MSTATE[=:][[:space:]]*\([A-Z_]*\).*/\1/p' | head -n 1)
  case "$STATE" in
    IDLE_MAINTENANCE) printf 'IDLE_MAINTENANCE\n' ;;
    IDLE) printf 'IDLE\n' ;;
    ACTIVE|INACTIVE|SENSING|LOCATING|IDLE_PENDING|WAITING_FOR_NETWORK) printf 'ACTIVE\n' ;;
    *) printf 'UNKNOWN\n' ;;
  esac
}
get_foreground_snapshot() {
  {
    /system/bin/dumpsys activity activities 2>/dev/null
    /system/bin/dumpsys window windows 2>/dev/null
  } | grep -E 'mResumedActivity|topResumedActivity|mFocusedApp|mCurrentFocus' \
    | sed -nE 's/.*[[:space:]](u[0-9]+[[:space:]]+)?([A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+)\/[^[:space:]}]+.*/\2/p' \
    | grep -E '^(android|[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+)$' \
    | sort -u
}
is_foreground() {
  # Return 0 when the package is foreground, 1 when a different foreground
  # package was parsed, and 2 when no usable foreground package is available.
  PKG_TO_CHECK=$1
  [ "$FOREGROUND_KNOWN" = 1 ] || return 2
  printf '%s\n' "$FOREGROUND" | grep -Fx "$PKG_TO_CHECK" >/dev/null 2>&1
}

[ -f "$ENABLED" ] || printf '1\n' > "$ENABLED"
[ -f "$CONFIG" ] || : > "$CONFIG"
chmod 0600 "$ENABLED" "$CONFIG" 2>/dev/null
USER_ID=$(get_current_user)
IDLE_START=0
TICK=0
log_msg "AOSP Idle Manager v1.1.0 daemon started (user=$USER_ID). Waiting for Android Deep Doze."

while :; do
  # Stop promptly when the module is disabled or scheduled for removal.
  if [ -f "$MODDIR/disable" ] || [ -f "$MODDIR/remove" ]; then
    log_msg "Module disable/remove flag detected; stopping local UI server and exiting."
    "$MODDIR/daemonctl.sh" stop-web >/dev/null 2>&1
    exit 0
  fi
  if [ "$(cat "$ENABLED" 2>/dev/null)" != 1 ]; then
    IDLE_START=0
    TICK=0
    sleep 30
    continue
  fi

  STATE=$(get_deep_state)
  NOW=$(get_uptime)
  case "$NOW" in ''|*[!0-9]*) NOW=0 ;; esac

  case "$STATE" in
    IDLE|IDLE_MAINTENANCE)
      USER_ID=$(get_current_user)
      if [ "$IDLE_START" -eq 0 ]; then
        IDLE_START=$NOW
        TICK=0
        log_msg "Deep Doze idle detected; policies are active (user=$USER_ID)."
      fi
      ELAPSED=$((NOW - IDLE_START))
      FOREGROUND=$(get_foreground_snapshot)
      if [ -n "$FOREGROUND" ]; then FOREGROUND_KNOWN=1; else FOREGROUND_KNOWN=0; fi

      if [ -f "$CONFIG" ]; then
        while IFS='|' read -r PKG MODE; do
          [ -n "$PKG" ] || continue
          valid_package "$PKG" || continue
          protected_package "$PKG" && continue
          case "$MODE" in
            kill)
              if [ $((TICK % 2)) -eq 0 ]; then
                /system/bin/am kill --user "$USER_ID" "$PKG" >/dev/null 2>&1
              fi
              ;;
            after10)
              if [ "$ELAPSED" -ge 600 ] && [ $((TICK % 2)) -eq 0 ]; then
                is_foreground "$PKG"
                FG_RESULT=$?
                if [ "$FG_RESULT" -eq 1 ]; then
                  /system/bin/am force-stop --user "$USER_ID" "$PKG" >/dev/null 2>&1
                fi
              fi
              ;;
            full)
              if [ $((TICK % 2)) -eq 0 ]; then
                is_foreground "$PKG"
                FG_RESULT=$?
                if [ "$FG_RESULT" -eq 1 ]; then
                  /system/bin/am force-stop --user "$USER_ID" "$PKG" >/dev/null 2>&1
                fi
              fi
              ;;
          esac
        done < "$CONFIG"
      fi
      TICK=$((TICK + 1))
      ;;
    *)
      if [ "$IDLE_START" -ne 0 ]; then
        log_msg "Deep Doze ended or became unavailable (state=$STATE); idle timers reset."
      fi
      IDLE_START=0
      TICK=0
      ;;
  esac
  sleep 30
done
