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
    @Published public private(set) var lifeAreas: [LifeArea] = []
    @Published public private(set) var sections: [TaskerProjectSection] = []
    @Published public private(set) var tags: [TagDefinition] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var isTaskCreated: Bool = false
    @Published public private(set) var validationErrors: [ValidationError] = []
    @Published var aiSuggestion: TaskFieldSuggestion?
    @Published var isGeneratingSuggestion: Bool = false
    
    // Form state — Primary Capture
    @Published public var taskName: String = ""
    @Published public var taskDetails: String = ""
    @Published public var selectedPriority: TaskPriority = .low
    @Published public var selectedType: TaskType = .morning
    @Published public var selectedProject: String = "Inbox"
    @Published public var dueDate: Date? = Date()
    @Published public var hasReminder: Bool = false
    @Published public var reminderTime: Date = Date()

    // Form state — Secondary Details
    @Published public var selectedLifeAreaID: UUID?
    @Published public var selectedSectionID: UUID?
    @Published public var selectedTagIDs: Set<UUID> = []

    // Form state — Advanced Planning
    @Published public var selectedParentTaskID: UUID?
    @Published public var selectedDependencyTaskIDs: Set<UUID> = []
    @Published public var selectedDependencyKind: TaskDependencyKind = .related
    @Published public var selectedEnergy: TaskEnergy = .medium
    @Published public var selectedCategory: TaskCategory = .general
    @Published public var selectedContext: TaskContext = .anywhere
    @Published public var estimatedDuration: TimeInterval? = nil
    @Published public var repeatPattern: TaskRepeatPattern? = nil

    // UI state
    @Published public var showMoreDetails: Bool = false
    @Published public var showAdvancedPlanning: Bool = false
    @Published public private(set) var lastCreatedTaskID: UUID? = nil

    // Read-only loaded data
    @Published public private(set) var availableParentTasks: [TaskDefinition] = []
    @Published public private(set) var availableDependencyTasks: [TaskDefinition] = []

    /// True when the form has any user-entered content (used for discard confirmation)
    public var hasUnsavedChanges: Bool {
        !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || !taskDetails.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || selectedPriority != .low
        || selectedType != .morning
        || selectedProject != "Inbox"
        || hasReminder
        || selectedLifeAreaID != lifeAreas.first?.id
        || selectedTagIDs.isEmpty == false
        || selectedParentTaskID != nil
        || selectedDependencyTaskIDs.isEmpty == false
        || estimatedDuration != nil
        || repeatPattern != nil
    }
    
    // MARK: - Dependencies
    
    private let taskReadModelRepository: TaskReadModelRepositoryProtocol?
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let createTaskDefinitionUseCase: CreateTaskDefinitionUseCase
    private let rescheduleTaskDefinitionUseCase: RescheduleTaskDefinitionUseCase?
    private let manageLifeAreasUseCase: ManageLifeAreasUseCase?
    private let manageSectionsUseCase: ManageSectionsUseCase?
    private let manageTagsUseCase: ManageTagsUseCase?
    private let aiSuggestionService: AISuggestionService?
    private var cancellables = Set<AnyCancellable>()
    private var suggestionTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    /// Initializes a new instance.
    init(
        taskReadModelRepository: TaskReadModelRepositoryProtocol? = nil,
        manageProjectsUseCase: ManageProjectsUseCase,
        createTaskDefinitionUseCase: CreateTaskDefinitionUseCase,
        rescheduleTaskDefinitionUseCase: RescheduleTaskDefinitionUseCase? = nil,
        manageLifeAreasUseCase: ManageLifeAreasUseCase? = nil,
        manageSectionsUseCase: ManageSectionsUseCase? = nil,
        manageTagsUseCase: ManageTagsUseCase? = nil,
        aiSuggestionService: AISuggestionService? = nil
    ) {
        self.taskReadModelRepository = taskReadModelRepository
        self.manageProjectsUseCase = manageProjectsUseCase
        self.createTaskDefinitionUseCase = createTaskDefinitionUseCase
        self.rescheduleTaskDefinitionUseCase = rescheduleTaskDefinitionUseCase
        self.manageLifeAreasUseCase = manageLifeAreasUseCase
        self.manageSectionsUseCase = manageSectionsUseCase
        self.manageTagsUseCase = manageTagsUseCase
        self.aiSuggestionService = aiSuggestionService

        setupValidation()
        setupAISuggestionPipeline()
        loadProjects()
        loadLifeAreas()
        loadTags()
    }

    deinit {
        suggestionTask?.cancel()
    }
    
    // MARK: - Public Methods
    
    /// Create a new task
    public func createTask() {
        guard validateInput() else {
            return
        }

        isLoading = true
        errorMessage = nil
        
        // Resolve projectID from selectedProject name
        let projectID = projects.first(where: { $0.name == selectedProject })?.id ?? ProjectConstants.inboxProjectID

        let resolvedTagIDs = selectedTagIDs.isEmpty ? parseImplicitTagIDs(from: taskName) : selectedTagIDs
        let requestID = UUID()
        let definitionRequest = CreateTaskDefinitionRequest(
            id: requestID,
            title: taskName,
            details: taskDetails.isEmpty ? nil : taskDetails,
            projectID: projectID,
            projectName: selectedProject,
            lifeAreaID: selectedLifeAreaID,
            sectionID: selectedSectionID,
            dueDate: dueDate,
            parentTaskID: selectedParentTaskID,
            tagIDs: Array(resolvedTagIDs),
            dependencies: selectedDependencyTaskIDs.map { dependsOnTaskID in
                TaskDependencyLinkDefinition(
                    taskID: requestID,
                    dependsOnTaskID: dependsOnTaskID,
                    kind: selectedDependencyKind
                )
            },
            priority: selectedPriority,
            type: selectedType,
            energy: selectedEnergy,
            category: selectedCategory,
            context: selectedContext,
            isEveningTask: selectedType == .evening,
            alertReminderTime: hasReminder ? reminderTime : nil,
            estimatedDuration: estimatedDuration,
            repeatPattern: repeatPattern
        )

        createTaskDefinitionUseCase.execute(
            request: definitionRequest
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false

                switch result {
                case .success:
                    self?.lastCreatedTaskID = requestID
                    self?.isTaskCreated = true
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes parseImplicitTagIDs.
    private func parseImplicitTagIDs(from title: String) -> Set<UUID> {
        let tokens = title
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { $0.hasPrefix("#") && $0.count > 1 }
            .map { String($0.dropFirst()).lowercased() }
        guard tokens.isEmpty == false else { return [] }
        let tokenSet = Set(tokens)
        return Set(tags.compactMap { tag in
            tokenSet.contains(tag.name.lowercased()) ? tag.id : nil
        })
    }
    
    /// Load available projects
    public func loadProjects() {
        manageProjectsUseCase.getAllProjects { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let projectsWithStats):
                    let mappedProjects = projectsWithStats.map { $0.project }
                    let dedupedProjects = self?.dedupeProjects(mappedProjects) ?? mappedProjects
                    if dedupedProjects.count != mappedProjects.count {
                        logWarning(
                            event: "add_task_projects_deduped",
                            message: "Duplicate project IDs detected in AddTaskViewModel; using deduped project list",
                            fields: [
                                "before_count": String(mappedProjects.count),
                                "after_count": String(dedupedProjects.count)
                            ]
                        )
                    }
                    self?.projects = dedupedProjects
                    if self?.selectedProject == "Inbox",
                       let inbox = self?.projects.first(where: { $0.id == ProjectConstants.inboxProjectID }) {
                        self?.selectedProject = inbox.name
                    }
                    if let strongSelf = self,
                       let selectedProjectID = strongSelf.projects.first(where: { $0.name == strongSelf.selectedProject })?.id {
                        strongSelf.loadSections(projectID: selectedProjectID)
                        strongSelf.loadTaskMetadataOptions(projectID: selectedProjectID)
                    } else {
                        self?.availableParentTasks = []
                        self?.availableDependencyTasks = []
                        self?.selectedParentTaskID = nil
                        self?.selectedDependencyTaskIDs = []
                    }
                    
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

    /// Create a tag inline from Add Task and select it on success.
    public func createTag(name: String, completion: @escaping (Bool) -> Void) {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else {
            completion(false)
            return
        }
        guard let manageTagsUseCase else {
            completion(false)
            return
        }

        manageTagsUseCase.create(name: normalized, color: nil, icon: nil) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let createdTag):
                    guard let self else {
                        completion(false)
                        return
                    }
                    if let existingIndex = self.tags.firstIndex(where: { $0.id == createdTag.id }) {
                        self.tags[existingIndex] = createdTag
                    } else {
                        self.tags.append(createdTag)
                    }
                    self.tags.sort {
                        if $0.sortOrder != $1.sortOrder {
                            return $0.sortOrder < $1.sortOrder
                        }
                        return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                    }
                    self.selectedTagIDs.insert(createdTag.id)
                    completion(true)
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                    completion(false)
                }
            }
        }
    }
    
    /// Reschedule task (for editing existing tasks)
    public func rescheduleTask(_ taskId: UUID, to newDate: Date) {
        guard let rescheduleTaskDefinitionUseCase else {
            errorMessage = "Task rescheduling is not configured."
            return
        }

        isLoading = true

        rescheduleTaskDefinitionUseCase.execute(taskID: taskId, newDate: newDate) { [weak self] result in
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
        if aiSuggestion != nil {
            logWarning(
                event: "assistant_suggestion_dismissed",
                message: "Add-task suggestion dismissed during form reset",
                fields: ["reason": "form_reset"]
            )
        }
        suggestionTask?.cancel()
        taskName = ""
        taskDetails = ""
        selectedPriority = .low
        selectedType = .morning
        selectedProject = "Inbox"
        selectedLifeAreaID = lifeAreas.first?.id
        selectedSectionID = nil
        selectedTagIDs = []
        selectedParentTaskID = nil
        selectedDependencyTaskIDs = []
        selectedDependencyKind = .related
        selectedEnergy = .medium
        selectedCategory = .general
        selectedContext = .anywhere
        estimatedDuration = nil
        repeatPattern = nil
        dueDate = Date()
        hasReminder = false
        reminderTime = Date()
        showMoreDetails = false
        showAdvancedPlanning = false
        validationErrors = []
        errorMessage = nil
        isTaskCreated = false
        aiSuggestion = nil
        isGeneratingSuggestion = false
    }

    /// Executes applyAISuggestion.
    func applyAISuggestion(_ suggestion: TaskFieldSuggestion) {
        selectedPriority = suggestion.priority
        selectedEnergy = suggestion.energy
        selectedType = suggestion.type
        selectedContext = suggestion.context
        logWarning(
            event: "assistant_suggestion_accepted",
            message: "Add-task suggestion accepted",
            fields: [
                "priority": String(suggestion.priority.rawValue),
                "energy": suggestion.energy.rawValue,
                "context": suggestion.context.rawValue,
                "type": String(suggestion.type.rawValue),
                "model": suggestion.modelName ?? "none"
            ]
        )
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
        
        // Validate due date (nil is valid — "Someday")
        if let dueDate, dueDate < Calendar.current.startOfDay(for: Date()) {
            validationErrors.append(.pastDueDate)
        }
        
        // Validate reminder time
        if hasReminder && reminderTime < Date() {
            validationErrors.append(.pastReminderTime)
        }
        
        return validationErrors.isEmpty
    }
    
    // MARK: - Private Methods
    
    /// Executes setupValidation.
    private func setupValidation() {
        // Validate input whenever relevant fields change
        Publishers.CombineLatest4($taskName, $dueDate, $hasReminder, $reminderTime)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.validateInput()
            }
            .store(in: &cancellables)

        $selectedProject
            .removeDuplicates()
            .sink { [weak self] projectName in
                guard let self else { return }
                guard let projectID = self.projects.first(where: { $0.name == projectName })?.id else {
                    self.sections = []
                    self.selectedSectionID = nil
                    self.availableParentTasks = []
                    self.availableDependencyTasks = []
                    self.selectedParentTaskID = nil
                    self.selectedDependencyTaskIDs = []
                    return
                }
                self.loadSections(projectID: projectID)
                self.loadTaskMetadataOptions(projectID: projectID)
            }
            .store(in: &cancellables)

        $selectedParentTaskID
            .removeDuplicates { $0 == $1 }
            .sink { [weak self] selectedParentTaskID in
                guard let selectedParentTaskID else { return }
                self?.selectedDependencyTaskIDs.remove(selectedParentTaskID)
            }
            .store(in: &cancellables)
    }

    /// Executes setupAISuggestionPipeline.
    private func setupAISuggestionPipeline() {
        guard V2FeatureFlags.assistantCopilotEnabled, aiSuggestionService != nil else {
            aiSuggestion = nil
            isGeneratingSuggestion = false
            return
        }
        $taskName
            .debounce(for: .milliseconds(800), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] taskName in
                self?.requestAISuggestionIfNeeded(for: taskName)
            }
            .store(in: &cancellables)
    }

    /// Executes requestAISuggestionIfNeeded.
    private func requestAISuggestionIfNeeded(for taskName: String) {
        guard V2FeatureFlags.assistantCopilotEnabled, let aiSuggestionService else {
            aiSuggestion = nil
            isGeneratingSuggestion = false
            return
        }
        suggestionTask?.cancel()
        let normalized = taskName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > 5 else {
            if aiSuggestion != nil {
                logWarning(
                    event: "assistant_suggestion_dismissed",
                    message: "Add-task suggestion dismissed after input change",
                    fields: ["reason": "input_short"]
                )
            }
            aiSuggestion = nil
            isGeneratingSuggestion = false
            return
        }

        let titleAtRequestStart = normalized
        isGeneratingSuggestion = true
        suggestionTask = Task { [weak self] in
            guard let self else { return }
            let suggestion = await aiSuggestionService.suggestFields(
                for: titleAtRequestStart,
                projectName: self.selectedProject
            )
            guard Task.isCancelled == false else { return }

            await MainActor.run {
                guard self.taskName.trimmingCharacters(in: .whitespacesAndNewlines) == titleAtRequestStart else {
                    self.isGeneratingSuggestion = false
                    return
                }
                self.aiSuggestion = suggestion
                self.isGeneratingSuggestion = false
                if let suggestion {
                    logWarning(
                        event: "assistant_suggestion_shown",
                        message: "Add-task suggestion shown",
                        fields: [
                            "confidence": String(format: "%.2f", suggestion.confidence),
                            "priority": String(suggestion.priority.rawValue),
                            "energy": suggestion.energy.rawValue,
                            "context": suggestion.context.rawValue,
                            "type": String(suggestion.type.rawValue),
                            "model": suggestion.modelName ?? "none",
                            "has_route_banner": suggestion.routeBanner == nil ? "false" : "true"
                        ]
                    )
                }
            }
        }
    }

    /// Executes dedupeProjects.
    private func dedupeProjects(_ projects: [Project]) -> [Project] {
        var byID: [UUID: Project] = [:]
        for project in projects {
            if let existing = byID[project.id] {
                let keepIncoming =
                    (project.isDefault && !existing.isDefault) ||
                    (project.isInbox && !existing.isInbox)
                if keepIncoming {
                    byID[project.id] = project
                }
            } else {
                byID[project.id] = project
            }
        }
        return Array(byID.values).sorted { lhs, rhs in
            if lhs.isDefault != rhs.isDefault {
                return lhs.isDefault
            }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
    }

    /// Executes loadLifeAreas.
    private func loadLifeAreas() {
        manageLifeAreasUseCase?.list { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let areas):
                    guard let self else { return }
                    let activeAreas = areas.filter { !$0.isArchived }
                    let dedupedAreas = self.dedupeLifeAreasByNormalizedName(
                        activeAreas,
                        preferredID: self.selectedLifeAreaID
                    )
                    if dedupedAreas.count != activeAreas.count {
                        logWarning(
                            event: "add_task_life_areas_deduped",
                            message: "Duplicate life-area names detected in AddTaskViewModel; using deduped life-area list",
                            fields: [
                                "before_count": String(activeAreas.count),
                                "after_count": String(dedupedAreas.count)
                            ]
                        )
                    }
                    self.lifeAreas = dedupedAreas
                    if let selectedLifeAreaID = self.selectedLifeAreaID,
                       dedupedAreas.contains(where: { $0.id == selectedLifeAreaID }) {
                        // Keep existing selection when the selected life-area survives dedupe.
                    } else {
                        self.selectedLifeAreaID = dedupedAreas.first?.id
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes dedupeLifeAreasByNormalizedName.
    private func dedupeLifeAreasByNormalizedName(
        _ lifeAreas: [LifeArea],
        preferredID: UUID?
    ) -> [LifeArea] {
        var chosenByName: [String: LifeArea] = [:]

        for lifeArea in lifeAreas {
            let normalizedName = normalizedLifeAreaName(lifeArea.name)
            guard let existing = chosenByName[normalizedName] else {
                chosenByName[normalizedName] = lifeArea
                continue
            }

            if existing.id == preferredID {
                continue
            }
            if lifeArea.id == preferredID {
                chosenByName[normalizedName] = lifeArea
            }
        }

        var emitted = Set<String>()
        var deduped: [LifeArea] = []
        for lifeArea in lifeAreas {
            let normalizedName = normalizedLifeAreaName(lifeArea.name)
            guard chosenByName[normalizedName]?.id == lifeArea.id else { continue }
            guard emitted.insert(normalizedName).inserted else { continue }
            deduped.append(lifeArea)
        }
        return deduped
    }

    /// Executes normalizedLifeAreaName.
    private func normalizedLifeAreaName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmed.isEmpty ? "General" : trimmed).lowercased()
    }

    /// Executes loadSections.
    private func loadSections(projectID: UUID) {
        manageSectionsUseCase?.list(projectID: projectID) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let sections):
                    self?.sections = sections.sorted(by: { $0.sortOrder < $1.sortOrder })
                    if let selected = self?.selectedSectionID,
                       sections.contains(where: { $0.id == selected }) == false {
                        self?.selectedSectionID = nil
                    }
                    if self?.selectedSectionID == nil {
                        self?.selectedSectionID = self?.sections.first?.id
                    }
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes loadTags.
    private func loadTags() {
        manageTagsUseCase?.list { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let tags):
                    self?.tags = tags.sorted(by: { $0.sortOrder < $1.sortOrder })
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }

    /// Executes loadTaskMetadataOptions.
    private func loadTaskMetadataOptions(projectID: UUID) {
        guard let taskReadModelRepository else {
            availableParentTasks = []
            availableDependencyTasks = []
            selectedParentTaskID = nil
            selectedDependencyTaskIDs = []
            return
        }

        taskReadModelRepository.fetchTasks(
            query: TaskReadQuery(
                projectID: projectID,
                includeCompleted: false,
                sortBy: .dueDateAscending,
                limit: 2_000,
                offset: 0
            )
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let slice):
                    let activeTasks = slice.tasks
                        .filter { !$0.isComplete }
                        .sorted(by: { (lhs: TaskDefinition, rhs: TaskDefinition) in
                            let lhsDate = lhs.dueDate ?? Date.distantFuture
                            let rhsDate = rhs.dueDate ?? Date.distantFuture
                            if lhsDate == rhsDate {
                                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                            }
                            return lhsDate < rhsDate
                        })
                    self.availableParentTasks = activeTasks
                    self.availableDependencyTasks = activeTasks

                    let validIDs = Set(activeTasks.map(\.id))
                    if let selectedParentTaskID = self.selectedParentTaskID, !validIDs.contains(selectedParentTaskID) {
                        self.selectedParentTaskID = nil
                    }
                    self.selectedDependencyTaskIDs = self.selectedDependencyTaskIDs.intersection(validIDs)
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                    self.availableParentTasks = []
                    self.availableDependencyTasks = []
                    self.selectedParentTaskID = nil
                    self.selectedDependencyTaskIDs = []
                }
            }
        }
    }

    /// Executes loadCalendarTaskCounts.
    public func loadCalendarTaskCounts(
        windowStart: Date,
        windowEnd: Date,
        completion: @escaping ([Date: Int]) -> Void
    ) {
        guard let taskReadModelRepository else {
            completion([:])
            return
        }

        taskReadModelRepository.fetchTasks(
            query: TaskReadQuery(
                includeCompleted: true,
                dueDateStart: windowStart,
                dueDateEnd: windowEnd,
                sortBy: .dueDateAscending,
                limit: 5_000,
                offset: 0
            )
        ) { result in
            let tasks = (try? result.get().tasks) ?? []
            let calendar = Calendar.current
            let counts = tasks.reduce(into: [Date: Int]()) { grouped, task in
                guard let dueDate = task.dueDate else { return }
                grouped[calendar.startOfDay(for: dueDate), default: 0] += 1
            }
            DispatchQueue.main.async {
                completion(counts)
            }
        }
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
            lifeAreas: lifeAreas,
            sections: sections,
            tags: tags,
            canSubmit: validationErrors.isEmpty && !taskName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
    public let lifeAreas: [LifeArea]
    public let sections: [TaskerProjectSection]
    public let tags: [TagDefinition]
    public let canSubmit: Bool
}
