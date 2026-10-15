import AppKit
import SwiftUI

/// La frise flottante : un panneau toujours au premier plan, sur tous les bureaux, qui n'active pas l'app quand on
/// clique dedans. Sa taille et sa place sont retenues d'un lancement à l'autre.
@MainActor
final class FloatingPanelController: NSObject, NSWindowDelegate {
    private weak var model: AppModel?
    private(set) var window: NSPanel?
    private static let frameName = "JalonsFrise"

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        let panel = window ?? makePanel()
        window = panel
        panel.orderFrontRegardless()
        model?.panelVisibilityChanged(true)
    }

    func hide() {
        window?.orderOut(nil)
        model?.panelVisibilityChanged(false)
    }

    func windowWillClose(_ notification: Notification) {
        model?.panelVisibilityChanged(false)
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
        if let model {
            panel.contentView = NSHostingView(rootView: TimelineView().environment(model))
        }
        // Les captures de mise au point ne touchent pas à la taille et à la place retenues.
        if model?.options.snapshotDirectory != nil {
            placeTopRight(panel)
        } else {
            if !panel.setFrameUsingName(Self.frameName) { placeTopRight(panel) }
            panel.setFrameAutosaveName(Self.frameName)
        }
        return panel
    }

    /// Première ouverture : en haut à droite de l'écran principal.
    private func placeTopRight(_ panel: NSPanel) {
        guard let visible = NSScreen.main?.visibleFrame else {
            panel.center()
            return
        }
        panel.setFrameOrigin(NSPoint(x: visible.maxX - panel.frame.width - 16, y: visible.maxY - panel.frame.height - 16))
    }
}
