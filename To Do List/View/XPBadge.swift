//
//  XPBadge.swift
//  Tasker
//
//  XP value badge for task rows showing points earned.
//  Accent color for high-value tasks (P0/P1), subtle for others.
//

import SwiftUI

// MARK: - XP Badge

public struct XPBadge: View {
    let xpValue: Int
    let priority: TaskPriority
    var isCompact: Bool = false
    var showLabel: Bool = true

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var themeColors: TaskerColorTokens { TaskerThemeManager.shared.currentTheme.tokens.color }

    private var isHighValue: Bool {
        priority == .max || priority == .high
    }

    private var isMaxPriority: Bool {
        priority == .max
    }

    public var body: some View {
        HStack(spacing: 3) {
            Text("+\(xpValue)")
                .font(.tasker(isCompact ? .caption2 : .caption1))
                .fontWeight(isHighValue ? .bold : .medium)

            if showLabel && !isCompact {
                Text("XP")
                    .font(.tasker(.caption2))
                    .fontWeight(.medium)
            }
        }
        .foregroundColor(foregroundColor)
        .padding(.horizontal, isCompact ? 5 : 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(backgroundColor)
        )
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: isHighValue ? 1 : 0)
        )
        .shadow(
            color: isMaxPriority ? Color.tasker.accentPrimary.opacity(0.3) : .clear,
            radius: isMaxPriority ? 4 : 0,
            x: 0,
            y: 1
        )
        .fixedSize()
    }

    private var foregroundColor: Color {
        if isHighValue {
            return Color.tasker.accentOnPrimary
        }
        return Color.tasker.textSecondary
    }

    private var backgroundColor: Color {
        if isHighValue {
            return Color.tasker.accentPrimary
        }
        return Color.tasker.surfaceSecondary
    }

    private var borderColor: Color {
        if isHighValue {
            return Color.tasker.accentPrimary.opacity(0.3)
        }
        return .clear
    }
}

// MARK: - Preview

#if DEBUG
struct XPBadge_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 12) {
            // All priority levels
            HStack(spacing: 8) {
                XPBadge(xpValue: 7, priority: .max)
                XPBadge(xpValue: 4, priority: .high)
                XPBadge(xpValue: 3, priority: .low)
                XPBadge(xpValue: 2, priority: .none)
            }

            Divider()

            // Compact variants
            HStack(spacing: 8) {
                XPBadge(xpValue: 7, priority: .max, isCompact: true)
                XPBadge(xpValue: 4, priority: .high, isCompact: true)
                XPBadge(xpValue: 3, priority: .low, isCompact: true)
            }

            Divider()

            // Without label
            HStack(spacing: 8) {
                XPBadge(xpValue: 7, priority: .max, showLabel: false)
                XPBadge(xpValue: 4, priority: .high, showLabel: false)
            }
        }
        .padding()
        .background(Color.tasker.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif
