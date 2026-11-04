#!/system/bin/sh
# AOSP Idle Manager privileged backend for KernelSU's native WebUI bridge.
# Copyright (c) 2026 Yuuki. Licensed under MIT.
PATH=/system/bin:/system/xbin:/vendor/bin:/vendor/xbin:/sbin
umask 077
ROOT=/data/adb/aosp_idle_manager
CONFIG="$ROOT/policies.tsv"
ENABLED="$ROOT/enabled"
LOCK="$ROOT/config.lock"
ACTION="$1"
PKG="$2"
MODE="$3"

mkdir -p "$ROOT" || exit 1
chmod 0700 "$ROOT" 2>/dev/null
[ -f "$ENABLED" ] || printf '1\n' > "$ENABLED"
[ -f "$CONFIG" ] || : > "$CONFIG"
chmod 0600 "$ENABLED" "$CONFIG" 2>/dev/null

valid_package() {
  printf '%s\n' "$1" | grep -Eq '^(android|[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+)$'
}
protected_package() {
  case "$1" in
    android|com.android.systemui|com.android.settings|com.android.phone|com.android.server.telecom|com.android.providers.settings|com.android.providers.contacts|com.android.providers.telephony|com.android.permissioncontroller|com.google.android.permissioncontroller|com.android.packageinstaller|com.google.android.packageinstaller|com.android.launcher3|com.google.android.apps.nexuslauncher|com.android.inputmethod.latin|com.google.android.inputmethod.latin|com.android.networkstack|com.android.networkstack.tethering|com.android.bluetooth|com.android.nfc|com.android.location.fused|com.android.cellbroadcastservice) return 0 ;;
    *) return 1 ;;
  esac
}
get_idle_state() {
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
get_current_user() {
  USER_ID=$(/system/bin/am get-current-user 2>/dev/null | tail -n 1 | tr -cd '0-9')
  [ -n "$USER_ID" ] || USER_ID=0
  printf '%s\n' "$USER_ID"
}
acquire_config_lock() {
  if mkdir "$LOCK" 2>/dev/null; then
    printf '%s\n' "$$" > "$LOCK/pid"
    chmod 0600 "$LOCK/pid" 2>/dev/null
    return 0
  fi
  OLD_PID=$(cat "$LOCK/pid" 2>/dev/null)
  case "$OLD_PID" in ''|*[!0-9]*) return 1 ;; esac
  if kill -0 "$OLD_PID" 2>/dev/null; then
    OLD_CMD=$(tr '\000' ' ' < "/proc/$OLD_PID/cmdline" 2>/dev/null)
    case "$OLD_CMD" in *ksu-api.sh*|*api.sh*) return 1 ;; esac
  fi
  rm -rf "$LOCK"
  mkdir "$LOCK" 2>/dev/null || return 1
  printf '%s\n' "$$" > "$LOCK/pid"
  chmod 0600 "$LOCK/pid" 2>/dev/null
  return 0
}
release_config_lock() { rm -rf "$LOCK"; }
write_toggle() {
  VALUE="$1"
  TMP="$ROOT/enabled.tmp.$$"
  printf '%s\n' "$VALUE" > "$TMP" || return 1
  chmod 0600 "$TMP"
  mv "$TMP" "$ENABLED"
}

case "$ACTION" in
  status)
    STATE=$(get_idle_state)
    ENABLED_VALUE=$(cat "$ENABLED" 2>/dev/null)
    [ "$ENABLED_VALUE" = 1 ] || ENABLED_VALUE=0
    USER_ID=$(get_current_user)
    printf '%s|%s|%s\n' "$STATE" "$ENABLED_VALUE" "$USER_ID"
    ;;
  config)
    cat "$CONFIG" 2>/dev/null
    ;;
  save)
    valid_package "$PKG" || { printf 'ERROR: Invalid package name\n'; exit 2; }
    case "$MODE" in none|kill|after10|full) : ;; *) printf 'ERROR: Invalid policy\n'; exit 2 ;; esac
    if protected_package "$PKG" && [ "$MODE" != none ]; then printf 'ERROR: Protected Android package\n'; exit 2; fi
    acquire_config_lock || { printf 'ERROR: Settings are busy; try again\n'; exit 3; }
    TMP="$ROOT/policies.tmp.$$"
    awk -F '|' -v p="$PKG" '$1 != p { print }' "$CONFIG" 2>/dev/null > "$TMP"
    if [ "$MODE" != none ]; then printf '%s|%s\n' "$PKG" "$MODE" >> "$TMP"; fi
    if ! sort -o "$TMP" "$TMP" 2>/dev/null; then
      rm -f "$TMP"
      release_config_lock
      printf 'ERROR: Could not sort policy file\n'
      exit 4
    fi
    chmod 0600 "$TMP"
    if ! mv "$TMP" "$CONFIG"; then
      rm -f "$TMP"
      release_config_lock
      printf 'ERROR: Could not save policy file\n'
      exit 5
    fi
    release_config_lock
    printf 'OK\n'
    ;;
  toggle)
    case "$PKG" in 0|1) : ;; *) printf 'ERROR: Invalid enabled state\n'; exit 2 ;; esac
    write_toggle "$PKG" || { printf 'ERROR: Could not update enabled state\n'; exit 4; }
    printf 'OK\n'
    ;;
  reset)
    acquire_config_lock || { printf 'ERROR: Settings are busy; try again\n'; exit 3; }
    TMP="$ROOT/policies.tmp.$$"
    : > "$TMP"
    chmod 0600 "$TMP"
    if ! mv "$TMP" "$CONFIG"; then
      rm -f "$TMP"
      release_config_lock
      printf 'ERROR: Could not reset policy file\n'
      exit 5
    fi
    release_config_lock
    printf 'OK\n'
    ;;
  *) printf 'ERROR: Unknown backend action\n'; exit 2 ;;
esac
