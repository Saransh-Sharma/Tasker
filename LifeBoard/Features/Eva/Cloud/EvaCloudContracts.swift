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
    enum Category: String, Codable, Sendable {
        case planning
        case journal
        case health
        case lifeMoments
        case personalMemory
    }

    let category: Category
    let payload: EvaJSONValue
}

enum EvaJSONValue: Codable, Sendable, Equatable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: EvaJSONValue])
    case array([EvaJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: EvaJSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([EvaJSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .bool(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

struct EvaInferenceRequest: Codable, Sendable {
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
