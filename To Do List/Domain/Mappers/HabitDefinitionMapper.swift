import Foundation
import CoreData

public enum HabitDefinitionMapper {
    public static let entityName = "HabitDefinition"

    public static func toDomain(from object: NSManagedObject) -> HabitDefinitionRecord {
        HabitDefinitionRecord(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            lifeAreaID: object.value(forKey: "lifeAreaID") as? UUID,
            projectID: object.value(forKey: "projectID") as? UUID,
            title: object.value(forKey: "title") as? String ?? "Habit",
            habitType: object.value(forKey: "habitType") as? String ?? "check_in",
            targetConfigData: object.value(forKey: "targetConfigData") as? Data,
            metricConfigData: object.value(forKey: "metricConfigData") as? Data,
            isPaused: object.value(forKey: "isPaused") as? Bool ?? false,
            lastGeneratedDate: object.value(forKey: "lastGeneratedDate") as? Date,
            streakCurrent: Int(object.value(forKey: "streakCurrent") as? Int32 ?? 0),
            streakBest: Int(object.value(forKey: "streakBest") as? Int32 ?? 0),
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    @discardableResult
    public static func apply(_ model: HabitDefinitionRecord, to object: NSManagedObject) -> NSManagedObject {
        object.setValue(model.id, forKey: "id")
        object.setValue(model.lifeAreaID, forKey: "lifeAreaID")
        object.setValue(model.projectID, forKey: "projectID")
        object.setValue(model.title, forKey: "title")
        object.setValue(model.habitType, forKey: "habitType")
        object.setValue(model.targetConfigData, forKey: "targetConfigData")
        object.setValue(model.metricConfigData, forKey: "metricConfigData")
        object.setValue(model.isPaused, forKey: "isPaused")
        object.setValue(model.lastGeneratedDate, forKey: "lastGeneratedDate")
        object.setValue(Int32(model.streakCurrent), forKey: "streakCurrent")
        object.setValue(Int32(model.streakBest), forKey: "streakBest")
        object.setValue(model.createdAt, forKey: "createdAt")
        object.setValue(model.updatedAt, forKey: "updatedAt")
        return object
    }
}
