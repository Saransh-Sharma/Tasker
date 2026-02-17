import Foundation
import CoreData

public enum LifeAreaMapper {
    public static let entityName = "LifeArea"

    public static func toDomain(from object: NSManagedObject) -> LifeArea {
        LifeArea(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            name: object.value(forKey: "name") as? String ?? "General",
            color: object.value(forKey: "color") as? String,
            icon: object.value(forKey: "icon") as? String,
            sortOrder: Int(object.value(forKey: "sortOrder") as? Int32 ?? 0),
            isArchived: object.value(forKey: "isArchived") as? Bool ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date(),
            updatedByDeviceID: object.value(forKey: "updatedByDeviceID") as? String,
            version: Int(object.value(forKey: "version") as? Int32 ?? 1)
        )
    }

    @discardableResult
    public static func apply(_ model: LifeArea, to object: NSManagedObject) -> NSManagedObject {
        object.setValue(model.id, forKey: "id")
        object.setValue(model.name, forKey: "name")
        object.setValue(model.color, forKey: "color")
        object.setValue(model.icon, forKey: "icon")
        object.setValue(Int32(model.sortOrder), forKey: "sortOrder")
        object.setValue(model.isArchived, forKey: "isArchived")
        object.setValue(model.createdAt, forKey: "createdAt")
        object.setValue(model.updatedAt, forKey: "updatedAt")
        object.setValue(model.updatedByDeviceID, forKey: "updatedByDeviceID")
        object.setValue(Int32(model.version), forKey: "version")
        return object
    }
}
