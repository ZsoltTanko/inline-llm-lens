# MVP Product Spec: macOS Inline LLM Lens

## 1. Project summary

Build a native macOS utility that lets a user send selected on-screen text to an LLM without switching to a browser or opening a large chat app.

The MVP should support this core workflow:

```text
Select text in any macOS app
→ trigger the utility via hotkey or right-click Services menu
→ see a small floating response panel near the current context
→ optionally choose model/action
→ copy or continue from the response
```

This is not intended to be a full ChatGPT/Claude replacement. It is an **inline semantic lens** over whatever the user is reading or editing.

The initial MVP should prioritize:

1. low interaction friction;
2. reliable selected-text capture;
3. fast LLM response;
4. minimal visual disruption;
5. configurability over polish.

---

## 2. Problem being solved

The current user workflow for getting LLM help on arbitrary text is too indirect:

```text
select text
→ right click
→ Look Up
→ Apple dictionary if recognized
→ otherwise Google
→ maybe Google’s embedded Gemini
→ browser tab/context switch
```

Problems with this workflow:

* It is conditional: behavior depends on whether Apple/Google classify the text as dictionary-worthy/search-worthy.
* It causes context switch into browser/search UI.
* It provides no control over model, prompt, response style, or privacy.
* It is bad for arbitrary strings: code snippets, jargon, fragments, identifiers, formulas, logs, UI text, Slack messages, prose excerpts.
* It does not preserve the user’s local attentional context.

The MVP should make the operation unconditional:

```text
selected text → LLM response
```

with no browser hop.

---

## 3. Product positioning

This is a **native macOS selection-to-LLM utility**.

It should feel closer to:

* Spotlight;
* Raycast quick command;
* PopClip selection action;
* Apple Dictionary lookup;
* a lightweight floating inspector;

than to:

* a full chat application;
* a browser;
* a document editor;
* a note-taking app.

The user should be able to invoke it many times per hour without feeling like they have “opened an app.”

---

## 4. MVP goals

### Functional goals

The MVP must allow a user to:

1. select text in another macOS app;
2. invoke the tool via global hotkey;
3. invoke the tool via right-click Services / Quick Actions menu where supported;
4. send selected text to an LLM provider;
5. choose from a small set of prompt modes;
6. choose from configured models;
7. view the response in a small floating panel;
8. copy the response;
9. continue asking a follow-up question in the same panel;
10. store API keys securely in macOS Keychain.

### Experience goals

The MVP should feel:

* lightweight;
* instant enough for frequent use;
* visually unobtrusive;
* native to macOS;
* keyboard-friendly;
* privacy-conscious;
* configurable by a technical user.

### Technical goals

The MVP should be built as a native macOS app using Swift/SwiftUI/AppKit.

The app should have:

* menu bar presence;
* floating response panel;
* global hotkey support;
* Services / Quick Action integration;
* Accessibility-based selected-text capture where possible;
* clipboard fallback where necessary;
* streaming LLM responses if feasible;
* provider abstraction for OpenAI / Anthropic / OpenRouter-style APIs.

---

## 5. MVP non-goals

The MVP should **not** initially include:

* full browser DOM extraction;
* automatic full-page text capture;
* screenshot capture;
* OCR;
* PDF structure extraction;
* app-specific integrations for VS Code, Cursor, Safari, Chrome, Slack, etc.;
* autonomous background monitoring;
* local vector memory;
* RAG over previous selections;
* multi-window chat history browser;
* team sync;
* cloud accounts;
* billing;
* plugin marketplace;
* mobile support;
* Windows/Linux support.

Those are later-stage features.

The MVP is about making the basic loop excellent:

```text
selection → model → small answer
```

---

## 6. Primary user stories

### Story 1: Explain selected term or phrase

As a user reading technical text, I want to select an unfamiliar term and get a concise explanation without leaving the page.

Flow:

```text
User selects “contrastive decoding”
User presses global hotkey
Small panel appears
LLM explains the term concisely
```

### Story 2: Ask about arbitrary selected text

As a user reading code, logs, prose, or UI copy, I want to ask an LLM about the selected fragment.

Flow:

```text
User selects a code snippet
User invokes “Ask LLM”
Panel opens with selected text preloaded
User chooses “Explain”
LLM returns explanation
```

### Story 3: Right-click workflow

As a user who prefers mouse-driven interaction, I want to right-click selected text and send it to the LLM from the Services menu.

Flow:

```text
User selects text
Right-clicks
Services → Ask LLM
Floating response panel appears
```

### Story 4: Model selection

As a technical user, I want to choose between fast/cheap and stronger models depending on the task.

Flow:

```text
User selects text
Panel appears
Dropdown shows configured models
User selects “Fast”, “Deep”, or a named model
Request is sent
```

### Story 5: Follow-up without full app switch

As a user, I want to ask a follow-up question about the answer without opening a large chat UI.

Flow:

```text
LLM response appears
User types follow-up in small input field
LLM responds in same floating panel
```

---

## 7. Core UX

### 7.1 Invocation methods

The MVP should support two invocation methods.

#### A. Global hotkey

Default candidate:

```text
Option + Space
```

or another configurable hotkey if Option+Space conflicts with other apps.

Behavior:

1. User selects text in frontmost app.
2. User presses hotkey.
3. App attempts to capture selected text.
4. Floating panel appears.
5. If selected text was captured, request is ready to send or auto-sent depending on user setting.
6. If no selected text was captured, panel opens with empty input and message: “No selection detected.”

#### B. Right-click Services menu

Behavior:

1. User selects text.
2. User right-clicks.
3. User chooses something like:

```text
Services → Ask Inline LLM
```

4. macOS passes selected text to the app.
5. App opens floating panel and processes the text.

This path is important because it uses native macOS affordances and is likely more reliable for receiving selected text in apps that support Services.

---

## 8. Floating panel behavior

The response UI should be a small floating panel, not a full main window.

### Required panel features

The panel should include:

* selected text preview, collapsed by default if long;
* action/prompt mode dropdown;
* model dropdown;
* send/regenerate button;
* streaming or loading response area;
* copy response button;
* follow-up input field;
* close button;
* keyboard shortcuts.

### Suggested layout

```text
┌──────────────────────────────────────────────┐
│ Ask LLM                              [model ▾]│
│ Mode: Explain ▾                              │
├──────────────────────────────────────────────┤
│ Selected text:                               │
│ “contrastive decoding...”          [expand]  │
├──────────────────────────────────────────────┤
│ Response streams here...                     │
│                                              │
├──────────────────────────────────────────────┤
│ Follow up…                         [Send]    │
└──────────────────────────────────────────────┘
```

### Panel behavior requirements

* The panel should appear near the current mouse position or centered over the active window.
* The panel should not permanently steal focus unless the user starts typing.
* Escape should close the panel.
* Cmd+C should copy selected text inside the panel if text is selected; otherwise copy the full response.
* Cmd+Enter should send follow-up.
* The panel should be resizable.
* The panel should support Markdown rendering, especially code blocks.
* The panel should preserve the last response while the user remains in the same invocation session.

---

## 9. Prompt modes

The MVP should ship with a small set of built-in modes.

### Required modes

| Mode       | Purpose                                                 | Prompt behavior                   |
| ---------- | ------------------------------------------------------- | --------------------------------- |
| Explain    | Explain selected text clearly and concisely             | Default                           |
| Define     | Treat selection as a term/phrase and define it          | Good for jargon                   |
| Summarize  | Condense selected text                                  | Good for paragraphs               |
| Rewrite    | Improve wording while preserving meaning                | Good for prose                    |
| Translate  | Translate selected text into configured target language | Optional target language setting  |
| Critique   | Point out issues, assumptions, ambiguity                | Useful for technical/prose review |
| Ask Custom | User types custom instruction                           | Maximum flexibility               |

### Default system instruction

The default system prompt should be something like:

```text
You are a concise, high-precision assistant embedded in a macOS text-selection utility. 
The user has selected text from another app and wants help without context switching. 
Answer directly. Avoid generic preamble. If the selected text is ambiguous, give the most likely interpretation and mention uncertainty briefly.
```

### Mode-specific examples

#### Explain

```text
Explain the selected text in context. Be concise but not shallow. If it is technical, include the key mechanism or distinction.
```

#### Define

```text
Define the selected term or phrase. Include common usage, nearby concepts, and any ambiguity.
```

#### Summarize

```text
Summarize the selected text. Preserve the important claims and structure. Use bullets only if helpful.
```

#### Rewrite

```text
Rewrite the selected text to be clearer and more precise while preserving its meaning. Return only the rewritten version unless there is an important caveat.
```

#### Critique

```text
Critique the selected text. Identify unclear claims, hidden assumptions, possible errors, and stronger alternatives.
```

---

## 10. Model/provider configuration

The MVP should support at least one provider, but the architecture should not hard-code a single vendor.

### Recommended provider abstraction

Create a generic interface:

```swift
protocol LLMProvider {
    func streamResponse(request: LLMRequest) async throws -> AsyncThrowingStream<LLMToken, Error>
    func complete(request: LLMRequest) async throws -> LLMResponse
}
```

### Minimal model configuration object

```swift
struct ModelConfig: Codable, Identifiable {
    let id: UUID
    var displayName: String
    var provider: ProviderKind
    var modelName: String
    var baseURL: URL
    var apiKeyReference: String
    var supportsVision: Bool
    var supportsStreaming: Bool
    var maxInputTokens: Int?
}
```

### Provider options

MVP should ideally support:

1. OpenAI-compatible API;
2. Anthropic-compatible API;
3. OpenRouter-compatible API.

But to keep MVP focused, it is acceptable to start with one of:

* OpenAI-compatible only;
* OpenRouter only, since it can route to multiple models;
* Anthropic only.

Best MVP choice for flexibility: **OpenRouter-style OpenAI-compatible endpoint plus editable base URL/model name.**

That lets the user configure many models without needing vendor-specific UI immediately.

### Model selector

The panel should expose a dropdown with configured models.

Example display:

```text
Fast — gpt-...
Deep — claude-...
Cheap — gemini-...
Local — llama...
```

The app should allow the user to mark one model as default.

---

## 11. Context capture

### 11.1 MVP context bundle

The MVP should construct a `ContextBundle` for each invocation.

```swift
struct ContextBundle: Codable {
    var selectedText: String
    var frontmostAppName: String?
    var frontmostWindowTitle: String?
    var captureMethod: CaptureMethod
    var timestamp: Date
}
```

Where:

```swift
enum CaptureMethod: String, Codable {
    case servicesInput
    case accessibility
    case clipboardFallback
    case manualInput
}
```

### 11.2 Capture methods

The MVP should implement these capture methods in priority order.

#### Method 1: Services input

When invoked from right-click Services / Quick Actions, macOS passes the selected text directly to the app.

This should be treated as the most reliable capture method.

#### Method 2: Accessibility selected text

When invoked by hotkey, the app should attempt to read selected text from the focused UI element using macOS Accessibility APIs.

This requires Accessibility permission.

If Accessibility permission is not granted, the app should ask for it with a clear explanation.

#### Method 3: Clipboard fallback

If Accessibility capture fails, the app may optionally use a clipboard fallback:

1. save current clipboard contents;
2. simulate Cmd+C;
3. read selected text from clipboard;
4. restore previous clipboard contents.

This should be user-configurable because it is somewhat invasive.

Default setting recommendation:

```text
Clipboard fallback: off by default, with explicit opt-in.
```

If enabled, the UI should clearly state this behavior in settings.

#### Method 4: Manual input

If no text can be captured, open the panel with an empty text field.

---

## 12. Permissions

The app should request permissions only when needed.

### Required/possible permissions

| Permission       | Needed for                       | MVP required?                 |
| ---------------- | -------------------------------- | ----------------------------- |
| Accessibility    | selected-text capture via hotkey | Yes, for best hotkey behavior |
| Automation       | controlling other apps           | No, avoid in MVP              |
| Screen Recording | screenshots / OCR                | No, future                    |
| Keychain         | API key storage                  | Yes                           |
| Network          | API calls                        | Yes                           |

### Permission UX

The app should include a settings section:

```text
Permissions
[ ] Accessibility permission detected
[ ] Screen Recording permission detected — future feature
[ ] Clipboard fallback enabled
```

For MVP, only Accessibility should be prompted.

If Accessibility is missing, show:

```text
To read selected text when you use the hotkey, Inline LLM Lens needs Accessibility permission. 
You can still use the right-click Services action without it in apps that support Services.
```

---

## 13. Settings

The MVP should include a basic settings window.

### Required settings

#### General

* launch at login;
* show menu bar icon;
* default invocation hotkey;
* default prompt mode;
* default model;
* auto-send on invocation: on/off.

#### Models

* add model;
* edit model;
* delete model;
* set default model;
* configure provider/base URL/model name;
* store API key in Keychain.

#### Capture

* enable Accessibility capture;
* enable clipboard fallback;
* restore clipboard after capture;
* include app/window title in prompt: on/off.

#### Response

* stream responses: on/off;
* response length preference:

  * concise;
  * normal;
  * detailed;
* default target language for Translate mode.

---

## 14. App states

### First launch

On first launch, show onboarding:

```text
1. Choose provider / enter API key.
2. Choose default model.
3. Set hotkey.
4. Enable Accessibility permission for selected-text capture.
5. Try selecting text and pressing the hotkey.
```

The app should remain usable after step 1 even if Accessibility is not enabled, via Services input/manual input.

### Normal operation

The app lives in the menu bar.

Menu bar menu:

```text
Ask Inline LLM
Settings…
History
Check Permissions
Quit
```

History can be minimal in MVP or disabled. If included, it should be local-only.

### No selected text

If invoked with no selection:

```text
No selected text detected.
Type or paste text below.
```

### API failure

Show a compact error:

```text
Request failed: invalid API key.
Open Settings
```

or:

```text
Request timed out.
Retry
```

### Permission failure

Show:

```text
Selected text could not be read from this app.
Try the right-click Services action, enable Accessibility permission, or type manually.
```

---

## 15. Data handling and privacy

The app should be explicit and conservative.

### MVP privacy principles

* No telemetry by default.
* No cloud backend owned by the app.
* API calls go directly from user’s machine to configured LLM provider.
* API keys are stored in macOS Keychain.
* Selected text is sent only after user invokes the tool.
* No background scraping.
* No persistent capture of screen contents.
* Local history should be optional.

### Local history

MVP options:

Either omit history entirely, or implement a simple local-only history with a toggle.

Recommended MVP default:

```text
History: off by default.
```

If enabled, store:

```swift
struct LocalHistoryItem: Codable {
    var timestamp: Date
    var selectedText: String
    var responseText: String
    var modelName: String
    var mode: PromptMode
    var appName: String?
}
```

No sync.

No analytics.

---

## 16. Technical architecture

### 16.1 Recommended stack

* Swift
* SwiftUI for settings and main panel content
* AppKit for:

  * menu bar app;
  * floating panel;
  * Services integration;
  * global hotkeys;
  * focus/window behavior;
* Keychain Services for API key storage
* URLSession for API calls
* async/await for networking
* optional streaming via Server-Sent Events or provider-specific streaming protocol

### 16.2 Major components

```text
App
├── MenuBarController
├── HotkeyManager
├── ServicesHandler
├── SelectionCaptureService
│   ├── AccessibilityCapture
│   ├── ClipboardFallbackCapture
│   └── ManualInputCapture
├── ContextBuilder
├── PromptBuilder
├── LLMClient
│   ├── OpenAICompatibleClient
│   ├── AnthropicClient optional
│   └── OpenRouterClient optional
├── FloatingPanelController
├── SettingsStore
├── KeychainStore
└── LocalHistoryStore optional
```

### 16.3 Request pipeline

```text
Invocation
→ Capture selected text
→ Build ContextBundle
→ Open floating panel
→ Choose mode/model
→ Build prompt
→ Send LLM request
→ Stream/render response
→ Allow follow-up
```

### 16.4 Prompt construction

Prompt payload should include:

```json
{
  "mode": "explain",
  "selected_text": "...",
  "frontmost_app": "Safari",
  "window_title": "Some Article",
  "user_instruction": null
}
```

Then transform into provider-specific API format.

The model should be told that app/window metadata is weak context and should not over-infer from it.

---

## 17. Services / right-click integration

The app should expose a macOS Service / Quick Action that accepts text input.

Suggested service names:

```text
Ask Inline LLM
Explain with Inline LLM
Summarize with Inline LLM
```

For MVP, one service is enough:

```text
Ask Inline LLM
```

When the service is triggered:

1. receive selected text;
2. launch app if not running;
3. open floating panel;
4. populate selection;
5. optionally auto-send using default mode/model.

The service path should not require Accessibility permission, because selected text is passed by the source app through the Services mechanism.

---

## 18. Global hotkey integration

The hotkey path should:

1. detect frontmost app;
2. attempt Accessibility capture;
3. fallback if enabled;
4. open panel.

Hotkey should be user-configurable.

Potential default:

```text
Option + Space
```

But if that conflicts, allow alternatives.

---

## 19. Response rendering

The response view should support:

* plain text;
* Markdown paragraphs;
* bullets;
* numbered lists;
* inline code;
* fenced code blocks;
* copy full response;
* copy code block, if feasible.

Do not overbuild rich formatting in MVP.

A clean, readable text view is enough.

---

## 20. Acceptance criteria

The MVP is complete when the following are true.

### Core workflow

* User can select text in a common macOS app and press a hotkey.
* App captures the selected text or gracefully reports failure.
* App sends selected text to configured LLM.
* App displays response in a floating panel.
* User can copy the response.
* User can ask a follow-up.

### Right-click workflow

* User can select text and invoke the app from the Services / Quick Actions menu.
* The selected text appears in the app.
* The response appears without opening a browser.

### Configurability

* User can enter an API key.
* API key is stored in Keychain.
* User can configure at least one model.
* User can select a model from the floating panel.
* User can choose at least three prompt modes: Explain, Summarize, Custom.

### Robustness

* App handles missing API key.
* App handles missing Accessibility permission.
* App handles no selected text.
* App handles network/API errors.
* App does not destroy clipboard contents unless user explicitly enabled clipboard fallback.

### Privacy

* No telemetry.
* No background capture.
* No selected text sent before user invokes action.
* No cloud backend.

---

## 21. MVP implementation sequence

### Milestone 1: Basic app shell

* menu bar app;
* settings window;
* API key entry;
* model config;
* basic floating panel.

### Milestone 2: Manual LLM request

* type/paste text into panel;
* send to configured model;
* render response;
* copy response.

### Milestone 3: Services integration

* add macOS Service accepting selected text;
* selected text populates panel;
* response generation works from right-click path.

### Milestone 4: Hotkey capture

* add global hotkey;
* implement Accessibility selected-text capture;
* handle permission flow;
* open panel with captured text.

### Milestone 5: Prompt modes and model selector

* Explain;
* Summarize;
* Define;
* Custom;
* model dropdown;
* default mode/model settings.

### Milestone 6: Follow-up

* allow user to ask follow-up;
* maintain short in-panel conversation state;
* include original selected text as context.

### Milestone 7: Polish and hardening

* error states;
* loading states;
* streaming if feasible;
* Markdown rendering;
* clipboard fallback optional;
* launch at login optional.

---

## 22. Later functionality

The MVP should be designed so the following can be added later without rewriting the app.

### 22.1 Richer context capture

Future context bundle:

```swift
struct RichContextBundle {
    var selectedText: String?
    var surroundingText: String?
    var fullDocumentText: String?
    var frontmostAppName: String?
    var frontmostWindowTitle: String?
    var currentURL: URL?
    var screenshot: Data?
    var ocrText: String?
    var domText: String?
    var sourceType: SourceType
}
```

Possible future sources:

* browser page text;
* current URL;
* document title;
* surrounding paragraph;
* full focused text field;
* screenshot of window;
* OCR from screenshot;
* PDF text;
* code file context;
* terminal buffer;
* Slack thread;
* selected table cells.

### 22.2 Browser extension

A browser extension could provide:

* exact selected text;
* surrounding DOM node;
* article text;
* URL;
* page title;
* headings;
* metadata;
* visible text only;
* structured context for web pages.

This would be superior to Accessibility for browser content.

### 22.3 Screenshot and vision mode

Future flow:

```text
select text or invoke hotkey
→ include screenshot toggle
→ send screenshot + selected text to vision-capable model
→ ask “what does this UI/error/chart mean?”
```

Requires Screen Recording permission.

### 22.4 OCR

Use local OCR to extract text from screenshots before sending to LLM.

Useful for:

* images;
* PDFs with poor text extraction;
* screenshots;
* video frames;
* apps that do not expose Accessibility text.

### 22.5 App-specific adapters

Add context adapters for:

* Safari;
* Chrome;
* Arc;
* Preview;
* PDF Expert;
* VS Code;
* Cursor;
* Terminal/iTerm;
* Slack;
* Obsidian;
* Notion;
* Apple Notes.

Each adapter can expose better context than generic Accessibility.

### 22.6 Replace selected text

Future rewrite flow:

```text
select text
→ Rewrite
→ preview output
→ Replace selection
```

This requires more careful app interaction and should not be in the MVP.

### 22.7 Local models

Support local inference through:

* Ollama;
* LM Studio;
* llama.cpp server;
* local OpenAI-compatible endpoint.

Useful for privacy-sensitive selections.

### 22.8 History and memory

Possible later features:

* local-only history;
* per-app history;
* per-page history;
* pinned answers;
* semantic search over past selections;
* “remember this as project context.”

Default should remain privacy-preserving.

### 22.9 Advanced routing

Future model router:

```text
short selected term → fast cheap model
code → code-capable model
screenshot included → vision model
long document → large-context model
private mode → local model
```

### 22.10 PopClip-style floating trigger

Instead of relying only on hotkey/right-click, the app could show a tiny floating action pill immediately after text selection:

```text
[Ask] [Explain] [Rewrite]
```

This would likely be the smoothest final UX, but it is not necessary for MVP.

---

## 23. One-sentence product definition

A native macOS menu-bar utility that turns selected text anywhere on the screen into a lightweight, configurable, inline LLM interaction without opening a browser or full chat app.
