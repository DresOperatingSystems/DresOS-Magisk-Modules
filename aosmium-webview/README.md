# DresOS AOSmium WebView

Systemless replacement of Android System WebView with AOSmium WebView
(Chromium 147.0.7727.49) from the AXP.OS project.

Project site: https://dresoperatingsystems.github.io
Forum thread: https://xdaforums.com/t/dresos-the-android-defensive-security-system.4787891

## What this module does

Replaces the active WebView provider on the device with AOSmium without ever
installing the APK to /data/app. Activation is achieved by three layered
mechanisms, followed by an optional fourth step:

1. A static RRO is placed in the systemless overlay partition. This adds
   org.axpos.aosmium_wv plus the AXP.OS ECDSA signing certificate to the
   framework resource config_webview_packages, which is the canonical
   allow list that WebViewUpdateService reads at boot to decide which
   packages are eligible to provide WebView.

2. The signed AOSmium APK is dropped into the systemless system tree at
   product/app/AOSmiumWebView/AOSmiumWebView.apk. Magisk magic mount
   makes this visible to PackageManager as a preinstalled system app,
   which satisfies the MATCH_FACTORY_ONLY scan that WebViewUpdateService
   performs.

3. After boot complete, service.sh calls cmd webviewupdate
   set-webview-implementation org.axpos.aosmium_wv to promote AOSmium
   to the active provider, with a settings put global webview_provider
   fallback write for redundancy.

4. Only after step 3 is confirmed by re reading dumpsys, service.sh
   disables the stock Google or AOSP WebView with pm disable-user so
   AOSmium is the only WebView engine on the device. This step is on by
   default and is fully reversible. The Trichrome library and Google
   Chrome are never touched, so Chrome keeps working. To keep the stock
   WebView enabled, create the file
   /data/adb/dresoswv_keep_stock_webview before flashing.

## Supported devices

| Property | Supported |
|----------|-----------|
| Android version | 10 through 16 and newer (API 29 and up) |
| ABI | arm64-v8a, armeabi-v7a |
| Manufacturers | AOSP, Pixel, Samsung, Motorola, OnePlus, Xiaomi, Lineage |
| Root method | Magisk 29.0 or newer |

Android 16 (API 36) is the highest tested version. Newer Android versions
are not blocked. The install warns and proceeds rather than aborting,
because WebViewUpdateService, config_webview_packages, RRO handling, and
cmd webviewupdate are unchanged through API 36 and are not expected to
break in later versions.

x86 and x86_64 are not supported because AXP.OS does not publish WebView
builds for those ABIs. The install script aborts cleanly on those devices.

APEX based WebView providers are not supported and the install script
aborts if any APEX WebView module is detected. As of May 2026 no shipping
device ships WebView as an APEX, so this guard is forward looking only.

## What this module does NOT do

* No pm install of any APK at flash time. The previous v1.0.0 used pm install
  and bootlooped Pixel 9 because the data partition was not yet mounted at
  flash time on some Lineage builds.
* No Magisk replace markers on com.android.webview or com.google.android.webview.
  The stock provider is disabled with pm disable-user only after AOSmium is
  confirmed active, and is fully restored on module removal, including
  removal via recovery, by a self deleting trampoline script.
* No changes to the Trichrome library or Google Chrome. Chrome continues to
  work normally after the stock WebView is disabled.
* No platform key signing required. The RRO is signed with a self generated
  debug key and Android accepts it because static RROs do not require the
  platform signature on Android 11 and later.
* No /apex modification. WebView APEX modules are off limits because AVB
  and fs verity reject changes there.

## Bootloop safety

Two layers of protection ensure that any failure on first boot does not
leave the device unbootable.

### Layer one: post-fs-data sentinel

post-fs-data.sh runs blocking before zygote on every boot.

* On entry it checks for a boot_pending marker. If the marker exists, the
  previous boot did not reach boot complete (i.e. system_server crashed),
  so the script touches /data/adb/modules/dresoswv/disable. Magisk
  recognises this file and skips the entire module on the next boot,
  letting the device recover cleanly.
* If no marker exists, it drops a fresh boot_pending marker which only
  service.sh is responsible for clearing once boot complete is reached.
* If an inert marker exists (set by a previous service.sh failure), the
  script exits silently and no activation is attempted on this boot.

### Layer two: inert mode in service.sh

service.sh activates AOSmium only after sys.boot_completed and verifies
the change took effect by re reading dumpsys webviewupdate.

* If PackageManager does not see org.axpos.aosmium_wv (RRO did not
  register, or APK bind mount did not land), the module flips itself into
  inert mode and does nothing else.
* If activation runs but the active provider in dumpsys is not AOSmium,
  the module flips itself into inert mode and stays out of the way until
  the user investigates.
* Inert mode persists across reboots. The user re enables by deleting
  /data/adb/modules/dresoswv/inert, or by reflashing the module.

### Manual recovery

If the device does bootloop despite the sentinel, boot into Magisk safe
mode (volume down during boot on most devices) and the module will be
disabled automatically. Alternatively, from adb shell while booted:

    touch /data/adb/modules/dresoswv/disable

Then reboot.

## Logs

Persistent logs live under the module directory and survive reboots:

* /data/adb/modules/dresoswv/logs/install.log
* /data/adb/modules/dresoswv/logs/boot.log     (truncated on every boot)
* /data/adb/modules/dresoswv/logs/service.log  (appended each boot)
* /data/adb/modules/dresoswv/webview_activation.log (appended each boot,
  preserved at the path the existing module used for user familiarity)

Pull them with:

    adb pull /data/adb/modules/dresoswv/logs/

## Verifying activation

After reboot, from adb shell:

    dumpsys webviewupdate | grep "Current WebView package"

The expected output is:

    Current WebView package (name, version): (org.axpos.aosmium_wv, 147.0.7727.49)

If the output shows the OEM provider instead, check
/data/adb/modules/dresoswv/logs/service.log for the failure mode and
whether the module flipped itself into inert mode.

## OEM specific notes

| OEM | Note |
|-----|------|
| Samsung One UI 4 plus | The Developer Options WebView picker may hide non Samsung providers, but cmd webviewupdate still works. Verify via dumpsys, not the UI. |
| Samsung Knox enrolled | Not supported. Knox attestation flags any WebView replacement. |
| Xiaomi HyperOS | Some builds do not register /product/app/ APKs until the second boot. Reboot twice if activation does not stick on first boot. |
| OnePlus OxygenOS | /system_ext/ may be mounted nosuid; the module places the overlay in /product/overlay/ which is unaffected. |
| Pixel A14 and A15 | WebViewGoogle.apk lives at /product/app/WebViewGoogle/ as a regular APK, not as an APEX. The module's product partition placement targets this layout. |
| GrapheneOS, DivestOS | Already replace WebView with Vanadium or Mulch. AOSmium coexists as an additional provider, selectable via cmd webviewupdate. |
| LineageOS | No com.google.android.webview; only com.android.webview. The RRO keeps both as fallbacks so removal of AOSmium does not brick. |

## Credits

* AXP.OS for the AOSmium WebView build (codeberg.org/AXP-OS/app_aosmium)
* topjohnwu for Magisk (github.com/topjohnwu/Magisk)
* DresOperatingSystems for the module wrapper, RRO, and bootloop safety design
