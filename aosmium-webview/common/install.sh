# DresOS AOSmium WebView - common/install.sh v1.1.0
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 DresOperatingSystems
# Adapted from Lubald/AOSmium-WebView (GPL-2.0)

DRESOSWV_LOG="$MODPATH/install.log"
DRESOSWV_APK="$MODPATH/apk/AOSmiumWebView.apk"
DRESOSWV_TMP="/data/local/tmp/AosmiumWebView.apk"

{
    echo "=== DresOS AOSmium WebView v1.1.0 install log ==="
    echo "Date:   $(date)"
    echo "API:    $API"
    echo "Arch:   $ARCH"
    echo "ROM:    $(getprop ro.build.display.id)"
    echo "Device: $(getprop ro.product.model)"
    echo "Board:  $(getprop ro.product.board)"
} > "$DRESOSWV_LOG"

# ----------------------------------------------------------------
# Determine install path.
# LineageOS uses system/product/app. Stock/AOSP uses system/app.
# Also detect by checking actual partition layout.
# ----------------------------------------------------------------
local LOS
local WVP

LOS=$(getprop | grep -o -c "lineage")

# Extended LineageOS detection - also check crDroid, EvolutionX etc
# which share the same product/app layout
ROM_NAME=$(getprop ro.build.display.id | tr '[:upper:]' '[:lower:]')
IS_LOS_BASED=0
for ROM_PATTERN in lineage crdroid evolution calyx divestos; do
    if echo "$ROM_NAME" | grep -q "$ROM_PATTERN"; then
        IS_LOS_BASED=1
        break
    fi
done

if [[ $LOS -gt 0 ]] || [[ $IS_LOS_BASED -eq 1 ]]; then
    WVP=/system/product/app/AosmiumWebView
    echo "LineageOS-based ROM detected - using system/product/app" | tee -a "$DRESOSWV_LOG"
elif [[ -d /system/product/app ]]; then
    WVP=/system/product/app/AosmiumWebView
    echo "product/app directory detected - using system/product/app" | tee -a "$DRESOSWV_LOG"
else
    WVP=/system/app/AosmiumWebView
    echo "Using system/app" | tee -a "$DRESOSWV_LOG"
fi

mkdir -p "$MODPATH/$WVP"

# ----------------------------------------------------------------
# Copy APK
# ----------------------------------------------------------------
if [[ ! -f "$DRESOSWV_APK" ]]; then
    abort "AOSmium APK not found at $DRESOSWV_APK - ZIP may be corrupt"
fi

cp "$DRESOSWV_APK" "$MODPATH/$WVP/AosmiumWebView.apk"
echo "APK placed at: $MODPATH/$WVP/AosmiumWebView.apk" >> "$DRESOSWV_LOG"

# ----------------------------------------------------------------
# Register with pm install
# ----------------------------------------------------------------
cp "$MODPATH/$WVP/AosmiumWebView.apk" "$DRESOSWV_TMP"
INSTALL_RESULT=$(pm install --install-location 1 "$DRESOSWV_TMP" 2>&1)
INSTALL_EXIT=$?
rm -f "$DRESOSWV_TMP"

echo "pm install result: $INSTALL_RESULT (exit $INSTALL_EXIT)" | tee -a "$DRESOSWV_LOG"

if [[ $INSTALL_EXIT -ne 0 ]]; then
    echo "WARNING: pm install returned non-zero - check install.log" | tee -a "$DRESOSWV_LOG"
fi

# ----------------------------------------------------------------
# Overlay detection - probes all known paths in order
# Expanded for LineageOS 23.2 and Android 15+ partition layouts
# ----------------------------------------------------------------
echo "Detecting overlay directory..." | tee -a "$DRESOSWV_LOG"

OVERLAY_PATH=""

# Check actual paths on device first
for PROBE in \
    /system/product/overlay \
    /product/overlay \
    /system/overlay \
    /system_ext/overlay \
    /system/vendor/overlay \
    /vendor/overlay; do
    if [[ -d "$PROBE" ]]; then
        # Always map through system/ prefix in Magisk module
        OVERLAY_PATH="system${PROBE}"
        echo "  Found overlay dir: $PROBE -> module path: $OVERLAY_PATH" | tee -a "$DRESOSWV_LOG"
        break
    fi
done

if [[ -z "$OVERLAY_PATH" ]]; then
    # LineageOS default fallback
    OVERLAY_PATH="system/product/overlay"
    echo "  No overlay dir found - using fallback: $OVERLAY_PATH" | tee -a "$DRESOSWV_LOG"
fi

mkdir -p "$MODPATH/$OVERLAY_PATH"
cp "$MODPATH/Overlay/WebViewOverlay29.apk" "$MODPATH/$OVERLAY_PATH/WebViewOverlay.apk"
echo "Overlay placed at: $OVERLAY_PATH" | tee -a "$DRESOSWV_LOG"

# ----------------------------------------------------------------
# Write package name for uninstall.sh
# ----------------------------------------------------------------
echo "WV1=org.axpos.aosmium_wv" >> "$MODPATH/debloat.sh"

# ----------------------------------------------------------------
# Cleanup
# ----------------------------------------------------------------
rm -rf "$MODPATH/Overlay"
rm -rf "$MODPATH/common"
rm -rf "$MODPATH/apk"
rm -f  "$MODPATH/system/.placeholder"

echo "Install complete." | tee -a "$DRESOSWV_LOG"
