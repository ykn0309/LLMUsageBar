#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/release/LLMUsageBar.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/.build/AppIcon.iconset"
ICON_FILE="AppIcon.icns"

cd "$ROOT_DIR"
swift build -c release
python3 "$ROOT_DIR/scripts/draw_app_icon.py"
python3 "$ROOT_DIR/scripts/make_icon.py"
iconutil -c icns "$ICONSET_DIR" -o "$ROOT_DIR/.build/$ICON_FILE"

rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"
cp "$ROOT_DIR/.build/release/LLMUsageBar" "$MACOS_DIR/LLMUsageBar"
cp "$ROOT_DIR/.build/$ICON_FILE" "$RESOURCES_DIR/$ICON_FILE"

RESOURCE_BUNDLE="$(find "$ROOT_DIR/.build" -path '*/release/LLMUsageBar_LLMUsageBar.bundle' -type d | head -n 1)"
if [[ -n "$RESOURCE_BUNDLE" ]]; then
  cp -R "$RESOURCE_BUNDLE" "$RESOURCES_DIR/"
  rm -f "$RESOURCES_DIR/LLMUsageBar_LLMUsageBar.bundle/aliyun-bailian.png"
  rm -f "$RESOURCES_DIR/LLMUsageBar_LLMUsageBar.bundle/aliyun-cloud.png"
fi

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>LLMUsageBar</string>
  <key>CFBundleIdentifier</key>
  <string>io.github.ykn0309.LLMUsageBar</string>
  <key>CFBundleName</key>
  <string>LLMUsageBar</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.2.2</string>
  <key>CFBundleVersion</key>
  <string>4</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

echo "$APP_DIR"
