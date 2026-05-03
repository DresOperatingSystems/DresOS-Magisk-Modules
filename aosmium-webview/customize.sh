#!/system/bin/sh
# SPDX-License-Identifier: GPL-3.0-or-later
# DresOS AOSmium WebView - customize.sh
# Copyright (C) 2026 DresOperatingSystems
# https://github.com/DresOperatingSystems/DresOS-Magisk-Modules
#
# WebView hiding and installation approach adapted with reference to
# Lubald/AOSmium-WebView (GPL-2.0) and Lordify/WebView-Changer (GPL-3.0).
##########################################################################

echo
echo "##################################################"
echo "##   DresOS AOSmium WebView                    ##"
echo "##   Chromium 147.0.7727.49                    ##"
echo "##   Hardened by GrapheneOS / Vanadium patches ##"
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
# for a package if one exists. Uses codePath=/data to identify
# updates installed over the system version.
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
# Finds the system codePath via pm dump, then:
#   Magisk - creates a .replace file so Magisk bind-mounts an
#            empty dir over it at boot, hiding it from pm.
#   KernelSU - creates the dir (setfattr applied in post-fs-data).
# Saves the path to debloat.sh for post-fs-data and uninstall.
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
# Step 1: Remove data-partition updates of competing WebViews
# ----------------------------------------------------------------
echo "Removing competing WebView updates..."
dresoswv_remove_update com.android.chrome
dresoswv_remove_update com.android.webview
dresoswv_remove_update com.google.android.webview
dresoswv_remove_update org.mozilla.webview_shell
dresoswv_remove_update com.sec.android.app.chromecustomizations
dresoswv_remove_update com.google.android.trichromelibrary
echo "Done."
echo

# ----------------------------------------------------------------
# Step 2: Systemlessly hide competing system WebView packages
# ----------------------------------------------------------------
echo "Hiding competing system WebView packages..."
dresoswv_hide com.android.chrome            pkg1
dresoswv_hide com.android.webview           pkg2
dresoswv_hide com.google.android.webview    pkg3
dresoswv_hide org.mozilla.webview_shell     pkg4
dresoswv_hide com.sec.android.app.chromecustomizations pkg5
dresoswv_hide com.google.android.trichromelibrary      pkg6
echo "Done."
echo

# ----------------------------------------------------------------
# Step 3: Remap /product /vendor /system_ext into system/
# so Magisk mounts them correctly regardless of device partitioning.
# ----------------------------------------------------------------
for PART in product vendor system_ext; do
    PARTDIR="$MODPATH/$PART"
    if [[ -d "$PARTDIR" ]]; then
        echo "Remapping /$PART → /system/$PART..."
        mkdir -p "$MODPATH/system/$PART"
        cp -a "$PARTDIR/." "$MODPATH/system/$PART/"
        rm -rf "$PARTDIR"
    fi
done

# ----------------------------------------------------------------
# Step 4: Install AOSmium and place the allowlist overlay
# ----------------------------------------------------------------
echo "Installing AOSmium..."
[ -f "$MODPATH/common/install.sh" ] && . "$MODPATH/common/install.sh"

echo
echo "##################################################"
echo "##   Installation complete.                    ##"
echo "##   Reboot, then:                             ##"
echo "##   Settings > Developer Options              ##"
echo "##   > WebView implementation                  ##"
echo "##   > Select AOSmium WebView                  ##"
echo "##################################################"
echo
