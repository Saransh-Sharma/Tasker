import Foundation
import Security

actor EvaCloudSessionStore {
    static let shared = EvaCloudSessionStore()

    private let service = "app.getlifeboard.eva-cloud"
    private let sessionAccount = "session-v1"
    private let guestBootstrapAccount = "guest-bootstrap-v1"
    private let usesInMemoryStorage: Bool
    private var inMemoryCredentials: EvaSessionCredentials?
    private var inMemoryGuestBootstrap: GuestBootstrapRecord?

    private struct GuestBootstrapRecord: Codable {
        let id: UUID
        let installationID: UUID
    }

    init(inMemory: Bool = false) {
        usesInMemoryStorage = inMemory
    }

    func load() throws -> EvaSessionCredentials? {
        if usesInMemoryStorage { return inMemoryCredentials }
        guard let data = try loadData(account: sessionAccount) else { return nil }
        return try JSONDecoder.evaCloud.decode(EvaSessionCredentials.self, from: data)
    }

    func save(_ credentials: EvaSessionCredentials) throws {
        if usesInMemoryStorage {
            inMemoryCredentials = credentials
            return
        }
        let data = try JSONEncoder.evaCloud.encode(credentials)
        try saveData(data, account: sessionAccount)
    }

    func clear() throws {
        if usesInMemoryStorage {
            inMemoryCredentials = nil
            return
        }
        try deleteData(account: sessionAccount)
    }

    func guestBootstrapID(for installationID: UUID) throws -> UUID {
        UserDefaults.standard.removeObject(forKey: "eva.cloud.guest-bootstrap-id.v1")
        if usesInMemoryStorage {
            if let record = inMemoryGuestBootstrap, record.installationID == installationID { return record.id }
            let record = GuestBootstrapRecord(id: UUID(), installationID: installationID)
            inMemoryGuestBootstrap = record
            return record.id
        }
        if let data = try loadData(account: guestBootstrapAccount),
           let record = try? JSONDecoder.evaCloud.decode(GuestBootstrapRecord.self, from: data),
           record.installationID == installationID {
            return record.id
        }
        let record = GuestBootstrapRecord(id: UUID(), installationID: installationID)
        try saveData(JSONEncoder.evaCloud.encode(record), account: guestBootstrapAccount)
        return record.id
    }

    func clearGuestBootstrapID() throws {
        if usesInMemoryStorage {
            inMemoryGuestBootstrap = nil
            return
        }
        try deleteData(account: guestBootstrapAccount)
    }

    private func loadData(account: String) throws -> Data? {
        var result: CFTypeRef?
        var query = baseQuery(account: account)
        query[kSecReturnData] = true
        query[kSecMatchLimit] = kSecMatchLimitOne
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw EvaKeychainError.status(status)
        }
        return data
    }

    private func saveData(_ data: Data, account: String) throws {
        let query = baseQuery(account: account)
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

    private func deleteData(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw EvaKeychainError.status(status)
        }
    }

    private func baseQuery(account: String) -> [CFString: Any] {
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: account,
        ]
        #if targetEnvironment(macCatalyst)
        query[kSecUseDataProtectionKeychain] = true
        #endif
        return query
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
