#!/system/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# DresOS AOSmium WebView - service.sh v1.1.0
# Copyright (C) 2026 DresOperatingSystems

MODDIR="${0%/*}"
PKGNAME="org.axpos.aosmium_wv"
LOG="$MODDIR/activation.log"

until [[ "$(getprop sys.boot_completed)" = "1" ]]; do sleep 3; done
sleep 8

{
    echo "=== DresOS AOSmium WebView v1.1.0 - boot activation ==="
    echo "Time:   $(date)"
    echo "API:    $(getprop ro.build.version.sdk)"
    echo "ROM:    $(getprop ro.build.display.id)"
    echo "Device: $(getprop ro.product.model)"
    echo ""

    PM_CHECK=$(pm list packages 2>/dev/null | grep "$PKGNAME")
    echo "AOSmium registered: ${PM_CHECK:-NOT FOUND}"

    if [[ -z "$PM_CHECK" ]]; then
        echo "Not registered - retrying pm install..."
        APK="/system/product/app/AosmiumWebView/AosmiumWebView.apk"
        [[ ! -f "$APK" ]] && APK="/system/app/AosmiumWebView/AosmiumWebView.apk"
        [[ ! -f "$APK" ]] && APK="$MODDIR/system/product/app/AosmiumWebView/AosmiumWebView.apk"
        if [[ -f "$APK" ]]; then
            cp "$APK" /data/local/tmp/AosmiumWebView.apk
            RESULT=$(pm install --install-location 1 /data/local/tmp/AosmiumWebView.apk 2>&1)
            echo "Retry result: $RESULT"
            rm -f /data/local/tmp/AosmiumWebView.apk
        else
            echo "APK not found for retry"
        fi
    fi

    SET=$(cmd webviewupdate set-webview-implementation "$PKGNAME" 2>&1)
    echo "webviewupdate: $SET"

    echo ""
    echo "--- WebView state ---"
    dumpsys webviewupdate 2>/dev/null \
        | grep -iE "current|preferred|packages:|valid|installed|aosmium|webview" \
        | head -20

} > "$LOG" 2>&1
