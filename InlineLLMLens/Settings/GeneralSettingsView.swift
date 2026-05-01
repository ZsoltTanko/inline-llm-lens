import SwiftUI
import KeyboardShortcuts

struct GeneralSettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @AppStorage(SettingsStore.Keys.autoSendOnInvocation) private var autoSend: Bool = true
    @AppStorage(SettingsStore.Keys.streamResponses) private var streamResponses: Bool = true
    @AppStorage(SettingsStore.Keys.historyEnabled) private var historyEnabled: Bool = false
    @AppStorage(SettingsStore.Keys.launchAtLogin) private var launchAtLogin: Bool = false

    var body: some View {
        Form {
            Section("Invocation") {
                KeyboardShortcuts.Recorder("Global hotkey", name: .invokePanel)
                Toggle("Auto-send when invoked with selected text", isOn: $autoSend)
                Text("Per-preset hotkeys are configured in the Prompts tab.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Response") {
                Toggle("Stream responses", isOn: $streamResponses)
            }

            Section("History") {
                Toggle("Keep local history (off by default)", isOn: $historyEnabled)
                Text("History is stored only on this Mac. No sync, no analytics. Each entry snapshots the resolved system prompt and user message so editing presets later does not rewrite history.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
