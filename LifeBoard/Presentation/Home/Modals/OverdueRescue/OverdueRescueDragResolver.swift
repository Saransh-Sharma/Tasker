//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

enum OverdueRescueDragResolver {
    static let horizontalDominanceRatio: CGFloat = 1.15

    static func commitThreshold(cardWidth: CGFloat) -> CGFloat {
        max(96, cardWidth * 0.28)
    }

    static func maxDragOffset(cardWidth: CGFloat) -> CGFloat {
        cardWidth * 0.3
    }

    static func resolve(translation: CGSize, cardWidth: CGFloat, reduceMotion: Bool = false) -> OverdueRescueDragResolution {
        let reveal = revealKind(for: translation)
        let threshold = commitThreshold(cardWidth: cardWidth)
        let progress = reveal == .none ? 0 : revealProgress(for: translation.width, threshold: threshold)
        let clampLimit = maxDragOffset(cardWidth: cardWidth)
        let clampedWidth = max(-clampLimit, min(clampLimit, translation.width))
        let visibleOffset = reveal == .none ? .zero : CGSize(width: clampedWidth, height: translation.height * 0.06)
        let commitAction = commitAction(for: translation, cardWidth: cardWidth)
        let tilt = reduceMotion || reveal == .none ? 0 : Double(max(-5.5, min(5.5, translation.width / cardWidth * 6)))

        return OverdueRescueDragResolution(
            reveal: reveal,
            progress: progress,
            visibleOffset: visibleOffset,
            commitAction: commitAction,
            tiltDegrees: tilt
        )
    }

    static func revealKind(for translation: CGSize) -> OverdueRescueSwipeRevealKind {
        let width = translation.width
        let height = translation.height
        guard abs(width) > 8, abs(width) > abs(height) * horizontalDominanceRatio else {
            return .none
        }
        return width > 0 ? .keep : .move
    }

    static func commitAction(for translation: CGSize, cardWidth: CGFloat) -> OverdueRescueDecisionAction? {
        let reveal = revealKind(for: translation)
        guard reveal != .none, abs(translation.width) >= commitThreshold(cardWidth: cardWidth) else {
            return nil
        }
        return reveal == .keep ? .keepToday : .moveLater
    }

    static func revealProgress(for width: CGFloat, threshold: CGFloat) -> Double {
        let start = max(8, threshold * 0.08)
        let distance = abs(width)
        guard distance > start else { return 0 }
        return min(1, Double((distance - start) / max(1, threshold - start)))
    }
}
