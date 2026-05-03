# DresOS AOSmium WebView - common/install.sh
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 DresOperatingSystems
#
# Installs bundled AOSmium APK to system/[product/]app and runs
# pm install so the package manager registers it. Detects correct
# overlay directory and places the RRO allowlist patch APK.
##########################################################################

DRESOSWV_LOG="$MODPATH/install.log"
DRESOSWV_APK="$MODPATH/apk/AOSmiumWebView.apk"
DRESOSWV_TMP="/data/local/tmp/AosmiumWebView.apk"

{
    echo "=== DresOS AOSmium WebView install log ==="
    echo "Date: $(date)"
    echo "API: $API | Arch: $ARCH"
    echo "ROM: $(getprop ro.build.display.id)"
} > "$DRESOSWV_LOG"

# ----------------------------------------------------------------
# Determine install path.
# LineageOS stores product apps under system/product/app.
# Stock Android uses system/app.
# ----------------------------------------------------------------
local LOS
LOS=$(getprop | grep -o -c "lineage")
if [[ $LOS -gt 0 ]]; then
    WVP=/system/product/app/AosmiumWebView
    echo "LineageOS ROM detected - using system/product/app"
    echo "ROM type: LineageOS" >> "$DRESOSWV_LOG"
else
    WVP=/system/app/AosmiumWebView
    echo "Stock/AOSP ROM - using system/app"
    echo "ROM type: AOSP/Other" >> "$DRESOSWV_LOG"
fi

mkdir -p "$MODPATH/$WVP"

# ----------------------------------------------------------------
# Copy the bundled APK into the module system path
# ----------------------------------------------------------------
if [[ ! -f "$DRESOSWV_APK" ]]; then
    abort "AOSmium APK not found in module. ZIP may be corrupt."
fi

cp "$DRESOSWV_APK" "$MODPATH/$WVP/AosmiumWebView.apk"
echo "APK path: $MODPATH/$WVP/AosmiumWebView.apk" >> "$DRESOSWV_LOG"

# ----------------------------------------------------------------
# Register with package manager via pm install.
# Copying to /data/local/tmp first ensures pm can read the file
# regardless of SELinux context on the module path.
# --install-location 1 = prefer internal storage
# ----------------------------------------------------------------
cp "$MODPATH/$WVP/AosmiumWebView.apk" "$DRESOSWV_TMP"
INSTALL_RESULT=$(pm install --install-location 1 "$DRESOSWV_TMP" 2>&1)
INSTALL_EXIT=$?
rm -f "$DRESOSWV_TMP"

echo "pm install: $INSTALL_RESULT (exit $INSTALL_EXIT)" >> "$DRESOSWV_LOG"
echo "pm install: $INSTALL_RESULT"

if [[ $INSTALL_EXIT -ne 0 ]]; then
    echo "WARNING: pm install returned non-zero. APK may still mount correctly." | tee -a "$DRESOSWV_LOG"
fi

# ----------------------------------------------------------------
# Overlay - patches Android's config_webview_packages allowlist
# to include org.axpos.aosmium_wv.
# Probe all known overlay directories in preference order.
# Always use system/ prefix in module path so Magisk mounts correctly.
# ----------------------------------------------------------------
echo "Detecting overlay directory..."
echo "Overlay detection:" >> "$DRESOSWV_LOG"

if [[ $LOS -gt 0 ]]; then
    OVERLAY_PATH=system/product/overlay/
elif [[ -d /system/product/overlay ]]; then
    OVERLAY_PATH=system/product/overlay/
elif [[ -d /system_ext/overlay ]]; then
    OVERLAY_PATH=system/system_ext/overlay/
elif [[ -d /system/overlay ]]; then
    OVERLAY_PATH=system/overlay/
elif [[ -d /system/vendor/overlay ]]; then
    OVERLAY_PATH=system/vendor/overlay/
else
    abort "No valid overlay directory found on this device. Cannot patch WebView allowlist."
fi

echo "  Using: $OVERLAY_PATH" | tee -a "$DRESOSWV_LOG"
mkdir -p "$MODPATH/$OVERLAY_PATH"
cp "$MODPATH/Overlay/WebViewOverlay29.apk" "$MODPATH/$OVERLAY_PATH/WebViewOverlay.apk"
echo "Overlay installed at: $OVERLAY_PATH"

# ----------------------------------------------------------------
# Write the installed package name to debloat.sh so uninstall.sh
# can remove it when the module is uninstalled.
# ----------------------------------------------------------------
echo "WV1=org.axpos.aosmium_wv" >> "$MODPATH/debloat.sh"

# ----------------------------------------------------------------
# Cleanup - remove bundled files no longer needed in module dir
# ----------------------------------------------------------------
rm -rf "$MODPATH/Overlay"
rm -rf "$MODPATH/common"
rm -rf "$MODPATH/apk"
rm -f  "$MODPATH/system/.placeholder"

echo "AOSmium WebView installed successfully." | tee -a "$DRESOSWV_LOG"
