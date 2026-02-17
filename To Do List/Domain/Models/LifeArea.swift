import Foundation

public struct LifeArea: Codable, Equatable, Hashable {
    public let id: UUID
    public var name: String
    public var color: String?
    public var icon: String?
    public var sortOrder: Int
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var updatedByDeviceID: String?
    public var version: Int

    public init(
        id: UUID = UUID(),
        name: String,
        color: String? = nil,
        icon: String? = nil,
        sortOrder: Int = 0,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        updatedByDeviceID: String? = nil,
        version: Int = 1
    ) {
        self.id = id
        self.name = name
        self.color = color
        self.icon = icon
        self.sortOrder = sortOrder
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.updatedByDeviceID = updatedByDeviceID
        self.version = version
    }
}
