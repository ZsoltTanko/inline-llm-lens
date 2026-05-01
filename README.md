# Inline LLM Lens

A native macOS menu-bar utility that turns selected text anywhere on screen into a lightweight, configurable, inline LLM interaction without opening a browser or full chat app.

> One-sentence definition (from [`mvp_spec.md`](mvp_spec.md) §23).

## What it does

Select text in any app → trigger via global hotkey *or* right-click Services menu → see a small floating panel near your context with the LLM's answer streaming in. Optionally choose a different model or prompt mode, copy the result, ask a follow-up.

The product is positioned as **an inline semantic lens**, closer to Spotlight / PopClip / Apple Dictionary lookup than to a full chat app. Optimized for low interaction friction, frequent invocation, and minimal visual disruption.

For the full product spec — problem framing, user stories, UX, prompt modes, non-goals, acceptance criteria, future roadmap — read [`mvp_spec.md`](mvp_spec.md). It is the source of truth for **what** and **why**; this codebase implements it.

## Status

MVP. All seven milestones from the spec (§21) are implemented and the app builds, runs, and ships its core loop end-to-end. See [`docs/STATUS.md`](docs/STATUS.md) for a per-milestone breakdown and what's deliberately out of scope.

## Quick start (users)

1. Install [XcodeGen](https://github.com/yonaskolb/XcodeGen) once: `brew install xcodegen`.
2. Generate the Xcode project: `xcodegen generate`.
3. `open InlineLLMLens.xcodeproj`, hit Cmd+R.
4. The app appears in the menu bar (no Dock icon — it's an `LSUIElement` agent).
5. Click the menu-bar icon → **Settings…** → **Models** → **+ Add Model** to configure your provider (OpenAI, OpenRouter, Ollama, LM Studio, etc.). API keys are stored in the macOS Keychain.
6. Click **Settings… → Permissions** to grant Accessibility access (only required for the global-hotkey path).
7. Select text in any app and either:
   - Press **Option+Space** (configurable in Settings → General), or
   - Right-click → **Services → Ask Inline LLM**.

If a Service entry doesn't appear in the right-click menu, see [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md#services-menu-entry-doesnt-appear).

## Quick start (contributors)

Read these in order:

1. [`mvp_spec.md`](mvp_spec.md) — what we're building and why.
2. [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — how the codebase is laid out, the request pipeline, key types, threading model.
3. [`docs/DEVELOPMENT.md`](docs/DEVELOPMENT.md) — environment setup, build, run, test, debug, log capture.
4. [`docs/EXTENDING.md`](docs/EXTENDING.md) — recipes for adding a provider, prompt mode, or capture strategy.
5. [`docs/TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md) — the hard-won macOS-specific gotchas we hit during MVP development. Read this *before* you debug anything weird.

## Repository layout

```text
text-select-llm/
├── README.md                  This file
├── mvp_spec.md                Product spec (source of truth for behavior)
├── project.yml                XcodeGen spec; generates InlineLLMLens.xcodeproj
├── .gitignore
├── docs/
│   ├── ARCHITECTURE.md
│   ├── DEVELOPMENT.md
│   ├── EXTENDING.md
│   ├── TROUBLESHOOTING.md
│   └── STATUS.md
├── InlineLLMLens/             Application source (Swift, organized by feature module)
│   ├── App/                   App entry point, AppDelegate, Info.plist, entitlements
│   ├── MenuBar/               NSStatusItem + menu
│   ├── Hotkey/                Global hotkey via KeyboardShortcuts SPM package
│   ├── Services/              macOS Services / right-click integration
│   ├── Capture/               Selected-text capture strategies (AX, clipboard, manual)
│   ├── Prompt/                PromptMode enum + system prompts + PromptBuilder
│   ├── LLM/                   LLMProvider protocol + OpenAI-compatible client
│   ├── Models/                ModelConfig + ModelStore
│   ├── Storage/               KeychainStore, SettingsStore, optional history
│   ├── Panel/                 Floating NSPanel + SwiftUI panel content
│   ├── Settings/              SwiftUI Settings scene (5 tabs)
│   ├── Onboarding/            First-launch onboarding window
│   └── Util/                  Logger, debouncer, launch-at-login
└── InlineLLMLensTests/        XCTest unit tests
```

## High-level architecture

```
Hotkey | Services
      ↓
  SelectionCaptureService  →  ContextBundle
      ↓                            ↓
  FloatingPanelController  →  PanelViewModel
                                   ↓
                           PromptBuilder
                                   ↓
                           ProviderRegistry
                                   ↓
                       OpenAICompatibleClient
                                   ↓
                  AsyncThrowingStream<LLMToken>
                                   ↓
                           PanelView (SwiftUI)
```

Full diagrams and module-by-module narrative in [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md).

## Tech stack

- **Language:** Swift 5.9+, targeting macOS 14+.
- **UI:** SwiftUI for panel content and settings; AppKit for `NSStatusItem`, `NSPanel`, Services, activation policy.
- **Hotkey:** [`sindresorhus/KeyboardShortcuts`](https://github.com/sindresorhus/KeyboardShortcuts) (SPM).
- **Markdown rendering:** [`gonzalezreal/swift-markdown-ui`](https://github.com/gonzalezreal/swift-markdown-ui) (SPM).
- **Networking:** `URLSession` with `bytes(for:).lines` for SSE streaming. No third-party HTTP lib.
- **Storage:** `UserDefaults` for prefs, JSON file in Application Support for `[ModelConfig]`, macOS Keychain (`SecItem*` APIs) for API keys.
- **Project generation:** XcodeGen — the `.xcodeproj` is regenerable from `project.yml`, so it's gitignored.

## Privacy

- No telemetry. No analytics. No crash reporting.
- No backend owned by this app — API calls go directly from the user's machine to their configured provider.
- API keys live in the macOS login Keychain.
- No background scraping. The app never reads selected text or pasteboard contents until the user explicitly invokes it.
- Local history is **off by default**; when enabled, stored as a JSON file on disk only.

See [`mvp_spec.md`](mvp_spec.md) §15 for the full privacy stance.

## License

Internal MVP — license TBD before any public release.
