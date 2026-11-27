import AppKit
import Testing
@testable import Jalons

/// Une souris inventée : la position du curseur et le bouton gauche, lus par le panneau à la place des vrais.
@MainActor
private final class FakeMouse {
    var location = CGPoint.zero
    var isDown = false
}

/// Le panneau de la frise sur le premier écran du Mac, piloté par une souris inventée : aucun vrai glissement.
@MainActor @Suite(.serialized) struct TimelinePanelTests {
    private let mouse = FakeMouse()

    private func panel(at frame: NSRect) -> TimelinePanel {
        _ = NSApplication.shared
        let panel = TimelinePanel(contentRect: NSRect(origin: .zero, size: frame.size),
                                  styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
                                  backing: .buffered, defer: true)
        panel.isReleasedWhenClosed = false
        let mouse = self.mouse
        panel.mouseLocation = { mouse.location }
        panel.isButtonDown = { mouse.isDown }
        panel.setFrame(frame, display: false)
        return panel
    }

    private func mainScreen() throws -> NSScreen { try #require(NSScreen.screens.first) }

    /// Une frise de 360 × 660 au milieu du premier écran, et la prise d'un glissement par sa barre de titre. Le cadre est
    /// posé sur des points entiers : une zone utile de hauteur impaire (Dock de 73 points) mettait le milieu sur un
    /// demi-point, qu'AppKit arrondit, et faisait échouer toute comparaison de cadres.
    private func start() throws -> (TimelinePanel, NSRect) {
        let visible = try mainScreen().visibleFrame
        let frame = NSRect(x: (visible.midX - 180).rounded(.down), y: (visible.midY - 330).rounded(.down),
                           width: 360, height: 660)
        let panel = panel(at: frame)
        mouse.location = CGPoint(x: frame.minX + 180, y: frame.maxY - 20)
        mouse.isDown = true
        panel.beginMove()
        return (panel, frame)
    }

    /// Prise basse (460 points sous le haut) poussée contre le haut de la zone utile, avec une dérive de 150 points à
    /// droite : le système retient la frise contre la butée, sans la suivre à l'horizontale.
    private func pushAgainstTheTop() throws -> (TimelinePanel, NSRect, NSRect) {
        let visible = try mainScreen().visibleFrame
        let frame = NSRect(x: (visible.midX - 180).rounded(.down), y: visible.maxY - 660 - 200, width: 360, height: 660)
        let panel = panel(at: frame)
        mouse.location = CGPoint(x: frame.minX + 180, y: frame.maxY - 460)
        mouse.isDown = true
        panel.beginMove()
        mouse.location.x += 150
        mouse.location.y += 500
        panel.setFrame(NSRect(x: frame.minX, y: visible.maxY - 660, width: 360, height: 660), display: false)
        panel.keepUnderCursor()
        return (panel, frame, visible)
    }

    @Test func aJumpIsBroughtBackUnderTheCursor() throws {
        let (panel, frame) = try start()
        defer { panel.close() }
        panel.setFrame(frame.offsetBy(dx: -900, dy: 40), display: false)  // le saut du système
        panel.keepUnderCursor()
        #expect(panel.frame.origin == frame.origin, "cadre après correction : \(panel.frame)")
    }

    /// Le premier passage d'écran propose son cadre à `constrainFrameRect` : il revient corrigé, avant d'être appliqué.
    @Test func theFirstCrossingIsCorrectedBeforeBeingApplied() throws {
        let screen = try mainScreen()
        let (panel, frame) = try start()
        defer { panel.close() }
        let proposed = panel.constrainFrameRect(frame.offsetBy(dx: -900, dy: 40), to: screen)
        #expect(proposed.origin == frame.origin, "cadre proposé corrigé : \(proposed)")
    }

    /// Relevé au banc : `windowWillMove` arrive après un départ rapide vers le haut, cadre en retard de 120 points.
    /// L'écart reste celui du point saisi au clic, pas celui du curseur contre ce cadre en retard.
    @Test func aLateMoveStartKeepsTheClickedPoint() throws {
        let visible = try mainScreen().visibleFrame
        let frame = NSRect(x: (visible.midX - 180).rounded(.down), y: (visible.midY - 330).rounded(.down),
                           width: 360, height: 660)
        let panel = panel(at: frame)
        defer { panel.close() }
        panel.noteClick(at: CGPoint(x: 180, y: 640))
        mouse.location = CGPoint(x: frame.minX + 180, y: frame.minY + 640 + 120)
        mouse.isDown = true
        panel.beginMove()
        #expect(panel.grabOffset == CGPoint(x: 180, y: 640), "écart noté : \(String(describing: panel.grabOffset))")
    }

    /// Le clic d'un geste fini (un clic bas sur une ligne de la frise) ne sert jamais de prise au glissement suivant.
    @Test func aClickFromAFinishedGestureIsNotReused() throws {
        let visible = try mainScreen().visibleFrame
        let frame = NSRect(x: (visible.midX - 180).rounded(.down), y: (visible.midY - 330).rounded(.down),
                           width: 360, height: 660)
        let panel = panel(at: frame)
        defer { panel.close() }
        panel.noteClick(at: CGPoint(x: 180, y: 30))
        mouse.location = CGPoint(x: frame.minX + 180, y: frame.minY + 30)
        mouse.isDown = true
        panel.beginMove()
        panel.stopMove()  // fin de ce glissement
        mouse.location = CGPoint(x: frame.minX + 180, y: frame.minY + 640)
        panel.beginMove()  // nouveau glissement, sans clic vu par le panneau
        #expect(panel.grabOffset == CGPoint(x: 180, y: 640), "écart noté : \(String(describing: panel.grabOffset))")
    }

    @Test func aReleasedButtonEndsTheDrag() throws {
        let (panel, frame) = try start()
        defer { panel.close() }
        mouse.isDown = false
        let moved = frame.offsetBy(dx: -900, dy: 40)
        panel.setFrame(moved, display: false)
        panel.keepUnderCursor()
        #expect(panel.frame == moved, "un déplacement après le relâchement n'est jamais corrigé : \(panel.frame)")
        #expect(panel.grabOffset == nil)
    }

    /// La veille finit le glissement au relâchement, même si plus rien ne bouge ensuite : un déplacement bouton tenu
    /// plus tard (un redimensionnement qui repasse par la taille d'origine) n'est pas corrigé.
    @Test func theReleaseWatchEndsTheDragWithoutAnyMove() async throws {
        let (panel, frame) = try start()
        defer { panel.close() }
        mouse.isDown = false
        try await Task.sleep(for: .milliseconds(250))
        #expect(panel.grabOffset == nil, "écart après le relâchement : \(String(describing: panel.grabOffset))")
        mouse.isDown = true
        let moved = frame.offsetBy(dx: -300, dy: 0)
        panel.setFrame(moved, display: false)
        panel.keepUnderCursor()
        #expect(panel.frame == moved, "cadre corrigé après la fin du glissement : \(panel.frame)")
    }

    @Test func aResizeEndsTheDragEvenBackAtTheFirstSize() throws {
        let (panel, frame) = try start()
        defer { panel.close() }
        // Redimensionnement par le bord gauche : l'origine et la taille changent, bouton tenu.
        panel.setFrame(NSRect(x: frame.minX - 40, y: frame.minY, width: 400, height: 660), display: false)
        panel.keepUnderCursor()
        #expect(panel.grabOffset == nil)
        // Retour à la taille d'origine, toujours bouton tenu, loin de la prise : le glissement est fini.
        let back = NSRect(x: frame.minX - 300, y: frame.minY, width: 360, height: 660)
        panel.setFrame(back, display: false)
        panel.keepUnderCursor()
        #expect(panel.frame == back, "cadre après le redimensionnement : \(panel.frame)")
    }

    @Test func aCorrectionNeverPushesTheTopAboveTheScreen() throws {
        let (panel, frame, visible) = try pushAgainstTheTop()
        defer { panel.close() }
        #expect(panel.frame.maxY <= visible.maxY + 1, "haut de la frise : \(panel.frame.maxY), zone utile : \(visible.maxY)")
        #expect(abs(panel.frame.minX - (frame.minX + 150)) < 1, "la frise suit le curseur à l'horizontale : \(panel.frame)")
    }

    /// Après la butée, en redescendant, chaque pas du système qui éloigne la frise de la butée est gardé : la frise
    /// ne colle pas au haut de l'écran.
    @Test func aDescentAfterTheTopIsNotPulledBack() throws {
        let (panel, _, _) = try pushAgainstTheTop()
        defer { panel.close() }
        let atTheTop = panel.frame
        mouse.location.y -= 60
        let lowered = atTheTop.offsetBy(dx: 0, dy: -60)
        panel.setFrame(lowered, display: false)  // le pas du système vers le bas
        panel.keepUnderCursor()
        #expect(panel.frame == lowered, "cadre après un pas de descente : \(panel.frame)")
    }

    /// Une frise plus haute que la zone utile : le système la raccourcirait en la recadrant ; elle garde sa taille,
    /// son haut sous la zone utile.
    @Test func aTimelineTallerThanTheScreenKeepsItsSize() throws {
        let visible = try mainScreen().visibleFrame
        let size = NSSize(width: 360, height: visible.height + 200)
        let frame = NSRect(x: (visible.midX - 180).rounded(.down), y: visible.maxY - size.height,
                           width: size.width, height: size.height)
        let panel = panel(at: frame)
        defer { panel.close() }
        mouse.location = CGPoint(x: frame.minX + 180, y: frame.maxY - 20)
        mouse.isDown = true
        panel.beginMove()
        mouse.location.y += 300  // poussée vers le haut
        panel.setFrame(frame.offsetBy(dx: -900, dy: 0), display: false)  // et un saut du système
        panel.keepUnderCursor()
        #expect(panel.frame.size == size, "taille gardée : \(panel.frame.size)")
        #expect(panel.frame.maxY <= visible.maxY + 1, "haut de la frise : \(panel.frame.maxY), zone utile : \(visible.maxY)")
    }
}
