#!/bin/bash
# Compile Jalons en release et assemble build/Jalons.app (signature ad hoc), sur le modèle d'Orchestre.
# Usage : scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.1.0"
BUNDLE_ID="io.github.djoko-cli.jalons"
APP="build/Jalons.app"

swift build -c release --product Jalons
BIN_DIR="$(swift build -c release --product Jalons --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Jalons" "$APP/Contents/MacOS/Jalons"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>fr</string>
    <key>CFBundleExecutable</key><string>Jalons</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>CFBundleName</key><string>Jalons</string>
    <key>CFBundleDisplayName</key><string>Jalons</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.productivity</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
</dict>
</plist>
PLIST

plutil -lint "$APP/Contents/Info.plist"
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"
echo "OK : $APP ($VERSION)"
