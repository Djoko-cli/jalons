import CoreGraphics

/// La place d'une frise qui n'en a pas encore : en haut à droite de l'écran où se trouve le pointeur au moment où elle
/// s'ouvre (bouton « Suivre » du sélecteur du menu, bouton « Run » d'une session, « Ouvrir avec » du Finder), à
/// 16 points des bords, à gauche des frises déjà visibles sur cet écran sans sortir de l'écran.
public enum PanelPlacement {
    public struct Screen: Sendable {
        public let frame: CGRect
        public let visibleFrame: CGRect
        public init(frame: CGRect, visibleFrame: CGRect) {
            self.frame = frame
            self.visibleFrame = visibleFrame
        }
    }

    /// `mouse` : nul pour une capture de mise au point, qui se fait toujours sur `fallback`. `fallback` : la zone utile
    /// de l'écran à prendre quand le pointeur n'est sur aucun écran. `occupied` : les cadres des frises visibles. Quand
    /// la rangée est pleine, la frise s'arrête au bord gauche, quitte à en recouvrir une.
    public static func topRight(size: CGSize, mouse: CGPoint?, screens: [Screen], fallback: CGRect?,
                                occupied: [CGRect]) -> CGPoint? {
        let underPointer = mouse.flatMap { point in screens.first { contains($0.frame, point) } }
        guard let visible = underPointer?.visibleFrame ?? fallback else { return nil }
        let step = size.width + 16
        let y = visible.maxY - size.height - 16
        let leftmost = visible.minX + 16
        var slot: CGFloat = 1
        while true {
            let x = max(leftmost, visible.maxX - slot * step)
            let frame = CGRect(x: x, y: y, width: size.width, height: size.height)
            if x == leftmost || !occupied.contains(where: { $0.intersects(frame) }) { return CGPoint(x: x, y: y) }
            slot += 1
        }
    }

    /// Comme `NSMouseInRect` dans un repère non retourné : le bord haut appartient à l'écran (pointeur dans sa barre
    /// des menus), le bord bas non ; le bord gauche oui, le bord droit non.
    static func contains(_ rect: CGRect, _ point: CGPoint) -> Bool {
        point.x >= rect.minX && point.x < rect.maxX && point.y > rect.minY && point.y <= rect.maxY
    }
}
