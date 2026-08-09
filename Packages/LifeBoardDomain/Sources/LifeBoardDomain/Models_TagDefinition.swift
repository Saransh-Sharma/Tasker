import Foundation

public struct TagDefinition: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var color: String?
    public var icon: String?
    public var sortOrder: Int
    public var createdAt: Date

    /// Initializes a new instance.
    public init(
        id: UUID = UUID(),
        name: String,
        color: String? = nil,
        icon: String? = nil,
        sortOrder: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}
