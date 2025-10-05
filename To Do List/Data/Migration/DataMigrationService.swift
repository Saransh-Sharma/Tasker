//
//  DataMigrationService.swift
//  Tasker
//
//  Service for migrating existing data to UUID-based system
//

import Foundation
import CoreData

/// Service responsible for migrating existing data to use UUIDs
public final class DataMigrationService {

    // MARK: - Properties

    private let persistentContainer: NSPersistentContainer
    private let inboxInitializer: InboxProjectInitializer

    // MARK: - Initialization

    public init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
        self.inboxInitializer = InboxProjectInitializer(
            viewContext: persistentContainer.viewContext,
            backgroundContext: persistentContainer.newBackgroundContext()
        )
    }

    // MARK: - Public Methods

    /// Perform complete data migration to UUID-based system
    public func migrateToUUIDs(completion: @escaping (Result<MigrationReport, Error>) -> Void) {
        print("🔄 Starting UUID migration...")

        let startTime = Date()

        // Use the inbox initializer to perform complete initialization
        inboxInitializer.performCompleteInitialization { result in
            switch result {
            case .success(let initReport):
                let duration = Date().timeIntervalSince(startTime)

                let report = MigrationReport(
                    tasksProcessed: initReport.tasksAssignedUUIDs,
                    projectsProcessed: initReport.projectsAssignedUUIDs,
                    tasksAssignedToInbox: initReport.tasksAssignedToInbox,
                    inboxCreated: initReport.inboxCreated,
                    errors: [],
                    duration: duration
                )

                print("✅ Migration completed successfully in \(String(format: "%.2f", duration))s")
                print(report.description)

                completion(.success(report))

            case .failure(let error):
                print("❌ Migration failed: \(error)")
                completion(.failure(error))
            }
        }
    }

    /// Check if migration is needed
    public func isMigrationNeeded(completion: @escaping (Bool) -> Void) {
        let context = persistentContainer.newBackgroundContext()

        context.perform {
            // Check if any tasks are missing taskID
            let taskRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
            taskRequest.predicate = NSPredicate(format: "taskID == nil")
            taskRequest.fetchLimit = 1

            do {
                let tasksWithoutID = try context.fetch(taskRequest)
                if !tasksWithoutID.isEmpty {
                    completion(true)
                    return
                }

                // Check if any tasks are missing projectID
                taskRequest.predicate = NSPredicate(format: "projectID == nil")
                let tasksWithoutProject = try context.fetch(taskRequest)
                if !tasksWithoutProject.isEmpty {
                    completion(true)
                    return
                }

                // Check if Inbox project exists
                let projectRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
                projectRequest.predicate = NSPredicate(
                    format: "projectID == %@",
                    ProjectConstants.inboxProjectID as CVarArg
                )
                projectRequest.fetchLimit = 1

                let inboxProjects = try context.fetch(projectRequest)
                if inboxProjects.isEmpty {
                    completion(true)
                    return
                }

                // No migration needed
                completion(false)

            } catch {
                print("Error checking migration status: \(error)")
                // If we can't check, assume migration is needed to be safe
                completion(true)
            }
        }
    }

    /// Perform data integrity check
    public func performIntegrityCheck(completion: @escaping (Result<IntegrityReport, Error>) -> Void) {
        let context = persistentContainer.newBackgroundContext()

        context.perform {
            do {
                // Count total tasks
                let taskRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
                let totalTasks = try context.count(for: taskRequest)

                // Count tasks with valid taskID
                taskRequest.predicate = NSPredicate(format: "taskID != nil")
                let tasksWithID = try context.count(for: taskRequest)

                // Count tasks with valid projectID
                taskRequest.predicate = NSPredicate(format: "projectID != nil")
                let tasksWithProject = try context.count(for: taskRequest)

                // Count projects
                let projectRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
                let totalProjects = try context.count(for: projectRequest)

                // Check if Inbox exists
                projectRequest.predicate = NSPredicate(
                    format: "projectID == %@",
                    ProjectConstants.inboxProjectID as CVarArg
                )
                let inboxExists = try context.count(for: projectRequest) > 0

                var issues: [String] = []

                if tasksWithID < totalTasks {
                    issues.append("\(totalTasks - tasksWithID) tasks missing taskID")
                }

                if tasksWithProject < totalTasks {
                    issues.append("\(totalTasks - tasksWithProject) tasks missing projectID")
                }

                if !inboxExists {
                    issues.append("Inbox project does not exist")
                }

                let report = IntegrityReport(
                    totalTasks: totalTasks,
                    tasksWithValidID: tasksWithID,
                    tasksWithValidProject: tasksWithProject,
                    totalProjects: totalProjects,
                    inboxExists: inboxExists,
                    issues: issues
                )

                completion(.success(report))

            } catch {
                completion(.failure(error))
            }
        }
    }
}

// MARK: - Migration Report

public struct MigrationReport {
    public let tasksProcessed: Int
    public let projectsProcessed: Int
    public let tasksAssignedToInbox: Int
    public let inboxCreated: Bool
    public let errors: [String]
    public let duration: TimeInterval

    public var description: String {
        return """

        ═══════════════════════════════════════════
        📊 Migration Report
        ═══════════════════════════════════════════
        Tasks processed: \(tasksProcessed)
        Projects processed: \(projectsProcessed)
        Tasks assigned to Inbox: \(tasksAssignedToInbox)
        Inbox created: \(inboxCreated ? "✅ Yes" : "⚠️ Already existed")
        Errors: \(errors.isEmpty ? "✅ None" : "❌ \(errors.count)")
        Duration: \(String(format: "%.2f", duration))s
        ═══════════════════════════════════════════
        """
    }

    public var wasSuccessful: Bool {
        return errors.isEmpty
    }
}

// MARK: - Integrity Report

public struct IntegrityReport {
    public let totalTasks: Int
    public let tasksWithValidID: Int
    public let tasksWithValidProject: Int
    public let totalProjects: Int
    public let inboxExists: Bool
    public let issues: [String]

    public var description: String {
        return """

        ═══════════════════════════════════════════
        🔍 Data Integrity Report
        ═══════════════════════════════════════════
        Total tasks: \(totalTasks)
        Tasks with valid ID: \(tasksWithValidID)
        Tasks with valid project: \(tasksWithValidProject)
        Total projects: \(totalProjects)
        Inbox exists: \(inboxExists ? "✅" : "❌")
        Issues: \(issues.isEmpty ? "✅ None" : "\n  • " + issues.joined(separator: "\n  • "))
        ═══════════════════════════════════════════
        """
    }

    public var isHealthy: Bool {
        return issues.isEmpty &&
               tasksWithValidID == totalTasks &&
               tasksWithValidProject == totalTasks &&
               inboxExists
    }
}
