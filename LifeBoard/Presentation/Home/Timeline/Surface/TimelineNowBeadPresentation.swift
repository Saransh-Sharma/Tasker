import SwiftUI

struct TimelineNowBeadPresentation: Equatable {
    static func clampedY(_ y: CGFloat, contentHeight: CGFloat, verticalInset: CGFloat = 14) -> CGFloat {
        let upper = max(contentHeight - verticalInset, verticalInset)
        return min(max(y, verticalInset), upper)
    }

    static func shouldPulse(reduceMotion: Bool) -> Bool {
        reduceMotion == false
    }
}
