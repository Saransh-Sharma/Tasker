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
        let createdAt = entity.createdAt as Date? ?? entity.dateAdded as Date? ?? Date()
        let updatedAt = entity.updatedAt as Date? ?? createdAt
        let isComplete = entity.isComplete || entity.status?.lowercased() == "completed"
        let projectRef = entity.value(forKey: "projectRef") as? ProjectEntity

        return TaskDefinition(
            id: taskID,
            projectID: projectID,
            projectName: projectRef?.name ?? ProjectConstants.inboxProjectName,
            lifeAreaID: nil,
            sectionID: entity.sectionID,
            parentTaskID: entity.parentTaskID,
            title: title,
            details: details,
            priority: TaskPriority(rawValue: priorityRaw),
            type: TaskType(rawValue: taskTypeRaw),
            energy: TaskEnergy(rawValue: entity.energy ?? "") ?? .medium,
            category: TaskCategory(rawValue: entity.category ?? "") ?? .general,
            context: TaskContext(rawValue: entity.context ?? "") ?? .anywhere,
            dueDate: entity.dueDate as Date?,
            isComplete: isComplete,
            dateAdded: entity.dateAdded as Date? ?? createdAt,
            dateCompleted: entity.dateCompleted as Date?,
            isEveningTask: entity.isEveningTask || TaskType(rawValue: taskTypeRaw) == .evening,
            alertReminderTime: entity.alertReminderTime as Date?,
            tagIDs: [],
            dependencies: [],
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    @discardableResult
    public static func apply(_ model: TaskDefinition, to entity: TaskDefinitionEntity) -> TaskDefinitionEntity {
        entity.id = model.id
        entity.taskID = model.id
        entity.projectID = model.projectID
        entity.sectionID = model.sectionID
        entity.parentTaskID = model.parentTaskID
        entity.title = model.title
        entity.notes = model.details
        entity.status = model.isComplete ? "completed" : "pending"
        entity.priority = model.priority.rawValue
        entity.taskType = model.type.rawValue
        entity.energy = model.energy.rawValue
        entity.category = model.category.rawValue
        entity.context = model.context.rawValue
        entity.dueDate = model.dueDate as NSDate?
        entity.isComplete = model.isComplete
        entity.dateAdded = model.dateAdded as NSDate
        entity.dateCompleted = model.dateCompleted as NSDate?
        entity.isEveningTask = model.isEveningTask || model.type == .evening
        entity.alertReminderTime = model.alertReminderTime as NSDate?
        entity.source = entity.source ?? "user"
        entity.createdBy = entity.createdBy ?? "user"
        entity.createdAt = model.createdAt as NSDate
        entity.updatedAt = model.updatedAt as NSDate
        entity.version = max(entity.version, 1)
        return entity
    }
}
