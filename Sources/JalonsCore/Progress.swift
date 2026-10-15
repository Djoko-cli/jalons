import Foundation
import OrchestreCore

public enum TaskStatus: Sendable, Equatable {
    case done, inProgress, todo
}

public enum PhaseStatus: Sendable, Equatable {
    case done, current, upcoming
}

extension ParsedTask {
    /// Faite quand toutes ses cases sont cochées ; en cours dès la première.
    public var status: TaskStatus {
        if total > 0 && checked == total { return .done }
        return checked > 0 ? .inProgress : .todo
    }

    /// La première case non cochée de la tâche.
    public var nextStep: ParsedStep? { steps.first { !$0.isChecked } }
}

/// Une tâche d'une phase, avec le plan qui la contient (pour l'ouvrir) et son titre (quand la phase a plusieurs plans).
public struct PhaseTask: Sendable, Equatable, Identifiable {
    public var plan: URL
    public var planTitle: String
    public var task: ParsedTask

    public var id: String { "\(plan.path)#\(task.line)" }
    /// La même tâche d'une lecture à l'autre, même quand des lignes s'insèrent au-dessus d'elle dans le plan.
    public var key: String { "\(plan.path)#tâche-\(task.number)" }
}

extension Phase {
    /// Cases cochées et cases en tout, dans tous les plans de la phase (tâches et cases isolées).
    public var steps: (checked: Int, total: Int) {
        var checked = 0
        var total = 0
        for plan in plans {
            checked += plan.looseChecked
            total += plan.looseTotal
            for task in plan.tasks {
                checked += task.checked
                total += task.total
            }
        }
        return (checked, total)
    }

    /// 1 si la phase est cochée dans la feuille de route ; sinon la part des cases cochées de ses plans (0 sans plan).
    public var progress: Double {
        if isChecked { return 1 }
        let steps = steps
        return steps.total > 0 ? Double(steps.checked) / Double(steps.total) : 0
    }

    public var hasPlan: Bool { !plans.isEmpty }

    public var tasks: [PhaseTask] {
        plans.flatMap { plan in
            plan.tasks.map { PhaseTask(plan: plan.url, planTitle: plan.title ?? plan.url.deletingPathExtension().lastPathComponent,
                                       task: $0) }
        }
    }

    /// La première tâche qui a des cases et ne les a pas toutes cochées (une tâche sans case n'est jamais « la suivante »).
    public var nextTask: PhaseTask? { tasks.first { $0.task.total > 0 && $0.task.status != .done } }

    /// Plans lus mais sans aucune case : l'avancement ne s'y mesure pas.
    public var plansWithoutSteps: [URL] {
        plans.filter { plan in plan.looseTotal + plan.tasks.reduce(0) { $0 + $1.total } == 0 }.map(\.url)
    }

    /// Faux si un plan de la phase (ou le dossier des plans) est illisible, ou si ses plans n'ont aucune case :
    /// son pourcentage ne veut alors rien dire. Une phase cochée reste mesurable (100 %).
    public func isMeasurable(in roadmap: Roadmap) -> Bool {
        if isChecked { return true }
        if !unreadablePlans.isEmpty || roadmap.plansDirectoryUnreadable { return false }
        return !(hasPlan && steps.total == 0)
    }

    /// Toutes les cases des plans sont cochées, mais la phase ne l'est pas encore dans la feuille de route.
    public var awaitsSignOff: Bool {
        let steps = steps
        return !isChecked && steps.total > 0 && steps.checked == steps.total
    }
}

extension Roadmap {
    /// La moyenne des phases : chaque phase pèse pareil.
    public var progress: Double {
        phases.isEmpty ? 0 : phases.reduce(0) { $0 + $1.progress } / Double(phases.count)
    }

    /// La première phase non cochée, dans l'ordre de la feuille de route.
    public var currentPhase: Phase? { phases.first { !$0.isChecked } }

    public var isFinished: Bool { !phases.isEmpty && currentPhase == nil }

    public var doneCount: Int { phases.filter(\.isChecked).count }

    public func status(of phase: Phase) -> PhaseStatus {
        if phase.isChecked { return .done }
        return phase.number == currentPhase?.number ? .current : .upcoming
    }

    /// Un dossier ou un plan n'a pas pu être lu : à signaler, l'avancement montré peut être faux.
    public var hasReadProblems: Bool {
        plansDirectoryUnreadable || phases.contains { !$0.unreadablePlans.isEmpty }
    }

    /// Une lecture incomplète : erreur de lecture, plan non rattaché ou sans case, case « Phase » ignorée, commentaire
    /// jamais refermé.
    public var hasWarnings: Bool {
        hasReadProblems || !unattachedPlans.isEmpty || !ignoredBoxLines.isEmpty || unclosedCommentLine != nil
            || phases.contains { !$0.isChecked && !$0.plansWithoutSteps.isEmpty }
    }
}
