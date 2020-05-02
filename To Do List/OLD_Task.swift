//
//  Task.swift
//  To Do List
//
//  Created by Saransh Sharma on 25/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation

class OLD_Task {
    
    var name: String
    var type: TaskType
    var completed: Bool
    var lastCompleted: NSDate?
    var taskCreationDate: NSDate?
    var priority: TaskPriority?
    
    
    init(withName: String) {
        self.name = withName
        self.type = TaskType.today
        self.completed = false
        //self.lastCompleted =
        //        self.taskCreationDate =
        self.priority = TaskPriority.p2
    }
    
    init(withName: String, withTaskType: TaskType) {
        self.name = withName
        self.type = withTaskType
        self.completed = false
        //self.lastCompleted =
        //        self.taskCreationDate =
        self.priority = TaskPriority.p2
    }
    
    init(withName: String, withTaskType: TaskType, withPriority: TaskPriority) {
          self.name = withName
          self.type = withTaskType
          self.completed = false
          //self.lastCompleted =
          //        self.taskCreationDate =
          self.priority = withPriority
      }
    
    init(withName: String, withPriority: TaskPriority) {
        self.name = withName
        self.type = TaskType.today
        self.completed = false
        //self.lastCompleted =
        //        self.taskCreationDate =
        self.priority = withPriority
    }
    
    func markComplete(task: OLD_Task) -> OLD_Task {
        task.completed = true
        return task
    }
    
    func markIncomplete(task: OLD_Task) -> OLD_Task {
        task.completed = false
        return task
    }
    
    func makeEveningTask(task: OLD_Task) -> OLD_Task {
        task.type = .evening
        return task
    }
    
    func calcTaskScore(task: OLD_Task) -> Int {
        let priority = task.priority
        if priority == .p0 {
            return 7
        } else if priority == .p1 {
            return 4
        } else if priority == .p2  {
            return 3
        } else if priority == .p3 {
            return 2
        }
        else {
            return 1
        }
       }
    
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
