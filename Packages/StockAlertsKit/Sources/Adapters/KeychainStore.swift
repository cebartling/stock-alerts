import Foundation
import Security

/// Generic Keychain wrapper. Every SecItem call routes through
/// `kSecUseDataProtectionKeychain: true`, which requires the app to declare
/// `keychain-access-groups` and be signed with a real development certificate
/// (ad-hoc signing fails at codesign time).
public struct KeychainStore {
    public let service: String
    public let account: String

    public init(service: String, account: String = "default") {
        self.service = service
        self.account = account
    }

    public func read() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecUseDataProtectionKeychain as String: true,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return string
    }

    public func write(_ value: String) {
        // Empty string means "no key stored" — delete the entry.
        guard !value.isEmpty else {
            delete()
            return
        }
        let data = Data(value.utf8)
        let baseQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
        let updateAttrs: [String: Any] = [kSecValueData as String: data]

        let status = SecItemUpdate(baseQuery as CFDictionary, updateAttrs as CFDictionary)
        if status == errSecItemNotFound {
            var addQuery = baseQuery
            addQuery[kSecValueData as String] = data
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    public func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

/// Read/write wrapper for the production Finnhub API key.
public enum Secrets {
    private static let finnhubStore = KeychainStore(
        service: "com.pintailconsultingllc.StockAlerts.finnhub"
    )

    public static var finnhubKey: String {
        get { finnhubStore.read() }
        set { finnhubStore.write(newValue) }
    }
}
