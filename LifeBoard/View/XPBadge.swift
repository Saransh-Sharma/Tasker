//
//  XPBadge.swift
//  LifeBoard
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

    private var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.currentTheme.tokens.spacing }
    private var themeColors: LifeBoardColorTokens { LifeBoardThemeManager.shared.currentTheme.tokens.color }

    private var isHighValue: Bool {
        priority == .max || priority == .high
    }

    private var isMaxPriority: Bool {
        priority == .max
    }

    public var body: some View {
        HStack(spacing: 3) {
            Text("+\(xpValue)")
                .font(.lifeboard(isCompact ? .caption2 : .caption1))
                .fontWeight(isHighValue ? .bold : .medium)

            if showLabel && !isCompact {
                Text("XP")
                    .font(.lifeboard(.caption2))
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
            color: isMaxPriority ? Color.lifeboard.accentPrimary.opacity(0.3) : .clear,
            radius: isMaxPriority ? 4 : 0,
            x: 0,
            y: 1
        )
        .fixedSize()
    }

    private var foregroundColor: Color {
        if isHighValue {
            return Color.lifeboard.accentOnPrimary
        }
        return Color.lifeboard.textSecondary
    }

    private var backgroundColor: Color {
        if isHighValue {
            return Color.lifeboard.accentPrimary
        }
        return Color.lifeboard.surfaceSecondary
    }

    private var borderColor: Color {
        if isHighValue {
            return Color.lifeboard.accentPrimary.opacity(0.3)
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
        .background(Color.lifeboard.bgCanvas)
        .previewLayout(.sizeThatFits)
    }
}
#endif
