//
//  CoreDataProjectRepository.swift
//  Tasker
//
//  Core Data implementation of ProjectRepositoryProtocol
//

import Foundation
import CoreData

/// Core Data implementation of the ProjectRepositoryProtocol
public final class CoreDataProjectRepository: ProjectRepositoryProtocol {
    
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
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Fetch Operations
    
    /// Executes fetchAllProjects.
    public func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            do {
                let entities = try self.viewContext.fetch(request)
                let projects = ProjectMapper.toDomainArray(from: entities)
                DispatchQueue.main.async { completion(.success(projects)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    /// Executes fetchProject.
    public func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
            request.fetchLimit = 1

            do {
                let entities = try self.viewContext.fetch(request)
                let project = entities.first.map { ProjectMapper.toDomain(from: $0) }
                DispatchQueue.main.async { completion(.success(project)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    /// Executes fetchProject.
    public func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "name ==[c] %@", name)
            request.fetchLimit = 1

            do {
                let entities = try self.viewContext.fetch(request)
                let project = entities.first.map { ProjectMapper.toDomain(from: $0) }
                DispatchQueue.main.async { completion(.success(project)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    /// Executes fetchInboxProject.
    public func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        let inboxProject = Project.createInbox()
        completion(.success(inboxProject))
    }
    
    /// Executes fetchCustomProjects.
    public func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

            do {
                let entities = try self.viewContext.fetch(request)
                let projects = ProjectMapper
                    .toDomainArray(from: entities)
                    .filter { !$0.isDefault && !$0.isInbox }
                DispatchQueue.main.async { completion(.success(projects)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    // MARK: - Create Operations
    
    /// Executes createProject.
    public func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        // First validate the name is unique
        isProjectNameAvailable(project.name, excludingId: nil) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let isAvailable):
                if !isAvailable {
                    let error = ProjectValidationError.duplicateName
                    completion(.failure(error))
                    return
                }

                // Persist to database
                self.backgroundContext.perform {
                    _ = ProjectMapper.toEntity(from: project, in: self.backgroundContext)

                    do {
                        try self.backgroundContext.save()
                        logDebug("✅ Created project '\(project.name)' with UUID: \(project.id)")
                        DispatchQueue.main.async { completion(.success(project)) }
                    } catch {
                        logError(" Failed to create project: \(error)")
                        DispatchQueue.main.async { completion(.failure(error)) }
                    }
                }

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Executes ensureInboxProject.
    public func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
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
                                    DispatchQueue.main.async {
                                        completion(.success(project ?? Project.createInbox()))
                                    }
                                case .failure(let error):
                                    DispatchQueue.main.async { completion(.failure(error)) }
                                }
                            }
                        case .failure(let error):
                            DispatchQueue.main.async { completion(.failure(error)) }
                        }
                    }
                    return
                }

                if let existingProject = existingProjects.first {
                    let inboxProject = ProjectMapper.toDomain(from: existingProject)
                    DispatchQueue.main.async { completion(.success(inboxProject)) }
                } else {
                    self.backgroundContext.perform {
                        let inboxProject = Project.createInbox()
                        _ = ProjectMapper.toEntity(from: inboxProject, in: self.backgroundContext)

                        do {
                            try self.backgroundContext.save()
                            logDebug("✅ Created Inbox project with UUID: \(ProjectConstants.inboxProjectID)")
                            DispatchQueue.main.async { completion(.success(inboxProject)) }
                        } catch {
                            logError(" Failed to create Inbox project: \(error)")
                            DispatchQueue.main.async { completion(.failure(error)) }
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    /// Executes repairProjectIdentityCollisions.
    public func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void) {
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
                DispatchQueue.main.async { completion(.success(report)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    // MARK: - Update Operations
    
    /// Executes updateProject.
    public func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        backgroundContext.perform {
            // Find the existing entity
            if let entity = ProjectMapper.findEntity(byId: project.id, in: self.backgroundContext) {
                // Update the entity with new data
                ProjectMapper.updateEntity(entity, from: project)

                do {
                    try self.backgroundContext.save()
                    logDebug("✅ Updated project '\(project.name)' with UUID: \(project.id)")
                    DispatchQueue.main.async { completion(.success(project)) }
                } catch {
                    logError(" Failed to update project: \(error)")
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            } else {
                let error = NSError(domain: "ProjectRepository", code: 404,
                                  userInfo: [NSLocalizedDescriptionKey: "Project not found"])
                logError(" Project not found: \(project.id)")
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    /// Executes renameProject.
    public func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        fetchProject(withId: id) { [weak self] result in
            switch result {
            case .success(let project):
                guard let project = project else {
                    let error = NSError(domain: "ProjectRepository", code: 404,
                                      userInfo: [NSLocalizedDescriptionKey: "Project not found"])
                    completion(.failure(error))
                    return
                }
                
                // Update project entity by project UUID.
                self?.backgroundContext.perform {
                    let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                    request.fetchLimit = 1

                    do {
                        guard let entity = try self?.backgroundContext.fetch(request).first else {
                            let notFound = NSError(
                                domain: "ProjectRepository",
                                code: 404,
                                userInfo: [NSLocalizedDescriptionKey: "Project not found"]
                            )
                            DispatchQueue.main.async { completion(.failure(notFound)) }
                            return
                        }

                        entity.name = newName
                        entity.updatedAt = Date()
                        entity.modifiedDate = Date()
                        try self?.backgroundContext.save()

                        var renamedProject = project
                        renamedProject.name = newName
                        DispatchQueue.main.async { completion(.success(renamedProject)) }
                    } catch {
                        DispatchQueue.main.async { completion(.failure(error)) }
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Delete Operations
    
    /// Executes deleteProject.
    public func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        fetchProject(withId: id) { [weak self] result in
            switch result {
            case .success(let project):
                guard let project = project else {
                    // Project not found, consider it already deleted
                    completion(.success(()))
                    return
                }
                
                // Don't allow deleting the Inbox project
                if project.isDefault {
                    let error = NSError(domain: "ProjectRepository", code: 403,
                                      userInfo: [NSLocalizedDescriptionKey: "Cannot delete the default Inbox project"])
                    completion(.failure(error))
                    return
                }
                
                self?.backgroundContext.perform {
                    let request: NSFetchRequest<TaskDefinitionEntity> = TaskDefinitionEntity.fetchRequest()
                    request.predicate = NSPredicate(format: "projectID == %@", id as CVarArg)

                    do {
                        let tasks = try self?.backgroundContext.fetch(request) ?? []
                        let habitRequest = NSFetchRequest<NSManagedObject>(entityName: "HabitDefinition")
                        habitRequest.predicate = NSPredicate(format: "projectID == %@", id as CVarArg)
                        let habits = try self?.backgroundContext.fetch(habitRequest) ?? []

                        logDebug("🗑️ Deleting project '\(project.name)' with \(tasks.count) tasks and \(habits.count) habits (deleteTasks: \(deleteTasks))")

                        if deleteTasks {
                            // Delete all tasks in the project
                            tasks.forEach { self?.backgroundContext.delete($0) }
                            logDebug("  ❌ Deleted \(tasks.count) tasks")
                        } else {
                            // Move tasks to Inbox.
                            let inboxID = ProjectConstants.inboxProjectID
                            let inboxRequest: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
                            inboxRequest.predicate = NSPredicate(format: "id == %@", inboxID as CVarArg)
                            inboxRequest.fetchLimit = 1
                            let inboxLifeAreaID = try self?.backgroundContext.fetch(inboxRequest).first?.lifeAreaID

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

                        if let projectEntity = try self?.backgroundContext.fetch(projectFetchRequest).first {
                            self?.backgroundContext.delete(projectEntity)
                            logDebug("  🗑️ Deleted ProjectEntity entity: '\(projectEntity.name ?? "Unknown")'")
                        }

                        try self?.backgroundContext.save()
                        logDebug("✅ Project deletion completed successfully")
                        DispatchQueue.main.async { completion(.success(())) }
                    } catch {
                        logError(" Project deletion failed: \(error)")
                        DispatchQueue.main.async { completion(.failure(error)) }
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Task Association
    
    /// Executes getTaskCount.
    public func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<TaskDefinitionEntity> = TaskDefinitionEntity.fetchRequest()
            request.predicate = NSPredicate(format: "projectID == %@", projectId as CVarArg)

            do {
                let count = try self.viewContext.count(for: request)
                DispatchQueue.main.async { completion(.success(count)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    /// Executes moveTasks.
    public func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        fetchProject(withId: sourceProjectId) { [weak self] sourceResult in
            switch sourceResult {
            case .success(let sourceProject):
                guard let sourceProject = sourceProject else {
                    let error = NSError(domain: "ProjectRepository", code: 404,
                                      userInfo: [NSLocalizedDescriptionKey: "Source project not found"])
                    completion(.failure(error))
                    return
                }
                
                self?.fetchProject(withId: targetProjectId) { targetResult in
                    switch targetResult {
                    case .success(let targetProject):
                        guard targetProject != nil else {
                            let error = NSError(domain: "ProjectRepository", code: 404,
                                              userInfo: [NSLocalizedDescriptionKey: "Target project not found"])
                            completion(.failure(error))
                            return
                        }
                        
                        self?.backgroundContext.perform {
                            let request: NSFetchRequest<TaskDefinitionEntity> = TaskDefinitionEntity.fetchRequest()
                            request.predicate = NSPredicate(format: "projectID == %@", sourceProjectId as CVarArg)
                            
                            do {
                                let tasks = try self?.backgroundContext.fetch(request) ?? []
                                tasks.forEach {
                                    $0.projectID = targetProjectId
                                    $0.lifeAreaID = targetProject?.lifeAreaID
                                }
                                
                                try self?.backgroundContext.save()
                                DispatchQueue.main.async { completion(.success(())) }
                            } catch {
                                DispatchQueue.main.async { completion(.failure(error)) }
                            }
                        }
                        
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Executes moveProjectToLifeArea.
    public func moveProjectToLifeArea(
        projectID: UUID,
        lifeAreaID: UUID,
        completion: @escaping (Result<ProjectLifeAreaMoveResult, Error>) -> Void
    ) {
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
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }

                let lifeAreaArchived = lifeAreaObject.value(forKey: "isArchived") as? Bool ?? false
                if lifeAreaArchived {
                    let error = NSError(
                        domain: "ProjectRepository",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot move project into an archived life area"]
                    )
                    DispatchQueue.main.async { completion(.failure(error)) }
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
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }

                if self.isInboxCandidate(projectEntity) || self.effectiveProjectID(for: projectEntity) == ProjectConstants.inboxProjectID {
                    let error = NSError(
                        domain: "ProjectRepository",
                        code: 403,
                        userInfo: [NSLocalizedDescriptionKey: "Cannot move the default Inbox project"]
                    )
                    DispatchQueue.main.async { completion(.failure(error)) }
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
                    DispatchQueue.main.async { completion(.success(result)) }
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
                DispatchQueue.main.async { completion(.success(result)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    /// Executes backfillProjectsWithoutLifeArea.
    public func backfillProjectsWithoutLifeArea(
        defaultLifeAreaID: UUID,
        completion: @escaping (Result<ProjectLifeAreaBackfillResult, Error>) -> Void
    ) {
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
                    DispatchQueue.main.async { completion(.failure(error)) }
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
                DispatchQueue.main.async { completion(.success(result)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    // MARK: - Validation
    
    /// Executes isProjectNameAvailable.
    public func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
            request.predicate = NSPredicate(format: "name ==[c] %@", name)
            request.fetchLimit = 1

            do {
                let existingProjects = try self.viewContext.fetch(request)

                if let existingProject = existingProjects.first {
                    // Name exists, check if we're excluding this ID
                    if let excludingId = excludingId, existingProject.id == excludingId {
                        // It's the same project, name is available
                        DispatchQueue.main.async { completion(.success(true)) }
                    } else {
                        // Different project has this name
                        DispatchQueue.main.async { completion(.success(false)) }
                    }
                } else {
                    // Name doesn't exist, it's available
                    DispatchQueue.main.async { completion(.success(true)) }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
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
