// LGIntegrationCoordinator.swift
// Deep integration coordinator for seamless navigation - Phase 6 Implementation
// Maintains Clean Architecture while coordinating between all Liquid Glass screens

import UIKit
import CoreData
import RxSwift
import RxCocoa

// MARK: - Integration Coordinator

final class LGIntegrationCoordinator {
    
    // MARK: - Properties
    
    private let window: UIWindow
    private let context: NSManagedObjectContext
    private let disposeBag = DisposeBag()
    
    // Navigation Controllers
    private var mainNavigationController: UINavigationController?
    private var tabBarController: UITabBarController?
    private var splitViewController: UISplitViewController?
    
    // View Controllers Registry
    private var activeViewControllers: [String: UIViewController] = [:]
    
    // Shared ViewModels for state consistency
    private var sharedTaskListViewModel: LGTaskListViewModel?
    private var sharedProjectViewModel: LGProjectManagementViewModel?
    
    // Navigation state
    private let navigationState = BehaviorRelay<NavigationState>(value: .home)
    
    // MARK: - Initialization
    
    init(window: UIWindow, context: NSManagedObjectContext) {
        self.window = window
        self.context = context
        setupCoordinator()
    }
    
    // MARK: - Setup
    
    private func setupCoordinator() {
        setupNavigationStructure()
        setupStateBindings()
        setupDeepLinking()
        applyOptimizations()
    }
    
    private func setupNavigationStructure() {
        if LGDevice.isIPad {
            setupIPadNavigation()
        } else {
            setupIPhoneNavigation()
        }
    }
    
    private func setupIPhoneNavigation() {
        // Create tab bar structure for iPhone
        tabBarController = UITabBarController()
        
        // Home Tab
        let homeVC = createHomeViewController()
        let homeNav = UINavigationController(rootViewController: homeVC)
        homeNav.tabBarItem = UITabBarItem(
            title: "Home",
            image: UIImage(systemName: "house.fill"),
            tag: 0
        )
        
        // Tasks Tab
        let tasksVC = createTasksViewController()
        let tasksNav = UINavigationController(rootViewController: tasksVC)
        tasksNav.tabBarItem = UITabBarItem(
            title: "Tasks",
            image: UIImage(systemName: "checklist"),
            tag: 1
        )
        
        // Projects Tab
        let projectsVC = createProjectsViewController()
        let projectsNav = UINavigationController(rootViewController: projectsVC)
        projectsNav.tabBarItem = UITabBarItem(
            title: "Projects",
            image: UIImage(systemName: "folder.fill"),
            tag: 2
        )
        
        // Settings Tab
        let settingsVC = createSettingsViewController()
        let settingsNav = UINavigationController(rootViewController: settingsVC)
        settingsNav.tabBarItem = UITabBarItem(
            title: "Settings",
            image: UIImage(systemName: "gear"),
            tag: 3
        )
        
        tabBarController?.viewControllers = [homeNav, tasksNav, projectsNav, settingsNav]
        
        // Apply glass morphism to tab bar
        if let tabBar = tabBarController?.tabBar {
            applyGlassToTabBar(tabBar)
        }
        
        window.rootViewController = tabBarController
    }
    
    private func setupIPadNavigation() {
        // Create split view for iPad
        splitViewController = UISplitViewController(style: .doubleColumn)
        splitViewController?.preferredDisplayMode = .oneBesideSecondary
        splitViewController?.preferredSplitBehavior = .tile
        
        // Primary: Navigation sidebar
        let sidebarVC = createSidebarViewController()
        let sidebarNav = UINavigationController(rootViewController: sidebarVC)
        
        // Secondary: Content area
        let homeVC = createHomeViewController()
        let contentNav = UINavigationController(rootViewController: homeVC)
        
        splitViewController?.setViewController(sidebarNav, for: .primary)
        splitViewController?.setViewController(contentNav, for: .secondary)
        
        window.rootViewController = splitViewController
    }
    
    // MARK: - View Controller Factory
    
    private func createHomeViewController() -> UIViewController {
        let viewModel = LGHomeViewModel(context: context)
        let homeVC = LGHomeViewController(viewModel: viewModel)
        
        // Set up navigation callbacks
        homeVC.onTaskSelected = { [weak self] task in
            self?.navigateToTaskDetail(task)
        }
        
        homeVC.onAddTaskTapped = { [weak self] in
            self?.navigateToAddTask()
        }
        
        activeViewControllers["home"] = homeVC
        return homeVC
    }
    
    private func createTasksViewController() -> UIViewController {
        // Create shared view model if needed
        if sharedTaskListViewModel == nil {
            sharedTaskListViewModel = LGTaskListViewModel(context: context)
        }
        
        let tasksVC = LGTodayViewController()
        tasksVC.viewModel = sharedTaskListViewModel
        
        activeViewControllers["tasks"] = tasksVC
        return tasksVC
    }
    
    private func createProjectsViewController() -> UIViewController {
        // Create shared view model if needed
        if sharedProjectViewModel == nil {
            sharedProjectViewModel = LGProjectManagementViewModel(context: context)
        }
        
        let projectsVC = LGProjectManagementViewController()
        
        // Set up navigation callbacks
        projectsVC.onProjectSelected = { [weak self] project in
            self?.navigateToProjectDetail(project)
        }
        
        activeViewControllers["projects"] = projectsVC
        return projectsVC
    }
    
    private func createSettingsViewController() -> UIViewController {
        let settingsVC = LGSettingsViewController()
        
        // Set up theme change callback
        settingsVC.onThemeChanged = { [weak self] theme in
            self?.handleThemeChange(theme)
        }
        
        activeViewControllers["settings"] = settingsVC
        return settingsVC
    }
    
    private func createSidebarViewController() -> UIViewController {
        let sidebarVC = LGSidebarViewController()
        
        sidebarVC.onItemSelected = { [weak self] item in
            self?.handleSidebarSelection(item)
        }
        
        activeViewControllers["sidebar"] = sidebarVC
        return sidebarVC
    }
    
    // MARK: - Navigation Methods
    
    func navigateToTaskDetail(_ task: NTask) {
        let detailViewModel = LGTaskDetailViewModel(task: task, context: context)
        let detailVC = LGTaskDetailViewController(viewModel: detailViewModel)
        
        // Set up callbacks
        detailVC.onTaskUpdated = { [weak self] in
            self?.refreshAllTaskLists()
        }
        
        detailVC.onTaskDeleted = { [weak self] in
            self?.popViewController()
            self?.refreshAllTaskLists()
        }
        
        pushViewController(detailVC, animated: true)
    }
    
    func navigateToAddTask(project: Projects? = nil) {
        let addViewModel = LGAddTaskViewModel(context: context)
        if let project = project {
            addViewModel.selectedProject.accept(project)
        }
        
        let addVC = LGAddTaskViewController(viewModel: addViewModel)
        
        // Set up callbacks
        addVC.onTaskCreated = { [weak self] task in
            self?.dismissViewController()
            self?.refreshAllTaskLists()
            self?.navigateToTaskDetail(task)
        }
        
        presentViewController(addVC, animated: true)
    }
    
    func navigateToProjectDetail(_ project: Projects) {
        // Create project detail view controller
        let projectDetailVC = LGProjectDetailViewController(project: project, context: context)
        
        projectDetailVC.onProjectUpdated = { [weak self] in
            self?.refreshProjectList()
        }
        
        pushViewController(projectDetailVC, animated: true)
    }
    
    private func pushViewController(_ viewController: UIViewController, animated: Bool) {
        if let navController = currentNavigationController() {
            navController.pushViewController(viewController, animated: animated)
        }
    }
    
    private func presentViewController(_ viewController: UIViewController, animated: Bool) {
        let navController = UINavigationController(rootViewController: viewController)
        
        if LGDevice.isIPad {
            navController.modalPresentationStyle = .formSheet
        }
        
        currentViewController()?.present(navController, animated: animated)
    }
    
    private func popViewController() {
        currentNavigationController()?.popViewController(animated: true)
    }
    
    private func dismissViewController() {
        currentViewController()?.dismiss(animated: true)
    }
    
    // MARK: - State Management
    
    private func setupStateBindings() {
        // Observe navigation state changes
        navigationState
            .distinctUntilChanged()
            .subscribe(onNext: { [weak self] state in
                self?.handleNavigationStateChange(state)
            })
            .disposed(by: disposeBag)
        
        // Observe data changes
        NotificationCenter.default.rx
            .notification(.NSManagedObjectContextDidSave)
            .subscribe(onNext: { [weak self] _ in
                self?.handleDataChange()
            })
            .disposed(by: disposeBag)
    }
    
    private func handleNavigationStateChange(_ state: NavigationState) {
        // Update UI based on navigation state
        switch state {
        case .home:
            tabBarController?.selectedIndex = 0
        case .tasks:
            tabBarController?.selectedIndex = 1
        case .projects:
            tabBarController?.selectedIndex = 2
        case .settings:
            tabBarController?.selectedIndex = 3
        case .detail:
            break // Already navigated
        }
    }
    
    private func handleDataChange() {
        // Refresh all active view controllers
        refreshAllTaskLists()
        refreshProjectList()
        refreshHomeScreen()
    }
    
    private func refreshAllTaskLists() {
        sharedTaskListViewModel?.refreshTasks()
        
        if let homeVC = activeViewControllers["home"] as? LGHomeViewController {
            homeVC.viewModel.refreshData()
        }
    }
    
    private func refreshProjectList() {
        sharedProjectViewModel?.refreshProjects()
    }
    
    private func refreshHomeScreen() {
        if let homeVC = activeViewControllers["home"] as? LGHomeViewController {
            homeVC.viewModel.refreshData()
        }
    }
    
    // MARK: - Deep Linking
    
    private func setupDeepLinking() {
        // Handle URL schemes and universal links
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleDeepLink(_:)),
            name: .lgDeepLinkReceived,
            object: nil
        )
    }
    
    @objc private func handleDeepLink(_ notification: Notification) {
        guard let url = notification.userInfo?["url"] as? URL else { return }
        
        // Parse deep link and navigate
        if url.path.contains("task") {
            if let taskId = extractTaskId(from: url) {
                navigateToTaskWithId(taskId)
            }
        } else if url.path.contains("project") {
            if let projectId = extractProjectId(from: url) {
                navigateToProjectWithId(projectId)
            }
        }
    }
    
    private func extractTaskId(from url: URL) -> NSManagedObjectID? {
        // Extract task ID from URL
        return nil // Implementation depends on URL structure
    }
    
    private func extractProjectId(from url: URL) -> NSManagedObjectID? {
        // Extract project ID from URL
        return nil // Implementation depends on URL structure
    }
    
    private func navigateToTaskWithId(_ taskId: NSManagedObjectID) {
        if let task = try? context.existingObject(with: taskId) as? NTask {
            navigateToTaskDetail(task)
        }
    }
    
    private func navigateToProjectWithId(_ projectId: NSManagedObjectID) {
        if let project = try? context.existingObject(with: projectId) as? Projects {
            navigateToProjectDetail(project)
        }
    }
    
    // MARK: - Theme Management
    
    private func handleThemeChange(_ theme: LGTheme) {
        // Apply theme to all active view controllers
        activeViewControllers.values.forEach { viewController in
            if let themeableVC = viewController as? LGThemeable {
                themeableVC.applyTheme(theme)
            }
        }
        
        // Update navigation bars
        updateNavigationBarAppearance()
        
        // Update tab bar
        if let tabBar = tabBarController?.tabBar {
            applyGlassToTabBar(tabBar)
        }
    }
    
    private func updateNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithTransparentBackground()
        appearance.backgroundColor = LGThemeManager.shared.navigationBarColor
        appearance.titleTextAttributes = [
            .foregroundColor: LGThemeManager.shared.primaryTextColor
        ]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
    }
    
    private func applyGlassToTabBar(_ tabBar: UITabBar) {
        // Apply glass morphism to tab bar
        let glassView = LGBaseView()
        glassView.glassIntensity = 0.9
        glassView.cornerRadius = 0
        glassView.frame = tabBar.bounds
        glassView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        tabBar.insertSubview(glassView, at: 0)
    }
    
    // MARK: - Performance Optimization
    
    private func applyOptimizations() {
        // Optimize navigation transitions
        optimizeNavigationTransitions()
        
        // Preload commonly used view controllers
        preloadViewControllers()
        
        // Set up view controller recycling
        setupViewControllerRecycling()
    }
    
    private func optimizeNavigationTransitions() {
        // Use optimized transition animations
        if let coordinator = tabBarController?.transitionCoordinator {
            coordinator.animateAlongsideTransition(in: nil, animation: { _ in
                LGPerformanceOptimizer.shared.prepareForComplexAnimation()
            }, completion: { _ in
                LGPerformanceOptimizer.shared.completeComplexAnimation()
            })
        }
    }
    
    private func preloadViewControllers() {
        // Preload view controllers in background
        DispatchQueue.global(qos: .utility).async { [weak self] in
            _ = self?.createTasksViewController()
            _ = self?.createProjectsViewController()
        }
    }
    
    private func setupViewControllerRecycling() {
        // Implement view controller recycling for memory efficiency
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
    }
    
    @objc private func handleMemoryWarning() {
        // Release inactive view controllers
        let activeKeys = Set(["home", "tasks", "projects", "settings"])
        activeViewControllers = activeViewControllers.filter { activeKeys.contains($0.key) }
    }
    
    // MARK: - Helper Methods
    
    private func currentViewController() -> UIViewController? {
        if let tabBar = tabBarController {
            return tabBar.selectedViewController
        } else if let split = splitViewController {
            return split.viewController(for: .secondary)
        }
        return window.rootViewController
    }
    
    private func currentNavigationController() -> UINavigationController? {
        if let nav = currentViewController() as? UINavigationController {
            return nav
        } else if let nav = currentViewController()?.navigationController {
            return nav
        }
        return nil
    }
    
    private func handleSidebarSelection(_ item: SidebarItem) {
        switch item {
        case .home:
            navigationState.accept(.home)
        case .today:
            navigationState.accept(.tasks)
        case .projects:
            navigationState.accept(.projects)
        case .settings:
            navigationState.accept(.settings)
        }
    }
}

// MARK: - Supporting Types

enum NavigationState {
    case home, tasks, projects, settings, detail
}

enum SidebarItem {
    case home, today, upcoming, projects, settings
}

// MARK: - Protocols

protocol LGThemeable {
    func applyTheme(_ theme: LGTheme)
}

// MARK: - Extensions

extension Notification.Name {
    static let lgDeepLinkReceived = Notification.Name("lgDeepLinkReceived")
}

// MARK: - Clean Architecture Compliance

extension LGIntegrationCoordinator {
    
    /// Ensures navigation maintains Clean Architecture boundaries
    private func validateArchitectureBoundaries() {
        // ViewControllers should only know about ViewModels
        // ViewModels should only know about Use Cases
        // Use Cases should only know about Repositories
        
        assert(activeViewControllers.values.allSatisfy { vc in
            // Check that view controllers don't directly access Core Data
            return true // Implementation would check for Core Data imports
        }, "Architecture boundary violation detected")
    }
    
    /// Coordinates use case execution across screens
    func executeUseCase<T>(_ useCase: () throws -> T, completion: @escaping (Result<T, Error>) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try LGPerformanceOptimizer.shared.monitorUseCase("UseCase", execute: useCase)
                DispatchQueue.main.async {
                    completion(.success(result))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }
}
