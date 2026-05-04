//
//  TaskDetailComponents.swift
//  LifeBoard
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
        HStack(spacing: LifeBoardTheme.Spacing.sm) {
            PriorityPill(label: "None", color: Color.lifeboard.priorityNone, isSelected: selectedPriority == 1) {
                withAnimation(LifeBoardAnimation.snappy) { selectedPriority = 1 }
                LifeBoardFeedback.selection()
            }
            PriorityPill(label: "Low", color: Color.lifeboard.priorityLow, isSelected: selectedPriority == 2) {
                withAnimation(LifeBoardAnimation.snappy) { selectedPriority = 2 }
                LifeBoardFeedback.selection()
            }
            PriorityPill(label: "High", color: Color.lifeboard.priorityHigh, isSelected: selectedPriority == 3) {
                withAnimation(LifeBoardAnimation.snappy) { selectedPriority = 3 }
                LifeBoardFeedback.selection()
            }
            PriorityPill(label: "Max", color: Color.lifeboard.priorityMax, isSelected: selectedPriority == 4) {
                withAnimation(LifeBoardAnimation.snappy) { selectedPriority = 4 }
                LifeBoardFeedback.selection()
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
                .font(.lifeboard(.callout))
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundColor(isSelected ? .white : color)
                .padding(.horizontal, LifeBoardTheme.Spacing.md)
                .padding(.vertical, LifeBoardTheme.Spacing.sm)
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

/// Compact capsule showing task completion reward.
struct ScoreBadge: View {
    let preview: XPCompletionPreview?
    var reasonHint: String = "priority · on-time · focus · effort · cap"

    var body: some View {
        let label = preview?.shortLabel ?? "XP pending"
        HStack(spacing: 3) {
            Image(systemName: "star.fill")
                .font(.system(size: 10, weight: .bold))
            Text(label)
                .font(.lifeboard(.caption1))
                .fontWeight(.bold)
        }
        .foregroundColor(Color.lifeboard.accentPrimary)
        .padding(.horizontal, LifeBoardTheme.Spacing.sm)
        .padding(.vertical, 4)
        .background(Color.lifeboard.accentMuted)
        .clipShape(Capsule())
        .accessibilityLabel(preview.map { "Reward \($0.shortLabel)" } ?? "Reward pending")
        .accessibilityHint("Reward factors: \(reasonHint)")
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
                .font(.lifeboard(.caption1))
                .fontWeight(.medium)
        }
        .foregroundColor(priorityColor)
        .padding(.horizontal, LifeBoardTheme.Spacing.sm)
        .padding(.vertical, 4)
        .background(priorityColor.opacity(0.12))
        .clipShape(Capsule())
    }

    private var priorityLabel: String {
        switch priority {
        case 1: return "None"
        case 2: return "Low"
        case 3: return "High"
        case 4: return "Max"
        default: return "Low"
        }
    }

    private var priorityColor: Color {
        switch priority {
        case 1: return Color.lifeboard.priorityNone
        case 2: return Color.lifeboard.priorityLow
        case 3: return Color.lifeboard.priorityHigh
        case 4: return Color.lifeboard.priorityMax
        default: return Color.lifeboard.priorityLow
        }
    }
}

// MARK: - Shared Status And Metric Components

@MainActor
enum LifeBoardStatusPillTone {
    case accent
    case neutral
    case success
    case warning
    case danger
    case quiet

    var textColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentPrimary
        case .neutral:
            return Color.lifeboard.textPrimary
        case .success:
            return Color.lifeboard.statusSuccess
        case .warning:
            return Color.lifeboard.statusWarning
        case .danger:
            return Color.lifeboard.statusDanger
        case .quiet:
            return Color.lifeboard.textSecondary
        }
    }

    var fillColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentWash
        case .neutral:
            return Color.lifeboard.surfacePrimary
        case .success:
            return Color.lifeboard.statusSuccess.opacity(0.12)
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.12)
        case .danger:
            return Color.lifeboard.statusDanger.opacity(0.12)
        case .quiet:
            return Color.lifeboard.surfaceSecondary
        }
    }

    var strokeColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentPrimary.opacity(0.2)
        case .neutral:
            return Color.lifeboard.strokeHairline.opacity(0.9)
        case .success:
            return Color.lifeboard.statusSuccess.opacity(0.22)
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.22)
        case .danger:
            return Color.lifeboard.statusDanger.opacity(0.22)
        case .quiet:
            return Color.lifeboard.strokeHairline.opacity(0.72)
        }
    }
}

struct LifeBoardStatusPill: View {
    let text: String
    var systemImage: String? = nil
    var tone: LifeBoardStatusPillTone = .quiet

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 10, weight: .semibold))
            }
            Text(text)
                .lineLimit(1)
        }
        .font(.lifeboard(.caption1).weight(.semibold))
        .foregroundStyle(tone.textColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 6)
        .background(tone.fillColor)
        .overlay(
            Capsule()
                .stroke(tone.strokeColor, lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

@MainActor
enum LifeBoardHeroMetricTone {
    case accent
    case success
    case warning
    case neutral

    var valueColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentPrimary
        case .success:
            return Color.lifeboard.statusSuccess
        case .warning:
            return Color.lifeboard.statusWarning
        case .neutral:
            return Color.lifeboard.textPrimary
        }
    }

    var fillColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentWash.opacity(0.92)
        case .success:
            return Color.lifeboard.statusSuccess.opacity(0.12)
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.12)
        case .neutral:
            return Color.lifeboard.surfacePrimary.opacity(0.8)
        }
    }

    var strokeColor: Color {
        switch self {
        case .accent:
            return Color.lifeboard.accentPrimary.opacity(0.18)
        case .success:
            return Color.lifeboard.statusSuccess.opacity(0.18)
        case .warning:
            return Color.lifeboard.statusWarning.opacity(0.18)
        case .neutral:
            return Color.lifeboard.strokeHairline.opacity(0.72)
        }
    }
}

struct LifeBoardHeroMetricTile: View {
    let title: String
    let value: String
    var detail: String? = nil
    var tone: LifeBoardHeroMetricTone = .neutral
    var accessibilityIdentifier: String? = nil

    var body: some View {
        let tile = VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.lifeboard(.meta))
                .foregroundStyle(Color.lifeboard.textTertiary)
            Text(value)
                .font(.lifeboard(.headline))
                .foregroundStyle(tone.valueColor)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .monospacedDigit()
                .contentTransition(.numericText())
            if let detail, detail.isEmpty == false {
                Text(detail)
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .leading)
        .padding(.horizontal, LifeBoardTheme.Spacing.md)
        .padding(.vertical, LifeBoardTheme.Spacing.sm)
        .lifeboardDenseSurface(
            cornerRadius: LifeBoardTheme.CornerRadius.md,
            fillColor: tone.fillColor,
            strokeColor: tone.strokeColor
        )
        .animation(LifeBoardAnimation.numericUpdate, value: value)

        if let accessibilityIdentifier, accessibilityIdentifier.isEmpty == false {
            tile.accessibilityIdentifier(accessibilityIdentifier)
        } else {
            tile
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

    /// Initializes a new instance.
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
        let resolvedIconColor = iconColor ?? Color.lifeboard.textSecondary
        Button(action: { action?() }) {
            HStack(spacing: LifeBoardTheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(resolvedIconColor)
                    .frame(width: 24, alignment: .center)

                Text(label)
                    .font(.lifeboard(.callout))
                    .foregroundColor(Color.lifeboard.textSecondary)

                Spacer()

                trailing

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.lifeboard.textTertiary)
                }
            }
            .padding(.vertical, LifeBoardTheme.Spacing.md)
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }
}

extension DetailRow where Trailing == Text {
    /// Initializes a new instance.
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
        let resolvedIconColor = iconColor ?? Color.lifeboard.textSecondary
        return Button(action: { action?() }) {
            HStack(spacing: LifeBoardTheme.Spacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(resolvedIconColor)
                    .frame(width: 24, alignment: .center)

                Text(label)
                    .font(.lifeboard(.callout))
                    .foregroundColor(Color.lifeboard.textSecondary)

                Spacer()

                trailing
                    .font(.lifeboard(.bodyEmphasis))
                    .foregroundColor(Color.lifeboard.textPrimary)

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.lifeboard.textTertiary)
                }
            }
            .padding(.vertical, LifeBoardTheme.Spacing.md)
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
        HStack(spacing: LifeBoardTheme.Spacing.sm) {
            LifeBoardChip(title: "Morning", isSelected: selectedType == 1, selectedStyle: .tinted) {
                withAnimation(LifeBoardAnimation.snappy) { selectedType = 1 }
                LifeBoardFeedback.selection()
            }
            LifeBoardChip(title: "Evening", isSelected: selectedType == 2, selectedStyle: .tinted) {
                withAnimation(LifeBoardAnimation.snappy) { selectedType = 2 }
                LifeBoardFeedback.selection()
            }
            LifeBoardChip(title: "Upcoming", isSelected: selectedType == 3, selectedStyle: .tinted) {
                withAnimation(LifeBoardAnimation.snappy) { selectedType = 3 }
                LifeBoardFeedback.selection()
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
                .font(.lifeboard(.caption1))
        }
        .foregroundColor(color)
        .padding(.horizontal, LifeBoardTheme.Spacing.sm)
        .padding(.vertical, 5)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Section Divider

/// Subtle divider with optional section label.
struct TaskDetailSectionDivider: View {
    let title: String?

    /// Initializes a new instance.
    init(_ title: String? = nil) {
        self.title = title
    }

    var body: some View {
        HStack(spacing: LifeBoardTheme.Spacing.sm) {
            if let title {
                Text(title)
                    .font(.lifeboard(.caption1))
                    .fontWeight(.semibold)
                    .foregroundColor(Color.lifeboard.textTertiary)
            }
            Rectangle()
                .fill(Color.lifeboard.strokeHairline)
                .frame(height: 1)
        }
        .padding(.vertical, LifeBoardTheme.Spacing.xs)
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
            withAnimation(LifeBoardAnimation.bouncy) {
                bounceScale = 1.3
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                withAnimation(LifeBoardAnimation.bouncy) {
                    bounceScale = 1.0
                }
            }
            action()
        }) {
            ZStack {
                Circle()
                    .stroke(
                        isComplete ? Color.lifeboard.textTertiary.opacity(0.55) : Color.lifeboard.textQuaternary.opacity(0.6),
                        lineWidth: compact ? 1.8 : 2.2
                    )

                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: compact ? 11 : 14, weight: .semibold))
                        .foregroundColor(Color.lifeboard.textSecondary)
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
