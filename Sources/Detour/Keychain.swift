import Foundation
import Security

// Stores the Anthropic API key in the login keychain so it never touches
// UserDefaults or any plaintext file.
//
// Keychain items are ACL-bound to the code signature of the app that created
// them. This app is ad-hoc signed, and ad-hoc signatures change on every
// rebuild — so a freshly built binary reading an item created by an older
// build triggers a "Detour wants to use your keychain" prompt. Two defenses:
//   1. Read the keychain once per launch and cache in memory (one prompt max).
//   2. After a successful read, rewrite the item so the current binary becomes
//      its owner — later launches of this build read it silently.
enum Keychain {
    private static let service = "com.detour.Detour"
    private static let account = "anthropic-api-key"

    // Double-optional: nil = not yet loaded, .some(nil) = loaded, no key.
    private static var cache: String??

    static var apiKey: String? {
        if let cache { return cache }
        let value = read()
        if let value {
            // Take ownership so the next launch doesn't prompt again.
            write(value)
        }
        cache = .some(value)
        return value
    }

    @discardableResult
    static func setAPIKey(_ key: String) -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        cache = .some(trimmed.isEmpty ? nil : trimmed)
        if trimmed.isEmpty {
            delete()
            return true
        }
        return write(trimmed)
    }

    static func deleteAPIKey() {
        cache = .some(nil)
        delete()
    }

    // MARK: - Raw keychain operations

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8), !key.isEmpty
        else { return nil }
        return key
    }

    @discardableResult
    private static func write(_ value: String) -> Bool {
        delete()
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
        ]
        return SecItemAdd(attributes as CFDictionary, nil) == errSecSuccess
    }

    private static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
