import Foundation

/// Trouve les plans d'une feuille de route : les fichiers Markdown du dossier `plans/` voisin du dossier de la spec
/// (`docs/superpowers/specs/x.md` → `docs/superpowers/plans/`), rangés par le numéro de phase lu dans leur nom
/// (`2026-10-16-phase-1-socle.md` → phase 1). Un plan dont le nom ne donne pas de phase est « non rattaché » :
/// il est signalé, jamais ignoré en silence.
public enum PlanLocator {
    public enum Listing: Sendable, Equatable {
        case found(byPhase: [Int: [URL]], unattached: [URL])
        /// Pas encore de dossier des plans : aucun plan, ce n'est pas une erreur.
        case missing
        case unreadable
    }

    public static func plansDirectory(forSpec spec: URL) -> URL {
        spec.deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("plans", isDirectory: true)
    }

    /// `…phase-3-…`, `phase_03`, `phase3.md` → 3 ; le mot doit être isolé (`emphase-2.md` ne compte pas).
    public static func phaseNumber(inFileName name: String) -> Int? {
        guard name.lowercased().hasSuffix(".md"),
              let match = name.firstMatch(of: #/(?i)(?:^|[^a-z])phase[-_ ]?0*(\d+)(?:[^0-9]|$)/#) else { return nil }
        return Int(match.1)
    }

    /// Les plans du dossier (fichiers ordinaires et liens symboliques), par phase, chaque liste triée par nom.
    /// « Pas encore de dossier » seulement s'il n'y a rien du tout à cet endroit : un lien cassé ou un fichier à la place
    /// du dossier est une lecture impossible, à signaler.
    public static func plans(in directory: URL, fileManager: FileManager = .default) -> Listing {
        guard (try? fileManager.attributesOfItem(atPath: directory.path)) != nil else { return .missing }
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue,
              let urls = try? fileManager.contentsOfDirectory(at: directory,
                                                              includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey],
                                                              options: [.skipsHiddenFiles]) else { return .unreadable }
        var byPhase: [Int: [URL]] = [:]
        var unattached: [URL] = []
        for url in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            // Un lien vers un plan compte ; s'il est cassé, sa lecture échouera et sera signalée.
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
            guard url.pathExtension.lowercased() == "md",
                  values?.isRegularFile == true || values?.isSymbolicLink == true else { continue }
            if let number = phaseNumber(inFileName: url.lastPathComponent) {
                byPhase[number, default: []].append(url)
            } else {
                unattached.append(url)
            }
        }
        return .found(byPhase: byPhase, unattached: unattached)
    }
}
