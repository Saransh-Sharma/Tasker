import Foundation

public struct HabitDefinitionRecord: Codable, Equatable, Hashable {
    public let id: UUID
    public var lifeAreaID: UUID?
    public var projectID: UUID?
    public var title: String
    public var habitType: String
    public var targetConfigData: Data?
    public var metricConfigData: Data?
    public var isPaused: Bool
    public var lastGeneratedDate: Date?
    public var streakCurrent: Int
    public var streakBest: Int
    public var createdAt: Date
    public var updatedAt: Date

    /// Initializes a new instance.
    public init(
        id: UUID = UUID(),
        lifeAreaID: UUID? = nil,
        projectID: UUID? = nil,
        title: String,
        habitType: String,
        targetConfigData: Data? = nil,
        metricConfigData: Data? = nil,
        isPaused: Bool = false,
        lastGeneratedDate: Date? = nil,
        streakCurrent: Int = 0,
        streakBest: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.lifeAreaID = lifeAreaID
        self.projectID = projectID
        self.title = title
        self.habitType = habitType
        self.targetConfigData = targetConfigData
        self.metricConfigData = metricConfigData
        self.isPaused = isPaused
        self.lastGeneratedDate = lastGeneratedDate
        self.streakCurrent = streakCurrent
        self.streakBest = streakBest
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
