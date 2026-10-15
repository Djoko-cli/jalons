import Foundation

/// Lit la feuille de route d'une spec : son titre (le premier `# `) et ses cases « Phase N : titre ».
/// Sont ignorés : l'en-tête YAML, les blocs de code (règles CommonMark, comme Orchestre) et les commentaires HTML.
/// Une case qui commence par « Phase » sans être retenue (« Phase 1.1 », numéro en double) est notée, jamais perdue
/// en silence.
public enum RoadmapParser {
    public static func parse(_ text: String) -> ParsedRoadmap {
        var title: String?
        var entries: [RoadmapEntry] = []
        var ignored: [Int] = []
        var numbers = Set<Int>()
        var fences = FenceTracker()
        var inComment = false
        var inFrontMatter = false
        for (index, raw) in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated() {
            var line = raw.trimmingCharacters(in: .whitespaces)
            if index == 0 && line == "---" {
                inFrontMatter = true
                continue
            }
            if inFrontMatter {
                if line == "---" || line == "..." { inFrontMatter = false }
                continue
            }
            if !inComment && fences.isCode(line) { continue }
            line = removingComments(line, inComment: &inComment)
            if line.isEmpty { continue }
            if title == nil, line.hasPrefix("# ") {
                title = clean(String(line.dropFirst(2)))
                continue
            }
            guard let (checked, rawLabel) = checkbox(line) else { continue }
            let label = clean(rawLabel)
            guard label.contains(#/(?i)^phase\b/#) else { continue }
            guard let match = label.wholeMatch(of: #/(?i)phase\s+(\d+)(?!\d|[.,]\d)\s*(?:[:.\-—–]\s*)?(.*)/#),
                  let number = Int(match.1),
                  numbers.insert(number).inserted else {
                ignored.append(index + 1)
                continue
            }
            entries.append(RoadmapEntry(number: number, title: String(match.2).trimmingCharacters(in: .whitespaces),
                                        isChecked: checked, line: index + 1))
        }
        return ParsedRoadmap(title: title, entries: entries, ignoredLines: ignored)
    }

    /// Une case de liste : `- [ ] texte`, `* [x] texte`, `1. [X] texte`.
    static func checkbox(_ line: String) -> (checked: Bool, label: String)? {
        guard let match = line.wholeMatch(of: #/(?:[-*+]|\d+[.)])\s+\[([ xX])\]\s+(.+)/#) else { return nil }
        return (match.1 != " ", String(match.2))
    }

    /// Retire les commentaires HTML de la ligne, y compris ceux qui s'étendent sur plusieurs lignes.
    static func removingComments(_ line: String, inComment: inout Bool) -> String {
        var rest = Substring(line)
        var kept = ""
        while !rest.isEmpty {
            if inComment {
                guard let end = rest.range(of: "-->") else { return kept.trimmingCharacters(in: .whitespaces) }
                rest = rest[end.upperBound...]
                inComment = false
            } else {
                guard let start = rest.range(of: "<!--") else {
                    kept += rest
                    break
                }
                kept += rest[..<start.lowerBound]
                rest = rest[start.upperBound...]
                inComment = true
            }
        }
        return kept.trimmingCharacters(in: .whitespaces)
    }

    /// Retire la mise en forme Markdown d'un libellé : liens (on garde leur texte), gras, souligné, code.
    /// « **Phase 1 : socle** », « [Phase 1 : socle](plans/x.md) » → « Phase 1 : socle ».
    static func clean(_ text: String) -> String {
        text.replacing(#/\[([^\]]*)\]\([^)]*\)/#) { String($0.1) }
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
            .trimmingCharacters(in: .whitespaces)
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
