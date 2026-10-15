import AppKit
import JalonsCore

/// L'icône de la barre des menus : un anneau qui se remplit avec l'avancement global, puis la phase en cours et son
/// avancement. Une image non « modèle », dessinée à chaque affichage : l'anneau garde ses couleurs, le texte suit
/// l'apparence de la barre (modèle : l'icône d'Orchestre).
enum MenuBarIcon {
    static func image(for state: RoadmapState) -> NSImage {
        switch state {
        case .loaded(let roadmap):
            guard let phase = roadmap.currentPhase else {
                return compose(progress: 1, text: "Terminé", warning: roadmap.hasWarnings, state: state)
            }
            return compose(progress: roadmap.progress,
                           text: "Phase \(phase.number) · \(Presentation.phasePercent(phase, in: roadmap))",
                           warning: roadmap.hasWarnings, state: state)
        case .failed(.noSpecChosen):
            return compose(progress: nil, text: "Jalons", warning: false, state: state)
        case .failed:
            return compose(progress: nil, text: "Jalons", warning: true, state: state)
        }
    }

    private static func compose(progress: Double?, text: String, warning: Bool, state: RoadmapState) -> NSImage {
        let height: CGFloat = 18
        let ring: CGFloat = 13
        let lineWidth: CGFloat = 2.2
        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .medium)
        let label = text as NSString
        let textWidth = ceil(label.size(withAttributes: [.font: font]).width)
        let warningGlyph = warning ? symbol("exclamationmark.triangle.fill", color: .systemOrange) : nil
        var width = 1 + ring + 5 + textWidth + 1
        if let warningGlyph { width += 4 + warningGlyph.size.width }
        let image = NSImage(size: NSSize(width: ceil(width), height: height), flipped: false) { _ in
            let center = NSPoint(x: 1 + ring / 2, y: height / 2)
            let radius = (ring - lineWidth) / 2
            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = lineWidth
            NSColor.labelColor.withAlphaComponent(0.28).setStroke()
            track.stroke()
            if let progress, progress > 0 {
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: radius, startAngle: 90,
                              endAngle: 90 - 360 * min(progress, 1), clockwise: true)
                arc.lineWidth = lineWidth
                arc.lineCapStyle = .round
                (progress >= 1 ? NSColor.systemGreen : NSColor.controlAccentColor).setStroke()
                arc.stroke()
            }
            let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.labelColor]
            let size = label.size(withAttributes: attributes)
            label.draw(at: NSPoint(x: 1 + ring + 5, y: (height - size.height) / 2), withAttributes: attributes)
            if let warningGlyph {
                warningGlyph.draw(in: NSRect(x: 1 + ring + 5 + textWidth + 4, y: (height - warningGlyph.size.height) / 2,
                                             width: warningGlyph.size.width, height: warningGlyph.size.height))
            }
            return true
        }
        image.isTemplate = false
        // Lu par VoiceOver sur l'élément de la barre des menus, en plus du libellé SwiftUI.
        image.accessibilityDescription = Presentation.accessibilityLabel(state)
        return image
    }

    private static func symbol(_ name: String, color: NSColor) -> NSImage? {
        let configuration = NSImage.SymbolConfiguration(pointSize: 10, weight: .semibold)
            .applying(NSImage.SymbolConfiguration(paletteColors: [color]))
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(configuration)
    }
}
