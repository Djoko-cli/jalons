import CoreGraphics
import JalonsCore
import Testing

/// Les cadres sont ceux d'un banc à trois écrans 4K côte à côte (x de −3840 à 7680) : une frise de 360 × 660 tenue
/// à 265 points de son bord gauche, comme dans la trace du saut relevée le 24/11/2026.
@Suite struct DragCorrectionTests {
    let grab = CGPoint(x: 265, y: 637)

    @Test func aFrameThatFollowsTheCursorIsKept() {
        let mouse = CGPoint(x: 3665, y: 1664)
        // Un léger écart (le système retient la frise contre un bord) n'est pas un saut.
        let proposed = CGRect(x: 3400 + 3, y: 1027 - 2, width: 360, height: 660)
        #expect(DragCorrection.frame(proposed, mouse: mouse, grabOffset: grab) == proposed)
    }

    @Test func aFrameThatJumpedAScreenIsBroughtBackUnderTheCursor() {
        // Relevé réel : le curseur entre sur l'écran du milieu en x = 3665, le système propose x = 237, l'écart
        // qu'avait la frise au bord gauche de l'écran qu'elle quittait.
        let mouse = CGPoint(x: 3665, y: 1664)
        let proposed = CGRect(x: 237, y: 1031, width: 360, height: 660)
        let kept = DragCorrection.frame(proposed, mouse: mouse, grabOffset: grab)
        #expect(kept == CGRect(x: 3400, y: 1027, width: 360, height: 660), "cadre gardé : \(kept)")
    }

    @Test func theToleranceIsTheLimit() {
        let mouse = CGPoint(x: 1000, y: 1000)
        let held = CGPoint(x: mouse.x - grab.x, y: mouse.y - grab.y)
        let atLimit = CGRect(x: held.x + DragCorrection.tolerance, y: held.y, width: 360, height: 660)
        let beyond = CGRect(x: held.x + DragCorrection.tolerance + 1, y: held.y, width: 360, height: 660)
        #expect(DragCorrection.frame(atLimit, mouse: mouse, grabOffset: grab) == atLimit)
        #expect(DragCorrection.frame(beyond, mouse: mouse, grabOffset: grab).origin == held)
    }

    @Test func theSizeIsNeverChanged() {
        let proposed = CGRect(x: -3603, y: 1031, width: 421, height: 1056)
        let kept = DragCorrection.frame(proposed, mouse: CGPoint(x: 2059, y: 1477), grabOffset: grab)
        #expect(kept.size == proposed.size, "taille gardée : \(kept.size)")
        #expect(kept.origin != proposed.origin)
    }
}
