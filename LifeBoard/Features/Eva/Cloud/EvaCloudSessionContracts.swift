import Foundation

struct EvaErrorEnvelope: Codable, Error, LocalizedError, Sendable {
    let code: String
    let message: String
    let requestId: String
    let retryable: Bool
    let retryAfter: Int?
    let credits: EvaCreditState?
    let quota: EvaQuotaState?
    let recoveryAction: String?

    var errorDescription: String? { message }

    init(
        code: String,
        message: String,
        requestId: String,
        retryable: Bool,
        retryAfter: Int?,
        credits: EvaCreditState?,
        quota: EvaQuotaState? = nil,
        recoveryAction: String?
    ) {
        self.code = code
        self.message = message
        self.requestId = requestId
        self.retryable = retryable
        self.retryAfter = retryAfter
        self.credits = credits
        self.quota = quota
        self.recoveryAction = recoveryAction
    }
}

enum EvaIdentityKind: String, Codable, Sendable {
    case guest
    case apple
}

struct EvaUsage: Codable, Sendable {
    let inputTokens: Int
    let cachedInputTokens: Int
    let cacheWriteTokens: Int
    let outputTokens: Int
    let reasoningTokens: Int
}

struct EvaSessionCredentials: Codable, Sendable {
    let accountId: String
    let familyId: UUID
    let accessToken: String
    let accessTokenExpiresAt: Date
    let refreshToken: String
    let refreshTokenExpiresAt: Date
    let installationId: UUID
    let platform: String
    let appleUserIdentifier: String?
    let identityKind: EvaIdentityKind?
    let trustTier: String?

    var resolvedIdentityKind: EvaIdentityKind {
        identityKind ?? (appleUserIdentifier == nil ? .guest : .apple)
    }

    init(
        accountId: String,
        familyId: UUID,
        accessToken: String,
        accessTokenExpiresAt: Date,
        refreshToken: String,
        refreshTokenExpiresAt: Date,
        installationId: UUID,
        platform: String,
        appleUserIdentifier: String?,
        identityKind: EvaIdentityKind? = nil,
        trustTier: String? = nil
    ) {
        self.accountId = accountId
        self.familyId = familyId
        self.accessToken = accessToken
        self.accessTokenExpiresAt = accessTokenExpiresAt
        self.refreshToken = refreshToken
        self.refreshTokenExpiresAt = refreshTokenExpiresAt
        self.installationId = installationId
        self.platform = platform
        self.appleUserIdentifier = appleUserIdentifier
        self.identityKind = identityKind
        self.trustTier = trustTier
    }
}

struct EvaRuntimeDescriptor: Sendable, Equatable {
    enum Provider: String, Sendable { case cloud, mlx, deterministic }

    let provider: Provider
    let label: String
    let supportsStreaming: Bool
    let supportsSpokenOutput: Bool
}

enum EvaProviderError: LocalizedError, Sendable {
    case unavailable(String)
    case authenticationRequired
    case adultEligibilityRequired
    case consentRequired
    case creditsExhausted(EvaCreditState?)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .unavailable(let message): message
        case .authenticationRequired: String(localized: "Activate Cloud EVA to continue.")
        case .adultEligibilityRequired: String(localized: "Cloud EVA is available to people age 13 or older.")
        case .consentRequired: String(localized: "Review what Cloud EVA may use before continuing.")
        case .creditsExhausted: String(localized: "You've reached Cloud EVA's rolling answer limit. Offline EVA is still available.")
        case .invalidResponse: String(localized: "Cloud EVA returned an unreadable response.")
        }
    }
}

extension Error {
    /// True when the server's verdict is that this device must authenticate
    /// again: a session it no longer has, a refresh family it rotated away, or
    /// a binding it revoked. Deliberately narrow — a timeout or a 5xx says
    /// nothing about whether the stored session is still good, and treating it
    /// as though it did would throw away a perfectly valid session.
    var evaRequiresReauthentication: Bool {
        if let providerError = self as? EvaProviderError, case .authenticationRequired = providerError {
            return true
        }
        guard let envelope = self as? EvaErrorEnvelope else { return false }
        return envelope.code == "session_expired" || envelope.code == "unauthenticated"
    }
}

extension JSONDecoder {
    static var evaCloud: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

extension JSONEncoder {
    static var evaCloud: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
