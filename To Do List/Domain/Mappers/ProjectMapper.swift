//
//  ProjectMapper.swift
//  Tasker
//
//  Mapper for converting between Project domain model and Core Data representation
//

import Foundation
import CoreData

/// Mapper class for converting between domain Project and Core Data Projects entity
public class ProjectMapper {

    // MARK: - Core Data Entity Support

    /// Convert a Core Data Projects entity to domain Project
    /// - Parameter entity: The Core Data Projects entity
    /// - Returns: The domain Project model
    public static func toDomain(from entity: Projects) -> Project {
        // projectID MUST exist - migration should have ensured this
        guard let id = entity.projectID else {
            fatalError("⚠️ Projects entity missing projectID! Entity: \(entity.projectName ?? "unknown"). Run migration to fix.")
        }

        // Check if this is the Inbox project
        let isInbox = entity.isDefault || (id == ProjectConstants.inboxProjectID)

        return Project(
            id: id,
            name: entity.projectName ?? "Unnamed Project",
            projectDescription: entity.projectDescription ?? entity.projecDescription,
            createdDate: entity.createdDate ?? Date(),
            modifiedDate: entity.modifiedDate ?? Date(),
            isDefault: isInbox,

            // Enhanced properties from schema
            color: ProjectColor(rawValue: entity.color ?? "") ?? (isInbox ? .gray : .blue),
            icon: ProjectIcon(rawValue: entity.icon ?? "") ?? (isInbox ? .inbox : .folder),
            status: ProjectStatus(rawValue: entity.status ?? "") ?? .active,
            priority: ProjectPriority(rawValue: Int(entity.priority)) ?? (isInbox ? .low : .medium),
            parentProjectId: entity.parentProjectID,
            subprojectIds: (entity.subprojectIDs as? [UUID]) ?? [],
            tags: (entity.tags as? [String]) ?? [],
            dueDate: entity.dueDate,
            estimatedTaskCount: entity.estimatedTaskCount > 0 ? Int(entity.estimatedTaskCount) : nil,
            isArchived: entity.isArchived,
            templateId: entity.templateID,
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
        entity.projectDescription = project.projectDescription
        entity.projecDescription = project.projectDescription // Legacy field, keep in sync
        entity.createdDate = project.createdDate
        entity.modifiedDate = Date() // Always update modified date
        entity.isDefault = project.isDefault

        // Enhanced properties
        entity.color = project.color.rawValue
        entity.icon = project.icon.rawValue
        entity.status = project.status.rawValue
        entity.priority = Int32(project.priority.rawValue)
        entity.parentProjectID = project.parentProjectId
        entity.subprojectIDs = project.subprojectIds as NSObject
        entity.tags = project.tags as NSObject
        entity.dueDate = project.dueDate
        entity.estimatedTaskCount = Int32(project.estimatedTaskCount ?? 0)
        entity.isArchived = project.isArchived
        entity.templateID = project.templateId
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
