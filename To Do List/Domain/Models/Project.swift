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
    
    // MARK: - Enhanced Properties
    
    public var color: ProjectColor
    public var icon: ProjectIcon
    public var status: ProjectStatus
    public var priority: ProjectPriority
    public var parentProjectId: UUID?
    public var subprojectIds: [UUID]
    public var tags: [String]
    public var dueDate: Date?
    public var estimatedTaskCount: Int?
    public var isArchived: Bool
    public var templateId: UUID?
    public var settings: ProjectSettings
    
    // MARK: - Initialization
    
    public init(
        id: UUID = UUID(),
        name: String,
        projectDescription: String? = nil,
        createdDate: Date = Date(),
        modifiedDate: Date = Date(),
        isDefault: Bool = false,
        color: ProjectColor = .blue,
        icon: ProjectIcon = .folder,
        status: ProjectStatus = .active,
        priority: ProjectPriority = .medium,
        parentProjectId: UUID? = nil,
        subprojectIds: [UUID] = [],
        tags: [String] = [],
        dueDate: Date? = nil,
        estimatedTaskCount: Int? = nil,
        isArchived: Bool = false,
        templateId: UUID? = nil,
        settings: ProjectSettings = ProjectSettings()
    ) {
        self.id = id
        self.name = name
        self.projectDescription = projectDescription
        self.createdDate = createdDate
        self.modifiedDate = modifiedDate
        self.isDefault = isDefault
        self.color = color
        self.icon = icon
        self.status = status
        self.priority = priority
        self.parentProjectId = parentProjectId
        self.subprojectIds = subprojectIds
        self.tags = tags
        self.dueDate = dueDate
        self.estimatedTaskCount = estimatedTaskCount
        self.isArchived = isArchived
        self.templateId = templateId
        self.settings = settings
    }
    
    // MARK: - Factory Methods
    
    /// Create the default "Inbox" project
    public static func createInbox() -> Project {
        return Project(
            name: "Inbox",
            projectDescription: "Default project for uncategorized tasks",
            isDefault: true,
            color: .gray,
            icon: .inbox
        )
    }
    
    // MARK: - Business Logic
    
    /// Check if project is overdue
    public var isOverdue: Bool {
        guard let dueDate = dueDate, !isArchived else { return false }
        return dueDate < Date() && status != .completed
    }
    
    /// Check if project is active and not archived
    public var isActive: Bool {
        return status == .active && !isArchived
    }
    
    /// Check if project has subprojects
    public var hasSubprojects: Bool {
        return !subprojectIds.isEmpty
    }
    
    /// Check if this is a subproject
    public var isSubproject: Bool {
        return parentProjectId != nil
    }
    
    /// Calculate project health score based on completion and deadlines
    public func calculateHealthScore(completedTasks: Int, totalTasks: Int) -> ProjectHealth {
        guard totalTasks > 0 else { return .unknown }
        
        let completionRate = Double(completedTasks) / Double(totalTasks)
        
        // Factor in overdue status
        if isOverdue {
            return completionRate > 0.8 ? .warning : .critical
        }
        
        // Factor in due date proximity
        if let dueDate = dueDate {
            let daysUntilDue = Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day ?? 0
            if daysUntilDue <= 3 && completionRate < 0.9 {
                return .warning
            }
        }
        
        // Based on completion rate
        switch completionRate {
        case 0.9...1.0: return .excellent
        case 0.7..<0.9: return .good
        case 0.4..<0.7: return .warning
        default: return .critical
        }
    }
    
    /// Get project hierarchy depth
    public func getHierarchyDepth() -> Int {
        // This would need to be calculated with access to other projects
        // For now, return simple depth based on parent existence
        return parentProjectId != nil ? 1 : 0
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
        
        // Enhanced validation
        if tags.count > 20 {
            throw ProjectValidationError.tooManyTags
        }
        
        if subprojectIds.count > 50 {
            throw ProjectValidationError.tooManySubprojects
        }
        
        // Check for circular reference (simplified)
        if let parentId = parentProjectId, parentId == id {
            throw ProjectValidationError.circularReference
        }
        
        if subprojectIds.contains(id) {
            throw ProjectValidationError.circularReference
        }
    }
}

// MARK: - Validation Errors

public enum ProjectValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case descriptionTooLong
    case duplicateName
    case tooManyTags
    case tooManySubprojects
    case circularReference
    
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
        case .tooManyTags:
            return "Cannot have more than 20 tags"
        case .tooManySubprojects:
            return "Cannot have more than 50 subprojects"
        case .circularReference:
            return "Project cannot reference itself"
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
