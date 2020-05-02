//
//  NTask+CoreDataProperties.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//
//

import Foundation
import CoreData


extension NTask {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<NTask> {
        return NSFetchRequest<NTask>(entityName: "NTask")
    }

    @NSManaged public var name: String
    @NSManaged public var isComplete: Bool
    @NSManaged public var dueDate: NSDate?
    @NSManaged public var taskDetails: String?
    @NSManaged public var taskPriority: Int32
    @NSManaged public var taskType: Int32

}
