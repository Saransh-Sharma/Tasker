import SwiftUI

struct TimelineStreamGeometry: Equatable {
    struct LaneMetrics: Equatable {
        let width: CGFloat
        let leadingX: CGFloat
        let centerX: CGFloat
        let contentX: CGFloat

        var halfWidth: CGFloat { width / 2 }
    }

    struct DensityPreset: Equatable {
        let multiplier: CGFloat
        let maxOffset: CGFloat
    }

    struct CurvatureBody: Equatable {
        let id: String
        let kind: TimelineStreamInfluenceKind
        let centerY: CGFloat
        let height: CGFloat
        let tintHex: String?
        let stackCount: Int
        let isOverlapping: Bool

        var startY: CGFloat { centerY - (height / 2) }
        var endY: CGFloat { centerY + (height / 2) }
    }


    static let baseLineWidth: CGFloat = 4

    static let coreLineWidth: CGFloat = 1.5

    static let glowLineWidth: CGFloat = 8

    static let sampleStride: CGFloat = 14

    static let minimumClusterDistance: CGFloat = 120

    static let clusterGapThreshold: CGFloat = 44

    static let densityWindow: CGFloat = 160

    static let maxSlopeDelta: CGFloat = 3.5

    static let contentGapAfterLane: CGFloat = 10

    static let minimumPhoneContentWidth: CGFloat = 230

    let baseX: CGFloat

    let laneHalfWidth: CGFloat

    let startY: CGFloat

    let endY: CGFloat

    let influences: [TimelineStreamInfluence]

    let curvatureBodies: [CurvatureBody]

    let samplePoints: [TimelineStreamSample]

    let anchors: [TimelineStreamAnchor]

    let segments: [TimelineStreamSegment]

    init(
        baseX: CGFloat,
        laneHalfWidth: CGFloat,
        startY: CGFloat,
        endY: CGFloat,
        influences: [TimelineStreamInfluence]
    ) {
        self.baseX = baseX
        self.laneHalfWidth = max(laneHalfWidth, 1)
        self.startY = min(startY, endY)
        self.endY = max(startY, endY)
        self.influences = influences
        let bodies = Self.curvatureBodies(from: influences)
        self.curvatureBodies = bodies
        self.samplePoints = Self.buildSamples(
            bodies: bodies,
            baseX: baseX,
            laneHalfWidth: self.laneHalfWidth,
            startY: self.startY,
            endY: self.endY,
            stride: Self.sampleStride
        )
        self.anchors = Self.directedAnchors(
            from: Self.rawAnchors(
                influences: influences,
                startY: self.startY,
                endY: self.endY,
                laneHalfWidth: self.laneHalfWidth
            ),
            laneHalfWidth: self.laneHalfWidth
        )
        self.segments = Self.segments(from: self.anchors, baseX: baseX, laneHalfWidth: self.laneHalfWidth)
    }
}
