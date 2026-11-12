import Foundation

/// Une copie de travail d'un dépôt git : la copie principale, ou une copie ajoutée par `git worktree add`.
public struct WorkingCopy: Sendable, Equatable {
    /// Le dossier racine de la copie, en chemin réel.
    public var root: URL
    /// La branche de la copie, ou le nom de son dossier quand elle est en tête détachée.
    public var name: String

    public init(root: URL, name: String) {
        self.root = root
        self.name = name
    }
}

/// Les copies de travail du dépôt d'un fichier, lues dans les fichiers que git tient à jour (`.git` de la copie,
/// `.git/worktrees/*/gitdir` et `HEAD`), sans lancer git. Une copie dont le dossier a disparu est laissée de côté.
public struct WorkingCopies: Sendable, Equatable {
    /// La copie qui contient le fichier.
    public var current: WorkingCopy
    /// Toutes les autres : la copie principale d'abord (si le fichier est dans une copie ajoutée), puis les copies
    /// ajoutées, dans l'ordre de leur nom dans `.git/worktrees`.
    public var others: [WorkingCopy]
    /// Le dossier `.git/worktrees` du dépôt : ajouter ou retirer une copie y crée ou y efface un dossier.
    public var registry: URL

    /// nil hors d'un dépôt git, ou si ses fichiers ne se lisent pas.
    public static func around(_ url: URL, fileManager: FileManager = .default) -> WorkingCopies? {
        guard let (currentRoot, common) = repository(containing: url, fileManager: fileManager) else { return nil }
        var copies: [WorkingCopy] = []
        // La copie principale : celle dont le `.git` est le dossier commun. Pas pour un dépôt nu, même rangé dans un
        // dossier `.git` (une disposition courante pour ne travailler que dans des copies ajoutées).
        if common.lastPathComponent == ".git", !isBare(common) {
            let mainRoot = common.deletingLastPathComponent()
            copies.append(WorkingCopy(root: mainRoot, name: branch(in: common, root: mainRoot)))
        }
        let registry = common.appendingPathComponent("worktrees", isDirectory: true)
        let entries = (try? fileManager.contentsOfDirectory(atPath: registry.path)) ?? []
        for entry in entries.sorted() {
            let admin = registry.appendingPathComponent(entry, isDirectory: true)
            guard let gitdir = firstLine(admin.appendingPathComponent("gitdir")) else { continue }
            // Absolu d'ordinaire ; relatif au dossier de la copie dans `.git/worktrees` avec `--relative-paths`.
            let dotGit = gitdir.hasPrefix("/") ? URL(fileURLWithPath: gitdir)
                : admin.appendingPathComponent(gitdir).standardizedFileURL
            let root = URL(fileURLWithPath: canonicalPath(dotGit.deletingLastPathComponent()))
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: root.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                continue
            }
            copies.append(WorkingCopy(root: root, name: branch(in: admin, root: root)))
        }
        let current = copies.first { $0.root.path == currentRoot.path }
            ?? WorkingCopy(root: currentRoot, name: currentRoot.lastPathComponent)
        return WorkingCopies(current: current, others: copies.filter { $0.root.path != currentRoot.path },
                             registry: URL(fileURLWithPath: canonicalPath(registry)))
    }

    /// La racine de la copie qui contient `url` et le dossier git commun du dépôt, en chemins réels.
    static func repository(containing url: URL, fileManager: FileManager) -> (root: URL, common: URL)? {
        var directory = URL(fileURLWithPath: canonicalPath(url.deletingLastPathComponent()))
        while true {
            let dotGit = directory.appendingPathComponent(".git")
            var isDirectory: ObjCBool = false
            if fileManager.fileExists(atPath: dotGit.path, isDirectory: &isDirectory) {
                if isDirectory.boolValue { return (directory, dotGit) }
                // Une copie ajoutée : son `.git` est un fichier « gitdir: <dépôt>/.git/worktrees/<nom> ».
                guard let line = firstLine(dotGit), line.hasPrefix("gitdir:") else { return nil }
                let path = line.dropFirst("gitdir:".count).trimmingCharacters(in: .whitespaces)
                let admin = URL(fileURLWithPath: path, relativeTo: directory).standardizedFileURL
                // `commondir` mène au dossier commun, d'ordinaire « ../.. » depuis le dossier de la copie. Sans lui
                // (sous-module, `--separate-git-dir`), le dossier désigné est lui-même le dossier commun.
                let common: URL
                if let relative = firstLine(admin.appendingPathComponent("commondir")) {
                    common = relative.hasPrefix("/") ? URL(fileURLWithPath: relative)
                        : admin.appendingPathComponent(relative).standardizedFileURL
                } else {
                    common = admin
                }
                return (directory, URL(fileURLWithPath: canonicalPath(common)))
            }
            let parent = directory.deletingLastPathComponent()
            guard parent.path != directory.path else { return nil }
            directory = parent
        }
    }

    /// Un dépôt nu : `bare = true` dans la section `[core]` de son `config`.
    static func isBare(_ common: URL) -> Bool {
        guard let data = try? Data(contentsOf: common.appendingPathComponent("config")),
              let text = String(data: data, encoding: .utf8) else { return false }
        var inCore = false
        for raw in text.split(whereSeparator: \.isNewline) {
            let line = raw.trimmingCharacters(in: .whitespaces).lowercased()
            if line.hasPrefix("[") { inCore = line.hasPrefix("[core]") }
            if inCore, line.replacingOccurrences(of: " ", with: "") == "bare=true" { return true }
        }
        return false
    }

    /// « ref: refs/heads/fonction » → « fonction » ; une tête détachée (un hash) → le nom du dossier de la copie.
    static func branch(in gitDirectory: URL, root: URL) -> String {
        guard let head = firstLine(gitDirectory.appendingPathComponent("HEAD")), head.hasPrefix("ref:") else {
            return root.lastPathComponent
        }
        let reference = head.dropFirst("ref:".count).trimmingCharacters(in: .whitespaces)
        return reference.hasPrefix("refs/heads/") ? String(reference.dropFirst("refs/heads/".count)) : reference
    }

    static func firstLine(_ url: URL) -> String? {
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8) else { return nil }
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init)?.trimmingCharacters(in: .whitespaces)
        return line?.isEmpty == false ? line : nil
    }
}
