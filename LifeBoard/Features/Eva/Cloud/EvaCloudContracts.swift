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
    /// Contract version this client speaks. The server admits 1 and 2; only a
    /// v2 request may carry `userInstructions` into the developer message.
    static let contractVersion = 2

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
