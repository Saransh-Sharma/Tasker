//
//  GetProjectStatisticsUseCase.swift
//  Tasker
//
//  Use case for generating project statistics and analytics
//

import Foundation

/// Use case for project statistics
public final class GetProjectStatisticsUseCase {
    
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
    
    // MARK: - Statistics Methods
    
    /// Get comprehensive project overview
    public func getProjectOverview(
        completion: @escaping (Result<ProjectOverview, StatisticsError>) -> Void
    ) {
        projectRepository.fetchAllProjects { result in
            switch result {
            case .success(let projects):
                let overview = ProjectOverview(
                    totalProjects: projects.count,
                    activeProjects: projects.filter { $0.status == .active }.count,
                    completedProjects: projects.filter { $0.status == .completed }.count
                )
                completion(.success(overview))
            case .failure(let error):
                completion(.failure(StatisticsError.repositoryError(error)))
            }
        }
    }
}

// MARK: - Model Types

public struct ProjectOverview {
    public let totalProjects: Int
    public let activeProjects: Int
    public let completedProjects: Int
    
    public init(totalProjects: Int, activeProjects: Int, completedProjects: Int) {
        self.totalProjects = totalProjects
        self.activeProjects = activeProjects
        self.completedProjects = completedProjects
    }
}