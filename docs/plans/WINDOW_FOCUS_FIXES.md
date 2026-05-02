# Window, Focus & Settings Fixes — Spec

Status: **Draft for review.** Implement after sign-off.

## Scope

Fix four related bugs in the floating panel / Settings window lifecycle, and
add a user-facing setting to control what happens when the panel loses focus.

## Audit: how windows and focus work today

### Key files

- `InlineLLMLens/Panel/FloatingPanel.swift` — `NSPanel` subclass. Style mask:
  `[.borderless, .resizable, .fullSizeContentView, .nonactivatingPanel]`.
  `level = .floating`, `canBecomeKey = true`, `canBecomeMain = false`,
  `hidesOnDeactivate = false`, `becomesKeyOnlyIfNeeded = false`.
- `InlineLLMLens/Panel/FloatingPanelController.swift` — owns the panel, calls
  `NSApp.activate(ignoringOtherApps: true)` + `makeKeyAndOrderFront` on
  `present(...)`, exposes `close()` that calls `orderOut`.
- `InlineLLMLens/Panel/PanelView.swift` — SwiftUI root. Esc is wired via
  `.onExitCommand { ... }` on the outer `VStack`. Gear button calls
  `AppDelegate.openSettings()`.
- `InlineLLMLens/App/AppDelegate.swift` — `openSettings()` is static. It
  (1) switches `NSApp.setActivationPolicy(.regular)`, (2) activates the app,
  (3) **calls `shared.panelController.close()` unconditionally**, (4) after a
  100 ms delay, `NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)`.
  A `willCloseNotification` observer flips activation policy back to
  `.accessory` once Settings closes.
- `InlineLLMLens/MenuBar/MenuBarController.swift` — status-bar "Settings…"
  item also calls `AppDelegate.openSettings()`.
- `InlineLLMLens/App/InlineLLMLensApp.swift` — SwiftUI `App` with a single
  `SettingsScene()` (i.e. SwiftUI `Settings { }` scene). This is the only
  Settings window surface in the app.
- `InlineLLMLens/Storage/SettingsStore.swift` — `UserDefaults`-backed prefs,
  shared singleton. No current key for click-off behaviour.

### Root causes of the reported bugs

**Bug 1 — Esc only works after clicking into a text field.**

`.onExitCommand` in SwiftUI is delivered through the AppKit responder chain
to the view that is the first responder. When the panel is shown via
`makeKeyAndOrderFront`, the first responder is the panel / hosting view
root, not a specific SwiftUI view, so `.onExitCommand` is not invoked and
AppKit walks off the end of the chain → system beep ("not valid" sound).
Clicking into the "Type or paste text…" `TextField` or the follow-up
`TextField` moves first-responder into a SwiftUI focusable view, after
which `.onExitCommand` fires correctly. Clicking the header bar doesn't
change first responder, so Esc still beeps.

**Bug 2 — Gear button "closes the panel and doesn't open Settings".**

`AppDelegate.openSettings()` calls `shared.panelController.close()`
*unconditionally* before opening Settings. Part of what the user sees is
"the panel closes" — that's this line. The "Settings doesn't open" part is
a secondary failure: by the time the 100 ms-delayed
`sendAction(showSettingsWindow:)` fires, the button's window (the panel)
has been order-out'd, so first-responder targeting via `to: nil` can miss,
and the SwiftUI `Settings` scene is finicky about reopening once the
activation policy has just flipped. Net effect matches the report.

**Bug 3 — Menu-bar "Settings…" closes the panel but doesn't open Settings.**

Same call path (`MenuBarController → onSettings → AppDelegate.openSettings`),
same `panelController.close()` side effect, same flakey `sendAction` reopen.

**Bug 4 — No way to control click-off behaviour.**

The panel is `.floating` + `hidesOnDeactivate = false`, so clicking off
leaves it on top. There is no setting or code path to make it behave like
a normal window (recede to background) or auto-dismiss on click-off.

## Fixes

### Fix 1 — Esc always closes the panel

Handle Esc at the `NSPanel` level, not at the SwiftUI level. Override
`cancelOperation(_:)` on `FloatingPanel` (AppKit sends this up the
responder chain on Esc) and call the controller's close action.

Concretely:

- Give `FloatingPanel` a closure property, e.g. `var onCancel: (() -> Void)?`.
- Override `cancelOperation(_ sender: Any?)` to invoke `onCancel?()`. Do
  **not** call `super` (the default walks further up and beeps).
- In `FloatingPanelController.init`, assign `panel.onCancel = { [weak self] in self?.close() }`.
- Keep the existing `.onExitCommand` in `PanelView` too, but special-case
  it for collapsing the follow-up bar first (current behaviour). When the
  follow-up bar is not visible, let it fall through to the panel-level
  handler (i.e. do nothing in the SwiftUI closure in that case and rely on
  `cancelOperation`) — or, equivalently, keep calling `onClose()` from
  SwiftUI when follow-up is closed, since both paths end in the same
  `close()`.

  Cleanest: route the follow-up collapse from `cancelOperation` too. The
  panel can expose a weak reference to the `PanelViewModel` or a
  `shouldCollapseFollowUpFirst: () -> Bool` hook. Preferred implementation:
  a single `onCancel` closure on the controller that inspects view-model
  state:

  ```swift
  panel.onCancel = { [weak self] in
      guard let self else { return }
      if self.viewModel.isFollowUpOpen {
          self.viewModel.closeFollowUp()
      } else {
          self.close()
      }
  }
  ```

  This requires lifting `followUpVisible` + `followUpInput` state out of
  `PanelView` into `PanelViewModel` (it's currently local `@State`).
  That's a small refactor and the right place for it anyway.

### Fix 2 — Gear button opens Settings without closing the panel

1. Remove the `shared.panelController.close()` call from
   `AppDelegate.openSettings()`. The panel should not be dismissed by
   opening Settings from anywhere.
2. Replace the SwiftUI `Settings` scene with a dedicated AppKit window we
   fully control, so opening/closing is reliable regardless of activation
   policy and doesn't need the 100 ms delay dance:
   - New file `InlineLLMLens/Settings/SettingsWindowController.swift`
     (pattern mirrors `OnboardingWindow`): `NSWindow` + `NSHostingController`
     hosting the existing `SettingsRoot` (from `SettingsScene.swift`).
     Style mask: `[.titled, .closable, .miniaturizable, .resizable]`, title
     "Inline LLM Lens Settings", centered on first show, min size
     720×520, `isReleasedWhenClosed = false`, persisted frame via
     `setFrameAutosaveName("InlineLLMLensSettings")`.
   - A singleton `SettingsWindowController.shared.show()` that creates the
     window lazily and calls `makeKeyAndOrderFront(nil)` + activates the
     app.
3. In `AppDelegate.openSettings()`:
   - Switch activation policy to `.regular` (still needed so a window of a
     menu-bar-only app can become properly key and show in Cmd-Tab).
   - `NSApp.activate(ignoringOtherApps: true)`.
   - `SettingsWindowController.shared.show()` — no delay, no `sendAction`.
   - Keep the `willCloseNotification` observer pattern to flip activation
     policy back to `.accessory` when the Settings window closes. Match on
     `window === SettingsWindowController.shared.window` to avoid the
     current title/identifier heuristic.
4. Delete `InlineLLMLens/Settings/SettingsScene.swift` and remove
   `SettingsScene()` from `InlineLLMLensApp`. Replace with an empty
   `Settings { EmptyView() }` or simply no scene body at all (SwiftUI
   `App.body` still compiles with a `Settings { EmptyView() }`). We don't
   need the SwiftUI scene anymore.

This single change fixes Bugs 2 and 3 (gear + menu-bar Settings item) and
removes the brittle `sendAction` reopen path.

### Fix 3 — Add click-off behaviour setting

**Data model.** Add to `SettingsStore`:

```swift
enum PanelClickOffBehavior: String, CaseIterable, Identifiable {
    case stayOnTop    // default — matches current behaviour
    case sendToBack   // normal Mac window behaviour: recede behind active app
    case closePanel   // dismiss panel on click-off

    var id: String { rawValue }
    var label: String {
        switch self {
        case .stayOnTop:  return "Stay on top"
        case .sendToBack: return "Recede to background"
        case .closePanel: return "Close"
        }
    }
}
```

- Add `Keys.panelClickOffBehavior = "settings.panelClickOffBehavior"`.
- Register default: `PanelClickOffBehavior.stayOnTop.rawValue`.
- Typed accessor `var panelClickOffBehavior: PanelClickOffBehavior` that
  reads/writes via the raw string and `objectWillChange.send()` on set.

**UI.** In `GeneralSettingsView`, add a new section (above or below
"Appearance"):

```
Window behaviour
  Picker: "When clicking outside the panel"
    ○ Stay on top (default)
    ○ Recede to background
    ○ Close
  Caption: "Stay on top keeps the panel above other windows until you
  press Esc or close it. Recede to background behaves like a normal
  Mac window. Close dismisses the panel on click-off."
```

Use `@AppStorage(SettingsStore.Keys.panelClickOffBehavior)` bound to the
enum's `rawValue`.

**Runtime behaviour.** Implemented in `FloatingPanelController` (or the
panel itself) by observing `NSWindow.didResignKeyNotification` for the
panel.

Dispatch the handler on the next runloop tick (`DispatchQueue.main.async`)
so that `NSApp.keyWindow` is settled; then:

- If `NSApp.keyWindow` is a window belonging to this app that is **not**
  the panel (Settings, Onboarding, an alert), **do nothing**. This keeps
  Settings usable from the gear without dismissing the panel regardless
  of which behaviour is selected.
- Otherwise, branch on `settings.panelClickOffBehavior`:
  - `.stayOnTop` — keep `panel.level = .floating`. No-op.
  - `.sendToBack` — set `panel.level = .normal`. The window stays
    visible but now sorts with regular windows. When the panel regains
    key (`didBecomeKeyNotification`), restore `level = .floating` only
    if the setting is still `.stayOnTop`; under `.sendToBack` leave it at
    `.normal` so it continues to behave like a normal window.
  - `.closePanel` — call `close()` (i.e. `orderOut` + cancel streaming).

On present (`FloatingPanelController.present(...)`), set
`panel.level` at the start of the call based on the current setting:
`.floating` for `.stayOnTop`, `.normal` for `.sendToBack` and
`.closePanel`. This way new invocations always start with the correct
z-order.

Also observe `SettingsStore` changes (Combine sink on `objectWillChange`
or `@AppStorage` re-read) so flipping the setting while the panel is
open applies immediately to `panel.level`.

**Interaction with Fix 2.** Because Fix 2 already guarantees the panel is
not closed by the gear (Settings opens as a sibling window without
dismissing it), and because the click-off handler above ignores resignKey
when the new key window belongs to our app, opening Settings from the
gear is safe under all three behaviours.

### Fix 4 (small) — make the header bar not look focusable

Not a bug by itself, but reinforces Fix 1: the header `HStack` currently
sets `.contentShape(Rectangle())` which invites clicks. We keep that for
drag-by-background but should make sure the header doesn't accidentally
eat Esc. Nothing extra to change here once `cancelOperation` is handled
at the panel level — Esc is no longer focus-dependent.

## Files

### New

- `InlineLLMLens/Settings/SettingsWindowController.swift`

### Modified

- `InlineLLMLens/Panel/FloatingPanel.swift` — add `onCancel` closure,
  override `cancelOperation(_:)`.
- `InlineLLMLens/Panel/FloatingPanelController.swift` — wire
  `panel.onCancel`, observe `didResignKeyNotification` /
  `didBecomeKeyNotification`, apply `panel.level` per setting on
  `present(...)`, react to settings changes.
- `InlineLLMLens/Panel/PanelViewModel.swift` — lift `followUpVisible` /
  `followUpInput` closing logic to a `closeFollowUp()` method and
  `isFollowUpOpen` bool (so the panel-level Esc handler can collapse
  follow-up first).
- `InlineLLMLens/Panel/PanelView.swift` — bind follow-up state to the
  view model instead of local `@State`; keep `.onExitCommand` as a
  fallback that calls the same view-model method.
- `InlineLLMLens/App/AppDelegate.swift` — `openSettings()` no longer
  closes the panel, no longer uses delay + `sendAction`; calls
  `SettingsWindowController.shared.show()` directly; close observer
  matches on identity.
- `InlineLLMLens/App/InlineLLMLensApp.swift` — drop `SettingsScene()`
  from the `App.body` (replace with `Settings { EmptyView() }` or
  equivalent no-op).
- `InlineLLMLens/Storage/SettingsStore.swift` — add
  `PanelClickOffBehavior` enum, key, default, typed accessor.
- `InlineLLMLens/Settings/GeneralSettingsView.swift` — new
  "Window behaviour" section with a picker bound to
  `panelClickOffBehavior`.

### Deleted

- `InlineLLMLens/Settings/SettingsScene.swift` — superseded by the
  AppKit-driven `SettingsWindowController`. Its `SettingsRoot` body is
  moved verbatim into the new file (or lifted to a shared `SettingsRoot`
  view that both could use; since we drop the scene entirely, just move
  it).

## Test plan

Manual (no XCTest coverage for window-level behaviour makes sense here):

1. Open panel with Opt+Space → press Esc immediately → panel closes.
   Repeat with follow-up bar open: first Esc collapses follow-up, second
   Esc closes panel. Repeat after clicking the header (not the text
   field): Esc still closes.
2. With panel open, click the gear → Settings window appears, panel
   stays visible. Close Settings → activation policy flips back to
   accessory (verify with `NSApp.activationPolicy()` in a debug log, or
   by checking Dock icon disappears).
3. With panel open, click the status-bar icon → Settings… → same as (2),
   panel not dismissed.
4. Set behaviour to "Recede to background": open panel, click on another
   app's window → panel goes behind. Bring app back to front (Cmd-Tab
   or click menu bar) → panel is reachable again.
5. Set behaviour to "Close": open panel, click another app → panel
   closes.
6. Set behaviour back to "Stay on top" (default): verify current
   behaviour unchanged.
7. Under each behaviour, open the gear from the panel → Settings opens
   and the panel is **not** closed/receded (same-app resignKey is
   ignored).
8. Flip the behaviour setting while the panel is open → next click-off
   honours the new value without needing to reopen the panel.

## Out of scope

- Changing the panel style mask, adding a title bar, or making it
  activating (`.nonactivatingPanel` stays — we still want it to not
  steal focus from the underlying app on show under normal flow).
- Reworking the Services / hotkey invocation paths.
- Any change to per-preset hotkey or auto-send behaviour.
