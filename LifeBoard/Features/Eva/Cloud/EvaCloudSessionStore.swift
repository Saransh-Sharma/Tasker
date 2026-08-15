import Foundation
import Security

actor EvaCloudSessionStore {
    static let shared = EvaCloudSessionStore()

    private let service = "app.getlifeboard.eva-cloud"
    private let account = "session-v1"

    func load() throws -> EvaSessionCredentials? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ] as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw EvaKeychainError.status(status)
        }
        return try JSONDecoder.evaCloud.decode(EvaSessionCredentials.self, from: data)
    }

    func save(_ credentials: EvaSessionCredentials) throws {
        let data = try JSONEncoder.evaCloud.encode(credentials)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if update == errSecItemNotFound {
            var add = query
            add[kSecValueData] = data
            add[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let status = SecItemAdd(add as CFDictionary, nil)
            guard status == errSecSuccess else { throw EvaKeychainError.status(status) }
        } else if update != errSecSuccess {
            throw EvaKeychainError.status(update)
        }
    }

    func clear() throws {
        let status = SecItemDelete([
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ] as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw EvaKeychainError.status(status)
        }
    }
}

private enum EvaKeychainError: Error {
    case status(OSStatus)
}

enum EvaInstallationIdentity {
    private static let key = "eva.cloud.installation-id.v1"

    static var current: UUID {
        if let value = UserDefaults.standard.string(forKey: key), let id = UUID(uuidString: value) {
            return id
        }
        let id = UUID()
        UserDefaults.standard.set(id.uuidString, forKey: key)
        return id
    }

    static var platform: String {
        #if targetEnvironment(macCatalyst)
        "catalyst"
        #else
        "ios"
        #endif
    }
}
