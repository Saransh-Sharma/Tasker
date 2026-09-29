import Foundation

public enum HealthSyncOperationKind: String, Codable, Sendable {
    case write
    case update
    case delete
}

public enum HealthSyncOperationState: String, Codable, Sendable {
    case pending
    case processing
    case retryScheduled
    case pausedPermission
    case completed
}

public struct HealthSyncOperation: Codable, Hashable, Sendable, Identifiable {
    public let id: UUID
    public let localID: UUID
    public let metric: HealthMetric
    public let role: String
    public var kind: HealthSyncOperationKind
    public var state: HealthSyncOperationState
    public var payload: HealthWritePayload?
    public var syncVersion: Int64
    public var attemptCount: Int
    public var nextAttemptAt: Date?
    public var lastErrorCode: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        localID: UUID,
        metric: HealthMetric,
        role: String = "primary",
        kind: HealthSyncOperationKind,
        state: HealthSyncOperationState = .pending,
        payload: HealthWritePayload? = nil,
        syncVersion: Int64 = 1,
        attemptCount: Int = 0,
        nextAttemptAt: Date? = nil,
        lastErrorCode: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.localID = localID
        self.metric = metric
        self.role = role
        self.kind = kind
        self.state = state
        self.payload = payload
        self.syncVersion = max(1, syncVersion)
        self.attemptCount = attemptCount
        self.nextAttemptAt = nextAttemptAt
        self.lastErrorCode = lastErrorCode
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
