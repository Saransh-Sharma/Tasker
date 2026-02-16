//
//  ProjectTaskValidator.swift
//  Tasker
//
//  Validator for ensuring data integrity between Projects and Tasks
//  Located in State layer as it directly interacts with CoreData
//

import Foundation
import CoreData

/// Validates referential integrity between tasks and projects
public final class ProjectTaskValidator {

    // MARK: - Properties

    private let persistentContainer: NSPersistentContainer

    // MARK: - Initialization

    public init(persistentContainer: NSPersistentContainer) {
        self.persistentContainer = persistentContainer
    }

    // MARK: - Public Methods

    /// Validate all task-project references
    public func validateAllReferences(completion: @escaping (Result<ValidationReport, Error>) -> Void) {
        let context = persistentContainer.newBackgroundContext()

        context.perform {
            do {
                let report = try self.performValidation(in: context)
                DispatchQueue.main.async {
                    completion(.success(report))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Repair broken references by assigning orphaned tasks to Inbox
    public func repairBrokenReferences(completion: @escaping (Result<RepairReport, Error>) -> Void) {
        let context = persistentContainer.newBackgroundContext()

        context.perform {
            do {
                var tasksRepaired = 0
                var projectsRepaired = 0

                // 1. Find tasks with nil projectID
                let nilProjectIDRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
                nilProjectIDRequest.predicate = NSPredicate(format: "projectID == nil")
                let tasksWithoutProjectID = try context.fetch(nilProjectIDRequest)

                for task in tasksWithoutProjectID {
                    task.projectID = ProjectConstants.inboxProjectID
                    task.project = ProjectConstants.inboxProjectName
                    tasksRepaired += 1
                }

                // 2. Find projects with nil projectID
                let nilProjectRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
                nilProjectRequest.predicate = NSPredicate(format: "projectID == nil")
                let projectsWithoutID = try context.fetch(nilProjectRequest)

                for project in projectsWithoutID {
                    project.projectID = UUID()
                    projectsRepaired += 1
                }

                // 3. Find tasks with invalid projectID (pointing to non-existent project)
                let allProjects = try context.fetch(Projects.fetchRequest()) as [Projects]
                let validProjectIDs = Set(allProjects.compactMap { $0.projectID })

                let allTasks = try context.fetch(NTask.fetchRequest()) as [NTask]
                var orphanedTasks = 0

                for task in allTasks {
                    if let projectID = task.projectID,
                       !validProjectIDs.contains(projectID),
                       projectID != ProjectConstants.inboxProjectID {
                        // Task points to non-existent project
                        task.projectID = ProjectConstants.inboxProjectID
                        task.project = ProjectConstants.inboxProjectName
                        orphanedTasks += 1
                    }
                }

                // Save all repairs
                if tasksRepaired > 0 || projectsRepaired > 0 || orphanedTasks > 0 {
                    try context.save()
                }

                let report = RepairReport(
                    tasksAssignedProjectID: tasksRepaired,
                    projectsAssignedID: projectsRepaired,
                    orphanedTasksReassigned: orphanedTasks,
                    totalRepairs: tasksRepaired + projectsRepaired + orphanedTasks
                )

                DispatchQueue.main.async {
                    completion(.success(report))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    /// Generate detailed data health report
    public func generateDataHealthReport(completion: @escaping (Result<DataHealthReport, Error>) -> Void) {
        let context = persistentContainer.newBackgroundContext()

        context.perform {
            do {
                // Total counts
                let totalTasks = try context.count(for: NTask.fetchRequest())
                let totalProjects = try context.count(for: Projects.fetchRequest())

                // Tasks with valid projectID
                let validTaskIDRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
                validTaskIDRequest.predicate = NSPredicate(format: "projectID != nil")
                let tasksWithValidID = try context.count(for: validTaskIDRequest)

                // Projects with valid projectID
                let validProjectRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
                validProjectRequest.predicate = NSPredicate(format: "projectID != nil")
                let projectsWithValidID = try context.count(for: validProjectRequest)

                // Check for orphaned tasks
                let allProjects = try context.fetch(Projects.fetchRequest()) as [Projects]
                let validProjectIDs = Set(allProjects.compactMap { $0.projectID })
                    .union([ProjectConstants.inboxProjectID])

                let allTasks = try context.fetch(NTask.fetchRequest()) as [NTask]
                var orphanedTasks = 0

                for task in allTasks {
                    if let projectID = task.projectID,
                       !validProjectIDs.contains(projectID),
                       projectID != ProjectConstants.inboxProjectID {
                        orphanedTasks += 1
                    }
                }

                // Check for duplicate project names
                var projectNames: [String: Int] = [:]
                for project in allProjects {
                    if let name = project.projectName?.lowercased() {
                        projectNames[name, default: 0] += 1
                    }
                }
                let duplicateProjectNames = projectNames.filter { $0.value > 1 }.count

                // Check Inbox exists
                let inboxRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
                inboxRequest.predicate = NSPredicate(
                    format: "projectID == %@",
                    ProjectConstants.inboxProjectID as CVarArg
                )
                let inboxExists = try context.count(for: inboxRequest) > 0

                // Build issues list
                var issues: [String] = []

                if tasksWithValidID < totalTasks {
                    issues.append("\(totalTasks - tasksWithValidID) tasks missing projectID")
                }

                if projectsWithValidID < totalProjects {
                    issues.append("\(totalProjects - projectsWithValidID) projects missing projectID")
                }

                if orphanedTasks > 0 {
                    issues.append("\(orphanedTasks) tasks reference non-existent projects")
                }

                if duplicateProjectNames > 0 {
                    issues.append("\(duplicateProjectNames) duplicate project names found")
                }

                if !inboxExists {
                    issues.append("Inbox project does not exist")
                }

                let report = DataHealthReport(
                    totalTasks: totalTasks,
                    tasksWithValidProjectID: tasksWithValidID,
                    totalProjects: totalProjects,
                    projectsWithValidID: projectsWithValidID,
                    orphanedTasks: orphanedTasks,
                    duplicateProjectNames: duplicateProjectNames,
                    inboxExists: inboxExists,
                    issues: issues
                )

                DispatchQueue.main.async {
                    completion(.success(report))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
            }
        }
    }

    // MARK: - Private Methods

    private func performValidation(in context: NSManagedObjectContext) throws -> ValidationReport {
        var issues: [ValidationIssue] = []

        // 1. Check for tasks without projectID
        let taskRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
        taskRequest.predicate = NSPredicate(format: "projectID == nil")
        let tasksWithoutProjectID = try context.fetch(taskRequest)

        for task in tasksWithoutProjectID {
            issues.append(ValidationIssue(
                type: .missingProjectID,
                severity: .critical,
                entity: "Task",
                identifier: task.taskID?.uuidString ?? task.objectID.uriRepresentation().absoluteString,
                description: "Task '\(task.name ?? "Unknown")' has no projectID"
            ))
        }

        // 2. Check for projects without projectID
        let projectRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
        projectRequest.predicate = NSPredicate(format: "projectID == nil")
        let projectsWithoutID = try context.fetch(projectRequest)

        for project in projectsWithoutID {
            issues.append(ValidationIssue(
                type: .missingProjectID,
                severity: .critical,
                entity: "Project",
                identifier: project.objectID.uriRepresentation().absoluteString,
                description: "Project '\(project.projectName ?? "Unknown")' has no projectID"
            ))
        }

        // 3. Check for broken references
        let allProjects = try context.fetch(Projects.fetchRequest()) as [Projects]
        let validProjectIDs = Set(allProjects.compactMap { $0.projectID })

        let allTasks = try context.fetch(NTask.fetchRequest()) as [NTask]

        for task in allTasks {
            if let projectID = task.projectID,
               !validProjectIDs.contains(projectID),
               projectID != ProjectConstants.inboxProjectID {
                issues.append(ValidationIssue(
                    type: .brokenReference,
                    severity: .critical,
                    entity: "Task",
                    identifier: task.taskID?.uuidString ?? task.objectID.uriRepresentation().absoluteString,
                    description: "Task '\(task.name ?? "Unknown")' references non-existent project UUID: \(projectID.uuidString)"
                ))
            }
        }

        // 4. Check for mismatched project string vs UUID
        for task in allTasks {
            if let projectID = task.projectID,
               let projectString = task.project {
                // Find project by UUID
                if let project = allProjects.first(where: { $0.projectID == projectID }),
                   let projectName = project.projectName,
                   projectName.lowercased() != projectString.lowercased() {
                    issues.append(ValidationIssue(
                        type: .mismatchedReference,
                        severity: .warning,
                        entity: "Task",
                        identifier: task.taskID?.uuidString ?? task.objectID.uriRepresentation().absoluteString,
                        description: "Task '\(task.name ?? "Unknown")' has mismatched project: string='\(projectString)' vs UUID points to '\(projectName)'"
                    ))
                }
            }
        }

        return ValidationReport(
            timestamp: Date(),
            totalIssues: issues.count,
            criticalIssues: issues.filter { $0.severity == .critical }.count,
            warningIssues: issues.filter { $0.severity == .warning }.count,
            issues: issues
        )
    }
}

// MARK: - Supporting Types

public struct ValidationReport {
    public let timestamp: Date
    public let totalIssues: Int
    public let criticalIssues: Int
    public let warningIssues: Int
    public let issues: [ValidationIssue]

    public var isHealthy: Bool {
        return totalIssues == 0
    }

    public var description: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium

        var report = """

        ═══════════════════════════════════════════
        Data Validation Report
        ═══════════════════════════════════════════
        Timestamp: \(formatter.string(from: timestamp))
        Total Issues: \(totalIssues)
        Critical: \(criticalIssues)
        Warnings: \(warningIssues)
        Status: \(isHealthy ? "Healthy" : "Issues Found")
        ═══════════════════════════════════════════
        """

        if !issues.isEmpty {
            report += "\n\nIssues:\n"
            for (index, issue) in issues.enumerated() {
                report += "\n\(index + 1). [\(issue.severity)] \(issue.description)"
            }
        }

        return report
    }
}

public struct ValidationIssue {
    public enum IssueType {
        case missingProjectID
        case brokenReference
        case mismatchedReference
        case duplicateName
    }

    public enum Severity {
        case critical
        case warning
        case info
    }

    public let type: IssueType
    public let severity: Severity
    public let entity: String
    public let identifier: String
    public let description: String
}

public struct RepairReport {
    public let tasksAssignedProjectID: Int
    public let projectsAssignedID: Int
    public let orphanedTasksReassigned: Int
    public let totalRepairs: Int

    public var description: String {
        return """

        ═══════════════════════════════════════════
        Data Repair Report
        ═══════════════════════════════════════════
        Tasks assigned projectID: \(tasksAssignedProjectID)
        Projects assigned ID: \(projectsAssignedID)
        Orphaned tasks reassigned: \(orphanedTasksReassigned)
        Total repairs: \(totalRepairs)
        ═══════════════════════════════════════════
        """
    }
}

public struct DataHealthReport {
    public let totalTasks: Int
    public let tasksWithValidProjectID: Int
    public let totalProjects: Int
    public let projectsWithValidID: Int
    public let orphanedTasks: Int
    public let duplicateProjectNames: Int
    public let inboxExists: Bool
    public let issues: [String]

    public var isHealthy: Bool {
        return issues.isEmpty &&
               tasksWithValidProjectID == totalTasks &&
               projectsWithValidID == totalProjects &&
               orphanedTasks == 0 &&
               duplicateProjectNames == 0 &&
               inboxExists
    }

    public var healthScore: Double {
        let taskScore = totalTasks > 0 ? Double(tasksWithValidProjectID) / Double(totalTasks) : 1.0
        let projectScore = totalProjects > 0 ? Double(projectsWithValidID) / Double(totalProjects) : 1.0
        let inboxScore: Double = inboxExists ? 1.0 : 0.0
        let orphanScore = totalTasks > 0 ? 1.0 - (Double(orphanedTasks) / Double(totalTasks)) : 1.0

        return (taskScore + projectScore + inboxScore + orphanScore) / 4.0
    }

    public var description: String {
        let healthPercentage = Int(healthScore * 100)
        let healthEmoji = self.healthEmoji

        var report = """

        ═══════════════════════════════════════════
        Data Health Report
        ═══════════════════════════════════════════
        Health Score: \(healthPercentage)% \(healthEmoji)

        Tasks:
        - Total: \(totalTasks)
        - With valid projectID: \(tasksWithValidProjectID)
        - Orphaned: \(orphanedTasks)

        Projects:
        - Total: \(totalProjects)
        - With valid ID: \(projectsWithValidID)
        - Duplicate names: \(duplicateProjectNames)

        Inbox: \(inboxExists ? "Yes" : "No")
        ═══════════════════════════════════════════
        """

        if !issues.isEmpty {
            report += "\n\nIssues:"
            for issue in issues {
                report += "\n  - \(issue)"
            }
        }

        return report
    }

    private var healthEmoji: String {
        switch healthScore {
        case 1.0: return "Excellent"
        case 0.9..<1.0: return "Good"
        case 0.7..<0.9: return "Fair"
        case 0.5..<0.7: return "Poor"
        default: return "Critical"
        }
    }
}
