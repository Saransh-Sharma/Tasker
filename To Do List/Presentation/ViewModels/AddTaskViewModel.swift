//
//  AddTaskViewModel.swift
//  Tasker
//
//  ViewModel for Add Task screen - manages task creation logic
//

import Foundation
import Combine

/// ViewModel for the Add Task screen
/// Manages task creation and validation
public final class AddTaskViewModel: ObservableObject {
    
    // MARK: - Published Properties (Form State)
    
    @Published public var taskName: String = ""
    @Published public var taskDetails: String = ""
    @Published public var selectedType: TaskType = .morning
    @Published public var selectedPriority: TaskPriority = .medium
    @Published public var selectedDate: Date = Date()
    @Published public var selectedProject: String = "Inbox"
    @Published public var reminderEnabled: Bool = false
    @Published public var reminderTime: Date = Date()
    
    // UI State
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var validationErrors: [ValidationError] = []
    @Published public private(set) var projects: [Project] = []
    @Published public private(set) var suggestedDates: [RescheduleSuggestion] = []
    
    // MARK: - Dependencies
    
    private let createTaskUseCase: CreateTaskUseCase
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let rescheduleTaskUseCase: RescheduleTaskUseCase
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Check if the form is valid
    public var isFormValid: Bool {
        return !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               taskName.count <= 200 &&
               (taskDetails.isEmpty || taskDetails.count <= 1000)
    }
    
    /// Get validation message
    public var validationMessage: String? {
        if taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Task name is required"
        }
        if taskName.count > 200 {
            return "Task name must be less than 200 characters"
        }
        if taskDetails.count > 1000 {
            return "Task details must be less than 1000 characters"
        }
        return nil
    }
    
    // MARK: - Initialization
    
    public init(
        createTaskUseCase: CreateTaskUseCase,
        manageProjectsUseCase: ManageProjectsUseCase,
        rescheduleTaskUseCase: RescheduleTaskUseCase
    ) {
        self.createTaskUseCase = createTaskUseCase
        self.manageProjectsUseCase = manageProjectsUseCase
        self.rescheduleTaskUseCase = rescheduleTaskUseCase
        
        setupBindings()
        loadProjects()
        setupDateSuggestions()
    }
    
    // MARK: - Public Methods
    
    /// Create the task with current form values
    public func createTask(completion: @escaping (Result<Task, Error>) -> Void) {
        guard isFormValid else {
            errorMessage = validationMessage
            completion(.failure(AddTaskError.validationFailed(validationMessage ?? "Invalid form")))
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let request = CreateTaskRequest(
            name: taskName.trimmingCharacters(in: .whitespacesAndNewlines),
            details: taskDetails.isEmpty ? nil : taskDetails,
            type: selectedType,
            priority: selectedPriority,
            dueDate: selectedDate,
            projectName: selectedProject == "Inbox" ? nil : selectedProject,
            reminderTime: reminderEnabled ? reminderTime : nil
        )
        
        createTaskUseCase.execute(request: request) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let task):
                    self?.resetForm()
                    completion(.success(task))
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(.failure(error))
                }
            }
        }
    }
    
    /// Reset form to default values
    public func resetForm() {
        taskName = ""
        taskDetails = ""
        selectedType = .morning
        selectedPriority = .medium
        selectedDate = Date()
        selectedProject = "Inbox"
        reminderEnabled = false
        reminderTime = Date()
        errorMessage = nil
        validationErrors = []
    }
    
    /// Validate the current form
    public func validateForm() {
        validationErrors.removeAll()
        
        if taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            validationErrors.append(.emptyName)
        }
        
        if taskName.count > 200 {
            validationErrors.append(.nameTooLong)
        }
        
        if taskDetails.count > 1000 {
            validationErrors.append(.detailsTooLong)
        }
        
        if selectedDate < Calendar.current.startOfDay(for: Date()) {
            validationErrors.append(.pastDate)
        }
    }
    
    /// Update task type based on selected time
    public func updateTaskTypeFromTime() {
        let hour = Calendar.current.component(.hour, from: selectedDate)
        
        if hour < 12 {
            selectedType = .morning
        } else if hour < 18 {
            selectedType = .evening
        } else {
            selectedType = .evening
        }
        
        // If date is more than 7 days away, mark as upcoming
        let daysUntil = Calendar.current.dateComponents([.day], from: Date(), to: selectedDate).day ?? 0
        if daysUntil > 7 {
            selectedType = .upcoming
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
                    print("Failed to load projects: \(error)")
                    // Still allow task creation with default Inbox
                    self?.projects = [Project.createInbox()]
                }
            }
        }
    }
    
    /// Create a quick task with minimal input
    public func createQuickTask(name: String, completion: @escaping (Result<Task, Error>) -> Void) {
        let request = CreateTaskRequest(
            name: name,
            type: determineQuickTaskType(),
            priority: .medium,
            dueDate: Date(),
            projectName: "Inbox"
        )
        
        createTaskUseCase.execute(request: request) { result in
            DispatchQueue.main.async {
                completion(result.mapError { $0 as Error })
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Auto-update task type when date changes
        $selectedDate
            .sink { [weak self] _ in
                self?.updateTaskTypeFromTime()
            }
            .store(in: &cancellables)
        
        // Validate form on text changes
        $taskName
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.validateForm()
            }
            .store(in: &cancellables)
        
        $taskDetails
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.validateForm()
            }
            .store(in: &cancellables)
    }
    
    private func setupDateSuggestions() {
        // Generate smart date suggestions
        suggestedDates = [
            RescheduleSuggestion(
                date: Date(),
                reason: "Today",
                taskLoad: .medium
            ),
            RescheduleSuggestion(
                date: Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date(),
                reason: "Tomorrow",
                taskLoad: .low
            ),
            RescheduleSuggestion(
                date: getNextMonday(),
                reason: "Next Monday",
                taskLoad: .low
            )
        ]
    }
    
    private func determineQuickTaskType() -> TaskType {
        let hour = Calendar.current.component(.hour, from: Date())
        
        if hour < 12 {
            return .morning
        } else if hour < 18 {
            return .evening
        } else {
            return .evening
        }
    }
    
    private func getNextMonday() -> Date {
        let calendar = Calendar.current
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        
        // Calculate days until Monday (weekday 2)
        let daysUntilMonday = (9 - weekday) % 7
        let nextMonday = calendar.date(byAdding: .day, value: daysUntilMonday == 0 ? 7 : daysUntilMonday, to: today)
        
        return nextMonday ?? today
    }
}

// MARK: - Validation Errors

public enum ValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case detailsTooLong
    case pastDate
    case invalidProject
    
    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Task name cannot be empty"
        case .nameTooLong:
            return "Task name is too long (max 200 characters)"
        case .detailsTooLong:
            return "Task details are too long (max 1000 characters)"
        case .pastDate:
            return "Cannot create task in the past"
        case .invalidProject:
            return "Selected project does not exist"
        }
    }
}

// MARK: - Errors

public enum AddTaskError: LocalizedError {
    case validationFailed(String)
    case creationFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .validationFailed(let message):
            return "Validation failed: \(message)"
        case .creationFailed(let message):
            return "Failed to create task: \(message)"
        }
    }
}
