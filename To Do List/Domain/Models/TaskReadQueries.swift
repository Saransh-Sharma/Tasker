import Foundation

public struct TaskReadQuery: Codable, Equatable, Hashable {
    public var projectID: UUID?
    public var includeCompleted: Bool
    public var dueDateStart: Date?
    public var dueDateEnd: Date?
    public var updatedAfter: Date?
    public var sortBy: TaskReadSort
    public var needsTotalCount: Bool
    public var limit: Int
    public var offset: Int

    /// Initializes a new instance.
    public init(
        projectID: UUID? = nil,
        includeCompleted: Bool = true,
        dueDateStart: Date? = nil,
        dueDateEnd: Date? = nil,
        updatedAfter: Date? = nil,
        sortBy: TaskReadSort = .dueDateAscending,
        needsTotalCount: Bool = false,
        limit: Int = 200,
        offset: Int = 0
    ) {
        self.projectID = projectID
        self.includeCompleted = includeCompleted
        self.dueDateStart = dueDateStart
        self.dueDateEnd = dueDateEnd
        self.updatedAfter = updatedAfter
        self.sortBy = sortBy
        self.needsTotalCount = needsTotalCount
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }
}

public enum TaskReadSort: String, Codable, Equatable, Hashable {
    case dueDateAscending
    case dueDateDescending
    case updatedAtDescending
}

public struct TaskSearchQuery: Codable, Equatable, Hashable {
    public var text: String
    public var projectID: UUID?
    public var includeCompleted: Bool
    public var needsTotalCount: Bool
    public var limit: Int
    public var offset: Int

    /// Initializes a new instance.
    public init(
        text: String,
        projectID: UUID? = nil,
        includeCompleted: Bool = true,
        needsTotalCount: Bool = false,
        limit: Int = 100,
        offset: Int = 0
    ) {
        self.text = text
        self.projectID = projectID
        self.includeCompleted = includeCompleted
        self.needsTotalCount = needsTotalCount
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }
}

public enum TaskSearchStatus: String, Codable, Equatable, Hashable {
    case all
    case today
    case overdue
    case completed
}

public struct TaskRepositorySearchQuery: Codable, Equatable, Hashable {
    public var text: String
    public var status: TaskSearchStatus
    public var projectIDs: [UUID]
    public var priorities: [Int32]
    public var needsTotalCount: Bool
    public var limit: Int
    public var offset: Int

    public init(
        text: String,
        status: TaskSearchStatus = .all,
        projectIDs: [UUID] = [],
        priorities: [Int32] = [],
        needsTotalCount: Bool = false,
        limit: Int = 100,
        offset: Int = 0
    ) {
        self.text = text
        self.status = status
        self.projectIDs = projectIDs
        self.priorities = priorities
        self.needsTotalCount = needsTotalCount
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }
}

public struct HomeProjectionQuery: Codable, Equatable {
    public var state: HomeFilterState
    public var scope: HomeListScope
    public var limit: Int
    public var offset: Int

    public init(
        state: HomeFilterState,
        scope: HomeListScope,
        limit: Int = 400,
        offset: Int = 0
    ) {
        self.state = state
        self.scope = scope
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }
}

public struct InsightsTodayTaskProjection: Codable, Equatable, Hashable {
    public let dueWindowTasks: [TaskDefinition]
    public let recentTasks: [TaskDefinition]

    public init(dueWindowTasks: [TaskDefinition], recentTasks: [TaskDefinition]) {
        self.dueWindowTasks = dueWindowTasks
        self.recentTasks = recentTasks
    }
}

public struct InsightsWeekTaskProjection: Codable, Equatable, Hashable {
    public let recentTasks: [TaskDefinition]
    public let dueWindowTasks: [TaskDefinition]
    public let projectScores: [UUID: Int]

    public init(
        recentTasks: [TaskDefinition],
        dueWindowTasks: [TaskDefinition],
        projectScores: [UUID: Int]
    ) {
        self.recentTasks = recentTasks
        self.dueWindowTasks = dueWindowTasks
        self.projectScores = projectScores
    }
}

public struct WeekChartProjection: Codable, Equatable, Hashable {
    public let weekStart: Date
    public let dayScores: [Date: Int]
    public let projectScores: [UUID: Int]

    public init(
        weekStart: Date,
        dayScores: [Date: Int],
        projectScores: [UUID: Int]
    ) {
        self.weekStart = weekStart
        self.dayScores = dayScores
        self.projectScores = projectScores
    }
}

public struct TaskDefinitionSliceResult: Codable, Equatable, Hashable {
    public var tasks: [TaskDefinition]
    public var totalCount: Int
    public var limit: Int
    public var offset: Int

    /// Initializes a new instance.
    public init(
        tasks: [TaskDefinition],
        totalCount: Int,
        limit: Int,
        offset: Int
    ) {
        self.tasks = tasks
        self.totalCount = totalCount
        self.limit = limit
        self.offset = offset
    }
}
