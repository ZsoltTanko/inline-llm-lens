# Extending the app

Recipes for the most common changes. Each recipe lists the files you'll touch and the order to do it in. Read [`ARCHITECTURE.md`](ARCHITECTURE.md) first.

## Add a new LLM provider

The MVP ships only `OpenAICompatibleClient`, but the protocol seam is in place. Adding a native Anthropic / Gemini / Bedrock client is a localized change.

1. **Add an enum case** in `InlineLLMLens/Models/ProviderKind.swift`:

   ```swift
   enum ProviderKind: String, Codable, CaseIterable, Identifiable {
       case openAICompatible
       case anthropic   // new

       var displayName: String {
           switch self {
           case .openAICompatible: return "OpenAI-compatible"
           case .anthropic:        return "Anthropic"
           }
       }
   }
   ```

2. **Implement `LLMProvider`** in a new file under `InlineLLMLens/LLM/`:

   ```swift
   final class AnthropicClient: LLMProvider {
       func complete(request: LLMRequest) async throws -> LLMResponse { ... }
       func streamResponse(request: LLMRequest) async throws -> AsyncThrowingStream<LLMToken, Error> { ... }
   }
   ```

   Translate the provider-neutral `LLMRequest` (which contains `[ChatMessage]` with `system`/`user`/`assistant` roles) into the vendor's wire format. For Anthropic, hoist any `system` messages into the top-level `system` field and convert the rest to `messages: [{role, content}]`.

   Reuse the streaming-tuned URLSession pattern from `OpenAICompatibleClient.makeStreamingSession()` — disable the URL cache, use `.reloadIgnoringLocalCacheData`, set generous `timeoutIntervalForResource`. SSE buffering with `URLSession.shared` is real and bites every provider.

3. **Wire it into the registry** in `InlineLLMLens/LLM/ProviderRegistry.swift`:

   ```swift
   func provider(for model: ModelConfig) -> LLMProvider {
       switch model.provider {
       case .openAICompatible:
           return OpenAICompatibleClient { [keychain] cfg in
               keychain.readAPIKey(account: cfg.apiKeyReference)
           }
       case .anthropic:
           return AnthropicClient { [keychain] cfg in
               keychain.readAPIKey(account: cfg.apiKeyReference)
           }
       }
   }
   ```

4. **Tests.** Copy `OpenAICompatibleClientTests.swift` and adapt to the vendor's response shapes. The `StubURLProtocol` pattern works for any URLSession-based client.

5. **No UI change required** — `ModelsSettingsView` already iterates `ProviderKind.allCases` for the picker. New providers appear automatically.

## Add a new prompt mode

1. **Add a case** in `InlineLLMLens/Prompt/PromptMode.swift` and update `displayName`.
2. **Add the mode-specific system instruction** in `InlineLLMLens/Prompt/SystemPrompts.swift` inside the `instruction(for:translateTarget:lengthHint:customInstruction:)` switch.
3. **Test** in `InlineLLMLensTests/PromptBuilderTests.swift` — assert the new instruction appears in the system message and the selected text appears in the user message.
4. The `ModePicker` view auto-discovers new cases.

## Add a new capture strategy

`SelectionCaptureService` runs strategies in priority order. Adding a new one means adding a file under `Capture/` and slotting it into the orchestrator.

Example: a "browser DOM via AppleScript" strategy for Safari/Chrome.

1. **Add a case** in `InlineLLMLens/Capture/CaptureMethod.swift` (e.g. `.browserDom`).
2. **Implement the strategy** in `InlineLLMLens/Capture/BrowserDomCapture.swift` with an `async` static method returning `String?`.
3. **Insert into the priority chain** in `SelectionCaptureService.captureForHotkey()`. Decide where it slots — for browsers it should go *before* `.accessibility` because AX of web content is nearly useless.
4. **Plumb any toggles** through `SettingsStore` (e.g. `enableBrowserDomCapture`) and surface them in `Settings/CaptureSettingsView`.
5. **Note for the spec.** Adding capture methods is squarely on the post-MVP roadmap (spec §22.1, §22.2, §22.5). Confirm with the spec owner before shipping a new one.

## Add a new setting

For a typed boolean / string / enum setting:

1. **Add a key** to `SettingsStore.Keys` in `InlineLLMLens/Storage/SettingsStore.swift`.
2. **Register a default** in `SettingsStore.init()`.
3. **Add a typed accessor** on `SettingsStore` (mirror the existing pattern — `objectWillChange.send()` after writing).
4. **Bind a UI control** in the appropriate `Settings/*View.swift` using either `@AppStorage(SettingsStore.Keys.foo)` (for SwiftUI-only views) or a `Binding(get:set:)` against the store.
5. **Use the setting** wherever it changes behavior. Tests for any logic gated by the setting belong in the relevant module's test file.

## Add a new field to `ModelConfig`

`ModelConfig` is `Codable` and persisted to JSON. Optional fields are backward-compatible by default.

1. **Add the field** as `Optional` in `InlineLLMLens/Models/ModelConfig.swift`. Update the `init` defaults.
2. **Surface it in the editor** — add a `@State` and a `TextField` / `Toggle` in `ModelsSettingsView.ModelEditor`. Map it back into `draft` on Save.
3. **Use it downstream** — usually inside `OpenAICompatibleClient.buildRequest` (or your new provider). Send the field only when non-empty so non-supporting models aren't broken.
4. **Write a test** if the field changes wire-format output. The `URLProtocol` stub in `OpenAICompatibleClientTests` can capture the request body and assert against it.

`reasoningEffort` (added late in MVP) is the canonical example — search the codebase for it to see all the touch points.

## Change the default hotkey

Edit the default in `InlineLLMLens/Hotkey/ShortcutNames.swift`:

```swift
static let invokePanel = Self("invokePanel", default: .init(.space, modifiers: [.option]))
```

Existing users won't be affected — `KeyboardShortcuts` persists their choice once they change it via Settings → General.

## Add a menu bar item

Edit `InlineLLMLens/MenuBar/MenuBarController.buildMenu()`. Wire its action to a new closure passed in the initializer, and route the closure to the appropriate `AppDelegate` method.

## Things you should not do without spec sign-off

The spec ([`../mvp_spec.md`](../mvp_spec.md) §5) explicitly excludes these from the MVP. Don't add them as side projects:

- Screenshot capture or OCR (§22.3, §22.4).
- Browser extension (§22.2).
- Per-app adapters beyond the generic AX path (§22.5).
- Auto-replace selected text (§22.6).
- Any cloud backend, account, sync, or telemetry (§15, §22.8).
- A multi-window chat-history browser.
- Full DOM extraction.

If a user asks for one of these, point them at the spec section and the post-MVP roadmap.
