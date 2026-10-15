import AppKit
import Foundation

/// Mise au point (`-snapshotDir <dossier>`) : écrit `frise.png` et `barre-des-menus.png` une fois la feuille de route lue,
/// sans autorisation d'enregistrement d'écran, puisque l'app dessine ses propres fenêtres (modèle : Orchestre).
@MainActor
enum DebugCapture {
    static func run(model: AppModel, directory: String) async {
        try? await Task.sleep(for: .seconds(1))
        switch model.options.appearance {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
        model.showAllPanels()
        try? await Task.sleep(for: .seconds(1.5))
        try? FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        // La principale dans frise.png, les autres dans frise-2.png, frise-3.png… dans l'ordre de la liste.
        let ordered = model.primary.map { primary in [primary] + model.trackers.filter { $0 !== primary } } ?? []
        for (index, tracker) in ordered.enumerated() {
            guard let panel = tracker.panelWindow else { continue }
            // Une fenêtre inactive perd la teinte de son verre : la rendre active avant de la photographier.
            panel.makeKeyAndOrderFront(nil)
            try? await Task.sleep(for: .milliseconds(800))
            write(panel, to: index == 0 ? "\(directory)/frise.png" : "\(directory)/frise-\(index + 1).png")
        }
        writeMenuBarIcon(MenuBarIcon.image(for: model.primaryState), to: "\(directory)/barre-des-menus.png")
        if model.options.quitAfterSnapshot {
            NSApplication.shared.terminate(nil)
            try? await Task.sleep(for: .seconds(2))
            exit(0)
        }
    }

    private static func write(_ window: NSWindow, to path: String) {
        if let image = composited(window), let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
            return
        }
        guard let view = window.contentView?.superview ?? window.contentView,
              let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: bitmap)
        if let data = bitmap.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    /// L'icône sur le fond de fenêtre de l'apparence en cours, au double de sa taille.
    private static func writeMenuBarIcon(_ image: NSImage, to path: String) {
        let size = NSSize(width: image.size.width + 16, height: 26)
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                                            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return }
        bitmap.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSApp.effectiveAppearance.performAsCurrentDrawingAppearance {
            NSColor.windowBackgroundColor.setFill()
            NSRect(origin: .zero, size: size).fill()
            image.draw(in: NSRect(x: 8, y: (size.height - image.size.height) / 2, width: image.size.width, height: image.size.height))
        }
        NSGraphicsContext.restoreGraphicsState()
        if let data = bitmap.representation(using: .png, properties: [:]) {
            try? data.write(to: URL(fileURLWithPath: path))
        }
    }

    /// `CGWindowListCreateImage` sur la seule fenêtre donnée (API marquée obsolète dans le SDK, d'où `dlsym`) ; une
    /// fenêtre de l'app elle-même se capture sans autorisation d'enregistrement d'écran.
    private static func composited(_ window: NSWindow) -> CGImage? {
        typealias Function = @convention(c) (CGRect, UInt32, UInt32, UInt32) -> Unmanaged<CGImage>?
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "CGWindowListCreateImage") else { return nil }
        let create = unsafeBitCast(symbol, to: Function.self)
        // kCGWindowListOptionIncludingWindow ; kCGWindowImageBoundsIgnoreFraming | kCGWindowImageBestResolution.
        return create(.null, 1 << 3, UInt32(window.windowNumber), (1 << 0) | (1 << 3))?.takeRetainedValue()
    }
}
