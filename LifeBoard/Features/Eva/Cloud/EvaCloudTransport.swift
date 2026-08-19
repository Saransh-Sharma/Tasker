import CryptoKit
import Foundation

struct EvaAppleExchangeRequestV1: Codable, Sendable {
    let challengeId: UUID
    let nonce: String
    let identityToken: String
    let authorizationCode: String
    let installationId: UUID
    let platform: String
    let signedAppTransaction: String?
}

/// What the exchange told us about the account behind the new session. `created`
/// matters because a freshly bootstrapped account has no server-side age lease,
/// so any locally cached eligibility must be discarded before it is trusted.
struct EvaAppleExchangeOutcome: Sendable {
    let credentials: EvaSessionCredentials
    let requiresAdultEligibility: Bool
    let requiresAttestation: Bool
    let created: Bool
}

actor EvaCloudTransport {
    static let shared = EvaCloudTransport()

    private struct ConfigurationEnvelope: Decodable {
        let signedConfiguration: String
    }

    private struct Challenge: Decodable {
        let challengeId: UUID?
        let nonce: String?
        let challenge: String?
    }

    private struct ExchangeResponse: Decodable {
        let accountId: String
        let familyId: UUID
        let accessToken: String
        let accessTokenExpiresAt: Date
        let refreshToken: String
        let refreshTokenExpiresAt: Date
        let requiresAdultEligibility: Bool?
        let requiresAttestation: Bool?
        let created: Bool?
    }

    private struct RefreshResponse: Decodable {
        let accessToken: String
        let accessTokenExpiresAt: Date
        let refreshToken: String
        let refreshTokenExpiresAt: Date
    }

    private struct StreamWireEvent: Decodable {
        let type: String
        let requestId: UUID
        let sequence: Int
        let credits: EvaCreditState?
        let delta: String?
        let value: EvaJSONValue?
        let inputTokens: Int?
        let cachedInputTokens: Int?
        let cacheWriteTokens: Int?
        let outputTokens: Int?
        let reasoningTokens: Int?
        let speechTicket: String?
        let speechSource: String?
        let error: EvaErrorEnvelope?
    }

    private let sessionStore: EvaCloudSessionStore
    private let configurationStore: EvaSignedConfigurationStore
    private let session: URLSession

    init(
        sessionStore: EvaCloudSessionStore = .shared,
        configurationStore: EvaSignedConfigurationStore = .shared,
        session: URLSession? = nil
    ) {
        self.sessionStore = sessionStore
        self.configurationStore = configurationStore
        self.session = session ?? Self.makeSession()
    }

    /// `URLSession.shared` defaults to a 60-second request timeout, which is far
    /// past the point where an activation step reads as broken rather than slow.
    /// Every request routed through `send` is a short control-plane call, so it
    /// gets a budget a person is willing to wait out. Streaming routes build
    /// their own sessions — an SSE response would never fit inside this.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    func runtimeConfiguration(forceRefresh: Bool = false) async throws -> EvaCloudRuntimeConfiguration {
        if !forceRefresh, let fresh = await configurationStore.loadFresh() { return fresh }
        do {
            let data = try await send(path: "/v1/eva/config", method: "GET", body: nil, authenticated: false, attested: false, retryOnce: true)
            let envelope = try JSONDecoder.evaCloud.decode(ConfigurationEnvelope.self, from: data)
            return try await configurationStore.accept(envelope.signedConfiguration)
        } catch {
            if let cached = await configurationStore.loadLastVerified() { return cached }
            throw EvaProviderError.unavailable("Cloud configuration could not be verified.")
        }
    }

    func signInChallenge() async throws -> (id: UUID, nonce: String) {
        let data = try JSONEncoder.evaCloud.encode(["purpose": "signIn"])
        // Issuing a challenge mints fresh state rather than spending any, so a
        // lost response costs nothing but an orphaned Durable Object entry.
        let response = try await send(path: "/v1/auth/challenge", method: "POST", body: data, authenticated: false, attested: false, retryOnce: true)
        let challenge = try JSONDecoder.evaCloud.decode(Challenge.self, from: response)
        guard let id = challenge.challengeId, let nonce = challenge.nonce else { throw EvaProviderError.invalidResponse }
        return (id, nonce)
    }

    func exchangeAppleCredential(
        challengeId: UUID,
        nonce: String,
        identityToken: String,
        authorizationCode: String,
        appleUserIdentifier: String,
        signedAppTransaction: String?
    ) async throws -> EvaAppleExchangeOutcome {
        let body = EvaAppleExchangeRequestV1(
            challengeId: challengeId,
            nonce: nonce,
            identityToken: identityToken,
            authorizationCode: authorizationCode,
            installationId: EvaInstallationIdentity.current,
            platform: EvaInstallationIdentity.platform,
            signedAppTransaction: signedAppTransaction
        )
        let data = try await send(
            path: "/v1/auth/apple/exchange",
            method: "POST",
            body: JSONEncoder.evaCloud.encode(body),
            authenticated: false,
            attested: false
        )
        let response = try JSONDecoder.evaCloud.decode(ExchangeResponse.self, from: data)
        let credentials = EvaSessionCredentials(
            accountId: response.accountId,
            familyId: response.familyId,
            accessToken: response.accessToken,
            accessTokenExpiresAt: response.accessTokenExpiresAt,
            refreshToken: response.refreshToken,
            refreshTokenExpiresAt: response.refreshTokenExpiresAt,
            installationId: EvaInstallationIdentity.current,
            platform: EvaInstallationIdentity.platform,
            appleUserIdentifier: appleUserIdentifier
        )
        try await sessionStore.save(credentials)
        return EvaAppleExchangeOutcome(
            credentials: credentials,
            requiresAdultEligibility: response.requiresAdultEligibility ?? true,
            requiresAttestation: response.requiresAttestation ?? (EvaInstallationIdentity.platform == "ios"),
            created: response.created ?? false
        )
    }

    func attestationChallenge() async throws -> String {
        let data = try await send(path: "/v1/attestation/challenge", method: "POST", body: Data("{}".utf8), authenticated: true, attested: false)
        let challenge = try JSONDecoder.evaCloud.decode(Challenge.self, from: data)
        guard let value = challenge.challenge else { throw EvaProviderError.invalidResponse }
        return value
    }

    func registerAttestation(challenge: String, keyIdentifier: String, attestation: String) async throws {
        _ = try await send(
            path: "/v1/attestation/register",
            method: "POST",
            body: JSONEncoder.evaCloud.encode([
                "challenge": challenge,
                "keyId": keyIdentifier,
                "attestation": attestation,
            ]),
            authenticated: true,
            attested: false
        )
    }

    func registerAdultEligibility(lowerBound: Int?, declaration: String) async throws {
        _ = try await send(
            path: "/v1/age/eligibility",
            method: "POST",
            body: JSONEncoder.evaCloud.encode(EvaAdultEligibilityRequestV1(
                declaration: declaration,
                lowerBound: lowerBound,
                policyVersion: "apple-dar-v1"
            )),
            authenticated: true,
            attested: true
        )
    }

    func credits() async throws -> EvaCreditState {
        try JSONDecoder.evaCloud.decode(EvaCreditState.self, from: await send(
            path: "/v1/eva/credits", method: "GET", body: nil, authenticated: true, attested: false, retryOnce: true
        ))
    }

    func consent() async throws -> EvaConsentPolicy {
        try JSONDecoder.evaCloud.decode(EvaConsentPolicy.self, from: await send(
            path: "/v1/eva/consent", method: "GET", body: nil, authenticated: true, attested: false, retryOnce: true
        ))
    }

    func updateConsent(expectedRevision: Int, grants: [EvaConsentPolicy.Grant]) async throws -> EvaConsentPolicy {
        struct Body: Encodable { let expectedRevision: Int; let grants: [EvaConsentPolicy.Grant] }
        let data = try await send(
            path: "/v1/eva/consent",
            method: "PUT",
            body: JSONEncoder.evaCloud.encode(Body(expectedRevision: expectedRevision, grants: grants)),
            authenticated: true,
            attested: true
        )
        return try JSONDecoder.evaCloud.decode(EvaConsentPolicy.self, from: data)
    }

    func inference(_ request: EvaInferenceRequest) async throws -> AsyncThrowingStream<EvaStreamEvent, Error> {
        let body = try JSONEncoder.evaCloud.encode(request)
        let urlRequest = try await makeRequest(
            path: "/v1/eva/responses",
            method: "POST",
            body: body,
            authenticated: true,
            attested: true
        )
        let (bytes, response) = try await session.bytes(for: urlRequest)
        try validate(response: response, errorData: nil)
        return AsyncThrowingStream { continuation in
            let task = Task {
                var expectedSequence = 0
                do {
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        guard line.hasPrefix("data: ") else { continue }
                        let payload = String(line.dropFirst(6))
                        guard let data = payload.data(using: .utf8) else { throw EvaProviderError.invalidResponse }
                        let wire = try JSONDecoder.evaCloud.decode(StreamWireEvent.self, from: data)
                        guard wire.sequence == expectedSequence else { throw EvaProviderError.invalidResponse }
                        expectedSequence += 1
                        continuation.yield(try Self.event(from: wire))
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func speech(requestId: UUID, ticket: String, text: String, allowPaidRegeneration: Bool) async throws -> AsyncThrowingStream<Data, Error> {
        struct Body: Encodable {
            let requestId: UUID
            let speechTicket: String
            let text: String
            let allowPaidRegeneration: Bool
        }
        let body = try JSONEncoder.evaCloud.encode(Body(
            requestId: requestId,
            speechTicket: ticket,
            text: text,
            allowPaidRegeneration: allowPaidRegeneration
        ))
        let request = try await makeRequest(path: "/v1/eva/speech", method: "POST", body: body, authenticated: true, attested: true)
        return EvaSpeechDataStream.make(request: request)
    }

    func logout() async {
        _ = try? await send(path: "/v1/auth/logout", method: "POST", body: Data("{}".utf8), authenticated: true, attested: false)
        try? await sessionStore.clear()
        await EvaAppAttestService.shared.clearRegistration()
    }

    func deleteAccount() async throws {
        _ = try await send(
            path: "/v1/account",
            method: "DELETE",
            body: Data("{}".utf8),
            authenticated: true,
            attested: true
        )
        try await sessionStore.clear()
        await EvaAppAttestService.shared.clearRegistration()
    }

    /// `retryOnce` is opt-in per call site and must stay that way. Several routes
    /// spend a single-use token the moment the server reads them — the Apple
    /// exchange consumes its challenge and Apple's authorization code, refresh
    /// rotates the token family, attested routes burn an attestation challenge,
    /// and a consent write is a compare-and-swap on `expectedRevision`. Replaying
    /// any of those after a lost response is worse than reporting the failure.
    private func send(
        path: String,
        method: String,
        body: Data?,
        authenticated: Bool,
        attested: Bool,
        retryOnce: Bool = false
    ) async throws -> Data {
        do {
            return try await perform(path: path, method: method, body: body, authenticated: authenticated, attested: attested)
        } catch {
            guard retryOnce, let delay = Self.retryDelay(for: error) else { throw error }
            try await Task.sleep(for: .seconds(delay))
            return try await perform(path: path, method: method, body: body, authenticated: authenticated, attested: attested)
        }
    }

    private func perform(path: String, method: String, body: Data?, authenticated: Bool, attested: Bool) async throws -> Data {
        let request = try await makeRequest(path: path, method: method, body: body, authenticated: authenticated, attested: attested)
        let (data, response) = try await session.data(for: request)
        try validate(response: response, errorData: data)
        return data
    }

    /// Returns how long to wait before the single retry, or `nil` when the error
    /// is not one a retry can fix. Cancellation is never retried — it is the
    /// caller going away, not the network faltering.
    private static func retryDelay(for error: Error) -> Double? {
        if error is CancellationError { return nil }
        if let envelope = error as? EvaErrorEnvelope {
            guard envelope.retryable else { return nil }
            return min(Double(envelope.retryAfter ?? 1), 5)
        }
        guard let urlError = error as? URLError else { return nil }
        switch urlError.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost, .cannotFindHost, .dnsLookupFailed:
            return 0.6
        default:
            return nil
        }
    }

    private func makeRequest(path: String, method: String, body: Data?, authenticated: Bool, attested: Bool) async throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: try Self.configuredBaseURL()) else {
            throw EvaProviderError.invalidResponse
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(UUID().uuidString, forHTTPHeaderField: "X-Request-ID")
        if authenticated {
            let credentials = try await validCredentials()
            request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        }
        if attested, EvaInstallationIdentity.platform == "ios" {
            let challenge = try await attestationChallenge()
            let digest = Data(SHA256.hash(data: body ?? Data()))
                .base64URLEncodedString()
            let payload = Data("\(method)\n\(path)\n\(challenge)\n\(digest)".utf8)
            request.setValue(challenge, forHTTPHeaderField: "X-EVA-Attest-Challenge")
            request.setValue(try await EvaAppAttestService.shared.assertion(for: payload), forHTTPHeaderField: "X-EVA-Attest-Assertion")
        }
        return request
    }

    private func validCredentials() async throws -> EvaSessionCredentials {
        guard let credentials = try await sessionStore.load() else { throw EvaProviderError.authenticationRequired }
        if credentials.accessTokenExpiresAt.timeIntervalSinceNow > 30 { return credentials }
        guard credentials.refreshTokenExpiresAt > Date() else {
            try? await sessionStore.clear()
            throw EvaProviderError.authenticationRequired
        }
        struct Body: Encodable {
            let accountId: String; let familyId: UUID; let refreshToken: String; let installationId: UUID; let platform: String
        }
        let data: Data
        do {
            data = try await send(
                path: "/v1/auth/refresh",
                method: "POST",
                body: JSONEncoder.evaCloud.encode(Body(
                    accountId: credentials.accountId,
                    familyId: credentials.familyId,
                    refreshToken: credentials.refreshToken,
                    installationId: credentials.installationId,
                    platform: credentials.platform
                )),
                authenticated: false,
                attested: false
            )
        } catch let error where error.evaRequiresReauthentication {
            // The server has retired this family — reuse detection, a deleted
            // account, or lost binding. Keeping the dead credentials would make
            // every later attempt take the same doomed path and report "Your EVA
            // session has expired" forever, with no route back to sign-in.
            try? await sessionStore.clear()
            throw EvaProviderError.authenticationRequired
        }
        let refreshed = try JSONDecoder.evaCloud.decode(RefreshResponse.self, from: data)
        let replacement = EvaSessionCredentials(
            accountId: credentials.accountId,
            familyId: credentials.familyId,
            accessToken: refreshed.accessToken,
            accessTokenExpiresAt: refreshed.accessTokenExpiresAt,
            refreshToken: refreshed.refreshToken,
            refreshTokenExpiresAt: refreshed.refreshTokenExpiresAt,
            installationId: credentials.installationId,
            platform: credentials.platform,
            appleUserIdentifier: credentials.appleUserIdentifier
        )
        try await sessionStore.save(replacement)
        return replacement
    }

    private func validate(response: URLResponse, errorData: Data?) throws {
        guard let http = response as? HTTPURLResponse else { throw EvaProviderError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            if let errorData, let envelope = try? JSONDecoder.evaCloud.decode(EvaErrorEnvelope.self, from: errorData) {
                throw envelope
            }
            throw EvaProviderError.unavailable("Cloud EVA returned HTTP \(http.statusCode).")
        }
    }

    private static func event(from wire: StreamWireEvent) throws -> EvaStreamEvent {
        switch wire.type {
        case "response.accepted": .accepted(requestId: wire.requestId, sequence: wire.sequence, credits: wire.credits)
        case "response.text.delta":
            if let delta = wire.delta { .textDelta(requestId: wire.requestId, sequence: wire.sequence, delta: delta) }
            else { throw EvaProviderError.invalidResponse }
        case "response.structured":
            if let value = wire.value { .structured(requestId: wire.requestId, sequence: wire.sequence, value: value) }
            else { throw EvaProviderError.invalidResponse }
        case "response.usage": .usage(
            requestId: wire.requestId,
            sequence: wire.sequence,
            usage: EvaUsage(
                inputTokens: wire.inputTokens ?? 0,
                cachedInputTokens: wire.cachedInputTokens ?? 0,
                cacheWriteTokens: wire.cacheWriteTokens ?? 0,
                outputTokens: wire.outputTokens ?? 0,
                reasoningTokens: wire.reasoningTokens ?? 0
            )
        )
        case "response.completed": .completed(
            requestId: wire.requestId,
            sequence: wire.sequence,
            speechTicket: wire.speechTicket,
            speechSource: wire.speechSource,
            credits: wire.credits
        )
        case "response.failed":
            if let error = wire.error { .failed(requestId: wire.requestId, sequence: wire.sequence, error: error) }
            else { throw EvaProviderError.invalidResponse }
        default: throw EvaProviderError.invalidResponse
        }
    }

    private static func configuredBaseURL() throws -> URL {
        guard let value = Bundle.main.object(forInfoDictionaryKey: "EVACloudBaseURL") as? String,
              value.isEmpty == false,
              let components = URLComponents(string: value),
              components.scheme == "https",
              components.host?.isEmpty == false,
              components.user == nil,
              components.password == nil,
              components.query == nil,
              components.fragment == nil,
              components.path.isEmpty || components.path == "/",
              let url = components.url else {
            throw EvaProviderError.unavailable("Cloud EVA has no trusted service endpoint in this build.")
        }
        return url
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private final class EvaSpeechDataStream: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    private var continuation: AsyncThrowingStream<Data, Error>.Continuation?
    private var task: URLSessionDataTask?
    private var statusCode = 0
    private var errorData = Data()

    static func make(request: URLRequest) -> AsyncThrowingStream<Data, Error> {
        let delegate = EvaSpeechDataStream()
        return AsyncThrowingStream { continuation in
            delegate.continuation = continuation
            let session = URLSession(configuration: .ephemeral, delegate: delegate, delegateQueue: nil)
            let task = session.dataTask(with: request)
            delegate.task = task
            continuation.onTermination = { _ in task.cancel() }
            task.resume()
        }
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
        completionHandler(.allow)
    }

    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if 200..<300 ~= statusCode { continuation?.yield(data) }
        else { errorData.append(data) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        defer { session.finishTasksAndInvalidate() }
        if let error { continuation?.finish(throwing: error) }
        else if !(200..<300 ~= statusCode) {
            if let envelope = try? JSONDecoder.evaCloud.decode(EvaErrorEnvelope.self, from: errorData) {
                continuation?.finish(throwing: envelope)
            } else {
                continuation?.finish(throwing: EvaProviderError.unavailable("Spoken output returned HTTP \(statusCode)."))
            }
        } else { continuation?.finish() }
        continuation = nil
        self.task = nil
    }
}
