//
//  ProjectRepositoryProtocol.swift
//  Tasker
//
//  Protocol defining the interface for Project data operations
//

import Foundation

public struct ProjectRepairReport: Sendable {
    public let scanned: Int
    public let merged: Int
    public let deleted: Int
    public let inboxCandidates: Int
    public let warnings: [String]

    /// Initializes a new instance.
    public init(
        scanned: Int,
        merged: Int,
        deleted: Int,
        inboxCandidates: Int,
        warnings: [String]
    ) {
        self.scanned = scanned
        self.merged = merged
        self.deleted = deleted
        self.inboxCandidates = inboxCandidates
        self.warnings = warnings
    }
}

public struct ProjectLifeAreaMoveResult: Sendable {
    public let updatedProjectID: UUID
    public let fromLifeAreaID: UUID?
    public let toLifeAreaID: UUID
    public let tasksRemappedCount: Int

    /// Initializes a new instance.
    public init(
        updatedProjectID: UUID,
        fromLifeAreaID: UUID?,
        toLifeAreaID: UUID,
        tasksRemappedCount: Int
    ) {
        self.updatedProjectID = updatedProjectID
        self.fromLifeAreaID = fromLifeAreaID
        self.toLifeAreaID = toLifeAreaID
        self.tasksRemappedCount = tasksRemappedCount
    }
}

public struct ProjectLifeAreaBackfillResult: Sendable {
    public let defaultLifeAreaID: UUID
    public let projectsUpdatedCount: Int
    public let tasksRemappedCount: Int
    public let inboxPinned: Bool

    /// Initializes a new instance.
    public init(
        defaultLifeAreaID: UUID,
        projectsUpdatedCount: Int,
        tasksRemappedCount: Int,
        inboxPinned: Bool
    ) {
        self.defaultLifeAreaID = defaultLifeAreaID
        self.projectsUpdatedCount = projectsUpdatedCount
        self.tasksRemappedCount = tasksRemappedCount
        self.inboxPinned = inboxPinned
    }
}

public struct ProjectRepositoryUnsupportedOperationError: LocalizedError, Sendable {
    public let operation: String

    /// Initializes a new instance.
    public init(operation: String) {
        self.operation = operation
    }

    public var errorDescription: String? {
        "Project repository operation '\(operation)' is not supported by this implementation."
    }
}

/// Protocol defining all project-related data operations
/// This abstraction allows for different implementations (Core Data, Mock, etc.)
public protocol ProjectRepositoryProtocol: Sendable {
    
    // MARK: - Fetch Operations
    
    /// Fetch all projects
    func fetchAllProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void)
    
    /// Fetch a single project by ID
    func fetchProject(withId id: UUID, completion: @escaping @Sendable (Result<Project?, Error>) -> Void)
    
    /// Fetch a project by name
    func fetchProject(withName name: String, completion: @escaping @Sendable (Result<Project?, Error>) -> Void)
    
    /// Fetch the default Inbox project
    func fetchInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void)
    
    /// Fetch custom (non-default) projects
    func fetchCustomProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void)
    
    // MARK: - Create Operations
    
    /// Create a new project
    func createProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void)
    
    /// Ensure the Inbox project exists (create if needed)
    func ensureInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void)

    /// Repair malformed project identity rows and deduplicate conflicting IDs.
    func repairProjectIdentityCollisions(completion: @escaping @Sendable (Result<ProjectRepairReport, Error>) -> Void)
    
    // MARK: - Update Operations
    
    /// Update an existing project
    func updateProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void)
    
    /// Rename a project
    func renameProject(withId id: UUID, to newName: String, completion: @escaping @Sendable (Result<Project, Error>) -> Void)
    
    // MARK: - Delete Operations
    
    /// Delete a project (and optionally its tasks)
    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping @Sendable (Result<Void, Error>) -> Void)
    
    // MARK: - Task Association
    
    /// Get the count of tasks in a project
    func getTaskCount(for projectId: UUID, completion: @escaping @Sendable (Result<Int, Error>) -> Void)
    
    /// Move tasks from one project to another
    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void)

    // MARK: - Life Area Association

    /// Move a project under another life area and remap all tasks under the project.
    func moveProjectToLifeArea(
        projectID: UUID,
        lifeAreaID: UUID,
        completion: @escaping @Sendable (Result<ProjectLifeAreaMoveResult, Error>) -> Void
    )

    /// Assign projects without a life-area linkage to a default life area.
    func backfillProjectsWithoutLifeArea(
        defaultLifeAreaID: UUID,
        completion: @escaping @Sendable (Result<ProjectLifeAreaBackfillResult, Error>) -> Void
    )
    
    // MARK: - Validation
    
    /// Check if a project name is available
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping @Sendable (Result<Bool, Error>) -> Void)
}

public extension ProjectRepositoryProtocol {
    func moveProjectToLifeArea(
        projectID: UUID,
        lifeAreaID: UUID,
        completion: @escaping @Sendable (Result<ProjectLifeAreaMoveResult, Error>) -> Void
    ) {
        completion(.failure(ProjectRepositoryUnsupportedOperationError(operation: "moveProjectToLifeArea")))
    }

    func backfillProjectsWithoutLifeArea(
        defaultLifeAreaID: UUID,
        completion: @escaping @Sendable (Result<ProjectLifeAreaBackfillResult, Error>) -> Void
    ) {
        completion(.failure(ProjectRepositoryUnsupportedOperationError(operation: "backfillProjectsWithoutLifeArea")))
    }
}
