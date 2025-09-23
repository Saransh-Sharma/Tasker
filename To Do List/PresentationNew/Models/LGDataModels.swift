// LGDataModels.swift
// Data models for Liquid Glass UI components
// Bridges between Core Data entities and UI components

import Foundation
import UIKit

// MARK: - Task Card Data

struct TaskCardData {
    let id: String
    let title: String
    let description: String
    let dueDate: Date?
    let priority: TaskPriority
    let project: ProjectData?
    let progress: Float
    let isCompleted: Bool
    
    init(id: String, title: String, description: String, dueDate: Date?, priority: TaskPriority, project: ProjectData?, progress: Float, isCompleted: Bool) {
        self.id = id
        self.title = title
        self.description = description
        self.dueDate = dueDate
        self.priority = priority
        self.project = project
        self.progress = progress
        self.isCompleted = isCompleted
    }
}

// MARK: - Project Data

struct ProjectData {
    let id: String
    let name: String
    let color: UIColor
    let iconName: String
    let taskCount: Int
    let completedCount: Int
    
    var completionPercentage: Float {
        guard taskCount > 0 else { return 0.0 }
        return Float(completedCount) / Float(taskCount)
    }
    
    init(id: String, name: String, color: UIColor, iconName: String, taskCount: Int, completedCount: Int) {
        self.id = id
        self.name = name
        self.color = color
        self.iconName = iconName
        self.taskCount = taskCount
        self.completedCount = completedCount
    }
}

// MARK: - Task Priority

enum TaskPriority: Int, CaseIterable {
    case lowest = 5
    case low = 4
    case medium = 3
    case high = 2
    case highest = 1
    
    var displayName: String {
        switch self {
        case .lowest: return "Lowest"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .highest: return "Highest"
        }
    }
    
    var color: UIColor {
        switch self {
        case .lowest: return .systemGray
        case .low: return .systemBlue
        case .medium: return .systemOrange
        case .high: return .systemRed
        case .highest: return .systemPurple
        }
    }
    
    var iconName: String {
        switch self {
        case .lowest: return "arrow.down.circle"
        case .low: return "minus.circle"
        case .medium: return "equal.circle"
        case .high: return "plus.circle"
        case .highest: return "arrow.up.circle"
        }
    }
}

// MARK: - Core Data Extensions

extension NTask {
    var taskCardData: TaskCardData {
        return TaskCardData(
            id: objectID.uriRepresentation().absoluteString,
            title: taskName ?? "Untitled Task",
            description: taskDescription ?? "",
            dueDate: dueDate,
            priority: TaskPriority(rawValue: Int(taskPriority)) ?? .medium,
            project: taskProject?.projectData,
            progress: isComplete ? 1.0 : 0.0,
            isCompleted: isComplete
        )
    }
}

extension Projects {
    var projectData: ProjectData {
        let allTasks = taskList?.allObjects as? [NTask] ?? []
        let completedTasks = allTasks.filter { $0.isComplete }
        
        return ProjectData(
            id: objectID.uriRepresentation().absoluteString,
            name: projectName ?? "Untitled Project",
            color: UIColor(named: projectColor ?? "systemBlue") ?? .systemBlue,
            iconName: projectIcon ?? "folder.fill",
            taskCount: allTasks.count,
            completedCount: completedTasks.count
        )
    }
}
