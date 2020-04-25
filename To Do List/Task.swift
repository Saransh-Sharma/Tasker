//
//  Task.swift
//  To Do List
//
//  Created by Saransh Sharma on 25/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import Foundation

enum TaskType {
    case today, evening, week, someday
}

enum TaskPriority {
    case p0, p1, p2, p3
}

struct Task {
    
    var name: String
    var type: TaskType
    var completed: Bool
    var lastCompleted: NSDate?
    var taskCreationDate: NSDate?
    var priority: TaskPriority?
}
