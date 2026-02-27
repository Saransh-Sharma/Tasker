import Foundation

public struct FocusSessionDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var taskID: UUID?
    public var startedAt: Date
    public var endedAt: Date?
    public var durationSeconds: Int
    public var targetDurationSeconds: Int
    public var wasCompleted: Bool
    public var xpAwarded: Int

    public init(
        id: UUID = UUID(),
        taskID: UUID? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        durationSeconds: Int = 0,
        targetDurationSeconds: Int = 0,
        wasCompleted: Bool = false,
        xpAwarded: Int = 0
    ) {
        self.id = id
        self.taskID = taskID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.targetDurationSeconds = targetDurationSeconds
        self.wasCompleted = wasCompleted
        self.xpAwarded = xpAwarded
    }
}
