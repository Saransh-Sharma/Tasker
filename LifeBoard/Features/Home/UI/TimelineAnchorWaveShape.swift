import SwiftUI

struct TimelineAnchorWaveShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let leftValleyY = rect.height * 0.70
        let crestY = rect.height * 0.16
        let rightValleyY = rect.height * 0.70

        path.move(to: CGPoint(x: rect.minX, y: leftValleyY))
        path.addCurve(
            to: CGPoint(x: rect.midX, y: crestY),
            control1: CGPoint(x: rect.width * 0.20, y: leftValleyY),
            control2: CGPoint(x: rect.width * 0.32, y: crestY)
        )
        path.addCurve(
            to: CGPoint(x: rect.maxX, y: rightValleyY),
            control1: CGPoint(x: rect.width * 0.68, y: crestY),
            control2: CGPoint(x: rect.width * 0.80, y: rightValleyY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()

        return path
    }
}
