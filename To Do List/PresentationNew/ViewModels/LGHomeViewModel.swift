// LGHomeViewModel.swift
// MVVM ViewModel for Liquid Glass Home Screen
// Bridges to existing Clean Architecture Use Cases and maintains reactive data binding

import Foundation
import UIKit
import CoreData
import RxSwift
import RxCocoa

class LGHomeViewModel {
    
    // MARK: - Dependencies
    private let context: NSManagedObjectContext
    private let disposeBag = DisposeBag()
    
    // MARK: - Reactive Properties
    
    // Tasks
    let tasks = BehaviorRelay<[NTask]>(value: [])
    let filteredTasks = BehaviorRelay<[NTask]>(value: [])
    let completedTasksToday = BehaviorRelay<Int>(value: 0)
    let totalTasksToday = BehaviorRelay<Int>(value: 0)
    
    // UI State
    let isLoading = BehaviorRelay<Bool>(value: false)
    let selectedDate = BehaviorRelay<Date>(value: Date())
    let selectedProject = BehaviorRelay<Projects?>(value: nil)
    let searchText = BehaviorRelay<String>(value: "")
    let showCompletedTasks = BehaviorRelay<Bool>(value: true)
    
    // Progress
    let dailyProgress = BehaviorRelay<Float>(value: 0.0)
    let weeklyProgress = BehaviorRelay<Float>(value: 0.0)
    
    // Projects
    let projects = BehaviorRelay<[Projects]>(value: [])
    
    // Error handling
    let error = PublishRelay<Error>()
    
    // MARK: - Computed Properties
    
    var todayTasksCount: Int {
        return filteredTasks.value.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: selectedDate.value)
        }.count
    }
    
    var completedTodayCount: Int {
        return filteredTasks.value.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: selectedDate.value) && task.isComplete
        }.count
    }
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
        setupBindings()
        loadInitialData()
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Filter tasks based on search text, selected project, and date
        Observable.combineLatest(
            tasks.asObservable(),
            searchText.asObservable(),
            selectedProject.asObservable(),
            selectedDate.asObservable(),
            showCompletedTasks.asObservable()
        )
        .map { [weak self] tasks, searchText, project, date, showCompleted in
            return self?.filterTasks(tasks, searchText: searchText, project: project, date: date, showCompleted: showCompleted) ?? []
        }
        .bind(to: filteredTasks)
        .disposed(by: disposeBag)
        
        // Update progress when filtered tasks change
        filteredTasks
            .map { [weak self] tasks in
                return self?.calculateDailyProgress(tasks) ?? 0.0
            }
            .bind(to: dailyProgress)
            .disposed(by: disposeBag)
        
        // Update task counts
        filteredTasks
            .map { [weak self] tasks in
                return self?.completedTodayCount ?? 0
            }
            .bind(to: completedTasksToday)
            .disposed(by: disposeBag)
        
        filteredTasks
            .map { [weak self] tasks in
                return self?.todayTasksCount ?? 0
            }
            .bind(to: totalTasksToday)
            .disposed(by: disposeBag)
    }
    
    // MARK: - Data Loading
    
    func loadInitialData() {
        isLoading.accept(true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let fetchedTasks = try self.fetchTasks()
                let fetchedProjects = try self.fetchProjects()
                
                DispatchQueue.main.async {
                    self.tasks.accept(fetchedTasks)
                    self.projects.accept(fetchedProjects)
                    self.isLoading.accept(false)
                }
            } catch {
                DispatchQueue.main.async {
                    self.error.accept(error)
                    self.isLoading.accept(false)
                }
            }
        }
    }
    
    func refreshData() {
        loadInitialData()
    }
    
    // MARK: - Task Operations
    
    func toggleTaskCompletion(_ task: NTask) {
        isLoading.accept(true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                // Toggle completion status
                task.isComplete.toggle()
                
                // Set completion date if completing
                if task.isComplete {
                    task.dateCompleted = Date()
                } else {
                    task.dateCompleted = nil
                }
                
                // Save context
                try self.saveContext()
                
                DispatchQueue.main.async {
                    // Refresh data to update UI
                    self.loadInitialData()
                }
            } catch {
                DispatchQueue.main.async {
                    self.error.accept(error)
                    self.isLoading.accept(false)
                }
            }
        }
    }
    
    func deleteTask(_ task: NTask) {
        isLoading.accept(true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let context = self.getContext()
                context.delete(task)
                try context.save()
                
                DispatchQueue.main.async {
                    self.loadInitialData()
                }
            } catch {
                DispatchQueue.main.async {
                    self.error.accept(error)
                    self.isLoading.accept(false)
                }
            }
        }
    }
    
    // MARK: - Filtering
    
    private func filterTasks(_ tasks: [NTask], searchText: String, project: Projects?, date: Date, showCompleted: Bool) -> [NTask] {
        var filtered = tasks
        
        // Filter by search text
        if !searchText.isEmpty {
            filtered = filtered.filter { task in
                return task.taskName?.localizedCaseInsensitiveContains(searchText) == true ||
                       task.taskDescription?.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        // Filter by project
        if let project = project {
            filtered = filtered.filter { task in
                return task.taskProject == project
            }
        }
        
        // Filter by completion status
        if !showCompleted {
            filtered = filtered.filter { !$0.isComplete }
        }
        
        // Sort by priority and due date
        filtered.sort { task1, task2 in
            // First sort by completion status (incomplete first)
            if task1.isComplete != task2.isComplete {
                return !task1.isComplete && task2.isComplete
            }
            
            // Then by priority (higher priority first)
            if task1.taskPriority != task2.taskPriority {
                return task1.taskPriority > task2.taskPriority
            }
            
            // Finally by due date (earlier first)
            guard let date1 = task1.dueDate, let date2 = task2.dueDate else {
                return task1.dueDate != nil
            }
            return date1 < date2
        }
        
        return filtered
    }
    
    // MARK: - Progress Calculation
    
    private func calculateDailyProgress(_ tasks: [NTask]) -> Float {
        let todayTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: selectedDate.value)
        }
        
        guard !todayTasks.isEmpty else { return 0.0 }
        
        let completedCount = todayTasks.filter { $0.isComplete }.count
        return Float(completedCount) / Float(todayTasks.count)
    }
    
    // MARK: - Core Data Helpers
    
    private func fetchTasks() throws -> [NTask] {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        return try context.fetch(request)
    }
    
    private func fetchProjects() throws -> [Projects] {
        let request: NSFetchRequest<Projects> = Projects.fetchRequest()
        return try context.fetch(request)
    }
    
    private func saveContext() throws {
        if context.hasChanges {
            try context.save()
        }
    }
    
    // MARK: - Date Helpers
    
    func selectDate(_ date: Date) {
        selectedDate.accept(date)
    }
    
    func selectProject(_ project: Projects?) {
        selectedProject.accept(project)
    }
    
    func updateSearchText(_ text: String) {
        searchText.accept(text)
    }
    
    func toggleShowCompleted() {
        showCompletedTasks.accept(!showCompletedTasks.value)
    }
    
    // MARK: - Task Creation
    
    func createNewTask() -> NTask {
        let newTask = NTask(context: context)
        newTask.taskName = "New Task"
        newTask.taskDescription = ""
        newTask.dueDate = selectedDate.value
        newTask.isComplete = false
        newTask.taskPriority = 2 // Medium priority
        newTask.dateCreated = Date()
        
        return newTask
    }
    
    func saveTask(_ task: NTask) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                try self.saveContext()
                DispatchQueue.main.async {
                    self.loadInitialData()
                }
            } catch {
                DispatchQueue.main.async {
                    self.error.accept(error)
                }
            }
        }
    }
    
    // MARK: - Statistics
    
    func getTaskStatistics() -> (total: Int, completed: Int, pending: Int, overdue: Int) {
        let allTasks = tasks.value
        let total = allTasks.count
        let completed = allTasks.filter { $0.isComplete }.count
        let pending = allTasks.filter { !$0.isComplete }.count
        
        let overdue = allTasks.filter { task in
            guard !task.isComplete, let dueDate = task.dueDate else { return false }
            return dueDate < Date()
        }.count
        
        return (total: total, completed: completed, pending: pending, overdue: overdue)
    }
    
    // MARK: - Priority Breakdown
    
    func getPriorityBreakdown(for date: Date) -> [Int32: Int] {
        var counts: [Int32: Int] = [1: 0, 2: 0, 3: 0, 4: 0] // highest, high, medium, low
        
        let tasksForDate = tasks.value.filter { task in
            guard task.isComplete, let completionDate = task.dateCompleted ?? task.dueDate else { return false }
            return Calendar.current.isDate(completionDate, inSameDayAs: date)
        }
        
        for task in tasksForDate {
            let priority = task.taskPriority
            counts[priority, default: 0] += 1
        }
        
        return counts
    }
}
