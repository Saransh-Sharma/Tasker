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
    // It's implemented in the main HomeViewController class
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
        
        // Setup Combine bindings
        setupViewModelBindings()
        
        // Load initial data
        viewModel.loadTodayTasks()
        viewModel.loadProjects()
    }
    
    /// Setup with migration adapter for backward compatibility
    private func setupWithMigrationAdapter() {
        // This allows the app to work even if ViewModel injection fails
        // Uses the migration adapter which wraps the use cases
    }
    
    /// Setup Combine bindings to ViewModel
    private func setupViewModelBindings() {
        guard let viewModel = viewModel else { return }
        
        // Bind loading state
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                // Update UI loading state
                if isLoading {
                    // Show loading indicator if needed
                } else {
                    // Hide loading indicator
                }
            }
            .store(in: &cancellables)
        
        // Bind error messages
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.showError(error)
            }
            .store(in: &cancellables)
        
        // Bind task updates
        viewModel.$morningTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTableView()
            }
            .store(in: &cancellables)
        
        viewModel.$eveningTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTableView()
            }
            .store(in: &cancellables)
        
        viewModel.$overdueTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshTableView()
            }
            .store(in: &cancellables)
        
        // Bind analytics updates
        viewModel.$dailyScore
            .receive(on: DispatchQueue.main)
            .sink { [weak self] score in
                self?.updateScoreDisplay(score)
            }
            .store(in: &cancellables)
        
        viewModel.$streak
            .receive(on: DispatchQueue.main)
            .sink { [weak self] streak in
                self?.updateStreakDisplay(streak)
            }
            .store(in: &cancellables)
        
        viewModel.$completionRate
            .receive(on: DispatchQueue.main)
            .sink { [weak self] rate in
                self?.updateCompletionRateDisplay(rate)
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Task Operations using ViewModel
    
    /// Toggle task completion using ViewModel
    func toggleTaskCompletionClean(_ task: NTask) {
        // Convert NTask to domain Task
        let domainTask = TaskMapper.toDomain(from: task)
        viewModel?.toggleTaskCompletion(domainTask)
    }
    
    /// Delete task using ViewModel
    func deleteTaskClean(_ task: NTask) {
        let domainTask = TaskMapper.toDomain(from: task)
        viewModel?.deleteTask(domainTask)
    }
    
    /// Reschedule task using ViewModel
    func rescheduleTaskClean(_ task: NTask, to date: Date) {
        let domainTask = TaskMapper.toDomain(from: task)
        viewModel?.rescheduleTask(domainTask, to: date)
    }
    
    /// Create task using ViewModel
    func createTaskClean(name: String, details: String?, type: TaskType, priority: TaskPriority, dueDate: Date, project: String?) {
        let request = CreateTaskRequest(
            name: name,
            details: details,
            type: type,
            priority: priority,
            dueDate: dueDate,
            projectName: project
        )
        viewModel?.createTask(request: request)
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
