import Foundation

public final class ManageSectionsUseCase: @unchecked Sendable {
    private let repository: SectionRepositoryProtocol

    /// Initializes a new instance.
    public init(repository: SectionRepositoryProtocol) {
        self.repository = repository
    }

    /// Executes list.
    public func list(projectID: UUID, completion: @escaping @Sendable (Result<[LifeBoardProjectSection], Error>) -> Void) {
        repository.fetchSections(projectID: projectID, completion: completion)
    }

    /// Executes create.
    public func create(projectID: UUID, name: String, completion: @escaping @Sendable (Result<LifeBoardProjectSection, Error>) -> Void) {
        let section = LifeBoardProjectSection(projectID: projectID, name: name)
        repository.create(section, completion: completion)
    }

    /// Executes rename.
    public func rename(id: UUID, projectID: UUID, name: String, completion: @escaping @Sendable (Result<LifeBoardProjectSection, Error>) -> Void) {
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
