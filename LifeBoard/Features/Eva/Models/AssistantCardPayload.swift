import Foundation
import LifeBoardDomain

enum AssistantCardType: String, Codable, Sendable {
    case unknown
    case proposal
    case undo
    case status
    case error
    case commandResult
    case dayOverview
    case navigation

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .unknown
    }
}

enum AssistantCardStatus: String, Codable, Sendable {
    case unknown
    case pending
    case confirmed
    case applied
    case rejected
    case failed
    case rollbackComplete
    case rollbackFailed
    case undoAvailable
    case undoExpired
    case undone

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: value) ?? .unknown
    }
}

struct AssistantCardPayload: Codable, Equatable, Sendable {
    var cardType: AssistantCardType
    var runID: UUID?
    var threadID: String
    var status: AssistantCardStatus
    var rationale: String?
    var diffLines: [AssistantDiffLine]
    var destructiveCount: Int
    var affectedTaskCount: Int
    var expiresAt: Date?
    var message: String?
    var commandResult: SlashCommandExecutionResult?
    var evaProposal: EvaProposalReviewPayload?
    var dayOverview: EvaDayOverviewPayload?
    var navigation: EvaNavigationCardPayload?
    var captureReferences: [EvaRecordReference]

    enum CodingKeys: String, CodingKey {
        case cardType = "card_type"
        case runID = "run_id"
        case threadID = "thread_id"
        case status
        case rationale
        case diffLines = "diff_lines"
        case destructiveCount = "destructive_count"
        case affectedTaskCount = "affected_task_count"
        case expiresAt = "expires_at"
        case message
        case commandResult = "command_result"
        case evaProposal = "eva_proposal"
        case dayOverview = "day_overview"
        case navigation
        case captureReferences = "capture_references"
    }

    /// Initializes a new instance.
    init(
        cardType: AssistantCardType,
        runID: UUID? = nil,
        threadID: String,
        status: AssistantCardStatus,
        rationale: String? = nil,
        diffLines: [AssistantDiffLine] = [],
        destructiveCount: Int = 0,
        affectedTaskCount: Int = 0,
        expiresAt: Date? = nil,
        message: String? = nil,
        commandResult: SlashCommandExecutionResult? = nil,
        evaProposal: EvaProposalReviewPayload? = nil,
        dayOverview: EvaDayOverviewPayload? = nil,
        navigation: EvaNavigationCardPayload? = nil,
        captureReferences: [EvaRecordReference] = []
    ) {
        self.cardType = cardType
        self.runID = runID
        self.threadID = threadID
        self.status = status
        self.rationale = rationale
        self.diffLines = diffLines
        self.destructiveCount = destructiveCount
        self.affectedTaskCount = affectedTaskCount
        self.expiresAt = expiresAt
        self.message = message
        self.commandResult = commandResult
        self.evaProposal = evaProposal
        self.dayOverview = dayOverview
        self.navigation = navigation
        self.captureReferences = captureReferences
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        cardType = try values.decode(AssistantCardType.self, forKey: .cardType)
        runID = try values.decodeIfPresent(UUID.self, forKey: .runID)
        threadID = try values.decodeIfPresent(String.self, forKey: .threadID) ?? ""
        status = try values.decodeIfPresent(AssistantCardStatus.self, forKey: .status) ?? .unknown
        rationale = try values.decodeIfPresent(String.self, forKey: .rationale)
        diffLines = try values.decodeIfPresent([AssistantDiffLine].self, forKey: .diffLines) ?? []
        destructiveCount = try values.decodeIfPresent(Int.self, forKey: .destructiveCount) ?? 0
        affectedTaskCount = try values.decodeIfPresent(Int.self, forKey: .affectedTaskCount) ?? 0
        expiresAt = try values.decodeIfPresent(Date.self, forKey: .expiresAt)
        message = try values.decodeIfPresent(String.self, forKey: .message)
        commandResult = try values.decodeIfPresent(SlashCommandExecutionResult.self, forKey: .commandResult)
        evaProposal = try values.decodeIfPresent(EvaProposalReviewPayload.self, forKey: .evaProposal)
        dayOverview = try values.decodeIfPresent(EvaDayOverviewPayload.self, forKey: .dayOverview)
        navigation = try values.decodeIfPresent(EvaNavigationCardPayload.self, forKey: .navigation)
        captureReferences = try values.decodeIfPresent([EvaRecordReference].self, forKey: .captureReferences) ?? []
    }
}

struct EvaNavigationCardPayload: Codable, Equatable, Sendable {
    let target: EvaNavigationTarget
    let query: String?
    let candidates: [EvaRecordReference]
    let message: String
}

enum AssistantCardCodec {
    static let prefix = "__LIFEBOARD_CARD_V1__\n"

    /// Executes encode.
    static func encode(_ payload: AssistantCardPayload) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(date.timeIntervalSinceReferenceDate)
        }
        guard let data = try? encoder.encode(payload) else {
            return prefix + "{}"
        }
        return prefix + String(decoding: data, as: UTF8.self)
    }

    /// Executes decode.
    static func decode(from content: String) -> AssistantCardPayload? {
        guard content.hasPrefix(prefix) else { return nil }
        let body = String(content.dropFirst(prefix.count))
        guard let data = body.data(using: .utf8) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            if let referenceInterval = try? container.decode(TimeInterval.self) {
                return Date(timeIntervalSinceReferenceDate: referenceInterval)
            }
            let value = try container.decode(String.self)
            if let date = iso8601Date(from: value, includingFractionalSeconds: true)
                ?? iso8601Date(from: value, includingFractionalSeconds: false) {
                return date
            }
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Invalid ISO 8601 date: \(value)"
            )
        }
        return try? decoder.decode(AssistantCardPayload.self, from: data)
    }

    /// Executes isCard.
    static func isCard(_ content: String) -> Bool {
        content.hasPrefix(prefix)
    }

    private static func iso8601Date(from value: String, includingFractionalSeconds: Bool) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = includingFractionalSeconds
            ? [.withInternetDateTime, .withFractionalSeconds]
            : [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
