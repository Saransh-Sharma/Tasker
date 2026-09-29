import Foundation

struct EvaCreditState: Codable, Sendable, Equatable {
    let balance: Int
    let capacity: Int
    let refillAmount: Int
    let nextRefillAt: Date
}

struct EvaQuotaState: Codable, Sendable, Equatable {
    let limit: Int
    let used: Int
    let remaining: Int
    let windowSeconds: Int
    let nextAvailableAt: Date?
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
    let reviewRequired: Bool?
    let updatedAt: Date

    init(
        schemaVersion: Int,
        revision: Int,
        grants: [Grant],
        reviewRequired: Bool? = nil,
        updatedAt: Date
    ) {
        self.schemaVersion = schemaVersion
        self.revision = revision
        self.grants = grants
        self.reviewRequired = reviewRequired
        self.updatedAt = updatedAt
    }
}

enum EvaStreamEvent: Sendable {
    case accepted(requestId: UUID, sequence: Int, quota: EvaQuotaState?, credits: EvaCreditState?)
    case textDelta(requestId: UUID, sequence: Int, delta: String)
    case structured(requestId: UUID, sequence: Int, value: EvaJSONValue)
    case usage(requestId: UUID, sequence: Int, usage: EvaUsage)
    case completed(requestId: UUID, sequence: Int, speechTicket: String?, speechSource: String?, quota: EvaQuotaState?, credits: EvaCreditState?)
    case failed(requestId: UUID, sequence: Int, error: EvaErrorEnvelope)
}
