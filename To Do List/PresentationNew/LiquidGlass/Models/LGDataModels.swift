// LGDataModels.swift
// Data models for Liquid Glass UI components
// These are temporary models for testing - will be replaced with actual domain models

import UIKit
import Foundation

// MARK: - Task Priority
enum TaskPriority: Int, CaseIterable {
    case low = 0
    case medium = 1
    case high = 2
    case urgent = 3
    
    var color: UIColor {
        switch self {
        case .low: return .systemGreen
        case .medium: return .systemYellow
        case .high: return .systemOrange
        case .urgent: return .systemRed
        }
    }
    
    var title: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .urgent: return "Urgent"
        }
    }
}

// MARK: - Task Card Data Model
struct TaskCardData {
    let id: String
    let title: String
    let description: String?
    let dueDate: Date?
    let priority: TaskPriority
    let project: ProjectData?
    let progress: Float
    let isCompleted: Bool
    
    init(id: String, title: String, description: String? = nil, dueDate: Date? = nil, priority: TaskPriority, project: ProjectData? = nil, progress: Float = 0.0, isCompleted: Bool = false) {
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

// MARK: - Project Data Model
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

// MARK: - Button Styles
extension LGButton {
    enum Style {
        case primary
        case secondary
        case ghost
        case destructive
    }
    
    enum Size {
        case small
        case medium
        case large
    }
}

// MARK: - TextField Styles
extension LGTextField {
    enum Style {
        case standard
        case outlined
        case filled
    }
}

// MARK: - Progress Bar Styles
extension LGProgressBar {
    enum Style {
        case `default`
        case success
        case warning
        case error
        case info
    }
}
