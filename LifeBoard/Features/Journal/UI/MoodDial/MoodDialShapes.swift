import SwiftUI

public struct MoodDialPointer: View {
    @Environment(\.moodDialTheme) private var theme

    public init() {}

    public var body: some View {
        ZStack(alignment: .topLeading) {
            MoodDialPointerShape()
                .fill(theme.accent)

            Circle()
                .fill(theme.surface)
                .frame(width: 9.5, height: 9.5)
                .offset(x: 20.25, y: 101.25)
        }
        .frame(width: 50, height: 136)
        .accessibilityHidden(true)
    }
}

public struct MoodDialPointerShape: Shape {
    public init() {}

    public func path(in rect: CGRect) -> Path {
        let baseWidth: CGFloat = 50
        let baseHeight: CGFloat = 136
        let scale = min(rect.width / baseWidth, rect.height / baseHeight)
        let origin = CGPoint(
            x: rect.midX - baseWidth * scale / 2,
            y: rect.midY - baseHeight * scale / 2
        )

        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }

        var path = Path()

        path.move(to: point(25, 136))
        path.addCurve(
            to: point(8.9, 82),
            control1: point(18.1, 133.4),
            control2: point(9.4, 111.2)
        )
        path.addCurve(
            to: point(10.8, 29),
            control1: point(6.9, 60.5),
            control2: point(7.3, 42)
        )
        path.addCurve(
            to: point(25, 2),
            control1: point(14.8, 10.4),
            control2: point(18.8, 2)
        )
        path.addCurve(
            to: point(39.2, 29),
            control1: point(31.2, 2),
            control2: point(35.2, 10.4)
        )
        path.addCurve(
            to: point(41.1, 82),
            control1: point(42.7, 42),
            control2: point(43.1, 60.5)
        )
        path.addCurve(
            to: point(25, 136),
            control1: point(40.6, 111.2),
            control2: point(31.9, 133.4)
        )
        path.closeSubpath()
        return path
    }
}

public struct MoodDialSegmentShape: Shape {
    let center: CGPoint
    let innerRadius: CGFloat
    let outerRadius: CGFloat
    let startAngleDegrees: Double
    let endAngleDegrees: Double

    public init(
        center: CGPoint,
        innerRadius: CGFloat,
        outerRadius: CGFloat,
        startAngleDegrees: Double,
        endAngleDegrees: Double
    ) {
        self.center = center
        self.innerRadius = innerRadius
        self.outerRadius = outerRadius
        self.startAngleDegrees = startAngleDegrees
        self.endAngleDegrees = endAngleDegrees
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let outerPoints = points(radius: outerRadius, from: startAngleDegrees, to: endAngleDegrees)
        let innerPoints = points(radius: innerRadius, from: endAngleDegrees, to: startAngleDegrees)

        guard let first = outerPoints.first else { return path }
        path.move(to: first)
        outerPoints.dropFirst().forEach { path.addLine(to: $0) }
        innerPoints.forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }

    private func points(radius: CGFloat, from startAngle: Double, to endAngle: Double) -> [CGPoint] {
        let steps = max(6, Int(abs(endAngle - startAngle) / 2))
        return (0...steps).map { step in
            let progress = Double(step) / Double(steps)
            let angle = startAngle + (endAngle - startAngle) * progress
            let radians = angle * .pi / 180
            return CGPoint(
                x: center.x + CGFloat(cos(radians)) * radius,
                y: center.y + CGFloat(sin(radians)) * radius
            )
        }
    }
}
