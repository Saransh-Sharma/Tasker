//
//  UrgencyBadge.swift
//  Tasker
//
//  Pill-shaped urgency indicator for task rows.
//  Red for Overdue, Amber for Due Soon, Green for Today.
//

import SwiftUI

// MARK: - Urgency Level

public enum UrgencyLevel {
    case overdue
    case dueSoon
    case today
    case none

    public static func from(task: DomainTask, now: Date = Date()) -> UrgencyLevel {
        guard !task.isComplete else { return .none }
        if task.isOverdue { return .overdue }
        guard let dueDate = task.dueDate else { return .none }
        let timeRemaining = dueDate.timeIntervalSince(now)
        if timeRemaining > 0, timeRemaining <= (2 * 60 * 60) { return .dueSoon }
        if Calendar.current.isDateInToday(dueDate) { return .today }
        return .none
    }
}

// MARK: - Urgency Badge

public struct UrgencyBadge: View {
    let level: UrgencyLevel
    var isCompact: Bool = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    public var body: some View {
        switch level {
        case .overdue:
            badgeContent(
                icon: "exclamationmark.circle.fill",
                text: "Overdue",
                backgroundColor: Color.tasker.statusDanger.opacity(0.15),
                foregroundColor: Color.tasker.statusDanger
            )
        case .dueSoon:
            badgeContent(
                icon: "clock.fill",
                text: "Due soon",
                backgroundColor: Color.tasker.statusWarning.opacity(0.15),
                foregroundColor: Color.tasker.statusWarning
            )
        case .today:
            badgeContent(
                icon: "checkmark.circle.fill",
                text: "Today",
                backgroundColor: Color.tasker.statusSuccess.opacity(0.12),
                foregroundColor: Color.tasker.statusSuccess
            )
        case .none:
            EmptyView()
        }
    }

    @ViewBuilder
    private func badgeContent(icon: String, text: String, backgroundColor: Color, foregroundColor: Color) -> some View {
        HStack(spacing: 3) {
            if !isCompact {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .medium))
            }
            Text(text)
                .font(.tasker(.caption2))
                .fontWeight(.medium)
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, isCompact ? 5 : 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
        .fixedSize()
    }
}

// MARK: - Preview

#if DEBUG
struct UrgencyBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            UrgencyBadge(level: .overdue)
            UrgencyBadge(level: .dueSoon)
            UrgencyBadge(level: .today)
            UrgencyBadge(level: .none)

            Divider()

            Text("Compact variants:")
            HStack(spacing: 8) {
                UrgencyBadge(level: .overdue, isCompact: true)
                UrgencyBadge(level: .dueSoon, isCompact: true)
                UrgencyBadge(level: .today, isCompact: true)
            }
        }
        .padding()
        .background(Color.tasker.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif
