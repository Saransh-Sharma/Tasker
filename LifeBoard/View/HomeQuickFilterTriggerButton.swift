//
//  HomeQuickFilterTriggerButton.swift
//  LifeBoard
//
//  Header trigger button for the quick filter dropdown.
//

 import SwiftUI

/// Button that appears in the Home header to trigger the filter dropdown.
/// Shows summary of current filter state and indicates when filters are active.
public struct HomeQuickFilterTriggerButton: View {

    /// The summary to display
    let summary: HomeQuickFilterSummary

    /// Whether the dropdown is currently open
    @Binding var isOpen: Bool

    /// Action when button is tapped
    let onTap: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: LifeBoardCornerTokens { LifeBoardThemeManager.shared.currentTheme.tokens.corner }

    /// Initializes a new instance.
    public init(
        summary: HomeQuickFilterSummary,
        isOpen: Binding<Bool>,
        onTap: @escaping () -> Void
    ) {
        self.summary = summary
        self._isOpen = isOpen
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: {
            LifeBoardFeedback.light()
            onTap()
        }) {
            HStack(spacing: spacing.s8) {
                // Active filter indicator (dot)
                if summary.hasActiveFilters {
                    Circle()
                        .fill(Color.lifeboard.accentPrimary)
                        .frame(width: 8, height: 8)
                        .transition(.scale.combined(with: .opacity))
                        .animation(reduceMotion ? nil : LifeBoardAnimation.bouncy, value: summary.hasActiveFilters)
                }

                // Primary text
                Text(summary.primaryText)
                    .font(.lifeboard(.callout))
                    .foregroundColor(Color.lifeboard.textPrimary)
                    .lineLimit(1)

                // Secondary text (if any)
                if let secondary = summary.secondaryText {
                    Text(secondary)
                        .font(.lifeboard(.caption1))
                        .foregroundColor(Color.lifeboard.textSecondary)
                        .lineLimit(1)
                }

                // Filter indicator
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.lifeboard.textSecondary)
            }
            .padding(.horizontal, spacing.s12)
            .padding(.vertical, spacing.s8)
            .frame(minHeight: 36)
            .background(
                Capsule()
                    .fill(backgroundColor)
            )
            .overlay(
                Capsule()
                    .stroke(borderColor, lineWidth: 1)
            )
            .animation(reduceMotion ? nil : LifeBoardAnimation.quick, value: summary.hasActiveFilters)
        }
        .lifeboardPressFeedback(reduceMotion: reduceMotion)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isOpen ? "Double tap to close filters" : "Double tap to open filters")
    }

    // MARK: - Private

    private var backgroundColor: Color {
        if summary.hasActiveFilters {
            return Color.lifeboard.accentMuted
        }
        return Color.lifeboard.surfaceSecondary
    }

    private var borderColor: Color {
        if summary.hasActiveFilters {
            return Color.lifeboard.accentRing
        }
        return Color.lifeboard.divider
    }

    private var accessibilityLabel: String {
        var label = "Filters: \(summary.displayText)"
        if summary.hasActiveFilters {
            label += ", active"
        }
        return label
    }
}

// MARK: - Preview

#if DEBUG
struct HomeQuickFilterTriggerButton_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 16) {
            // Default state
            HomeQuickFilterTriggerButton(
                summary: HomeQuickFilterSummary(primaryText: "Today", hasActiveFilters: false),
                isOpen: .constant(false),
                onTap: {}
            )

            // With filters active
            HomeQuickFilterTriggerButton(
                summary: HomeQuickFilterSummary(
                    primaryText: "Today",
                    secondaryText: "+ 2 projects",
                    hasActiveFilters: true
                ),
                isOpen: .constant(false),
                onTap: {}
            )

            // Dropdown open
            HomeQuickFilterTriggerButton(
                summary: HomeQuickFilterSummary(primaryText: "Upcoming", hasActiveFilters: true),
                isOpen: .constant(true),
                onTap: {}
            )
        }
        .padding()
        .background(Color.lifeboard.bgCanvas)
    }
}
#endif
