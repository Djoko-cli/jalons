import Foundation
@testable import JalonsCore

/// Un vrai dépôt git jetable et ses copies de travail (`git worktree add`), dans un dossier temporaire effacé par
/// `remove()`. Le vrai git écrit les fichiers que Jalons lit (`.git/worktrees/*/gitdir`, `HEAD`) : pas de faux à tenir
/// à jour.
struct GitCopies {
    let root: URL
    var main: URL { root.appendingPathComponent("principale", isDirectory: true) }

    init(root: URL? = nil) throws {
        self.root = root ?? URL(fileURLWithPath: canonicalPath(FileManager.default.temporaryDirectory))
            .appendingPathComponent("jalons-copies-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: main, withIntermediateDirectories: true)
        try git(["init", "-q", "-b", "main"], in: main)
        try git(["commit", "-q", "--allow-empty", "-m", "départ"], in: main)
    }

    /// Ajoute une copie de travail sur une nouvelle branche, ou en tête détachée si `branch` est nil.
    @discardableResult
    func addCopy(_ folder: String, branch: String?) throws -> URL {
        let url = root.appendingPathComponent(folder, isDirectory: true)
        let mode = branch.map { ["-b", $0] } ?? ["--detach"]
        try git(["worktree", "add", "-q"] + mode + [url.path], in: main)
        return url
    }

    @discardableResult
    func write(_ text: String, to relativePath: String, in copy: URL) throws -> URL {
        let url = copy.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func remove() {
        try? FileManager.default.removeItem(at: root)
    }

    /// Lance git sans la configuration de la machine (crochets, signature) ni ses variables `GIT_*`.
    func git(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-c", "user.name=Essai", "-c", "user.email=essai@example.invalid", "-c",
                             "core.hooksPath=/dev/null", "-c", "commit.gpgsign=false", "-c", "protocol.file.allow=always"] + arguments
        process.currentDirectoryURL = directory
        var environment = ProcessInfo.processInfo.environment.filter { !$0.key.hasPrefix("GIT_") }
        environment["GIT_CONFIG_NOSYSTEM"] = "1"
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { throw CocoaError(.executableLoad) }
    }
}
