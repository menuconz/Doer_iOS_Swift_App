import Foundation
import Security

class SecureStorageManager {
    static let shared = SecureStorageManager()

    private let serviceName = "nz.co.doer"
    private let keyIsLoggedIn = "is_logged_in"

    private init() {}

    var isLoggedIn: Bool {
        get {
            return getString(keyIsLoggedIn) == "true"
        }
        set {
            setString(keyIsLoggedIn, value: newValue ? "true" : "false")
        }
    }

    func clear() {
        deleteItem(keyIsLoggedIn)
    }

    // MARK: - Keychain Helpers

    private func setString(_ key: String, value: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]

        SecItemDelete(query as CFDictionary)

        var newQuery = query
        newQuery[kSecValueData as String] = data
        SecItemAdd(newQuery as CFDictionary, nil)
    }

    private func getString(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    private func deleteItem(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: serviceName,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
