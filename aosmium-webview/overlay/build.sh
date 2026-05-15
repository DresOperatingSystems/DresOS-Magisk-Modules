#!/bin/sh
set -eu

OUT_APK="DresOSAOSmiumOverlay.apk"
KEYSTORE="release.keystore"
KEY_ALIAS="dresos"
KEY_PASS="dresos1"
FRAMEWORK_RES="/usr/share/android-framework-res/framework-res.apk"

if [ ! -f "$KEYSTORE" ]; then
    keytool -genkeypair -keystore "$KEYSTORE" -alias "$KEY_ALIAS" \
        -keyalg RSA -keysize 2048 \
        -storepass "$KEY_PASS" -keypass "$KEY_PASS" -validity 36500 \
        -dname "CN=DresOS, OU=Magisk Module, O=DresOperatingSystems, L=N/A, ST=N/A, C=N/A"
fi

rm -rf build
mkdir -p build/compiled

aapt2 compile --dir res/ -o build/compiled/

aapt2 link \
    -I "$FRAMEWORK_RES" \
    --manifest AndroidManifest.xml \
    -o build/unsigned.apk \
    --no-resource-deduping \
    --no-resource-removal \
    --min-sdk-version 29 \
    --target-sdk-version 35 \
    build/compiled/*.flat

zipalign -p 4 build/unsigned.apk build/aligned.apk

rm -f "$OUT_APK"
apksigner sign \
    --ks "$KEYSTORE" --ks-pass "pass:$KEY_PASS" --key-pass "pass:$KEY_PASS" \
    --ks-key-alias "$KEY_ALIAS" \
    --min-sdk-version 21 \
    --v1-signing-enabled true \
    --v2-signing-enabled true \
    --v3-signing-enabled true \
    --out "$OUT_APK" \
    build/aligned.apk

rm -rf build
ls -la "$OUT_APK"
