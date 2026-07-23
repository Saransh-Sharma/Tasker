import CoreData
import EventKit
import Foundation

public enum PlanningPersistenceError: LocalizedError, Sendable {
    case taskNotFound(UUID)

    public var errorDescription: String? {
        switch self {
        case .taskNotFound(let id): "The task \(id.uuidString) no longer exists."
        }
    }
}

private struct FocusCommandLedger: Codable, Sendable {
    var appliedCommandIDs: Set<UUID>
    var receipts: [FocusCommandReceipt]
}

public final class CoreDataPlanningRepository: PlanningRepository, PlanningProjectionRepository, PlanningCalendarContextRepository, InternalTimeBlockRepository, PlanningMutationRepository, FocusExecutionCoordinator, @unchecked Sendable {
    // Read-only calendar context stays an EventKit concern; this repository
    // only forwards so callers can treat planning as one composed boundary.
    private lazy var calendarContext = SystemPlanningCalendarContextRepository()

    public func authorization() async -> PlanningCalendarAuthorization {
        await calendarContext.authorization()
    }

    public func requestAccess() async -> PlanningCalendarAuthorization {
        await calendarContext.requestAccess()
    }

    public func fetchCommitments(from: Date, to: Date) async throws -> PlanningCalendarContext {
        try await calendarContext.fetchCommitments(from: from, to: to)
    }

    private let container: NSPersistentContainer

    public init(container: NSPersistentContainer) {
        self.container = container
    }

    public func fetchTaskMetadata(taskIDs: Set<UUID>?) async throws -> [PlanningTaskMetadata] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
            if let taskIDs {
                guard taskIDs.isEmpty == false else { return [] }
                request.predicate = NSPredicate(format: "id IN %@", Array(taskIDs))
            }
            request.fetchBatchSize = 200
            return try context.fetch(request).compactMap(Self.taskMetadata)
        }
    }

    public func saveTaskMetadata(_ value: PlanningTaskMetadata) async throws {
        try await saveTaskMetadata([value])
    }

    public func saveTaskMetadata(_ values: [PlanningTaskMetadata]) async throws {
        try await write { context in
            for value in values {
                guard let task = try Self.fetchOne(entity: "TaskDefinition", id: value.taskID, in: context) else {
                    throw PlanningPersistenceError.taskNotFound(value.taskID)
                }
                task.setValue(value.planningDay?.year, forKey: "planningDayYear")
                task.setValue(value.planningDay?.month, forKey: "planningDayMonth")
                task.setValue(value.planningDay?.day, forKey: "planningDayDay")
                task.setValue(value.planningDay?.timeZoneIdentifier, forKey: "planningDayTimeZoneIdentifier")
                task.setValue(value.commitmentLevel.rawValue, forKey: "commitmentLevelRaw")
                task.setValue(value.availability.rawValue, forKey: "availabilityRaw")
                task.setValue(value.planningContext.rawValue, forKey: "planningContextRaw")
                task.setValue(value.unscheduledDisposition.rawValue, forKey: "unscheduledDispositionRaw")
                task.setValue(value.availabilityExplanation, forKey: "availabilityExplanation")
                task.setValue(value.resumeDate, forKey: "planningResumeDate")
                task.setValue(value.pinOrder, forKey: "planningPinOrder")
                task.setValue(value.updatedAt, forKey: "updatedAt")
            }
        }
    }

    public func fetchOpenPlanningTasks() async throws -> [PlanningTaskSummary] {
        try await read { context in
            let taskRequest = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
            taskRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "isComplete == NO"),
                NSPredicate(format: "parentTaskID == nil"),
                NSCompoundPredicate(orPredicateWithSubpredicates: [
                    NSPredicate(format: "unscheduledDispositionRaw == nil"),
                    NSPredicate(
                        format: "unscheduledDispositionRaw != %@",
                        UnscheduledDisposition.deleted.rawValue
                    )
                ])
            ])
            taskRequest.sortDescriptors = [
                NSSortDescriptor(key: "dueDate", ascending: true),
                NSSortDescriptor(key: "sortOrder", ascending: true),
                NSSortDescriptor(key: "title", ascending: true)
            ]
            taskRequest.fetchBatchSize = 250
            let tasks = try context.fetch(taskRequest)
            let taskIDs = Set(tasks.compactMap { $0.value(forKey: "id") as? UUID })

            let projectIDs = Set(tasks.compactMap { $0.value(forKey: "projectID") as? UUID })
            let projectRequest = NSFetchRequest<NSManagedObject>(entityName: "Project")
            projectRequest.predicate = projectIDs.isEmpty
                ? NSPredicate(value: false)
                : NSPredicate(format: "id IN %@", Array(projectIDs))
            let projectModes: [(UUID, ProjectExecutionMode)] = try context.fetch(projectRequest).compactMap { project -> (UUID, ProjectExecutionMode)? in
                guard let id = project.value(forKey: "id") as? UUID else { return nil }
                let mode = (project.value(forKey: "executionModeRaw") as? String)
                    .flatMap(ProjectExecutionMode.init(rawValue:)) ?? .parallel
                return (id, mode)
            }
            let executionModeByProjectID: [UUID: ProjectExecutionMode] = Dictionary(uniqueKeysWithValues: projectModes)

            let dependencyRequest = NSFetchRequest<NSManagedObject>(entityName: "TaskDependency")
            dependencyRequest.predicate = taskIDs.isEmpty
                ? NSPredicate(value: false)
                : NSPredicate(format: "taskID IN %@", Array(taskIDs))
            let dependencies = try context.fetch(dependencyRequest)
            let prerequisiteIDs = Set(dependencies.compactMap { $0.value(forKey: "dependsOnTaskID") as? UUID })

            let completedRequest = NSFetchRequest<NSManagedObject>(entityName: "TaskDefinition")
            completedRequest.predicate = prerequisiteIDs.isEmpty
                ? NSPredicate(value: false)
                : NSPredicate(format: "id IN %@ AND isComplete == YES", Array(prerequisiteIDs))
            let completedIDs = Set(try context.fetch(completedRequest).compactMap { $0.value(forKey: "id") as? UUID })
            let unresolvedByTask = Dictionary(grouping: dependencies) { dependency in
                dependency.value(forKey: "taskID") as? UUID
            }

            var summaries = tasks.compactMap { object -> PlanningTaskSummary? in
                guard let id = object.value(forKey: "id") as? UUID else { return nil }
                let metadata = Self.taskMetadata(object) ?? PlanningTaskMetadata(taskID: id)
                let taskDependencies = unresolvedByTask[id] ?? []
                let dependenciesReady = taskDependencies.allSatisfy { dependency in
                    guard let prerequisiteID = dependency.value(forKey: "dependsOnTaskID") as? UUID else { return true }
                    return completedIDs.contains(prerequisiteID)
                }
                let rawEstimate = (object.value(forKey: "estimatedDuration") as? NSNumber)?.doubleValue
                let projectID = object.value(forKey: "projectID") as? UUID
                return PlanningTaskSummary(
                    id: id,
                    title: (object.value(forKey: "title") as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? "Untitled task",
                    projectID: projectID,
                    dueDate: object.value(forKey: "dueDate") as? Date,
                    estimatedDuration: rawEstimate.flatMap { $0 > 0 ? $0 : nil },
                    metadata: metadata,
                    dependenciesReady: dependenciesReady,
                    priority: Self.focusPriority(object.value(forKey: "priority")),
                    requiredEnergy: Self.energyLevel(object.value(forKey: "energy")),
                    locationContext: object.value(forKey: "context") as? String,
                    scheduledStartAt: object.value(forKey: "scheduledStartAt") as? Date,
                    scheduledEndAt: object.value(forKey: "scheduledEndAt") as? Date,
                    alignsWithWeeklyOutcome: object.value(forKey: "weeklyOutcomeID") as? UUID != nil,
                    projectExecutionMode: projectID.flatMap { executionModeByProjectID[$0] } ?? .parallel
                )
            }

            // Sequential projects expose only their first dependency-ready task as actionable.
            var firstReadyTaskByProject: [UUID: UUID] = [:]
            for summary in summaries where summary.projectExecutionMode == .sequential && summary.dependenciesReady {
                guard let projectID = summary.projectID, firstReadyTaskByProject[projectID] == nil else { continue }
                firstReadyTaskByProject[projectID] = summary.id
            }
            for index in summaries.indices where summaries[index].projectExecutionMode == .sequential {
                guard let projectID = summaries[index].projectID else { continue }
                summaries[index].dependenciesReady = summaries[index].dependenciesReady
                    && firstReadyTaskByProject[projectID] == summaries[index].id
            }
            return summaries
        }
    }

    public func fetchPlanningProjects() async throws -> [PlanningProjectSummary] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "Project")
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            return try context.fetch(request).compactMap { object in
                guard let id = object.value(forKey: "id") as? UUID,
                      let rawName = object.value(forKey: "name") as? String else { return nil }
                let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard name.isEmpty == false else { return nil }
                return PlanningProjectSummary(
                    id: id,
                    name: name,
                    isArchived: (object.value(forKey: "isArchived") as? NSNumber)?.boolValue ?? false
                )
            }
        }
    }

    public func fetchTimeBlocks(from: Date, to: Date) async throws -> [InternalTimeBlock] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "InternalTimeBlock")
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "startAt < %@", to as NSDate),
                NSPredicate(format: "endAt > %@", from as NSDate)
            ])
            request.sortDescriptors = [NSSortDescriptor(key: "startAt", ascending: true)]
            request.fetchBatchSize = 100
            return try context.fetch(request).compactMap(Self.timeBlock)
        }
    }

    public func saveTimeBlock(_ value: InternalTimeBlock) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "InternalTimeBlock", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.title.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "title")
            object.setValue(value.startAt, forKey: "startAt")
            object.setValue(value.endAt, forKey: "endAt")
            object.setValue(value.taskID, forKey: "taskID")
            object.setValue(value.planningContext.rawValue, forKey: "planningContextRaw")
            object.setValue(value.isFixed, forKey: "isFixed")
            object.setValue(value.createdAt, forKey: "createdAt")
            object.setValue(value.updatedAt, forKey: "updatedAt")
        }
    }

    public func deleteTimeBlock(id: UUID) async throws {
        try await write { context in
            if let object = try Self.fetchOne(entity: "InternalTimeBlock", id: id, in: context) {
                context.delete(object)
            }
        }
    }

    public func fetchWorkingHoursProfiles() async throws -> [WorkingHoursProfile] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "WorkingHoursProfile")
            request.sortDescriptors = [
                NSSortDescriptor(key: "isDefault", ascending: false),
                NSSortDescriptor(key: "name", ascending: true)
            ]
            return try context.fetch(request).compactMap(Self.workingHoursProfile)
        }
    }

    public func saveWorkingHoursProfile(_ value: WorkingHoursProfile) async throws {
        try await write { context in
            if value.isDefault {
                let request = NSFetchRequest<NSManagedObject>(entityName: "WorkingHoursProfile")
                request.predicate = NSPredicate(format: "isDefault == YES AND id != %@", value.id as CVarArg)
                try context.fetch(request).forEach { $0.setValue(false, forKey: "isDefault") }
            }
            let object = try Self.upsert(entity: "WorkingHoursProfile", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.name, forKey: "name")
            object.setValue(try JSONEncoder().encode(value.intervalsByWeekday), forKey: "intervalsData")
            object.setValue(value.bufferDuration, forKey: "bufferDuration")
            object.setValue(value.isDefault, forKey: "isDefault")
            object.setValue(value.updatedAt, forKey: "updatedAt")
        }
    }

    public func prepare(_ mutation: PlanMutation, source: String, summary: String) async throws -> PlanMutationReceipt {
        let receipt = PlanMutationReceipt(
            id: UUID(),
            source: source,
            summary: summary,
            forwardData: try JSONEncoder().encode(mutation),
            undoData: try JSONEncoder().encode(mutation.inverse),
            createdAt: Date()
        )
        try await write { context in
            let object = NSEntityDescription.insertNewObject(forEntityName: "PlanningMutationReceipt", into: context)
            object.setValue(receipt.id, forKey: "id")
            object.setValue(receipt.source, forKey: "source")
            object.setValue(receipt.summary, forKey: "summary")
            object.setValue(receipt.forwardData, forKey: "forwardData")
            object.setValue(receipt.undoData, forKey: "undoData")
            object.setValue(receipt.createdAt, forKey: "createdAt")
            object.setValue("prepared", forKey: "stateRaw")
        }
        return receipt
    }

    public func apply(receiptID: UUID) async throws {
        try await write { context in
            guard let receipt = try Self.fetchOne(entity: "PlanningMutationReceipt", id: receiptID, in: context),
                  receipt.value(forKey: "stateRaw") as? String != "applied" else { return }
            guard let data = receipt.value(forKey: "forwardData") as? Data else { return }
            let mutation = try JSONDecoder().decode(PlanMutation.self, from: data)
            try Self.apply(mutation, in: context)
            receipt.setValue("applied", forKey: "stateRaw")
            receipt.setValue(Date(), forKey: "appliedAt")
            receipt.setValue(nil, forKey: "undoneAt")
        }
    }

    public func undo(receiptID: UUID) async throws {
        try await write { context in
            guard let receipt = try Self.fetchOne(entity: "PlanningMutationReceipt", id: receiptID, in: context),
                  receipt.value(forKey: "stateRaw") as? String == "applied" else { return }
            guard let data = receipt.value(forKey: "undoData") as? Data else { return }
            let mutation = try JSONDecoder().decode(PlanMutation.self, from: data)
            try Self.apply(mutation, in: context)
            receipt.setValue("undone", forKey: "stateRaw")
            receipt.setValue(Date(), forKey: "undoneAt")
        }
    }

    public func hasAppliedReceipt(source: String) async throws -> Bool {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "PlanningMutationReceipt")
            request.fetchLimit = 1
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "source == %@", source),
                NSPredicate(format: "stateRaw == %@", "applied")
            ])
            return try context.count(for: request) > 0
        }
    }

    public func fetchMutationReceipts(since: Date? = nil) async throws -> [PlanningReceiptRecord] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "PlanningMutationReceipt")
            if let since { request.predicate = NSPredicate(format: "createdAt >= %@", since as NSDate) }
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            request.fetchBatchSize = 200
            return try context.fetch(request).compactMap { object in
                guard let id = object.value(forKey: "id") as? UUID,
                      let source = object.value(forKey: "source") as? String,
                      let summary = object.value(forKey: "summary") as? String,
                      let forwardData = object.value(forKey: "forwardData") as? Data,
                      let undoData = object.value(forKey: "undoData") as? Data,
                      let createdAt = object.value(forKey: "createdAt") as? Date else { return nil }
                let receipt = PlanMutationReceipt(
                    id: id,
                    source: source,
                    summary: summary,
                    forwardData: forwardData,
                    undoData: undoData,
                    createdAt: createdAt
                )
                let state = (object.value(forKey: "stateRaw") as? String)
                    .flatMap(PlanningReceiptState.init(rawValue:)) ?? .prepared
                return PlanningReceiptRecord(
                    receipt: receipt,
                    state: state,
                    appliedAt: object.value(forKey: "appliedAt") as? Date,
                    undoneAt: object.value(forKey: "undoneAt") as? Date
                )
            }
        }
    }

    public func activeSession() async throws -> FocusSessionV2? {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "FocusSession")
            request.predicate = NSPredicate(format: "stateRaw IN %@", [FocusSessionState.running.rawValue, FocusSessionState.paused.rawValue])
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            request.fetchLimit = 1
            return try context.fetch(request).first.flatMap(Self.focusSession)
        }
    }

    public func session(id: UUID) async throws -> FocusSessionV2? {
        try await read { context in
            try Self.fetchOne(entity: "FocusSession", id: id, in: context).flatMap(Self.focusSession)
        }
    }

    public func sessions(since: Date? = nil) async throws -> [FocusSessionV2] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "FocusSession")
            if let since { request.predicate = NSPredicate(format: "startedAt >= %@", since as NSDate) }
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            request.fetchBatchSize = 200
            return try context.fetch(request).compactMap(Self.focusSession)
        }
    }

    public func commandReceipts(since: Date? = nil) async throws -> [FocusCommandReceipt] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "FocusSession")
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            request.fetchBatchSize = 200
            return try context.fetch(request)
                .flatMap(Self.focusCommandReceipts)
                .filter { receipt in
                    since.map { threshold in threshold <= receipt.occurredAt } ?? true
                }
                .sorted {
                    if $0.occurredAt != $1.occurredAt { return $0.occurredAt > $1.occurredAt }
                    return $0.id.uuidString < $1.id.uuidString
                }
        }
    }

    public func start(
        taskID: UUID?,
        timeBlockID: UUID?,
        targetDuration: TimeInterval,
        at: Date
    ) async throws -> FocusSessionV2 {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        return try await context.perform {
            let activeRequest = NSFetchRequest<NSManagedObject>(entityName: "FocusSession")
            activeRequest.predicate = NSPredicate(format: "stateRaw IN %@", [FocusSessionState.running.rawValue, FocusSessionState.paused.rawValue])
            activeRequest.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            activeRequest.fetchLimit = 1
            if let active = try context.fetch(activeRequest).first.flatMap(Self.focusSession) { return active }

            let session = FocusSessionV2(
                taskID: taskID,
                timeBlockID: timeBlockID,
                targetDuration: targetDuration,
                startedAt: at
            )
            let object = NSEntityDescription.insertNewObject(forEntityName: "FocusSession", into: context)
            try Self.write(session, to: object)
            try context.save()
            return session
        }
    }

    public func handle(_ command: FocusSessionCommand) async throws -> FocusSessionV2 {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        return try await context.perform {
            guard let object = try Self.fetchOne(entity: "FocusSession", id: command.sessionID, in: context),
                  let current = Self.focusSession(object) else {
                throw PlanningPersistenceError.taskNotFound(command.sessionID)
            }
            let wasApplied = Self.focusCommandCanApply(command, to: current)
            let updated = FocusSessionStateMachine.applying(command, to: current)
            var receipts = Self.focusCommandReceipts(object)
            if receipts.contains(where: { $0.id == command.id }) == false {
                receipts.append(FocusCommandReceipt(
                    id: command.id,
                    sessionID: command.sessionID,
                    kind: command.kind,
                    occurredAt: command.occurredAt,
                    resultingState: updated.state,
                    focusedDuration: updated.focusedDuration(at: command.occurredAt),
                    wasApplied: wasApplied
                ))
            }
            try Self.write(updated, to: object, commandReceipts: receipts)
            if context.hasChanges { try context.save() }
            return updated
        }
    }

    private func read<T: Sendable>(
        _ operation: @escaping @Sendable (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        return try await context.perform { try operation(context) }
    }

    private func write(
        _ operation: @escaping @Sendable (NSManagedObjectContext) throws -> Void
    ) async throws {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        try await context.perform {
            try operation(context)
            if context.hasChanges { try context.save() }
        }
    }

    private static func fetchOne(
        entity: String,
        id: UUID,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func upsert(
        entity: String,
        id: UUID,
        in context: NSManagedObjectContext
    ) throws -> NSManagedObject {
        if let object = try fetchOne(entity: entity, id: id, in: context) { return object }
        return NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
    }

    private static func taskMetadata(_ object: NSManagedObject) -> PlanningTaskMetadata? {
        guard let taskID = object.value(forKey: "id") as? UUID else { return nil }
        let year = (object.value(forKey: "planningDayYear") as? NSNumber)?.intValue
        let month = (object.value(forKey: "planningDayMonth") as? NSNumber)?.intValue
        let day = (object.value(forKey: "planningDayDay") as? NSNumber)?.intValue
        let timeZone = object.value(forKey: "planningDayTimeZoneIdentifier") as? String
        let planningDay: PlanningDay?
        if let year, let month, let day, let timeZone {
            planningDay = PlanningDay(year: year, month: month, day: day, timeZoneIdentifier: timeZone)
        } else {
            planningDay = nil
        }
        return PlanningTaskMetadata(
            taskID: taskID,
            planningDay: planningDay,
            commitmentLevel: (object.value(forKey: "commitmentLevelRaw") as? String)
                .flatMap(TaskCommitmentLevel.init(rawValue:)) ?? .standard,
            availability: (object.value(forKey: "availabilityRaw") as? String)
                .flatMap(TaskAvailability.init(rawValue:)) ?? .actionable,
            planningContext: (object.value(forKey: "planningContextRaw") as? String)
                .flatMap(PlanningContext.init(rawValue:)) ?? .neutral,
            unscheduledDisposition: (object.value(forKey: "unscheduledDispositionRaw") as? String)
                .flatMap(UnscheduledDisposition.init(rawValue:)) ?? .inbox,
            availabilityExplanation: object.value(forKey: "availabilityExplanation") as? String,
            resumeDate: object.value(forKey: "planningResumeDate") as? Date,
            pinOrder: (object.value(forKey: "planningPinOrder") as? NSNumber)?.intValue,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? .distantPast
        )
    }

    private static func apply(_ mutation: PlanMutation, in context: NSManagedObjectContext) throws {
        switch mutation {
        case .saveTaskMetadata(_, let metadata):
            guard let task = try fetchOne(entity: "TaskDefinition", id: metadata.taskID, in: context) else {
                throw PlanningPersistenceError.taskNotFound(metadata.taskID)
            }
            task.setValue(metadata.planningDay?.year, forKey: "planningDayYear")
            task.setValue(metadata.planningDay?.month, forKey: "planningDayMonth")
            task.setValue(metadata.planningDay?.day, forKey: "planningDayDay")
            task.setValue(metadata.planningDay?.timeZoneIdentifier, forKey: "planningDayTimeZoneIdentifier")
            task.setValue(metadata.commitmentLevel.rawValue, forKey: "commitmentLevelRaw")
            task.setValue(metadata.availability.rawValue, forKey: "availabilityRaw")
            task.setValue(metadata.planningContext.rawValue, forKey: "planningContextRaw")
            task.setValue(metadata.unscheduledDisposition.rawValue, forKey: "unscheduledDispositionRaw")
            task.setValue(metadata.availabilityExplanation, forKey: "availabilityExplanation")
            task.setValue(metadata.resumeDate, forKey: "planningResumeDate")
            task.setValue(metadata.pinOrder, forKey: "planningPinOrder")
            task.setValue(metadata.updatedAt, forKey: "updatedAt")
        case .saveTimeBlock(_, let block):
            let object = try upsert(entity: "InternalTimeBlock", id: block.id, in: context)
            object.setValue(block.id, forKey: "id")
            object.setValue(block.title, forKey: "title")
            object.setValue(block.startAt, forKey: "startAt")
            object.setValue(block.endAt, forKey: "endAt")
            object.setValue(block.taskID, forKey: "taskID")
            object.setValue(block.planningContext.rawValue, forKey: "planningContextRaw")
            object.setValue(block.isFixed, forKey: "isFixed")
            object.setValue(block.createdAt, forKey: "createdAt")
            object.setValue(block.updatedAt, forKey: "updatedAt")
        case .deleteTimeBlock(let block):
            if let object = try fetchOne(entity: "InternalTimeBlock", id: block.id, in: context) {
                context.delete(object)
            }
        case .batch(let mutations):
            for mutation in mutations { try apply(mutation, in: context) }
        }
    }

    private static func focusSession(_ object: NSManagedObject) -> FocusSessionV2? {
        guard let id = object.value(forKey: "id") as? UUID,
              let startedAt = object.value(forKey: "startedAt") as? Date else { return nil }
        let commandIDs: Set<UUID>
        if let data = object.value(forKey: "appliedCommandIDsData") as? Data {
            commandIDs = (try? JSONDecoder().decode(FocusCommandLedger.self, from: data).appliedCommandIDs)
                ?? (try? JSONDecoder().decode(Set<UUID>.self, from: data))
                ?? []
        } else {
            commandIDs = []
        }
        return FocusSessionV2(
            id: id,
            taskID: object.value(forKey: "taskID") as? UUID,
            timeBlockID: object.value(forKey: "timeBlockID") as? UUID,
            targetDuration: (object.value(forKey: "targetDurationSeconds") as? NSNumber)?.doubleValue ?? 0,
            state: (object.value(forKey: "stateRaw") as? String).flatMap(FocusSessionState.init(rawValue:)) ?? .ended,
            startedAt: startedAt,
            pausedAt: object.value(forKey: "pausedAt") as? Date,
            endedAt: object.value(forKey: "endedAt") as? Date,
            accumulatedPauseDuration: (object.value(forKey: "accumulatedPauseDuration") as? NSNumber)?.doubleValue ?? 0,
            interruptionCount: (object.value(forKey: "interruptionCount") as? NSNumber)?.intValue ?? 0,
            outcome: (object.value(forKey: "completionOutcomeRaw") as? String).flatMap(FocusCompletionOutcome.init(rawValue:)),
            energyAfter: (object.value(forKey: "energyAfter") as? NSNumber)?.intValue,
            reflection: object.value(forKey: "reflection") as? String,
            appliedCommandIDs: commandIDs
        )
    }

    private static func focusCommandReceipts(_ object: NSManagedObject) -> [FocusCommandReceipt] {
        guard let data = object.value(forKey: "appliedCommandIDsData") as? Data else { return [] }
        return (try? JSONDecoder().decode(FocusCommandLedger.self, from: data).receipts) ?? []
    }

    private static func focusCommandCanApply(
        _ command: FocusSessionCommand,
        to session: FocusSessionV2
    ) -> Bool {
        guard command.sessionID == session.id,
              session.appliedCommandIDs.contains(command.id) == false else { return false }
        return switch command.kind {
        case .pause:
            session.state == .running
        case .resume:
            session.state == .paused && session.pausedAt != nil
        case .end(_):
            session.state != .ended
        }
    }

    private static func write(
        _ session: FocusSessionV2,
        to object: NSManagedObject,
        commandReceipts: [FocusCommandReceipt] = []
    ) throws {
        object.setValue(session.id, forKey: "id")
        object.setValue(session.taskID, forKey: "taskID")
        object.setValue(session.timeBlockID, forKey: "timeBlockID")
        object.setValue(session.startedAt, forKey: "startedAt")
        object.setValue(session.pausedAt, forKey: "pausedAt")
        object.setValue(session.endedAt, forKey: "endedAt")
        object.setValue(Int32(session.targetDuration.rounded()), forKey: "targetDurationSeconds")
        object.setValue(session.accumulatedPauseDuration, forKey: "accumulatedPauseDuration")
        object.setValue(session.interruptionCount, forKey: "interruptionCount")
        object.setValue(session.focusedDuration(), forKey: "actualFocusedDuration")
        object.setValue(Int32(session.focusedDuration().rounded()), forKey: "durationSeconds")
        object.setValue(session.outcome?.rawValue, forKey: "completionOutcomeRaw")
        object.setValue(session.outcome == .completed, forKey: "wasCompleted")
        object.setValue(session.energyAfter, forKey: "energyAfter")
        object.setValue(session.reflection, forKey: "reflection")
        object.setValue(session.state.rawValue, forKey: "stateRaw")
        let ledger = FocusCommandLedger(
            appliedCommandIDs: session.appliedCommandIDs,
            receipts: commandReceipts.sorted {
                if $0.occurredAt != $1.occurredAt { return $0.occurredAt < $1.occurredAt }
                return $0.id.uuidString < $1.id.uuidString
            }
        )
        object.setValue(try JSONEncoder().encode(ledger), forKey: "appliedCommandIDsData")
        object.setValue(object.value(forKey: "createdAt") as? Date ?? session.startedAt, forKey: "createdAt")
    }

    private static func timeBlock(_ object: NSManagedObject) -> InternalTimeBlock? {
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

    private static func workingHoursProfile(_ object: NSManagedObject) -> WorkingHoursProfile? {
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

    private static func focusPriority(_ value: Any?) -> FocusPriorityBand {
        switch (value as? NSNumber)?.intValue ?? 1 {
        case ...0: .low
        case 1: .medium
        case 2: .high
        default: .urgent
        }
    }

    private static func energyLevel(_ value: Any?) -> Int? {
        guard let raw = (value as? String)?.lowercased() else { return nil }
        if let numeric = Int(raw) { return min(5, max(1, numeric)) }
        return switch raw {
        case "low": 1
        case "medium", "moderate": 3
        case "high": 5
        default: nil
        }
    }
}

public actor SystemPlanningCalendarContextRepository: PlanningCalendarContextRepository {
    private let eventStore: EKEventStore

    public init(eventStore: EKEventStore = EKEventStore()) {
        self.eventStore = eventStore
    }

    public func authorization() -> PlanningCalendarAuthorization {
        Self.authorization(EKEventStore.authorizationStatus(for: .event))
    }

    public func requestAccess() async -> PlanningCalendarAuthorization {
        do {
            _ = try await eventStore.requestFullAccessToEvents()
        } catch {
            return Self.authorization(EKEventStore.authorizationStatus(for: .event))
        }
        return Self.authorization(EKEventStore.authorizationStatus(for: .event))
    }

    public func fetchCommitments(from: Date, to: Date) async throws -> PlanningCalendarContext {
        let status = authorization()
        guard status == .authorized, to > from else {
            return PlanningCalendarContext(authorization: status)
        }
        let predicate = eventStore.predicateForEvents(withStart: from, end: to, calendars: nil)
        let events = eventStore.events(matching: predicate).filter { $0.status != .canceled }
        var commitments: [CalendarCommitment] = []
        commitments.reserveCapacity(events.count)
        for event in events {
            let calendarID = event.calendar.calendarIdentifier
            let identifier = event.eventIdentifier
                ?? "\(calendarID):\(event.startDate.timeIntervalSinceReferenceDate)"
            let title = event.title?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty
                ?? "Calendar event"
            commitments.append(CalendarCommitment(
                id: identifier,
                calendarID: calendarID,
                title: title,
                startAt: event.startDate,
                endAt: event.endDate,
                isAllDay: event.isAllDay,
                availability: String(event.availability.rawValue)
            ))
        }
        commitments.sort { lhs, rhs in
            lhs.startAt == rhs.startAt ? lhs.id < rhs.id : lhs.startAt < rhs.startAt
        }
        return PlanningCalendarContext(authorization: status, commitments: commitments)
    }

    private static func authorization(_ status: EKAuthorizationStatus) -> PlanningCalendarAuthorization {
        switch status {
        case .notDetermined: .notDetermined
        case .restricted: .restricted
        case .denied, .writeOnly: .denied
        case .fullAccess, .authorized: .authorized
        @unknown default: .unavailable
        }
    }
}

public struct UnavailablePlanningCalendarContextRepository: PlanningCalendarContextRepository {
    public init() {}
    public func authorization() async -> PlanningCalendarAuthorization { .unavailable }
    public func requestAccess() async -> PlanningCalendarAuthorization { .unavailable }
    public func fetchCommitments(from: Date, to: Date) async throws -> PlanningCalendarContext {
        PlanningCalendarContext(authorization: .unavailable)
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
