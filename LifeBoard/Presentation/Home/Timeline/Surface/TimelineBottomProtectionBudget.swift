import SwiftUI

struct TimelineBottomProtectionBudget: Equatable {
    let bottomNavHeight: CGFloat
    let floatingActionButtonHeight: CGFloat
    let reflectionBannerHeight: CGFloat
    let extraClearance: CGFloat

    var timelineInset: CGFloat {
        bottomNavHeight + floatingActionButtonHeight + reflectionBannerHeight + extraClearance
    }

    static func make(for layoutClass: LifeBoardLayoutClass) -> TimelineBottomProtectionBudget {
        switch layoutClass {
        case .phone:
            return TimelineBottomProtectionBudget(
                bottomNavHeight: 72,
                floatingActionButtonHeight: 0,
                reflectionBannerHeight: 0,
                extraClearance: 40
            )
        case .padCompact, .padRegular, .padExpanded:
            return TimelineBottomProtectionBudget(
                bottomNavHeight: 44,
                floatingActionButtonHeight: 32,
                reflectionBannerHeight: 24,
                extraClearance: 32
            )
        }
    }
}
