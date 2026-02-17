import Foundation

public final class ManageTagsUseCase {
    private let repository: TagRepositoryProtocol

    public init(repository: TagRepositoryProtocol) {
        self.repository = repository
    }

    public func list(completion: @escaping (Result<[TagDefinition], Error>) -> Void) {
        repository.fetchAll(completion: completion)
    }

    public func create(name: String, color: String?, icon: String?, completion: @escaping (Result<TagDefinition, Error>) -> Void) {
        let tag = TagDefinition(name: name, color: color, icon: icon)
        repository.create(tag, completion: completion)
    }

    public func delete(id: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        repository.delete(id: id, completion: completion)
    }
}
