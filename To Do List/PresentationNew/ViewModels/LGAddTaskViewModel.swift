// LGAddTaskViewModel.swift
// MVVM ViewModel for Add/Edit Task Screen - Phase 4 Implementation
// Reactive form validation with RxSwift and Core Data integration

import Foundation
import UIKit
import CoreData
import RxSwift
import RxCocoa

class LGAddTaskViewModel {
    
    // MARK: - Dependencies
    private let context: NSManagedObjectContext
    private let disposeBag = DisposeBag()
    
    // MARK: - Input Properties (From UI)
    let taskName = BehaviorRelay<String>(value: "")
    let taskDescription = BehaviorRelay<String>(value: "")
    let selectedPriority = BehaviorRelay<TaskPriority>(value: .medium)
    let selectedProject = BehaviorRelay<Projects?>(value: nil)
    let selectedDueDate = BehaviorRelay<Date>(value: Date())
    let isReminderEnabled = BehaviorRelay<Bool>(value: false)
    let reminderDate = BehaviorRelay<Date?>(value: nil)
    
    // MARK: - Output Properties (To UI)
    let isFormValid = BehaviorRelay<Bool>(value: false)
    let taskNameValidation = BehaviorRelay<ValidationResult>(value: .idle)
    let dueDateValidation = BehaviorRelay<ValidationResult>(value: .valid)
    let formProgress = BehaviorRelay<Float>(value: 0.0)
    let isLoading = BehaviorRelay<Bool>(value: false)
    let error = PublishRelay<Error>()
    let saveSuccess = PublishRelay<NTask>()
    
    // MARK: - Available Data
    let availableProjects = BehaviorRelay<[Projects]>(value: [])
    let availablePriorities = BehaviorRelay<[TaskPriority]>(value: TaskPriority.allCases)
    
    // MARK: - Edit Mode
    private var editingTask: NTask?
    let isEditMode = BehaviorRelay<Bool>(value: false)
    
    // MARK: - Validation Results
    enum ValidationResult {
        case idle
        case valid
        case invalid(String)
        
        var isValid: Bool {
            switch self {
            case .valid: return true
            default: return false
            }
        }
        
        var errorMessage: String? {
            switch self {
            case .invalid(let message): return message
            default: return nil
            }
        }
    }
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext, editingTask: NTask? = nil) {
        self.context = context
        self.editingTask = editingTask
        
        setupBindings()
        loadInitialData()
        
        if let task = editingTask {
            populateFormWithTask(task)
            isEditMode.accept(true)
        }
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Task name validation
        taskName
            .map { [weak self] name in
                return self?.validateTaskName(name) ?? .invalid("Unknown error")
            }
            .bind(to: taskNameValidation)
            .disposed(by: disposeBag)
        
        // Due date validation
        selectedDueDate
            .map { [weak self] date in
                return self?.validateDueDate(date) ?? .valid
            }
            .bind(to: dueDateValidation)
            .disposed(by: disposeBag)
        
        // Form validation
        Observable.combineLatest(
            taskNameValidation.asObservable(),
            dueDateValidation.asObservable()
        )
        .map { nameValidation, dateValidation in
            return nameValidation.isValid && dateValidation.isValid
        }
        .bind(to: isFormValid)
        .disposed(by: disposeBag)
        
        // Form progress calculation
        Observable.combineLatest(
            taskName.asObservable(),
            taskDescription.asObservable(),
            selectedProject.asObservable(),
            isReminderEnabled.asObservable()
        )
        .map { [weak self] name, description, project, reminder in
            return self?.calculateFormProgress(name: name, description: description, project: project, reminder: reminder) ?? 0.0
        }
        .bind(to: formProgress)
        .disposed(by: disposeBag)
        
        // Reminder date validation
        isReminderEnabled
            .subscribe(onNext: { [weak self] enabled in
                if enabled && self?.reminderDate.value == nil {
                    // Set default reminder to 1 hour before due date
                    let dueDate = self?.selectedDueDate.value ?? Date()
                    let reminderTime = Calendar.current.date(byAdding: .hour, value: -1, to: dueDate)
                    self?.reminderDate.accept(reminderTime)
                }
            })
            .disposed(by: disposeBag)
    }
    
    private func loadInitialData() {
        isLoading.accept(true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let projects = try self.fetchProjects()
                
                DispatchQueue.main.async {
                    self.availableProjects.accept(projects)
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
    
    // MARK: - Validation Logic
    
    private func validateTaskName(_ name: String) -> ValidationResult {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedName.isEmpty {
            return .invalid("Task name is required")
        }
        
        if trimmedName.count < 2 {
            return .invalid("Task name must be at least 2 characters")
        }
        
        if trimmedName.count > 100 {
            return .invalid("Task name must be less than 100 characters")
        }
        
        return .valid
    }
    
    private func validateDueDate(_ date: Date) -> ValidationResult {
        let calendar = Calendar.current
        let now = Date()
        
        // Allow past dates for editing existing tasks
        if isEditMode.value {
            return .valid
        }
        
        // For new tasks, warn if due date is in the past
        if calendar.compare(date, to: now, toGranularity: .day) == .orderedAscending {
            return .invalid("Due date is in the past")
        }
        
        return .valid
    }
    
    private func calculateFormProgress(name: String, description: String, project: Projects?, reminder: Bool) -> Float {
        var progress: Float = 0.0
        let totalFields: Float = 5.0
        
        // Task name (required)
        if !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            progress += 1.0
        }
        
        // Description (optional but adds to progress)
        if !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            progress += 1.0
        }
        
        // Project selection (optional)
        if project != nil {
            progress += 1.0
        }
        
        // Priority is always set (default medium)
        progress += 1.0
        
        // Reminder setup
        if reminder {
            progress += 1.0
        }
        
        return progress / totalFields
    }
    
    // MARK: - Form Population (Edit Mode)
    
    private func populateFormWithTask(_ task: NTask) {
        taskName.accept(task.taskName ?? "")
        taskDescription.accept(task.taskDescription ?? "")
        selectedPriority.accept(TaskPriority(rawValue: Int(task.taskPriority)) ?? .medium)
        selectedProject.accept(task.taskProject)
        selectedDueDate.accept(task.dueDate ?? Date())
        
        // Check if task has reminder
        if let reminderTime = task.reminderDate {
            isReminderEnabled.accept(true)
            reminderDate.accept(reminderTime)
        }
    }
    
    // MARK: - Save Operations
    
    func saveTask() {
        guard isFormValid.value else {
            error.accept(ValidationError.invalidForm)
            return
        }
        
        isLoading.accept(true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let task = self.editingTask ?? NTask(context: self.context)
                
                // Update task properties
                task.taskName = self.taskName.value.trimmingCharacters(in: .whitespacesAndNewlines)
                task.taskDescription = self.taskDescription.value.trimmingCharacters(in: .whitespacesAndNewlines)
                task.taskPriority = Int32(self.selectedPriority.value.rawValue)
                task.taskProject = self.selectedProject.value
                task.dueDate = self.selectedDueDate.value
                
                // Set creation date for new tasks
                if self.editingTask == nil {
                    task.dateCreated = Date()
                    task.isComplete = false
                }
                
                // Handle reminder
                if self.isReminderEnabled.value {
                    task.reminderDate = self.reminderDate.value
                } else {
                    task.reminderDate = nil
                }
                
                // Save context
                try self.context.save()
                
                DispatchQueue.main.async {
                    self.isLoading.accept(false)
                    self.saveSuccess.accept(task)
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.error.accept(error)
                    self.isLoading.accept(false)
                }
            }
        }
    }
    
    func deleteTask() {
        guard let task = editingTask else {
            error.accept(ValidationError.noTaskToDelete)
            return
        }
        
        isLoading.accept(true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                self.context.delete(task)
                try self.context.save()
                
                DispatchQueue.main.async {
                    self.isLoading.accept(false)
                    self.saveSuccess.accept(task) // Signal completion
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.error.accept(error)
                    self.isLoading.accept(false)
                }
            }
        }
    }
    
    // MARK: - Data Fetching
    
    private func fetchProjects() throws -> [Projects] {
        let request: NSFetchRequest<Projects> = Projects.fetchRequest()
        let sortDescriptor = NSSortDescriptor(key: "projectName", ascending: true)
        request.sortDescriptors = [sortDescriptor]
        return try context.fetch(request)
    }
    
    // MARK: - Utility Methods
    
    func resetForm() {
        taskName.accept("")
        taskDescription.accept("")
        selectedPriority.accept(.medium)
        selectedProject.accept(nil)
        selectedDueDate.accept(Date())
        isReminderEnabled.accept(false)
        reminderDate.accept(nil)
    }
    
    func updatePriority(_ priority: TaskPriority) {
        selectedPriority.accept(priority)
    }
    
    func updateProject(_ project: Projects?) {
        selectedProject.accept(project)
    }
    
    func updateDueDate(_ date: Date) {
        selectedDueDate.accept(date)
        
        // Update reminder date if it's enabled and would be after due date
        if isReminderEnabled.value, let reminder = reminderDate.value, reminder >= date {
            let newReminderDate = Calendar.current.date(byAdding: .hour, value: -1, to: date)
            reminderDate.accept(newReminderDate)
        }
    }
    
    func toggleReminder() {
        let newValue = !isReminderEnabled.value
        isReminderEnabled.accept(newValue)
        
        if newValue && reminderDate.value == nil {
            let defaultReminder = Calendar.current.date(byAdding: .hour, value: -1, to: selectedDueDate.value)
            reminderDate.accept(defaultReminder)
        }
    }
    
    // MARK: - Validation Errors
    
    enum ValidationError: LocalizedError {
        case invalidForm
        case noTaskToDelete
        case saveFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidForm:
                return "Please fix the form errors before saving"
            case .noTaskToDelete:
                return "No task selected for deletion"
            case .saveFailed:
                return "Failed to save task"
            }
        }
    }
}

// MARK: - Extensions

extension LGAddTaskViewModel {
    
    // MARK: - Form State Helpers
    
    var canSave: Observable<Bool> {
        return Observable.combineLatest(
            isFormValid.asObservable(),
            isLoading.asObservable()
        )
        .map { isValid, isLoading in
            return isValid && !isLoading
        }
    }
    
    var canDelete: Observable<Bool> {
        return Observable.combineLatest(
            isEditMode.asObservable(),
            isLoading.asObservable()
        )
        .map { isEdit, isLoading in
            return isEdit && !isLoading
        }
    }
    
    // MARK: - UI Helper Methods
    
    func priorityDisplayName(for priority: TaskPriority) -> String {
        return priority.displayName
    }
    
    func priorityColor(for priority: TaskPriority) -> UIColor {
        return priority.color
    }
    
    func projectDisplayName(for project: Projects?) -> String {
        return project?.projectName ?? "No Project"
    }
    
    func formattedDueDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: selectedDueDate.value)
    }
    
    func formattedReminderDate() -> String? {
        guard let reminder = reminderDate.value else { return nil }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: reminder)
    }
}
