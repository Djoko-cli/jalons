import CoreGraphics

/// Garde la frise sous le curseur pendant qu'on la fait glisser. Au passage d'un écran à l'autre, macOS 27 propose
/// pour un panneau réglé comme la frise un cadre replacé au même endroit relatif sur le nouvel écran, loin du curseur ;
/// une fenêtre ordinaire n'a pas ce saut (mesuré au banc le 24/11/2026). Le cadre proposé passe ici avant d'être
/// appliqué.
public enum DragCorrection {
    /// Au-delà de cet écart, en points, entre le cadre proposé et la place que tient le curseur, le cadre est ramené.
    /// Les petits ajustements du système (bords d'écran, barre des menus) restent bien en deçà ; un saut vaut un écran.
    public static let tolerance: CGFloat = 100

    /// Le cadre proposé, ou, s'il s'éloigne de plus de `tolerance` de la place où le curseur tient la frise (le curseur
    /// moins l'écart noté au début du glissement), le même cadre ramené à cette place.
    public static func frame(_ proposed: CGRect, mouse: CGPoint, grabOffset: CGPoint) -> CGRect {
        let held = CGPoint(x: mouse.x - grabOffset.x, y: mouse.y - grabOffset.y)
        guard hypot(proposed.minX - held.x, proposed.minY - held.y) > tolerance else { return proposed }
        return CGRect(origin: held, size: proposed.size)
    }
}
