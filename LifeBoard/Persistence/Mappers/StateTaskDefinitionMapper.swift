import LifeBoardContracts
import LifeBoardDomain
import Foundation
import CoreData

public enum StateTaskDefinitionMapper {
    /// Executes toDomain.
    public static func toDomain(from entity: TaskDefinitionEntity) -> TaskDefinition {
        let taskID = entity.taskID ?? entity.id ?? UUID()
        let projectID = entity.projectID ?? ProjectConstants.inboxProjectID
        let title = entity.title ?? "Untitled Task"
        let details = entity.notes
        let priorityRaw = entity.priority > 0 ? entity.priority : TaskPriority.low.rawValue
        let taskTypeRaw = entity.taskType > 0 ? entity.taskType : TaskType.morning.rawValue
        let createdAt = entity.createdAt.map { $0 as Date }
            ?? entity.dateAdded.map { $0 as Date }
            ?? Date()
        let updatedAt = entity.updatedAt.map { $0 as Date } ?? createdAt
        let isComplete = entity.isComplete || entity.status?.lowercased() == "completed"
        let projectRef = entity.value(forKey: "projectRef") as? ProjectEntity
        let recurrenceRule: TaskRecurrenceRule? = {
            guard let data = entity.repeatPatternData, data.isEmpty == false else { return nil }
            let decoder = JSONDecoder()
            if let rule = try? decoder.decode(TaskRecurrenceRule.self, from: data) {
                return rule
            }
            guard let legacy = try? decoder.decode(TaskRepeatPattern.self, from: data) else {
                return nil
            }
            return TaskRecurrenceRule(pattern: legacy, anchor: .scheduledDate)
        }()
        let estimatedDuration = entity.estimatedDuration > 0 ? entity.estimatedDuration : nil
        let actualDuration = entity.actualDuration > 0 ? entity.actualDuration : nil
        let planningBucket = TaskPlanningBucket(
            rawValue: (entity.value(forKey: "planningBucketRaw") as? String) ?? ""
        ) ?? .thisWeek
        let weeklyOutcomeID = entity.value(forKey: "weeklyOutcomeID") as? UUID
        let deferredFromWeekStart = entity.value(forKey: "deferredFromWeekStart") as? Date
        let deferredCount = max(0, (entity.value(forKey: "deferredCount") as? Int32).map(Int.init) ?? 0)
        let replanCount = max(0, Int(entity.replanCount))
        let scheduledStartAt = entity.value(forKey: "scheduledStartAt") as? Date
        let scheduledEndAt = entity.value(forKey: "scheduledEndAt") as? Date
        let isAllDay = entity.value(forKey: "isAllDay") as? Bool ?? false

        return TaskDefinition(
            id: taskID,
            recurrenceSeriesID: entity.recurrenceSeriesID,
            habitDefinitionID: entity.habitDefinitionID,
            projectID: projectID,
            projectName: projectRef?.name ?? ProjectConstants.inboxProjectName,
            iconSymbolName: entity.value(forKey: "iconSymbolName") as? String,
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
            dueDate: entity.dueDate.map { $0 as Date },
            scheduledStartAt: scheduledStartAt,
            scheduledEndAt: scheduledEndAt,
            isAllDay: isAllDay,
            isComplete: isComplete,
            dateAdded: entity.dateAdded.map { $0 as Date } ?? createdAt,
            dateCompleted: entity.dateCompleted.map { $0 as Date },
            isEveningTask: entity.isEveningTask || TaskType(rawValue: taskTypeRaw) == .evening,
            alertReminderTime: entity.alertReminderTime.map { $0 as Date },
            tagIDs: [],
            dependencies: [],
            estimatedDuration: estimatedDuration,
            actualDuration: actualDuration,
            repeatPattern: recurrenceRule?.pattern,
            recurrenceAnchor: recurrenceRule?.anchor ?? .scheduledDate,
            planningBucket: planningBucket,
            weeklyOutcomeID: weeklyOutcomeID,
            deferredFromWeekStart: deferredFromWeekStart,
            deferredCount: deferredCount,
            replanCount: replanCount,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Executes apply.
    @discardableResult
    public static func apply(_ model: TaskDefinition, to entity: TaskDefinitionEntity) -> TaskDefinitionEntity {
        entity.id = model.id
        entity.taskID = model.id
        entity.projectID = model.projectID
        entity.setValue(model.iconSymbolName, forKey: "iconSymbolName")
        entity.lifeAreaID = model.lifeAreaID
        entity.sectionID = model.sectionID
        entity.parentTaskID = model.parentTaskID
        entity.recurrenceSeriesID = model.recurrenceSeriesID
        entity.habitDefinitionID = model.habitDefinitionID
        entity.title = model.title
        entity.notes = model.details
        entity.status = model.isComplete ? "completed" : "pending"
        entity.priority = model.priority.rawValue
        entity.taskType = model.type.rawValue
        entity.energy = model.energy.rawValue
        entity.category = model.category.rawValue
        entity.context = model.context.rawValue
        entity.dueDate = model.dueDate.map { $0 as NSDate }
        entity.setValue(model.scheduledStartAt, forKey: "scheduledStartAt")
        entity.setValue(model.scheduledEndAt, forKey: "scheduledEndAt")
        entity.setValue(model.isAllDay, forKey: "isAllDay")
        entity.isComplete = model.isComplete
        entity.dateAdded = model.dateAdded as NSDate
        entity.dateCompleted = model.dateCompleted.map { $0 as NSDate }
        entity.isEveningTask = model.isEveningTask || model.type == .evening
        entity.alertReminderTime = model.alertReminderTime.map { $0 as NSDate }
        entity.estimatedDuration = model.estimatedDuration ?? 0
        entity.actualDuration = model.actualDuration ?? 0
        entity.repeatPatternData = model.repeatPattern.flatMap {
            try? JSONEncoder().encode(
                TaskRecurrenceRule(pattern: $0, anchor: model.recurrenceAnchor)
            )
        }
        entity.setValue(model.planningBucket.rawValue, forKey: "planningBucketRaw")
        entity.setValue(model.weeklyOutcomeID, forKey: "weeklyOutcomeID")
        entity.setValue(model.deferredFromWeekStart, forKey: "deferredFromWeekStart")
        entity.setValue(Int32(model.deferredCount), forKey: "deferredCount")
        entity.replanCount = Int32(max(0, model.replanCount))
        entity.source = entity.source ?? "user"
        entity.createdBy = entity.createdBy ?? "user"
        entity.createdAt = model.createdAt as NSDate
        entity.updatedAt = model.updatedAt as NSDate
        entity.version = max(entity.version, 1)
        return entity
    }
}
