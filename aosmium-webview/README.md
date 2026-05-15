# DresOS AOSmium WebView

Systemless replacement of Android System WebView with AOSmium WebView (Chromium 147.0.7727.49) from the AXP.OS project.

## How it works

1. Static RRO in /product/overlay/ adds org.axpos.aosmium_wv plus the AXP.OS signing certificate to config_webview_packages.
2. Signed AOSmium APK placed in /product/app/AOSmiumWebView/ via Magisk magic mount.
3. service.sh runs cmd webviewupdate set-webview-implementation org.axpos.aosmium_wv after boot complete.

## Supported devices

| Property | Supported |
|----------|-----------|
| Android | 10 through 15 (API 29 through 35) |
| ABI | arm64-v8a, armeabi-v7a |
| Root | Magisk 24.0+ |

## Bootloop safety

post-fs-data.sh drops a boot_pending marker. service.sh clears it on success. If the marker persists into the next boot, the module auto-disables itself.

service.sh verifies activation via dumpsys. On failure it sets an inert flag to prevent retries.

## Logs

- /data/adb/modules/dresoswv/logs/install.log
- /data/adb/modules/dresoswv/logs/boot.log
- /data/adb/modules/dresoswv/logs/service.log
- /data/adb/modules/dresoswv/webview_activation.log

## Credits

- AXP.OS for AOSmium (codeberg.org/AXP-OS/app_aosmium)
- topjohnwu for Magisk
