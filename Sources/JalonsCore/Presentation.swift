import Foundation
import OrchestreCore

/// Les textes composés de l'interface (frise, menu, icône), en fonctions pures pour être testés. Règle : une lecture
/// incomplète se dit toujours en clair, avant tout autre état ; elle ne passe jamais pour un « plan à écrire » ou un 0 %.
public enum Presentation {
    /// Le sous-titre d'une phase dans la frise, et s'il signale un problème.
    public static func phaseSubtitle(_ phase: Phase, in roadmap: Roadmap) -> (text: String, isWarning: Bool) {
        if phase.isChecked { return ("Terminée", false) }
        if !phase.unreadablePlans.isEmpty { return ("Plan illisible", true) }
        if roadmap.plansDirectoryUnreadable { return ("Plans illisibles", true) }
        if phase.hasPlan && phase.steps.total == 0 { return ("Plan sans case", true) }
        if phase.awaitsSignOff { return ("À valider", false) }
        if !phase.hasPlan { return ("Plan à écrire", false) }
        return (Wording.percent(phase.progress), false)
    }

    /// La ligne du menu sous la phase en cours ; dans le même ordre que le sous-titre de la frise.
    public static func currentPhaseDetail(_ phase: Phase, in roadmap: Roadmap) -> String? {
        if !phase.unreadablePlans.isEmpty {
            return list("Plan illisible", "Plans illisibles", phase.unreadablePlans.map(\.lastPathComponent))
        }
        if roadmap.plansDirectoryUnreadable { return "Dossier des plans illisible" }
        if phase.hasPlan && phase.steps.total == 0 { return "Plan sans case à cocher : avancement non mesurable" }
        if phase.awaitsSignOff { return "Toutes les étapes sont cochées : phase à valider" }
        if let next = phase.nextTask { return "Prochaine tâche : \(taskLabel(next, in: phase))" }
        if !phase.hasPlan { return "Plan à écrire" }
        return nil
    }

    /// La ligne du menu sous la prochaine tâche : sa première case non cochée. Rien quand la ligne du dessus signale un
    /// problème de lecture.
    public static func currentStepDetail(_ phase: Phase, in roadmap: Roadmap) -> String? {
        guard let step = highlightedTask(phase, in: roadmap)?.task.nextStep else { return nil }
        let label = Wording.stepLabel(step)
        let named = label.firstMatch(of: #/^(?i)(étape|step)\s*\d/#) != nil
        return truncated(named ? label : "Étape suivante : \(label)", to: 90)
    }

    /// La tâche dont la frise déplie d'office les étapes et met en avant la suivante, comme le menu : la prochaine tâche
    /// d'une phase non cochée et mesurable. Aucune pour une phase terminée ou un plan illisible.
    public static func highlightedTask(_ phase: Phase, in roadmap: Roadmap) -> PhaseTask? {
        guard !phase.isChecked, phase.isMeasurable(in: roadmap) else { return nil }
        return phase.nextTask
    }

    /// Coupe un texte trop long pour une ligne de menu, avec des points de suspension.
    static func truncated(_ text: String, to length: Int) -> String {
        text.count > length ? String(text.prefix(length - 1)).trimmingCharacters(in: .whitespaces) + "…" : text
    }

    /// L'avancement d'une phase en texte, pour l'icône et le menu : « 37 % », ou « ? » quand il n'est pas mesurable
    /// (plan ou dossier illisible, plan sans case). Jamais un 0 % trompeur.
    public static func phasePercent(_ phase: Phase, in roadmap: Roadmap) -> String {
        phase.isMeasurable(in: roadmap) ? Wording.percent(phase.progress) : "?"
    }

    /// « Tâche 2 : … », précédé du titre du plan quand la phase en a plusieurs (les numéros s'y répètent).
    public static func taskLabel(_ item: PhaseTask, in phase: Phase) -> String {
        let label = Wording.taskLabel(item.task)
        return phase.plans.count > 1 ? "\(item.planTitle) · \(label)" : label
    }

    /// Les avertissements de lecture, dans l'ordre où les montrer.
    public static func warnings(_ roadmap: Roadmap) -> [String] {
        var lines: [String] = []
        if roadmap.plansDirectoryUnreadable { lines.append("Dossier des plans illisible") }
        let unreadable = roadmap.phases.flatMap(\.unreadablePlans).map(\.lastPathComponent)
        if !unreadable.isEmpty { lines.append(list("Plan illisible", "Plans illisibles", unreadable)) }
        if !roadmap.unattachedPlans.isEmpty {
            lines.append(list("Plan rattaché à aucune phase", "Plans rattachés à aucune phase",
                              roadmap.unattachedPlans.map(\.lastPathComponent)))
        }
        let withoutSteps = roadmap.phases.filter { !$0.isChecked }.flatMap(\.plansWithoutSteps).map(\.lastPathComponent)
        if !withoutSteps.isEmpty {
            lines.append(list("Plan sans case à cocher", "Plans sans case à cocher", withoutSteps))
        }
        if let line = roadmap.unclosedCommentLine {
            lines.append("Commentaire HTML jamais refermé dans la spec, ligne \(line) : la suite n'a pas été lue")
        }
        if !roadmap.ignoredBoxLines.isEmpty {
            let numbers = roadmap.ignoredBoxLines.map(String.init)
            lines.append(numbers.count == 1 ? "Case « Phase » ignorée dans la spec, ligne \(numbers[0])"
                         : "Cases « Phase » ignorées dans la spec, lignes \(numbers.joined(separator: ", "))")
        }
        return lines
    }

    /// Le libellé d'accessibilité de l'icône de la barre des menus.
    public static func accessibilityLabel(_ state: RoadmapState) -> String {
        switch state {
        case .loaded(let roadmap):
            let warning = roadmap.hasWarnings ? " ; lecture incomplète : l'avancement peut être faux" : ""
            guard let phase = roadmap.currentPhase else { return "Jalons : toutes les phases sont terminées" + warning }
            let value = phase.isMeasurable(in: roadmap) ? Wording.percent(phase.progress) : "avancement inconnu"
            return "Jalons : \(Wording.phaseLabel(phase)), \(value) ; "
                + "avancement global \(Wording.percent(roadmap.progress))" + warning
        case .failed(let failure):
            return "Jalons : \(Wording.failure(failure))"
        }
    }

    /// « Plan illisible : a.md », « Plans illisibles : a.md, b.md, c.md et 2 autres ».
    static func list(_ singular: String, _ plural: String, _ names: [String]) -> String {
        guard names.count > 1 else { return "\(singular) : \(names.first ?? "")" }
        let shown = names.prefix(3).joined(separator: ", ")
        return names.count > 3 ? "\(plural) : \(shown) et \(names.count - 3) autres" : "\(plural) : \(shown)"
    }
}
