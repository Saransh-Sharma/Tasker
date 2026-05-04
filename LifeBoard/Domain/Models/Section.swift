import Foundation

public struct TaskerProjectSection: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var projectID: UUID
    public var name: String
    public var sortOrder: Int
    public var isCollapsed: Bool
    public var createdAt: Date
    public var updatedAt: Date

    /// Initializes a new instance.
    public init(
        id: UUID = UUID(),
        projectID: UUID,
        name: String,
        sortOrder: Int = 0,
        isCollapsed: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.name = name
        self.sortOrder = sortOrder
        self.isCollapsed = isCollapsed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
