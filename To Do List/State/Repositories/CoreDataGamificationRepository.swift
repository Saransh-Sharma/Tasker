import Foundation
import CoreData

public final class CoreDataGamificationRepository: GamificationRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
    }

    public func fetchProfile(completion: @escaping (Result<GamificationSnapshot?, Error>) -> Void) {
        viewContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.viewContext,
                    entityName: "GamificationProfile",
                    predicate: NSPredicate(value: true)
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
                    updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
                )
                completion(.success(snapshot))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func saveProfile(_ profile: GamificationSnapshot, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "GamificationProfile",
                    id: profile.id
                )
                object.setValue(profile.id, forKey: "id")
                object.setValue(profile.xpTotal, forKey: "xpTotal")
                object.setValue(Int32(profile.level), forKey: "level")
                object.setValue(Int32(profile.currentStreak), forKey: "currentStreak")
                object.setValue(Int32(profile.bestStreak), forKey: "bestStreak")
                object.setValue(profile.lastActiveDate, forKey: "lastActiveDate")
                object.setValue(profile.updatedAt, forKey: "updatedAt")
                try self.backgroundContext.save()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchXPEvents(completion: @escaping (Result<[XPEventDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
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
                        createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
                    )
                }
                completion(.success(events))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func saveXPEvent(_ event: XPEventDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                let existing = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.backgroundContext,
                    entityName: "XPEvent",
                    predicate: NSPredicate(format: "idempotencyKey == %@", event.idempotencyKey)
                )
                if existing != nil {
                    completion(.success(()))
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
                object.setValue(event.idempotencyKey, forKey: "idempotencyKey")
                object.setValue(event.createdAt, forKey: "createdAt")
                try self.backgroundContext.save()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchAchievementUnlocks(completion: @escaping (Result<[AchievementUnlockDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
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

    public func saveAchievementUnlock(_ unlock: AchievementUnlockDefinition, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                let existing = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.backgroundContext,
                    entityName: "AchievementUnlock",
                    predicate: NSPredicate(format: "achievementKey == %@", unlock.achievementKey)
                )
                guard existing == nil else {
                    completion(.success(()))
                    return
                }
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "AchievementUnlock",
                    id: unlock.id
                )
                object.setValue(unlock.id, forKey: "id")
                object.setValue(unlock.achievementKey, forKey: "achievementKey")
                object.setValue(unlock.unlockedAt, forKey: "unlockedAt")
                object.setValue(unlock.sourceEventID, forKey: "sourceEventID")
                try self.backgroundContext.save()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
