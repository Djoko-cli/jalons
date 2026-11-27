import AppKit
import JalonsCore
import Observation
import ServiceManagement
import UniformTypeIdentifiers

/// L'état de l'app : les feuilles de route suivies (chacune avec sa frise), la principale, et l'ouverture à la connexion.
@MainActor @Observable
final class AppModel {
    private(set) var trackers: [RoadmapTracker] = []
    private(set) var followed = FollowedRoadmaps()
    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    private(set) var launchAtLoginNote: String?

    let options: LaunchOptions
    @ObservationIgnored private let defaults: UserDefaults

    static let followedKey = "feuillesDeRoute"
    /// Les réglages d'avant les frises multiples : repris une fois, puis laissés tels quels.
    static let legacySpecPathKey = "cheminFeuilleDeRoute"
    static let legacyPanelVisibleKey = "friseVisible"
    static let legacyFrameName = "JalonsFrise"

    init(options: LaunchOptions) {
        self.options = options
        defaults = options.settingsSuite.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    /// `-specPath` suit cette seule spec, et une capture de mise au point ne doit rien changer : ni l'un ni l'autre
    /// n'enregistre la liste suivie.
    private var persists: Bool { options.specPath == nil && options.snapshotDirectory == nil }

    /// La feuille de route de l'icône de la barre des menus.
    var primary: RoadmapTracker? { trackers.first { $0.path == followed.primary } ?? trackers.first }

    var primaryState: RoadmapState { primary?.state ?? .failed(.noSpecChosen) }

    var anyPanelVisible: Bool { trackers.contains(where: \.isPanelVisible) }

    func start() {
        followed = loadFollowed()
        // Reprise des anciens réglages, une seule fois : la place d'avant (`JalonsFrise`) l'emporte sur une place
        // laissée sous le nom propre à la spec par une mise au point, et la liste est aussitôt enregistrée.
        if persists, defaults.data(forKey: Self.followedKey) == nil,
           let legacy = defaults.string(forKey: Self.legacySpecPathKey) {
            NSWindow.removeFrame(usingName: RoadmapTracker.frameName(for: legacy))
            save()
        }
        for path in followed.paths { trackers.append(makeTracker(path)) }
        for tracker in trackers {
            tracker.start()
            if options.snapshotDirectory != nil || followed.visible.contains(tracker.path) { tracker.showPanel() }
        }
        if let directory = options.snapshotDirectory {
            Task { await DebugCapture.run(model: self, directory: directory) }
        }
    }

    /// La liste suivie : celle de `-specPath`, sinon celle enregistrée, sinon celle reprise des anciens réglages.
    private func loadFollowed() -> FollowedRoadmaps {
        if let path = options.specPath {
            return FollowedRoadmaps(legacyPath: standardized(URL(fileURLWithPath: path)), legacyVisible: true)
        }
        if let data = defaults.data(forKey: Self.followedKey),
           let decoded = try? JSONDecoder().decode(FollowedRoadmaps.self, from: data) {
            return decoded
        }
        return FollowedRoadmaps(legacyPath: defaults.string(forKey: Self.legacySpecPathKey),
                                legacyVisible: defaults.bool(forKey: Self.legacyPanelVisibleKey))
    }

    /// Enregistre la liste suivie (sauf en mise au point, voir `persists`).
    private func save() {
        guard persists, let data = try? JSONEncoder().encode(followed) else { return }
        defaults.set(data, forKey: Self.followedKey)
    }

    /// Un suivi de plus. Sa frise, à sa première ouverture, se pose à gauche de celles déjà visibles sur son écran
    /// (voir `FloatingPanelController`).
    private func makeTracker(_ path: String, fallbackFrameNames: [String] = []) -> RoadmapTracker {
        let legacy = defaults.string(forKey: Self.legacySpecPathKey) == path ? [Self.legacyFrameName] : []
        return RoadmapTracker(path: path, model: self, options: options, fallbackFrameNames: fallbackFrameNames + legacy,
                              remembersFrame: persists)
    }

    /// Le chemin enregistré dans la liste suivie et affiché.
    private func standardized(_ url: URL) -> String { url.standardizedFileURL.path }

    /// Le suivi de cette spec, même atteinte par un autre chemin (lien symbolique, casse) : comparé sur le chemin réel.
    private func tracker(following url: URL) -> RoadmapTracker? {
        let real = canonicalPath(url)
        return trackers.first { canonicalPath($0.specURL) == real }
    }

    /// Suit une spec de plus et affiche sa frise ; une spec déjà suivie montre simplement la sienne.
    func add(_ url: URL) {
        if let existing = tracker(following: url) {
            existing.showPanel()
            return
        }
        let path = standardized(url)
        followed.add(path)
        save()
        let tracker = makeTracker(path)
        trackers.append(tracker)
        tracker.start()
        tracker.showPanel()
    }

    func addInteractively() {
        for url in pickSpecs(title: "Ajouter des feuilles de route", prompt: "Suivre", multiple: true) { add(url) }
    }

    /// Une spec illisible ou sans phase : en suivre une autre à sa place, avec la même frise.
    func replaceInteractively(_ tracker: RoadmapTracker) {
        guard let url = pickSpecs(title: "Remplacer la feuille de route", prompt: "Suivre", multiple: false).first else {
            return
        }
        replace(tracker, with: url)
    }

    /// Suit `url` à la place de `tracker`, au même rang et à la même place. Si `url` est déjà suivie, l'ancienne est
    /// simplement retirée, et la frise de l'autre montrée seulement si celle de l'ancienne l'était.
    func replace(_ tracker: RoadmapTracker, with url: URL) {
        guard let index = trackers.firstIndex(where: { $0 === tracker }) else { return }
        let existing = self.tracker(following: url)
        guard existing !== tracker else { return }
        let path = existing?.path ?? standardized(url)
        let wasVisible = tracker.isPanelVisible
        followed.replace(tracker.path, with: path)
        save()
        tracker.stop()
        trackers.remove(at: index)
        if let existing {
            if wasVisible { existing.showPanel() }
            return
        }
        let replacement = makeTracker(path, fallbackFrameNames: [tracker.frameName])
        trackers.insert(replacement, at: index)
        replacement.start()
        if wasVisible { replacement.showPanel() }
    }

    /// Ne suit plus cette feuille de route : sa surveillance s'arrête et sa frise se ferme.
    func remove(_ tracker: RoadmapTracker) {
        followed.remove(tracker.path)
        save()
        if persists { NSWindow.removeFrame(usingName: tracker.frameName) }
        tracker.stop()
        trackers.removeAll { $0 === tracker }
    }

    /// Celle que l'icône de la barre des menus montre.
    func setPrimary(_ tracker: RoadmapTracker) {
        followed.setPrimary(tracker.path)
        save()
    }

    func showAllPanels() { trackers.forEach { $0.showPanel() } }

    func hideAllPanels() { trackers.forEach { $0.hidePanel() } }

    /// Appelée par une frise quand elle s'ouvre ou se ferme ; mémorisée pour la rouvrir au prochain lancement.
    func panelVisibilityChanged(_ tracker: RoadmapTracker, _ visible: Bool) {
        guard followed.paths.contains(tracker.path), followed.visible.contains(tracker.path) != visible else { return }
        followed.setVisible(tracker.path, visible)
        save()
    }

    /// Le sélecteur de fichiers, limité aux specs Markdown.
    private func pickSpecs(title: String, prompt: String, multiple: Bool) -> [URL] {
        let openPanel = NSOpenPanel()
        openPanel.title = title
        openPanel.message = "La spec dont la feuille de route liste les phases (« - [ ] Phase 1 : … »)."
        openPanel.prompt = prompt
        openPanel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText, .plainText]
        openPanel.allowsMultipleSelection = multiple
        NSApp.activate()
        return openPanel.runModal() == .OK ? openPanel.urls : []
    }

    /// Se cale sur l'état réel de l'ouverture à la connexion, qui a pu changer dans Réglages Système.
    func refreshLaunchAtLogin() {
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if launchAtLogin { launchAtLoginNote = nil }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        // L'état a pu changer dans Réglages Système depuis la dernière lecture : on se cale dessus sans rien appeler.
        if (SMAppService.mainApp.status == .enabled) == enabled {
            launchAtLogin = enabled
            launchAtLoginNote = nil
            return
        }
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchAtLoginNote = SMAppService.mainApp.status == .requiresApproval
                ? "À autoriser dans Réglages Système › Général › Ouverture" : nil
        } catch {
            launchAtLoginNote = "Ouverture à la connexion impossible : \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}
