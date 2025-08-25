import Foundation
import CoreData

/// Concrete implementation of ProjectRepository using Core Data
final class CoreDataProjectRepository: ProjectRepository {
    // MARK: - Properties
    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext
    private let defaultProjectName: String = "Inbox"
    private let defaultProjectDescription: String = "Catch all project for all tasks not attached to a project"

    // MARK: - Init
    init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.viewContext.automaticallyMergesChangesFromParent = true
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }

    // MARK: - Fetch
    func fetchProjects(predicate: NSPredicate?,
                       sortDescriptors: [NSSortDescriptor]?,
                       completion: @escaping ([ProjectData]) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = sortDescriptors
            do {
                let results = try self.viewContext.fetch(request)
                let data = results.map { ProjectData(managedObject: $0) }
                DispatchQueue.main.async { completion(data) }
            } catch {
                print("❌ Project fetch error: \(error)")
                DispatchQueue.main.async { completion([]) }
            }
        }
    }

    func fetchProject(by projectID: NSManagedObjectID,
                      completion: @escaping (Result<Projects, Error>) -> Void) {
        viewContext.perform {
            do {
                if let project = try self.viewContext.existingObject(with: projectID) as? Projects {
                    DispatchQueue.main.async { completion(.success(project)) }
                } else {
                    let error = NSError(domain: "ProjectRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
                    DispatchQueue.main.async { completion(.failure(error)) }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func getProjectByName(_ name: String, completion: @escaping (Projects?) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(format: "projectName ==[c] %@", name)
            request.fetchLimit = 1
            do {
                let results = try self.viewContext.fetch(request)
                DispatchQueue.main.async { completion(results.first) }
            } catch {
                print("❌ Project fetch by name error: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }

    // MARK: - Create
    func addProject(name: String,
                    description: String?,
                    completion: ((Result<Projects, Error>) -> Void)?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async {
                let err = NSError(domain: "ProjectRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Project name cannot be empty"])
                completion?(.failure(err))
            }
            return
        }
        if trimmed.caseInsensitiveCompare(defaultProjectName) == .orderedSame {
            DispatchQueue.main.async {
                let err = NSError(domain: "ProjectRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot create project with reserved name 'Inbox'"])
                completion?(.failure(err))
            }
            return
        }

        // Check duplicate on viewContext first
        getProjectByName(trimmed) { existing in
            if existing != nil {
                let err = NSError(domain: "ProjectRepository", code: 409, userInfo: [NSLocalizedDescriptionKey: "Project with name '\(trimmed)' already exists"])
                completion?(.failure(err))
                return
            }
            self.backgroundContext.perform {
                let proj = Projects(context: self.backgroundContext)
                proj.projectName = trimmed
                proj.projecDescription = description
                do {
                    try self.backgroundContext.save()
                    let objectID = proj.objectID
                    self.viewContext.perform {
                        do {
                            guard let main = try self.viewContext.existingObject(with: objectID) as? Projects else {
                                let error = NSError(domain: "CoreDataProjectRepository", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve saved project in main context"])
                                DispatchQueue.main.async { completion?(.failure(error)) }
                                return
                            }
                            DispatchQueue.main.async { completion?(.success(main)) }
                        } catch {
                            DispatchQueue.main.async { completion?(.failure(error)) }
                        }
                    }
                } catch {
                    print("❌ Project add error: \(error)")
                    DispatchQueue.main.async { completion?(.failure(error)) }
                }
            }
        }
    }

    // MARK: - Update
    func updateProject(projectID: NSManagedObjectID,
                       name: String,
                       description: String?,
                       completion: ((Result<Void, Error>) -> Void)?) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            DispatchQueue.main.async {
                let err = NSError(domain: "ProjectRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Project name cannot be empty"])
                completion?(.failure(err))
            }
            return
        }

        backgroundContext.perform {
            do {
                guard let project = try self.backgroundContext.existingObject(with: projectID) as? Projects else {
                    throw NSError(domain: "ProjectRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
                }

                let oldName = project.projectName ?? ""
                // Prevent invalid renames involving Inbox
                if oldName.caseInsensitiveCompare(self.defaultProjectName) == .orderedSame && trimmed.caseInsensitiveCompare(self.defaultProjectName) != .orderedSame {
                    throw NSError(domain: "ProjectRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot rename the default 'Inbox' project."])
                }
                if oldName.caseInsensitiveCompare(self.defaultProjectName) != .orderedSame && trimmed.caseInsensitiveCompare(self.defaultProjectName) == .orderedSame {
                    throw NSError(domain: "ProjectRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot rename a project to 'Inbox'."])
                }

                // If name changed, check duplicate (case-insensitive) against other projects
                if oldName.caseInsensitiveCompare(trimmed) != .orderedSame {
                    let dupReq: NSFetchRequest<Projects> = Projects.fetchRequest()
                    dupReq.predicate = NSPredicate(format: "projectName ==[c] %@ AND self != %@", trimmed, project)
                    dupReq.fetchLimit = 1
                    let dup = try self.backgroundContext.fetch(dupReq)
                    if !dup.isEmpty {
                        throw NSError(domain: "ProjectRepository", code: 409, userInfo: [NSLocalizedDescriptionKey: "Another project with the name '\(trimmed)' already exists."])
                    }
                }

                project.projectName = trimmed
                project.projecDescription = description

                // If the project name changed, update all tasks pointing to the old name
                if oldName.caseInsensitiveCompare(trimmed) != .orderedSame {
                    let taskReq: NSFetchRequest<NTask> = NTask.fetchRequest()
                    taskReq.predicate = NSPredicate(format: "project ==[c] %@", oldName)
                    let tasks = try self.backgroundContext.fetch(taskReq)
                    for task in tasks {
                        task.project = trimmed
                    }
                }

                try self.backgroundContext.save()
                DispatchQueue.main.async { completion?(.success(())) }
            } catch {
                print("❌ Project update error: \(error)")
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }

    // MARK: - Delete
    func deleteProject(projectID: NSManagedObjectID,
                       completion: ((Result<Void, Error>) -> Void)?) {
        backgroundContext.perform {
            do {
                guard let project = try self.backgroundContext.existingObject(with: projectID) as? Projects else {
                    throw NSError(domain: "ProjectRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
                }
                let name = project.projectName ?? ""
                if name.caseInsensitiveCompare(self.defaultProjectName) == .orderedSame {
                    throw NSError(domain: "ProjectRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Cannot delete the default 'Inbox' project."])
                }

                // Reassign only open (not complete) tasks to Inbox
                let taskReq: NSFetchRequest<NTask> = NTask.fetchRequest()
                taskReq.predicate = NSPredicate(format: "project ==[c] %@ AND isComplete == NO", name)
                let tasks = try self.backgroundContext.fetch(taskReq)
                for task in tasks { task.project = self.defaultProjectName }

                self.backgroundContext.delete(project)
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion?(.success(())) }
            } catch {
                print("❌ Project delete error: \(error)")
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }

    // MARK: - Defaults
    func ensureDefaultInboxExists(completion: ((Result<Projects, Error>) -> Void)?) {
        backgroundContext.perform {
            do {
                let req: NSFetchRequest<Projects> = Projects.fetchRequest()
                req.predicate = NSPredicate(format: "projectName ==[c] %@", self.defaultProjectName)
                let results = try self.backgroundContext.fetch(req)

                if results.isEmpty {
                    let inbox = Projects(context: self.backgroundContext)
                    inbox.projectName = self.defaultProjectName
                    inbox.projecDescription = self.defaultProjectDescription
                    try self.backgroundContext.save()
                    let objectID = inbox.objectID
                    self.viewContext.perform {
                        do {
                            if let main = try self.viewContext.existingObject(with: objectID) as? Projects {
                                DispatchQueue.main.async { completion?(.success(main)) }
                            } else {
                                let err = NSError(domain: "CoreDataProjectRepository", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve created Inbox project in main context"])
                                DispatchQueue.main.async { completion?(.failure(err)) }
                            }
                        } catch {
                            DispatchQueue.main.async { completion?(.failure(error)) }
                        }
                    }
                } else if results.count > 1 {
                    // Keep the first as primary, delete duplicates
                    let primary = results.first!
                    for dup in results.dropFirst() {
                        self.backgroundContext.delete(dup)
                    }
                    try self.backgroundContext.save()
                    DispatchQueue.main.async { completion?(.success(primary)) }
                } else {
                    DispatchQueue.main.async { completion?(.success(results[0])) }
                }
            } catch {
                print("❌ ensureDefaultInboxExists error: \(error)")
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }
}
