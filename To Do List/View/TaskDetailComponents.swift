//
//  TaskDetailComponents.swift
//  Tasker
//
//  Reusable subcomponents for the Task Detail Sheet.
//  Uses the Obsidian & Gems design system tokens throughout.
//

import SwiftUI

// MARK: - Priority Pill Selector

/// Horizontal row of tappable priority pills with jewel-tone colors.
struct PriorityPillSelector: View {
    @Binding var selectedPriority: Int32

    var body: some View {
        HStack(spacing: TaskerTheme.Spacing.sm) {
            PriorityPill(label: "None", color: Color.tasker.priorityNone, isSelected: selectedPriority == 4) {
                withAnimation(TaskerAnimation.snappy) { selectedPriority = 4 }
                TaskerHaptic.selection()
            }
            PriorityPill(label: "Low", color: Color.tasker.priorityLow, isSelected: selectedPriority == 3) {
                withAnimation(TaskerAnimation.snappy) { selectedPriority = 3 }
                TaskerHaptic.selection()
            }
            PriorityPill(label: "High", color: Color.tasker.priorityHigh, isSelected: selectedPriority == 2) {
                withAnimation(TaskerAnimation.snappy) { selectedPriority = 2 }
                TaskerHaptic.selection()
            }
            PriorityPill(label: "Max", color: Color.tasker.priorityMax, isSelected: selectedPriority == 1) {
                withAnimation(TaskerAnimation.snappy) { selectedPriority = 1 }
                TaskerHaptic.selection()
            }
        }
    }
}

/// Individual priority pill button.
private struct PriorityPill: View {
    let label: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.tasker(.callout))
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, TaskerTheme.Spacing.md)
                .padding(.vertical, TaskerTheme.Spacing.sm)
                .frame(minHeight: 36)
                .background(isSelected ? color : color.opacity(0.12))
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color : color.opacity(0.3), lineWidth: isSelected ? 0 : 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .scaleOnPress()
    }
}

// MARK: - Score Badge

/// Compact capsule showing XP points earned for task priority.
struct ScoreBadge: View {
    let points: Int

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 10, weight: .bold))
            Text("\(points) XP")
                .font(.tasker(.caption1))
                .fontWeight(.bold)
        }
        .foregroundColor(Color.tasker.accentPrimary)
        .padding(.horizontal, TaskerTheme.Spacing.sm)
        .padding(.vertical, 4)
        .background(Color.tasker.accentMuted)
        .clipShape(Capsule())
    }
}

// MARK: - Priority Badge

/// Colored capsule showing current priority level.
struct PriorityBadge: View {
    let priority: Int32

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(priorityColor)
                .frame(width: 6, height: 6)
            Text(priorityLabel)
                .font(.tasker(.caption1))
                .fontWeight(.medium)
        }
        .foregroundColor(priorityColor)
        .padding(.horizontal, TaskerTheme.Spacing.sm)
        .padding(.vertical, 4)
        .background(priorityColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var priorityLabel: String {
        switch priority {
        case 1: return "Max"
        case 2: return "High"
        case 3: return "Low"
        case 4: return "None"
        default: return "Low"
        }
    }

    private var priorityColor: Color {
        switch priority {
        case 1: return Color.tasker.priorityMax
        case 2: return Color.tasker.priorityHigh
        case 3: return Color.tasker.priorityLow
        case 4: return Color.tasker.priorityNone
        default: return Color.tasker.priorityLow
        }
    }
}

// MARK: - Detail Row

/// Settings-style row with icon, label, value, and optional chevron.
struct DetailRow<Trailing: View>: View {
    let icon: String
    let iconColor: Color?
    let label: String
    let trailing: Trailing
    var action: (() -> Void)?

    init(
        icon: String,
        iconColor: Color? = nil,
        label: String,
        action: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.label = label
        self.action = action
        self.trailing = trailing()
    }

    var body: some View {
        let resolvedIconColor = iconColor ?? Color.tasker.textSecondary
        Button(action: { action?() }) {
            HStack(spacing: TaskerTheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(resolvedIconColor)
                    .frame(width: 24, alignment: .center)

                Text(label)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textSecondary)

                Spacer()

                trailing

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.tasker.textTertiary)
                }
            }
            .padding(.vertical, TaskerTheme.Spacing.md)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

extension DetailRow where Trailing == Text {
    init(
        icon: String,
        iconColor: Color? = nil,
        label: String,
        value: String,
        valueColor: Color? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.iconColor = iconColor
        self.label = label
        self.action = action
        // Note: Color resolved in body
        self.trailing = Text(value)
    }

    var resolvedBody: some View {
        let resolvedIconColor = iconColor ?? Color.tasker.textSecondary
        return Button(action: { action?() }) {
            HStack(spacing: TaskerTheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(resolvedIconColor)
                    .frame(width: 24, alignment: .center)

                Text(label)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textSecondary)

                Spacer()

                trailing
                    .font(.tasker(.bodyEmphasis))
                    .foregroundColor(Color.tasker.textPrimary)

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.tasker.textTertiary)
                }
            }
            .padding(.vertical, TaskerTheme.Spacing.md)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

// MARK: - Type Chip Selector

/// Morning / Evening / Upcoming task type selector.
struct TypeChipSelector: View {
    @Binding var selectedType: Int32

    var body: some View {
        HStack(spacing: TaskerTheme.Spacing.sm) {
            TaskerChip(title: "Morning", isSelected: selectedType == 1, selectedStyle: .tinted) {
                withAnimation(TaskerAnimation.snappy) { selectedType = 1 }
                TaskerHaptic.selection()
            }
            TaskerChip(title: "Evening", isSelected: selectedType == 2, selectedStyle: .tinted) {
                withAnimation(TaskerAnimation.snappy) { selectedType = 2 }
                TaskerHaptic.selection()
            }
            TaskerChip(title: "Upcoming", isSelected: selectedType == 3, selectedStyle: .tinted) {
                withAnimation(TaskerAnimation.snappy) { selectedType = 3 }
                TaskerHaptic.selection()
            }
        }
    }
}

// MARK: - Info Pill

/// Compact metadata pill with icon and text.
struct InfoPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .medium))
            Text(text)
                .font(.tasker(.caption1))
        }
        .foregroundColor(color)
        .padding(.horizontal, TaskerTheme.Spacing.sm)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Section Divider

/// Subtle divider with optional section label.
struct TaskDetailSectionDivider: View {
    let title: String?

    init(_ title: String? = nil) {
        self.title = title
    }

    var body: some View {
        HStack(spacing: TaskerTheme.Spacing.sm) {
            if let title {
                Text(title.uppercased())
                    .font(.tasker(.caption2))
                    .fontWeight(.semibold)
                    .foregroundColor(Color.tasker.textTertiary)
                    .tracking(0.8)
            }
            Rectangle()
                .fill(Color.tasker.strokeHairline)
                .frame(height: 1)
        }
        .padding(.vertical, TaskerTheme.Spacing.xs)
    }
}

// MARK: - Completion Checkbox

/// Animated completion checkbox with bounce and haptic feedback.
struct CompletionCheckbox: View {
    let isComplete: Bool
    var compact: Bool = false
    let action: () -> Void

    @State private var bounceScale: CGFloat = 1.0

    var body: some View {
        Button(action: {
            withAnimation(TaskerAnimation.bouncy) {
                bounceScale = 1.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(TaskerAnimation.bouncy) {
                    bounceScale = 1.0
                }
            }
            action()
        }) {
            ZStack {
                Circle()
                    .stroke(
                        isComplete ? Color.tasker.textTertiary.opacity(0.55) : Color.tasker.textQuaternary.opacity(0.6),
                        lineWidth: compact ? 1.8 : 2.2
                    )

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: compact ? 11 : 14, weight: .semibold))
                        .foregroundColor(Color.tasker.textSecondary)
                        .transition(.opacity.combined(with: .scale))
                }
            }
            .scaleEffect(bounceScale)
        }
        .buttonStyle(.plain)
        .frame(width: compact ? 30 : 44, height: compact ? 30 : 44)
        .accessibilityLabel(isComplete ? "Completed" : "Not completed")
        .accessibilityHint("Double tap to toggle completion")
    }
}
