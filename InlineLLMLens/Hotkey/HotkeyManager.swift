import Foundation
import KeyboardShortcuts

/// Owns the global hotkey bindings:
///
/// - The "ask" hotkey (`KeyboardShortcuts.Name.invokePanel`) opens the panel
///   with the user's default preset.
/// - Every preset additionally gets its own dynamically-registered hotkey
///   (`prompt.preset.<uuid>`); when set, pressing it presents the panel
///   pre-bound to that preset (respecting its `autoSend` flag).
final class HotkeyManager {
    private let onInvoke: () -> Void
    private let onInvokePreset: (PromptPreset) -> Void

    private var registeredPresetNames: Set<String> = []

    init(onInvoke: @escaping () -> Void, onInvokePreset: @escaping (PromptPreset) -> Void) {
        self.onInvoke = onInvoke
        self.onInvokePreset = onInvokePreset
    }

    func start() {
        KeyboardShortcuts.onKeyDown(for: .invokePanel) { [weak self] in
            self?.onInvoke()
        }
    }

    func stop() {
        KeyboardShortcuts.disable(.invokePanel)
        for raw in registeredPresetNames {
            let name = KeyboardShortcuts.Name(raw)
            KeyboardShortcuts.disable(name)
        }
        registeredPresetNames.removeAll()
    }

    /// Re-binds per-preset hotkeys after the catalog mutates. Bindings whose
    /// preset was deleted are disabled; new presets gain a callback. The
    /// underlying shortcut value is persisted by the KeyboardShortcuts library
    /// in UserDefaults under the preset's stable name, so it survives renames
    /// and relaunches.
    func syncPresetHotkeys(presets: [PromptPreset], invoke: @escaping (PromptPreset) -> Void) {
        let aliveNames = Set(presets.map { $0.hotkeyShortcutKey })
        // Disable removed.
        for raw in registeredPresetNames.subtracting(aliveNames) {
            let name = KeyboardShortcuts.Name(raw)
            KeyboardShortcuts.disable(name)
        }
        // Enable / refresh.
        for preset in presets {
            let name = KeyboardShortcuts.Name(preset.hotkeyShortcutKey)
            KeyboardShortcuts.onKeyDown(for: name) { [preset] in
                invoke(preset)
            }
        }
        registeredPresetNames = aliveNames
    }
}
