//
//  TaskManagerMigrationAdapter.swift
//  Tasker
//
//  Adapter to migrate from TaskManager singleton to Clean Architecture
//

import Foundation
import CoreData

/// Adapter class to help migrate from TaskManager singleton to Clean Architecture
/// This allows gradual migration without breaking existing code
public final class TaskManagerMigrationAdapter {
    
    // MARK: - Properties
    
    private let useCaseCoordinator: UseCaseCoordinator
    private let context: NSManagedObjectContext
    
    // MARK: - Singleton (for compatibility)
    
    public static var sharedInstance: TaskManagerMigrationAdapter!
    
    // MARK: - Initialization
    
    public init(useCaseCoordinator: UseCaseCoordinator, context: NSManagedObjectContext) {
        self.useCaseCoordinator = useCaseCoordinator
        self.context = context
    }
    
    // MARK: - TaskManager Compatible Methods
    
    /// Get all tasks (legacy compatibility)
    public var getAllTasks: [NTask] {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        return (try? context.fetch(request)) ?? []
    }
    
    /// Get task count (legacy compatibility)
    public var count: Int {
        return getAllTasks.count
    }
    
    /// Get upcoming tasks (legacy compatibility)
    public func getUpcomingTasks() -> [NTask] {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        request.predicate = NSPredicate(format: "taskType == %d", TaskType.upcoming.rawValue)
        request.sortDescriptors = [NSSortDescriptor(key: "dueDate", ascending: true)]
        return (try? context.fetch(request)) ?? []
    }
    
    /// Get all inbox tasks (legacy compatibility)
    public func getAllInboxTasks() -> [NTask] {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        request.predicate = NSPredicate(format: "project == %@ OR project == nil", "Inbox")
        return (try? context.fetch(request)) ?? []
    }
    
    /// Get tasks for date (legacy compatibility)
    public func getTasksForDate(_ date: Date) -> [NTask] {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        request.predicate = NSPredicate(
            format: "dueDate >= %@ AND dueDate < %@",
            startOfDay as NSDate,
            endOfDay as NSDate
        )
        return (try? context.fetch(request)) ?? []
    }
    
    /// Add task (legacy compatibility)
    public func addTask(name: String, details: String?, type: Int32, priority: Int32, dueDate: Date, project: String?) {
        let request = CreateTaskRequest(
            name: name,
            details: details,
            type: TaskType(rawValue: type),
            priority: TaskPriority(rawValue: priority),
            dueDate: dueDate,
            projectName: project
        )
        
        useCaseCoordinator.createTask.execute(request: request) { _ in
            // Fire and forget for legacy compatibility
        }
    }
    
    /// Toggle task complete (legacy compatibility)
    public func toggleTaskComplete(task: NTask) {
        guard let taskId = getTaskId(from: task) else { return }
        
        useCaseCoordinator.completeTask.execute(taskId: taskId) { _ in
            // Fire and forget for legacy compatibility
        }
    }
    
    /// Delete task (legacy compatibility)
    public func deleteTask(_ task: NTask) {
        guard let taskId = getTaskId(from: task) else { return }
        
        let deleteUseCase = DeleteTaskUseCase(
            taskRepository: useCaseCoordinator.taskRepository,
            notificationService: nil
        )
        
        deleteUseCase.execute(taskId: taskId) { _ in
            // Fire and forget for legacy compatibility
        }
    }
    
    /// Save context (legacy compatibility)
    public func saveContext() {
        if context.hasChanges {
            try? context.save()
        }
    }
    
    // MARK: - Helper Methods
    
    private func getTaskId(from nTask: NTask) -> UUID? {
        // Convert NTask to domain Task to get UUID
        let domainTask = TaskMapper.toDomain(from: nTask)
        return domainTask.id
    }
}

// MARK: - ProjectManager Migration Adapter

/// Adapter class to help migrate from ProjectManager singleton to Clean Architecture
public final class ProjectManagerMigrationAdapter {
    
    // MARK: - Properties
    
    private let manageProjectsUseCase: ManageProjectsUseCase
    public let defaultProject = "Inbox"
    
    // MARK: - Singleton (for compatibility)
    
    public static var sharedInstance: ProjectManagerMigrationAdapter!
    
    // MARK: - Initialization
    
    public init(manageProjectsUseCase: ManageProjectsUseCase) {
        self.manageProjectsUseCase = manageProjectsUseCase
    }
    
    // MARK: - ProjectManager Compatible Methods
    
    /// Get all projects (legacy compatibility)
    public func getAllProjects(completion: @escaping ([String]) -> Void) {
        manageProjectsUseCase.getAllProjects { result in
            switch result {
            case .success(let projectsWithStats):
                let projectNames = projectsWithStats.map { $0.project.name }
                completion(projectNames)
            case .failure:
                completion(["Inbox"])
            }
        }
    }
    
    /// Create project (legacy compatibility)
    public func createProject(name: String, completion: @escaping (Bool) -> Void) {
        let request = CreateProjectRequest(name: name)
        
        manageProjectsUseCase.createProject(request: request) { result in
            switch result {
            case .success:
                completion(true)
            case .failure:
                completion(false)
            }
        }
    }
    
    /// Delete project (legacy compatibility)
    public func deleteProject(name: String, completion: @escaping (Bool) -> Void) {
        // First find the project
        manageProjectsUseCase.getAllProjects { [weak self] result in
            switch result {
            case .success(let projectsWithStats):
                if let project = projectsWithStats.first(where: { $0.project.name == name })?.project {
                    self?.manageProjectsUseCase.deleteProject(
                        projectId: project.id,
                        deleteStrategy: .moveToInbox
                    ) { deleteResult in
                        switch deleteResult {
                        case .success:
                            completion(true)
                        case .failure:
                            completion(false)
                        }
                    }
                } else {
                    completion(false)
                }
            case .failure:
                completion(false)
            }
        }
    }
}

// MARK: - Migration Helper

/// Helper class to setup migration adapters
public final class MigrationHelper {
    
    /// Setup migration adapters to replace singletons
    public static func setupMigrationAdapters(container: PresentationDependencyContainer, context: NSManagedObjectContext) {
        // Setup TaskManager adapter
        TaskManagerMigrationAdapter.sharedInstance = TaskManagerMigrationAdapter(
            useCaseCoordinator: container.coordinator,
            context: context
        )
        
        // Setup ProjectManager adapter
        ProjectManagerMigrationAdapter.sharedInstance = ProjectManagerMigrationAdapter(
            manageProjectsUseCase: container.coordinator.manageProjects
        )
        
        print("✅ Migration adapters configured - singletons can now be gradually replaced")
    }
}
