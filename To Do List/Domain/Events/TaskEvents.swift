//
//  TaskEvents.swift
//  Tasker
//
//  Domain events related to Task operations
//

import Foundation

// MARK: - Task Domain Events

/// Event fired when a task is created
public struct TaskCreatedEvent: SerializableDomainEvent {
    public let eventId: UUID
    public let occurredAt: Date
    public let eventType: String = "TaskCreated"
    public let eventVersion: Int = 1
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let userId: UUID?
    
    // Task-specific data
    public let taskName: String
    public let taskType: TaskType
    public let taskPriority: TaskPriority
    public let projectName: String?
    public let dueDate: Date?
    
    public init(
        taskId: UUID,
        taskName: String,
        taskType: TaskType,
        taskPriority: TaskPriority,
        projectName: String?,
        dueDate: Date?,
        userId: UUID? = nil,
        eventId: UUID = UUID(),
        occurredAt: Date = Date()
    ) {
        self.eventId = eventId
        self.occurredAt = occurredAt
        self.aggregateId = taskId
        self.userId = userId
        self.taskName = taskName
        self.taskType = taskType
        self.taskPriority = taskPriority
        self.projectName = projectName
        self.dueDate = dueDate
        self.metadata = [
            "taskId": taskId.uuidString,
            "taskName": taskName,
            "taskType": taskType.rawValue,
            "taskPriority": taskPriority.rawValue
        ]
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "eventId": eventId.uuidString,
            "occurredAt": occurredAt.timeIntervalSince1970,
            "eventType": eventType,
            "eventVersion": eventVersion,
            "aggregateId": aggregateId.uuidString,
            "taskName": taskName,
            "taskType": taskType.rawValue,
            "taskPriority": taskPriority.rawValue
        ]
        
        if let userId = userId {
            dict["userId"] = userId.uuidString
        }
        if let projectName = projectName {
            dict["projectName"] = projectName
        }
        if let dueDate = dueDate {
            dict["dueDate"] = dueDate.timeIntervalSince1970
        }
        
        return dict
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> TaskCreatedEvent? {
        guard let eventIdString = dict["eventId"] as? String,
              let eventId = UUID(uuidString: eventIdString),
              let occurredAtInterval = dict["occurredAt"] as? TimeInterval,
              let aggregateIdString = dict["aggregateId"] as? String,
              let aggregateId = UUID(uuidString: aggregateIdString),
              let taskName = dict["taskName"] as? String,
              let taskTypeRaw = dict["taskType"] as? Int32,
              let taskPriorityRaw = dict["taskPriority"] as? Int32 else {
            return nil
        }
        
        let occurredAt = Date(timeIntervalSince1970: occurredAtInterval)
        let taskType = TaskType(rawValue: taskTypeRaw)
        let taskPriority = TaskPriority(rawValue: taskPriorityRaw)
        
        let userId = (dict["userId"] as? String).flatMap(UUID.init(uuidString:))
        let projectName = dict["projectName"] as? String
        let dueDate = (dict["dueDate"] as? TimeInterval).map { Date(timeIntervalSince1970: $0) }
        
        return TaskCreatedEvent(
            taskId: aggregateId,
            taskName: taskName,
            taskType: taskType,
            taskPriority: taskPriority,
            projectName: projectName,
            dueDate: dueDate,
            userId: userId,
            eventId: eventId,
            occurredAt: occurredAt
        )
    }
}

/// Event fired when a task is completed
public struct TaskCompletedEvent: SerializableDomainEvent {
    public let eventId: UUID
    public let occurredAt: Date
    public let eventType: String = "TaskCompleted"
    public let eventVersion: Int = 1
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let userId: UUID?
    
    // Task completion data
    public let taskName: String
    public let taskPriority: TaskPriority
    public let scoreEarned: Int
    public let completionTime: TimeInterval? // Time taken to complete
    
    public init(
        taskId: UUID,
        taskName: String,
        taskPriority: TaskPriority,
        scoreEarned: Int,
        completionTime: TimeInterval? = nil,
        userId: UUID? = nil,
        eventId: UUID = UUID(),
        occurredAt: Date = Date()
    ) {
        self.eventId = eventId
        self.occurredAt = occurredAt
        self.aggregateId = taskId
        self.userId = userId
        self.taskName = taskName
        self.taskPriority = taskPriority
        self.scoreEarned = scoreEarned
        self.completionTime = completionTime
        self.metadata = [
            "taskId": taskId.uuidString,
            "taskName": taskName,
            "scoreEarned": scoreEarned
        ]
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "eventId": eventId.uuidString,
            "occurredAt": occurredAt.timeIntervalSince1970,
            "eventType": eventType,
            "eventVersion": eventVersion,
            "aggregateId": aggregateId.uuidString,
            "taskName": taskName,
            "taskPriority": taskPriority.rawValue,
            "scoreEarned": scoreEarned
        ]
        
        if let userId = userId {
            dict["userId"] = userId.uuidString
        }
        if let completionTime = completionTime {
            dict["completionTime"] = completionTime
        }
        
        return dict
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> TaskCompletedEvent? {
        guard let eventIdString = dict["eventId"] as? String,
              let eventId = UUID(uuidString: eventIdString),
              let occurredAtInterval = dict["occurredAt"] as? TimeInterval,
              let aggregateIdString = dict["aggregateId"] as? String,
              let aggregateId = UUID(uuidString: aggregateIdString),
              let taskName = dict["taskName"] as? String,
              let taskPriorityRaw = dict["taskPriority"] as? Int32,
              let scoreEarned = dict["scoreEarned"] as? Int else {
            return nil
        }
        
        let occurredAt = Date(timeIntervalSince1970: occurredAtInterval)
        let taskPriority = TaskPriority(rawValue: taskPriorityRaw)
        let userId = (dict["userId"] as? String).flatMap(UUID.init(uuidString:))
        let completionTime = dict["completionTime"] as? TimeInterval
        
        return TaskCompletedEvent(
            taskId: aggregateId,
            taskName: taskName,
            taskPriority: taskPriority,
            scoreEarned: scoreEarned,
            completionTime: completionTime,
            userId: userId,
            eventId: eventId,
            occurredAt: occurredAt
        )
    }
}

/// Event fired when a task is updated
public struct TaskUpdatedEvent: SerializableDomainEvent {
    public let eventId: UUID
    public let occurredAt: Date
    public let eventType: String = "TaskUpdated"
    public let eventVersion: Int = 1
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let userId: UUID?
    
    // Update data
    public let changedFields: [String]
    public let oldValues: [String: Any]
    public let newValues: [String: Any]
    
    public init(
        taskId: UUID,
        changedFields: [String],
        oldValues: [String: Any],
        newValues: [String: Any],
        userId: UUID? = nil,
        eventId: UUID = UUID(),
        occurredAt: Date = Date()
    ) {
        self.eventId = eventId
        self.occurredAt = occurredAt
        self.aggregateId = taskId
        self.userId = userId
        self.changedFields = changedFields
        self.oldValues = oldValues
        self.newValues = newValues
        self.metadata = [
            "taskId": taskId.uuidString,
            "changedFieldsCount": changedFields.count
        ]
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "eventId": eventId.uuidString,
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
    
    public static func fromDictionary(_ dict: [String: Any]) -> TaskUpdatedEvent? {
        guard let eventIdString = dict["eventId"] as? String,
              let eventId = UUID(uuidString: eventIdString),
              let occurredAtInterval = dict["occurredAt"] as? TimeInterval,
              let aggregateIdString = dict["aggregateId"] as? String,
              let aggregateId = UUID(uuidString: aggregateIdString),
              let changedFields = dict["changedFields"] as? [String],
              let oldValues = dict["oldValues"] as? [String: Any],
              let newValues = dict["newValues"] as? [String: Any] else {
            return nil
        }
        
        let occurredAt = Date(timeIntervalSince1970: occurredAtInterval)
        let userId = (dict["userId"] as? String).flatMap(UUID.init(uuidString:))
        
        return TaskUpdatedEvent(
            taskId: aggregateId,
            changedFields: changedFields,
            oldValues: oldValues,
            newValues: newValues,
            userId: userId,
            eventId: eventId,
            occurredAt: occurredAt
        )
    }
}

/// Event fired when a task is deleted
public struct TaskDeletedEvent: SerializableDomainEvent {
    public let eventId: UUID
    public let occurredAt: Date
    public let eventType: String = "TaskDeleted"
    public let eventVersion: Int = 1
    public let aggregateId: UUID
    public let metadata: [String: Any]?
    public let userId: UUID?
    
    // Deletion context
    public let taskName: String
    public let reason: String?
    
    public init(
        taskId: UUID,
        taskName: String,
        reason: String? = nil,
        userId: UUID? = nil,
        eventId: UUID = UUID(),
        occurredAt: Date = Date()
    ) {
        self.eventId = eventId
        self.occurredAt = occurredAt
        self.aggregateId = taskId
        self.userId = userId
        self.taskName = taskName
        self.reason = reason
        self.metadata = [
            "taskId": taskId.uuidString,
            "taskName": taskName
        ]
    }
    
    public func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [
            "eventId": eventId.uuidString,
            "occurredAt": occurredAt.timeIntervalSince1970,
            "eventType": eventType,
            "eventVersion": eventVersion,
            "aggregateId": aggregateId.uuidString,
            "taskName": taskName
        ]
        
        if let userId = userId {
            dict["userId"] = userId.uuidString
        }
        if let reason = reason {
            dict["reason"] = reason
        }
        
        return dict
    }
    
    public static func fromDictionary(_ dict: [String: Any]) -> TaskDeletedEvent? {
        guard let eventIdString = dict["eventId"] as? String,
              let eventId = UUID(uuidString: eventIdString),
              let occurredAtInterval = dict["occurredAt"] as? TimeInterval,
              let aggregateIdString = dict["aggregateId"] as? String,
              let aggregateId = UUID(uuidString: aggregateIdString),
              let taskName = dict["taskName"] as? String else {
            return nil
        }
        
        let occurredAt = Date(timeIntervalSince1970: occurredAtInterval)
        let userId = (dict["userId"] as? String).flatMap(UUID.init(uuidString:))
        let reason = dict["reason"] as? String
        
        return TaskDeletedEvent(
            taskId: aggregateId,
            taskName: taskName,
            reason: reason,
            userId: userId,
            eventId: eventId,
            occurredAt: occurredAt
        )
    }
}
