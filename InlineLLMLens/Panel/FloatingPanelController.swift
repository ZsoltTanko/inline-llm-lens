import AppKit
import SwiftUI

@MainActor
final class FloatingPanelController {
    private let panel: FloatingPanel
    private let viewModel: PanelViewModel
    private let modelStore: ModelStore
    private let presetStore: PromptPresetStore
    private let settings: SettingsStore

    init(modelStore: ModelStore, presetStore: PromptPresetStore, registry: ProviderRegistry, settings: SettingsStore) {
        self.modelStore = modelStore
        self.presetStore = presetStore
        self.settings = settings
        self.viewModel = PanelViewModel(modelStore: modelStore, presetStore: presetStore, registry: registry, settings: settings)
        self.panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: PanelPositioner.defaultSize))

        let host = NSHostingView(rootView: PanelView(viewModel: viewModel, onClose: { [weak self] in
            self?.close()
        }))
        host.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = host
    }

    /// Present with the default preset.
    func present(with bundle: ContextBundle, autoSend: Bool) {
        present(with: bundle, preset: presetStore.defaultPreset, autoSendOverride: autoSend)
    }

    /// Present pre-bound to a specific preset (used by per-preset hotkeys and
    /// the status-bar submenu). When `autoSendOverride` is nil, the preset's
    /// own `autoSend` flag wins.
    func present(with bundle: ContextBundle, preset: PromptPreset?, autoSendOverride: Bool? = nil) {
        viewModel.reset(with: bundle, presetOverride: preset)
        PanelPositioner.position(panel: panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)

        let shouldAutoSend: Bool
        if let override = autoSendOverride {
            shouldAutoSend = override && (preset?.autoSend ?? true)
        } else {
            shouldAutoSend = preset?.autoSend ?? false
        }
        if shouldAutoSend, viewModel.canSend {
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
