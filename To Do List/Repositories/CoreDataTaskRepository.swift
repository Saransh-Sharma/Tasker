import Foundation
import CoreData

/// Concrete implementation of TaskRepository using Core Data
final class CoreDataTaskRepository: TaskRepository {
    // MARK: - Properties

    /// Context used for fetching data and displaying in the UI
    internal let viewContext: NSManagedObjectContext

    /// Context used for background operations like saving and updating
    internal let backgroundContext: NSManagedObjectContext

    /// Default project name, usually "Inbox"
    internal let defaultProject: String
    
    // MARK: - Initialization
    
    /// Initializes a new repository with the provided persistent container
    /// - Parameters:
    ///   - container: The Core Data persistent container to use
    ///   - defaultProject: The default project name, defaults to "Inbox"
    init(container: NSPersistentContainer, defaultProject: String = "Inbox") {
        self.viewContext = container.viewContext
        self.backgroundContext = container.newBackgroundContext()
        self.defaultProject = defaultProject
        
        // Configure contexts
        self.viewContext.automaticallyMergesChangesFromParent = true
        self.backgroundContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
    
    // MARK: - Core Methods
    
    func fetchTasks(predicate: NSPredicate?, sortDescriptors: [NSSortDescriptor]?, completion: @escaping ([TaskData]) -> Void) {
        // Use viewContext for read operations so that we always see the latest data saved on the main context (e.g., when a user marks an overdue task complete).
        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = sortDescriptors
            
            do {
                let results = try self.viewContext.fetch(request)
                let data = results.map { TaskData(managedObject: $0) }
                DispatchQueue.main.async { completion(data) }
            } catch {
                logError(
                    event: "task_repository_fetch_failed",
                    message: "Task fetch failed",
                    fields: ["error": error.localizedDescription]
                )
                DispatchQueue.main.async { completion([]) }
            }
        }
    }
    
    func fetchTask(by taskID: NSManagedObjectID, completion: @escaping (Result<NTask, Error>) -> Void) {
        viewContext.perform {
            do {
                let task = try self.viewContext.existingObject(with: taskID) as? NTask
                if let task = task {
                    completion(.success(task))
                } else {
                    let error = NSError(domain: "TaskRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
                    completion(.failure(error))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    func addTask(data: TaskData, completion: ((Result<NTask, Error>) -> Void)?) {
        backgroundContext.perform {
            let managed = NTask(context: self.backgroundContext)
            managed.taskID = UUID()
            managed.name = data.name
            managed.taskDetails = data.details
            managed.taskType = data.type
            managed.taskPriority = data.priorityRawValue
            managed.dueDate = data.dueDate as NSDate
            managed.isComplete = data.isComplete
            managed.dateAdded = data.dateAdded as NSDate
            managed.dateCompleted = data.dateCompleted as NSDate?
            managed.alertReminderTime = data.alertReminderTime as NSDate?

            let requestedProjectName = data.project.trimmingCharacters(in: .whitespacesAndNewlines)
            let effectiveProjectName = requestedProjectName.isEmpty ? ProjectConstants.inboxProjectName : requestedProjectName

            let projectRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
            projectRequest.fetchLimit = 1
            projectRequest.predicate = NSPredicate(format: "projectName ==[c] %@", effectiveProjectName)

            if let matchedProject = try? self.backgroundContext.fetch(projectRequest).first,
               let matchedProjectID = matchedProject.projectID {
                managed.projectID = matchedProjectID
                managed.project = matchedProject.projectName ?? effectiveProjectName
            } else {
                managed.projectID = ProjectConstants.inboxProjectID
                managed.project = ProjectConstants.inboxProjectName
            }

            do {
                try self.backgroundContext.save()
                let savedTaskID = managed.objectID
                
                // Access viewContext only on its own queue (main queue context).
                self.viewContext.perform {
                    do {
                        guard let mainContextTask = try self.viewContext.existingObject(with: savedTaskID) as? NTask else {
                            let error = NSError(domain: "CoreDataTaskRepository", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to retrieve saved task in main context"])
                            completion?(.failure(error))
                            return
                        }
                        NotificationCenter.default.post(name: NSNotification.Name("TaskCreated"), object: mainContextTask)
                        completion?(.success(mainContextTask))
                    } catch {
                        completion?(.failure(error))
                    }
                }
            } catch {
                logError(
                    event: "task_repository_add_failed",
                    message: "Task creation failed",
                    fields: ["error": error.localizedDescription]
                )
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }
    
    func toggleComplete(taskID: NSManagedObjectID, completion: ((Result<Void, Error>) -> Void)?) {
        backgroundContext.perform {
            do {
                guard let task = try self.backgroundContext.existingObject(with: taskID) as? NTask else {
                    throw NSError(domain: "TaskRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
                }
                
                task.isComplete.toggle()
                task.dateCompleted = task.isComplete ? Date() as NSDate : nil
                
                try self.backgroundContext.save()
                
                // Notify that charts should be refreshed
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("TaskCompletionChanged"), object: nil)
                    completion?(.success(()))
                }
            } catch {
                logError(
                    event: "task_repository_toggle_failed",
                    message: "Task completion toggle failed",
                    fields: ["error": error.localizedDescription]
                )
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }
    
    func deleteTask(taskID: NSManagedObjectID, completion: ((Result<Void, Error>) -> Void)?) {
        backgroundContext.perform {
            do {
                let toDelete = try self.backgroundContext.existingObject(with: taskID)
                self.backgroundContext.delete(toDelete)
                
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion?(.success(())) }
            } catch {
                logError(
                    event: "task_repository_delete_failed",
                    message: "Task deletion failed",
                    fields: ["error": error.localizedDescription]
                )
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }
    
    func reschedule(taskID: NSManagedObjectID, to newDate: Date, completion: ((Result<Void, Error>) -> Void)?) {
        backgroundContext.perform {
            do {
                guard let task = try self.backgroundContext.existingObject(with: taskID) as? NTask else {
                    throw NSError(domain: "TaskRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
                }
                
                task.dueDate = newDate as NSDate
                
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion?(.success(())) }
            } catch {
                logError(
                    event: "task_repository_reschedule_failed",
                    message: "Task reschedule failed",
                    fields: ["error": error.localizedDescription]
                )
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }
    
    // MARK: - Task Type Specific Methods
    
    func getMorningTasks(for date: Date, completion: @escaping ([TaskData]) -> Void) {
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = NSPredicate(
            format: "taskType == %d AND dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
            1, // TaskType.morning.rawValue
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        fetchTasks(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)],
            completion: completion
        )
    }
    
    func getEveningTasks(for date: Date, completion: @escaping ([TaskData]) -> Void) {
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = NSPredicate(
            format: "taskType == %d AND dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
            2, // TaskType.evening.rawValue
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        fetchTasks(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)],
            completion: completion
        )
    }
    
    func getUpcomingTasks(completion: @escaping ([TaskData]) -> Void) {
        let predicate = NSPredicate(format: "taskType == %d", 3) // TaskType.upcoming.rawValue
        
        fetchTasks(
            predicate: predicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)],
            completion: completion
        )
    }
    
    // MARK: - Project-Based Methods

    func getTasksForInbox(date: Date, completion: @escaping ([TaskData]) -> Void) {
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // Use UUID-based queries (with string fallback for legacy data during transition)
        let inboxID = ProjectConstants.inboxProjectID

        // Tasks due today and not complete
        let dueTodayPredicate = NSPredicate(
            format: "projectID == %@ AND dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
            inboxID as CVarArg,
            startOfDay as NSDate,
            endOfDay as NSDate
        )

        // Tasks completed today
        let completedTodayPredicate = NSPredicate(
            format: "projectID == %@ AND dateCompleted >= %@ AND dateCompleted < %@ AND isComplete == YES",
            inboxID as CVarArg,
            startOfDay as NSDate,
            endOfDay as NSDate
        )

        // For today's date, also include overdue tasks
        var finalPredicate: NSPredicate
        if Calendar.current.isDateInToday(date) {
            let overduePredicate = NSPredicate(
                format: "projectID == %@ AND dueDate < %@ AND isComplete == NO",
                inboxID as CVarArg,
                startOfDay as NSDate
            )

            // Combine all predicates with OR
            let combinedPredicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [dueTodayPredicate, completedTodayPredicate, overduePredicate]
            )
            finalPredicate = combinedPredicate
        } else {
            // For other dates, just combine due and completed
            finalPredicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [dueTodayPredicate, completedTodayPredicate]
            )
        }

        fetchTasks(
            predicate: finalPredicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)],
            completion: completion
        )
    }
    
    /// Get tasks for a project by UUID (preferred method)
    func getTasksForProject(projectID: UUID, date: Date, completion: @escaping ([TaskData]) -> Void) {
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // Tasks due today and not complete
        let dueTodayPredicate = NSPredicate(
            format: "projectID == %@ AND dueDate >= %@ AND dueDate < %@",
            projectID as CVarArg,
            startOfDay as NSDate,
            endOfDay as NSDate
        )

        // Tasks completed today
        let completedTodayPredicate = NSPredicate(
            format: "projectID == %@ AND dateCompleted >= %@ AND dateCompleted < %@ AND isComplete == YES",
            projectID as CVarArg,
            startOfDay as NSDate,
            endOfDay as NSDate
        )

        // For today's date, also include overdue tasks
        var finalPredicate: NSPredicate
        if Calendar.current.isDateInToday(date) {
            let overduePredicate = NSPredicate(
                format: "projectID == %@ AND dueDate < %@ AND isComplete == NO",
                projectID as CVarArg,
                startOfDay as NSDate
            )

            // Combine all predicates with OR
            let combinedPredicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [dueTodayPredicate, completedTodayPredicate, overduePredicate]
            )
            finalPredicate = combinedPredicate
        } else {
            // For other dates, just combine due and completed
            finalPredicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [dueTodayPredicate, completedTodayPredicate]
            )
        }

        fetchTasks(
            predicate: finalPredicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)],
            completion: completion
        )
    }

    /// Get tasks for a project by name (legacy method - deprecated, use UUID version)
    @available(*, deprecated, message: "Use getTasksForProject(projectID:date:completion:) instead")
    func getTasksForProject(projectName: String, date: Date, completion: @escaping ([TaskData]) -> Void) {
        // For legacy support, we need to look up the project UUID from the name
        // This is a temporary fallback during the transition period
        let context = viewContext
        context.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(format: "projectName ==[c] %@", projectName)
            request.fetchLimit = 1

            do {
                if let project = try context.fetch(request).first,
                   let projectID = project.projectID {
                    // Found project with UUID, use UUID-based query
                    DispatchQueue.main.async {
                        self.getTasksForProject(projectID: projectID, date: date, completion: completion)
                    }
                } else {
                    // Fallback: Project not found or no UUID, return empty
                    logWarning(
                        event: "task_repository_project_lookup_missing_uuid",
                        message: "Project lookup missing UUID in legacy path"
                    )
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            } catch {
                logError(
                    event: "task_repository_project_lookup_failed",
                    message: "Failed to look up project by name",
                    fields: ["error": error.localizedDescription]
                )
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    /// Get open (incomplete) tasks for a project by UUID
    func getTasksForProjectOpen(projectID: UUID, date: Date, completion: @escaping ([TaskData]) -> Void) {
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        let dueTodayPredicate = NSPredicate(
            format: "projectID == %@ AND dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
            projectID as CVarArg,
            startOfDay as NSDate,
            endOfDay as NSDate
        )

        // For today's date, also include overdue tasks
        var finalPredicate: NSPredicate
        if Calendar.current.isDateInToday(date) {
            let overduePredicate = NSPredicate(
                format: "projectID == %@ AND dueDate < %@ AND isComplete == NO",
                projectID as CVarArg,
                startOfDay as NSDate
            )

            // Combine with OR
            finalPredicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [dueTodayPredicate, overduePredicate]
            )
        } else {
            finalPredicate = dueTodayPredicate
        }

        fetchTasks(
            predicate: finalPredicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)],
            completion: completion
        )
    }

    /// Get open tasks for a project by name (legacy - deprecated)
    @available(*, deprecated, message: "Use getTasksForProjectOpen(projectID:date:completion:) instead")
    func getTasksForProjectOpen(projectName: String, date: Date, completion: @escaping ([TaskData]) -> Void) {
        let context = viewContext
        context.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(format: "projectName ==[c] %@", projectName)
            request.fetchLimit = 1

            do {
                if let project = try context.fetch(request).first,
                   let projectID = project.projectID {
                    DispatchQueue.main.async {
                        self.getTasksForProjectOpen(projectID: projectID, date: date, completion: completion)
                    }
                } else {
                    logWarning(
                        event: "task_repository_project_lookup_missing_uuid",
                        message: "Project lookup missing UUID in legacy path"
                    )
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            } catch {
                logError(
                    event: "task_repository_project_lookup_failed",
                    message: "Failed to look up project by name",
                    fields: ["error": error.localizedDescription]
                )
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    func getTasksForAllCustomProjectsOpen(date: Date, completion: @escaping ([TaskData]) -> Void) {
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!

        // Tasks from custom projects (not the Inbox project)
        let inboxID = ProjectConstants.inboxProjectID
        let notDefaultProjectPredicate = NSPredicate(
            format: "projectID != %@",
            inboxID as CVarArg
        )

        // Due today and not complete
        let dueTodayPredicate = NSPredicate(
            format: "dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
            startOfDay as NSDate,
            endOfDay as NSDate
        )

        // Combine with AND
        var combinedPredicate = NSCompoundPredicate(
            andPredicateWithSubpredicates: [notDefaultProjectPredicate, dueTodayPredicate]
        )

        // For today's date, also include overdue tasks
        if Calendar.current.isDateInToday(date) {
            let overduePredicate = NSPredicate(
                format: "dueDate < %@ AND isComplete == NO",
                startOfDay as NSDate
            )

            let overdueCustomPredicate = NSCompoundPredicate(
                andPredicateWithSubpredicates: [notDefaultProjectPredicate, overduePredicate]
            )

            // Combine with OR
            combinedPredicate = NSCompoundPredicate(
                orPredicateWithSubpredicates: [combinedPredicate, overdueCustomPredicate]
            )
        }

        fetchTasks(
            predicate: combinedPredicate,
            sortDescriptors: [NSSortDescriptor(key: "dueDate", ascending: true)],
            completion: completion
        )
    }
    
    // MARK: - Task Update Methods
    
    func updateTask(taskID: NSManagedObjectID, data: TaskData, completion: ((Result<Void, Error>) -> Void)?) {
        backgroundContext.perform {
            do {
                guard let task = try self.backgroundContext.existingObject(with: taskID) as? NTask else {
                    throw NSError(domain: "TaskRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
                }
                
                // Update all task properties with new data
                task.name = data.name
                task.taskDetails = data.details
                task.taskType = data.type
                task.taskPriority = data.priorityRawValue
                task.dueDate = data.dueDate as NSDate
                task.project = data.project
                task.isComplete = data.isComplete
                
                // Only update dateCompleted if completion status changed
                if data.isComplete && task.dateCompleted == nil {
                    task.dateCompleted = Date() as NSDate
                } else if !data.isComplete {
                    task.dateCompleted = nil
                }
                
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion?(.success(())) }
            } catch {
                logError(
                    event: "task_repository_update_failed",
                    message: "Task update failed",
                    fields: ["error": error.localizedDescription]
                )
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }
    
    func saveTask(taskID: NSManagedObjectID, 
                 name: String,
                 details: String?,
                 type: Int32, // TaskType raw value
                 priority: TaskPriority,
                 dueDate: Date,
                 project: String,
                 completion: ((Result<Void, Error>) -> Void)?) {
        backgroundContext.perform {
            do {
                guard let task = try self.backgroundContext.existingObject(with: taskID) as? NTask else {
                    throw NSError(domain: "TaskRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Task not found"])
                }
                
                // Save the current completion status to preserve it
                let wasComplete = task.isComplete
                
                // Update task properties from task details page
                task.name = name
                task.taskDetails = details
                task.taskType = type
                task.taskPriority = Int32(priority.rawValue)
                task.dueDate = dueDate as NSDate
                task.project = project
                
                // Preserve completion status and dateCompleted
                task.isComplete = wasComplete
                
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion?(.success(())) }
            } catch {
                logError(
                    event: "task_repository_save_failed",
                    message: "Task save failed",
                    fields: ["error": error.localizedDescription]
                )
                DispatchQueue.main.async { completion?(.failure(error)) }
            }
        }
    }
}
