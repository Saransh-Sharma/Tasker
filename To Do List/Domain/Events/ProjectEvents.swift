//
//  ProjectEvents.swift
//  Tasker
//
//  Domain events related to Project operations
//

import Foundation

// MARK: - Project Domain Events

/// Event fired when a project is created
public struct ProjectCreatedEvent: SerializableDomainEvent {
    public let id: UUID
    public let occurredAt: Date
    public let eventType: String = "ProjectCreated"
    public let eventVersion: Int = 1
    public let aggregateId: UUID
    public let userId: UUID?
    
    // Project-specific data
    public let projectName: String
    public let projectDescription: String?
    public let color: ProjectColor
    public let icon: ProjectIcon
    public let parentProjectId: UUID?
    
    public init(
        projectId: UUID,
        projectName: String,
        projectDescription: String?,
        color: ProjectColor,
        icon: ProjectIcon,
        parentProjectId: UUID? = nil,
        userId: UUID? = nil
    ) {
        self.id = UUID()
        self.occurredAt = Date()
        self.aggregateId = projectId
        self.userId = userId
        self.projectName = projectName
        self.projectDescription = projectDescription
        self.color = color
        self.icon = icon
        self.parentProjectId = parentProjectId
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "occurredAt": occurredAt.timeIntervalSince1970,
            "eventType": eventType,
            "eventVersion": eventVersion,
            "aggregateId": aggregateId.uuidString,
            "projectName": projectName,
            "color": color.rawValue,
            "icon": icon.rawValue
        ]
        
        if let userId = userId {
            dict["userId"] = userId.uuidString
        }
        if let projectDescription = projectDescription {
            dict["projectDescription"] = projectDescription
        }
        if let parentProjectId = parentProjectId {
            dict["parentProjectId"] = parentProjectId.uuidString
        }
        
        return dict
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> ProjectCreatedEvent? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let occurredAtInterval = dict["occurredAt"] as? TimeInterval,
              let aggregateIdString = dict["aggregateId"] as? String,
              let aggregateId = UUID(uuidString: aggregateIdString),
              let projectName = dict["projectName"] as? String,
              let colorRaw = dict["color"] as? String,
              let color = ProjectColor(rawValue: colorRaw),
              let iconRaw = dict["icon"] as? String,
              let icon = ProjectIcon(rawValue: iconRaw) else {
            return nil
        }
        
        let userId = dict["userId"] as? String != nil ? UUID(uuidString: dict["userId"] as! String) : nil
        let projectDescription = dict["projectDescription"] as? String
        let parentProjectId = dict["parentProjectId"] as? String != nil ? UUID(uuidString: dict["parentProjectId"] as! String) : nil
        
        return ProjectCreatedEvent(
            projectId: aggregateId,
            projectName: projectName,
            projectDescription: projectDescription,
            color: color,
            icon: icon,
            parentProjectId: parentProjectId,
            userId: userId
        )
    }
}

/// Event fired when a project is updated
public struct ProjectUpdatedEvent: SerializableDomainEvent {
    public let id: UUID
    public let occurredAt: Date
    public let eventType: String = "ProjectUpdated"
    public let eventVersion: Int = 1
    public let aggregateId: UUID
    public let userId: UUID?
    
    // Update data
    public let changedFields: [String]
    public let oldValues: [String: Any]
    public let newValues: [String: Any]
    
    public init(
        projectId: UUID,
        changedFields: [String],
        oldValues: [String: Any],
        newValues: [String: Any],
        userId: UUID? = nil
    ) {
        self.id = UUID()
        self.occurredAt = Date()
        self.aggregateId = projectId
        self.userId = userId
        self.changedFields = changedFields
        self.oldValues = oldValues
        self.newValues = newValues
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "occurredAt": occurredAt.timeIntervalSince1970,
            "eventType": eventType,
            "eventVersion": eventVersion,
            "aggregateId": aggregateId.uuidString,
            "changedFields": changedFields,
            "oldValues": oldValues,
            "newValues": newValues
        ]
        
        if let userId = userId {
            dict["userId"] = userId.uuidString
        }
        
        return dict
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> ProjectUpdatedEvent? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let occurredAtInterval = dict["occurredAt"] as? TimeInterval,
              let aggregateIdString = dict["aggregateId"] as? String,
              let aggregateId = UUID(uuidString: aggregateIdString),
              let changedFields = dict["changedFields"] as? [String],
              let oldValues = dict["oldValues"] as? [String: Any],
              let newValues = dict["newValues"] as? [String: Any] else {
            return nil
        }
        
        let userId = dict["userId"] as? String != nil ? UUID(uuidString: dict["userId"] as! String) : nil
        
        return ProjectUpdatedEvent(
            projectId: aggregateId,
            changedFields: changedFields,
            oldValues: oldValues,
            newValues: newValues,
            userId: userId
        )
    }
}

/// Event fired when a project is archived
public struct ProjectArchivedEvent: SerializableDomainEvent {
    public let id: UUID
    public let occurredAt: Date
    public let eventType: String = "ProjectArchived"
    public let eventVersion: Int = 1
    public let aggregateId: UUID
    public let userId: UUID?
    
    // Archive context
    public let projectName: String
    public let reason: String?
    public let taskCount: Int
    
    public init(
        projectId: UUID,
        projectName: String,
        reason: String? = nil,
        taskCount: Int = 0,
        userId: UUID? = nil
    ) {
        self.id = UUID()
        self.occurredAt = Date()
        self.aggregateId = projectId
        self.userId = userId
        self.projectName = projectName
        self.reason = reason
        self.taskCount = taskCount
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "occurredAt": occurredAt.timeIntervalSince1970,
            "eventType": eventType,
            "eventVersion": eventVersion,
            "aggregateId": aggregateId.uuidString,
            "projectName": projectName,
            "taskCount": taskCount
        ]
        
        if let userId = userId {
            dict["userId"] = userId.uuidString
        }
        if let reason = reason {
            dict["reason"] = reason
        }
        
        return dict
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> ProjectArchivedEvent? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let occurredAtInterval = dict["occurredAt"] as? TimeInterval,
              let aggregateIdString = dict["aggregateId"] as? String,
              let aggregateId = UUID(uuidString: aggregateIdString),
              let projectName = dict["projectName"] as? String,
              let taskCount = dict["taskCount"] as? Int else {
            return nil
        }
        
        let userId = dict["userId"] as? String != nil ? UUID(uuidString: dict["userId"] as! String) : nil
        let reason = dict["reason"] as? String
        
        return ProjectArchivedEvent(
            projectId: aggregateId,
            projectName: projectName,
            reason: reason,
            taskCount: taskCount,
            userId: userId
        )
    }
}

/// Event fired when a project is deleted
public struct ProjectDeletedEvent: SerializableDomainEvent {
    public let id: UUID
    public let occurredAt: Date
    public let eventType: String = "ProjectDeleted"
    public let eventVersion: Int = 1
    public let aggregateId: UUID
    public let userId: UUID?
    
    // Deletion context
    public let projectName: String
    public let reason: String?
    public let tasksMoved: Bool
    public let destinationProject: String?
    
    public init(
        projectId: UUID,
        projectName: String,
        reason: String? = nil,
        tasksMoved: Bool = false,
        destinationProject: String? = nil,
        userId: UUID? = nil
    ) {
        self.id = UUID()
        self.occurredAt = Date()
        self.aggregateId = projectId
        self.userId = userId
        self.projectName = projectName
        self.reason = reason
        self.tasksMoved = tasksMoved
        self.destinationProject = destinationProject
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "id": id.uuidString,
            "occurredAt": occurredAt.timeIntervalSince1970,
            "eventType": eventType,
            "eventVersion": eventVersion,
            "aggregateId": aggregateId.uuidString,
            "projectName": projectName,
            "tasksMoved": tasksMoved
        ]
        
        if let userId = userId {
            dict["userId"] = userId.uuidString
        }
        if let reason = reason {
            dict["reason"] = reason
        }
        if let destinationProject = destinationProject {
            dict["destinationProject"] = destinationProject
        }
        
        return dict
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> ProjectDeletedEvent? {
        guard let idString = dict["id"] as? String,
              let id = UUID(uuidString: idString),
              let occurredAtInterval = dict["occurredAt"] as? TimeInterval,
              let aggregateIdString = dict["aggregateId"] as? String,
              let aggregateId = UUID(uuidString: aggregateIdString),
              let projectName = dict["projectName"] as? String,
              let tasksMoved = dict["tasksMoved"] as? Bool else {
            return nil
        }
        
        let userId = dict["userId"] as? String != nil ? UUID(uuidString: dict["userId"] as! String) : nil
        let reason = dict["reason"] as? String
        let destinationProject = dict["destinationProject"] as? String
        
        return ProjectDeletedEvent(
            projectId: aggregateId,
            projectName: projectName,
            reason: reason,
            tasksMoved: tasksMoved,
            destinationProject: destinationProject,
            userId: userId
        )
    }
}