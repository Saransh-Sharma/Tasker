import CoreData
import Foundation

extension CoreDataTrackFoundationRepository {
    static func sleepContext(_ object: NSManagedObject) -> SleepContextRecord? {
        guard let id = object.value(forKey: "id") as? UUID,
              let bedtime = object.value(forKey: "bedtime") as? Date,
              let wakeTime = object.value(forKey: "wakeTime") as? Date else { return nil }
        return .init(
            id: id, bedtime: bedtime, wakeTime: wakeTime,
            perceivedRest: (object.value(forKey: "perceivedRest") as? NSNumber)?.intValue,
            interruptionCount: (object.value(forKey: "interruptionCount") as? NSNumber)?.intValue ?? 0,
            notes: object.value(forKey: "notes") as? String,
            createdAt: object.value(forKey: "createdAt") as? Date ?? bedtime
        )
    }
}
