import Foundation

public struct TombstoneDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var entityType: String
    public var entityID: UUID
    public var deletedAt: Date
    public var deletedBy: String?
    public var purgeAfter: Date

    /// Initializes a new instance.
    public init(
        id: UUID = UUID(),
        entityType: String,
        entityID: UUID,
        deletedAt: Date = Date(),
        deletedBy: String? = nil,
        purgeAfter: Date
    ) {
        self.id = id
        self.entityType = entityType
        self.entityID = entityID
        self.deletedAt = deletedAt
        self.deletedBy = deletedBy
        self.purgeAfter = purgeAfter
    }
}
