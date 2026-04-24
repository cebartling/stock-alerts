import Foundation
import Security

struct KeychainStore {
    let service: String
    let account: String

    init(service: String, account: String = "default") {
        self.service = service
        self.account = account
    }

    func read() -> String {
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

    func write(_ value: String) {
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

    func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecUseDataProtectionKeychain as String: true,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum Secrets {
    private static let finnhubStore = KeychainStore(
        service: "com.pintailconsultingllc.StockAlerts.finnhub"
    )

    static var finnhubKey: String {
        get { finnhubStore.read() }
        set { finnhubStore.write(newValue) }
    }
}
