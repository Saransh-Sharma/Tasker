import Foundation

struct EvaErrorEnvelope: Codable, Error, LocalizedError, Sendable {
    let code: String
    let message: String
    let requestId: String
    let retryable: Bool
    let retryAfter: Int?
    let credits: EvaCreditState?
    let recoveryAction: String?

    var errorDescription: String? { message }
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
        case .authenticationRequired: String(localized: "Sign in with Apple to use Cloud EVA.")
        case .adultEligibilityRequired: String(localized: "Confirm 18+ eligibility to use Cloud EVA.")
        case .consentRequired: String(localized: "Review what Cloud EVA may use before continuing.")
        case .creditsExhausted: String(localized: "Cloud credits are unavailable. Offline EVA is still available.")
        case .invalidResponse: String(localized: "Cloud EVA returned an unreadable response.")
        }
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
