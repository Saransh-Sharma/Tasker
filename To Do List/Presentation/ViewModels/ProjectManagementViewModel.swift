//
//  ProjectManagementViewModel.swift
//  Tasker
//
//  ViewModel for Project Management screen
//

import Foundation
import Combine

/// ViewModel for Project Management screen
public final class ProjectManagementViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var projects: [ProjectWithStats] = []
    @Published public private(set) var isLoading: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public var newProjectName: String = ""
    @Published public var newProjectDescription: String = ""
    @Published public var selectedProject: Project?
    @Published public var showCreateProjectSheet: Bool = false
    @Published public var showEditProjectSheet: Bool = false
    
    // MARK: - Dependencies
    
    private let manageProjectsUseCase: ManageProjectsUseCase
    private let getTasksUseCase: GetTasksUseCase
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    public var canCreateProject: Bool {
        return !newProjectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               newProjectName.count <= 100
    }
    
    public var totalTaskCount: Int {
        return projects.reduce(0) { $0 + $1.taskCount }
    }
    
    public var totalCompletedCount: Int {
        return projects.reduce(0) { $0 + $1.completedTaskCount }
    }
    
    // MARK: - Initialization
    
    public init(
        manageProjectsUseCase: ManageProjectsUseCase,
        getTasksUseCase: GetTasksUseCase
    ) {
        self.manageProjectsUseCase = manageProjectsUseCase
        self.getTasksUseCase = getTasksUseCase
        
        setupBindings()
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
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Create a new project
    public func createProject() {
        guard canCreateProject else {
            errorMessage = "Invalid project name"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let request = CreateProjectRequest(
            name: newProjectName.trimmingCharacters(in: .whitespacesAndNewlines),
            description: newProjectDescription.isEmpty ? nil : newProjectDescription
        )
        
        manageProjectsUseCase.createProject(request: request) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    self?.newProjectName = ""
                    self?.newProjectDescription = ""
                    self?.showCreateProjectSheet = false
                    self?.loadProjects()
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Update an existing project
    public func updateProject(_ project: Project, newName: String?, newDescription: String?) {
        guard newName != nil || newDescription != nil else { return }
        
        isLoading = true
        errorMessage = nil
        
        let request = UpdateProjectRequest(
            name: newName,
            description: newDescription
        )
        
        manageProjectsUseCase.updateProject(projectId: project.id, request: request) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success:
                    self?.showEditProjectSheet = false
                    self?.loadProjects()
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Delete a project
    public func deleteProject(_ project: Project, deleteTasks: Bool = false) {
        // Don't allow deleting the Inbox
        guard !project.isDefault else {
            errorMessage = "Cannot delete the Inbox project"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        let strategy: DeleteStrategy = deleteTasks ? .deleteAllTasks : .moveToInbox
        
        manageProjectsUseCase.deleteProject(projectId: project.id, deleteStrategy: strategy) { [weak self] result in
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
    
    /// Move tasks between projects
    public func moveTasksBetweenProjects(from sourceProject: Project, to targetProject: Project) {
        isLoading = true
        errorMessage = nil
        
        manageProjectsUseCase.moveTasksBetweenProjects(
            from: sourceProject.id,
            to: targetProject.id
        ) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                switch result {
                case .success(let taskCount):
                    self?.loadProjects()
                    self?.errorMessage = "\(taskCount) tasks moved successfully"
                    
                case .failure(let error):
                    self?.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    /// Get tasks for a specific project
    public func getTasksForProject(_ project: Project, completion: @escaping ([Task]) -> Void) {
        getTasksUseCase.getTasksForProject(project.name) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let projectResult):
                    completion(projectResult.tasks)
                    
                case .failure:
                    completion([])
                }
            }
        }
    }
    
    /// Select a project for editing
    public func selectProjectForEditing(_ project: Project) {
        selectedProject = project
        newProjectName = project.name
        newProjectDescription = project.projectDescription ?? ""
        showEditProjectSheet = true
    }
    
    /// Clear form
    public func clearForm() {
        newProjectName = ""
        newProjectDescription = ""
        selectedProject = nil
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Listen for project-related notifications
        NotificationCenter.default.publisher(for: NSNotification.Name("ProjectCreated"))
            .sink { [weak self] _ in
                self?.loadProjects()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("ProjectUpdated"))
            .sink { [weak self] _ in
                self?.loadProjects()
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: NSNotification.Name("ProjectDeleted"))
            .sink { [weak self] _ in
                self?.loadProjects()
            }
            .store(in: &cancellables)
    }
}

// MARK: - View State

extension ProjectManagementViewModel {
    
    /// Project statistics for display
    public struct ProjectStatistics {
        public let totalProjects: Int
        public let customProjects: Int
        public let totalTasks: Int
        public let completedTasks: Int
        public let completionRate: Double
        
        init(projects: [ProjectWithStats]) {
            self.totalProjects = projects.count
            self.customProjects = projects.filter { !$0.project.isDefault }.count
            self.totalTasks = projects.reduce(0) { $0 + $1.taskCount }
            self.completedTasks = projects.reduce(0) { $0 + $1.completedTaskCount }
            self.completionRate = totalTasks > 0 ? Double(completedTasks) / Double(totalTasks) : 0
        }
    }
    
    /// Get overall statistics
    public var statistics: ProjectStatistics {
        return ProjectStatistics(projects: projects)
    }
}
