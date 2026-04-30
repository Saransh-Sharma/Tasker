import SwiftUI

struct HomeDayLiquidSwipeWaveShape: Shape {
    let side: HomeDayLiquidSwipeSide
    let containerSize: CGSize
    var centerY: CGFloat
    var progress: CGFloat

    init(data: HomeDayLiquidSwipeData) {
        self.side = data.side
        self.containerSize = data.containerSize
        self.centerY = data.centerY
        self.progress = data.progress
    }

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(centerY, progress) }
        set {
            centerY = newValue.first
            progress = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let data = HomeDayLiquidSwipeData(
            side: side,
            centerY: centerY,
            progress: progress,
            containerSize: containerSize
        )
        let waveLedge = data.waveLedgeX
        let horizontalRadius = data.waveHorizontalRadius
        let verticalRadius = data.waveVerticalRadius
        let curveStartY = verticalRadius + centerY
        let isLeading = side == .leading
        let sign: CGFloat = isLeading ? 1 : -1
        let outerX: CGFloat = isLeading ? -50 : max(containerSize.width, 1) + 50
        let bottomY = max(containerSize.height, rect.height) + 100

        path.move(to: CGPoint(x: waveLedge, y: -100))
        path.addLine(to: CGPoint(x: outerX, y: -100))
        path.addLine(to: CGPoint(x: outerX, y: bottomY))
        path.addLine(to: CGPoint(x: waveLedge, y: bottomY))
        path.addLine(to: CGPoint(x: waveLedge, y: curveStartY))

        var index = 0
        while index < Self.curveData.count {
            let x1 = waveLedge + sign * horizontalRadius * Self.curveData[index]
            let y1 = curveStartY - verticalRadius * Self.curveData[index + 1]
            let x2 = waveLedge + sign * horizontalRadius * Self.curveData[index + 2]
            let y2 = curveStartY - verticalRadius * Self.curveData[index + 3]
            let x = waveLedge + sign * horizontalRadius * Self.curveData[index + 4]
            let y = curveStartY - verticalRadius * Self.curveData[index + 5]
            index += 6

            path.addCurve(
                to: CGPoint(x: x, y: y),
                control1: CGPoint(x: x1, y: y1),
                control2: CGPoint(x: x2, y: y2)
            )
        }

        path.closeSubpath()
        return path
    }

    private static let curveData: [CGFloat] = [
        0, 0.13461, 0.05341, 0.24127, 0.15615, 0.33223,
        0.23616, 0.40308, 0.33052, 0.45611, 0.50124, 0.53505,
        0.51587, 0.54182, 0.56641, 0.56503, 0.57493, 0.56896,
        0.72837, 0.63973, 0.80866, 0.68334, 0.87740, 0.73990,
        0.96534, 0.81226, 1, 0.89361, 1, 1,
        1, 1.10014, 0.95957, 1.18879, 0.86084, 1.27048,
        0.78521, 1.33305, 0.70338, 1.37958, 0.52911, 1.46651,
        0.52418, 1.46896, 0.50573, 1.47816, 0.50153, 1.48026,
        0.31874, 1.57142, 0.23320, 1.62041, 0.15411, 1.68740,
        0.05099, 1.77475, 0, 1.87092, 0, 2
    ]
}
