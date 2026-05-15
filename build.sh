#!/usr/bin/env bash
# Build Hyprmon.app from the SwiftPM executable.
# Usage:
#   ./build.sh              # native (arm64 or x86_64 depending on host)
#   ./build.sh --universal  # universal binary (arm64 + x86_64)
set -euo pipefail

cd "$(dirname "$0")"
OUT_DIR="build"
APP="$OUT_DIR/Hyprmon.app"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

rm -rf "$APP"
mkdir -p "$BIN_DIR" "$RES_DIR"

UNIVERSAL=false
if [[ "${1:-}" == "--universal" ]]; then UNIVERSAL=true; fi

if $UNIVERSAL; then
    echo "Building universal binary..."
    swift build -c release --triple arm64-apple-macos14.0
    ARM_BIN="$(swift build -c release --triple arm64-apple-macos14.0 --show-bin-path)/hyprmon"
    cp "$ARM_BIN" "$BIN_DIR/hyprmon-arm64"
    swift build -c release --triple x86_64-apple-macos14.0
    X86_BIN="$(swift build -c release --triple x86_64-apple-macos14.0 --show-bin-path)/hyprmon"
    cp "$X86_BIN" "$BIN_DIR/hyprmon-x86_64"
    lipo -create "$BIN_DIR/hyprmon-arm64" "$BIN_DIR/hyprmon-x86_64" -output "$BIN_DIR/hyprmon"
    rm "$BIN_DIR/hyprmon-arm64" "$BIN_DIR/hyprmon-x86_64"
else
    echo "Building native..."
    swift build -c release
    NATIVE_BIN="$(swift build -c release --show-bin-path)/hyprmon"
    cp "$NATIVE_BIN" "$BIN_DIR/hyprmon"
fi

cp Resources/Info.plist "$APP/Contents/Info.plist"

# Ensure the app icon exists (generate it if missing) and copy into the bundle.
if [ ! -f Resources/AppIcon.icns ]; then
    echo "Generating AppIcon.icns..."
    ./scripts/build-icns.sh
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
chmod +x "$BIN_DIR/hyprmon"

codesign --force --sign - --deep "$APP" >/dev/null
echo "Built $APP"
file "$BIN_DIR/hyprmon"
