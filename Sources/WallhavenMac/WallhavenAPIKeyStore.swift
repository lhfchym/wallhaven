import Foundation
import Security

protocol WallhavenAPIKeyStoring: Sendable {
    func loadAPIKey() -> String
    func saveAPIKey(_ apiKey: String)
}

struct WallhavenAPIKeyStore: WallhavenAPIKeyStoring {
    private let service: String
    private let account: String

    init(
        service: String = "dev.local.wallhavenmac",
        account: String = "wallhaven.apiKey"
    ) {
        self.service = service
        self.account = account
    }

    func loadAPIKey() -> String {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8)
        else {
            return ""
        }

        return apiKey
    }

    func saveAPIKey(_ apiKey: String) {
        let trimmedAPIKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedAPIKey.isEmpty {
            SecItemDelete(baseQuery() as CFDictionary)
            return
        }

        let data = Data(trimmedAPIKey.utf8)
        let updateAttributes = [
            kSecValueData as String: data
        ]

        let updateStatus = SecItemUpdate(
            baseQuery() as CFDictionary,
            updateAttributes as CFDictionary
        )

        guard updateStatus == errSecItemNotFound else {
            return
        }

        var addQuery = baseQuery()
        addQuery[kSecValueData as String] = data
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(addQuery as CFDictionary, nil)
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
