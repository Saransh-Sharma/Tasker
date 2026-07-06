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
            ForEach(0..<4, id: \.self) { index in
                let reverseIndex = 3 - index
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
                    .shadow(color: Color.black.opacity(0.045 + Double(index) * 0.012), radius: 16 + CGFloat(index) * 4, y: 8 + CGFloat(index) * 2)
            }
        }
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
