import AppKit
import JalonsCore
import SwiftUI

/// Le menu de l'icône : où en est la feuille de route principale, la liste des feuilles de route suivies (chacune avec
/// ses commandes), puis les commandes générales.
struct MenuContent: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if let primary = model.primary {
            switch primary.state {
            case .loaded(let roadmap):
                summary(roadmap)
            case .failed(let failure):
                Text(Wording.failure(failure))
            }
        } else {
            Text(Wording.failure(.noSpecChosen))
        }
        ForEach(model.trackers.filter(\.watchUnavailable)) { tracker in
            Text("Surveillance indisponible pour \(tracker.specURL.lastPathComponent) : relecture chaque minute")
        }
        Divider()
        if !model.trackers.isEmpty {
            Section("Feuilles de route suivies") {
                ForEach(model.trackers) { tracker in
                    roadmapMenu(tracker)
                }
            }
            Divider()
        }
        Button("Ajouter une feuille de route…") { model.addInteractively() }
        if model.trackers.count > 1 {
            if model.trackers.contains(where: { !$0.isPanelVisible }) {
                Button("Afficher toutes les frises") { model.showAllPanels() }
            }
            if model.anyPanelVisible {
                Button("Masquer toutes les frises") { model.hideAllPanels() }
            }
        }
        Toggle("Ouvrir à la connexion", isOn: Binding(get: { model.launchAtLogin }, set: { model.setLaunchAtLogin($0) }))
        if let note = model.launchAtLoginNote { Text(note) }
        Divider()
        Button("Quitter Jalons") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

    /// Une feuille de route suivie : « ★ » pour la principale, et ses commandes dans un sous-menu.
    private func roadmapMenu(_ tracker: RoadmapTracker) -> some View {
        let isPrimary = tracker === model.primary
        return Menu((isPrimary ? "★ " : "") + tracker.menuTitle) {
            Button(tracker.isPanelVisible ? "Masquer la frise" : "Afficher la frise") { tracker.togglePanel() }
            if !isPrimary {
                Button("Définir comme principale") { model.setPrimary(tracker) }
            }
            Button("Ouvrir la spec") { tracker.open(tracker.specURL) }
            Divider()
            Button("Ne plus suivre") { model.remove(tracker) }
        }
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
