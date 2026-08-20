import Foundation

enum EvaCloudRoute: String, Codable, CaseIterable, Sendable {
    case chat
    case plan
    case planRepair
    case fieldSuggestion
    case topThree
    case taskBreakdown
    case dailyBrief
    case universalInputClassification
    case dynamicChips
    case journalAnswer
    case knowledgeAnswer
    case shortcutsAnswer
    case debugSmoke
}

struct EvaCloudMessage: Codable, Sendable, Equatable {
    enum Role: String, Codable, Sendable {
        case user
        case assistant
    }

    let role: Role
    let content: String
}

struct EvaCloudContextSection: Codable, Sendable {
    /// Only the last four are consent-gated. The rest project records the person
    /// already sees inside LifeBoard and ride on the request's own
    /// authorization, so widening this list does not widen what a grant means.
    enum Category: String, Codable, Sendable, CaseIterable {
        case planning
        case capacity
        case goals
        case habits
        case dayLoop
        case retrospective
        case calendar
        case conversationSummary
        case journal
        case health
        case lifeMoments
        case personalMemory

        /// Mirrors `sensitiveContextCategories` in the shared contract. The
        /// server is authoritative; this only avoids building a section that
        /// would be refused.
        var requiredGrant: EvaConsentPolicy.Grant? {
            switch self {
            case .journal: .journal
            case .health: .health
            case .lifeMoments: .lifeMoments
            case .personalMemory: .personalMemory
            default: nil
            }
        }
    }

    let category: Category
    let payload: EvaJSONValue
}

struct EvaInferenceRequest: Codable, Sendable {
    /// The highest contract version this build can speak.
    ///
    /// It is a ceiling, not the value to send. See `negotiatedContractVersion`.
    static let maximumContractVersion = 2

    /// The version to actually send, given what the server advertises.
    ///
    /// Hardcoding the ceiling made the deploy order load-bearing: a client that
    /// always claimed v2 was rejected with HTTP 400 by any Worker that had not
    /// been deployed yet, because v2 fields and categories fail an older strict
    /// schema. The signed configuration already publishes `contractVersions`, so
    /// the client negotiates down instead and the two sides can ship in either
    /// order.
    ///
    /// Falling back to nil — no verified configuration — means v1, the version
    /// every deployed Worker has always accepted.
    static func negotiatedContractVersion(
        advertised: [Int]?,
        maximum: Int = EvaInferenceRequest.maximumContractVersion
    ) -> Int {
        let supported = (advertised ?? []).filter { $0 >= 1 && $0 <= maximum }
        return supported.max() ?? 1
    }

    struct Capabilities: Codable, Sendable {
        let streaming: Bool
        let structuredOutput: Bool
        let spokenOutput: Bool
    }

    let requestId: UUID
    let route: EvaCloudRoute
    let contractVersion: Int
    let locale: String
    let timeZone: String
    let messages: [EvaCloudMessage]
    let context: [EvaCloudContextSection]
    let userInstructions: EvaUserInstructions?
    let clientVersion: String
    let platform: String
    let installationId: UUID
    let consentRevision: Int
    let providerCapabilities: Capabilities
}

struct EvaCreditState: Codable, Sendable, Equatable {
    let balance: Int
    let capacity: Int
    let refillAmount: Int
    let nextRefillAt: Date
}

struct EvaConsentPolicy: Codable, Sendable, Equatable {
    enum Grant: String, Codable, CaseIterable, Sendable {
        case journal
        case health
        case lifeMoments
        case personalMemory
    }

    let schemaVersion: Int
    let revision: Int
    let grants: [Grant]
    let updatedAt: Date
}

enum EvaStreamEvent: Sendable {
    case accepted(requestId: UUID, sequence: Int, credits: EvaCreditState?)
    case textDelta(requestId: UUID, sequence: Int, delta: String)
    case structured(requestId: UUID, sequence: Int, value: EvaJSONValue)
    case usage(requestId: UUID, sequence: Int, usage: EvaUsage)
    case completed(requestId: UUID, sequence: Int, speechTicket: String?, speechSource: String?, credits: EvaCreditState?)
    case failed(requestId: UUID, sequence: Int, error: EvaErrorEnvelope)
}
