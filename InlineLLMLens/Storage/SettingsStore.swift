import Foundation
import Combine
import SwiftUI

/// Single source of truth for user preferences. Backed by `UserDefaults` so
/// SwiftUI views can also bind directly via `@AppStorage(SettingsStore.Keys.*)`.
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    enum ResponseLength: String, Codable, CaseIterable, Identifiable {
        case concise, normal, detailed
        var id: String { rawValue }
        var displayName: String {
            switch self {
            case .concise: return "Concise"
            case .normal: return "Normal"
            case .detailed: return "Detailed"
            }
        }
    }

    enum Keys {
        static let defaultPromptMode = "settings.defaultPromptMode"
        static let autoSendOnInvocation = "settings.autoSendOnInvocation"
        static let streamResponses = "settings.streamResponses"
        static let responseLength = "settings.responseLength"
        static let translateTargetLanguage = "settings.translateTargetLanguage"
        static let clipboardFallbackEnabled = "settings.clipboardFallbackEnabled"
        static let restoreClipboardAfterCapture = "settings.restoreClipboardAfterCapture"
        static let includeAppContext = "settings.includeAppContext"
        static let historyEnabled = "settings.historyEnabled"
        static let launchAtLogin = "settings.launchAtLogin"
        static let hasCompletedOnboarding = "settings.hasCompletedOnboarding"
        static let showMenuBarIcon = "settings.showMenuBarIcon"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.defaultPromptMode: PromptMode.explain.rawValue,
            Keys.autoSendOnInvocation: true,
            Keys.streamResponses: true,
            Keys.responseLength: ResponseLength.normal.rawValue,
            Keys.translateTargetLanguage: "English",
            Keys.clipboardFallbackEnabled: false,
            Keys.restoreClipboardAfterCapture: true,
            Keys.includeAppContext: true,
            Keys.historyEnabled: false,
            Keys.launchAtLogin: false,
            Keys.hasCompletedOnboarding: false,
            Keys.showMenuBarIcon: true
        ])
    }

    // MARK: - Typed accessors

    var defaultPromptMode: PromptMode {
        get { PromptMode(rawValue: defaults.string(forKey: Keys.defaultPromptMode) ?? "") ?? .explain }
        set { defaults.set(newValue.rawValue, forKey: Keys.defaultPromptMode); objectWillChange.send() }
    }

    var autoSendOnInvocation: Bool {
        get { defaults.bool(forKey: Keys.autoSendOnInvocation) }
        set { defaults.set(newValue, forKey: Keys.autoSendOnInvocation); objectWillChange.send() }
    }

    var streamResponses: Bool {
        get { defaults.bool(forKey: Keys.streamResponses) }
        set { defaults.set(newValue, forKey: Keys.streamResponses); objectWillChange.send() }
    }

    var responseLength: ResponseLength {
        get { ResponseLength(rawValue: defaults.string(forKey: Keys.responseLength) ?? "") ?? .normal }
        set { defaults.set(newValue.rawValue, forKey: Keys.responseLength); objectWillChange.send() }
    }

    var translateTargetLanguage: String {
        get { defaults.string(forKey: Keys.translateTargetLanguage) ?? "English" }
        set { defaults.set(newValue, forKey: Keys.translateTargetLanguage); objectWillChange.send() }
    }

    var clipboardFallbackEnabled: Bool {
        get { defaults.bool(forKey: Keys.clipboardFallbackEnabled) }
        set { defaults.set(newValue, forKey: Keys.clipboardFallbackEnabled); objectWillChange.send() }
    }

    var restoreClipboardAfterCapture: Bool {
        get { defaults.bool(forKey: Keys.restoreClipboardAfterCapture) }
        set { defaults.set(newValue, forKey: Keys.restoreClipboardAfterCapture); objectWillChange.send() }
    }

    var includeAppContext: Bool {
        get { defaults.bool(forKey: Keys.includeAppContext) }
        set { defaults.set(newValue, forKey: Keys.includeAppContext); objectWillChange.send() }
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
}
