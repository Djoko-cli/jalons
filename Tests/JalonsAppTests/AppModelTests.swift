import AppKit
import Foundation
import JalonsCore
import Testing
@testable import Jalons

/// Le modèle sur une suite de réglages jetable, sans surveillance du disque, avec des specs inventées.
@MainActor
private final class Bench {
    let suite = "jalons-tests-\(UUID().uuidString)"
    let folder: URL
    let model: AppModel

    init() throws {
        _ = NSApplication.shared
        folder = URL(fileURLWithPath: canonicalPath(FileManager.default.temporaryDirectory))
            .appendingPathComponent("jalons-modele-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        model = AppModel(options: LaunchOptions(arguments: ["Jalons", "-settingsSuite", suite, "-noWatch"]))
    }

    func spec(_ name: String) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try "# \(name)\n\n- [ ] Phase 1 : socle\n".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    var saved: FollowedRoadmaps? {
        UserDefaults(suiteName: suite)?.data(forKey: AppModel.followedKey)
            .flatMap { try? JSONDecoder().decode(FollowedRoadmaps.self, from: $0) }
    }

    func tearDown() {
        for tracker in model.trackers { model.remove(tracker) }
        UserDefaults().removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }
}

@MainActor @Suite(.serialized) struct AppModelTests {
    @Test func theSingleFollowedSpecIsCarriedOver() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        let spec = try bench.spec("a.md")
        UserDefaults(suiteName: bench.suite)!.set(spec.path, forKey: AppModel.legacySpecPathKey)
        bench.model.start()
        #expect(bench.model.trackers.map(\.path) == [spec.path])
        #expect(bench.model.primary?.path == spec.path)
        #expect(bench.model.trackers.first?.isPanelVisible == false)
        // Enregistrée aussitôt : la reprise ne se refait pas au lancement suivant.
        #expect(bench.saved?.paths == [spec.path])
    }

    @Test func aSpecReachedThroughASymbolicLinkIsNotFollowedTwice() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.model.start()
        let spec = try bench.spec("a.md")
        let link = bench.folder.appendingPathComponent("lien.md")
        try FileManager.default.createSymbolicLink(at: link, withDestinationURL: spec)
        bench.model.add(spec)
        bench.model.add(link)
        #expect(bench.model.trackers.count == 1)
        #expect(bench.saved?.paths == [spec.standardizedFileURL.path])
    }

    @Test func aRemovedTrackerIsReleasedAndForgotten() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.model.start()
        let a = try bench.spec("a.md"), b = try bench.spec("b.md")
        weak var removed: RoadmapTracker?
        // Sans boucle d'événements, AppKit garde la fenêtre fermée jusqu'à la fin du bassin d'autorelease.
        autoreleasepool {
            bench.model.add(a)
            bench.model.add(b)
            removed = bench.model.trackers.first
            #expect(removed?.isPanelVisible == true)
            bench.model.remove(bench.model.trackers[0])
        }
        #expect(removed == nil)
        #expect(bench.saved?.paths.count == 1)
        #expect(bench.model.primary?.specURL.lastPathComponent == "b.md")
    }

    @Test func replacingKeepsTheRankAndHidesNothingNew() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.model.start()
        let a = try bench.spec("a.md"), b = try bench.spec("b.md"), c = try bench.spec("c.md")
        bench.model.add(a)
        bench.model.add(b)
        bench.model.trackers[0].hidePanel()
        bench.model.replace(bench.model.trackers[0], with: c)
        #expect(bench.model.trackers.map(\.specURL.lastPathComponent) == ["c.md", "b.md"])
        #expect(bench.model.trackers[0].isPanelVisible == false)
        #expect(bench.saved?.primary == c.standardizedFileURL.path)
        // Vers une spec déjà suivie : l'ancienne disparaît, l'autre garde sa frise telle quelle.
        bench.model.trackers[1].hidePanel()
        bench.model.replace(bench.model.trackers[0], with: b)
        #expect(bench.model.trackers.map(\.specURL.lastPathComponent) == ["b.md"])
        #expect(bench.model.trackers[0].isPanelVisible == false)
    }
}
