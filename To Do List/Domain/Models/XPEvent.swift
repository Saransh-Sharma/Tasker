import Foundation

public struct XPEventDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var occurrenceID: UUID?
    public var taskID: UUID?
    public var delta: Int
    public var reason: String
    public var idempotencyKey: String
    public var createdAt: Date
    public var category: XPActionCategory?
    public var source: XPSource?
    public var qualityWeight: Double?
    public var periodKey: String?
    public var metadataBlob: Data?

    public init(
        id: UUID = UUID(),
        occurrenceID: UUID? = nil,
        taskID: UUID? = nil,
        delta: Int,
        reason: String,
        idempotencyKey: String,
        createdAt: Date = Date(),
        category: XPActionCategory? = nil,
        source: XPSource? = nil,
        qualityWeight: Double? = nil,
        periodKey: String? = nil,
        metadataBlob: Data? = nil
    ) {
        self.id = id
        self.occurrenceID = occurrenceID
        self.taskID = taskID
        self.delta = delta
        self.reason = reason
        self.idempotencyKey = idempotencyKey
        self.createdAt = createdAt
        self.category = category
        self.source = source
        self.qualityWeight = qualityWeight
        self.periodKey = periodKey
        self.metadataBlob = metadataBlob
    }
}
