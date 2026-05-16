#!/system/bin/sh
##############################################################################
#  DresOS AOSmium WebView: uninstall.sh
#
#  Runs when the user removes the module via the Magisk app. Magisk itself
#  removes the module directory and unmounts the systemless tree. This
#  script must:
#
#    1. Clear the framework saved WebView provider selection so the next
#       boot does not try to load an AOSmium that no longer exists.
#    2. Re enable the stock Google or AOSP WebView that service.sh disabled,
#       because that disable state lives in /data and survives module
#       removal. Without this the device would have no stock WebView.
#    3. Plant a one shot self deleting trampoline in post-fs-data.d as a
#       backup, in case this script is running in an environment where pm
#       is not available, or in case the user removed the module via
#       recovery where uninstall.sh never runs at all. Magisk keeps
#       running post-fs-data.d scripts even after the module is gone.
##############################################################################

MODDIR=${0%/*}

# Clear the framework WebView provider selection.
settings delete global webview_provider 2>/dev/null

# Work out which stock package service.sh disabled, if any.
STOCK_WV=""
if [ -f "$MODDIR/disabled_stock_webview" ]; then
    STOCK_WV=$(cat "$MODDIR/disabled_stock_webview" 2>/dev/null)
fi

# Best effort immediate re enable. Works when uninstall is fired from the
# booted Magisk app.
if [ -n "$STOCK_WV" ]; then
    pm enable "$STOCK_WV" 2>/dev/null
fi
pm enable com.google.android.webview 2>/dev/null
pm enable com.android.webview 2>/dev/null

# Best effort switch the live provider back to a sane default so the user
# is not left without a working WebView this boot.
if pm list packages 2>/dev/null | grep -q "^package:com.google.android.webview$"; then
    cmd webviewupdate set-webview-implementation com.google.android.webview 2>/dev/null
elif pm list packages 2>/dev/null | grep -q "^package:com.android.webview$"; then
    cmd webviewupdate set-webview-implementation com.android.webview 2>/dev/null
fi

# Backup trampoline. Survives even if this script could not reach pm, or if
# the module is later wiped via recovery. It only acts once the DresOS
# module directory is actually gone, then deletes itself.
TRAMP_DIR=/data/adb/post-fs-data.d
TRAMP="$TRAMP_DIR/zz_dresoswv_restore_wv.sh"
mkdir -p "$TRAMP_DIR" 2>/dev/null
{
    echo '#!/system/bin/sh'
    echo '# DresOS AOSmium WebView stock restore trampoline.'
    echo '# Only acts if the DresOS module is gone. Self deletes.'
    echo 'MODD=/data/adb/modules/dresoswv'
    echo '[ -d "$MODD" ] && exit 0'
    echo '('
    echo '  until [ "$(getprop sys.boot_completed)" = "1" ]; do sleep 1; done'
    echo '  sleep 10'
    [ -n "$STOCK_WV" ] && echo "  pm enable $STOCK_WV"
    echo '  pm enable com.google.android.webview 2>/dev/null'
    echo '  pm enable com.android.webview 2>/dev/null'
    echo '  settings delete global webview_provider 2>/dev/null'
    echo '  rm -- "$0"'
    echo ') &'
} > "$TRAMP"
chmod 0755 "$TRAMP" 2>/dev/null

exit 0
