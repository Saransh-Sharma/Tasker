import Foundation
import CoreData

enum StateTagMapper {
    static let entityName = "Tag"

    /// Executes toDomain.
    static func toDomain(from object: NSManagedObject) -> TagDefinition {
        TagDefinition(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            name: object.value(forKey: "name") as? String ?? "Tag",
            color: object.value(forKey: "color") as? String,
            icon: object.value(forKey: "icon") as? String,
            sortOrder: Int(object.value(forKey: "sortOrder") as? Int32 ?? 0),
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date()
        )
    }

    /// Executes apply.
    @discardableResult
    static func apply(_ model: TagDefinition, to object: NSManagedObject) -> NSManagedObject {
        object.setValue(model.id, forKey: "id")
        object.setValue(model.name, forKey: "name")
        object.setValue(model.color, forKey: "color")
        object.setValue(model.icon, forKey: "icon")
        object.setValue(Int32(model.sortOrder), forKey: "sortOrder")
        object.setValue(model.createdAt, forKey: "createdAt")
        return object
    }
}
