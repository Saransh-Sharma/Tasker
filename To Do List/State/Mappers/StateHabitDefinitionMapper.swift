import Foundation
import CoreData

enum StateHabitDefinitionMapper {
    static let entityName = "HabitDefinition"

    /// Executes toDomain.
    static func toDomain(from object: NSManagedObject) -> HabitDefinitionRecord {
        HabitDefinitionRecord(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            lifeAreaID: object.value(forKey: "lifeAreaID") as? UUID,
            projectID: object.value(forKey: "projectID") as? UUID,
            title: object.value(forKey: "title") as? String ?? "Habit",
            habitType: object.value(forKey: "habitType") as? String ?? "check_in",
            kindRaw: object.value(forKey: "kindRaw") as? String,
            trackingModeRaw: object.value(forKey: "trackingModeRaw") as? String,
            iconSymbolName: object.value(forKey: "iconSymbolName") as? String,
            iconCategoryKey: object.value(forKey: "iconCategoryKey") as? String,
            targetConfigData: object.value(forKey: "targetConfigData") as? Data,
            metricConfigData: object.value(forKey: "metricConfigData") as? Data,
            notes: object.value(forKey: "notes") as? String,
            isPaused: object.value(forKey: "isPaused") as? Bool ?? false,
            archivedAt: object.value(forKey: "archivedAt") as? Date,
            lastGeneratedDate: object.value(forKey: "lastGeneratedDate") as? Date,
            streakCurrent: Int(object.value(forKey: "streakCurrent") as? Int32 ?? 0),
            streakBest: Int(object.value(forKey: "streakBest") as? Int32 ?? 0),
            successMask14Raw: object.value(forKey: "successMask14Raw") as? Int16 ?? 0,
            failureMask14Raw: object.value(forKey: "failureMask14Raw") as? Int16 ?? 0,
            lastHistoryRollDate: object.value(forKey: "lastHistoryRollDate") as? Date,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    /// Executes apply.
    @discardableResult
    static func apply(_ model: HabitDefinitionRecord, to object: NSManagedObject) -> NSManagedObject {
        object.setValue(model.id, forKey: "id")
        object.setValue(model.lifeAreaID, forKey: "lifeAreaID")
        object.setValue(model.projectID, forKey: "projectID")
        object.setValue(model.title, forKey: "title")
        object.setValue(model.habitType, forKey: "habitType")
        object.setValue(model.kindRaw, forKey: "kindRaw")
        object.setValue(model.trackingModeRaw, forKey: "trackingModeRaw")
        object.setValue(model.iconSymbolName, forKey: "iconSymbolName")
        object.setValue(model.iconCategoryKey, forKey: "iconCategoryKey")
        object.setValue(model.targetConfigData, forKey: "targetConfigData")
        object.setValue(model.metricConfigData, forKey: "metricConfigData")
        object.setValue(model.notes, forKey: "notes")
        object.setValue(model.isPaused, forKey: "isPaused")
        object.setValue(model.archivedAt, forKey: "archivedAt")
        object.setValue(model.lastGeneratedDate, forKey: "lastGeneratedDate")
        object.setValue(Int32(model.streakCurrent), forKey: "streakCurrent")
        object.setValue(Int32(model.streakBest), forKey: "streakBest")
        object.setValue(model.successMask14Raw, forKey: "successMask14Raw")
        object.setValue(model.failureMask14Raw, forKey: "failureMask14Raw")
        object.setValue(model.lastHistoryRollDate, forKey: "lastHistoryRollDate")
        object.setValue(model.createdAt, forKey: "createdAt")
        object.setValue(model.updatedAt, forKey: "updatedAt")
        return object
    }
}
