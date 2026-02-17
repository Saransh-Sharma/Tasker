import Foundation

public struct XPEventDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var occurrenceID: UUID?
    public var taskID: UUID?
    public var delta: Int
    public var reason: String
    public var idempotencyKey: String
    public var createdAt: Date
}
