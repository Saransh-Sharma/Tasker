import SwiftUI

struct TimelineStreamLayerSpec: Equatable {
    let glowLineWidth: CGFloat
    let bodyLineWidth: CGFloat
    let coreLineWidth: CGFloat
    let usesRoundedCapsAndJoins: Bool

    static let expressive = TimelineStreamLayerSpec(
        glowLineWidth: TimelineStreamGeometry.glowLineWidth,
        bodyLineWidth: TimelineStreamGeometry.baseLineWidth,
        coreLineWidth: TimelineStreamGeometry.coreLineWidth,
        usesRoundedCapsAndJoins: true
    )
}
