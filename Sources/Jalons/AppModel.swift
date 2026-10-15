import AppKit
import JalonsCore
import Observation
import ServiceManagement
import UniformTypeIdentifiers

/// L'état de l'app : la feuille de route suivie, sa surveillance, la frise flottante et l'ouverture à la connexion.
@MainActor @Observable
final class AppModel {
    private(set) var state: RoadmapState = .failed(.noSpecChosen)
    private(set) var isPanelVisible = false
    private(set) var launchAtLogin = SMAppService.mainApp.status == .enabled
    private(set) var launchAtLoginNote: String?
    /// La surveillance des fichiers n'a pas pu démarrer : relecture de secours chaque minute, et avertissement affiché.
    private(set) var watchUnavailable = false

    let options: LaunchOptions
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var watcher: FileWatcher?
    @ObservationIgnored private var reloadPending = false
    @ObservationIgnored private var fallbackReload: Task<Void, Never>?
    @ObservationIgnored private lazy var panel = FloatingPanelController(model: self)

    static let specPathKey = "cheminFeuilleDeRoute"
    static let panelVisibleKey = "friseVisible"

    init(options: LaunchOptions) {
        self.options = options
        defaults = options.settingsSuite.flatMap { UserDefaults(suiteName: $0) } ?? .standard
    }

    /// La spec suivie : celle de `-specPath` en mise au point, sinon celle choisie dans le menu.
    var specURL: URL? {
        if let path = options.specPath { return URL(fileURLWithPath: path) }
        return defaults.string(forKey: Self.specPathKey).map { URL(fileURLWithPath: $0) }
    }

    var panelWindow: NSPanel? { panel.window }

    func start() {
        reload()
        startWatching()
        if options.snapshotDirectory != nil || defaults.bool(forKey: Self.panelVisibleKey) { showPanel() }
        if let directory = options.snapshotDirectory {
            Task { await DebugCapture.run(model: self, directory: directory) }
        }
    }

    /// Relit la feuille de route, depuis le chemin réel de la spec : le chargeur et la surveillance dérivent ainsi le
    /// dossier des plans du même chemin, même si un dossier intermédiaire est un lien symbolique.
    func reload() {
        state = RoadmapLoader.load(specURL: specURL.map { URL(fileURLWithPath: canonicalPath($0)) })
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if launchAtLogin { launchAtLoginNote = nil }
    }

    /// Les événements arrivent par rafales : la première programme une relecture, les suivantes s'y joignent.
    func scheduleReload() {
        guard !reloadPending else { return }
        reloadPending = true
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self else { return }
            reloadPending = false
            reload()
        }
    }

    func choose(_ url: URL) {
        defaults.set(url.path, forKey: Self.specPathKey)
        reload()
        startWatching()
    }

    func chooseInteractively() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Choisir une feuille de route"
        openPanel.message = "La spec dont la feuille de route liste les phases (« - [ ] Phase 1 : … »)."
        openPanel.prompt = "Suivre"
        openPanel.allowedContentTypes = [UTType(filenameExtension: "md") ?? .plainText, .plainText]
        openPanel.allowsMultipleSelection = false
        NSApp.activate()
        if openPanel.runModal() == .OK, let url = openPanel.url { choose(url) }
    }

    func togglePanel() {
        isPanelVisible ? hidePanel() : showPanel()
    }

    func showPanel() { panel.show() }

    func hidePanel() { panel.hide() }

    /// Appelée par la frise quand elle s'ouvre ou se ferme ; mémorisée pour la rouvrir au prochain lancement.
    func panelVisibilityChanged(_ visible: Bool) {
        isPanelVisible = visible
        if options.snapshotDirectory == nil { defaults.set(visible, forKey: Self.panelVisibleKey) }
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

    func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }

    /// Surveille le dossier de la spec et celui des plans (y compris s'il n'existe pas encore : on surveille leur parent).
    /// Les chemins comparés sont les chemins réels, tels que FSEvents les rapporte.
    private func startWatching() {
        watcher?.stop()
        watcher = nil
        fallbackReload?.cancel()
        fallbackReload = nil
        watchUnavailable = false
        guard !options.noWatch, let spec = specURL else { return }
        let specDirectory = canonicalPath(spec.deletingLastPathComponent())
        let root = (specDirectory as NSString).deletingLastPathComponent
        let plansDirectory = (root as NSString).appendingPathComponent("plans")
        let watcher = FileWatcher(paths: [root], accepts: { path in
            path == specDirectory || path.hasPrefix(specDirectory + "/")
                || path == plansDirectory || path.hasPrefix(plansDirectory + "/")
        }, handler: { [weak self] in
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
