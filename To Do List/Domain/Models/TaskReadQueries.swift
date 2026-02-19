import Foundation

public struct TaskReadQuery: Codable, Equatable, Hashable {
    public var projectID: UUID?
    public var includeCompleted: Bool
    public var dueDateStart: Date?
    public var dueDateEnd: Date?
    public var updatedAfter: Date?
    public var sortBy: TaskReadSort
    public var limit: Int
    public var offset: Int

    public init(
        projectID: UUID? = nil,
        includeCompleted: Bool = true,
        dueDateStart: Date? = nil,
        dueDateEnd: Date? = nil,
        updatedAfter: Date? = nil,
        sortBy: TaskReadSort = .dueDateAscending,
        limit: Int = 200,
        offset: Int = 0
    ) {
        self.projectID = projectID
        self.includeCompleted = includeCompleted
        self.dueDateStart = dueDateStart
        self.dueDateEnd = dueDateEnd
        self.updatedAfter = updatedAfter
        self.sortBy = sortBy
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
    public var limit: Int
    public var offset: Int

    public init(
        text: String,
        projectID: UUID? = nil,
        includeCompleted: Bool = true,
        limit: Int = 100,
        offset: Int = 0
    ) {
        self.text = text
        self.projectID = projectID
        self.includeCompleted = includeCompleted
        self.limit = max(1, limit)
        self.offset = max(0, offset)
    }
}

public struct TaskDefinitionSliceResult: Codable, Equatable, Hashable {
    public var tasks: [TaskDefinition]
    public var totalCount: Int
    public var limit: Int
    public var offset: Int

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
