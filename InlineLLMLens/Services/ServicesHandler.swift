import AppKit

final class ServicesHandler: NSObject {
    static let shared = ServicesHandler()

    private weak var panelController: FloatingPanelController?
    private var captureService: SelectionCaptureService?
    private var settings: SettingsStore?

    func configure(
        panelController: FloatingPanelController,
        captureService: SelectionCaptureService,
        settings: SettingsStore
    ) {
        self.panelController = panelController
        self.captureService = captureService
        self.settings = settings
    }

    /// Bound to the `NSMessage = askInlineLLM` Service entry in Info.plist.
    @objc func askInlineLLM(_ pasteboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString>) {
        let text = pasteboard.string(forType: .string) ?? ""
        let bundle = ContextBundle(
            selectedText: text,
            frontmostAppName: NSWorkspace.shared.frontmostApplication?.localizedName,
            frontmostWindowTitle: nil,
            captureMethod: .servicesInput,
            timestamp: Date()
        )
        let autoSend = settings?.autoSendOnInvocation ?? false
        DispatchQueue.main.async { [weak self] in
            NSApp.activate(ignoringOtherApps: true)
            self?.panelController?.present(with: bundle, autoSend: autoSend)
        }
    }
}
