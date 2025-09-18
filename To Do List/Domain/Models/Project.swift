//
//  Project.swift
//  Tasker
//
//  Domain model for Project - Pure Swift, no framework dependencies
//

import Foundation

/// Pure domain model representing a Project
/// This model is independent of any persistence framework
public struct Project {
    // MARK: - Properties
    
    public let id: UUID
    public var name: String
    public var projectDescription: String?
    public var createdDate: Date
    public var modifiedDate: Date
    public var isDefault: Bool
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        name: String,
        projectDescription: String? = nil,
        createdDate: Date = Date(),
        modifiedDate: Date = Date(),
        isDefault: Bool = false
    ) {
        self.id = id
        self.name = name
        self.projectDescription = projectDescription
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.isDefault = isDefault
    }
    
    // MARK: - Factory Methods
    
    /// Create the default "Inbox" project
    public static func createInbox() -> Project {
        return Project(
            name: "Inbox",
            projectDescription: "Default project for uncategorized tasks",
            isDefault: true
        )
    }
    
    // MARK: - Validation
    
    /// Validate the project data
    public func validate() throws {
        if name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw ProjectValidationError.emptyName
        }
        
        if name.count > 100 {
            throw ProjectValidationError.nameTooLong
        }
        
        if let description = projectDescription, description.count > 500 {
            throw ProjectValidationError.descriptionTooLong
        }
    }
}

// MARK: - Validation Errors

public enum ProjectValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case descriptionTooLong
    case duplicateName
    
    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Project name cannot be empty"
        case .nameTooLong:
            return "Project name cannot exceed 100 characters"
        case .descriptionTooLong:
            return "Project description cannot exceed 500 characters"
        case .duplicateName:
            return "A project with this name already exists"
        }
    }
}

// MARK: - Equatable

extension Project: Equatable {
    public static func == (lhs: Project, rhs: Project) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Hashable

extension Project: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
