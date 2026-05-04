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

    /// Optional per-preset panel size in points. When `nil`, falls back to
    /// `PanelPositioner.defaultSize`. Lets a "long-form translation" preset
    /// open a tall panel while a "quick lookup" preset stays compact.
    /// Both must be set to take effect — a single dimension is ignored.
    var panelWidth: Double?
    var panelHeight: Double?

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
        sortOrder: Int = 0,
        panelWidth: Double? = nil,
        panelHeight: Double? = nil
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
        self.panelWidth = panelWidth
        self.panelHeight = panelHeight
    }
}

extension PromptPreset {
    /// Stable identifier used to register a per-preset global hotkey via the
    /// KeyboardShortcuts library. Constant per preset so the binding survives
    /// rename.
    var hotkeyShortcutKey: String { "prompt.preset.\(id.uuidString)" }

    /// Shared copy for the "concise assistant" framing used by both factory
    /// seeds. Kept as a single source of truth so edits stay consistent.
    fileprivate static let seedBaseSystemPrompt = """
    You are a concise, high-precision assistant embedded in a macOS text-selection utility. The user has selected text from another app and wants help without context switching. Explain the selected text. Be concise but not shallow. If it is technical, include the key mechanism or distinction. You always respond in English, translating any provided text first. If the selection is ambiguous, give the most likely interpretation. Don’t mention uncertainty or hedge - your best guess suffices. Don’t suggest follow-up clarifications or discussion since the user can only see your first message, not respond further.
    """

    /// Presets installed on first launch when the prompts file is missing
    /// or empty. The user is free to rename, edit, or delete any of them;
    /// they are only (re)seeded when the catalog is completely empty.
    static var factorySeeds: [PromptPreset] {
        [
            PromptPreset(
                name: "Explain",
                systemPrompt: seedBaseSystemPrompt,
                requiresUserInput: false,
                requiresSelection: false,
                autoSend: true,
                pinnedInDropdown: true,
                sortOrder: 0
            ),
            PromptPreset(
                name: "Ask",
                systemPrompt: seedBaseSystemPrompt + "\n\nThe user has provided the following additional instruction or question: {{userInput}}",
                requiresUserInput: true,
                requiresSelection: false,
                autoSend: true,
                pinnedInDropdown: true,
                sortOrder: 1
            )
        ]
    }

    /// Back-compat accessor for tests / callers that want "the default
    /// starter preset". Always returns the first factory seed ("Explain").
    static var seed: PromptPreset { factorySeeds[0] }
}
