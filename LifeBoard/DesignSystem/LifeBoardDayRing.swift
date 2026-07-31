import SwiftUI

// MARK: - Day ring
//
// Two arcs growing symmetrically from twelve o'clock. Structure adapted from
// Shubham Kumar Singh's Apache-2.0 SwiftUI-Animations `CircularDownloadView`,
// which mirrors one trimmed circle against another so a single progress value
// reads as two halves closing toward each other. The geometry, the semantics and
// the honesty rules here are LifeBoard's own: the sample shows one download
// filling, this shows two independent quantities — what the day held, and what
// was actually spent inside it.
//
// Symmetry is doing real work rather than decoration. A day is a span with a
// middle, so growth from the top outward reads as "the day filling in from both
// ends" rather than as a gauge being scored out of a target. That distinction is
// the entire point: this ring reports, it does not grade.

/// One half of the mirrored pair.
///
/// Split out as a `Shape` so the arc animates through `animatableData` rather
/// than by re-laying-out a `Circle().trim`, which cannot interpolate its own
/// trim across a mirrored `rotation3DEffect` without visible snapping.
public struct LifeBoardDayRingArc: Shape {
    /// Portion of the half-circle drawn, 0...1.
    public var extent: Double
    /// `false` mirrors the sweep to the other side of twelve o'clock.
    public let isTrailing: Bool

    public var animatableData: Double {
        get { extent }
        set { extent = newValue }
    }

    public init(extent: Double, isTrailing: Bool) {
        self.extent = extent
        self.isTrailing = isTrailing
    }

    public func path(in rect: CGRect) -> Path {
        let clamped = min(max(extent, 0), 1)
        guard clamped > 0 else { return Path() }
        let radius = min(rect.width, rect.height) / 2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // -90° is twelve o'clock in SwiftUI's coordinate space.
        let sweep = 180.0 * clamped
        var path = Path()
        path.addArc(
            center: center,
            radius: radius,
            startAngle: .degrees(-90),
            endAngle: .degrees(isTrailing ? -90 + sweep : -90 - sweep),
            clockwise: !isTrailing
        )
        return path
    }
}

/// The day, as one object: an outer arc for what the day held and an inner arc
/// for what was actually spent inside it.
///
/// Both quantities are optional, and that is the whole contract. A day with no
/// blocks renders a bare track and says so; it never renders a 0% arc, because
/// "nothing was planned" and "everything planned was missed" are different facts
/// and only one of them is true.
public struct LifeBoardDayRing: View {
    private let plannedMinutes: Int?
    private let focusedMinutes: Int?
    /// Drives the closing checkmark. Only ever set at the moment a day is
    /// deliberately closed — never as a verdict on how the day went.
    private let closedProgress: Double
    private let diameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The arc caps here, so an overrun stays legible as a full ring instead of
    /// wrapping. The *number* beside it is never clamped — see
    /// `DayCloseRingSummary.focusRatio`.
    private static let maximumArcExtent: Double = 1

    public init(
        plannedMinutes: Int?,
        focusedMinutes: Int?,
        closedProgress: Double = 0,
        diameter: CGFloat = 148
    ) {
        self.plannedMinutes = plannedMinutes
        self.focusedMinutes = focusedMinutes
        self.closedProgress = closedProgress
        self.diameter = diameter
    }

    /// Focused against planned. `nil` when there is nothing to compare against.
    private var focusExtent: Double? {
        guard let plannedMinutes, plannedMinutes > 0, let focusedMinutes else { return nil }
        return min(Double(focusedMinutes) / Double(plannedMinutes), Self.maximumArcExtent)
    }

    /// The outer arc is the day's own shape, so it is always whole when anything
    /// was planned. It is a frame for the inner arc, not a second score.
    private var plannedExtent: Double {
        (plannedMinutes ?? 0) > 0 ? 1 : 0
    }

    public var body: some View {
        ZStack {
            track(inset: 0)
            track(inset: 18)

            arcPair(extent: plannedExtent, inset: 0, lineWidth: 7)
                .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))

            if let focusExtent {
                arcPair(extent: focusExtent, inset: 18, lineWidth: 7)
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationSunAccent))
            }

            if closedProgress > 0 {
                // Reuses the shipped ring→tick morph rather than re-porting it.
                LifeBoardCompletionMark(progress: closedProgress)
                    .stroke(
                        Color(LifeBoardColorTokens.foundationSunAccent),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round, lineJoin: .round)
                    )
                    .frame(width: diameter * 0.32, height: diameter * 0.32)
            } else {
                centreFigures
            }
        }
        .frame(width: diameter, height: diameter)
        .lifeBoardMotion(.controlMorph, value: focusExtent)
        .lifeBoardMotion(.celebration, value: closedProgress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your day")
        .accessibilityValue(accessibilityValue)
    }

    private func track(inset: CGFloat) -> some View {
        Circle()
            .stroke(Color(LifeBoardColorTokens.metricRingTrack), lineWidth: 7)
            .padding(inset)
    }

    private func arcPair(extent: Double, inset: CGFloat, lineWidth: CGFloat) -> some View {
        ZStack {
            LifeBoardDayRingArc(extent: extent, isTrailing: true)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            LifeBoardDayRingArc(extent: extent, isTrailing: false)
                .stroke(style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
        }
        .padding(inset)
    }

    @ViewBuilder
    private var centreFigures: some View {
        VStack(spacing: 2) {
            if let focusedMinutes {
                LifeBoardNumericRoll(
                    value: Double(focusedMinutes),
                    unit: "min",
                    emphasis: .hero
                )
                Text("focused")
                    .font(LifeBoardFoundationTypography.metadata())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            } else if plannedMinutes == nil {
                // Not an error and not a zero. The day simply had no shape to
                // report, which is an ordinary way for a day to go.
                Text("Open day")
                    .font(LifeBoardFoundationTypography.metric())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    .multilineTextAlignment(.center)
            } else {
                Text("No focus\nrecorded")
                    .font(LifeBoardFoundationTypography.metadata())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 8)
    }

    private var accessibilityValue: String {
        switch (plannedMinutes, focusedMinutes) {
        case let (planned?, focused?):
            "\(focused) minutes focused, against \(planned) minutes planned"
        case let (planned?, nil):
            "\(planned) minutes planned. No focus recorded."
        case let (nil, focused?):
            "\(focused) minutes focused. Nothing was planned."
        case (nil, nil):
            "Nothing was planned and no focus was recorded."
        }
    }
}
