import Foundation

public final class ManageSectionsUseCase {
    private let repository: SectionRepositoryProtocol

    public init(repository: SectionRepositoryProtocol) {
        self.repository = repository
    }

    public func list(projectID: UUID, completion: @escaping (Result<[TaskerProjectSection], Error>) -> Void) {
        repository.fetchSections(projectID: projectID, completion: completion)
    }

    public func create(projectID: UUID, name: String, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void) {
        let section = TaskerProjectSection(projectID: projectID, name: name)
        repository.create(section, completion: completion)
    }

    public func rename(id: UUID, projectID: UUID, name: String, completion: @escaping (Result<TaskerProjectSection, Error>) -> Void) {
        repository.fetchSections(projectID: projectID) { result in
            switch result {
            case .success(let sections):
                guard var target = sections.first(where: { $0.id == id }) else {
                    completion(.failure(NSError(domain: "ManageSectionsUseCase", code: 404)))
                    return
                }
                target.name = name
                target.updatedAt = Date()
                self.repository.update(target, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
