import CoreData
import Foundation

extension PersistentStoreBootstrapService {
    public static func validateRuntimeSchema(in model: NSManagedObjectModel) -> NSError? {
        if let habitSchemaError = CoreDataHabitRepository.schemaValidationError(in: model) {
            logError(
                event: "persistent_store_habit_schema_invalid",
                message: "Loaded Core Data model is missing required habit runtime fields",
                fields: [
                    "error": habitSchemaError.localizedDescription,
                    "missing_requirements": habitSchemaError.userInfo["missingRequirements"] as? String ?? "unknown"
                ]
            )
            return habitSchemaError
        }

        if let weeklyPlanningSchemaError = weeklyPlanningSchemaValidationError(in: model) {
            logError(
                event: "persistent_store_weekly_planning_schema_invalid",
                message: "Loaded Core Data model is missing required weekly planning fields",
                fields: [
                    "error": weeklyPlanningSchemaError.localizedDescription,
                    "missing_requirements": weeklyPlanningSchemaError.userInfo["missingRequirements"] as? String ?? "unknown"
                ]
            )
            return weeklyPlanningSchemaError
        }

        if let gamificationSchemaError = CoreDataGamificationRepository.schemaValidationError(in: model) {
            logError(
                event: "persistent_store_gamification_schema_invalid",
                message: "Loaded Core Data model is missing required gamification fields",
                fields: [
                    "error": gamificationSchemaError.localizedDescription,
                    "missing_requirements": gamificationSchemaError.userInfo["missingRequirements"] as? String ?? "unknown"
                ]
            )
            return gamificationSchemaError
        }

        return nil
    }

    private static func weeklyPlanningSchemaValidationError(in model: NSManagedObjectModel) -> NSError? {
        var missingRequirements: [String] = []

        func requireAttributes(entityName: String, attributes: [String]) {
            guard let entity = model.entitiesByName[entityName] else {
                missingRequirements.append("entity:\(entityName)")
                return
            }

            for attribute in attributes where entity.attributesByName[attribute] == nil {
                missingRequirements.append("\(entityName).\(attribute)")
            }
        }

        requireAttributes(
            entityName: "TaskDefinition",
            attributes: [
                "iconSymbolName",
                "planningBucketRaw",
                "weeklyOutcomeID",
                "deferredFromWeekStart",
                "deferredCount",
                "replanCount",
                "scheduledStartAt",
                "scheduledEndAt",
                "isAllDay"
            ]
        )
        requireAttributes(
            entityName: "Project",
            attributes: [
                "motivationWhy",
                "motivationSuccessLooksLike",
                "motivationCostOfNeglect"
            ]
        )
        requireAttributes(
            entityName: "WeeklyPlan",
            attributes: [
                "id",
                "weekStartDate",
                "reviewStatus"
            ]
        )
        requireAttributes(
            entityName: "WeeklyOutcome",
            attributes: [
                "id",
                "weeklyPlanID",
                "title",
                "status",
                "orderIndex"
            ]
        )
        requireAttributes(
            entityName: "WeeklyReview",
            attributes: [
                "id",
                "weeklyPlanID",
                "completedAt"
            ]
        )
        requireAttributes(
            entityName: "ReflectionNote",
            attributes: [
                "id",
                "kind",
                "noteText",
                "createdAt"
            ]
        )
        requireAttributes(
            entityName: "Occurrence",
            attributes: [
                "recordedValue",
                "recordedValueUpdatedAt"
            ]
        )
        requireAttributes(
            entityName: "FrictionFinding",
            attributes: [
                "id",
                "taskID",
                "evidenceData",
                "selectedReasonRaw",
                "interventionRaw",
                "reviewAfter",
                "outcomeRaw"
            ]
        )

        guard missingRequirements.isEmpty == false else {
            return nil
        }

        return NSError(
            domain: "LifeBoardPersistentStoreBootstrapService",
            code: 301,
            userInfo: [
                NSLocalizedDescriptionKey: "The loaded Core Data model is missing required weekly planning schema.",
                "missingRequirements": missingRequirements.sorted().joined(separator: ",")
            ]
        )
    }
}
