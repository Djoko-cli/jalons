import Foundation

/// Le chemin réel d'un fichier ou d'un dossier, tel que FSEvents le rapporte (`/tmp/x` → `/private/tmp/x`).
/// `URL.resolvingSymlinksInPath()` retire au contraire `/private`, d'où des événements jamais reconnus.
/// Pour un chemin qui n'existe pas encore, le parent est résolu et le dernier composant gardé.
public func canonicalPath(_ url: URL) -> String {
    if let resolved = realpath(url.path, nil) {
        defer { free(resolved) }
        return String(cString: resolved)
    }
    let parent = url.deletingLastPathComponent()
    guard parent.path != url.path else { return url.path }
    return (canonicalPath(parent) as NSString).appendingPathComponent(url.lastPathComponent)
}
