import AppKit
import SwiftUI

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
    /// Rang de la frise à sa première ouverture : chaque nouvelle frise se pose à gauche de la précédente.
    private let cascadeIndex: Int

    init(tracker: RoadmapTracker, frameName: String, fallbackFrameNames: [String], remembersFrame: Bool,
         cascadeIndex: Int) {
        self.tracker = tracker
        self.frameName = frameName
        self.fallbackFrameNames = fallbackFrameNames
        self.remembersFrame = remembersFrame
        self.cascadeIndex = cascadeIndex
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

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 360, height: 660),
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

    /// Première ouverture : en haut à droite de l'écran principal, à gauche des frises ouvertes avant elle.
    private func placeTopRight(_ panel: NSPanel) {
        guard let visible = NSScreen.main?.visibleFrame else {
            panel.center()
            return
        }
        let step = panel.frame.width + 16
        let x = max(visible.minX + 16, visible.maxX - step - CGFloat(cascadeIndex) * step)
        panel.setFrameOrigin(NSPoint(x: x, y: visible.maxY - panel.frame.height - 16))
    }
}
