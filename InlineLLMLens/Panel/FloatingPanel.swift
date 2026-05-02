import AppKit

/// Borderless `NSPanel` styled as a slim, chromeless floating surface.
///
/// We deliberately drop `.titled` (and therefore the macOS traffic-light
/// buttons) — every vertical pixel matters in the panel and the title row
/// added nothing useful. The panel is still draggable by background and
/// resizable by edge, becomes key for typing/Esc, and renders its own
/// rounded ultra-thin-material chrome from SwiftUI.
final class FloatingPanel: NSPanel {
    /// Invoked when the panel receives `cancelOperation(_:)` (Esc, via the
    /// responder chain). Handled at the `NSPanel` level so Esc works
    /// regardless of which SwiftUI view inside the hosting view is focused —
    /// otherwise Esc only fires when a `TextField` is first responder.
    var onCancel: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.borderless, .resizable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isFloatingPanel = true
        level = .floating
        becomesKeyOnlyIfNeeded = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isMovableByWindowBackground = true
        isReleasedWhenClosed = false
        animationBehavior = .utilityWindow

        // Transparent window so the SwiftUI rounded background shows through.
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Esc key. We intentionally don't call `super` — the default
    /// implementation walks further up the responder chain and, finding
    /// nothing, produces the "not valid" system beep.
    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
