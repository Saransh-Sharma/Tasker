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
    private let migrationManager: MigrationManager

    // MARK: - Initialization

    public init(persistentContainer: NSPersistentContainer, migrationManager: MigrationManager = MigrationManager()) {
        self.persistentContainer = persistentContainer
        self.inboxInitializer = InboxProjectInitializer(
            viewContext: persistentContainer.viewContext,
            backgroundContext: persistentContainer.newBackgroundContext()
        )
        self.migrationManager = migrationManager
    }

    // MARK: - Public Methods

    /// Perform complete data migration to UUID-based system with version tracking
    public func migrateToUUIDs(completion: @escaping (Result<MigrationReport, Error>) -> Void) {
        // Check if migration is needed
        guard migrationManager.needsMigration() else {
            print("✅ No migration needed. Current version: \(migrationManager.currentVersion().description)")
            let report = MigrationReport(
                tasksProcessed: 0,
                projectsProcessed: 0,
                tasksAssignedToInbox: 0,
                tasksMigrated: 0,
                projectsCreated: 0,
                inboxCreated: false,
                errors: [],
                duration: 0,
                versionBefore: migrationManager.currentVersion(),
                versionAfter: migrationManager.currentVersion()
            )
            completion(.success(report))
            return
        }

        let versionBefore = migrationManager.currentVersion()
        let plan = migrationManager.generateMigrationPlan()

        print("🔄 Starting UUID migration...")
        print(plan.description)

        let startTime = Date()

        // Use the inbox initializer to perform complete initialization
        inboxInitializer.performCompleteInitialization { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let initReport):
                let duration = Date().timeIntervalSince(startTime)

                // Update migration version to reflect completion
                self.migrationManager.setCurrentVersion(.referenceMigrated)

                let report = MigrationReport(
                    tasksProcessed: initReport.tasksAssignedUUIDs,
                    projectsProcessed: initReport.projectsAssignedUUIDs,
                    tasksAssignedToInbox: initReport.tasksAssignedToInbox,
                    tasksMigrated: initReport.migrationReport?.tasksMigrated ?? 0,
                    projectsCreated: initReport.migrationReport?.projectsCreated ?? 0,
                    inboxCreated: initReport.inboxCreated,
                    errors: [],
                    duration: duration,
                    versionBefore: versionBefore,
                    versionAfter: self.migrationManager.currentVersion()
                )

                print("✅ Migration completed successfully in \(String(format: "%.2f", duration))s")
                print(report.description)

                completion(.success(report))

            case .failure(let error):
                print("❌ Migration failed: \(error)")
                let duration = Date().timeIntervalSince(startTime)

                let report = MigrationReport(
                    tasksProcessed: 0,
                    projectsProcessed: 0,
                    tasksAssignedToInbox: 0,
                    tasksMigrated: 0,
                    projectsCreated: 0,
                    inboxCreated: false,
                    errors: [error.localizedDescription],
                    duration: duration,
                    versionBefore: versionBefore,
                    versionAfter: self.migrationManager.currentVersion()
                )

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
    public let tasksMigrated: Int
    public let projectsCreated: Int
    public let inboxCreated: Bool
    public let errors: [String]
    public let duration: TimeInterval
    public let versionBefore: MigrationVersion
    public let versionAfter: MigrationVersion

    public var description: String {
        return """

        ═══════════════════════════════════════════
        📊 Migration Report
        ═══════════════════════════════════════════
        Version: \(versionBefore.description) → \(versionAfter.description)
        Tasks assigned UUIDs: \(tasksProcessed)
        Projects assigned UUIDs: \(projectsProcessed)
        Tasks linked to project UUIDs: \(tasksMigrated)
        Projects created from legacy data: \(projectsCreated)
        Tasks assigned to Inbox: \(tasksAssignedToInbox)
        Inbox: \(inboxCreated ? "✅ Created" : "⚠️ Already existed")
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
