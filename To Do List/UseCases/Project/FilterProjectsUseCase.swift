//
//  FilterProjectsUseCase.swift
//  Tasker
//
//  Use case for filtering projects with various criteria
//

import Foundation

/// Use case for filtering projects
public final class FilterProjectsUseCase {
    
    // MARK: - Dependencies
    
    private let projectRepository: ProjectRepositoryProtocol
    
    // MARK: - Initialization
    
    public init(projectRepository: ProjectRepositoryProtocol) {
        self.projectRepository = projectRepository
    }
    
    // MARK: - Filter Methods
    
    /// Filter projects by status
    public func filterByStatus(
        _ status: ProjectStatus,
        completion: @escaping (Result<[Project], FilterProjectsError>) -> Void
    ) {
        projectRepository.fetchAllProjects { result in
            switch result {
            case .success(let projects):
                let filtered = projects.filter { $0.status == status }
                completion(Result.success(filtered))
            case .failure(let error):
                completion(Result.failure(FilterProjectsError.repositoryError(error)))
            }
        }
    }
    
    /// Filter projects by priority
    public func filterByPriority(
        _ priority: ProjectPriority,
        completion: @escaping (Result<[Project], FilterProjectsError>) -> Void
    ) {
        projectRepository.fetchAllProjects { result in
            switch result {
            case .success(let projects):
                let filtered = projects.filter { $0.priority == priority }
                completion(Result.success(filtered))
            case .failure(let error):
                completion(Result.failure(FilterProjectsError.repositoryError(error)))
            }
        }
    }
}

// MARK: - Supporting Types

public enum FilterProjectsError: LocalizedError {
    case repositoryError(Error)
    case invalidCriteria
    
    public var errorDescription: String? {
        switch self {
        case .repositoryError(let error):
            return "Repository error: \(error.localizedDescription)"
        case .invalidCriteria:
            return "Invalid filter criteria"
        }
    }
}