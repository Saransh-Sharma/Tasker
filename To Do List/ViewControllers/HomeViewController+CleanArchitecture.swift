//
//  HomeViewController+CleanArchitecture.swift
//  Tasker
//
//  Extension to migrate HomeViewController to Clean Architecture
//

import UIKit
import Combine

// MARK: - Clean Architecture Protocol Conformance

extension HomeViewController: HomeViewControllerProtocol {
    // This property will be injected by PresentationDependencyContainer
    // It's implemented in the main HomeViewController class as Any? to avoid type conflicts
}

// MARK: - Clean Architecture Methods

extension HomeViewController {
    
    /// Setup Clean Architecture bindings
    func setupCleanArchitecture() {
        guard viewModel != nil else {
            print("⚠️ HomeViewController: ViewModel not injected, using migration adapter")
            setupWithMigrationAdapter()
            return
        }
        
        print("✅ HomeViewController: Using Clean Architecture with ViewModel")
        
        // Setup Combine bindings when real ViewModel types are available
        setupViewModelBindings()
        
        // Load initial data through the ViewModel
        loadInitialDataViaViewModel()
    }
    
    /// Setup with migration adapter for backward compatibility
    private func setupWithMigrationAdapter() {
        // This allows the app to work even if ViewModel injection fails
        // Uses the migration adapter which wraps the use cases
    }
    
    /// Load initial data via ViewModel when available
    private func loadInitialDataViaViewModel() {
        guard let vm = viewModel else { return }
        
        print("📋 Clean Architecture: Loading initial data via ViewModel")
        
        // Use the shared method calling approach
        callViewModelMethod(vm, methodName: "loadTodayTasks")
        callViewModelMethod(vm, methodName: "loadProjects")
    }
    
    /// Setup Combine bindings to ViewModel
    private func setupViewModelBindings() {
        guard viewModel != nil else { return }
        
        // Combine bindings will be set up when real ViewModel types are available
        print("🔗 Clean Architecture: Setting up ViewModel bindings")
        
        // For now, we'll implement a basic observer pattern
        // The real implementation will use @Published properties and Combine
    }
    
    // MARK: - ViewModel Data Conversion Methods
    
    /// Convert ViewModel's today tasks to UI sections
    private func updateUIWithTodayTasks(_ result: Any) {
        // Use type-safe approach with protocol or generic handling
        guard let todayTasks = result as? (Any & AnyObject) else {
            print("⚠️ Unable to convert today tasks result to UI format")
            return
        }
        
        ToDoListSections.removeAll()
        
        // For now, create empty sections as a fallback
        // The real implementation will use proper domain types
        let placeholderSection = ToDoListData.Section(
            title: "📋 Tasks",
            taskListItems: []
        )
        ToDoListSections.append(placeholderSection)
        
        // Update FluentUI table controller
        fluentToDoTableViewController?.updateDataWithViewModelSections(ToDoListSections)
        
        print("✅ Clean Architecture: UI updated with \(ToDoListSections.count) sections")
        refreshTableView()
    }
    
    /// Convert ViewModel's projects to UI sections
    private func updateUIWithProjects(_ projects: [Any]) {
        // This would be used for project-grouped views
        // Implementation depends on the specific project display requirements
        print("📋 Clean Architecture: Projects UI update - \(projects.count) projects available")
    }
    
    // MARK: - Task Operations using ViewModel
    
    /// Toggle task completion using ViewModel
    func toggleTaskCompletionClean(_ task: NTask) {
        // Convert NTask to domain Task when real types are available
        // For now, use direct ViewModel call if available
        if let vm = viewModel {
            // vm.toggleTaskCompletion(domainTask) when real types are available
            print("🔄 Clean Architecture: Toggle task completion for \(task.name ?? "Unknown")")
        }
    }
    
    /// Delete task using ViewModel
    func deleteTaskClean(_ task: NTask) {
        // Convert NTask to domain Task when real types are available
        if let vm = viewModel {
            // vm.deleteTask(domainTask) when real types are available
            print("🗏 Clean Architecture: Delete task \(task.name ?? "Unknown")")
        }
    }
    
    /// Reschedule task using ViewModel
    func rescheduleTaskClean(_ task: NTask, to date: Date) {
        // Convert NTask to domain Task when real types are available
        if let vm = viewModel {
            // vm.rescheduleTask(domainTask, to: date) when real types are available
            print("📅 Clean Architecture: Reschedule task \(task.name ?? "Unknown") to \(date)")
        }
    }
    
    /// Create task using ViewModel
    func createTaskClean(name: String, details: String?, type: Int32, priority: Int32, dueDate: Date, project: String?) {
        // Create request with proper types when available
        if let vm = viewModel {
            // vm.createTask(request: request) when real types are available
            print("➕ Clean Architecture: Create task \(name) with priority \(priority)")
        }
    }
    
    // MARK: - Data Loading using ViewModel
    
    /// Load tasks for selected date using ViewModel
    func loadTasksForDateClean(_ date: Date) {
        viewModel?.selectDate(date)
    }
    
    /// Load tasks for selected project using ViewModel
    func loadTasksForProjectClean(_ projectName: String) {
        viewModel?.selectProject(projectName)
    }
    
    // MARK: - Helper Methods
    
    private func refreshTableView() {
        DispatchQueue.main.async { [weak self] in
            self?.fluentToDoTableViewController?.tableView.reloadData()
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func updateScoreDisplay(_ score: Int) {
        // Update score UI element
    }
    
    private func updateStreakDisplay(_ streak: Int) {
        // Update streak UI element
    }
    
    private func updateCompletionRateDisplay(_ rate: Double) {
        // Update completion rate UI element
    }
}

// MARK: - Migration Methods

extension HomeViewController {
    
    /// Check if using Clean Architecture or legacy
    var isUsingCleanArchitecture: Bool {
        return viewModel != nil
    }
    
    /// Wrapper method for task operations that works with both architectures
    func performTaskOperation(_ operation: TaskOperation) {
        if isUsingCleanArchitecture {
            // Use ViewModel
            switch operation {
            case .toggleComplete(let task):
                toggleTaskCompletionClean(task)
            case .delete(let task):
                deleteTaskClean(task)
            case .reschedule(let task, let date):
                rescheduleTaskClean(task, to: date)
            }
        } else {
            // Fallback to migration adapter (which uses use cases internally)
            switch operation {
            case .toggleComplete(let task):
                TaskManagerMigrationAdapter.sharedInstance.toggleTaskComplete(task: task)
            case .delete(let task):
                TaskManagerMigrationAdapter.sharedInstance.deleteTask(task)
            case .reschedule(let task, let date):
                task.dueDate = date as NSDate
                TaskManagerMigrationAdapter.sharedInstance.saveContext()
            }
        }
    }
    
    /// Enum for task operations
    enum TaskOperation {
        case toggleComplete(NTask)
        case delete(NTask)
        case reschedule(NTask, Date)
    }
}
