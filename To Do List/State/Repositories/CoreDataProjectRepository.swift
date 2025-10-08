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
final class CoreDataProjectRepository: ProjectRepositoryProtocol {
    
    // MARK: - Properties
    
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let defaultProjectName = "Inbox"
    
    // MARK: - Initialization
    
    init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        
        // Configure contexts
        self.viewContext.automaticallyMergesChangesFromParent = true
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Fetch Operations
    
    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        viewContext.perform {
            let projectNames = ProjectMapper.getAllProjectNames(from: self.viewContext)
            let projects = ProjectMapper.toDomainArray(from: projectNames)
            DispatchQueue.main.async { completion(.success(projects)) }
        }
    }
    
    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
        viewContext.perform {
            let projectNames = ProjectMapper.getAllProjectNames(from: self.viewContext)
            let projects = ProjectMapper.toDomainArray(from: projectNames)
            let project = projects.first { $0.id == id }
            DispatchQueue.main.async { completion(.success(project)) }
        }
    }
    
    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
        viewContext.perform {
            let projectNames = ProjectMapper.getAllProjectNames(from: self.viewContext)
            
            if projectNames.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) {
                let project = ProjectMapper.toDomain(from: name)
                DispatchQueue.main.async { completion(.success(project)) }
            } else {
                DispatchQueue.main.async { completion(.success(nil)) }
            }
        }
    }
    
    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        let inboxProject = Project.createInbox()
        completion(.success(inboxProject))
    }
    
    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        viewContext.perform {
            let projectNames = ProjectMapper.getAllProjectNames(from: self.viewContext)
            let customNames = projectNames.filter { $0 != self.defaultProjectName }
            let projects = ProjectMapper.toDomainArray(from: customNames)
            DispatchQueue.main.async { completion(.success(projects)) }
        }
    }
    
    // MARK: - Create Operations
    
    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        // Since we don't have a Projects entity yet, we just validate the name is unique
        isProjectNameAvailable(project.name, excludingId: nil) { result in
            switch result {
            case .success(let isAvailable):
                if isAvailable {
                    // Project name is available, return the project
                    completion(.success(project))
                } else {
                    let error = ProjectValidationError.duplicateName
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        // Check if any task has "Inbox" as project
        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = NSPredicate(format: "project ==[c] %@", self.defaultProjectName)
            request.fetchLimit = 1
            
            do {
                let count = try self.viewContext.count(for: request)
                if count == 0 {
                    // Create a dummy task with Inbox project to ensure it exists
                    self.backgroundContext.perform {
                        let dummyTask = NTask(context: self.backgroundContext)
                        dummyTask.name = "Welcome to Tasker"
                        dummyTask.project = self.defaultProjectName
                        dummyTask.taskType = TaskType.inbox.rawValue
                        dummyTask.taskPriority = TaskPriority.low.rawValue
                        dummyTask.dueDate = Date() as NSDate
                        dummyTask.dateAdded = Date() as NSDate
                        dummyTask.isComplete = false
                        
                        do {
                            try self.backgroundContext.save()
                            let inboxProject = Project.createInbox()
                            DispatchQueue.main.async { completion(.success(inboxProject)) }
                        } catch {
                            DispatchQueue.main.async { completion(.failure(error)) }
                        }
                    }
                } else {
                    let inboxProject = Project.createInbox()
                    DispatchQueue.main.async { completion(.success(inboxProject)) }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    // MARK: - Update Operations
    
    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        // Since we don't have a Projects entity yet, we need to update all tasks with the old name
        // This is a placeholder implementation
        completion(.success(project))
    }
    
    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
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
    
    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
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

                        print("🗑️ Deleting project '\(project.name)' with \(tasks.count) tasks (deleteTasks: \(deleteTasks))")

                        if deleteTasks {
                            // Delete all tasks in the project
                            tasks.forEach { self?.backgroundContext.delete($0) }
                            print("  ❌ Deleted \(tasks.count) tasks")
                        } else {
                            // CRITICAL FIX: Move tasks to Inbox using BOTH UUID and string (for sync)
                            let inboxID = ProjectConstants.inboxProjectID
                            let inboxName = ProjectConstants.inboxProjectName

                            tasks.forEach { task in
                                task.projectID = inboxID
                                task.project = inboxName  // Keep string in sync for legacy support
                            }
                            print("  ✅ Reassigned \(tasks.count) tasks to Inbox")
                        }

                        // Now delete the Projects entity itself (if it exists)
                        let projectFetchRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
                        projectFetchRequest.predicate = NSPredicate(format: "projectID == %@", id as CVarArg)

                        if let projectEntity = try self?.backgroundContext.fetch(projectFetchRequest).first {
                            self?.backgroundContext.delete(projectEntity)
                            print("  🗑️ Deleted Projects entity: '\(projectEntity.projectName ?? "Unknown")'")
                        }

                        try self?.backgroundContext.save()
                        print("✅ Project deletion completed successfully")
                        DispatchQueue.main.async { completion(.success(())) }
                    } catch {
                        print("❌ Project deletion failed: \(error)")
                        DispatchQueue.main.async { completion(.failure(error)) }
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Task Association
    
    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        fetchProject(withId: projectId) { [weak self] result in
            switch result {
            case .success(let project):
                guard let project = project else {
                    completion(.success(0))
                    return
                }
                
                self?.viewContext.perform {
                    let request: NSFetchRequest<NTask> = NTask.fetchRequest()
                    request.predicate = NSPredicate(format: "project ==[c] %@", project.name)
                    
                    do {
                        let count = try self?.viewContext.count(for: request) ?? 0
                        DispatchQueue.main.async { completion(.success(count)) }
                    } catch {
                        DispatchQueue.main.async { completion(.failure(error)) }
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func getTasks(for projectId: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
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
    
    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
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
    
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        viewContext.perform {
            let projectNames = ProjectMapper.getAllProjectNames(from: self.viewContext)
            
            // Check if name exists (case-insensitive)
            let nameExists = projectNames.contains { existingName in
                existingName.caseInsensitiveCompare(name) == .orderedSame
            }
            
            if let excludingId = excludingId {
                // If we're excluding an ID, check if it's the same project
                let projects = ProjectMapper.toDomainArray(from: projectNames)
                if let existingProject = projects.first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
                    // Name exists, check if it's the same project we're excluding
                    let isAvailable = existingProject.id == excludingId
                    DispatchQueue.main.async { completion(.success(isAvailable)) }
                } else {
                    // Name doesn't exist, it's available
                    DispatchQueue.main.async { completion(.success(true)) }
                }
            } else {
                // Not excluding any ID, just check if name exists
                DispatchQueue.main.async { completion(.success(!nameExists)) }
            }
        }
    }
}
