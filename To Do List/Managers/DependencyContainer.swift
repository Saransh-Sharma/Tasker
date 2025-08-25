import Foundation
import CoreData
import UIKit

/// A container for managing application-wide dependencies
/// This class provides access to shared services and repositories
class DependencyContainer {
    // MARK: - Shared Instance
    
    /// Shared instance of the dependency container
    static let shared = DependencyContainer()
    
    // MARK: - Dependencies
    
    /// Task repository implementation
    private(set) var taskRepository: TaskRepository!
    
    /// Project repository implementation
    private(set) var projectRepository: ProjectRepository!
    
    /// Use case: aggregate task retrieval operations
    private(set) var getTasksUseCase: GetTasksUseCase!
    
    /// Use case: fetch a single task by ID
    private(set) var getTaskByIdUseCase: GetTaskByIdUseCase!
    
    /// Use case: add a new task
    private(set) var addTaskUseCase: AddTaskUseCase!
    
    /// Use case: update an existing task
    private(set) var updateTaskUseCase: UpdateTaskUseCase!
    
    /// Use case: delete a task
    private(set) var deleteTaskUseCase: DeleteTaskUseCase!
    
    /// Use case: reschedule a task
    private(set) var rescheduleTaskUseCase: RescheduleTaskUseCase!
    
    /// Use case: toggle task completion
    private(set) var toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase!
    
    /// Core Data persistent container
    private(set) var persistentContainer: NSPersistentContainer!
    
    // MARK: - Initialization
    
    private init() {
        // Initialize dependencies when first accessed
    }
    
    /// Configures the container with the required dependencies
    /// Call this method during app initialization (in AppDelegate)
    /// - Parameter container: The Core Data persistent container to use
    func configure(with container: NSPersistentContainer) {
        print("🔧 DependencyContainer: Starting configuration...")
        self.persistentContainer = container
        self.taskRepository = CoreDataTaskRepository(container: container)
        self.projectRepository = CoreDataProjectRepository(container: container)
        // Initialize use cases
        self.getTasksUseCase = GetTasksUseCaseImpl(repository: taskRepository)
        self.getTaskByIdUseCase = GetTaskByIdUseCaseImpl(repository: taskRepository)
        self.addTaskUseCase = AddTaskUseCaseImpl(repository: taskRepository)
        self.updateTaskUseCase = UpdateTaskUseCaseImpl(repository: taskRepository)
        self.deleteTaskUseCase = DeleteTaskUseCaseImpl(repository: taskRepository)
        self.rescheduleTaskUseCase = RescheduleTaskUseCaseImpl(repository: taskRepository)
        self.toggleTaskCompletionUseCase = ToggleTaskCompletionUseCaseImpl(repository: taskRepository)
        // Ensure default data prerequisites
        self.projectRepository.ensureDefaultInboxExists(completion: nil)
        print("✅ DependencyContainer: Configuration completed successfully")
        print("📊 DependencyContainer: TaskRepository initialized: \(taskRepository != nil)")
        print("📊 DependencyContainer: ProjectRepository initialized: \(projectRepository != nil)")
    }
    
    /// Injects dependencies into the specified view controller
    /// - Parameter viewController: The view controller to inject dependencies into
    func inject(into viewController: UIViewController) {
        let vcType = String(describing: type(of: viewController))
        print("💉 DependencyContainer: Starting injection for \(vcType)")
        
        // Check if container is properly configured
        guard taskRepository != nil else {
            print("❌ DependencyContainer: ERROR - TaskRepository is nil! Container not configured properly.")
            return
        }
        
        // Inject if the view controller conforms to TaskRepositoryDependent
        if let dependentVC = viewController as? TaskRepositoryDependent {
            print("✅ DependencyContainer: \(vcType) conforms to TaskRepositoryDependent")
            dependentVC.taskRepository = taskRepository
            print("💉 DependencyContainer: Successfully injected taskRepository into \(vcType)")
            print("📊 DependencyContainer: Verification - taskRepository is nil: \(dependentVC.taskRepository == nil)")
        } else {
            print("ℹ️ DependencyContainer: \(vcType) does not conform to TaskRepositoryDependent")
        }
        
        // Inject if the view controller conforms to ProjectRepositoryDependent
        if let projDependentVC = viewController as? ProjectRepositoryDependent {
            print("✅ DependencyContainer: \(vcType) conforms to ProjectRepositoryDependent")
            projDependentVC.projectRepository = projectRepository
            print("💉 DependencyContainer: Successfully injected projectRepository into \(vcType)")
        } else {
            print("ℹ️ DependencyContainer: \(vcType) does not conform to ProjectRepositoryDependent")
        }
        
        // Inject if the view controller conforms to AddTaskUseCaseDependent
        if let addTaskVC = viewController as? AddTaskUseCaseDependent {
            print("✅ DependencyContainer: \(vcType) conforms to AddTaskUseCaseDependent")
            addTaskVC.addTaskUseCase = addTaskUseCase
            print("💉 DependencyContainer: Injected addTaskUseCase into \(vcType)")
        }
        
        // Inject if the view controller conforms to UpdateTaskUseCaseDependent
        if let updateTaskVC = viewController as? UpdateTaskUseCaseDependent {
            print("✅ DependencyContainer: \(vcType) conforms to UpdateTaskUseCaseDependent")
            updateTaskVC.updateTaskUseCase = updateTaskUseCase
            print("💉 DependencyContainer: Injected updateTaskUseCase into \(vcType)")
        }
        
        // Inject if the view controller conforms to DeleteTaskUseCaseDependent
        if let deleteTaskVC = viewController as? DeleteTaskUseCaseDependent {
            print("✅ DependencyContainer: \(vcType) conforms to DeleteTaskUseCaseDependent")
            deleteTaskVC.deleteTaskUseCase = deleteTaskUseCase
            print("💉 DependencyContainer: Injected deleteTaskUseCase into \(vcType)")
        }
        
        // Inject if the view controller conforms to RescheduleTaskUseCaseDependent
        if let rescheduleTaskVC = viewController as? RescheduleTaskUseCaseDependent {
            print("✅ DependencyContainer: \(vcType) conforms to RescheduleTaskUseCaseDependent")
            rescheduleTaskVC.rescheduleTaskUseCase = rescheduleTaskUseCase
            print("💉 DependencyContainer: Injected rescheduleTaskUseCase into \(vcType)")
        }
        
        // Inject if the view controller conforms to ToggleTaskCompletionUseCaseDependent
        if let toggleTaskVC = viewController as? ToggleTaskCompletionUseCaseDependent {
            print("✅ DependencyContainer: \(vcType) conforms to ToggleTaskCompletionUseCaseDependent")
            toggleTaskVC.toggleTaskCompletionUseCase = toggleTaskCompletionUseCase
            print("💉 DependencyContainer: Injected toggleTaskCompletionUseCase into \(vcType)")
        }
        
        // Inject Core Data view context if needed
        if let contextDependentVC = viewController as? ViewContextDependent {
            contextDependentVC.viewContext = persistentContainer.viewContext
            print("💾 DependencyContainer: Injected viewContext into \(vcType)")
        }
        
        // Recursively inject into child view controllers
        if !viewController.children.isEmpty {
            print("🔄 DependencyContainer: Injecting into \(viewController.children.count) child view controllers")
            for child in viewController.children {
                inject(into: child)
            }
        }
        
        // If it's a navigation controller, inject into its stack as well
        if let nav = viewController as? UINavigationController {
            print("🔄 DependencyContainer: Injecting into NavigationController's stack (")
            inject(into: nav.viewControllers)
        }
        
        // If there's a presented view controller already, inject into it too
        if let presented = viewController.presentedViewController {
            print("🔄 DependencyContainer: Injecting into presented view controller -> \(String(describing: type(of: presented)))")
            inject(into: presented)
        }
        
        print("✅ DependencyContainer: Injection completed for \(vcType)")
    }

    /// Convenience injector for arrays of view controllers
    private func inject(into viewControllers: [UIViewController]) {
        for vc in viewControllers {
            inject(into: vc)
        }
    }
}

/// Protocol for view controllers that depend on TaskRepository
protocol TaskRepositoryDependent: AnyObject {
    var taskRepository: TaskRepository! { get set }
}

/// Protocol for view controllers that depend on ProjectRepository
protocol ProjectRepositoryDependent: AnyObject {
    var projectRepository: ProjectRepository! { get set }
}

/// Protocol for view controllers that need Core Data viewContext
protocol ViewContextDependent: AnyObject {
    var viewContext: NSManagedObjectContext! { get set }
}

/// Protocol for injecting AddTaskUseCase
protocol AddTaskUseCaseDependent: AnyObject {
    var addTaskUseCase: AddTaskUseCase! { get set }
}

/// Protocol for injecting UpdateTaskUseCase
protocol UpdateTaskUseCaseDependent: AnyObject {
    var updateTaskUseCase: UpdateTaskUseCase! { get set }
}

/// Protocol for injecting DeleteTaskUseCase
protocol DeleteTaskUseCaseDependent: AnyObject {
    var deleteTaskUseCase: DeleteTaskUseCase! { get set }
}

/// Protocol for injecting RescheduleTaskUseCase
protocol RescheduleTaskUseCaseDependent: AnyObject {
    var rescheduleTaskUseCase: RescheduleTaskUseCase! { get set }
}

/// Protocol for injecting ToggleTaskCompletionUseCase
protocol ToggleTaskCompletionUseCaseDependent: AnyObject {
    var toggleTaskCompletionUseCase: ToggleTaskCompletionUseCase! { get set }
}
