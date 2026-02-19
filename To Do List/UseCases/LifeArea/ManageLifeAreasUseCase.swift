import Foundation

public final class ManageLifeAreasUseCase {
    private let repository: LifeAreaRepositoryProtocol

    public init(repository: LifeAreaRepositoryProtocol) {
        self.repository = repository
    }

    public func list(completion: @escaping (Result<[LifeArea], Error>) -> Void) {
        repository.fetchAll(completion: completion)
    }

    public func create(name: String, color: String?, icon: String?, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        let model = LifeArea(name: name, color: color, icon: icon)
        repository.create(model, completion: completion)
    }

    public func archive(id: UUID, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        repository.fetchAll { result in
            switch result {
            case .success(let areas):
                guard var area = areas.first(where: { $0.id == id }) else {
                    completion(.failure(NSError(domain: "ManageLifeAreasUseCase", code: 404)))
                    return
                }
                area.isArchived = true
                area.updatedAt = Date()
                self.repository.update(area, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
