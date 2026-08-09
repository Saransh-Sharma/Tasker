//
//  HomeSunriseLayoutSupport.swift
//  LifeBoard
//
//  Pure Sunrise shell layout support values.
//

import SwiftUI

// MARK: - Sunrise Anchor

enum SunriseAnchor: Equatable {
    /// Sunrise covers calendar + charts. Default state.
    case collapsed
    /// Sunrise anchors below the weekly calendar strip.
    case midReveal
    /// Sunrise anchors below the chart cards (full analytics view).
    case fullReveal
}

struct HomeSunriseLayoutMetrics {
    var calendarExpandedHeight: CGFloat = 0
    var timelineHeaderHeight: CGFloat = 0
    var weeklyBackdropHeight: CGFloat = 0
    var geometryHeight: CGFloat = 0

    /// Executes offset.
    func offset(for anchor: SunriseAnchor) -> CGFloat {
        let measuredCalendarHeight = max(calendarExpandedHeight, 72)
        let measuredHeaderHeight = max(timelineHeaderHeight, 56)
        let measuredWeekHeight = max(weeklyBackdropHeight, measuredHeaderHeight + 44)
        let midRevealBase = measuredCalendarHeight + min(measuredWeekHeight * 0.52, measuredHeaderHeight + 56)
        let minimumMidReveal = max(104, measuredCalendarHeight + 20)
        let midReveal = min(
            max(midRevealBase, minimumMidReveal),
            geometryHeight * 0.24
        )
        let fullRevealBase = measuredCalendarHeight + measuredWeekHeight + max(24, measuredHeaderHeight * 0.28)
        let fullReveal = min(
            max(fullRevealBase, midReveal + 72),
            geometryHeight * 0.56
        )

        switch anchor {
        case .collapsed:
            return 0
        case .midReveal:
            return midReveal
        case .fullReveal:
            return fullReveal
        }
    }
}

struct HomeSunriseHintEligibility {
    static let triggerCooldown: TimeInterval = 0.7

    /// Executes canTrigger.
    static func canTrigger(
        isHomeVisible: Bool,
        sunriseAnchor: SunriseAnchor,
        reduceMotionEnabled: Bool,
        isUITesting: Bool,
        hasRunningAnimation: Bool,
        lastTriggerDate: Date?,
        now: Date = Date(),
        cooldown: TimeInterval = triggerCooldown
    ) -> Bool {
        guard isHomeVisible else { return false }
        guard sunriseAnchor == .collapsed else { return false }
        guard !reduceMotionEnabled else { return false }
        guard !isUITesting else { return false }
        guard !hasRunningAnimation else { return false }
        guard let lastTriggerDate else { return true }

        return now.timeIntervalSince(lastTriggerDate) >= cooldown
    }
}

extension SunriseAnchor {
    var accessibilityValue: String {
        switch self {
        case .collapsed:
            return "collapsed"
        case .midReveal:
            return "midReveal"
        case .fullReveal:
            return "fullReveal"
        }
    }
}
