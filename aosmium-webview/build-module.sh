#!/bin/sh
##############################################################################
#  DresOS AOSmium WebView: module build script
#
#  Assembles the flashable Magisk module zip from the repo source.
#
#  Inputs (must be present before running):
#    overlay/DresOSAOSmiumOverlay.apk      Built by overlay/build.sh
#    apks/webview64-signed.apk             Downloaded from AXP.OS releases
#    apks/webview32-signed.apk             Downloaded from AXP.OS releases
#
#  Output:
#    DresOS-AOSmium-WebView-<version>.zip in the current directory
#
#  Run from the aosmium-webview/ directory.
##############################################################################

set -eu

##############################################################################
#  Read version from module.prop so the zip name and the prop stay in sync.
##############################################################################

if [ ! -f "module.prop" ]; then
    echo "ERROR: run this script from the aosmium-webview/ directory." >&2
    exit 1
fi

VERSION=$(grep "^version=" module.prop | cut -d= -f2)
[ -z "$VERSION" ] && { echo "ERROR: could not read version from module.prop"; exit 1; }
OUT_ZIP="DresOS-AOSmium-WebView-$(echo "$VERSION" | tr '.' '_').zip"

##############################################################################
#  Verify required artifacts
##############################################################################

RRO="overlay/DresOSAOSmiumOverlay.apk"
WV64="apks/webview64-signed.apk"
WV32="apks/webview32-signed.apk"

for f in "$RRO" "$WV64" "$WV32"; do
    if [ ! -f "$f" ]; then
        echo "ERROR: missing required artifact: $f" >&2
        if [ "$f" = "$RRO" ]; then
            echo "  Build it with: (cd overlay && ./build.sh)" >&2
        else
            echo "  Download AOSmium WebView APKs from:" >&2
            echo "    https://codeberg.org/AXP-OS/app_aosmium/releases" >&2
            echo "  Place them in apks/ as webview64-signed.apk and webview32-signed.apk" >&2
        fi
        exit 1
    fi
done

##############################################################################
#  Verify the AOSmium APKs have the expected package name and ABI markers
##############################################################################

if command -v aapt >/dev/null 2>&1; then
    for f in "$WV64" "$WV32"; do
        pkg=$(aapt dump badging "$f" 2>/dev/null | grep "^package:" | head -1 | sed "s/^package: name='\([^']*\)'.*/\1/")
        if [ "$pkg" != "org.axpos.aosmium_wv" ]; then
            echo "ERROR: $f has package name '$pkg', expected 'org.axpos.aosmium_wv'." >&2
            echo "Are you sure these are the AOSmium WebView APKs and not the browser?" >&2
            exit 1
        fi
    done
fi

##############################################################################
#  Stage the module tree
##############################################################################

STAGE=$(mktemp -d)
trap "rm -rf $STAGE" EXIT

echo "  Staging module tree."
cp module.prop      "$STAGE/"
cp customize.sh     "$STAGE/"
cp post-fs-data.sh  "$STAGE/"
cp service.sh       "$STAGE/"
cp uninstall.sh     "$STAGE/"
cp README.md        "$STAGE/"

mkdir -p "$STAGE/overlay" "$STAGE/webview"
cp "$RRO"  "$STAGE/overlay/DresOSAOSmiumOverlay.apk"
cp "$WV64" "$STAGE/webview/webview64-signed.apk"
cp "$WV32" "$STAGE/webview/webview32-signed.apk"

##############################################################################
#  Build the zip
##############################################################################

rm -f "$OUT_ZIP"
echo "  Building $OUT_ZIP"
( cd "$STAGE" && zip -qr9 "$OLDPWD/$OUT_ZIP" . )

echo ""
echo "  Module built: $(pwd)/$OUT_ZIP"
ls -lh "$OUT_ZIP"
echo ""
echo "  SHA256:"
sha256sum "$OUT_ZIP"
