import Foundation

public final class ManageTagsUseCase: @unchecked Sendable {
    private let repository: TagRepositoryProtocol

    /// Initializes a new instance.
    public init(repository: TagRepositoryProtocol) {
        self.repository = repository
    }

    /// Executes list.
    public func list(completion: @escaping @Sendable (Result<[TagDefinition], Error>) -> Void) {
        repository.fetchAll(completion: completion)
    }

    /// Executes create.
    public func create(name: String, color: String?, icon: String?, completion: @escaping @Sendable (Result<TagDefinition, Error>) -> Void) {
        let tag = TagDefinition(name: name, color: color, icon: icon)
        repository.create(tag, completion: completion)
    }

    /// Executes delete.
    public func delete(id: UUID, completion: @escaping @Sendable (Result<Void, Error>) -> Void) {
        repository.delete(id: id, completion: completion)
    }
}
