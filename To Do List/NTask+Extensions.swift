//
//  NTask+Extensions.swift
//  To Do List
//
//  Created on 2025-06-06
//  Copyright © 2025 saransh1337. All rights reserved.
//

import Foundation
import CoreData

extension NTask {
    // MARK: - Type-safe Task Type Properties
    
    /// The type of this task as Int32 raw value
    /// 1=morning, 2=evening, 3=upcoming, 4=inbox
    var type: Int32 {
        get {
            return self.taskType
        }
        set {
            self.taskType = newValue
        }
    }
    
    /// Returns true if this is a morning task
    var isMorningTask: Bool {
        return type == 1 // .morning
    }
    
    /// Updates both isEveningTask and taskType to maintain consistency
    /// This method should be called whenever you need to change the evening status of a task
    func updateEveningTaskStatus(_ isEvening: Bool) {
        // Update the Core Data property
        self.isEveningTask = isEvening
        // Update the task type for consistency
        if isEvening {
            self.taskType = 2 // TaskType.evening.rawValue
        } else if self.taskType == 2 { // TaskType.evening.rawValue
            // Only change to morning if it was evening before
            self.taskType = 1 // TaskType.morning.rawValue
        }
    }
    
    /// Returns true if this is an upcoming task
    var isUpcomingTask: Bool {
        return type == 3 // .upcoming
    }
    
    // MARK: - Type-safe Task Priority Properties
    
    /// The priority of this task as a TaskPriority enum
    // Use raw Int32 values to avoid enum visibility issues
    var priorityRawValue: Int32 {
        get {
            return self.taskPriority
        }
        set {
            self.taskPriority = newValue
        }
    }
    
    /// Returns true if this task has maximum priority.
    var isHighestPriority: Bool {
        return self.taskPriority == TaskPriority.max.rawValue
    }
    
    /// Returns true if this task has high priority.
    var isHighPriority: Bool {
        return self.taskPriority == TaskPriority.high.rawValue
    }
    
    /// Returns true if this task has low priority (legacy medium alias).
    var isMediumPriority: Bool {
        return self.taskPriority == TaskPriority.low.rawValue
    }
    
    /// Returns true if this task has no priority (legacy low alias).
    var isLowPriority: Bool {
        return self.taskPriority == TaskPriority.none.rawValue
    }
}
