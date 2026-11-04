#!/system/bin/sh
# AOSP Idle Manager Magisk-only localhost CGI bridge.
# Copyright (c) 2026 Yuuki. Licensed under MIT.
PATH=/system/bin:/system/xbin:/vendor/bin:/vendor/xbin:/sbin
umask 077
ROOT=/data/adb/aosp_idle_manager
CONFIG="$ROOT/policies.tsv"
ENABLED="$ROOT/enabled"
TOKEN_FILE="$ROOT/web_token"
PORT=18765

header() {
  printf 'Content-Type: application/json; charset=utf-8\r\nCache-Control: no-store\r\nPragma: no-cache\r\nX-Content-Type-Options: nosniff\r\n\r\n'
}
fail() {
  header
  printf '{"ok":false,"error":"%s"}\n' "$1"
  exit 0
}
get_param() {
  PARAM_VALUE=
  OLD_IFS=$IFS
  IFS='&'
  for ITEM in $QUERY_STRING; do
    case "$ITEM" in
      "$1"=*) PARAM_VALUE=${ITEM#*=}; break ;;
    esac
  done
  IFS=$OLD_IFS
}
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
  if mkdir "$ROOT/config.lock" 2>/dev/null; then
    printf '%s\n' "$$" > "$ROOT/config.lock/pid"
    chmod 0600 "$ROOT/config.lock/pid" 2>/dev/null
    return 0
  fi
  OLD_PID=$(cat "$ROOT/config.lock/pid" 2>/dev/null)
  case "$OLD_PID" in ''|*[!0-9]*) return 1 ;; esac
  if kill -0 "$OLD_PID" 2>/dev/null; then
    OLD_CMD=$(tr '\000' ' ' < "/proc/$OLD_PID/cmdline" 2>/dev/null)
    case "$OLD_CMD" in *api.sh*|*ksu-api.sh*) return 1 ;; esac
  fi
  rm -rf "$ROOT/config.lock"
  mkdir "$ROOT/config.lock" 2>/dev/null || return 1
  printf '%s\n' "$$" > "$ROOT/config.lock/pid"
  chmod 0600 "$ROOT/config.lock/pid" 2>/dev/null
  return 0
}
release_config_lock() { rm -rf "$ROOT/config.lock"; }

mkdir -p "$ROOT" || fail "Cannot create module data directory."
chmod 0700 "$ROOT" 2>/dev/null
[ -f "$ENABLED" ] || printf '1\n' > "$ENABLED"
[ -f "$CONFIG" ] || : > "$CONFIG"
chmod 0600 "$ENABLED" "$CONFIG" 2>/dev/null
get_param action
ACTION="$PARAM_VALUE"

# Never expose a token bootstrap endpoint: every privileged request must carry
# the unguessable session token issued by action.sh in a custom header.
TOKEN="$HTTP_X_AOSP_IDLE_TOKEN"
EXPECTED=$(cat "$TOKEN_FILE" 2>/dev/null)
[ -n "$TOKEN" ] && [ -n "$EXPECTED" ] && [ "$TOKEN" = "$EXPECTED" ] || fail "Unauthorized session. Tap Action and reopen the WebUI."

case "$ACTION" in
  status)
    USER_ID=$(get_current_user)
    ENABLED_VALUE=$(cat "$ENABLED" 2>/dev/null)
    [ "$ENABLED_VALUE" = 1 ] || ENABLED_VALUE=0
    IDLE_STATE=$(get_idle_state)
    header
    printf '{"ok":true,"user":%s,"enabled":%s,"idle_state":"%s"}\n' "$USER_ID" "$ENABLED_VALUE" "$IDLE_STATE"
    ;;
  list)
    USER_ID=$(get_current_user)
    ENABLED_VALUE=$(cat "$ENABLED" 2>/dev/null)
    [ "$ENABLED_VALUE" = 1 ] || ENABLED_VALUE=0
    IDLE_STATE=$(get_idle_state)
    ALL_TMP="$ROOT/list_all.$$"
    SYS_TMP="$ROOT/list_sys.$$"
    /system/bin/pm list packages --user "$USER_ID" 2>/dev/null | sed 's/^package://' > "$ALL_TMP"
    if [ ! -s "$ALL_TMP" ]; then /system/bin/cmd package list packages --user "$USER_ID" 2>/dev/null | sed 's/^package://' > "$ALL_TMP"; fi
    /system/bin/pm list packages -s --user "$USER_ID" 2>/dev/null | sed 's/^package://' > "$SYS_TMP"
    if [ ! -s "$SYS_TMP" ]; then /system/bin/cmd package list packages -s --user "$USER_ID" 2>/dev/null | sed 's/^package://' > "$SYS_TMP"; fi
    grep -E '^(android|[A-Za-z0-9_]+(\.[A-Za-z0-9_]+)+)$' "$ALL_TMP" 2>/dev/null | sort -u > "$ALL_TMP.clean"
    mv "$ALL_TMP.clean" "$ALL_TMP"
    if [ ! -s "$ALL_TMP" ]; then rm -f "$ALL_TMP" "$SYS_TMP"; fail "Android Package Manager returned no installed packages."; fi
    header
    printf '{"ok":true,"user":%s,"enabled":%s,"idle_state":"%s","apps":[' "$USER_ID" "$ENABLED_VALUE" "$IDLE_STATE"
    FIRST=1
    while IFS= read -r PKG; do
      [ -n "$PKG" ] || continue
      if grep -Fxq "$PKG" "$SYS_TMP" 2>/dev/null; then TYPE=system; else TYPE=user; fi
      MODE=$(awk -F '|' -v p="$PKG" '$1 == p { print $2; exit }' "$CONFIG" 2>/dev/null)
      case "$MODE" in kill|after10|full) : ;; *) MODE=none ;; esac
      if protected_package "$PKG"; then PROTECTED=true; else PROTECTED=false; fi
      [ "$FIRST" -eq 1 ] || printf ','
      FIRST=0
      printf '{"package":"%s","type":"%s","mode":"%s","protected":%s}' "$PKG" "$TYPE" "$MODE" "$PROTECTED"
    done < "$ALL_TMP"
    printf ']}\n'
    rm -f "$ALL_TMP" "$SYS_TMP"
    ;;
  save)
    [ "$REQUEST_METHOD" = POST ] || fail "POST required."
    get_param package; PKG="$PARAM_VALUE"
    get_param mode; MODE="$PARAM_VALUE"
    valid_package "$PKG" || fail "Invalid package name."
    case "$MODE" in none|kill|after10|full) : ;; *) fail "Invalid policy." ;; esac
    if protected_package "$PKG" && [ "$MODE" != none ]; then fail "This critical Android package is protected."; fi
    acquire_config_lock || fail "Settings are busy; try again."
    TMP="$ROOT/policies.tmp.$$"
    awk -F '|' -v p="$PKG" '$1 != p { print }' "$CONFIG" 2>/dev/null > "$TMP"
    if [ "$MODE" != none ]; then printf '%s|%s\n' "$PKG" "$MODE" >> "$TMP"; fi
    if ! sort -o "$TMP" "$TMP" 2>/dev/null; then rm -f "$TMP"; release_config_lock; fail "Could not prepare policy file."; fi
    chmod 0600 "$TMP"
    if ! mv "$TMP" "$CONFIG"; then rm -f "$TMP"; release_config_lock; fail "Could not save policy file."; fi
    release_config_lock
    header
    printf '{"ok":true,"message":"Policy saved."}\n'
    ;;
  toggle)
    [ "$REQUEST_METHOD" = POST ] || fail "POST required."
    get_param enabled; VALUE="$PARAM_VALUE"
    case "$VALUE" in 0|1) : ;; *) fail "Invalid enabled state." ;; esac
    TMP="$ROOT/enabled.tmp.$$"
    printf '%s\n' "$VALUE" > "$TMP" || fail "Could not write enabled state."
    chmod 0600 "$TMP"
    mv "$TMP" "$ENABLED" || fail "Could not update enabled state."
    header
    printf '{"ok":true,"enabled":%s}\n' "$VALUE"
    ;;
  reset)
    [ "$REQUEST_METHOD" = POST ] || fail "POST required."
    acquire_config_lock || fail "Settings are busy; try again."
    TMP="$ROOT/policies.tmp.$$"
    : > "$TMP"
    chmod 0600 "$TMP"
    if ! mv "$TMP" "$CONFIG"; then rm -f "$TMP"; release_config_lock; fail "Could not reset policy file."; fi
    release_config_lock
    header
    printf '{"ok":true,"message":"All policies cleared. Apps already force-stopped remain stopped until launched."}\n'
    ;;
  *) fail "Unknown action." ;;
esac
