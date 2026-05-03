#!/system/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# DresOS AOSmium WebView - service.sh
# Copyright (C) 2026 DresOperatingSystems
#
# Runs after Android has fully booted. Verifies AOSmium is
# registered and attempts to activate it as system WebView.
# Writes a full diagnostic log for troubleshooting.
##########################################################################

MODDIR="${0%/*}"
PKGNAME="org.axpos.aosmium_wv"
LOG="$MODDIR/activation.log"

# Wait for full boot
until [[ "$(getprop sys.boot_completed)" = "1" ]]; do sleep 3; done
sleep 8

{
    echo "=== DresOS AOSmium WebView - boot activation ==="
    echo "Time: $(date)"
    echo "API:  $(getprop ro.build.version.sdk)"
    echo "ROM:  $(getprop ro.build.display.id)"
    echo ""

    # Check package is registered
    PM_CHECK=$(pm list packages 2>/dev/null | grep "$PKGNAME")
    echo "Registered: ${PM_CHECK:-NOT FOUND}"

    # If not registered (e.g. after data wipe), bail - user needs to reflash
    if [[ -z "$PM_CHECK" ]]; then
        echo "AOSmium not registered. Reflash the module to reinstall."
    else
        # Attempt to set as active WebView implementation
        SET=$(cmd webviewupdate set-webview-implementation "$PKGNAME" 2>&1)
        echo "webviewupdate: $SET"
    fi

    echo ""
    echo "--- WebView state (dumpsys) ---"
    dumpsys webviewupdate 2>/dev/null \
        | grep -iE "current|preferred|packages:|valid|installed|aosmium|webview" \
        | head -20

} > "$LOG" 2>&1
