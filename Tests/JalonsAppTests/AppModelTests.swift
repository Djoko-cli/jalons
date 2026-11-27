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

    /// `debugSpec` : le nom d'une spec à suivre seule, comme une mise au point (`-specPath`).
    init(debugSpec: String? = nil) throws {
        _ = NSApplication.shared
        folder = URL(fileURLWithPath: canonicalPath(FileManager.default.temporaryDirectory))
            .appendingPathComponent("jalons-modele-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var arguments = ["Jalons", "-settingsSuite", suite, "-noWatch"]
        if let debugSpec {
            let url = folder.appendingPathComponent(debugSpec)
            try "# \(debugSpec)\n\n- [ ] Phase 1 : socle\n".write(to: url, atomically: true, encoding: .utf8)
            arguments += ["-specPath", url.path]
        }
        model = AppModel(options: LaunchOptions(arguments: arguments))
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

    /// Quitter ferme les fenêtres de l'app (`close()`, sans `windowShouldClose`) : la frise reste à rouvrir au prochain
    /// lancement. Seul un geste de fermeture (`performClose`, celui du bouton et de ⌘W) la retient masquée.
    @Test func onlyACloseGestureHidesTheTimeline() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.model.start()
        let a = try bench.spec("a.md")
        bench.model.add(a)
        let tracker = try #require(bench.model.trackers.first)
        let path = a.standardizedFileURL.path
        #expect(bench.saved?.visible.contains(path) == true, "frise visible avant toute fermeture")

        try #require(tracker.panelWindow).close()
        #expect(bench.saved?.visible.contains(path) == true, "la fermeture imposée en quittant l'a retenue masquée")

        tracker.showPanel()
        try #require(tracker.panelWindow).performClose(nil)
        #expect(tracker.isPanelVisible == false)
        #expect(bench.saved?.visible.contains(path) == false, "le geste de fermeture ne l'a pas retenue masquée")
    }

    // MARK: Specs ouvertes par le système (`open -a Jalons`, « Ouvrir avec »)

    final class Alerts { var count = 0 }

    @Test func specsOpenedTogetherAreAllFollowedAndShown() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        let alerts = Alerts()
        bench.model.alert = { alerts.count += 1 }
        bench.model.start()
        let a = try bench.spec("a.md")
        let b = try bench.spec("b.md")
        bench.model.receive([a, b])
        #expect(bench.model.trackers.map(\.specURL.lastPathComponent) == ["a.md", "b.md"])
        #expect(bench.model.trackers.map(\.isPanelVisible) == [true, true])
        #expect(bench.saved?.paths.count == 2)
        #expect(alerts.count == 0, "aucune alerte pour des specs acceptées")
        // Les deux frises s'ouvrent sur l'écran du pointeur, la seconde à gauche de la première.
        let frames = bench.model.trackers.compactMap(\.panelWindow?.frame)
        try #require(frames.count == 2)
        #expect(frames[1].maxX <= frames[0].minX, "la seconde frise n'est pas à gauche de la première : \(frames)")
    }

    /// Une frise masquée garde sa place : une frise nouvelle ne la prend pas, et rien ne se recouvre quand on réaffiche.
    @Test func aHiddenTimelineKeepsItsPlaceFromANewOne() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.model.start()
        let a = try bench.spec("a.md")
        let b = try bench.spec("b.md")
        bench.model.receive([a])
        let hidden = try #require(bench.model.trackers.first?.panelWindow)
        hidden.performClose(nil)
        bench.model.receive([b])
        let opened = try #require(bench.model.trackers.last?.panelWindow?.frame)
        #expect(!opened.intersects(hidden.frame), "la frise nouvelle recouvre la masquée : \(opened) et \(hidden.frame)")
    }

    /// Une frise masquée lors d'un lancement précédent n'a pas encore de fenêtre, mais sa place est retenue.
    @Test func aTimelineHiddenAtTheLastLaunchKeepsItsPlace() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        let a = try bench.spec("a.md")
        let b = try bench.spec("b.md")
        var followed = FollowedRoadmaps()
        followed.add(a.path)
        followed.setVisible(a.path, false)
        UserDefaults(suiteName: bench.suite)!.set(try JSONEncoder().encode(followed), forKey: AppModel.followedKey)
        // La place retenue de A : là où une frise nouvelle s'ouvrirait, sur l'écran du pointeur.
        let screens = NSScreen.screens.map { PanelPlacement.Screen(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        let size = CGSize(width: 360, height: 660)
        let origin = try #require(PanelPlacement.topRight(size: size, mouse: NSEvent.mouseLocation, screens: screens,
                                                          fallback: NSScreen.screens.first?.visibleFrame, occupied: []))
        let place = NSRect(origin: origin, size: size)
        let name = RoadmapTracker.frameName(for: a.path)
        let probe = NSWindow(contentRect: place, styleMask: [.titled], backing: .buffered, defer: true)
        probe.setFrame(place, display: false)
        probe.saveFrame(usingName: name)
        defer { NSWindow.removeFrame(usingName: name) }
        bench.model.start()
        #expect(bench.model.trackers.first?.panelWindow == nil, "la frise masquée a déjà une fenêtre")
        bench.model.receive([b])
        let opened = try #require(bench.model.trackers.last?.panelWindow?.frame)
        #expect(!opened.intersects(place), "la frise nouvelle prend la place retenue de la masquée : \(opened)")
    }

    /// Une mise au point (`-specPath`, capture) suit sa seule spec : un fichier reçu n'est pas suivi, et l'alerte sonne.
    @Test func aDebugInstanceRefusesReceivedFiles() throws {
        let bench = try Bench(debugSpec: "seule.md")
        defer { bench.tearDown() }
        let alerts = Alerts()
        bench.model.alert = { alerts.count += 1 }
        bench.model.start()
        let b = try bench.spec("b.md")
        bench.model.receive([b])
        #expect(bench.model.trackers.map(\.specURL.lastPathComponent) == ["seule.md"])
        #expect(alerts.count == 1)
    }

    /// La boîte filtre comme le modèle : une image passée par la boîte n'est pas suivie, et l'alerte sonne.
    @Test func theInboxFiltersLikeTheModel() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        let alerts = Alerts()
        bench.model.alert = { alerts.count += 1 }
        bench.model.start()
        let image = bench.folder.appendingPathComponent("capture.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: image)
        let inbox = SpecInbox()
        inbox.connect(to: bench.model)
        inbox.receive([image])
        #expect(bench.model.trackers.isEmpty)
        #expect(alerts.count == 1)
    }

    @Test func theSameSpecTwiceInOneBatchIsFollowedOnce() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        let alerts = Alerts()
        bench.model.alert = { alerts.count += 1 }
        bench.model.start()
        let a = try bench.spec("a.md")
        bench.model.receive([a, a])
        #expect(bench.model.trackers.count == 1)
        #expect(bench.saved?.paths.count == 1)
        #expect(alerts.count == 0)
    }

    /// La boîte branchée sur le modèle : un fichier ouvert par le système suit le chemin de `receive`.
    @Test func theInboxConnectedToTheModelFollowsWhatItReceives() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.model.start()
        let a = try bench.spec("a.md")
        let inbox = SpecInbox()
        inbox.connect(to: bench.model)
        inbox.receive([a])
        #expect(bench.model.trackers.map(\.specURL.lastPathComponent) == ["a.md"])
    }

    @Test func aSpecAlreadyFollowedIsShownAgainNotFollowedTwice() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        bench.model.start()
        let a = try bench.spec("a.md")
        bench.model.add(a)
        let tracker = try #require(bench.model.trackers.first)
        let window = try #require(tracker.panelWindow)
        window.setFrameOrigin(NSPoint(x: window.frame.minX - 40, y: window.frame.minY - 40))
        let placed = window.frame
        window.performClose(nil)
        #expect(tracker.isPanelVisible == false)
        bench.model.receive([a])
        #expect(bench.model.trackers.count == 1)
        #expect(tracker.isPanelVisible)
        // Une frise qui a déjà une place revient à cette place : rien ne la déplace.
        #expect(tracker.panelWindow?.frame == placed, "frise déplacée : \(String(describing: tracker.panelWindow?.frame)) au lieu de \(placed)")
    }

    /// Un fichier refusé n'empêche pas de suivre ceux qui l'accompagnent, et l'alerte ne sonne qu'une fois.
    @Test func refusedFilesAreNotFollowedAndSoundTheAlertOnce() throws {
        let bench = try Bench()
        defer { bench.tearDown() }
        let alerts = Alerts()
        bench.model.alert = { alerts.count += 1 }
        bench.model.start()
        let image = bench.folder.appendingPathComponent("capture.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: image)
        let other = bench.folder.appendingPathComponent("autre.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: other)
        let a = try bench.spec("a.md")
        bench.model.receive([image, a, other])
        #expect(bench.model.trackers.map(\.specURL.lastPathComponent) == ["a.md"])
        #expect(alerts.count == 1)
    }
}
