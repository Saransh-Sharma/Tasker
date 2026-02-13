//
//  HomeQuickFilterTriggerButton.swift
//  Tasker
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

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corner: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

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
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
            onTap()
        }) {
            HStack(spacing: spacing.s8) {
                // Active filter indicator (dot)
                if summary.hasActiveFilters {
                    Circle()
                        .fill(Color.tasker.accentPrimary)
                        .frame(width: 8, height: 8)
                }

                // Primary text
                Text(summary.primaryText)
                    .font(.tasker(.callout))
                    .foregroundColor(Color.tasker.textPrimary)
                    .lineLimit(1)

                // Secondary text (if any)
                if let secondary = summary.secondaryText {
                    Text(secondary)
                        .font(.tasker(.caption1))
                        .foregroundColor(Color.tasker.textSecondary)
                        .lineLimit(1)
                }

                // Chevron indicator
                Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color.tasker.textSecondary)
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
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint(isOpen ? "Double tap to close filters" : "Double tap to open filters")
    }

    // MARK: - Private

    private var backgroundColor: Color {
        if summary.hasActiveFilters {
            return Color.tasker.accentMuted
        }
        return Color.tasker.surfaceSecondary
    }

    private var borderColor: Color {
        if summary.hasActiveFilters {
            return Color.tasker.accentRing
        }
        return Color.tasker.divider
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
        .background(Color.tasker.bgCanvas)
    }
}
#endif
