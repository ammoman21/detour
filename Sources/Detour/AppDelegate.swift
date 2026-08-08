import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panelController: PanelController!
    private var settingsController: SettingsWindowController!
    private let hotKeyManager = HotKeyManager()
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        panelController = PanelController(openSettings: { [weak self] in
            self?.openSettings()
        })

        settingsController = SettingsWindowController(
            onHotKeyChange: { [weak self] preset in
                self?.hotKeyManager.register(preset)
                self?.rebuildStatusMenu()
            },
            onMenuBarIconChange: { [weak self] hidden in
                self?.statusItem?.isVisible = !hidden
            },
            onAPIKeyChange: { [weak self] in
                self?.panelController.viewModel.refreshAPIKeyState()
            }
        )

        hotKeyManager.onHotKey = { [weak self] in
            self?.panelController.toggle()
        }
        hotKeyManager.register(Preferences.hotKey)

        setUpStatusItem()

        // First run: with no API key yet, surface the panel so the app isn't
        // completely invisible after launch.
        if Keychain.apiKey == nil {
            panelController.show()
        }
    }

    // Relaunching the app (double-click in Finder) is the escape hatch when the
    // menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = NSImage(
            systemSymbolName: "arrow.triangle.branch",
            accessibilityDescription: "Detour"
        )
        item.button?.image?.isTemplate = true
        statusItem = item
        rebuildStatusMenu()
        item.isVisible = !Preferences.hideMenuBarIcon
    }

    private func rebuildStatusMenu() {
        let menu = NSMenu()

        let toggleItem = NSMenuItem(
            title: "Toggle Detour  (\(Preferences.hotKey.displayName))",
            action: #selector(togglePanel),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        let clearItem = NSMenuItem(title: "New Chat", action: #selector(clearChat), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)

        menu.addItem(.separator())

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettingsAction), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Detour", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func togglePanel() {
        panelController.toggle()
    }

    @objc private func clearChat() {
        panelController.viewModel.clear()
    }

    @objc private func openSettingsAction() {
        openSettings()
    }

    private func openSettings() {
        panelController.hide()
        settingsController.show()
    }
}
