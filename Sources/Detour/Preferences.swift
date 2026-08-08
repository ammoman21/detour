import Foundation
import Carbon.HIToolbox

enum ModelChoice: String, CaseIterable, Identifiable {
    case haiku = "claude-haiku-4-5"
    case sonnet = "claude-sonnet-5"
    case opus = "claude-opus-5"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .haiku: return "Haiku 4.5 — fastest, cheapest"
        case .sonnet: return "Sonnet 5 — balanced"
        case .opus: return "Opus 5 — most capable"
        }
    }

    var shortName: String {
        switch self {
        case .haiku: return "Haiku"
        case .sonnet: return "Sonnet"
        case .opus: return "Opus"
        }
    }
}

enum HotKeyPreset: String, CaseIterable, Identifiable {
    case optionSpace
    case controlOptionSpace
    case commandShiftSpace
    case controlShiftSpace

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .optionSpace: return "⌥ Space"
        case .controlOptionSpace: return "⌃⌥ Space"
        case .commandShiftSpace: return "⌘⇧ Space"
        case .controlShiftSpace: return "⌃⇧ Space"
        }
    }

    var keyCode: UInt32 { UInt32(kVK_Space) }

    var carbonModifiers: UInt32 {
        switch self {
        case .optionSpace: return UInt32(optionKey)
        case .controlOptionSpace: return UInt32(controlKey | optionKey)
        case .commandShiftSpace: return UInt32(cmdKey | shiftKey)
        case .controlShiftSpace: return UInt32(controlKey | shiftKey)
        }
    }
}

enum Preferences {
    private static let defaults = UserDefaults.standard

    private enum Key {
        static let model = "model"
        static let hotKey = "hotKeyPreset"
        static let hideMenuBarIcon = "hideMenuBarIcon"
    }

    static var model: ModelChoice {
        get { defaults.string(forKey: Key.model).flatMap(ModelChoice.init(rawValue:)) ?? .haiku }
        set { defaults.set(newValue.rawValue, forKey: Key.model) }
    }

    static var hotKey: HotKeyPreset {
        get { defaults.string(forKey: Key.hotKey).flatMap(HotKeyPreset.init(rawValue:)) ?? .optionSpace }
        set { defaults.set(newValue.rawValue, forKey: Key.hotKey) }
    }

    static var hideMenuBarIcon: Bool {
        get { defaults.bool(forKey: Key.hideMenuBarIcon) }
        set { defaults.set(newValue, forKey: Key.hideMenuBarIcon) }
    }
}
