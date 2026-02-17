import Foundation

public enum AssistantActionStatus: String, Codable {
    case pending
    case confirmed
    case applied
    case rejected
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

public enum AssistantCommand: Codable, Equatable, Hashable {
    case createTask(projectID: UUID, title: String)
    case restoreTask(taskID: UUID, projectID: UUID, title: String, dueDate: Date?, isComplete: Bool, dateCompleted: Date?)
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
    }

    private enum Kind: String, Codable {
        case createTask
        case restoreTask
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
    public var createdAt: Date
}
