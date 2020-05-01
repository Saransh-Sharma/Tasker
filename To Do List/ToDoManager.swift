//
//  ToDoManager.swift
//  To Do List
//
//  Created by Saransh Sharma on 30/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit

class TodoManager {
    // Singleon
    static let sharedInstance = TodoManager()
    
    var tasks = [Task]()
    var eveningTasks = [Task]()
    var mornningTasks = [Task]()
    
    var count: Int {
        get {
            return tasks.count
        }
    }
    var getEveningTasks: [Task] {
        get {
            var eveningTasks = [Task]()
            for item in tasks {
                if item.type == .evening {
                    eveningTasks.append(item)
                }
                       
            }
            return eveningTasks
        }
    }
    var getMornningTasks: [Task] {
        get {
            var morningTasks = [Task]()
            for item in tasks {
                if item.type == .today {
                    morningTasks.append(item)
                }
                       
            }
            return morningTasks
        }
    }
    

    
    func taskAtIndex(index: Int) -> Task {
        return tasks[index]
    }
    
    func addTaskWithName(name: String) {
        let task = Task(withName: name)
        tasks.append(task)
    }
    
    // MARK: Init
    
    private init() {
        tasks.append(Task(withName: "Swipe me to left to complete your first task !", withPriority: TaskPriority.p0))
        tasks.append(Task(withName: "Create your first task by clicking on the + sign", withPriority: TaskPriority.p1))
        tasks.append(Task(withName: "Delete me by swiping to the right", withPriority: TaskPriority.p2))
//        tasks.append(Task(withName: "Meet Batman", withPriority: TaskPriority.p3))
        tasks.append(Task(withName: "Meet Batman", withTaskType: TaskType.evening))
    }
}
