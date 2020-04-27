//
//  Task.swift
//  To Do List
//
//  Created by Saransh Sharma on 25/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation

class Task {
    
    var name: String = "error1! You should not be seeing this!"
    var type: TaskType = TaskType.today
    var completed: Bool = false
    var lastCompleted: NSDate?
    var taskCreationDate: NSDate?
    var priority: TaskPriority?
    
    //remove this or take value from the textbox
    init() {
        self.name = "error2! You should not be seeing this!"
        self.type = TaskType.today
        self.completed = false
        //self.lastCompleted =
        //        self.taskCreationDate =
        self.priority = TaskPriority.p2
    }
    
    init(withName: String) {
        self.name = withName
        self.type = TaskType.today
        self.completed = false
        //self.lastCompleted =
        //        self.taskCreationDate =
        self.priority = TaskPriority.p2
    }
    
    init(withName: String, withPriority: TaskPriority) {
        self.name = withName
        self.type = TaskType.today
        self.completed = false
        //self.lastCompleted =
        //        self.taskCreationDate =
        self.priority = withPriority
    }
    
    func toggleCompleted(completedStatus: Bool) -> Bool {
        return !completedStatus
    }
    
    func calculateTaskPoints(priority: TaskPriority) -> Int {
        if TaskPriority.p0 == .p0 {
            return 7
        } else if TaskPriority.p1 == .p1 {
            return 4
        } else if TaskPriority.p2 == .p2  {
            return 3
        } else if TaskPriority.p3 == .p3 {
            return 2
        }
        else {
            return 1
        }        
    }
    
}
/*
 today is the current day
 evening is the current day evening
 upcoming is any task in future with a date that is not today
 inbox is any task which doesnt have a date
 */
enum TaskType {
    case today, evening, upcoming, inbox
}

/*
 p0 is highest priority & has the highest points
 p1 is second hiighest & has second highest points
 */
enum TaskPriority {
    case p0, p1, p2, p3
}
