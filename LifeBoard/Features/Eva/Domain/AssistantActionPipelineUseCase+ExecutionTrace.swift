import Foundation
import LifeBoardDomain

struct AssistantExecutionTrace: Codable, Sendable {
    var runID: UUID?
    var commandCount: Int
    var startedAt: Date
    var finishedAt: Date?
    var durationMillis: Int?
    var status: String
    var rollbackVerified: Bool?
    var failureReason: String?
    var createdReferences: [EvaRecordReference]

    private enum CodingKeys: String, CodingKey {
        case runID, commandCount, startedAt, finishedAt, durationMillis, status
        case rollbackVerified, failureReason, createdReferences
    }

    init(
        runID: UUID?, commandCount: Int, startedAt: Date, finishedAt: Date?,
        durationMillis: Int?, status: String, rollbackVerified: Bool?,
        failureReason: String?, createdReferences: [EvaRecordReference] = []
    ) {
        self.runID = runID
        self.commandCount = commandCount
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.durationMillis = durationMillis
        self.status = status
        self.rollbackVerified = rollbackVerified
        self.failureReason = failureReason
        self.createdReferences = createdReferences
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            runID: try values.decodeIfPresent(UUID.self, forKey: .runID),
            commandCount: try values.decode(Int.self, forKey: .commandCount),
            startedAt: try values.decode(Date.self, forKey: .startedAt),
            finishedAt: try values.decodeIfPresent(Date.self, forKey: .finishedAt),
            durationMillis: try values.decodeIfPresent(Int.self, forKey: .durationMillis),
            status: try values.decode(String.self, forKey: .status),
            rollbackVerified: try values.decodeIfPresent(Bool.self, forKey: .rollbackVerified),
            failureReason: try values.decodeIfPresent(String.self, forKey: .failureReason),
            createdReferences: try values.decodeIfPresent([EvaRecordReference].self, forKey: .createdReferences) ?? []
        )
    }
}

final class AssistantActionCompletion<Value: Sendable>: @unchecked Sendable {
    private let completion: @Sendable (Result<Value, Error>) -> Void

    init(_ completion: @escaping @Sendable (Result<Value, Error>) -> Void) {
        self.completion = completion
    }

    func deliver(_ result: Result<Value, Error>) {
        DispatchQueue.main.async {
            self.completion(result)
        }
    }
}
