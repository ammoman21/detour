import Carbon.HIToolbox
import Foundation

// Global hotkey via Carbon's RegisterEventHotKey. Unlike CGEventTap this does
// not require Accessibility permission, which keeps first-run friction at zero.
final class HotKeyManager {
    var onHotKey: (@MainActor () -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func register(_ preset: HotKeyPreset) {
        unregister()
        installHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: fourCharCode("DTOR"), id: 1)
        let status = RegisterEventHotKey(
            preset.keyCode,
            preset.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        if status != noErr {
            NSLog("Detour: failed to register hotkey (\(status))")
        }
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }

    private func installHandlerIfNeeded() {
        guard eventHandlerRef == nil else { return }
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData -> OSStatus in
                guard let userData else { return noErr }
                let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in manager.onHotKey?() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func fourCharCode(_ string: String) -> FourCharCode {
        var code: FourCharCode = 0
        for byte in string.utf8.prefix(4) {
            code = (code << 8) + FourCharCode(byte)
        }
        return code
    }

    deinit {
        unregister()
        if let ref = eventHandlerRef {
            RemoveEventHandler(ref)
        }
    }
}
