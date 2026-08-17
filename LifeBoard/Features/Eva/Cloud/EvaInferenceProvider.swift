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
        try await EvaAgeEligibilityService().revalidateIfNeeded(using: transport)
        let events = try await transport.inference(request)
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
            case .completed(_, _, let speechTicket, let speechSource, let credits):
                didComplete = true
                await EvaCloudAccountState.shared.accept(credits: credits)
                if let speechTicket {
                    await EvaSpeechTicketRegistry.shared.store(
                        requestId: request.requestId,
                        text: speechSource ?? text,
                        ticket: speechTicket
                    )
                }
            case .failed(_, _, let error):
                throw error
            case .accepted, .usage:
                break
            }
        }
        guard didComplete, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw EvaProviderError.invalidResponse
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

    private(set) var configuration: EvaCloudRuntimeConfiguration?
    private(set) var consent: EvaConsentPolicy?
    private(set) var credits: EvaCreditState?
    private(set) var isAuthenticated = false
    private(set) var isAdultEligible = false
    private(set) var lastError: String?

    var canUseCloud: Bool {
        canUseCloud(route: .chat)
    }

    func canUseCloud(route: EvaCloudRoute) -> Bool {
        readinessError(route: route) == nil
    }

    func readinessError(route: EvaCloudRoute = .chat) -> EvaProviderError? {
        Self.readinessError(
            configuration: configuration,
            isAuthenticated: isAuthenticated,
            isAdultEligible: isAdultEligible,
            hasConsent: consent != nil,
            creditBalance: credits?.balance,
            route: route,
            lastError: lastError
        )
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
        if let lastError { return .unavailable(lastError) }
        guard isAuthenticated else { return .authenticationRequired }
        guard isAdultEligible else { return .adultEligibilityRequired }
        guard let configuration else {
            return .unavailable(String(localized: "Cloud configuration could not be verified."))
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
        return nil
    }

    func refresh(
        using transport: EvaCloudTransport = .shared,
        forceConfigurationRefresh: Bool = false
    ) async {
        do {
            guard await EvaAppleIdentityService.shared.credentialIsAuthorized() else {
                await handleAppleCredentialInvalidation()
                return
            }
            configuration = try await transport.runtimeConfiguration(forceRefresh: forceConfigurationRefresh)
            consent = try await transport.consent()
            credits = try await transport.credits()
            isAuthenticated = true
            isAdultEligible = true
            lastError = nil
        } catch {
            isAuthenticated = (try? await EvaCloudSessionStore.shared.load()) != nil
            isAdultEligible = false
            lastError = error.localizedDescription
        }
    }

    func activateCloud() async throws {
        _ = try await EvaAppleIdentityService.shared.signIn()
        let age = try await EvaAgeEligibilityService().requestAndRegister()
        guard age.eligibleAdult else { throw EvaProviderError.adultEligibilityRequired }
        await refresh(forceConfigurationRefresh: true)
        if let readinessError = readinessError() { throw readinessError }
    }

    func accept(credits: EvaCreditState?) {
        if let credits { self.credits = credits }
    }

    func deactivateCloud() async {
        await EvaCloudTransport.shared.logout()
        configuration = nil
        consent = nil
        credits = nil
        isAuthenticated = false
        isAdultEligible = false
    }

    func handleAppleCredentialInvalidation() async {
        await EvaCloudTransport.shared.logout()
        configuration = nil
        consent = nil
        credits = nil
        isAuthenticated = false
        isAdultEligible = false
        lastError = String(localized: "Sign in with Apple authorization changed. Sign in again to use Cloud EVA.")
    }

    func deleteCloudAccount() async throws {
        // A fresh Apple exchange gives the deletion endpoint its required
        // recent-authentication proof and binds the request to this device.
        _ = try await EvaAppleIdentityService.shared.signIn()
        try await EvaCloudTransport.shared.deleteAccount()
        configuration = nil
        consent = nil
        credits = nil
        isAuthenticated = false
        isAdultEligible = false
    }
}

actor EvaProviderRouter {
    static let shared = EvaProviderRouter()

    enum Preference: String, Sendable {
        case automatic
        case cloud
        case offline
    }

    private let cloud = EvaCloudProvider()
    private let mlx = EvaMLXProvider()
    private let deterministic = EvaDeterministicProvider()

    func select(hasOfflineModel: Bool, route: EvaCloudRoute) async -> EvaRuntimeDescriptor {
        let preference = Preference(rawValue: UserDefaults.standard.string(forKey: "eva.provider.preference.v1") ?? "automatic") ?? .automatic
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
    static func resolve(_ localModelName: String?, route: EvaCloudRoute = .chat) -> String? {
        let preference = EvaProviderRouter.Preference(
            rawValue: UserDefaults.standard.string(forKey: "eva.provider.preference.v1") ?? "automatic"
        ) ?? .automatic
        if preference != .offline, EvaCloudAccountState.shared.canUseCloud(route: route) {
            return "cloud-eva"
        }
        return preference == .offline ? localModelName : nil
    }
}

enum EvaRuntimePreparation {
    static func ensureReady(
        modelName: String,
        route: EvaCloudRoute
    ) async -> (result: LLMRuntimeCoordinator.EnsureReadyResult, usesCloud: Bool) {
        let cloudReady = await MainActor.run { EvaCloudAccountState.shared.canUseCloud(route: route) }
        let usesCloud = modelName == "cloud-eva" && cloudReady
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
    static func make(
        route: EvaCloudRoute,
        promptSnapshot: LLMChatPromptSnapshot,
        consentRevision: Int
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
            contractVersion: 1,
            locale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier,
            messages: messages.isEmpty ? [EvaCloudMessage(role: .user, content: "Continue.")] : messages,
            context: promptSnapshot.cloudContext,
            clientVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0",
            platform: EvaInstallationIdentity.platform,
            installationId: EvaInstallationIdentity.current,
            consentRevision: consentRevision,
            providerCapabilities: .init(streaming: true, structuredOutput: true, spokenOutput: true)
        )
    }
}
