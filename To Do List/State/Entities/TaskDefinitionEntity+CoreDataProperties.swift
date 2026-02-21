//
//  TaskDefinitionEntity+CoreDataProperties.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//
//

import Foundation
import CoreData


extension TaskDefinitionEntity {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<TaskDefinitionEntity> {
        return NSFetchRequest<TaskDefinitionEntity>(entityName: "TaskDefinition")
    }

    /// Executes getTaskScore.
    @NSManaged public var taskID: UUID?
    @NSManaged public var projectID: UUID?
    @NSManaged public var lifeAreaID: UUID?
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var notes: String?
    @NSManaged public var status: String?
    @NSManaged public var sectionID: UUID?
    @NSManaged public var parentTaskID: UUID?
    @NSManaged public var recurrenceSeriesID: UUID?
    @NSManaged public var habitDefinitionID: UUID?
    @NSManaged public var priority: Int32
    @NSManaged public var energy: String?
    @NSManaged public var category: String?
    @NSManaged public var context: String?
    @NSManaged public var estimatedDuration: Double
    @NSManaged public var actualDuration: Double
    @NSManaged public var source: String?
    @NSManaged public var repeatPatternData: Data?
    @NSManaged public var createdBy: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var createdAt: NSDate?
    @NSManaged public var updatedAt: NSDate?
    @NSManaged public var updatedByDeviceID: String?
    @NSManaged public var version: Int32
    @NSManaged public var isComplete: Bool
    @NSManaged public var dueDate: NSDate?
    @NSManaged public var taskType: Int32 //1-4 where 1 is morning; 2 is evening; 3 is upcoming; 4 is inbox; default is 1(morning)
    @NSManaged public var alertReminderTime: NSDate?
    @NSManaged public var dateAdded: NSDate?
    @NSManaged public var isEveningTask: Bool
    @NSManaged public var dateCompleted: NSDate? //date its marked done

    

    func getTaskScore(task: TaskDefinitionEntity) -> Int {
        return TaskPriorityConfig.scoreForRawValue(task.priority)
    }
    
//    func getProjectScore(task: TaskDefinitionEntity) -> Int {
//
//     }
}
