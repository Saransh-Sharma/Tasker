import Foundation

enum EvaCloudRoute: String, Codable, CaseIterable, Sendable {
    case chat
    case capture
    case navigation
    case plan
    case planRepair
    case fieldSuggestion
    case memoryCandidate
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

enum EvaSurface: String, Codable, Sendable {
    case evaTab
    case globalComposer
    case home
    case dailyBrief
    case knowledge
    case journal
    case shortcut
    case background
}

struct EvaTurnContext: Codable, Sendable, Equatable {
    let requestedAt: Date
    let localDate: String
    let calendarIdentifier: String
    let firstWeekday: Int
    let surface: EvaSurface

    static func current(
        surface: EvaSurface,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> EvaTurnContext {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return EvaTurnContext(
            requestedAt: now,
            localDate: formatter.string(from: now),
            calendarIdentifier: calendar.identifier.evaWireName,
            firstWeekday: calendar.firstWeekday,
            surface: surface
        )
    }
}

private extension Calendar.Identifier {
    var evaWireName: String {
        String(describing: self)
    }
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
        case journal
        case health
        case lifeMoments
        case personalMemory
        case knowledge

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
    let metadata: EvaContextSectionMetadata?

    init(
        category: Category,
        payload: EvaJSONValue,
        metadata: EvaContextSectionMetadata? = nil
    ) {
        self.category = category
        self.payload = payload
        self.metadata = metadata
    }

    func forContract(_ version: Int) -> EvaCloudContextSection {
        guard version >= 3 else {
            return EvaCloudContextSection(category: category, payload: payload)
        }
        let resolved = metadata ?? .init(
            availability: "complete",
            availableCount: nil,
            includedCount: nil,
            partialReasons: [],
            sourceIDs: []
        )
        return EvaCloudContextSection(
            category: category,
            payload: payload,
            metadata: .init(
                availability: resolved.availability,
                availableCount: resolved.availableCount,
                includedCount: resolved.includedCount,
                partialReasons: resolved.partialReasons,
                sourceIDs: resolved.sourceIDs,
                selectionReasons: version >= 4
                    ? (resolved.selectionReasons?.isEmpty == false ? resolved.selectionReasons : ["routeBaseline"])
                    : nil,
                freshnessAt: version >= 4 ? resolved.freshnessAt : nil
            )
        )
    }
}

struct EvaContextSectionMetadata: Codable, Sendable, Equatable {
    let availability: String
    let availableCount: Int?
    let includedCount: Int?
    let partialReasons: [String]
    let sourceIDs: [String]
    let selectionReasons: [String]?
    let freshnessAt: Date?

    init(
        availability: String,
        availableCount: Int?,
        includedCount: Int?,
        partialReasons: [String],
        sourceIDs: [String],
        selectionReasons: [String]? = nil,
        freshnessAt: Date? = nil
    ) {
        self.availability = availability
        self.availableCount = availableCount
        self.includedCount = includedCount
        self.partialReasons = partialReasons
        self.sourceIDs = sourceIDs
        self.selectionReasons = selectionReasons
        self.freshnessAt = freshnessAt
    }
}

struct EvaInferenceRequest: Codable, Sendable {
    /// The highest contract version this build can speak.
    ///
    /// It is a ceiling, not the value to send. See `negotiatedContractVersion`.
    static let maximumContractVersion = 4

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
    var turnContext: EvaTurnContext? = nil
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
