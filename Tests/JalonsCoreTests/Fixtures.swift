import Foundation

/// Un dossier temporaire `docs/superpowers/{specs,plans}` rempli de textes inventés, effacé par `remove()`.
struct FixtureFolder {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("jalons-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: specsDirectory, withIntermediateDirectories: true)
    }

    var specsDirectory: URL { root.appendingPathComponent("docs/superpowers/specs", isDirectory: true) }
    var plansDirectory: URL { root.appendingPathComponent("docs/superpowers/plans", isDirectory: true) }

    @discardableResult
    func writeSpec(_ text: String, name: String = "2026-01-01-projet-design.md") throws -> URL {
        let url = specsDirectory.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    @discardableResult
    func writePlan(_ text: String, name: String) throws -> URL {
        try FileManager.default.createDirectory(at: plansDirectory, withIntermediateDirectories: true)
        let url = plansDirectory.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }
}

enum Samples {
    /// Une spec inventée : trois phases, la première cochée, plus des cases qui ne sont pas des phases.
    static let spec = """
    # Projet d'essai : conception

    ## Décisions

    - [x] Une case qui n'est pas une phase

    ## Feuille de route

    - [x] Phase 1 : socle
    - [ ] Phase 2 : inventaire
    - [ ] Phase 3 : noms
    """

    /// Un plan de la phase 2 : une tâche faite (2/2), une en cours (1/2), une à faire (0/1).
    static let planPhase2 = """
    # Plan de la phase 2

    ### Task 1: Préparer l'export
    - [x] Étape 1
    - [x] Étape 2

    ### Task 2: Corriger l'extracteur
    - [x] Étape 1
    - [ ] Étape 2

    ### Task 3: Rédiger la table
    - [ ] Étape 1
    """
}
