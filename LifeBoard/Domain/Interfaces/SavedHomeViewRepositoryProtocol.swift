//
//  SavedHomeViewRepositoryProtocol.swift
//  Tasker
//
//  Storage abstraction for Home "saved views" presets
//

import Foundation

public protocol SavedHomeViewRepositoryProtocol {
    /// Executes fetchAll.
    func fetchAll(completion: @escaping (Result<[SavedHomeView], Error>) -> Void)
    /// Executes save.
    func save(_ view: SavedHomeView, completion: @escaping (Result<[SavedHomeView], Error>) -> Void)
    /// Executes delete.
    func delete(id: UUID, completion: @escaping (Result<[SavedHomeView], Error>) -> Void)
    /// Executes replaceAll.
    func replaceAll(_ views: [SavedHomeView], completion: @escaping (Result<[SavedHomeView], Error>) -> Void)
}

public enum SavedHomeViewRepositoryError: LocalizedError {
    case encodingFailed
    case decodingFailed

    public var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return "Failed to encode saved Home views"
        case .decodingFailed:
            return "Failed to decode saved Home views"
        }
    }
}
