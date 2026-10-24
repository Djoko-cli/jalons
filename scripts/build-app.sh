#!/bin/bash
# Compile Jalons en release et assemble build/Jalons.app (signature ad hoc), sur le modèle d'Orchestre.
# Usage : scripts/build-app.sh
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="0.2.0"
BUNDLE_ID="io.github.djoko-cli.jalons"
APP="build/Jalons.app"
ICON="Ressources/AppIcon.icon"

# Pas d'app sans icône : on s'arrête avant de compiler si elle manque.
if [ ! -f "$ICON/icon.json" ] || ! ls "$ICON"/Assets/*.png >/dev/null 2>&1; then
    echo "ERREUR : icône absente ($ICON). Régénérer le calque : swift scripts/dessiner-icone.swift $ICON/Assets/jalon.png" >&2
    exit 1
fi

swift build -c release --product Jalons
BIN_DIR="$(swift build -c release --product Jalons --show-bin-path)"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/Jalons" "$APP/Contents/MacOS/Jalons"

# L'icône Icon Composer, compilée en AppIcon.icns et Assets.car.
xcrun actool "$ICON" --compile "$APP/Contents/Resources" --platform macosx --minimum-deployment-target 15.0 \
    --app-icon AppIcon --output-partial-info-plist "build/icone-partielle.plist" --output-format human-readable-text \
    > build/actool.log
if [ ! -s "$APP/Contents/Resources/AppIcon.icns" ] || [ ! -s "$APP/Contents/Resources/Assets.car" ]; then
    echo "ERREUR : actool n'a pas produit l'icône (voir build/actool.log)" >&2
    exit 1
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>fr</string>
    <key>CFBundleExecutable</key><string>Jalons</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIconName</key><string>AppIcon</string>
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
