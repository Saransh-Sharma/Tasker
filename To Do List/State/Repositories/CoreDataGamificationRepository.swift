import Foundation
import CoreData

public final class CoreDataGamificationRepository: GamificationRepositoryProtocol {
    private let readContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let schemaValidationError: NSError?

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.readContext = container.newBackgroundContext()
        self.backgroundContext = container.newBackgroundContext()
        self.readContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        self.readContext.automaticallyMergesChangesFromParent = true
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.backgroundContext.transactionAuthor = "tasker.gamification.local"
        self.schemaValidationError = Self.validateSchema(in: container.managedObjectModel)
        if let schemaValidationError {
            logError(
                event: "gamification_schema_guard_failed",
                message: "Gamification repository disabled because required Core Data schema is missing",
                fields: [
                    "error": schemaValidationError.localizedDescription,
                    "details": schemaValidationError.userInfo["missingRequirements"] as? String ?? "unknown"
                ]
            )
        }
    }

    public func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) {
        guard guardSchemaReady(completion: completion) else { return }
        readContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.readContext,
                    entityName: "GamificationProfile",
                    predicate: NSPredicate(value: true),
                    sort: [
                        NSSortDescriptor(key: "updatedAt", ascending: false),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                guard let object else {
                    completion(.success(nil))
                    return
                }
                let snapshot = GamificationSnapshot(
                    id: object.value(forKey: "id") as? UUID ?? UUID(),
                    xpTotal: object.value(forKey: "xpTotal") as? Int64 ?? 0,
                    level: Int(object.value(forKey: "level") as? Int32 ?? 1),
                    currentStreak: Int(object.value(forKey: "currentStreak") as? Int32 ?? 0),
                    bestStreak: Int(object.value(forKey: "bestStreak") as? Int32 ?? 0),
                    lastActiveDate: object.value(forKey: "lastActiveDate") as? Date,
                    updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date(),
                    gamificationV2ActivatedAt: object.value(forKey: "gamificationV2ActivatedAt") as? Date,
                    nextLevelXP: object.value(forKey: "nextLevelXP") as? Int64 ?? 0,
                    returnStreak: Int(object.value(forKey: "returnStreak") as? Int32 ?? 0),
                    bestReturnStreak: Int(object.value(forKey: "bestReturnStreak") as? Int32 ?? 0)
                )
                completion(.success(snapshot))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes saveProfile.
    public func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) {
        guard guardSchemaReady(completion: completion) else { return }
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(profile.id, field: "gamificationProfile.id")
                let object = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "GamificationProfile",
                    predicate: NSPredicate(value: true),
                    sort: [
                        NSSortDescriptor(key: "updatedAt", ascending: false),
                        NSSortDescriptor(key: "id", ascending: true)
                    ],
                    createIfMissing: true
                )
                guard let object else {
                    throw NSError(
                        domain: "CoreDataGamificationRepository",
                        code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create canonical GamificationProfile row"]
                    )
                }
                let canonicalID = (object.value(forKey: "id") as? UUID) ?? profile.id
                let incomingLevel = Int32(profile.level)
                let incomingCurrentStreak = Int32(profile.currentStreak)
                let incomingBestStreak = Int32(profile.bestStreak)
                let incomingReturnStreak = Int32(profile.returnStreak)
                let incomingBestReturnStreak = Int32(profile.bestReturnStreak)

                let existingMatches = (object.value(forKey: "id") as? UUID ?? canonicalID) == canonicalID
                    && (object.value(forKey: "xpTotal") as? Int64 ?? 0) == profile.xpTotal
                    && (object.value(forKey: "level") as? Int32 ?? 0) == incomingLevel
                    && (object.value(forKey: "currentStreak") as? Int32 ?? 0) == incomingCurrentStreak
                    && (object.value(forKey: "bestStreak") as? Int32 ?? 0) == incomingBestStreak
                    && (object.value(forKey: "lastActiveDate") as? Date) == profile.lastActiveDate
                    && (object.value(forKey: "updatedAt") as? Date) == profile.updatedAt
                    && (object.value(forKey: "gamificationV2ActivatedAt") as? Date) == profile.gamificationV2ActivatedAt
                    && (object.value(forKey: "nextLevelXP") as? Int64 ?? 0) == profile.nextLevelXP
                    && (object.value(forKey: "returnStreak") as? Int32 ?? 0) == incomingReturnStreak
                    && (object.value(forKey: "bestReturnStreak") as? Int32 ?? 0) == incomingBestReturnStreak

                if existingMatches {
                    self.finalizeWrite(completion: completion)
                    return
                }
                object.setValue(canonicalID, forKey: "id")
                object.setValue(profile.xpTotal, forKey: "xpTotal")
                object.setValue(incomingLevel, forKey: "level")
                object.setValue(incomingCurrentStreak, forKey: "currentStreak")
                object.setValue(incomingBestStreak, forKey: "bestStreak")
                object.setValue(profile.lastActiveDate, forKey: "lastActiveDate")
                object.setValue(profile.updatedAt, forKey: "updatedAt")
                object.setValue(profile.gamificationV2ActivatedAt, forKey: "gamificationV2ActivatedAt")
                object.setValue(profile.nextLevelXP, forKey: "nextLevelXP")
                object.setValue(incomingReturnStreak, forKey: "returnStreak")
                object.setValue(incomingBestReturnStreak, forKey: "bestReturnStreak")
                try self.backgroundContext.save()
                self.finalizeWrite(completion: completion)
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchXPEvents.
    public func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        guard guardSchemaReady(completion: completion) else { return }
        readContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.readContext,
                    entityName: "XPEvent",
                    sort: [NSSortDescriptor(key: "createdAt", ascending: true)]
                )
                let events = objects.map { object in
                    XPEventDefinition(
                        id: object.value(forKey: "id") as? UUID ?? UUID(),
                        occurrenceID: object.value(forKey: "occurrenceID") as? UUID,
                        taskID: object.value(forKey: "taskID") as? UUID,
                        delta: Int(object.value(forKey: "delta") as? Int32 ?? 0),
                        reason: object.value(forKey: "reason") as? String ?? "task_completion",
                        idempotencyKey: object.value(forKey: "idempotencyKey") as? String ?? UUID().uuidString,
                        createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
                        category: (object.value(forKey: "category") as? String).flatMap(XPActionCategory.init(rawValue:)),
                        source: (object.value(forKey: "source") as? String).flatMap(XPSource.init(rawValue:)),
                        qualityWeight: object.value(forKey: "qualityWeight") as? Double,
                        periodKey: object.value(forKey: "periodKey") as? String,
                        metadataBlob: object.value(forKey: "metadataBlob") as? Data
                    )
                }
                completion(.success(events))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes saveXPEvent.
    public func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        guard guardSchemaReady(completion: completion) else { return }
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(event.id, field: "xpEvent.id")
                let normalizedIdempotencyKey = try V2CoreDataRepositorySupport.requireNonEmpty(
                    event.idempotencyKey,
                    field: "xpEvent.idempotencyKey"
                )
                let existing = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "XPEvent",
                    predicate: NSPredicate(format: "idempotencyKey == %@", normalizedIdempotencyKey),
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                )
                if existing != nil {
                    if self.backgroundContext.hasChanges {
                        try self.backgroundContext.save()
                    }
                    self.finalizeWrite(completion: completion)
                    return
                }
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "XPEvent",
                    id: event.id
                )
                object.setValue(event.id, forKey: "id")
                object.setValue(event.occurrenceID, forKey: "occurrenceID")
                object.setValue(event.taskID, forKey: "taskID")
                object.setValue(Int32(event.delta), forKey: "delta")
                object.setValue(event.reason, forKey: "reason")
                object.setValue(normalizedIdempotencyKey, forKey: "idempotencyKey")
                object.setValue(event.createdAt, forKey: "createdAt")
                object.setValue(event.category?.rawValue, forKey: "category")
                object.setValue(event.source?.rawValue, forKey: "source")
                object.setValue(event.qualityWeight.map { Float($0) }, forKey: "qualityWeight")
                object.setValue(event.periodKey, forKey: "periodKey")
                object.setValue(event.metadataBlob, forKey: "metadataBlob")
                try self.backgroundContext.save()
                self.finalizeWrite(completion: completion)
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchAchievementUnlocks.
    public func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) {
        guard guardSchemaReady(completion: completion) else { return }
        readContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.readContext,
                    entityName: "AchievementUnlock",
                    sort: [NSSortDescriptor(key: "unlockedAt", ascending: true)]
                )
                let unlocks = objects.map { object in
                    AchievementUnlockDefinition(
                        id: object.value(forKey: "id") as? UUID ?? UUID(),
                        achievementKey: object.value(forKey: "achievementKey") as? String ?? "",
                        unlockedAt: object.value(forKey: "unlockedAt") as? Date ?? Date(),
                        sourceEventID: object.value(forKey: "sourceEventID") as? UUID
                    )
                }
                completion(.success(unlocks))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes saveAchievementUnlock.
    public func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        guard guardSchemaReady(completion: completion) else { return }
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(unlock.id, field: "achievementUnlock.id")
                let normalizedAchievementKey = try V2CoreDataRepositorySupport.requireNonEmpty(
                    unlock.achievementKey,
                    field: "achievementUnlock.achievementKey"
                )
                let existing = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "AchievementUnlock",
                    predicate: NSPredicate(format: "achievementKey == %@", normalizedAchievementKey),
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                )
                guard existing == nil else {
                    if self.backgroundContext.hasChanges {
                        try self.backgroundContext.save()
                    }
                    self.finalizeWrite(completion: completion)
                    return
                }
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "AchievementUnlock",
                    id: unlock.id
                )
                object.setValue(unlock.id, forKey: "id")
                object.setValue(normalizedAchievementKey, forKey: "achievementKey")
                object.setValue(unlock.unlockedAt, forKey: "unlockedAt")
                object.setValue(unlock.sourceEventID, forKey: "sourceEventID")
                try self.backgroundContext.save()
                self.finalizeWrite(completion: completion)
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - XP Events (Date Range)

    public func fetchXPEvents(from startDate: Date, to endDate: Date, completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        guard guardSchemaReady(completion: completion) else { return }
        readContext.perform {
            do {
                let predicate = NSPredicate(format: "createdAt >= %@ AND createdAt < %@", startDate as NSDate, endDate as NSDate)
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.readContext,
                    entityName: "XPEvent",
                    predicate: predicate,
                    sort: [NSSortDescriptor(key: "createdAt", ascending: true)]
                )
                let events = objects.map { object in
                    XPEventDefinition(
                        id: object.value(forKey: "id") as? UUID ?? UUID(),
                        occurrenceID: object.value(forKey: "occurrenceID") as? UUID,
                        taskID: object.value(forKey: "taskID") as? UUID,
                        delta: Int(object.value(forKey: "delta") as? Int32 ?? 0),
                        reason: object.value(forKey: "reason") as? String ?? "task_completion",
                        idempotencyKey: object.value(forKey: "idempotencyKey") as? String ?? UUID().uuidString,
                        createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
                        category: (object.value(forKey: "category") as? String).flatMap(XPActionCategory.init(rawValue:)),
                        source: (object.value(forKey: "source") as? String).flatMap(XPSource.init(rawValue:)),
                        qualityWeight: object.value(forKey: "qualityWeight") as? Double,
                        periodKey: object.value(forKey: "periodKey") as? String,
                        metadataBlob: object.value(forKey: "metadataBlob") as? Data
                    )
                }
                completion(.success(events))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - XP Event Idempotency Check

    public func hasXPEvent(idempotencyKey: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard guardSchemaReady(completion: completion) else { return }
        readContext.perform {
            do {
                let normalizedKey = try V2CoreDataRepositorySupport.requireNonEmpty(
                    idempotencyKey,
                    field: "xpEvent.idempotencyKey"
                )
                let existing = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.readContext,
                    entityName: "XPEvent",
                    predicate: NSPredicate(format: "idempotencyKey == %@", normalizedKey),
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                )
                completion(.success(existing != nil))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Daily XP Aggregates

    public func fetchDailyAggregate(dateKey: String, completion: @escaping (Result<DailyXPAggregateDefinition?, Error>) -> Void) {
        guard guardSchemaReady(completion: completion) else { return }
        readContext.perform {
            do {
                let normalizedDateKey = try V2CoreDataRepositorySupport.requireNonEmpty(
                    dateKey,
                    field: "dailyXPAggregate.dateKey"
                )
                let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.readContext,
                    entityName: "DailyXPAggregate",
                    predicate: NSPredicate(format: "dateKey == %@", normalizedDateKey),
                    sort: [
                        NSSortDescriptor(key: "totalXP", ascending: false),
                        NSSortDescriptor(key: "eventCount", ascending: false),
                        NSSortDescriptor(key: "updatedAt", ascending: false),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                guard let object = object else {
                    completion(.success(nil))
                    return
                }
                let aggregate = DailyXPAggregateDefinition(
                    id: object.value(forKey: "id") as? UUID ?? UUID(),
                    dateKey: object.value(forKey: "dateKey") as? String ?? normalizedDateKey,
                    totalXP: Int(object.value(forKey: "totalXP") as? Int32 ?? 0),
                    eventCount: Int(object.value(forKey: "eventCount") as? Int32 ?? 0),
                    updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
                )
                completion(.success(aggregate))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func saveDailyAggregate(_ aggregate: DailyXPAggregateDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        guard guardSchemaReady(completion: completion) else { return }
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(aggregate.id, field: "dailyXPAggregate.id")
                let normalizedDateKey = try V2CoreDataRepositorySupport.requireNonEmpty(
                    aggregate.dateKey,
                    field: "dailyXPAggregate.dateKey"
                )
                let object = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "DailyXPAggregate",
                    predicate: NSPredicate(format: "dateKey == %@", normalizedDateKey),
                    sort: [
                        NSSortDescriptor(key: "totalXP", ascending: false),
                        NSSortDescriptor(key: "eventCount", ascending: false),
                        NSSortDescriptor(key: "updatedAt", ascending: false),
                        NSSortDescriptor(key: "id", ascending: true)
                    ],
                    createIfMissing: true
                )
                guard let object else {
                    throw NSError(
                        domain: "CoreDataGamificationRepository",
                        code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to create canonical DailyXPAggregate row"]
                    )
                }
                let canonicalID = (object.value(forKey: "id") as? UUID) ?? aggregate.id
                let incomingTotalXP = Int32(aggregate.totalXP)
                let incomingEventCount = Int32(aggregate.eventCount)
                let existingMatches = (object.value(forKey: "id") as? UUID ?? canonicalID) == canonicalID
                    && (object.value(forKey: "dateKey") as? String ?? normalizedDateKey) == normalizedDateKey
                    && (object.value(forKey: "totalXP") as? Int32 ?? 0) == incomingTotalXP
                    && (object.value(forKey: "eventCount") as? Int32 ?? 0) == incomingEventCount

                if existingMatches {
                    self.finalizeWrite(completion: completion)
                    return
                }
                object.setValue(canonicalID, forKey: "id")
                object.setValue(normalizedDateKey, forKey: "dateKey")
                object.setValue(incomingTotalXP, forKey: "totalXP")
                object.setValue(incomingEventCount, forKey: "eventCount")
                object.setValue(aggregate.updatedAt, forKey: "updatedAt")
                try self.backgroundContext.save()
                self.finalizeWrite(completion: completion)
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchDailyAggregates(from startDateKey: String, to endDateKey: String, completion: @escaping (Result<[DailyXPAggregateDefinition], Error>) -> Void) {
        guard guardSchemaReady(completion: completion) else { return }
        readContext.perform {
            do {
                let normalizedStartDateKey = try V2CoreDataRepositorySupport.requireNonEmpty(
                    startDateKey,
                    field: "dailyXPAggregate.startDateKey"
                )
                let normalizedEndDateKey = try V2CoreDataRepositorySupport.requireNonEmpty(
                    endDateKey,
                    field: "dailyXPAggregate.endDateKey"
                )
                let predicate = NSPredicate(
                    format: "dateKey >= %@ AND dateKey <= %@",
                    normalizedStartDateKey,
                    normalizedEndDateKey
                )
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.readContext,
                    entityName: "DailyXPAggregate",
                    predicate: predicate,
                    sort: [
                        NSSortDescriptor(key: "dateKey", ascending: true),
                        NSSortDescriptor(key: "totalXP", ascending: false),
                        NSSortDescriptor(key: "updatedAt", ascending: false),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                let rawAggregates = objects.map { object in
                    DailyXPAggregateDefinition(
                        id: object.value(forKey: "id") as? UUID ?? UUID(),
                        dateKey: object.value(forKey: "dateKey") as? String ?? "",
                        totalXP: Int(object.value(forKey: "totalXP") as? Int32 ?? 0),
                        eventCount: Int(object.value(forKey: "eventCount") as? Int32 ?? 0),
                        updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
                    )
                }
                var canonicalByDateKey: [String: DailyXPAggregateDefinition] = [:]
                for aggregate in rawAggregates where aggregate.dateKey.isEmpty == false {
                    guard let existing = canonicalByDateKey[aggregate.dateKey] else {
                        canonicalByDateKey[aggregate.dateKey] = aggregate
                        continue
                    }
                    let incomingWins = aggregate.totalXP > existing.totalXP
                        || (aggregate.totalXP == existing.totalXP && aggregate.updatedAt > existing.updatedAt)
                    if incomingWins {
                        canonicalByDateKey[aggregate.dateKey] = aggregate
                    }
                }
                let aggregates = canonicalByDateKey.values.sorted { $0.dateKey < $1.dateKey }
                completion(.success(aggregates))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Focus Sessions

    public func createFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        guard guardSchemaReady(completion: completion) else { return }
        backgroundContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "FocusSession",
                    id: session.id
                )
                self.applyFocusSessionValues(session, to: object)
                try self.backgroundContext.save()
                self.finalizeWrite(completion: completion)
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func updateFocusSession(_ session: FocusSessionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        guard guardSchemaReady(completion: completion) else { return }
        backgroundContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "FocusSession",
                    id: session.id
                )
                self.applyFocusSessionValues(session, to: object)
                try self.backgroundContext.save()
                self.finalizeWrite(completion: completion)
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchFocusSessions(from startDate: Date, to endDate: Date, completion: @escaping (Result<[FocusSessionDefinition], Error>) -> Void) {
        guard guardSchemaReady(completion: completion) else { return }
        readContext.perform {
            do {
                let predicate = NSPredicate(format: "startedAt >= %@ AND startedAt < %@", startDate as NSDate, endDate as NSDate)
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.readContext,
                    entityName: "FocusSession",
                    predicate: predicate,
                    sort: [NSSortDescriptor(key: "startedAt", ascending: true)]
                )
                let sessions = objects.map { object in
                    FocusSessionDefinition(
                        id: object.value(forKey: "id") as? UUID ?? UUID(),
                        taskID: object.value(forKey: "taskID") as? UUID,
                        startedAt: object.value(forKey: "startedAt") as? Date ?? Date(),
                        endedAt: object.value(forKey: "endedAt") as? Date,
                        durationSeconds: Int(object.value(forKey: "durationSeconds") as? Int32 ?? 0),
                        targetDurationSeconds: Int(object.value(forKey: "targetDurationSeconds") as? Int32 ?? 0),
                        wasCompleted: object.value(forKey: "wasCompleted") as? Bool ?? false,
                        xpAwarded: Int(object.value(forKey: "xpAwarded") as? Int32 ?? 0)
                    )
                }
                completion(.success(sessions))
            } catch {
                completion(.failure(error))
            }
        }
    }

    // MARK: - Private Helpers

    private func guardSchemaReady<T>(completion: @escaping (Result<T, Error>) -> Void) -> Bool {
        guard let schemaValidationError else { return true }
        completion(.failure(schemaValidationError))
        return false
    }

    private func finalizeWrite(completion: @escaping (Result<Void, Error>) -> Void) {
        readContext.perform {
            let registeredObjectCount = self.readContext.registeredObjects.count
            self.readContext.reset()
            #if DEBUG
            logDebug(
                "gamification_read_context_reset_after_write " +
                    "registered_objects=\(registeredObjectCount)"
            )
            #endif
            completion(.success(()))
        }
    }

    private static func validateSchema(in model: NSManagedObjectModel) -> NSError? {
        let requiredSchema: [String: Set<String>] = [
            "GamificationProfile": [
                "id", "xpTotal", "level", "currentStreak", "bestStreak", "lastActiveDate", "updatedAt",
                "gamificationV2ActivatedAt", "nextLevelXP", "returnStreak", "bestReturnStreak"
            ],
            "XPEvent": [
                "id", "occurrenceID", "taskID", "delta", "reason", "idempotencyKey", "createdAt",
                "category", "source", "qualityWeight", "periodKey", "metadataBlob"
            ],
            "AchievementUnlock": ["id", "achievementKey", "unlockedAt", "sourceEventID"],
            "DailyXPAggregate": ["id", "dateKey", "totalXP", "eventCount", "updatedAt"],
            "FocusSession": [
                "id", "taskID", "startedAt", "endedAt", "durationSeconds", "targetDurationSeconds",
                "wasCompleted", "xpAwarded"
            ]
        ]

        let entitiesByName = model.entitiesByName
        var missingRequirements: [String] = []

        for (entityName, requiredAttributes) in requiredSchema {
            guard let entity = entitiesByName[entityName] else {
                missingRequirements.append("\(entityName):missing_entity")
                continue
            }
            let existing = Set(entity.attributesByName.keys)
            let missing = requiredAttributes.subtracting(existing).sorted()
            if missing.isEmpty == false {
                missingRequirements.append("\(entityName):\(missing.joined(separator: ","))")
            }
        }

        guard missingRequirements.isEmpty == false else {
            return nil
        }

        let details = missingRequirements.joined(separator: "; ")
        return NSError(
            domain: "CoreDataGamificationRepository.Schema",
            code: 500,
            userInfo: [
                NSLocalizedDescriptionKey: "Gamification Core Data schema requirements are missing",
                "missingRequirements": details
            ]
        )
    }

    private func applyFocusSessionValues(_ session: FocusSessionDefinition, to object: NSManagedObject) {
        object.setValue(session.id, forKey: "id")
        object.setValue(session.taskID, forKey: "taskID")
        object.setValue(session.startedAt, forKey: "startedAt")
        object.setValue(session.endedAt, forKey: "endedAt")
        object.setValue(Int32(session.durationSeconds), forKey: "durationSeconds")
        object.setValue(Int32(session.targetDurationSeconds), forKey: "targetDurationSeconds")
        object.setValue(session.wasCompleted, forKey: "wasCompleted")
        object.setValue(Int32(session.xpAwarded), forKey: "xpAwarded")
    }
}
