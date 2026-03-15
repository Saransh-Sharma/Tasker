import SwiftUI

private struct TaskerOptionalAccessibilityIdentifier: ViewModifier {
    let identifier: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let identifier {
            content.accessibilityIdentifier(identifier)
        } else {
            content
        }
    }
}

extension View {
    @ViewBuilder
    func taskerPressFeedback(reduceMotion: Bool) -> some View {
        if reduceMotion {
            self
        } else {
            self.scaleOnPress()
        }
    }

    func taskerAccessibilityIdentifier(_ identifier: String?) -> some View {
        modifier(TaskerOptionalAccessibilityIdentifier(identifier: identifier))
    }
}

struct TaskerFilterChip: View {
    let title: String
    var systemImage: String? = nil
    var count: Int? = nil
    var isSelected: Bool = true
    var isDestructive: Bool = false
    var accentColor: Color? = nil
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        Button(action: handleTap) {
            chipLabel
        }
        .buttonStyle(.plain)
        .taskerPressFeedback(reduceMotion: reduceMotion)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isSelected ? "Selected" : "Double tap to apply")
        .accessibilityValue(isSelected ? "selected" : "unselected")
        .taskerAccessibilityIdentifier(accessibilityIdentifier)
    }

    private func handleTap() {
        TaskerFeedback.light()
        action()
    }

    private var chipLabel: some View {
        HStack(spacing: spacing.s8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
            }

            Text(title)
                .font(.tasker(.caption1))
                .fontWeight(.semibold)
                .lineLimit(1)

            if let count {
                Text("\(count)")
                    .font(.tasker(.caption2))
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, spacing.s2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.tasker.surfacePrimary.opacity(0.92))
                    )
            }
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 36)
        .taskerChromeSurface(
            cornerRadius: 18,
            accentColor: resolvedAccentColor,
            level: .e1
        )
        .overlay(
            Capsule(style: .continuous)
                .fill(chipFillColor)
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(chipStrokeColor, lineWidth: 1)
        )
        .activeGlow(isActive: isSelected && !isDestructive, color: resolvedAccentColor)
    }

    private var resolvedAccentColor: Color {
        if let accentColor {
            return accentColor
        }
        return isDestructive ? Color.tasker.statusDanger : Color.tasker.accentPrimary
    }

    private var foregroundColor: Color {
        if isDestructive {
            return Color.tasker.statusDanger
        }
        return isSelected ? Color.tasker.textPrimary : Color.tasker.textSecondary
    }

    private var chipFillColor: Color {
        if isSelected {
            return resolvedAccentColor.opacity(isDestructive ? 0.08 : 0.14)
        }
        return Color.clear
    }

    private var chipStrokeColor: Color {
        if isSelected {
            return resolvedAccentColor.opacity(isDestructive ? 0.24 : 0.34)
        }
        return Color.tasker.strokeHairline.opacity(0.24)
    }

    private var accessibilityLabel: String {
        var parts = [title]
        if let count {
            parts.append("\(count) items")
        }
        if isDestructive {
            parts.append("destructive")
        }
        return parts.joined(separator: ", ")
    }
}

struct TaskerFilterRow: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    var count: Int? = nil
    var isMultiSelect: Bool = false
    var systemImage: String? = nil
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        Button(action: action) {
            rowLabel
        }
        .buttonStyle(.plain)
        .taskerPressFeedback(reduceMotion: reduceMotion)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isSelected ? "Selected" : "Double tap to apply")
        .taskerAccessibilityIdentifier(accessibilityIdentifier)
    }

    private var rowLabel: some View {
        HStack(spacing: spacing.s12) {
            Image(systemName: selectionIcon)
                .font(.system(size: 18))
                .foregroundStyle(isSelected ? rowAccent : Color.tasker.textTertiary)
                .animation(reduceMotion ? nil : TaskerAnimation.quick, value: isSelected)

            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.tasker.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.tasker(.caption2))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let count {
                Text("\(count)")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .padding(.horizontal, spacing.s8)
                    .padding(.vertical, spacing.s2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.tasker.surfaceSecondary)
                    )
            }

            if systemImage != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.tasker.textTertiary)
            }
        }
        .padding(.horizontal, spacing.s20)
        .padding(.vertical, spacing.s12)
        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? rowAccent.opacity(0.14) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? rowAccent.opacity(0.24) : Color.clear, lineWidth: 1)
        )
        .contentShape(Rectangle())
    }

    private var selectionIcon: String {
        if isMultiSelect {
            return isSelected ? "checkmark.square.fill" : "square"
        }
        return isSelected ? "checkmark.circle.fill" : "circle"
    }

    private var accessibilityLabel: String {
        var label = title
        if let count {
            label += ", \(count) items"
        }
        if isSelected {
            label += ", selected"
        }
        return label
    }

    private var rowAccent: Color {
        if systemImage == "calendar" {
            return Color.tasker.accentSecondary
        }
        return isSelected ? Color.tasker.accentPrimary : Color.tasker.accentSecondary
    }
}

struct TaskerFilterSectionHeader: View {
    let title: String
    var index: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        let header = Text(title)
            .font(.tasker(.caption1))
            .foregroundStyle(Color.tasker.textSecondary)
            .padding(.horizontal, spacing.s20)
            .padding(.top, spacing.s12)
            .padding(.bottom, spacing.s8)

        if reduceMotion {
            header
        } else {
            header.enhancedStaggeredAppearance(index: index)
        }
    }
}

struct TaskerFilterSheetContainer<Content: View>: View {
    let horizontalPadding: CGFloat
    let bottomPadding: CGFloat
    @ViewBuilder let content: () -> Content

    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    init(
        horizontalPadding: CGFloat,
        bottomPadding: CGFloat,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.horizontalPadding = horizontalPadding
        self.bottomPadding = bottomPadding
        self.content = content
    }

    var body: some View {
        content()
            .taskerPremiumSurface(
                cornerRadius: corner.modal,
                fillColor: Color.tasker.surfacePrimary,
                strokeColor: Color.tasker.strokeHairline.opacity(0.85),
                accentColor: Color.tasker.accentSecondary,
                level: .e3
            )
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, bottomPadding)
    }
}
