//
//  ToDoManager.swift
//  To Do List
//
//  Created by Saransh Sharma on 30/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit

class OLD_TodoManager {
    // Singleon
    static let sharedInstance = OLD_TodoManager()
    
    var tasks = [OLD_Task]()
    var eveningTasks = [OLD_Task]()
    var mornningTasks = [OLD_Task]()
    
    var count: Int {
        get {
            return tasks.count
        }
    }
    var getEveningTasks: [OLD_Task] {
        get {
            var eveningTasks = [OLD_Task]()
            for item in tasks {
                if item.type == .evening {
                    eveningTasks.append(item)
                }
                       
            }
            return eveningTasks
        }
    }
    var getMornningTasks: [OLD_Task] {
        get {
            var morningTasks = [OLD_Task]()
            for item in tasks {
                if item.type == .today {
                    morningTasks.append(item)
                }
                       
            }
            return morningTasks
        }
    }
    

    
    func taskAtIndex(index: Int) -> OLD_Task {
        return tasks[index]
    }
    
    func addTaskWithName(name: String) {
        let task = OLD_Task(withName: name)
        tasks.append(task)
    }
    
    // MARK: Init
    
    private init() {
        tasks.append(OLD_Task(withName: "Swipe me to left to complete your first task !", withPriority: TaskPriority.p0))
        tasks.append(OLD_Task(withName: "Create your first task by clicking on the + sign", withPriority: TaskPriority.p1))
        tasks.append(OLD_Task(withName: "Delete me by swiping to the right", withPriority: TaskPriority.p2))
//        tasks.append(Task(withName: "Meet Batman", withPriority: TaskPriority.p3))
        tasks.append(OLD_Task(withName: "Meet Batman", withTaskType: TaskType.evening))
    }
}
