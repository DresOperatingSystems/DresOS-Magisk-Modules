#!/system/bin/sh

ui_print " "
ui_print "==============================================="
ui_print "  DresOS AOSmium WebView"
ui_print "  Version v2.1.0"
ui_print "  Chromium 147.0.7727.49 (AXP.OS)"
ui_print "==============================================="
ui_print " "

if [ -z "$MAGISK_VER_CODE" ] || [ "$MAGISK_VER_CODE" -lt 24000 ]; then
    abort "! Magisk 24.0 or newer is required."
fi

API_LEVEL=$(getprop ro.build.version.sdk)
if [ "$API_LEVEL" -lt 29 ] || [ "$API_LEVEL" -gt 35 ]; then
    abort "! Requires Android 10 through 15."
fi

ABI=$(getprop ro.product.cpu.abi)
case "$ABI" in
    arm64-v8a) APK_SRC_NAME="webview64-signed.apk" ;;
    armeabi-v7a|armeabi) APK_SRC_NAME="webview32-signed.apk" ;;
    *) abort "! Unsupported ABI: $ABI" ;;
esac

if ls -d /apex/com.google.android.webview* /apex/com.android.webview.app* >/dev/null 2>&1; then
    abort "! Device packages WebView as APEX. Not supported."
fi

if ! dumpsys webviewupdate 2>/dev/null | grep -q "Current WebView package"; then
    abort "! WebViewUpdateService not responding."
fi

APP_DIR="system/product/app/AOSmiumWebView"
OVERLAY_DIR="system/product/overlay"
EXTRA_OVERLAY_DIR=""

[ "$API_LEVEL" -eq 29 ] && EXTRA_OVERLAY_DIR="system/vendor/overlay"

MFG=$(getprop ro.product.manufacturer | tr 'A-Z' 'a-z')
if [ "$MFG" = "samsung" ] && [ -d /system_ext/overlay ]; then
    OVERLAY_DIR="system/system_ext/overlay"
fi

mkdir -p "$MODPATH/$APP_DIR" "$MODPATH/$OVERLAY_DIR"
[ -n "$EXTRA_OVERLAY_DIR" ] && mkdir -p "$MODPATH/$EXTRA_OVERLAY_DIR"

cp -f "$MODPATH/webview/$APK_SRC_NAME" "$MODPATH/$APP_DIR/AOSmiumWebView.apk"
cp -f "$MODPATH/overlay/DresOSAOSmiumOverlay.apk" "$MODPATH/$OVERLAY_DIR/DresOSAOSmiumOverlay.apk"
[ -n "$EXTRA_OVERLAY_DIR" ] && cp -f "$MODPATH/overlay/DresOSAOSmiumOverlay.apk" "$MODPATH/$EXTRA_OVERLAY_DIR/DresOSAOSmiumOverlay.apk"

rm -rf "$MODPATH/webview" "$MODPATH/overlay"

set_perm_recursive "$MODPATH/system" 0 0 0755 0644

rm -f "$MODPATH/boot_pending" "$MODPATH/inert" "$MODPATH/disable" 2>/dev/null
mkdir -p "$MODPATH/logs"

ui_print " "
ui_print "  Install complete. Reboot to activate."
ui_print " "
