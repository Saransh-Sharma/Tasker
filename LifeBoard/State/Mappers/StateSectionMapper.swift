import Foundation
import CoreData

enum StateSectionMapper {
    static let entityName = "ProjectSection"

    /// Executes toDomain.
    static func toDomain(from object: NSManagedObject) -> LifeBoardProjectSection {
        LifeBoardProjectSection(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            projectID: object.value(forKey: "projectID") as? UUID ?? ProjectConstants.inboxProjectID,
            name: object.value(forKey: "name") as? String ?? "Section",
            sortOrder: Int(object.value(forKey: "sortOrder") as? Int32 ?? 0),
            isCollapsed: object.value(forKey: "isCollapsed") as? Bool ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    static func validatedDomain(from object: NSManagedObject) throws -> LifeBoardProjectSection {
        LifeBoardProjectSection(
            id: try V2CoreDataRepositorySupport.requireStoredID(object.value(forKey: "id"), field: "section.id"),
            projectID: try V2CoreDataRepositorySupport.requireStoredID(object.value(forKey: "projectID"), field: "section.projectID"),
            name: try V2CoreDataRepositorySupport.requireStoredNonEmpty(object.value(forKey: "name"), field: "section.name"),
            sortOrder: Int(object.value(forKey: "sortOrder") as? Int32 ?? 0),
            isCollapsed: object.value(forKey: "isCollapsed") as? Bool ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    /// Executes apply.
    @discardableResult
    static func apply(_ model: LifeBoardProjectSection, to object: NSManagedObject) -> NSManagedObject {
        object.setValue(model.id, forKey: "id")
        object.setValue(model.projectID, forKey: "projectID")
        object.setValue(model.name, forKey: "name")
        object.setValue(Int32(model.sortOrder), forKey: "sortOrder")
        object.setValue(model.isCollapsed, forKey: "isCollapsed")
        object.setValue(model.createdAt, forKey: "createdAt")
        object.setValue(model.updatedAt, forKey: "updatedAt")
        return object
    }
}
