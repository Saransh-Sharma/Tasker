import LifeBoardContracts
import LifeBoardDomain
import CoreData
import Foundation

private struct PersistedOverdueRescueSession: Decodable {
    let referenceDate: Date
    let undoStack: [PersistedOverdueRescueUndoRecord]
}

private struct PersistedOverdueRescueUndoRecord: Decodable {
    let taskID: UUID
    let source: String
    let action: String
    let fullSnapshot: AssistantTaskSnapshot
}

public enum RescueScheduleRepairService {
    public struct Report: Equatable {
        public var scannedRuns = 0
        public var scannedSessionRecords = 0
        public var repairedTasks = 0

        public init() {}
    }
    /// The pass scans every applied rescue run and decodes its proposal. It
    /// used to run on every foreground *and* every remote-change notification
    /// — CloudKit delivers those in bursts — so an idle iPhone re-decoded the
    /// same history dozens of times a minute. Now at most once per interval,
    /// with one trailing pass so the tail of a burst is still covered.
    public static let minimumRepairInterval: TimeInterval = 30

    private final class RepairThrottle: @unchecked Sendable {
        let lock = NSLock()
        var lastRunAt: Date?
        var trailingRunScheduled = false
    }

    private final class DeferredRepairRequest: @unchecked Sendable {
        weak var container: NSPersistentContainer?
        let defaults: UserDefaults
        init(container: NSPersistentContainer, defaults: UserDefaults) {
            self.container = container
            self.defaults = defaults
        }
    }

    private static let throttle = RepairThrottle()

    /// - Parameter force: bypasses the interval — for a caller that knows it
    ///   just saved a rescue run the pass should look at.
    public static func repair(
        container: NSPersistentContainer,
        defaults: UserDefaults = .standard,
        force: Bool = false,
        completion: (@Sendable (Report) -> Void)? = nil
    ) {
        let now = Date()
        let trailingDelay: TimeInterval? = throttle.lock.withLock {
            if force == false,
               let last = throttle.lastRunAt,
               now.timeIntervalSince(last) < minimumRepairInterval {
                guard throttle.trailingRunScheduled == false else { return -1 }
                throttle.trailingRunScheduled = true
                return minimumRepairInterval - now.timeIntervalSince(last)
            }
            throttle.lastRunAt = now
            return nil
        }
        if let trailingDelay {
            if trailingDelay >= 0 {
                let request = DeferredRepairRequest(container: container, defaults: defaults)
                DispatchQueue.main.asyncAfter(deadline: .now() + trailingDelay) {
                    throttle.lock.withLock { throttle.trailingRunScheduled = false }
                    guard let container = request.container else { return }
                    repair(container: container, defaults: request.defaults)
                }
            }
            if let completion {
                DispatchQueue.main.async { completion(Report()) }
            }
            return
        }
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        let rescueSessionEntries = rescueSessionEntries(from: defaults)
        context.perform {
            do {
                let report = try repair(in: context, rescueSessionEntries: rescueSessionEntries)
                if context.hasChanges {
                    try context.save()
                }
                DispatchQueue.main.async {
                    if report.repairedTasks > 0 {
                        NotificationCenter.default.post(
                            name: .homeTaskMutation,
                            object: nil,
                            userInfo: HomeTaskMutationPayload(
                                reason: .bulkChanged,
                                source: "rescueScheduleRepair"
                            ).userInfo
                        )
                    }
                    completion?(report)
                }
            } catch {
                logError(
                    event: "rescue_schedule_repair_failed",
                    message: "Failed to repair rescue schedule history",
                    fields: ["error": error.localizedDescription]
                )
                DispatchQueue.main.async {
                    completion?(Report())
                }
            }
        }
    }

    @discardableResult
    static func repair(
        in context: NSManagedObjectContext,
        defaults: UserDefaults = .standard,
        rescueSessionEntries: [(key: String, data: Data)]? = nil,
        now: Date = Date(),
        calendar: Calendar = .current
    ) throws -> Report {
        var report = Report()
        let runRequest = NSFetchRequest<NSManagedObject>(entityName: "AssistantActionRun")
        runRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "threadID BEGINSWITH %@", "eva_rescue_"),
            NSPredicate(format: "status == %@", AssistantActionStatus.applied.rawValue),
            NSPredicate(format: "proposalData != nil")
        ])
        runRequest.sortDescriptors = [NSSortDescriptor(key: "appliedAt", ascending: false)]

        for run in try context.fetch(runRequest) {
            report.scannedRuns += 1
            guard let data = run.value(forKey: "proposalData") as? Data,
                  let envelope = try? JSONDecoder().decode(AssistantCommandEnvelope.self, from: data),
                  let undoCommands = envelope.undoCommands else {
                continue
            }
            let originals = Dictionary(
                undoCommands.compactMap(snapshotPair),
                uniquingKeysWith: { first, _ in first }
            )
            for command in envelope.commands {
                guard case .restoreTaskSnapshot(let forward) = command,
                      let original = originals[forward.id],
                      originalHadAllDayIntent(original, calendar: calendar),
                      forwardLooksLikeCorruptedTimedRescue(forward, calendar: calendar),
                      let task = try fetchTask(id: forward.id, in: context),
                      currentTask(task, matches: forward),
                      isRepairEligible(task) else {
                    continue
                }
                applyAllDayRepair(
                    task,
                    targetDate: forward.dueDate ?? forward.scheduledStartAt,
                    now: now,
                    calendar: calendar
                )
                report.repairedTasks += 1
            }
        }

        for (_, data) in rescueSessionEntries ?? Self.rescueSessionEntries(from: defaults) {
            guard let session = try? JSONDecoder().decode(PersistedOverdueRescueSession.self, from: data) else {
                continue
            }
            for record in session.undoStack
            where record.source == "bulk" && record.action == "keepToday" {
                report.scannedSessionRecords += 1
                guard originalHadAllDayIntent(record.fullSnapshot, calendar: calendar),
                      let task = try fetchTask(id: record.taskID, in: context),
                      currentTask(task, matches: record.fullSnapshot),
                      isRepairEligible(task) else {
                    continue
                }
                applyAllDayRepair(
                    task,
                    targetDate: session.referenceDate,
                    now: now,
                    calendar: calendar
                )
                report.repairedTasks += 1
            }
        }

        if report.repairedTasks > 0 {
            logWarning(
                event: "rescue_schedule_repair_applied",
                message: "Repaired all-day tasks using persisted rescue evidence",
                fields: [
                    "scanned_runs": String(report.scannedRuns),
                    "scanned_session_records": String(report.scannedSessionRecords),
                    "repaired_tasks": String(report.repairedTasks)
                ]
            )
        }
        return report
    }

    private static func rescueSessionEntries(from defaults: UserDefaults) -> [(key: String, data: Data)] {
        defaults.dictionaryRepresentation().compactMap { key, value in
            guard key.hasPrefix("overdueRescue.session.v1."),
                  let data = value as? Data else {
                return nil
            }
            return (key, data)
        }
    }

    private static func snapshotPair(_ command: AssistantCommand) -> (UUID, AssistantTaskSnapshot)? {
        guard case .restoreTaskSnapshot(let snapshot) = command else { return nil }
        return (snapshot.id, snapshot)
    }

    private static func originalHadAllDayIntent(
        _ snapshot: AssistantTaskSnapshot,
        calendar: Calendar
    ) -> Bool {
        snapshot.isAllDay == true
            || snapshot.dueDate.map { TaskScheduleNormalizer.isDateOnly($0, calendar: calendar) } == true
    }

    private static func forwardLooksLikeCorruptedTimedRescue(
        _ snapshot: AssistantTaskSnapshot,
        calendar: Calendar
    ) -> Bool {
        snapshot.isAllDay != true
            && snapshot.scheduledStartAt != nil
            && snapshot.dueDate.map { TaskScheduleNormalizer.isDateOnly($0, calendar: calendar) == false } == true
    }

    private static func fetchTask(
        id: UUID,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func isRepairEligible(_ task: NSManagedObject) -> Bool {
        (task.value(forKey: "isComplete") as? Bool) != true
            && task.value(forKey: "parentTaskID") == nil
    }

    private static func currentTask(
        _ task: NSManagedObject,
        matches snapshot: AssistantTaskSnapshot
    ) -> Bool {
        datesEqual(task.value(forKey: "dueDate") as? Date, snapshot.dueDate)
            && datesEqual(task.value(forKey: "scheduledStartAt") as? Date, snapshot.scheduledStartAt)
            && datesEqual(task.value(forKey: "scheduledEndAt") as? Date, snapshot.scheduledEndAt)
            && ((task.value(forKey: "isAllDay") as? Bool) ?? false) == (snapshot.isAllDay ?? false)
    }

    private static func datesEqual(_ lhs: Date?, _ rhs: Date?) -> Bool {
        switch (lhs, rhs) {
        case (nil, nil):
            return true
        case let (lhs?, rhs?):
            return abs(lhs.timeIntervalSince(rhs)) < 1
        default:
            return false
        }
    }

    private static func applyAllDayRepair(
        _ task: NSManagedObject,
        targetDate: Date?,
        now: Date,
        calendar: Calendar
    ) {
        guard let targetDate else { return }
        task.setValue(calendar.startOfDay(for: targetDate), forKey: "dueDate")
        task.setValue(nil, forKey: "scheduledStartAt")
        task.setValue(nil, forKey: "scheduledEndAt")
        task.setValue(true, forKey: "isAllDay")
        task.setValue(now, forKey: "updatedAt")
    }
}
