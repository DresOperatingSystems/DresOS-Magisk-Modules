#!/system/bin/sh
##############################################################################
#  DresOS AOSmium WebView: service.sh
#
#  Runs late_start, non blocking, in parallel with the rest of device boot.
#  Responsible for:
#
#    1. Waiting until the framework has finished booting (sys.boot_completed).
#    2. Verifying the AOSmium package is visible to PackageManager.
#    3. Promoting AOSmium to the active WebView provider via the canonical
#       cmd webviewupdate set-webview-implementation command, with a
#       redundant settings put global webview_provider fallback write.
#    4. Confirming the change took effect by re reading dumpsys.
#    5. Only after AOSmium is the confirmed active provider, disabling the
#       stock Google or AOSP WebView with pm disable-user, then re
#       confirming AOSmium is still active and planting an uninstall
#       trampoline so the stock WebView always comes back on module
#       removal even via recovery. Skipped if the user opted out.
#    6. On any failure, flipping the module into inert mode so the next boot
#       does not retry and bootloop.
#    7. Always clearing the post-fs-data boot_pending marker so the sentinel
#       sees a clean state on the next boot.
#
#  Google Chrome and the Trichrome library are never touched, so Chrome
#  continues to work after the stock WebView is disabled.
##############################################################################

MODDIR=${0%/*}
LOG_DIR="$MODDIR/logs"
mkdir -p "$LOG_DIR" 2>/dev/null
LOG="$LOG_DIR/service.log"
USER_LOG="$MODDIR/webview_activation.log"

AOSMIUM_PKG="org.axpos.aosmium_wv"

ts() { date '+%Y-%m-%d %H:%M:%S'; }
log() {
    echo "[$(ts)] $1" >> "$LOG"
    echo "[$(ts)] $1" >> "$USER_LOG"
}

log "service.sh start"

##############################################################################
#  Wait for boot completion. resetprop is shipped with Magisk and is more
#  reliable than polling getprop in a loop.
##############################################################################

resetprop -w sys.boot_completed 0 >/dev/null 2>&1
log "Boot complete signal received."

# PackageManager and WebViewUpdateService finish settling a few seconds after
# sys.boot_completed flips. Sleep enough that pm list and dumpsys can answer
# authoritatively without race.
sleep 10

##############################################################################
#  Inert mode short circuit. If we were flipped inert by the bootloop
#  sentinel, do nothing and clear the pending marker.
##############################################################################

if [ -f "$MODDIR/inert" ]; then
    log "Inert mode is set. Skipping activation."
    rm -f "$MODDIR/boot_pending"
    exit 0
fi

##############################################################################
#  Visibility check. The RRO plus bind mount has made AOSmium present in the
#  systemless overlay; PackageManager should now list it.
##############################################################################

VISIBLE=$(pm list packages "$AOSMIUM_PKG" 2>/dev/null | grep -c "^package:${AOSMIUM_PKG}$")
if [ "$VISIBLE" -ne 1 ]; then
    log "FAIL: PackageManager does not see $AOSMIUM_PKG."
    log "Likely cause: RRO did not register or APK bind mount did not land."
    log "Flipping module to inert mode."
    touch "$MODDIR/inert"
    rm -f "$MODDIR/boot_pending"
    exit 0
fi
log "PackageManager sees $AOSMIUM_PKG"

##############################################################################
#  Promote AOSmium. The cmd webviewupdate API has been stable since Android 7
#  and is the canonical activation mechanism.
##############################################################################

# Clear any previously disabled WebView packages first. This is idempotent
# and recovers from situations where a prior install left the package list
# in an odd state.
cmd webviewupdate enable-redundant-packages >> "$LOG" 2>&1

# Authoritative activation call.
SETIMPL_OUT=$(cmd webviewupdate set-webview-implementation "$AOSMIUM_PKG" 2>&1)
log "cmd webviewupdate set-webview-implementation: $SETIMPL_OUT"

# Belt and braces. The settings global write is read by the framework on
# subsequent boots and survives reboot even if the cmd above is a no op
# on some OEM build.
settings put global webview_provider "$AOSMIUM_PKG" 2>>"$LOG"

##############################################################################
#  Verification. The only authoritative source for the current provider is
#  dumpsys webviewupdate, since cmd set-webview-implementation has been
#  observed to return exit code 0 on silent no ops on some OEM builds.
##############################################################################

# Allow a moment for the framework to settle on the new selection.
sleep 3

CURRENT=$(dumpsys webviewupdate 2>/dev/null \
    | sed -n 's/.*Current WebView package[^:]*: (\([^,)]*\).*/\1/p' \
    | head -1 | tr -d ' ')

if [ "$CURRENT" = "$AOSMIUM_PKG" ]; then
    log "SUCCESS: Active WebView provider is now $AOSMIUM_PKG"
    log "Activation complete."

    ##########################################################################
    #  Stock WebView removal. This block only runs when AOSmium is the
    #  confirmed active provider, so there is always at least one valid
    #  provider on the device at all times and the framework cannot end up
    #  with zero providers. The stock package is disabled, not deleted, and
    #  is fully restored by uninstall.sh. We never touch the Trichrome
    #  library or Google Chrome, so Chrome keeps working.
    #
    #  The user can opt out by creating /data/adb/dresoswv_keep_stock_webview
    #  before flashing, which makes customize.sh drop a keep_stock_webview
    #  marker into the module directory.
    ##########################################################################

    if [ -f "$MODDIR/keep_stock_webview" ]; then
        log "Opt out marker present. Leaving stock WebView enabled."
    else
        # Probe for the stock provider package by name. GMS and Pixel
        # devices ship com.google.android.webview. AOSP, LineageOS and
        # similar ship com.android.webview. We never assume a filesystem
        # path, only the package name, so this works on every OEM.
        STOCK_WV=""
        if pm path com.google.android.webview >/dev/null 2>&1; then
            STOCK_WV="com.google.android.webview"
        elif pm path com.android.webview >/dev/null 2>&1; then
            STOCK_WV="com.android.webview"
        fi

        if [ -z "$STOCK_WV" ]; then
            log "No stock WebView package found to disable. Nothing to do."
        elif [ "$STOCK_WV" = "$AOSMIUM_PKG" ]; then
            log "Stock probe resolved to AOSmium itself. Skipping disable."
        else
            log "Disabling stock WebView package: $STOCK_WV"
            DIS_OUT=$(pm disable-user --user 0 "$STOCK_WV" 2>&1)
            log "pm disable-user: $DIS_OUT"

            # Authoritative verification. enabled=3 is DISABLED_USER.
            ENABLED_STATE=$(dumpsys package "$STOCK_WV" 2>/dev/null \
                | grep -m1 "enabled=" | tr -d ' ')
            log "Post disable state: $ENABLED_STATE"

            # Re confirm AOSmium is still the active provider after the
            # disable. If for any reason it is not, immediately re enable
            # the stock package so the device is never left with a broken
            # WebView, and flip to inert mode.
            sleep 2
            RECHECK=$(dumpsys webviewupdate 2>/dev/null \
                | sed -n 's/.*Current WebView package[^:]*: (\([^,)]*\).*/\1/p' \
                | head -1 | tr -d ' ')
            if [ "$RECHECK" = "$AOSMIUM_PKG" ]; then
                log "Confirmed: AOSmium still active after disabling $STOCK_WV."
                # Drop a marker so uninstall.sh knows it must re enable.
                echo "$STOCK_WV" > "$MODDIR/disabled_stock_webview"

                # Plant a one shot self deleting re enable trampoline
                # OUTSIDE the module directory. Magisk keeps executing
                # scripts in post-fs-data.d even after the module itself
                # is removed, including removal via recovery where
                # uninstall.sh never runs. This is the safety net that
                # guarantees the stock WebView always comes back.
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
                    echo "  pm enable $STOCK_WV"
                    echo '  pm enable com.google.android.webview 2>/dev/null'
                    echo '  pm enable com.android.webview 2>/dev/null'
                    echo '  settings delete global webview_provider 2>/dev/null'
                    echo '  rm -- "$0"'
                    echo ') &'
                } > "$TRAMP"
                chmod 0755 "$TRAMP" 2>/dev/null
                log "Restore trampoline planted at $TRAMP"
            else
                log "WARNING: AOSmium no longer active after disable."
                log "Re enabling $STOCK_WV to keep the device safe."
                pm enable "$STOCK_WV" >> "$LOG" 2>&1
                touch "$MODDIR/inert"
            fi
        fi
    fi
else
    log "FAIL: Active provider is '$CURRENT', expected '$AOSMIUM_PKG'."
    log "Possible causes:"
    log "  RRO loaded but signature mismatch on AOSmium APK."
    log "  AOSmium versionCode below preinstalled provider (unlikely)."
    log "  OEM lock that prevents non OEM WebView providers."
    log "Flipping module to inert mode."
    touch "$MODDIR/inert"
fi

##############################################################################
#  Always clear the boot_pending marker. We reached this far without crashing
#  the framework, so the sentinel must not interpret the next boot as a
#  recovery from a bootloop.
##############################################################################

rm -f "$MODDIR/boot_pending"
log "service.sh end"
exit 0
