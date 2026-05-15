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
    cp .build/arm64-apple-macos14.0/release/hyprmon "$BIN_DIR/hyprmon-arm64"
    swift build -c release --triple x86_64-apple-macos14.0
    cp .build/x86_64-apple-macos14.0/release/hyprmon "$BIN_DIR/hyprmon-x86_64"
    lipo -create "$BIN_DIR/hyprmon-arm64" "$BIN_DIR/hyprmon-x86_64" -output "$BIN_DIR/hyprmon"
    rm "$BIN_DIR/hyprmon-arm64" "$BIN_DIR/hyprmon-x86_64"
else
    echo "Building native..."
    swift build -c release
    cp ".build/release/hyprmon" "$BIN_DIR/hyprmon"
fi

cp Resources/Info.plist "$APP/Contents/Info.plist"
chmod +x "$BIN_DIR/hyprmon"

codesign --force --sign - --deep "$APP" >/dev/null
echo "Built $APP"
file "$BIN_DIR/hyprmon"
