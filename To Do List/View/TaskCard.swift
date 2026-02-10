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
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    
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
            let iconColor = task.isComplete ? Color(uiColor: themeColors.accentPrimary) : Color(uiColor: themeColors.textSecondary)
            
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(iconColor)
                .animation(.easeInOut(duration: 0.2), value: task.isComplete)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var taskContent: some View {
        HStack {
            VStack(alignment: .leading, spacing: spacing.titleSubtitleGap) {
                // Task title
                Text(task.name ?? "Untitled Task")
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(task.isComplete ? .secondary : .primary)
                    .strikethrough(task.isComplete)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                
                // Task details
                if let details = taskDetails, !details.isEmpty {
                    Text(details)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                        .lineLimit(1)
                }
                
                // Due date and priority
                HStack(spacing: spacing.s8) {
                    if let dueDate = task.dueDate {
                        Label {
                            Text(DateUtils.formatDate(dueDate as Date))
                                .font(.tasker(.caption2))
                        } icon: {
                            Image(systemName: "calendar")
                                .font(.tasker(.caption2))
                        }
                        .foregroundColor(dueDateColor)
                    }
                    
                    if task.taskPriority > 0 {
                        Label {
                            Text(priorityText)
                                .font(.tasker(.caption2))
                        } icon: {
                            Image(systemName: "exclamationmark")
                                .font(.tasker(.caption2))
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
                    .foregroundColor(Color.tasker.textSecondary)
            }
        }
    }
    
    var cardBody: some View {
        HStack(spacing: spacing.cardStackVertical) {
            completionButton
            taskContent
        }
        .padding(spacing.cardPadding)
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
            return Color(uiColor: themeColors.statusWarning)
        } else if dueDateAsDate < now {
            return Color(uiColor: themeColors.statusDanger)
        } else if calendar.isDateInTomorrow(dueDateAsDate) {
            return Color(uiColor: themeColors.accentPrimary)
        } else {
            return Color(uiColor: themeColors.textSecondary)
        }
    }
    
    private var priorityText: String {
        switch task.taskPriority {
        case 1: return "Highest"
        case 2: return "High"
        case 3: return "Medium"
        case 4: return "Low"
        default: return "Medium"
        }
    }
    
    private var priorityColor: Color {
        switch task.taskPriority {
        case 1: return Color(uiColor: themeColors.statusDanger)
        case 2: return Color(uiColor: themeColors.statusWarning)
        case 3: return Color(uiColor: themeColors.accentPrimary)
        case 4: return Color(uiColor: themeColors.accentMuted)
        default: return Color(uiColor: themeColors.accentPrimary)
        }
    }

    private var themeColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }
    
    private var accessibilityLabel: String {
        var label = "Task: \(task.name ?? "Untitled")"
        
        if task.isComplete {
            label += ", completed"
        }
        
        if let dueDate = task.dueDate {
            label += ", due \(DateUtils.formatDate(dueDate as Date))"
        }
        
        if task.taskPriority > 0 {
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
        HStack(spacing: spacing.cardStackVertical) {
            Button(action: {
                onToggleComplete?()
            }) {
                Image(systemName: task.isComplete ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(task.isComplete ? Color(uiColor: themeColors.accentPrimary) : Color(uiColor: themeColors.textSecondary))
            }
            .buttonStyle(PlainButtonStyle())
            
            VStack(alignment: .leading, spacing: spacing.s2) {
                Text(task.name ?? "Untitled Task")
                    .font(.tasker(.callout))
                    .foregroundColor(task.isComplete ? .secondary : .primary)
                    .strikethrough(task.isComplete)
                    .lineLimit(1)
                
                if let dueDate = task.dueDate {
                    Text(DateUtils.formatDate(dueDate as Date))
                        .font(.tasker(.caption2))
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if task.taskPriority > 0 {
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(spacing.listRowVerticalPadding)
        .themedSmallCard()
        .onTapGesture {
            onTap?()
        }
    }
    
    private var priorityColor: Color {
        switch task.taskPriority {
        case 1: return Color(uiColor: themeColors.statusDanger)
        case 2: return Color(uiColor: themeColors.statusWarning)
        case 3: return Color(uiColor: themeColors.accentPrimary)
        case 4: return Color(uiColor: themeColors.accentMuted)
        default: return Color(uiColor: themeColors.accentPrimary)
        }
    }

    private var themeColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.currentTheme.tokens.spacing
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
                        .foregroundColor(task.isComplete ? Color(uiColor: themeColors.accentPrimary) : Color(uiColor: themeColors.textSecondary))
                }
                .buttonStyle(PlainButtonStyle())
                
                Spacer()
                
                if task.taskPriority > 0 {
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
        switch task.taskPriority {
        case 1: return "Highest Priority"
        case 2: return "High Priority"
        case 3: return "Medium Priority"
        case 4: return "Low Priority"
        default: return "Medium Priority"
        }
    }
    
    private var priorityColor: Color {
        switch task.taskPriority {
        case 1: return Color(uiColor: themeColors.statusDanger)
        case 2: return Color(uiColor: themeColors.statusWarning)
        case 3: return Color(uiColor: themeColors.accentPrimary)
        case 4: return Color(uiColor: themeColors.accentMuted)
        default: return Color(uiColor: themeColors.accentPrimary)
        }
    }
    
    private var dueDateColor: Color {
        guard let dueDate = task.dueDate else { return .secondary }
        
        let calendar = Calendar.current
        let now = Date()
        
        let dueDateAsDate = dueDate as Date
        if calendar.isDateInToday(dueDateAsDate) {
            return Color(uiColor: themeColors.statusWarning)
        } else if dueDateAsDate < now {
            return Color(uiColor: themeColors.statusDanger)
        } else if calendar.isDateInTomorrow(dueDateAsDate) {
            return Color(uiColor: themeColors.accentPrimary)
        } else {
            return Color(uiColor: themeColors.textSecondary)
        }
    }

    private var themeColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
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
        task.taskPriority = Int32(TaskPriority.low.rawValue)
        task.isComplete = false
        return task
    }
}
#endif
