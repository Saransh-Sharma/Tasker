//
//  AssignOrphanedTasksToInboxUseCase.swift
//  Tasker
//
//  Use case for finding and assigning orphaned tasks to the Inbox project
//

import Foundation

/// Use case for assigning tasks without a valid projectID to Inbox
/// This is used during data migration and for maintaining data integrity
public final class AssignOrphanedTasksToInboxUseCase {

    // MARK: - Dependencies

    private let taskRepository: TaskRepositoryProtocol
    private let projectRepository: ProjectRepositoryProtocol

    // MARK: - Initialization

    public init(
        taskRepository: TaskRepositoryProtocol,
        projectRepository: ProjectRepositoryProtocol
    ) {
        self.taskRepository = taskRepository
        self.projectRepository = projectRepository
    }

    // MARK: - Execution

    /// Finds all orphaned tasks and assigns them to the Inbox project
    /// Returns the number of tasks that were assigned
    public func execute(completion: @escaping (Result<OrphanedTasksReport, OrphanedTasksError>) -> Void) {
        // Step 1: Fetch all tasks without a projectID
        taskRepository.fetchTasksWithoutProject { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let orphanedTasks):
                if orphanedTasks.isEmpty {
                    // No orphaned tasks, return success with zero count
                    let report = OrphanedTasksReport(
                        orphanedTasksFound: 0,
                        tasksAssignedToInbox: 0,
                        errors: []
                    )
                    completion(.success(report))
                    return
                }

                // Step 2: Assign all orphaned tasks to Inbox
                let taskIDs = orphanedTasks.map { $0.id }
                self.assignTasksToInbox(taskIDs: taskIDs, orphanedCount: orphanedTasks.count, completion: completion)

            case .failure(let error):
                completion(.failure(.fetchFailed(error)))
            }
        }
    }

    /// Execute and also validate that all tasks have valid project references
    public func executeWithValidation(completion: @escaping (Result<OrphanedTasksReport, OrphanedTasksError>) -> Void) {
        // Step 1: Fetch all projects to get valid project IDs
        projectRepository.fetchAllProjects { [weak self] projectsResult in
            guard let self = self else { return }

            switch projectsResult {
            case .success(let projects):
                let validProjectIDs = Set(projects.map { $0.id })

                // Step 2: Fetch all tasks
                self.taskRepository.fetchAllTasks { [weak self] tasksResult in
                    guard let self = self else { return }

                    switch tasksResult {
                    case .success(let allTasks):
                        // Step 3: Find tasks with invalid projectID
                        let invalidTasks = allTasks.filter { task in
                            !validProjectIDs.contains(task.projectID)
                        }

                        if invalidTasks.isEmpty {
                            // All tasks have valid projects
                            let report = OrphanedTasksReport(
                                orphanedTasksFound: 0,
                                tasksAssignedToInbox: 0,
                                errors: []
                            )
                            completion(.success(report))
                            return
                        }

                        // Step 4: Assign invalid tasks to Inbox
                        let taskIDs = invalidTasks.map { $0.id }
                        self.assignTasksToInbox(
                            taskIDs: taskIDs,
                            orphanedCount: invalidTasks.count,
                            completion: completion
                        )

                    case .failure(let error):
                        completion(.failure(.fetchFailed(error)))
                    }
                }

            case .failure(let error):
                completion(.failure(.projectFetchFailed(error)))
            }
        }
    }

    // MARK: - Private Methods

    private func assignTasksToInbox(
        taskIDs: [UUID],
        orphanedCount: Int,
        completion: @escaping (Result<OrphanedTasksReport, OrphanedTasksError>) -> Void
    ) {
        taskRepository.assignTasksToProject(
            taskIDs: taskIDs,
            projectID: ProjectConstants.inboxProjectID
        ) { result in
            switch result {
            case .success:
                logDebug("✅ Assigned \(orphanedCount) orphaned tasks to Inbox")
                let report = OrphanedTasksReport(
                    orphanedTasksFound: orphanedCount,
                    tasksAssignedToInbox: orphanedCount,
                    errors: []
                )
                completion(.success(report))

            case .failure(let error):
                logError(" Failed to assign orphaned tasks: \(error)")
                let report = OrphanedTasksReport(
                    orphanedTasksFound: orphanedCount,
                    tasksAssignedToInbox: 0,
                    errors: [error.localizedDescription]
                )
                completion(.failure(.assignmentFailed(error, report: report)))
            }
        }
    }
}

// MARK: - Report Type

public struct OrphanedTasksReport {
    public let orphanedTasksFound: Int
    public let tasksAssignedToInbox: Int
    public let errors: [String]

    public var description: String {
        return """
        Orphaned Tasks Report:
        - Tasks found without valid project: \(orphanedTasksFound)
        - Tasks assigned to Inbox: \(tasksAssignedToInbox)
        - Errors: \(errors.isEmpty ? "None" : errors.joined(separator: ", "))
        """
    }

    public var wasSuccessful: Bool {
        return orphanedTasksFound == tasksAssignedToInbox && errors.isEmpty
    }
}

// MARK: - Error Types

public enum OrphanedTasksError: LocalizedError {
    case fetchFailed(Error)
    case projectFetchFailed(Error)
    case assignmentFailed(Error, report: OrphanedTasksReport)

    public var errorDescription: String? {
        switch self {
        case .fetchFailed(let error):
            return "Failed to fetch orphaned tasks: \(error.localizedDescription)"
        case .projectFetchFailed(let error):
            return "Failed to fetch projects: \(error.localizedDescription)"
        case .assignmentFailed(let error, let report):
            return "Failed to assign tasks to Inbox: \(error.localizedDescription)\n\(report.description)"
        }
    }
}
