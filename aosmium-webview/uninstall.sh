#!/system/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# DresOS AOSmium WebView - uninstall.sh
# Copyright (C) 2026 DresOperatingSystems
##########################################################################

MODDIR="${0%/*}"
[ -f "$MODDIR/debloat.sh" ] && source "$MODDIR/debloat.sh"

# Revert system WebView to stock before uninstalling
cmd webviewupdate set-webview-implementation com.android.webview 2>/dev/null

# Wait for boot to complete before uninstalling
waitUntilBootCompleted() {
    resetprop -w sys.boot_completed 0 && return
    while [[ $(getprop sys.boot_completed) -eq 0 ]]; do sleep 10; done
}

(
    waitUntilBootCompleted
    sleep 3
    pm uninstall "$WV1" 2>/dev/null
    rm -f /data/misc/shared_relro/*webview* 2>/dev/null
    rm -f /data/misc/shared_relro/*chrome*  2>/dev/null
) &
