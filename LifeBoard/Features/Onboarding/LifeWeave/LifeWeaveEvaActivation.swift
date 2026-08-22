import Foundation
import SwiftUI

enum EvaCloudAccessState: Equatable, Sendable {
    case hydrating
    case ready
    case needsDisclosure
    case activating
    case temporarilyUnavailable(String)
    case quotaExhausted(Date?)
    case ageBlocked(String)
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

/// The one owner of Cloud EVA readiness across launch, onboarding, chat, and settings.
///
/// Views render `state` and send intent here. Network work is single-flight, so
/// launch hydration and a first-message activation cannot race into duplicate
/// guest sessions. The local receipt only authorizes resuming a bootstrap; the
/// server session and consent revision remain request authority.
@MainActor
final class EvaCloudAccessCoordinator: ObservableObject {
    static let shared = EvaCloudAccessCoordinator()

    @Published private(set) var state: EvaCloudAccessState = .hydrating
    @Published private(set) var errorMessage: String?
    @Published var selectedGrants: Set<EvaConsentPolicy.Grant>

    let account: EvaCloudAccountState

    private let defaults: UserDefaults
    private let sessionStore: EvaCloudSessionStore
    private var hydrationTask: Task<EvaCloudAccessState, Never>?
    private var activationTask: Task<Bool, Never>?

    init(
        account: EvaCloudAccountState = .shared,
        defaults: UserDefaults = .standard,
        sessionStore: EvaCloudSessionStore = .shared
    ) {
        self.account = account
        self.defaults = defaults
        self.sessionStore = sessionStore
        self.selectedGrants = Set(
            EvaCloudActivationReceiptStore.load(defaults: defaults)?.grants
                ?? EvaConsentPolicy.Grant.allCases
        )
    }

    var isWorking: Bool {
        state == .hydrating || state == .activating
    }

    var hasCurrentReceipt: Bool {
        EvaCloudActivationReceiptStore.load(defaults: defaults) != nil
    }

    @discardableResult
    func hydrate() async -> EvaCloudAccessState {
        if let hydrationTask { return await hydrationTask.value }

        state = .hydrating
        errorMessage = nil
        let task = Task { @MainActor [weak self] () -> EvaCloudAccessState in
            guard let self else { return .needsDisclosure }
            let previousIdentityKind = (try? await sessionStore.load())?.resolvedIdentityKind
            await account.refresh()
            if let consent = account.consent {
                selectedGrants = Set(consent.grants)
            } else if let receipt = EvaCloudActivationReceiptStore.load(defaults: defaults) {
                selectedGrants = Set(receipt.grants)
            }
            let resolved = resolveState(previousIdentityKind: previousIdentityKind)
            state = resolved
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

    /// Resumes only when this device has a current, explicit disclosure receipt.
    @discardableResult
    func resumeConfirmedActivation(source: EvaCloudAccessSource) async -> Bool {
        guard EvaProviderRouter.Preference.resolvedStoredPreference(defaults: defaults) != .offline else {
            return false
        }
        let hydrated = await hydrate()
        if hydrated == .ready { return true }
        switch hydrated {
        case .appleReauthenticationRequired, .quotaExhausted, .ageBlocked:
            return false
        case .hydrating, .ready, .needsDisclosure, .activating, .temporarilyUnavailable:
            break
        }
        guard let receipt = EvaCloudActivationReceiptStore.load(defaults: defaults) else { return false }
        selectedGrants = Set(receipt.grants)
        await ProductTelemetry.shared.record(.evaActivationAutoResumed, outcome: source.rawValue)
        return await activate(grants: Set(receipt.grants), source: source)
    }

    @discardableResult
    func confirmAndActivate(
        grants: Set<EvaConsentPolicy.Grant>,
        source: EvaCloudAccessSource
    ) async -> Bool {
        EvaCloudActivationReceiptStore.save(grants: grants, defaults: defaults)
        selectCloud()
        selectedGrants = grants
        let hydrated = await hydrate()
        guard hydrated != .appleReauthenticationRequired else { return false }
        return await activate(grants: grants, source: source)
    }

    @discardableResult
    func ensureReadyForSend(promptID: UUID) async -> Bool {
        let hydrated = await hydrate()
        if hydrated == .ready { return true }
        if hasCurrentReceipt {
            return await resumeConfirmedActivation(source: .chatSend)
        }
        state = .needsDisclosure
        await ProductTelemetry.shared.record(
            .evaInlineActivationShown,
            outcome: String(promptID.uuidString.prefix(8))
        )
        return false
    }

    @discardableResult
    func reconnectApple() async -> Bool {
        if let activationTask { return await activationTask.value }
        selectCloud()
        state = .activating
        errorMessage = nil
        let task = Task { @MainActor [weak self] () -> Bool in
            guard let self else { return false }
            do {
                _ = try await EvaAppleIdentityService.shared.signIn()
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
        defaults.set(EvaProviderRouter.Preference.offline.rawValue, forKey: "eva.provider.preference.v1")
        errorMessage = nil
    }

    func selectCloud() {
        defaults.set(EvaProviderRouter.Preference.cloud.rawValue, forKey: "eva.provider.preference.v1")
        errorMessage = nil
    }

    func clearError() {
        errorMessage = nil
    }

    private func activate(
        grants: Set<EvaConsentPolicy.Grant>,
        source: EvaCloudAccessSource
    ) async -> Bool {
        if let activationTask { return await activationTask.value }
        state = .activating
        errorMessage = nil
        let orderedGrants = grants.sorted { $0.rawValue < $1.rawValue }
        let task = Task { @MainActor [weak self] () -> Bool in
            guard let self else { return false }
            do {
                try await account.activateCloud(grants: orderedGrants)
                guard account.canUseCloud else {
                    throw account.readinessError() ?? EvaProviderError.invalidResponse
                }
                state = .ready
                errorMessage = nil
                EvaActivationDefaultsStore.markCompleted(defaults: defaults)
                await ProductTelemetry.shared.record(.evaActivationSucceeded, outcome: source.rawValue)
                return true
            } catch is CancellationError {
                state = .needsDisclosure
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
            readinessError: account.readinessError(),
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
            return previousIdentityKind == .apple ? .appleReauthenticationRequired : .needsDisclosure
        case .adultEligibilityRequired:
            return .ageBlocked(error.localizedDescription)
        case .consentRequired:
            return .needsDisclosure
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
        if let envelope = error as? EvaErrorEnvelope {
            switch envelope.code {
            case "daily_quota_exhausted":
                state = .quotaExhausted(envelope.quota?.nextAvailableAt)
            case "adult_eligibility_required", "age_eligibility_required", "age_decision_required":
                state = .ageBlocked(envelope.message)
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
                state = account.identityKind == .apple ? .appleReauthenticationRequired : .needsDisclosure
            case .adultEligibilityRequired:
                state = .ageBlocked(providerError.localizedDescription)
            case .consentRequired:
                state = .needsDisclosure
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
        case .needsDisclosure: "needs_disclosure"
        case .activating: "activating"
        case .temporarilyUnavailable: "temporarily_unavailable"
        case .quotaExhausted: "quota_exhausted"
        case .ageBlocked: "age_blocked"
        case .appleReauthenticationRequired: "apple_reauthentication_required"
        }
    }

    private static func errorCode(for error: Error) -> String {
        if let envelope = error as? EvaErrorEnvelope { return envelope.code }
        if let urlError = error as? URLError { return "url_\(urlError.code.rawValue)" }
        return String(describing: type(of: error))
    }

    static func message(for error: Error) -> String {
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
