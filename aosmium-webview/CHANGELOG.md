# DresOS AOSmium WebView - Changelog

## v1.1.0 (versionCode 11) - May 2026

### Bootloop fix for LineageOS 23.2 and Android 15+ Pixel devices

**Bug:** The module caused a bootloop on Google Pixel 9 Pro XL running
LineageOS 23.2 (and likely other Pixel 9 series devices on LineageOS and
similar Android 15+ ROMs).

**Root cause:** The module used Magisk .replace files to hide
com.android.webview (the stock AOSP WebView) at post-fs-data time.
post-fs-data runs very early in the boot sequence before /data is fully
mounted. AOSmium was installed to /data/app via pm install, so it was not
visible to Android at that early stage. With the stock WebView hidden and
AOSmium not yet accessible, Android had no valid WebView provider at all
and crashed into a bootloop.

**Fix:** com.android.webview is no longer hidden by this module. AOSmium
is installed alongside the stock WebView rather than replacing it at the
filesystem level. After reboot, go to Developer Options > WebView
implementation and select AOSmium WebView manually. Both options will
appear in the list - this is expected and correct behaviour.

What is still hidden (Google and OEM WebViews only, safe to hide):
- com.google.android.webview
- com.android.chrome
- com.google.android.trichromelibrary
- org.mozilla.webview_shell
- com.sec.android.app.chromecustomizations

What is no longer hidden:
- com.android.webview (stock AOSP WebView - kept as safe fallback)

### Other changes in v1.1.0

- Extended ROM detection in install.sh: now also detects crDroid,
  EvolutionX, CalyxOS, DivestOS and other LineageOS-based ROMs that
  use the same system/product/app path
- install.log now includes device model and board name for easier
  debugging of future bug reports
- service.sh: improved APK fallback path search order for retry
- Overlay detection now also probes /vendor/overlay as a fallback

---

## v1.0.0 (versionCode 10) - May 2026

First stable release.

- Installs AOSmium WebView v147.0.7727.49 as system WebView
- Hides competing WebView packages via Magisk .replace files
- Places RRO overlay patching config_webview_packages allowlist
- Runs pm install at flash time to register with package manager
- Supports Magisk and KernelSU
- Detects LineageOS and uses correct system/product/app path
- No internet required - APK bundled in ZIP
- Install log: /data/adb/modules/dresoswv/install.log
- Activation log: /data/adb/modules/dresoswv/activation.log
