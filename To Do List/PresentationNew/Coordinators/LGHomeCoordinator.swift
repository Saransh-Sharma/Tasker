// LGHomeCoordinator.swift
// Coordinator for Liquid Glass Home Screen integration
// Handles navigation and integration with existing architecture

import UIKit
import CoreData

class LGHomeCoordinator {
    
    // MARK: - Properties
    private weak var navigationController: UINavigationController?
    private var homeViewController: LGHomeViewController?
    private let taskRepository: TaskRepository
    
    // MARK: - Initialization
    
    init(navigationController: UINavigationController, taskRepository: TaskRepository) {
        self.navigationController = navigationController
        self.taskRepository = taskRepository
    }
    
    // MARK: - Public Methods
    
    func start() {
        let homeVC = LGHomeViewController()
        homeVC.taskRepository = taskRepository
        
        // Configure navigation
        homeVC.navigationItem.title = ""
        homeVC.navigationController?.setNavigationBarHidden(true, animated: false)
        
        self.homeViewController = homeVC
        
        // Present the home view controller
        if let navController = navigationController {
            navController.setViewControllers([homeVC], animated: true)
        }
    }
    
    func showTaskDetail(_ task: NTask) {
        // TODO: Implement task detail presentation
        // This would integrate with existing task detail views
    }
    
    func showTaskCreation() {
        // TODO: Implement task creation flow
        // This would integrate with existing task creation views
    }
    
    func showSettings() {
        // TODO: Implement settings navigation
        // This would integrate with existing settings views
    }
}

// MARK: - Integration Helper

class LGHomeIntegration {
    
    static func replaceHomeViewController(in window: UIWindow?) {
        guard let window = window,
              let rootViewController = window.rootViewController else {
            return
        }
        
        // Get the existing navigation controller or create one
        let navigationController: UINavigationController
        
        if let existingNavController = rootViewController as? UINavigationController {
            navigationController = existingNavController
        } else if let tabBarController = rootViewController as? UITabBarController,
                  let selectedNavController = tabBarController.selectedViewController as? UINavigationController {
            navigationController = selectedNavController
        } else {
            // Create new navigation controller
            navigationController = UINavigationController()
            window.rootViewController = navigationController
        }
        
        // Create task repository
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        let taskRepository = TaskRepository(context: context)
        
        // Create and start coordinator
        let coordinator = LGHomeCoordinator(navigationController: navigationController, taskRepository: taskRepository)
        coordinator.start()
    }
    
    static func enableLiquidGlassHome() {
        // Enable feature flag
        FeatureFlags.enableLiquidGlassUI = true
        FeatureFlags.enableLiquidAnimations = true
        FeatureFlags.enableAdvancedAnimations = true
        
        // Replace home view controller
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            replaceHomeViewController(in: window)
        }
    }
}
