import SwiftUI

// Liquid Glass (macOS 26 et suivants), sur le modèle d'Orchestre : chaque API de verre est gardée par `#available`,
// et un aspect plat sert de repli. Noms vérifiés par Orchestre dans le SDK macOS 27 : `View.glassEffect(_:in:)`,
// `Glass.regular`, `Glass.tint(_:)`, `GlassEffectContainer(spacing:content:)`.

/// La carte de la phase en cours : du verre teinté de la couleur d'accent, bordé d'un liseré d'accent qui reste visible
/// quand la fenêtre est inactive (le verre y perd sa teinte) ; les autres phases restent à plat.
private struct PhaseSurface: ViewModifier {
    var isCurrent: Bool

    func body(content: Content) -> some View {
        if #available(macOS 26, *) {
            if isCurrent {
                content
                    .glassEffect(.regular.tint(Color.accentColor.opacity(0.18)), in: .rect(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.accentColor.opacity(0.45), lineWidth: 1))
            } else {
                content
            }
        } else {
            content
                .background(RoundedRectangle(cornerRadius: 12).fill(isCurrent ? Color.accentColor.opacity(0.10) : Color.clear))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isCurrent ? Color.accentColor.opacity(0.45) : Color.clear, lineWidth: 1))
        }
    }
}

/// Regroupe les surfaces de verre dans un même conteneur (rendu cohérent).
struct GlassGroup<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: 4) { content }
        } else {
            content
        }
    }
}

/// Le fond de la frise : la couleur de fenêtre et un dégradé très doux, qui donne au verre quelque chose à réfracter.
struct TimelineBackground: View {
    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            LinearGradient(colors: [Color.blue.opacity(0.14), Color.purple.opacity(0.08), Color.green.opacity(0.10)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        .ignoresSafeArea()
    }
}

extension View {
    func phaseSurface(isCurrent: Bool) -> some View { modifier(PhaseSurface(isCurrent: isCurrent)) }
}
