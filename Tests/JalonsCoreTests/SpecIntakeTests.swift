import Foundation
import JalonsCore
import Testing

/// Les fichiers que le système ouvre dans Jalons (`open -a Jalons`, « Ouvrir avec ») : les mêmes que ceux du menu
/// « Ajouter une feuille de route… », Markdown et texte brut. Aucun accès au disque : le type se lit sur le nom.
@Suite struct SpecIntakeTests {
    @Test func aMarkdownSpecIsAccepted() {
        #expect(SpecIntake.accepts(URL(fileURLWithPath: "/tmp/projet/docs/feuille-design.md")))
        #expect(SpecIntake.accepts(URL(fileURLWithPath: "/tmp/projet/docs/FEUILLE.MD")))
    }

    @Test func aPathWithSpacesIsAccepted() {
        #expect(SpecIntake.accepts(URL(fileURLWithPath: "/tmp/Dossier 1/feuille de route.md")))
    }

    @Test func aPlainTextFileIsAcceptedAsInTheMenu() {
        #expect(SpecIntake.accepts(URL(fileURLWithPath: "/tmp/projet/notes.txt")))
    }

    @Test func anImageIsRefused() {
        #expect(!SpecIntake.accepts(URL(fileURLWithPath: "/tmp/projet/capture.png")))
    }

    /// Du texte, mais pas du texte brut : le menu les refuse aussi.
    @Test func structuredTextIsRefused() {
        #expect(!SpecIntake.accepts(URL(fileURLWithPath: "/tmp/projet/donnees.json")))
        #expect(!SpecIntake.accepts(URL(fileURLWithPath: "/tmp/projet/page.html")))
    }

    @Test func aFileWithoutExtensionIsRefused() {
        #expect(!SpecIntake.accepts(URL(fileURLWithPath: "/tmp/projet/LISEZMOI")))
    }

    @Test func aFolderIsRefusedEvenWithAMarkdownName() {
        #expect(!SpecIntake.accepts(URL(fileURLWithPath: "/tmp/projet/archives.md", isDirectory: true)))
    }

    @Test func aWebLinkIsRefused() throws {
        #expect(!SpecIntake.accepts(try #require(URL(string: "https://example.com/feuille.md"))))
    }
}
