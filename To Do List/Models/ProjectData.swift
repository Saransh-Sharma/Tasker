import Foundation
import CoreData

/// A plain Swift struct representing a Project (separates Core Data from the UI layer)
struct ProjectData {
    let id: NSManagedObjectID?
    let name: String
    let details: String?
    
    /// Initialize from Core Data managed object `Projects`
    init(managedObject: Projects) {
        self.id = managedObject.objectID
        self.name = managedObject.projectName ?? ""
        self.details = managedObject.projecDescription
    }
    
    /// Convenience initializer
    init(id: NSManagedObjectID? = nil, name: String, details: String? = nil) {
        self.id = id
        self.name = name
        self.details = details
    }
}
