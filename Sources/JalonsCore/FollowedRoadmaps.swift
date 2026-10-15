import Foundation

/// Les feuilles de route suivies, par chemin de spec : leur ordre (celui des ajouts), la principale (celle de l'icône
/// de la barre des menus) et celles dont la frise est affichée. Une liste abîmée se répare à la lecture.
public struct FollowedRoadmaps: Sendable, Equatable, Codable {
    public private(set) var paths: [String] = []
    public private(set) var primary: String?
    public private(set) var visible: Set<String> = []

    public init() {}

    /// Reprend le réglage d'avant les frises multiples : une seule spec, sa frise affichée ou non.
    public init(legacyPath: String?, legacyVisible: Bool) {
        guard let legacyPath else { return }
        add(legacyPath)
        setVisible(legacyPath, legacyVisible)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let paths = try container.decodeIfPresent([String].self, forKey: .paths) ?? []
        for path in paths { add(path) }
        visible = (try container.decodeIfPresent(Set<String>.self, forKey: .visible) ?? []).intersection(self.paths)
        if let primary = try container.decodeIfPresent(String.self, forKey: .primary) { setPrimary(primary) }
    }

    /// Ajoute une spec et affiche sa frise ; la première ajoutée devient la principale. Faux si elle était déjà suivie.
    @discardableResult
    public mutating func add(_ path: String) -> Bool {
        guard !paths.contains(path) else { return false }
        paths.append(path)
        visible.insert(path)
        if primary == nil { primary = path }
        return true
    }

    /// Ne suit plus cette spec ; si c'était la principale, la première qui reste prend sa place.
    public mutating func remove(_ path: String) {
        paths.removeAll { $0 == path }
        visible.remove(path)
        if primary == path { primary = paths.first }
    }

    /// Celle que l'icône de la barre des menus montre ; un chemin non suivi est ignoré.
    public mutating func setPrimary(_ path: String) {
        if paths.contains(path) { primary = path }
    }

    /// Retient si la frise de cette spec est affichée ; un chemin non suivi est ignoré.
    public mutating func setVisible(_ path: String, _ isVisible: Bool) {
        guard paths.contains(path) else { return }
        if isVisible { visible.insert(path) } else { visible.remove(path) }
    }

    /// Suit une autre spec à la place de celle-ci, au même rang, avec le même rôle et la même visibilité. Si la nouvelle
    /// est déjà suivie, l'ancienne est simplement retirée.
    public mutating func replace(_ old: String, with new: String) {
        guard let index = paths.firstIndex(of: old), old != new else { return }
        guard !paths.contains(new) else {
            if primary == old { primary = new }
            remove(old)
            return
        }
        paths[index] = new
        if primary == old { primary = new }
        if visible.remove(old) != nil { visible.insert(new) }
    }
}
