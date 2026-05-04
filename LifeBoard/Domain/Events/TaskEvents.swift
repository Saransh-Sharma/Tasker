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
    
    /// Initializes a new instance.
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
    
    /// Executes toDictionary.
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
    
    /// Executes fromDictionary.
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
    
    /// Initializes a new instance.
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
    
    /// Executes toDictionary.
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
    
    /// Executes fromDictionary.
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
    
    /// Initializes a new instance.
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
    
    /// Executes toDictionary.
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
    
    /// Executes fromDictionary.
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

/// Event fired when a scheduled occurrence is resolved.
public struct OccurrenceResolvedEvent: SerializableDomainEvent {
    public let eventId: UUID
    public let occurredAt: Date
    public let eventType: String = "OccurrenceResolved"
    public let eventVersion: Int = 1
    public let aggregateId: UUID
    public let metadata: [String: Any]?

    public let resolutionType: String
    public let actor: String

    /// Initializes a new instance.
    public init(
        occurrenceId: UUID,
        resolutionType: String,
        actor: String,
        eventId: UUID = UUID(),
        occurredAt: Date = Date()
    ) {
        self.eventId = eventId
        self.occurredAt = occurredAt
        self.aggregateId = occurrenceId
        self.resolutionType = resolutionType
        self.actor = actor
        self.metadata = [
            "occurrenceId": occurrenceId.uuidString,
            "resolutionType": resolutionType,
            "actor": actor
        ]
    }

    /// Executes toDictionary.
    public func toDictionary() -> [String: Any] {
        [
            "eventId": eventId.uuidString,
            "occurredAt": occurredAt.timeIntervalSince1970,
            "eventType": eventType,
            "eventVersion": eventVersion,
            "aggregateId": aggregateId.uuidString,
            "resolutionType": resolutionType,
            "actor": actor
        ]
    }

    /// Executes fromDictionary.
    public static func fromDictionary(_ dict: [String: Any]) -> OccurrenceResolvedEvent? {
        guard
            let eventIdString = dict["eventId"] as? String,
            let eventId = UUID(uuidString: eventIdString),
            let occurredAtInterval = dict["occurredAt"] as? TimeInterval,
            let aggregateIdString = dict["aggregateId"] as? String,
            let aggregateId = UUID(uuidString: aggregateIdString),
            let resolutionType = dict["resolutionType"] as? String,
            let actor = dict["actor"] as? String
        else {
            return nil
        }

        return OccurrenceResolvedEvent(
            occurrenceId: aggregateId,
            resolutionType: resolutionType,
            actor: actor,
            eventId: eventId,
            occurredAt: Date(timeIntervalSince1970: occurredAtInterval)
        )
    }
}

/// Event fired when XP is awarded from the gamification ledger.
public struct XPAwardedEvent: SerializableDomainEvent {
    public let eventId: UUID
    public let occurredAt: Date
    public let eventType: String = "XPAwarded"
    public let eventVersion: Int = 1
    public let aggregateId: UUID
    public let metadata: [String: Any]?

    public let delta: Int
    public let reason: String
    public let idempotencyKey: String

    /// Initializes a new instance.
    public init(
        eventId: UUID = UUID(),
        occurredAt: Date = Date(),
        aggregateId: UUID = UUID(),
        delta: Int,
        reason: String,
        idempotencyKey: String
    ) {
        self.eventId = eventId
        self.occurredAt = occurredAt
        self.aggregateId = aggregateId
        self.delta = delta
        self.reason = reason
        self.idempotencyKey = idempotencyKey
        self.metadata = [
            "delta": delta,
            "reason": reason,
            "idempotencyKey": idempotencyKey
        ]
    }

    /// Executes toDictionary.
    public func toDictionary() -> [String: Any] {
        [
            "eventId": eventId.uuidString,
            "occurredAt": occurredAt.timeIntervalSince1970,
            "eventType": eventType,
            "eventVersion": eventVersion,
            "aggregateId": aggregateId.uuidString,
            "delta": delta,
            "reason": reason,
            "idempotencyKey": idempotencyKey
        ]
    }

    /// Executes fromDictionary.
    public static func fromDictionary(_ dict: [String: Any]) -> XPAwardedEvent? {
        guard
            let eventIdString = dict["eventId"] as? String,
            let eventId = UUID(uuidString: eventIdString),
            let occurredAtInterval = dict["occurredAt"] as? TimeInterval,
            let aggregateIdString = dict["aggregateId"] as? String,
            let aggregateId = UUID(uuidString: aggregateIdString),
            let delta = dict["delta"] as? Int,
            let reason = dict["reason"] as? String,
            let idempotencyKey = dict["idempotencyKey"] as? String
        else {
            return nil
        }

        return XPAwardedEvent(
            eventId: eventId,
            occurredAt: Date(timeIntervalSince1970: occurredAtInterval),
            aggregateId: aggregateId,
            delta: delta,
            reason: reason,
            idempotencyKey: idempotencyKey
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
    
    /// Initializes a new instance.
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
    
    /// Executes toDictionary.
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
    
    /// Executes fromDictionary.
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
