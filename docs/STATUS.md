# MVP status

What's shipped vs. what's deliberately deferred. Read alongside [`../mvp_spec.md`](../mvp_spec.md), which is the source of truth for scope.

## Spec milestones

| Milestone | Spec § | Status | Notes |
| --- | --- | --- | --- |
| M1 — App shell (menu bar, Settings, Keychain, basic panel) | §21 | ✅ | |
| M2 — Manual LLM request (type/paste, send, render, copy) | §21 | ✅ | |
| M3 — Services / right-click integration | §21 | ✅ | Requires `lsregister` + user opt-in for dev builds; see [`TROUBLESHOOTING.md`](TROUBLESHOOTING.md). |
| M4 — Hotkey + Accessibility capture | §21 | ✅ | Default Option+Space; bounded BFS over the AX tree. |
| M5 — Prompt modes + model selector | §21 | ✅ | All seven modes (Explain, Define, Summarize, Rewrite, Translate, Critique, Custom). |
| M6 — Follow-up | §21 | ✅ | In-panel `[ChatMessage]` conversation state; Cmd+Enter to send. |
| M7 — Polish (streaming, Markdown, clipboard fallback, launch-at-login) | §21 | ✅ | SSE streaming via dedicated tuned URLSession. |

## Provider support

Per the planning round, the MVP intentionally ships **only the OpenAI-compatible provider** behind the `LLMProvider` protocol. This single client covers OpenAI, OpenRouter, Ollama (local), LM Studio (local), and any compatible endpoint by varying `baseURL` + `modelName`. Adding a native Anthropic / Gemini / Bedrock client is a localized change documented in [`EXTENDING.md`](EXTENDING.md).

A `reasoning_effort` field on `ModelConfig` was added late in development to support OpenAI's reasoning models without bloating TTFT — sent in the request body only when non-empty.

## Acceptance criteria

The spec's §20 acceptance criteria are all met to the extent possible without per-app testing across all consuming apps:

- ✅ Hotkey-driven flow with graceful failure when AX is unavailable.
- ✅ Right-click Services flow with selected text passed in.
- ✅ Configurable models, Keychain-stored keys, model picker in panel.
- ✅ ≥3 modes (we ship 7).
- ✅ Robustness: missing API key, missing AX, no selection, network errors, no clipboard destruction unless explicitly enabled.
- ✅ Privacy: no telemetry, no background capture, no cloud backend, selection only sent on explicit invocation.

## Known limitations

These are user-facing limitations baked into the MVP shape, not bugs:

- **Browser web content, Terminal, Electron apps don't expose AX text** — hotkey path returns empty for them. Workarounds: use right-click Services or enable clipboard fallback. Per spec §22.2/22.5, dedicated browser extensions and per-app adapters are post-MVP.
- **`Settings…` briefly shows a Dock icon** while open — required by SwiftUI's `Settings { }` scene under `LSUIElement`. Acceptable per spec UX bar; not worth the engineering cost to fix in MVP.
- **No history UI** — `LocalHistoryStore` is scaffolded and feature-flagged off by default (spec §15 recommendation). When enabled, history is written to `~/Library/Application Support/InlineLLMLens/history.json`. There's no in-app browser for it yet (spec §22.8).
- **First request after long idle pays TLS setup cost** (~1–2s for OpenAI). Subsequent requests reuse the connection.

## Explicit non-goals (spec §5)

These are not in MVP and won't be without spec sign-off:

- Browser DOM extraction
- Screenshot capture / OCR / PDF structure
- Per-app adapters (Safari, Chrome, VS Code, Cursor, Slack, Notion, …)
- Autonomous background monitoring
- Local vector memory / RAG over selections
- Multi-window history browser
- Cloud accounts, sync, billing, plugin marketplace
- Mobile / Windows / Linux

## What a contributor should pick up next

If you're new and looking for a high-value first PR:

1. **Add CI** — GitHub Actions on macOS runners running `xcodegen generate && xcodebuild test`. We have none.
2. **Improve the AX BFS** — currently bounded at depth 6. Some apps put text-bearing elements deeper or behind `kAXVisibleChildrenAttribute`. Pick a real-world app it fails in and fix it.
3. **Pre-seed model templates** — first-launch onboarding could offer one-click templates for OpenAI / OpenRouter / Ollama instead of an empty Models tab.
4. **Add a "thinking… 12s" elapsed timer** to the panel while waiting for first delta from reasoning models.
5. **Add a clipboard-fallback toggle to the panel header** so users can opt in per-invocation rather than globally.

Anything bigger than these — read the spec's §22 (later functionality) and align with the spec owner first.
