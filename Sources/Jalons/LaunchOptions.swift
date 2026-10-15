import Foundation

/// Arguments de lancement utiles à la mise au point ; sans argument, l'app se comporte normalement.
struct LaunchOptions: Sendable {
    /// `-specPath <chemin>` : suit cette seule spec et affiche sa frise, sans toucher à la liste suivie.
    var specPath: String?
    /// `-settingsSuite <nom>` : lit et écrit les réglages dans cette suite de `UserDefaults`.
    var settingsSuite: String?
    /// `-snapshotDir <dossier>` : écrit des images PNG de la frise et de l'icône de la barre des menus.
    var snapshotDirectory: String?
    /// `-quitAfterSnapshot` : quitte après avoir écrit les images.
    var quitAfterSnapshot = false
    /// `-appearance light|dark` : force l'apparence (images de mise au point en clair et en sombre).
    var appearance: String?
    /// `-noWatch` : aucune surveillance du disque.
    var noWatch = false

    static let current = LaunchOptions(arguments: CommandLine.arguments)

    init(arguments: [String]) {
        func value(after flag: String) -> String? {
            guard let index = arguments.firstIndex(of: flag), index + 1 < arguments.count else { return nil }
            return arguments[index + 1]
        }
        specPath = value(after: "-specPath")
        settingsSuite = value(after: "-settingsSuite")
        snapshotDirectory = value(after: "-snapshotDir")
        quitAfterSnapshot = arguments.contains("-quitAfterSnapshot")
        appearance = value(after: "-appearance")
        noWatch = arguments.contains("-noWatch")
    }
}
