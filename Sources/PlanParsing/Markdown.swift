// Copie du lecteur de plans d'Orchestre (OrchestreCore/Work, commit d03903e), pour que Jalons se compile seul.
// Une évolution d'un côté se reporte à la main de l'autre.

import Foundation

/// Reconnaissance des lignes Markdown utiles à Orchestre. Les lignes reçues sont déjà sans blancs autour.
enum MarkdownLine {
    static func heading(_ line: String) -> (level: Int, text: String)? {
        let level = line.prefix(while: { $0 == "#" }).count
        guard (1...6).contains(level), line.dropFirst(level).first == " " else { return nil }
        return (level, line.dropFirst(level).trimmingCharacters(in: .whitespaces))
    }

    /// true pour une case cochée, false pour une case vide, nil si ce n'est pas une case (une case reportée `[-]`
    /// non plus : elle n'est ni faite ni à faire).
    static func checkbox(_ line: String) -> Bool? {
        switch checkboxMark(line) {
        case " ": return false
        case "x", "X": return true
        default: return nil
        }
    }

    /// Une case reportée, remplacée ou sans objet : `- [-] …`.
    static func isDeferredCheckbox(_ line: String) -> Bool { checkboxMark(line) == "-" }

    /// Le caractère entre les crochets d'une case `- [?]` ou `* [?]`, suivie d'une espace ou de la fin de ligne.
    private static func checkboxMark(_ line: String) -> Character? {
        guard line.hasPrefix("- [") || line.hasPrefix("* [") else { return nil }
        let chars = Array(line)
        guard chars.count >= 5, chars[4] == "]", chars.count == 5 || chars[5] == " " else { return nil }
        return chars[3]
    }

    static func fenceMarker(_ line: String) -> (char: Character, count: Int, isBare: Bool)? {
        guard let first = line.first, first == "`" || first == "~" else { return nil }
        let count = line.prefix(while: { $0 == first }).count
        guard count >= 3 else { return nil }
        let rest = line.dropFirst(count)
        // CommonMark : une clôture à accents graves ne peut pas contenir d'accent grave (« ```x``` texte » n'est pas une fence).
        if first == "`" && rest.firstIndex(of: "`") != nil { return nil }
        return (first, count, rest.trimmingCharacters(in: .whitespaces).isEmpty)
    }
}

/// Suit l'ouverture et la fermeture des blocs de code (règle CommonMark : même caractère, au moins aussi long, sans texte).
struct FenceTracker {
    private var open: (char: Character, count: Int)?

    /// Vrai si la ligne fait partie d'un bloc de code, clôtures comprises.
    mutating func isCode(_ line: String) -> Bool {
        if let marker = MarkdownLine.fenceMarker(line) {
            if let current = open {
                if marker.char == current.char && marker.count >= current.count && marker.isBare { open = nil }
            } else {
                open = (marker.char, marker.count)
            }
            return true
        }
        return open != nil
    }
}
