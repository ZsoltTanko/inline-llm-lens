# Troubleshooting

These are the macOS-integration potholes this project has hit during development. Read this before debugging anything that "should just work" but doesn't. Almost all of them are macOS quirks, not bugs in our code, but they require knowing the workaround.

## Quick triage

**AX trust:** An orange dot appears in the panel header (next to the gear icon) when Accessibility access is not granted. If you see it → it's a permissions issue. Hover the dot for a short description.

**Capture method:** The panel no longer shows the capture method inline. Check the log for `SelectionCaptureService` events — it logs the chosen strategy and text length on every invocation. If a real selection is producing an empty result, the source app likely doesn't expose text via AX; switch to right-click Services or enable clipboard fallback in Settings → Capture.

Tail the log for everything:

```bash
log stream --predicate 'subsystem == "com.inlinellmlens"' --level info
```

---

## Hotkey doesn't capture selected text

### Symptom

Press the global hotkey with text selected, the panel opens, but the selection is empty and the panel says "No selection detected" or "Accessibility access is not granted".

### Cause and fix

The hotkey path uses macOS Accessibility APIs, which require **Accessibility permission** for the app's bundle.

1. Press the hotkey **once** with the app running. A system dialog should appear asking for Accessibility access. Click **Open System Settings**.
2. In **Privacy & Security → Accessibility**, toggle the `InlineLLMLens` row on.
3. **Quit the app** (menu-bar icon → Quit) and **relaunch** it. AX trust is cached at process start; the running process never sees the new permission until it restarts.
4. Press the hotkey again with text selected. The orange dot in the panel header should disappear, and the log should show `capture: accessibility`.

### If a stale row is stuck

Sometimes a previous build's bundle is still in the Accessibility list and the system uses *that* row's setting:

1. Open **System Settings → Privacy & Security → Accessibility**.
2. Select any `InlineLLMLens` row, click **–**, confirm.
3. Quit the app, relaunch, press the hotkey to re-trigger the prompt, re-grant. Quit and relaunch one more time.

### If AX is granted but capture is still empty

That means the source app doesn't expose selected text via AX. Known cases:

- **Google Chrome / Safari web content / any browser** — web pages are rendered, not exposed as AX text. `kAXSelectedTextAttribute` returns nothing for the rendered text inside a web view.
- **Terminal.app, iTerm2** — same problem; the terminal buffer isn't a standard AX text element.
- **Electron apps** (VS Code, Slack, Discord, …) — most don't implement AX correctly.

Workarounds for these apps:

- Use **right-click → Services → Ask Inline LLM** instead. Services are populated by the source app via the system pasteboard, which web/terminal/Electron apps do support.
- Or enable **Settings → Capture → "Enable clipboard fallback"** (off by default per spec). When AX returns nothing, the app simulates Cmd+C, reads the clipboard, and restores it. Works in Chrome and most other apps but is invasive — it briefly takes over the system pasteboard.

Native AppKit text views (TextEdit, Notes, Mail composer, Messages, Pages, Xcode editors) work via AX directly.

---

## Services menu entry doesn't appear

### Symptom

Select text in any app, right-click → Services. "Ask Inline LLM" is missing.

### Cause and fix

macOS Services discovery is two layers of cache. Both can be stale.

**Layer 1: Launch Services index.** The app must be registered with Launch Services. This happens automatically for apps in `/Applications`, but for dev builds in `<repo>/build/Build/Products/Debug/` you need to nudge it:

```bash
APP="$(pwd)/build/Build/Products/Debug/InlineLLMLens.app"
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "$APP"
/System/Library/CoreServices/pbs -update
```

If the Services system is really stuck:

```bash
/System/Library/CoreServices/pbs -flush
/System/Library/CoreServices/pbs -update
```

**Layer 2: Per-app cache.** Each *consuming* app reads the Services menu when it launches. After registering, you must **quit and relaunch the consuming app** (TextEdit, Notes, …) before the new entry appears in *its* Services menu.

**Layer 3: User opt-in.** macOS hides text-Services the user hasn't enabled. Open **System Settings → Keyboard → Keyboard Shortcuts → Services**, scroll to **Text** at the bottom, ensure **Ask Inline LLM** is ticked.

### Where the Services entry actually appears

Different apps surface Services differently:

- Right-click in TextEdit, Notes, Mail: usually a top-level **Services** submenu near the bottom of the context menu.
- The application menu always works: e.g. **TextEdit → Services → Ask Inline LLM**.
- Some browsers and Electron apps put Services very low in the context menu or omit them.

### Verify the Service is registered at the system level

```bash
/System/Library/CoreServices/pbs -dump_pboard | grep -A4 askInlineLLM
```

You should see:

```
NSMessage = askInlineLLM;
NSPortName = InlineLLMLens;
NSSendTypes = (
    "public.utf8-plain-text",
    NSStringPboardType
);
```

If that's present, the system knows about the Service. The problem is then in the consuming app's cache or the user-enable toggle.

---

## Settings window won't open

### Symptom

Click the menu-bar icon → "Settings…". Nothing visible happens. Or the window flashes and immediately disappears. Or clicking the gear inside the floating panel closes the panel but doesn't open Settings.

### Cause

Menu-bar apps with `LSUIElement = YES` run with `NSApp.activationPolicy = .accessory`. The **old** implementation used SwiftUI's `Settings { }` scene, which does not present reliably under `.accessory`; it worked around that with a 100 ms delay + `NSApp.sendAction(Selector(("showSettingsWindow:")), …)` plus closing the floating panel first. All three were flaky: the gear button in the panel would sometimes dismiss the panel and then fail to reopen Settings.

The app now owns the Settings window directly via `SettingsWindowController` (AppKit — `NSWindow` + `NSHostingController`). The `Settings { }` scene is intentionally empty (`Settings { EmptyView() }`) and exists only to satisfy the `App` protocol.

If Settings still won't open, check:

- The activation-policy switch (`NSApp.setActivationPolicy(.regular)`) must run before `SettingsWindowController.shared.show()`.
- `observeSettingsCloseOnce()` must still be wired; otherwise the app will stay in `.regular` after you close Settings (a cosmetic issue — Dock icon lingers — not a blocker).

### Fix in code

Look at `InlineLLMLens/App/AppDelegate.swift`. The pattern is:

```swift
static func openSettings() {
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)

    // Do NOT close the floating panel. Settings is a sibling window; the
    // click-off observer in `FloatingPanelController` ignores resignKey
    // when another of our windows becomes key.
    SettingsWindowController.shared.show()
    shared.observeSettingsCloseOnce()
}

private func observeSettingsCloseOnce() {
    // Subscribe to NSWindow.willCloseNotification, match on identity via
    // SettingsWindowController.isSettingsWindow(window), hop one runloop
    // tick to let visibility settle, revert activation policy to .accessory.
}
```

If you need to add Esc-to-close or similar window-level behaviour, do it on the private `SettingsWindow` subclass inside `SettingsWindowController.swift` (it overrides `cancelOperation(_:)` to call `performClose(nil)`) rather than bolting a SwiftUI `.onExitCommand` onto `SettingsRoot`.

**Do not** revert the activation policy in `applicationDidResignActive`. We tried — it races with window presentation and silently kills the Settings window before it can show. Use the explicit `willCloseNotification` observer instead.

**Do** leave the floating panel up while opening Settings — they are designed as sibling windows. The panel's click-off observer in `FloatingPanelController` explicitly ignores `resignKey` when another of our own windows (Settings, Onboarding, an alert) becomes key, so none of the three panel click-off behaviours (stay on top / recede / close) will fire from opening Settings. If your Settings window opens and *appears* to immediately vanish, it's likely being sent behind the `.floating`-level panel; bring focus back to Settings via Cmd-Tab or click its titlebar.

---

## Per-preset hotkey "crashes" the app

### Symptom

Configuring a global hotkey for a prompt preset, then pressing it, makes the menu-bar icon briefly vanish and the panel either never appears or flashes. Looks like a crash.

### Cause

`KeyboardShortcuts.onKeyDown(for:)` is **additive** — calling it twice for the same `Name` registers two handlers, and the library has no public per-name handler-removal API. The app previously registered per-preset handlers once from `applicationDidFinishLaunching` *and* again from the `@Published presets` sink's synchronous current-value emission, then additionally on every preset save. Each press of the hotkey fired N copies of `invokeFromHotkey(preset:)` concurrently — each spawning a Task that activated the app, simulated Cmd+C, snapshotted/restored the pasteboard, and presented the panel. The overlapping work is what looked like a crash.

### Fix / how to keep it fixed

`HotkeyManager.syncPresetHotkeys(...)` now calls `KeyboardShortcuts.removeAllHandlers()` before re-installing the global + per-preset handlers. The `presetStore.$presets` subscription in `AppDelegate` uses `.dropFirst()` so the synchronous initial emission doesn't re-register. Don't call `onKeyDown(for: someName)` anywhere else — all hotkey registration must go through `HotkeyManager.syncPresetHotkeys(...)`, which is idempotent by construction.

---

## Streaming feels slow to start

### Symptom

User selects text, hits the hotkey, the panel opens with a spinner, but tokens don't begin appearing for 5–30 seconds.

### Diagnose

Trigger one request and read the timing logs:

```bash
log show --predicate 'subsystem == "com.inlinellmlens"' --info --last 2m | grep "LLM"
```

You'll see three lines:

```
LLM stream request started: <model>
LLM headers received in N.NNs
LLM first delta in N.NNs
```

### Three possible causes

1. **Reasoning model TTFT.** If `headers received` is fast (< 1s) but `first delta` is many seconds later, the model itself is "thinking" before producing visible tokens. This is normal for reasoning models (`o1`, `o3-mini`, `gpt-5*` reasoning variants, etc.). Set `reasoning_effort: minimal` on the model in **Settings → Models → Edit → Reasoning** to drop it dramatically. Or use a non-reasoning model (`gpt-4o-mini`, `gpt-4o`, `claude-3-5-haiku`) for the snappy lens experience and reserve reasoning models for explicit "Critique" requests. Per the spec's "Fast / Deep" pattern, configure two models and switch in the panel.
2. **Cold connection.** First request after a long idle pays DNS + TCP + TLS. Should be < 2s and only on the first call.
3. **URLSession buffering.** Already mitigated. `OpenAICompatibleClient.makeStreamingSession()` uses a dedicated `URLSession` with `urlCache = nil` and `requestCachePolicy = .reloadIgnoringLocalCacheData`. If you change this back to `URLSession.shared`, expect SSE chunks to be buffered for several seconds before being delivered to `.lines`.

---

## "API key" errors with localhost endpoints

### Symptom

You configured an Ollama or LM Studio model with base URL `http://localhost:11434/v1`, didn't enter an API key, and got `LLMError.missingAPIKey`.

### Cause and fix

`OpenAICompatibleClient.buildRequest` skips the `Authorization: Bearer …` header for `localhost`, `127.0.0.1`, and `::1`. If your local server runs on a different hostname or `host.docker.internal`, the client demands a key.

Either change the model's base URL to `http://localhost:…` (recommended), or enter any non-empty placeholder API key — the local server will ignore it.

---

## Keyboard shortcut conflicts

### Symptom

The default Option+Space hotkey doesn't fire, or it fires but the wrong app comes to the foreground.

### Cause

Another app or system component is registered for the same shortcut globally. macOS Spotlight is on Cmd+Space, not Option+Space, but some users remap or have third-party launchers (Alfred, Raycast) on Option+Space.

### Fix

**Settings → General → Global hotkey** lets you record a different combination. The `KeyboardShortcuts` package will handle conflict detection and refuse to bind a shortcut already in use globally.

---

## App is sandboxed and can't reach an API

### Symptom

`LLMError.transport(NSURLErrorDomain Code=-1003)` or similar network errors that don't reproduce with `curl` from your terminal.

### Cause

The entitlements file (`InlineLLMLens/App/InlineLLMLens.entitlements`) sets `com.apple.security.app-sandbox = false`, which is required for arbitrary-host network access without a per-host exception. If you (or a future release pipeline) re-enable the sandbox, you must add explicit network entitlements and may need to handle TCC flows for outbound connections.

For MAS distribution this becomes mandatory and substantially restructures the entitlements story. Don't enable the sandbox casually for development.

---

## Tests fail with weird "default model already set" errors

### Symptom

`ModelStoreTests` fail intermittently, complaining about wrong default-model UUIDs.

### Cause

Earlier versions of `ModelStore` read `defaultModelID` from `UserDefaults.standard` directly, which leaked across test runs. This was fixed by giving `ModelStore` an injectable `UserDefaults`.

### Fix

Always construct test `ModelStore` instances with a per-test suite:

```swift
let defaults = UserDefaults(suiteName: "ModelStoreTests-\(UUID().uuidString)")!
let store = ModelStore(fileURL: tmp, defaults: defaults)
```

Mirror this pattern for any new test that touches stored state.

---

## Rebuilding doesn't pick up changes / app behaves like the old version

If iterative `xcodebuild` runs seem to use stale code:

1. Quit the app (`killall InlineLLMLens`).
2. Delete `build/`.
3. Re-run `xcodegen generate` if you edited `project.yml`.
4. Rebuild.
5. Re-run `lsregister -f` on the new bundle so Launch Services and Services menu point at the new binary.

The Launch Services index in particular is sticky — without `lsregister -f`, double-clicking the rebuilt `.app` may launch a previously-known copy.

---

## Anything else

Capture the `os.Logger` stream (see Quick triage above), file an issue, and link to the relevant spec section if behavior diverges from intent.
