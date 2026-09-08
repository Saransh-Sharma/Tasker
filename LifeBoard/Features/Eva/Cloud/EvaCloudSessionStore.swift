import Foundation
import Security

actor EvaCloudSessionStore {
    static let shared = EvaCloudSessionStore()

    private let service = "app.getlifeboard.eva-cloud"
    private let sessionAccount = "session-v1"
    private let guestBootstrapAccount = "guest-bootstrap-v1"
    private let usesInMemoryStorage: Bool
    private let securityStatusOverride: (@Sendable (EvaSecureStorageOperation) -> OSStatus?)?
    private var inMemoryCredentials: EvaSessionCredentials?
    private var inMemoryGuestBootstrap: GuestBootstrapRecord?

    private struct GuestBootstrapRecord: Codable {
        let id: UUID
        let installationID: UUID
    }

    init(
        inMemory: Bool = false,
        securityStatusOverride: (@Sendable (EvaSecureStorageOperation) -> OSStatus?)? = nil
    ) {
        usesInMemoryStorage = inMemory
        self.securityStatusOverride = securityStatusOverride
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
        let status = securityStatusOverride?(.load)
            ?? SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else {
            throw EvaSecureStorageError(operation: .load, status: status)
        }
        guard let data = result as? Data else {
            throw EvaSecureStorageError(operation: .load, status: errSecDecode)
        }
        return data
    }

    private func saveData(_ data: Data, account: String) throws {
        let query = baseQuery(account: account)
        let update = securityStatusOverride?(.update)
            ?? SecItemUpdate(query as CFDictionary, [kSecValueData: data] as CFDictionary)
        if update == errSecItemNotFound {
            var add = query
            add[kSecValueData] = data
            add[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            let status = securityStatusOverride?(.add)
                ?? SecItemAdd(add as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw EvaSecureStorageError(operation: .add, status: status)
            }
        } else if update != errSecSuccess {
            throw EvaSecureStorageError(operation: .update, status: update)
        }
    }

    private func deleteData(account: String) throws {
        let status = securityStatusOverride?(.delete)
            ?? SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw EvaSecureStorageError(operation: .delete, status: status)
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

enum EvaSecureStorageOperation: String, CaseIterable, Equatable, Sendable {
    case load
    case update
    case add
    case delete
}

struct EvaSecureStorageError: Error, LocalizedError, CustomNSError, Equatable, Sendable {
    static let errorDomain = "app.getlifeboard.eva-cloud.secure-storage"
    static let userFacingDescription = "Cloud EVA couldn’t access secure storage on this Mac. Quit and reopen LifeBoard, then try again."

    let operation: EvaSecureStorageOperation
    let status: OSStatus

    var errorDescription: String? { Self.userFacingDescription }
    var errorCode: Int { Int(status) }
    var telemetryCode: String { "keychain_\(operation.rawValue)_\(status)" }

    var systemMessage: String {
        guard let message = SecCopyErrorMessageString(status, nil) else {
            return "Unknown Security framework error"
        }
        return message as String
    }

    var diagnosticDescription: String {
        "Keychain \(operation.rawValue) failed with OSStatus \(status): \(systemMessage)"
    }

    var errorUserInfo: [String: Any] {
        [
            NSLocalizedDescriptionKey: Self.userFacingDescription,
            NSLocalizedFailureReasonErrorKey: systemMessage,
            "operation": operation.rawValue,
            "osStatus": Int(status),
        ]
    }
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
