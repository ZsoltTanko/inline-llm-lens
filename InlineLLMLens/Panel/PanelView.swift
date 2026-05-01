import SwiftUI
import AppKit

struct PanelView: View {
    @ObservedObject var viewModel: PanelViewModel
    var onClose: () -> Void

    @State private var selectionExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            selectionSection
            Divider()
            responseSection
                .frame(maxHeight: .infinity)
            Divider()
            followUpSection
            Divider()
            diagnosticsFooter
        }
        .background(.ultraThinMaterial)
        .onExitCommand { onClose() }
    }

    private var diagnosticsFooter: some View {
        HStack(spacing: 8) {
            Image(systemName: AccessibilityCapture.isTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .foregroundStyle(AccessibilityCapture.isTrusted ? .green : .orange)
            Text("AX: \(AccessibilityCapture.isTrusted ? "trusted" : "not trusted")")
            Text("· capture: \(viewModel.bundle.captureMethod.rawValue)")
            if let preset = viewModel.selectedPreset {
                Text("· preset: \(preset.name)")
                if let model = viewModel.selectedModel,
                   let effort = PromptBuilder.effectiveReasoningEffort(preset: preset, model: model) {
                    Text("· reasoning: \(effort)")
                }
            }
            if let app = viewModel.bundle.frontmostAppName {
                Text("· from: \(app)")
            }
            Spacer()
        }
        .font(.caption2)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 8) {
            Text("Ask LLM")
                .font(.system(size: 13, weight: .semibold))
            Spacer()
            PresetPicker(presetStore: viewModel.presetStore, selectedID: $viewModel.selectedPresetID, onChange: { viewModel.onPresetChanged() })
                .frame(maxWidth: 160)
            ModelPicker(modelStore: viewModel.modelStore, selectedID: $viewModel.selectedModelID)
                .frame(maxWidth: 160)
            Button {
                AppDelegate.openSettings()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.plain)
            .help("Settings (⌘,)")
            .keyboardShortcut(",", modifiers: [.command])
            Button(action: onClose) { Image(systemName: "xmark.circle.fill") }
                .buttonStyle(.plain)
                .help("Close (Esc)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var selectionSection: some View {
        if !viewModel.bundle.selectedText.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Selected text · via \(viewModel.bundle.captureMethod.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(selectionExpanded ? "Collapse" : "Expand") {
                        selectionExpanded.toggle()
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
                Text(viewModel.bundle.selectedText)
                    .font(.system(size: 12))
                    .lineLimit(selectionExpanded ? nil : 2)
                    .truncationMode(.tail)
                    .textSelection(.enabled)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(emptyStateMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $viewModel.manualSelectedText)
                    .font(.system(size: 12))
                    .frame(minHeight: 56, maxHeight: 96)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(.separator))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }

    private var responseSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let preset = viewModel.selectedPreset, preset.requiresUserInput {
                TextField(
                    preset.userInputPlaceholder ?? "Instruction…",
                    text: $viewModel.userInput,
                    axis: .vertical
                )
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...3)
            }

            if let err = viewModel.lastError {
                Text(err)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(.vertical, 2)
            }

            ScrollView {
                if viewModel.streamingText.isEmpty {
                    if viewModel.isStreaming {
                        ProgressView().controlSize(.small)
                            .padding(.top, 8)
                    } else {
                        Text("Press Send to ask.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    MarkdownResponseView(text: viewModel.streamingText)
                        .padding(.vertical, 2)
                }
            }

            HStack {
                Button("Send") { viewModel.send() }
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!viewModel.canSend || viewModel.isStreaming)
                if viewModel.isStreaming {
                    Button("Stop") { viewModel.cancelStreaming() }
                }
                Spacer()
                Button {
                    copyResponse()
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .disabled(viewModel.streamingText.isEmpty)
                .keyboardShortcut("c", modifiers: [.command])
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var followUpSection: some View {
        HStack(spacing: 8) {
            TextField("Follow up…", text: $viewModel.followUpInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit { viewModel.sendFollowUp() }
            Button("Send") { viewModel.sendFollowUp() }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(viewModel.followUpInput.trimmingCharacters(in: .whitespaces).isEmpty || viewModel.isStreaming)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var emptyStateMessage: String {
        if !AccessibilityCapture.isTrusted {
            return "Accessibility access is not granted — the hotkey can't read selected text. Open Settings → Permissions to grant it, then quit and relaunch the app. You can still type or paste text below."
        }
        return "No selection detected. Type or paste text below."
    }

    private func copyResponse() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(viewModel.streamingText, forType: .string)
    }
}
