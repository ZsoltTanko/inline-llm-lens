import SwiftUI
import KeyboardShortcuts

struct GeneralSettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @AppStorage(SettingsStore.Keys.autoSendOnInvocation) private var autoSend: Bool = true
    @AppStorage(SettingsStore.Keys.launchAtLogin) private var launchAtLogin: Bool = false
    @AppStorage(SettingsStore.Keys.defaultPromptMode) private var defaultModeRaw: String = PromptMode.explain.rawValue

    var body: some View {
        Form {
            Section("Invocation") {
                KeyboardShortcuts.Recorder("Global hotkey", name: .invokePanel)
                Toggle("Auto-send when invoked with selected text", isOn: $autoSend)
            }

            Section("Defaults") {
                Picker("Default prompt mode", selection: $defaultModeRaw) {
                    ForEach(PromptMode.allCases) { m in
                        Text(m.displayName).tag(m.rawValue)
                    }
                }
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: Binding(
                    get: { launchAtLogin },
                    set: { newValue in
                        launchAtLogin = newValue
                        settings.launchAtLogin = newValue
                    }
                ))
            }
        }
        .formStyle(.grouped)
    }
}
