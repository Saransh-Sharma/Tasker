import CryptoKit
import Foundation

private struct EvaCloudRefreshResponse: Decodable {
    let accessToken: String
    let accessTokenExpiresAt: Date
    let refreshToken: String
    let refreshTokenExpiresAt: Date
}

extension EvaCloudTransport {
    /// Retry remains opt-in because several routes consume single-use state or
    /// perform compare-and-swap writes that must never be replayed implicitly.
    func send(
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

    func perform(path: String, method: String, body: Data?, authenticated: Bool, attested: Bool) async throws -> Data {
        let request = try await makeRequest(path: path, method: method, body: body, authenticated: authenticated, attested: attested)
        let (data, response) = try await controlSession.data(for: request)
        try validate(response: response, errorData: data)
        return data
    }

    static func retryDelay(for error: Error) -> Double? {
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

    func makeRequest(path: String, method: String, body: Data?, authenticated: Bool, attested: Bool) async throws -> URLRequest {
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
            let digest = Data(SHA256.hash(data: body ?? Data())).base64URLEncodedString()
            let payload = Data("\(method)\n\(path)\n\(challenge)\n\(digest)".utf8)
            request.setValue(challenge, forHTTPHeaderField: "X-EVA-Attest-Challenge")
            request.setValue(try await EvaAppAttestService.shared.assertion(for: payload), forHTTPHeaderField: "X-EVA-Attest-Assertion")
        }
        return request
    }

    func validCredentials() async throws -> EvaSessionCredentials {
        guard let credentials = try await sessionStore.load() else { throw EvaProviderError.authenticationRequired }
        if credentials.accessTokenExpiresAt.timeIntervalSinceNow > 30 { return credentials }
        guard credentials.refreshTokenExpiresAt > Date() else {
            try? await sessionStore.clear()
            throw EvaProviderError.authenticationRequired
        }
        struct Body: Encodable {
            let accountId: String
            let familyId: UUID
            let refreshToken: String
            let installationId: UUID
            let platform: String
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
            try? await sessionStore.clear()
            throw EvaProviderError.authenticationRequired
        }
        let refreshed = try JSONDecoder.evaCloud.decode(EvaCloudRefreshResponse.self, from: data)
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

    func validate(response: URLResponse, errorData: Data?) throws {
        guard let http = response as? HTTPURLResponse else { throw EvaProviderError.invalidResponse }
        guard 200..<300 ~= http.statusCode else {
            if let errorData, let envelope = try? JSONDecoder.evaCloud.decode(EvaErrorEnvelope.self, from: errorData) {
                throw envelope
            }
            throw EvaProviderError.unavailable("Cloud EVA returned HTTP \(http.statusCode).")
        }
    }

    static func configuredBaseURL() throws -> URL {
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
