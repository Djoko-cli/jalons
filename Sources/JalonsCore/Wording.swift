import Foundation
import OrchestreCore

/// Les textes affichés, en français.
public enum Wording {
    /// « 37 % » (espace fine insécable). Arrondi au plus proche, mais jamais 100 % avant la fin ni 0 % après un début.
    public static func percent(_ value: Double) -> String {
        let clamped = min(max(value, 0), 1)
        var number = Int((clamped * 100).rounded())
        if clamped < 1 && number == 100 { number = 99 }
        if clamped > 0 && number == 0 { number = 1 }
        return "\(number)\u{202F}%"
    }

    /// « socle » → « Socle ».
    public static func capitalizedFirst(_ text: String) -> String {
        guard let first = text.first else { return text }
        return first.uppercased() + text.dropFirst()
    }

    /// « Phase 1 : Socle », ou « Phase 1 » sans titre.
    public static func phaseLabel(_ phase: Phase) -> String {
        phase.title.isEmpty ? "Phase \(phase.number)" : "Phase \(phase.number) : \(capitalizedFirst(phase.title))"
    }

    /// « Tâche 3 : Brancher Hue ».
    public static func taskLabel(_ task: ParsedTask) -> String {
        task.title.isEmpty ? "Tâche \(task.number)" : "Tâche \(task.number) : \(task.title)"
    }

    /// Le texte d'une case sans ses marques Markdown de gras, de code et de lien : « **Étape 2 :** lancer `swift test` »
    /// → « Étape 2 : lancer swift test » ; « [la spec](a.md) » → « la spec ».
    public static func stepLabel(_ step: ParsedStep) -> String {
        let text = step.text.replacing(#/\[([^\]]*)\]\([^)]*\)/#) { String($0.1) }
            .replacingOccurrences(of: "**", with: "").replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? "Étape sans texte" : text
    }

    /// Le compteur d'une tâche : « 3/5 », « 3/5 · 1 reportée » quand des cases sont reportées, « 2 reportées » quand il
    /// n'y a que des cases reportées.
    public static func taskCount(_ task: ParsedTask) -> String {
        let count = "\(task.checked)/\(task.total)"
        guard task.deferred > 0 else { return count }
        let deferred = "\(task.deferred) " + (task.deferred > 1 ? "reportées" : "reportée")
        return task.total > 0 ? "\(count) · \(deferred)" : deferred
    }

    /// « 1 phase terminée sur 7 », « 3 phases terminées sur 7 ».
    public static func phasesDone(_ done: Int, of total: Int) -> String {
        "\(done) \(done > 1 ? "phases terminées" : "phase terminée") sur \(total)"
    }

    public static func failure(_ failure: RoadmapFailure) -> String {
        switch failure {
        case .noSpecChosen: "Aucune feuille de route choisie"
        case .specUnreadable(let url): "Feuille de route illisible ou introuvable : \(url.lastPathComponent)"
        case .noPhases(let url): "Aucune case « Phase N : … » dans \(url.lastPathComponent)"
        }
    }

    /// « Mis à jour à 14:32 ».
    public static func updated(_ date: Date) -> String {
        "Mis à jour à " + date.formatted(.dateTime.hour().minute().locale(Locale(identifier: "fr_FR")))
    }
}
