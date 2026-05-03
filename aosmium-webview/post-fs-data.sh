#!/system/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# DresOS AOSmium WebView - post-fs-data.sh
# Copyright (C) 2026 DresOperatingSystems
#
# Runs at early boot before Android framework initialises.
# For KernelSU: applies the opaque overlay attribute to hidden
# package dirs so they are invisible to the package manager.
# For all modes: clears stale shared_relro library mappings from
# any previously active WebView provider.
##########################################################################

MODDIR="${0%/*}"

# Source debloat.sh to load pkg1-pkg6 paths saved during flash
[ -f "$MODDIR/debloat.sh" ] && source "$MODDIR/debloat.sh"

# KernelSU: set trusted.overlay.opaque on all hidden package dirs
# so the kernel presents them as empty directories to userspace.
if [[ "$KSU" ]]; then
    MODULE_PATH="/data/adb/modules/$(basename "$MODDIR")"
    for PKGPATH in "$pkg1" "$pkg2" "$pkg3" "$pkg4" "$pkg5" "$pkg6"; do
        [ -n "$PKGPATH" ] && setfattr -n trusted.overlay.opaque -v y \
            "$MODULE_PATH/$PKGPATH" 2>/dev/null
    done
fi

# Clear stale shared_relro cache entries for the old WebView.
# These are pre-compiled native library mappings that would otherwise
# cause the previous WebView's libraries to be loaded instead of AOSmium's.
rm -f /data/misc/shared_relro/*webview* 2>/dev/null
rm -f /data/misc/shared_relro/*chrome*  2>/dev/null
