import AppKit

enum PanelPositioner {
    static let defaultSize = NSSize(width: 460, height: 380)

    /// Places the panel near the current mouse position, clamped to the active screen.
    static func position(panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) })
            ?? NSScreen.main
        guard let screen else { return }

        let size = panel.frame.size == .zero ? defaultSize : panel.frame.size
        var origin = NSPoint(x: mouse.x + 12, y: mouse.y - size.height - 12)

        let visible = screen.visibleFrame
        if origin.x + size.width > visible.maxX { origin.x = visible.maxX - size.width - 12 }
        if origin.x < visible.minX { origin.x = visible.minX + 12 }
        if origin.y < visible.minY { origin.y = visible.minY + 12 }
        if origin.y + size.height > visible.maxY { origin.y = visible.maxY - size.height - 12 }

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
