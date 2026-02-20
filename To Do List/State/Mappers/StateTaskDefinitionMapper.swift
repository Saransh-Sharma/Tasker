import Foundation
import CoreData

public enum StateTaskDefinitionMapper {
    public static func toDomain(from entity: TaskDefinitionEntity) -> TaskDefinition {
        let taskID = entity.taskID ?? entity.id ?? UUID()
        let projectID = entity.projectID ?? ProjectConstants.inboxProjectID
        let title = entity.title ?? "Untitled Task"
        let details = entity.notes
        let priorityRaw = entity.priority > 0 ? entity.priority : TaskPriority.low.rawValue
        let taskTypeRaw = entity.taskType > 0 ? entity.taskType : TaskType.morning.rawValue
        let createdAt = entity.createdAt ?? entity.dateAdded ?? Date()
        let updatedAt = entity.updatedAt ?? createdAt
        let isComplete = entity.isComplete || entity.status?.lowercased() == "completed"
        let projectRef = entity.value(forKey: "projectRef") as? ProjectEntity
        let repeatPattern: TaskRepeatPattern? = {
            guard let data = entity.repeatPatternData, data.isEmpty == false else { return nil }
            return try? JSONDecoder().decode(TaskRepeatPattern.self, from: data)
        }()
        let estimatedDuration = entity.estimatedDuration > 0 ? entity.estimatedDuration : nil
        let actualDuration = entity.actualDuration > 0 ? entity.actualDuration : nil

        return TaskDefinition(
            id: taskID,
            recurrenceSeriesID: entity.recurrenceSeriesID,
            projectID: projectID,
            projectName: projectRef?.name ?? ProjectConstants.inboxProjectName,
            lifeAreaID: entity.lifeAreaID,
            sectionID: entity.sectionID,
            parentTaskID: entity.parentTaskID,
            title: title,
            details: details,
            priority: TaskPriority(rawValue: priorityRaw),
            type: TaskType(rawValue: taskTypeRaw),
            energy: TaskEnergy(rawValue: entity.energy ?? "") ?? .medium,
            category: TaskCategory(rawValue: entity.category ?? "") ?? .general,
            context: TaskContext(rawValue: entity.context ?? "") ?? .anywhere,
            dueDate: entity.dueDate,
            isComplete: isComplete,
            dateAdded: entity.dateAdded ?? createdAt,
            dateCompleted: entity.dateCompleted,
            isEveningTask: entity.isEveningTask || TaskType(rawValue: taskTypeRaw) == .evening,
            alertReminderTime: entity.alertReminderTime,
            tagIDs: [],
            dependencies: [],
            estimatedDuration: estimatedDuration,
            actualDuration: actualDuration,
            repeatPattern: repeatPattern,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    @discardableResult
    public static func apply(_ model: TaskDefinition, to entity: TaskDefinitionEntity) -> TaskDefinitionEntity {
        entity.id = model.id
        entity.taskID = model.id
        entity.projectID = model.projectID
        entity.lifeAreaID = model.lifeAreaID
        entity.sectionID = model.sectionID
        entity.parentTaskID = model.parentTaskID
        entity.recurrenceSeriesID = model.recurrenceSeriesID
        entity.title = model.title
        entity.notes = model.details
        entity.status = model.isComplete ? "completed" : "pending"
        entity.priority = model.priority.rawValue
        entity.taskType = model.type.rawValue
        entity.energy = model.energy.rawValue
        entity.category = model.category.rawValue
        entity.context = model.context.rawValue
        entity.dueDate = model.dueDate
        entity.isComplete = model.isComplete
        entity.dateAdded = model.dateAdded
        entity.dateCompleted = model.dateCompleted
        entity.isEveningTask = model.isEveningTask || model.type == .evening
        entity.alertReminderTime = model.alertReminderTime
        entity.estimatedDuration = model.estimatedDuration ?? 0
        entity.actualDuration = model.actualDuration ?? 0
        entity.repeatPatternData = model.repeatPattern.flatMap { try? JSONEncoder().encode($0) }
        entity.source = entity.source ?? "user"
        entity.createdBy = entity.createdBy ?? "user"
        entity.createdAt = model.createdAt
        entity.updatedAt = model.updatedAt
        entity.version = max(entity.version, 1)
        return entity
    }
}
