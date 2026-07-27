import SwiftUI

/// Angle and value math for an arc-shaped dial.
///
/// Kept apart from the view because everything that can be wrong here is
/// arithmetic: which way the sweep runs, what happens in the gap between the
/// two ends, and where a drag lands when the finger leaves the track. A dial
/// that jumps from its minimum to its maximum because a thumb crossed the gap
/// is the classic failure, and it is only catchable in isolation.
///
/// Angles are measured clockwise from twelve o'clock, in degrees, so they read
/// the way the control looks rather than the way trigonometry prefers.
public enum LifeBoardArcDialGeometry {
    /// Where the track begins. Down-left, leaving the gap at the bottom where a
    /// gripping hand already covers the control.
    public static let startAngle: Double = 225
    /// How far the track runs, clockwise from `startAngle`.
    public static let sweep: Double = 270

    public static var endAngle: Double { startAngle + sweep }

    /// Fraction along the track for a unit progress value.
    public static func angle(forProgress progress: Double) -> Double {
        startAngle + sweep * progress.clampedToUnitInterval
    }

    /// Progress for an angle, clamped into the track.
    ///
    /// Angles inside the gap resolve to whichever end they are nearer, so a
    /// finger sliding off the bottom of the dial parks at min or max instead of
    /// teleporting across the range.
    public static func progress(forAngle angle: Double) -> Double {
        let offset = (angle - startAngle).positiveDegrees
        if offset <= sweep { return offset / sweep }
        // In the gap: split it, and snap to the closer end.
        let gap = 360 - sweep
        let intoGap = offset - sweep
        return intoGap < gap / 2 ? 1 : 0
    }

    /// Progress for a touch, relative to the dial's centre.
    ///
    /// Distance is ignored on purpose: once a drag starts, the finger routinely
    /// wanders off the ring, and following the angle alone keeps the knob under
    /// it instead of dropping the gesture.
    public static func progress(at point: CGPoint, center: CGPoint) -> Double {
        let dx = point.x - center.x
        let dy = point.y - center.y
        guard dx != 0 || dy != 0 else { return 0 }
        // atan2 measures counter-clockwise from east; convert to clockwise from north.
        let radians = atan2(dy, dx)
        let degrees = (radians * 180 / .pi + 90).positiveDegrees
        return progress(forAngle: degrees)
    }

    /// Snaps progress onto `step`-sized detents across `range`.
    public static func snapped(
        progress: Double,
        range: ClosedRange<Double>,
        step: Double
    ) -> Double {
        let value = self.value(forProgress: progress, range: range, step: step)
        return self.progress(forValue: value, range: range)
    }

    /// The dial's value at a progress, quantised to `step`.
    public static func value(
        forProgress progress: Double,
        range: ClosedRange<Double>,
        step: Double
    ) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return range.lowerBound }
        let raw = range.lowerBound + span * progress.clampedToUnitInterval
        guard step > 0 else { return min(max(raw, range.lowerBound), range.upperBound) }
        let stepped = (raw / step).rounded() * step
        return min(max(stepped, range.lowerBound), range.upperBound)
    }

    /// Progress showing `value` on the track.
    public static func progress(forValue value: Double, range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return ((value - range.lowerBound) / span).clampedToUnitInterval
    }
}

private extension Double {
    var clampedToUnitInterval: Double { min(max(self, 0), 1) }

    /// Same angle expressed in `0..<360`.
    var positiveDegrees: Double {
        let wrapped = truncatingRemainder(dividingBy: 360)
        return wrapped < 0 ? wrapped + 360 : wrapped
    }
}

/// A value dial you set by dragging around an arc.
///
/// Reads as one continuous gesture: the knob follows the finger's angle, detents
/// tick as they pass, and the arc fills behind. The whole control is one
/// adjustable accessibility element, so VoiceOver gets the same detents the
/// finger does.
public struct LifeBoardArcDial: View {
    private let title: String
    private let range: ClosedRange<Double>
    private let step: Double
    private let format: (Double) -> String
    @Binding private var value: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var lastDetent: Double?

    public init(
        title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 1,
        format: @escaping (Double) -> String = { String(Int($0.rounded())) }
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }

    private var progress: Double {
        LifeBoardArcDialGeometry.progress(forValue: value, range: range)
    }

    public var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let center = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
            ZStack {
                track(lineWidth: side * 0.10)
                fill(lineWidth: side * 0.10)
                knob(side: side)
                readout
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { drag in
                        apply(
                            LifeBoardArcDialGeometry.progress(at: drag.location, center: center)
                        )
                    }
                    .onEnded { _ in lastDetent = nil }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(format(value))
        .accessibilityAdjustableAction { direction in
            let delta = step > 0 ? step : (range.upperBound - range.lowerBound) / 10
            value = min(max(value + (direction == .increment ? delta : -delta), range.lowerBound), range.upperBound)
        }
    }

    private func apply(_ rawProgress: Double) {
        let next = LifeBoardArcDialGeometry.value(
            forProgress: rawProgress, range: range, step: step
        )
        guard next != value else { return }
        value = next
        // One tick per detent crossed, not per touch sample.
        if lastDetent != next {
            lastDetent = next
            LifeBoardHaptic.pick.play()
        }
    }

    private func track(lineWidth: CGFloat) -> some View {
        arcShape(to: 1)
            .stroke(
                Color(LifeBoardColorTokens.foundationHairline),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
    }

    private func fill(lineWidth: CGFloat) -> some View {
        arcShape(to: progress)
            .stroke(
                Color(LifeBoardColorTokens.foundationApricotAccent),
                style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
            )
            .animation(reduceMotion ? nil : LifeBoardAnimation.directManipulation, value: progress)
    }

    private func arcShape(to end: Double) -> LifeBoardArcDialTrack {
        LifeBoardArcDialTrack(progress: end)
    }

    private func knob(side: CGFloat) -> some View {
        let angle = Angle(degrees: LifeBoardArcDialGeometry.angle(forProgress: progress) - 90)
        let radius = side / 2 - side * 0.05
        return Circle()
            .fill(Color(LifeBoardColorTokens.foundationSurfaceSolid))
            .overlay { Circle().stroke(Color(LifeBoardColorTokens.foundationApricotAccent), lineWidth: 2) }
            .frame(width: side * 0.14, height: side * 0.14)
            .offset(x: radius * cos(angle.radians), y: radius * sin(angle.radians))
            .animation(reduceMotion ? nil : LifeBoardAnimation.directManipulation, value: progress)
    }

    private var readout: some View {
        VStack(spacing: 2) {
            Text(format(value))
                .font(.title2.weight(.semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
        }
    }
}

/// The dial's arc, drawn from the shared geometry so the track, the fill and the
/// knob cannot drift apart.
public struct LifeBoardArcDialTrack: Shape {
    public var progress: Double

    public init(progress: Double) {
        self.progress = progress
    }

    public var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    public func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) / 2 - min(rect.width, rect.height) * 0.05
        var path = Path()
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.midY),
            radius: radius,
            // Shift by 90° because Path measures from east, the geometry from north.
            startAngle: .degrees(LifeBoardArcDialGeometry.startAngle - 90),
            endAngle: .degrees(LifeBoardArcDialGeometry.angle(forProgress: progress) - 90),
            clockwise: false
        )
        return path
    }
}
