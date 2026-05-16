#!/bin/sh
##############################################################################
#  DresOS AOSmium WebView: RRO build script
#
#  Builds DresOSAOSmiumOverlay.apk from the source files in this directory.
#  Run from the overlay/ directory. The output APK is dropped in the current
#  directory and is ready to be picked up by ../build-module.sh.
#
#  Requirements (Debian or Ubuntu):
#    apt install aapt apksigner zipalign android-framework-res \
#                openjdk-21-jre-headless
##############################################################################

set -eu

##############################################################################
#  Tunables
##############################################################################

OUT_APK="DresOSAOSmiumOverlay.apk"
KEYSTORE="release.keystore"
KEY_ALIAS="dresos"
KEY_PASS="dresos1"
FRAMEWORK_RES="/usr/share/android-framework-res/framework-res.apk"

##############################################################################
#  Sanity checks
##############################################################################

for cmd in aapt2 zipalign apksigner keytool; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: $cmd not found in PATH." >&2
        echo "Install with: apt install aapt apksigner zipalign default-jre-headless" >&2
        exit 1
    fi
done

if [ ! -f "$FRAMEWORK_RES" ]; then
    echo "ERROR: framework-res.apk not found at $FRAMEWORK_RES" >&2
    echo "Install with: apt install android-framework-res" >&2
    exit 1
fi

if [ ! -f "AndroidManifest.xml" ] || [ ! -d "res" ]; then
    echo "ERROR: run this script from the overlay/ directory." >&2
    exit 1
fi

##############################################################################
#  Generate a signing key on first run. The RRO holds no sensitive data, so
#  this is an integrity key, not an identity key. Treat the keystore as a
#  build artifact, not a secret.
##############################################################################

if [ ! -f "$KEYSTORE" ]; then
    echo "  Generating signing key (one time)."
    keytool -genkeypair -keystore "$KEYSTORE" -alias "$KEY_ALIAS" \
        -keyalg RSA -keysize 2048 \
        -storepass "$KEY_PASS" -keypass "$KEY_PASS" -validity 36500 \
        -dname "CN=DresOS, OU=Magisk Module, O=DresOperatingSystems, L=N/A, ST=N/A, C=N/A" \
        2>&1 | tail -2
fi

##############################################################################
#  Compile resources
##############################################################################

rm -rf build
mkdir -p build/compiled

echo "  Compiling resources."
aapt2 compile --dir res/ -o build/compiled/

##############################################################################
#  Link into an unsigned APK
##############################################################################

echo "  Linking APK."
aapt2 link \
    -I "$FRAMEWORK_RES" \
    --manifest AndroidManifest.xml \
    -o build/unsigned.apk \
    --no-resource-deduping \
    --no-resource-removal \
    --min-sdk-version 29 \
    --target-sdk-version 35 \
    build/compiled/*.flat

##############################################################################
#  Align and sign
##############################################################################

echo "  Aligning."
zipalign -p 4 build/unsigned.apk build/aligned.apk

echo "  Signing (v1+v2+v3)."
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

##############################################################################
#  Verify and report
##############################################################################

echo "  Verifying."
apksigner verify --min-sdk-version 21 --verbose "$OUT_APK" | head -5

rm -rf build

echo ""
echo "  RRO built: $(pwd)/$OUT_APK"
ls -la "$OUT_APK"
