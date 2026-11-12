import AppKit
import Foundation
import JalonsCore
import Testing
@testable import Jalons

/// De bout en bout, avec la vraie surveillance : une copie de travail ajoutée après le lancement, et un plan écrit
/// dedans, apparaissent sans relancer l'app.
@MainActor @Suite(.serialized) struct CopyWatchTests {
    @Test func aPlanWrittenInACopyAddedAfterLaunchShowsUp() async throws {
        _ = NSApplication.shared
        let root = URL(fileURLWithPath: canonicalPath(FileManager.default.temporaryDirectory))
            .appendingPathComponent("jalons-surveillance-copies-\(UUID().uuidString)", isDirectory: true)
        let main = root.appendingPathComponent("principale", isDirectory: true)
        let suite = "jalons-tests-\(UUID().uuidString)"
        try FileManager.default.createDirectory(at: main, withIntermediateDirectories: true)
        defer {
            UserDefaults().removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: root)
        }
        try git(["init", "-q", "-b", "main"], in: main)
        try git(["commit", "-q", "--allow-empty", "-m", "départ"], in: main)
        let spec = main.appendingPathComponent("docs/superpowers/specs/2026-01-01-projet-design.md")
        try FileManager.default.createDirectory(at: spec.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "# Projet\n\n- [ ] Phase 1 : socle\n".write(to: spec, atomically: true, encoding: .utf8)

        let model = AppModel(options: LaunchOptions(arguments: ["Jalons", "-settingsSuite", suite]))
        model.start()
        model.add(spec)
        defer { for tracker in model.trackers { model.remove(tracker) } }
        let tracker = try #require(model.trackers.first)
        try await Task.sleep(for: .milliseconds(500))

        // Le dépôt n'a encore aucune copie : `.git/worktrees` n'existe pas au lancement.
        let copy = root.appendingPathComponent("copie-fonction", isDirectory: true)
        try git(["worktree", "add", "-q", "-b", "fonction", copy.path], in: main)
        let plan = copy.appendingPathComponent("docs/superpowers/plans/2026-01-02-phase-1-socle.md")
        try FileManager.default.createDirectory(at: plan.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "### Task 1: A\n- [x] a\n- [ ] b\n".write(to: plan, atomically: true, encoding: .utf8)

        var seen: String?
        for _ in 0..<80 {
            if case .loaded(let roadmap) = tracker.state, let name = roadmap.phases.first?.plans.first?.copyName {
                seen = name
                break
            }
            try await Task.sleep(for: .milliseconds(100))
        }
        #expect(seen == "fonction")
    }

    private func git(_ arguments: [String], in directory: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["-c", "user.name=Essai", "-c", "user.email=essai@example.invalid", "-c",
                             "core.hooksPath=/dev/null", "-c", "commit.gpgsign=false"] + arguments
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
