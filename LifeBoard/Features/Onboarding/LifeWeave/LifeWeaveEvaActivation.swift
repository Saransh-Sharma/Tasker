import Foundation
import Network
import SwiftUI

enum EvaCloudAccessState: Equatable, Sendable {
    case hydrating
    case ready
    case needsActivation
    case activating
    case temporarilyUnavailable(String)
    case quotaExhausted(Date?)
    case appleReauthenticationRequired
}

enum EvaCloudAccessSource: String, Sendable {
    case appLaunch
    case evaEntry
    case chatSend
    case chatInlineAction
    case onboarding
    case setupCenter
}

struct EvaCloudActivationReceiptV1: Codable, Equatable, Sendable {
    static let schemaVersion = 1
    static let currentDisclosureRevision = 1

    let schemaVersion: Int
    let disclosureRevision: Int
    let grants: [EvaConsentPolicy.Grant]
    let confirmedAt: Date

    init(
        grants: [EvaConsentPolicy.Grant],
        confirmedAt: Date = .now,
        disclosureRevision: Int = Self.currentDisclosureRevision
    ) {
        self.schemaVersion = Self.schemaVersion
        self.disclosureRevision = disclosureRevision
        self.grants = grants.sorted { $0.rawValue < $1.rawValue }
        self.confirmedAt = confirmedAt
    }

    var isCurrent: Bool {
        schemaVersion == Self.schemaVersion
            && disclosureRevision == Self.currentDisclosureRevision
    }
}

enum EvaCloudActivationReceiptStore {
    static let key = "eva.cloud.activation-receipt.v1"

    static func load(defaults: UserDefaults = .standard) -> EvaCloudActivationReceiptV1? {
        guard let data = defaults.data(forKey: key),
              let receipt = try? JSONDecoder.evaCloud.decode(EvaCloudActivationReceiptV1.self, from: data),
              receipt.isCurrent else { return nil }
        return receipt
    }

    @discardableResult
    static func save(
        grants: Set<EvaConsentPolicy.Grant>,
        defaults: UserDefaults = .standard,
        now: Date = .now
    ) -> EvaCloudActivationReceiptV1 {
        let receipt = EvaCloudActivationReceiptV1(grants: Array(grants), confirmedAt: now)
        if let data = try? JSONEncoder.evaCloud.encode(receipt) {
            defaults.set(data, forKey: key)
        }
        return receipt
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
    }
}

/// Local defaults are not a claim that the user confirmed a disclosure.
struct EvaCloudActivationRecord: Codable, Equatable {
    enum Origin: String, Codable { case automaticDefaults, userSelection }
    var version = 3
    let grants: [EvaConsentPolicy.Grant]
    let origin: Origin
    let updatedAt: Date
    let lastServerConsentRevision: Int?
    let explicitOffline: Bool

    init(
        grants: [EvaConsentPolicy.Grant],
        origin: Origin,
        updatedAt: Date = .now,
        lastServerConsentRevision: Int? = nil,
        explicitOffline: Bool = false
    ) {
        self.version = 3
        self.grants = grants
        self.origin = origin
        self.updatedAt = updatedAt
        self.lastServerConsentRevision = lastServerConsentRevision
        self.explicitOffline = explicitOffline
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 2
        grants = try container.decode([EvaConsentPolicy.Grant].self, forKey: .grants)
        origin = try container.decode(EvaCloudActivationRecord.Origin.self, forKey: .origin)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        lastServerConsentRevision = try container.decodeIfPresent(Int.self, forKey: .lastServerConsentRevision)
        explicitOffline = try container.decodeIfPresent(Bool.self, forKey: .explicitOffline) ?? false
    }
}

enum EvaCloudActivationRecordStore {
    static let key = "eva.cloud.activation-record.v3"
    static let legacyKey = "eva.cloud.activation-record.v2"
    static let disabledKey = "eva.cloud.automatic-activation-disabled.v1"

    static func load(defaults: UserDefaults = .standard) -> EvaCloudActivationRecord? {
        if let data = defaults.data(forKey: key),
           let record = try? JSONDecoder.evaCloud.decode(EvaCloudActivationRecord.self, from: data) {
            if record.version == 3 { return record }
            if record.version == 2 {
                return save(
                    grants: Set(record.grants),
                    origin: record.origin,
                    defaults: defaults,
                    lastServerConsentRevision: record.lastServerConsentRevision,
                    explicitOffline: record.explicitOffline
                )
            }
        }
        if let data = defaults.data(forKey: legacyKey),
           let record = try? JSONDecoder.evaCloud.decode(EvaCloudActivationRecord.self, from: data) {
            return save(grants: Set(record.grants), origin: record.origin, defaults: defaults,
                        lastServerConsentRevision: record.lastServerConsentRevision,
                        explicitOffline: record.explicitOffline)
        }
        // Even an older disclosure revision retains the user's restrictions.
        if let data = defaults.data(forKey: EvaCloudActivationReceiptStore.key),
           let old = try? JSONDecoder.evaCloud.decode(EvaCloudActivationReceiptV1.self, from: data) {
            return save(grants: Set(old.grants), origin: .userSelection, defaults: defaults)
        }
        return nil
    }

    @discardableResult
    static func save(grants: Set<EvaConsentPolicy.Grant>, origin: EvaCloudActivationRecord.Origin,
                     defaults: UserDefaults = .standard,
                     lastServerConsentRevision: Int? = nil,
                     explicitOffline: Bool? = nil) -> EvaCloudActivationRecord {
        let existing = defaults.data(forKey: key).flatMap {
            try? JSONDecoder.evaCloud.decode(EvaCloudActivationRecord.self, from: $0)
        }
        let record = EvaCloudActivationRecord(
            grants: grants.sorted { $0.rawValue < $1.rawValue },
            origin: origin,
            updatedAt: .now,
            lastServerConsentRevision: lastServerConsentRevision,
            explicitOffline: explicitOffline ?? existing?.explicitOffline ?? false
        )
        if let data = try? JSONEncoder.evaCloud.encode(record) {
            defaults.set(data, forKey: key)
            defaults.removeObject(forKey: legacyKey)
        }
        return record
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: key)
        defaults.removeObject(forKey: legacyKey)
        defaults.removeObject(forKey: disabledKey)
    }

    static func setExplicitOffline(_ offline: Bool, defaults: UserDefaults = .standard) {
        let existing = load(defaults: defaults)
        _ = save(
            grants: Set(existing?.grants ?? EvaConsentPolicy.Grant.allCases),
            origin: existing?.origin ?? .automaticDefaults,
            defaults: defaults,
            lastServerConsentRevision: existing?.lastServerConsentRevision,
            explicitOffline: offline
        )
    }
}

/// The one owner of Cloud EVA readiness across launch, onboarding, chat, and settings.
///
/// Views render `state` and send intent here. Network work is single-flight, so
/// launch hydration and a first-message activation cannot race into duplicate
/// guest sessions. Local records retain defaults and user choices; the server
/// session and context revision remain request authority.
@MainActor
final class EvaCloudAccessCoordinator: ObservableObject {
    static let shared = EvaCloudAccessCoordinator()

    @Published private(set) var state: EvaCloudAccessState = .hydrating
    @Published private(set) var errorMessage: String?
    @Published var selectedGrants: Set<EvaConsentPolicy.Grant>

    let account: EvaCloudAccountState

    private let defaults: UserDefaults
    private let sessionStore: EvaCloudSessionStore
    private let refreshAccount: @MainActor () async -> Void
    private let accountReadinessError: @MainActor () -> EvaProviderError?
    private let activateAccount: @MainActor ([EvaConsentPolicy.Grant], Bool) async throws -> Void
    private var hydrationTask: Task<EvaCloudAccessState, Never>?
    private var activationTask: Task<Bool, Never>?
    private var ensureTask: Task<Bool, Never>?
    private var retryTask: Task<Void, Never>?
    private var retryCount = 0
    private var nextRetryAt = Date.distantPast
    private var networkMonitor: NWPathMonitor?

    var automaticActivationAllowed: Bool {
        EvaProviderRouter.Preference.resolvedStoredPreference(defaults: defaults) != .offline
            && !defaults.bool(forKey: EvaCloudActivationRecordStore.disabledKey)
            && EvaCloudActivationRecordStore.load(defaults: defaults)?.explicitOffline != true
    }

    /// Install once at launch; network changes only resume an unfinished activation.
    func startAutomaticActivation() {
        guard networkMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            guard path.status == .satisfied else { return }
            Task { @MainActor [weak self] in
                guard let self, state != .ready else { return }
                _ = await ensureActivated(source: .appLaunch)
            }
        }
        monitor.start(queue: DispatchQueue(label: "eva.activation.reachability"))
        networkMonitor = monitor
        Task { _ = await ensureActivated(source: .appLaunch) }
    }

    /// Drain network work before logout/deletion so a late bootstrap cannot
    /// recreate credentials after the user has turned Cloud off.
    func stopAutomaticActivation() async {
        disableAutomaticActivation()
        if let ensureTask { _ = await ensureTask.value }
        if let activationTask { _ = await activationTask.value }
        if let hydrationTask { _ = await hydrationTask.value }
        state = .needsActivation
    }

    func disableAutomaticActivation() {
        defaults.set(true, forKey: EvaCloudActivationRecordStore.disabledKey)
        EvaCloudActivationRecordStore.setExplicitOffline(true, defaults: defaults)
        retryTask?.cancel()
        retryTask = nil
        state = .needsActivation
    }


    init(
        account: EvaCloudAccountState = .shared,
        defaults: UserDefaults = .standard,
        sessionStore: EvaCloudSessionStore? = nil,
        refreshAccount: (@MainActor () async -> Void)? = nil,
        readinessError: (@MainActor () -> EvaProviderError?)? = nil,
        activateAccount: (@MainActor ([EvaConsentPolicy.Grant], Bool) async throws -> Void)? = nil
    ) {
        self.account = account
        self.defaults = defaults
        self.sessionStore = sessionStore ?? account.transport.sessionStore
        self.refreshAccount = refreshAccount ?? { await account.refresh() }
        self.accountReadinessError = readinessError ?? { account.readinessError() }
        self.activateAccount = activateAccount ?? { grants, preserve in
            try await account.activateCloud(grants: grants, preserveExistingGrants: preserve)
            if let error = account.readinessError() { throw error }
        }
        self.selectedGrants = Set(
            EvaCloudActivationRecordStore.load(defaults: defaults)?.grants
                ?? EvaConsentPolicy.Grant.allCases
        )
    }

    var isWorking: Bool {
        state == .hydrating || state == .activating
    }

    @discardableResult
    func hydrate() async -> EvaCloudAccessState {
        if let activationTask {
            _ = await activationTask.value
            return state
        }
        if let hydrationTask { return await hydrationTask.value }

        state = .hydrating
        errorMessage = nil
        let task = Task { @MainActor [weak self] () -> EvaCloudAccessState in
            guard let self else { return .needsActivation }
            let previousIdentityKind: EvaIdentityKind?
            switch await sessionStore.restoreOutcome() {
            case .missing:
                previousIdentityKind = EvaCloudRecoveryStore.load(defaults: defaults)?.identityKind
            case .restored(let credentials):
                previousIdentityKind = credentials.resolvedIdentityKind
            case .serverRevoked(let credentials):
                // The server rejected the family, but the stable identity is
                // still useful: Apple sessions need reauthentication and
                // guest sessions can recover through the same bootstrap ID.
                previousIdentityKind = credentials.resolvedIdentityKind
                await ProductTelemetry.shared.record(
                    .evaSessionStorageDeferred,
                    outcome: credentials.resolvedIdentityKind == .apple ? "apple_server_revoked" : "guest_server_revoked"
                )
            case .identityMismatch(let credentials):
                // Keep the old credentials untouched. A mismatch is either a
                // stale item surviving an uninstall or a temporary identity
                // read problem; neither is permission to create another guest.
                previousIdentityKind = credentials.resolvedIdentityKind
                let message = String(localized: "Cloud EVA is restoring this installation. Try again when secure storage is available.")
                errorMessage = message
                state = .temporarilyUnavailable(message)
                await ProductTelemetry.shared.record(.evaSessionStorageDeferred, outcome: "identity_mismatch")
                return state
            case .temporarilyUnavailable(let error):
                applyFailure(error, source: .appLaunch)
                await ProductTelemetry.shared.record(.evaSessionStorageDeferred, outcome: "keychain_unavailable")
                return state
            case .corrupt(let error):
                applyFailure(error, source: .appLaunch)
                await ProductTelemetry.shared.record(.evaSessionStorageDeferred, outcome: "corrupt")
                return state
            }
            await refreshAccount()
            if let consent = account.consent {
                selectedGrants = Set(consent.grants)
            } else if let receipt = EvaCloudActivationRecordStore.load(defaults: defaults) {
                selectedGrants = Set(receipt.grants)
            }
            let resolved = resolveState(previousIdentityKind: previousIdentityKind)
            state = resolved
            if case .temporarilyUnavailable(let message) = resolved { errorMessage = message }
            if resolved == .ready { ConnectionResumeStore.setPending(.eva, false) }
            await ProductTelemetry.shared.record(
                .evaReadinessHydrated,
                outcome: telemetryLabel(for: resolved)
            )
            return resolved
        }
        hydrationTask = task
        let result = await task.value
        hydrationTask = nil
        return result
    }

    /// All entry points join one operation. A missing legacy receipt is not a gate.
    @discardableResult
    func ensureActivated(source: EvaCloudAccessSource) async -> Bool {
        guard automaticActivationAllowed else { return false }
        if let ensureTask { return await ensureTask.value }
        guard Date() >= nextRetryAt else { return false }
        let task = Task { @MainActor [weak self] () -> Bool in
            guard let self else { return false }
            let hydrated = await hydrate()
            guard automaticActivationAllowed else { return false }
            if hydrated == .ready {
                retryCount = 0
                persistCurrentGrants()
                return true
            }
            switch hydrated {
            case .temporarilyUnavailable:
                scheduleRetry(source: source)
                return false
            case .appleReauthenticationRequired, .quotaExhausted: return false
            default: break
            }
            // A failed refresh must not overwrite an existing account's grants
            // with defaults. The account's activation method preserves server grants.
            let record = EvaCloudActivationRecordStore.load(defaults: defaults)
            let grants = Set(account.consent?.grants ?? record?.grants ?? EvaConsentPolicy.Grant.allCases)
            if record == nil {
                EvaCloudActivationRecordStore.save(grants: grants,
                    origin: account.consent == nil ? .automaticDefaults : .userSelection,
                    defaults: defaults,
                    lastServerConsentRevision: account.consent?.revision)
            }
            selectedGrants = grants
            let ready = await activate(grants: grants, source: source, preserveExistingGrants: true)
            if ready { retryCount = 0; persistCurrentGrants() }
            else { scheduleRetry(source: source) }
            return ready
        }
        ensureTask = task
        let result = await task.value
        ensureTask = nil
        return result
    }

    private func persistCurrentGrants() {
        guard let consent = account.consent else { return }
        selectedGrants = Set(consent.grants)
        let previous = EvaCloudActivationRecordStore.load(defaults: defaults)
        let origin: EvaCloudActivationRecord.Origin = previous.map { Set($0.grants) == Set(consent.grants) } == true
            ? (previous?.origin ?? .userSelection) : .userSelection
        EvaCloudActivationRecordStore.save(
            grants: selectedGrants,
            origin: origin,
            defaults: defaults,
            lastServerConsentRevision: consent.revision
        )
    }

    private func scheduleRetry(source: EvaCloudAccessSource) {
        guard case .temporarilyUnavailable = state, automaticActivationAllowed else { return }
        let delay = min(pow(2.0, Double(retryCount + 1)), 60)
        nextRetryAt = Date().addingTimeInterval(delay)
        guard retryCount < 3 else { return }
        retryCount += 1
        retryTask?.cancel()
        retryTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(delay)) } catch { return }
            guard let self, !Task.isCancelled else { return }
            retryTask = nil
            _ = await ensureActivated(source: source)
        }
    }

    @discardableResult
    func ensureReadyForSend(promptID: UUID) async -> Bool {
        await ensureActivated(source: .chatSend)
    }

    @discardableResult
    func reconnectApple() async -> Bool {
        if let ensureTask { _ = await ensureTask.value }
        if let activationTask { return await activationTask.value }
        if let hydrationTask { _ = await hydrationTask.value }
        if let activationTask { return await activationTask.value }
        selectCloud()
        state = .activating
        errorMessage = nil
        let task = Task { @MainActor [weak self] () -> Bool in
            guard let self else { return false }
            do {
                _ = try await EvaAppleIdentityService.shared.signIn(using: account.transport)
                EvaCloudRecoveryStore.clear(defaults: defaults)
                await account.refresh(forceConfigurationRefresh: true)
                let resolved = resolveState(previousIdentityKind: .apple)
                state = resolved
                return resolved == .ready
            } catch {
                applyFailure(error, source: .chatInlineAction)
                return false
            }
        }
        activationTask = task
        let result = await task.value
        activationTask = nil
        return result
    }

    func selectOffline() {
        retryTask?.cancel()
        retryTask = nil
        ConnectionResumeStore.setPending(.eva, false)
        defaults.set(EvaProviderRouter.Preference.offline.rawValue, forKey: "eva.provider.preference.v1")
        EvaCloudActivationRecordStore.setExplicitOffline(true, defaults: defaults)
        errorMessage = nil
    }

    func selectCloud() {
        defaults.set(false, forKey: EvaCloudActivationRecordStore.disabledKey)
        EvaCloudActivationRecordStore.setExplicitOffline(false, defaults: defaults)
        nextRetryAt = .distantPast
        retryCount = 0
        defaults.set(EvaProviderRouter.Preference.cloud.rawValue, forKey: "eva.provider.preference.v1")
        errorMessage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    private func activate(
        grants: Set<EvaConsentPolicy.Grant>,
        source: EvaCloudAccessSource,
        preserveExistingGrants: Bool = false
    ) async -> Bool {
        if let activationTask { return await activationTask.value }
        state = .activating
        ConnectionResumeStore.setPending(.eva, true)
        errorMessage = nil
        let orderedGrants = grants.sorted { $0.rawValue < $1.rawValue }
        let task = Task { @MainActor [weak self] () -> Bool in
            guard let self else { return false }
            do {
                try await activateAccount(orderedGrants, preserveExistingGrants)
                guard automaticActivationAllowed else { return false }
                state = .ready
                errorMessage = nil
                ConnectionResumeStore.setPending(.eva, false)
                EvaActivationDefaultsStore.markCompleted(defaults: defaults)
                await ProductTelemetry.shared.record(.evaActivationSucceeded, outcome: source.rawValue)
                return true
            } catch is CancellationError {
                state = .needsActivation
                errorMessage = nil
                return false
            } catch {
                applyFailure(error, source: source)
                return false
            }
        }
        activationTask = task
        let result = await task.value
        activationTask = nil
        return result
    }

    private func resolveState(previousIdentityKind: EvaIdentityKind?) -> EvaCloudAccessState {
        Self.resolveState(
            readinessError: accountReadinessError(),
            previousIdentityKind: previousIdentityKind,
            nextAvailableAt: account.quota?.nextAvailableAt
        )
    }

    static func resolveState(
        readinessError: EvaProviderError?,
        previousIdentityKind: EvaIdentityKind?,
        nextAvailableAt: Date?
    ) -> EvaCloudAccessState {
        guard let error = readinessError else { return .ready }
        switch error {
        case .authenticationRequired:
            return previousIdentityKind == .apple ? .appleReauthenticationRequired : .needsActivation
        case .adultEligibilityRequired:
            return .temporarilyUnavailable("EVA could not connect. Please try again.")
        case .consentRequired:
            return .needsActivation
        case .creditsExhausted:
            return .quotaExhausted(nextAvailableAt)
        case .unavailable(let message):
            return .temporarilyUnavailable(message)
        case .invalidResponse:
            return .temporarilyUnavailable(error.localizedDescription)
        }
    }

    private func applyFailure(_ error: Error, source: EvaCloudAccessSource) {
        errorMessage = Self.message(for: error)
        if let storageError = error as? EvaSecureStorageError {
            logError(
                event: "eva_secure_storage_failed",
                message: "Cloud EVA secure storage operation failed",
                component: "eva_cloud",
                fields: [
                    "operation": storageError.operation.rawValue,
                    "osStatus": String(storageError.status),
                    "systemMessage": storageError.systemMessage,
                ]
            )
        }
        if let envelope = error as? EvaErrorEnvelope {
            switch envelope.code {
            case "daily_quota_exhausted":
                state = .quotaExhausted(envelope.quota?.nextAvailableAt)
            case "adult_eligibility_required", "age_eligibility_required", "age_decision_required":
                state = .temporarilyUnavailable("EVA could not connect. Please try again.")
                errorMessage = "EVA could not connect. Please try again."
            case "session_expired", "unauthenticated":
                state = account.identityKind == .apple
                    ? .appleReauthenticationRequired
                    : .temporarilyUnavailable(errorMessage ?? envelope.message)
            default:
                state = .temporarilyUnavailable(errorMessage ?? envelope.message)
            }
        } else if let providerError = error as? EvaProviderError {
            switch providerError {
            case .authenticationRequired:
                state = account.identityKind == .apple ? .appleReauthenticationRequired : .needsActivation
            case .adultEligibilityRequired:
                state = .temporarilyUnavailable("EVA could not connect. Please try again.")
                errorMessage = "EVA could not connect. Please try again."
            case .consentRequired:
                state = .needsActivation
            case .creditsExhausted:
                state = .quotaExhausted(account.quota?.nextAvailableAt)
            case .unavailable(let message):
                state = .temporarilyUnavailable(message)
            case .invalidResponse:
                state = .temporarilyUnavailable(providerError.localizedDescription)
            }
        } else {
            state = .temporarilyUnavailable(errorMessage ?? error.localizedDescription)
        }
        Task {
            await ProductTelemetry.shared.record(
                .evaActivationFailed,
                outcome: source.rawValue,
                errorCode: Self.errorCode(for: error)
            )
        }
    }

    private func telemetryLabel(for state: EvaCloudAccessState) -> String {
        switch state {
        case .hydrating: "hydrating"
        case .ready: "ready"
        case .needsActivation: "needs_activation"
        case .activating: "activating"
        case .temporarilyUnavailable: "temporarily_unavailable"
        case .quotaExhausted: "quota_exhausted"
        case .appleReauthenticationRequired: "apple_reauthentication_required"
        }
    }

    static func errorCode(for error: Error) -> String {
        if let storageError = error as? EvaSecureStorageError { return storageError.telemetryCode }
        if let envelope = error as? EvaErrorEnvelope { return envelope.code }
        if let urlError = error as? URLError { return "url_\(urlError.code.rawValue)" }
        return String(describing: type(of: error))
    }

    static func message(for error: Error) -> String {
        if let storageError = error as? EvaSecureStorageError {
            return storageError.localizedDescription
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
                return "EVA's server didn't respond in time. Tap to try again — setup will resume safely."
            case .notConnectedToInternet, .networkConnectionLost:
                return "You're offline. Reconnect and tap to try again, or use Offline EVA."
            default:
                break
            }
        }
        if let envelope = error as? EvaErrorEnvelope, envelope.retryable {
            return "\(envelope.message) Tap to try again."
        }
        return error.localizedDescription
    }
}
