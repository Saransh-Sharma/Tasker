import Foundation
import CoreData

enum StateTombstoneMapper {
    static let entityName = "Tombstone"

    static func toDomain(from object: NSManagedObject) -> TombstoneDefinition {
        TombstoneDefinition(
            id: object.value(forKey: "id") as? UUID ?? UUID(),
            entityType: object.value(forKey: "entityType") as? String ?? "Unknown",
            entityID: object.value(forKey: "entityID") as? UUID ?? UUID(),
            deletedAt: object.value(forKey: "deletedAt") as? Date ?? Date(),
            deletedBy: object.value(forKey: "deletedBy") as? String,
            purgeAfter: object.value(forKey: "purgeAfter") as? Date ?? Date()
        )
    }

    @discardableResult
    static func apply(_ model: TombstoneDefinition, to object: NSManagedObject) -> NSManagedObject {
        object.setValue(model.id, forKey: "id")
        object.setValue(model.entityType, forKey: "entityType")
        object.setValue(model.entityID, forKey: "entityID")
        object.setValue(model.deletedAt, forKey: "deletedAt")
        object.setValue(model.deletedBy, forKey: "deletedBy")
        object.setValue(model.purgeAfter, forKey: "purgeAfter")
        return object
    }
}
