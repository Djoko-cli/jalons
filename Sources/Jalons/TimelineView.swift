import AppKit
import JalonsCore
import SwiftUI

/// La frise verticale : l'en-tête (titre et avancement global), une ligne par phase reliée aux autres par un rail,
/// les tâches de la phase en cours dépliées (et les étapes de sa prochaine tâche), et l'heure de la dernière lecture.
struct TimelineView: View {
    @Environment(RoadmapTracker.self) private var tracker

    var body: some View {
        ZStack {
            TimelineBackground()
            switch tracker.state {
            case .loaded(let roadmap):
                RoadmapTimeline(roadmap: roadmap)
                    .id(roadmap.specURL)
            case .failed(let failure):
                FailureView(failure: failure)
            }
        }
        .frame(minWidth: 280, idealWidth: 360, minHeight: 240, idealHeight: 660)
    }
}

private struct RoadmapTimeline: View {
    let roadmap: Roadmap
    /// Les phases dépliées ou repliées à la main ; sinon seule la phase en cours est dépliée.
    @State private var overrides: [Int: Bool] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Header(roadmap: roadmap)
                .padding(.horizontal, 16)
                .padding(.top, 30)
                .padding(.bottom, 12)
            Divider().opacity(0.5)
            ScrollView {
                GlassGroup {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(roadmap.phases.enumerated()), id: \.element.id) { index, phase in
                            row(phase, at: index)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                }
            }
            Divider().opacity(0.5)
            Footer(roadmap: roadmap)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
        }
    }

    private func row(_ phase: Phase, at index: Int) -> PhaseRow {
        PhaseRow(phase: phase, status: roadmap.status(of: phase),
                 subtitle: Presentation.phaseSubtitle(phase, in: roadmap),
                 isFirst: index == 0, isLast: index == roadmap.phases.count - 1,
                 upperDone: index > 0 && roadmap.phases[index - 1].isChecked,
                 highlighted: Presentation.highlightedTask(phase, in: roadmap),
                 isExpanded: isExpanded(phase)) {
            overrides[phase.number] = !isExpanded(phase)
        }
    }

    private func isExpanded(_ phase: Phase) -> Bool {
        overrides[phase.number] ?? (roadmap.status(of: phase) == .current)
    }
}

private struct Header: View {
    let roadmap: Roadmap

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(roadmap.title)
                .font(.headline)
                .lineLimit(2)
            HStack(spacing: 8) {
                ProgressBar(value: roadmap.progress, color: roadmap.isFinished ? .green : .accentColor)
                Text(Wording.percent(roadmap.progress))
                    .font(.callout.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Text(roadmap.isFinished ? "Toutes les phases sont terminées"
                 : Wording.phasesDone(roadmap.doneCount, of: roadmap.phases.count))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Une barre de progression dessinée : contrairement à `ProgressView`, elle garde sa couleur quand la fenêtre est
/// inactive, ce qui est le cas presque tout le temps pour une frise flottante.
private struct ProgressBar: View {
    let value: Double
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.secondary.opacity(0.2))
                Capsule()
                    .fill(color)
                    .frame(width: value > 0 ? max(geometry.size.width * min(value, 1), 6) : 0)
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel("Avancement global")
        .accessibilityValue(Wording.percent(value))
    }
}

private struct PhaseRow: View {
    let phase: Phase
    let status: PhaseStatus
    let subtitle: (text: String, isWarning: Bool)
    let isFirst: Bool
    let isLast: Bool
    let upperDone: Bool
    /// La tâche mise en avant (voir `Presentation.highlightedTask`).
    let highlighted: PhaseTask?
    let isExpanded: Bool
    let toggle: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Rail(status: status, progress: phase.progress, isFirst: isFirst, isLast: isLast,
                 upperDone: upperDone, lowerDone: phase.isChecked)
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    if canExpand { toggle() }
                } label: {
                    HStack(alignment: .center, spacing: 6) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("PHASE \(phase.number)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(phase.title.isEmpty ? "Phase \(phase.number)" : Wording.capitalizedFirst(phase.title))
                                .font(status == .current ? .body.weight(.semibold) : .body)
                                .foregroundStyle(status == .upcoming ? .secondary : .primary)
                        }
                        Spacer(minLength: 8)
                        Text(subtitle.text)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(subtitle.isWarning ? Color.orange : Color.secondary)
                        if canExpand {
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if isExpanded {
                    TaskList(phase: phase, highlighted: highlighted)
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .phaseSurface(isCurrent: status == .current)
            .padding(.bottom, isLast ? 0 : 6)
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private var canExpand: Bool { !phase.tasks.isEmpty || !phase.unreadablePlans.isEmpty }
}

/// Le rail : un segment vers la phase précédente, le nœud, un segment vers la suivante (vert entre phases finies).
private struct Rail: View {
    let status: PhaseStatus
    let progress: Double
    let isFirst: Bool
    let isLast: Bool
    let upperDone: Bool
    let lowerDone: Bool

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(isFirst ? Color.clear : lineColor(done: upperDone))
                .frame(width: 2, height: 12)
            Node(status: status, progress: progress)
                .frame(width: 22, height: 22)
                .accessibilityLabel(status == .done ? "terminée" : status == .current ? "en cours" : "à venir")
            Rectangle()
                .fill(isLast ? Color.clear : lineColor(done: lowerDone))
                .frame(width: 2)
                .frame(maxHeight: .infinity)
        }
        .frame(width: 22)
    }

    private func lineColor(done: Bool) -> Color {
        done ? Color.green.opacity(0.7) : Color.secondary.opacity(0.3)
    }
}

/// Le nœud d'une phase : coche pleine si finie, anneau de progression si en cours, cercle vide si à venir.
private struct Node: View {
    let status: PhaseStatus
    let progress: Double

    var body: some View {
        switch status {
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 19))
                .symbolRenderingMode(.palette)
                .foregroundStyle(.white, .green)
        case .current:
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.25), lineWidth: 3)
                Circle()
                    .trim(from: 0, to: max(progress, 0.001))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .padding(2)
        case .upcoming:
            Circle()
                .strokeBorder(Color.secondary.opacity(0.5), lineWidth: 1.5)
                .padding(3)
        }
    }
}

/// Les tâches d'une phase dépliée. Les étapes de la prochaine tâche sont dépliées d'office ; les autres se déplient à
/// la main, par leur chevron.
private struct TaskList: View {
    @Environment(RoadmapTracker.self) private var tracker
    let phase: Phase
    let highlighted: PhaseTask?
    /// Les tâches dépliées ou repliées à la main, par `PhaseTask.key`.
    @State private var overrides: [String: Bool] = [:]

    var body: some View {
        let tasks = phase.tasks
        // La première tâche de chaque plan, sous le titre du plan quand la phase en a plusieurs.
        let planStarts = Set(Dictionary(grouping: tasks, by: \.plan).values.compactMap { $0.first?.id })
        VStack(alignment: .leading, spacing: 5) {
            ForEach(tasks) { item in
                if phase.plans.count > 1, planStarts.contains(item.id) {
                    Text(item.planTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, item.id == tasks.first?.id ? 0 : 4)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Button {
                        tracker.open(item.plan)
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            TaskIcon(status: item.task.status, isAllDeferred: item.task.total == 0 && item.task.deferred > 0)
                            Text(Wording.taskLabel(item.task))
                                .font(.callout)
                                .lineLimit(2)
                                .foregroundStyle(item.task.status == .done ? .secondary : .primary)
                            Spacer(minLength: 6)
                            if item.task.total + item.task.deferred > 0 {
                                Text(Wording.taskCount(item.task))
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Ouvrir le plan")
                    if !item.task.steps.isEmpty {
                        Button {
                            overrides[item.key] = !isExpanded(item)
                        } label: {
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.tertiary)
                                .rotationEffect(.degrees(isExpanded(item) ? 90 : 0))
                                .frame(minWidth: 24, minHeight: 20)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .help(isExpanded(item) ? "Masquer les étapes" : "Afficher les étapes")
                        .accessibilityLabel("Étapes de \(Wording.taskLabel(item.task))")
                        .accessibilityValue(isExpanded(item) ? "dépliées" : "repliées")
                    }
                }
                if isExpanded(item) {
                    StepList(item: item, highlightsNext: item.id == highlighted?.id)
                        .padding(.leading, 22)
                }
            }
            ForEach(phase.unreadablePlans, id: \.self) { url in
                Label("Plan illisible : \(url.lastPathComponent)", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(.top, 2)
    }

    private func isExpanded(_ item: PhaseTask) -> Bool {
        guard !item.task.steps.isEmpty else { return false }
        return overrides[item.key] ?? (item.id == highlighted?.id)
    }
}

/// Les étapes d'une tâche : cochées, la suivante mise en avant (dans la prochaine tâche seulement), puis celles à
/// venir. Un clic ouvre le plan.
private struct StepList: View {
    @Environment(RoadmapTracker.self) private var tracker
    let item: PhaseTask
    let highlightsNext: Bool

    var body: some View {
        let next = highlightsNext ? item.task.nextStep?.line : nil
        VStack(alignment: .leading, spacing: 3) {
            ForEach(item.task.steps, id: \.line) { step in
                let isNext = step.line == next
                Button {
                    tracker.open(item.plan)
                } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        StepIcon(isChecked: step.isChecked, isDeferred: step.isDeferred, isNext: isNext)
                        Text(Wording.stepLabel(step))
                            .font(isNext ? .caption.weight(.semibold) : .caption)
                            .lineLimit(2)
                            .foregroundStyle(isNext ? .primary : .secondary)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Ouvrir le plan")
            }
        }
    }
}

private struct StepIcon: View {
    let isChecked: Bool
    let isDeferred: Bool
    let isNext: Bool

    var body: some View {
        Group {
            if isChecked {
                Image(systemName: "checkmark").foregroundStyle(.green).accessibilityLabel("faite")
            } else if isDeferred {
                Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary).accessibilityLabel("reportée")
            } else if isNext {
                Image(systemName: "arrowtriangle.right.fill").foregroundStyle(Color.accentColor)
                    .accessibilityLabel("étape suivante")
            } else {
                Image(systemName: "circle").foregroundStyle(.secondary).accessibilityLabel("à faire")
            }
        }
        .font(.caption2.weight(.semibold))
        .frame(width: 12)
    }
}

private struct TaskIcon: View {
    let status: TaskStatus
    /// Toutes ses cases sont reportées : rien n'a été fait, la tâche est seulement sortie du travail.
    var isAllDeferred = false

    var body: some View {
        switch status {
        case .done where isAllDeferred:
            Image(systemName: "arrow.turn.down.right.circle").foregroundStyle(.secondary).accessibilityLabel("reportée")
        case .done:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green).accessibilityLabel("faite")
        case .inProgress:
            Image(systemName: "circle.lefthalf.filled").foregroundStyle(Color.accentColor).accessibilityLabel("en cours")
        case .todo:
            Image(systemName: "circle").foregroundStyle(.secondary).accessibilityLabel("à faire")
        }
    }
}

private struct Footer: View {
    @Environment(RoadmapTracker.self) private var tracker
    let roadmap: Roadmap

    var body: some View {
        let warnings = Presentation.warnings(roadmap)
            + (tracker.watchUnavailable ? ["Surveillance des fichiers indisponible : relecture chaque minute"] : [])
        VStack(alignment: .leading, spacing: 4) {
            if !warnings.isEmpty {
                // L'orange ne vaut que pour les avertissements : `.secondary` se calcule à partir du style hérité.
                VStack(alignment: .leading, spacing: 2) {
                    Label("Lecture incomplète : l'avancement peut être faux", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                    ForEach(warnings, id: \.self) { warning in
                        Text(warning).font(.caption2)
                    }
                }
                .foregroundStyle(Color.orange)
            }
            HStack(spacing: 6) {
                Text(Wording.updated(roadmap.readAt))
                Spacer(minLength: 8)
                Text(roadmap.specURL.lastPathComponent)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

private struct FailureView: View {
    @Environment(RoadmapTracker.self) private var tracker
    let failure: RoadmapFailure

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: failure == .noSpecChosen ? "map" : "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(failure == .noSpecChosen ? Color.secondary : Color.orange)
            Text(Wording.failure(failure))
                .multilineTextAlignment(.center)
            HStack {
                // Différés : ces actions ferment la fenêtre qui porte ces boutons.
                Button("Ne plus suivre") { Task { @MainActor in tracker.model?.remove(tracker) } }
                Button("Choisir une autre spec…") { Task { @MainActor in tracker.model?.replaceInteractively(tracker) } }
            }
        }
        .padding(24)
    }
}
