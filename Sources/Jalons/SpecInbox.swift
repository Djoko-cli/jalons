import AppKit

/// Les fichiers que le système ouvre dans Jalons (`open -a Jalons`, « Ouvrir avec »). Ils peuvent arriver avant que
/// l'app soit prête (Jalons lancée par `open -a`) : ils attendent le receveur, puis lui arrivent une seule fois.
@MainActor
final class SpecInbox {
    static let shared = SpecInbox()

    var receiver: (([URL]) -> Void)? {
        didSet { deliver() }
    }

    private var waiting: [URL] = []

    /// Branche la boîte sur le modèle : chaque lot reçu suit le chemin de `AppModel.receive`.
    func connect(to model: AppModel) {
        receiver = { model.receive($0) }
    }

    func receive(_ urls: [URL]) {
        waiting += urls
        deliver()
    }

    private func deliver() {
        guard let receiver, !waiting.isEmpty else { return }
        let urls = waiting
        waiting = []
        receiver(urls)
    }
}

/// Le délégué de l'app : passe à la boîte de réception les fichiers que le système ouvre dans Jalons.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        SpecInbox.shared.receive(urls)
    }
}
