#!/system/bin/sh
##############################################################################
#  DresOS AOSmium WebView
#  Systemless WebView replacement for Android 10 through 16 and newer
#  dresoperatingsystems.github.io
##############################################################################
#
#  This script runs once at flash time inside Magisk. It does the following:
#    1. Prints a banner identifying the module.
#    2. Validates the host: Magisk version, Android API level, ABI.
#    3. Confirms WebViewUpdateService is alive and not living inside an APEX.
#    4. Selects the correct AOSmium APK for the device ABI.
#    5. Detects the right partition layout for the RRO and the AOSmium APK.
#    6. Builds the systemless tree under $MODPATH/system/.
#    7. Sets file permissions and SELinux contexts via Magisk helpers.
#    8. Marks the module fresh so post-fs-data does not treat the next boot
#       as a recovered bootloop.
#
#  The script never calls pm install. It never modifies real /system. The
#  stock Google or AOSP WebView is left fully intact at flash time and is
#  only disabled later by service.sh, after AOSmium is confirmed active,
#  and only if the user opted in. Everything happens inside the module
#  directory and is mounted by Magisk magic mount.
##############################################################################


ui_print " "
ui_print "==============================================="
ui_print "  DresOS AOSmium WebView"
ui_print "  Version v2.2.0"
ui_print "  Chromium 147.0.7727.49 (AXP.OS)"
ui_print "  dresoperatingsystems.github.io"
ui_print "==============================================="
ui_print " "

##############################################################################
#  Stage 1: Magisk version gate. v29.0 (29000) is the floor. The rewritten
#  magic mount backend and Android 16 QPR2 sepolicy support landed in the
#  v29 to v30 series, and this module relies on correct /product magic
#  mount behaviour on modern Android.
##############################################################################

if [ -z "$MAGISK_VER_CODE" ] || [ "$MAGISK_VER_CODE" -lt 29000 ]; then
    ui_print "! Magisk 29.0 or newer is required."
    ui_print "! Detected Magisk version code: $MAGISK_VER_CODE"
    abort "! Aborting install."
fi
ui_print "  Magisk version code: $MAGISK_VER_CODE"

##############################################################################
#  Stage 2: Android API gate. Android 10 (29) is the hard floor. Android 16
#  (36) is the highest tested version. Anything newer than the tested
#  ceiling warns and proceeds rather than aborting, because aborting on a
#  too new Android version strands users on every future release with no
#  recourse. WebViewUpdateService, config_webview_packages, RRO handling,
#  and cmd webviewupdate are unchanged through API 36, so this is safe.
##############################################################################

API_LEVEL=$(getprop ro.build.version.sdk)
ANDROID_REL=$(getprop ro.build.version.release)
ui_print "  Android version: $ANDROID_REL (API $API_LEVEL)"

TESTED_MAX_API=36

if [ "$API_LEVEL" -lt 29 ]; then
    ui_print "! Android 10 (API 29) or newer is required."
    abort "! Aborting install."
fi
if [ "$API_LEVEL" -gt "$TESTED_MAX_API" ]; then
    ui_print "! Untested on API $API_LEVEL (tested up to API $TESTED_MAX_API, Android 16)."
    ui_print "! Proceeding anyway. If WebView does not activate, report it at"
    ui_print "! github.com/DresOperatingSystems/DresOS-Magisk-Modules"
fi

##############################################################################
#  Stage 3: ABI gate. AXP.OS does not ship x86 or x86_64 WebView builds.
##############################################################################

ABI=$(getprop ro.product.cpu.abi)
ui_print "  Device ABI: $ABI"

case "$ABI" in
    arm64-v8a)
        APK_SRC_NAME="webview64-signed.apk"
        ABI_LABEL="arm64"
        ;;
    armeabi-v7a|armeabi)
        APK_SRC_NAME="webview32-signed.apk"
        ABI_LABEL="arm"
        ;;
    x86|x86_64)
        ui_print "! AXP.OS does not publish x86 or x86_64 AOSmium builds."
        ui_print "! See codeberg.org/AXP-OS/app_aosmium for available ABIs."
        abort "! Aborting install."
        ;;
    *)
        ui_print "! Unsupported ABI: $ABI"
        abort "! Aborting install."
        ;;
esac
ui_print "  Selected APK: $APK_SRC_NAME"

##############################################################################
#  Stage 4: APEX guard. As of May 2026, no shipping device packages
#  com.google.android.webview as an APEX (the Android 15 APEX
#  com.android.webview.bootstrap is framework glue only). If a device
#  ever does, refuse to install rather than guess.
##############################################################################

if ls -d /apex/com.google.android.webview* >/dev/null 2>&1; then
    ui_print "! This device packages WebView as an APEX module."
    ui_print "! Systemless replacement is unsafe in that configuration."
    abort "! Aborting install."
fi
if ls -d /apex/com.android.webview.app* >/dev/null 2>&1; then
    ui_print "! This device packages WebView as an APEX module."
    abort "! Aborting install."
fi

##############################################################################
#  Stage 5: WebViewUpdateService liveness. If the framework cannot answer
#  dumpsys, the device is already broken and we should not touch it.
##############################################################################

CURRENT_WV=$(dumpsys webviewupdate 2>/dev/null | grep "Current WebView package" | head -1)
if [ -z "$CURRENT_WV" ]; then
    ui_print "! WebViewUpdateService is not responding."
    ui_print "! Refusing to install on a device that already has a broken WebView."
    abort "! Aborting install."
fi
ui_print "  Existing provider: $(echo "$CURRENT_WV" | sed 's/.*Current WebView package //' | tr -d '()')"

##############################################################################
#  Stage 6: Partition layout. The default is product, which works on every
#  device from Android 10 through 15. On Android 10 specifically, drop a
#  duplicate overlay into vendor/overlay as a belt and braces against the
#  product overlay allow list quirks on some early Treble devices.
##############################################################################

APP_DIR="system/product/app/AOSmiumWebView"
OVERLAY_DIR="system/product/overlay"
EXTRA_OVERLAY_DIR=""

if [ "$API_LEVEL" -eq 29 ]; then
    EXTRA_OVERLAY_DIR="system/vendor/overlay"
fi

# Samsung One UI prefers system_ext where available. Use it only if the
# directory exists on the live system.
MFG=$(getprop ro.product.manufacturer | tr 'A-Z' 'a-z')
if [ "$MFG" = "samsung" ] && [ -d /system_ext/overlay ]; then
    OVERLAY_DIR="system/system_ext/overlay"
    ui_print "  Samsung One UI detected, using system_ext overlay path."
fi

ui_print "  APK target dir: /$(echo "$APP_DIR" | sed 's|system/||')"
ui_print "  RRO target dir: /$(echo "$OVERLAY_DIR" | sed 's|system/||')"
if [ -n "$EXTRA_OVERLAY_DIR" ]; then
    ui_print "  RRO duplicate: /$(echo "$EXTRA_OVERLAY_DIR" | sed 's|system/||')"
fi

##############################################################################
#  Stage 7: Build the systemless tree.
##############################################################################

ui_print "  Building systemless tree."

mkdir -p "$MODPATH/$APP_DIR"
mkdir -p "$MODPATH/$OVERLAY_DIR"
[ -n "$EXTRA_OVERLAY_DIR" ] && mkdir -p "$MODPATH/$EXTRA_OVERLAY_DIR"

APK_SRC="$MODPATH/webview/$APK_SRC_NAME"
if [ ! -f "$APK_SRC" ]; then
    ui_print "! Bundled APK missing: $APK_SRC"
    abort "! Aborting install."
fi

cp -f "$APK_SRC" "$MODPATH/$APP_DIR/AOSmiumWebView.apk"

RRO_SRC="$MODPATH/overlay/DresOSAOSmiumOverlay.apk"
if [ ! -f "$RRO_SRC" ]; then
    ui_print "! Bundled overlay missing: $RRO_SRC"
    abort "! Aborting install."
fi
cp -f "$RRO_SRC" "$MODPATH/$OVERLAY_DIR/DresOSAOSmiumOverlay.apk"
if [ -n "$EXTRA_OVERLAY_DIR" ]; then
    cp -f "$RRO_SRC" "$MODPATH/$EXTRA_OVERLAY_DIR/DresOSAOSmiumOverlay.apk"
fi

# Remove the staging copies. Magisk packs the module tree exactly as it sits,
# so leaving them in $MODPATH/webview and $MODPATH/overlay would just inflate
# the installed footprint.
rm -rf "$MODPATH/webview"
rm -rf "$MODPATH/overlay"

##############################################################################
#  Stage 8: Permissions and SELinux contexts. Magisk handles SELinux via
#  set_perm_recursive when the partition prefix matches system, so a single
#  recursive call gives every file the correct u:object_r:system_file:s0
#  context on every supported Android version.
##############################################################################

set_perm_recursive "$MODPATH/system" 0 0 0755 0644

##############################################################################
#  Stage 9: Prepare runtime state. Clear any stale sentinels from a previous
#  install of this module so post-fs-data does not flip us into inert mode
#  on the first boot.
##############################################################################

rm -f "$MODPATH/boot_pending" 2>/dev/null
rm -f "$MODPATH/inert" 2>/dev/null
rm -f "$MODPATH/disable" 2>/dev/null

mkdir -p "$MODPATH/logs"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] Install complete. Awaiting reboot." \
    > "$MODPATH/logs/install.log"

##############################################################################
#  Stage 9b: Stock WebView removal opt out. By default this module disables
#  the stock Google or AOSP WebView after AOSmium is confirmed active, so
#  that the privacy hardened engine is the only WebView on the device. A
#  user who wants the stock WebView left enabled can opt out by creating
#  the file /data/adb/dresoswv_keep_stock_webview before first boot. If
#  that file exists at flash time we copy a marker into the module so
#  service.sh knows to skip the disable step.
##############################################################################

if [ -f /data/adb/dresoswv_keep_stock_webview ]; then
    touch "$MODPATH/keep_stock_webview"
    ui_print "  Opt out file found. Stock WebView will be left enabled."
else
    ui_print "  Stock WebView will be disabled after AOSmium is confirmed active."
    ui_print "  To keep the stock WebView, create the file"
    ui_print "  /data/adb/dresoswv_keep_stock_webview and reflash."
fi

##############################################################################
#  Stage 10: Confirmation banner.
##############################################################################

ui_print " "
ui_print "==============================================="
ui_print "  Install complete."
ui_print " "
ui_print "  Reboot to activate AOSmium WebView."
ui_print "  After boot, verify with:"
ui_print "    adb shell dumpsys webviewupdate | grep Current"
ui_print " "
ui_print "  Activation log will be written to:"
ui_print "    /data/adb/modules/dresoswv/logs/service.log"
ui_print "    /data/adb/modules/dresoswv/webview_activation.log"
ui_print "==============================================="
ui_print " "
