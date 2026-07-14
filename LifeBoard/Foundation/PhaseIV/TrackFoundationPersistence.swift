import CoreData
import Foundation

public final class CoreDataTrackFoundationRepository: TrackFoundationRepository, @unchecked Sendable {
    private let container: NSPersistentContainer

    public init(container: NSPersistentContainer) {
        self.container = container
    }

    public func fetchGoals() async throws -> [GoalDefinition] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "GoalDefinition")
            request.predicate = NSPredicate(format: "isArchived == NO")
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return try context.fetch(request).compactMap(Self.goal)
        }
    }

    public func saveGoal(_ value: GoalDefinition) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "GoalDefinition", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.title, forKey: "title")
            object.setValue(value.type.rawValue, forKey: "typeRaw")
            object.setValue(value.areaID, forKey: "areaID")
            object.setValue(value.targetValue, forKey: "targetValue")
            object.setValue(value.unitLabel, forKey: "unitLabel")
            object.setValue(value.targetDate, forKey: "targetDate")
            object.setValue(value.isArchived, forKey: "isArchived")
            object.setValue(value.createdAt, forKey: "createdAt")
            object.setValue(value.updatedAt, forKey: "updatedAt")
        }
    }

    public func fetchGoalLinks(goalID: UUID?) async throws -> [GoalLink] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "GoalLink")
            if let goalID { request.predicate = NSPredicate(format: "goalID == %@", goalID as CVarArg) }
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return try context.fetch(request).compactMap(Self.goalLink)
        }
    }

    public func saveGoalLink(_ value: GoalLink) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "GoalLink", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.goalID, forKey: "goalID")
            object.setValue(value.source.rawValue, forKey: "sourceTypeRaw")
            object.setValue(value.sourceID, forKey: "sourceID")
            object.setValue(value.createdAt, forKey: "createdAt")
        }
    }

    public func fetchHabitResiliencePolicies() async throws -> [HabitResiliencePolicy] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "HabitResiliencePolicy")
            return try context.fetch(request).compactMap(Self.habitPolicy)
        }
    }

    public func saveHabitResiliencePolicy(_ value: HabitResiliencePolicy) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "HabitResiliencePolicy", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.habitID, forKey: "habitID")
            object.setValue(value.groupID, forKey: "groupID")
            object.setValue(try Self.encode(value.offDays), forKey: "offDayKeysData")
            object.setValue(value.recoveryEnabled, forKey: "recoveryEnabled")
            object.setValue(value.streakPresentation.rawValue, forKey: "streakPresentationRaw")
            object.setValue(value.updatedAt, forKey: "updatedAt")
        }
    }

    public func fetchRoutines() async throws -> [RoutineDefinition] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "RoutineDefinition")
            request.predicate = NSPredicate(format: "isArchived == NO")
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            let definitions = try context.fetch(request)
            return try definitions.compactMap { object in
                guard let id = object.value(forKey: "id") as? UUID else { return nil }
                return Self.routine(object, steps: try Self.fetchRoutineSteps(routineID: id, context: context))
            }
        }
    }

    public func saveRoutine(_ value: RoutineDefinition) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "RoutineDefinition", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.title, forKey: "title")
            object.setValue(value.version, forKey: "version")
            object.setValue(value.isArchived, forKey: "isArchived")
            object.setValue(value.createdAt, forKey: "createdAt")
            object.setValue(value.updatedAt, forKey: "updatedAt")

            let request = NSFetchRequest<NSManagedObject>(entityName: "RoutineStep")
            request.predicate = NSPredicate(format: "routineID == %@", value.id as CVarArg)
            try context.fetch(request).forEach(context.delete)
            for step in value.steps {
                let stepObject = NSEntityDescription.insertNewObject(forEntityName: "RoutineStep", into: context)
                stepObject.setValue(step.id, forKey: "id")
                stepObject.setValue(value.id, forKey: "routineID")
                stepObject.setValue(step.kind.rawValue, forKey: "kindRaw")
                stepObject.setValue(step.title, forKey: "title")
                stepObject.setValue(step.ordinal, forKey: "ordinal")
                stepObject.setValue(step.duration, forKey: "duration")
                stepObject.setValue(step.isRequired, forKey: "isRequired")
                stepObject.setValue(step.isSkippable, forKey: "isSkippable")
                stepObject.setValue(try Self.encode(step), forKey: "configurationData")
            }
        }
    }

    public func fetchRoutineRuns(routineID: UUID?) async throws -> [RoutineRun] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "RoutineRun")
            if let routineID { request.predicate = NSPredicate(format: "routineID == %@", routineID as CVarArg) }
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            request.fetchBatchSize = 100
            let runObjects = try context.fetch(request)
            return try runObjects.compactMap { object in
                guard let id = object.value(forKey: "id") as? UUID else { return nil }
                return Self.routineRun(object, events: try Self.fetchRoutineEvents(runID: id, context: context))
            }
        }
    }

    public func saveRoutineRun(_ value: RoutineRun) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "RoutineRun", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.routineID, forKey: "routineID")
            object.setValue(try Self.encode(value.versionSnapshot), forKey: "versionSnapshotData")
            object.setValue(value.status.rawValue, forKey: "statusRaw")
            object.setValue(value.currentStepID, forKey: "currentStepID")
            object.setValue(value.startedAt, forKey: "startedAt")
            object.setValue(value.endedAt, forKey: "endedAt")
            object.setValue(value.updatedAt, forKey: "updatedAt")
            for event in value.events {
                let eventObject = try Self.upsert(entity: "RoutineStepEvent", id: event.id, in: context)
                eventObject.setValue(event.id, forKey: "id")
                eventObject.setValue(value.id, forKey: "runID")
                eventObject.setValue(event.stepID, forKey: "stepID")
                eventObject.setValue(event.wasSkipped ? "skipped" : "completed", forKey: "statusRaw")
                eventObject.setValue(try Self.encode(event), forKey: "responseData")
                eventObject.setValue(event.occurredAt, forKey: "occurredAt")
                eventObject.setValue(event.idempotencyKey, forKey: "idempotencyKey")
            }
        }
    }

    public func fetchRoutineSchedules(routineID: UUID?) async throws -> [RoutineSchedule] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "RoutineSchedule")
            if let routineID { request.predicate = NSPredicate(format: "routineID == %@", routineID as CVarArg) }
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            return try context.fetch(request).compactMap(Self.routineSchedule)
        }
    }

    public func saveRoutineSchedule(_ value: RoutineSchedule) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "RoutineSchedule", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.routineID, forKey: "routineID")
            object.setValue(try Self.encode(value.weekdays), forKey: "weekdaysData")
            object.setValue(value.daypart?.rawValue, forKey: "daypartRaw")
            object.setValue(value.reminderTimeMinutes, forKey: "reminderTimeMinutes")
            object.setValue(value.timeZoneIdentifier, forKey: "timeZoneIdentifier")
            object.setValue(value.isEnabled, forKey: "isEnabled")
            object.setValue(value.updatedAt, forKey: "updatedAt")
        }
    }

    public func fetchRoutineLinkedMutationReceipt(idempotencyKey: String) async throws -> RoutineLinkedMutationReceipt? {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "RoutineLinkedMutationReceipt")
            request.predicate = NSPredicate(format: "idempotencyKey == %@", idempotencyKey)
            request.fetchLimit = 1
            return try context.fetch(request).first.flatMap(Self.routineLinkedMutationReceipt)
        }
    }

    public func saveRoutineLinkedMutationReceipt(_ value: RoutineLinkedMutationReceipt) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "RoutineLinkedMutationReceipt", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.runID, forKey: "runID")
            object.setValue(value.stepID, forKey: "stepID")
            object.setValue(value.mutation.rawValue, forKey: "targetTypeRaw")
            object.setValue(value.targetID, forKey: "targetID")
            object.setValue(value.idempotencyKey, forKey: "idempotencyKey")
            object.setValue(value.status.rawValue, forKey: "statusRaw")
            object.setValue(value.preparedAt, forKey: "preparedAt")
            object.setValue(value.appliedAt, forKey: "appliedAt")
            object.setValue(value.reconciledAt, forKey: "reconciledAt")
        }
    }

    public func fetchHydrationLogs(from: Date, to: Date) async throws -> [HydrationLog] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "HydrationLog")
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "timestamp >= %@", from as NSDate),
                NSPredicate(format: "timestamp < %@", to as NSDate)
            ])
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            return try context.fetch(request).compactMap(Self.hydrationLog)
        }
    }

    public func saveHydrationLog(_ value: HydrationLog) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "HydrationLog", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.amount, forKey: "amount")
            object.setValue(value.unit.rawValue, forKey: "unitRaw")
            object.setValue(value.timestamp, forKey: "timestamp")
            object.setValue(value.note, forKey: "note")
            object.setValue(value.correctedAt, forKey: "correctedAt")
        }
    }

    public func fetchHydrationTarget() async throws -> HydrationTarget? {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "HydrationTarget")
            request.fetchLimit = 1
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            return try context.fetch(request).first.flatMap(Self.hydrationTarget)
        }
    }

    public func saveHydrationTarget(_ value: HydrationTarget) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "HydrationTarget", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.amount, forKey: "amount")
            object.setValue(value.unit.rawValue, forKey: "unitRaw")
            object.setValue(value.updatedAt, forKey: "updatedAt")
        }
    }

    public func fetchSleepContextRecords(from: Date, to: Date) async throws -> [SleepContextRecord] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "SleepContextRecord")
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "bedtime >= %@", from as NSDate),
                NSPredicate(format: "bedtime < %@", to as NSDate)
            ])
            request.sortDescriptors = [NSSortDescriptor(key: "bedtime", ascending: false)]
            return try context.fetch(request).compactMap(Self.sleepContext)
        }
    }

    public func saveSleepContextRecord(_ value: SleepContextRecord) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "SleepContextRecord", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.bedtime, forKey: "bedtime")
            object.setValue(value.wakeTime, forKey: "wakeTime")
            object.setValue(value.perceivedRest, forKey: "perceivedRest")
            object.setValue(value.interruptionCount, forKey: "interruptionCount")
            object.setValue(value.notes, forKey: "notes")
            object.setValue(value.createdAt, forKey: "createdAt")
        }
    }

    public func fetchStarterPackInstallations() async throws -> [StarterPackInstallation] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "StarterPackInstallation")
            request.sortDescriptors = [NSSortDescriptor(key: "installedAt", ascending: false)]
            return try context.fetch(request).compactMap(Self.starterPackInstallation)
        }
    }

    public func saveStarterPackInstallation(_ value: StarterPackInstallation) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "StarterPackInstallation", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.pack.rawValue, forKey: "packRaw")
            object.setValue(try Self.encode(value.createdIDs), forKey: "createdIDsData")
            object.setValue(value.installedAt, forKey: "installedAt")
            object.setValue(value.removedAt, forKey: "removedAt")
        }
    }

    private func read<T: Sendable>(_ operation: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        return try await context.perform { try operation(context) }
    }

    private func write(_ operation: @escaping @Sendable (NSManagedObjectContext) throws -> Void) async throws {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        try await context.perform {
            try operation(context)
            if context.hasChanges { try context.save() }
        }
    }

    private static func fetchOne(entity: String, id: UUID, in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func upsert(entity: String, id: UUID, in context: NSManagedObjectContext) throws -> NSManagedObject {
        try fetchOne(entity: entity, id: id, in: context)
            ?? NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
    }

    private static func fetchRoutineSteps(routineID: UUID, context: NSManagedObjectContext) throws -> [RoutineStep] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "RoutineStep")
        request.predicate = NSPredicate(format: "routineID == %@", routineID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "ordinal", ascending: true)]
        return try context.fetch(request).compactMap { object in
            decode(RoutineStep.self, from: object.value(forKey: "configurationData") as? Data)
        }
    }

    private static func fetchRoutineEvents(runID: UUID, context: NSManagedObjectContext) throws -> [RoutineStepEvent] {
        let request = NSFetchRequest<NSManagedObject>(entityName: "RoutineStepEvent")
        request.predicate = NSPredicate(format: "runID == %@", runID as CVarArg)
        request.sortDescriptors = [NSSortDescriptor(key: "occurredAt", ascending: true)]
        return try context.fetch(request).compactMap { object in
            decode(RoutineStepEvent.self, from: object.value(forKey: "responseData") as? Data)
        }
    }

    private static func goal(_ object: NSManagedObject) -> GoalDefinition? {
        guard let id = object.value(forKey: "id") as? UUID,
              let title = object.value(forKey: "title") as? String,
              let raw = object.value(forKey: "typeRaw") as? String,
              let type = GoalType(rawValue: raw) else { return nil }
        return .init(
            id: id, areaID: object.value(forKey: "areaID") as? UUID, title: title, type: type,
            targetValue: (object.value(forKey: "targetValue") as? NSNumber)?.doubleValue,
            unitLabel: object.value(forKey: "unitLabel") as? String,
            targetDate: object.value(forKey: "targetDate") as? Date,
            isArchived: (object.value(forKey: "isArchived") as? NSNumber)?.boolValue ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private static func goalLink(_ object: NSManagedObject) -> GoalLink? {
        guard let id = object.value(forKey: "id") as? UUID,
              let goalID = object.value(forKey: "goalID") as? UUID,
              let sourceID = object.value(forKey: "sourceID") as? UUID,
              let raw = object.value(forKey: "sourceTypeRaw") as? String,
              let source = GoalLinkSource(rawValue: raw) else { return nil }
        return .init(id: id, goalID: goalID, source: source, sourceID: sourceID, createdAt: object.value(forKey: "createdAt") as? Date ?? Date())
    }

    private static func habitPolicy(_ object: NSManagedObject) -> HabitResiliencePolicy? {
        guard let id = object.value(forKey: "id") as? UUID,
              let habitID = object.value(forKey: "habitID") as? UUID else { return nil }
        return .init(
            id: id,
            habitID: habitID,
            groupID: object.value(forKey: "groupID") as? UUID,
            offDays: decode(Set<PlanningDay>.self, from: object.value(forKey: "offDayKeysData") as? Data) ?? [],
            recoveryEnabled: (object.value(forKey: "recoveryEnabled") as? NSNumber)?.boolValue ?? true,
            streakPresentation: (object.value(forKey: "streakPresentationRaw") as? String)
                .flatMap(HabitStreakPresentation.init(rawValue:)) ?? .gradeAndStreak,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private static func routine(_ object: NSManagedObject, steps: [RoutineStep]) -> RoutineDefinition? {
        guard let id = object.value(forKey: "id") as? UUID,
              let title = object.value(forKey: "title") as? String else { return nil }
        return .init(
            id: id, title: title, version: (object.value(forKey: "version") as? NSNumber)?.intValue ?? 1,
            steps: steps, isArchived: (object.value(forKey: "isArchived") as? NSNumber)?.boolValue ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private static func routineRun(_ object: NSManagedObject, events: [RoutineStepEvent]) -> RoutineRun? {
        guard let id = object.value(forKey: "id") as? UUID,
              let routineID = object.value(forKey: "routineID") as? UUID,
              let snapshot = decode(RoutineDefinition.self, from: object.value(forKey: "versionSnapshotData") as? Data),
              let raw = object.value(forKey: "statusRaw") as? String,
              let status = RoutineRunStatus(rawValue: raw),
              let startedAt = object.value(forKey: "startedAt") as? Date else { return nil }
        return .init(
            id: id, routineID: routineID, versionSnapshot: snapshot, status: status,
            currentStepID: object.value(forKey: "currentStepID") as? UUID, events: events,
            startedAt: startedAt, endedAt: object.value(forKey: "endedAt") as? Date,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? startedAt
        )
    }

    private static func routineSchedule(_ object: NSManagedObject) -> RoutineSchedule? {
        guard let id = object.value(forKey: "id") as? UUID,
              let routineID = object.value(forKey: "routineID") as? UUID else { return nil }
        return .init(
            id: id,
            routineID: routineID,
            weekdays: decode(Set<Int>.self, from: object.value(forKey: "weekdaysData") as? Data) ?? [],
            daypart: (object.value(forKey: "daypartRaw") as? String).flatMap(ResolvedDaypart.init(rawValue:)),
            reminderTimeMinutes: (object.value(forKey: "reminderTimeMinutes") as? NSNumber)?.intValue,
            timeZoneIdentifier: object.value(forKey: "timeZoneIdentifier") as? String ?? TimeZone.current.identifier,
            isEnabled: (object.value(forKey: "isEnabled") as? NSNumber)?.boolValue ?? true,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? .distantPast
        )
    }

    private static func routineLinkedMutationReceipt(_ object: NSManagedObject) -> RoutineLinkedMutationReceipt? {
        guard let id = object.value(forKey: "id") as? UUID,
              let runID = object.value(forKey: "runID") as? UUID,
              let stepID = object.value(forKey: "stepID") as? UUID,
              let targetID = object.value(forKey: "targetID") as? UUID,
              let mutationRaw = object.value(forKey: "targetTypeRaw") as? String,
              let mutation = RoutineLinkedMutationKind(rawValue: mutationRaw),
              let idempotencyKey = object.value(forKey: "idempotencyKey") as? String else { return nil }
        return .init(
            id: id,
            runID: runID,
            stepID: stepID,
            mutation: mutation,
            targetID: targetID,
            idempotencyKey: idempotencyKey,
            status: (object.value(forKey: "statusRaw") as? String)
                .flatMap(RoutineLinkedMutationStatus.init(rawValue:)) ?? .prepared,
            preparedAt: object.value(forKey: "preparedAt") as? Date ?? .distantPast,
            appliedAt: object.value(forKey: "appliedAt") as? Date,
            reconciledAt: object.value(forKey: "reconciledAt") as? Date
        )
    }

    private static func hydrationLog(_ object: NSManagedObject) -> HydrationLog? {
        guard let id = object.value(forKey: "id") as? UUID,
              let raw = object.value(forKey: "unitRaw") as? String,
              let unit = HydrationUnit(rawValue: raw),
              let timestamp = object.value(forKey: "timestamp") as? Date else { return nil }
        return .init(
            id: id, amount: (object.value(forKey: "amount") as? NSNumber)?.doubleValue ?? 0,
            unit: unit, timestamp: timestamp, note: object.value(forKey: "note") as? String,
            correctedAt: object.value(forKey: "correctedAt") as? Date
        )
    }

    private static func hydrationTarget(_ object: NSManagedObject) -> HydrationTarget? {
        guard let id = object.value(forKey: "id") as? UUID,
              let raw = object.value(forKey: "unitRaw") as? String,
              let unit = HydrationUnit(rawValue: raw) else { return nil }
        return .init(
            id: id, amount: (object.value(forKey: "amount") as? NSNumber)?.doubleValue ?? 0,
            unit: unit, updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private static func sleepContext(_ object: NSManagedObject) -> SleepContextRecord? {
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

    private static func starterPackInstallation(_ object: NSManagedObject) -> StarterPackInstallation? {
        guard let id = object.value(forKey: "id") as? UUID,
              let raw = object.value(forKey: "packRaw") as? String,
              let pack = StarterPack(rawValue: raw) else { return nil }
        return .init(
            id: id,
            pack: pack,
            createdIDs: decode([StarterPackItemKind: Set<UUID>].self, from: object.value(forKey: "createdIDsData") as? Data) ?? [:],
            installedAt: object.value(forKey: "installedAt") as? Date ?? .distantPast,
            removedAt: object.value(forKey: "removedAt") as? Date
        )
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data { try JSONEncoder().encode(value) }
    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
