import Foundation
import JalonsCore
import Testing
@testable import Jalons

/// Un compteur partagé avec la file de FSEvents.
private final class Counter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func increment() { lock.withLock { count += 1 } }
    var value: Int { lock.withLock { count } }
}

@Suite(.serialized) struct FileWatcherTests {
    @Test func canonicalPathsMatchWhatFSEventsReports() {
        #expect(canonicalPath(URL(fileURLWithPath: "/tmp")) == "/private/tmp")
        #expect(canonicalPath(URL(fileURLWithPath: "/tmp/jalons-\(UUID().uuidString)/plans"))
                .hasPrefix("/private/tmp/jalons-"))
    }

    @Test func reportsAChangeThenStaysSilentAfterStop() async throws {
        let directory = URL(fileURLWithPath: canonicalPath(FileManager.default.temporaryDirectory))
            .appendingPathComponent("jalons-surveillance-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let counter = Counter()
        let prefix = directory.path + "/"
        let watcher = FileWatcher(paths: [directory.path], accepts: { $0.hasPrefix(prefix) }, handler: { counter.increment() })
        #expect(watcher.start())
        try await Task.sleep(for: .milliseconds(300))

        // Enregistrement atomique (fichier temporaire puis renommage), comme un éditeur.
        try "- [x] Étape".write(to: directory.appendingPathComponent("plan.md"), atomically: true, encoding: .utf8)
        var waited = 0
        while counter.value == 0 && waited < 50 {
            try await Task.sleep(for: .milliseconds(100))
            waited += 1
        }
        #expect(counter.value > 0)

        watcher.stop()
        try await Task.sleep(for: .milliseconds(300))
        let before = counter.value
        try "- [ ] Étape".write(to: directory.appendingPathComponent("plan.md"), atomically: true, encoding: .utf8)
        try await Task.sleep(for: .milliseconds(1500))
        #expect(counter.value == before)
    }

    @Test func manyStartStopCyclesUnderWritesDoNotCrash() async throws {
        let directory = URL(fileURLWithPath: canonicalPath(FileManager.default.temporaryDirectory))
            .appendingPathComponent("jalons-cycles-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("plan.md")
        let writer = Task.detached {
            for index in 0..<2_000 where !Task.isCancelled {
                try? "\(index)".write(to: file, atomically: false, encoding: .utf8)
            }
        }
        for _ in 0..<200 {
            let watcher = FileWatcher(paths: [directory.path], accepts: { _ in true }, handler: {})
            watcher.start()
            watcher.stop()
        }
        writer.cancel()
        _ = await writer.result
    }
}

@Suite struct LaunchOptionsTests {
    @Test func readsTheDebuggingArguments() {
        let options = LaunchOptions(arguments: ["Jalons", "-specPath", "/tmp/s.md", "-snapshotDir", "/tmp/i",
                                                "-quitAfterSnapshot", "-appearance", "dark", "-noWatch",
                                                "-settingsSuite", "essai"])
        #expect(options.specPath == "/tmp/s.md")
        #expect(options.snapshotDirectory == "/tmp/i")
        #expect(options.quitAfterSnapshot)
        #expect(options.appearance == "dark")
        #expect(options.noWatch)
        #expect(options.settingsSuite == "essai")
        let none = LaunchOptions(arguments: ["Jalons", "-specPath"])
        #expect(none.specPath == nil)
        #expect(!none.noWatch)
    }
}
