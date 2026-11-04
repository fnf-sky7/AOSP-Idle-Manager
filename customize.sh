SKIPUNZIP=0

ui_print "------------------------------------------"
ui_print "       AOSP Idle Manager v1.1.0"
ui_print "              by Yuuki"
ui_print "------------------------------------------"
ui_print "Installing Deep Doze per-app policy engine..."
ui_print "KernelSU: use the module WebUI button. Magisk: use Action."
ui_print "Designed for AOSP-based Android ROMs. Review force-stop policies carefully."

ROOT=/data/adb/aosp_idle_manager
mkdir -p "$ROOT"
[ -f "$ROOT/enabled" ] || printf '1\n' > "$ROOT/enabled"
[ -f "$ROOT/policies.tsv" ] || : > "$ROOT/policies.tsv"
chmod 0700 "$ROOT"
chmod 0600 "$ROOT/enabled" "$ROOT/policies.tsv"

set_perm "$MODPATH/action.sh" 0 0 0755
set_perm "$MODPATH/service.sh" 0 0 0755
set_perm "$MODPATH/idle-daemon.sh" 0 0 0755
set_perm "$MODPATH/daemonctl.sh" 0 0 0755
set_perm "$MODPATH/hotinstall.sh" 0 0 0755
set_perm "$MODPATH/ksu-api.sh" 0 0 0755
set_perm "$MODPATH/webserver.sh" 0 0 0755
set_perm "$MODPATH/uninstall.sh" 0 0 0755
set_perm "$MODPATH/META-INF/com/google/android/update-binary" 0 0 0755

# Magisk's BusyBox httpd executes executable scripts in /cgi-bin.
if [ "$KSU" != "true" ]; then
  set_perm "$MODPATH/webroot/cgi-bin/api.sh" 0 0 0755
else
  # The module changes no system files, so KernelSU can apply WebUI and daemon
  # changes immediately; this hook replaces the previous daemon safely.
  export MODULE_HOT_INSTALL_REQUEST=true
  export MODULE_HOT_RUN_SCRIPT=hotinstall.sh
fi
