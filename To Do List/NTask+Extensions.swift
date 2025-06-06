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
    
    /// The type of this task as a TaskType enum
    var type: TaskType {
        get {
            return TaskType(rawValue: self.taskType) ?? .morning
        }
        set {
            self.taskType = newValue.rawValue
        }
    }
    
    /// Returns true if this is a morning task
    var isMorningTask: Bool {
        return type == .morning
    }
    
    /// Updates both isEveningTask and taskType to maintain consistency
    /// This method should be called whenever you need to change the evening status of a task
    func updateEveningTaskStatus(_ isEvening: Bool) {
        // Update the Core Data property
        self.isEveningTask = isEvening
        // Update the task type for consistency
        if isEvening {
            self.taskType = TaskType.evening.rawValue
        } else if self.taskType == TaskType.evening.rawValue {
            // Only change to morning if it was evening before
            self.taskType = TaskType.morning.rawValue
        }
    }
    
    /// Returns true if this is an upcoming task
    var isUpcomingTask: Bool {
        return type == .upcoming
    }
    
    // MARK: - Type-safe Task Priority Properties
    
    /// The priority of this task as a TaskPriority enum
    var priority: TaskPriority {
        get {
            return TaskPriority(rawValue: self.taskPriority) ?? .medium
        }
        set {
            self.taskPriority = newValue.rawValue
        }
    }
    
    /// Returns true if this task has high priority
    var isHighPriority: Bool {
        return priority == .high
    }
    
    /// Returns true if this task has medium priority
    var isMediumPriority: Bool {
        return priority == .medium
    }
    
    /// Returns true if this task has low priority
    var isLowPriority: Bool {
        return priority == .low
    }
}
