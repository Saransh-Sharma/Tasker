//
//  ProjectManagementViewModel.swift
//  Tasker
//
//  ViewModel for Project Management screen - manages project operations
//

import Foundation
import Combine

/// ViewModel for the Project Management screen
/// Manages project CRUD operations and statistics
public final class ProjectManagementViewModel: ObservableObject {
    
    // MARK: - Published Properties (Observable State)
    
    @Published public private(set) var projects: [ProjectWithStats] = []
    @Published public private(set) var filteredProjects: [ProjectWithStats] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public private(set) var selectedProject: ProjectWithStats?
    @Published public private(set) var selectedProjectTasks: [TaskDefinition] = []
    @Published public private(set) var weeklyContributionStats: ProjectWeeklyContributionStats = ProjectWeeklyContributionStats()
    @Published public private(set) var recentReflectionNotes: [ReflectionNote] = []
    @Published public private(set) var isSavingMotivation: Bool = false
    @Published public private(set) var isUpdatingTaskBuckets: Bool = false
    @Published public private(set) var saveMessage: String?

    // Filter and search state
    @Published public var searchText: String = ""
    @Published public var filterType: ProjectFilterType = .all
    @Published public var sortOption: ProjectSortOption = .name
    @Published public var selectedTaskIDs: Set<UUID> = []
    @Published public var motivationWhyDraft: String = ""
    @Published public var motivationSuccessLooksLikeDraft: String = ""
    @Published public var motivationCostOfNeglectDraft: String = ""
    
    // UI state
    @Published public private(set) var showingCreateProject: Bool = false
    @Published public private(set) var showingDeleteConfirmation: Bool = false
    @Published public private(set) var projectToDelete: ProjectWithStats?
    
    // MARK: - Dependencies
    
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let getTasksUseCase: GetTasksUseCase
    private let buildWeeklyPlanSnapshotUseCase: BuildWeeklyPlanSnapshotUseCase
    private let updateTaskDefinitionUseCase: UpdateTaskDefinitionUseCase
    private let reflectionNoteRepository: ReflectionNoteRepositoryProtocol
    private let gamificationEngine: GamificationEngine?
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    /// Initializes a new instance.
    public init(
        manageProjectsUseCase: ManageProjectsUseCase,
        getTasksUseCase: GetTasksUseCase,
        buildWeeklyPlanSnapshotUseCase: BuildWeeklyPlanSnapshotUseCase,
        updateTaskDefinitionUseCase: UpdateTaskDefinitionUseCase,
        reflectionNoteRepository: ReflectionNoteRepositoryProtocol,
        gamificationEngine: GamificationEngine? = nil
    ) {
        self.manageProjectsUseCase = manageProjectsUseCase
        self.getTasksUseCase = getTasksUseCase
        self.buildWeeklyPlanSnapshotUseCase = buildWeeklyPlanSnapshotUseCase
        self.updateTaskDefinitionUseCase = updateTaskDefinitionUseCase
        self.reflectionNoteRepository = reflectionNoteRepository
        self.gamificationEngine = gamificationEngine
        
        setupFilteringAndSorting()
        loadProjects()
    }
    
    // MARK: - Public Methods
    
    /// Load all projects with statistics
    public func loadProjects() {
        isLoading = true
        errorMessage = nil
        
        manageProjectsUseCase.getAllProjects { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let projectsWithStats):
                    self?.projects = projectsWithStats
                    self?.applyFiltersAndSorting()
                    self?.refreshSelectedProjectFromLatestList()
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Create a new project
    public func createProject(name: String, description: String? = nil) {
        isLoading = true

        let request = CreateProjectRequest(
            name: name,
            description: description
        )

        manageProjectsUseCase.createProject(request: request) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    self?.loadProjects()
                    self?.showingCreateProject = false
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Update project
    public func updateProject(
        _ project: Project,
        name: String? = nil,
        description: String? = nil,
        motivationWhy: String? = nil,
        motivationSuccessLooksLike: String? = nil,
        motivationCostOfNeglect: String? = nil
    ) {
        isLoading = true

        let request = UpdateProjectRequest(
            name: name,
            description: description,
            motivationWhy: motivationWhy,
            motivationSuccessLooksLike: motivationSuccessLooksLike,
            motivationCostOfNeglect: motivationCostOfNeglect
        )

        manageProjectsUseCase.updateProject(projectId: project.id, request: request) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    self?.loadProjects()
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Delete project
    public func deleteProject(_ project: ProjectWithStats, strategy: DeleteStrategy = .moveToInbox) {
        isLoading = true

        manageProjectsUseCase.deleteProject(
            projectId: project.project.id,
            deleteStrategy: strategy
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    self?.loadProjects()
                    self?.showingDeleteConfirmation = false
                    self?.projectToDelete = nil
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Archive project
    public func archiveProject(_ project: Project) {
        // TODO: Implement proper archive functionality when status field is added to repository
        updateProject(project, name: nil, description: nil)
    }
    
    /// Select project for detailed view
    public func selectProject(_ project: ProjectWithStats) {
        selectedProject = project
        hydrateMotivationDrafts(from: project.project)
        loadSelectedProjectDetails(projectID: project.project.id)
    }
    
    /// Show create project dialog
    public func showCreateProject() {
        showingCreateProject = true
    }
    
    /// Hide create project dialog
    public func hideCreateProject() {
        showingCreateProject = false
    }
    
    /// Show delete confirmation for project
    public func showDeleteConfirmation(for project: ProjectWithStats) {
        projectToDelete = project
        showingDeleteConfirmation = true
    }
    
    /// Hide delete confirmation
    public func hideDeleteConfirmation() {
        showingDeleteConfirmation = false
        projectToDelete = nil
    }
    
    /// Get tasks for specific project
    public func loadTasksForProject(_ project: Project, completion: @escaping ([TaskDefinition]) -> Void) {
        getTasksUseCase.getTasksForProject(project.id) { result in
            switch result {
            case .success(let projectResult):
                completion(projectResult.tasks)
            case .failure:
                completion([])
            }
        }
    }

    public var hasSelectedTasks: Bool {
        selectedTaskIDs.isEmpty == false
    }

    public var selectedTaskCount: Int {
        selectedTaskIDs.count
    }

    public func clearSelection() {
        selectedTaskIDs.removeAll()
    }

    public func clearError() {
        errorMessage = nil
    }

    public func toggleTaskSelection(_ taskID: UUID) {
        if selectedTaskIDs.contains(taskID) {
            selectedTaskIDs.remove(taskID)
        } else {
            selectedTaskIDs.insert(taskID)
        }
    }

    public func saveMotivation() {
        guard let selectedProject else { return }

        isSavingMotivation = true
        saveMessage = nil
        errorMessage = nil

        let normalizedWhy = normalizedDraftText(motivationWhyDraft)
        let normalizedSuccess = normalizedDraftText(motivationSuccessLooksLikeDraft)
        let normalizedCost = normalizedDraftText(motivationCostOfNeglectDraft)

        manageProjectsUseCase.updateProject(
            projectId: selectedProject.project.id,
            request: UpdateProjectRequest(
                motivationWhy: normalizedWhy,
                motivationSuccessLooksLike: normalizedSuccess,
                motivationCostOfNeglect: normalizedCost
            )
        ) { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSavingMotivation = false
                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                case .success(let updatedProject):
                    self.saveMessage = "Motivation saved"
                    self.applyUpdatedProject(updatedProject)
                }
            }
        }
    }

    public func applyQuickAction(bucket: TaskPlanningBucket) {
        let targetTasks: [TaskDefinition]
        if selectedTaskIDs.isEmpty {
            targetTasks = selectedProjectTasks.filter { !$0.isComplete }
        } else {
            targetTasks = selectedProjectTasks.filter { selectedTaskIDs.contains($0.id) }
        }
        updateTasks(targetTasks, to: bucket)
    }

    public func saveReflectionNote(_ note: ReflectionNote, completion: @escaping (Result<ReflectionNote, Error>) -> Void) {
        reflectionNoteRepository.saveNote(note) { [weak self] result in
            DispatchQueue.main.async {
                if case .success(let saved) = result {
                    self?.recentReflectionNotes.insert(saved, at: 0)
                    self?.recentReflectionNotes = Array(self?.recentReflectionNotes.prefix(6) ?? [])
                    self?.saveMessage = "Reflection saved"
                    self?.awardReflectionCaptureXP(linkedTaskID: saved.linkedTaskID, linkedHabitID: saved.linkedHabitID)
                } else if case .failure(let error) = result {
                    self?.errorMessage = error.localizedDescription
                }
                completion(result)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /// Executes setupFilteringAndSorting.
    private func setupFilteringAndSorting() {
        // Apply filters and sorting whenever search or filter criteria change
        Publishers.CombineLatest3($searchText, $filterType, $sortOption)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyFiltersAndSorting()
            }
            .store(in: &cancellables)
    }

    private func awardReflectionCaptureXP(linkedTaskID: UUID?, linkedHabitID: UUID?) {
        guard let gamificationEngine else { return }
        gamificationEngine.recordEvent(
            context: XPEventContext(
                category: .reflectionCapture,
                source: .manual,
                taskID: linkedTaskID,
                habitID: linkedHabitID,
                completedAt: Date()
            )
        ) { _ in }
    }
    
    /// Executes applyFiltersAndSorting.
    private func applyFiltersAndSorting() {
        var filtered = projects
        
        // Apply text search
        if !searchText.isEmpty {
            filtered = filtered.filter { projectStats in
                projectStats.project.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Apply filter type
        switch filterType {
        case .all:
            break
        case .active:
            filtered = filtered.filter { $0.taskCount > 0 }
        case .inactive:
            filtered = filtered.filter { $0.taskCount == 0 }
        case .completed:
            filtered = filtered.filter { $0.completedTaskCount == $0.taskCount && $0.taskCount > 0 }
        }

        // Apply sorting
        switch sortOption {
        case .name:
            filtered.sort { $0.project.name < $1.project.name }
        case .taskCount:
            filtered.sort { $0.taskCount > $1.taskCount }
        case .completionRate:
            // Calculate completion rate: completedTaskCount / taskCount
            filtered.sort {
                let rate0 = $0.taskCount > 0 ? Double($0.completedTaskCount) / Double($0.taskCount) : 0
                let rate1 = $1.taskCount > 0 ? Double($1.completedTaskCount) / Double($1.taskCount) : 0
                return rate0 > rate1
            }
        case .dateCreated:
            filtered.sort { $0.project.createdDate > $1.project.createdDate }
        }
        
        filteredProjects = filtered
    }

    private func refreshSelectedProjectFromLatestList() {
        guard let selectedProjectID = selectedProject?.project.id else { return }
        guard let refreshed = projects.first(where: { $0.project.id == selectedProjectID }) else {
            selectedProject = nil
            selectedProjectTasks = []
            selectedTaskIDs.removeAll()
            recentReflectionNotes = []
            weeklyContributionStats = ProjectWeeklyContributionStats()
            return
        }
        selectedProject = refreshed
        hydrateMotivationDrafts(from: refreshed.project)
        loadSelectedProjectDetails(projectID: refreshed.project.id)
    }

    private func hydrateMotivationDrafts(from project: Project) {
        motivationWhyDraft = project.motivationWhy ?? ""
        motivationSuccessLooksLikeDraft = project.motivationSuccessLooksLike ?? ""
        motivationCostOfNeglectDraft = project.motivationCostOfNeglect ?? ""
    }

    private func loadSelectedProjectDetails(projectID: UUID) {
        let lock = NSLock()
        let group = DispatchGroup()

        var fetchedTasks: [TaskDefinition] = []
        var fetchedStats = ProjectWeeklyContributionStats()
        var fetchedNotes: [ReflectionNote] = []
        var firstError: Error?

        func capture(_ error: Error) {
            lock.lock()
            if firstError == nil {
                firstError = error
            }
            lock.unlock()
        }

        group.enter()
        getTasksUseCase.getTasksForProject(projectID) { result in
            switch result {
            case .failure(let error):
                capture(error)
            case .success(let projectResult):
                fetchedTasks = projectResult.tasks.sorted(by: self.taskSort)
            }
            group.leave()
        }

        group.enter()
        buildWeeklyPlanSnapshotUseCase.execute(referenceDate: Date()) { result in
            switch result {
            case .failure(let error):
                capture(error)
            case .success(let snapshot):
                let projectTasks = (snapshot.thisWeekTasks + snapshot.nextWeekTasks + snapshot.laterTasks)
                    .filter { $0.projectID == projectID }
                let thisWeekTasks = projectTasks.filter { $0.planningBucket == .thisWeek }
                let nextWeekTasks = projectTasks.filter { $0.planningBucket == .nextWeek }
                let laterTasks = projectTasks.filter { $0.planningBucket == .later || $0.planningBucket == .someday }
                let carriedTasks = thisWeekTasks.filter {
                    ($0.deferredCount > 0) || ($0.deferredFromWeekStart != nil)
                }
                let linkedOutcomeCount = Set(projectTasks.compactMap(\.weeklyOutcomeID)).count
                let outcomeContributionCount = snapshot.outcomes.filter { $0.sourceProjectID == projectID }.count
                fetchedStats = ProjectWeeklyContributionStats(
                    linkedOutcomeCount: linkedOutcomeCount,
                    outcomeContributionCount: outcomeContributionCount,
                    thisWeekCount: thisWeekTasks.count,
                    completedThisWeekCount: thisWeekTasks.filter(\.isComplete).count,
                    nextWeekCount: nextWeekTasks.count,
                    laterCount: laterTasks.count,
                    carryPressureCount: carriedTasks.count
                )
            }
            group.leave()
        }

        group.enter()
        reflectionNoteRepository.fetchNotes(
            query: ReflectionNoteQuery(linkedProjectID: projectID, limit: 6)
        ) { result in
            switch result {
            case .failure(let error):
                capture(error)
            case .success(let notes):
                fetchedNotes = notes
            }
            group.leave()
        }

        group.notify(queue: .main) {
            guard self.selectedProject?.project.id == projectID else { return }
            if let firstError {
                self.errorMessage = firstError.localizedDescription
                return
            }

            self.selectedProjectTasks = fetchedTasks
            self.weeklyContributionStats = fetchedStats
            self.recentReflectionNotes = fetchedNotes
            self.selectedTaskIDs = self.selectedTaskIDs.intersection(Set(fetchedTasks.map(\.id)))
        }
    }

    private func updateTasks(_ tasks: [TaskDefinition], to bucket: TaskPlanningBucket) {
        guard tasks.isEmpty == false else { return }

        isUpdatingTaskBuckets = true
        saveMessage = nil
        errorMessage = nil

        let group = DispatchGroup()
        let lock = NSLock()
        var firstError: Error?
        var changedCount = 0

        for task in tasks {
            guard task.planningBucket != bucket || (bucket != .thisWeek && task.weeklyOutcomeID != nil) else {
                continue
            }

            group.enter()
            updateTaskDefinitionUseCase.execute(
                request: UpdateTaskDefinitionRequest(
                    id: task.id,
                    planningBucket: bucket,
                    weeklyOutcomeID: bucket == .thisWeek ? task.weeklyOutcomeID : nil,
                    clearWeeklyOutcomeLink: bucket != .thisWeek && task.weeklyOutcomeID != nil,
                    deferredFromWeekStart: bucket == .thisWeek ? task.deferredFromWeekStart : nil,
                    clearDeferredFromWeekStart: bucket != .thisWeek && task.deferredFromWeekStart != nil,
                    updatedAt: Date()
                )
            ) { result in
                if case .failure(let error) = result {
                    lock.lock()
                    if firstError == nil { firstError = error }
                    lock.unlock()
                } else {
                    lock.lock()
                    changedCount += 1
                    lock.unlock()
                }
                group.leave()
            }
        }

        group.notify(queue: .main) {
            self.isUpdatingTaskBuckets = false
            if let firstError {
                self.errorMessage = firstError.localizedDescription
                return
            }

            if changedCount > 0 {
                self.saveMessage = bucket == .thisWeek
                    ? "Added to this week"
                    : (bucket == .nextWeek ? "Moved to next week" : "Moved out of this week")
            }

            self.clearSelection()
            self.loadProjects()
        }
    }

    private func applyUpdatedProject(_ updatedProject: Project) {
        if let index = projects.firstIndex(where: { $0.project.id == updatedProject.id }) {
            let existingStats = projects[index]
            let replacement = ProjectWithStats(
                project: updatedProject,
                taskCount: existingStats.taskCount,
                completedTaskCount: existingStats.completedTaskCount
            )
            projects[index] = replacement
        }
        applyFiltersAndSorting()
        if let refreshed = filteredProjects.first(where: { $0.project.id == updatedProject.id }) {
            selectedProject = refreshed
            hydrateMotivationDrafts(from: refreshed.project)
        }
    }

    private func normalizedDraftText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func taskSort(_ lhs: TaskDefinition, _ rhs: TaskDefinition) -> Bool {
        if lhs.isComplete != rhs.isComplete {
            return !lhs.isComplete && rhs.isComplete
        }
        if lhs.planningBucket != rhs.planningBucket {
            return lhs.planningBucket.sortIndex < rhs.planningBucket.sortIndex
        }
        return (lhs.dueDate ?? .distantFuture) < (rhs.dueDate ?? .distantFuture)
    }
}

public struct ProjectWeeklyContributionStats: Equatable {
    public var linkedOutcomeCount: Int
    public var outcomeContributionCount: Int
    public var thisWeekCount: Int
    public var completedThisWeekCount: Int
    public var nextWeekCount: Int
    public var laterCount: Int
    public var carryPressureCount: Int

    public init(
        linkedOutcomeCount: Int = 0,
        outcomeContributionCount: Int = 0,
        thisWeekCount: Int = 0,
        completedThisWeekCount: Int = 0,
        nextWeekCount: Int = 0,
        laterCount: Int = 0,
        carryPressureCount: Int = 0
    ) {
        self.linkedOutcomeCount = linkedOutcomeCount
        self.outcomeContributionCount = outcomeContributionCount
        self.thisWeekCount = thisWeekCount
        self.completedThisWeekCount = completedThisWeekCount
        self.nextWeekCount = nextWeekCount
        self.laterCount = laterCount
        self.carryPressureCount = carryPressureCount
    }
}

// MARK: - Filter and Sort Types

public enum ProjectFilterType: CaseIterable {
    case all
    case active
    case inactive
    case completed
    
    public var displayName: String {
        switch self {
        case .all: return "All Projects"
        case .active: return "Active"
        case .inactive: return "Inactive"
        case .completed: return "Completed"
        }
    }
}

public enum ProjectSortOption: CaseIterable {
    case name
    case taskCount
    case completionRate
    case dateCreated
    
    public var displayName: String {
        switch self {
        case .name: return "Name"
        case .taskCount: return "Task Count"
        case .completionRate: return "Completion Rate"
        case .dateCreated: return "Date Created"
        }
    }
}

// MARK: - View State

extension ProjectManagementViewModel {
    
    /// Combined state for the view
    public var viewState: ProjectManagementViewState {
        return ProjectManagementViewState(
            isLoading: isLoading,
            errorMessage: errorMessage,
            projects: filteredProjects,
            selectedProject: selectedProject,
            showingCreateProject: showingCreateProject,
            showingDeleteConfirmation: showingDeleteConfirmation,
            projectToDelete: projectToDelete,
            hasProjects: !projects.isEmpty,
            totalProjects: projects.count,
            activeProjects: projects.filter { $0.taskCount > 0 }.count,
            selectedProjectTasks: selectedProjectTasks,
            weeklyContributionStats: weeklyContributionStats,
            recentReflectionNotes: recentReflectionNotes
        )
    }
}

/// State structure for the project management view
public struct ProjectManagementViewState {
    public let isLoading: Bool
    public let errorMessage: String?
    public let projects: [ProjectWithStats]
    public let selectedProject: ProjectWithStats?
    public let showingCreateProject: Bool
    public let showingDeleteConfirmation: Bool
    public let projectToDelete: ProjectWithStats?
    public let hasProjects: Bool
    public let totalProjects: Int
    public let activeProjects: Int
    public let selectedProjectTasks: [TaskDefinition]
    public let weeklyContributionStats: ProjectWeeklyContributionStats
    public let recentReflectionNotes: [ReflectionNote]
}
