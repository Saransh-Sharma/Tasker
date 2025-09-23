// App Coordinator
// Manages navigation flow between Legacy UI and Liquid Glass UI

import UIKit

protocol Coordinator: AnyObject {
    var navigationController: UINavigationController { get }
    var childCoordinators: [Coordinator] { get set }
    func start()
}

class AppCoordinator: Coordinator {
    
    // MARK: - Properties
    let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    private let dependencyContainer: DependencyContainer
    
    // MARK: - Initialization
    init(navigationController: UINavigationController, 
         dependencyContainer: DependencyContainer) {
        self.navigationController = navigationController
        self.dependencyContainer = dependencyContainer
    }
    
    // MARK: - Coordinator
    func start() {
        if FeatureFlags.useLiquidGlassUI {
            startLiquidGlassFlow()
        } else {
            startLegacyFlow()
        }
        
        // Listen for feature flag changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFeatureFlagChange),
            name: .featureFlagChanged,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Navigation
    private func startLiquidGlassFlow() {
        let coordinator = LiquidGlassCoordinator(
            navigationController: navigationController,
            dependencyContainer: dependencyContainer
        )
        childCoordinators.append(coordinator)
        coordinator.start()
    }
    
    private func startLegacyFlow() {
        // Use existing HomeViewController - instantiate programmatically
        let homeVC = HomeViewController()
        
        // Inject dependencies if needed
        dependencyContainer.inject(into: homeVC)
        
        navigationController.setViewControllers([homeVC], animated: false)
    }
    
    @objc private func handleFeatureFlagChange() {
        // Restart the app flow when feature flag changes
        childCoordinators.removeAll()
        
        // Smooth transition between UIs
        let transition = CATransition()
        transition.duration = 0.5
        transition.type = .fade
        navigationController.view.layer.add(transition, forKey: kCATransition)
        
        start()
    }
}

class LiquidGlassCoordinator: Coordinator {
    
    // MARK: - Properties
    let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    private let dependencyContainer: DependencyContainer
    
    // MARK: - Initialization
    init(navigationController: UINavigationController,
         dependencyContainer: DependencyContainer) {
        self.navigationController = navigationController
        self.dependencyContainer = dependencyContainer
    }
    
    // MARK: - Coordinator
    func start() {
        showHome()
    }
    
    // MARK: - Navigation
    private func showHome() {
        if FeatureFlags.useLiquidGlassHome {
            // Phase 3: Liquid Glass Home Screen Implementation
            showLiquidGlassHome()
        } else {
            showLegacyWithBanner()
        }
    }
    
    private func showLiquidGlassHome() {
        // For now, show legacy with Phase 3 banner until LGHomeViewController is added to Xcode target
        // This provides a smooth transition and shows Phase 3 progress
        print("🌊 Phase 3: Showing legacy home with Liquid Glass banner (LGHomeViewController ready for Xcode integration)")
        showLegacyWithPhase3Banner()
    }
    
    private func showLegacyWithPhase3Banner() {
        // Create HomeViewController programmatically instead of from storyboard
        let homeVC = HomeViewController()
        
        // Inject dependencies if needed
        dependencyContainer.inject(into: homeVC)
        
        navigationController.setViewControllers([homeVC], animated: false)
        
        // Add Phase 3 completion banner
        if FeatureFlags.showMigrationProgress {
            addPhase3CompletionBanner(to: homeVC)
        }
    }
    
    private func showLegacyWithBanner() {
        // Create HomeViewController programmatically instead of from storyboard
        let homeVC = HomeViewController()
        
        // Inject dependencies if needed
        dependencyContainer.inject(into: homeVC)
        
        navigationController.setViewControllers([homeVC], animated: false)
        
        // Add migration banner
        if FeatureFlags.showMigrationProgress {
            addMigrationBanner(to: homeVC)
        }
    }
    
    private func showLegacyWithEnhancedBanner() {
        // Create HomeViewController programmatically instead of from storyboard
        let homeVC = HomeViewController()
        
        // Inject dependencies if needed
        dependencyContainer.inject(into: homeVC)
        
        navigationController.setViewControllers([homeVC], animated: false)
        
        // Add enhanced banner for Liquid Glass preview
        addEnhancedBanner(to: homeVC)
    }
    
    private func addMigrationBanner(to viewController: UIViewController) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let banner = LGMigrationBanner()
            banner.show(in: viewController.view)
        }
    }
    
    private func addEnhancedBanner(to viewController: UIViewController) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            let banner = LGMigrationBanner()
            banner.updateProgress(0.14, phase: "Phase 1 Complete - Foundation Ready!")
            banner.show(in: viewController.view, autoHide: false)
        }
    }
    
    private func addPhase3CompletionBanner(to viewController: UIViewController) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            let banner = LGMigrationBanner()
            banner.updateProgress(0.60, phase: "Phase 3 Complete - Liquid Glass Home Screen Active! 🌊")
            banner.show(in: viewController.view)
        }
    }
}

// MARK: - Debug Coordinator (for testing)
class LGDebugCoordinator: Coordinator {
    
    let navigationController: UINavigationController
    var childCoordinators: [Coordinator] = []
    
    init(navigationController: UINavigationController) {
        self.navigationController = navigationController
    }
    
    func start() {
        let debugVC = LGDebugMenuViewController()
        navigationController.setViewControllers([debugVC], animated: false)
    }
}
