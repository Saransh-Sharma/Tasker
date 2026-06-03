//
//  EvaOverdueRescueSheetV2.swift
//  LifeBoard
//
//  Screenshot-aligned Overdue Rescue decision deck.
//

import SwiftUI
import UIKit

struct OverdueRescueDeckLayoutMetrics: Equatable {
    var containerSize: CGSize
    var bottomInset: CGFloat
    var dynamicTypeIsExpanded: Bool

    var horizontalInset: CGFloat {
        min(30, max(20, containerSize.width * 0.052))
    }

    var contentWidth: CGFloat {
        min(max(containerSize.width - horizontalInset * 2, 300), 390)
    }

    var isCompactHeight: Bool {
        containerSize.height < 880
    }

    var cardWidth: CGFloat {
        min(contentWidth + 12, containerSize.width - 28)
    }

    var cardHeight: CGFloat {
        let height = containerSize.height > 0 ? containerSize.height : 844
        if isCompactHeight {
            return min(354, max(318, height * 0.38))
        }
        return min(430, max(386, height * 0.44))
    }

    var deckHeight: CGFloat {
        cardHeight + (isCompactHeight ? 46 : 68)
    }

    var revealPanelWidth: CGFloat {
        cardWidth * 0.96
    }

    var revealPanelOffset: CGFloat {
        cardWidth * 0.12
    }

    var revealContentInset: CGFloat {
        min(max(58, cardWidth * 0.17), max(48, revealPanelWidth * 0.24))
    }

    var revealContentWidth: CGFloat {
        let availableWidth = max(84, revealPanelWidth - revealContentInset * 2)
        let idealWidth = min(max(96, cardWidth * 0.30), 118)
        return min(idealWidth, availableWidth)
    }

    func revealPanelOffset(for reveal: OverdueRescueSwipeRevealKind) -> CGFloat {
        switch reveal {
        case .keep: return -revealPanelOffset
        case .move: return revealPanelOffset
        case .none: return 0
        }
    }

    func revealContentFrame(for reveal: OverdueRescueSwipeRevealKind) -> CGRect {
        guard reveal != .none else { return .zero }
        let centerX = containerSize.width / 2 + revealPanelOffset(for: reveal)
        let panelMinX = centerX - revealPanelWidth / 2
        let panelMaxX = centerX + revealPanelWidth / 2

        switch reveal {
        case .keep:
            return CGRect(
                x: panelMinX + revealContentInset,
                y: 0,
                width: revealContentWidth,
                height: cardHeight * 0.96
            )
        case .move:
            return CGRect(
                x: panelMaxX - revealContentInset - revealContentWidth,
                y: 0,
                width: revealContentWidth,
                height: cardHeight * 0.96
            )
        case .none:
            return .zero
        }
    }

    var progressWidth: CGFloat {
        min(250, max(190, contentWidth * 0.58))
    }

    var actionButtonHeight: CGFloat {
        dynamicTypeIsExpanded ? 88 : (isCompactHeight ? 62 : 76)
    }

    var actionGridUsesSingleColumn: Bool {
        dynamicTypeIsExpanded || contentWidth < 330
    }

    var bottomClearance: CGFloat {
        max(isCompactHeight ? 82 : 104, bottomInset + 18)
    }

    static func make(size: CGSize, bottomInset: CGFloat, dynamicTypeSize: DynamicTypeSize) -> OverdueRescueDeckLayoutMetrics {
        OverdueRescueDeckLayoutMetrics(
            containerSize: CGSize(
                width: max(size.width, 320),
                height: max(size.height, 640)
            ),
            bottomInset: bottomInset,
            dynamicTypeIsExpanded: dynamicTypeSize.isAccessibilitySize
        )
    }
}
