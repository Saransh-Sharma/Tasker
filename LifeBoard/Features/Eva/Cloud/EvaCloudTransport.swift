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

/// Owns Cloud EVA networking while keeping control-plane calls and long-lived
/// inference streams on sessions with deliberately different timeout policies.
actor EvaCloudTransport {
    static let shared = EvaCloudTransport()

    let sessionStore: EvaCloudSessionStore
    let configurationStore: EvaSignedConfigurationStore
    let controlSession: URLSession
    let inferenceSession: URLSession

    init(
        sessionStore: EvaCloudSessionStore = .shared,
        configurationStore: EvaSignedConfigurationStore = .shared,
        session: URLSession? = nil,
        inferenceSession: URLSession? = nil
    ) {
        self.sessionStore = sessionStore
        self.configurationStore = configurationStore
        controlSession = session ?? Self.makeSession()
        // Tests that inject one protocol-backed session should observe every
        // route. Production gets a dedicated streaming policy.
        self.inferenceSession = inferenceSession ?? session ?? Self.makeInferenceSession()
    }

    /// Short account/configuration calls should fail while recovery still feels
    /// immediate. Inference does not use this session.
    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }

    /// The Worker may legitimately spend 60 seconds producing a response. The
    /// request timeout bounds first-byte or stream inactivity; the resource
    /// timeout sits beyond the Worker's own hard deadline.
    static func makeInferenceSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 75
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }
}
