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
    @NSManaged public var taskPriority: Int32 //1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is p4; default is 3(p2)
    @NSManaged public var taskType: Int32 //1-4 where 1 is morning; 2 is evening; 3 is upcoming; 4 is inbox; default is 1(morning)
    @NSManaged public var alertReminderTime: NSDate?
    @NSManaged public var dateAdded: NSDate?
    @NSManaged public var isEveningTask: Bool
    

    func getTaskScore(task: NTask) -> Int {
        if task.taskPriority == 1 {
            return 7
        } else if task.taskPriority == 2 {
            return 4
        } else if task.taskPriority == 3 {
            return 3
        } else if task.taskPriority == 4 {
            return 2
        }
        else {
            return 1
        }
    }
}
