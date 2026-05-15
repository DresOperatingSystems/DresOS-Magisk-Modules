#!/bin/sh
set -eu

VERSION=$(grep "^version=" module.prop | cut -d= -f2)
OUT_ZIP="DresOS-AOSmium-WebView-$(echo "$VERSION" | tr '.' '_').zip"

STAGE=$(mktemp -d)
trap "rm -rf $STAGE" EXIT

cp module.prop customize.sh post-fs-data.sh service.sh uninstall.sh README.md "$STAGE/"
mkdir -p "$STAGE/overlay" "$STAGE/webview"
cp overlay/DresOSAOSmiumOverlay.apk "$STAGE/overlay/"
cp apks/webview64-signed.apk "$STAGE/webview/"
cp apks/webview32-signed.apk "$STAGE/webview/"

rm -f "$OUT_ZIP"
( cd "$STAGE" && zip -qr9 "$OLDPWD/$OUT_ZIP" . )

ls -lh "$OUT_ZIP"
sha256sum "$OUT_ZIP"
