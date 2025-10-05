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

    @NSManaged public var projectID: UUID?
    @NSManaged public var projectName: String?
    @NSManaged public var projecDescription: String?

}
