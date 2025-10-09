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

    /// Migrate task→project references from strings to UUIDs
    /// Links tasks that have project string but projectID == nil to their actual project UUID
    public func migrateTaskProjectReferences(completion: @escaping (Result<MigrationReferenceReport, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }

            do {
                var tasksMigrated = 0
                var tasksWithMissingProject = 0
                var projectsCreated = 0

                // Fetch all tasks that have a project string but no projectID
                let taskFetchRequest = NTask.fetchRequest()
                taskFetchRequest.predicate = NSPredicate(format: "projectID == nil AND project != nil")

                let tasksNeedingMigration = try self.backgroundContext.fetch(taskFetchRequest)

                print("🔄 Found \(tasksNeedingMigration.count) tasks needing project UUID migration")

                // Build a cache of project names → project UUIDs for efficiency
                let allProjectsRequest = Projects.fetchRequest()
                let allProjects = try self.backgroundContext.fetch(allProjectsRequest)

                var projectCache: [String: UUID] = [:]
                for project in allProjects {
                    if let name = project.projectName?.lowercased(), let id = project.projectID {
                        projectCache[name] = id
                    }
                }

                // Process each task
                for task in tasksNeedingMigration {
                    guard let projectName = task.project else { continue }

                    let normalizedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                    // Check if this is the Inbox project (case-insensitive)
                    if normalizedName == ProjectConstants.inboxProjectName.lowercased() {
                        task.projectID = ProjectConstants.inboxProjectID
                        task.project = ProjectConstants.inboxProjectName
                        tasksMigrated += 1
                        continue
                    }

                    // Look up project UUID from cache
                    if let projectID = projectCache[normalizedName] {
                        task.projectID = projectID
                        tasksMigrated += 1
                        print("  ✅ Linked task '\(task.name ?? "Unknown")' to project UUID")
                    } else {
                        // Project doesn't exist in Projects entity - need to create it
                        print("  ⚠️ Creating missing project: '\(projectName)'")

                        let newProject = Projects(context: self.backgroundContext)
                        let newProjectID = UUID()
                        newProject.projectID = newProjectID
                        newProject.projectName = projectName
                        newProject.projecDescription = "Migrated from legacy data"

                        // Update cache and task
                        projectCache[normalizedName] = newProjectID
                        task.projectID = newProjectID

                        projectsCreated += 1
                        tasksMigrated += 1
                    }
                }

                // Now handle tasks with no project at all (projectID == nil AND project == nil)
                let orphanedTasksRequest = NTask.fetchRequest()
                orphanedTasksRequest.predicate = NSPredicate(format: "projectID == nil AND project == nil")
                let orphanedTasks = try self.backgroundContext.fetch(orphanedTasksRequest)

                for task in orphanedTasks {
                    task.projectID = ProjectConstants.inboxProjectID
                    task.project = ProjectConstants.inboxProjectName
                    tasksWithMissingProject += 1
                }

                // Save all changes
                if tasksMigrated > 0 || tasksWithMissingProject > 0 || projectsCreated > 0 {
                    try self.backgroundContext.save()
                    print("✅ Migration saved: \(tasksMigrated) tasks migrated, \(projectsCreated) projects created")
                }

                let report = MigrationReferenceReport(
                    tasksMigrated: tasksMigrated,
                    tasksAssignedToInbox: tasksWithMissingProject,
                    projectsCreated: projectsCreated
                )

                completion(.success(report))
            } catch {
                print("❌ Migration failed: \(error)")
                completion(.failure(error))
            }
        }
    }

    /// Clean up duplicate projects from the database
    /// Removes duplicate Inbox projects (keeps only one with correct UUID)
    /// Removes duplicate custom projects by name (keeps the first one found)
    public func cleanupDuplicateProjects(completion: @escaping (Result<CleanupReport, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }

            do {
                var inboxDuplicatesRemoved = 0
                var customDuplicatesRemoved = 0

                // 1. Clean up duplicate Inbox projects
                let inboxFetchRequest = Projects.fetchRequest()
                inboxFetchRequest.predicate = NSPredicate(
                    format: "projectName ==[c] %@",
                    ProjectConstants.inboxProjectName
                )

                let inboxProjects = try self.backgroundContext.fetch(inboxFetchRequest)

                if inboxProjects.count > 1 {
                    // Keep only the one with the correct UUID, or the first one if none match
                    var projectToKeep: Projects?

                    // First, try to find one with the correct UUID
                    projectToKeep = inboxProjects.first { $0.projectID == ProjectConstants.inboxProjectID }

                    // If no project has the correct UUID, keep the first one and update its UUID
                    if projectToKeep == nil {
                        projectToKeep = inboxProjects.first
                        projectToKeep?.projectID = ProjectConstants.inboxProjectID
                        projectToKeep?.projectName = ProjectConstants.inboxProjectName
                        projectToKeep?.projecDescription = ProjectConstants.inboxProjectDescription
                    }

                    // Delete all other Inbox projects
                    for project in inboxProjects {
                        if project.objectID != projectToKeep?.objectID {
                            self.backgroundContext.delete(project)
                            inboxDuplicatesRemoved += 1
                        }
                    }
                }

                // 2. Clean up duplicate custom projects
                let allProjectsFetchRequest = Projects.fetchRequest()
                let allProjects = try self.backgroundContext.fetch(allProjectsFetchRequest)

                // Group projects by name (case-insensitive)
                var projectsByName: [String: [Projects]] = [:]
                for project in allProjects {
                    let name = project.projectName?.lowercased() ?? ""
                    if !name.isEmpty && name != ProjectConstants.inboxProjectName.lowercased() {
                        if projectsByName[name] == nil {
                            projectsByName[name] = []
                        }
                        projectsByName[name]?.append(project)
                    }
                }

                // For each group with duplicates, keep only the first one
                for (_, projects) in projectsByName {
                    if projects.count > 1 {
                        // Keep the first project (or the one with UUID if available)
                        let projectToKeep = projects.first { $0.projectID != nil } ?? projects.first

                        // Delete all others
                        for project in projects {
                            if project.objectID != projectToKeep?.objectID {
                                self.backgroundContext.delete(project)
                                customDuplicatesRemoved += 1
                            }
                        }
                    }
                }

                // Save changes if any duplicates were removed
                if inboxDuplicatesRemoved > 0 || customDuplicatesRemoved > 0 {
                    try self.backgroundContext.save()
                }

                let report = CleanupReport(
                    inboxDuplicatesRemoved: inboxDuplicatesRemoved,
                    customDuplicatesRemoved: customDuplicatesRemoved
                )

                completion(.success(report))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// Perform complete initialization: ensure Inbox exists, generate UUIDs, migrate references, assign orphaned tasks, and cleanup duplicates
    public func performCompleteInitialization(completion: @escaping (Result<InitializationReport, Error>) -> Void) {
        // First, cleanup duplicates
        cleanupDuplicateProjects { [weak self] cleanupResult in
            guard let self = self else { return }

            switch cleanupResult {
            case .success(let cleanupReport):
                print("🧹 Cleanup completed: \(cleanupReport.description)")

                // Then proceed with regular initialization
                self.ensureInboxExists { result in
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
                                        // Projects have UUIDs, now migrate task→project references
                                        self.migrateTaskProjectReferences { migrationResult in
                                            switch migrationResult {
                                            case .success(let migrationReport):
                                                // References migrated, now assign any remaining orphaned tasks
                                                self.assignOrphanedTasksToInbox { orphanedResult in
                                                    switch orphanedResult {
                                                    case .success(let orphanedCount):
                                                        let report = InitializationReport(
                                                            inboxCreated: true,
                                                            tasksAssignedUUIDs: tasksUpdated,
                                                            projectsAssignedUUIDs: projectsUpdated,
                                                            tasksAssignedToInbox: orphanedCount,
                                                            cleanupReport: cleanupReport,
                                                            migrationReport: migrationReport
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
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            case .failure(let error):
                print("❌ Cleanup failed: \(error)")
                // Continue with initialization even if cleanup fails
                self.ensureInboxExists { result in
                    switch result {
                    case .success:
                        self.ensureAllTasksHaveUUIDs { taskUUIDResult in
                            switch taskUUIDResult {
                            case .success(let tasksUpdated):
                                self.ensureAllProjectsHaveUUIDs { projectUUIDResult in
                                    switch projectUUIDResult {
                                    case .success(let projectsUpdated):
                                        self.migrateTaskProjectReferences { migrationResult in
                                            switch migrationResult {
                                            case .success(let migrationReport):
                                                self.assignOrphanedTasksToInbox { orphanedResult in
                                                    switch orphanedResult {
                                                    case .success(let orphanedCount):
                                                        let report = InitializationReport(
                                                            inboxCreated: true,
                                                            tasksAssignedUUIDs: tasksUpdated,
                                                            projectsAssignedUUIDs: projectsUpdated,
                                                            tasksAssignedToInbox: orphanedCount,
                                                            cleanupReport: nil,
                                                            migrationReport: migrationReport
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
                    case .failure(let error):
                        completion(.failure(error))
                    }
                }
            }
        }
    }

    /// 🔥 EMERGENCY: Force UUID assignment for ALL projects that don't have them
    /// This is a critical fix for when migration state is corrupted but projects still lack UUIDs
    public func forceAssignUUIDsToAllProjects(completion: @escaping (Result<Int, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }

            do {
                // 🔥 EMERGENCY: Get ALL projects without UUIDs
                let request: NSFetchRequest<Projects> = Projects.fetchRequest()
                request.predicate = NSPredicate(format: "projectID == nil")

                let projectsWithoutUUIDs = try self.backgroundContext.fetch(request)
                print("🚨 EMERGENCY: Found \(projectsWithoutUUIDs.count) projects without UUIDs")

                var updatedCount = 0

                for project in projectsWithoutUUIDs {
                    let generatedUUID = UUID()
                    project.projectID = generatedUUID
                    print("  ✅ Assigned UUID \(generatedUUID) to project: \(project.projectName ?? "Unknown")")
                    updatedCount += 1
                }

                if updatedCount > 0 {
                    try self.backgroundContext.save()
                    print("💾 Saved \(updatedCount) projects with new UUIDs")
                } else {
                    print("✅ All projects already have UUIDs")
                }

                completion(.success(updatedCount))
            } catch {
                print("❌ Emergency UUID assignment failed: \(error)")
                completion(.failure(error))
            }
        }
    }

    /// 🔥 EMERGENCY: Force update task project references to use UUIDs
    /// This fixes all tasks with nil projectID that have a project string
    public func forceUpdateTaskProjectReferences(completion: @escaping (Result<Int, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }

            do {
                // 🔥 EMERGENCY: Fix all tasks with nil projectID that have a project string
                let request: NSFetchRequest<NTask> = NTask.fetchRequest()
                request.predicate = NSPredicate(format: "projectID == nil AND project != nil")

                let tasksNeedingUpdate = try self.backgroundContext.fetch(request)
                print("🚨 EMERGENCY: Found \(tasksNeedingUpdate.count) tasks needing UUID references")

                // Get all projects with UUIDs for lookup
                let projectRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
                projectRequest.predicate = NSPredicate(format: "projectID != nil")
                let projectsWithUUIDs = try self.backgroundContext.fetch(projectRequest)

                // Create name -> UUID lookup
                var projectLookup: [String: UUID] = [:]
                for project in projectsWithUUIDs {
                    if let name = project.projectName?.lowercased(), let uuid = project.projectID {
                        projectLookup[name] = uuid
                    }
                }

                var updatedTasks = 0

                for task in tasksNeedingUpdate {
                    guard let projectName = task.project?.lowercased() else { continue }

                    if let projectUUID = projectLookup[projectName] {
                        task.projectID = projectUUID
                        updatedTasks += 1
                        print("  ✅ Updated task '\(task.name ?? "Unknown")' to reference UUID")
                    } else {
                        // Assign to Inbox if project not found
                        task.projectID = ProjectConstants.inboxProjectID
                        task.project = ProjectConstants.inboxProjectName
                        updatedTasks += 1
                        print("  📥 Assigned task '\(task.name ?? "Unknown")' to Inbox")
                    }
                }

                if updatedTasks > 0 {
                    try self.backgroundContext.save()
                    print("💾 Saved \(updatedTasks) updated task references")
                } else {
                    print("✅ All task references already updated")
                }

                completion(.success(updatedTasks))
            } catch {
                print("❌ Emergency task reference update failed: \(error)")
                completion(.failure(error))
            }
        }
    }

    /// Ensure ALL project strings referenced by tasks have corresponding Projects entities
    /// This is critical for maintaining data integrity between legacy string-based projects and UUID-based Projects entities
    public func ensureAllProjectsHaveEntities(completion: @escaping (Result<ProjectEntityReport, Error>) -> Void) {
        backgroundContext.perform { [weak self] in
            guard let self = self else { return }

            do {
                var entitiesCreated = 0
                var existingEntities = 0

                // 1. Get all unique project strings from tasks
                let taskFetchRequest = NTask.fetchRequest()
                let allTasks = try self.backgroundContext.fetch(taskFetchRequest)

                let projectNames = allTasks.compactMap { $0.project }
                let uniqueProjectNames = Array(Set(projectNames))

                print("📊 Found \(uniqueProjectNames.count) unique project names in tasks")

                // 2. For each unique project name, ensure a Projects entity exists
                for projectName in uniqueProjectNames {
                    let normalizedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)

                    // Check if Projects entity exists for this name
                    let projectFetchRequest = Projects.fetchRequest()
                    projectFetchRequest.predicate = NSPredicate(format: "projectName ==[c] %@", normalizedName)
                    projectFetchRequest.fetchLimit = 1

                    let existingProjects = try self.backgroundContext.fetch(projectFetchRequest)

                    if existingProjects.isEmpty {
                        // Create new Projects entity
                        let newProject = Projects(context: self.backgroundContext)

                        // Special handling for Inbox
                        if normalizedName.lowercased() == "inbox" {
                            newProject.projectID = ProjectConstants.inboxProjectID
                            newProject.projectName = ProjectConstants.inboxProjectName
                            newProject.projecDescription = ProjectConstants.inboxProjectDescription
                        } else {
                            newProject.projectID = UUID()
                            newProject.projectName = normalizedName
                            newProject.projecDescription = "Created from legacy task data"
                        }

                        entitiesCreated += 1
                        print("  ✅ Created Projects entity for: '\(normalizedName)'")
                    } else {
                        existingEntities += 1
                    }
                }

                // 3. Save all changes
                if entitiesCreated > 0 {
                    try self.backgroundContext.save()
                    print("💾 Saved \(entitiesCreated) new Projects entities")
                }

                let report = ProjectEntityReport(
                    entitiesCreated: entitiesCreated,
                    existingEntities: existingEntities,
                    totalProjectNames: uniqueProjectNames.count
                )

                completion(.success(report))
            } catch {
                print("❌ Failed to ensure project entities: \(error)")
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
    public let cleanupReport: CleanupReport?
    public let migrationReport: MigrationReferenceReport?

    public var description: String {
        var report = """
        Initialization Report:
        - Inbox: \(inboxCreated ? "Created/Verified" : "Failed")
        - Tasks assigned UUIDs: \(tasksAssignedUUIDs)
        - Projects assigned UUIDs: \(projectsAssignedUUIDs)
        - Tasks assigned to Inbox: \(tasksAssignedToInbox)
        """

        if let cleanupReport = cleanupReport {
            report += "\n\(cleanupReport.description)"
        }

        if let migrationReport = migrationReport {
            report += "\n\(migrationReport.description)"
        }

        return report
    }
}

// MARK: - Cleanup Report

public struct CleanupReport {
    public let inboxDuplicatesRemoved: Int
    public let customDuplicatesRemoved: Int

    public var description: String {
        return """
        Cleanup Report:
        - Inbox duplicates removed: \(inboxDuplicatesRemoved)
        - Custom project duplicates removed: \(customDuplicatesRemoved)
        """
    }
}

// MARK: - Migration Reference Report

public struct MigrationReferenceReport {
    public let tasksMigrated: Int
    public let tasksAssignedToInbox: Int
    public let projectsCreated: Int

    public var description: String {
        return """
        Task→Project Migration Report:
        - Tasks linked to project UUIDs: \(tasksMigrated)
        - Orphaned tasks assigned to Inbox: \(tasksAssignedToInbox)
        - Missing projects created: \(projectsCreated)
        """
    }

    public var wasSuccessful: Bool {
        return true // Any completion is successful
    }
}

// MARK: - Project Entity Report

public struct ProjectEntityReport {
    public let entitiesCreated: Int
    public let existingEntities: Int
    public let totalProjectNames: Int

    public var description: String {
        return """
        Project Entity Synchronization Report:
        - Projects entities created: \(entitiesCreated)
        - Existing entities found: \(existingEntities)
        - Total unique project names: \(totalProjectNames)
        """
    }

    public var wasSuccessful: Bool {
        return entitiesCreated + existingEntities == totalProjectNames
    }
}
