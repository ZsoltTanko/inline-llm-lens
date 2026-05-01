import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate!

    let modelStore = ModelStore()
    let settings = SettingsStore.shared
    let registry: ProviderRegistry
    let captureService: SelectionCaptureService
    let panelController: FloatingPanelController

    private var menuBarController: MenuBarController?
    private var hotkeyManager: HotkeyManager?

    override init() {
        self.registry = ProviderRegistry(modelStore: modelStore)
        self.captureService = SelectionCaptureService(settings: settings)
        self.panelController = FloatingPanelController(
            modelStore: modelStore,
            registry: registry,
            settings: settings
        )
        super.init()
        AppDelegate.shared = self
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        menuBarController = MenuBarController(
            onAsk: { [weak self] in self?.invokeFromMenu() },
            onSettings: { Self.openSettings() },
            onPermissions: { [weak self] in self?.panelController.showPermissionsCheck() },
            onQuit: { NSApp.terminate(nil) }
        )

        ServicesHandler.shared.configure(
            panelController: panelController,
            captureService: captureService,
            settings: settings
        )
        NSApp.servicesProvider = ServicesHandler.shared
        NSUpdateDynamicServices()

        hotkeyManager = HotkeyManager { [weak self] in
            self?.invokeFromHotkey()
        }
        hotkeyManager?.start()

        if !settings.hasCompletedOnboarding {
            OnboardingWindow.show()
        }
    }

    func invokeFromHotkey() {
        Task { @MainActor in
            if !AccessibilityCapture.isTrusted {
                AccessibilityCapture.requestTrust()
            }
            let bundle = await captureService.captureForHotkey()
            panelController.present(with: bundle, autoSend: settings.autoSendOnInvocation)
        }
    }

    func invokeFromMenu() {
        Task { @MainActor in
            let bundle = await captureService.captureForHotkey()
            panelController.present(with: bundle, autoSend: false)
        }
    }

    private var settingsCloseObserver: NSObjectProtocol?

    static func openSettings() {
        // SwiftUI's `Settings { }` scene only presents reliably under .regular
        // activation policy, so we briefly switch out of menu-bar-only mode.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.async {
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
            // SwiftUI Settings windows have title "Settings" (or localized) and a known autosave name.
            let isSettings = window.frameAutosaveName.contains("Settings")
                || window.title.localizedCaseInsensitiveContains("settings")
                || window.identifier?.rawValue.contains("Settings") == true
            guard isSettings else { return }
            NSApp.setActivationPolicy(.accessory)
            if let obs = self?.settingsCloseObserver {
                NotificationCenter.default.removeObserver(obs)
                self?.settingsCloseObserver = nil
            }
        }
    }
}
