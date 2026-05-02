import Foundation
import Combine
import SwiftUI

/// Single source of truth for user preferences. Backed by `UserDefaults` so
/// SwiftUI views can also bind directly via `@AppStorage(SettingsStore.Keys.*)`.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    enum Keys {
        static let autoSendOnInvocation = "settings.autoSendOnInvocation"
        static let streamResponses = "settings.streamResponses"
        static let clipboardFallbackEnabled = "settings.clipboardFallbackEnabled"
        static let restoreClipboardAfterCapture = "settings.restoreClipboardAfterCapture"
        static let historyEnabled = "settings.historyEnabled"
        static let launchAtLogin = "settings.launchAtLogin"
        static let hasCompletedOnboarding = "settings.hasCompletedOnboarding"
        static let showMenuBarIcon = "settings.showMenuBarIcon"
        static let panelFontSize = "settings.panelFontSize"
    }

    /// Default body font size for the response area. Tuned for power-user
    /// glanceability — small enough to fit a paragraph at a glance, large
    /// enough to stay readable. User-overridable in Settings → General.
    static let defaultPanelFontSize: Double = 13
    static let panelFontSizeRange: ClosedRange<Double> = 11...18

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.autoSendOnInvocation: true,
            Keys.streamResponses: true,
            Keys.clipboardFallbackEnabled: true,
            Keys.restoreClipboardAfterCapture: true,
            Keys.historyEnabled: false,
            Keys.launchAtLogin: false,
            Keys.hasCompletedOnboarding: false,
            Keys.showMenuBarIcon: true,
            Keys.panelFontSize: SettingsStore.defaultPanelFontSize
        ])
    }

    // MARK: - Typed accessors

    var autoSendOnInvocation: Bool {
        get { defaults.bool(forKey: Keys.autoSendOnInvocation) }
        set { defaults.set(newValue, forKey: Keys.autoSendOnInvocation); objectWillChange.send() }
    }

    var streamResponses: Bool {
        get { defaults.bool(forKey: Keys.streamResponses) }
        set { defaults.set(newValue, forKey: Keys.streamResponses); objectWillChange.send() }
    }

    var clipboardFallbackEnabled: Bool {
        get { defaults.bool(forKey: Keys.clipboardFallbackEnabled) }
        set { defaults.set(newValue, forKey: Keys.clipboardFallbackEnabled); objectWillChange.send() }
    }

    var restoreClipboardAfterCapture: Bool {
        get { defaults.bool(forKey: Keys.restoreClipboardAfterCapture) }
        set { defaults.set(newValue, forKey: Keys.restoreClipboardAfterCapture); objectWillChange.send() }
    }

    var historyEnabled: Bool {
        get { defaults.bool(forKey: Keys.historyEnabled) }
        set { defaults.set(newValue, forKey: Keys.historyEnabled); objectWillChange.send() }
    }

    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set {
            defaults.set(newValue, forKey: Keys.launchAtLogin)
            LaunchAtLogin.set(enabled: newValue)
            objectWillChange.send()
        }
    }

    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding); objectWillChange.send() }
    }

    var showMenuBarIcon: Bool {
        get { defaults.bool(forKey: Keys.showMenuBarIcon) }
        set { defaults.set(newValue, forKey: Keys.showMenuBarIcon); objectWillChange.send() }
    }

    var panelFontSize: Double {
        get {
            let v = defaults.double(forKey: Keys.panelFontSize)
            return v == 0 ? SettingsStore.defaultPanelFontSize : v
        }
        set { defaults.set(newValue, forKey: Keys.panelFontSize); objectWillChange.send() }
    }
}
