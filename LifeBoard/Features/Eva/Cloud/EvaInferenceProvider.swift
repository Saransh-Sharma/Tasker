import CryptoKit
import Foundation
import MLXLMCommon
import Observation

protocol EvaInferenceProviding: Sendable {
    var runtime: EvaRuntimeDescriptor { get }
    func generate(
        request: EvaInferenceRequest,
        onText: @MainActor @Sendable @escaping (String) -> Void
    ) async throws -> String
}

struct EvaCloudProvider: EvaInferenceProviding {
    let transport: EvaCloudTransport

    init(transport: EvaCloudTransport = .shared) {
        self.transport = transport
    }

    let runtime = EvaRuntimeDescriptor(
        provider: .cloud,
        label: String(localized: "Cloud EVA · Luna"),
        supportsStreaming: true,
        supportsSpokenOutput: true
    )

    func generate(
        request: EvaInferenceRequest,
        onText: @MainActor @Sendable @escaping (String) -> Void
    ) async throws -> String {
        let requiresAgeDecision = await MainActor.run {
            EvaCloudAccountState.shared.configuration?.requiresAgeDecision == true
        }
        if requiresAgeDecision {
            try await EvaAgeEligibilityService().revalidateIfNeeded(using: transport)
        }
        if UserDefaults.standard.bool(forKey: "eva.cloud.first-prompt.sent") == false {
            await ProductTelemetry.shared.record(.evaFirstPromptSent)
            UserDefaults.standard.set(true, forKey: "eva.cloud.first-prompt.sent")
        }
        let events: AsyncThrowingStream<EvaStreamEvent, Error>
        do {
            events = try await transport.inference(request)
        } catch let error as EvaErrorEnvelope where error.code == "daily_quota_exhausted" {
            await ProductTelemetry.shared.record(.evaQuotaExhausted)
            throw error
        }
        var text = ""
        var didComplete = false
        for try await event in events {
            try Task.checkCancellation()
            switch event {
            case .textDelta(_, _, let delta):
                text += delta
                await onText(text)
            case .structured(_, _, let value):
                let data = try JSONEncoder.evaCloud.encode(value)
                text = String(decoding: data, as: UTF8.self)
                await onText(text)
            case .completed(_, _, let speechTicket, let speechSource, let quota, let credits):
                didComplete = true
                await EvaCloudAccountState.shared.accept(quota: quota, credits: credits)
                if let speechTicket {
                    await EvaSpeechTicketRegistry.shared.store(
                        requestId: request.requestId,
                        text: speechSource ?? text,
                        ticket: speechTicket
                    )
                }
            case .failed(_, _, let error):
                if error.code == "daily_quota_exhausted" {
                    await ProductTelemetry.shared.record(.evaQuotaExhausted)
                }
                throw error
            case .accepted, .usage:
                break
            }
        }
        guard didComplete, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EvaProviderError.invalidResponse
        }
        if UserDefaults.standard.bool(forKey: "eva.cloud.first-answer.completed") == false {
            await ProductTelemetry.shared.record(.evaFirstAnswerCompleted)
            UserDefaults.standard.set(true, forKey: "eva.cloud.first-answer.completed")
        }
        return text
    }
}

struct EvaMLXProvider: Sendable {
    let runtime = EvaRuntimeDescriptor(
        provider: .mlx,
        label: String(localized: "Offline EVA · MLX"),
        supportsStreaming: true,
        supportsSpokenOutput: false
    )
}

struct EvaDeterministicProvider: Sendable {
    let runtime = EvaRuntimeDescriptor(
        provider: .deterministic,
        label: "LifeBoard",
        supportsStreaming: false,
        supportsSpokenOutput: false
    )
}

@MainActor
@Observable
final class EvaCloudAccountState {
    static let shared = EvaCloudAccountState()

    /// Activation is four visible steps, not one opaque wait. Naming the current
    /// step lets the UI say which one is slow instead of showing a single spinner
    /// for the whole chain.
    enum ActivationStage: Sendable {
        case idle
        case creatingGuest
        case verifyingDevice
        case confirmingAge
        case finalizing

        var progressCaption: String? {
            switch self {
            case .idle: nil
            case .creatingGuest: String(localized: "Activating Cloud EVA…")
            case .verifyingDevice: String(localized: "Verifying this device…")
            case .confirmingAge: String(localized: "Confirming your age range…")
            case .finalizing: String(localized: "Securing your EVA session…")
            }
        }
    }

    private(set) var configuration: EvaCloudRuntimeConfiguration?
    private(set) var consent: EvaConsentPolicy?
    private(set) var credits: EvaCreditState?
    private(set) var quota: EvaQuotaState?
    private(set) var identityKind: EvaIdentityKind?
    private(set) var trustTier: String?
    private(set) var isAuthenticated = false
    private(set) var isAdultEligible = false
    private(set) var lastError: String?
    private(set) var activationStage: ActivationStage = .idle

    var canUseCloud: Bool {
        canUseCloud(route: .chat)
    }

    func canUseCloud(route: EvaCloudRoute) -> Bool {
        readinessError(route: route) == nil
    }

    func readinessError(route: EvaCloudRoute = .chat) -> EvaProviderError? {
        if let base = Self.readinessError(
            configuration: configuration,
            isAuthenticated: isAuthenticated,
            isAdultEligible: isAdultEligible,
            hasConsent: consent != nil && consent?.reviewRequired != true,
            creditBalance: quota?.remaining ?? credits?.balance,
            route: route,
            lastError: lastError
        ) { return base }
        if identityKind == .guest, configuration?.guestAccess?.inferenceEnabled != true {
            return .unavailable(configuration?.maintenanceMessage ?? String(localized: "Guest Cloud EVA is temporarily unavailable."))
        }
        return nil
    }

    static func readinessError(
        configuration: EvaCloudRuntimeConfiguration?,
        isAuthenticated: Bool,
        isAdultEligible: Bool,
        hasConsent: Bool,
        creditBalance: Int?,
        route: EvaCloudRoute,
        lastError: String?
    ) -> EvaProviderError? {
        // `lastError` is checked last, not first. It holds the text of the most
        // recent transient failure and is cleared only by a fully successful
        // refresh, so leading with it would mask an accurate, actionable state
        // (“confirm your age”) behind a stale network string for as long as the
        // next refresh takes to succeed.
        guard isAuthenticated else { return .authenticationRequired }
        guard isAdultEligible else { return .adultEligibilityRequired }
        guard let configuration else {
            return .unavailable(lastError ?? String(localized: "Cloud configuration could not be verified."))
        }
        guard configuration.cloudState != .disabled else {
            return .unavailable(configuration.maintenanceMessage ?? String(localized: "Cloud EVA is temporarily unavailable."))
        }
        guard configuration.routes[route]?.enabled == true else {
            return .unavailable(configuration.maintenanceMessage ?? String(localized: "This Cloud EVA capability is temporarily unavailable."))
        }
        guard hasConsent else { return .consentRequired }
        if configuration.routes[route]?.billable == true, (creditBalance ?? 0) <= 0 {
            return .creditsExhausted(nil)
        }
        if let lastError { return .unavailable(lastError) }
        return nil
    }

    func refresh(
        using transport: EvaCloudTransport = .shared,
        forceConfigurationRefresh: Bool = false
    ) async {
        do {
            guard let credentials = try await transport.sessionStore.load() else {
                configuration = nil
                consent = nil
                credits = nil
                quota = nil
                identityKind = nil
                trustTier = nil
                isAuthenticated = false
                isAdultEligible = false
                lastError = nil
                return
            }
            if credentials.resolvedIdentityKind == .apple {
                guard await EvaAppleIdentityService.shared.credentialIsAuthorized() else {
                    await handleAppleCredentialInvalidation()
                    return
                }
            }
            configuration = try await transport.runtimeConfiguration(forceRefresh: forceConfigurationRefresh)
            consent = try await transport.consent()
            quota = try await transport.quota()
            credits = Self.creditProjection(from: quota)
            let highTrust = await EvaAppAttestService.shared.registerIfNeeded(using: transport)
            let updatedCredentials = (try? await transport.sessionStore.load()) ?? credentials
            identityKind = updatedCredentials.resolvedIdentityKind
            trustTier = highTrust ? "high" : updatedCredentials.trustTier
            isAuthenticated = true
            isAdultEligible = true
            lastError = nil
        } catch is CancellationError {
            // The caller went away — `.task(id:)` teardown on a step change is the
            // common case. Recording that as a failure would pin `canUseCloud`
            // false and relabel the screen with the word "cancelled".
            return
        } catch let error as URLError where error.code == .cancelled {
            return
        } catch {
            isAuthenticated = (try? await EvaCloudSessionStore.shared.load()) != nil
            // Only an explicit server verdict clears eligibility. A timed-out
            // credits call says nothing about the user's age.
            if let envelope = error as? EvaErrorEnvelope,
               envelope.code == "adult_eligibility_required" || envelope.code == "age_eligibility_required" {
                isAdultEligible = false
                EvaAgeEligibilityService.invalidateCachedEligibility()
            }
            lastError = error.localizedDescription
        }
    }

    /// Resumable by design. Each leg checks whether its work is already done, so
    /// retrying after a stalled network hop picks up where it stopped instead of
    /// re-presenting the Apple sheet and spending another of the five exchanges
    /// the server allows per minute.
    func activateCloud(grants: [EvaConsentPolicy.Grant] = EvaConsentPolicy.Grant.allCases) async throws {
        lastError = nil
        activationStage = .creatingGuest
        defer { activationStage = .idle }
        await ProductTelemetry.shared.record(.evaActivationStarted)

        configuration = try await EvaCloudTransport.shared.runtimeConfiguration(forceRefresh: true)
        if try await resumeStoredSession() {
            isAuthenticated = true
            let currentConsent = try await EvaCloudTransport.shared.consent()
            let requestedGrants = Set(grants)
            if Set(currentConsent.grants) == requestedGrants {
                consent = currentConsent
            } else {
                consent = try await EvaCloudTransport.shared.updateConsent(
                    expectedRevision: currentConsent.revision,
                    grants: grants
                )
            }
        } else {
            guard configuration?.guestAccess?.bootstrapEnabled == true else {
                throw EvaProviderError.unavailable(
                    configuration?.maintenanceMessage ?? String(localized: "Guest Cloud EVA is not enabled yet.")
                )
            }
            await ProductTelemetry.shared.record(.evaActivationReviewConfirmed)
            let credentials = try await EvaCloudTransport.shared.bootstrapGuest(grants: grants)
            identityKind = credentials.resolvedIdentityKind
            trustTier = credentials.trustTier
            isAuthenticated = true
        }
        try await finishGuestActivation()
    }

    private func finishGuestActivation() async throws {
        if configuration?.requiresAgeDecision == true {
            activationStage = .confirmingAge
            let age = try await EvaAgeEligibilityService().requestAndRegister(policyRequired: true)
            guard age.eligible else { throw EvaProviderError.adultEligibilityRequired }
            isAdultEligible = true
        } else {
            isAdultEligible = true
        }

        activationStage = .verifyingDevice
        let highTrust = await EvaAppAttestService.shared.registerIfNeeded(using: .shared)
        trustTier = highTrust ? "high" : (trustTier ?? "low")
        activationStage = .finalizing
        await refresh(forceConfigurationRefresh: true)
        if let readinessError = readinessError() { throw readinessError }
    }

    /// Decides whether the stored session can stand in for a fresh sign-in.
    ///
    /// The Keychain only knows what was true when the session was written. It
    /// cannot know that the server has since rotated the refresh family away,
    /// deleted the account, or dropped the device binding — so the local checks
    /// below are a precondition, not an answer. The server is asked directly,
    /// and a refusal discards the dead session and returns `false` so this
    /// attempt signs in again. Without that fallback a retired session is a
    /// permanent dead end: every tap re-reads the same dead credentials and
    /// reports "Your EVA session has expired" with no route back to sign-in.
    private func resumeStoredSession() async throws -> Bool {
        guard let credentials = try? await EvaCloudSessionStore.shared.load(),
              credentials.refreshTokenExpiresAt > Date() else { return false }
        if credentials.resolvedIdentityKind == .apple,
           await EvaAppleIdentityService.shared.credentialIsAuthorized() == false { return false }

        activationStage = .verifyingDevice
        do {
            // A cheap authenticated GET is the only honest liveness probe: it
            // forces a token refresh when needed and makes the server rule on
            // the family. App Attest registration cannot serve here — it
            // short-circuits whenever a key already exists, proving nothing.
            quota = try await EvaCloudTransport.shared.quota()
            credits = Self.creditProjection(from: quota)
            // Sign-in would have done this; the resume path has to, or the
            // attested eligibility POST fails for want of a key.
            let highTrust = await EvaAppAttestService.shared.registerIfNeeded(using: .shared)
            identityKind = credentials.resolvedIdentityKind
            trustTier = highTrust ? "high" : credentials.trustTier
            return true
        } catch let error where error.evaRequiresReauthentication {
            await discardStoredSession()
            return false
        }
        // Any other failure — a timeout, a 5xx — propagates. It says nothing
        // about the session, and silently re-presenting the Apple sheet would
        // spend an exchange to solve a problem that was never authentication.
    }

    private func discardStoredSession() async {
        try? await EvaCloudSessionStore.shared.clear()
        await EvaAppAttestService.shared.clearRegistration()
        EvaAgeEligibilityService.invalidateCachedEligibility()
        configuration = nil
        consent = nil
        credits = nil
        quota = nil
        identityKind = nil
        trustTier = nil
        isAuthenticated = false
        isAdultEligible = false
    }

    func accept(quota: EvaQuotaState?, credits: EvaCreditState?) {
        if let quota {
            self.quota = quota
            self.credits = Self.creditProjection(from: quota)
            return
        }
        if let credits { self.credits = credits }
    }

    func accept(credits: EvaCreditState?) { accept(quota: nil, credits: credits) }

    func deactivateCloud() async {
        await EvaCloudTransport.shared.logout()
        EvaCloudActivationReceiptStore.clear()
        configuration = nil
        consent = nil
        credits = nil
        quota = nil
        identityKind = nil
        trustTier = nil
        isAuthenticated = false
        isAdultEligible = false
    }

    func handleAppleCredentialInvalidation() async {
        guard identityKind == .apple else { return }
        await EvaCloudTransport.shared.logout()
        configuration = nil
        consent = nil
        credits = nil
        quota = nil
        identityKind = nil
        trustTier = nil
        isAuthenticated = false
        isAdultEligible = false
        lastError = String(localized: "Your protected Cloud EVA session changed. Activate Cloud EVA again to continue.")
    }

    func deleteCloudAccount() async throws {
        if identityKind == .apple {
            try await EvaAppleIdentityService.shared.reauthenticate()
        }
        try await EvaCloudTransport.shared.deleteAccount()
        EvaCloudActivationReceiptStore.clear()
        configuration = nil
        consent = nil
        credits = nil
        quota = nil
        identityKind = nil
        trustTier = nil
        isAuthenticated = false
        isAdultEligible = false
    }

    func protectWithApple() async throws {
        guard identityKind == .guest else { return }
        do {
            _ = try await EvaCloudTransport.shared.quota()
        } catch let error where error.evaRequiresReauthentication {
            // A link may have committed while its response was lost. In that
            // case the guest family is intentionally revoked; a normal Apple
            // exchange recovers the canonical account without another merge.
            _ = try await EvaAppleIdentityService.shared.signIn()
            identityKind = .apple
            await refresh(forceConfigurationRefresh: true)
            return
        }
        _ = try await EvaAppleIdentityService.shared.linkGuest()
        await refresh(forceConfigurationRefresh: true)
        guard identityKind == .apple else { throw EvaProviderError.invalidResponse }
    }

    private static func creditProjection(from quota: EvaQuotaState?) -> EvaCreditState? {
        guard let quota else { return nil }
        return EvaCreditState(
            balance: quota.remaining,
            capacity: quota.limit,
            refillAmount: 1,
            nextRefillAt: quota.nextAvailableAt ?? Date().addingTimeInterval(TimeInterval(quota.windowSeconds))
        )
    }
}

actor EvaProviderRouter {
    static let shared = EvaProviderRouter()

    enum Preference: String, Sendable {
        /// Decode-only compatibility for builds that exposed an Automatic mode.
        case automatic
        case cloud
        case offline

        static func resolvedStoredPreference(defaults: UserDefaults = .standard) -> Preference {
            let stored = Preference(
                rawValue: defaults.string(forKey: "eva.provider.preference.v1") ?? Preference.cloud.rawValue
            ) ?? .cloud
            guard stored == .automatic else { return stored }
            defaults.set(Preference.cloud.rawValue, forKey: "eva.provider.preference.v1")
            return .cloud
        }
    }

    private let cloud = EvaCloudProvider()
    private let mlx = EvaMLXProvider()
    private let deterministic = EvaDeterministicProvider()

    func select(hasOfflineModel: Bool, route: EvaCloudRoute) async -> EvaRuntimeDescriptor {
        let preference = Preference.resolvedStoredPreference()
        let cloudReady = await MainActor.run { EvaCloudAccountState.shared.canUseCloud(route: route) }
        switch preference {
        case .cloud where cloudReady:
            return cloud.runtime
        case .offline where hasOfflineModel:
            return mlx.runtime
        case .automatic where cloudReady:
            return cloud.runtime
        case .automatic where hasOfflineModel:
            return deterministic.runtime
        case .cloud where hasOfflineModel:
            return deterministic.runtime
        default:
            return deterministic.runtime
        }
    }

    func cloudProvider() -> EvaCloudProvider { cloud }

    func setPreference(_ preference: Preference) {
        UserDefaults.standard.set(preference.rawValue, forKey: "eva.provider.preference.v1")
    }
}

@MainActor
enum EvaModelSelection {
    /// Routing sentinel, not an installed model. It never resolves through
    /// `ModelConfiguration.getModelByName`, so anything that treats a model name
    /// as proof of a local runtime has to test for it explicitly.
    nonisolated static let cloudSentinel = "cloud-eva"

    nonisolated static func isCloud(_ modelName: String?) -> Bool {
        modelName == cloudSentinel
    }

    static func resolve(_ localModelName: String?, route: EvaCloudRoute = .chat) -> String? {
        let preference = EvaProviderRouter.Preference.resolvedStoredPreference()
        if preference == .cloud, EvaCloudAccountState.shared.canUseCloud(route: route) {
            return cloudSentinel
        }
        return preference == .offline ? localModelName : nil
    }
}

enum EvaRuntimePreparation {
    static func prepare(
        runtime: EvaTurnRuntime
    ) async -> (readiness: LLMRuntimeCoordinator.EnsureReadyResult, durationMs: Int) {
        let startedAt = Date()
        let readiness = await ensureReady(runtime: runtime)
        return (readiness, Int(Date().timeIntervalSince(startedAt) * 1_000))
    }

    static func ensureReady(
        runtime: EvaTurnRuntime
    ) async -> LLMRuntimeCoordinator.EnsureReadyResult {
        if runtime.usesCloud {
            return .init(
                prewarmEligible: false,
                prewarmHit: true,
                ready: true,
                resolvedModelName: runtime.modelName,
                failureMessage: nil
            )
        }
        return await LLMRuntimeCoordinator.shared.ensureReady(modelName: runtime.modelName)
    }

    static func ensureReady(
        modelName: String,
        route: EvaCloudRoute
    ) async -> (result: LLMRuntimeCoordinator.EnsureReadyResult, usesCloud: Bool) {
        let cloudReady = await MainActor.run { EvaCloudAccountState.shared.canUseCloud(route: route) }
        let usesCloud = EvaModelSelection.isCloud(modelName) && cloudReady
        if usesCloud {
            return (.init(
                prewarmEligible: false,
                prewarmHit: true,
                ready: true,
                resolvedModelName: modelName,
                failureMessage: nil
            ), true)
        }
        return (await LLMRuntimeCoordinator.shared.ensureReady(modelName: modelName), false)
    }
}

actor EvaSpeechTicketRegistry {
    static let shared = EvaSpeechTicketRegistry()

    struct Ticket: Codable, Sendable {
        let requestId: UUID
        let text: String
        let textHash: String
        let token: String
        let expiresAt: Date
    }

    private var ticketsByTextHash: [String: Ticket] = [:]
    private var didLoad = false

    func store(requestId: UUID, text: String, ticket: String) {
        loadIfNeeded()
        let textHash = Self.key(text)
        ticketsByTextHash[textHash] = Ticket(
            requestId: requestId,
            text: text,
            textHash: textHash,
            token: ticket,
            expiresAt: Self.expiration(in: ticket) ?? Date().addingTimeInterval(30 * 24 * 60 * 60)
        )
        persist()
    }

    func ticket(for text: String) -> Ticket? {
        loadIfNeeded()
        let key = Self.key(text)
        guard let ticket = ticketsByTextHash[key] else { return nil }
        guard ticket.expiresAt > Date(), ticket.textHash == key, ticket.text == text else {
            ticketsByTextHash[key] = nil
            persist()
            return nil
        }
        return ticket
    }

    func remove(text: String) {
        remove(textHash: Self.key(text))
    }

    func remove(textHash: String) {
        loadIfNeeded()
        ticketsByTextHash[textHash] = nil
        persist()
    }

    private func loadIfNeeded() {
        guard !didLoad else { return }
        didLoad = true
        guard let data = try? Data(contentsOf: Self.storageURL),
              let stored = try? JSONDecoder.evaCloud.decode([String: Ticket].self, from: data) else { return }
        ticketsByTextHash = stored.filter { key, value in
            value.expiresAt > Date() && value.textHash == key && Self.key(value.text) == key
        }
        persist()
    }

    private func persist() {
        do {
            let directory = Self.storageURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true,
                attributes: [.protectionKey: FileProtectionType.complete]
            )
            try JSONEncoder.evaCloud.encode(ticketsByTextHash).write(
                to: Self.storageURL,
                options: [.atomic, .completeFileProtection]
            )
        } catch {
            // A missing protected ticket safely disables regeneration after restart.
        }
    }

    private static func key(_ text: String) -> String {
        SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    private static var storageURL: URL {
        let base = (try? FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? FileManager.default.temporaryDirectory
        return base.appending(path: "EVACloud/speech-tickets-v1.json")
    }

    private static func expiration(in token: String) -> Date? {
        let pieces = token.split(separator: ".")
        guard pieces.count == 3 else { return nil }
        var payload = String(pieces[1]).replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        payload += String(repeating: "=", count: (4 - payload.count % 4) % 4)
        guard let data = Data(base64Encoded: payload),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let expiration = object["exp"] as? NSNumber else { return nil }
        return Date(timeIntervalSince1970: expiration.doubleValue)
    }
}

extension EvaInferenceRequest {
    /// Builds the wire request.
    ///
    /// System messages are still dropped here, and deliberately: the route's
    /// operating contract and EVA's persona live server-side in `prompts.ts`,
    /// where they can be corrected without an app release. What the client owns
    /// is the person's *own* instruction, which now travels as
    /// `userInstructions` rather than being composed into a system message and
    /// silently discarded.
    static func make(
        route: EvaCloudRoute,
        promptSnapshot: LLMChatPromptSnapshot,
        consentRevision: Int,
        userInstructions: EvaUserInstructions? = nil,
        contractVersion: Int = 1,
        surface: EvaSurface = .evaTab
    ) -> EvaInferenceRequest {
        let messages = promptSnapshot.messages.compactMap { message -> EvaCloudMessage? in
            switch message.role {
            case .user: EvaCloudMessage(role: .user, content: message.content)
            case .assistant: EvaCloudMessage(role: .assistant, content: message.content)
            case .system, .tool: nil
            }
        }
        return EvaInferenceRequest(
            requestId: UUID(),
            route: route,
            contractVersion: contractVersion,
            locale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier,
            turnContext: contractVersion >= 4 ? .current(surface: surface) : nil,
            messages: messages.isEmpty ? [EvaCloudMessage(role: .user, content: "Continue.")] : messages,
            context: promptSnapshot.cloudContext.map { $0.forContract(contractVersion) },
            // A v1 Worker's strict schema has no `userInstructions` property and
            // rejects the whole request rather than ignoring it.
            userInstructions: contractVersion >= 2 ? userInstructions : nil,
            clientVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            platform: EvaInstallationIdentity.platform,
            installationId: EvaInstallationIdentity.current,
            consentRevision: consentRevision,
            providerCapabilities: .init(streaming: true, structuredOutput: true, spokenOutput: true)
        )
    }
}
