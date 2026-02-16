//
//  EnsureInboxProjectUseCase.swift
//  Tasker
//
//  Use case for ensuring the Inbox project exists in the system
//

import Foundation

/// Use case for ensuring the Inbox project exists
/// This is called during app initialization to guarantee the default project is available
public final class EnsureInboxProjectUseCase {

    // MARK: - Dependencies

    private let projectRepository: ProjectRepositoryProtocol

    // MARK: - Initialization

    public init(projectRepository: ProjectRepositoryProtocol) {
        self.projectRepository = projectRepository
    }

    // MARK: - Execution

    /// Ensures the Inbox project exists in the database
    /// Creates it if it doesn't exist, updates it if needed
    public func execute(completion: @escaping (Result<Project, EnsureInboxError>) -> Void) {
        // Try to fetch the Inbox project first
        projectRepository.fetchProject(withId: ProjectConstants.inboxProjectID) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let project):
                if let existingInbox = project {
                    // Inbox exists, return it
                    completion(.success(existingInbox))
                } else {
                    // Inbox doesn't exist, create it
                    self.createInboxProject(completion: completion)
                }
            case .failure(let error):
                // Error fetching, try to create it anyway
                logError("Error fetching Inbox project: \(error), attempting to create")
                self.createInboxProject(completion: completion)
            }
        }
    }

    // MARK: - Private Methods

    private func createInboxProject(completion: @escaping (Result<Project, EnsureInboxError>) -> Void) {
        let inboxProject = Project.createInbox()

        projectRepository.createProject(inboxProject) { result in
            switch result {
            case .success(let createdProject):
                logDebug("✅ Inbox project created successfully with ID: \(createdProject.id)")
                completion(.success(createdProject))
            case .failure(let error):
                logError(" Failed to create Inbox project: \(error)")
                completion(.failure(.creationFailed(error)))
            }
        }
    }
}

// MARK: - Error Types

public enum EnsureInboxError: LocalizedError {
    case creationFailed(Error)
    case validationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .creationFailed(let error):
            return "Failed to create Inbox project: \(error.localizedDescription)"
        case .validationFailed(let message):
            return "Inbox project validation failed: \(message)"
        }
    }
}
