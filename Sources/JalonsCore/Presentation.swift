import Foundation

/// Les textes composés de l'interface (frise, menu, icône), en fonctions pures pour être testés. Règle : une lecture
/// incomplète se dit toujours en clair, avant tout autre état ; elle ne passe jamais pour un « plan à écrire » ou un 0 %.
public enum Presentation {
    /// Le sous-titre d'une phase dans la frise, et s'il signale un problème.
    public static func phaseSubtitle(_ phase: Phase, in roadmap: Roadmap) -> (text: String, isWarning: Bool) {
        if phase.isChecked { return ("Terminée", false) }
        if !phase.unreadablePlans.isEmpty { return ("Plan illisible", true) }
        if roadmap.plansDirectoryUnreadable { return ("Plans illisibles", true) }
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
        if phase.awaitsSignOff { return "Toutes les étapes sont cochées : phase à valider" }
        if let next = phase.nextTask { return "Prochaine tâche : \(taskLabel(next, in: phase))" }
        if !phase.hasPlan { return "Plan à écrire" }
        return nil
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
            return "Jalons : \(Wording.phaseLabel(phase)), \(Wording.percent(phase.progress)) ; "
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
