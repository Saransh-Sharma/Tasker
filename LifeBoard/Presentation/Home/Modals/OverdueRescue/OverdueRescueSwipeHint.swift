//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueSwipeHint: View {
    let reveal: OverdueRescueSwipeRevealKind
    let progress: Double

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 19, weight: .medium))
            Text(text)
        }
        .font(.lifeboard(.caption1))
        .foregroundStyle(OverdueRescuePalette.secondaryInk)
        .frame(height: 28)
        .accessibilityHidden(true)
    }

    var icon: String {
        switch reveal {
        case .keep: return "hand.point.right"
        case .move: return "hand.point.left"
        case .none: return "hand.draw.fill"
        }
    }

    var text: String {
        switch reveal {
        case .keep: return "Swipe right to keep"
        case .move: return "Swipe left to move later"
        case .none: return "Swipe left or right or tap a choice below."
        }
    }
}
