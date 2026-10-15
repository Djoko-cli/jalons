import Foundation

/// Lit la feuille de route d'une spec : son titre (le premier `# `) et ses cases « Phase N : titre ».
/// Sont ignorés : l'en-tête YAML refermé, les blocs de code (règles CommonMark, comme Orchestre) et les commentaires
/// HTML. Rien n'est perdu en silence : une case « Phase N » non retenue (« Phase 1.1 », numéro en double, case dans
/// l'en-tête YAML) est notée, et un commentaire jamais refermé est signalé avec sa ligne d'ouverture.
public enum RoadmapParser {
    public static func parse(_ text: String) -> ParsedRoadmap {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        var title: String?
        var entries: [RoadmapEntry] = []
        var ignored: [Int] = []
        var numbers = Set<Int>()
        var fences = FenceTracker()
        /// Ligne (index) d'ouverture d'un commentaire HTML sur plusieurs lignes, tant qu'il n'est pas refermé.
        var openComment: Int?
        var start = 0
        // L'en-tête YAML ne compte que s'il est refermé : un `---` de séparation en ligne 1 n'avale rien.
        if lines.first == "---", let end = lines.indices.dropFirst().first(where: { lines[$0] == "---" || lines[$0] == "..." }) {
            for index in 1..<end where isPhaseLike(lines[index]) { ignored.append(index + 1) }
            start = end + 1
        }
        for index in lines.indices where index >= start {
            var line = lines[index]
            if openComment != nil {
                guard let end = line.range(of: "-->") else { continue }
                openComment = nil
                line = String(line[end.upperBound...]).trimmingCharacters(in: .whitespaces)
            } else if fences.isCode(line) {
                continue
            }
            line = removingCompleteComments(line)
            // Un commentaire ne s'ouvre sur plusieurs lignes que s'il commence la ligne ; un `<!--` orphelin au milieu
            // d'une ligne reste du texte.
            if line.hasPrefix("<!--") {
                openComment = index
                continue
            }
            if line.isEmpty { continue }
            if title == nil, line.hasPrefix("# ") {
                title = clean(String(line.dropFirst(2)))
                continue
            }
            guard let (checked, rawLabel) = checkbox(line) else { continue }
            let label = clean(rawLabel)
            guard isPhaseLabel(label) else { continue }
            guard let match = label.wholeMatch(of: #/(?i)\W*phase[\s_-]*(\d+)(?!\d|[.,]\d)\s*(?:[:.\-—–]\s*)?(.*)/#),
                  let number = Int(match.1),
                  numbers.insert(number).inserted else {
                ignored.append(index + 1)
                continue
            }
            entries.append(RoadmapEntry(number: number, title: String(match.2).trimmingCharacters(in: .whitespaces),
                                        isChecked: checked, line: index + 1))
        }
        return ParsedRoadmap(title: title, entries: entries, ignoredLines: ignored,
                             unclosedCommentLine: openComment.map { $0 + 1 })
    }

    /// Une case de liste : `- [ ] texte`, `* [x] texte`, `1. [X] texte`.
    static func checkbox(_ line: String) -> (checked: Bool, label: String)? {
        guard let match = line.wholeMatch(of: #/(?:[-*+]|\d+[.)])\s+\[([ xX])\]\s+(.+)/#) else { return nil }
        return (match.1 != " ", String(match.2))
    }

    /// « Phase » suivi d'un numéro, après d'éventuels signes (emoji, puce) : « Phase de recette » n'en est pas une.
    static func isPhaseLabel(_ label: String) -> Bool {
        label.contains(#/(?i)^\W*phase[\s_-]*\d/#)
    }

    static func isPhaseLike(_ line: String) -> Bool {
        guard let (_, label) = checkbox(line) else { return false }
        return isPhaseLabel(clean(label))
    }

    /// Retire les commentaires HTML complets de la ligne, `<!-->` et `<!--->` compris (CommonMark).
    static func removingCompleteComments(_ line: String) -> String {
        line.replacing(#/<!--(?:>|->|.*?-->)/#, with: "").trimmingCharacters(in: .whitespaces)
    }

    /// Retire la mise en forme Markdown d'un libellé : liens (on garde leur texte), code, et marques d'emphase en bord
    /// de mot (gras, italique, barré). « **Phase 1 : socle** », « [Phase 1 : socle](plans/x.md) », « ~~Phase 1~~ »
    /// → « Phase 1 : socle », « Phase 1 ». Les `_` à l'intérieur d'un mot restent (« Phase_1 »).
    static func clean(_ text: String) -> String {
        let unlinked = text
            .replacing(#/\[([^\]]*)\]\([^)]*\)/#) { String($0.1) }
            .replacing(#/\[([^\]]*)\]\[[^\]]*\]/#) { String($0.1) }
            .replacingOccurrences(of: "`", with: "")
        let emphasis = CharacterSet(charactersIn: "*_~")
        return unlinked.split(separator: " ", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: emphasis) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// Suit l'ouverture et la fermeture des blocs de code, avec les règles CommonMark d'Orchestre : même caractère, clôture
/// au moins aussi longue et sans texte ; une ligne « ```code``` texte » n'ouvre pas de bloc.
struct FenceTracker {
    private var open: (char: Character, count: Int)?

    /// Vrai si la ligne fait partie d'un bloc de code, clôtures comprises.
    mutating func isCode(_ line: String) -> Bool {
        if let marker = Self.marker(line) {
            if let current = open {
                if marker.char == current.char && marker.count >= current.count && marker.isBare { open = nil }
            } else {
                open = (marker.char, marker.count)
            }
            return true
        }
        return open != nil
    }

    static func marker(_ line: String) -> (char: Character, count: Int, isBare: Bool)? {
        guard let first = line.first, first == "`" || first == "~" else { return nil }
        let count = line.prefix(while: { $0 == first }).count
        guard count >= 3 else { return nil }
        let rest = line.dropFirst(count)
        if first == "`" && rest.contains("`") { return nil }
        return (first, count, rest.trimmingCharacters(in: .whitespaces).isEmpty)
    }
}
