//
//  TaskCard.swift
//  To Do List
//
//  Created by Assistant on Card View Implementation
//

import SwiftUI
import UIKit
import CoreData

// MARK: - Task Card Component
struct TaskCard: View {
    let task: NTask
    let onTap: (() -> Void)?
    let onToggleComplete: (() -> Void)?
    
    @State private var isPressed = false
    
    init(
        task: NTask,
        onTap: (() -> Void)? = nil,
        onToggleComplete: (() -> Void)? = nil
    ) {
        self.task = task
        self.onTap = onTap
        self.onToggleComplete = onToggleComplete
    }
    
    var body: some View {
        cardBody
    }
    
    private var completionButton: some View {
        Button(action: {
            onToggleComplete?()
        }) {
            let iconName = task.isComplete ? "checkmark.circle.fill" : "circle"
            let primaryColor = ToDoColors.themes[ToDoColors.currentIndex].primary
            let iconColor = task.isComplete ? Color(primaryColor) : .secondary
            
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .animation(.easeInOut(duration: 0.2), value: task.isComplete)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var taskContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                // Task title
                Text(task.name ?? "Untitled Task")
                    .font(.headline)
                    .foregroundColor(task.isComplete ? .secondary : .primary)
                    .strikethrough(task.isComplete)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Task details
                if let details = taskDetails, !details.isEmpty {
                    Text(details)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // Due date and priority
                HStack(spacing: 8) {
                    if let dueDate = task.dueDate {
                        Label {
                            Text(DateUtils.formatDate(dueDate as Date))
                                .font(.caption2)
                        } icon: {
                            Image(systemName: "calendar")
                                .font(.caption2)
                        }
                        .foregroundColor(dueDateColor)
                    }
                    
                    if task.priority.rawValue > 0 {
                        Label {
                            Text(priorityText)
                                .font(.caption2)
                        } icon: {
                            Image(systemName: "exclamationmark")
                                .font(.caption2)
                        }
                        .foregroundColor(priorityColor)
                    }
                    
                    Spacer()
                }
            }
            
            Spacer()
            
            // Chevron indicator
            if onTap != nil {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(Color.secondary)
            }
        }
    }
    
    var cardBody: some View {
        HStack(spacing: 12) {
            completionButton
            taskContent
        }
        .padding(16)
        .themedMediumCard()
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .onTapGesture {
            onTap?()
        }
        .onLongPressGesture(minimumDuration: 0) { pressing in
            isPressed = pressing
        } perform: {}
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(accessibilityHint)
    }
    
    // MARK: - Computed Properties
    
    private var taskDetails: String? {
        var details: [String] = []
        
        if let taskDetails = task.taskDetails, !taskDetails.isEmpty {
            details.append(taskDetails)
        }
        
        if let project = task.project, !project.isEmpty {
            details.append("📁 \(project)")
        }
        
        return details.isEmpty ? nil : details.joined(separator: " • ")
    }
    
    private var dueDateColor: Color {
        guard let dueDate = task.dueDate else { return .secondary }
        
        let calendar = Calendar.current
        let now = Date()
        
        let dueDateAsDate = dueDate as Date
        if calendar.isDateInToday(dueDateAsDate) {
            return .orange
        } else if dueDateAsDate < now {
            return .red
        } else if calendar.isDateInTomorrow(dueDateAsDate) {
            return .yellow
        } else {
            return .secondary
        }
    }
    
    private var priorityText: String {
        switch task.priority {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .veryLow:
            return "Very Low"
        }
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case .low:
            return .blue
        case .medium:
            return .orange
        case .high:
            return .red
        case .veryLow:
            return .green
        }
    }
    
    private var accessibilityLabel: String {
        var label = "Task: \(task.name ?? "Untitled")"
        
        if task.isComplete {
            label += ", completed"
        }
        
        if let dueDate = task.dueDate {
            label += ", due \(DateUtils.formatDate(dueDate as Date))"
        }
        
        if task.priority.rawValue > 0 {
            label += ", \(priorityText) priority"
        }
        
        return label
    }
    
    private var accessibilityHint: String {
        var hints: [String] = []
        
        if onToggleComplete != nil {
            hints.append("Double tap to toggle completion")
        }
        
        if onTap != nil {
            hints.append("Tap to view details")
        }
        
        return hints.joined(separator: ", ")
    }
}

// MARK: - Task Card Variants

/// Compact version of TaskCard for list views
struct CompactTaskCard: View {
    let task: NTask
    let onTap: (() -> Void)?
    let onToggleComplete: (() -> Void)?
    
    var body: some View {
        HStack(spacing: 12) {
            Button(action: {
                onToggleComplete?()
            }) {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isComplete ? Color(ToDoColors.themes[ToDoColors.currentIndex].primary) : .secondary)
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(task.name ?? "Untitled Task")
                    .font(.subheadline)
                    .foregroundColor(task.isComplete ? .secondary : .primary)
                    .strikethrough(task.isComplete)
                    .lineLimit(1)
                
                if let dueDate = task.dueDate {
                    Text(DateUtils.formatDate(dueDate as Date))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if task.priority.rawValue > 0 {
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(12)
        .themedSmallCard()
        .onTapGesture {
            onTap?()
        }
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .veryLow: return .green
        }
    }
}

/// Featured version of TaskCard for dashboard/home views
struct FeaturedTaskCard: View {
    let task: NTask
    let onTap: (() -> Void)?
    let onToggleComplete: (() -> Void)?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: {
                    onToggleComplete?()
                }) {
                    Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                        .font(.title)
                        .foregroundColor(task.isComplete ? Color(ToDoColors.themes[ToDoColors.currentIndex].primary) : .secondary)
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                if task.priority.rawValue > 0 {
                    Text(priorityText)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(priorityColor.opacity(0.2))
                        .foregroundColor(priorityColor)
                        .clipShape(Capsule())
                }
            }
            
            Text(task.name ?? "Untitled Task")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(task.isComplete ? .secondary : .primary)
                .strikethrough(task.isComplete)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
            
            if let taskDetails = task.taskDetails, !taskDetails.isEmpty {
                Text(taskDetails)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if let dueDate = task.dueDate {
                HStack {
                    Image(systemName: "calendar")
                    Text("Due \(DateUtils.formatDate(dueDate as Date))")
                }
                .font(.caption)
                .foregroundColor(dueDateColor)
            }
        }
        .padding(20)
        .themedLargeCard()
        .onTapGesture {
            onTap?()
        }
    }
    
    private var priorityText: String {
        switch task.priority {
        case .low: return "Low Priority"
        case .medium: return "Medium Priority"
        case .high: return "High Priority"
        case .veryLow: return "Very Low Priority"
        }
    }
    
    private var priorityColor: Color {
        switch task.priority {
        case .low: return .blue
        case .medium: return .orange
        case .high: return .red
        case .veryLow: return .green
        }
    }
    
    private var dueDateColor: Color {
        guard let dueDate = task.dueDate else { return .secondary }
        
        let calendar = Calendar.current
        let now = Date()
        
        let dueDateAsDate = dueDate as Date
        if calendar.isDateInToday(dueDateAsDate) {
            return .orange
        } else if dueDateAsDate < now {
            return .red
        } else if calendar.isDateInTomorrow(dueDateAsDate) {
            return .yellow
        } else {
            return .secondary
        }
    }
}

// MARK: - Preview
#if DEBUG
struct TaskCard_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            TaskCard(
                task: sampleTask,
                onTap: { print("Task tapped") },
                onToggleComplete: { print("Toggle complete") }
            )
            
            CompactTaskCard(
                task: sampleTask,
                onTap: { print("Compact task tapped") },
                onToggleComplete: { print("Toggle complete") }
            )
            
            FeaturedTaskCard(
                task: sampleTask,
                onTap: { print("Featured task tapped") },
                onToggleComplete: { print("Toggle complete") }
            )
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
    
    static var sampleTask: NTask {
        let task = NTask()
        task.name = "Sample Task"
        task.taskDetails = "This is a sample task for preview"
        task.dueDate = Date().addingTimeInterval(86400) as NSDate // Tomorrow
        task.taskPriority = Int32(TaskPriority.medium.rawValue)
        task.isComplete = false
        return task
    }
}
#endif
