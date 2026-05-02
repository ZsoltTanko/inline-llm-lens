import SwiftUI
import AppKit

/// The floating panel UI. Designed for power users who fire on selected text,
/// glance at the response, and hit Esc. Everything that isn't the response
/// either hides or shrinks.
///
/// Layout, top to bottom:
///   - Slim header (preset chip · model chip · status dot · gear · ✕)
///   - Single-line collapsed selection preview (click to expand)
///   - Response area (the star — fills available space, Markdown rendered)
///   - Inline error pill (only when there's an error)
///   - Optional follow-up bar (hidden by default, ⌘L or click to reveal)
struct PanelView: View {
    @ObservedObject var viewModel: PanelViewModel
    @ObservedObject private var settings = SettingsStore.shared
    var onClose: () -> Void

    @State private var selectionExpanded: Bool = false
    @FocusState private var followUpFocused: Bool
    @FocusState private var userInputFocused: Bool
    @State private var copyHover: Bool = false

    private var fontSize: CGFloat { CGFloat(settings.panelFontSize) }

    var body: some View {
        VStack(spacing: 0) {
            header
            selectionPreview
            responseArea
            errorBar
            followUpBar
        }
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        // Fallback for when a SwiftUI `TextField` is first responder.
        // The primary Esc handler lives on `FloatingPanel.cancelOperation`
        // so it works even when no SwiftUI view is focused.
        .onExitCommand {
            if viewModel.isFollowUpOpen {
                viewModel.closeFollowUp()
            } else {
                onClose()
            }
        }
        // Keyboard affordance to reveal the follow-up bar without clicking.
        .background(
            Button("") { showFollowUp() }
                .keyboardShortcut("l", modifiers: [.command])
                .opacity(0)
                .accessibilityHidden(true)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 6) {
            chipPreset
            chipModel
            Spacer(minLength: 4)
            statusDot
            iconButton(system: "gearshape", help: "Settings (⌘,)") {
                AppDelegate.openSettings()
            }
            .keyboardShortcut(",", modifiers: [.command])
            iconButton(system: "xmark", help: "Close (Esc)", onClick: onClose)
        }
        .padding(.horizontal, 10)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .contentShape(Rectangle())
    }

    private var chipPreset: some View {
        PresetPicker(
            presetStore: viewModel.presetStore,
            selectedID: $viewModel.selectedPresetID,
            onChange: { viewModel.onPresetChanged() }
        )
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
        .controlSize(.small)
    }

    private var chipModel: some View {
        ModelPicker(modelStore: viewModel.modelStore, selectedID: $viewModel.selectedModelID)
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()
            .controlSize(.small)
    }

    @ViewBuilder
    private var statusDot: some View {
        if !AccessibilityCapture.isTrusted {
            Circle()
                .fill(Color.orange)
                .frame(width: 6, height: 6)
                .help("Accessibility access not granted — the global hotkey can't read selected text. Open Settings → Permissions.")
                .padding(.trailing, 2)
        } else {
            EmptyView()
        }
    }

    private func iconButton(system: String, help: String, onClick: @escaping () -> Void) -> some View {
        Button(action: onClick) {
            Image(systemName: system)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 18, height: 18)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Selection preview

    @ViewBuilder
    private var selectionPreview: some View {
        if !viewModel.bundle.selectedText.isEmpty {
            Button {
                selectionExpanded.toggle()
            } label: {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: selectionExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                    Text(viewModel.bundle.selectedText)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(selectionExpanded ? nil : 1)
                        .truncationMode(.tail)
                        .multilineTextAlignment(.leading)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.04))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } else if !AccessibilityCapture.isTrusted || viewModel.manualSelectedText.isEmpty {
            // No selection captured and either AX denied or the user hasn't
            // typed anything yet — give them a tiny inline editor.
            VStack(alignment: .leading, spacing: 2) {
                Text(emptyStateMessage)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                TextField("Type or paste text…", text: $viewModel.manualSelectedText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .lineLimit(1...4)
                    .focused($userInputFocused)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }

    // MARK: - Response

    private var responseArea: some View {
        ZStack(alignment: .topTrailing) {
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    if let preset = viewModel.selectedPreset, preset.requiresUserInput {
                        TextField(
                            preset.userInputPlaceholder ?? "Instruction…",
                            text: $viewModel.userInput,
                            axis: .vertical
                        )
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...3)
                        .font(.system(size: fontSize))
                    }

                    if viewModel.streamingText.isEmpty {
                        if viewModel.isStreaming {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.top, 4)
                        } else {
                            emptyResponsePlaceholder
                        }
                    } else {
                        MarkdownResponseView(text: viewModel.streamingText, fontSize: fontSize)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)

            // Floating action overlay — Send/Stop only when meaningful.
            // Copy on hover, top-right. Keeps the canvas clean by default.
            HStack(spacing: 4) {
                if viewModel.isStreaming {
                    smallPill(label: "Stop", system: "stop.fill") {
                        viewModel.cancelStreaming()
                    }
                }
                if !viewModel.streamingText.isEmpty {
                    Button {
                        copyResponse()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(copyHover ? .primary : .secondary)
                            .frame(width: 22, height: 22)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(copyHover ? Color.primary.opacity(0.08) : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Copy response (⌘C)")
                    .keyboardShortcut("c", modifiers: [.command])
                    .onHover { copyHover = $0 }
                }
            }
            .padding(.top, 6)
            .padding(.trailing, 8)
        }
        // Hidden ⌘↵ shortcut so Cmd+Return always sends, even with no visible button.
        .background(
            Button("") { viewModel.send() }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!viewModel.canSend || viewModel.isStreaming)
                .opacity(0)
                .accessibilityHidden(true)
        )
    }

    @ViewBuilder
    private var emptyResponsePlaceholder: some View {
        HStack(spacing: 6) {
            Button {
                viewModel.send()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .medium))
                    Text("Ask")
                        .font(.system(size: 11, weight: .medium))
                    Text("⌘↵")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.06))
                )
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canSend)
        }
        .padding(.top, 4)
    }

    private func smallPill(label: String, system: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: system).font(.system(size: 9, weight: .medium))
                Text(label).font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.primary.opacity(0.08))
            )
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Error

    @ViewBuilder
    private var errorBar: some View {
        if let err = viewModel.lastError {
            Text(err)
                .font(.system(size: 11))
                .foregroundStyle(.red)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.red.opacity(0.08))
        }
    }

    // MARK: - Follow-up (hidden by default)

    @ViewBuilder
    private var followUpBar: some View {
        if viewModel.isFollowUpOpen {
            HStack(spacing: 6) {
                Image(systemName: "arrow.turn.down.right")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                TextField("Follow up…", text: $viewModel.followUpInput)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .focused($followUpFocused)
                    .onSubmit {
                        viewModel.sendFollowUp()
                        viewModel.isFollowUpOpen = false
                    }
                if !viewModel.followUpInput.trimmingCharacters(in: .whitespaces).isEmpty {
                    Text("↵")
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.04))
            .onAppear { followUpFocused = true }
        } else if !viewModel.streamingText.isEmpty || !viewModel.conversation.isEmpty {
            // Tiny affordance — only appears once there's something to follow up on.
            HStack {
                Spacer()
                Button(action: showFollowUp) {
                    HStack(spacing: 3) {
                        Text("Follow up")
                        Text("⌘L").foregroundStyle(.tertiary)
                    }
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Ask a follow-up (⌘L)")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Actions

    private func showFollowUp() {
        viewModel.isFollowUpOpen = true
        DispatchQueue.main.async { followUpFocused = true }
    }

    private var emptyStateMessage: String {
        if !AccessibilityCapture.isTrusted {
            return "No selection — Accessibility access not granted."
        }
        return "No selection captured."
    }

    private func copyResponse() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(viewModel.streamingText, forType: .string)
    }
}
