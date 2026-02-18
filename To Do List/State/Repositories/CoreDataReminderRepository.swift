import Foundation
import CoreData

public final class CoreDataReminderRepository: ReminderRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
    }

    public func fetchReminders(completion: @escaping (Result<[ReminderDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "Reminder",
                    sort: [
                        NSSortDescriptor(key: "createdAt", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                let reminders = objects.map(Self.mapReminder)
                completion(.success(reminders))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func saveReminder(_ reminder: ReminderDefinition, completion: @escaping (Result<ReminderDefinition, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(reminder.id, field: "reminder.id")
                _ = try V2CoreDataRepositorySupport.requireID(reminder.sourceID, field: "reminder.sourceID")
                if let occurrenceID = reminder.occurrenceID {
                    _ = try V2CoreDataRepositorySupport.requireID(occurrenceID, field: "reminder.occurrenceID")
                }
                _ = try V2CoreDataRepositorySupport.requireNonEmpty(reminder.policy, field: "reminder.policy")
                let object = try V2CoreDataRepositorySupport.upsertByID(in: self.backgroundContext, entityName: "Reminder", id: reminder.id)
                object.setValue(reminder.id, forKey: "id")
                object.setValue(reminder.sourceType.rawValue, forKey: "sourceType")
                object.setValue(reminder.sourceID, forKey: "sourceID")
                object.setValue(reminder.occurrenceID, forKey: "occurrenceID")
                object.setValue(reminder.policy, forKey: "policy")
                object.setValue(Int32(reminder.channelMask), forKey: "channelMask")
                object.setValue(reminder.isEnabled, forKey: "isEnabled")
                object.setValue(reminder.createdAt, forKey: "createdAt")
                object.setValue(reminder.updatedAt, forKey: "updatedAt")
                try self.backgroundContext.save()
                completion(.success(reminder))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchTriggers(reminderID: UUID, completion: @escaping (Result<[ReminderTriggerDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(reminderID, field: "reminderTrigger.reminderID")
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "ReminderTrigger",
                    predicate: NSPredicate(format: "reminderID == %@", reminderID as CVarArg),
                    sort: [
                        NSSortDescriptor(key: "createdAt", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                completion(.success(objects.map(Self.mapTrigger)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func saveTrigger(_ trigger: ReminderTriggerDefinition, completion: @escaping (Result<ReminderTriggerDefinition, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(trigger.id, field: "reminderTrigger.id")
                _ = try V2CoreDataRepositorySupport.requireID(trigger.reminderID, field: "reminderTrigger.reminderID")
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "ReminderTrigger",
                    id: trigger.id
                )
                object.setValue(trigger.id, forKey: "id")
                object.setValue(trigger.reminderID, forKey: "reminderID")
                object.setValue(trigger.triggerType.rawValue, forKey: "triggerType")
                object.setValue(trigger.fireAt, forKey: "fireAt")
                object.setValue(trigger.offsetSeconds.map { Int32($0) }, forKey: "offsetSeconds")
                object.setValue(trigger.locationPayloadData, forKey: "locationPayloadData")
                object.setValue(trigger.createdAt, forKey: "createdAt")
                try self.backgroundContext.save()
                completion(.success(trigger))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func fetchDeliveries(reminderID: UUID, completion: @escaping (Result<[ReminderDeliveryDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(reminderID, field: "reminderDelivery.reminderID")
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "ReminderDelivery",
                    predicate: NSPredicate(format: "reminderID == %@", reminderID as CVarArg),
                    sort: [
                        NSSortDescriptor(key: "createdAt", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                completion(.success(objects.map(Self.mapDelivery)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    public func saveDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) {
        persistDelivery(delivery, completion: completion)
    }

    public func updateDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) {
        persistDelivery(delivery, completion: completion)
    }

    private func persistDelivery(_ delivery: ReminderDeliveryDefinition, completion: @escaping (Result<ReminderDeliveryDefinition, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(delivery.id, field: "reminderDelivery.id")
                _ = try V2CoreDataRepositorySupport.requireID(delivery.reminderID, field: "reminderDelivery.reminderID")
                _ = try V2CoreDataRepositorySupport.requireID(delivery.triggerID, field: "reminderDelivery.triggerID")
                _ = try V2CoreDataRepositorySupport.requireNonEmpty(delivery.status, field: "reminderDelivery.status")
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "ReminderDelivery",
                    id: delivery.id
                )
                object.setValue(delivery.id, forKey: "id")
                object.setValue(delivery.reminderID, forKey: "reminderID")
                object.setValue(delivery.triggerID, forKey: "triggerID")
                object.setValue(delivery.status, forKey: "status")
                object.setValue(delivery.scheduledAt, forKey: "scheduledAt")
                object.setValue(delivery.sentAt, forKey: "sentAt")
                object.setValue(delivery.ackAt, forKey: "ackAt")
                object.setValue(delivery.snoozedUntil, forKey: "snoozedUntil")
                object.setValue(delivery.errorCode, forKey: "errorCode")
                object.setValue(delivery.createdAt, forKey: "createdAt")
                try self.backgroundContext.save()
                completion(.success(delivery))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func mapReminder(_ object: NSManagedObject) -> ReminderDefinition {
        ReminderDefinition(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            sourceType: ReminderSourceType(rawValue: object.value(forKey: "sourceType") as? String ?? "task") ?? .task,
            sourceID: object.value(forKey: "sourceID") as? UUID ?? UUID(),
            occurrenceID: object.value(forKey: "occurrenceID") as? UUID,
            policy: object.value(forKey: "policy") as? String ?? "once",
            channelMask: Int(object.value(forKey: "channelMask") as? Int32 ?? 1),
            isEnabled: object.value(forKey: "isEnabled") as? Bool ?? true,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private static func mapTrigger(_ object: NSManagedObject) -> ReminderTriggerDefinition {
        let offset = object.value(forKey: "offsetSeconds") as? Int32
        return ReminderTriggerDefinition(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            reminderID: object.value(forKey: "reminderID") as? UUID ?? UUID(),
            triggerType: ReminderTriggerType(rawValue: object.value(forKey: "triggerType") as? String ?? "absolute") ?? .absolute,
            fireAt: object.value(forKey: "fireAt") as? Date,
            offsetSeconds: offset.map(Int.init),
            locationPayloadData: object.value(forKey: "locationPayloadData") as? Data,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
        )
    }

    private static func mapDelivery(_ object: NSManagedObject) -> ReminderDeliveryDefinition {
        ReminderDeliveryDefinition(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            reminderID: object.value(forKey: "reminderID") as? UUID ?? UUID(),
            triggerID: object.value(forKey: "triggerID") as? UUID ?? UUID(),
            status: object.value(forKey: "status") as? String ?? "scheduled",
            scheduledAt: object.value(forKey: "scheduledAt") as? Date,
            sentAt: object.value(forKey: "sentAt") as? Date,
            ackAt: object.value(forKey: "ackAt") as? Date,
            snoozedUntil: object.value(forKey: "snoozedUntil") as? Date,
            errorCode: object.value(forKey: "errorCode") as? String,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
        )
    }
}
