import AppKit
import JalonsCore
import SwiftUI

@main
struct JalonsApp: App {
    @State private var model: AppModel

    init() {
        let model = AppModel(options: LaunchOptions.current)
        model.start()
        _model = State(initialValue: model)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent().environment(model)
        } label: {
            MenuBarLabel().environment(model)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// L'icône de la barre des menus : l'anneau de l'avancement global et « Phase 2 · 37 % ».
struct MenuBarLabel: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        Image(nsImage: MenuBarIcon.image(for: model.primaryState))
            .accessibilityLabel(Presentation.accessibilityLabel(model.primaryState))
    }
}
