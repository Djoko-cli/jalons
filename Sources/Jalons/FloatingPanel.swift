import AppKit
import JalonsCore
import SwiftUI

/// Le panneau de la frise. Pendant qu'on la fait glisser, il ramène sous le curseur un cadre que le système replace
/// loin de lui au passage d'un écran à l'autre (voir `DragCorrection`).
final class TimelinePanel: NSPanel {
    /// Les lectures de la souris : la position du curseur et le bouton gauche tenu. Remplacées dans les tests.
    var mouseLocation: () -> CGPoint = { NSEvent.mouseLocation }
    var isButtonDown: () -> Bool = { NSEvent.pressedMouseButtons & 1 != 0 }

    /// L'écart entre le curseur et l'origine du panneau, noté au début du glissement en cours ; nil hors glissement.
    private(set) var grabOffset: CGPoint?
    /// La taille du panneau au début du glissement : un cadre d'une autre taille vient d'un redimensionnement, qui met
    /// fin au glissement.
    private var grabSize: CGSize?
    /// Attend le relâchement du bouton, pour finir le glissement même si plus rien ne bouge ensuite.
    private var releaseWatch: Task<Void, Never>?
    /// Le point saisi par le clic en cours, en coordonnées du panneau (origine en bas à gauche) : l'écart exact entre
    /// le curseur et l'origine au début d'un glissement. Oublié au relâchement et en fin de glissement, pour qu'un
    /// geste fini ne serve jamais de prise.
    private var clickedPoint: CGPoint?

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown: noteClick(at: event.locationInWindow)
        case .leftMouseUp: noteClick(at: nil)
        default: break
        }
        super.sendEvent(event)
    }

    func noteClick(at point: CGPoint?) { clickedPoint = point }

    /// Début d'un déplacement (`windowWillMove`) : l'écart est noté si le bouton de la souris est tenu, sinon aucun.
    /// Il vient du point saisi au clic : `windowWillMove` peut arriver après un départ rapide, avec un cadre déjà en
    /// retard sur le curseur (relevé au banc : 120 points). Sans clic noté, il est lu sur le curseur et le cadre.
    func beginMove() {
        guard isButtonDown() else {
            stopMove()
            return
        }
        if let clickedPoint {
            grabOffset = clickedPoint
        } else {
            let mouse = mouseLocation()
            grabOffset = CGPoint(x: mouse.x - frame.minX, y: mouse.y - frame.minY)
        }
        grabSize = frame.size
        releaseWatch?.cancel()
        releaseWatch = Task { @MainActor [weak self] in
            while !Task.isCancelled, self?.isButtonDown() == true {
                try? await Task.sleep(for: .milliseconds(50))
            }
            if !Task.isCancelled { self?.stopMove() }
        }
    }

    func stopMove() {
        grabOffset = nil
        grabSize = nil
        clickedPoint = nil
        releaseWatch?.cancel()
        releaseWatch = nil
    }

    /// L'écart à tenir, ou nil : hors glissement, ou glissement fini (bouton relâché, ou redimensionnement).
    private func heldOffset(for size: CGSize) -> CGPoint? {
        guard let grabOffset else { return nil }
        guard isButtonDown(), size == grabSize else {
            stopMove()
            return nil
        }
        return grabOffset
    }

    /// Le cadre ramené sous le curseur s'il s'en est éloigné (`DragCorrection`), puis recadré par le système comme tout
    /// cadre, sur l'écran du curseur : la correction n'annule que le saut, jamais une butée (barre des menus, haut de
    /// l'écran) contre laquelle on pousse la frise.
    private func underCursor(_ current: NSRect, offset: CGPoint, screen: NSScreen?) -> NSRect {
        let mouse = mouseLocation()
        let held = DragCorrection.frame(current, mouse: mouse, grabOffset: offset)
        guard held != current else { return current }
        let target = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? screen
        let fitted = super.constrainFrameRect(held, to: target)
        // Le système peut raccourcir une frise plus haute que l'écran : elle garde sa taille, sous le haut recadré.
        let placed = NSRect(x: fitted.minX, y: fitted.maxY - held.height, width: held.width, height: held.height)
        // Recadrée (butée, écran plus petit), la frise ne tient plus la place prévue : l'écart se recale sur sa place,
        // sinon chaque pas qui l'éloigne de la butée serait annulé.
        if placed.origin != held.origin {
            grabOffset = CGPoint(x: mouse.x - placed.minX, y: mouse.y - placed.minY)
        }
        return placed
    }

    /// Le premier passage d'écran d'un glissement propose son cadre ici : il est corrigé avant d'être appliqué.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect {
        let proposed = super.constrainFrameRect(frameRect, to: screen)
        guard let offset = heldOffset(for: proposed.size) else { return proposed }
        return underCursor(proposed, offset: offset, screen: screen)
    }

    /// Les passages suivants ne proposent rien : le système déplace le panneau directement (relevé au banc le
    /// 24/11/2026). Appelée après chaque déplacement (`windowDidMove`, `windowDidChangeScreen`) : un panneau éloigné du
    /// curseur est remis sous lui, et le système poursuit le glissement depuis cette place.
    func keepUnderCursor() {
        guard let offset = heldOffset(for: frame.size) else { return }
        let kept = underCursor(frame, offset: offset, screen: screen)
        if abs(kept.minX - frame.minX) >= 1 || abs(kept.minY - frame.minY) >= 1 { setFrameOrigin(kept.origin) }
    }
}

/// La frise flottante d'une feuille de route : un panneau toujours au premier plan, sur tous les bureaux, qui n'active
/// pas l'app quand on clique dedans. Sa taille et sa place sont retenues d'un lancement à l'autre, pour chaque spec.
@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private weak var tracker: RoadmapTracker?
    private(set) var window: NSPanel?
    private let frameName: String
    /// Places retenues sous d'autres noms, essayées dans l'ordre si la frise n'a pas encore la sienne.
    private let fallbackFrameNames: [String]
    /// Faux en mise au point (`-specPath`) : la place de la frise n'est pas enregistrée.
    private let remembersFrame: Bool

    init(tracker: RoadmapTracker, frameName: String, fallbackFrameNames: [String], remembersFrame: Bool) {
        self.tracker = tracker
        self.frameName = frameName
        self.fallbackFrameNames = fallbackFrameNames
        self.remembersFrame = remembersFrame
    }

    func show() {
        let panel = window ?? makePanel()
        window = panel
        panel.orderFrontRegardless()
        tracker?.panelVisibilityChanged(true)
    }

    func hide() {
        window?.orderOut(nil)
        tracker?.panelVisibilityChanged(false)
    }

    /// Ferme la frise pour de bon (feuille de route retirée), sans changer la visibilité retenue.
    func close() {
        window?.delegate = nil
        window?.close()
        window = nil
    }

    /// Seul un geste de fermeture (bouton de fermeture, ⌘W) passe par ici : la frise est retenue masquée. La fermeture
    /// que l'app impose à ses fenêtres en quittant ne passe que par `windowWillClose`, et ne change rien à la frise à
    /// rouvrir au prochain lancement.
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        tracker?.panelVisibilityChanged(false)
        return true
    }

    func windowWillMove(_ notification: Notification) {
        (window as? TimelinePanel)?.beginMove()
    }

    func windowDidMove(_ notification: Notification) {
        (window as? TimelinePanel)?.keepUnderCursor()
    }

    func windowDidChangeScreen(_ notification: Notification) {
        (window as? TimelinePanel)?.keepUnderCursor()
    }


    private func makePanel() -> NSPanel {
        let panel = TimelinePanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 660),
                            styleMask: [.titled, .closable, .resizable, .fullSizeContentView, .nonactivatingPanel],
                            backing: .buffered, defer: true)
        panel.title = "Jalons"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.minSize = NSSize(width: 280, height: 240)
        panel.delegate = self
        if let tracker {
            panel.contentView = NSHostingView(rootView: TimelineView().environment(tracker))
        }
        // Les captures de mise au point ne touchent pas à la taille et à la place retenues.
        if tracker?.model?.options.snapshotDirectory != nil {
            placeTopRight(panel)
        } else {
            if !([frameName] + fallbackFrameNames).contains(where: { panel.setFrameUsingName($0) }) {
                placeTopRight(panel)
            }
            if remembersFrame { panel.setFrameAutosaveName(frameName) }
        }
        return panel
    }

    /// La place de la frise, même masquée : celle de sa fenêtre, ou, avant sa première ouverture, celle qui est retenue.
    var knownFrame: NSRect? {
        if let window { return window.frame }
        guard remembersFrame else { return nil }
        // Redimensionnable : sinon AppKit ne reprend que la position retenue, et la taille reste nulle.
        let probe = NSWindow(contentRect: .zero, styleMask: [.titled, .resizable], backing: .buffered, defer: true)
        probe.isReleasedWhenClosed = false
        return ([frameName] + fallbackFrameNames).contains(where: { probe.setFrameUsingName($0) }) ? probe.frame : nil
    }

    /// Première ouverture : en haut à droite de l'écran du pointeur, à gauche des places des autres frises sur cet
    /// écran, masquées comprises, pour que rien ne se recouvre quand elles reviennent (voir `PanelPlacement`). Une
    /// capture de mise au point ignore le pointeur : elle se fait sur l'écran principal, le même d'une fois à l'autre.
    private func placeTopRight(_ panel: NSPanel) {
        let screens = NSScreen.screens.map { PanelPlacement.Screen(frame: $0.frame, visibleFrame: $0.visibleFrame) }
        let capturing = tracker?.model?.options.snapshotDirectory != nil
        let occupied = (tracker?.model?.trackers ?? []).filter { $0 !== tracker }.compactMap(\.knownPanelFrame)
        guard let origin = PanelPlacement.topRight(size: panel.frame.size,
                                                   mouse: capturing ? nil : NSEvent.mouseLocation, screens: screens,
                                                   fallback: NSScreen.screens.first?.visibleFrame,
                                                   occupied: occupied) else {
            panel.center()
            return
        }
        panel.setFrameOrigin(origin)
    }
}
