//
//  ManageProjectsUseCase.swift
//  Tasker
//
//  Use case for managing projects (create, update, delete)
//

import Foundation

/// Use case for managing projects
/// Handles all project CRUD operations with business rules
public final class ManageProjectsUseCase {
    
    // MARK: - Dependencies
    
    private let projectRepository: ProjectRepositoryProtocol
    private let taskRepository: TaskRepositoryProtocol
    
    // MARK: - Initialization
    
    public init(
        projectRepository: ProjectRepositoryProtocol,
        taskRepository: TaskRepositoryProtocol
    ) {
        self.projectRepository = projectRepository
        self.taskRepository = taskRepository
    }
    
    // MARK: - Create Project
    
    /// Creates a new project
    public func createProject(
        request: CreateProjectRequest,
        completion: @escaping (Result<Project, ProjectError>) -> Void
    ) {
        // Validate project name
        guard validateProjectName(request.name) else {
            completion(.failure(.invalidName("Project name is invalid")))
            return
        }
        
        // Check if name is available
        projectRepository.isProjectNameAvailable(request.name, excludingId: nil) { [weak self] result in
            switch result {
            case .success(let isAvailable):
                if !isAvailable {
                    completion(.failure(.duplicateName))
                    return
                }
                
                // Create the project
                let project = Project(
                    name: request.name,
                    projectDescription: request.description,
                    createdDate: Date(),
                    modifiedDate: Date(),
                    isDefault: false
                )
                
                // Validate the project
                do {
                    try project.validate()
                } catch {
                    completion(.failure(.validationFailed(error.localizedDescription)))
                    return
                }
                
                // Save to repository
                self?.projectRepository.createProject(project) { result in
                    switch result {
                    case .success(let createdProject):
                        // Post notification
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ProjectCreated"),
                            object: createdProject
                        )
                        completion(.success(createdProject))
                        
                    case .failure(let error):
                        completion(.failure(.repositoryError(error)))
                    }
                }
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Update Project
    
    /// Updates an existing project
    public func updateProject(
        projectId: UUID,
        request: UpdateProjectRequest,
        completion: @escaping (Result<Project, ProjectError>) -> Void
    ) {
        // Fetch the existing project
        projectRepository.fetchProject(withId: projectId) { [weak self] result in
            switch result {
            case .success(let project):
                guard var project = project else {
                    completion(.failure(.projectNotFound))
                    return
                }
                
                // Don't allow updating the default Inbox project name
                if project.isDefault && request.name != nil {
                    completion(.failure(.cannotModifyDefault))
                    return
                }
                
                // Apply updates
                if let newName = request.name {
                    // Validate new name
                    guard self?.validateProjectName(newName) == true else {
                        completion(.failure(.invalidName("Project name is invalid")))
                        return
                    }
                    
                    // Check if new name is available
                    self?.projectRepository.isProjectNameAvailable(newName, excludingId: projectId) { result in
                        switch result {
                        case .success(let isAvailable):
                            if !isAvailable {
                                completion(.failure(.duplicateName))
                                return
                            }
                            
                            project.name = newName
                            self?.performProjectUpdate(project: project, completion: completion)
                            
                        case .failure(let error):
                            completion(.failure(.repositoryError(error)))
                        }
                    }
                } else {
                    // Just update description
                    if let newDescription = request.description {
                        project.projectDescription = newDescription
                    }
                    project.modifiedDate = Date()
                    self?.performProjectUpdate(project: project, completion: completion)
                }
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Delete Project
    
    /// Deletes a project and optionally its tasks
    public func deleteProject(
        projectId: UUID,
        deleteStrategy: DeleteStrategy = .moveToInbox,
        completion: @escaping (Result<Void, ProjectError>) -> Void
    ) {
        // Fetch the project to check if it's deletable
        projectRepository.fetchProject(withId: projectId) { [weak self] result in
            switch result {
            case .success(let project):
                guard let project = project else {
                    // Project doesn't exist, consider it already deleted
                    completion(.success(()))
                    return
                }
                
                // Don't allow deleting the default Inbox project
                if project.isDefault {
                    completion(.failure(.cannotDeleteDefault))
                    return
                }
                
                // Delete based on strategy
                let deleteTasks = (deleteStrategy == .deleteAllTasks)
                self?.projectRepository.deleteProject(withId: projectId, deleteTasks: deleteTasks) { result in
                    switch result {
                    case .success:
                        // Post notification
                        NotificationCenter.default.post(
                            name: NSNotification.Name("ProjectDeleted"),
                            object: project
                        )
                        completion(.success(()))
                        
                    case .failure(let error):
                        completion(.failure(.repositoryError(error)))
                    }
                }
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Get Projects
    
    /// Gets all projects with task counts
    public func getAllProjects(completion: @escaping (Result<[ProjectWithStats], ProjectError>) -> Void) {
        projectRepository.fetchAllProjects { [weak self] result in
            switch result {
            case .success(let projects):
                var projectsWithStats: [ProjectWithStats] = []
                let group = DispatchGroup()
                
                for project in projects {
                    group.enter()
                    self?.projectRepository.getTaskCount(for: project.id) { countResult in
                        if case .success(let count) = countResult {
                            let stats = ProjectWithStats(
                                project: project,
                                taskCount: count,
                                completedTaskCount: 0 // Would need additional query
                            )
                            projectsWithStats.append(stats)
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    // Sort projects: Inbox first, then alphabetically
                    projectsWithStats.sort { p1, p2 in
                        if p1.project.isDefault { return true }
                        if p2.project.isDefault { return false }
                        return p1.project.name < p2.project.name
                    }
                    completion(.success(projectsWithStats))
                }
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    /// Gets custom (non-default) projects
    public func getCustomProjects(completion: @escaping (Result<[Project], ProjectError>) -> Void) {
        projectRepository.fetchCustomProjects { result in
            switch result {
            case .success(let projects):
                completion(.success(projects))
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Move Tasks
    
    /// Moves all tasks from one project to another
    public func moveTasksBetweenProjects(
        from sourceProjectId: UUID,
        to targetProjectId: UUID,
        completion: @escaping (Result<Int, ProjectError>) -> Void
    ) {
        // Validate both projects exist
        projectRepository.fetchProject(withId: sourceProjectId) { [weak self] sourceResult in
            switch sourceResult {
            case .success(let sourceProject):
                guard sourceProject != nil else {
                    completion(.failure(.projectNotFound))
                    return
                }
                
                self?.projectRepository.fetchProject(withId: targetProjectId) { targetResult in
                    switch targetResult {
                    case .success(let targetProject):
                        guard targetProject != nil else {
                            completion(.failure(.projectNotFound))
                            return
                        }
                        
                        // Get task count before moving
                        self?.projectRepository.getTaskCount(for: sourceProjectId) { countResult in
                            let taskCount = (try? countResult.get()) ?? 0
                            
                            // Perform the move
                            self?.projectRepository.moveTasks(from: sourceProjectId, to: targetProjectId) { moveResult in
                                switch moveResult {
                                case .success:
                                    completion(.success(taskCount))
                                case .failure(let error):
                                    completion(.failure(.repositoryError(error)))
                                }
                            }
                        }
                        
                    case .failure(let error):
                        completion(.failure(.repositoryError(error)))
                    }
                }
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func validateProjectName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && trimmed.count <= 100
    }
    
    private func performProjectUpdate(project: Project, completion: @escaping (Result<Project, ProjectError>) -> Void) {
        // Validate the updated project
        do {
            try project.validate()
        } catch {
            completion(.failure(.validationFailed(error.localizedDescription)))
            return
        }
        
        // Save to repository
        projectRepository.updateProject(project) { result in
            switch result {
            case .success(let updatedProject):
                // Post notification
                NotificationCenter.default.post(
                    name: NSNotification.Name("ProjectUpdated"),
                    object: updatedProject
                )
                completion(.success(updatedProject))
                
            case .failure(let error):
                completion(.failure(.repositoryError(error)))
            }
        }
    }
}

// MARK: - Request Models

public struct CreateProjectRequest {
    public let name: String
    public let description: String?
    
    public init(name: String, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

public struct UpdateProjectRequest {
    public let name: String?
    public let description: String?
    
    public init(name: String? = nil, description: String? = nil) {
        self.name = name
        self.description = description
    }
}

// MARK: - Result Models

public struct ProjectWithStats {
    public let project: Project
    public let taskCount: Int
    public let completedTaskCount: Int
}

// MARK: - Supporting Types

public enum DeleteStrategy {
    case moveToInbox    // Move tasks to Inbox before deleting project
    case deleteAllTasks // Delete all tasks in the project
}

public enum ProjectError: LocalizedError {
    case projectNotFound
    case invalidName(String)
    case duplicateName
    case cannotDeleteDefault
    case cannotModifyDefault
    case validationFailed(String)
    case repositoryError(Error)
    
    public var errorDescription: String? {
        switch self {
        case .projectNotFound:
            return "Project not found"
        case .invalidName(let reason):
            return "Invalid project name: \(reason)"
        case .duplicateName:
            return "A project with this name already exists"
        case .cannotDeleteDefault:
            return "Cannot delete the default Inbox project"
        case .cannotModifyDefault:
            return "Cannot modify the default Inbox project"
        case .validationFailed(let reason):
            return "Validation failed: \(reason)"
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        }
    }
}
