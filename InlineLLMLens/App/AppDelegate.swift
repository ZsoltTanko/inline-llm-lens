import AppKit
import SwiftUI
import KeyboardShortcuts
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!

    let modelStore = ModelStore()
    let presetStore = PromptPresetStore()
    let settings = SettingsStore.shared
    let registry: ProviderRegistry
    let captureService: SelectionCaptureService
    let panelController: FloatingPanelController

    private var menuBarController: MenuBarController?
    private var hotkeyManager: HotkeyManager?
    private var presetCancellable: AnyCancellable?

    override init() {
        self.registry = ProviderRegistry(modelStore: modelStore)
        self.captureService = SelectionCaptureService(settings: settings)
        self.panelController = FloatingPanelController(
            modelStore: modelStore,
            presetStore: presetStore,
            registry: registry,
            settings: settings
        )
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        rebuildMenuBar()
        // Rebuild the menu bar's "Prompt presets" submenu whenever the catalog changes.
        presetCancellable = presetStore.$presets
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.rebuildMenuBar()
                self?.registerPerPresetHotkeys()
            }

        ServicesHandler.shared.configure(
            panelController: panelController,
            captureService: captureService,
            settings: settings
        )
        NSApp.servicesProvider = ServicesHandler.shared
        NSUpdateDynamicServices()

        hotkeyManager = HotkeyManager(
            onInvoke: { [weak self] in self?.invokeFromHotkey(preset: nil) },
            onInvokePreset: { [weak self] preset in self?.invokeFromHotkey(preset: preset) }
        )
        hotkeyManager?.start()
        registerPerPresetHotkeys()

        if !settings.hasCompletedOnboarding {
            OnboardingWindow.show()
        }
    }

    private func rebuildMenuBar() {
        menuBarController = MenuBarController(
            presetStore: presetStore,
            onAsk: { [weak self] in self?.invokeFromMenu(preset: nil) },
            onAskWithPreset: { [weak self] preset in self?.invokeFromMenu(preset: preset) },
            onSettings: { Self.openSettings() },
            onPermissions: { [weak self] in self?.panelController.showPermissionsCheck() },
            onQuit: { NSApp.terminate(nil) }
        )
    }

    private func registerPerPresetHotkeys() {
        hotkeyManager?.syncPresetHotkeys(presets: presetStore.presets) { [weak self] preset in
            self?.invokeFromHotkey(preset: preset)
        }
    }

    func invokeFromHotkey(preset: PromptPreset?) {
        Task { @MainActor in
            if !AccessibilityCapture.isTrusted {
                AccessibilityCapture.requestTrust()
            }
            let bundle = await captureService.captureForHotkey()
            // For the global "ask" hotkey, fall back to the legacy auto-send
            // setting; for per-preset hotkeys, the preset's own flag wins.
            if let preset {
                panelController.present(with: bundle, preset: preset, autoSendOverride: nil)
            } else {
                panelController.present(with: bundle, autoSend: settings.autoSendOnInvocation)
            }
        }
    }

    func invokeFromMenu(preset: PromptPreset?) {
        Task { @MainActor in
            let bundle = await captureService.captureForHotkey()
            panelController.present(with: bundle, preset: preset ?? presetStore.defaultPreset, autoSendOverride: false)
        }
    }

    private var settingsCloseObserver: NSObjectProtocol?

    static func openSettings() {
        // SwiftUI's `Settings { }` scene only presents reliably under .regular
        // activation policy, so we briefly switch out of menu-bar-only mode.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        // The floating panel sits at .floating level and would occlude the
        // Settings window. Hide it so Settings is actually visible.
        shared.panelController.close()

        // Delay so the policy switch + status-menu dismissal can settle before
        // we dispatch the action; otherwise Settings can fail to present.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if #available(macOS 14.0, *) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            } else {
                NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
            }
            shared.observeSettingsCloseOnce()
        }
    }

    private func observeSettingsCloseOnce() {
        guard settingsCloseObserver == nil else { return }
        settingsCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let window = note.object as? NSWindow else { return }
            let titleLooksLikeSettings = window.frameAutosaveName.contains("Settings")
                || window.title.localizedCaseInsensitiveContains("settings")
                || window.identifier?.rawValue.contains("Settings") == true
            let isOurFloatingPanel = window is FloatingPanel
            guard titleLooksLikeSettings || !isOurFloatingPanel else { return }
            DispatchQueue.main.async {
                let stillHasVisibleSettings = NSApp.windows.contains { w in
                    guard w.isVisible, !(w is FloatingPanel) else { return false }
                    return w.frameAutosaveName.contains("Settings")
                        || w.title.localizedCaseInsensitiveContains("settings")
                        || w.identifier?.rawValue.contains("Settings") == true
                }
                guard !stillHasVisibleSettings else { return }
                NSApp.setActivationPolicy(.accessory)
                if let obs = self?.settingsCloseObserver {
                    NotificationCenter.default.removeObserver(obs)
                    self?.settingsCloseObserver = nil
                }
            }
        }
    }
}
