//
//  StateProjectMapper.swift
//  Tasker
//
//  Mapper for converting between Project domain model and Core Data representation
//

import Foundation
import CoreData

/// Mapper class for converting between domain Project and Core Data ProjectEntity entity
public enum StateProjectMapper {

    // MARK: - Core Data Entity Support

    /// Convert a Core Data ProjectEntity entity to domain Project
    /// - Parameter entity: The Core Data ProjectEntity entity
    /// - Returns: The domain Project model
    public static func toDomain(from entity: ProjectEntity) -> Project {
        let normalizedProjectName = normalizedName(entity.name)
        let inboxByName = normalizedProjectName?.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame
        let inboxByFlag = entity.isDefault || entity.isInbox
        let inboxLike = inboxByFlag || inboxByName
        let id = entity.id
            ?? (inboxLike
                ? ProjectConstants.inboxProjectID
                : stableUUID(from: entity.objectID.uriRepresentation().absoluteString))

        // Check if this is the Inbox project
        let isInbox = inboxLike || (id == ProjectConstants.inboxProjectID)

        return Project(
            id: id,
            name: normalizedProjectName ?? "Unnamed Project",
            projectDescription: entity.projectDescription,
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

    /// Convert a domain Project to Core Data ProjectEntity entity
    /// - Parameters:
    ///   - project: The domain Project model
    ///   - context: The Core Data managed object context
    /// - Returns: The Core Data ProjectEntity entity
    public static func toEntity(from project: Project, in context: NSManagedObjectContext) -> ProjectEntity {
        let entity = ProjectEntity(context: context)
        updateEntity(entity, from: project)
        return entity
    }

    /// Update an existing ProjectEntity entity with domain Project data
    /// - Parameters:
    ///   - entity: The Core Data ProjectEntity entity to update
    ///   - project: The domain Project model
    public static func updateEntity(_ entity: ProjectEntity, from project: Project) {
        entity.id = project.id
        entity.name = project.name
        entity.projectDescription = project.projectDescription
        entity.createdDate = project.createdDate
        entity.modifiedDate = Date() // Always update modified date
        entity.createdAt = entity.createdAt ?? project.createdDate
        entity.updatedAt = Date()
        entity.isDefault = project.isDefault
        entity.isInbox = project.isDefault || project.id == ProjectConstants.inboxProjectID

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

    /// Find an existing ProjectEntity entity by UUID
    /// - Parameters:
    ///   - id: The UUID to search for
    ///   - context: The Core Data managed object context
    /// - Returns: The ProjectEntity entity if found, nil otherwise
    public static func findEntity(byId id: UUID, in context: NSManagedObjectContext) -> ProjectEntity? {
        let request: NSFetchRequest<ProjectEntity> = ProjectEntity.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1

        do {
            let projects = try context.fetch(request)
            return projects.first
        } catch {
            logError("Error fetching project by ID: \(error)")
            return nil
        }
    }

    /// Convert an array of Core Data ProjectEntity entities to domain ProjectEntity
    /// - Parameter entities: Array of Core Data ProjectEntity entities
    /// - Returns: Array of domain Project models
    public static func toDomainArray(from entities: [ProjectEntity]) -> [Project] {
        return entities.map { toDomain(from: $0) }
    }

    private static func normalizedName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func stableUUID(from string: String) -> UUID {
        var hash = UInt64(1469598103934665603)
        let prime: UInt64 = 1099511628211
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* prime
        }

        var bytes = [UInt8](repeating: 0, count: 16)
        for index in 0..<16 {
            bytes[index] = UInt8((hash >> ((index % 8) * 8)) & 0xff)
            hash = hash &* prime ^ UInt64(index)
        }
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        let tuple = (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        )
        return UUID(uuid: tuple)
    }
}
