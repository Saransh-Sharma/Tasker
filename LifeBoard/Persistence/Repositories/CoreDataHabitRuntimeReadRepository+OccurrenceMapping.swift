import CoreData
import Foundation
import LifeBoardDomain

extension CoreDataHabitRuntimeReadRepository {
    func mapOccurrence(_ object: NSManagedObject) -> OccurrenceDefinition {
        let scheduleTemplateID = object.value(forKey: "scheduleTemplateID") as? UUID ?? UUID()
        let sourceID = object.value(forKey: "sourceID") as? UUID ?? UUID()
        let scheduledAt = object.value(forKey: "scheduledAt") as? Date ?? Date()
        let occurrenceKey = object.value(forKey: "occurrenceKey") as? String
            ?? OccurrenceKeyCodec.encode(
                scheduleTemplateID: scheduleTemplateID,
                scheduledAt: scheduledAt,
                sourceID: sourceID
            )
        return OccurrenceDefinition(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            occurrenceKey: occurrenceKey,
            scheduleTemplateID: scheduleTemplateID,
            sourceType: ScheduleSourceType(rawValue: object.value(forKey: "sourceType") as? String ?? "habit") ?? .habit,
            sourceID: sourceID,
            scheduledAt: scheduledAt,
            dueAt: object.value(forKey: "dueAt") as? Date,
            state: OccurrenceState(rawValue: object.value(forKey: "state") as? String ?? "pending") ?? .pending,
            isGenerated: object.value(forKey: "isGenerated") as? Bool ?? true,
            generationWindow: object.value(forKey: "generationWindow") as? String,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date(),
            recordedValue: (object.value(forKey: "recordedValue") as? NSNumber)?.doubleValue,
            recordedValueUpdatedAt: object.value(forKey: "recordedValueUpdatedAt") as? Date
        )
    }
}
