import SwiftUI

// A `Shape`, and nothing more. Split out of `CompletionControl`,
// which stays app-side because it drives the Metal completion burst.
/// An open ring that unwinds as a checkmark draws in its place.
///
/// `progress` is the only input: `0` is a closed ring, `1` is a fully drawn
/// tick, and everything between is a genuine intermediate frame rather than a
/// cross-fade between two states.
public struct CompletionMark: Shape {
    /// Where the ring stops unwinding and the tick starts drawing. They overlap
    /// slightly on purpose — a hard handoff reads as two separate animations.
    public static let phaseSplit: Double = 0.45

    public var progress: Double

    public var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    public init(progress: Double) {
        self.progress = progress
    }

    /// Portion of the ring still drawn, `1` at rest down to `0` at the split.
    public static func ringExtent(at progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        guard clamped > 0 else { return 1 }
        guard clamped < phaseSplit else { return 0 }
        return 1 - (clamped / phaseSplit)
    }

    /// Portion of the checkmark drawn, `0` until the split and `1` at the end.
    public static func tickExtent(at progress: Double) -> Double {
        let clamped = min(max(progress, 0), 1)
        guard clamped > phaseSplit else { return 0 }
        return (clamped - phaseSplit) / (1 - phaseSplit)
    }

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        let side = min(rect.width, rect.height)
        guard side > 0 else { return path }

        let box = CGRect(
            x: rect.midX - side / 2,
            y: rect.midY - side / 2,
            width: side,
            height: side
        )

        let ring = Self.ringExtent(at: progress)
        if ring > 0 {
            // Unwinds anticlockwise from 12 o'clock, so the gap opens where the
            // tick's first stroke will arrive rather than on the opposite side.
            let radius = side / 2
            path.addArc(
                center: CGPoint(x: box.midX, y: box.midY),
                radius: radius,
                startAngle: .degrees(-90),
                endAngle: .degrees(-90 + 360 * ring),
                clockwise: false
            )
        }

        let tick = Self.tickExtent(at: progress)
        if tick > 0 {
            path.addPath(Self.tickPath(in: box, extent: tick))
        }

        return path
    }

    /// A two-segment checkmark drawn to `extent` of its combined length, so a
    /// partial tick is a partial *stroke* rather than a scaled-down whole one.
    public static func tickPath(in box: CGRect, extent: Double) -> Path {
        let start = CGPoint(x: box.minX + box.width * 0.26, y: box.minY + box.height * 0.52)
        let elbow = CGPoint(x: box.minX + box.width * 0.44, y: box.minY + box.height * 0.70)
        let end = CGPoint(x: box.minX + box.width * 0.75, y: box.minY + box.height * 0.33)

        let firstLength = hypot(elbow.x - start.x, elbow.y - start.y)
        let secondLength = hypot(end.x - elbow.x, end.y - elbow.y)
        let total = firstLength + secondLength

        var path = Path()
        guard total > 0 else { return path }

        let drawn = total * min(max(extent, 0), 1)
        path.move(to: start)

        if drawn <= firstLength {
            let t = firstLength > 0 ? drawn / firstLength : 0
            path.addLine(to: CGPoint(
                x: start.x + (elbow.x - start.x) * t,
                y: start.y + (elbow.y - start.y) * t
            ))
        } else {
            path.addLine(to: elbow)
            let t = secondLength > 0 ? (drawn - firstLength) / secondLength : 0
            path.addLine(to: CGPoint(
                x: elbow.x + (end.x - elbow.x) * t,
                y: elbow.y + (end.y - elbow.y) * t
            ))
        }

        return path
    }
}
