//
//  Task.swift
//  Tasker
//
//  V2 domain model for TaskDefinition
//

import Foundation

public struct TaskDefinition: Codable, Equatable, Hashable {
    public let id: UUID
    public var recurrenceSeriesID: UUID?
    public var habitDefinitionID: UUID?
    public var projectID: UUID
    public var projectName: String?
    public var iconSymbolName: String?
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
    public var isAllDay: Bool
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
    public var planningBucket: TaskPlanningBucket
    public var weeklyOutcomeID: UUID?
    public var deferredFromWeekStart: Date?
    public var deferredCount: Int
    public var replanCount: Int
    public var createdAt: Date
    public var updatedAt: Date

    /// Initializes a new instance.
    public init(
        id: UUID = UUID(),
        recurrenceSeriesID: UUID? = nil,
        habitDefinitionID: UUID? = nil,
        projectID: UUID = ProjectConstants.inboxProjectID,
        projectName: String? = ProjectConstants.inboxProjectName,
        iconSymbolName: String? = nil,
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
        scheduledStartAt: Date? = nil,
        scheduledEndAt: Date? = nil,
        isAllDay: Bool = false,
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
        planningBucket: TaskPlanningBucket = .thisWeek,
        weeklyOutcomeID: UUID? = nil,
        deferredFromWeekStart: Date? = nil,
        deferredCount: Int = 0,
        replanCount: Int = 0,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.recurrenceSeriesID = recurrenceSeriesID
        self.habitDefinitionID = habitDefinitionID
        self.projectID = projectID
        self.projectName = projectName
        self.iconSymbolName = iconSymbolName
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
        self.scheduledStartAt = scheduledStartAt
        self.scheduledEndAt = scheduledEndAt
        self.isAllDay = isAllDay
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
        self.planningBucket = planningBucket
        self.weeklyOutcomeID = weeklyOutcomeID
        self.deferredFromWeekStart = deferredFromWeekStart
        self.deferredCount = deferredCount
        self.replanCount = replanCount
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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

    /// Executes canBeCompletedToday.
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

    /// Executes calculateEfficiencyScore.
    public func calculateEfficiencyScore() -> Double {
        guard let estimated = estimatedDuration,
              let actual = actualDuration,
              estimated > 0,
              actual > 0 else { return 1.0 }

        return estimated / actual
    }

    /// Executes isBlocked.
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

    /// Executes fitsContext.
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

    /// Executes validate.
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

struct TaskScheduleNormalizationResult: Equatable {
    let dueDate: Date?
    let scheduledStartAt: Date?
    let scheduledEndAt: Date?
    let isAllDay: Bool
    let explicitAllDayIntent: Bool?
    let clearScheduledStartAt: Bool
    let clearScheduledEndAt: Bool
}

enum TaskScheduleNormalizer {
    private static let defaultDuration: TimeInterval = 30 * 60

    static func normalize(
        deadlineDate: Date?,
        existingScheduledStartAt: Date?,
        existingScheduledEndAt: Date?,
        estimatedDuration: TimeInterval?,
        preserveExistingDuration: Bool,
        allDayIntent: Bool? = nil,
        calendar: Calendar = .current
    ) -> TaskScheduleNormalizationResult {
        guard let deadlineDate else {
            return TaskScheduleNormalizationResult(
                dueDate: nil,
                scheduledStartAt: nil,
                scheduledEndAt: nil,
                isAllDay: false,
                explicitAllDayIntent: allDayIntent,
                clearScheduledStartAt: true,
                clearScheduledEndAt: true
            )
        }

        if allDayIntent == true {
            return TaskScheduleNormalizationResult(
                dueDate: calendar.startOfDay(for: deadlineDate),
                scheduledStartAt: nil,
                scheduledEndAt: nil,
                isAllDay: true,
                explicitAllDayIntent: true,
                clearScheduledStartAt: true,
                clearScheduledEndAt: true
            )
        }

        let resolvedDuration: TimeInterval
        if preserveExistingDuration,
           let existingScheduledStartAt,
           let existingScheduledEndAt,
           existingScheduledEndAt > existingScheduledStartAt {
            resolvedDuration = existingScheduledEndAt.timeIntervalSince(existingScheduledStartAt)
        } else if let estimatedDuration, estimatedDuration > 0 {
            resolvedDuration = estimatedDuration
        } else {
            resolvedDuration = defaultDuration
        }

        return TaskScheduleNormalizationResult(
            dueDate: deadlineDate,
            scheduledStartAt: deadlineDate,
            scheduledEndAt: deadlineDate.addingTimeInterval(resolvedDuration),
            isAllDay: false,
            explicitAllDayIntent: allDayIntent,
            clearScheduledStartAt: false,
            clearScheduledEndAt: false
        )
    }

    static func isDateOnly(_ date: Date, calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        return (components.hour ?? 0) == 0
            && (components.minute ?? 0) == 0
            && (components.second ?? 0) == 0
    }
}

extension TaskDefinition {
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.recurrenceSeriesID = try container.decodeIfPresent(UUID.self, forKey: .recurrenceSeriesID)
        self.habitDefinitionID = try container.decodeIfPresent(UUID.self, forKey: .habitDefinitionID)
        self.projectID = try container.decodeIfPresent(UUID.self, forKey: .projectID) ?? ProjectConstants.inboxProjectID
        self.projectName = try container.decodeIfPresent(String.self, forKey: .projectName)
        self.lifeAreaID = try container.decodeIfPresent(UUID.self, forKey: .lifeAreaID)
        self.sectionID = try container.decodeIfPresent(UUID.self, forKey: .sectionID)
        self.parentTaskID = try container.decodeIfPresent(UUID.self, forKey: .parentTaskID)
        self.title = try container.decode(String.self, forKey: .title)
        self.details = try container.decodeIfPresent(String.self, forKey: .details)
        self.priority = try container.decodeIfPresent(TaskPriority.self, forKey: .priority) ?? .low
        self.type = try container.decodeIfPresent(TaskType.self, forKey: .type) ?? .morning
        self.energy = try container.decodeIfPresent(TaskEnergy.self, forKey: .energy) ?? .medium
        self.category = try container.decodeIfPresent(TaskCategory.self, forKey: .category) ?? .general
        self.context = try container.decodeIfPresent(TaskContext.self, forKey: .context) ?? .anywhere
        self.dueDate = try container.decodeIfPresent(Date.self, forKey: .dueDate)
        self.scheduledStartAt = try container.decodeIfPresent(Date.self, forKey: .scheduledStartAt)
        self.scheduledEndAt = try container.decodeIfPresent(Date.self, forKey: .scheduledEndAt)
        self.isAllDay = try container.decodeIfPresent(Bool.self, forKey: .isAllDay) ?? false
        self.isComplete = try container.decodeIfPresent(Bool.self, forKey: .isComplete) ?? false
        self.dateAdded = try container.decodeIfPresent(Date.self, forKey: .dateAdded) ?? Date()
        self.dateCompleted = try container.decodeIfPresent(Date.self, forKey: .dateCompleted)
        self.isEveningTask = try container.decodeIfPresent(Bool.self, forKey: .isEveningTask) ?? false
        self.alertReminderTime = try container.decodeIfPresent(Date.self, forKey: .alertReminderTime)
        self.tagIDs = try container.decodeIfPresent([UUID].self, forKey: .tagIDs) ?? []
        self.dependencies = try container.decodeIfPresent([TaskDependencyLinkDefinition].self, forKey: .dependencies) ?? []
        self.estimatedDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .estimatedDuration)
        self.actualDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .actualDuration)
        self.subtasks = try container.decodeIfPresent([UUID].self, forKey: .subtasks) ?? []
        self.repeatPattern = try container.decodeIfPresent(TaskRepeatPattern.self, forKey: .repeatPattern)
        self.planningBucket = try container.decodeIfPresent(TaskPlanningBucket.self, forKey: .planningBucket) ?? .thisWeek
        self.weeklyOutcomeID = try container.decodeIfPresent(UUID.self, forKey: .weeklyOutcomeID)
        self.deferredFromWeekStart = try container.decodeIfPresent(Date.self, forKey: .deferredFromWeekStart)
        self.deferredCount = try container.decodeIfPresent(Int.self, forKey: .deferredCount) ?? 0
        self.replanCount = try container.decodeIfPresent(Int.self, forKey: .replanCount) ?? 0
        self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? self.dateAdded
        self.updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? self.createdAt
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

    /// Initializes a new instance.
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

    /// Initializes a new instance.
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
    public var recurrenceSeriesID: UUID?
    public var habitDefinitionID: UUID?
    public var title: String
    public var details: String?
    public var projectID: UUID
    public var projectName: String?
    public var iconSymbolName: String?
    public var lifeAreaID: UUID?
    public var sectionID: UUID?
    public var dueDate: Date?
    public var scheduledStartAt: Date?
    public var scheduledEndAt: Date?
    public var isAllDay: Bool
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
    public var planningBucket: TaskPlanningBucket
    public var weeklyOutcomeID: UUID?
    public var deferredFromWeekStart: Date?
    public var deferredCount: Int
    public var replanCount: Int
    public var createdAt: Date

    /// Initializes a new instance.
    public init(
        id: UUID = UUID(),
        recurrenceSeriesID: UUID? = nil,
        habitDefinitionID: UUID? = nil,
        title: String,
        details: String? = nil,
        projectID: UUID,
        projectName: String? = nil,
        iconSymbolName: String? = nil,
        lifeAreaID: UUID? = nil,
        sectionID: UUID? = nil,
        dueDate: Date? = nil,
        scheduledStartAt: Date? = nil,
        scheduledEndAt: Date? = nil,
        isAllDay: Bool = false,
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
        planningBucket: TaskPlanningBucket = .thisWeek,
        weeklyOutcomeID: UUID? = nil,
        deferredFromWeekStart: Date? = nil,
        deferredCount: Int = 0,
        replanCount: Int = 0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.recurrenceSeriesID = recurrenceSeriesID
        self.habitDefinitionID = habitDefinitionID
        self.title = title
        self.details = details
        self.projectID = projectID
        self.projectName = projectName
        self.iconSymbolName = iconSymbolName
        self.lifeAreaID = lifeAreaID
        self.sectionID = sectionID
        self.dueDate = dueDate
        self.scheduledStartAt = scheduledStartAt
        self.scheduledEndAt = scheduledEndAt
        self.isAllDay = isAllDay
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
        self.planningBucket = planningBucket
        self.weeklyOutcomeID = weeklyOutcomeID
        self.deferredFromWeekStart = deferredFromWeekStart
        self.deferredCount = deferredCount
        self.replanCount = replanCount
        self.createdAt = createdAt
    }

    /// Executes toTaskDefinition.
    public func toTaskDefinition(projectName: String?) -> TaskDefinition {
        TaskDefinition(
            id: id,
            recurrenceSeriesID: recurrenceSeriesID,
            habitDefinitionID: habitDefinitionID,
            projectID: projectID,
            projectName: projectName ?? self.projectName ?? ProjectConstants.inboxProjectName,
            iconSymbolName: iconSymbolName,
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
            isAllDay: isAllDay,
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
            planningBucket: planningBucket,
            weeklyOutcomeID: weeklyOutcomeID,
            deferredFromWeekStart: deferredFromWeekStart,
            deferredCount: deferredCount,
            replanCount: replanCount,
            createdAt: createdAt,
            updatedAt: createdAt
        )
    }
}

public struct UpdateTaskDefinitionRequest: Codable, Equatable, Hashable {
    public let id: UUID
    public var recurrenceSeriesID: UUID?
    public var habitDefinitionID: UUID?
    public var title: String?
    public var details: String?
    public var projectID: UUID?
    public var iconSymbolName: String?
    public var clearIconSymbolName: Bool
    public var lifeAreaID: UUID?
    public var clearLifeArea: Bool
    public var sectionID: UUID?
    public var clearSection: Bool
    public var dueDate: Date?
    public var clearDueDate: Bool
    public var scheduledStartAt: Date?
    public var clearScheduledStartAt: Bool
    public var scheduledEndAt: Date?
    public var clearScheduledEndAt: Bool
    public var isAllDay: Bool?
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
    public var clearReminderTime: Bool
    public var estimatedDuration: TimeInterval?
    public var clearEstimatedDuration: Bool
    public var actualDuration: TimeInterval?
    public var repeatPattern: TaskRepeatPattern?
    public var clearRepeatPattern: Bool
    public var planningBucket: TaskPlanningBucket?
    public var weeklyOutcomeID: UUID?
    public var clearWeeklyOutcomeLink: Bool
    public var deferredFromWeekStart: Date?
    public var clearDeferredFromWeekStart: Bool
    public var deferredCount: Int?
    public var replanCount: Int?
    public var updatedAt: Date

    /// Initializes a new instance.
    public init(
        id: UUID,
        recurrenceSeriesID: UUID? = nil,
        habitDefinitionID: UUID? = nil,
        title: String? = nil,
        details: String? = nil,
        projectID: UUID? = nil,
        iconSymbolName: String? = nil,
        clearIconSymbolName: Bool = false,
        lifeAreaID: UUID? = nil,
        clearLifeArea: Bool = false,
        sectionID: UUID? = nil,
        clearSection: Bool = false,
        dueDate: Date? = nil,
        clearDueDate: Bool = false,
        scheduledStartAt: Date? = nil,
        clearScheduledStartAt: Bool = false,
        scheduledEndAt: Date? = nil,
        clearScheduledEndAt: Bool = false,
        isAllDay: Bool? = nil,
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
        clearReminderTime: Bool = false,
        estimatedDuration: TimeInterval? = nil,
        clearEstimatedDuration: Bool = false,
        actualDuration: TimeInterval? = nil,
        repeatPattern: TaskRepeatPattern? = nil,
        clearRepeatPattern: Bool = false,
        planningBucket: TaskPlanningBucket? = nil,
        weeklyOutcomeID: UUID? = nil,
        clearWeeklyOutcomeLink: Bool = false,
        deferredFromWeekStart: Date? = nil,
        clearDeferredFromWeekStart: Bool = false,
        deferredCount: Int? = nil,
        replanCount: Int? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.recurrenceSeriesID = recurrenceSeriesID
        self.habitDefinitionID = habitDefinitionID
        self.title = title
        self.details = details
        self.projectID = projectID
        self.iconSymbolName = iconSymbolName
        self.clearIconSymbolName = clearIconSymbolName
        self.lifeAreaID = lifeAreaID
        self.clearLifeArea = clearLifeArea
        self.sectionID = sectionID
        self.clearSection = clearSection
        self.dueDate = dueDate
        self.clearDueDate = clearDueDate
        self.scheduledStartAt = scheduledStartAt
        self.clearScheduledStartAt = clearScheduledStartAt
        self.scheduledEndAt = scheduledEndAt
        self.clearScheduledEndAt = clearScheduledEndAt
        self.isAllDay = isAllDay
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
        self.clearReminderTime = clearReminderTime
        self.estimatedDuration = estimatedDuration
        self.clearEstimatedDuration = clearEstimatedDuration
        self.actualDuration = actualDuration
        self.repeatPattern = repeatPattern
        self.clearRepeatPattern = clearRepeatPattern
        self.planningBucket = planningBucket
        self.weeklyOutcomeID = weeklyOutcomeID
        self.clearWeeklyOutcomeLink = clearWeeklyOutcomeLink
        self.deferredFromWeekStart = deferredFromWeekStart
        self.clearDeferredFromWeekStart = clearDeferredFromWeekStart
        self.deferredCount = deferredCount
        self.replanCount = replanCount
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
    public var planningBuckets: [TaskPlanningBucket]
    public var weeklyOutcomeID: UUID?
    public var limit: Int?
    public var offset: Int?

    /// Initializes a new instance.
    public init(
        projectID: UUID? = nil,
        sectionID: UUID? = nil,
        parentTaskID: UUID? = nil,
        includeCompleted: Bool = true,
        dueDateStart: Date? = nil,
        dueDateEnd: Date? = nil,
        updatedAfter: Date? = nil,
        searchText: String? = nil,
        planningBuckets: [TaskPlanningBucket] = [],
        weeklyOutcomeID: UUID? = nil,
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
        self.planningBuckets = planningBuckets
        self.weeklyOutcomeID = weeklyOutcomeID
        self.limit = limit
        self.offset = offset
    }
}

public enum TaskDeleteScope: String, Codable, Equatable, Hashable {
    case single
    case series
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
