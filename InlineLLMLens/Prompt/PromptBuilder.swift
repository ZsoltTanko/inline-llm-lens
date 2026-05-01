import Foundation

struct PromptBuilder {
    let settings: SettingsStore

    func buildInitial(
        bundle: ContextBundle,
        mode: PromptMode,
        customInstruction: String?
    ) -> [ChatMessage] {
        let modeInstruction = SystemPrompts.instruction(
            for: mode,
            translateTarget: settings.translateTargetLanguage,
            lengthHint: settings.responseLength,
            customInstruction: customInstruction
        )

        var system = SystemPrompts.base + "\n\n" + modeInstruction
        if settings.includeAppContext, bundle.frontmostAppName != nil || bundle.frontmostWindowTitle != nil {
            system += "\n\n[Weak context — do not over-infer from this]"
            if let app = bundle.frontmostAppName { system += "\nFrontmost app: \(app)" }
            if let title = bundle.frontmostWindowTitle { system += "\nWindow title: \(title)" }
        }

        let user: String
        if bundle.selectedText.isEmpty {
            user = customInstruction ?? "(no selected text provided)"
        } else if mode == .custom, let custom = customInstruction, !custom.trimmingCharacters(in: .whitespaces).isEmpty {
            user = "\(custom)\n\nSelected text:\n\"\"\"\n\(bundle.selectedText)\n\"\"\""
        } else {
            user = "Selected text:\n\"\"\"\n\(bundle.selectedText)\n\"\"\""
        }

        return [
            ChatMessage(role: .system, content: system),
            ChatMessage(role: .user, content: user)
        ]
    }

    func appendFollowUp(messages: [ChatMessage], userInput: String) -> [ChatMessage] {
        messages + [ChatMessage(role: .user, content: userInput)]
    }
}
