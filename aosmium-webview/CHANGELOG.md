# DresOS AOSmium WebView changelog

## v2.1.0

Complete rewrite of the activation pipeline.

### Fixed
- Overlay APK is now properly compiled binary AXML with the AXP.OS certificate embedded.
- Overlay targets the framework android package instead of com.android.webview.
- pm install removed. APK placed in systemless tree at system/product/app/AOSmiumWebView/.
- Magisk replace markers on com.android.webview removed.
- Activation runs in service.sh after sys.boot_completed via cmd webviewupdate.

### Added
- Bootloop sentinel in post-fs-data.sh.
- Inert mode flag set automatically on activation failure.
- Logs at /data/adb/modules/dresoswv/logs/.
- ABI gate, APEX guard, Samsung One UI detection.
