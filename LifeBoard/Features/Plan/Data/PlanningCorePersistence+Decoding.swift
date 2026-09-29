import CoreData
import Foundation

extension CoreDataPlanningRepository {
    static func projectMilestone(_ object: NSManagedObject) -> ProjectMilestone? {
        guard let id = object.value(forKey: "id") as? UUID,
              let projectID = object.value(forKey: "projectID") as? UUID,
              let title = object.value(forKey: "title") as? String else {
            return nil
        }
        let targetDay: PlanningDay?
        if let year = (object.value(forKey: "targetDayYear") as? NSNumber)?.intValue,
           let month = (object.value(forKey: "targetDayMonth") as? NSNumber)?.intValue,
           let day = (object.value(forKey: "targetDayDay") as? NSNumber)?.intValue {
            targetDay = PlanningDay(
                year: year,
                month: month,
                day: day,
                timeZoneIdentifier: object.value(forKey: "targetDayTimeZoneIdentifier") as? String
                    ?? TimeZone.current.identifier
            )
        } else {
            targetDay = nil
        }
        return ProjectMilestone(
            id: id,
            projectID: projectID,
            title: title,
            targetDay: targetDay,
            completedAt: object.value(forKey: "completedAt") as? Date,
            sortOrder: (object.value(forKey: "sortOrder") as? NSNumber)?.intValue ?? 0
        )
    }

    static func timeBlock(_ object: NSManagedObject) -> InternalTimeBlock? {
        guard let id = object.value(forKey: "id") as? UUID,
              let title = object.value(forKey: "title") as? String,
              let startAt = object.value(forKey: "startAt") as? Date,
              let endAt = object.value(forKey: "endAt") as? Date else { return nil }
        return InternalTimeBlock(
            id: id,
            title: title,
            startAt: startAt,
            endAt: endAt,
            taskID: object.value(forKey: "taskID") as? UUID,
            planningContext: (object.value(forKey: "planningContextRaw") as? String)
                .flatMap(PlanningContext.init(rawValue:)) ?? .neutral,
            isFixed: (object.value(forKey: "isFixed") as? NSNumber)?.boolValue ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? startAt,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? startAt
        )
    }

    static func workingHoursProfile(_ object: NSManagedObject) -> WorkingHoursProfile? {
        guard let id = object.value(forKey: "id") as? UUID,
              let name = object.value(forKey: "name") as? String else { return nil }
        let intervals: [Int: [WorkingHoursInterval]]
        if let data = object.value(forKey: "intervalsData") as? Data {
            intervals = (try? JSONDecoder().decode([Int: [WorkingHoursInterval]].self, from: data)) ?? [:]
        } else {
            intervals = [:]
        }
        return WorkingHoursProfile(
            id: id,
            name: name,
            intervalsByWeekday: intervals,
            bufferDuration: (object.value(forKey: "bufferDuration") as? NSNumber)?.doubleValue ?? 0,
            isDefault: (object.value(forKey: "isDefault") as? NSNumber)?.boolValue ?? false,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? .distantPast
        )
    }
}
