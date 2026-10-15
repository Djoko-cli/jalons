import AppKit
import JalonsCore
import SwiftUI

/// Le menu de l'icône : où en est la feuille de route, puis les commandes.
struct MenuContent: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        switch model.state {
        case .loaded(let roadmap):
            summary(roadmap)
        case .failed(let failure):
            Text(Wording.failure(failure))
        }
        if model.watchUnavailable {
            Text("Surveillance des fichiers indisponible : relecture chaque minute")
        }
        Divider()
        Button(model.isPanelVisible ? "Masquer la frise" : "Afficher la frise") { model.togglePanel() }
        Button("Choisir une feuille de route…") { model.chooseInteractively() }
        Toggle("Ouvrir à la connexion", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
        if let note = model.launchAtLoginNote { Text(note) }
        Divider()
        Button("Quitter Jalons") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    @ViewBuilder
    private func summary(_ roadmap: Roadmap) -> some View {
        Text(roadmap.title)
        Text("Avancement global : \(Wording.percent(roadmap.progress)) · "
             + Wording.phasesDone(roadmap.doneCount, of: roadmap.phases.count))
        Divider()
        if let phase = roadmap.currentPhase {
            Text("\(Wording.phaseLabel(phase)) · \(Presentation.phasePercent(phase, in: roadmap))")
            if let detail = Presentation.currentPhaseDetail(phase, in: roadmap) {
                Text(detail)
            }
            if let step = Presentation.currentStepDetail(phase, in: roadmap) {
                Text(step)
            }
        } else {
            Text("Toutes les phases sont terminées")
        }
        let warnings = Presentation.warnings(roadmap)
        if !warnings.isEmpty {
            Divider()
            Text("Lecture incomplète : l'avancement peut être faux")
            ForEach(warnings, id: \.self) { Text($0) }
        }
    }
}
