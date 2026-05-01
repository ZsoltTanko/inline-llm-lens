import SwiftUI

struct ModePicker: View {
    @Binding var mode: PromptMode

    var body: some View {
        Picker("Mode", selection: $mode) {
            ForEach(PromptMode.allCases) { m in
                Text(m.displayName).tag(m)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
    }
}
