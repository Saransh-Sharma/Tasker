//
//  UserRepositoryProtocol.swift
//  Tasker
//
//  Protocol defining the interface for User data operations
//

import Foundation

/// Protocol defining all user-related data operations
/// This abstraction allows for different implementations (Core Data, Mock, etc.)
public protocol UserRepositoryProtocol {
    
    // MARK: - Fetch Operations
    
    /// Fetch a single user by ID
    func fetchUser(_ userId: UUID, completion: @escaping (Result<User, Error>) -> Void)
    
    /// Fetch multiple users by IDs
    func fetchUsers(_ userIds: [UUID], completion: @escaping (Result<[User], Error>) -> Void)
    
    /// Fetch all users
    func fetchAllUsers(completion: @escaping (Result<[User], Error>) -> Void)
    
    /// Fetch users by email
    func fetchUser(byEmail email: String, completion: @escaping (Result<User?, Error>) -> Void)
    
    /// Search users by name or email
    func searchUsers(query: String, completion: @escaping (Result<[User], Error>) -> Void)
    
    /// Fetch users with specific collaboration level
    func fetchUsers(withCollaborationLevel level: CollaborationLevel, completion: @escaping (Result<[User], Error>) -> Void)
    
    /// Fetch online users
    func fetchOnlineUsers(completion: @escaping (Result<[User], Error>) -> Void)
    
    // MARK: - Create Operations
    
    /// Create a new user
    func createUser(_ user: User, completion: @escaping (Result<User, Error>) -> Void)
    
    // MARK: - Update Operations
    
    /// Update an existing user
    func updateUser(_ user: User, completion: @escaping (Result<User, Error>) -> Void)
    
    /// Update user preferences
    func updateUserPreferences(userId: UUID, preferences: UserPreferences, completion: @escaping (Result<User, Error>) -> Void)
    
    /// Update user notification settings
    func updateNotificationSettings(userId: UUID, settings: NotificationSettings, completion: @escaping (Result<User, Error>) -> Void)
    
    /// Update user availability
    func updateUserAvailability(userId: UUID, availability: UserAvailability, completion: @escaping (Result<User, Error>) -> Void)
    
    /// Update user last seen timestamp
    func updateLastSeen(userId: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// Update user collaboration level
    func updateCollaborationLevel(userId: UUID, level: CollaborationLevel, completion: @escaping (Result<User, Error>) -> Void)
    
    // MARK: - Delete Operations
    
    /// Delete a user (soft delete - mark as inactive)
    func deleteUser(userId: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    
    /// Permanently delete a user and all associated data
    func permanentlyDeleteUser(userId: UUID, completion: @escaping (Result<Void, Error>) -> Void)
    
    // MARK: - Batch Operations
    
    /// Create multiple users
    func createUsers(_ users: [User], completion: @escaping (Result<[User], Error>) -> Void)
    
    /// Update multiple users
    func updateUsers(_ users: [User], completion: @escaping (Result<[User], Error>) -> Void)
}