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
        // UUID properties
        entity.taskID = task.id
        entity.projectID = task.projectID

        // Basic properties
        entity.name = task.name
        entity.taskDetails = task.details
        entity.taskType = task.type.rawValue
        entity.taskPriority = task.priority.rawValue
        entity.dueDate = task.dueDate as NSDate?
        entity.project = task.project // Kept for backward compatibility
        entity.isComplete = task.isComplete
        entity.dateAdded = task.dateAdded as NSDate
        entity.dateCompleted = task.dateCompleted as NSDate?
        entity.isEveningTask = task.isEveningTask
        entity.alertReminderTime = task.alertReminderTime as NSDate?
        
        // Enhanced properties - store as JSON in extended fields if available
        // For now, we'll add these when the Core Data model is updated
        // entity.estimatedDuration = task.estimatedDuration
        // entity.actualDuration = task.actualDuration
        // entity.tags = task.tags.joined(separator: ",")
        // entity.dependencies = task.dependencies.map { $0.uuidString }.joined(separator: ",")
        // entity.subtasks = task.subtasks.map { $0.uuidString }.joined(separator: ",")
        // entity.category = task.category.rawValue
        // entity.energy = task.energy.rawValue
        // entity.context = task.context.rawValue
        // entity.repeatPattern = try? JSONEncoder().encode(task.repeatPattern)
    }
    
    // MARK: - Core Data to Domain
    
    /// Convert a Core Data NTask to domain Task
    /// - Parameter entity: The Core Data NTask entity
    /// - Returns: The domain Task model
    public static func toDomain(from entity: NTask) -> Task {
        // Use the taskID if available, otherwise generate from objectID for backward compatibility
        let id = entity.taskID ?? generateUUID(from: entity.objectID)

        // Use projectID if available, otherwise default to Inbox
        let projectID = entity.projectID ?? ProjectConstants.inboxProjectID

        // Parse enhanced properties from Core Data if available, otherwise use defaults
        // For now, we provide sensible defaults until Core Data model is updated

        return Task(
            id: id,
            projectID: projectID,
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
            alertReminderTime: entity.alertReminderTime as Date?,

            // Enhanced properties - defaults until Core Data is updated
            estimatedDuration: nil as TimeInterval?, // entity.estimatedDuration
            actualDuration: nil as TimeInterval?,    // entity.actualDuration
            tags: [],               // entity.tags?.split(separator: ",").map(String.init) ?? []
            dependencies: [],       // parseUUIDs(from: entity.dependencies)
            subtasks: [],          // parseUUIDs(from: entity.subtasks)
            category: TaskCategory.general,     // TaskCategory(rawValue: entity.category ?? "") ?? .general
            energy: TaskEnergy.medium,       // TaskEnergy(rawValue: entity.energy ?? "") ?? .medium
            context: TaskContext.anywhere,    // TaskContext(rawValue: entity.context ?? "") ?? .anywhere
            repeatPattern: nil as TaskRepeatPattern?     // parseRepeatPattern(from: entity.repeatPattern)
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
        let uriString = objectID.uriRepresentation().absoluteString
        let forward = fnv1a64(bytes: uriString.utf8)
        let reverse = fnv1a64(bytes: uriString.utf8.reversed())

        var raw = [UInt8](repeating: 0, count: 16)
        withUnsafeBytes(of: forward.bigEndian) { buffer in
            raw.replaceSubrange(0..<8, with: buffer)
        }
        withUnsafeBytes(of: reverse.bigEndian) { buffer in
            raw.replaceSubrange(8..<16, with: buffer)
        }

        return UUID(uuid: (
            raw[0], raw[1], raw[2], raw[3],
            raw[4], raw[5], raw[6], raw[7],
            raw[8], raw[9], raw[10], raw[11],
            raw[12], raw[13], raw[14], raw[15]
        ))
    }
    
    /// Find an existing NTask entity by UUID
    /// - Parameters:
    ///   - id: The UUID to search for
    ///   - context: The Core Data managed object context
    /// - Returns: The NTask entity if found, nil otherwise
    public static func findEntity(byId id: UUID, in context: NSManagedObjectContext) -> NTask? {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        request.predicate = NSPredicate(format: "taskID == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            let tasks = try context.fetch(request)
            if let matched = tasks.first {
                return matched
            }

            let legacyRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
            legacyRequest.predicate = NSPredicate(format: "taskID == nil")

            let legacyTasks = try context.fetch(legacyRequest)
            return legacyTasks.first { task in
                generateUUID(from: task.objectID) == id
            }
        } catch {
            logError("Error fetching task by ID: \(error)")
            return nil
        }
    }

    private static func fnv1a64<S: Sequence>(bytes: S) -> UInt64 where S.Element == UInt8 {
        let prime: UInt64 = 1_099_511_628_211
        var hash: UInt64 = 14_695_981_039_346_656_037

        for byte in bytes {
            hash ^= UInt64(byte)
            hash &*= prime
        }

        return hash
    }
    
    // MARK: - Enhanced Property Helpers
    
    /// Parse UUIDs from comma-separated string
    /// - Parameter string: Comma-separated UUID string
    /// - Returns: Array of UUIDs
    private static func parseUUIDs(from string: String?) -> [UUID] {
        guard let string = string, !string.isEmpty else { return [] }
        return string.split(separator: ",")
            .compactMap { UUID(uuidString: String($0)) }
    }
    
    /// Parse repeat pattern from JSON data
    /// - Parameter data: JSON data representing repeat pattern
    /// - Returns: TaskRepeatPattern if parsing succeeds
    private static func parseRepeatPattern(from data: Data?) -> TaskRepeatPattern? {
        guard let data = data else { return nil }
        return try? JSONDecoder().decode(TaskRepeatPattern.self, from: data)
    }
    
    /// Convert UUIDs to comma-separated string
    /// - Parameter uuids: Array of UUIDs
    /// - Returns: Comma-separated string
    private static func uuidsToString(_ uuids: [UUID]) -> String {
        return uuids.map { $0.uuidString }.joined(separator: ",")
    }
}
