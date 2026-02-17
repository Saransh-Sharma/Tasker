import Foundation

public struct ExternalContainerMapDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var provider: String
    public var projectID: UUID
    public var externalContainerID: String
    public var syncEnabled: Bool
    public var lastSyncAt: Date?
    public var createdAt: Date
}

public struct ExternalItemMapDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var provider: String
    public var localEntityType: String
    public var localEntityID: UUID
    public var externalItemID: String
    public var externalPersistentID: String?
    public var lastSeenExternalModAt: Date?
    public var externalPayloadData: Data?
    public var createdAt: Date
}
