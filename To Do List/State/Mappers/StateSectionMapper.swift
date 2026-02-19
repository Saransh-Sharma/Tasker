import Foundation
import CoreData

enum StateSectionMapper {
    static let entityName = "ProjectSection"

    static func toDomain(from object: NSManagedObject) -> TaskerProjectSection {
        TaskerProjectSection(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            projectID: object.value(forKey: "projectID") as? UUID ?? ProjectConstants.inboxProjectID,
            name: object.value(forKey: "name") as? String ?? "Section",
            sortOrder: Int(object.value(forKey: "sortOrder") as? Int32 ?? 0),
            isCollapsed: object.value(forKey: "isCollapsed") as? Bool ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    @discardableResult
    static func apply(_ model: TaskerProjectSection, to object: NSManagedObject) -> NSManagedObject {
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
