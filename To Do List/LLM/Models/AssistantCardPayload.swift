import Foundation

enum AssistantCardType: String, Codable {
    case proposal
    case undo
    case status
    case error
    case commandResult
}

enum AssistantCardStatus: String, Codable {
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
}

struct AssistantCardPayload: Codable, Equatable {
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
        commandResult: SlashCommandExecutionResult? = nil
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
    }
}

enum AssistantCardCodec {
    static let prefix = "__TASKER_CARD_V1__\n"

    /// Executes encode.
    static func encode(_ payload: AssistantCardPayload) -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
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
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AssistantCardPayload.self, from: data)
    }

    /// Executes isCard.
    static func isCard(_ content: String) -> Bool {
        content.hasPrefix(prefix)
    }
}
