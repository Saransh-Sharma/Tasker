//
//  AddTaskViewModel.swift
//  Tasker
//
//  ViewModel for Add Task screen - manages task creation workflow
//

import Foundation
import Combine

/// ViewModel for the Add Task screen
/// Manages task creation state and validation
public final class AddTaskViewModel: ObservableObject {
    
    // MARK: - Published Properties (Observable State)
    
    @Published public private(set) var projects: [Project] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isTaskCreated: Bool = false
    @Published public private(set) var validationErrors: [ValidationError] = []
    
    // Form state
    @Published public var taskName: String = ""
    @Published public var taskDetails: String = ""
    @Published public var selectedPriority: TaskPriority = .low
    @Published public var selectedType: TaskType = .morning
    @Published public var selectedProject: String = "Inbox"
    @Published public var dueDate: Date = Date()
    @Published public var hasReminder: Bool = false
    @Published public var reminderTime: Date = Date()
    
    // MARK: - Dependencies
    
    private let createTaskUseCase: CreateTaskUseCase
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let rescheduleTaskUseCase: RescheduleTaskUseCase
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        createTaskUseCase: CreateTaskUseCase,
        manageProjectsUseCase: ManageProjectsUseCase,
        rescheduleTaskUseCase: RescheduleTaskUseCase
    ) {
        self.createTaskUseCase = createTaskUseCase
        self.manageProjectsUseCase = manageProjectsUseCase
        self.rescheduleTaskUseCase = rescheduleTaskUseCase
        
        setupValidation()
        loadProjects()
    }
    
    // MARK: - Public Methods
    
    /// Create a new task
    public func createTask() {
        guard validateInput() else {
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let request = CreateTaskRequest(
            name: taskName,
            details: taskDetails.isEmpty ? nil : taskDetails,
            type: selectedType,
            priority: selectedPriority,
            dueDate: dueDate,
            projectID: nil, // TODO: Convert selectedProject name to UUID
            project: selectedProject,
            alertReminderTime: hasReminder ? reminderTime : nil
        )
        
        createTaskUseCase.execute(request: request) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    self?.isTaskCreated = true
                    self?.resetForm()
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Load available projects
    public func loadProjects() {
        manageProjectsUseCase.getAllProjects { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let projectsWithStats):
                    self?.projects = projectsWithStats.map { $0.project }
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Create a new project
    public func createProject(name: String) {
        let request = CreateProjectRequest(name: name)
        
        manageProjectsUseCase.createProject(request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.selectedProject = name
                    self?.loadProjects()
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Reschedule task (for editing existing tasks)
    public func rescheduleTask(_ taskId: UUID, to newDate: Date) {
        isLoading = true
        
        rescheduleTaskUseCase.execute(taskId: taskId, newDate: newDate) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    // Task rescheduled successfully
                    break
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Reset form to initial state
    public func resetForm() {
        taskName = ""
        taskDetails = ""
        selectedPriority = .low
        selectedType = .morning
        selectedProject = "Inbox"
        dueDate = Date()
        hasReminder = false
        reminderTime = Date()
        validationErrors = []
        isTaskCreated = false
    }
    
    /// Validate input and update validation errors
    @discardableResult
    public func validateInput() -> Bool {
        validationErrors = []
        
        // Validate task name
        if taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors.append(.emptyTaskName)
        } else if taskName.count > 200 {
            validationErrors.append(.taskNameTooLong)
        }
        
        // Validate due date
        if dueDate < Calendar.current.startOfDay(for: Date()) {
            validationErrors.append(.pastDueDate)
        }
        
        // Validate reminder time
        if hasReminder && reminderTime < Date() {
            validationErrors.append(.pastReminderTime)
        }
        
        return validationErrors.isEmpty
    }
    
    // MARK: - Private Methods
    
    private func setupValidation() {
        // Validate input whenever relevant fields change
        Publishers.CombineLatest4($taskName, $dueDate, $hasReminder, $reminderTime)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.validateInput()
            }
            .store(in: &cancellables)
    }
}

// MARK: - Validation Errors

public enum ValidationError: LocalizedError {
    case emptyTaskName
    case taskNameTooLong
    case pastDueDate
    case pastReminderTime
    
    public var errorDescription: String? {
        switch self {
        case .emptyTaskName:
            return "Task name cannot be empty"
        case .taskNameTooLong:
            return "Task name is too long (max 200 characters)"
        case .pastDueDate:
            return "Due date cannot be in the past"
        case .pastReminderTime:
            return "Reminder time cannot be in the past"
        }
    }
}

// MARK: - View State

extension AddTaskViewModel {
    
    /// Combined state for the view
    public var viewState: AddTaskViewState {
        return AddTaskViewState(
            isLoading: isLoading,
            errorMessage: errorMessage,
            isTaskCreated: isTaskCreated,
            validationErrors: validationErrors,
            projects: projects,
            canSubmit: validationErrors.isEmpty && !taskName.isEmpty
        )
    }
}

/// State structure for the add task view
public struct AddTaskViewState {
    public let isLoading: Bool
    public let errorMessage: String?
    public let isTaskCreated: Bool
    public let validationErrors: [ValidationError]
    public let projects: [Project]
    public let canSubmit: Bool
}