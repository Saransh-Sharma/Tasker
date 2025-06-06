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
        self.persistentContainer = container
        self.taskRepository = CoreDataTaskRepository(container: container)
    }
    
    /// Injects dependencies into the specified view controller
    /// - Parameter viewController: The view controller to inject dependencies into
    func inject(into viewController: UIViewController) {
        // Use reflection to inject dependencies
        if let property = class_getProperty(type(of: viewController), "taskRepository") {
            if let viewController = viewController as? TaskRepositoryDependent {
                viewController.taskRepository = taskRepository
            }
        }
        
        // Recursively inject into child view controllers
        for child in viewController.children {
            inject(into: child)
        }
    }
}

/// Protocol for view controllers that depend on TaskRepository
protocol TaskRepositoryDependent: AnyObject {
    var taskRepository: TaskRepository! { get set }
}
