import Foundation
import Security

/// Synchronous storage seam for exercising migration and failed writes without
/// requiring a test bundle to inherit the application's Keychain entitlements.
protocol EvaSecureRecordStorage: Sendable {
    func load(account: String) throws -> Data?
    func save(_ data: Data, account: String) throws
    func delete(account: String) throws
}

actor EvaCloudSessionStore {
    static let shared = EvaCloudSessionStore()

    private let service = EvaCloudKeychainNamespace.service
    private let sessionAccount = EvaCloudKeychainNamespace.sessionAccount
    private let legacySessionAccount = EvaCloudKeychainNamespace.legacySessionAccount
    private let guestBootstrapAccount = EvaCloudKeychainNamespace.guestBootstrapAccount
    private let legacyGuestBootstrapAccount = EvaCloudKeychainNamespace.legacyGuestBootstrapAccount
    private let usesInMemoryStorage: Bool
    private let securityStatusOverride: (@Sendable (EvaSecureStorageOperation) -> OSStatus?)?
    private let recordStorage: (any EvaSecureRecordStorage)?
    private let installationIDProvider: @Sendable () throws -> UUID
    private var inMemoryCredentials: EvaSessionCredentials?
    private var inMemoryGuestBootstrap: GuestBootstrapRecord?
    private var serverRevokedCredentials: EvaSessionCredentials?

    private struct SessionEnvelopeV2: Codable {
        static let schemaVersion = 2

        let schemaVersion: Int
        let credentials: EvaSessionCredentials

        init(credentials: EvaSessionCredentials) {
            self.schemaVersion = Self.schemaVersion
            self.credentials = credentials
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
            credentials = try container.decode(EvaSessionCredentials.self, forKey: .credentials)
            guard schemaVersion <= Self.schemaVersion else {
                throw EvaSessionPersistenceError.unsupportedSchema(schemaVersion)
            }
        }
    }

    private struct GuestBootstrapRecord: Codable {
        static let schemaVersion = 2

        let schemaVersion: Int
        let id: UUID
        let installationID: UUID

        init(id: UUID, installationID: UUID) {
            self.schemaVersion = Self.schemaVersion
            self.id = id
            self.installationID = installationID
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
            id = try container.decode(UUID.self, forKey: .id)
            installationID = try container.decode(UUID.self, forKey: .installationID)
            guard schemaVersion <= Self.schemaVersion else {
                throw EvaSessionPersistenceError.unsupportedSchema(schemaVersion)
            }
        }
    }

    init(
        inMemory: Bool = false,
        recordStorage: (any EvaSecureRecordStorage)? = nil,
        installationIDProvider: @escaping @Sendable () throws -> UUID = { try EvaInstallationIdentity.resolved() },
        securityStatusOverride: (@Sendable (EvaSecureStorageOperation) -> OSStatus?)? = nil
    ) {
        usesInMemoryStorage = inMemory
        self.recordStorage = recordStorage
        self.installationIDProvider = installationIDProvider
        self.securityStatusOverride = securityStatusOverride
    }

    /// Test and preview transports deliberately use an in-memory session. They
    /// must not be coupled to the app target's real keychain entitlement while
    /// production paths still fail closed when secure storage is unavailable.
    func isInMemoryStorage() -> Bool { usesInMemoryStorage }

    func load() throws -> EvaSessionCredentials? {
        if usesInMemoryStorage { return inMemoryCredentials }
        if let data = try loadData(account: sessionAccount) {
            return try decodeCurrentSession(data, account: sessionAccount)
        }

        // Older releases wrote credentials directly under session-v1. Keep the
        // old item readable during upgrade, then migrate it after the new write
        // succeeds so a failed migration never destroys the old session.
        guard let legacyData = try loadData(account: legacySessionAccount) else { return nil }
        let credentials: EvaSessionCredentials
        if let envelope = try? JSONDecoder.evaCloud.decode(SessionEnvelopeV2.self, from: legacyData) {
            credentials = envelope.credentials
        } else if let old = try? JSONDecoder.evaCloud.decode(EvaSessionCredentials.self, from: legacyData) {
            credentials = old
        } else {
            throw EvaSessionPersistenceError.corrupt(legacySessionAccount)
        }
        try saveData(JSONEncoder.evaCloud.encode(SessionEnvelopeV2(credentials: credentials)), account: sessionAccount)
        try? deleteData(account: legacySessionAccount)
        Task { await ProductTelemetry.shared.record(.evaSessionMigrated, outcome: "session_v1") }
        return credentials
    }

    func save(_ credentials: EvaSessionCredentials) throws {
        if usesInMemoryStorage {
            inMemoryCredentials = credentials
            serverRevokedCredentials = nil
            return
        }
        let data = try JSONEncoder.evaCloud.encode(SessionEnvelopeV2(credentials: credentials))
        try saveData(data, account: sessionAccount)
        serverRevokedCredentials = nil
    }

    func clear() throws {
        // `markServerRevoked` is applied after the clear operation so explicit
        // logout/deletion cannot leave a stale process-local restore result.
        serverRevokedCredentials = nil
        if usesInMemoryStorage {
            inMemoryCredentials = nil
            return
        }
        try deleteData(account: sessionAccount)
        try? deleteData(account: legacySessionAccount)
    }

    /// Keeps the reason for a just-observed server revocation available to the
    /// next restore pass. It is intentionally process-local: an app restart
    /// with no credentials is simply a missing session, while the current
    /// process can still distinguish guest recovery from Apple reauthentication.
    func markServerRevoked(_ credentials: EvaSessionCredentials) {
        serverRevokedCredentials = credentials
    }

    func guestBootstrapID(for installationID: UUID) throws -> UUID {
        if usesInMemoryStorage {
            if let record = inMemoryGuestBootstrap, record.installationID == installationID { return record.id }
            let record = GuestBootstrapRecord(id: UUID(), installationID: installationID)
            inMemoryGuestBootstrap = record
            return record.id
        }

        if let data = try loadData(account: guestBootstrapAccount) {
            let record = try decodeGuestBootstrap(data, account: guestBootstrapAccount)
            if record.installationID == installationID {
                if record.schemaVersion != GuestBootstrapRecord.schemaVersion {
                    try saveData(
                        JSONEncoder.evaCloud.encode(
                            GuestBootstrapRecord(id: record.id, installationID: record.installationID)
                        ),
                        account: guestBootstrapAccount
                    )
                    Task { await ProductTelemetry.shared.record(.evaSessionMigrated, outcome: "guest_bootstrap_schema") }
                }
                return record.id
            }
            throw EvaSessionPersistenceError.corrupt(guestBootstrapAccount)
        } else if let legacyData = try loadData(account: legacyGuestBootstrapAccount) {
            let record = try decodeGuestBootstrap(legacyData, account: legacyGuestBootstrapAccount)
            if record.installationID == installationID {
                try saveData(
                    JSONEncoder.evaCloud.encode(
                        GuestBootstrapRecord(id: record.id, installationID: record.installationID)
                    ),
                    account: guestBootstrapAccount
                )
                try? deleteData(account: legacyGuestBootstrapAccount)
                Task { await ProductTelemetry.shared.record(.evaSessionMigrated, outcome: "guest_bootstrap_v1") }
                return record.id
            }
            throw EvaSessionPersistenceError.corrupt(legacyGuestBootstrapAccount)
        }

        // Pre-Keychain builds briefly stored this value in UserDefaults. Read it
        // once, delete it only after the secure write succeeds, and never erase
        // it before a migration attempt.
        if let legacyValue = UserDefaults.standard.string(forKey: EvaCloudKeychainNamespace.legacyGuestBootstrapDefaultsKey),
           let legacyID = UUID(uuidString: legacyValue) {
            let record = GuestBootstrapRecord(id: legacyID, installationID: installationID)
            try saveData(JSONEncoder.evaCloud.encode(record), account: guestBootstrapAccount)
            UserDefaults.standard.removeObject(forKey: EvaCloudKeychainNamespace.legacyGuestBootstrapDefaultsKey)
            Task { await ProductTelemetry.shared.record(.evaSessionMigrated, outcome: "guest_bootstrap_defaults") }
            return legacyID
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
        try? deleteData(account: legacyGuestBootstrapAccount)
        UserDefaults.standard.removeObject(forKey: EvaCloudKeychainNamespace.legacyGuestBootstrapDefaultsKey)
    }

    func restoreOutcome() -> EvaCloudSessionRestoreOutcome {
        if let credentials = serverRevokedCredentials {
            serverRevokedCredentials = nil
            recordRestore(outcome: "server_revoked")
            return .serverRevoked(credentials)
        }
        // Resolve the installation marker before loading credentials. This is
        // what turns an uninstall followed by a stale ThisDeviceOnly item into
        // a clean installation boundary rather than a second guest account.
        let installationID: UUID?
        if !usesInMemoryStorage {
            do {
                installationID = try installationIDProvider()
            } catch let error as EvaSecureStorageError {
                recordRestore(outcome: "temporarily_unavailable")
                return .temporarilyUnavailable(error)
            } catch let error as EvaSessionPersistenceError {
                recordRestore(outcome: "corrupt")
                return .corrupt(error)
            } catch {
                recordRestore(outcome: "temporarily_unavailable")
                return .temporarilyUnavailable(
                    EvaSecureStorageError(operation: .load, status: errSecInteractionNotAllowed)
                )
            }
        } else {
            installationID = nil
        }
        do {
            guard let credentials = try load() else {
                recordRestore(outcome: "missing")
                return .missing
            }
            if let installationID,
               credentials.installationId != installationID {
                recordRestore(outcome: "identity_mismatch")
                return .identityMismatch(credentials)
            }
            recordRestore(outcome: "restored")
            return .restored(credentials)
        } catch let error as EvaSecureStorageError {
            recordRestore(outcome: "temporarily_unavailable")
            return .temporarilyUnavailable(error)
        } catch let error as EvaSessionPersistenceError {
            recordRestore(outcome: "corrupt")
            return .corrupt(error)
        } catch {
            recordRestore(outcome: "corrupt")
            return .corrupt(.corrupt(sessionAccount))
        }
    }

    private func recordRestore(outcome: String) {
        Task { await ProductTelemetry.shared.record(.evaSessionRestored, outcome: outcome) }
    }

    private func decodeCurrentSession(_ data: Data, account: String) throws -> EvaSessionCredentials {
        guard let envelope = try? JSONDecoder.evaCloud.decode(SessionEnvelopeV2.self, from: data) else {
            throw EvaSessionPersistenceError.corrupt(account)
        }
        if envelope.schemaVersion != SessionEnvelopeV2.schemaVersion {
            try saveData(
                JSONEncoder.evaCloud.encode(SessionEnvelopeV2(credentials: envelope.credentials)),
                account: account
            )
            Task { await ProductTelemetry.shared.record(.evaSessionMigrated, outcome: "session_schema") }
        }
        return envelope.credentials
    }

    private func decodeGuestBootstrap(_ data: Data, account: String) throws -> GuestBootstrapRecord {
        guard let record = try? JSONDecoder.evaCloud.decode(GuestBootstrapRecord.self, from: data) else {
            throw EvaSessionPersistenceError.corrupt(account)
        }
        return record
    }

    private func loadData(account: String) throws -> Data? {
        if let recordStorage { return try recordStorage.load(account: account) }
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
        if let recordStorage { return try recordStorage.save(data, account: account) }
        let query = baseQuery(account: account)
        let update = securityStatusOverride?(.update)
            ?? SecItemUpdate(query as CFDictionary, [
                kSecValueData: data,
                // Existing items from session-v1/guest-bootstrap-v1 were
                // written with the old accessibility class. Updating the
                // attribute during the first successful write makes the
                // migration durable without changing the service or access
                // group.
                kSecAttrAccessible: EvaCloudKeychainNamespace.accessibility,
            ] as CFDictionary)
        if update == errSecItemNotFound {
            var add = query
            add[kSecValueData] = data
            add[kSecAttrAccessible] = EvaCloudKeychainNamespace.accessibility
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
        if let recordStorage { return try recordStorage.delete(account: account) }
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

enum EvaCloudKeychainNamespace {
    static let service = "app.getlifeboard.eva-cloud"
    static let sessionAccount = "session-v2"
    static let legacySessionAccount = "session-v1"
    static let guestBootstrapAccount = "guest-bootstrap-v2"
    static let legacyGuestBootstrapAccount = "guest-bootstrap-v1"
    static let installationAccount = "installation-v1"
    static let legacyGuestBootstrapDefaultsKey = "eva.cloud.guest-bootstrap-id.v1"
    // Store the constant as a Swift `String` so this namespace remains safe to
    // reference from concurrency-checked code. Security APIs bridge it back to
    // the required CFType when the keychain query is built.
    static let accessibility: String = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String
}

enum EvaSessionPersistenceError: Error, LocalizedError, CustomNSError, Equatable, Sendable {
    static let errorDomain = "app.getlifeboard.eva-cloud.persistence"

    case corrupt(String)
    case unsupportedSchema(Int)

    var errorDescription: String? {
        switch self {
        case .corrupt: String(localized: "Cloud EVA’s saved session could not be read. Try again.")
        case .unsupportedSchema: String(localized: "This Cloud EVA session needs a newer app version.")
        }
    }

    var errorCode: Int {
        switch self {
        case .corrupt: 1
        case .unsupportedSchema: 2
        }
    }
}

enum EvaCloudSessionRestoreOutcome: Equatable, Sendable {
    case missing
    case restored(EvaSessionCredentials)
    case identityMismatch(EvaSessionCredentials)
    case temporarilyUnavailable(EvaSecureStorageError)
    case corrupt(EvaSessionPersistenceError)
    case serverRevoked(EvaSessionCredentials)
}

struct EvaCloudRecoveryRecord: Codable, Equatable, Sendable {
    static let schemaVersion = 1

    let schemaVersion: Int
    let identityKind: EvaIdentityKind
    let accountID: String
    let appleUserIdentifier: String?

    init(credentials: EvaSessionCredentials) {
        self.schemaVersion = Self.schemaVersion
        self.identityKind = credentials.resolvedIdentityKind
        self.accountID = credentials.accountId
        self.appleUserIdentifier = credentials.appleUserIdentifier
    }
}

enum EvaCloudRecoveryStore {
    static let key = "eva.cloud.recovery-record.v1"

    static func load(defaults: UserDefaults = .standard) -> EvaCloudRecoveryRecord? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder.evaCloud.decode(EvaCloudRecoveryRecord.self, from: data)
    }

    static func saveApple(credentials: EvaSessionCredentials, defaults: UserDefaults = .standard) {
        guard credentials.resolvedIdentityKind == .apple,
              let data = try? JSONEncoder.evaCloud.encode(EvaCloudRecoveryRecord(credentials: credentials)) else { return }
        defaults.set(data, forKey: key)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
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
    static let userFacingDescription = "Cloud EVA couldn’t access secure storage. Unlock this device and try again. Your saved session is retained."

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
    private static let processFallbackID = UUID()
    private static let lock = NSLock()

    /// Compatibility accessor for tests and non-network presentation code.
    /// Network paths use `resolved()` so a Keychain failure is not hidden.
    static var current: UUID {
        (try? resolved())
            ?? UUID(uuidString: UserDefaults.standard.string(forKey: key) ?? "")
            ?? processFallbackID
    }

    /// UserDefaults is the reinstall marker and migration mirror. A value that
    /// already exists there wins during an app upgrade; if it is absent, create
    /// a new identity even when a stale ThisDeviceOnly Keychain item survives an
    /// uninstall.
    static func resolved() throws -> UUID {
        try lock.withLock { try resolveLocked() }
    }

    private static func resolveLocked() throws -> UUID {
        let marker = UserDefaults.standard.string(forKey: key)
        let defaultsID = marker.flatMap(UUID.init(uuidString:))
        guard marker == nil || defaultsID != nil else {
            throw EvaSessionPersistenceError.corrupt(key)
        }
        if let defaultsID {
            let keychainID = try loadKeychainIdentity()
            if keychainID == nil || keychainID != defaultsID {
                try saveKeychainIdentity(defaultsID)
            }
            return defaultsID
        }

        // A missing defaults marker is the one signal that this is a genuinely
        // new installation. ThisDeviceOnly Keychain items can outlive an app
        // uninstall on some OS versions, so remove every old Eva item before
        // minting the new identity. If Keychain is locked, fail and preserve
        // the old credentials instead of creating a second guest account.
        try clearKeychainForInstallationBoundary()
        let newID = UUID()
        try saveKeychainIdentity(newID)
        UserDefaults.standard.set(newID.uuidString, forKey: key)
        return newID
    }

    /// Explicit account deletion has the same local cleanup semantics as a
    /// confirmed reinstall boundary, but it also removes the defaults mirror.
    static func reset() throws {
        try lock.withLock { try resetLocked() }
    }

    private static func resetLocked() throws {
        try clearKeychainForInstallationBoundary()
        UserDefaults.standard.removeObject(forKey: key)
        UserDefaults.standard.removeObject(forKey: EvaCloudKeychainNamespace.legacyGuestBootstrapDefaultsKey)
        EvaCloudRecoveryStore.clear()
    }

    private static func clearKeychainForInstallationBoundary() throws {
        let accounts = [
            EvaCloudKeychainNamespace.sessionAccount,
            EvaCloudKeychainNamespace.legacySessionAccount,
            EvaCloudKeychainNamespace.guestBootstrapAccount,
            EvaCloudKeychainNamespace.legacyGuestBootstrapAccount,
            EvaCloudKeychainNamespace.installationAccount,
        ]
        // Deletion may be permitted while protected data is unreadable. Probe
        // every old record first, so a locked device never causes partial loss.
        for account in accounts {
            var query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: EvaCloudKeychainNamespace.service,
                kSecAttrAccount: account,
                kSecReturnData: true,
                kSecMatchLimit: kSecMatchLimitOne,
            ]
            #if targetEnvironment(macCatalyst)
            query[kSecUseDataProtectionKeychain] = true
            #endif
            var result: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &result)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw EvaSecureStorageError(operation: .load, status: status)
            }
        }
        for account in accounts {
            var query: [CFString: Any] = [
                kSecClass: kSecClassGenericPassword,
                kSecAttrService: EvaCloudKeychainNamespace.service,
                kSecAttrAccount: account,
            ]
            #if targetEnvironment(macCatalyst)
            query[kSecUseDataProtectionKeychain] = true
            #endif
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw EvaSecureStorageError(operation: .delete, status: status)
            }
        }
        UserDefaults.standard.removeObject(forKey: EvaCloudKeychainNamespace.legacyGuestBootstrapDefaultsKey)
    }

    private static func loadKeychainIdentity() throws -> UUID? {
        var result: CFTypeRef?
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: EvaCloudKeychainNamespace.service,
            kSecAttrAccount: EvaCloudKeychainNamespace.installationAccount,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        #if targetEnvironment(macCatalyst)
        query[kSecUseDataProtectionKeychain] = true
        #endif
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data else {
            throw EvaSecureStorageError(operation: .load, status: status)
        }
        guard let id = try? JSONDecoder.evaCloud.decode(UUID.self, from: data) else {
            throw EvaSessionPersistenceError.corrupt(EvaCloudKeychainNamespace.installationAccount)
        }
        return id
    }

    private static func saveKeychainIdentity(_ id: UUID) throws {
        let data = try JSONEncoder.evaCloud.encode(id)
        var query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: EvaCloudKeychainNamespace.service,
            kSecAttrAccount: EvaCloudKeychainNamespace.installationAccount,
        ]
        #if targetEnvironment(macCatalyst)
        query[kSecUseDataProtectionKeychain] = true
        #endif
        let update = SecItemUpdate(query as CFDictionary, [
            kSecValueData: data,
            kSecAttrAccessible: EvaCloudKeychainNamespace.accessibility,
        ] as CFDictionary)
        if update == errSecItemNotFound {
            query[kSecValueData] = data
            query[kSecAttrAccessible] = EvaCloudKeychainNamespace.accessibility
            let status = SecItemAdd(query as CFDictionary, nil)
            guard status == errSecSuccess else {
                throw EvaSecureStorageError(operation: .add, status: status)
            }
        } else if update != errSecSuccess {
            throw EvaSecureStorageError(operation: .update, status: update)
        }
    }

    static var platform: String {
        #if targetEnvironment(macCatalyst)
        "catalyst"
        #else
        "ios"
        #endif
    }
}
