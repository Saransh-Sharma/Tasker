//
//  InboxProjectInitializer.swift
//  Tasker
//
//  Service to ensure the Inbox project exists with the correct fixed UUID
//

import Foundation
import CoreData

/// Service responsible for initializing and ensuring the Inbox project exists
public final class InboxProjectInitializer {

    // MARK: - Properties

    private let viewContext: NSManagedObjectContext
    private let backgroundContext: NSManagedObjectContext

    // MARK: - Initialization

    public init(viewContext: NSManagedObjectContext, backgroundContext: NSManagedObjectContext) {
        self.viewContext = viewContext
        self.backgroundContext = backgroundContext
    }

    // MARK: - Public Methods

    /// Ensure the Inbox project exists in the database
    /// Creates it if it doesn't exist, or updates it if needed
    public func ensureInboxExists(completion: @escaping (Result<Void, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }

            do {
                // Check if Inbox project already exists
                let fetchRequest = Projects.fetchRequest()
                fetchRequest.predicate = NSPredicate(
                    format: "projectID == %@",
                    ProjectConstants.inboxProjectID as CVarArg
                )

                let results = try self.backgroundContext.fetch(fetchRequest)

                if let existingInbox = results.first {
                    // Inbox exists, ensure it has correct properties
                    existingInbox.projectID = ProjectConstants.inboxProjectID
                    existingInbox.projectName = ProjectConstants.inboxProjectName
                    existingInbox.projecDescription = ProjectConstants.inboxProjectDescription

                    try self.backgroundContext.save()
                    completion(.success(()))
                } else {
                    // Inbox doesn't exist, create it
                    let inbox = Projects(context: self.backgroundContext)
                    inbox.projectID = ProjectConstants.inboxProjectID
                    inbox.projectName = ProjectConstants.inboxProjectName
                    inbox.projecDescription = ProjectConstants.inboxProjectDescription

                    try self.backgroundContext.save()
                    completion(.success(()))
                }
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Assign all tasks without a valid projectID to Inbox
    public func assignOrphanedTasksToInbox(completion: @escaping (Result<Int, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }

            do {
                // Fetch all tasks without a projectID
                let fetchRequest = NTask.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "projectID == nil")

                let orphanedTasks = try self.backgroundContext.fetch(fetchRequest)
                let count = orphanedTasks.count

                // Assign all orphaned tasks to Inbox
                for task in orphanedTasks {
                    task.projectID = ProjectConstants.inboxProjectID
                    task.project = ProjectConstants.inboxProjectName
                }

                if count > 0 {
                    try self.backgroundContext.save()
                }

                completion(.success(count))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Generate UUIDs for all tasks that don't have them
    public func ensureAllTasksHaveUUIDs(completion: @escaping (Result<Int, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }

            do {
                // Fetch all tasks without a taskID
                let fetchRequest = NTask.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "taskID == nil")

                let tasksWithoutUUIDs = try self.backgroundContext.fetch(fetchRequest)
                let count = tasksWithoutUUIDs.count

                // Generate UUIDs for all tasks without them
                for task in tasksWithoutUUIDs {
                    task.taskID = UUID()
                }

                if count > 0 {
                    try self.backgroundContext.save()
                }

                completion(.success(count))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Generate UUIDs for all projects that don't have them
    public func ensureAllProjectsHaveUUIDs(completion: @escaping (Result<Int, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }

            do {
                // Fetch all projects without a projectID
                let fetchRequest = Projects.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "projectID == nil")

                let projectsWithoutUUIDs = try self.backgroundContext.fetch(fetchRequest)
                let count = projectsWithoutUUIDs.count

                // Generate UUIDs for all projects without them
                for project in projectsWithoutUUIDs {
                    project.projectID = UUID()
                }

                if count > 0 {
                    try self.backgroundContext.save()
                }

                completion(.success(count))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Perform complete initialization: ensure Inbox exists, generate UUIDs, and assign orphaned tasks
    public func performCompleteInitialization(completion: @escaping (Result<InitializationReport, Error>) -> Void) {
        ensureInboxExists { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success:
                // Inbox created/verified, now ensure all tasks have UUIDs
                self.ensureAllTasksHaveUUIDs { taskUUIDResult in
                    switch taskUUIDResult {
                    case .success(let tasksUpdated):
                        // Tasks have UUIDs, now ensure all projects have UUIDs
                        self.ensureAllProjectsHaveUUIDs { projectUUIDResult in
                            switch projectUUIDResult {
                            case .success(let projectsUpdated):
                                // Projects have UUIDs, now assign orphaned tasks
                                self.assignOrphanedTasksToInbox { orphanedResult in
                                    switch orphanedResult {
                                    case .success(let orphanedCount):
                                        let report = InitializationReport(
                                            inboxCreated: true,
                                            tasksAssignedUUIDs: tasksUpdated,
                                            projectsAssignedUUIDs: projectsUpdated,
                                            tasksAssignedToInbox: orphanedCount
                                        )
                                        completion(.success(report))
                                    case .failure(let error):
                                        completion(.failure(error))
                                    }
                                }
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Initialization Report

public struct InitializationReport {
    public let inboxCreated: Bool
    public let tasksAssignedUUIDs: Int
    public let projectsAssignedUUIDs: Int
    public let tasksAssignedToInbox: Int

    public var description: String {
        return """
        Initialization Report:
        - Inbox: \(inboxCreated ? "Created/Verified" : "Failed")
        - Tasks assigned UUIDs: \(tasksAssignedUUIDs)
        - Projects assigned UUIDs: \(projectsAssignedUUIDs)
        - Tasks assigned to Inbox: \(tasksAssignedToInbox)
        """
    }
}
