#!/bin/bash
# Compile Jalons en release et assemble build/Jalons.app (signature ad hoc), sur le modèle d'Orchestre.
# Usage : scripts/build-app.sh [--sortie <dossier>] [--identifiant <id>]
#   --sortie       dossier où poser l'app (build/ par défaut) ;
#   --identifiant  identifiant du paquet (io.github.djoko-cli.jalons par défaut) ; pour <défaut>.<suffixe>, l'app
#                  s'appelle Jalons-<suffixe>.app (la répétition de scripts/publier.sh).
# Le chemin absolu de l'app est imprimé sur la dernière ligne (scripts/publication.py le lit).
set -euo pipefail

VERSION="0.3.1"
BUNDLE_ID="io.github.djoko-cli.jalons"
SORTIE="build"

usage() { echo "Usage : scripts/build-app.sh [--sortie <dossier>] [--identifiant <id>]" >&2; exit 2; }
while [ $# -gt 0 ]; do
    case "$1" in
        --sortie|--identifiant)
            [ $# -ge 2 ] && [ -n "$2" ] || usage
            if [ "$1" = --sortie ]; then SORTIE="$2"; else BUNDLE_ID="$2"; fi
            shift 2 ;;
        *) usage ;;
    esac
done
# Un dossier de sortie relatif se lit depuis le dossier d'appel, avant le cd vers le dépôt.
case "$SORTIE" in /*) ;; build) ;; *) SORTIE="$PWD/$SORTIE" ;; esac
cd "$(dirname "$0")/.."

NOM="Jalons"
case "$BUNDLE_ID" in
    io.github.djoko-cli.jalons) ;;
    io.github.djoko-cli.jalons.?*) NOM="Jalons-${BUNDLE_ID#io.github.djoko-cli.jalons.}" ;;
    *) echo "ERREUR : identifiant inattendu : $BUNDLE_ID" >&2; exit 2 ;;
esac
APP="$SORTIE/$NOM.app"
ICON="Ressources/AppIcon.icon"

# Pas d'app sans icône : on s'arrête avant de compiler si elle manque.
if [ ! -f "$ICON/icon.json" ] || ! ls "$ICON"/Assets/*.png >/dev/null 2>&1; then
    echo "ERREUR : icône absente ($ICON). Régénérer le calque : swift scripts/dessiner-icone.swift $ICON/Assets/jalon.png" >&2
    exit 1
fi

swift build -c release --product Jalons
BIN_DIR="$(swift build -c release --product Jalons --show-bin-path)"

rm -rf "$APP"
mkdir -p build "$APP/Contents/MacOS" "$APP/Contents/Resources"
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
    <key>CFBundleDocumentTypes</key>
    <array>
        <dict>
            <key>CFBundleTypeName</key><string>Feuille de route Markdown</string>
            <key>CFBundleTypeRole</key><string>Viewer</string>
            <key>LSHandlerRank</key><string>Alternate</string>
            <key>LSItemContentTypes</key><array><string>net.daringfireball.markdown</string></array>
        </dict>
    </array>
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
# Jalons s'offre pour le seul Markdown, au rang « Alternate » : dans « Ouvrir avec », jamais l'app par défaut.
lire_plist() { /usr/libexec/PlistBuddy -c "Print :$1" "$APP/Contents/Info.plist" 2>/dev/null || true; }
RANG=$(lire_plist CFBundleDocumentTypes:0:LSHandlerRank)
TYPE=$(lire_plist CFBundleDocumentTypes:0:LSItemContentTypes:0)
AUTRE_TYPE=$(lire_plist CFBundleDocumentTypes:0:LSItemContentTypes:1)
AUTRE_DECLARATION=$(lire_plist CFBundleDocumentTypes:1)
if [ "$RANG" != "Alternate" ] || [ "$TYPE" != "net.daringfireball.markdown" ] \
    || [ -n "$AUTRE_TYPE" ] || [ -n "$AUTRE_DECLARATION" ]; then
    echo "ERREUR : l'Info.plist doit déclarer le seul Markdown, au rang Alternate (jamais app par défaut) ;" \
        "lu : rang « $RANG », type « $TYPE », autre type « $AUTRE_TYPE »" >&2
    exit 1
fi
codesign --force --sign - --timestamp=none "$APP"
codesign --verify --strict "$APP"
echo "OK : $APP ($VERSION)"
(cd "$APP" && pwd)
