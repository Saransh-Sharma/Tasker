//
//  SavedHomeViewRepositoryProtocol.swift
//  Tasker
//
//  Storage abstraction for Home "saved views" presets
//

import Foundation

public protocol SavedHomeViewRepositoryProtocol {
    func fetchAll(completion: @escaping (Result<[SavedHomeView], Error>) -> Void)
    func save(_ view: SavedHomeView, completion: @escaping (Result<[SavedHomeView], Error>) -> Void)
    func delete(id: UUID, completion: @escaping (Result<[SavedHomeView], Error>) -> Void)
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
