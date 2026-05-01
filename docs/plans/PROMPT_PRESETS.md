# Prompt Presets — Implementation Plan

Status: **Draft for review.** Do not start coding until this doc is signed off.

## Goal

Replace the hard-coded `PromptMode` enum (Explain/Define/Summarize/…/Custom) with user-defined, persistable **Prompt Presets** ("personas" in user copy if we want; code stays `PromptPreset` / `PromptPresetStore`). Each preset is a self-contained recipe describing how Inline LLM Lens should behave when invoked.

## Decisions locked in (from design discussion)

1. **One unified data type, not two abstractions.** No factory presets vs user presets distinction. Ship a single seed preset on first run so the app works out of the box; the user owns it from then on (rename/edit/delete freely). No "Restore factory" button. No `isFactory` flag.
2. **Drop `responseLength` and `translateTargetLanguage` globals.** They become naturally expressible in the system-prompt text (or via template variables, see #5).
3. **System prompt + user message split, kept simple.**
   - **User message → always the selected text.** No second author-controlled "user template".
   - **System prompt → the preset's text** with template variables expanded.
   - When a preset has `requiresUserInput = true`, the panel shows a text field and that text is available to the system prompt as `{{userInput}}`.
4. **Built-ins:** ship exactly one seed preset on first launch — a permissive "Explain" persona. After that, the catalog is the user's.
5. **Template variables:** `{{selection}}`, `{{userInput}}`, `{{app}}`, `{{windowTitle}}`, `{{date}}`. (These do *not* re-introduce the global response-length/language toggles; they're context only.) Unknown variables surface a warning in the preview pane but render as literal text at runtime.
6. **Per-preset model override.** `preferredModelID: UUID?` — falls back to global default model.
7. **Per-preset inference params.** `temperature: Double?`, `maxOutputTokens: Int?`, `reasoningEffort: ReasoningEffort?` — all nullable, fall back to the model's own defaults.
   - **`reasoningEffort` is a first-class field** (free-text `String?`, default `nil` / "none") because models accept bespoke values (`minimal`, `low`, `medium`, `high`, `xhigh`, etc). Sent verbatim to providers that accept it; ignored otherwise. UI is a plain text field with the common values shown as a hint.
8. **Per-preset behavior flags:** `requiresUserInput: Bool`, `requiresSelection: Bool`, `autoSend: Bool`.
9. **Per-preset hotkey:** optional `KeyboardShortcuts.Name` binding, configurable in Settings. Implemented in v1.
10. **Pin-to-dropdown / hide-from-dropdown** flag per preset, plus reorder.
11. **Default preset.** Mirrors `defaultModelID`. If unset, falls back to the first preset.
12. **Import / export** as JSON, single preset and bundle.
13. **Preview pane** in the editor: render the resolved system + user messages against a sample selection.
14. **History snapshots the resolved prompt.** On invocation we record the *expanded* system prompt + user message + model + inference params, not just a `presetID`. Editing or deleting a preset later does not rewrite history.
15. **No backwards compat** — app is dev-only. Wipe `defaultPromptMode`, `responseLength`, `translateTargetLanguage` from `SettingsStore`. Drop `PromptMode`, `SystemPrompts`, the `ModePicker`, and the existing `customInstruction` plumbing.

## Data model

```swift
struct PromptPreset: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String                           // "Explain", "Translate to French", "Code review"
    var systemPrompt: String                   // template string with {{vars}}
    var requiresUserInput: Bool                // panel shows an instruction field
    var userInputPlaceholder: String?          // e.g. "Target language", "Question…"
    var requiresSelection: Bool                // if true, invocation refuses with no selection
    var autoSend: Bool                         // hotkey path fires send() immediately

    // Optional overrides (nil → fall back)
    var preferredModelID: UUID?
    var temperature: Double?
    var maxOutputTokens: Int?
    var reasoningEffort: String?            // free text, e.g. "low", "high", "xhigh"

    // UX
    var pinnedInDropdown: Bool                 // appears in panel dropdown
    var sortOrder: Int                         // for stable manual ordering
    var hotkeyName: String?                    // KeyboardShortcuts name id (nil = unbound)
}

```

`PromptPresetStore` mirrors `ModelStore`:

- Persists to `Application Support/InlineLLMLens/prompts.json`.
- `@Published var presets: [PromptPreset]`, `@Published var defaultPresetID: UUID?` (the latter in `UserDefaults`).
- API: `add`, `update`, `delete`, `setDefault`, `move(from:to:)`, `importBundle(_:)`, `exportBundle()`.
- On first launch with empty file: seed the single default preset (see "Seed preset" below).

### History snapshot

Update `LocalHistoryStore` entries to include:

```swift
struct HistoryEntry {
    // existing fields…
    var presetSnapshot: PresetSnapshot
    var modelSnapshot: ModelSnapshot
}

struct PresetSnapshot: Codable {
    var presetID: UUID?            // for "Re-run with current preset" if it still exists
    var name: String               // human-readable at the time
    var resolvedSystemPrompt: String
    var resolvedUserMessage: String
    var temperature: Double?
    var maxOutputTokens: Int?
    var reasoningEffort: String?
}
```

## Prompt resolution pipeline

`PromptBuilder` is rewritten:

1. Pull the active preset.
2. Expand `{{selection}}`, `{{userInput}}`, `{{app}}`, `{{windowTitle}}`, `{{date}}` in `preset.systemPrompt`.
3. Build messages:
   - `system` = expanded system prompt.
   - `user` = `bundle.selectedText` (verbatim; no fenced wrapping by default — keep simple).
4. Resolve effective model: `preset.preferredModelID ?? viewModel.selectedModelID ?? modelStore.defaultModelID`.
5. Resolve effective inference params: preset values, with each falling back to the model's own default if nil.
6. Return both messages and a `PresetSnapshot` for the history store.

`appendFollowUp(...)` stays as-is: just append a user message.

The "weak app context" block (currently appended when `settings.includeAppContext` is true) is **gone** — anything the user wants from app context they can put in the system prompt with `{{app}}` / `{{windowTitle}}`.

## LLM request changes

`LLMRequest` (and `OpenAICompatibleClient`) need to carry optional `temperature`, `maxOutputTokens`, `reasoningEffort`. Wiring:

- `OpenAICompatibleClient` already builds a JSON body — extend it to include `temperature` and `max_tokens` when present, and `reasoning: { effort: ... }` (OpenAI Responses-style) or the provider-specific equivalent. We only emit reasoning fields when the model is known to accept them; otherwise drop silently.
- For unknown providers we default to omitting reasoning fields. (Per-provider capability matrix can grow later.)

## UI changes

### Settings → Prompts (new tab)

- List of presets with drag-to-reorder, default radio, pin checkbox, hotkey display, and an Add/Duplicate/Delete toolbar.
- Detail editor (right pane or sheet):
  - Name
  - System prompt (multiline, monospaced)
  - "Requires user input" toggle + placeholder text
  - "Requires selection" toggle
  - "Auto-send on invocation" toggle
  - Preferred model picker (None / specific)
  - Advanced disclosure: temperature, max output tokens, reasoning effort
  - Hotkey recorder (KeyboardShortcuts UI)
  - Pin to panel dropdown toggle
  - **Preview pane**: shows the resolved system + user messages against a hard-coded sample selection ("The mitochondrion is the powerhouse of the cell.") and any sample userInput; lists any unknown `{{vars}}`.
  - Import / Export buttons (single preset = `.json`; bundle = `.json` array).

### Panel

- Replace `ModePicker` with `PresetPicker` showing presets where `pinnedInDropdown == true`, plus a "More…" item that opens a search palette with the rest.
- If selected preset has `requiresUserInput`, show an instruction text field in place of the current `customInstruction` field, placeholder from the preset.
- The current free-form custom field is gone (folded into the seed preset's behavior or any preset with `requiresUserInput`).
- Diagnostics footer additions: show effective preset name, model, and reasoning effort when set.

### Menu bar / hotkeys

- Existing global "Ask" hotkey opens with the **default** preset.
- Each preset with `hotkeyName` set gets its own global hotkey (registered via `KeyboardShortcuts`), which presents the panel pre-bound to that preset and respects its `autoSend`.
- Status-bar icon menu gains a "Prompt presets" submenu listing all presets; selecting one invokes that preset.

## Files added

- `InlineLLMLens/Prompts/PromptPreset.swift`
- `InlineLLMLens/Prompts/PromptPresetStore.swift`
- `InlineLLMLens/Settings/PromptsSettingsView.swift`
- `InlineLLMLens/Settings/PromptPresetEditor.swift`
- `InlineLLMLens/Panel/PresetPicker.swift`
- `InlineLLMLensTests/PromptPresetStoreTests.swift`
- `InlineLLMLensTests/PromptResolutionTests.swift`

## Files modified

- `InlineLLMLens/Prompt/PromptBuilder.swift` — rewritten around presets + variable expansion.
- `InlineLLMLens/Panel/PanelView.swift` / `PanelViewModel.swift` — preset picker, instruction field, snapshot recording.
- `InlineLLMLens/LLM/LLMRequest.swift` — add `temperature`, `maxOutputTokens`, `reasoningEffort`.
- `InlineLLMLens/LLM/OpenAICompatibleClient.swift` — emit those when present; reasoning gated by capability.
- `InlineLLMLens/Storage/SettingsStore.swift` — drop `defaultPromptMode`, `responseLength`, `translateTargetLanguage`, `includeAppContext`.
- `InlineLLMLens/Storage/LocalHistoryStore.swift` — store `PresetSnapshot` + `ModelSnapshot`.
- `InlineLLMLens/MenuBar/MenuBarController.swift` — Prompt presets submenu.
- `InlineLLMLens/App/AppDelegate.swift` — register per-preset hotkeys; `invokeFromHotkey` accepts an optional preset.
- `InlineLLMLens/Hotkeys/HotkeyManager.swift` — per-preset hotkey registration alongside the global one.
- `InlineLLMLens/Settings/SettingsScene.swift` — add Prompts tab; remove Response tab (its remaining content folds into Prompts) and General's "default prompt mode" picker.

## Files deleted

- `InlineLLMLens/Prompt/PromptMode.swift`
- `InlineLLMLens/Prompt/SystemPrompts.swift`
- `InlineLLMLens/Panel/ModePicker.swift`
- `InlineLLMLens/Settings/ResponseSettingsView.swift` (folded away)
- `InlineLLMLensTests/PromptBuilderTests.swift` (replaced by `PromptResolutionTests.swift`)

## Seed preset (created on first run if `prompts.json` missing/empty)

```text
Name: Explain
System prompt:
  You are a concise, high-precision assistant embedded in a macOS text-selection
  utility. The user has selected text from another app and wants help without
  context switching. Explain the selected text. Be concise but not shallow. If
  it is technical, include the key mechanism or distinction. If the selection
  is ambiguous, give the most likely interpretation and mention uncertainty
  briefly.

requiresUserInput: false
requiresSelection: false
autoSend: true
preferredModelID: nil
temperature: nil
maxOutputTokens: nil
reasoningEffort: nil
pinnedInDropdown: true
sortOrder: 0
hotkeyName: nil
```

## Implementation order

1. Data layer: `PromptPreset`, `ReasoningEffort`, `PromptPresetStore` + tests. Seed-on-first-run.
2. Rewrite `PromptBuilder` for variable expansion + return `PresetSnapshot`. Tests for variable expansion edge cases (unknown vars, empty values, repeated vars, `{{` literal).
3. Plumb `temperature` / `maxOutputTokens` / `reasoningEffort` through `LLMRequest` and `OpenAICompatibleClient`. Capability gating for reasoning.
4. Panel rewiring: `PresetPicker`, instruction field gated by `requiresUserInput`, snapshot recording in `PanelViewModel.send()`.
5. History: extend entries with `PresetSnapshot` + `ModelSnapshot`. Wipe-and-recreate is acceptable (dev-only).
6. Settings UI: Prompts tab with list, editor, preview pane, import/export. Drop General's mode picker and the Response tab.
7. Hotkeys: per-preset registration; menu-bar submenu.
8. Cleanup: delete dead files; update docs (`README.md`, `docs/ARCHITECTURE.md`, `docs/EXTENDING.md`, `mvp_spec.md` if needed).

## Open questions for review

- **Reasoning effort UI default value** — show as four-segment picker or three options "—/Low/Medium/High"? I'm leaning four-segment with an explicit "Inherit from model" option above it.
- **Per-preset hotkey conflicts** — what do we do if two presets bind the same shortcut? Plan: `KeyboardShortcuts` lib already shows a system warning; we additionally surface a red badge in the preset list.
- **Where the "Ask anything" preset lives** — under this design it's just whatever preset the user creates with `requiresUserInput = true` and a system prompt like `{{userInput}}`. We don't seed it. OK to drop, or do you want it seeded too?
- **Reordering and pin behaviour** — list in panel dropdown is `presets.filter { $0.pinnedInDropdown }.sortedBy(sortOrder)`, then a "More…" command for the rest. Acceptable, or should the dropdown always show all presets?

---

When this looks right, I'll start at step 1 and work down.
