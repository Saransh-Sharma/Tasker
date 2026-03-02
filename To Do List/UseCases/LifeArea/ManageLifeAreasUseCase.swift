import Foundation

public final class ManageLifeAreasUseCase {
    private let repository: LifeAreaRepositoryProtocol

    /// Initializes a new instance.
    public init(repository: LifeAreaRepositoryProtocol) {
        self.repository = repository
    }

    /// Executes list.
    public func list(completion: @escaping (Result<[LifeArea], Error>) -> Void) {
        repository.fetchAll(completion: completion)
    }

    /// Executes create.
    public func create(name: String, color: String?, icon: String?, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        let normalizedDisplayName = Self.normalizedDisplayName(name)
        let normalizedKey = Self.normalizedNameKey(name)

        repository.fetchAll { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let areas):
                let hasCollision = areas.contains { area in
                    Self.normalizedNameKey(area.name) == normalizedKey
                }
                guard hasCollision == false else {
                    completion(.failure(NSError(
                        domain: "ManageLifeAreasUseCase",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Life area '\(normalizedDisplayName)' already exists."]
                    )))
                    return
                }

                let model = LifeArea(name: normalizedDisplayName, color: color, icon: icon)
                self.repository.create(model, completion: completion)

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Executes update.
    public func update(
        id: UUID,
        name: String,
        color: String?,
        icon: String?,
        completion: @escaping (Result<LifeArea, Error>) -> Void
    ) {
        let normalizedDisplayName = Self.normalizedDisplayName(name)
        let normalizedKey = Self.normalizedNameKey(name)

        repository.fetchAll { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let areas):
                guard var existing = areas.first(where: { $0.id == id }) else {
                    completion(.failure(NSError(domain: "ManageLifeAreasUseCase", code: 404)))
                    return
                }

                let hasCollision = areas.contains { area in
                    area.id != id && Self.normalizedNameKey(area.name) == normalizedKey
                }
                guard hasCollision == false else {
                    completion(.failure(NSError(
                        domain: "ManageLifeAreasUseCase",
                        code: 409,
                        userInfo: [NSLocalizedDescriptionKey: "Life area '\(normalizedDisplayName)' already exists."]
                    )))
                    return
                }

                existing.name = normalizedDisplayName
                existing.color = color
                existing.icon = icon
                existing.updatedAt = Date()
                self.repository.update(existing, completion: completion)

            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Executes archive.
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

    /// Executes unarchive.
    public func unarchive(id: UUID, completion: @escaping (Result<LifeArea, Error>) -> Void) {
        repository.fetchAll { result in
            switch result {
            case .success(let areas):
                guard var area = areas.first(where: { $0.id == id }) else {
                    completion(.failure(NSError(domain: "ManageLifeAreasUseCase", code: 404)))
                    return
                }
                area.isArchived = false
                area.updatedAt = Date()
                self.repository.update(area, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    /// Executes normalizedDisplayName.
    private static func normalizedDisplayName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "General" : trimmed
    }

    /// Executes normalizedNameKey.
    private static func normalizedNameKey(_ name: String) -> String {
        normalizedDisplayName(name).lowercased()
    }
}
