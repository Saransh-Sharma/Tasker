import CoreData
import Foundation

private final class WeeklyRepositoryCompletion<Value: Sendable>: @unchecked Sendable {
    private let completion: @Sendable (Result<Value, Error>) -> Void

    init(_ completion: @escaping @Sendable (Result<Value, Error>) -> Void) {
        self.completion = completion
    }

    func deliver(_ result: Result<Value, Error>) {
        completion(result)
    }
}

private enum WeeklyRepositoryCalendar {
    struct WeekIdentity: Hashable {
        let isoYear: Int
        let isoWeek: Int
        let canonicalStartUTC: Date

        var storageKey: String {
            String(format: "iso:%04d-W%02d", isoYear, isoWeek)
        }
    }

    private static func makeStorageDateFormatter() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }

    private static var canonicalCalendar: Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    static func normalizedWeekStart(for date: Date) -> Date {
        canonicalWeekStart(for: date)
    }

    static func normalizedWeekEnd(for weekStartDate: Date) -> Date {
        canonicalWeekEnd(for: weekStartDate)
    }

    static func canonicalWeekStart(for date: Date) -> Date {
        XPCalculationEngine.startOfWeek(
            for: date,
            startingOn: .monday,
            calendar: canonicalCalendar
        )
    }

    static func canonicalWeekEnd(for weekStartDate: Date) -> Date {
        XPCalculationEngine.endOfWeek(
            for: canonicalWeekStart(for: weekStartDate),
            startingOn: .monday,
            calendar: canonicalCalendar
        )
    }

    static func identity(for date: Date) -> WeekIdentity {
        let canonicalStart = canonicalWeekStart(for: date)
        let components = canonicalCalendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: canonicalStart)
        return WeekIdentity(
            isoYear: components.yearForWeekOfYear ?? 0,
            isoWeek: components.weekOfYear ?? 0,
            canonicalStartUTC: canonicalStart
        )
    }

    static func legacyWeekStarts(for date: Date) -> [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .gmt
        let canonicalStart = canonicalWeekStart(for: date)
        let values = Weekday.allCases.map {
            XPCalculationEngine.startOfWeek(for: date, startingOn: $0)
        }
        return Array(Set(values)).filter { !calendar.isDate($0, inSameDayAs: canonicalStart) }
    }

    static func isSameCanonicalWeek(_ lhs: Date, _ rhs: Date) -> Bool {
        let calendar = Calendar.autoupdatingCurrent
        return calendar.isDate(canonicalWeekStart(for: lhs), inSameDayAs: canonicalWeekStart(for: rhs))
    }

    static func weekKeyAliases(for weekStartDate: Date) -> [String] {
        var keys = Set<String>()
        let identity = identity(for: weekStartDate)
        keys.insert(identity.storageKey)
        let formatter = makeStorageDateFormatter()
        keys.insert(formatter.string(from: identity.canonicalStartUTC))
        keys.insert(formatter.string(from: canonicalWeekStart(for: weekStartDate)))
        legacyWeekStarts(for: weekStartDate).forEach { keys.insert(formatter.string(from: $0)) }
        return Array(keys)
    }

    static func canonicalWeekStart(forStorageKey key: String) -> Date? {
        if key.hasPrefix("iso:") {
            let value = String(key.dropFirst("iso:".count))
            let components = value.components(separatedBy: "-W")
            if components.count == 2,
               let year = Int(components[0]),
               let week = Int(components[1]) {
                var dateComponents = DateComponents()
                dateComponents.calendar = canonicalCalendar
                dateComponents.timeZone = TimeZone(secondsFromGMT: 0)
                dateComponents.yearForWeekOfYear = year
                dateComponents.weekOfYear = week
                dateComponents.weekday = 2
                if let date = canonicalCalendar.date(from: dateComponents) {
                    return canonicalWeekStart(for: date)
                }
            }
        }

        if let parsed = makeStorageDateFormatter().date(from: key) {
            return canonicalWeekStart(for: parsed)
        }

        return nil
    }

    static func canonicalStorageKey(for weekStartDate: Date) -> String {
        identity(for: weekStartDate).storageKey
    }
}

public final class CoreDataWeeklyPlanRepository: WeeklyPlanRepositoryProtocol, @unchecked Sendable {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    public func fetchPlan(id: UUID, completion: @escaping @Sendable (Result<WeeklyPlan?, Error>) -> Void) {
        let callback = WeeklyRepositoryCompletion(completion)
        viewContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.viewContext,
                    entityName: "WeeklyPlan",
                    predicate: NSPredicate(format: "id == %@", id as CVarArg)
                )
                callback.deliver(.success(object.map(Self.mapWeeklyPlan)))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }

    public func fetchPlan(forWeekStarting weekStartDate: Date, completion: @escaping @Sendable (Result<WeeklyPlan?, Error>) -> Void) {
        let callback = WeeklyRepositoryCompletion(completion)
        let canonicalWeekStart = WeeklyRepositoryCalendar.normalizedWeekStart(for: weekStartDate)
        viewContext.perform {
            do {
                if let object = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.viewContext,
                    entityName: "WeeklyPlan",
                    predicate: NSPredicate(format: "weekStartDate == %@", canonicalWeekStart as NSDate),
                    sort: [NSSortDescriptor(key: "createdAt", ascending: true)]
                ) {
                    callback.deliver(.success(Self.mapWeeklyPlan(object)))
                    return
                }

                let legacyStarts = WeeklyRepositoryCalendar.legacyWeekStarts(for: weekStartDate)
                guard legacyStarts.isEmpty == false else {
                    callback.deliver(.success(nil))
                    return
                }

                let legacyObjects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "WeeklyPlan",
                    predicate: NSPredicate(format: "weekStartDate IN %@", legacyStarts as NSArray),
                    sort: [NSSortDescriptor(key: "createdAt", ascending: true)]
                )
                guard let legacyObject = legacyObjects.first else {
                    callback.deliver(.success(nil))
                    return
                }

                Self.migrateLegacyPlanObject(
                    legacyObject,
                    canonicalWeekStart: canonicalWeekStart,
                    in: self.viewContext
                )
                callback.deliver(.success(Self.mapWeeklyPlan(legacyObject)))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }

    public func fetchPlans(from startDate: Date, to endDate: Date, completion: @escaping @Sendable (Result<[WeeklyPlan], Error>) -> Void) {
        let callback = WeeklyRepositoryCompletion(completion)
        let canonicalStart = WeeklyRepositoryCalendar.normalizedWeekStart(for: startDate)
        let canonicalEnd = WeeklyRepositoryCalendar.normalizedWeekStart(for: endDate)
        let calendar = Calendar.autoupdatingCurrent
        let widenedStart = calendar.date(byAdding: .day, value: -6, to: canonicalStart) ?? canonicalStart
        let widenedEnd = calendar.date(byAdding: .day, value: 6, to: canonicalEnd) ?? canonicalEnd
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "WeeklyPlan",
                    predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "weekStartDate >= %@", widenedStart as NSDate),
                        NSPredicate(format: "weekStartDate <= %@", widenedEnd as NSDate)
                    ]),
                    sort: [
                        NSSortDescriptor(key: "weekStartDate", ascending: true),
                        NSSortDescriptor(key: "createdAt", ascending: true)
                    ]
                )
                var dedupedPlansByCanonicalStart: [Date: WeeklyPlan] = [:]
                for object in objects {
                    let plan = Self.mapWeeklyPlan(object)
                    let canonicalPlanStart = WeeklyRepositoryCalendar.normalizedWeekStart(for: plan.weekStartDate)
                    if dedupedPlansByCanonicalStart[canonicalPlanStart] == nil {
                        dedupedPlansByCanonicalStart[canonicalPlanStart] = plan
                    }
                }

                let plans = dedupedPlansByCanonicalStart.values
                    .filter { $0.weekStartDate >= canonicalStart && $0.weekStartDate <= canonicalEnd }
                    .sorted { $0.weekStartDate < $1.weekStartDate }
                callback.deliver(.success(plans))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }

    public func savePlan(_ plan: WeeklyPlan, completion: @escaping @Sendable (Result<WeeklyPlan, Error>) -> Void) {
        let callback = WeeklyRepositoryCompletion(completion)
        backgroundContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "WeeklyPlan",
                    id: plan.id
                )
                Self.apply(plan, to: object)
                try self.backgroundContext.save()
                callback.deliver(.success(Self.mapWeeklyPlan(object)))
            } catch {
                callback.deliver(.failure(error))
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

    private static func migrateLegacyPlanObject(
        _ object: NSManagedObject,
        canonicalWeekStart: Date,
        in context: NSManagedObjectContext
    ) {
        let existingStart = (object.value(forKey: "weekStartDate") as? Date) ?? canonicalWeekStart
        let calendar = Calendar.autoupdatingCurrent
        guard calendar.isDate(existingStart, inSameDayAs: canonicalWeekStart) == false else {
            return
        }

        object.setValue(canonicalWeekStart, forKey: "weekStartDate")
        object.setValue(WeeklyRepositoryCalendar.normalizedWeekEnd(for: canonicalWeekStart), forKey: "weekEndDate")
        object.setValue(Date(), forKey: "updatedAt")
        do {
            if context.hasChanges {
                try context.save()
            }
        } catch {
            logWarning(
                event: "weekly_plan_legacy_migration_failed",
                message: "Failed to migrate legacy weekly plan key to canonical identity",
                fields: ["error": error.localizedDescription]
            )
        }
    }
}

public final class CoreDataWeeklyOutcomeRepository: WeeklyOutcomeRepositoryProtocol, @unchecked Sendable {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    public func fetchOutcomes(weeklyPlanID: UUID, completion: @escaping @Sendable (Result<[WeeklyOutcome], Error>) -> Void) {
        let callback = WeeklyRepositoryCompletion(completion)
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
                callback.deliver(.success(objects.map(Self.mapWeeklyOutcome)))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }

    public func saveOutcome(_ outcome: WeeklyOutcome, completion: @escaping @Sendable (Result<WeeklyOutcome, Error>) -> Void) {
        let callback = WeeklyRepositoryCompletion(completion)
        backgroundContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "WeeklyOutcome",
                    id: outcome.id
                )
                Self.apply(outcome, to: object)
                try self.backgroundContext.save()
                callback.deliver(.success(Self.mapWeeklyOutcome(object)))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }

    public func replaceOutcomes(
        weeklyPlanID: UUID,
        outcomes: [WeeklyOutcome],
        completion: @escaping @Sendable (Result<[WeeklyOutcome], Error>) -> Void
    ) {
        let callback = WeeklyRepositoryCompletion(completion)
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
                callback.deliver(.success(persistedObjects.map(Self.mapWeeklyOutcome)))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }

    public func deleteOutcome(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        let callback = WeeklyRepositoryCompletion(completion)
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
                callback.deliver(.success(()))
            } catch {
                callback.deliver(.failure(error))
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

public final class CoreDataWeeklyReviewRepository: WeeklyReviewRepositoryProtocol, @unchecked Sendable {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    public func fetchReview(weeklyPlanID: UUID, completion: @escaping @Sendable (Result<WeeklyReview?, Error>) -> Void) {
        let callback = WeeklyRepositoryCompletion(completion)
        viewContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.viewContext,
                    entityName: "WeeklyReview",
                    predicate: NSPredicate(format: "weeklyPlanID == %@", weeklyPlanID as CVarArg),
                    sort: [NSSortDescriptor(key: "createdAt", ascending: true)]
                )
                callback.deliver(.success(object.map(Self.mapWeeklyReview)))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }

    public func saveReview(_ review: WeeklyReview, completion: @escaping @Sendable (Result<WeeklyReview, Error>) -> Void) {
        let callback = WeeklyRepositoryCompletion(completion)
        backgroundContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "WeeklyReview",
                    id: review.id
                )
                Self.apply(review, to: object)
                try self.backgroundContext.save()
                callback.deliver(.success(Self.mapWeeklyReview(object)))
            } catch {
                callback.deliver(.failure(error))
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

public final class CoreDataReflectionNoteRepository: ReflectionNoteRepositoryProtocol, @unchecked Sendable {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    public func fetchNotes(query: ReflectionNoteQuery, completion: @escaping @Sendable (Result<[ReflectionNote], Error>) -> Void) {
        let callback = WeeklyRepositoryCompletion(completion)
        viewContext.perform {
            do {
                let request = NSFetchRequest<NSManagedObject>(entityName: "ReflectionNote")
                request.predicate = Self.predicate(for: query)
                request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
                if let limit = query.limit, limit > 0 {
                    request.fetchLimit = limit
                }
                let objects = try self.viewContext.fetch(request)
                callback.deliver(.success(objects.map(Self.mapReflectionNote)))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }

    public func saveNote(_ note: ReflectionNote, completion: @escaping @Sendable (Result<ReflectionNote, Error>) -> Void) {
        let callback = WeeklyRepositoryCompletion(completion)
        backgroundContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "ReflectionNote",
                    id: note.id
                )
                Self.apply(note, to: object)
                try self.backgroundContext.save()
                callback.deliver(.success(Self.mapReflectionNote(object)))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }

    public func deleteNote(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        let callback = WeeklyRepositoryCompletion(completion)
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
                callback.deliver(.success(()))
            } catch {
                callback.deliver(.failure(error))
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

public final class CoreDataWeeklyReviewMutationRepository: WeeklyReviewMutationRepositoryProtocol, @unchecked Sendable {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    public func finalizeReview(
        request: CompleteWeeklyReviewRequest,
        completion: @escaping @Sendable (Result<CompleteWeeklyReviewResult, Error>) -> Void
    ) {
        let callback = WeeklyRepositoryCompletion(completion)
        backgroundContext.perform {
            do {
                guard let planObject = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "WeeklyPlan",
                    predicate: NSPredicate(format: "id == %@", request.weeklyPlanID as CVarArg),
                    sort: [NSSortDescriptor(key: "createdAt", ascending: true)]
                ) else {
                    callback.deliver(.failure(NSError(
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
                let result = CompleteWeeklyReviewResult(
                    review: Self.mapReview(review),
                    skippedTaskIDs: taskResolution.skippedTaskIDs,
                    skippedOutcomeIDs: outcomeResolution.skippedOutcomeIDs
                )
                self.viewContext.perform {
                    self.viewContext.refreshAllObjects()
                    callback.deliver(.success(result))
                }
            } catch {
                self.backgroundContext.rollback()
                callback.deliver(.failure(Self.mapFinalizeError(error)))
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
        let canonicalWeekStart = WeeklyRepositoryCalendar.normalizedWeekStart(for: weekStartDate)
        for decision in decisions {
            guard let taskObject = taskObjectsByID[decision.taskID] else { continue }

            let existingDeferredCount = max(0, Int((taskObject.value(forKey: "deferredCount") as? Int32) ?? 0))
            let existingDeferredFromWeekStart = (taskObject.value(forKey: "deferredFromWeekStart") as? Date)
                .map(WeeklyRepositoryCalendar.normalizedWeekStart(for:))
            let isRepeatedCarryForSameWeek = decision.disposition == .carry
                && existingDeferredFromWeekStart.map { WeeklyRepositoryCalendar.isSameCanonicalWeek($0, canonicalWeekStart) } == true
            let nextDeferredCount = existingDeferredCount + ((decision.disposition == .carry && !isRepeatedCarryForSameWeek) ? 1 : 0)
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
                deferredFromWeekStart: canonicalWeekStart,
                clearDeferredFromWeekStart: false,
                deferredCount: nextDeferredCount,
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

public final class UserDefaultsWeeklyReviewDraftStore: WeeklyReviewDraftStoreProtocol, @unchecked Sendable {
    private struct WeeklyReviewLocalStateFile: Codable, Equatable {
        var draftsByWeekKey: [String: WeeklyReviewDraft]
        var completedTaskDecisionsByWeekKey: [String: [WeeklyReviewTaskDecision]]
    }

    private static let maxStoredWeeks = 26

    private let defaults: UserDefaults
    private let storageKey: String

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = "tasker.weekly.review.localstate.v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        normalizePersistedStateIfNeeded()
    }

    public func fetchDraft(
        weekStartDate: Date,
        completion: @escaping @Sendable (Result<WeeklyReviewDraft?, Error>) -> Void
    ) {
        let callback = WeeklyRepositoryCompletion(completion)
        do {
            var file = normalizeAndPrune(try loadState())
            let canonicalKey = Self.weekKey(for: weekStartDate)
            if let draft = file.draftsByWeekKey[canonicalKey] {
                callback.deliver(.success(draft))
                return
            }

            let legacyKey = Self.legacyWeekKeys(for: weekStartDate).first { file.draftsByWeekKey[$0] != nil }
            if let legacyKey, let legacyDraft = file.draftsByWeekKey[legacyKey] {
                let normalizedDraft = Self.normalizeDraft(legacyDraft)
                file.draftsByWeekKey[legacyKey] = nil
                file.draftsByWeekKey[canonicalKey] = normalizedDraft
                try persist(file)
                callback.deliver(.success(normalizedDraft))
                return
            }

            callback.deliver(.success(nil))
        } catch {
            callback.deliver(.failure(error))
        }
    }

    public func saveDraft(
        _ draft: WeeklyReviewDraft,
        completion: @escaping @Sendable (Result<WeeklyReviewDraft, Error>) -> Void
    ) {
        let callback = WeeklyRepositoryCompletion(completion)
        do {
            var file = normalizeAndPrune(try loadState())
            let normalizedDraft = Self.normalizeDraft(draft)
            file.draftsByWeekKey[Self.weekKey(for: normalizedDraft.weekStartDate)] = normalizedDraft
            try persist(file)
            callback.deliver(.success(normalizedDraft))
        } catch {
            callback.deliver(.failure(error))
        }
    }

    public func clearDraft(
        weekStartDate: Date,
        completion: @escaping @Sendable (Result<Void, Error>) -> Void
    ) {
        let callback = WeeklyRepositoryCompletion(completion)
        do {
            var file = normalizeAndPrune(try loadState())
            for key in Self.allWeekKeys(for: weekStartDate) {
                file.draftsByWeekKey.removeValue(forKey: key)
            }
            try persist(file)
            callback.deliver(.success(()))
        } catch {
            callback.deliver(.failure(error))
        }
    }

    public func fetchCompletedTaskDecisions(
        weekStartDate: Date,
        completion: @escaping @Sendable (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    ) {
        let callback = WeeklyRepositoryCompletion(completion)
        do {
            var file = normalizeAndPrune(try loadState())
            let canonicalKey = Self.weekKey(for: weekStartDate)
            if let decisions = file.completedTaskDecisionsByWeekKey[canonicalKey] {
                callback.deliver(.success(decisions))
                return
            }

            let legacyKey = Self.legacyWeekKeys(for: weekStartDate).first { file.completedTaskDecisionsByWeekKey[$0] != nil }
            if let legacyKey, let decisions = file.completedTaskDecisionsByWeekKey[legacyKey] {
                file.completedTaskDecisionsByWeekKey[legacyKey] = nil
                file.completedTaskDecisionsByWeekKey[canonicalKey] = decisions
                try persist(file)
                callback.deliver(.success(decisions))
                return
            }

            callback.deliver(.success([]))
        } catch {
            callback.deliver(.failure(error))
        }
    }

    public func saveCompletedTaskDecisions(
        _ decisions: [WeeklyReviewTaskDecision],
        weekStartDate: Date,
        completion: @escaping @Sendable (Result<[WeeklyReviewTaskDecision], Error>) -> Void
    ) {
        let callback = WeeklyRepositoryCompletion(completion)
        do {
            var file = normalizeAndPrune(try loadState())
            let normalized = decisions.sorted { $0.taskID.uuidString < $1.taskID.uuidString }
            file.completedTaskDecisionsByWeekKey[Self.weekKey(for: weekStartDate)] = normalized
            try persist(file)
            callback.deliver(.success(normalized))
        } catch {
            callback.deliver(.failure(error))
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
        let normalized = normalizeAndPrune(file)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try encoder.encode(normalized), forKey: storageKey)
    }

    private static func normalizeDraft(_ draft: WeeklyReviewDraft) -> WeeklyReviewDraft {
        WeeklyReviewDraft(
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
    }

    private func normalizeAndPrune(_ file: WeeklyReviewLocalStateFile) -> WeeklyReviewLocalStateFile {
        var normalizedDrafts: [String: WeeklyReviewDraft] = [:]
        for draft in file.draftsByWeekKey.values {
            let normalizedDraft = Self.normalizeDraft(draft)
            let canonicalKey = Self.weekKey(for: normalizedDraft.weekStartDate)
            if let existing = normalizedDrafts[canonicalKey] {
                if existing.updatedAt <= normalizedDraft.updatedAt {
                    normalizedDrafts[canonicalKey] = normalizedDraft
                }
            } else {
                normalizedDrafts[canonicalKey] = normalizedDraft
            }
        }

        var normalizedCompleted: [String: [WeeklyReviewTaskDecision]] = [:]
        for (rawKey, decisions) in file.completedTaskDecisionsByWeekKey {
            guard let canonicalWeekStart = WeeklyRepositoryCalendar.canonicalWeekStart(forStorageKey: rawKey) else {
                continue
            }
            let canonicalKey = Self.weekKey(for: canonicalWeekStart)
            var dedupedByTaskID: [UUID: WeeklyReviewTaskDecision] = [:]
            for decision in decisions {
                dedupedByTaskID[decision.taskID] = decision
            }
            let normalizedDecisions = dedupedByTaskID.values.sorted { $0.taskID.uuidString < $1.taskID.uuidString }
            if let existing = normalizedCompleted[canonicalKey] {
                if normalizedDecisions.count >= existing.count {
                    normalizedCompleted[canonicalKey] = normalizedDecisions
                }
            } else {
                normalizedCompleted[canonicalKey] = normalizedDecisions
            }
        }

        let allKeys = Set(normalizedDrafts.keys).union(normalizedCompleted.keys)
        let sortableKeys = allKeys.compactMap { key -> (String, Date)? in
            guard let weekStart = WeeklyRepositoryCalendar.canonicalWeekStart(forStorageKey: key) else { return nil }
            return (key, weekStart)
        }
        let keysToKeep = Set(
            sortableKeys
                .sorted { $0.1 > $1.1 }
                .prefix(Self.maxStoredWeeks)
                .map(\.0)
        )

        normalizedDrafts = normalizedDrafts.filter { key, _ in
            guard WeeklyRepositoryCalendar.canonicalWeekStart(forStorageKey: key) != nil else { return true }
            return keysToKeep.contains(key)
        }
        normalizedCompleted = normalizedCompleted.filter { key, _ in
            guard WeeklyRepositoryCalendar.canonicalWeekStart(forStorageKey: key) != nil else { return true }
            return keysToKeep.contains(key)
        }

        return WeeklyReviewLocalStateFile(
            draftsByWeekKey: normalizedDrafts,
            completedTaskDecisionsByWeekKey: normalizedCompleted
        )
    }

    private func normalizePersistedStateIfNeeded() {
        do {
            let loaded = try loadState()
            let normalized = normalizeAndPrune(loaded)
            guard normalized != loaded else { return }
            try persist(normalized)
        } catch {
            logWarning(
                event: "weekly_review_draft_store_normalize_failed",
                message: "Failed to normalize persisted weekly review local state",
                fields: ["error": error.localizedDescription]
            )
        }
    }

    private static func weekKey(for weekStartDate: Date) -> String {
        WeeklyRepositoryCalendar.canonicalStorageKey(for: weekStartDate)
    }

    private static func allWeekKeys(for weekStartDate: Date) -> [String] {
        WeeklyRepositoryCalendar.weekKeyAliases(for: weekStartDate)
    }

    private static func legacyWeekKeys(for weekStartDate: Date) -> [String] {
        let canonicalKey = weekKey(for: weekStartDate)
        return allWeekKeys(for: weekStartDate).filter { $0 != canonicalKey }
    }
}


// MARK: - Daily Reflection Store

import Foundation

public final class UserDefaultsDailyReflectionStore: DailyReflectionStoreProtocol, @unchecked Sendable {
    private struct LocalStateFile: Codable, Equatable {
        var completionDateKeys: [String]
        var payloadsByDateKey: [String: ReflectionPayload]
        var planDraftsByDateKey: [String: DailyPlanDraft]
    }

    public static let legacyCompletionDefaultsKey = "gamification.reflection.completedDateKeys"

    private static let storageKey = "tasker.dailyReflection.localState.v1"
    private static let maxStoredDays = 45
    private static let maximumNoteLength = 140

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let stampFormatter: DateFormatter

    public init(defaults: UserDefaults = .standard, calendar: Calendar = .autoupdatingCurrent) {
        self.defaults = defaults
        self.calendar = calendar

        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        self.stampFormatter = formatter

        normalizePersistedStateIfNeeded()
    }

    public func isCompleted(on date: Date) -> Bool {
        let key = dateKey(for: date)
        return completedDateStamps().contains(key)
    }

    public func completedDateStamps() -> Set<String> {
        let file = (try? loadState()).map(normalizeAndPrune) ?? LocalStateFile(
            completionDateKeys: [],
            payloadsByDateKey: [:],
            planDraftsByDateKey: [:]
        )
        return Set(file.completionDateKeys)
    }

    public func fetchReflectionPayload(on date: Date) -> ReflectionPayload? {
        let key = dateKey(for: date)
        guard let file = try? loadState() else { return nil }
        return normalizeAndPrune(file).payloadsByDateKey[key]
    }

    @discardableResult
    public func saveReflectionPayload(_ payload: ReflectionPayload) throws -> ReflectionPayload {
        var file = normalizeAndPrune(try loadState())
        let normalized = Self.normalizePayload(payload, calendar: calendar)
        file.payloadsByDateKey[dateKey(for: normalized.reflectionDate)] = normalized
        try persist(file)
        return normalized
    }

    @discardableResult
    public func markCompleted(
        on reflectionDate: Date,
        completedAt: Date,
        payload: ReflectionPayload?
    ) throws -> ReflectionPayload? {
        var file = normalizeAndPrune(try loadState())
        let key = dateKey(for: reflectionDate)
        if file.completionDateKeys.contains(key) == false {
            file.completionDateKeys.append(key)
        }

        let normalizedPayload: ReflectionPayload?
        if let payload {
            let existing = file.payloadsByDateKey[key]
            normalizedPayload = Self.normalizePayload(
                ReflectionPayload(
                    reflectionDate: reflectionDate,
                    planningDate: payload.planningDate,
                    mode: payload.mode,
                    mood: payload.mood,
                    energy: payload.energy,
                    frictionTags: payload.frictionTags,
                    note: payload.note,
                    createdAt: existing?.createdAt ?? payload.createdAt,
                    updatedAt: completedAt
                ),
                calendar: calendar
            )
            file.payloadsByDateKey[key] = normalizedPayload
        } else {
            normalizedPayload = file.payloadsByDateKey[key]
        }

        try persist(file)
        return normalizedPayload
    }

    public func fetchPlanDraft(on date: Date) -> DailyPlanDraft? {
        let key = dateKey(for: date)
        guard let file = try? loadState() else { return nil }
        return normalizeAndPrune(file).planDraftsByDateKey[key]
    }

    @discardableResult
    public func savePlanDraft(_ draft: DailyPlanDraft, replaceExisting: Bool) throws -> DailyPlanDraft {
        var file = normalizeAndPrune(try loadState())
        let normalized = Self.normalizeDraft(draft, calendar: calendar)
        let key = dateKey(for: normalized.date)
        if replaceExisting == false, file.planDraftsByDateKey[key] != nil {
            return file.planDraftsByDateKey[key] ?? normalized
        }
        file.planDraftsByDateKey[key] = normalized
        try persist(file)
        return normalized
    }

    public func clearPlanDraft(on date: Date) throws {
        var file = normalizeAndPrune(try loadState())
        file.planDraftsByDateKey.removeValue(forKey: dateKey(for: date))
        try persist(file)
    }

    private func loadState() throws -> LocalStateFile {
        guard let data = defaults.data(forKey: Self.storageKey) else {
            return LocalStateFile(
                completionDateKeys: defaults.stringArray(forKey: Self.legacyCompletionDefaultsKey) ?? [],
                payloadsByDateKey: [:],
                planDraftsByDateKey: [:]
            )
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(LocalStateFile.self, from: data)
        return LocalStateFile(
            completionDateKeys: decoded.completionDateKeys + (defaults.stringArray(forKey: Self.legacyCompletionDefaultsKey) ?? []),
            payloadsByDateKey: decoded.payloadsByDateKey,
            planDraftsByDateKey: decoded.planDraftsByDateKey
        )
    }

    private func persist(_ file: LocalStateFile) throws {
        let normalized = normalizeAndPrune(file)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        defaults.set(try encoder.encode(normalized), forKey: Self.storageKey)
        defaults.set(normalized.completionDateKeys, forKey: Self.legacyCompletionDefaultsKey)
    }

    private func normalizeAndPrune(_ file: LocalStateFile) -> LocalStateFile {
        var payloads: [String: ReflectionPayload] = [:]
        for payload in file.payloadsByDateKey.values {
            let normalized = Self.normalizePayload(payload, calendar: calendar)
            let key = dateKey(for: normalized.reflectionDate)
            if let existing = payloads[key] {
                if existing.updatedAt <= normalized.updatedAt {
                    payloads[key] = normalized
                }
            } else {
                payloads[key] = normalized
            }
        }

        var drafts: [String: DailyPlanDraft] = [:]
        for draft in file.planDraftsByDateKey.values {
            let normalized = Self.normalizeDraft(draft, calendar: calendar)
            let key = dateKey(for: normalized.date)
            if let existing = drafts[key] {
                if existing.updatedAt <= normalized.updatedAt {
                    drafts[key] = normalized
                }
            } else {
                drafts[key] = normalized
            }
        }

        let allKeys = Set(file.completionDateKeys)
            .union(payloads.keys)
            .union(drafts.keys)
        let keysToKeep = Set(
            allKeys
                .sorted(by: >)
                .prefix(Self.maxStoredDays)
        )

        let completionKeys = Array(Set(file.completionDateKeys))
            .filter { keysToKeep.contains($0) }
            .sorted()

        let filteredPayloads = payloads.filter { keysToKeep.contains($0.key) }
        let filteredDrafts = drafts.filter { keysToKeep.contains($0.key) }

        return LocalStateFile(
            completionDateKeys: completionKeys,
            payloadsByDateKey: filteredPayloads,
            planDraftsByDateKey: filteredDrafts
        )
    }

    private func normalizePersistedStateIfNeeded() {
        do {
            let loaded = try loadState()
            let normalized = normalizeAndPrune(loaded)
            guard normalized != loaded else {
                defaults.set(normalized.completionDateKeys, forKey: Self.legacyCompletionDefaultsKey)
                return
            }
            try persist(normalized)
        } catch {
            logWarning(
                event: "daily_reflection_store_normalize_failed",
                message: "Failed to normalize persisted daily reflection local state",
                fields: ["error": error.localizedDescription]
            )
        }
    }

    private func dateKey(for date: Date) -> String {
        stampFormatter.string(from: calendar.startOfDay(for: date))
    }

    private static func normalizePayload(_ payload: ReflectionPayload, calendar: Calendar) -> ReflectionPayload {
        let note = payload.note?
            .components(separatedBy: .newlines)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let boundedNote = note.flatMap { value -> String? in
            guard value.isEmpty == false else { return nil }
            return String(value.prefix(Self.maximumNoteLength))
        }

        return ReflectionPayload(
            reflectionDate: calendar.startOfDay(for: payload.reflectionDate),
            planningDate: calendar.startOfDay(for: payload.planningDate),
            mode: payload.mode,
            mood: payload.mood,
            energy: payload.energy,
            frictionTags: Array(Set(payload.frictionTags)).sorted { $0.rawValue < $1.rawValue },
            note: boundedNote,
            createdAt: payload.createdAt,
            updatedAt: payload.updatedAt
        )
    }

    private static func normalizeDraft(_ draft: DailyPlanDraft, calendar: Calendar) -> DailyPlanDraft {
        let topTasks = Array(
            Dictionary(uniqueKeysWithValues: draft.topTasks.map { ($0.id, $0) })
                .values
                .sorted { lhs, rhs in
                    if lhs.priority.scorePoints != rhs.priority.scorePoints {
                        return lhs.priority.scorePoints > rhs.priority.scorePoints
                    }
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                .prefix(3)
        )

        return DailyPlanDraft(
            date: calendar.startOfDay(for: draft.date),
            topTasks: topTasks,
            suggestedFocusBlock: draft.suggestedFocusBlock,
            protectedHabitID: draft.protectedHabitID,
            protectedHabitTitle: draft.protectedHabitTitle,
            protectedHabitStreak: draft.protectedHabitStreak,
            primaryRisk: draft.primaryRisk,
            primaryRiskDetail: draft.primaryRiskDetail,
            source: draft.source,
            updatedAt: draft.updatedAt
        )
    }
}
