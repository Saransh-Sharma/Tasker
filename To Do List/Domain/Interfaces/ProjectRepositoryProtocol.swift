//
//  ProjectRepositoryProtocol.swift
//  Tasker
//
//  Protocol defining the interface for Project data operations
//

import Foundation

public struct ProjectRepairReport {
    public let scanned: Int
    public let merged: Int
    public let deleted: Int
    public let inboxCandidates: Int
    public let warnings: [String]

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

/// Protocol defining all project-related data operations
/// This abstraction allows for different implementations (Core Data, Mock, etc.)
public protocol ProjectRepositoryProtocol {
    
    // MARK: - Fetch Operations
    
    /// Fetch all projects
    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void)
    
    /// Fetch a single project by ID
    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void)
    
    /// Fetch a project by name
    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void)
    
    /// Fetch the default Inbox project
    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void)
    
    /// Fetch custom (non-default) projects
    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void)
    
    // MARK: - Create Operations
    
    /// Create a new project
    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void)
    
    /// Ensure the Inbox project exists (create if needed)
    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void)

    /// Repair malformed project identity rows and deduplicate conflicting IDs.
    func repairProjectIdentityCollisions(completion: @escaping (Result<ProjectRepairReport, Error>) -> Void)
    
    // MARK: - Update Operations
    
    /// Update an existing project
    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void)
    
    /// Rename a project
    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void)
    
    // MARK: - Delete Operations
    
    /// Delete a project (and optionally its tasks)
    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void)
    
    // MARK: - Task Association
    
    /// Get the count of tasks in a project
    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void)
    
    /// Move tasks from one project to another
    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    
    // MARK: - Validation
    
    /// Check if a project name is available
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void)
}
