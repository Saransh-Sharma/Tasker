import CoreData
import Foundation

private enum WeeklyRepositoryCalendar {
    static func normalizedWeekStart(for date: Date) -> Date {
        let weekStartsOn = TaskerWorkspacePreferencesStore.shared.load().weekStartsOn
        return XPCalculationEngine.startOfWeek(for: date, startingOn: weekStartsOn)
    }

    static func normalizedWeekEnd(for weekStartDate: Date) -> Date {
        let weekStartsOn = TaskerWorkspacePreferencesStore.shared.load().weekStartsOn
        let normalizedStart = normalizedWeekStart(for: weekStartDate)
        return XPCalculationEngine.endOfWeek(for: normalizedStart, startingOn: weekStartsOn)
    }
}

public final class CoreDataWeeklyPlanRepository: WeeklyPlanRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func fetchPlan(id: UUID, completion: @escaping (Result<WeeklyPlan?, Error>) -> Void) {
        viewContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.viewContext,
                    entityName: "WeeklyPlan",
                    predicate: NSPredicate(format: "id == %@", id as CVarArg)
                )
                completion(.success(object.map(Self.mapWeeklyPlan)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchPlan(forWeekStarting weekStartDate: Date, completion: @escaping (Result<WeeklyPlan?, Error>) -> Void) {
        let normalizedWeekStart = WeeklyRepositoryCalendar.normalizedWeekStart(for: weekStartDate)
        viewContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.viewContext,
                    entityName: "WeeklyPlan",
                    predicate: NSPredicate(format: "weekStartDate == %@", normalizedWeekStart as NSDate),
                    sort: [NSSortDescriptor(key: "createdAt", ascending: true)]
                )
                completion(.success(object.map(Self.mapWeeklyPlan)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchPlans(from startDate: Date, to endDate: Date, completion: @escaping (Result<[WeeklyPlan], Error>) -> Void) {
        let normalizedStart = WeeklyRepositoryCalendar.normalizedWeekStart(for: startDate)
        let normalizedEnd = WeeklyRepositoryCalendar.normalizedWeekStart(for: endDate)
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "WeeklyPlan",
                    predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "weekStartDate >= %@", normalizedStart as NSDate),
                        NSPredicate(format: "weekStartDate <= %@", normalizedEnd as NSDate)
                    ]),
                    sort: [NSSortDescriptor(key: "weekStartDate", ascending: true)]
                )
                completion(.success(objects.map(Self.mapWeeklyPlan)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func savePlan(_ plan: WeeklyPlan, completion: @escaping (Result<WeeklyPlan, Error>) -> Void) {
        backgroundContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "WeeklyPlan",
                    id: plan.id
                )
                Self.apply(plan, to: object)
                try self.backgroundContext.save()
                completion(.success(Self.mapWeeklyPlan(object)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func mapWeeklyPlan(_ object: NSManagedObject) -> WeeklyPlan {
        let weekStartDate = (object.value(forKey: "weekStartDate") as? Date) ?? Date()
        let normalizedWeekStart = WeeklyRepositoryCalendar.normalizedWeekStart(for: weekStartDate)
        return WeeklyPlan(
            id: (object.value(forKey: "id") as? UUID) ?? UUID(),
            weekStartDate: normalizedWeekStart,
            weekEndDate: (object.value(forKey: "weekEndDate") as? Date)
                ?? WeeklyRepositoryCalendar.normalizedWeekEnd(for: normalizedWeekStart),
            focusStatement: object.value(forKey: "focusStatement") as? String,
            selectedHabitIDs: (object.value(forKey: "selectedHabitIDs") as? [UUID]) ?? [],
            targetCapacity: (object.value(forKey: "targetCapacity") as? Int32).map(Int.init),
            minimumViableWeekEnabled: (object.value(forKey: "minimumViableWeekEnabled") as? Bool) ?? false,
            reviewStatus: WeeklyPlanReviewStatus(rawValue: (object.value(forKey: "reviewStatus") as? String) ?? "") ?? .notStarted,
            createdAt: (object.value(forKey: "createdAt") as? Date) ?? Date(),
            updatedAt: (object.value(forKey: "updatedAt") as? Date) ?? Date()
        )
    }

    private static func apply(_ plan: WeeklyPlan, to object: NSManagedObject) {
        let normalizedWeekStart = WeeklyRepositoryCalendar.normalizedWeekStart(for: plan.weekStartDate)
        object.setValue(plan.id, forKey: "id")
        object.setValue(normalizedWeekStart, forKey: "weekStartDate")
        object.setValue(WeeklyRepositoryCalendar.normalizedWeekEnd(for: normalizedWeekStart), forKey: "weekEndDate")
        object.setValue(plan.focusStatement, forKey: "focusStatement")
        object.setValue(plan.selectedHabitIDs as NSArray, forKey: "selectedHabitIDs")
        object.setValue(plan.targetCapacity.map { Int32($0) }, forKey: "targetCapacity")
        object.setValue(plan.minimumViableWeekEnabled, forKey: "minimumViableWeekEnabled")
        object.setValue(plan.reviewStatus.rawValue, forKey: "reviewStatus")
        object.setValue(plan.createdAt, forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
    }
}

public final class CoreDataWeeklyOutcomeRepository: WeeklyOutcomeRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func fetchOutcomes(weeklyPlanID: UUID, completion: @escaping (Result<[WeeklyOutcome], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "WeeklyOutcome",
                    predicate: NSPredicate(format: "weeklyPlanID == %@", weeklyPlanID as CVarArg),
                    sort: [
                        NSSortDescriptor(key: "orderIndex", ascending: true),
                        NSSortDescriptor(key: "createdAt", ascending: true)
                    ]
                )
                completion(.success(objects.map(Self.mapWeeklyOutcome)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func saveOutcome(_ outcome: WeeklyOutcome, completion: @escaping (Result<WeeklyOutcome, Error>) -> Void) {
        backgroundContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "WeeklyOutcome",
                    id: outcome.id
                )
                Self.apply(outcome, to: object)
                try self.backgroundContext.save()
                completion(.success(Self.mapWeeklyOutcome(object)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func replaceOutcomes(
        weeklyPlanID: UUID,
        outcomes: [WeeklyOutcome],
        completion: @escaping (Result<[WeeklyOutcome], Error>) -> Void
    ) {
        backgroundContext.perform {
            do {
                let existingObjects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.backgroundContext,
                    entityName: "WeeklyOutcome",
                    predicate: NSPredicate(format: "weeklyPlanID == %@", weeklyPlanID as CVarArg)
                )
                let incomingIDs = Set(outcomes.map(\.id))
                for object in existingObjects {
                    if let id = object.value(forKey: "id") as? UUID, incomingIDs.contains(id) == false {
                        self.backgroundContext.delete(object)
                    }
                }

                for (index, outcome) in outcomes.enumerated() {
                    let object = try V2CoreDataRepositorySupport.upsertByID(
                        in: self.backgroundContext,
                        entityName: "WeeklyOutcome",
                        id: outcome.id
                    )
                    var normalizedOutcome = outcome
                    normalizedOutcome.weeklyPlanID = weeklyPlanID
                    normalizedOutcome.orderIndex = index
                    Self.apply(normalizedOutcome, to: object)
                }

                try self.backgroundContext.save()

                let persistedObjects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.backgroundContext,
                    entityName: "WeeklyOutcome",
                    predicate: NSPredicate(format: "weeklyPlanID == %@", weeklyPlanID as CVarArg),
                    sort: [
                        NSSortDescriptor(key: "orderIndex", ascending: true),
                        NSSortDescriptor(key: "createdAt", ascending: true)
                    ]
                )
                completion(.success(persistedObjects.map(Self.mapWeeklyOutcome)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func deleteOutcome(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                if let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.backgroundContext,
                    entityName: "WeeklyOutcome",
                    predicate: NSPredicate(format: "id == %@", id as CVarArg)
                ) {
                    self.backgroundContext.delete(object)
                    try self.backgroundContext.save()
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func mapWeeklyOutcome(_ object: NSManagedObject) -> WeeklyOutcome {
        WeeklyOutcome(
            id: (object.value(forKey: "id") as? UUID) ?? UUID(),
            weeklyPlanID: (object.value(forKey: "weeklyPlanID") as? UUID) ?? UUID(),
            sourceProjectID: object.value(forKey: "sourceProjectID") as? UUID,
            title: (object.value(forKey: "title") as? String) ?? "Untitled Outcome",
            whyItMatters: object.value(forKey: "whyItMatters") as? String,
            successDefinition: object.value(forKey: "successDefinition") as? String,
            status: WeeklyOutcomeStatus(rawValue: (object.value(forKey: "status") as? String) ?? "") ?? .planned,
            orderIndex: max(0, Int((object.value(forKey: "orderIndex") as? Int32) ?? 0)),
            createdAt: (object.value(forKey: "createdAt") as? Date) ?? Date(),
            updatedAt: (object.value(forKey: "updatedAt") as? Date) ?? Date()
        )
    }

    private static func apply(_ outcome: WeeklyOutcome, to object: NSManagedObject) {
        object.setValue(outcome.id, forKey: "id")
        object.setValue(outcome.weeklyPlanID, forKey: "weeklyPlanID")
        object.setValue(outcome.sourceProjectID, forKey: "sourceProjectID")
        object.setValue(outcome.title, forKey: "title")
        object.setValue(outcome.whyItMatters, forKey: "whyItMatters")
        object.setValue(outcome.successDefinition, forKey: "successDefinition")
        object.setValue(outcome.status.rawValue, forKey: "status")
        object.setValue(Int32(max(0, outcome.orderIndex)), forKey: "orderIndex")
        object.setValue(outcome.createdAt, forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
    }
}

public final class CoreDataWeeklyReviewRepository: WeeklyReviewRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func fetchReview(weeklyPlanID: UUID, completion: @escaping (Result<WeeklyReview?, Error>) -> Void) {
        viewContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.viewContext,
                    entityName: "WeeklyReview",
                    predicate: NSPredicate(format: "weeklyPlanID == %@", weeklyPlanID as CVarArg),
                    sort: [NSSortDescriptor(key: "createdAt", ascending: true)]
                )
                completion(.success(object.map(Self.mapWeeklyReview)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func saveReview(_ review: WeeklyReview, completion: @escaping (Result<WeeklyReview, Error>) -> Void) {
        backgroundContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "WeeklyReview",
                    id: review.id
                )
                Self.apply(review, to: object)
                try self.backgroundContext.save()
                completion(.success(Self.mapWeeklyReview(object)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func mapWeeklyReview(_ object: NSManagedObject) -> WeeklyReview {
        WeeklyReview(
            id: (object.value(forKey: "id") as? UUID) ?? UUID(),
            weeklyPlanID: (object.value(forKey: "weeklyPlanID") as? UUID) ?? UUID(),
            wins: object.value(forKey: "wins") as? String,
            blockers: object.value(forKey: "blockers") as? String,
            lessons: object.value(forKey: "lessons") as? String,
            nextWeekPrepNotes: object.value(forKey: "nextWeekPrepNotes") as? String,
            perceivedWeekRating: (object.value(forKey: "perceivedWeekRating") as? Int32).map(Int.init),
            createdAt: (object.value(forKey: "createdAt") as? Date) ?? Date(),
            updatedAt: (object.value(forKey: "updatedAt") as? Date) ?? Date(),
            completedAt: object.value(forKey: "completedAt") as? Date
        )
    }

    private static func apply(_ review: WeeklyReview, to object: NSManagedObject) {
        object.setValue(review.id, forKey: "id")
        object.setValue(review.weeklyPlanID, forKey: "weeklyPlanID")
        object.setValue(review.wins, forKey: "wins")
        object.setValue(review.blockers, forKey: "blockers")
        object.setValue(review.lessons, forKey: "lessons")
        object.setValue(review.nextWeekPrepNotes, forKey: "nextWeekPrepNotes")
        object.setValue(review.perceivedWeekRating.map { Int32($0) }, forKey: "perceivedWeekRating")
        object.setValue(review.createdAt, forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
        object.setValue(review.completedAt, forKey: "completedAt")
    }
}

public final class CoreDataReflectionNoteRepository: ReflectionNoteRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func fetchNotes(query: ReflectionNoteQuery, completion: @escaping (Result<[ReflectionNote], Error>) -> Void) {
        viewContext.perform {
            do {
                let request = NSFetchRequest<NSManagedObject>(entityName: "ReflectionNote")
                request.predicate = Self.predicate(for: query)
                request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
                if let limit = query.limit, limit > 0 {
                    request.fetchLimit = limit
                }
                let objects = try self.viewContext.fetch(request)
                completion(.success(objects.map(Self.mapReflectionNote)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func saveNote(_ note: ReflectionNote, completion: @escaping (Result<ReflectionNote, Error>) -> Void) {
        backgroundContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "ReflectionNote",
                    id: note.id
                )
                Self.apply(note, to: object)
                try self.backgroundContext.save()
                completion(.success(Self.mapReflectionNote(object)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func deleteNote(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                if let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.backgroundContext,
                    entityName: "ReflectionNote",
                    predicate: NSPredicate(format: "id == %@", id as CVarArg)
                ) {
                    self.backgroundContext.delete(object)
                    try self.backgroundContext.save()
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func predicate(for query: ReflectionNoteQuery) -> NSPredicate? {
        var predicates: [NSPredicate] = []
        if let linkedTaskID = query.linkedTaskID {
            predicates.append(NSPredicate(format: "linkedTaskID == %@", linkedTaskID as CVarArg))
        }
        if let linkedProjectID = query.linkedProjectID {
            predicates.append(NSPredicate(format: "linkedProjectID == %@", linkedProjectID as CVarArg))
        }
        if let linkedHabitID = query.linkedHabitID {
            predicates.append(NSPredicate(format: "linkedHabitID == %@", linkedHabitID as CVarArg))
        }
        if let linkedWeeklyPlanID = query.linkedWeeklyPlanID {
            predicates.append(NSPredicate(format: "linkedWeeklyPlanID == %@", linkedWeeklyPlanID as CVarArg))
        }
        if query.kinds.isEmpty == false {
            predicates.append(NSPredicate(format: "kind IN %@", query.kinds.map(\.rawValue)))
        }
        guard predicates.isEmpty == false else {
            return nil
        }
        return NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
    }

    private static func mapReflectionNote(_ object: NSManagedObject) -> ReflectionNote {
        ReflectionNote(
            id: (object.value(forKey: "id") as? UUID) ?? UUID(),
            kind: ReflectionNoteKind(rawValue: (object.value(forKey: "kind") as? String) ?? "") ?? .freeform,
            linkedTaskID: object.value(forKey: "linkedTaskID") as? UUID,
            linkedProjectID: object.value(forKey: "linkedProjectID") as? UUID,
            linkedHabitID: object.value(forKey: "linkedHabitID") as? UUID,
            linkedWeeklyPlanID: object.value(forKey: "linkedWeeklyPlanID") as? UUID,
            energy: (object.value(forKey: "energy") as? Int16).map(Int.init),
            mood: (object.value(forKey: "mood") as? Int16).map(Int.init),
            prompt: object.value(forKey: "prompt") as? String,
            noteText: (object.value(forKey: "noteText") as? String) ?? "",
            createdAt: (object.value(forKey: "createdAt") as? Date) ?? Date(),
            updatedAt: (object.value(forKey: "updatedAt") as? Date) ?? Date()
        )
    }

    private static func apply(_ note: ReflectionNote, to object: NSManagedObject) {
        object.setValue(note.id, forKey: "id")
        object.setValue(note.kind.rawValue, forKey: "kind")
        object.setValue(note.linkedTaskID, forKey: "linkedTaskID")
        object.setValue(note.linkedProjectID, forKey: "linkedProjectID")
        object.setValue(note.linkedHabitID, forKey: "linkedHabitID")
        object.setValue(note.linkedWeeklyPlanID, forKey: "linkedWeeklyPlanID")
        object.setValue(note.energy.map { Int16($0) }, forKey: "energy")
        object.setValue(note.mood.map { Int16($0) }, forKey: "mood")
        object.setValue(note.prompt, forKey: "prompt")
        object.setValue(note.noteText, forKey: "noteText")
        object.setValue(note.createdAt, forKey: "createdAt")
        object.setValue(Date(), forKey: "updatedAt")
    }
}

public final class CoreDataWeeklyReviewMutationRepository: WeeklyReviewMutationRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func finalizeReview(
        request: CompleteWeeklyReviewRequest,
        completion: @escaping (Result<CompleteWeeklyReviewResult, Error>) -> Void
    ) {
        backgroundContext.perform {
            do {
                guard let planObject = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "WeeklyPlan",
                    predicate: NSPredicate(format: "id == %@", request.weeklyPlanID as CVarArg),
                    sort: [NSSortDescriptor(key: "createdAt", ascending: true)]
                ) else {
                    completion(.failure(NSError(
                        domain: "CoreDataWeeklyReviewMutationRepository",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Weekly plan not found."]
                    )))
                    return
                }

                let weekStartDate = ((planObject.value(forKey: "weekStartDate") as? Date).map(WeeklyRepositoryCalendar.normalizedWeekStart))
                    ?? WeeklyRepositoryCalendar.normalizedWeekStart(for: request.completedAt)

                let taskResolution = try self.resolveTaskDecisions(
                    request.taskDecisions.sorted { $0.taskID.uuidString < $1.taskID.uuidString }
                )
                try self.applyTaskDecisions(
                    taskResolution.validDecisions,
                    taskObjectsByID: taskResolution.taskObjectsByID,
                    weekStartDate: weekStartDate
                )

                let outcomeResolution = try self.resolveOutcomeStatuses(
                    request.outcomeStatusesByOutcomeID,
                    weeklyPlanID: request.weeklyPlanID
                )
                self.applyOutcomeStatuses(
                    outcomeResolution.validStatusesByOutcomeID,
                    outcomeObjectsByID: outcomeResolution.outcomeObjectsByID
                )

                let existingReview = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "WeeklyReview",
                    predicate: NSPredicate(format: "weeklyPlanID == %@", request.weeklyPlanID as CVarArg),
                    sort: [NSSortDescriptor(key: "createdAt", ascending: true)]
                )
                let review = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "WeeklyReview",
                    id: (existingReview?.value(forKey: "id") as? UUID) ?? UUID()
                )
                Self.applyReview(request: request, existingReview: existingReview, to: review)

                planObject.setValue(WeeklyPlanReviewStatus.completed.rawValue, forKey: "reviewStatus")
                planObject.setValue(request.completedAt, forKey: "updatedAt")

                try self.backgroundContext.save()
                self.viewContext.perform {
                    self.viewContext.refreshAllObjects()
                }
                completion(.success(
                    CompleteWeeklyReviewResult(
                        review: Self.mapReview(review),
                        skippedTaskIDs: taskResolution.skippedTaskIDs,
                        skippedOutcomeIDs: outcomeResolution.skippedOutcomeIDs
                    )
                ))
            } catch {
                self.backgroundContext.rollback()
                completion(.failure(Self.mapFinalizeError(error)))
            }
        }
    }

    private struct ResolvedTaskDecisions {
        let validDecisions: [WeeklyReviewTaskDecision]
        let taskObjectsByID: [UUID: NSManagedObject]
        let skippedTaskIDs: [UUID]
    }

    private struct ResolvedOutcomeStatuses {
        let validStatusesByOutcomeID: [UUID: WeeklyOutcomeStatus]
        let outcomeObjectsByID: [UUID: NSManagedObject]
        let skippedOutcomeIDs: [UUID]
    }

    private func resolveTaskDecisions(
        _ decisions: [WeeklyReviewTaskDecision],
    ) throws -> ResolvedTaskDecisions {
        guard decisions.isEmpty == false else {
            return ResolvedTaskDecisions(validDecisions: [], taskObjectsByID: [:], skippedTaskIDs: [])
        }

        let taskIDs = decisions.map(\.taskID)
        let taskObjects = try V2CoreDataRepositorySupport.fetchObjects(
            in: backgroundContext,
            entityName: "TaskDefinition",
            predicate: NSPredicate(format: "taskID IN %@", taskIDs),
            sort: [
                NSSortDescriptor(key: "taskID", ascending: true),
                NSSortDescriptor(key: "id", ascending: true)
            ]
        )
        var taskObjectsByID: [UUID: NSManagedObject] = [:]
        for object in taskObjects {
            guard let taskID = object.value(forKey: "taskID") as? UUID,
                  taskObjectsByID[taskID] == nil else {
                continue
            }
            taskObjectsByID[taskID] = object
        }
        let skippedTaskIDs = taskIDs.filter { taskObjectsByID[$0] == nil }
        let validDecisions = decisions.filter { taskObjectsByID[$0.taskID] != nil }

        return ResolvedTaskDecisions(
            validDecisions: validDecisions,
            taskObjectsByID: taskObjectsByID,
            skippedTaskIDs: skippedTaskIDs
        )
    }

    private func applyTaskDecisions(
        _ decisions: [WeeklyReviewTaskDecision],
        taskObjectsByID: [UUID: NSManagedObject],
        weekStartDate: Date
    ) throws {
        for decision in decisions {
            guard let taskObject = taskObjectsByID[decision.taskID] else { continue }

            let existingDeferredCount = max(0, Int((taskObject.value(forKey: "deferredCount") as? Int32) ?? 0))
            let updateRequest = UpdateTaskDefinitionRequest(
                id: decision.taskID,
                planningBucket: {
                    switch decision.disposition {
                    case .carry:
                        return .thisWeek
                    case .later, .drop:
                        return .later
                    }
                }(),
                weeklyOutcomeID: nil,
                clearWeeklyOutcomeLink: true,
                deferredFromWeekStart: weekStartDate,
                clearDeferredFromWeekStart: false,
                deferredCount: existingDeferredCount + (decision.disposition == .carry ? 1 : 0),
                updatedAt: Date()
            )
            TaskDefinitionMutationApplier.applyUpdateRequest(updateRequest, to: taskObject)
        }
    }

    private func resolveOutcomeStatuses(
        _ statusesByOutcomeID: [UUID: WeeklyOutcomeStatus],
        weeklyPlanID: UUID
    ) throws -> ResolvedOutcomeStatuses {
        guard statusesByOutcomeID.isEmpty == false else {
            return ResolvedOutcomeStatuses(validStatusesByOutcomeID: [:], outcomeObjectsByID: [:], skippedOutcomeIDs: [])
        }

        let requestedOutcomeIDs = Array(statusesByOutcomeID.keys)
        let outcomeObjects = try V2CoreDataRepositorySupport.fetchObjects(
            in: backgroundContext,
            entityName: "WeeklyOutcome",
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "weeklyPlanID == %@", weeklyPlanID as CVarArg),
                NSPredicate(format: "id IN %@", requestedOutcomeIDs)
            ])
        )
        var outcomeObjectsByID: [UUID: NSManagedObject] = [:]
        for object in outcomeObjects {
            guard let outcomeID = object.value(forKey: "id") as? UUID else { continue }
            outcomeObjectsByID[outcomeID] = object
        }
        let skippedOutcomeIDs = requestedOutcomeIDs.filter { outcomeObjectsByID[$0] == nil }
        let validStatusesByOutcomeID = statusesByOutcomeID.filter { outcomeObjectsByID[$0.key] != nil }

        return ResolvedOutcomeStatuses(
            validStatusesByOutcomeID: validStatusesByOutcomeID,
            outcomeObjectsByID: outcomeObjectsByID,
            skippedOutcomeIDs: skippedOutcomeIDs
        )
    }

    private func applyOutcomeStatuses(
        _ statusesByOutcomeID: [UUID: WeeklyOutcomeStatus],
        outcomeObjectsByID: [UUID: NSManagedObject]
    ) {
        guard statusesByOutcomeID.isEmpty == false else { return }
        for (outcomeID, status) in statusesByOutcomeID {
            guard let object = outcomeObjectsByID[outcomeID] else { continue }
            object.setValue(status.rawValue, forKey: "status")
            object.setValue(Date(), forKey: "updatedAt")
        }
    }

    private static func applyReview(
        request: CompleteWeeklyReviewRequest,
        existingReview: NSManagedObject?,
        to object: NSManagedObject
    ) {
        object.setValue(object.value(forKey: "id") as? UUID ?? UUID(), forKey: "id")
        object.setValue(request.weeklyPlanID, forKey: "weeklyPlanID")
        object.setValue(request.wins, forKey: "wins")
        object.setValue(request.blockers, forKey: "blockers")
        object.setValue(request.lessons, forKey: "lessons")
        object.setValue(request.nextWeekPrepNotes, forKey: "nextWeekPrepNotes")
        object.setValue(request.perceivedWeekRating.map { Int32($0) }, forKey: "perceivedWeekRating")
        object.setValue((existingReview?.value(forKey: "createdAt") as? Date) ?? request.completedAt, forKey: "createdAt")
        object.setValue(request.completedAt, forKey: "updatedAt")
        object.setValue(request.completedAt, forKey: "completedAt")
    }

    private static func mapReview(_ object: NSManagedObject) -> WeeklyReview {
        WeeklyReview(
            id: (object.value(forKey: "id") as? UUID) ?? UUID(),
            weeklyPlanID: (object.value(forKey: "weeklyPlanID") as? UUID) ?? UUID(),
            wins: object.value(forKey: "wins") as? String,
            blockers: object.value(forKey: "blockers") as? String,
            lessons: object.value(forKey: "lessons") as? String,
            nextWeekPrepNotes: object.value(forKey: "nextWeekPrepNotes") as? String,
            perceivedWeekRating: (object.value(forKey: "perceivedWeekRating") as? Int32).map(Int.init),
            createdAt: (object.value(forKey: "createdAt") as? Date) ?? Date(),
            updatedAt: (object.value(forKey: "updatedAt") as? Date) ?? Date(),
            completedAt: object.value(forKey: "completedAt") as? Date
        )
    }

    private static func mapFinalizeError(_ error: Error) -> Error {
        let nsError = error as NSError
        guard nsError.domain != "CoreDataWeeklyReviewMutationRepository" else {
            return error
        }

        return NSError(
            domain: "CoreDataWeeklyReviewMutationRepository",
            code: 500,
            userInfo: [
                NSLocalizedDescriptionKey: "Weekly review couldn't be saved right now.",
                NSUnderlyingErrorKey: error
            ]
        )
    }
}

public final class UserDefaultsWeeklyReviewDraftStore: WeeklyReviewDraftStoreProtocol {
    private struct WeeklyReviewLocalStateFile: Codable {
        var draftsByWeekKey: [String: WeeklyReviewDraft]
        var completedTaskDecisionsByWeekKey: [String: [WeeklyReviewTaskDecision]]
    }

    private let defaults: UserDefaults
    private let storageKey: String

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = "tasker.weekly.review.localstate.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    public func fetchDraft(
        weekStartDate: Date,
        completion: @escaping (Result<WeeklyReviewDraft?, Error>) -> Void
    ) {
        do {
            let file = try loadState()
            completion(.success(file.draftsByWeekKey[Self.weekKey(for: weekStartDate)]))
        } catch {
            completion(.failure(error))
        }
    }

    public func saveDraft(
        _ draft: WeeklyReviewDraft,
        completion: @escaping (Result<WeeklyReviewDraft, Error>) -> Void
    ) {
        do {
            var file = try loadState()
            let normalizedDraft = WeeklyReviewDraft(
                weekStartDate: WeeklyRepositoryCalendar.normalizedWeekStart(for: draft.weekStartDate),
                wins: draft.wins,
                blockers: draft.blockers,
                lessons: draft.lessons,
                nextWeekPrepNotes: draft.nextWeekPrepNotes,
                perceivedWeekRating: draft.perceivedWeekRating,
                taskDecisions: draft.taskDecisions,
                outcomeStatuses: draft.outcomeStatuses,
                updatedAt: draft.updatedAt
            )
            file.draftsByWeekKey[Self.weekKey(for: normalizedDraft.weekStartDate)] = normalizedDraft
            try persist(file)
            completion(.success(normalizedDraft))
        } catch {
            completion(.failure(error))
        }
    }

    public func clearDraft(
        weekStartDate: Date,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        do {
            var file = try loadState()
            file.draftsByWeekKey.removeValue(forKey: Self.weekKey(for: weekStartDate))
            try persist(file)
            completion(.success(()))
        } catch {
            completion(.failure(error))
        }
    }

    public func fetchCompletedTaskDecisions(
        weekStartDate: Date,
        completion: @escaping (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    ) {
        do {
            let file = try loadState()
            completion(.success(file.completedTaskDecisionsByWeekKey[Self.weekKey(for: weekStartDate)] ?? []))
        } catch {
            completion(.failure(error))
        }
    }

    public func saveCompletedTaskDecisions(
        _ decisions: [WeeklyReviewTaskDecision],
        weekStartDate: Date,
        completion: @escaping (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    ) {
        do {
            var file = try loadState()
            let normalized = decisions.sorted { $0.taskID.uuidString < $1.taskID.uuidString }
            file.completedTaskDecisionsByWeekKey[Self.weekKey(for: weekStartDate)] = normalized
            try persist(file)
            completion(.success(normalized))
        } catch {
            completion(.failure(error))
        }
    }

    private func loadState() throws -> WeeklyReviewLocalStateFile {
        guard let data = defaults.data(forKey: storageKey) else {
            return WeeklyReviewLocalStateFile(draftsByWeekKey: [:], completedTaskDecisionsByWeekKey: [:])
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WeeklyReviewLocalStateFile.self, from: data)
    }

    private func persist(_ file: WeeklyReviewLocalStateFile) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try encoder.encode(file), forKey: storageKey)
    }

    private static func weekKey(for weekStartDate: Date) -> String {
        let normalizedDate = WeeklyRepositoryCalendar.normalizedWeekStart(for: weekStartDate)
        return ISO8601DateFormatter().string(from: normalizedDate)
    }
}
