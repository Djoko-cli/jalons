import CoreServices
import Foundation

/// Une surveillance FSEvents (événements sur les fichiers), sur le modèle de celle d'Orchestre : le gestionnaire est
/// appelé, sur une file dédiée, dès qu'un chemin retenu change ou que des événements ont été perdus.
///
/// Le flux retient le surveillant (`retain`/`release` du contexte) : un rappel en vol ne peut pas le voir disparaître.
/// En contrepartie, `stop()` est obligatoire avant de le lâcher ; il n'y a pas de `deinit`, puisqu'un surveillant
/// démarré ne peut pas être libéré tant que son flux vit (relecture du prototype : plantage reproduit avec un
/// contexte non retenu et un `stop()` dans `deinit`).
final class FileWatcher: @unchecked Sendable {
    private let paths: [String]
    private let queue = DispatchQueue(label: "io.github.djoko-cli.jalons.fsevents")
    private let accepts: @Sendable (String) -> Bool
    private let handler: @Sendable () -> Void
    private var stream: FSEventStreamRef?

    init(paths: [String], accepts: @escaping @Sendable (String) -> Bool, handler: @escaping @Sendable () -> Void) {
        self.paths = paths
        self.accepts = accepts
        self.handler = handler
    }

    /// Faux si le flux n'a pas pu être créé ou démarré : l'appelant doit alors prévoir une autre relecture.
    @discardableResult
    func start() -> Bool {
        guard stream == nil else { return true }
        guard !paths.isEmpty else { return false }
        var context = FSEventStreamContext(
            version: 0, info: Unmanaged.passUnretained(self).toOpaque(),
            retain: { info in
                guard let info else { return nil }
                _ = Unmanaged<FileWatcher>.fromOpaque(info).retain()
                return info
            },
            release: { info in
                guard let info else { return }
                Unmanaged<FileWatcher>.fromOpaque(info).release()
            },
            copyDescription: nil)
        let callback: FSEventStreamCallback = { _, info, count, eventPaths, eventFlags, _ in
            guard let info else { return }
            let watcher = Unmanaged<FileWatcher>.fromOpaque(info).takeUnretainedValue()
            let array = unsafeBitCast(eventPaths, to: CFArray.self) as? [String] ?? []
            let lost = UInt32(kFSEventStreamEventFlagMustScanSubDirs) | UInt32(kFSEventStreamEventFlagUserDropped)
                | UInt32(kFSEventStreamEventFlagKernelDropped)
            var relevant = false
            for (index, path) in array.prefix(count).enumerated() where watcher.accepts(path) || eventFlags[index] & lost != 0 {
                relevant = true
                break
            }
            if relevant { watcher.handler() }
        }
        let flags = FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes
                                             | kFSEventStreamCreateFlagNoDefer)
        guard let created = FSEventStreamCreate(kCFAllocatorDefault, callback, &context, paths as CFArray,
                                                FSEventStreamEventId(kFSEventStreamEventIdSinceNow), 0.2, flags) else {
            return false
        }
        FSEventStreamSetDispatchQueue(created, queue)
        guard FSEventStreamStart(created) else {
            FSEventStreamInvalidate(created)
            FSEventStreamRelease(created)
            return false
        }
        stream = created
        return true
    }

    /// Arrête le flux et rend le surveillant libérable (le flux relâche sa retenue).
    func stop() {
        guard let stream else { return }
        FSEventStreamStop(stream)
        FSEventStreamInvalidate(stream)
        FSEventStreamRelease(stream)
        self.stream = nil
    }
}

/// Le chemin réel d'un fichier ou d'un dossier, tel que FSEvents le rapporte (`/tmp/x` → `/private/tmp/x`).
/// `URL.resolvingSymlinksInPath()` retire au contraire `/private`, d'où des événements jamais reconnus.
/// Pour un chemin qui n'existe pas encore, le parent est résolu et le dernier composant gardé.
func canonicalPath(_ url: URL) -> String {
    if let resolved = realpath(url.path, nil) {
        defer { free(resolved) }
        return String(cString: resolved)
    }
    let parent = url.deletingLastPathComponent()
    guard parent.path != url.path else { return url.path }
    return (canonicalPath(parent) as NSString).appendingPathComponent(url.lastPathComponent)
}
