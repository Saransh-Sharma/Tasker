//
//  Task.swift
//  Tasker
//
//  V2 domain model for TaskDefinition
//

import Foundation

public struct TaskDefinition: Codable, Equatable, Hashable {
    public let id: UUID
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
    public var estimatedDuration: TimeInterval?
    public var actualDuration: TimeInterval?
    public var subtasks: [UUID]
    public var repeatPattern: TaskRepeatPattern?
    public var createdAt: Date
    public var updatedAt: Date

    // Backward-compatible aliases kept for view/use-case ergonomics in V2-only runtime.
    public var name: String {
        get { title }
        set { title = newValue }
    }

    public var project: String? {
        get { projectName }
        set { projectName = newValue }
    }

    public var tags: [String] {
        get { tagIDs.map(\.uuidString) }
        set { tagIDs = newValue.compactMap(UUID.init(uuidString:)) }
    }

    public init(
        id: UUID = UUID(),
        projectID: UUID = ProjectConstants.inboxProjectID,
        projectName: String? = ProjectConstants.inboxProjectName,
        lifeAreaID: UUID? = nil,
        sectionID: UUID? = nil,
        parentTaskID: UUID? = nil,
        title: String,
        details: String? = nil,
        priority: TaskPriority = .low,
        type: TaskType = .morning,
        energy: TaskEnergy = .medium,
        category: TaskCategory = .general,
        context: TaskContext = .anywhere,
        dueDate: Date? = nil,
        isComplete: Bool = false,
        dateAdded: Date = Date(),
        dateCompleted: Date? = nil,
        isEveningTask: Bool = false,
        alertReminderTime: Date? = nil,
        tagIDs: [UUID] = [],
        dependencies: [TaskDependencyLinkDefinition] = [],
        estimatedDuration: TimeInterval? = nil,
        actualDuration: TimeInterval? = nil,
        subtasks: [UUID] = [],
        repeatPattern: TaskRepeatPattern? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.projectID = projectID
        self.projectName = projectName
        self.lifeAreaID = lifeAreaID
        self.sectionID = sectionID
        self.parentTaskID = parentTaskID
        self.title = title
        self.details = details
        self.priority = priority
        self.type = type
        self.energy = energy
        self.category = category
        self.context = context
        self.dueDate = dueDate
        self.isComplete = isComplete
        self.dateAdded = dateAdded
        self.dateCompleted = dateCompleted
        self.isEveningTask = isEveningTask
        self.alertReminderTime = alertReminderTime
        self.tagIDs = tagIDs
        self.dependencies = dependencies
        self.estimatedDuration = estimatedDuration
        self.actualDuration = actualDuration
        self.subtasks = subtasks
        self.repeatPattern = repeatPattern
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    @available(*, deprecated, message: "Use init(title:) instead.")
    public init(
        id: UUID = UUID(),
        projectID: UUID = ProjectConstants.inboxProjectID,
        projectName: String? = ProjectConstants.inboxProjectName,
        lifeAreaID: UUID? = nil,
        sectionID: UUID? = nil,
        parentTaskID: UUID? = nil,
        name: String,
        details: String? = nil,
        type: TaskType = .morning,
        priority: TaskPriority = .low,
        energy: TaskEnergy = .medium,
        category: TaskCategory = .general,
        context: TaskContext = .anywhere,
        dueDate: Date? = nil,
        isComplete: Bool = false,
        dateAdded: Date = Date(),
        dateCompleted: Date? = nil,
        isEveningTask: Bool = false,
        alertReminderTime: Date? = nil,
        tagIDs: [UUID] = [],
        dependencies: [TaskDependencyLinkDefinition] = [],
        estimatedDuration: TimeInterval? = nil,
        actualDuration: TimeInterval? = nil,
        subtasks: [UUID] = [],
        repeatPattern: TaskRepeatPattern? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.init(
            id: id,
            projectID: projectID,
            projectName: projectName,
            lifeAreaID: lifeAreaID,
            sectionID: sectionID,
            parentTaskID: parentTaskID,
            title: name,
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
            estimatedDuration: estimatedDuration,
            actualDuration: actualDuration,
            subtasks: subtasks,
            repeatPattern: repeatPattern,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    // MARK: - Business Logic

    public var score: Int {
        guard isComplete else { return 0 }
        return priority.scorePoints
    }

    public var isOverdue: Bool {
        guard let dueDate = dueDate, !isComplete else { return false }
        let startOfToday = Calendar.current.startOfDay(for: Date())
        return dueDate < startOfToday
    }

    public var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    public var isMorningTask: Bool {
        type == .morning
    }

    public var isUpcomingTask: Bool {
        type == .upcoming
    }

    public func canBeCompletedToday() -> Bool {
        guard !isBlocked() else { return false }

        if let dueDate = dueDate, !isComplete {
            let daysSinceOverdue = Calendar.current.dateComponents([.day], from: dueDate, to: Date()).day ?? 0
            if daysSinceOverdue > 7 {
                return false
            }
        }

        if let estimatedDuration = estimatedDuration {
            let now = Date()
            let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: now) ?? now
            let timeLeft = endOfDay.timeIntervalSince(now)
            return timeLeft >= estimatedDuration
        }

        return true
    }

    public func calculateEfficiencyScore() -> Double {
        guard let estimated = estimatedDuration,
              let actual = actualDuration,
              estimated > 0,
              actual > 0 else { return 1.0 }

        return estimated / actual
    }

    public func isBlocked() -> Bool {
        !dependencies.isEmpty
    }

    public var energyDescription: String {
        switch energy {
        case .low: return "Low energy required"
        case .medium: return "Medium energy required"
        case .high: return "High energy required"
        }
    }

    public func fitsContext(_ currentContext: TaskContext) -> Bool {
        context == .anywhere || context == currentContext
    }

    public var complexityScore: Int {
        var score = priority.scorePoints
        score += dependencies.count * 2
        score += subtasks.count

        if let duration = estimatedDuration {
            let hours = duration / 3600
            score += Int(hours)
        }

        return max(score, 1)
    }

    public func validate() throws {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw TaskValidationError.emptyName
        }

        if title.count > 200 {
            throw TaskValidationError.nameTooLong
        }

        if let details, details.count > 1000 {
            throw TaskValidationError.detailsTooLong
        }

        if let estimated = estimatedDuration, estimated <= 0 {
            throw TaskValidationError.invalidDuration
        }

        if let actual = actualDuration, actual <= 0 {
            throw TaskValidationError.invalidDuration
        }

        if tagIDs.count > 10 {
            throw TaskValidationError.tooManyTags
        }

        if dependencies.count > 20 {
            throw TaskValidationError.tooManyDependencies
        }

        if dependencies.contains(where: { $0.dependsOnTaskID == id }) {
            throw TaskValidationError.circularDependency
        }
    }
}

public enum TaskDependencyKind: String, Codable, CaseIterable {
    case blocks
    case related
}

public struct TaskDependencyLinkDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var taskID: UUID
    public var dependsOnTaskID: UUID
    public var kind: TaskDependencyKind
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        taskID: UUID,
        dependsOnTaskID: UUID,
        kind: TaskDependencyKind,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.dependsOnTaskID = dependsOnTaskID
        self.kind = kind
        self.createdAt = createdAt
    }
}

public struct TaskTagLinkDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var taskID: UUID
    public var tagID: UUID
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        taskID: UUID,
        tagID: UUID,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.taskID = taskID
        self.tagID = tagID
        self.createdAt = createdAt
    }
}

public struct CreateTaskDefinitionRequest: Codable, Equatable, Hashable {
    public let id: UUID
    public var title: String
    public var details: String?
    public var projectID: UUID
    public var projectName: String?
    public var lifeAreaID: UUID?
    public var sectionID: UUID?
    public var dueDate: Date?
    public var parentTaskID: UUID?
    public var tagIDs: [UUID]
    public var dependencies: [TaskDependencyLinkDefinition]
    public var priority: TaskPriority
    public var type: TaskType
    public var energy: TaskEnergy
    public var category: TaskCategory
    public var context: TaskContext
    public var isEveningTask: Bool
    public var alertReminderTime: Date?
    public var estimatedDuration: TimeInterval?
    public var repeatPattern: TaskRepeatPattern?
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        details: String? = nil,
        projectID: UUID,
        projectName: String? = nil,
        lifeAreaID: UUID? = nil,
        sectionID: UUID? = nil,
        dueDate: Date? = nil,
        parentTaskID: UUID? = nil,
        tagIDs: [UUID] = [],
        dependencies: [TaskDependencyLinkDefinition] = [],
        priority: TaskPriority = .low,
        type: TaskType = .morning,
        energy: TaskEnergy = .medium,
        category: TaskCategory = .general,
        context: TaskContext = .anywhere,
        isEveningTask: Bool = false,
        alertReminderTime: Date? = nil,
        estimatedDuration: TimeInterval? = nil,
        repeatPattern: TaskRepeatPattern? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.projectID = projectID
        self.projectName = projectName
        self.lifeAreaID = lifeAreaID
        self.sectionID = sectionID
        self.dueDate = dueDate
        self.parentTaskID = parentTaskID
        self.tagIDs = tagIDs
        self.dependencies = dependencies
        self.priority = priority
        self.type = type
        self.energy = energy
        self.category = category
        self.context = context
        self.isEveningTask = isEveningTask
        self.alertReminderTime = alertReminderTime
        self.estimatedDuration = estimatedDuration
        self.repeatPattern = repeatPattern
        self.createdAt = createdAt
    }

    public func toTaskDefinition(projectName: String?) -> TaskDefinition {
        TaskDefinition(
            id: id,
            projectID: projectID,
            projectName: projectName ?? self.projectName ?? ProjectConstants.inboxProjectName,
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
            isComplete: false,
            dateAdded: createdAt,
            dateCompleted: nil,
            isEveningTask: isEveningTask,
            alertReminderTime: alertReminderTime,
            tagIDs: tagIDs,
            dependencies: dependencies,
            estimatedDuration: estimatedDuration,
            actualDuration: nil,
            subtasks: [],
            repeatPattern: repeatPattern,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

public struct UpdateTaskDefinitionRequest: Codable, Equatable, Hashable {
    public let id: UUID
    public var title: String?
    public var details: String?
    public var projectID: UUID?
    public var lifeAreaID: UUID?
    public var sectionID: UUID?
    public var dueDate: Date?
    public var parentTaskID: UUID?
    public var clearParentTaskLink: Bool
    public var tagIDs: [UUID]?
    public var dependencies: [TaskDependencyLinkDefinition]?
    public var priority: TaskPriority?
    public var type: TaskType?
    public var energy: TaskEnergy?
    public var category: TaskCategory?
    public var context: TaskContext?
    public var isComplete: Bool?
    public var dateCompleted: Date?
    public var alertReminderTime: Date?
    public var estimatedDuration: TimeInterval?
    public var actualDuration: TimeInterval?
    public var repeatPattern: TaskRepeatPattern?
    public var updatedAt: Date

    public init(
        id: UUID,
        title: String? = nil,
        details: String? = nil,
        projectID: UUID? = nil,
        lifeAreaID: UUID? = nil,
        sectionID: UUID? = nil,
        dueDate: Date? = nil,
        parentTaskID: UUID? = nil,
        clearParentTaskLink: Bool = false,
        tagIDs: [UUID]? = nil,
        dependencies: [TaskDependencyLinkDefinition]? = nil,
        priority: TaskPriority? = nil,
        type: TaskType? = nil,
        energy: TaskEnergy? = nil,
        category: TaskCategory? = nil,
        context: TaskContext? = nil,
        isComplete: Bool? = nil,
        dateCompleted: Date? = nil,
        alertReminderTime: Date? = nil,
        estimatedDuration: TimeInterval? = nil,
        actualDuration: TimeInterval? = nil,
        repeatPattern: TaskRepeatPattern? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.details = details
        self.projectID = projectID
        self.lifeAreaID = lifeAreaID
        self.sectionID = sectionID
        self.dueDate = dueDate
        self.parentTaskID = parentTaskID
        self.clearParentTaskLink = clearParentTaskLink
        self.tagIDs = tagIDs
        self.dependencies = dependencies
        self.priority = priority
        self.type = type
        self.energy = energy
        self.category = category
        self.context = context
        self.isComplete = isComplete
        self.dateCompleted = dateCompleted
        self.alertReminderTime = alertReminderTime
        self.estimatedDuration = estimatedDuration
        self.actualDuration = actualDuration
        self.repeatPattern = repeatPattern
        self.updatedAt = updatedAt
    }
}

public struct TaskDefinitionQuery: Codable, Equatable, Hashable {
    public var projectID: UUID?
    public var sectionID: UUID?
    public var parentTaskID: UUID?
    public var includeCompleted: Bool
    public var dueDateStart: Date?
    public var dueDateEnd: Date?
    public var updatedAfter: Date?
    public var searchText: String?
    public var limit: Int?
    public var offset: Int?

    public init(
        projectID: UUID? = nil,
        sectionID: UUID? = nil,
        parentTaskID: UUID? = nil,
        includeCompleted: Bool = true,
        dueDateStart: Date? = nil,
        dueDateEnd: Date? = nil,
        updatedAfter: Date? = nil,
        searchText: String? = nil,
        limit: Int? = nil,
        offset: Int? = nil
    ) {
        self.projectID = projectID
        self.sectionID = sectionID
        self.parentTaskID = parentTaskID
        self.includeCompleted = includeCompleted
        self.dueDateStart = dueDateStart
        self.dueDateEnd = dueDateEnd
        self.updatedAfter = updatedAfter
        self.searchText = searchText
        self.limit = limit
        self.offset = offset
    }
}

// MARK: - Validation Errors

public enum TaskValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case detailsTooLong
    case invalidDuration
    case tooManyTags
    case tooManyDependencies
    case circularDependency

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Task name cannot be empty"
        case .nameTooLong:
            return "Task name cannot exceed 200 characters"
        case .detailsTooLong:
            return "Task details cannot exceed 1000 characters"
        case .invalidDuration:
            return "Duration must be greater than 0"
        case .tooManyTags:
            return "Cannot have more than 10 tags"
        case .tooManyDependencies:
            return "Cannot have more than 20 dependencies"
        case .circularDependency:
            return "Task cannot depend on itself"
        }
    }
}
