import AppKit

final class MenuBarController: NSObject {
    private let statusItem: NSStatusItem
    private let onAsk: () -> Void
    private let onSettings: () -> Void
    private let onPermissions: () -> Void
    private let onQuit: () -> Void

    init(
        onAsk: @escaping () -> Void,
        onSettings: @escaping () -> Void,
        onPermissions: @escaping () -> Void,
        onQuit: @escaping () -> Void
    ) {
        self.onAsk = onAsk
        self.onSettings = onSettings
        self.onPermissions = onPermissions
        self.onQuit = onQuit
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "Inline LLM Lens")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Inline LLM Lens"
        }

        statusItem.menu = buildMenu()
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(item("Ask Inline LLM", action: #selector(handleAsk), key: ""))
        menu.addItem(.separator())
        menu.addItem(item("Settings…", action: #selector(handleSettings), key: ","))
        menu.addItem(item("Check Permissions", action: #selector(handlePermissions), key: ""))
        menu.addItem(.separator())
        menu.addItem(item("Quit", action: #selector(handleQuit), key: "q"))
        for i in menu.items { i.target = self }
        return menu
    }

    private func item(_ title: String, action: Selector, key: String) -> NSMenuItem {
        NSMenuItem(title: title, action: action, keyEquivalent: key)
    }

    @objc private func handleAsk() { onAsk() }
    @objc private func handleSettings() { onSettings() }
    @objc private func handlePermissions() { onPermissions() }
    @objc private func handleQuit() { onQuit() }
}
