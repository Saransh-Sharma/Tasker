//
//  Projects+CoreDataProperties.swift
//  
//
//  Created by Saransh Sharma on 29/06/20.
//
//

import Foundation
import CoreData


extension Projects {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Projects> {
        return NSFetchRequest<Projects>(entityName: "Projects")
    }

    // Core properties
    @NSManaged public var projectID: UUID?
    @NSManaged public var projectName: String?
    @NSManaged public var projecDescription: String?
    @NSManaged public var projectDescription: String?

    // Metadata
    @NSManaged public var createdDate: Date?
    @NSManaged public var modifiedDate: Date?
    @NSManaged public var isDefault: Bool
    @NSManaged public var isArchived: Bool

    // Visual properties
    @NSManaged public var color: String?
    @NSManaged public var icon: String?

    // Organizational properties
    @NSManaged public var status: String?
    @NSManaged public var priority: Int32
    @NSManaged public var tags: NSObject?

    // Dates and metrics
    @NSManaged public var dueDate: Date?
    @NSManaged public var estimatedTaskCount: Int32

    // Hierarchy
    @NSManaged public var parentProjectID: UUID?
    @NSManaged public var subprojectIDs: NSObject?
    @NSManaged public var templateID: UUID?

}
