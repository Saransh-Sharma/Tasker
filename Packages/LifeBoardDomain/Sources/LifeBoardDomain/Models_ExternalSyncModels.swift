import Foundation

public struct ExternalContainerMapDefinition: Codable, Equatable, Hashable, Sendable {
    public let id: UUID
    public var provider: String
    public var projectID: UUID
    public var externalContainerID: String
    public var syncEnabled: Bool
    public var lastSyncAt: Date?
    public var createdAt: Date

    // Memberwise init written out: a public struct's implicit one is
    // internal, and this type is constructed from outside the package.
    // Optional `var`s keep the `= nil` default the implicit init gives them.
    public init(id: UUID, provider: String, projectID: UUID, externalContainerID: String, syncEnabled: Bool, lastSyncAt: Date? = nil, createdAt: Date) {
        self.id = id
        self.provider = provider
        self.projectID = projectID
        self.externalContainerID = externalContainerID
        self.syncEnabled = syncEnabled
        self.lastSyncAt = lastSyncAt
        self.createdAt = createdAt
    }
}

public struct ExternalItemMapDefinition: Codable, Equatable, Hashable, Sendable {
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

    /// Initializes a new instance.
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
