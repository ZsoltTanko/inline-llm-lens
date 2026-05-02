import AppKit
import SwiftUI
import Combine

@MainActor
final class FloatingPanelController {
    private let panel: FloatingPanel
    private let viewModel: PanelViewModel
    private let modelStore: ModelStore
    private let presetStore: PromptPresetStore
    private let settings: SettingsStore

    private var resignKeyObserver: NSObjectProtocol?
    private var becomeKeyObserver: NSObjectProtocol?
    private var defaultsObserver: NSObjectProtocol?
    private var settingsCancellable: AnyCancellable?

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

        // Esc at the panel (NSPanel) level, so it works regardless of which
        // SwiftUI subview holds focus. Collapses the follow-up bar first if
        // open, otherwise closes the panel.
        panel.onCancel = { [weak self] in
            guard let self else { return }
            if self.viewModel.isFollowUpOpen {
                self.viewModel.closeFollowUp()
            } else {
                self.close()
            }
        }

        // ⌘C with no active text selection → copy the full response.
        // See `FloatingPanel.performKeyEquivalent(with:)`.
        panel.onCopyFallback = { [weak self] in
            guard let self else { return }
            let text = self.viewModel.streamingText
            guard !text.isEmpty else { return }
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(text, forType: .string)
        }

        resignKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            // Hop through the runloop so `NSApp.keyWindow` is settled before
            // we inspect it. Without this, keyWindow can still be us.
            DispatchQueue.main.async { self?.handleResignKey() }
        }

        becomeKeyObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: panel,
            queue: .main
        ) { [weak self] _ in
            self?.applyCurrentLevel()
        }

        // React to live changes of the click-off behaviour setting. Covers
        // both direct `SettingsStore` setters and `@AppStorage` writes made
        // from `GeneralSettingsView` (the latter only emits the UserDefaults
        // notification).
        settingsCancellable = settings.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyCurrentLevel()
            }
        defaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.applyCurrentLevel()
        }
    }

    deinit {
        if let o = resignKeyObserver { NotificationCenter.default.removeObserver(o) }
        if let o = becomeKeyObserver { NotificationCenter.default.removeObserver(o) }
        if let o = defaultsObserver { NotificationCenter.default.removeObserver(o) }
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
        PanelPositioner.position(panel: panel, placement: settings.panelPlacement)
        applyCurrentLevel()
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

    // MARK: - Click-off behaviour

    /// Apply `panel.level` based on the current setting. Called on present,
    /// on `didBecomeKey`, and whenever `SettingsStore` changes.
    private func applyCurrentLevel() {
        guard panel.isVisible else {
            panel.level = settings.panelClickOffBehavior == .stayOnTop ? .floating : .normal
            return
        }
        switch settings.panelClickOffBehavior {
        case .stayOnTop, .closePanel:
            // `.closePanel` panels are still "on top" while they're alive —
            // we dismiss them on resignKey rather than letting them recede.
            panel.level = .floating
        case .sendToBack:
            panel.level = .normal
        }
    }

    private func handleResignKey() {
        guard panel.isVisible else { return }

        // If another window of our app (Settings, Onboarding, an alert) is
        // now key, never dismiss or recede — `NSApp.keyWindow` only returns
        // windows belonging to us, so a non-nil, non-panel value means a
        // sibling window took focus and the panel should coexist with it.
        if let key = NSApp.keyWindow, key !== panel { return }

        switch settings.panelClickOffBehavior {
        case .stayOnTop:
            return
        case .sendToBack:
            panel.level = .normal
        case .closePanel:
            close()
        }
    }
}
