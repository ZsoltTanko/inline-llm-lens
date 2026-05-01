import Foundation

/// User-defined recipe for invoking the LLM. Mirrors `ModelConfig` in shape and
/// persistence pattern. The collection of presets is owned by `PromptPresetStore`.
///
/// The `systemPrompt` may reference template variables which are expanded at
/// invocation time by `PromptBuilder.expand(...)`:
///
/// - `{{selection}}`     – the captured selected text (or empty string if none)
/// - `{{userInput}}`     – text the user typed into the panel's instruction field
///                         (only meaningful when `requiresUserInput == true`)
/// - `{{app}}`           – frontmost app name at capture time (or empty)
/// - `{{windowTitle}}`   – frontmost window title at capture time (or empty)
/// - `{{date}}`          – ISO-8601 date at invocation time
struct PromptPreset: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var systemPrompt: String

    var requiresUserInput: Bool
    var userInputPlaceholder: String?
    var requiresSelection: Bool
    var autoSend: Bool

    // Optional overrides — nil falls back to model / user defaults.
    var preferredModelID: UUID?
    var temperature: Double?
    var maxOutputTokens: Int?
    /// Free-form value sent as `reasoning_effort` when non-empty. Common values
    /// are "minimal", "low", "medium", "high"; some providers accept bespoke
    /// values like "xhigh". Treat as opaque text.
    var reasoningEffort: String?

    var pinnedInDropdown: Bool
    var sortOrder: Int

    init(
        id: UUID = UUID(),
        name: String,
        systemPrompt: String,
        requiresUserInput: Bool = false,
        userInputPlaceholder: String? = nil,
        requiresSelection: Bool = false,
        autoSend: Bool = false,
        preferredModelID: UUID? = nil,
        temperature: Double? = nil,
        maxOutputTokens: Int? = nil,
        reasoningEffort: String? = nil,
        pinnedInDropdown: Bool = true,
        sortOrder: Int = 0
    ) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.requiresUserInput = requiresUserInput
        self.userInputPlaceholder = userInputPlaceholder
        self.requiresSelection = requiresSelection
        self.autoSend = autoSend
        self.preferredModelID = preferredModelID
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
        self.reasoningEffort = reasoningEffort
        self.pinnedInDropdown = pinnedInDropdown
        self.sortOrder = sortOrder
    }
}

extension PromptPreset {
    /// Stable identifier used to register a per-preset global hotkey via the
    /// KeyboardShortcuts library. Constant per preset so the binding survives
    /// rename.
    var hotkeyShortcutKey: String { "prompt.preset.\(id.uuidString)" }

    /// Seed preset created on first launch when the prompts file is missing or
    /// empty. The user is free to rename, edit, or delete it.
    static let seed = PromptPreset(
        name: "Explain",
        systemPrompt: """
        You are a concise, high-precision assistant embedded in a macOS text-selection utility. The user has selected text from another app and wants help without context switching.

        Explain the selected text. Be concise but not shallow. If it is technical, include the key mechanism or distinction. If the selection is ambiguous, give the most likely interpretation and mention uncertainty briefly.
        """,
        autoSend: true,
        sortOrder: 0
    )
}
