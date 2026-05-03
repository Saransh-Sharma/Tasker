import Foundation
import CoreData

private enum TaskDefinitionRowRepair {
    static let sentinelDate = Date(timeIntervalSinceReferenceDate: 0)

    static func repairedUUID(for entity: NSManagedObject, field: String, repairs: inout [String]) -> UUID {
        repairs.append(field)
        let entityURI = entity.objectID.uriRepresentation().absoluteString
        return deterministicUUID(seed: "TaskDefinition:\(field):\(entityURI)")
    }

    static func repairedDate(
        _ value: Date?,
        fallbacks: [Date?],
        field: String,
        repairs: inout [String]
    ) -> Date {
        if let value {
            return value
        }
        repairs.append(field)
        return fallbacks.compactMap { $0 }.first ?? sentinelDate
    }

    static func logIfNeeded(repairs: [String], entity: NSManagedObject, path: String) {
        guard repairs.isEmpty == false else { return }
        logWarning(
            event: "task_definition_row_repaired",
            message: "Repaired malformed TaskDefinition row while mapping",
            component: "CoreDataTaskDefinitionRepository",
            fields: [
                "fields": repairs.joined(separator: ","),
                "object_id": entity.objectID.uriRepresentation().absoluteString,
                "path": path
            ]
        )
    }

    private static func deterministicUUID(seed: String) -> UUID {
        var first = UInt64(14_695_981_039_346_656_037)
        var second = UInt64(10_995_116_282_11)

        for byte in seed.utf8 {
            first ^= UInt64(byte)
            first &*= 1_099_511_628_211
            second &+= UInt64(byte)
            second &*= 1_099_511_628_211
        }

        let bytes = withUnsafeBytes(of: first.bigEndian, Array.init)
            + withUnsafeBytes(of: second.bigEndian, Array.init)

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], (bytes[6] & 0x0F) | 0x50, bytes[7],
            (bytes[8] & 0x3F) | 0x80, bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}

private struct TaskEntitySnapshot {
    private static let keys = [
        "id",
        "taskID",
        "projectID",
        "iconSymbolName",
        "recurrenceSeriesID",
        "habitDefinitionID",
        "lifeAreaID",
        "sectionID",
        "parentTaskID",
        "title",
        "notes",
        "taskType",
        "priority",
        "energy",
        "category",
        "context",
        "dueDate",
        "scheduledStartAt",
        "scheduledEndAt",
        "isAllDay",
        "isComplete",
        "dateAdded",
        "dateCompleted",
        "isEveningTask",
        "alertReminderTime",
        "estimatedDuration",
        "actualDuration",
        "repeatPatternData",
        "planningBucketRaw",
        "weeklyOutcomeID",
        "deferredFromWeekStart",
        "deferredCount",
        "replanCount",
        "createdAt",
        "updatedAt"
    ]

    private static func snapshotValues(from entity: NSManagedObject) -> [String: Any] {
        let availableKeys = Set(entity.entity.attributesByName.keys)
        let readableKeys = Self.keys.filter { availableKeys.contains($0) }
        guard readableKeys.isEmpty == false else { return [:] }
        return entity.dictionaryWithValues(forKeys: readableKeys)
    }

    let taskID: UUID
    let projectID: UUID
    let iconSymbolName: String?
    let recurrenceSeriesID: UUID?
    let habitDefinitionID: UUID?
    let lifeAreaID: UUID?
    let sectionID: UUID?
    let parentTaskID: UUID?
    let title: String
    let notes: String?
    let taskTypeRaw: Int32
    let priorityRaw: Int32
    let energyRaw: String
    let categoryRaw: String
    let contextRaw: String
    let dueDate: Date?
    let scheduledStartAt: Date?
    let scheduledEndAt: Date?
    let isAllDay: Bool
    let isComplete: Bool
    let dateAdded: Date
    let dateCompleted: Date?
    let isEveningTask: Bool
    let alertReminderTime: Date?
    let estimatedDuration: Double?
    let actualDuration: Double?
    let repeatPatternData: Data?
    let planningBucketRaw: String?
    let weeklyOutcomeID: UUID?
    let deferredFromWeekStart: Date?
    let deferredCount: Int
    let replanCount: Int
    let createdAt: Date
    let updatedAt: Date
    let fallbackProjectName: String?

    init(entity: NSManagedObject) {
        let values = Self.snapshotValues(from: entity)
        var repairs: [String] = []
        self.taskID = (values["taskID"] as? UUID)
            ?? (values["id"] as? UUID)
            ?? TaskDefinitionRowRepair.repairedUUID(for: entity, field: "taskID", repairs: &repairs)
        if let projectID = values["projectID"] as? UUID {
            self.projectID = projectID
        } else {
            repairs.append("projectID")
            self.projectID = ProjectConstants.inboxProjectID
        }
        self.iconSymbolName = values["iconSymbolName"] as? String
        self.recurrenceSeriesID = values["recurrenceSeriesID"] as? UUID
        self.habitDefinitionID = values["habitDefinitionID"] as? UUID
        self.lifeAreaID = values["lifeAreaID"] as? UUID
        self.sectionID = values["sectionID"] as? UUID
        self.parentTaskID = values["parentTaskID"] as? UUID
        self.title = (values["title"] as? String) ?? "Untitled Task"
        self.notes = values["notes"] as? String
        self.taskTypeRaw = (values["taskType"] as? Int32) ?? 1
        self.priorityRaw = (values["priority"] as? Int32) ?? 2
        self.energyRaw = (values["energy"] as? String) ?? ""
        self.categoryRaw = (values["category"] as? String) ?? ""
        self.contextRaw = (values["context"] as? String) ?? ""
        self.dueDate = values["dueDate"] as? Date
        self.scheduledStartAt = values["scheduledStartAt"] as? Date
        self.scheduledEndAt = values["scheduledEndAt"] as? Date
        self.isAllDay = (values["isAllDay"] as? Bool) ?? false
        self.isComplete = (values["isComplete"] as? Bool) ?? false
        let dateAdded = values["dateAdded"] as? Date
        let createdAt = values["createdAt"] as? Date
        let updatedAt = values["updatedAt"] as? Date
        self.dateAdded = TaskDefinitionRowRepair.repairedDate(
            dateAdded,
            fallbacks: [createdAt, updatedAt],
            field: "dateAdded",
            repairs: &repairs
        )
        self.dateCompleted = values["dateCompleted"] as? Date
        self.isEveningTask = (values["isEveningTask"] as? Bool) ?? false
        self.alertReminderTime = values["alertReminderTime"] as? Date
        self.estimatedDuration = (values["estimatedDuration"] as? Double).flatMap { $0 > 0 ? $0 : nil }
        self.actualDuration = (values["actualDuration"] as? Double).flatMap { $0 > 0 ? $0 : nil }
        self.repeatPatternData = values["repeatPatternData"] as? Data
        self.planningBucketRaw = values["planningBucketRaw"] as? String
        self.weeklyOutcomeID = values["weeklyOutcomeID"] as? UUID
        self.deferredFromWeekStart = values["deferredFromWeekStart"] as? Date
        self.deferredCount = max(0, (values["deferredCount"] as? Int32).map(Int.init) ?? 0)
        self.replanCount = max(0, (values["replanCount"] as? Int32).map(Int.init) ?? 0)
        self.createdAt = TaskDefinitionRowRepair.repairedDate(
            createdAt,
            fallbacks: [dateAdded, updatedAt],
            field: "createdAt",
            repairs: &repairs
        )
        self.updatedAt = TaskDefinitionRowRepair.repairedDate(
            updatedAt,
            fallbacks: [createdAt, dateAdded],
            field: "updatedAt",
            repairs: &repairs
        )

        if entity.entity.relationshipsByName["projectRef"] != nil,
           let projectRef = entity.value(forKey: "projectRef") as? NSManagedObject {
            let projectValues = projectRef.dictionaryWithValues(forKeys: ["name"])
            self.fallbackProjectName = projectValues["name"] as? String
        } else {
            self.fallbackProjectName = nil
        }
        TaskDefinitionRowRepair.logIfNeeded(repairs: repairs, entity: entity, path: "snapshot")
    }
}

private struct TaskTagLinkSnapshot {
    private static let keys = ["taskID", "tagID"]

    let taskID: UUID?
    let tagID: UUID?

    init(object: NSManagedObject) {
        let values = object.dictionaryWithValues(forKeys: Self.keys)
        self.taskID = values["taskID"] as? UUID
        self.tagID = values["tagID"] as? UUID
    }
}

private struct TaskDependencySnapshot {
    private static let keys = ["id", "taskID", "dependsOnTaskID", "kind", "createdAt"]

    let id: UUID
    let taskID: UUID?
    let dependsOnTaskID: UUID?
    let rawKind: String?
    let createdAt: Date

    init(object: NSManagedObject) {
        let values = object.dictionaryWithValues(forKeys: Self.keys)
        self.id = (values["id"] as? UUID) ?? UUID()
        self.taskID = values["taskID"] as? UUID
        self.dependsOnTaskID = values["dependsOnTaskID"] as? UUID
        self.rawKind = values["kind"] as? String
        self.createdAt = (values["createdAt"] as? Date) ?? Date()
    }
}

private struct ProjectNameSnapshot {
    private static let keys = ["id", "name"]

    let id: UUID?
    let name: String?

    init(object: NSManagedObject) {
        let values = object.dictionaryWithValues(forKeys: Self.keys)
        self.id = values["id"] as? UUID
        self.name = values["name"] as? String
    }
}

enum TaskDefinitionMutationApplier {
    static func applyCreateRequest(_ request: CreateTaskDefinitionRequest, to entity: NSManagedObject) {
        setAttribute("id", value: request.id, on: entity)
        setAttribute("taskID", value: request.id, on: entity)
        setAttribute("projectID", value: request.projectID, on: entity)
        setAttribute("iconSymbolName", value: request.iconSymbolName, on: entity)
        setAttribute("lifeAreaID", value: request.lifeAreaID, on: entity)
        setAttribute("sectionID", value: request.sectionID, on: entity)
        setAttribute("parentTaskID", value: request.parentTaskID, on: entity)
        setAttribute("recurrenceSeriesID", value: request.recurrenceSeriesID, on: entity)
        setAttribute("habitDefinitionID", value: request.habitDefinitionID, on: entity)
        setAttribute("title", value: request.title, on: entity)
        setAttribute("notes", value: request.details, on: entity)
        setAttribute("priority", value: request.priority.rawValue, on: entity)
        setAttribute("taskType", value: request.type.rawValue, on: entity)
        setAttribute("energy", value: request.energy.rawValue, on: entity)
        setAttribute("category", value: request.category.rawValue, on: entity)
        setAttribute("context", value: request.context.rawValue, on: entity)
        setAttribute("dueDate", value: request.dueDate, on: entity)
        setAttribute("scheduledStartAt", value: request.scheduledStartAt, on: entity)
        setAttribute("scheduledEndAt", value: request.scheduledEndAt, on: entity)
        setAttribute("isAllDay", value: request.isAllDay, on: entity)
        setAttribute("estimatedDuration", value: request.estimatedDuration, on: entity)
        setAttribute("actualDuration", value: nil, on: entity)
        setAttribute("repeatPatternData", value: encodeRepeatPattern(request.repeatPattern), on: entity)
        setAttribute("planningBucketRaw", value: request.planningBucket.rawValue, on: entity)
        setAttribute("weeklyOutcomeID", value: request.weeklyOutcomeID, on: entity)
        setAttribute("deferredFromWeekStart", value: request.deferredFromWeekStart, on: entity)
        setAttribute("deferredCount", value: Int32(request.deferredCount), on: entity)
        setAttribute("replanCount", value: Int32(max(0, request.replanCount)), on: entity)
        setAttribute("isComplete", value: false, on: entity)
        setAttribute("dateAdded", value: request.createdAt, on: entity)
        setAttribute("dateCompleted", value: nil, on: entity)
        setAttribute("isEveningTask", value: request.isEveningTask, on: entity)
        setAttribute("alertReminderTime", value: request.alertReminderTime, on: entity)
        setAttribute("createdAt", value: request.createdAt, on: entity)
        setAttribute("updatedAt", value: Date(), on: entity)
        setAttribute("status", value: "pending", on: entity)
        setAttribute("version", value: Int32(1), on: entity)
    }

    static func applyUpdateRequest(_ request: UpdateTaskDefinitionRequest, to entity: NSManagedObject) {
        if let title = request.title {
            setAttribute("title", value: title, on: entity)
        }
        if request.details != nil {
            setAttribute("notes", value: request.details, on: entity)
        }
        if let projectID = request.projectID {
            setAttribute("projectID", value: projectID, on: entity)
        }
        if request.clearIconSymbolName {
            setAttribute("iconSymbolName", value: nil, on: entity)
        } else if request.iconSymbolName != nil {
            setAttribute("iconSymbolName", value: request.iconSymbolName, on: entity)
        }
        if request.clearLifeArea {
            setAttribute("lifeAreaID", value: nil, on: entity)
        } else if request.lifeAreaID != nil {
            setAttribute("lifeAreaID", value: request.lifeAreaID, on: entity)
        }
        if request.clearSection {
            setAttribute("sectionID", value: nil, on: entity)
        } else if request.sectionID != nil {
            setAttribute("sectionID", value: request.sectionID, on: entity)
        }
        if request.clearParentTaskLink {
            setAttribute("parentTaskID", value: nil, on: entity)
        } else if let parentTaskID = request.parentTaskID {
            setAttribute("parentTaskID", value: parentTaskID, on: entity)
        }
        if let recurrenceSeriesID = request.recurrenceSeriesID {
            setAttribute("recurrenceSeriesID", value: recurrenceSeriesID, on: entity)
        }
        if let habitDefinitionID = request.habitDefinitionID {
            setAttribute("habitDefinitionID", value: habitDefinitionID, on: entity)
        }
        if request.clearDueDate {
            setAttribute("dueDate", value: nil, on: entity)
        } else if let dueDate = request.dueDate {
            setAttribute("dueDate", value: dueDate, on: entity)
        }
        if request.clearScheduledStartAt {
            setAttribute("scheduledStartAt", value: nil, on: entity)
        } else if let scheduledStartAt = request.scheduledStartAt {
            setAttribute("scheduledStartAt", value: scheduledStartAt, on: entity)
        }
        if request.clearScheduledEndAt {
            setAttribute("scheduledEndAt", value: nil, on: entity)
        } else if let scheduledEndAt = request.scheduledEndAt {
            setAttribute("scheduledEndAt", value: scheduledEndAt, on: entity)
        }
        if let isAllDay = request.isAllDay {
            setAttribute("isAllDay", value: isAllDay, on: entity)
        }
        if let priority = request.priority {
            setAttribute("priority", value: priority.rawValue, on: entity)
        }
        if let type = request.type {
            setAttribute("taskType", value: type.rawValue, on: entity)
        }
        if let energy = request.energy {
            setAttribute("energy", value: energy.rawValue, on: entity)
        }
        if let category = request.category {
            setAttribute("category", value: category.rawValue, on: entity)
        }
        if let context = request.context {
            setAttribute("context", value: context.rawValue, on: entity)
        }
        if let isComplete = request.isComplete {
            setAttribute("isComplete", value: isComplete, on: entity)
            setAttribute("status", value: isComplete ? "completed" : "pending", on: entity)
        }
        if request.dateCompleted != nil || request.isComplete == false {
            setAttribute("dateCompleted", value: request.dateCompleted, on: entity)
        }
        if request.clearReminderTime {
            setAttribute("alertReminderTime", value: nil, on: entity)
        } else if let alertReminderTime = request.alertReminderTime {
            setAttribute("alertReminderTime", value: alertReminderTime, on: entity)
        }
        if request.clearEstimatedDuration {
            setAttribute("estimatedDuration", value: nil, on: entity)
        } else if let estimatedDuration = request.estimatedDuration {
            setAttribute("estimatedDuration", value: estimatedDuration, on: entity)
        }
        if let actualDuration = request.actualDuration {
            setAttribute("actualDuration", value: actualDuration, on: entity)
        }
        if request.clearRepeatPattern {
            setAttribute("repeatPatternData", value: nil, on: entity)
        } else if let repeatPattern = request.repeatPattern {
            setAttribute("repeatPatternData", value: encodeRepeatPattern(repeatPattern), on: entity)
        }
        if let planningBucket = request.planningBucket {
            setAttribute("planningBucketRaw", value: planningBucket.rawValue, on: entity)
        }
        if request.clearWeeklyOutcomeLink {
            setAttribute("weeklyOutcomeID", value: nil, on: entity)
        } else if let weeklyOutcomeID = request.weeklyOutcomeID {
            setAttribute("weeklyOutcomeID", value: weeklyOutcomeID, on: entity)
        }
        if request.clearDeferredFromWeekStart {
            setAttribute("deferredFromWeekStart", value: nil, on: entity)
        } else if let deferredFromWeekStart = request.deferredFromWeekStart {
            setAttribute("deferredFromWeekStart", value: deferredFromWeekStart, on: entity)
        }
        if let deferredCount = request.deferredCount {
            setAttribute("deferredCount", value: Int32(max(0, deferredCount)), on: entity)
        }
        if let replanCount = request.replanCount {
            setAttribute("replanCount", value: Int32(max(0, replanCount)), on: entity)
        }
        setAttribute("updatedAt", value: request.updatedAt, on: entity)
    }

    static func setAttribute(_ key: String, value: Any?, on entity: NSManagedObject) {
        guard entity.entity.attributesByName[key] != nil else { return }
        entity.setValue(value, forKey: key)
    }

    static func encodeRepeatPattern(_ repeatPattern: TaskRepeatPattern?) -> Data? {
        guard let repeatPattern else { return nil }
        return try? JSONEncoder().encode(repeatPattern)
    }
}

public final class CoreDataTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    /// Executes fetchAll.
    public func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        fetchAll(query: nil, completion: completion)
    }

    /// Executes fetchAll.
    public func fetchAll(query: TaskDefinitionQuery?, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                let request: NSFetchRequest<TaskDefinitionEntity> = TaskDefinitionEntity.fetchRequest()
                var predicates: [NSPredicate] = []
                if let query {
                    if let projectID = query.projectID {
                        predicates.append(NSPredicate(format: "projectID == %@", projectID as CVarArg))
                    }
                    if let sectionID = query.sectionID {
                        predicates.append(NSPredicate(format: "sectionID == %@", sectionID as CVarArg))
                    }
                    if let parentTaskID = query.parentTaskID {
                        predicates.append(NSPredicate(format: "parentTaskID == %@", parentTaskID as CVarArg))
                    }
                    if query.includeCompleted == false {
                        predicates.append(NSPredicate(format: "isComplete == NO"))
                    }
                    if let dueDateStart = query.dueDateStart {
                        predicates.append(NSPredicate(format: "dueDate >= %@", dueDateStart as CVarArg))
                    }
                    if let dueDateEnd = query.dueDateEnd {
                        predicates.append(NSPredicate(format: "dueDate <= %@", dueDateEnd as CVarArg))
                    }
                    if let updatedAfter = query.updatedAfter {
                        predicates.append(NSPredicate(format: "updatedAt >= %@", updatedAfter as CVarArg))
                    }
                    if query.planningBuckets.isEmpty == false {
                        predicates.append(NSPredicate(
                            format: "planningBucketRaw IN %@",
                            query.planningBuckets.map(\.rawValue)
                        ))
                    }
                    if let weeklyOutcomeID = query.weeklyOutcomeID {
                        predicates.append(NSPredicate(format: "weeklyOutcomeID == %@", weeklyOutcomeID as CVarArg))
                    }
                    if let searchText = query.searchText?.trimmingCharacters(in: .whitespacesAndNewlines),
                       searchText.isEmpty == false {
                        predicates.append(
                            NSCompoundPredicate(orPredicateWithSubpredicates: [
                                NSPredicate(format: "title CONTAINS[cd] %@", searchText),
                                NSPredicate(format: "notes CONTAINS[cd] %@", searchText)
                            ])
                        )
                    }
                }
                if predicates.isEmpty == false {
                    request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
                }
                request.sortDescriptors = [
                    NSSortDescriptor(key: "isComplete", ascending: true),
                    NSSortDescriptor(key: "dueDate", ascending: true),
                    NSSortDescriptor(key: "dateAdded", ascending: true),
                    NSSortDescriptor(key: "taskID", ascending: true),
                    NSSortDescriptor(key: "id", ascending: true)
                ]
                request.fetchBatchSize = 120
                if let query {
                    if let limit = query.limit, limit > 0 {
                        request.fetchLimit = limit
                        request.fetchBatchSize = min(max(50, limit), 200)
                    }
                    if let offset = query.offset, offset >= 0 {
                        request.fetchOffset = offset
                    }
                }
                let entities = try self.viewContext.fetch(request)
                completion(.success(try Self.mapTaskDefinitions(entities, context: self.viewContext)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchTaskDefinition.
    public func fetchTaskDefinition(id: UUID, completion: @escaping (Result<TaskDefinition?, Error>) -> Void) {
        viewContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(id, field: "taskDefinition.id")
                let entity = try V2CoreDataRepositorySupport.fetchObject(
                    in: self.viewContext,
                    entityName: "TaskDefinition",
                    predicate: NSPredicate(format: "taskID == %@", id as CVarArg),
                    sort: [
                        NSSortDescriptor(key: "taskID", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )
                guard let entity else {
                    completion(.success(nil))
                    return
                }
                completion(.success(try Self.mapTaskDefinitions([entity], context: self.viewContext).first))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes create.
    public func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        let request = CreateTaskDefinitionRequest(
            id: task.id,
            recurrenceSeriesID: task.recurrenceSeriesID,
            habitDefinitionID: task.habitDefinitionID,
            title: task.title,
            details: task.details,
            projectID: task.projectID,
            projectName: task.projectName,
            iconSymbolName: task.iconSymbolName,
            lifeAreaID: task.lifeAreaID,
            sectionID: task.sectionID,
            dueDate: task.dueDate,
            scheduledStartAt: task.scheduledStartAt,
            scheduledEndAt: task.scheduledEndAt,
            isAllDay: task.isAllDay,
            parentTaskID: task.parentTaskID,
            tagIDs: task.tagIDs,
            dependencies: task.dependencies,
            priority: task.priority,
            type: task.type,
            energy: task.energy,
            category: task.category,
            context: task.context,
            isEveningTask: task.isEveningTask,
            alertReminderTime: task.alertReminderTime,
            estimatedDuration: task.estimatedDuration,
            repeatPattern: task.repeatPattern,
            planningBucket: task.planningBucket,
            weeklyOutcomeID: task.weeklyOutcomeID,
            deferredFromWeekStart: task.deferredFromWeekStart,
            deferredCount: task.deferredCount,
            replanCount: task.replanCount,
            createdAt: task.createdAt
        )
        create(request: request, completion: completion)
    }

    /// Executes create.
    public func create(
        request: CreateTaskDefinitionRequest,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(request.id, field: "taskDefinition.id")
                _ = try V2CoreDataRepositorySupport.requireID(request.projectID, field: "taskDefinition.projectID")
                _ = try V2CoreDataRepositorySupport.requireNonEmpty(request.title, field: "taskDefinition.title")
                let entity = try V2CoreDataRepositorySupport.upsertByID(
                    in: self.backgroundContext,
                    entityName: "TaskDefinition",
                    id: request.id
                )
                TaskDefinitionMutationApplier.applyCreateRequest(request, to: entity)
                try self.backgroundContext.save()
                let mapped = try Self.mapTaskDefinitions([entity], context: self.backgroundContext)
                if let first = mapped.first {
                    completion(.success(first))
                } else {
                    completion(.failure(NSError(
                        domain: "CoreDataTaskDefinitionRepository",
                        code: 500,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to map created TaskDefinition"]
                    )))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes update.
    public func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        let request = UpdateTaskDefinitionRequest(
            id: task.id,
            recurrenceSeriesID: task.recurrenceSeriesID,
            habitDefinitionID: task.habitDefinitionID,
            title: task.title,
            details: task.details,
            projectID: task.projectID,
            iconSymbolName: task.iconSymbolName,
            clearIconSymbolName: task.iconSymbolName == nil,
            lifeAreaID: task.lifeAreaID,
            sectionID: task.sectionID,
            dueDate: task.dueDate,
            scheduledStartAt: task.scheduledStartAt,
            clearScheduledStartAt: task.scheduledStartAt == nil,
            scheduledEndAt: task.scheduledEndAt,
            clearScheduledEndAt: task.scheduledEndAt == nil,
            isAllDay: task.isAllDay,
            parentTaskID: task.parentTaskID,
            clearParentTaskLink: task.parentTaskID == nil,
            tagIDs: task.tagIDs,
            dependencies: task.dependencies,
            priority: task.priority,
            type: task.type,
            energy: task.energy,
            category: task.category,
            context: task.context,
            isComplete: task.isComplete,
            dateCompleted: task.dateCompleted,
            alertReminderTime: task.alertReminderTime,
            estimatedDuration: task.estimatedDuration,
            actualDuration: task.actualDuration,
            repeatPattern: task.repeatPattern,
            planningBucket: task.planningBucket,
            weeklyOutcomeID: task.weeklyOutcomeID,
            clearWeeklyOutcomeLink: task.weeklyOutcomeID == nil,
            deferredFromWeekStart: task.deferredFromWeekStart,
            clearDeferredFromWeekStart: task.deferredFromWeekStart == nil,
            deferredCount: task.deferredCount,
            replanCount: task.replanCount,
            updatedAt: task.updatedAt
        )
        update(request: request, completion: completion)
    }

    /// Executes update.
    public func update(
        request: UpdateTaskDefinitionRequest,
        completion: @escaping (Result<TaskDefinition, Error>) -> Void
    ) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(request.id, field: "taskDefinition.id")
                guard let entity = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "TaskDefinition",
                    predicate: NSPredicate(format: "taskID == %@", request.id as CVarArg),
                    sort: [
                        NSSortDescriptor(key: "taskID", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                ) else {
                    completion(.failure(NSError(
                        domain: "CoreDataTaskDefinitionRepository",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "TaskDefinition not found"]
                    )))
                    return
                }
                TaskDefinitionMutationApplier.applyUpdateRequest(request, to: entity)
                try self.backgroundContext.save()
                completion(.success(try Self.mapTaskDefinitions([entity], context: self.backgroundContext).first ?? Self.mapTaskDefinition(entity)))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes fetchChildren.
    public func fetchChildren(parentTaskID: UUID, completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        do {
            _ = try V2CoreDataRepositorySupport.requireID(parentTaskID, field: "taskDefinition.parentTaskID")
        } catch {
            completion(.failure(error))
            return
        }
        fetchAll(
            query: TaskDefinitionQuery(parentTaskID: parentTaskID, includeCompleted: true),
            completion: completion
        )
    }

    /// Executes delete.
    public func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(id, field: "taskDefinition.id")
                if let entity = try V2CoreDataRepositorySupport.canonicalObject(
                    in: self.backgroundContext,
                    entityName: "TaskDefinition",
                    predicate: NSPredicate(format: "taskID == %@", id as CVarArg),
                    sort: [
                        NSSortDescriptor(key: "taskID", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                ) {
                    self.backgroundContext.delete(entity)
                    try self.backgroundContext.save()
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    private static func mapTaskDefinition(from snapshot: TaskEntitySnapshot) -> TaskDefinition {
        let energy = TaskEnergy(rawValue: snapshot.energyRaw) ?? .medium
        let category = TaskCategory(rawValue: snapshot.categoryRaw) ?? .general
        let context = TaskContext(rawValue: snapshot.contextRaw) ?? .anywhere
        let repeatPattern = snapshot.repeatPatternData.flatMap { try? JSONDecoder().decode(TaskRepeatPattern.self, from: $0) }
        let projectName = snapshot.fallbackProjectName ?? ProjectConstants.inboxProjectName
        let planningBucket = TaskPlanningBucket(rawValue: snapshot.planningBucketRaw ?? "") ?? .thisWeek

        return TaskDefinition(
            id: snapshot.taskID,
            recurrenceSeriesID: snapshot.recurrenceSeriesID,
            habitDefinitionID: snapshot.habitDefinitionID,
            projectID: snapshot.projectID,
            projectName: projectName,
            iconSymbolName: snapshot.iconSymbolName,
            lifeAreaID: snapshot.lifeAreaID,
            sectionID: snapshot.sectionID,
            parentTaskID: snapshot.parentTaskID,
            title: snapshot.title,
            details: snapshot.notes,
            priority: TaskPriority(rawValue: snapshot.priorityRaw),
            type: TaskType(rawValue: snapshot.taskTypeRaw),
            energy: energy,
            category: category,
            context: context,
            dueDate: snapshot.dueDate,
            scheduledStartAt: snapshot.scheduledStartAt,
            scheduledEndAt: snapshot.scheduledEndAt,
            isAllDay: snapshot.isAllDay,
            isComplete: snapshot.isComplete,
            dateAdded: snapshot.dateAdded,
            dateCompleted: snapshot.dateCompleted,
            isEveningTask: snapshot.isEveningTask,
            alertReminderTime: snapshot.alertReminderTime,
            tagIDs: [],
            dependencies: [],
            estimatedDuration: snapshot.estimatedDuration,
            actualDuration: snapshot.actualDuration,
            repeatPattern: repeatPattern,
            planningBucket: planningBucket,
            weeklyOutcomeID: snapshot.weeklyOutcomeID,
            deferredFromWeekStart: snapshot.deferredFromWeekStart,
            deferredCount: snapshot.deferredCount,
            replanCount: snapshot.replanCount,
            createdAt: snapshot.createdAt,
            updatedAt: snapshot.updatedAt
        )
    }

    /// Executes mapTaskDefinition.
    static func mapTaskDefinition(_ entity: NSManagedObject) -> TaskDefinition {
        if V2FeatureFlags.iPadPerfCoreDataMappingSnapshotV3Enabled {
            return mapTaskDefinition(from: TaskEntitySnapshot(entity: entity))
        }

        var repairs: [String] = []
        let taskID = attributeValue("taskID", from: entity)
            ?? attributeValue("id", from: entity)
            ?? TaskDefinitionRowRepair.repairedUUID(for: entity, field: "taskID", repairs: &repairs)
        let projectID: UUID
        if let storedProjectID: UUID = attributeValue("projectID", from: entity) {
            projectID = storedProjectID
        } else {
            repairs.append("projectID")
            projectID = ProjectConstants.inboxProjectID
        }
        let storedDateAdded: Date? = attributeValue("dateAdded", from: entity)
        let storedCreatedAt: Date? = attributeValue("createdAt", from: entity)
        let storedUpdatedAt: Date? = attributeValue("updatedAt", from: entity)
        let dateAdded = TaskDefinitionRowRepair.repairedDate(
            storedDateAdded,
            fallbacks: [storedCreatedAt, storedUpdatedAt],
            field: "dateAdded",
            repairs: &repairs
        )
        let createdAt = TaskDefinitionRowRepair.repairedDate(
            storedCreatedAt,
            fallbacks: [storedDateAdded, storedUpdatedAt],
            field: "createdAt",
            repairs: &repairs
        )
        let updatedAt = TaskDefinitionRowRepair.repairedDate(
            storedUpdatedAt,
            fallbacks: [storedCreatedAt, storedDateAdded],
            field: "updatedAt",
            repairs: &repairs
        )
        TaskDefinitionRowRepair.logIfNeeded(repairs: repairs, entity: entity, path: "managed_object")
        let title = attributeValue("title", from: entity) ?? "Untitled Task"
        let details: String? = attributeValue("notes", from: entity)
        let typeRaw: Int32 = attributeValue("taskType", from: entity) ?? 1
        let priorityRaw: Int32 = attributeValue("priority", from: entity) ?? 2
        let energy = TaskEnergy(rawValue: attributeValue("energy", from: entity) ?? "") ?? .medium
        let category = TaskCategory(rawValue: attributeValue("category", from: entity) ?? "") ?? .general
        let context = TaskContext(rawValue: attributeValue("context", from: entity) ?? "") ?? .anywhere
        let projectName = resolvedProjectName(from: entity) ?? ProjectConstants.inboxProjectName
        let repeatPattern = decodeRepeatPattern(from: entity)
        let estimatedDuration = (attributeValue("estimatedDuration", from: entity) as Double?).flatMap { $0 > 0 ? $0 : nil }
        let actualDuration = (attributeValue("actualDuration", from: entity) as Double?).flatMap { $0 > 0 ? $0 : nil }
        let planningBucket = TaskPlanningBucket(rawValue: attributeValue("planningBucketRaw", from: entity) ?? "") ?? .thisWeek
        let deferredCount = max(0, Int((attributeValue("deferredCount", from: entity) as Int32?) ?? 0))
        let replanCount = max(0, Int((attributeValue("replanCount", from: entity) as Int32?) ?? 0))

        return TaskDefinition(
            id: taskID,
            recurrenceSeriesID: attributeValue("recurrenceSeriesID", from: entity),
            habitDefinitionID: attributeValue("habitDefinitionID", from: entity),
            projectID: projectID,
            projectName: projectName,
            iconSymbolName: attributeValue("iconSymbolName", from: entity),
            lifeAreaID: attributeValue("lifeAreaID", from: entity),
            sectionID: attributeValue("sectionID", from: entity),
            parentTaskID: attributeValue("parentTaskID", from: entity),
            title: title,
            details: details,
            priority: TaskPriority(rawValue: priorityRaw),
            type: TaskType(rawValue: typeRaw),
            energy: energy,
            category: category,
            context: context,
            dueDate: attributeValue("dueDate", from: entity),
            scheduledStartAt: attributeValue("scheduledStartAt", from: entity),
            scheduledEndAt: attributeValue("scheduledEndAt", from: entity),
            isAllDay: attributeValue("isAllDay", from: entity) ?? false,
            isComplete: attributeValue("isComplete", from: entity) ?? false,
            dateAdded: dateAdded,
            dateCompleted: attributeValue("dateCompleted", from: entity),
            isEveningTask: attributeValue("isEveningTask", from: entity) ?? false,
            alertReminderTime: attributeValue("alertReminderTime", from: entity),
            tagIDs: [],
            dependencies: [],
            estimatedDuration: estimatedDuration,
            actualDuration: actualDuration,
            repeatPattern: repeatPattern,
            planningBucket: planningBucket,
            weeklyOutcomeID: attributeValue("weeklyOutcomeID", from: entity),
            deferredFromWeekStart: attributeValue("deferredFromWeekStart", from: entity),
            deferredCount: deferredCount,
            replanCount: replanCount,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }

    /// Executes mapTaskDefinitions.
    static func mapTaskDefinitions(
        _ entities: [NSManagedObject],
        context: NSManagedObjectContext
    ) throws -> [TaskDefinition] {
        guard entities.isEmpty == false else { return [] }
        if V2FeatureFlags.iPadPerfCoreDataMappingSnapshotV3Enabled {
            logDebug(
                event: "taskMapSnapshotPathUsed",
                message: "Using snapshot-based Core Data task mapping path",
                fields: ["entity_count": String(entities.count)]
            )

            let snapshots = entities.map(TaskEntitySnapshot.init)
            let taskIDs = snapshots.map(\.taskID)
            let projectIDs = snapshots.map(\.projectID)
            let tagIDsByTaskID = try hydrateTagIDsByTaskID(taskIDs: taskIDs, context: context)
            let dependenciesByTaskID = try hydrateDependenciesByTaskID(taskIDs: taskIDs, context: context)
            let projectNamesByProjectID = try hydrateProjectNamesByProjectID(projectIDs: projectIDs, context: context)

            return snapshots.map { snapshot in
                var mapped = mapTaskDefinition(from: snapshot)
                mapped.tagIDs = tagIDsByTaskID[mapped.id] ?? []
                mapped.dependencies = dependenciesByTaskID[mapped.id] ?? []
                mapped.projectName = projectNamesByProjectID[mapped.projectID] ?? mapped.projectName
                return mapped
            }
        }

        let taskIDs: [UUID] = entities.compactMap { entity -> UUID? in
            let taskID: UUID? = attributeValue("taskID", from: entity)
            return taskID ?? attributeValue("id", from: entity)
        }
        let projectIDs = entities.compactMap { entity in
            attributeValue("projectID", from: entity) as UUID?
        }
        let tagIDsByTaskID = try hydrateTagIDsByTaskID(taskIDs: taskIDs, context: context)
        let dependenciesByTaskID = try hydrateDependenciesByTaskID(taskIDs: taskIDs, context: context)
        let projectNamesByProjectID = try hydrateProjectNamesByProjectID(projectIDs: projectIDs, context: context)

        return entities.map { entity in
            var mapped = mapTaskDefinition(entity)
            mapped.tagIDs = tagIDsByTaskID[mapped.id] ?? []
            mapped.dependencies = dependenciesByTaskID[mapped.id] ?? []
            mapped.projectName = projectNamesByProjectID[mapped.projectID] ?? mapped.projectName
            return mapped
        }
    }

    /// Executes hydrateTagIDsByTaskID.
    fileprivate static func hydrateTagIDsByTaskID(
        taskIDs: [UUID],
        context: NSManagedObjectContext
    ) throws -> [UUID: [UUID]] {
        guard taskIDs.isEmpty == false else { return [:] }
        let uniqueTaskIDs = Array(Set(taskIDs))
        let request = NSFetchRequest<NSManagedObject>(entityName: "TaskTagLink")
        request.predicate = NSPredicate(format: "taskID IN %@", uniqueTaskIDs as NSArray)
        request.sortDescriptors = [
            NSSortDescriptor(key: "taskID", ascending: true),
            NSSortDescriptor(key: "tagID", ascending: true),
            NSSortDescriptor(key: "id", ascending: true)
        ]

        let objects = try context.fetch(request)
        var grouped: [UUID: [UUID]] = [:]
        var seen: [UUID: Set<UUID>] = [:]

        for object in objects {
            if V2FeatureFlags.iPadPerfCoreDataMappingSnapshotV3Enabled {
                let snapshot = TaskTagLinkSnapshot(object: object)
                guard let taskID = snapshot.taskID, let tagID = snapshot.tagID else {
                    continue
                }
                if seen[taskID, default: []].contains(tagID) {
                    continue
                }
                seen[taskID, default: []].insert(tagID)
                grouped[taskID, default: []].append(tagID)
                continue
            }
            guard
                let taskID: UUID = attributeValue("taskID", from: object),
                let tagID: UUID = attributeValue("tagID", from: object)
            else {
                continue
            }
            if seen[taskID, default: []].contains(tagID) {
                continue
            }
            seen[taskID, default: []].insert(tagID)
            grouped[taskID, default: []].append(tagID)
        }

        for (taskID, values) in grouped {
            grouped[taskID] = values.sorted { $0.uuidString < $1.uuidString }
        }

        return grouped
    }

    /// Executes hydrateDependenciesByTaskID.
    fileprivate static func hydrateDependenciesByTaskID(
        taskIDs: [UUID],
        context: NSManagedObjectContext
    ) throws -> [UUID: [TaskDependencyLinkDefinition]] {
        guard taskIDs.isEmpty == false else { return [:] }
        let uniqueTaskIDs = Array(Set(taskIDs))
        let request = NSFetchRequest<NSManagedObject>(entityName: "TaskDependency")
        request.predicate = NSPredicate(format: "taskID IN %@", uniqueTaskIDs as NSArray)
        request.sortDescriptors = [
            NSSortDescriptor(key: "taskID", ascending: true),
            NSSortDescriptor(key: "createdAt", ascending: true),
            NSSortDescriptor(key: "dependsOnTaskID", ascending: true),
            NSSortDescriptor(key: "id", ascending: true)
        ]

        let objects = try context.fetch(request)
        var grouped: [UUID: [TaskDependencyLinkDefinition]] = [:]
        var seen: [UUID: Set<String>] = [:]

        for object in objects {
            if V2FeatureFlags.iPadPerfCoreDataMappingSnapshotV3Enabled {
                let snapshot = TaskDependencySnapshot(object: object)
                guard
                    let taskID = snapshot.taskID,
                    let dependsOnTaskID = snapshot.dependsOnTaskID,
                    let rawKind = snapshot.rawKind,
                    let kind = TaskDependencyKind(rawValue: rawKind)
                else {
                    continue
                }

                let key = V2CoreDataRepositorySupport.compositeKey([
                    taskID.uuidString,
                    dependsOnTaskID.uuidString,
                    kind.rawValue
                ])
                if seen[taskID, default: []].contains(key) {
                    continue
                }
                seen[taskID, default: []].insert(key)

                grouped[taskID, default: []].append(
                    TaskDependencyLinkDefinition(
                        id: snapshot.id,
                        taskID: taskID,
                        dependsOnTaskID: dependsOnTaskID,
                        kind: kind,
                        createdAt: snapshot.createdAt
                    )
                )
                continue
            }
            guard
                let taskID: UUID = attributeValue("taskID", from: object),
                let dependsOnTaskID: UUID = attributeValue("dependsOnTaskID", from: object),
                let rawKind: String = attributeValue("kind", from: object),
                let kind = TaskDependencyKind(rawValue: rawKind)
            else {
                continue
            }

            let key = V2CoreDataRepositorySupport.compositeKey([
                taskID.uuidString,
                dependsOnTaskID.uuidString,
                kind.rawValue
            ])
            if seen[taskID, default: []].contains(key) {
                continue
            }
            seen[taskID, default: []].insert(key)

            grouped[taskID, default: []].append(
                TaskDependencyLinkDefinition(
                    id: attributeValue("id", from: object) ?? UUID(),
                    taskID: taskID,
                    dependsOnTaskID: dependsOnTaskID,
                    kind: kind,
                    createdAt: attributeValue("createdAt", from: object) ?? Date()
                )
            )
        }

        return grouped
    }

    /// Executes hydrateProjectNamesByProjectID.
    fileprivate static func hydrateProjectNamesByProjectID(
        projectIDs: [UUID],
        context: NSManagedObjectContext
    ) throws -> [UUID: String] {
        guard projectIDs.isEmpty == false else { return [:] }
        let uniqueProjectIDs = Array(Set(projectIDs))
        let request = NSFetchRequest<NSManagedObject>(entityName: "Project")
        request.predicate = NSPredicate(format: "id IN %@", uniqueProjectIDs as NSArray)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        let objects = try context.fetch(request)
        var namesByID: [UUID: String] = [:]
        for object in objects {
            if V2FeatureFlags.iPadPerfCoreDataMappingSnapshotV3Enabled {
                let snapshot = ProjectNameSnapshot(object: object)
                guard
                    let id = snapshot.id,
                    let name = snapshot.name,
                    name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
                else {
                    continue
                }
                namesByID[id] = name
                continue
            }
            guard
                let id: UUID = attributeValue("id", from: object),
                let name: String = attributeValue("name", from: object),
                name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            else {
                continue
            }
            namesByID[id] = name
        }
        return namesByID
    }

    fileprivate static func attributeValue<T>(_ key: String, from entity: NSManagedObject) -> T? {
        guard entity.entity.attributesByName[key] != nil else { return nil }
        return entity.value(forKey: key) as? T
    }

    /// Executes resolvedProjectName.
    private static func resolvedProjectName(from entity: NSManagedObject) -> String? {
        guard let projectRef = entity.value(forKey: "projectRef") as? NSManagedObject else {
            return nil
        }
        return attributeValue("name", from: projectRef)
    }

    /// Executes decodeRepeatPattern.
    private static func decodeRepeatPattern(from entity: NSManagedObject) -> TaskRepeatPattern? {
        guard
            let data = attributeValue("repeatPatternData", from: entity) as Data?,
            data.isEmpty == false
        else {
            return nil
        }
        return try? JSONDecoder().decode(TaskRepeatPattern.self, from: data)
    }
}

public final class CoreDataTaskTagLinkRepository: TaskTagLinkRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    /// Executes fetchTagIDs.
    public func fetchTagIDs(taskID: UUID, completion: @escaping (Result<[UUID], Error>) -> Void) {
        viewContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(taskID, field: "taskTagLink.taskID")
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "TaskTagLink",
                    predicate: NSPredicate(format: "taskID == %@", taskID as CVarArg),
                    sort: [NSSortDescriptor(key: "tagID", ascending: true)]
                )
                let ids = objects.compactMap { $0.value(forKey: "tagID") as? UUID }
                completion(.success(Array(Set(ids)).sorted { $0.uuidString < $1.uuidString }))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes replaceTagLinks.
    public func replaceTagLinks(taskID: UUID, tagIDs: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(taskID, field: "taskTagLink.taskID")
                let uniqueTagIDs = Array(Set(tagIDs)).sorted { $0.uuidString < $1.uuidString }
                for tagID in uniqueTagIDs {
                    _ = try V2CoreDataRepositorySupport.requireID(tagID, field: "taskTagLink.tagID")
                }
                let existing = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.backgroundContext,
                    entityName: "TaskTagLink",
                    predicate: NSPredicate(format: "taskID == %@", taskID as CVarArg),
                    sort: [
                        NSSortDescriptor(key: "tagID", ascending: true),
                        NSSortDescriptor(key: "id", ascending: true)
                    ]
                )

                let existingByTagID = Dictionary(
                    grouping: existing,
                    by: { $0.value(forKey: "tagID") as? UUID ?? UUID() }
                )
                let uniqueSet = Set(uniqueTagIDs)

                for object in existing {
                    let tagID = object.value(forKey: "tagID") as? UUID
                    if let tagID, uniqueSet.contains(tagID) == false {
                        self.backgroundContext.delete(object)
                    }
                }

                for tagID in uniqueTagIDs {
                    let duplicates = existingByTagID[tagID] ?? []
                    if let canonical = duplicates.first {
                        canonical.setValue(taskID, forKey: "taskID")
                        canonical.setValue(tagID, forKey: "tagID")
                        canonical.setValue(canonical.value(forKey: "createdAt") as? Date ?? Date(), forKey: "createdAt")
                        for duplicate in duplicates.dropFirst() {
                            self.backgroundContext.delete(duplicate)
                        }
                    } else {
                        let object = NSEntityDescription.insertNewObject(forEntityName: "TaskTagLink", into: self.backgroundContext)
                        object.setValue(UUID(), forKey: "id")
                        object.setValue(taskID, forKey: "taskID")
                        object.setValue(tagID, forKey: "tagID")
                        object.setValue(Date(), forKey: "createdAt")
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

public final class CoreDataTaskDependencyRepository: TaskDependencyRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }

    /// Executes fetchDependencies.
    public func fetchDependencies(taskID: UUID, completion: @escaping (Result<[TaskDependencyLinkDefinition], Error>) -> Void) {
        viewContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(taskID, field: "taskDependency.taskID")
                let objects = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.viewContext,
                    entityName: "TaskDependency",
                    predicate: NSPredicate(format: "taskID == %@", taskID as CVarArg),
                    sort: [NSSortDescriptor(key: "createdAt", ascending: true)]
                )
                let mapped = objects.compactMap { object -> TaskDependencyLinkDefinition? in
                    guard
                        let taskID = object.value(forKey: "taskID") as? UUID,
                        let dependsOnTaskID = object.value(forKey: "dependsOnTaskID") as? UUID,
                        let rawKind = object.value(forKey: "kind") as? String,
                        let kind = TaskDependencyKind(rawValue: rawKind)
                    else {
                        return nil
                    }
                    return TaskDependencyLinkDefinition(
                        id: object.value(forKey: "id") as? UUID ?? UUID(),
                        taskID: taskID,
                        dependsOnTaskID: dependsOnTaskID,
                        kind: kind,
                        createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
                    )
                }
                completion(.success(mapped))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Executes replaceDependencies.
    public func replaceDependencies(
        taskID: UUID,
        dependencies: [TaskDependencyLinkDefinition],
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        backgroundContext.perform {
            do {
                _ = try V2CoreDataRepositorySupport.requireID(taskID, field: "taskDependency.taskID")
                let sanitized = dependencies
                    .filter { $0.taskID == taskID && $0.dependsOnTaskID != taskID }
                    .filter { $0.kind == .blocks || $0.kind == .related }
                    .compactMap { dependency -> TaskDependencyLinkDefinition? in
                        do {
                            _ = try V2CoreDataRepositorySupport.requireID(dependency.dependsOnTaskID, field: "taskDependency.dependsOnTaskID")
                            return dependency
                        } catch {
                            return nil
                        }
                    }

                let uniqueDependencies = Dictionary(
                    sanitized.map {
                        (
                            V2CoreDataRepositorySupport.compositeKey([
                                taskID.uuidString,
                                $0.dependsOnTaskID.uuidString,
                                $0.kind.rawValue
                            ]),
                            $0
                        )
                    },
                    uniquingKeysWith: { first, _ in first }
                ).values

                let existing = try V2CoreDataRepositorySupport.fetchObjects(
                    in: self.backgroundContext,
                    entityName: "TaskDependency",
                    predicate: NSPredicate(format: "taskID == %@", taskID as CVarArg)
                )
                for object in existing {
                    self.backgroundContext.delete(object)
                }

                for dependency in uniqueDependencies {
                    let object = NSEntityDescription.insertNewObject(forEntityName: "TaskDependency", into: self.backgroundContext)
                    object.setValue(dependency.id, forKey: "id")
                    object.setValue(taskID, forKey: "taskID")
                    object.setValue(dependency.dependsOnTaskID, forKey: "dependsOnTaskID")
                    object.setValue(dependency.kind.rawValue, forKey: "kind")
                    object.setValue(dependency.createdAt, forKey: "createdAt")
                }

                try self.backgroundContext.save()
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }
}
