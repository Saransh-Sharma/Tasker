//
//  CoreDataProjectRepository.swift
//  Tasker
//
//  Core Data implementation of ProjectRepositoryProtocol
//

import Foundation
import CoreData

private final class CoreDataRepositoryCompletion<Value: Sendable>: @unchecked Sendable {
    private let completion: @Sendable (Result<Value, Error>) -> Void

    init(_ completion: @escaping @Sendable (Result<Value, Error>) -> Void) {
        self.completion = completion
    }

    func deliver(_ result: Result<Value, Error>) {
        DispatchQueue.main.async {
            self.completion(result)
        }
    }
}

/// Core Data implementation of the ProjectRepositoryProtocol
public final class CoreDataProjectRepository: ProjectRepositoryProtocol, @unchecked Sendable {
    
    // MARK: - Properties
    
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    // MARK: - Initialization

    /// Initializes a new instance.
    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        
        // Configure contexts
        self.viewContext.automaticallyMergesChangesFromParent = true
        self.backgroundContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
    }
    
    // MARK: - Fetch Operations
    
    /// Executes fetchAllProjects.
    public func fetchAllProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void) {
        let callback = CoreDataRepositoryCompletion(completion)
        viewContext.perform {
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            do {
                let entities = try self.viewContext.fetch(request)
                let projects = ProjectMapper.toDomainArray(from: entities)
                callback.deliver(.success(projects))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }
    
    /// Executes fetchProject.
    public func fetchProject(withId id: UUID, completion: @escaping @Sendable (Result<Project?, Error>) -> Void) {
        let callback = CoreDataRepositoryCompletion(completion)
        viewContext.perform {
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            do {
                let entities = try self.viewContext.fetch(request)
                let project = entities.first.map { ProjectMapper.toDomain(from: $0) }
                callback.deliver(.success(project))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }
    
    /// Executes fetchProject.
    public func fetchProject(withName name: String, completion: @escaping @Sendable (Result<Project?, Error>) -> Void) {
        let callback = CoreDataRepositoryCompletion(completion)
        viewContext.perform {
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "name ==[c] %@", name)
            request.fetchLimit = 1

            do {
                let entities = try self.viewContext.fetch(request)
                let project = entities.first.map { ProjectMapper.toDomain(from: $0) }
                callback.deliver(.success(project))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }
    
    /// Executes fetchInboxProject.
    public func fetchInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        let inboxProject = Project.createInbox()
        completion(.success(inboxProject))
    }
    
    /// Executes fetchCustomProjects.
    public func fetchCustomProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void) {
        let callback = CoreDataRepositoryCompletion(completion)
        viewContext.perform {
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            do {
                let entities = try self.viewContext.fetch(request)
                let projects = ProjectMapper
                    .toDomainArray(from: entities)
                    .filter { !$0.isDefault && !$0.isInbox }
                callback.deliver(.success(projects))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }
    
    // MARK: - Create Operations
    
    /// Executes createProject.
    public func createProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        let callback = CoreDataRepositoryCompletion(completion)
        // First validate the name is unique
        isProjectNameAvailable(project.name, excludingId: nil) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let isAvailable):
                if !isAvailable {
                    let error = ProjectValidationError.duplicateName
                    callback.deliver(.failure(error))
                    return
                }

                // Persist to database
                self.backgroundContext.perform {
                    do {
                        if try self.findProjectNamed(project.name, excludingId: nil, in: self.backgroundContext) != nil {
                            logWarning(
                                event: "cloudkit_project_uniqueness_rejected",
                                message: "Rejected duplicate project name before Core Data write",
                                fields: ["project_name": project.name]
                            )
                            callback.deliver(.failure(ProjectValidationError.duplicateName))
                            return
                        }

                        _ = ProjectMapper.toEntity(from: project, in: self.backgroundContext)
                        try self.backgroundContext.save()
                        logDebug("✅ Created project '\(project.name)' with UUID: \(project.id)")
                        callback.deliver(.success(project))
                    } catch {
                        logError(" Failed to create project: \(error)")
                        callback.deliver(.failure(error))
                    }
                }

            case .failure(let error):
                callback.deliver(.failure(error))
            }
        }
    }
    
    /// Executes ensureInboxProject.
    public func ensureInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        let callback = CoreDataRepositoryCompletion(completion)
        viewContext.perform {
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.predicate = self.inboxCandidatePredicate()

            do {
                let existingProjects = try self.viewContext.fetch(request)

                if existingProjects.count > 1 {
                    self.repairProjectIdentityCollisions { repairResult in
                        switch repairResult {
                        case .success:
                            self.fetchProject(withId: ProjectConstants.inboxProjectID) { fetchResult in
                                switch fetchResult {
                                case .success(let project):
                                    callback.deliver(.success(project ?? Project.createInbox()))
                                case .failure(let error):
                                    callback.deliver(.failure(error))
                                }
                            }
                        case .failure(let error):
                            callback.deliver(.failure(error))
                        }
                    }
                    return
                }

                if let existingProject = existingProjects.first {
                    let inboxProject = ProjectMapper.toDomain(from: existingProject)
                    callback.deliver(.success(inboxProject))
                } else {
                    self.backgroundContext.perform {
                        let inboxProject = Project.createInbox()
                        _ = ProjectMapper.toEntity(from: inboxProject, in: self.backgroundContext)

                        do {
                            try self.backgroundContext.save()
                            logDebug("✅ Created Inbox project with UUID: \(ProjectConstants.inboxProjectID)")
                            callback.deliver(.success(inboxProject))
                        } catch {
                            logError(" Failed to create Inbox project: \(error)")
                            callback.deliver(.failure(error))
                        }
                    }
                }
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }

    /// Executes repairProjectIdentityCollisions.
    public func repairProjectIdentityCollisions(completion: @escaping @Sendable (Result<ProjectRepairReport, Error>) -> Void) {
        let callback = CoreDataRepositoryCompletion(completion)
        backgroundContext.perform {
            do {
                let projectRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
                projectRequest.returnsObjectsAsFaults = false
                var projects = try self.backgroundContext.fetch(projectRequest)
                let scannedCount = projects.count

                var merged = 0
                var deleted = 0
                var warnings: [String] = []

                for project in projects {
                    self.normalizeProjectIdentity(project)
                }

                var inboxCandidates = projects.filter { self.isInboxCandidate($0) }
                var canonicalInbox: ProjectEntity
                if let selected = self.selectCanonicalInbox(from: inboxCandidates) {
                    canonicalInbox = selected
                } else {
                    canonicalInbox = ProjectMapper.toEntity(from: Project.createInbox(), in: self.backgroundContext)
                    projects.append(canonicalInbox)
                    warnings.append("Inbox was missing and has been recreated during repair")
                }

                self.normalizeAsCanonicalInbox(canonicalInbox)

                for duplicate in inboxCandidates where duplicate.objectID != canonicalInbox.objectID {
                    self.repointTasks(from: duplicate, to: canonicalInbox)
                    self.backgroundContext.delete(duplicate)
                    merged += 1
                    deleted += 1
                }

                projects = projects.filter { !$0.isDeleted }
                let groups = Dictionary(grouping: projects) { self.effectiveProjectID(for: $0) }

                for (projectID, group) in groups where group.count > 1 {
                    let canonical = self.selectCanonicalProject(from: group, targetID: projectID)
                    for duplicate in group where duplicate.objectID != canonical.objectID {
                        self.repointTasks(from: duplicate, to: canonical)
                        self.backgroundContext.delete(duplicate)
                        merged += 1
                        deleted += 1
                    }
                }

                try self.backgroundContext.save()

                inboxCandidates = [canonicalInbox] + inboxCandidates.filter { !$0.isDeleted && $0.objectID != canonicalInbox.objectID }
                let report = ProjectRepairReport(
                    scanned: scannedCount,
                    merged: merged,
                    deleted: deleted,
                    inboxCandidates: inboxCandidates.count,
                    warnings: warnings
                )
                callback.deliver(.success(report))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }
    
    // MARK: - Update Operations
    
    /// Executes updateProject.
    public func updateProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        let callback = CoreDataRepositoryCompletion(completion)
        backgroundContext.perform {
            // Find the existing entity
            if let entity = ProjectMapper.findEntity(byId: project.id, in: self.backgroundContext) {
                do {
                    if try self.findProjectNamed(project.name, excludingId: project.id, in: self.backgroundContext) != nil {
                        logWarning(
                            event: "cloudkit_project_uniqueness_rejected",
                            message: "Rejected duplicate project name before Core Data update",
                            fields: [
                                "project_id": project.id.uuidString,
                                "project_name": project.name
                            ]
                        )
                        callback.deliver(.failure(ProjectValidationError.duplicateName))
                        return
                    }

                    // Update the entity with new data
                    ProjectMapper.updateEntity(entity, from: project)
                    try self.backgroundContext.save()
                    logDebug("✅ Updated project '\(project.name)' with UUID: \(project.id)")
                    callback.deliver(.success(project))
                } catch {
                    logError(" Failed to update project: \(error)")
                    callback.deliver(.failure(error))
                }
            } else {
                let error = NSError(domain: "ProjectRepository", code: 404,
                                  userInfo: [NSLocalizedDescriptionKey: "Project not found"])
                logError(" Project not found: \(project.id)")
                callback.deliver(.failure(error))
            }
        }
    }
    
    /// Executes renameProject.
    public func renameProject(withId id: UUID, to newName: String, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        let callback = CoreDataRepositoryCompletion(completion)
        fetchProject(withId: id) { [weak self] result in
            switch result {
            case .success(let project):
                guard let project = project else {
                    let error = NSError(domain: "ProjectRepository", code: 404,
                                      userInfo: [NSLocalizedDescriptionKey: "Project not found"])
                    callback.deliver(.failure(error))
                    return
                }
                
                // Update project entity by project UUID.
                guard let self else { return }
                self.backgroundContext.perform {
                    let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    request.fetchLimit = 1

                    do {
                        if try self.findProjectNamed(newName, excludingId: id, in: self.backgroundContext) != nil {
                            logWarning(
                                event: "cloudkit_project_uniqueness_rejected",
                                message: "Rejected duplicate project name before Core Data rename",
                                fields: [
                                    "project_id": id.uuidString,
                                    "project_name": newName
                                ]
                            )
                            callback.deliver(.failure(ProjectValidationError.duplicateName))
                            return
                        }

                        guard let entity = try self.backgroundContext.fetch(request).first else {
                            let notFound = NSError(
                                domain: "ProjectRepository",
                                code: 404,
                                userInfo: [NSLocalizedDescriptionKey: "Project not found"]
                            )
                            callback.deliver(.failure(notFound))
                            return
                        }

                        entity.name = newName
                        entity.updatedAt = Date()
                        entity.modifiedDate = Date()
                        try self.backgroundContext.save()

                        var renamedProject = project
                        renamedProject.name = newName
                        callback.deliver(.success(renamedProject))
                    } catch {
                        callback.deliver(.failure(error))
                    }
                }
                
            case .failure(let error):
                callback.deliver(.failure(error))
            }
        }
    }
    
    // MARK: - Delete Operations
    
    /// Executes deleteProject.
    public func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        let callback = CoreDataRepositoryCompletion(completion)
        fetchProject(withId: id) { [weak self] result in
            switch result {
            case .success(let project):
                guard let project = project else {
                    // Project not found, consider it already deleted
                    callback.deliver(.success(()))
                    return
                }
                
                // Don't allow deleting the Inbox project
                if project.isDefault {
                    let error = NSError(domain: "ProjectRepository", code: 403,
                                      userInfo: [NSLocalizedDescriptionKey: "Cannot delete the default Inbox project"])
                    callback.deliver(.failure(error))
                    return
                }
                
                guard let self else { return }
                self.backgroundContext.perform {
                    let request: NSFetchRequest<TaskDefinitionEntity> = TaskDefinitionEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "projectID == %@", id as CVarArg)

                    do {
                        let tasks = try self.backgroundContext.fetch(request)
                        let habitRequest = NSFetchRequest<NSManagedObject>(entityName: "HabitDefinition")
                        habitRequest.predicate = NSPredicate(format: "projectID == %@", id as CVarArg)
                        let habits = try self.backgroundContext.fetch(habitRequest)

                        logDebug("🗑️ Deleting project '\(project.name)' with \(tasks.count) tasks and \(habits.count) habits (deleteTasks: \(deleteTasks))")

                        if deleteTasks {
                            // Delete all tasks in the project
                            tasks.forEach { self.backgroundContext.delete($0) }
                            logDebug("  ❌ Deleted \(tasks.count) tasks")
                        } else {
                            // Move tasks to Inbox.
                            let inboxID = ProjectConstants.inboxProjectID
                            let inboxRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
                            inboxRequest.predicate = NSPredicate(format: "id == %@", inboxID as CVarArg)
                            inboxRequest.fetchLimit = 1
                            let inboxLifeAreaID = try self.backgroundContext.fetch(inboxRequest).first?.lifeAreaID

                            tasks.forEach { task in
                                task.projectID = inboxID
                                task.lifeAreaID = inboxLifeAreaID
                            }
                            logDebug("  ✅ Reassigned \(tasks.count) tasks to Inbox")
                        }

                        habits.forEach { habit in
                            habit.setValue(nil, forKey: "projectID")
                            habit.setValue(nil, forKey: "projectRef")
                        }

                        // Now delete the ProjectEntity entity itself (if it exists)
                        let projectFetchRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
                        projectFetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

                        if let projectEntity = try self.backgroundContext.fetch(projectFetchRequest).first {
                            self.backgroundContext.delete(projectEntity)
                            logDebug("  🗑️ Deleted ProjectEntity entity: '\(projectEntity.name ?? "Unknown")'")
                        }

                        try self.backgroundContext.save()
                        logDebug("✅ Project deletion completed successfully")
                        callback.deliver(.success(()))
                    } catch {
                        logError(" Project deletion failed: \(error)")
                        callback.deliver(.failure(error))
                    }
                }
                
            case .failure(let error):
                callback.deliver(.failure(error))
            }
        }
    }
    
    // MARK: - Task Association
    
    /// Executes getTaskCount.
    public func getTaskCount(for projectId: UUID, completion: @escaping @Sendable (Result<Int, Error>) -> Void) {
        let callback = CoreDataRepositoryCompletion(completion)
        viewContext.perform {
            let request: NSFetchRequest<TaskDefinitionEntity> = TaskDefinitionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "projectID == %@", projectId as CVarArg)

            do {
                let count = try self.viewContext.count(for: request)
                callback.deliver(.success(count))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }
    
    /// Executes moveTasks.
    public func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        let callback = CoreDataRepositoryCompletion(completion)
        fetchProject(withId: sourceProjectId) { [weak self] sourceResult in
            switch sourceResult {
            case .success(let sourceProject):
                guard sourceProject != nil else {
                    let error = NSError(domain: "ProjectRepository", code: 404,
                                      userInfo: [NSLocalizedDescriptionKey: "Source project not found"])
                    callback.deliver(.failure(error))
                    return
                }
                
                guard let self else { return }
                self.fetchProject(withId: targetProjectId) { targetResult in
                    switch targetResult {
                    case .success(let targetProject):
                        guard targetProject != nil else {
                            let error = NSError(domain: "ProjectRepository", code: 404,
                                              userInfo: [NSLocalizedDescriptionKey: "Target project not found"])
                            callback.deliver(.failure(error))
                            return
                        }
                        let targetLifeAreaID = targetProject?.lifeAreaID
                        
                        self.backgroundContext.perform {
                            let request: NSFetchRequest<TaskDefinitionEntity> = TaskDefinitionEntity.fetchRequest()
                            request.predicate = NSPredicate(format: "projectID == %@", sourceProjectId as CVarArg)
                            
                            do {
                                let tasks = try self.backgroundContext.fetch(request)
                                tasks.forEach {
                                    $0.projectID = targetProjectId
                                    $0.lifeAreaID = targetLifeAreaID
                                }
                                
                                try self.backgroundContext.save()
                                callback.deliver(.success(()))
                            } catch {
                                callback.deliver(.failure(error))
                            }
                        }
                        
                    case .failure(let error):
                        callback.deliver(.failure(error))
                    }
                }
                
            case .failure(let error):
                callback.deliver(.failure(error))
            }
        }
    }

    /// Executes moveProjectToLifeArea.
    public func moveProjectToLifeArea(
        projectID: UUID,
        lifeAreaID: UUID,
        completion: @escaping @Sendable (Result<ProjectLifeAreaMoveResult, Error>) -> Void
    ) {
        let callback = CoreDataRepositoryCompletion(completion)
        backgroundContext.perform {
            do {
                let lifeAreaRequest = NSFetchRequest<NSManagedObject>(entityName: "LifeArea")
                lifeAreaRequest.predicate = NSPredicate(format: "id == %@", lifeAreaID as CVarArg)
                lifeAreaRequest.fetchLimit = 1
                guard let lifeAreaObject = try self.backgroundContext.fetch(lifeAreaRequest).first else {
                    let error = NSError(
                        domain: "ProjectRepository",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Target life area not found"]
                    )
                    callback.deliver(.failure(error))
                    return
                }

                let lifeAreaArchived = lifeAreaObject.value(forKey: "isArchived") as? Bool ?? false
                if lifeAreaArchived {
                    let error = NSError(
                        domain: "ProjectRepository",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot move project into an archived life area"]
                    )
                    callback.deliver(.failure(error))
                    return
                }

                let projectRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
                projectRequest.predicate = NSPredicate(format: "id == %@", projectID as CVarArg)
                projectRequest.fetchLimit = 1
                guard let projectEntity = try self.backgroundContext.fetch(projectRequest).first else {
                    let error = NSError(
                        domain: "ProjectRepository",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Project not found"]
                    )
                    callback.deliver(.failure(error))
                    return
                }

                if self.isInboxCandidate(projectEntity) || self.effectiveProjectID(for: projectEntity) == ProjectConstants.inboxProjectID {
                    let error = NSError(
                        domain: "ProjectRepository",
                        code: 403,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot move the default Inbox project"]
                    )
                    callback.deliver(.failure(error))
                    return
                }

                let fromLifeAreaID = projectEntity.lifeAreaID
                if fromLifeAreaID == lifeAreaID {
                    let result = ProjectLifeAreaMoveResult(
                        updatedProjectID: projectID,
                        fromLifeAreaID: fromLifeAreaID,
                        toLifeAreaID: lifeAreaID,
                        tasksRemappedCount: 0
                    )
                    callback.deliver(.success(result))
                    return
                }

                projectEntity.lifeAreaID = lifeAreaID
                if projectEntity.entity.relationshipsByName["lifeAreaRef"] != nil {
                    projectEntity.setValue(lifeAreaObject, forKey: "lifeAreaRef")
                }
                projectEntity.updatedAt = Date()
                projectEntity.modifiedDate = Date()

                let taskRequest: NSFetchRequest<TaskDefinitionEntity> = TaskDefinitionEntity.fetchRequest()
                taskRequest.predicate = NSPredicate(format: "projectID == %@", projectID as CVarArg)
                let tasks = try self.backgroundContext.fetch(taskRequest)

                var remappedCount = 0
                for task in tasks {
                    if task.lifeAreaID != lifeAreaID {
                        remappedCount += 1
                    }
                    task.lifeAreaID = lifeAreaID
                }

                try self.backgroundContext.save()

                let result = ProjectLifeAreaMoveResult(
                    updatedProjectID: projectID,
                    fromLifeAreaID: fromLifeAreaID,
                    toLifeAreaID: lifeAreaID,
                    tasksRemappedCount: remappedCount
                )
                callback.deliver(.success(result))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }

    /// Executes backfillProjectsWithoutLifeArea.
    public func backfillProjectsWithoutLifeArea(
        defaultLifeAreaID: UUID,
        completion: @escaping @Sendable (Result<ProjectLifeAreaBackfillResult, Error>) -> Void
    ) {
        let callback = CoreDataRepositoryCompletion(completion)
        backgroundContext.perform {
            do {
                let lifeAreaRequest = NSFetchRequest<NSManagedObject>(entityName: "LifeArea")
                lifeAreaRequest.predicate = NSPredicate(format: "id == %@", defaultLifeAreaID as CVarArg)
                lifeAreaRequest.fetchLimit = 1
                guard let lifeAreaObject = try self.backgroundContext.fetch(lifeAreaRequest).first else {
                    let error = NSError(
                        domain: "ProjectRepository",
                        code: 404,
                        userInfo: [NSLocalizedDescriptionKey: "Default life area not found"]
                    )
                    callback.deliver(.failure(error))
                    return
                }

                let projectRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
                let projects = try self.backgroundContext.fetch(projectRequest)

                var projectsUpdatedCount = 0
                var tasksRemappedCount = 0
                var inboxPinned = false

                for project in projects {
                    let projectID = self.effectiveProjectID(for: project)
                    let shouldPinInbox = projectID == ProjectConstants.inboxProjectID
                    let shouldBackfill = shouldPinInbox || project.lifeAreaID == nil
                    guard shouldBackfill else { continue }

                    if project.lifeAreaID != defaultLifeAreaID {
                        project.lifeAreaID = defaultLifeAreaID
                        projectsUpdatedCount += 1
                    }

                    if shouldPinInbox {
                        inboxPinned = true
                        project.isInbox = true
                        project.isDefault = true
                    }

                    if project.entity.relationshipsByName["lifeAreaRef"] != nil {
                        project.setValue(lifeAreaObject, forKey: "lifeAreaRef")
                    }
                    project.updatedAt = Date()
                    project.modifiedDate = Date()

                    let taskRequest: NSFetchRequest<TaskDefinitionEntity> = TaskDefinitionEntity.fetchRequest()
                    taskRequest.predicate = NSPredicate(format: "projectID == %@", projectID as CVarArg)
                    let tasks = try self.backgroundContext.fetch(taskRequest)
                    for task in tasks {
                        if task.lifeAreaID != defaultLifeAreaID {
                            tasksRemappedCount += 1
                        }
                        task.lifeAreaID = defaultLifeAreaID
                    }
                }

                if self.backgroundContext.hasChanges {
                    try self.backgroundContext.save()
                }

                let result = ProjectLifeAreaBackfillResult(
                    defaultLifeAreaID: defaultLifeAreaID,
                    projectsUpdatedCount: projectsUpdatedCount,
                    tasksRemappedCount: tasksRemappedCount,
                    inboxPinned: inboxPinned
                )
                callback.deliver(.success(result))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }
    
    // MARK: - Validation
    
    /// Executes isProjectNameAvailable.
    public func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping @Sendable (Result<Bool, Error>) -> Void) {
        let callback = CoreDataRepositoryCompletion(completion)
        viewContext.perform {
            do {
                let existingProject = try self.findProjectNamed(name, excludingId: excludingId, in: self.viewContext)
                callback.deliver(.success(existingProject == nil))
            } catch {
                callback.deliver(.failure(error))
            }
        }
    }

    private func findProjectNamed(
        _ name: String,
        excludingId: UUID?,
        in context: NSManagedObjectContext?
    ) throws -> ProjectEntity? {
        guard let context, let normalized = normalizedName(name) else {
            return nil
        }
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.returnsObjectsAsFaults = false
        let projects = try context.fetch(request)
        return projects.first { project in
            guard project.id != excludingId,
                  let candidate = normalizedName(project.name) else {
                return false
            }
            return candidate.caseInsensitiveCompare(normalized) == .orderedSame
        }
    }

    /// Executes normalizeProjectIdentity.
    private func normalizeProjectIdentity(_ entity: ProjectEntity) {
        if entity.id == nil {
            let derivedID: UUID
            if isInboxCandidate(entity) {
                derivedID = ProjectConstants.inboxProjectID
            } else {
                derivedID = Self.stableUUID(from: entity.objectID.uriRepresentation().absoluteString)
            }
            entity.id = derivedID
        }
    }

    /// Executes normalizeAsCanonicalInbox.
    private func normalizeAsCanonicalInbox(_ entity: ProjectEntity) {
        entity.id = ProjectConstants.inboxProjectID
        entity.isInbox = true
        entity.isDefault = true
        entity.name = ProjectConstants.inboxProjectName
        entity.projectDescription = ProjectConstants.inboxProjectDescription
    }

    /// Executes repointTasks.
    private func repointTasks(from source: ProjectEntity, to target: ProjectEntity) {
        let sourceIDs = Set([source.id].compactMap { $0 })
        let targetID = effectiveProjectID(for: target)

        let request: NSFetchRequest<TaskDefinitionEntity> = TaskDefinitionEntity.fetchRequest()
        var predicates: [NSPredicate] = []

        if sourceIDs.isEmpty == false {
            predicates.append(NSPredicate(format: "projectID IN %@", Array(sourceIDs)))
        }
        guard predicates.isEmpty == false else {
            return
        }

        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: predicates)
        do {
            let tasks = try backgroundContext.fetch(request)
            for task in tasks {
                task.projectID = targetID
                task.lifeAreaID = target.lifeAreaID
            }
        } catch {
            logWarning("Project identity repair could not repoint tasks: \(error.localizedDescription)")
        }
    }

    /// Executes selectCanonicalInbox.
    private func selectCanonicalInbox(from candidates: [ProjectEntity]) -> ProjectEntity? {
        candidates.sorted { lhs, rhs in
            let lhsRank = inboxCanonicalRank(lhs)
            let rhsRank = inboxCanonicalRank(rhs)
            if lhsRank != rhsRank {
                return lhsRank < rhsRank
            }
            return createdDate(lhs) < createdDate(rhs)
        }.first
    }

    /// Executes selectCanonicalProject.
    private func selectCanonicalProject(from candidates: [ProjectEntity], targetID: UUID) -> ProjectEntity {
        if targetID == ProjectConstants.inboxProjectID, let inbox = selectCanonicalInbox(from: candidates) {
            return inbox
        }
        return candidates.min(by: { createdDate($0) < createdDate($1) }) ?? candidates[0]
    }

    /// Executes inboxCanonicalRank.
    private func inboxCanonicalRank(_ entity: ProjectEntity) -> Int {
        let id = entity.id
        if id == ProjectConstants.inboxProjectID {
            return 0
        }
        return 1
    }

    /// Executes createdDate.
    private func createdDate(_ entity: ProjectEntity) -> Date {
        entity.createdDate ?? entity.createdAt ?? .distantFuture
    }

    /// Executes isInboxCandidate.
    private func isInboxCandidate(_ entity: ProjectEntity) -> Bool {
        if entity.id == ProjectConstants.inboxProjectID {
            return true
        }
        if entity.isInbox || entity.isDefault {
            return true
        }
        return normalizedName(entity.name)?.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame
    }

    /// Executes effectiveProjectID.
    private func effectiveProjectID(for entity: ProjectEntity) -> UUID {
        if let id = entity.id {
            return id
        }
        return Self.stableUUID(from: entity.objectID.uriRepresentation().absoluteString)
    }

    /// Executes normalizedName.
    private func normalizedName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Executes inboxCandidatePredicate.
    private func inboxCandidatePredicate() -> NSPredicate {
        NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "id == %@", ProjectConstants.inboxProjectID as CVarArg),
            NSPredicate(format: "isInbox == YES"),
            NSPredicate(format: "isDefault == YES"),
            NSPredicate(format: "name ==[c] %@", ProjectConstants.inboxProjectName)
        ])
    }

    /// Executes stableUUID.
    private static func stableUUID(from string: String) -> UUID {
        var hash = UInt64(1469598103934665603)
        let prime: UInt64 = 1099511628211
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }

        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<16 {
            bytes[index] = UInt8((hash >> ((index % 8) * 8)) & 0xff)
            hash = hash &* prime ^ UInt64(index)
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40 // version 4 style bits
        bytes[8] = (bytes[8] & 0x3F) | 0x80 // variant bits

        let uuidTuple = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: uuidTuple)
    }
}
