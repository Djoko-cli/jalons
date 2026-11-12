// Copie du lecteur de plans d'Orchestre (OrchestreCore/Work, commit d03903e), pour que Jalons se compile seul.
// Une évolution d'un côté se reporte à la main de l'autre.

import Foundation

/// Une case à cocher d'une tâche.
public struct ParsedStep: Sendable, Equatable {
    /// Le texte après la case, tel qu'écrit (Markdown compris), sans les espaces autour.
    public var text: String
    public var isChecked: Bool
    /// Ligne de la case, à partir de 1.
    public var line: Int
    /// Case reportée, remplacée ou sans objet (`- [-]`) : ni faite ni à faire, hors des compteurs de la tâche.
    public var isDeferred: Bool

    public init(text: String, isChecked: Bool, line: Int, isDeferred: Bool = false) {
        self.text = text
        self.isChecked = isChecked
        self.line = line
        self.isDeferred = isDeferred
    }
}

public struct ParsedTask: Sendable, Equatable {
    public var number: Int
    public var title: String
    /// Ligne du titre, à partir de 1.
    public var line: Int
    public var checked = 0
    /// Cases faites ou à faire ; les cases reportées n'y sont pas.
    public var total = 0
    /// Cases reportées (`- [-]`).
    public var deferred = 0
    /// Fichiers des lignes `- Create:`.
    public var createdFiles: [String] = []
    /// Fichiers des lignes `- Create:`, `- Modify:`, `- Test:` et `- Replace:`.
    public var touchedFiles: [String] = []
    /// Les cases de la tâche, dans l'ordre du plan.
    public var steps: [ParsedStep] = []
}

public struct ParsedPlan: Sendable, Equatable {
    public var title: String?
    public var tasks: [ParsedTask]
    /// Cases hors de toute tâche.
    public var looseChecked = 0
    public var looseTotal = 0
    /// Cases reportées hors de toute tâche, hors de `looseTotal`.
    public var looseDeferred = 0

    public var anyChecked: Bool { looseChecked > 0 || tasks.contains { $0.checked > 0 } }
}

public enum PlanParser {
    public static func parse(_ text: String) -> ParsedPlan {
        var plan = ParsedPlan(title: nil, tasks: [])
        var fences = FenceTracker()
        var current: ParsedTask?
        var inFiles = false
        for (index, raw) in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated() {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if fences.isCode(line) { continue }
            if let heading = MarkdownLine.heading(line) {
                inFiles = false
                if heading.level == 1 && plan.title == nil { plan.title = heading.text }
                if heading.level <= 3 {
                    if let task = current { plan.tasks.append(task) }
                    current = heading.level == 3 ? task(from: heading.text, line: index + 1) : nil
                }
                continue
            }
            if MarkdownLine.isDeferredCheckbox(line) {
                if current != nil {
                    current!.deferred += 1
                    let text = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    current!.steps.append(ParsedStep(text: text, isChecked: false, line: index + 1, isDeferred: true))
                } else {
                    plan.looseDeferred += 1
                }
                continue
            }
            if let checked = MarkdownLine.checkbox(line) {
                if current != nil {
                    current!.total += 1
                    if checked { current!.checked += 1 }
                    let text = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
                    current!.steps.append(ParsedStep(text: text, isChecked: checked, line: index + 1))
                } else {
                    plan.looseTotal += 1
                    if checked { plan.looseChecked += 1 }
                }
                continue
            }
            guard current != nil else { continue }
            if line == "**Files:**" || line == "**Fichiers :**" || line == "**Fichiers:**" {
                inFiles = true
                continue
            }
            if inFiles {
                if let files = filesLine(line) {
                    current!.touchedFiles += files.paths
                    if files.isCreate { current!.createdFiles += files.paths }
                } else if line.isEmpty || !line.hasPrefix("-") {
                    inFiles = false
                }
            }
        }
        if let task = current { plan.tasks.append(task) }
        return plan
    }

    static func task(from heading: String, line: Int) -> ParsedTask? {
        guard let match = heading.wholeMatch(of: #/(?i)(?:task|tâche)\s+(\d+)\s*[:.\-—–]?\s*(.*)/#),
              let number = Int(match.1) else { return nil }
        return ParsedTask(number: number, title: String(match.2), line: line)
    }

    static func filesLine(_ line: String) -> (isCreate: Bool, paths: [String])? {
        guard let match = line.wholeMatch(of: #/-\s*(Create|Modify|Test|Replace|Créer|Modifier|Tester|Remplacer)\s*(\([^)]*\))?\s*:\s*(.*)/#) else { return nil }
        let kind = match.1.lowercased()
        // Seule la partie avant la première parenthèse porte les chemins ; le reste est une annotation.
        let value = match.3.prefix(while: { $0 != "(" })
        let paths = value.matches(of: #/`([^`]+)`/#)
            .map { String($0.1) }
            .filter { !$0.isEmpty && !$0.contains(" ") }
            .flatMap { expandBraces(withoutLineRange($0)) }
        return (kind == "create" || kind == "créer", paths)
    }

    static func withoutLineRange(_ path: String) -> String {
        if let match = path.wholeMatch(of: #/(.+?):\d+(?:-\d+)?/#) { return String(match.1) }
        return path
    }

    /// Développe un seul groupe d'accolades : `a/{x,y}.swift` donne `a/x.swift` et `a/y.swift`.
    static func expandBraces(_ path: String) -> [String] {
        guard let match = path.wholeMatch(of: #/(.*)\{([^{}]*)\}(.*)/#) else { return [path] }
        return match.2.split(separator: ",", omittingEmptySubsequences: false).map {
            String(match.1) + $0 + String(match.3)
        }
    }
}
