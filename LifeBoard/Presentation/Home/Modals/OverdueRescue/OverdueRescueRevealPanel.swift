//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueRevealPanel: View {
    let reveal: OverdueRescueSwipeRevealKind
    let progress: Double
    let metrics: OverdueRescueDeckLayoutMetrics

    var body: some View {
        RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.cardCorner, style: .continuous)
            .fill(panelFill)
            .overlay(
                RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.cardCorner, style: .continuous)
                    .stroke(panelForeground.opacity(0.18), lineWidth: 1)
            )
            .frame(width: metrics.revealPanelWidth, height: metrics.cardHeight * 0.96)
            .lbShadow(LBShadowTokens.rescueReveal(progress: easedProgress))
            .overlay(alignment: reveal == .keep ? .leading : .trailing) {
                if reveal != .none {
                    VStack(spacing: 12) {
                        Image(systemName: icon)
                            .font(.system(size: 54, weight: .semibold))
                            .frame(width: 60, height: 60)
                        Text(title)
                            .font(.lifeboard(.screenTitle))
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.82)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: metrics.revealContentWidth)
                    .foregroundStyle(panelForeground)
                    .opacity(easedProgress)
                    .scaleEffect(0.86 + 0.14 * easedProgress)
                    .padding(.horizontal, metrics.revealContentInset)
                }
            }
            .offset(x: panelOffsetX, y: 0)
            .opacity(reveal == .none ? 0 : easedProgress)
            .accessibilityHidden(true)
    }

    var easedProgress: Double {
        progress * progress * (3 - 2 * progress)
    }

    var panelOffsetX: CGFloat {
        metrics.revealPanelOffset(for: reveal)
    }

    var panelFill: Color {
        switch reveal {
        case .keep: return OverdueRescuePalette.keepFill
        case .move: return OverdueRescuePalette.moveFill
        case .none: return .clear
        }
    }

    var panelForeground: Color {
        switch reveal {
        case .keep: return OverdueRescuePalette.keepForeground
        case .move: return OverdueRescuePalette.moveForeground
        case .none: return Color.clear
        }
    }

    var title: String {
        switch reveal {
        case .keep: return "Keep\ntoday"
        case .move: return "Move\nlater"
        case .none: return ""
        }
    }

    var icon: String {
        switch reveal {
        case .keep: return "checkmark.circle"
        case .move: return "clock"
        case .none: return "circle"
        }
    }
}
