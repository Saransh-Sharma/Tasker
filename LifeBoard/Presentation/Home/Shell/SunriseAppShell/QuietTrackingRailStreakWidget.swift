//
//  SunriseAppShellView.swift
//  LifeBoard
//
//  New SwiftUI Home shell with backdrop/sunrise pattern.
//

import SwiftUI
import UIKit
import Combine

struct QuietTrackingRailStreakWidget: View {
    let card: QuietTrackingRailCardPresentation
    let slotWidth: CGFloat
    let visibleDayCount: Int

    @Environment(\.lifeboardLayoutClass) var layoutClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var spacing: LifeBoardSpacingTokens { LifeBoardThemeManager.shared.tokens(for: layoutClass).spacing }

    var isExpandedType: Bool {
        dynamicTypeSize >= .accessibility1
    }

    var widgetVerticalPadding: CGFloat {
        isExpandedType ? 6 : spacing.s4
    }

    var visibleCells: [HabitBoardCell] {
        card.visibleCells(dayCount: visibleDayCount)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HabitBoardStripView(
                cells: visibleCells,
                family: card.colorFamily,
                mode: .compact
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Image(systemName: card.iconSymbolName)
                    .font(.system(size: 10, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(Color.lifeboard.textSecondary.opacity(0.82))
                    .accessibilityHidden(true)

                Text(card.title)
                    .font(.lifeboard(.caption2).weight(.medium))
                    .foregroundStyle(Color.lifeboard.textSecondary)
                    .lineLimit(isExpandedType ? 2 : 1)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: slotWidth, alignment: .leading)
        .frame(minHeight: 44, alignment: .topLeading)
        .padding(.vertical, widgetVerticalPadding)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.accessibilityLabel)
        .accessibilityValue(card.accessibilityValue(visibleDayCount: visibleDayCount))
    }
}
