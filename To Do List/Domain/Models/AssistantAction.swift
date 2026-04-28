import Foundation

public enum AssistantActionStatus: String, Codable {
    case pending
    case confirmed
    case applied
    case undone
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

    /// Initializes a new instance.
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
    public var recurrenceSeriesID: UUID?
    public var habitDefinitionID: UUID?
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
    public var scheduledStartAt: Date?
    public var scheduledEndAt: Date?
    public var isAllDay: Bool?
    public var isComplete: Bool
    public var dateAdded: Date
    public var dateCompleted: Date?
    public var isEveningTask: Bool
    public var alertReminderTime: Date?
    public var tagIDs: [UUID]
    public var dependencies: [TaskDependencyLinkDefinition]
    public var estimatedDuration: TimeInterval?
    public var actualDuration: TimeInterval?
    public var subtasks: [UUID]?
    public var repeatPattern: TaskRepeatPattern?
    public var planningBucket: TaskPlanningBucket
    public var weeklyOutcomeID: UUID?
    public var deferredFromWeekStart: Date?
    public var deferredCount: Int
    public var replanCount: Int
    public var createdAt: Date
    public var updatedAt: Date

    private enum CodingKeys: String, CodingKey {
        case id
        case recurrenceSeriesID
        case habitDefinitionID
        case projectID
        case projectName
        case lifeAreaID
        case sectionID
        case parentTaskID
        case title
        case details
        case priority
        case type
        case energy
        case category
        case context
        case dueDate
        case scheduledStartAt
        case scheduledEndAt
        case isAllDay
        case isComplete
        case dateAdded
        case dateCompleted
        case isEveningTask
        case alertReminderTime
        case tagIDs
        case dependencies
        case estimatedDuration
        case actualDuration
        case subtasks
        case repeatPattern
        case planningBucket
        case weeklyOutcomeID
        case deferredFromWeekStart
        case deferredCount
        case replanCount
        case createdAt
        case updatedAt
    }

    /// Initializes a new instance.
    public init(task: TaskDefinition) {
        self.id = task.id
        self.recurrenceSeriesID = task.recurrenceSeriesID
        self.habitDefinitionID = task.habitDefinitionID
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
        self.scheduledStartAt = task.scheduledStartAt
        self.scheduledEndAt = task.scheduledEndAt
        self.isAllDay = task.isAllDay
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
        self.estimatedDuration = task.estimatedDuration
        self.actualDuration = task.actualDuration
        self.subtasks = task.subtasks.sorted { $0.uuidString < $1.uuidString }
        self.repeatPattern = task.repeatPattern
        self.planningBucket = task.planningBucket
        self.weeklyOutcomeID = task.weeklyOutcomeID
        self.deferredFromWeekStart = task.deferredFromWeekStart
        self.deferredCount = task.deferredCount
        self.replanCount = task.replanCount
        self.createdAt = task.createdAt
        self.updatedAt = task.updatedAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        recurrenceSeriesID = try container.decodeIfPresent(UUID.self, forKey: .recurrenceSeriesID)
        habitDefinitionID = try container.decodeIfPresent(UUID.self, forKey: .habitDefinitionID)
        projectID = try container.decode(UUID.self, forKey: .projectID)
        projectName = try container.decodeIfPresent(String.self, forKey: .projectName)
        lifeAreaID = try container.decodeIfPresent(UUID.self, forKey: .lifeAreaID)
        sectionID = try container.decodeIfPresent(UUID.self, forKey: .sectionID)
        parentTaskID = try container.decodeIfPresent(UUID.self, forKey: .parentTaskID)
        title = try container.decode(String.self, forKey: .title)
        details = try container.decodeIfPresent(String.self, forKey: .details)
        priority = try container.decode(TaskPriority.self, forKey: .priority)
        type = try container.decode(TaskType.self, forKey: .type)
        energy = try container.decode(TaskEnergy.self, forKey: .energy)
        category = try container.decode(TaskCategory.self, forKey: .category)
        context = try container.decode(TaskContext.self, forKey: .context)
        dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        scheduledStartAt = try container.decodeIfPresent(Date.self, forKey: .scheduledStartAt)
        scheduledEndAt = try container.decodeIfPresent(Date.self, forKey: .scheduledEndAt)
        isAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay)
        isComplete = try container.decode(Bool.self, forKey: .isComplete)
        dateAdded = try container.decode(Date.self, forKey: .dateAdded)
        dateCompleted = try container.decodeIfPresent(Date.self, forKey: .dateCompleted)
        isEveningTask = try container.decode(Bool.self, forKey: .isEveningTask)
        alertReminderTime = try container.decodeIfPresent(Date.self, forKey: .alertReminderTime)
        tagIDs = try container.decode([UUID].self, forKey: .tagIDs)
        dependencies = try container.decode([TaskDependencyLinkDefinition].self, forKey: .dependencies)
        estimatedDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .estimatedDuration)
        actualDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .actualDuration)
        subtasks = try container.decodeIfPresent([UUID].self, forKey: .subtasks)
        repeatPattern = try container.decodeIfPresent(TaskRepeatPattern.self, forKey: .repeatPattern)
        planningBucket = try container.decode(TaskPlanningBucket.self, forKey: .planningBucket)
        weeklyOutcomeID = try container.decodeIfPresent(UUID.self, forKey: .weeklyOutcomeID)
        deferredFromWeekStart = try container.decodeIfPresent(Date.self, forKey: .deferredFromWeekStart)
        deferredCount = try container.decode(Int.self, forKey: .deferredCount)
        replanCount = try container.decodeIfPresent(Int.self, forKey: .replanCount) ?? 0
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }

    /// Executes toTaskDefinition.
    public func toTaskDefinition() -> TaskDefinition {
        TaskDefinition(
            id: id,
            recurrenceSeriesID: recurrenceSeriesID,
            habitDefinitionID: habitDefinitionID,
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
            scheduledStartAt: scheduledStartAt,
            scheduledEndAt: scheduledEndAt,
            isAllDay: isAllDay ?? false,
            isComplete: isComplete,
            dateAdded: dateAdded,
            dateCompleted: dateCompleted,
            isEveningTask: isEveningTask,
            alertReminderTime: alertReminderTime,
            tagIDs: tagIDs,
            dependencies: dependencies,
            estimatedDuration: estimatedDuration,
            actualDuration: actualDuration,
            subtasks: subtasks ?? [],
            repeatPattern: repeatPattern,
            planningBucket: planningBucket,
            weeklyOutcomeID: weeklyOutcomeID,
            deferredFromWeekStart: deferredFromWeekStart,
            deferredCount: deferredCount,
            replanCount: replanCount,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

public enum AssistantDeferralReason: String, Codable, Equatable, Hashable {
    case userRequested
    case runningLate
    case overload
    case conflict
    case needsReview
}

public enum AssistantDropDestination: String, Codable, Equatable, Hashable {
    case inbox
    case later
    case someday

    var displayLabel: String {
        switch self {
        case .inbox: "Inbox"
        case .later: "Later"
        case .someday: "Someday"
        }
    }
}

public enum AssistantFieldUpdate<Value: Codable & Hashable>: Codable, Equatable, Hashable {
    case absent
    case set(Value)
    case clear

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .clear
        } else {
            self = .set(try container.decode(Value.self))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .absent, .clear:
            try container.encodeNil()
        case .set(let value):
            try container.encode(value)
        }
    }

    var setValue: Value? {
        if case .set(let value) = self { return value }
        return nil
    }
}

private extension KeyedDecodingContainer {
    func decodeFieldUpdate<Value: Codable & Hashable>(
        _ type: Value.Type,
        forKey key: Key
    ) throws -> AssistantFieldUpdate<Value> {
        guard contains(key) else { return .absent }
        if try decodeNil(forKey: key) {
            return .clear
        }
        return .set(try decode(type, forKey: key))
    }
}

private extension KeyedEncodingContainer {
    mutating func encodeFieldUpdate<Value: Codable & Hashable>(
        _ update: AssistantFieldUpdate<Value>,
        forKey key: Key
    ) throws {
        switch update {
        case .absent:
            return
        case .clear:
            try encodeNil(forKey: key)
        case .set(let value):
            try encode(value, forKey: key)
        }
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
    case createScheduledTask(
        projectID: UUID,
        title: String,
        scheduledStartAt: Date,
        scheduledEndAt: Date,
        estimatedDuration: TimeInterval?,
        lifeAreaID: UUID?,
        priority: TaskPriority?,
        energy: TaskEnergy?,
        category: TaskCategory?,
        context: TaskContext?,
        details: String?,
        tagIDs: [UUID]
    )
    case createInboxTask(
        projectID: UUID,
        title: String,
        estimatedDuration: TimeInterval?,
        lifeAreaID: UUID?,
        priority: TaskPriority?,
        category: TaskCategory?,
        details: String?,
        tagIDs: [UUID]
    )
    case updateTaskSchedule(
        taskID: UUID,
        scheduledStartAt: Date?,
        scheduledEndAt: Date?,
        estimatedDuration: TimeInterval?,
        dueDate: Date?
    )
    case updateTaskFields(
        taskID: UUID,
        title: AssistantFieldUpdate<String>,
        details: AssistantFieldUpdate<String>,
        priority: AssistantFieldUpdate<TaskPriority>,
        energy: AssistantFieldUpdate<TaskEnergy>,
        category: AssistantFieldUpdate<TaskCategory>,
        context: AssistantFieldUpdate<TaskContext>,
        lifeAreaID: AssistantFieldUpdate<UUID>,
        tagIDs: AssistantFieldUpdate<[UUID]>
    )
    case deferTask(
        taskID: UUID,
        targetDate: Date,
        reason: AssistantDeferralReason
    )
    case dropTaskFromToday(
        taskID: UUID,
        destination: AssistantDropDestination,
        reason: String
    )

    private enum CodingKeys: String, CodingKey {
        case type
        case taskID
        case projectID
        case targetProjectID
        case title
        case details
        case dueDate
        case scheduledStartAt
        case scheduledEndAt
        case estimatedDuration
        case lifeAreaID
        case priority
        case energy
        case category
        case context
        case tagIDs
        case targetDate
        case reason
        case destination
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
        case createScheduledTask
        case createInboxTask
        case updateTaskSchedule
        case updateTaskFields
        case deferTask
        case dropTaskFromToday
    }

    /// Initializes a new instance.
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
        case .createScheduledTask:
            self = .createScheduledTask(
                projectID: try container.decode(UUID.self, forKey: .projectID),
                title: try container.decode(String.self, forKey: .title),
                scheduledStartAt: try container.decode(Date.self, forKey: .scheduledStartAt),
                scheduledEndAt: try container.decode(Date.self, forKey: .scheduledEndAt),
                estimatedDuration: try container.decodeIfPresent(TimeInterval.self, forKey: .estimatedDuration),
                lifeAreaID: try container.decodeIfPresent(UUID.self, forKey: .lifeAreaID),
                priority: try container.decodeIfPresent(TaskPriority.self, forKey: .priority),
                energy: try container.decodeIfPresent(TaskEnergy.self, forKey: .energy),
                category: try container.decodeIfPresent(TaskCategory.self, forKey: .category),
                context: try container.decodeIfPresent(TaskContext.self, forKey: .context),
                details: try container.decodeIfPresent(String.self, forKey: .details),
                tagIDs: try container.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
            )
        case .createInboxTask:
            self = .createInboxTask(
                projectID: try container.decode(UUID.self, forKey: .projectID),
                title: try container.decode(String.self, forKey: .title),
                estimatedDuration: try container.decodeIfPresent(TimeInterval.self, forKey: .estimatedDuration),
                lifeAreaID: try container.decodeIfPresent(UUID.self, forKey: .lifeAreaID),
                priority: try container.decodeIfPresent(TaskPriority.self, forKey: .priority),
                category: try container.decodeIfPresent(TaskCategory.self, forKey: .category),
                details: try container.decodeIfPresent(String.self, forKey: .details),
                tagIDs: try container.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
            )
        case .updateTaskSchedule:
            self = .updateTaskSchedule(
                taskID: try container.decode(UUID.self, forKey: .taskID),
                scheduledStartAt: try container.decodeIfPresent(Date.self, forKey: .scheduledStartAt),
                scheduledEndAt: try container.decodeIfPresent(Date.self, forKey: .scheduledEndAt),
                estimatedDuration: try container.decodeIfPresent(TimeInterval.self, forKey: .estimatedDuration),
                dueDate: try container.decodeIfPresent(Date.self, forKey: .dueDate)
            )
        case .updateTaskFields:
            self = .updateTaskFields(
                taskID: try container.decode(UUID.self, forKey: .taskID),
                title: try container.decodeFieldUpdate(String.self, forKey: .title),
                details: try container.decodeFieldUpdate(String.self, forKey: .details),
                priority: try container.decodeFieldUpdate(TaskPriority.self, forKey: .priority),
                energy: try container.decodeFieldUpdate(TaskEnergy.self, forKey: .energy),
                category: try container.decodeFieldUpdate(TaskCategory.self, forKey: .category),
                context: try container.decodeFieldUpdate(TaskContext.self, forKey: .context),
                lifeAreaID: try container.decodeFieldUpdate(UUID.self, forKey: .lifeAreaID),
                tagIDs: try container.decodeFieldUpdate([UUID].self, forKey: .tagIDs)
            )
        case .deferTask:
            self = .deferTask(
                taskID: try container.decode(UUID.self, forKey: .taskID),
                targetDate: try container.decode(Date.self, forKey: .targetDate),
                reason: try container.decodeIfPresent(AssistantDeferralReason.self, forKey: .reason) ?? .userRequested
            )
        case .dropTaskFromToday:
            self = .dropTaskFromToday(
                taskID: try container.decode(UUID.self, forKey: .taskID),
                destination: try container.decode(AssistantDropDestination.self, forKey: .destination),
                reason: try container.decodeIfPresent(String.self, forKey: .reason) ?? ""
            )
        }
    }

    /// Executes encode.
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
        case .createScheduledTask(
            let projectID,
            let title,
            let scheduledStartAt,
            let scheduledEndAt,
            let estimatedDuration,
            let lifeAreaID,
            let priority,
            let energy,
            let category,
            let context,
            let details,
            let tagIDs
        ):
            try container.encode(Kind.createScheduledTask, forKey: .type)
            try container.encode(projectID, forKey: .projectID)
            try container.encode(title, forKey: .title)
            try container.encode(scheduledStartAt, forKey: .scheduledStartAt)
            try container.encode(scheduledEndAt, forKey: .scheduledEndAt)
            try container.encodeIfPresent(estimatedDuration, forKey: .estimatedDuration)
            try container.encodeIfPresent(lifeAreaID, forKey: .lifeAreaID)
            try container.encodeIfPresent(priority, forKey: .priority)
            try container.encodeIfPresent(energy, forKey: .energy)
            try container.encodeIfPresent(category, forKey: .category)
            try container.encodeIfPresent(context, forKey: .context)
            try container.encodeIfPresent(details, forKey: .details)
            try container.encode(tagIDs, forKey: .tagIDs)
        case .createInboxTask(
            let projectID,
            let title,
            let estimatedDuration,
            let lifeAreaID,
            let priority,
            let category,
            let details,
            let tagIDs
        ):
            try container.encode(Kind.createInboxTask, forKey: .type)
            try container.encode(projectID, forKey: .projectID)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(estimatedDuration, forKey: .estimatedDuration)
            try container.encodeIfPresent(lifeAreaID, forKey: .lifeAreaID)
            try container.encodeIfPresent(priority, forKey: .priority)
            try container.encodeIfPresent(category, forKey: .category)
            try container.encodeIfPresent(details, forKey: .details)
            try container.encode(tagIDs, forKey: .tagIDs)
        case .updateTaskSchedule(let taskID, let scheduledStartAt, let scheduledEndAt, let estimatedDuration, let dueDate):
            try container.encode(Kind.updateTaskSchedule, forKey: .type)
            try container.encode(taskID, forKey: .taskID)
            try container.encodeIfPresent(scheduledStartAt, forKey: .scheduledStartAt)
            try container.encodeIfPresent(scheduledEndAt, forKey: .scheduledEndAt)
            try container.encodeIfPresent(estimatedDuration, forKey: .estimatedDuration)
            try container.encodeIfPresent(dueDate, forKey: .dueDate)
        case .updateTaskFields(
            let taskID,
            let title,
            let details,
            let priority,
            let energy,
            let category,
            let context,
            let lifeAreaID,
            let tagIDs
        ):
            try container.encode(Kind.updateTaskFields, forKey: .type)
            try container.encode(taskID, forKey: .taskID)
            try container.encodeFieldUpdate(title, forKey: .title)
            try container.encodeFieldUpdate(details, forKey: .details)
            try container.encodeFieldUpdate(priority, forKey: .priority)
            try container.encodeFieldUpdate(energy, forKey: .energy)
            try container.encodeFieldUpdate(category, forKey: .category)
            try container.encodeFieldUpdate(context, forKey: .context)
            try container.encodeFieldUpdate(lifeAreaID, forKey: .lifeAreaID)
            try container.encodeFieldUpdate(tagIDs, forKey: .tagIDs)
        case .deferTask(let taskID, let targetDate, let reason):
            try container.encode(Kind.deferTask, forKey: .type)
            try container.encode(taskID, forKey: .taskID)
            try container.encode(targetDate, forKey: .targetDate)
            try container.encode(reason, forKey: .reason)
        case .dropTaskFromToday(let taskID, let destination, let reason):
            try container.encode(Kind.dropTaskFromToday, forKey: .type)
            try container.encode(taskID, forKey: .taskID)
            try container.encode(destination, forKey: .destination)
            try container.encode(reason, forKey: .reason)
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

    /// Initializes a new instance.
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
