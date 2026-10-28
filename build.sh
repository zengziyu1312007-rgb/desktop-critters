#!/bin/bash
set -euo pipefail
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="$PROJECT_DIR/dist"
APP_DIR="$OUTPUT_DIR/桌面有点脏.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$PROJECT_DIR/.build-cache"
test -s "$PROJECT_DIR/Resources/Textures/roach-body-photo.png"
test -s "$PROJECT_DIR/Resources/Textures/ant-body-photo-v1.png"
xcrun swiftc -O -swift-version 5 -target arm64-apple-macosx13.0 -module-cache-path "$PROJECT_DIR/.build-cache" \
  "$PROJECT_DIR"/Sources/*.swift \
  -framework AppKit -framework QuartzCore -o "$APP_DIR/Contents/MacOS/DesktopCritters"
cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>cn.peterai.desktopcritters</string>
<key>CFBundleName</key><string>桌面有点脏</string>
<key>CFBundleDisplayName</key><string>桌面有点脏</string>
<key>CFBundleExecutable</key><string>DesktopCritters</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.9.0</string>
<key>CFBundleVersion</key><string>16</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>LSUIElement</key><false/>
<key>NSHighResolutionCapable</key><true/>
<key>NSSupportsAutomaticGraphicsSwitching</key><true/>
<key>NSPrincipalClass</key><string>NSApplication</string>
</dict></plist>
PLIST
mkdir -p "$APP_DIR/Contents/Resources/Textures"
cp "$PROJECT_DIR/Resources/Textures/roach-body-photo.png" "$APP_DIR/Contents/Resources/Textures/roach-body-photo.png"
cp "$PROJECT_DIR/Resources/Textures/ant-body-photo-v1.png" "$APP_DIR/Contents/Resources/Textures/ant-body-photo-v1.png"
cp "$PROJECT_DIR/Resources/素材署名.txt" "$APP_DIR/Contents/Resources/素材署名.txt"
if [ -f "$PROJECT_DIR/Resources/AppIcon.icns" ]; then
  cp "$PROJECT_DIR/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
fi
codesign --force --sign - "$APP_DIR"
printf '%s\n' "$APP_DIR"
