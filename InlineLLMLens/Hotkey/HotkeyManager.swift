import KeyboardShortcuts

final class HotkeyManager {
    private let onTrigger: () -> Void

    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
    }

    func start() {
        KeyboardShortcuts.onKeyDown(for: .invokePanel) { [weak self] in
            self?.onTrigger()
        }
    }

    func stop() {
        KeyboardShortcuts.disable(.invokePanel)
    }
}
