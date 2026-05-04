import Foundation
import CoreData

public final class CoreDataOccurrenceRepository: OccurrenceRepositoryProtocol, @unchecked Sendable {
    private let readContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.readContext = container.newBackgroundContext()
        self.readContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    /// Executes fetchInRange.
    public func fetchInRange(start: Date, end: Date, completion: @escaping @Sendable (Result<[OccurrenceDefinition], Error>) -> Void) {
        guard start <= end else {
            completion(.failure(NSError(
                domain: "CoreDataOccurrenceRepository",
                code: 422,
                userInfo: [NSLocalizedDescriptionKey: "start date must be earlier than end date"]
            )))
            return
        }
        readContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.readContext,
                    entityName: "Occurrence",
                    predicate: NSPredicate(format: "scheduledAt >= %@ AND scheduledAt <= %@", start as NSDate, end as NSDate),
                    sort: [
                        NSSortDescriptor(key: "scheduledAt", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                let mapped = objects.map(Self.mapOccurrence)
                completion(.success(mapped))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchByID.
    public func fetchByID(id: UUID, completion: @escaping @Sendable (Result<OccurrenceDefinition?, Error>) -> Void) {
        readContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.readContext,
                    entityName: "Occurrence",
                    predicate: NSPredicate(format: "id == %@", id as CVarArg),
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                )
                completion(.success(object.map(Self.mapOccurrence)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchLatestForHabit.
    public func fetchLatestForHabit(
        habitID: UUID,
        on date: Date,
        completion: @escaping @Sendable (Result<OccurrenceDefinition?, Error>) -> Void
    ) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        readContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.readContext,
                    entityName: "Occurrence",
                    predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [
                        NSPredicate(format: "sourceType == %@", ScheduleSourceType.habit.rawValue),
                        NSPredicate(format: "sourceID == %@", habitID as CVarArg),
                        NSPredicate(format: "scheduledAt >= %@", startOfDay as NSDate),
                        NSPredicate(format: "scheduledAt < %@", endOfDay as NSDate)
                    ]),
                    sort: [
                        NSSortDescriptor(key: "scheduledAt", ascending: false),
                        NSSortDescriptor(key: "updatedAt", ascending: false),
                        NSSortDescriptor(key: "id", ascending: false)
                    ]
                )
                completion(.success(object.map(Self.mapOccurrence)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes saveOccurrences.
    public func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                for occurrence in occurrences {
                    _ = try V2CoreDataRepositorySupport.requireID(occurrence.id, field: "occurrence.id")
                    _ = try V2CoreDataRepositorySupport.requireID(occurrence.scheduleTemplateID, field: "occurrence.scheduleTemplateID")
                    _ = try V2CoreDataRepositorySupport.requireID(occurrence.sourceID, field: "occurrence.sourceID")
                    _ = try V2CoreDataRepositorySupport.requireNonEmpty(occurrence.occurrenceKey, field: "occurrence.occurrenceKey")
                    let object = try V2CoreDataRepositorySupport.upsertByID(
                        in: self.backgroundContext,
                        entityName: "Occurrence",
                        id: occurrence.id
                    )
                    let persistedKey = (object.value(forKey: "occurrenceKey") as? String)?
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if let persistedKey, persistedKey.isEmpty == false, persistedKey != occurrence.occurrenceKey {
                        throw NSError(
                            domain: "CoreDataOccurrenceRepository",
                            code: 409,
                            userInfo: [
                                NSLocalizedDescriptionKey:
                                    "Occurrence key is immutable (id=\(occurrence.id.uuidString), existing=\(persistedKey), incoming=\(occurrence.occurrenceKey))"
                            ]
                        )
                    }
                    object.setValue(occurrence.id, forKey: "id")
                    object.setValue(persistedKey?.isEmpty == false ? persistedKey : occurrence.occurrenceKey, forKey: "occurrenceKey")
                    object.setValue(occurrence.scheduleTemplateID, forKey: "scheduleTemplateID")
                    object.setValue(occurrence.sourceType.rawValue, forKey: "sourceType")
                    object.setValue(occurrence.sourceID, forKey: "sourceID")
                    object.setValue(occurrence.scheduledAt, forKey: "scheduledAt")
                    object.setValue(occurrence.dueAt, forKey: "dueAt")
                    object.setValue(occurrence.state.rawValue, forKey: "state")
                    object.setValue(occurrence.isGenerated, forKey: "isGenerated")
                    object.setValue(occurrence.generationWindow, forKey: "generationWindow")
                    object.setValue(occurrence.createdAt, forKey: "createdAt")
                    object.setValue(occurrence.updatedAt, forKey: "updatedAt")
                }
                try self.backgroundContext.save()
                completion(.success(()))
            } catch {
                self.backgroundContext.rollback()
                completion(.failure(error))
            }
        }
    }

    /// Executes resolve.
    public func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(resolution.id, field: "occurrenceResolution.id")
                _ = try V2CoreDataRepositorySupport.requireID(resolution.occurrenceID, field: "occurrenceResolution.occurrenceID")
                _ = try V2CoreDataRepositorySupport.requireNonEmpty(resolution.actor, field: "occurrenceResolution.actor")
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "OccurrenceResolution",
                    id: resolution.id
                )
                object.setValue(resolution.id, forKey: "id")
                object.setValue(resolution.occurrenceID, forKey: "occurrenceID")
                object.setValue(resolution.resolutionType.rawValue, forKey: "resolutionType")
                object.setValue(resolution.resolvedAt, forKey: "resolvedAt")
                object.setValue(resolution.actor, forKey: "actor")
                object.setValue(resolution.reason, forKey: "reason")
                object.setValue(resolution.createdAt, forKey: "createdAt")

                if let occurrence = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.backgroundContext,
                    entityName: "Occurrence",
                    predicate: NSPredicate(format: "id == %@", resolution.occurrenceID as CVarArg),
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                ) {
                    let nextState: String
                    switch resolution.resolutionType {
                    case .completed:
                        nextState = OccurrenceState.completed.rawValue
                    case .skipped, .deferred:
                        nextState = OccurrenceState.skipped.rawValue
                    case .missed:
                        nextState = OccurrenceState.missed.rawValue
                    case .lapsed:
                        nextState = OccurrenceState.failed.rawValue
                    }
                    occurrence.setValue(nextState, forKey: "state")
                    occurrence.setValue(resolution.resolvedAt, forKey: "updatedAt")
                }
                try self.backgroundContext.save()
                completion(.success(()))
            } catch {
                self.backgroundContext.rollback()
                completion(.failure(error))
            }
        }
    }

    /// Executes deleteOccurrences.
    public func deleteOccurrences(ids: [UUID], completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                for id in ids {
                    _ = try V2CoreDataRepositorySupport.requireID(id, field: "occurrence.id")
                    guard
                        let object = try V2CoreDataRepositorySupport.fetchObject(
                            in: self.backgroundContext,
                            entityName: "Occurrence",
                            predicate: NSPredicate(format: "id == %@", id as CVarArg),
                            sort: [NSSortDescriptor(key: "id", ascending: true)]
                        )
                    else { continue }
                    self.backgroundContext.delete(object)
                }
                try self.backgroundContext.save()
                completion(.success(()))
            } catch {
                self.backgroundContext.rollback()
                completion(.failure(error))
            }
        }
    }

    /// Executes fallbackOccurrenceKey.
    private static func fallbackOccurrenceKey(
        scheduleTemplateID: UUID,
        scheduledAt: Date,
        sourceID: UUID
    ) -> String {
        OccurrenceKeyCodec.encode(
            scheduleTemplateID: scheduleTemplateID,
            scheduledAt: scheduledAt,
            sourceID: sourceID
        )
    }

    private static func mapOccurrence(_ object: NSManagedObject) -> OccurrenceDefinition {
        let scheduleTemplateID = object.value(forKey: "scheduleTemplateID") as? UUID ?? UUID()
        let sourceID = object.value(forKey: "sourceID") as? UUID ?? UUID()
        let scheduledAt = object.value(forKey: "scheduledAt") as? Date ?? Date()
        let fallbackKey = fallbackOccurrenceKey(
            scheduleTemplateID: scheduleTemplateID,
            scheduledAt: scheduledAt,
            sourceID: sourceID
        )
        return OccurrenceDefinition(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            occurrenceKey: object.value(forKey: "occurrenceKey") as? String ?? fallbackKey,
            scheduleTemplateID: scheduleTemplateID,
            sourceType: ScheduleSourceType(rawValue: object.value(forKey: "sourceType") as? String ?? "task") ?? .task,
            sourceID: sourceID,
            scheduledAt: scheduledAt,
            dueAt: object.value(forKey: "dueAt") as? Date,
            state: OccurrenceState(rawValue: object.value(forKey: "state") as? String ?? "pending") ?? .pending,
            isGenerated: object.value(forKey: "isGenerated") as? Bool ?? true,
            generationWindow: object.value(forKey: "generationWindow") as? String,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }
}
