import AppKit
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @State private var apiKey: String = Keychain.apiKey ?? ""
    @State private var model: ModelChoice = Preferences.model
    @State private var hotKey: HotKeyPreset = Preferences.hotKey
    @State private var hideMenuBarIcon: Bool = Preferences.hideMenuBarIcon
    @State private var launchAtLogin: Bool = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?

    var onHotKeyChange: (HotKeyPreset) -> Void
    var onMenuBarIconChange: (Bool) -> Void
    var onAPIKeyChange: () -> Void

    var body: some View {
        Form {
            Section {
                SecureField("Anthropic API key", text: $apiKey)
                    .onChange(of: apiKey) { newValue in
                        Keychain.setAPIKey(newValue)
                        onAPIKeyChange()
                    }
                if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Stored in your keychain. Create one at console.anthropic.com → API Keys.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Saved to your keychain — saves as you type, no Enter needed. Close this window and press the hotkey.", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            Section {
                Picker("Model", selection: $model) {
                    ForEach(ModelChoice.allCases) { choice in
                        Text(choice.displayName).tag(choice)
                    }
                }
                .onChange(of: model) { Preferences.model = $0 }

                Picker("Hotkey", selection: $hotKey) {
                    ForEach(HotKeyPreset.allCases) { preset in
                        Text(preset.displayName).tag(preset)
                    }
                }
                .onChange(of: hotKey) { newValue in
                    Preferences.hotKey = newValue
                    onHotKeyChange(newValue)
                }
            }

            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                            loginItemError = nil
                        } catch {
                            loginItemError = "Couldn't update login item — run Detour from /Applications and try again."
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                if let loginItemError {
                    Text(loginItemError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Toggle("Hide menu bar icon", isOn: $hideMenuBarIcon)
                    .onChange(of: hideMenuBarIcon) { hidden in
                        Preferences.hideMenuBarIcon = hidden
                        onMenuBarIconChange(hidden)
                    }
                if hideMenuBarIcon {
                    Text("With the icon hidden, open Detour.app again (e.g. from Finder) to get back to Settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 420)
        .fixedSize(horizontal: false, vertical: true)
    }
}

final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    convenience init(
        onHotKeyChange: @escaping (HotKeyPreset) -> Void,
        onMenuBarIconChange: @escaping (Bool) -> Void,
        onAPIKeyChange: @escaping () -> Void
    ) {
        let hosting = NSHostingController(
            rootView: SettingsView(
                onHotKeyChange: onHotKeyChange,
                onMenuBarIconChange: onMenuBarIconChange,
                onAPIKeyChange: onAPIKeyChange
            )
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "Detour Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }
}
