import LifeBoardContracts
import LifeBoardDomain
import Foundation
import CoreData
import UIKit

// A caching decorator over `ProjectRepositoryProtocol`. Split out of the
// dependency container, which only ever constructed it.
/// Project repository with caching
final class CachedProjectRepository: ProjectRepositoryProtocol {
    private let repository: ProjectRepositoryProtocol
    private let cache: CacheServiceProtocol

    /// Initializes a new instance.
    init(repository: ProjectRepositoryProtocol, cache: CacheServiceProtocol) {
        self.repository = repository
        self.cache = cache
    }

    // Implement all ProjectRepositoryProtocol methods with caching
    // This is a simplified example

    /// Executes fetchAllProjects.
    func fetchAllProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void) {
        if let cached = cache.getCachedProjects() {
            completion(.success(cached))
            return
        }

        repository.fetchAllProjects { [weak self] result in
            if case .success(let projects) = result {
                self?.cache.cacheProjects(projects)
            }
            completion(result)
        }
    }

    // ... implement other methods similarly

    /// Executes fetchProject.
    func fetchProject(withId id: UUID, completion: @escaping @Sendable (Result<Project?, Error>) -> Void) {
        repository.fetchProject(withId: id, completion: completion)
    }

    /// Executes fetchProject.
    func fetchProject(withName name: String, completion: @escaping @Sendable (Result<Project?, Error>) -> Void) {
        repository.fetchProject(withName: name, completion: completion)
    }

    /// Executes fetchInboxProject.
    func fetchInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        repository.fetchInboxProject(completion: completion)
    }

    /// Executes fetchCustomProjects.
    func fetchCustomProjects(completion: @escaping @Sendable (Result<[Project], Error>) -> Void) {
        repository.fetchCustomProjects(completion: completion)
    }

    /// Executes createProject.
    func createProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        cache.clearAll()
        repository.createProject(project, completion: completion)
    }

    /// Executes ensureInboxProject.
    func ensureInboxProject(completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        repository.ensureInboxProject(completion: completion)
    }

    /// Executes repairProjectIdentityCollisions.
    func repairProjectIdentityCollisions(completion: @escaping @Sendable (Result<ProjectRepairReport, Error>) -> Void) {
        repository.repairProjectIdentityCollisions(completion: completion)
    }

    /// Executes updateProject.
    func updateProject(_ project: Project, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        cache.clearAll()
        repository.updateProject(project, completion: completion)
    }

    /// Executes renameProject.
    func renameProject(withId id: UUID, to newName: String, completion: @escaping @Sendable (Result<Project, Error>) -> Void) {
        cache.clearAll()
        repository.renameProject(withId: id, to: newName, completion: completion)
    }

    /// Executes deleteProject.
    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        cache.clearAll()
        repository.deleteProject(withId: id, deleteTasks: deleteTasks, completion: completion)
    }

    /// Executes getTaskCount.
    func getTaskCount(for projectId: UUID, completion: @escaping @Sendable (Result<Int, Error>) -> Void) {
        repository.getTaskCount(for: projectId, completion: completion)
    }

    /// Executes moveTasks.
    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        cache.clearAll()
        repository.moveTasks(from: sourceProjectId, to: targetProjectId, completion: completion)
    }

    /// Executes moveProjectToLifeArea.
    func moveProjectToLifeArea(
        projectID: UUID,
        lifeAreaID: UUID,
        completion: @escaping @Sendable (Result<ProjectLifeAreaMoveResult, Error>) -> Void
    ) {
        cache.clearAll()
        repository.moveProjectToLifeArea(
            projectID: projectID,
            lifeAreaID: lifeAreaID,
            completion: completion
        )
    }

    /// Executes backfillProjectsWithoutLifeArea.
    func backfillProjectsWithoutLifeArea(
        defaultLifeAreaID: UUID,
        completion: @escaping @Sendable (Result<ProjectLifeAreaBackfillResult, Error>) -> Void
    ) {
        cache.clearAll()
        repository.backfillProjectsWithoutLifeArea(
            defaultLifeAreaID: defaultLifeAreaID,
            completion: completion
        )
    }

    /// Executes isProjectNameAvailable.
    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping @Sendable (Result<Bool, Error>) -> Void) {
        repository.isProjectNameAvailable(name, excludingId: excludingId, completion: completion)
    }
}
