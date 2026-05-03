# DresOS Magisk Modules

**Part of the [DresOS Android Defensive Security System](https://github.com/DresOperatingSystems/DresOS-The-Android-Defensive-Security-System)**

Magisk modules that automate steps from the DresOS build guide. Each module replaces a block of manual steps with a single flash. The goal is a full automated DresOS build - flash the modules, reboot, done.

> **Status:** Active development. More modules coming. See [Roadmap](#roadmap).

---

## Modules

### AOSmium WebView - `dresoswv`

Replaces Android's system WebView with **AOSmium** - a Chromium fork hardened with GrapheneOS/Vanadium security patches, built by the [AXP.OS Project](https://axpos.org/).

The system WebView is the browser engine used internally by hundreds of apps whenever they render web content. Replacing it with AOSmium means every app on the device stops feeding Google's data pipeline through embedded web renders.

**[→ Download v1.0.0](https://github.com/DresOperatingSystems/DresOS-Magisk-Modules/releases/latest)**

| | |
|---|---|
| AOSmium version | 147.0.7727.49 (Chromium 147) |
| Package | `org.axpos.aosmium_wv` |
| Built by | [AXP.OS Project](https://axpos.org/) |
| Security patches | GrapheneOS / Vanadium |
| Root support | Magisk 20400+ and KernelSU |
| Android requirement | 10+ (API 29+) |
| Architecture | ARM and ARM64 |
| Internet required | No - APK bundled in ZIP |

#### What it does

| Step | Action |
|------|--------|
| 1 | Validates device - Android 10+, ARM/ARM64 |
| 2 | Removes data-partition updates of Chrome, AOSP WebView, Google WebView, TrichromeLibrary, Mozilla WebView, Samsung Chrome customisations |
| 3 | Systemlessly hides all competing system WebView packages via Magisk `.replace` files - no system files modified, fully reversible |
| 4 | Remaps `/product`, `/vendor`, `/system_ext` paths so Magisk mounts them correctly |
| 5 | Installs AOSmium to `system/product/app` (LineageOS) or `system/app` (everything else) |
| 6 | Runs `pm install` to register AOSmium with the package manager |
| 7 | Places a compiled RRO overlay APK that patches `config_webview_packages` - required for AOSmium to appear in the WebView selector |
| 8 | At boot: verifies registration and activates via `cmd webviewupdate` |

#### Flash instructions

1. Download `DresOS-AOSmium-WebView-v1.0.0.zip` from [Releases](https://github.com/DresOperatingSystems/DresOS-Magisk-Modules/releases/latest)
2. Open **Magisk → Modules → Install from storage**
3. Select the ZIP
4. Reboot
5. **Settings → Developer Options → WebView implementation → Select AOSmium WebView**

#### Diagnostic logs

```
/data/adb/modules/dresoswv/install.log     ← flash-time install log
/data/adb/modules/dresoswv/activation.log  ← first-boot activation log
```

#### Uninstalling

Disable or remove in **Magisk → Modules** and reboot. All hidden packages reappear automatically. AOSmium is uninstalled via `pm uninstall`.

#### Credits

Module scripts written by DresOS (GPL-3.0). Developed with reference to:
- [Lubald/AOSmium-WebView](https://github.com/Lubald/AOSmium-WebView) (GPL-2.0)
- [Lordify/WebView-Changer](https://gitlab.com/Lordify/webview-changer) (GPL-3.0)
- [Open WebView by F3FFO](https://github.com/Magisk-Modules-Alt-Repo/open_webview) (GPL-3.0)

---

## Roadmap

| Module | Automates | Status |
|--------|-----------|--------|
| `dresoswv` - AOSmium WebView | System WebView replacement | ✅ v1.0.0 |
| `dresosmicrog` - Noogle microG | Google Play Services replacement | 🔨 Planned |
| `dresosdebloat` - System Debloater | Core Google app removal | 🔨 Planned |
| `dresosperms` - Permissions Hardener | Revoke dangerous permissions from system apps | 🔨 Planned |
| `dresosafwall` - AFWall+ Bootstrap | Pre-configured iptables firewall rules | 🔨 Planned |
| `dresosoverlay` - Privacy Overlay | Disable telemetry, advertising IDs, sensors at system level | 🔨 Planned |
| `dresosfossify` - Fossify Installer | Install Fossify suite as system apps | 🔨 Planned |
| `dresosheliboard` - HeliBoard | Install HeliBoard as default system keyboard | 🔨 Planned |

---

## Repository Structure

```
DresOS-Magisk-Modules/
├── README.md
├── LICENSE                                        ← GPL-3.0
└── aosmium-webview/
    ├── module.prop
    ├── customize.sh
    ├── post-fs-data.sh
    ├── service.sh
    ├── uninstall.sh
    ├── update.json                                ← Magisk auto-update check
    ├── CHANGELOG.md
    ├── common/
    │   └── install.sh
    └── META-INF/
        └── com/google/android/
            ├── update-binary
            └── updater-script
```

Flashable ZIPs (with bundled APKs) are in [Releases](https://github.com/DresOperatingSystems/DresOS-Magisk-Modules/releases).
Source scripts are in this repository.

---

## License

Module scripts: **GPL-3.0** - see [LICENSE](LICENSE)

AOSmium WebView APK: built by [AXP.OS Project](https://axpos.org/) under its own license.
WebViewOverlay29.apk: derived from [Open WebView](https://github.com/Magisk-Modules-Alt-Repo/open_webview) (GPL-3.0).

---

## Links

- **Main guide:** [DresOS Android Defensive Security System](https://github.com/DresOperatingSystems/DresOS-The-Android-Defensive-Security-System)
- **Website:** https://dresoperatingsystems.github.io/
- **Issues:** Open an issue to report bugs or request new modules
