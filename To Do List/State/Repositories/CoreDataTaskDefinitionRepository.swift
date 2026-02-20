import Foundation
import CoreData

public final class CoreDataTaskDefinitionRepository: TaskDefinitionRepositoryProtocol {
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    public func fetchAll(completion: @escaping (Result<[TaskDefinition], Error>) -> Void) {
        fetchAll(query: nil, completion: completion)
    }

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
                if let query {
                    if let limit = query.limit, limit > 0 {
                        request.fetchLimit = limit
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

    public func create(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        let request = CreateTaskDefinitionRequest(
            id: task.id,
            recurrenceSeriesID: task.recurrenceSeriesID,
            title: task.title,
            details: task.details,
            projectID: task.projectID,
            projectName: task.projectName,
            lifeAreaID: task.lifeAreaID,
            sectionID: task.sectionID,
            dueDate: task.dueDate,
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
            createdAt: task.createdAt
        )
        create(request: request, completion: completion)
    }

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
                Self.applyCreateRequest(request, to: entity)
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

    public func update(_ task: TaskDefinition, completion: @escaping (Result<TaskDefinition, Error>) -> Void) {
        let request = UpdateTaskDefinitionRequest(
            id: task.id,
            recurrenceSeriesID: task.recurrenceSeriesID,
            title: task.title,
            details: task.details,
            projectID: task.projectID,
            lifeAreaID: task.lifeAreaID,
            sectionID: task.sectionID,
            dueDate: task.dueDate,
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
            updatedAt: task.updatedAt
        )
        update(request: request, completion: completion)
    }

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
                Self.applyUpdateRequest(request, to: entity)
                try self.backgroundContext.save()
                completion(.success(try Self.mapTaskDefinitions([entity], context: self.backgroundContext).first ?? Self.mapTaskDefinition(entity)))
            } catch {
                completion(.failure(error))
            }
        }
    }

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

    static func mapTaskDefinition(_ entity: NSManagedObject) -> TaskDefinition {
        let taskID = attributeValue("taskID", from: entity) ?? attributeValue("id", from: entity) ?? UUID()
        let projectID = attributeValue("projectID", from: entity) ?? ProjectConstants.inboxProjectID
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

        return TaskDefinition(
            id: taskID,
            recurrenceSeriesID: attributeValue("recurrenceSeriesID", from: entity),
            projectID: projectID,
            projectName: projectName,
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
            isComplete: attributeValue("isComplete", from: entity) ?? false,
            dateAdded: attributeValue("dateAdded", from: entity) ?? Date(),
            dateCompleted: attributeValue("dateCompleted", from: entity),
            isEveningTask: attributeValue("isEveningTask", from: entity) ?? false,
            alertReminderTime: attributeValue("alertReminderTime", from: entity),
            tagIDs: [],
            dependencies: [],
            estimatedDuration: estimatedDuration,
            actualDuration: actualDuration,
            repeatPattern: repeatPattern,
            createdAt: attributeValue("createdAt", from: entity) ?? Date(),
            updatedAt: attributeValue("updatedAt", from: entity) ?? Date()
        )
    }

    static func mapTaskDefinitions(
        _ entities: [NSManagedObject],
        context: NSManagedObjectContext
    ) throws -> [TaskDefinition] {
        guard entities.isEmpty == false else { return [] }

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

    private static func applyCreateRequest(_ request: CreateTaskDefinitionRequest, to entity: NSManagedObject) {
        setAttribute("id", value: request.id, on: entity)
        setAttribute("taskID", value: request.id, on: entity)
        setAttribute("projectID", value: request.projectID, on: entity)
        setAttribute("lifeAreaID", value: request.lifeAreaID, on: entity)
        setAttribute("sectionID", value: request.sectionID, on: entity)
        setAttribute("parentTaskID", value: request.parentTaskID, on: entity)
        setAttribute("recurrenceSeriesID", value: request.recurrenceSeriesID, on: entity)
        setAttribute("title", value: request.title, on: entity)
        setAttribute("notes", value: request.details, on: entity)
        setAttribute("priority", value: request.priority.rawValue, on: entity)
        setAttribute("taskType", value: request.type.rawValue, on: entity)
        setAttribute("energy", value: request.energy.rawValue, on: entity)
        setAttribute("category", value: request.category.rawValue, on: entity)
        setAttribute("context", value: request.context.rawValue, on: entity)
        setAttribute("dueDate", value: request.dueDate, on: entity)
        setAttribute("estimatedDuration", value: request.estimatedDuration, on: entity)
        setAttribute("actualDuration", value: nil, on: entity)
        setAttribute("repeatPatternData", value: encodeRepeatPattern(request.repeatPattern), on: entity)
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

    private static func applyUpdateRequest(_ request: UpdateTaskDefinitionRequest, to entity: NSManagedObject) {
        if let title = request.title {
            setAttribute("title", value: title, on: entity)
        }
        if request.details != nil {
            setAttribute("notes", value: request.details, on: entity)
        }
        if let projectID = request.projectID {
            setAttribute("projectID", value: projectID, on: entity)
        }
        if request.lifeAreaID != nil {
            setAttribute("lifeAreaID", value: request.lifeAreaID, on: entity)
        }
        if request.sectionID != nil {
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
        if let dueDate = request.dueDate {
            setAttribute("dueDate", value: dueDate, on: entity)
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
        if let alertReminderTime = request.alertReminderTime {
            setAttribute("alertReminderTime", value: alertReminderTime, on: entity)
        }
        if let estimatedDuration = request.estimatedDuration {
            setAttribute("estimatedDuration", value: estimatedDuration, on: entity)
        }
        if let actualDuration = request.actualDuration {
            setAttribute("actualDuration", value: actualDuration, on: entity)
        }
        if let repeatPattern = request.repeatPattern {
            setAttribute("repeatPatternData", value: encodeRepeatPattern(repeatPattern), on: entity)
        }
        setAttribute("updatedAt", value: request.updatedAt, on: entity)
    }

    fileprivate static func attributeValue<T>(_ key: String, from entity: NSManagedObject) -> T? {
        guard entity.entity.attributesByName[key] != nil else { return nil }
        return entity.value(forKey: key) as? T
    }

    private static func resolvedProjectName(from entity: NSManagedObject) -> String? {
        guard let projectRef = entity.value(forKey: "projectRef") as? NSManagedObject else {
            return nil
        }
        return attributeValue("name", from: projectRef)
    }

    private static func setAttribute(_ key: String, value: Any?, on entity: NSManagedObject) {
        guard entity.entity.attributesByName[key] != nil else { return }
        entity.setValue(value, forKey: key)
    }

    private static func encodeRepeatPattern(_ repeatPattern: TaskRepeatPattern?) -> Data? {
        guard let repeatPattern else { return nil }
        return try? JSONEncoder().encode(repeatPattern)
    }

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

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

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

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

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
