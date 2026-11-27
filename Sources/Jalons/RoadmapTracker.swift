import AppKit
import JalonsCore
import Observation

/// Une feuille de route suivie : sa lecture, la surveillance de sa spec et de ses plans, et sa frise flottante.
@MainActor @Observable
final class RoadmapTracker: Identifiable {
    /// Le chemin de la spec, tel qu'il est enregistré dans la liste suivie.
    let path: String
    private(set) var state: RoadmapState = .failed(.noSpecChosen)
    private(set) var isPanelVisible = false
    /// La surveillance des fichiers n'a pas pu démarrer : relecture de secours chaque minute, et avertissement affiché.
    private(set) var watchUnavailable = false

    @ObservationIgnored private(set) weak var model: AppModel?
    @ObservationIgnored private let options: LaunchOptions
    @ObservationIgnored private var watcher: FileWatcher?
    @ObservationIgnored private var reloadPending = false
    @ObservationIgnored private var fallbackReload: Task<Void, Never>?
    /// Ce que la surveillance regarde ; refaite quand une copie de travail du dépôt apparaît ou disparaît.
    @ObservationIgnored private var watchedScope: WatchScope?
    /// Arrêté : un événement encore en vol ne relit plus rien.
    @ObservationIgnored private var isStopped = false
    @ObservationIgnored private var panel: FloatingPanelController!

    nonisolated var id: String { path }
    var specURL: URL { URL(fileURLWithPath: path) }
    var menuTitle: String { Presentation.roadmapMenuTitle(state, specName: specURL.lastPathComponent) }
    var panelWindow: NSPanel? { panel.window }
    /// La place de la frise, même masquée (voir `FloatingPanelController.knownFrame`).
    var knownPanelFrame: NSRect? { panel.knownFrame }
    /// Le nom sous lequel la taille et la place de la frise sont retenues.
    var frameName: String { Self.frameName(for: path) }

    static func frameName(for path: String) -> String { "JalonsFrise \(path)" }

    /// `fallbackFrameNames` : des places retenues sous d'autres noms, reprises si la spec n'a pas encore la sienne
    /// (celle d'avant les frises multiples, ou celle de la spec remplacée). `remembersFrame` : faux en mise au point.
    init(path: String, model: AppModel, options: LaunchOptions, fallbackFrameNames: [String], remembersFrame: Bool) {
        self.path = path
        self.model = model
        self.options = options
        panel = FloatingPanelController(tracker: self, frameName: Self.frameName(for: path),
                                        fallbackFrameNames: fallbackFrameNames, remembersFrame: remembersFrame)
    }

    func start() {
        reload()
        startWatching()
    }

    /// Arrête la surveillance et ferme la frise, sans toucher à la liste suivie.
    func stop() {
        isStopped = true
        watcher?.stop()
        watcher = nil
        fallbackReload?.cancel()
        fallbackReload = nil
        panel.close()
    }

    /// Relit la feuille de route, depuis le chemin réel de la spec : le chargeur et la surveillance dérivent ainsi le
    /// dossier des plans du même chemin, même si un dossier intermédiaire est un lien symbolique.
    func reload() {
        guard !isStopped else { return }
        state = RoadmapLoader.load(specURL: URL(fileURLWithPath: canonicalPath(specURL)))
        model?.refreshLaunchAtLogin()
        // Une copie apparue ou disparue : surveiller ses plans, puis relire ce qui a pu changer entre-temps.
        if watchedScope != nil, currentScope() != watchedScope {
            startWatching()
            scheduleReload()
        }
    }

    private func currentScope() -> WatchScope {
        let spec = URL(fileURLWithPath: canonicalPath(specURL))
        return WatchScope(specURL: spec, sources: PlanLocator.sources(forSpec: spec))
    }

    /// Les événements arrivent par rafales : la première programme une relecture, les suivantes s'y joignent.
    func scheduleReload() {
        guard !reloadPending, !isStopped else { return }
        reloadPending = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self else { return }
            reloadPending = false
            reload()
        }
    }

    func togglePanel() {
        isPanelVisible ? hidePanel() : showPanel()
    }

    func showPanel() { panel.show() }

    func hidePanel() { panel.hide() }

    /// Appelée par la frise quand elle s'ouvre ou se ferme ; la liste suivie la mémorise.
    func panelVisibilityChanged(_ visible: Bool) {
        isPanelVisible = visible
        model?.panelVisibilityChanged(self, visible)
    }

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// Surveille le dossier de la spec, celui des plans et ceux des autres copies de travail du dépôt (voir `WatchScope`).
    private func startWatching() {
        watcher?.stop()
        watcher = nil
        fallbackReload?.cancel()
        fallbackReload = nil
        watchUnavailable = false
        watchedScope = nil
        guard !options.noWatch, !isStopped else { return }
        let scope = currentScope()
        watchedScope = scope
        let watcher = FileWatcher(paths: scope.roots, accepts: { scope.accepts($0) }, handler: { [weak self] in
            Task { @MainActor in self?.scheduleReload() }
        })
        if watcher.start() {
            self.watcher = watcher
        } else {
            watchUnavailable = true
            fallbackReload = Task { @MainActor [weak self] in
                while true {
                    do { try await Task.sleep(for: .seconds(60)) } catch { return }
                    guard let self else { return }
                    reload()
                }
            }
        }
    }
}
