//
//  UserDefaultsSavedHomeViewRepository.swift
//  Tasker
//
//  Local persisted implementation for Home saved views (v2)
//

import Foundation

public final class UserDefaultsSavedHomeViewRepository: SavedHomeViewRepositoryProtocol {

    private let defaults: UserDefaults
    private let storageKey: String

    /// Initializes a new instance.
    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = "home.focus.savedViews.v2"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
    }

    /// Executes fetchAll.
    public func fetchAll(completion: @escaping (Result<[SavedHomeView], Error>) -> Void) {
        do {
            let views = try loadViews()
            completion(.success(views.sorted { $0.updatedAt > $1.updatedAt }))
        } catch {
            completion(.failure(error))
        }
    }

    /// Executes save.
    public func save(_ view: SavedHomeView, completion: @escaping (Result<[SavedHomeView], Error>) -> Void) {
        do {
            var views = try loadViews()

            if let index = views.firstIndex(where: { $0.id == view.id }) {
                views[index] = view
            } else {
                views.append(view)
            }

            try persist(views)
            completion(.success(views.sorted { $0.updatedAt > $1.updatedAt }))
        } catch {
            completion(.failure(error))
        }
    }

    /// Executes delete.
    public func delete(id: UUID, completion: @escaping (Result<[SavedHomeView], Error>) -> Void) {
        do {
            var views = try loadViews()
            views.removeAll { $0.id == id }
            try persist(views)
            completion(.success(views.sorted { $0.updatedAt > $1.updatedAt }))
        } catch {
            completion(.failure(error))
        }
    }

    /// Executes replaceAll.
    public func replaceAll(_ views: [SavedHomeView], completion: @escaping (Result<[SavedHomeView], Error>) -> Void) {
        do {
            try persist(views)
            completion(.success(views.sorted { $0.updatedAt > $1.updatedAt }))
        } catch {
            completion(.failure(error))
        }
    }

    /// Executes loadViews.
    private func loadViews() throws -> [SavedHomeView] {
        guard let data = defaults.data(forKey: storageKey) else {
            return []
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        do {
            return try decoder.decode([SavedHomeView].self, from: data)
        } catch {
            throw SavedHomeViewRepositoryError.decodingFailed
        }
    }

    /// Executes persist.
    private func persist(_ views: [SavedHomeView]) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        do {
            let data = try encoder.encode(views)
            defaults.set(data, forKey: storageKey)
        } catch {
            throw SavedHomeViewRepositoryError.encodingFailed
        }
    }
}
