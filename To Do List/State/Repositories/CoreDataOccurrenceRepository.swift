import Foundation
import CoreData

public final class CoreDataOccurrenceRepository: OccurrenceRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
    }

    public func fetchInRange(start: Date, end: Date, completion: @escaping (Result<[OccurrenceDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "Occurrence",
                    predicate: NSPredicate(format: "scheduledAt >= %@ AND scheduledAt <= %@", start as NSDate, end as NSDate),
                    sort: [NSSortDescriptor(key: "scheduledAt", ascending: true)]
                )
                let mapped = objects.map { object in
                    OccurrenceDefinition(
                        id: object.value(forKey: "id") as? UUID ?? UUID(),
                        occurrenceKey: object.value(forKey: "occurrenceKey") as? String ?? UUID().uuidString,
                        scheduleTemplateID: object.value(forKey: "scheduleTemplateID") as? UUID ?? UUID(),
                        sourceType: ScheduleSourceType(rawValue: object.value(forKey: "sourceType") as? String ?? "task") ?? .task,
                        sourceID: object.value(forKey: "sourceID") as? UUID ?? UUID(),
                        scheduledAt: object.value(forKey: "scheduledAt") as? Date ?? Date(),
                        dueAt: object.value(forKey: "dueAt") as? Date,
                        state: OccurrenceState(rawValue: object.value(forKey: "state") as? String ?? "pending") ?? .pending,
                        isGenerated: object.value(forKey: "isGenerated") as? Bool ?? true,
                        generationWindow: object.value(forKey: "generationWindow") as? String,
                        createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
                        updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
                    )
                }
                completion(.success(mapped))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func saveOccurrences(_ occurrences: [OccurrenceDefinition], completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                for occurrence in occurrences {
                    let object = try V2CoreDataRepositorySupport.upsertByID(
                        in: self.backgroundContext,
                        entityName: "Occurrence",
                        id: occurrence.id
                    )
                    object.setValue(occurrence.id, forKey: "id")
                    object.setValue(occurrence.occurrenceKey, forKey: "occurrenceKey")
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
                completion(.failure(error))
            }
        }
    }

    public func resolve(_ resolution: OccurrenceResolutionDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
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
                    predicate: NSPredicate(format: "id == %@", resolution.occurrenceID as CVarArg)
                ) {
                    let nextState: String
                    switch resolution.resolutionType {
                    case .completed:
                        nextState = OccurrenceState.completed.rawValue
                    case .skipped, .deferred:
                        nextState = OccurrenceState.skipped.rawValue
                    case .missed:
                        nextState = OccurrenceState.missed.rawValue
                    }
                    occurrence.setValue(nextState, forKey: "state")
                    occurrence.setValue(resolution.resolvedAt, forKey: "updatedAt")
                    if resolution.resolutionType == .deferred {
                        let originalKey = occurrence.value(forKey: "occurrenceKey") as? String ?? UUID().uuidString
                        occurrence.setValue("\(originalKey)_deferred_\(Int(resolution.resolvedAt.timeIntervalSince1970))", forKey: "occurrenceKey")
                    }
                }
                try self.backgroundContext.save()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
