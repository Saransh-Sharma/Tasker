//
//  CoreDataProjectRepository.swift
//  Tasker
//
//  Core Data implementation of ProjectRepositoryProtocol
//

import Foundation
import CoreData

/// Core Data implementation of the ProjectRepositoryProtocol
/// Note: Currently works with string-based project names as Projects entity doesn't exist yet
public final class CoreDataProjectRepository: ProjectRepositoryProtocol {
    
    // MARK: - Properties
    
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let defaultProjectName = "Inbox"
    
    // MARK: - Initialization

    public init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        
        // Configure contexts
        self.viewContext.automaticallyMergesChangesFromParent = true
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Fetch Operations
    
    public func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "projectName", ascending: true)]

            do {
                let entities = try self.viewContext.fetch(request)
                let projects = ProjectMapper.toDomainArray(from: entities)
                DispatchQueue.main.async { completion(.success(projects)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    public func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(format: "projectID == %@", id as CVarArg)
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
    
    public func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(format: "projectName ==[c] %@", name)
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
    
    public func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        let inboxProject = Project.createInbox()
        completion(.success(inboxProject))
    }
    
    public func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(format: "projectID != %@", ProjectConstants.inboxProjectID as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "projectName", ascending: true)]

            do {
                let entities = try self.viewContext.fetch(request)
                let projects = ProjectMapper.toDomainArray(from: entities)
                DispatchQueue.main.async { completion(.success(projects)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    // MARK: - Create Operations
    
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
    
    public func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        // Check if Inbox Projects entity exists
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(format: "projectID == %@", ProjectConstants.inboxProjectID as CVarArg)
            request.fetchLimit = 1

            do {
                let existingProjects = try self.viewContext.fetch(request)

                if let existingProject = existingProjects.first {
                    // Inbox already exists
                    let inboxProject = ProjectMapper.toDomain(from: existingProject)
                    DispatchQueue.main.async { completion(.success(inboxProject)) }
                } else {
                    // Create Inbox Projects entity
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
    
    // MARK: - Update Operations
    
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
                
                // Update all tasks with the old project name to the new name
                self?.backgroundContext.perform {
                    let request: NSFetchRequest<NTask> = NTask.fetchRequest()
                    request.predicate = NSPredicate(format: "project ==[c] %@", project.name)
                    
                    do {
                        let tasks = try self?.backgroundContext.fetch(request) ?? []
                        tasks.forEach { $0.project = newName }
                        
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
                    // CRITICAL FIX: Use UUID-based queries to find ALL tasks for this project
                    // Query by BOTH projectID AND legacy project string for complete coverage
                    let uuidPredicate = NSPredicate(format: "projectID == %@", id as CVarArg)
                    let stringPredicate = NSPredicate(format: "project ==[c] %@", project.name)
                    let combinedPredicate = NSCompoundPredicate(
                        orPredicateWithSubpredicates: [uuidPredicate, stringPredicate]
                    )

                    let request: NSFetchRequest<NTask> = NTask.fetchRequest()
                    request.predicate = combinedPredicate

                    do {
                        let tasks = try self?.backgroundContext.fetch(request) ?? []

                        logDebug("🗑️ Deleting project '\(project.name)' with \(tasks.count) tasks (deleteTasks: \(deleteTasks))")

                        if deleteTasks {
                            // Delete all tasks in the project
                            tasks.forEach { self?.backgroundContext.delete($0) }
                            logDebug("  ❌ Deleted \(tasks.count) tasks")
                        } else {
                            // CRITICAL FIX: Move tasks to Inbox using BOTH UUID and string (for sync)
                            let inboxID = ProjectConstants.inboxProjectID
                            let inboxName = ProjectConstants.inboxProjectName

                            tasks.forEach { task in
                                task.projectID = inboxID
                                task.project = inboxName  // Keep string in sync for legacy support
                            }
                            logDebug("  ✅ Reassigned \(tasks.count) tasks to Inbox")
                        }

                        // Now delete the Projects entity itself (if it exists)
                        let projectFetchRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
                        projectFetchRequest.predicate = NSPredicate(format: "projectID == %@", id as CVarArg)

                        if let projectEntity = try self?.backgroundContext.fetch(projectFetchRequest).first {
                            self?.backgroundContext.delete(projectEntity)
                            logDebug("  🗑️ Deleted Projects entity: '\(projectEntity.projectName ?? "Unknown")'")
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
    
    public func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = NSPredicate(format: "projectID == %@", projectId as CVarArg)

            do {
                let count = try self.viewContext.count(for: request)
                DispatchQueue.main.async { completion(.success(count)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    public func getTasks(for projectId: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        fetchProject(withId: projectId) { [weak self] result in
            switch result {
            case .success(let project):
                guard let project = project else {
                    completion(.success([]))
                    return
                }
                
                self?.viewContext.perform {
                    let request: NSFetchRequest<NTask> = NTask.fetchRequest()
                    request.predicate = NSPredicate(format: "project ==[c] %@", project.name)
                    request.sortDescriptors = [
                        NSSortDescriptor(key: "dueDate", ascending: true),
                        NSSortDescriptor(key: "taskPriority", ascending: true)
                    ]
                    
                    do {
                        let entities = try self?.viewContext.fetch(request) ?? []
                        let tasks = entities.map { TaskMapper.toDomain(from: $0) }
                        DispatchQueue.main.async { completion(.success(tasks)) }
                    } catch {
                        DispatchQueue.main.async { completion(.failure(error)) }
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
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
                        guard let targetProject = targetProject else {
                            let error = NSError(domain: "ProjectRepository", code: 404,
                                              userInfo: [NSLocalizedDescriptionKey: "Target project not found"])
                            completion(.failure(error))
                            return
                        }
                        
                        self?.backgroundContext.perform {
                            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
                            request.predicate = NSPredicate(format: "project ==[c] %@", sourceProject.name)
                            
                            do {
                                let tasks = try self?.backgroundContext.fetch(request) ?? []
                                tasks.forEach { $0.project = targetProject.name }
                                
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
    
    // MARK: - Validation
    
    public func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(format: "projectName ==[c] %@", name)
            request.fetchLimit = 1

            do {
                let existingProjects = try self.viewContext.fetch(request)

                if let existingProject = existingProjects.first {
                    // Name exists, check if we're excluding this ID
                    if let excludingId = excludingId, existingProject.projectID == excludingId {
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
}
