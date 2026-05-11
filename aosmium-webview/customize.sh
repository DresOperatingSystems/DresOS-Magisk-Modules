#!/system/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# DresOS AOSmium WebView - customize.sh v1.1.0
# Copyright (C) 2026 DresOperatingSystems
# https://github.com/DresOperatingSystems/DresOS-Magisk-Modules
#
# v1.1.0 - Bootloop fix for LineageOS 23.2 and Pixel 9 series:
#   com.android.webview (stock AOSP WebView) is NO LONGER hidden.
#   Hiding it at post-fs-data caused bootloops because /data is not
#   mounted at that stage so AOSmium was not yet visible to Android,
#   leaving no valid WebView provider and triggering a system crash.
#   AOSmium now coexists alongside the stock WebView. Use Developer
#   Options > WebView implementation to switch after reboot.
#
# WebView hiding and install approach adapted from:
#   Lubald/AOSmium-WebView (GPL-2.0)
#   Lordify/WebView-Changer (GPL-3.0)
##########################################################################

echo
echo "##################################################"
echo "##   DresOS AOSmium WebView                    ##"
echo "##   Chromium 147.0.7727.49                    ##"
echo "##   Hardened by GrapheneOS / Vanadium patches ##"
echo "##   v1.1.0 - LineageOS 23.2 bootloop fix      ##"
echo "##   github.com/DresOperatingSystems            ##"
echo "##################################################"
echo

# ----------------------------------------------------------------
# Validation
# ----------------------------------------------------------------
[[ $API -lt 29 ]] && abort "Android 10 (API 29) or higher required. Found: API $API"
[[ "$ARCH" != "arm" && "$ARCH" != "arm64" ]] && abort "ARM or ARM64 required. Found: $ARCH"
echo "Device check passed: API $API | $ARCH"
echo

# ----------------------------------------------------------------
# dresoswv_remove_update: uninstall a data-partition APK update
# for a package if one exists.
# ----------------------------------------------------------------
dresoswv_remove_update() {
    local PKG="$1"
    local UPDATEPATH
    UPDATEPATH=$(pm dump "$PKG" | grep "codePath=/data" | grep -o "/.*")
    if [[ -d "$UPDATEPATH" ]]; then
        echo "  Removing update: $PKG"
        pm uninstall "$PKG"
    fi
}

# ----------------------------------------------------------------
# dresoswv_hide: systemlessly hide a package's system path.
#
# IMPORTANT - com.android.webview is deliberately NOT in this list.
# Hiding it via .replace at post-fs-data stage causes bootloops on
# LineageOS 23.2 and Android 15+ Pixel devices because /data is not
# mounted at that stage, so AOSmium (installed to /data/app) is not
# visible yet, leaving Android with no valid WebView provider.
#
# We hide: Google WebView, Chrome, TrichromeLibrary, Samsung/OEM
# We do NOT hide: com.android.webview (stock AOSP fallback)
# ----------------------------------------------------------------
dresoswv_hide() {
    local PKG="$1"
    local VARNAME="$2"
    local PKGPATH
    PKGPATH=$(pm dump "$PKG" | grep "codePath" | grep -o "/.*")
    if [[ -d "$PKGPATH" ]]; then
        if [[ "$KSU" ]]; then
            mkdir -p "$MODPATH/$PKGPATH"
        else
            mktouch "$MODPATH/$PKGPATH/.replace"
        fi
        echo "  Hidden: $PKG ($PKGPATH)"
        echo "${VARNAME}=${PKGPATH}" >> "$MODPATH/debloat.sh"
    else
        echo "  Not found: $PKG"
    fi
}

# ----------------------------------------------------------------
# Step 1: Remove data-partition updates
# Note: we still remove the com.android.webview DATA update if one
# exists - we only avoid hiding the SYSTEM version at boot time.
# ----------------------------------------------------------------
echo "Removing competing WebView data updates..."
dresoswv_remove_update com.android.webview
dresoswv_remove_update com.android.chrome
dresoswv_remove_update com.google.android.webview
dresoswv_remove_update org.mozilla.webview_shell
dresoswv_remove_update com.sec.android.app.chromecustomizations
dresoswv_remove_update com.google.android.trichromelibrary
echo "Done."
echo

# ----------------------------------------------------------------
# Step 2: Systemlessly hide competing WebView packages.
# com.android.webview is intentionally excluded - see comment above.
# ----------------------------------------------------------------
echo "Hiding competing WebView packages..."
echo "  Note: com.android.webview kept visible to prevent bootloop"
echo "  It will appear alongside AOSmium in Developer Options"
dresoswv_hide com.android.chrome            pkg1
dresoswv_hide com.google.android.webview    pkg2
dresoswv_hide org.mozilla.webview_shell     pkg3
dresoswv_hide com.sec.android.app.chromecustomizations pkg4
dresoswv_hide com.google.android.trichromelibrary      pkg5
echo "Done."
echo

# ----------------------------------------------------------------
# Step 3: Partition remapping
# ----------------------------------------------------------------
for PART in product vendor system_ext; do
    PARTDIR="$MODPATH/$PART"
    if [[ -d "$PARTDIR" ]]; then
        echo "Remapping /$PART to /system/$PART..."
        mkdir -p "$MODPATH/system/$PART"
        cp -a "$PARTDIR/." "$MODPATH/system/$PART/"
        rm -rf "$PARTDIR"
    fi
done

# ----------------------------------------------------------------
# Step 4: Install AOSmium and place overlay
# ----------------------------------------------------------------
echo "Installing AOSmium..."
[ -f "$MODPATH/common/install.sh" ] && . "$MODPATH/common/install.sh"

echo
echo "##################################################"
echo "##   Done. REBOOT NOW.                         ##"
echo "##   After reboot:                             ##"
echo "##   Settings > Developer Options              ##"
echo "##   > WebView implementation                  ##"
echo "##   > Select: AOSmium WebView                 ##"
echo "##   (Stock WebView also visible - that is OK) ##"
echo "##################################################"
echo
