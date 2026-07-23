//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueBackCards: View {
    let metrics: OverdueRescueDeckLayoutMetrics

    var body: some View {
        ZStack(alignment: .center) {
            backCard(index: 0, reverseIndex: 3)
            backCard(index: 1, reverseIndex: 2)
            backCard(index: 2, reverseIndex: 1)
            backCard(index: 3, reverseIndex: 0)
        }
    }

    private func backCard(index: Int, reverseIndex: Int) -> some View {
        RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.cardCorner, style: .continuous)
            .fill(OverdueRescuePalette.backCard(index))
            .overlay(
                RoundedRectangle(cornerRadius: OverdueRescueVisualSpec.cardCorner, style: .continuous)
                    .stroke(OverdueRescuePalette.glassStroke, lineWidth: 1)
            )
            .frame(
                width: metrics.cardWidth - CGFloat(reverseIndex) * 10,
                height: metrics.cardHeight - CGFloat(reverseIndex) * 8
            )
            .offset(
                x: horizontalOffset(reverseIndex),
                y: -CGFloat(reverseIndex) * 21
            )
            .scaleEffect(1.0 - Double(reverseIndex) * 0.015)
            .lbShadow(LBShadowTokens.rescueStack(depth: index))
    }

    func horizontalOffset(_ reverseIndex: Int) -> CGFloat {
        switch reverseIndex {
        case 1: return 8
        case 2: return -12
        case 3: return 14
        default: return 0
        }
    }
}
