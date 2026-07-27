import SwiftUI

// MARK: - Completion mark
//
// The ring→tick morph. Interaction concept adapted from Shubham Kumar Singh's
// Apache-2.0 SwiftUI-Animations `DownloadArrowShape` / `DownloadTickShape`,
// which morph one glyph into another through a single `animatableData` channel.
// The geometry, phase split and easing here are LifeBoard's own: the sample
// morphs a download arrow inside a filled disc, this unwinds an open task ring
// and draws a checkmark in its place.
//
// One animatable channel is the whole point. Two independent animations (a ring
// fading while a tick scales) drift apart at different Dynamic Type sizes and
// under interrupted gestures; a single `progress` cannot desynchronise.

/// An open ring that unwinds as a checkmark draws in its place.
///
/// `progress` is the only input: `0` is a closed ring, `1` is a fully drawn
/// tick, and everything between is a genuine intermediate frame rather than a
/// cross-fade between two states.
public struct LifeBoardCompletionMark: Shape {
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
    static func tickPath(in box: CGRect, extent: Double) -> Path {
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

// MARK: - Completion control

/// The canonical task completion target.
///
/// Every task row in the Foundation shell previously drew a decorative `circle`
/// glyph with no gesture attached, so completing a task was only reachable from
/// widgets, notifications, Eva and routine steps. This is the 44 pt control the
/// task-row contract calls for.
///
/// Callers own the write. This view reports intent and plays the reward; it
/// never assumes the mutation succeeded.
public struct LifeBoardCompletionControl: View {
    private let isComplete: Bool
    private let title: String
    private let isEnabled: Bool
    private let onToggle: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase

    @State private var progress: Double = 0
    @State private var burstTrigger = 0

    /// The visible ring is smaller than the 44 pt target; the target is padding.
    private let markSide: CGFloat = 22
    private let strokeWidth: CGFloat = 2

    public init(
        isComplete: Bool,
        title: String,
        isEnabled: Bool = true,
        onToggle: @escaping (Bool) -> Void
    ) {
        self.isComplete = isComplete
        self.title = title
        self.isEnabled = isEnabled
        self.onToggle = onToggle
    }

    public var body: some View {
        Button(action: toggle) {
            ZStack {
                if isEnabled {
                    LifeBoardCompletionMark(progress: progress)
                        .stroke(
                            markTint,
                            style: StrokeStyle(lineWidth: strokeWidth, lineCap: .round, lineJoin: .round)
                        )
                        .frame(width: markSide, height: markSide)
                } else {
                    // A blocked task is a different state, not a disabled
                    // control: the lock explains *why* it cannot be completed.
                    Image(systemName: "lock.circle")
                        .font(.system(size: markSide, weight: .regular))
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                }
            }
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(LifeBoardCompletionButtonStyle())
        .disabled(isEnabled == false)
        .lifeboardCompletionBurst(trigger: burstTrigger)
        .onAppear { progress = isComplete ? 1 : 0 }
        .onChange(of: isComplete) { _, updated in settle(to: updated ? 1 : 0) }
        .accessibilityLabel(title)
        .accessibilityValue(accessibilityValue)
        .accessibilityHint(isEnabled ? "Completing can be undone." : "")
        .accessibilityAddTraits(isComplete ? [.isSelected] : [])
    }

    private var markTint: Color {
        // Shape carries the state, not colour: the ring and the tick are
        // different marks, so this survives Differentiate Without Color.
        isComplete
            ? Color(LifeBoardColorTokens.foundationSageAccent)
            : Color(LifeBoardColorTokens.inkTertiary)
    }

    private var accessibilityValue: String {
        if isEnabled == false { return "Waiting on a dependency" }
        return isComplete ? "Complete" : "Not complete"
    }

    private func toggle() {
        let target = isComplete == false
        settle(to: target ? 1 : 0)
        if target {
            burstTrigger &+= 1
            LifeBoardHaptic.commit.play(policy: motionPolicy)
        } else {
            LifeBoardHaptic.decline.play(policy: motionPolicy)
        }
        onToggle(target)
    }

    private var motionPolicy: LifeBoardMotionPolicy {
        LifeBoardMotionPolicy.resolve(
            reduceMotion: reduceMotion || LifeBoardVisualAppearanceFixture.active?.usesReducedMotion == true,
            reduceTransparency: reduceTransparency || LifeBoardVisualAppearanceFixture.active?.usesReducedTransparency == true,
            sceneIsActive: scenePhase == .active
        )
    }

    /// Under Reduce Motion the mark snaps between its two rest states. It never
    /// stops part-drawn, which would leave an ambiguous glyph on screen.
    private func settle(to target: Double) {
        let suppressed = LifeBoardAnimation.animationsDisabled(reduceMotion: reduceMotion)
            || LifeBoardVisualAppearanceFixture.active?.usesReducedMotion == true
        guard suppressed == false else {
            progress = target
            return
        }
        withAnimation(LifeBoardInteractionMotion.completion(reduceMotion: false)) {
            progress = target
        }
    }
}

/// Press feedback for the completion target. Separate from
/// `LifeBoardClayButtonStyle` because this control has no clay surface to
/// compress — only the mark itself moves.
private struct LifeBoardCompletionButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && reduceMotion == false ? 0.88 : 1)
            .animation(LifeBoardMotionProfile.press.animation(reduceMotion: reduceMotion), value: configuration.isPressed)
    }
}
