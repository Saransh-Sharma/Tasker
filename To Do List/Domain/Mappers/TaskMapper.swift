//
//  TaskMapper.swift
//  Tasker
//
//  Mapper for converting between Task domain model and NTask Core Data entity
//

import Foundation
import CoreData

/// Mapper class for converting between domain Task and Core Data NTask
public class TaskMapper {
    
    // MARK: - Domain to Core Data
    
    /// Convert a domain Task to Core Data NTask
    /// - Parameters:
    ///   - task: The domain Task model
    ///   - context: The Core Data managed object context
    /// - Returns: The Core Data NTask entity
    public static func toEntity(from task: Task, in context: NSManagedObjectContext) -> NTask {
        let entity = NTask(context: context)
        updateEntity(entity, from: task)
        return entity
    }
    
    /// Update an existing NTask entity with domain Task data
    /// - Parameters:
    ///   - entity: The Core Data NTask entity to update
    ///   - task: The domain Task model
    public static func updateEntity(_ entity: NTask, from task: Task) {
        entity.name = task.name
        entity.taskDetails = task.details
        entity.taskType = task.type.rawValue
        entity.taskPriority = task.priority.rawValue
        entity.dueDate = task.dueDate as NSDate?
        entity.project = task.project
        entity.isComplete = task.isComplete
        entity.dateAdded = task.dateAdded as NSDate
        entity.dateCompleted = task.dateCompleted as NSDate?
        entity.isEveningTask = task.isEveningTask
        entity.alertReminderTime = task.alertReminderTime as NSDate?
    }
    
    // MARK: - Core Data to Domain
    
    /// Convert a Core Data NTask to domain Task
    /// - Parameter entity: The Core Data NTask entity
    /// - Returns: The domain Task model
    public static func toDomain(from entity: NTask) -> Task {
        // Generate a UUID from the object ID or create a new one
        let id = generateUUID(from: entity.objectID)
        
        return Task(
            id: id,
            name: entity.name ?? "Untitled Task",
            details: entity.taskDetails,
            type: TaskType(rawValue: entity.taskType),
            priority: TaskPriority(rawValue: entity.taskPriority),
            dueDate: entity.dueDate as Date?,
            project: entity.project ?? "Inbox",
            isComplete: entity.isComplete,
            dateAdded: entity.dateAdded as Date? ?? Date(),
            dateCompleted: entity.dateCompleted as Date?,
            isEveningTask: entity.isEveningTask,
            alertReminderTime: entity.alertReminderTime as Date?
        )
    }
    
    /// Convert an array of Core Data NTask entities to domain Tasks
    /// - Parameter entities: Array of Core Data NTask entities
    /// - Returns: Array of domain Task models
    public static func toDomainArray(from entities: [NTask]) -> [Task] {
        return entities.map { toDomain(from: $0) }
    }
    
    // MARK: - Helper Methods
    
    /// Generate a UUID from NSManagedObjectID
    /// This creates a deterministic UUID based on the object ID
    private static func generateUUID(from objectID: NSManagedObjectID) -> UUID {
        // Use the URI representation of the object ID to create a deterministic UUID
        let uriString = objectID.uriRepresentation().absoluteString
        
        // Create a hash from the URI string
        let hash = uriString.hash
        
        // Create UUID bytes from the hash
        var bytes: [UInt8] = []
        var hashValue = hash
        for _ in 0..<16 {
            bytes.append(UInt8(hashValue & 0xFF))
            hashValue = hashValue >> 8
        }
        
        // Ensure we have exactly 16 bytes
        while bytes.count < 16 {
            bytes.append(0)
        }
        
        // Create UUID from bytes
        let uuid = UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
        
        return uuid
    }
    
    /// Find an existing NTask entity by UUID
    /// - Parameters:
    ///   - id: The UUID to search for
    ///   - context: The Core Data managed object context
    /// - Returns: The NTask entity if found, nil otherwise
    public static func findEntity(byId id: UUID, in context: NSManagedObjectContext) -> NTask? {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        do {
            let tasks = try context.fetch(request)
            // Find the task that matches the UUID
            return tasks.first { task in
                generateUUID(from: task.objectID) == id
            }
        } catch {
            print("Error fetching task by ID: \(error)")
            return nil
        }
    }
}
