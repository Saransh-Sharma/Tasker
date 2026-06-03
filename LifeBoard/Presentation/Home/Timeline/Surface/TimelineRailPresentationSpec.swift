import SwiftUI

struct TimelineRailPresentationSpec: Equatable {
    let lineWidth: CGFloat
    let opacity: Double
    let isDashed: Bool

    static let compactConnector = TimelineRailPresentationSpec(
        lineWidth: 1.5,
        opacity: 0.46,
        isDashed: false
    )
}
