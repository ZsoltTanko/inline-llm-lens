import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController {
    private let panel: FloatingPanel
    private let viewModel: PanelViewModel
    private let modelStore: ModelStore
    private let settings: SettingsStore

    init(modelStore: ModelStore, registry: ProviderRegistry, settings: SettingsStore) {
        self.modelStore = modelStore
        self.settings = settings
        self.viewModel = PanelViewModel(modelStore: modelStore, registry: registry, settings: settings)
        self.panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: PanelPositioner.defaultSize))

        let host = NSHostingView(rootView: PanelView(viewModel: viewModel, onClose: { [weak self] in
            self?.close()
        }))
        host.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = host
    }

    func present(with bundle: ContextBundle, autoSend: Bool) {
        viewModel.reset(with: bundle)
        PanelPositioner.position(panel: panel)
        panel.orderFrontRegardless()

        if autoSend, !bundle.selectedText.isEmpty, viewModel.canSend {
            viewModel.send()
        }
    }

    func close() {
        viewModel.cancelStreaming()
        panel.orderOut(nil)
    }

    func showPermissionsCheck() {
        let prompted = AccessibilityCapture.requestTrust()
        let alert = NSAlert()
        alert.messageText = prompted
            ? "Accessibility access is enabled."
            : "Accessibility access is required for the global hotkey."
        alert.informativeText = prompted
            ? "Inline LLM Lens can read selected text via the hotkey."
            : "You can still use the right-click Services action without it. Open System Settings → Privacy & Security → Accessibility to enable."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
