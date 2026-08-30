import Foundation
import Security

/// Minimal keychain wrapper for the one secret this app owns: the Home
/// Assistant refresh token.
///
/// The token is stored with `…ThisDeviceOnly`, which keeps it out of encrypted
/// device backups as well as out of iCloud. A refresh token is bound to one
/// Home Assistant installation on one Apple TV; letting it ride along into a
/// backup would extend its reach to whatever device that backup is restored to.
enum KeychainStore {
    enum KeychainError: LocalizedError {
        case unexpectedStatus(OSStatus)

        var errorDescription: String? {
            switch self {
            case .unexpectedStatus(let status):
                let message = SecCopyErrorMessageString(status, nil) as String?
                return message ?? "Keychain-Fehler \(status)"
            }
        }
    }

    private static let service = "io.github.jan620.roomglance.tokens"

    static func save(_ data: Data, account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return }

        guard updateStatus == errSecItemNotFound else {
            throw KeychainError.unexpectedStatus(updateStatus)
        }

        let addStatus = SecItemAdd(query.merging(attributes, uniquingKeysWith: { _, new in new }) as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainError.unexpectedStatus(addStatus)
        }
    }

    static func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    static func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

extension KeychainStore {
    static func saveJSON<T: Encodable>(_ value: T, account: String) throws {
        try save(try JSONEncoder().encode(value), account: account)
    }

    static func loadJSON<T: Decodable>(_ type: T.Type, account: String) -> T? {
        guard let data = load(account: account) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
