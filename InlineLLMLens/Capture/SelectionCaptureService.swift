import AppKit

/// Orchestrates the capture strategies in priority order for the hotkey path.
/// The Services path bypasses this and constructs its own bundle directly.
final class SelectionCaptureService {
    private let settings: SettingsStore

    init(settings: SettingsStore) {
        self.settings = settings
    }

    /// Tries Accessibility, then optional clipboard fallback, then returns an empty manual bundle.
    func captureForHotkey() async -> ContextBundle {
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName
        let windowTitle = AccessibilityCapture.frontmostWindowTitle()

        if let text = AccessibilityCapture.selectedText() {
            return ContextBundle(
                selectedText: text,
                frontmostAppName: appName,
                frontmostWindowTitle: windowTitle,
                captureMethod: .accessibility,
                timestamp: Date()
            )
        }

        if settings.clipboardFallbackEnabled {
            if let text = await ClipboardFallbackCapture.capture(restore: settings.restoreClipboardAfterCapture) {
                return ContextBundle(
                    selectedText: text,
                    frontmostAppName: appName,
                    frontmostWindowTitle: windowTitle,
                    captureMethod: .clipboardFallback,
                    timestamp: Date()
                )
            }
        }

        return ContextBundle(
            selectedText: "",
            frontmostAppName: appName,
            frontmostWindowTitle: windowTitle,
            captureMethod: .manualInput,
            timestamp: Date()
        )
    }
}
