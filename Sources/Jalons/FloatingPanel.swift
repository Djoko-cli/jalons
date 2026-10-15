import AppKit
import SwiftUI

/// La frise flottante d'une feuille de route : un panneau toujours au premier plan, sur tous les bureaux, qui n'active
/// pas l'app quand on clique dedans. Sa taille et sa place sont retenues d'un lancement à l'autre, pour chaque spec.
@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private weak var tracker: RoadmapTracker?
    private(set) var window: NSPanel?
    private let frameName: String
    private let fallbackFrameName: String?
    /// Rang de la frise à sa première ouverture : chaque nouvelle frise se pose à gauche de la précédente.
    private let cascadeIndex: Int

    init(tracker: RoadmapTracker, frameName: String, fallbackFrameName: String?, cascadeIndex: Int) {
        self.tracker = tracker
        self.frameName = frameName
        self.fallbackFrameName = fallbackFrameName
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

    func windowWillClose(_ notification: Notification) {
        tracker?.panelVisibilityChanged(false)
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
            if !panel.setFrameUsingName(frameName),
               !(fallbackFrameName.map { panel.setFrameUsingName($0) } ?? false) {
                placeTopRight(panel)
            }
            panel.setFrameAutosaveName(frameName)
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
