import SwiftUI

struct ResponseSettingsView: View {
    @AppStorage(SettingsStore.Keys.streamResponses) private var stream: Bool = true
    @AppStorage(SettingsStore.Keys.responseLength) private var lengthRaw: String = SettingsStore.ResponseLength.normal.rawValue
    @AppStorage(SettingsStore.Keys.translateTargetLanguage) private var translateTarget: String = "English"
    @AppStorage(SettingsStore.Keys.historyEnabled) private var historyEnabled: Bool = false

    var body: some View {
        Form {
            Section("Streaming") {
                Toggle("Stream responses", isOn: $stream)
            }

            Section("Length preference") {
                Picker("Response length", selection: $lengthRaw) {
                    ForEach(SettingsStore.ResponseLength.allCases) { l in
                        Text(l.displayName).tag(l.rawValue)
                    }
                }
            }

            Section("Translate") {
                TextField("Default target language", text: $translateTarget)
            }

            Section("History") {
                Toggle("Keep local history (off by default)", isOn: $historyEnabled)
                Text("History is stored only on this Mac. No sync, no analytics.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
