"""Le contrôle de l'Info.plist (scripts/verifier-plist.sh) : Jalons s'offre pour le seul Markdown, en lecteur, au rang
Alternate, sans déclarer de type à lui. Chaque plist piégé doit être refusé par le contrôle lui-même : sa ligne
commence par « ERREUR : l'Info.plist », et le code de sortie vaut 1."""
import copy
import os
import plistlib
import subprocess
import tempfile
import unittest

SCRIPT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), 'verifier-plist.sh')
MESSAGE = "ERREUR : l'Info.plist"

VALIDE = {
    'CFBundleIdentifier': 'io.github.exemple.essai',
    'CFBundleDocumentTypes': [{
        'CFBundleTypeName': 'Feuille de route Markdown',
        'CFBundleTypeRole': 'Viewer',
        'LSHandlerRank': 'Alternate',
        'LSItemContentTypes': ['net.daringfireball.markdown'],
    }],
}


def verifier(contenu):
    with tempfile.TemporaryDirectory() as dossier:
        chemin = os.path.join(dossier, 'Info.plist')
        with open(chemin, 'wb') as f:
            plistlib.dump(contenu, f)
        sortie = subprocess.run(['/bin/bash', SCRIPT, chemin], capture_output=True, text=True)
    return sortie.returncode, sortie.stderr


def piege(modifier):
    contenu = copy.deepcopy(VALIDE)
    modifier(contenu)
    return contenu


class VerifierPlistTests(unittest.TestCase):
    def refuse(self, contenu):
        code, erreur = verifier(contenu)
        self.assertEqual(1, code, erreur)
        self.assertTrue(erreur.startswith(MESSAGE), erreur)

    def test_la_declaration_attendue_passe(self):
        code, erreur = verifier(VALIDE)
        self.assertEqual(0, code, erreur)
        self.assertNotIn('ERREUR', erreur)

    def test_un_autre_rang_est_refuse(self):
        self.refuse(piege(lambda c: c['CFBundleDocumentTypes'][0].update(LSHandlerRank='Default')))
        self.refuse(piege(lambda c: c['CFBundleDocumentTypes'][0].update(LSHandlerRank='Owner')))

    def test_le_role_editeur_est_refuse(self):
        self.refuse(piege(lambda c: c['CFBundleDocumentTypes'][0].update(CFBundleTypeRole='Editor')))

    def test_un_second_type_est_refuse(self):
        self.refuse(piege(lambda c: c['CFBundleDocumentTypes'][0]['LSItemContentTypes'].append('public.plain-text')))

    def test_le_texte_brut_a_la_place_du_markdown_est_refuse(self):
        self.refuse(piege(lambda c: c['CFBundleDocumentTypes'][0].update(LSItemContentTypes=['public.plain-text'])))

    def test_une_seconde_declaration_est_refusee(self):
        self.refuse(piege(lambda c: c['CFBundleDocumentTypes'].append(dict(c['CFBundleDocumentTypes'][0]))))

    def test_des_extensions_declarees_sont_refusees(self):
        self.refuse(piege(lambda c: c['CFBundleDocumentTypes'][0].update(CFBundleTypeExtensions=['md'])))

    def test_un_type_exporte_ou_importe_est_refuse(self):
        declaration = [{'UTTypeIdentifier': 'io.github.exemple.feuille', 'UTTypeConformsTo': ['public.plain-text']}]
        self.refuse(piege(lambda c: c.update(UTExportedTypeDeclarations=declaration)))
        self.refuse(piege(lambda c: c.update(UTImportedTypeDeclarations=declaration)))

    def test_aucune_declaration_est_refusee(self):
        self.refuse(piege(lambda c: c.pop('CFBundleDocumentTypes')))


if __name__ == '__main__':
    unittest.main()
