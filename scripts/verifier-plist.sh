#!/bin/bash
# Contrôle de l'Info.plist de Jalons : la seule déclaration de document est le Markdown, en lecteur (Viewer), au rang
# Alternate, sans extension ni type déclaré par l'app. Jalons figure ainsi dans « Ouvrir avec » sans jamais devenir
# l'app par défaut des fichiers Markdown. Appelé par build-app.sh, testé par scripts/tests/test_verifier_plist.py.
# Usage : scripts/verifier-plist.sh <Info.plist>
set -uo pipefail

PLIST="${1:?usage : scripts/verifier-plist.sh <Info.plist>}"
lire() { /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" 2>/dev/null; }
present() { /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST" > /dev/null 2>&1; }

ecarts=""
[ "$(lire CFBundleDocumentTypes:0:LSHandlerRank)" = "Alternate" ] || ecarts="$ecarts rang"
[ "$(lire CFBundleDocumentTypes:0:CFBundleTypeRole)" = "Viewer" ] || ecarts="$ecarts rôle"
[ "$(lire CFBundleDocumentTypes:0:LSItemContentTypes:0)" = "net.daringfireball.markdown" ] || ecarts="$ecarts type"
present CFBundleDocumentTypes:0:LSItemContentTypes:1 && ecarts="$ecarts second-type"
present CFBundleDocumentTypes:1 && ecarts="$ecarts seconde-déclaration"
present CFBundleDocumentTypes:0:CFBundleTypeExtensions && ecarts="$ecarts extensions"
present UTExportedTypeDeclarations && ecarts="$ecarts type-exporté"
present UTImportedTypeDeclarations && ecarts="$ecarts type-importé"

if [ -n "$ecarts" ]; then
    echo "ERREUR : l'Info.plist doit déclarer le seul Markdown, en lecteur, au rang Alternate (jamais app par défaut) ;" \
        "écarts :$ecarts" >&2
    exit 1
fi
