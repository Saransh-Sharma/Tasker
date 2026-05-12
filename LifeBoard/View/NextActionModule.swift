//
//  NextActionModule.swift
//  LifeBoard
//
//  Ultra-compact contextual guidance row.
//

 import SwiftUI

struct NextActionModule: View {
    let openTaskCount: Int
    let focusPinnedCount: Int
    let onStartFifteenMinuteFocus: () -> Void

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }

    @ViewBuilder
    var body: some View {
        Group {
            switch openTaskCount {
            case 0:
                EmptyView()
            case 1...2:
                Button(action: onStartFifteenMinuteFocus) {
                    actionRow(icon: "timer", title: "Plan next 15 min")
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Plan next 15 min")
                .accessibilityHint("Starts a 15 minute focus timer")
                .accessibilityIdentifier("home.nextActionModule")
            default:
                actionRow(icon: "hand.point.up.left", title: "Drag tasks to focus")
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("home.nextActionModule")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Executes actionRow.
    private func actionRow(icon: String, title: String, showChevron: Bool = false) -> some View {
        HStack(spacing: spacing.s8) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Color.lifeboard.accentPrimary)

            Text(title)
                .font(.lifeboard(.caption1))
                .foregroundColor(Color.lifeboard.textSecondary)

            Spacer(minLength: 0)

            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.lifeboard.textQuaternary)
            }
        }
        .padding(.horizontal, spacing.s4)
        .padding(.vertical, spacing.s4)
        .frame(maxWidth: .infinity, minHeight: 32)
        .contentShape(Rectangle())
    }
}
