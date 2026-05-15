#!/system/bin/sh

MODDIR=${0%/*}
mkdir -p "$MODDIR/logs" 2>/dev/null
LOG="$MODDIR/logs/service.log"
USER_LOG="$MODDIR/webview_activation.log"

AOSMIUM_PKG="org.axpos.aosmium_wv"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$USER_LOG"
}

log "service.sh start"

resetprop -w sys.boot_completed 0 >/dev/null 2>&1
sleep 10

if [ -f "$MODDIR/inert" ]; then
    log "Inert mode active. Skipping."
    rm -f "$MODDIR/boot_pending"
    exit 0
fi

VISIBLE=$(pm list packages "$AOSMIUM_PKG" 2>/dev/null | grep -c "^package:${AOSMIUM_PKG}$")
if [ "$VISIBLE" -ne 1 ]; then
    log "FAIL: PackageManager cannot see $AOSMIUM_PKG. Flipping to inert."
    touch "$MODDIR/inert"
    rm -f "$MODDIR/boot_pending"
    exit 0
fi

cmd webviewupdate enable-redundant-packages >> "$LOG" 2>&1
SETIMPL_OUT=$(cmd webviewupdate set-webview-implementation "$AOSMIUM_PKG" 2>&1)
log "set-webview-implementation: $SETIMPL_OUT"
settings put global webview_provider "$AOSMIUM_PKG" 2>>"$LOG"

sleep 3
CURRENT=$(dumpsys webviewupdate 2>/dev/null | awk -F'[(),]' '/Current WebView package/ {gsub(/ /, "", $2); print $2; exit}')

if [ "$CURRENT" = "$AOSMIUM_PKG" ]; then
    log "SUCCESS: Active provider is $AOSMIUM_PKG"
else
    log "FAIL: Active provider is '$CURRENT'. Flipping to inert."
    touch "$MODDIR/inert"
fi

rm -f "$MODDIR/boot_pending"
exit 0
