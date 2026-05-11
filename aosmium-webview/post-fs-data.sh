#!/system/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# DresOS AOSmium WebView - post-fs-data.sh v1.1.0
# Copyright (C) 2026 DresOperatingSystems
#
# v1.1.0: com.android.webview is no longer hidden at this stage.
# Hiding AOSP WebView here caused bootloops on LineageOS 23.2 and
# Android 15+ Pixel devices. AOSmium coexists with stock WebView.

MODDIR="${0%/*}"

# Source debloat.sh for pkg paths (Google/Chrome/Samsung WebViews only)
[ -f "$MODDIR/debloat.sh" ] && source "$MODDIR/debloat.sh"

# KernelSU: apply opaque overlay to hidden Google/Chrome packages
if [[ "$KSU" ]]; then
    MODULE_PATH="/data/adb/modules/$(basename "$MODDIR")"
    for PKGPATH in "$pkg1" "$pkg2" "$pkg3" "$pkg4" "$pkg5"; do
        [ -n "$PKGPATH" ] && setfattr -n trusted.overlay.opaque -v y \
            "$MODULE_PATH/$PKGPATH" 2>/dev/null
    done
fi

# Clear stale shared_relro entries from previous WebView
rm -f /data/misc/shared_relro/*webview* 2>/dev/null
rm -f /data/misc/shared_relro/*chrome*  2>/dev/null
