import Foundation
import Combine

@MainActor
final class PanelViewModel: ObservableObject {
    @Published var bundle: ContextBundle = .empty()
    @Published var manualSelectedText: String = ""
    @Published var mode: PromptMode
    @Published var selectedModelID: UUID?
    @Published var customInstruction: String = ""
    @Published var followUpInput: String = ""

    @Published private(set) var conversation: [ChatMessage] = []
    @Published private(set) var streamingText: String = ""
    @Published private(set) var isStreaming: Bool = false
    @Published private(set) var lastError: String?

    let modelStore: ModelStore
    private let registry: ProviderRegistry
    let settings: SettingsStore
    private let promptBuilder: PromptBuilder

    private var streamTask: Task<Void, Never>?

    init(modelStore: ModelStore, registry: ProviderRegistry, settings: SettingsStore) {
        self.modelStore = modelStore
        self.registry = registry
        self.settings = settings
        self.promptBuilder = PromptBuilder(settings: settings)
        self.mode = settings.defaultPromptMode
        self.selectedModelID = modelStore.defaultModel?.id
    }

    var effectiveSelectedText: String {
        bundle.selectedText.isEmpty ? manualSelectedText : bundle.selectedText
    }

    var canSend: Bool {
        guard selectedModel != nil else { return false }
        if mode == .custom { return !customInstruction.trimmingCharacters(in: .whitespaces).isEmpty || !effectiveSelectedText.isEmpty }
        return !effectiveSelectedText.isEmpty
    }

    var selectedModel: ModelConfig? {
        if let id = selectedModelID, let m = modelStore.models.first(where: { $0.id == id }) { return m }
        return modelStore.defaultModel
    }

    func reset(with bundle: ContextBundle) {
        cancelStreaming()
        self.bundle = bundle
        self.manualSelectedText = ""
        self.mode = settings.defaultPromptMode
        self.selectedModelID = modelStore.defaultModel?.id
        self.customInstruction = ""
        self.followUpInput = ""
        self.conversation = []
        self.streamingText = ""
        self.lastError = nil
    }

    func send() {
        guard let model = selectedModel else {
            lastError = "No model configured. Open Settings to add one."
            return
        }
        let activeBundle = currentBundleForSend()
        let messages = promptBuilder.buildInitial(
            bundle: activeBundle,
            mode: mode,
            customInstruction: customInstruction.isEmpty ? nil : customInstruction
        )
        conversation = messages
        runRequest(model: model)
    }

    func sendFollowUp() {
        guard let model = selectedModel else { return }
        let trimmed = followUpInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if conversation.isEmpty {
            conversation = promptBuilder.buildInitial(
                bundle: currentBundleForSend(),
                mode: mode,
                customInstruction: customInstruction.isEmpty ? nil : customInstruction
            )
        }
        conversation.append(ChatMessage(role: .user, content: trimmed))
        followUpInput = ""
        runRequest(model: model)
    }

    func cancelStreaming() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false
    }

    private func currentBundleForSend() -> ContextBundle {
        if !bundle.selectedText.isEmpty { return bundle }
        var copy = bundle
        copy.selectedText = manualSelectedText
        return copy
    }

    private func runRequest(model: ModelConfig) {
        cancelStreaming()
        lastError = nil
        streamingText = ""
        isStreaming = true

        let request = LLMRequest(
            model: model,
            messages: conversation,
            temperature: nil,
            maxTokens: nil,
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
                    self.recordHistory(model: model)
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

    private func recordHistory(model: ModelConfig) {
        guard settings.historyEnabled, !streamingText.isEmpty else { return }
        let item = LocalHistoryItem(
            timestamp: Date(),
            selectedText: effectiveSelectedText,
            responseText: streamingText,
            modelName: model.displayName,
            mode: mode,
            appName: bundle.frontmostAppName
        )
        LocalHistoryStore.shared.append(item)
    }
}
