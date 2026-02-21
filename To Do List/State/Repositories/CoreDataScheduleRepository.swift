import Foundation
import CoreData

public final class CoreDataScheduleRepository: ScheduleRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
    }

    /// Executes fetchTemplates.
    public func fetchTemplates(completion: @escaping (Result<[ScheduleTemplateDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "ScheduleTemplate",
                    sort: [
                        NSSortDescriptor(key: "createdAt", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                let mapped = objects.map { object in
                    ScheduleTemplateDefinition(
                        id: object.value(forKey: "id") as? UUID ?? UUID(),
                        sourceType: ScheduleSourceType(rawValue: object.value(forKey: "sourceType") as? String ?? "task") ?? .task,
                        sourceID: object.value(forKey: "sourceID") as? UUID ?? UUID(),
                        timezoneID: object.value(forKey: "timezoneID") as? String,
                        temporalReference: TemporalReference(rawValue: object.value(forKey: "temporalReference") as? String ?? "anchored") ?? .anchored,
                        anchorAt: object.value(forKey: "anchorAt") as? Date,
                        windowStart: object.value(forKey: "windowStart") as? String,
                        windowEnd: object.value(forKey: "windowEnd") as? String,
                        isActive: object.value(forKey: "isActive") as? Bool ?? true,
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

    /// Executes fetchRules.
    public func fetchRules(templateID: UUID, completion: @escaping (Result<[ScheduleRuleDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(templateID, field: "scheduleRule.scheduleTemplateID")
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "ScheduleRule",
                    predicate: NSPredicate(format: "scheduleTemplateID == %@", templateID as CVarArg),
                    sort: [
                        NSSortDescriptor(key: "createdAt", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                let mapped = objects.map { object in
                    ScheduleRuleDefinition(
                        id: object.value(forKey: "id") as? UUID ?? UUID(),
                        scheduleTemplateID: object.value(forKey: "scheduleTemplateID") as? UUID ?? templateID,
                        ruleType: object.value(forKey: "ruleType") as? String ?? "daily",
                        interval: Int(object.value(forKey: "interval") as? Int32 ?? 1),
                        byDayMask: (object.value(forKey: "byDayMask") as? Int32).map(Int.init),
                        byMonthDay: (object.value(forKey: "byMonthDay") as? Int32).map(Int.init),
                        byHour: (object.value(forKey: "byHour") as? Int32).map(Int.init),
                        byMinute: (object.value(forKey: "byMinute") as? Int32).map(Int.init),
                        rawRuleData: object.value(forKey: "rawRuleData") as? Data,
                        createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
                    )
                }
                completion(.success(mapped))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes saveTemplate.
    public func saveTemplate(_ template: ScheduleTemplateDefinition, completion: @escaping (Result<ScheduleTemplateDefinition, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(template.id, field: "scheduleTemplate.id")
                _ = try V2CoreDataRepositorySupport.requireID(template.sourceID, field: "scheduleTemplate.sourceID")
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "ScheduleTemplate",
                    id: template.id
                )
                object.setValue(template.id, forKey: "id")
                object.setValue(template.sourceType.rawValue, forKey: "sourceType")
                object.setValue(template.sourceID, forKey: "sourceID")
                object.setValue(template.timezoneID, forKey: "timezoneID")
                object.setValue(template.temporalReference.rawValue, forKey: "temporalReference")
                object.setValue(template.anchorAt, forKey: "anchorAt")
                object.setValue(template.windowStart, forKey: "windowStart")
                object.setValue(template.windowEnd, forKey: "windowEnd")
                object.setValue(template.isActive, forKey: "isActive")
                object.setValue(template.createdAt, forKey: "createdAt")
                object.setValue(template.updatedAt, forKey: "updatedAt")
                try self.backgroundContext.save()
                completion(.success(template))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchExceptions.
    public func fetchExceptions(templateID: UUID, completion: @escaping (Result<[ScheduleExceptionDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(templateID, field: "scheduleException.scheduleTemplateID")
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "ScheduleException",
                    predicate: NSPredicate(format: "scheduleTemplateID == %@", templateID as CVarArg),
                    sort: [
                        NSSortDescriptor(key: "createdAt", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                let mapped = objects.map { object in
                    let resolvedTemplateID = object.value(forKey: "scheduleTemplateID") as? UUID ?? templateID
                    let templateRef = object.value(forKey: "templateRef") as? NSManagedObject
                    let templateSourceID = templateRef?.value(forKey: "sourceID") as? UUID
                    let rawOccurrenceKey = object.value(forKey: "occurrenceKey") as? String ?? ""
                    let canonicalOccurrenceKey = OccurrenceKeyCodec.canonicalize(
                        rawOccurrenceKey,
                        fallbackTemplateID: resolvedTemplateID,
                        fallbackSourceID: templateSourceID
                    ) ?? rawOccurrenceKey
                    return ScheduleExceptionDefinition(
                        id: object.value(forKey: "id") as? UUID ?? UUID(),
                        scheduleTemplateID: resolvedTemplateID,
                        occurrenceKey: canonicalOccurrenceKey,
                        action: ScheduleExceptionAction(rawValue: object.value(forKey: "action") as? String ?? "skip") ?? .skip,
                        movedToAt: object.value(forKey: "movedToAt") as? Date,
                        payloadData: object.value(forKey: "payloadData") as? Data,
                        createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
                    )
                }
                completion(.success(mapped))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes saveException.
    public func saveException(_ exception: ScheduleExceptionDefinition, completion: @escaping (Result<ScheduleExceptionDefinition, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(exception.id, field: "scheduleException.id")
                _ = try V2CoreDataRepositorySupport.requireID(
                    exception.scheduleTemplateID,
                    field: "scheduleException.scheduleTemplateID"
                )
                _ = try V2CoreDataRepositorySupport.requireNonEmpty(
                    exception.occurrenceKey,
                    field: "scheduleException.occurrenceKey"
                )
                let templateObject = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.backgroundContext,
                    entityName: "ScheduleTemplate",
                    predicate: NSPredicate(format: "id == %@", exception.scheduleTemplateID as CVarArg),
                    sort: [NSSortDescriptor(key: "id", ascending: true)]
                )
                let templateSourceID = templateObject?.value(forKey: "sourceID") as? UUID
                guard let canonicalOccurrenceKey = OccurrenceKeyCodec.canonicalize(
                    exception.occurrenceKey,
                    fallbackTemplateID: exception.scheduleTemplateID,
                    fallbackSourceID: templateSourceID
                ) else {
                    throw NSError(
                        domain: "CoreDataScheduleRepository",
                        code: 422,
                        userInfo: [NSLocalizedDescriptionKey: "Malformed occurrenceKey; expected canonical key with templateID, scheduledAt, and sourceID"]
                    )
                }
                let object = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "ScheduleException",
                    id: exception.id
                )
                object.setValue(exception.id, forKey: "id")
                object.setValue(exception.scheduleTemplateID, forKey: "scheduleTemplateID")
                object.setValue(canonicalOccurrenceKey, forKey: "occurrenceKey")
                object.setValue(exception.action.rawValue, forKey: "action")
                object.setValue(exception.movedToAt, forKey: "movedToAt")
                object.setValue(exception.payloadData, forKey: "payloadData")
                object.setValue(exception.createdAt, forKey: "createdAt")
                try self.backgroundContext.save()
                var normalized = exception
                normalized.occurrenceKey = canonicalOccurrenceKey
                completion(.success(normalized))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
