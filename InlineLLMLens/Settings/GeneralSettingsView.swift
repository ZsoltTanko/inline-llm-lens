import SwiftUI
import KeyboardShortcuts

struct GeneralSettingsView: View {
    @ObservedObject private var settings = SettingsStore.shared
    @AppStorage(SettingsStore.Keys.autoSendOnInvocation) private var autoSend: Bool = true
    @AppStorage(SettingsStore.Keys.streamResponses) private var streamResponses: Bool = true
    @AppStorage(SettingsStore.Keys.historyEnabled) private var historyEnabled: Bool = false
    @AppStorage(SettingsStore.Keys.launchAtLogin) private var launchAtLogin: Bool = false
    @AppStorage(SettingsStore.Keys.panelFontSize) private var panelFontSize: Double = SettingsStore.defaultPanelFontSize
    @AppStorage(SettingsStore.Keys.panelClickOffBehavior) private var clickOffBehaviorRaw: String = SettingsStore.PanelClickOffBehavior.stayOnTop.rawValue
    @AppStorage(SettingsStore.Keys.panelPlacement) private var panelPlacementRaw: String = SettingsStore.PanelPlacement.nearMouse.rawValue

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

            Section("Appearance") {
                HStack {
                    Text("Panel font size")
                    Slider(
                        value: $panelFontSize,
                        in: SettingsStore.panelFontSizeRange,
                        step: 1
                    )
                    Text("\(Int(panelFontSize)) pt")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
                Text("Default \(Int(SettingsStore.defaultPanelFontSize)) pt. Affects the response text in the floating panel.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Window behaviour") {
                Picker("Panel placement on invocation", selection: Binding(
                    get: {
                        SettingsStore.PanelPlacement(rawValue: panelPlacementRaw) ?? .nearMouse
                    },
                    set: { newValue in
                        panelPlacementRaw = newValue.rawValue
                    }
                )) {
                    ForEach(SettingsStore.PanelPlacement.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }

                Picker("When clicking outside the panel", selection: Binding(
                    get: {
                        SettingsStore.PanelClickOffBehavior(rawValue: clickOffBehaviorRaw) ?? .stayOnTop
                    },
                    set: { newValue in
                        clickOffBehaviorRaw = newValue.rawValue
                    }
                )) {
                    ForEach(SettingsStore.PanelClickOffBehavior.allCases) { option in
                        Text(option.label).tag(option)
                    }
                }
                Text("Stay on top keeps the panel above other windows until you press Esc or close it. Recede to background behaves like a normal Mac window. Close dismisses the panel on click-off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
