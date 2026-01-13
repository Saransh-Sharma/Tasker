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
    
    // Filter and search state
    @Published public var searchText: String = ""
    @Published public var filterType: ProjectFilterType = .all
    @Published public var sortOption: ProjectSortOption = .name
    
    // UI state
    @Published public private(set) var showingCreateProject: Bool = false
    @Published public private(set) var showingDeleteConfirmation: Bool = false
    @Published public private(set) var projectToDelete: ProjectWithStats?
    
    // MARK: - Dependencies
    
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let getTasksUseCase: GetTasksUseCase
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    public init(
        manageProjectsUseCase: ManageProjectsUseCase,
        getTasksUseCase: GetTasksUseCase
    ) {
        self.manageProjectsUseCase = manageProjectsUseCase
        self.getTasksUseCase = getTasksUseCase
        
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
    public func updateProject(_ project: Project, name: String? = nil, description: String? = nil) {
        isLoading = true

        let request = UpdateProjectRequest(
            name: name,
            description: description
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
    public func loadTasksForProject(_ project: Project, completion: @escaping ([Task]) -> Void) {
        getTasksUseCase.getTasksForProject(project.name) { result in
            switch result {
            case .success(let projectResult):
                completion(projectResult.tasks)
            case .failure:
                completion([])
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func setupFilteringAndSorting() {
        // Apply filters and sorting whenever search or filter criteria change
        Publishers.CombineLatest3($searchText, $filterType, $sortOption)
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.applyFiltersAndSorting()
            }
            .store(in: &cancellables)
    }
    
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
            activeProjects: projects.filter { $0.taskCount > 0 }.count
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
}