# DresOS AOSmium WebView - Changelog

## v1.0.0 - May 2026

First stable release.

### What it does
- Installs **AOSmium WebView v147.0.7727.49** (Chromium 147, hardened with GrapheneOS/Vanadium security patches) as the system WebView
- Systemlessly hides all competing WebView packages (AOSP WebView, Google WebView, Chrome, TrichromeLibrary, Mozilla WebView, Samsung Chrome customisations) via Magisk `.replace` files - no system files modified, fully reversible
- Places a compiled RRO overlay APK that patches Android's `config_webview_packages` allowlist to include `org.axpos.aosmium_wv` - required for the WebView to appear in Developer Options
- Runs `pm install` at flash time to register AOSmium with the package manager
- Supports **Magisk** and **KernelSU**
- Detects LineageOS automatically and uses the correct `system/product/app` install path
- No internet connection required - APK is bundled in the ZIP
- Writes install log to `/data/adb/modules/dresoswv/install.log`
- Writes boot activation log to `/data/adb/modules/dresoswv/activation.log`

### After flashing
1. Reboot
2. Settings → Developer Options → WebView implementation
3. Select **AOSmium WebView**

---

## Development history

Multiple iterations were required to solve the following problems:

- **system/app vs system/priv-app vs apk/ only** - APK must be in `system/app` (or `system/product/app` on LineageOS) AND also registered via `pm install`
- **Overlay path** - must use `system/` prefix in module directory even for `/product/overlay`; path must be probed at flash time since it varies by ROM
- **config_webview_packages allowlist** - without the RRO overlay patching this, WebViewUpdateService rejects any non-stock WebView regardless of installation
- **Dual-presence bug** - having the APK in both `system/priv-app` and `/data/app` simultaneously causes pm registration failure
- **codePath extraction** - `pm dump` returns multiple lines; extraction must isolate the single system-partition path cleanly
