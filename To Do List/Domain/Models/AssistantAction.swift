import Foundation

public enum AssistantActionStatus: String, Codable {
    case pending
    case confirmed
    case applied
    case rejected
    case failed
}

public enum AssistantRollbackStatus: String, Codable {
    case notNeeded
    case pendingVerification
    case verified
    case failed
}

public struct AssistantCommandEnvelope: Codable, Equatable, Hashable {
    public var schemaVersion: Int
    public var commands: [AssistantCommand]
    public var undoCommands: [AssistantCommand]?
    public var rationaleText: String?

    public init(
        schemaVersion: Int,
        commands: [AssistantCommand],
        undoCommands: [AssistantCommand]? = nil,
        rationaleText: String? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.commands = commands
        self.undoCommands = undoCommands
        self.rationaleText = rationaleText
    }
}

public struct AssistantTaskSnapshot: Codable, Equatable, Hashable {
    public var id: UUID
    public var projectID: UUID
    public var projectName: String?
    public var lifeAreaID: UUID?
    public var sectionID: UUID?
    public var parentTaskID: UUID?
    public var title: String
    public var details: String?
    public var priority: TaskPriority
    public var type: TaskType
    public var energy: TaskEnergy
    public var category: TaskCategory
    public var context: TaskContext
    public var dueDate: Date?
    public var isComplete: Bool
    public var dateAdded: Date
    public var dateCompleted: Date?
    public var isEveningTask: Bool
    public var alertReminderTime: Date?
    public var tagIDs: [UUID]
    public var dependencies: [TaskDependencyLinkDefinition]
    public var createdAt: Date
    public var updatedAt: Date

    public init(task: TaskDefinition) {
        self.id = task.id
        self.projectID = task.projectID
        self.projectName = task.projectName
        self.lifeAreaID = task.lifeAreaID
        self.sectionID = task.sectionID
        self.parentTaskID = task.parentTaskID
        self.title = task.title
        self.details = task.details
        self.priority = task.priority
        self.type = task.type
        self.energy = task.energy
        self.category = task.category
        self.context = task.context
        self.dueDate = task.dueDate
        self.isComplete = task.isComplete
        self.dateAdded = task.dateAdded
        self.dateCompleted = task.dateCompleted
        self.isEveningTask = task.isEveningTask
        self.alertReminderTime = task.alertReminderTime
        self.tagIDs = task.tagIDs.sorted { $0.uuidString < $1.uuidString }
        self.dependencies = task.dependencies.sorted {
            ($0.id.uuidString, $0.dependsOnTaskID.uuidString, $0.kind.rawValue)
            < ($1.id.uuidString, $1.dependsOnTaskID.uuidString, $1.kind.rawValue)
        }
        self.createdAt = task.createdAt
        self.updatedAt = task.updatedAt
    }

    public func toTaskDefinition() -> TaskDefinition {
        TaskDefinition(
            id: id,
            projectID: projectID,
            projectName: projectName,
            lifeAreaID: lifeAreaID,
            sectionID: sectionID,
            parentTaskID: parentTaskID,
            title: title,
            details: details,
            priority: priority,
            type: type,
            energy: energy,
            category: category,
            context: context,
            dueDate: dueDate,
            isComplete: isComplete,
            dateAdded: dateAdded,
            dateCompleted: dateCompleted,
            isEveningTask: isEveningTask,
            alertReminderTime: alertReminderTime,
            tagIDs: tagIDs,
            dependencies: dependencies,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

public enum AssistantCommand: Codable, Equatable, Hashable {
    case createTask(projectID: UUID, title: String)
    case restoreTask(taskID: UUID, projectID: UUID, title: String, dueDate: Date?, isComplete: Bool, dateCompleted: Date?)
    case restoreTaskSnapshot(snapshot: AssistantTaskSnapshot)
    case deleteTask(taskID: UUID)
    case updateTask(taskID: UUID, title: String?, dueDate: Date?)
    case setTaskCompletion(taskID: UUID, isComplete: Bool, dateCompleted: Date?)
    case completeTask(taskID: UUID)
    case moveTask(taskID: UUID, targetProjectID: UUID)

    private enum CodingKeys: String, CodingKey {
        case type
        case taskID
        case projectID
        case targetProjectID
        case title
        case dueDate
        case isComplete
        case dateCompleted
        case snapshot
    }

    private enum Kind: String, Codable {
        case createTask
        case restoreTask
        case restoreTaskSnapshot
        case deleteTask
        case updateTask
        case setTaskCompletion
        case completeTask
        case moveTask
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try container.decode(Kind.self, forKey: .type)
        switch kind {
        case .createTask:
            self = .createTask(
                projectID: try container.decode(UUID.self, forKey: .projectID),
                title: try container.decode(String.self, forKey: .title)
            )
        case .restoreTask:
            self = .restoreTask(
                taskID: try container.decode(UUID.self, forKey: .taskID),
                projectID: try container.decode(UUID.self, forKey: .projectID),
                title: try container.decode(String.self, forKey: .title),
                dueDate: try container.decodeIfPresent(Date.self, forKey: .dueDate),
                isComplete: try container.decode(Bool.self, forKey: .isComplete),
                dateCompleted: try container.decodeIfPresent(Date.self, forKey: .dateCompleted)
            )
        case .restoreTaskSnapshot:
            self = .restoreTaskSnapshot(
                snapshot: try container.decode(AssistantTaskSnapshot.self, forKey: .snapshot)
            )
        case .deleteTask:
            self = .deleteTask(taskID: try container.decode(UUID.self, forKey: .taskID))
        case .updateTask:
            self = .updateTask(
                taskID: try container.decode(UUID.self, forKey: .taskID),
                title: try container.decodeIfPresent(String.self, forKey: .title),
                dueDate: try container.decodeIfPresent(Date.self, forKey: .dueDate)
            )
        case .setTaskCompletion:
            self = .setTaskCompletion(
                taskID: try container.decode(UUID.self, forKey: .taskID),
                isComplete: try container.decode(Bool.self, forKey: .isComplete),
                dateCompleted: try container.decodeIfPresent(Date.self, forKey: .dateCompleted)
            )
        case .completeTask:
            self = .completeTask(taskID: try container.decode(UUID.self, forKey: .taskID))
        case .moveTask:
            self = .moveTask(
                taskID: try container.decode(UUID.self, forKey: .taskID),
                targetProjectID: try container.decode(UUID.self, forKey: .targetProjectID)
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .createTask(let projectID, let title):
            try container.encode(Kind.createTask, forKey: .type)
            try container.encode(projectID, forKey: .projectID)
            try container.encode(title, forKey: .title)
        case .restoreTask(let taskID, let projectID, let title, let dueDate, let isComplete, let dateCompleted):
            try container.encode(Kind.restoreTask, forKey: .type)
            try container.encode(taskID, forKey: .taskID)
            try container.encode(projectID, forKey: .projectID)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(dueDate, forKey: .dueDate)
            try container.encode(isComplete, forKey: .isComplete)
            try container.encodeIfPresent(dateCompleted, forKey: .dateCompleted)
        case .restoreTaskSnapshot(let snapshot):
            try container.encode(Kind.restoreTaskSnapshot, forKey: .type)
            try container.encode(snapshot, forKey: .snapshot)
        case .deleteTask(let taskID):
            try container.encode(Kind.deleteTask, forKey: .type)
            try container.encode(taskID, forKey: .taskID)
        case .updateTask(let taskID, let title, let dueDate):
            try container.encode(Kind.updateTask, forKey: .type)
            try container.encode(taskID, forKey: .taskID)
            try container.encodeIfPresent(title, forKey: .title)
            try container.encodeIfPresent(dueDate, forKey: .dueDate)
        case .setTaskCompletion(let taskID, let isComplete, let dateCompleted):
            try container.encode(Kind.setTaskCompletion, forKey: .type)
            try container.encode(taskID, forKey: .taskID)
            try container.encode(isComplete, forKey: .isComplete)
            try container.encodeIfPresent(dateCompleted, forKey: .dateCompleted)
        case .completeTask(let taskID):
            try container.encode(Kind.completeTask, forKey: .type)
            try container.encode(taskID, forKey: .taskID)
        case .moveTask(let taskID, let targetProjectID):
            try container.encode(Kind.moveTask, forKey: .type)
            try container.encode(taskID, forKey: .taskID)
            try container.encode(targetProjectID, forKey: .targetProjectID)
        }
    }
}

public struct AssistantActionRunDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var threadID: String?
    public var proposalData: Data?
    public var status: AssistantActionStatus
    public var confirmedAt: Date?
    public var appliedAt: Date?
    public var rejectedAt: Date?
    public var resultSummary: String?
    public var executionTraceData: Data?
    public var rollbackStatus: AssistantRollbackStatus?
    public var rollbackVerifiedAt: Date?
    public var lastErrorCode: String?
    public var createdAt: Date

    public init(
        id: UUID,
        threadID: String? = nil,
        proposalData: Data? = nil,
        status: AssistantActionStatus,
        confirmedAt: Date? = nil,
        appliedAt: Date? = nil,
        rejectedAt: Date? = nil,
        resultSummary: String? = nil,
        executionTraceData: Data? = nil,
        rollbackStatus: AssistantRollbackStatus? = nil,
        rollbackVerifiedAt: Date? = nil,
        lastErrorCode: String? = nil,
        createdAt: Date
    ) {
        self.id = id
        self.threadID = threadID
        self.proposalData = proposalData
        self.status = status
        self.confirmedAt = confirmedAt
        self.appliedAt = appliedAt
        self.rejectedAt = rejectedAt
        self.resultSummary = resultSummary
        self.executionTraceData = executionTraceData
        self.rollbackStatus = rollbackStatus
        self.rollbackVerifiedAt = rollbackVerifiedAt
        self.lastErrorCode = lastErrorCode
        self.createdAt = createdAt
    }
}
