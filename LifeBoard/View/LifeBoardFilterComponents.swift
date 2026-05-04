import SwiftUI

private struct LifeBoardOptionalAccessibilityIdentifier: ViewModifier {
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
    func lifeboardPressFeedback(reduceMotion: Bool) -> some View {
        if reduceMotion {
            self
        } else {
            self.scaleOnPress()
        }
    }

    func lifeboardAccessibilityIdentifier(_ identifier: String?) -> some View {
        modifier(LifeBoardOptionalAccessibilityIdentifier(identifier: identifier))
    }
}

struct LifeBoardFilterChip: View {
    let title: String
    var systemImage: String? = nil
    var count: Int? = nil
    var isSelected: Bool = true
    var isDestructive: Bool = false
    var accentColor: Color? = nil
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        Button(action: handleTap) {
            chipLabel
        }
        .buttonStyle(.plain)
        .lifeboardPressFeedback(reduceMotion: reduceMotion)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isSelected ? "Selected" : "Double tap to apply")
        .accessibilityValue(isSelected ? "selected" : "unselected")
        .lifeboardAccessibilityIdentifier(accessibilityIdentifier)
    }

    private func handleTap() {
        LifeBoardFeedback.light()
        action()
    }

    private var chipLabel: some View {
        HStack(spacing: spacing.s8) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .semibold))
            }

            Text(title)
                .font(.lifeboard(.caption1))
                .fontWeight(.semibold)
                .lineLimit(1)

            if let count {
                Text("\(count)")
                    .font(.lifeboard(.caption2))
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, spacing.s2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.lifeboard.surfacePrimary.opacity(0.92))
                    )
            }
        }
        .foregroundStyle(foregroundColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(minHeight: 36)
        .lifeboardChromeSurface(
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
        return isDestructive ? Color.lifeboard.statusDanger : Color.lifeboard.accentPrimary
    }

    private var foregroundColor: Color {
        if isDestructive {
            return Color.lifeboard.statusDanger
        }
        return isSelected ? Color.lifeboard.textPrimary : Color.lifeboard.textSecondary
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
        return Color.lifeboard.strokeHairline.opacity(0.24)
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

struct LifeBoardFilterRow: View {
    let title: String
    var subtitle: String? = nil
    let isSelected: Bool
    var count: Int? = nil
    var isMultiSelect: Bool = false
    var systemImage: String? = nil
    var accessibilityIdentifier: String? = nil
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        Button(action: action) {
            rowLabel
        }
        .buttonStyle(.plain)
        .lifeboardPressFeedback(reduceMotion: reduceMotion)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isSelected ? "Selected" : "Double tap to apply")
        .lifeboardAccessibilityIdentifier(accessibilityIdentifier)
    }

    private var rowLabel: some View {
        HStack(spacing: spacing.s12) {
            Image(systemName: selectionIcon)
                .font(.system(size: 18))
                .foregroundStyle(isSelected ? rowAccent : Color.lifeboard.textTertiary)
                .animation(reduceMotion ? nil : LifeBoardAnimation.quick, value: isSelected)

            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.lifeboard.textSecondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard.textPrimary)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.lifeboard(.caption2))
                        .foregroundStyle(Color.lifeboard.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let count {
                Text("\(count)")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .padding(.horizontal, spacing.s8)
                    .padding(.vertical, spacing.s2)
                    .background(
                        Capsule(style: .continuous)
                            .fill(Color.lifeboard.surfaceSecondary)
                    )
            }

            if systemImage != nil {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Color.lifeboard.textTertiary)
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
            return Color.lifeboard.accentSecondary
        }
        return isSelected ? Color.lifeboard.accentPrimary : Color.lifeboard.accentSecondary
    }
}

struct LifeBoardFilterSectionHeader: View {
    let title: String
    var index: Int = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    var body: some View {
        let header = Text(title)
            .font(.lifeboard(.caption1))
            .foregroundStyle(Color.lifeboard.textSecondary)
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

struct LifeBoardFilterSheetContainer<Content: View>: View {
    let horizontalPadding: CGFloat
    let bottomPadding: CGFloat
    @ViewBuilder let content: () -> Content

    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

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
            .lifeboardPremiumSurface(
                cornerRadius: corner.modal,
                fillColor: Color.lifeboard.surfacePrimary,
                strokeColor: Color.lifeboard.strokeHairline.opacity(0.85),
                accentColor: Color.lifeboard.accentSecondary,
                level: .e3
            )
            .padding(.horizontal, horizontalPadding)
            .padding(.bottom, bottomPadding)
    }
}
