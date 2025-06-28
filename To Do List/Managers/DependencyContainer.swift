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
        print("🔧 DependencyContainer: Starting configuration...")
        self.persistentContainer = container
        self.taskRepository = CoreDataTaskRepository(container: container)
        print("✅ DependencyContainer: Configuration completed successfully")
        print("📊 DependencyContainer: TaskRepository initialized: \(taskRepository != nil)")
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
        
        // Use reflection to inject dependencies
        if let _ = class_getProperty(type(of: viewController), "taskRepository") {
            print("🔍 DependencyContainer: Found taskRepository property in \(vcType)")
            if let dependentVC = viewController as? TaskRepositoryDependent {
                print("✅ DependencyContainer: \(vcType) conforms to TaskRepositoryDependent")
                dependentVC.taskRepository = taskRepository
                print("💉 DependencyContainer: Successfully injected taskRepository into \(vcType)")
                print("📊 DependencyContainer: Verification - taskRepository is nil: \(dependentVC.taskRepository == nil)")
            } else {
                print("⚠️ DependencyContainer: \(vcType) has taskRepository property but doesn't conform to TaskRepositoryDependent")
            }
        } else {
            print("ℹ️ DependencyContainer: \(vcType) doesn't have taskRepository property")
        }
        
        // Recursively inject into child view controllers
        if !viewController.children.isEmpty {
            print("🔄 DependencyContainer: Injecting into \(viewController.children.count) child view controllers")
            for child in viewController.children {
                inject(into: child)
            }
        }
        
        print("✅ DependencyContainer: Injection completed for \(vcType)")
    }
}

/// Protocol for view controllers that depend on TaskRepository
protocol TaskRepositoryDependent: AnyObject {
    var taskRepository: TaskRepository! { get set }
}
