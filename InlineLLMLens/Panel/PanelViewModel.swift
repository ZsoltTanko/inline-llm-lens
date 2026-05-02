import Foundation
import Combine

@MainActor
final class PanelViewModel: ObservableObject {
    @Published var bundle: ContextBundle = .empty()
    @Published var manualSelectedText: String = ""
    @Published var selectedPresetID: UUID?
    @Published var selectedModelID: UUID?
    @Published var userInput: String = ""
    @Published var followUpInput: String = ""
    /// Whether the follow-up bar is visible. Lifted out of `PanelView`'s
    /// local `@State` so panel-level Esc handling (in `FloatingPanel`) can
    /// collapse the follow-up bar before closing the panel.
    @Published var isFollowUpOpen: Bool = false
    /// Changes on every `reset(...)`. Views observe this with `.onChange`
    /// to trigger per-invocation side effects (e.g. auto-focusing the
    /// preset's user-input field) without needing a stable bundle ID.
    @Published private(set) var invocationToken: UUID = UUID()

    @Published private(set) var conversation: [ChatMessage] = []
    @Published private(set) var streamingText: String = ""
    @Published private(set) var isStreaming: Bool = false
    @Published private(set) var lastError: String?
    @Published private(set) var lastResolution: PromptResolution?

    let modelStore: ModelStore
    let presetStore: PromptPresetStore
    let settings: SettingsStore
    private let registry: ProviderRegistry
    private let promptBuilder = PromptBuilder()

    private var streamTask: Task<Void, Never>?

    init(modelStore: ModelStore, presetStore: PromptPresetStore, registry: ProviderRegistry, settings: SettingsStore) {
        self.modelStore = modelStore
        self.presetStore = presetStore
        self.registry = registry
        self.settings = settings
        self.selectedPresetID = presetStore.defaultPreset?.id
        self.selectedModelID = effectiveModel(for: presetStore.defaultPreset)?.id
    }

    var effectiveSelectedText: String {
        bundle.selectedText.isEmpty ? manualSelectedText : bundle.selectedText
    }

    var selectedPreset: PromptPreset? {
        presetStore.preset(byID: selectedPresetID) ?? presetStore.defaultPreset
    }

    var selectedModel: ModelConfig? {
        if let id = selectedModelID, let m = modelStore.models.first(where: { $0.id == id }) { return m }
        return modelStore.defaultModel
    }

    var canSend: Bool {
        guard let preset = selectedPreset, selectedModel != nil else { return false }
        if preset.requiresSelection, effectiveSelectedText.isEmpty { return false }
        if preset.requiresUserInput, userInput.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        // If neither selection nor user input is required, still need *something*
        // to send to the model (avoid empty user message + empty system).
        if effectiveSelectedText.isEmpty
            && userInput.trimmingCharacters(in: .whitespaces).isEmpty
            && preset.systemPrompt.trimmingCharacters(in: .whitespaces).isEmpty {
            return false
        }
        return true
    }

    func reset(with bundle: ContextBundle, presetOverride: PromptPreset? = nil) {
        cancelStreaming()
        self.bundle = bundle
        self.manualSelectedText = ""
        let preset = presetOverride ?? presetStore.defaultPreset
        self.selectedPresetID = preset?.id
        self.selectedModelID = effectiveModel(for: preset)?.id
        self.userInput = ""
        self.followUpInput = ""
        self.isFollowUpOpen = false
        self.conversation = []
        self.streamingText = ""
        self.lastError = nil
        self.lastResolution = nil
        self.invocationToken = UUID()
    }

    /// When the user picks a different preset in the panel, honor that preset's
    /// preferred model (if any) — otherwise fall back to whatever was selected
    /// before, then to the global default.
    func onPresetChanged() {
        if let preset = selectedPreset, let modelID = preset.preferredModelID,
           modelStore.models.contains(where: { $0.id == modelID }) {
            selectedModelID = modelID
        }
    }

    func send() {
        guard let preset = selectedPreset else {
            lastError = "No prompt preset configured."
            return
        }
        guard let model = effectiveModel(for: preset) else {
            lastError = "No model configured. Open Settings to add one."
            return
        }
        let activeBundle = currentBundleForSend()
        let (messages, resolution) = promptBuilder.resolve(
            preset: preset,
            bundle: activeBundle,
            userInput: userInput,
            model: model
        )
        conversation = messages
        lastResolution = resolution
        runRequest(model: model, preset: preset)
    }

    func sendFollowUp() {
        let trimmed = followUpInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let preset = selectedPreset, let model = effectiveModel(for: preset) else { return }
        if conversation.isEmpty {
            let (messages, resolution) = promptBuilder.resolve(
                preset: preset,
                bundle: currentBundleForSend(),
                userInput: userInput,
                model: model
            )
            conversation = messages
            lastResolution = resolution
        }
        conversation.append(ChatMessage(role: .user, content: trimmed))
        followUpInput = ""
        runRequest(model: model, preset: preset)
    }

    func closeFollowUp() {
        isFollowUpOpen = false
        followUpInput = ""
    }

    func cancelStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    private func effectiveModel(for preset: PromptPreset?) -> ModelConfig? {
        if let preset, let id = preset.preferredModelID,
           let model = modelStore.models.first(where: { $0.id == id }) {
            return model
        }
        if let id = selectedModelID, let m = modelStore.models.first(where: { $0.id == id }) {
            return m
        }
        return modelStore.defaultModel
    }

    private func currentBundleForSend() -> ContextBundle {
        if !bundle.selectedText.isEmpty { return bundle }
        var copy = bundle
        copy.selectedText = manualSelectedText
        return copy
    }

    private func runRequest(model: ModelConfig, preset: PromptPreset) {
        cancelStreaming()
        lastError = nil
        streamingText = ""
        isStreaming = true

        let request = LLMRequest(
            model: model,
            messages: conversation,
            temperature: preset.temperature,
            maxTokens: preset.maxOutputTokens,
            reasoningEffort: preset.reasoningEffort,
            stream: settings.streamResponses && model.supportsStreaming
        )
        let provider = registry.provider(for: model)

        streamTask = Task { [weak self] in
            guard let self else { return }
            do {
                if request.stream {
                    let stream = try await provider.streamResponse(request: request)
                    for try await token in stream {
                        if Task.isCancelled { break }
                        if !token.delta.isEmpty {
                            await MainActor.run { self.streamingText += token.delta }
                        }
                    }
                } else {
                    let response = try await provider.complete(request: request)
                    await MainActor.run { self.streamingText = response.text }
                }

                await MainActor.run {
                    self.conversation.append(ChatMessage(role: .assistant, content: self.streamingText))
                    self.isStreaming = false
                    self.recordHistory(model: model, preset: preset)
                }
            } catch is CancellationError {
                await MainActor.run { self.isStreaming = false }
            } catch {
                await MainActor.run {
                    self.lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                    self.isStreaming = false
                }
            }
        }
    }

    private func recordHistory(model: ModelConfig, preset: PromptPreset) {
        guard settings.historyEnabled, !streamingText.isEmpty else { return }
        guard let resolution = lastResolution else { return }
        let item = LocalHistoryItem(
            timestamp: Date(),
            selectedText: effectiveSelectedText,
            userInput: userInput,
            responseText: streamingText,
            appName: bundle.frontmostAppName,
            windowTitle: bundle.frontmostWindowTitle,
            resolution: resolution
        )
        LocalHistoryStore.shared.append(item)
    }
}
