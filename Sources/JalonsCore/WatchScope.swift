import Foundation

/// Ce que la surveillance d'une feuille de route regarde, en chemins réels (ceux que FSEvents rapporte) : le dossier de
/// sa spec, son dossier des plans, celui de chaque autre copie de travail, et le registre des copies du dépôt.
///
/// FSEvents reçoit des dossiers qui existent toujours : le parent du dossier de la spec, la racine de chaque autre copie
/// (son dossier des plans peut ne pas exister encore) et le dossier git commun (son registre `worktrees` naît avec la
/// première copie ajoutée et disparaît avec la dernière). Seuls comptent les plans, la spec, et dans le registre
/// l'arrivée ou le départ d'une copie, son `gitdir` et son `HEAD` : jamais l'index ni les journaux de git.
public struct WatchScope: Sendable, Equatable {
    /// Les dossiers confiés à FSEvents.
    public var roots: [String]
    /// Les dossiers dont tout le contenu compte.
    var folders: [String]
    var registry: String?

    public init(specURL: URL, sources: PlanLocator.Sources, fileManager: FileManager = .default) {
        let specDirectory = canonicalPath(specURL.deletingLastPathComponent())
        folders = [specDirectory, canonicalPath(sources.directory)] + sources.otherCopies.map { canonicalPath($0.directory) }
        registry = sources.registry.map(canonicalPath)
        var roots = [(specDirectory as NSString).deletingLastPathComponent]
        roots += sources.otherCopies.map { canonicalPath($0.root) }.filter { fileManager.fileExists(atPath: $0) }
        if let registry { roots.append((registry as NSString).deletingLastPathComponent) }
        var seen = Set<String>()
        self.roots = roots.filter { seen.insert($0).inserted }
    }

    public func accepts(_ path: String) -> Bool {
        if folders.contains(where: { path == $0 || path.hasPrefix($0 + "/") }) { return true }
        guard let registry else { return false }
        let parent = (path as NSString).deletingLastPathComponent
        if path == registry || parent == registry { return true }
        let name = (path as NSString).lastPathComponent
        return (parent as NSString).deletingLastPathComponent == registry && (name == "gitdir" || name == "HEAD")
    }
}
