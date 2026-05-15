#!/usr/bin/env bash
# Builds Resources/AppIcon.icns from a 1024×1024 master rendered by
# scripts/generate-app-icon.swift.
set -euo pipefail

cd "$(dirname "$0")/.."
MASTER="/tmp/hyprmon-icon-1024.png"
ICONSET="/tmp/AppIcon.iconset"
OUT="Resources/AppIcon.icns"

mkdir -p Resources

# 1. Render the master PNG.
./scripts/generate-app-icon.swift "$MASTER"

# 2. Generate every size Apple expects.
rm -rf "$ICONSET"
mkdir -p "$ICONSET"

declare -a SIZES=(16 32 64 128 256 512 1024)
for s in "${SIZES[@]}"; do
    sips -z "$s" "$s" "$MASTER" --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
done

# Apple also wants @2x renditions named differently.
cp "$ICONSET/icon_32x32.png"     "$ICONSET/icon_16x16@2x.png"
cp "$ICONSET/icon_64x64.png"     "$ICONSET/icon_32x32@2x.png"
cp "$ICONSET/icon_256x256.png"   "$ICONSET/icon_128x128@2x.png"
cp "$ICONSET/icon_512x512.png"   "$ICONSET/icon_256x256@2x.png"
cp "$ICONSET/icon_1024x1024.png" "$ICONSET/icon_512x512@2x.png"

# Remove the bare 64 and 1024 — they aren't standard names.
rm -f "$ICONSET/icon_64x64.png" "$ICONSET/icon_1024x1024.png"

# 3. Build the .icns.
iconutil --convert icns "$ICONSET" --output "$OUT"
echo "Built $OUT"
