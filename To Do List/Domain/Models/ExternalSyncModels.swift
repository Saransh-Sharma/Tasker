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
    public var syncStateData: Data?
    public var createdAt: Date

    public init(
        id: UUID,
        provider: String,
        localEntityType: String,
        localEntityID: UUID,
        externalItemID: String,
        externalPersistentID: String? = nil,
        lastSeenExternalModAt: Date? = nil,
        externalPayloadData: Data? = nil,
        syncStateData: Data? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.provider = provider
        self.localEntityType = localEntityType
        self.localEntityID = localEntityID
        self.externalItemID = externalItemID
        self.externalPersistentID = externalPersistentID
        self.lastSeenExternalModAt = lastSeenExternalModAt
        self.externalPayloadData = externalPayloadData
        self.syncStateData = syncStateData
        self.createdAt = createdAt
    }
}
