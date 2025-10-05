//
//  ProjectMapper.swift
//  Tasker
//
//  Mapper for converting between Project domain model and Core Data representation
//

import Foundation
import CoreData

/// Mapper class for converting between domain Project and Core Data representation
/// Note: Since Projects entity doesn't exist yet in Core Data, this mapper works with
/// string-based project names for now. This will be updated when Projects entity is added.
public class ProjectMapper {
    
    // MARK: - String to Domain
    
    /// Convert a project name string to a domain Project
    /// - Parameter projectName: The project name string
    /// - Returns: The domain Project model
    public static func toDomain(from projectName: String) -> Project {
        // Check if this is the default Inbox project
        let isInbox = projectName.lowercased() == "inbox"
        
        return Project(
            id: generateUUID(from: projectName),
            name: projectName,
            projectDescription: isInbox ? "Default project for uncategorized tasks" : nil,
            createdDate: Date(), // Will be updated when Projects entity is added
            modifiedDate: Date(), // Will be updated when Projects entity is added
            isDefault: isInbox,
            
            // Enhanced properties - defaults until Core Data is updated
            color: isInbox ? ProjectColor.gray : ProjectColor.blue,
            icon: isInbox ? ProjectIcon.inbox : ProjectIcon.folder,
            status: ProjectStatus.active,
            priority: isInbox ? ProjectPriority.low : ProjectPriority.medium,
            parentProjectId: nil as UUID?,
            subprojectIds: [] as [UUID],
            tags: [] as [String],
            dueDate: nil as Date?,
            estimatedTaskCount: nil as Int?,
            isArchived: false,
            templateId: nil as UUID?,
            settings: ProjectSettings()
        )
    }
    
    /// Convert an array of project names to domain Projects
    /// - Parameter projectNames: Array of project name strings
    /// - Returns: Array of domain Project models
    public static func toDomainArray(from projectNames: [String]) -> [Project] {
        return projectNames.map { toDomain(from: $0) }
    }
    
    // MARK: - Domain to String
    
    /// Convert a domain Project to a project name string
    /// - Parameter project: The domain Project model
    /// - Returns: The project name string
    public static func toString(from project: Project) -> String {
        return project.name
    }
    
    // MARK: - Helper Methods
    
    /// Generate a deterministic UUID from a project name
    /// This ensures the same project name always generates the same UUID
    private static func generateUUID(from projectName: String) -> UUID {
        // Create a hash from the project name
        let hash = projectName.lowercased().hash
        
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
    
    /// Get all unique project names from tasks
    /// - Parameter context: The Core Data managed object context
    /// - Returns: Array of unique project names
    public static func getAllProjectNames(from context: NSManagedObjectContext) -> [String] {
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        do {
            let tasks = try context.fetch(request)
            let projectNames = tasks.compactMap { $0.project }
            let uniqueNames = Array(Set(projectNames))
            
            // Ensure Inbox is always included
            if !uniqueNames.contains("Inbox") {
                return ["Inbox"] + uniqueNames.sorted()
            }
            
            // Put Inbox first, then sort the rest
            let nonInboxProjects = uniqueNames.filter { $0 != "Inbox" }.sorted()
            return ["Inbox"] + nonInboxProjects
            
        } catch {
            print("Error fetching project names: \(error)")
            return ["Inbox"]
        }
    }
    
    // MARK: - Core Data Entity Support

    /// Convert a Core Data Projects entity to domain Project
    /// - Parameter entity: The Core Data Projects entity
    /// - Returns: The domain Project model
    public static func toDomain(from entity: Projects) -> Project {
        // Use projectID if available, otherwise generate from name
        let id = entity.projectID ?? generateUUID(from: entity.projectName ?? "Unnamed")

        // Check if this is the Inbox project
        let isInbox = id == ProjectConstants.inboxProjectID

        return Project(
            id: id,
            name: entity.projectName ?? "Unnamed Project",
            projectDescription: entity.projecDescription,
            createdDate: Date(), // Will be added when Core Data model is updated
            modifiedDate: Date(), // Will be added when Core Data model is updated
            isDefault: isInbox,

            // Enhanced properties - defaults until Core Data is updated
            color: isInbox ? ProjectColor.gray : ProjectColor.blue,
            icon: isInbox ? ProjectIcon.inbox : ProjectIcon.folder,
            status: ProjectStatus.active,
            priority: isInbox ? ProjectPriority.low : ProjectPriority.medium,
            parentProjectId: nil as UUID?,
            subprojectIds: [] as [UUID],
            tags: [] as [String],
            dueDate: nil as Date?,
            estimatedTaskCount: nil as Int?,
            isArchived: false,
            templateId: nil as UUID?,
            settings: ProjectSettings()
        )
    }

    /// Convert a domain Project to Core Data Projects entity
    /// - Parameters:
    ///   - project: The domain Project model
    ///   - context: The Core Data managed object context
    /// - Returns: The Core Data Projects entity
    public static func toEntity(from project: Project, in context: NSManagedObjectContext) -> Projects {
        let entity = Projects(context: context)
        updateEntity(entity, from: project)
        return entity
    }

    /// Update an existing Projects entity with domain Project data
    /// - Parameters:
    ///   - entity: The Core Data Projects entity to update
    ///   - project: The domain Project model
    public static func updateEntity(_ entity: Projects, from project: Project) {
        entity.projectID = project.id
        entity.projectName = project.name
        entity.projecDescription = project.projectDescription
        // Additional properties will be added when Core Data model is updated
    }

    /// Find an existing Projects entity by UUID
    /// - Parameters:
    ///   - id: The UUID to search for
    ///   - context: The Core Data managed object context
    /// - Returns: The Projects entity if found, nil otherwise
    public static func findEntity(byId id: UUID, in context: NSManagedObjectContext) -> Projects? {
        let request: NSFetchRequest<Projects> = Projects.fetchRequest()
        request.predicate = NSPredicate(format: "projectID == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            let projects = try context.fetch(request)
            return projects.first
        } catch {
            print("Error fetching project by ID: \(error)")
            return nil
        }
    }

    /// Convert an array of Core Data Projects entities to domain Projects
    /// - Parameter entities: Array of Core Data Projects entities
    /// - Returns: Array of domain Project models
    public static func toDomainArray(from entities: [Projects]) -> [Project] {
        return entities.map { toDomain(from: $0) }
    }
}
