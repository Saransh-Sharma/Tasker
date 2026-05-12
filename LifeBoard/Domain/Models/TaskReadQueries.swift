import Foundation

public struct TaskReadQuery: Codable, Equatable, Hashable, Sendable {
    public var projectID: UUID?
    public var includeCompleted: Bool
    public var dueDateStart: Date?
    public var dueDateEnd: Date?
    public var updatedAfter: Date?
    public var planningBuckets: [TaskPlanningBucket]
    public var weeklyOutcomeID: UUID?
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
        planningBuckets: [TaskPlanningBucket] = [],
        weeklyOutcomeID: UUID? = nil,
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
        self.planningBuckets = planningBuckets
        self.weeklyOutcomeID = weeklyOutcomeID
        self.sortBy = sortBy
        self.needsTotalCount = needsTotalCount
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }
}

public enum TaskReadSort: String, Codable, Equatable, Hashable, Sendable {
    case dueDateAscending
    case dueDateDescending
    case updatedAtDescending
}

public struct TaskSearchQuery: Codable, Equatable, Hashable, Sendable {
    public var text: String
    public var projectID: UUID?
    public var includeCompleted: Bool
    public var planningBuckets: [TaskPlanningBucket]
    public var weeklyOutcomeID: UUID?
    public var needsTotalCount: Bool
    public var limit: Int
    public var offset: Int

    /// Initializes a new instance.
    public init(
        text: String,
        projectID: UUID? = nil,
        includeCompleted: Bool = true,
        planningBuckets: [TaskPlanningBucket] = [],
        weeklyOutcomeID: UUID? = nil,
        needsTotalCount: Bool = false,
        limit: Int = 100,
        offset: Int = 0
    ) {
        self.text = text
        self.projectID = projectID
        self.includeCompleted = includeCompleted
        self.planningBuckets = planningBuckets
        self.weeklyOutcomeID = weeklyOutcomeID
        self.needsTotalCount = needsTotalCount
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }
}

public enum TaskSearchStatus: String, Codable, Equatable, Hashable, Sendable {
    case all
    case today
    case overdue
    case completed
}

public struct TaskRepositorySearchQuery: Codable, Equatable, Hashable, Sendable {
    public var text: String
    public var status: TaskSearchStatus
    public var projectIDs: [UUID]
    public var priorities: [Int32]
    public var planningBuckets: [TaskPlanningBucket]
    public var weeklyOutcomeID: UUID?
    public var needsTotalCount: Bool
    public var limit: Int
    public var offset: Int

    public init(
        text: String,
        status: TaskSearchStatus = .all,
        projectIDs: [UUID] = [],
        priorities: [Int32] = [],
        planningBuckets: [TaskPlanningBucket] = [],
        weeklyOutcomeID: UUID? = nil,
        needsTotalCount: Bool = false,
        limit: Int = 100,
        offset: Int = 0
    ) {
        self.text = text
        self.status = status
        self.projectIDs = projectIDs
        self.priorities = priorities
        self.planningBuckets = planningBuckets
        self.weeklyOutcomeID = weeklyOutcomeID
        self.needsTotalCount = needsTotalCount
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }
}

public struct HomeProjectionQuery: Codable, Equatable, Sendable {
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

public struct NeedsReplanCandidateQuery: Codable, Equatable, Hashable, Sendable {
    public var referenceDate: Date
    public var scopedDate: Date?
    public var activeProjectIDs: [UUID]
    public var includeUnscheduledBacklog: Bool
    public var limit: Int
    public var offset: Int

    public init(
        referenceDate: Date = Date(),
        scopedDate: Date? = nil,
        activeProjectIDs: [UUID] = [],
        includeUnscheduledBacklog: Bool = true,
        limit: Int = 400,
        offset: Int = 0
    ) {
        self.referenceDate = referenceDate
        self.scopedDate = scopedDate
        self.activeProjectIDs = activeProjectIDs
        self.includeUnscheduledBacklog = includeUnscheduledBacklog
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }
}

public struct NeedsReplanCandidateProjection: Codable, Equatable, Hashable, Sendable {
    public let tasks: [TaskDefinition]
    public let totalCount: Int
    public let limit: Int
    public let offset: Int

    public init(tasks: [TaskDefinition], totalCount: Int, limit: Int, offset: Int) {
        self.tasks = tasks
        self.totalCount = totalCount
        self.limit = limit
        self.offset = offset
    }
}

public struct HomeTimelineTaskProjectionQuery: Codable, Equatable, Hashable, Sendable {
    public var selectedDay: Date
    public var weekStart: Date
    public var weekEnd: Date
    public var projectIDs: [UUID]
    public var includeCompleted: Bool
    public var limit: Int
    public var offset: Int

    public init(
        selectedDay: Date,
        weekStart: Date,
        weekEnd: Date,
        projectIDs: [UUID] = [],
        includeCompleted: Bool = true,
        limit: Int = 500,
        offset: Int = 0
    ) {
        self.selectedDay = selectedDay
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.projectIDs = projectIDs
        self.includeCompleted = includeCompleted
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }
}

public struct HomeTimelineTaskProjection: Codable, Equatable, Hashable, Sendable {
    public let tasks: [TaskDefinition]
    public let totalCount: Int
    public let limit: Int
    public let offset: Int

    public init(tasks: [TaskDefinition], totalCount: Int, limit: Int, offset: Int) {
        self.tasks = tasks
        self.totalCount = totalCount
        self.limit = limit
        self.offset = offset
    }
}

public struct InsightsTodayProjectionQuery: Codable, Equatable, Hashable, Sendable {
    public var referenceDate: Date
    public var dueWindowLimit: Int
    public var recentLimit: Int

    public init(
        referenceDate: Date,
        dueWindowLimit: Int = 240,
        recentLimit: Int = 240
    ) {
        self.referenceDate = referenceDate
        self.dueWindowLimit = max(1, dueWindowLimit)
        self.recentLimit = max(1, recentLimit)
    }
}

public struct InsightsWeekProjectionQuery: Codable, Equatable, Hashable, Sendable {
    public var referenceDate: Date
    public var dueWindowLimit: Int
    public var recentLimit: Int

    public init(
        referenceDate: Date,
        dueWindowLimit: Int = 260,
        recentLimit: Int = 260
    ) {
        self.referenceDate = referenceDate
        self.dueWindowLimit = max(1, dueWindowLimit)
        self.recentLimit = max(1, recentLimit)
    }
}

public struct DailyReflectionTaskProjectionQuery: Codable, Equatable, Hashable, Sendable {
    public var reflectionDate: Date
    public var planningDate: Date
    public var completedLimit: Int
    public var openTaskLimit: Int

    public init(
        reflectionDate: Date,
        planningDate: Date,
        completedLimit: Int = 160,
        openTaskLimit: Int = 240
    ) {
        self.reflectionDate = reflectionDate
        self.planningDate = planningDate
        self.completedLimit = max(1, completedLimit)
        self.openTaskLimit = max(1, openTaskLimit)
    }
}

public struct InsightsTodayTaskProjection: Codable, Equatable, Hashable, Sendable {
    public let dueWindowTasks: [TaskDefinition]
    public let recentTasks: [TaskDefinition]

    public init(dueWindowTasks: [TaskDefinition], recentTasks: [TaskDefinition]) {
        self.dueWindowTasks = dueWindowTasks
        self.recentTasks = recentTasks
    }
}

public struct InsightsWeekTaskProjection: Codable, Equatable, Hashable, Sendable {
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

public struct WeekChartProjection: Codable, Equatable, Hashable, Sendable {
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

public struct DailyReflectionTaskProjection: Codable, Equatable, Hashable, Sendable {
    public let reflectionCompletedTasks: [TaskDefinition]
    public let reflectionOpenTasks: [TaskDefinition]
    public let planningOpenTasks: [TaskDefinition]

    public init(
        reflectionCompletedTasks: [TaskDefinition],
        reflectionOpenTasks: [TaskDefinition],
        planningOpenTasks: [TaskDefinition]
    ) {
        self.reflectionCompletedTasks = reflectionCompletedTasks
        self.reflectionOpenTasks = reflectionOpenTasks
        self.planningOpenTasks = planningOpenTasks
    }
}

public struct TaskDefinitionSliceResult: Codable, Equatable, Hashable, Sendable {
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
