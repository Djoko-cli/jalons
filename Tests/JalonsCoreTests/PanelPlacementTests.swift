import CoreGraphics
import JalonsCore
import Testing

/// La place d'une frise qui n'en a pas encore : en haut à droite de l'écran du pointeur, 16 points du bord, à gauche
/// des frises déjà visibles sur cet écran. Deux écrans inventés : l'écran principal à gauche (1920 × 1080, barre des
/// menus de 30 points) et un second à droite (2560 × 1440). Frise de 360 × 660 : un pas de 376 points.
@Suite struct PanelPlacementTests {
    let main = PanelPlacement.Screen(frame: CGRect(x: 0, y: 0, width: 1920, height: 1080),
                                     visibleFrame: CGRect(x: 0, y: 0, width: 1920, height: 1050))
    let second = PanelPlacement.Screen(frame: CGRect(x: 1920, y: 0, width: 2560, height: 1440),
                                       visibleFrame: CGRect(x: 1920, y: 0, width: 2560, height: 1410))
    let size = CGSize(width: 360, height: 660)

    func place(mouse: CGPoint?, occupied: [CGRect] = [], fallback: CGRect? = nil) -> CGPoint? {
        PanelPlacement.topRight(size: size, mouse: mouse, screens: [main, second],
                                fallback: fallback ?? main.visibleFrame, occupied: occupied)
    }

    /// Le cadre d'une frise posée au rang `slot` (1 = contre le bord droit) du second écran.
    func onSecond(slot: CGFloat) -> CGRect {
        CGRect(x: 4480 - slot * 376, y: 734, width: 360, height: 660)
    }

    /// L'écran principal est donné en repli : une place sur l'écran principal serait l'ancien comportement.
    @Test func aNewTimelineOpensOnTheScreenUnderThePointer() {
        #expect(place(mouse: CGPoint(x: 2500, y: 700)) == CGPoint(x: 4480 - 376, y: 1410 - 676))
    }

    /// Un clic dans la barre des menus du second écran : le pointeur est sur son bord haut.
    @Test func theTopEdgeOfTheSecondScreenBelongsToIt() {
        #expect(place(mouse: CGPoint(x: 2500, y: 1440)) == CGPoint(x: 4104, y: 734))
    }

    /// x = 1920 est à la fois le bord droit du principal et le bord gauche du second : il appartient au second.
    @Test func theSharedEdgeBelongsToTheScreenOnItsRight() {
        #expect(place(mouse: CGPoint(x: 1920, y: 700)) == CGPoint(x: 4104, y: 734))
    }

    /// Deux écrans empilés : y = 0 est le bord bas du principal et le bord haut de celui du dessous ; il appartient à
    /// celui du dessous (comme `NSMouseInRect`).
    @Test func theSharedEdgeOfStackedScreensBelongsToTheLowerOne() {
        let below = PanelPlacement.Screen(frame: CGRect(x: 0, y: -1080, width: 1920, height: 1080),
                                          visibleFrame: CGRect(x: 0, y: -1080, width: 1920, height: 1080))
        let placed = PanelPlacement.topRight(size: size, mouse: CGPoint(x: 100, y: 0), screens: [main, below],
                                             fallback: main.visibleFrame, occupied: [])
        #expect(placed == CGPoint(x: 1544, y: -676))
    }

    @Test func thePointerOnTheMainScreenKeepsTheTimelineThere() {
        #expect(place(mouse: CGPoint(x: 100, y: 100)) == CGPoint(x: 1920 - 376, y: 1050 - 676))
    }

    @Test func aNewTimelineSitsLeftOfThoseAlreadyOnItsScreen() {
        let placed = place(mouse: CGPoint(x: 2500, y: 700), occupied: [onSecond(slot: 1), onSecond(slot: 2)])
        #expect(placed == CGPoint(x: 4480 - 3 * 376, y: 734))
    }

    /// Une frise visible sur l'autre écran ne pousse pas la nouvelle : chaque écran a sa propre rangée.
    @Test func aTimelineOnAnotherScreenDoesNotPushIt() {
        let onMain = CGRect(x: 1544, y: 374, width: 360, height: 660)
        #expect(place(mouse: CGPoint(x: 2500, y: 700), occupied: [onMain]) == CGPoint(x: 4104, y: 734))
    }

    /// Une place libérée (frise masquée, ou déplacée ailleurs) se reprend, même si une frise est plus à gauche.
    @Test func aFreedPlaceIsTakenAgain() {
        #expect(place(mouse: CGPoint(x: 2500, y: 700), occupied: [onSecond(slot: 2)]) == CGPoint(x: 4104, y: 734))
    }

    @Test func aFullRowStopsAtTheLeftEdgeOfThatScreen() {
        let band = CGRect(x: 1920, y: 0, width: 2560, height: 1410)
        #expect(place(mouse: CGPoint(x: 2500, y: 700), occupied: [band]) == CGPoint(x: 1920 + 16, y: 734))
    }

    @Test func aPointerOnNoScreenFallsBackToTheGivenOne() {
        #expect(place(mouse: CGPoint(x: -500, y: -500), fallback: second.visibleFrame) == CGPoint(x: 4104, y: 734))
    }

    /// Une capture de mise au point ne donne pas de pointeur : toujours l'écran de repli, quel que soit le pointeur.
    @Test func noPointerMeansTheFallbackScreen() {
        #expect(place(mouse: nil, fallback: main.visibleFrame) == CGPoint(x: 1544, y: 374))
    }

    @Test func noScreenAtAllGivesNoPlace() {
        #expect(PanelPlacement.topRight(size: size, mouse: .zero, screens: [], fallback: nil, occupied: []) == nil)
    }
}
