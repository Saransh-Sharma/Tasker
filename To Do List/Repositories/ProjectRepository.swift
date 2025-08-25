import Foundation
import CoreData

/// Protocol defining the contract for any project repository implementation
protocol ProjectRepository {
    /// Fetch projects using an optional predicate and sort descriptors
    func fetchProjects(predicate: NSPredicate?,
                       sortDescriptors: [NSSortDescriptor]?,
                       completion: @escaping ([ProjectData]) -> Void)

    /// Fetch a single project by object ID
    func fetchProject(by projectID: NSManagedObjectID,
                      completion: @escaping (Result<Projects, Error>) -> Void)

    /// Find a project by name (case-insensitive)
    func getProjectByName(_ name: String, completion: @escaping (Projects?) -> Void)

    /// Create a new project
    func addProject(name: String,
                    description: String?,
                    completion: ((Result<Projects, Error>) -> Void)?)

    /// Update an existing project
    func updateProject(projectID: NSManagedObjectID,
                       name: String,
                       description: String?,
                       completion: ((Result<Void, Error>) -> Void)?)

    /// Delete a project. Must not allow deleting the default project.
    func deleteProject(projectID: NSManagedObjectID,
                       completion: ((Result<Void, Error>) -> Void)?)

    /// Ensure the default Inbox project exists and is unique. Returns the primary Inbox project.
    func ensureDefaultInboxExists(completion: ((Result<Projects, Error>) -> Void)?)
}
