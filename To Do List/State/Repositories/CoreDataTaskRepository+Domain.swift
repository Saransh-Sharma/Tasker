//
//  CoreDataTaskRepository+Domain.swift
//  Tasker
//
//  Extension to make CoreDataTaskRepository conform to TaskRepositoryProtocol
//

import Foundation
import CoreData

// MARK: - TaskRepositoryProtocol Conformance

extension CoreDataTaskRepository: TaskRepositoryProtocol {
    
    // MARK: - Fetch Operations
    
    func fetchAllTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        viewContext.perform {
            self.viewContext.refreshAllObjects()
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.sortDescriptors = [
                NSSortDescriptor(key: "taskPriority", ascending: true),
                NSSortDescriptor(key: "dueDate", ascending: true)
            ]
            
            do {
                let entities = try self.viewContext.fetch(request)
                let tasks = entities.map { TaskMapper.toDomain(from: $0) }
                DispatchQueue.main.async { completion(.success(tasks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func fetchTasks(for date: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        let startOfDay = date.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let predicate = NSPredicate(
            format: "dueDate >= %@ AND dueDate < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        
        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [
                NSSortDescriptor(key: "taskPriority", ascending: true),
                NSSortDescriptor(key: "dueDate", ascending: true)
            ]
            
            do {
                let entities = try self.viewContext.fetch(request)
                let tasks = entities.map { TaskMapper.toDomain(from: $0) }
                DispatchQueue.main.async { completion(.success(tasks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func fetchTodayTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        let now = Date()
        let startOfToday = now.startOfDay
        let endOfToday = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!

        print("🔍 [REPO] fetchTodayTasks called")
        print("🔍 [REPO] Current time: \(now)")
        print("🔍 [REPO] Start of today: \(startOfToday)")
        print("🔍 [REPO] End of today: \(endOfToday)")

        // Include tasks due today OR overdue incomplete tasks
        // (dueDate >= startOfToday AND dueDate < endOfToday) OR (dueDate < startOfToday AND isComplete == NO)
        let todayPredicate = NSPredicate(
            format: "dueDate >= %@ AND dueDate < %@",
            startOfToday as NSDate,
            endOfToday as NSDate
        )

        let overduePredicate = NSPredicate(
            format: "dueDate < %@ AND isComplete == NO",
            startOfToday as NSDate
        )

        let combinedPredicate = NSCompoundPredicate(
            orPredicateWithSubpredicates: [todayPredicate, overduePredicate]
        )

        print("🔍 [REPO] Combined predicate: \(combinedPredicate)")

        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = combinedPredicate
            request.sortDescriptors = [
                NSSortDescriptor(key: "taskPriority", ascending: true),
                NSSortDescriptor(key: "dueDate", ascending: true)
            ]

            do {
                let entities = try self.viewContext.fetch(request)
                print("🔍 [REPO] Fetched \(entities.count) entities from Core Data")

                // Log details of each entity
                for (index, entity) in entities.enumerated() {
                    print("🔍 [REPO] Task \(index + 1): '\(entity.name ?? "NO NAME")' | dueDate: \(entity.dueDate ?? NSDate()) | isComplete: \(entity.isComplete)")
                }

                let tasks = entities.map { TaskMapper.toDomain(from: $0) }
                print("🔍 [REPO] Mapped to \(tasks.count) domain tasks")

                // Log details of each task
                for (index, task) in tasks.enumerated() {
                    print("🔍 [REPO] Domain Task \(index + 1): '\(task.name)' | dueDate: \(task.dueDate?.description ?? "NIL") | isComplete: \(task.isComplete) | isOverdue: \(task.isOverdue)")
                }

                DispatchQueue.main.async { completion(.success(tasks)) }
            } catch {
                print("❌ [REPO] Error fetching tasks: \(error)")
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func fetchTasks(for project: String, completion: @escaping (Result<[Task], Error>) -> Void) {
        let predicate = NSPredicate(format: "project ==[c] %@", project)
        
        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [
                NSSortDescriptor(key: "dueDate", ascending: true),
                NSSortDescriptor(key: "taskPriority", ascending: true)
            ]
            
            do {
                let entities = try self.viewContext.fetch(request)
                let tasks = entities.map { TaskMapper.toDomain(from: $0) }
                DispatchQueue.main.async { completion(.success(tasks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func fetchOverdueTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        let startOfToday = Date().startOfDay
        let predicate = NSPredicate(
            format: "dueDate < %@ AND isComplete == NO",
            startOfToday as NSDate
        )

        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [
                NSSortDescriptor(key: "taskPriority", ascending: true),
                NSSortDescriptor(key: "dueDate", ascending: false)
            ]

            do {
                let entities = try self.viewContext.fetch(request)
                let tasks = entities.map { TaskMapper.toDomain(from: $0) }
                DispatchQueue.main.async { completion(.success(tasks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func fetchUpcomingTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        let startOfToday = Date().startOfDay
        let startOfTomorrow = Calendar.current.date(byAdding: .day, value: 1, to: startOfToday)!

        let predicate = NSPredicate(
            format: "dueDate >= %@ AND isComplete == NO",
            startOfTomorrow as NSDate
        )

        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [
                NSSortDescriptor(key: "dueDate", ascending: true),
                NSSortDescriptor(key: "taskPriority", ascending: true)
            ]

            do {
                let entities = try self.viewContext.fetch(request)
                let tasks = entities.map { TaskMapper.toDomain(from: $0) }
                DispatchQueue.main.async { completion(.success(tasks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func fetchCompletedTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        let predicate = NSPredicate(format: "isComplete == YES")
        
        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [
                NSSortDescriptor(key: "dateCompleted", ascending: false)
            ]
            
            do {
                let entities = try self.viewContext.fetch(request)
                let tasks = entities.map { TaskMapper.toDomain(from: $0) }
                DispatchQueue.main.async { completion(.success(tasks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func fetchTasks(ofType type: TaskType, completion: @escaping (Result<[Task], Error>) -> Void) {
        let predicate = NSPredicate(format: "taskType == %d", type.rawValue)
        
        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [
                NSSortDescriptor(key: "dueDate", ascending: true),
                NSSortDescriptor(key: "taskPriority", ascending: true)
            ]
            
            do {
                let entities = try self.viewContext.fetch(request)
                let tasks = entities.map { TaskMapper.toDomain(from: $0) }
                DispatchQueue.main.async { completion(.success(tasks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func fetchTask(withId id: UUID, completion: @escaping (Result<Task?, Error>) -> Void) {
        viewContext.perform {
            self.viewContext.refreshAllObjects()
            if let entity = TaskMapper.findEntity(byId: id, in: self.viewContext) {
                let task = TaskMapper.toDomain(from: entity)
                DispatchQueue.main.async { completion(.success(task)) }
            } else {
                DispatchQueue.main.async { completion(.success(nil)) }
            }
        }
    }

    func fetchTasks(from startDate: Date, to endDate: Date, completion: @escaping (Result<[Task], Error>) -> Void) {
        let predicate = NSPredicate(
            format: "dueDate >= %@ AND dueDate <= %@",
            startDate as NSDate,
            endDate as NSDate
        )

        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [
                NSSortDescriptor(key: "dueDate", ascending: true),
                NSSortDescriptor(key: "taskPriority", ascending: true)
            ]

            do {
                let entities = try self.viewContext.fetch(request)
                let tasks = entities.map { TaskMapper.toDomain(from: $0) }
                DispatchQueue.main.async { completion(.success(tasks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    // MARK: - Create Operations
    
    func createTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        backgroundContext.perform {
            let entity = TaskMapper.toEntity(from: task, in: self.backgroundContext)
            
            do {
                try self.backgroundContext.save()
                let savedTask = TaskMapper.toDomain(from: entity)
                DispatchQueue.main.async { completion(.success(savedTask)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    // MARK: - Update Operations
    
    func updateTask(_ task: Task, completion: @escaping (Result<Task, Error>) -> Void) {
        backgroundContext.perform {
            guard let entity = TaskMapper.findEntity(byId: task.id, in: self.backgroundContext) else {
                let error = NSError(domain: "TaskRepository", code: 404, 
                                  userInfo: [NSLocalizedDescriptionKey: "Task not found"])
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            TaskMapper.updateEntity(entity, from: task)
            
            do {
                try self.backgroundContext.save()
                let updatedTask = TaskMapper.toDomain(from: entity)
                DispatchQueue.main.async { completion(.success(updatedTask)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func completeTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        backgroundContext.perform {
            guard let entity = TaskMapper.findEntity(byId: id, in: self.backgroundContext) else {
                let error = NSError(domain: "TaskRepository", code: 404, 
                                  userInfo: [NSLocalizedDescriptionKey: "Task not found"])
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            entity.isComplete = true
            entity.dateCompleted = Date() as NSDate
            
            do {
                try self.backgroundContext.save()
                self.viewContext.performAndWait {
                    self.viewContext.refreshAllObjects()
                }
                let updatedTask = TaskMapper.toDomain(from: entity)
                
                // Post notification for charts refresh
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("TaskCompletionChanged"), object: nil)
                    completion(.success(updatedTask))
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func uncompleteTask(withId id: UUID, completion: @escaping (Result<Task, Error>) -> Void) {
        backgroundContext.perform {
            guard let entity = TaskMapper.findEntity(byId: id, in: self.backgroundContext) else {
                let error = NSError(domain: "TaskRepository", code: 404, 
                                  userInfo: [NSLocalizedDescriptionKey: "Task not found"])
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            entity.isComplete = false
            entity.dateCompleted = nil
            
            do {
                try self.backgroundContext.save()
                self.viewContext.performAndWait {
                    self.viewContext.refreshAllObjects()
                }
                let updatedTask = TaskMapper.toDomain(from: entity)
                
                // Post notification for charts refresh
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: NSNotification.Name("TaskCompletionChanged"), object: nil)
                    completion(.success(updatedTask))
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func rescheduleTask(withId id: UUID, to date: Date, completion: @escaping (Result<Task, Error>) -> Void) {
        backgroundContext.perform {
            guard let entity = TaskMapper.findEntity(byId: id, in: self.backgroundContext) else {
                let error = NSError(domain: "TaskRepository", code: 404, 
                                  userInfo: [NSLocalizedDescriptionKey: "Task not found"])
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }
            
            entity.dueDate = date as NSDate
            
            do {
                try self.backgroundContext.save()
                let updatedTask = TaskMapper.toDomain(from: entity)
                DispatchQueue.main.async { completion(.success(updatedTask)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    // MARK: - Delete Operations
    
    func deleteTask(withId id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            guard let entity = TaskMapper.findEntity(byId: id, in: self.backgroundContext) else {
                // Task not found, but we can consider this a success
                DispatchQueue.main.async { completion(.success(())) }
                return
            }
            
            self.backgroundContext.delete(entity)
            
            do {
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func deleteCompletedTasks(completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = NSPredicate(format: "isComplete == YES")
            
            do {
                let completedTasks = try self.backgroundContext.fetch(request)
                completedTasks.forEach { self.backgroundContext.delete($0) }
                
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    // MARK: - Batch Operations
    
    func createTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        backgroundContext.perform {
            var createdTasks: [Task] = []
            
            for task in tasks {
                let entity = TaskMapper.toEntity(from: task, in: self.backgroundContext)
                createdTasks.append(TaskMapper.toDomain(from: entity))
            }
            
            do {
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion(.success(createdTasks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func updateTasks(_ tasks: [Task], completion: @escaping (Result<[Task], Error>) -> Void) {
        backgroundContext.perform {
            var updatedTasks: [Task] = []
            
            for task in tasks {
                if let entity = TaskMapper.findEntity(byId: task.id, in: self.backgroundContext) {
                    TaskMapper.updateEntity(entity, from: task)
                    updatedTasks.append(TaskMapper.toDomain(from: entity))
                }
            }
            
            do {
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion(.success(updatedTasks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
    
    func deleteTasks(withIds ids: [UUID], completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            for id in ids {
                if let entity = TaskMapper.findEntity(byId: id, in: self.backgroundContext) {
                    self.backgroundContext.delete(entity)
                }
            }

            do {
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    // MARK: - UUID-based Operations

    func fetchTasks(forProjectID projectID: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        let predicate = NSPredicate(format: "projectID == %@", projectID as CVarArg)

        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [
                NSSortDescriptor(key: "dueDate", ascending: true),
                NSSortDescriptor(key: "taskPriority", ascending: true)
            ]

            do {
                let entities = try self.viewContext.fetch(request)
                let tasks = entities.map { TaskMapper.toDomain(from: $0) }
                DispatchQueue.main.async { completion(.success(tasks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func fetchTasksWithoutProject(completion: @escaping (Result<[Task], Error>) -> Void) {
        let predicate = NSPredicate(format: "projectID == nil")

        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = predicate
            request.sortDescriptors = [
                NSSortDescriptor(key: "dateAdded", ascending: false)
            ]

            do {
                let entities = try self.viewContext.fetch(request)
                let tasks = entities.map { TaskMapper.toDomain(from: $0) }
                DispatchQueue.main.async { completion(.success(tasks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func assignTasksToProject(taskIDs: [UUID], projectID: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform {
            for taskID in taskIDs {
                if let entity = TaskMapper.findEntity(byId: taskID, in: self.backgroundContext) {
                    entity.projectID = projectID
                }
            }

            do {
                try self.backgroundContext.save()
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func fetchInboxTasks(completion: @escaping (Result<[Task], Error>) -> Void) {
        fetchTasks(forProjectID: ProjectConstants.inboxProjectID, completion: completion)
    }
}

// MARK: - Helper Extensions

// Note: startOfDay extension already defined in DateUtils.swift
