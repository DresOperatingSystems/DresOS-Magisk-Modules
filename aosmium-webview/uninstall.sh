#!/system/bin/sh

settings delete global webview_provider 2>/dev/null

if pm list packages | grep -q "^package:com.google.android.webview$"; then
    cmd webviewupdate set-webview-implementation com.google.android.webview 2>/dev/null
elif pm list packages | grep -q "^package:com.android.webview$"; then
    cmd webviewupdate set-webview-implementation com.android.webview 2>/dev/null
fi

exit 0
