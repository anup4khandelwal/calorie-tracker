import Foundation
import Security

/// Keychain-backed storage for API keys. Keys never touch UserDefaults or disk.
enum KeyVault {
    enum Key: String, CaseIterable {
        case anthropic = "anthropic-api-key"
        case gemini = "gemini-api-key"
    }

    private static let service = "com.mise.app.keys"

    static func set(_ value: String, for key: Key) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        delete(key)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    static func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let string = String(data: data, encoding: .utf8),
              !string.isEmpty
        else { return nil }
        return string
    }

    static func delete(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key.rawValue,
        ]
        SecItemDelete(query as CFDictionary)
    }

    static var hasAnthropicKey: Bool { Self.get(.anthropic) != nil }
    static var hasGeminiKey: Bool { Self.get(.gemini) != nil }
}
