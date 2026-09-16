import SwiftUI
import UIKit

// MARK: - Geometry and rules

/// Everything about the habit ring that can be decided without drawing: what a
/// tap adds, how a hold fills, where a finger on the ring lands, and what
/// VoiceOver says. Pure, so the feel of the control is pinned by tests.
enum HabitRingGeometry {
    /// A press becomes a hold after this long without release.
    static let holdDelay: TimeInterval = 0.25
    /// A hold fills from the logged amount to the target over this long.
    static let holdFillDuration: TimeInterval = 0.6
    /// Scrubbing may overshoot the target to show extra effort, to this much.
    static let overachievementCeiling: Double = 1.5
    /// More detents than this and each one stops being felt; haptics thin out.
    static let maximumHapticDetents = 8

    static func fraction(value: Double, target: Double) -> Double {
        guard target > 0, value.isFinite else { return 0 }
        return min(max(0, value / target), overachievementCeiling)
    }

    /// Fill progress for a press held this long; nil while it is still a tap.
    static func holdProgress(elapsed: TimeInterval) -> Double? {
        guard elapsed >= holdDelay else { return nil }
        return min(1, (elapsed - holdDelay) / holdFillDuration)
    }

    /// The amount shown while a hold fills: from what is logged toward the
    /// target. A hold never lowers an amount already past the target.
    static func holdValue(progress: Double, saved: Double, target: Double) -> Double {
        guard saved < target else { return saved }
        return saved + (target - saved) * min(max(progress, 0), 1)
    }

    /// Which amount a finger at `point` means, continuing from `previous` so a
    /// drag past twelve o'clock carries on into the second lap instead of
    /// jumping back to zero. Snaps to `step`.
    static func scrubValue(
        at point: CGPoint,
        center: CGPoint,
        previous: Double,
        target: Double,
        step: Double
    ) -> Double {
        guard target > 0 else { return previous }
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        // Clockwise from twelve o'clock, in turns 0..<1.
        var turns = atan2(dx, -dy) / (2 * .pi)
        if turns < 0 { turns += 1 }
        let previousFraction = previous / target
        let candidates = [turns, turns + 1].filter { $0 <= overachievementCeiling + 0.25 }
        let nearest = candidates.min { abs($0 - previousFraction) < abs($1 - previousFraction) } ?? turns
        let clamped = min(max(0, nearest), overachievementCeiling)
        return snap(clamped * target, step: step, target: target)
    }

    static func snap(_ value: Double, step: Double, target: Double) -> Double {
        guard step > 0 else { return value }
        let snapped = (value / step).rounded() * step
        return min(max(0, snapped), target * overachievementCeiling)
    }

    /// How many step boundaries a change crossed — one detent haptic each,
    /// thinned so large targets do not buzz continuously.
    static func detentsCrossed(from: Double, to: Double, step: Double, target: Double) -> Int {
        guard step > 0 else { return 0 }
        let crossed = abs(Int((to / step).rounded(.down)) - Int((from / step).rounded(.down)))
        let totalSteps = max(1, Int((target / step).rounded(.up)))
        guard totalSteps > maximumHapticDetents else { return crossed }
        let detentSize = Double(totalSteps) / Double(maximumHapticDetents)
        return Int((Double(crossed) / detentSize).rounded(.down))
    }

    /// Whether a touch began on the ring's stroke rather than its middle.
    static func isOnStroke(_ point: CGPoint, center: CGPoint, radius: CGFloat, tolerance: CGFloat = 16) -> Bool {
        let distance = hypot(point.x - center.x, point.y - center.y)
        return abs(distance - radius) <= tolerance
    }

    /// Step boundaries worth drawing as ticks on the track (small targets only).
    static func tickFractions(target: Double, step: Double) -> [Double] {
        guard step > 0, target > 0 else { return [] }
        let count = Int((target / step).rounded(.up))
        guard count > 1, count <= 12 else { return [] }
        return (1..<count).map { Double($0) * step / target }
    }

    static func centerText(value: Double, target: Double, isTimed: Bool) -> String {
        if isTimed {
            return "\(Int((value / 60).rounded(.down)))/\(Int((target / 60).rounded()))"
        }
        return "\(formatted(value))/\(formatted(target))"
    }

    static func accessibilityValue(value: Double, target: Double, unit: String, isTimed: Bool) -> String {
        if isTimed {
            return "\(Int((value / 60).rounded(.down))) of \(Int((target / 60).rounded())) minutes"
        }
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedUnit.isEmpty
            ? "\(formatted(value)) of \(formatted(target))"
            : "\(formatted(value)) of \(formatted(target)) \(trimmedUnit)"
    }

    static func formatted(_ value: Double) -> String {
        value.rounded() == value ? String(Int(value)) : String(format: "%.1f", value)
    }
}

// MARK: - Control

/// Log a habit amount where it is shown: tap for one step, hold to finish,
/// hold and slide around the ring to set any amount.
///
/// The ring owns only the gesture and its motion. The caller owns the write
/// (`onChange`) and reports whether it persisted, so completion motion never
/// plays for a save that failed — `DESIGN.md`: effects after persistence.
struct HabitProgressRing: View {
    enum TapBehavior {
        case addStep
        case perform(() -> Void)
    }

    enum Size {
        case hero, board, row

        var diameter: CGFloat {
            switch self {
            case .hero: 120
            case .board: 56
            case .row: 36
            }
        }

        var lineWidth: CGFloat {
            switch self {
            case .hero: 10
            case .board: 6
            case .row: 4
            }
        }

        var supportsScrub: Bool { self != .row }
    }

    let title: String
    let value: Double
    let target: Double
    let step: Double
    let unit: String
    let isTimed: Bool
    var size: Size = .board
    /// What a quick tap does. Amount habits add a step; a check-in habit opens
    /// instead, so only a deliberate hold can complete it.
    var tapBehavior: TapBehavior = .addStep
    /// Check-ins have no count worth printing in the middle of the ring.
    var showsCount = true
    /// Persist a change; return true once it is saved.
    let onChange: (HabitAmountChange) async -> Bool

    @Environment(\.lifeBoardMotionContext) private var motion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var liveValue: Double?
    @State private var holdStartedAt: Date?
    @State private var holdTask: Task<Void, Never>?
    @State private var holdEngaged = false
    @State private var isScrubbing = false
    @State private var isCommitting = false
    @State private var bloomTrigger = 0
    @State private var burstTrigger = 0
    @State private var completionProgress: Double = 0
    @State private var shakeOffset: CGFloat = 0

    private var displayedValue: Double { liveValue ?? value }
    private var isComplete: Bool { displayedValue >= target }
    private var spatialMotion: Bool { motion.allowsSpatialMotion && motion.comfortProfile != .calm }

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                HabitRingStepper(
                    title: title,
                    value: displayedValue,
                    target: target,
                    unit: unit,
                    isTimed: isTimed,
                    onStep: { delta in commit(.add(delta)) },
                    step: step
                )
            } else {
                ring
            }
        }
        .onAppear { completionProgress = value >= target ? 1 : 0 }
        .onChange(of: value) { _, newValue in
            // The store caught up with what the ring showed; stop overriding it.
            if let liveValue, abs(liveValue - newValue) < 0.0001 { self.liveValue = nil }
            if isCommitting == false { completionProgress = newValue >= target ? 1 : 0 }
        }
    }

    private var ring: some View {
        let center = CGPoint(x: size.diameter / 2, y: size.diameter / 2)
        let radius = (size.diameter - size.lineWidth) / 2
        return ZStack {
                HabitRingTrack(
                    fraction: HabitRingGeometry.fraction(value: displayedValue, target: target),
                    ticks: size == .row ? [] : HabitRingGeometry.tickFractions(target: target, step: step),
                    ghostFraction: holdStartedAt != nil && isScrubbing == false && value < target ? 1 : nil,
                    lineWidth: size.lineWidth,
                    completionProgress: completionProgress
                )
                if isScrubbing {
                    HabitRingBead(
                        fraction: HabitRingGeometry.fraction(value: displayedValue, target: target),
                        radius: radius,
                        diameter: size.lineWidth + 6
                    )
                }
                if showsCount {
                    HabitRingCenter(
                        value: displayedValue,
                        target: target,
                        unit: unit,
                        isTimed: isTimed,
                        size: size,
                        isComplete: completionProgress >= 1
                    )
                }
        }
        .frame(width: size.diameter, height: size.diameter)
        .contentShape(Circle())
        // Tap and hold live on the same view. As a child gesture the hold used
        // to outrank the tap, so a quick tap never added a step; recognizing
        // them together, the hold's release is kept from counting as a tap by
        // `holdEngaged`.
        .onTapGesture { tap() }
        .simultaneousGesture(holdAndScrub(center: center, radius: radius))
        .scaleEffect(holdStartedAt != nil && spatialMotion ? 0.97 : 1)
        .animation(MotionProfile.press.animation(reduceMotion: motion.effectiveReduceMotion), value: holdStartedAt != nil)
        .offset(x: shakeOffset)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .lifeboardClayPressBloom(trigger: bloomTrigger)
        .lifeboardCompletionBurst(trigger: burstTrigger)
        // No context menu on the ring itself: its long-press fired half-way
        // through a hold. Callers put secondary actions on the label instead.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(
            showsCount
                ? HabitRingGeometry.accessibilityValue(value: displayedValue, target: target, unit: unit, isTimed: isTimed)
                : (isComplete ? "Done" : "Not done")
        )
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: commit(.add(step))
            case .decrement: commit(.add(-step))
            @unknown default: break
            }
        }
        .accessibilityAction(named: "Complete") { commit(.set(max(target, value))) }
    }

    // MARK: Gestures

    private func holdAndScrub(center: CGPoint, radius: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: HabitRingGeometry.holdDelay, maximumDistance: 12)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { phase in
                switch phase {
                case .first:
                    break
                case .second(true, let drag):
                    if holdStartedAt == nil { beginHold() }
                    guard let drag, size.supportsScrub else { return }
                    let moved = hypot(drag.translation.width, drag.translation.height)
                    if isScrubbing == false, moved > 6,
                       HabitRingGeometry.isOnStroke(drag.startLocation, center: center, radius: radius, tolerance: radius * 0.6) {
                        beginScrub()
                    }
                    if isScrubbing { scrub(to: drag.location, center: center) }
                default:
                    break
                }
            }
            .onEnded { _ in endHold() }
    }

    private func tap() {
        // A hold that has begun ends in `endHold`; its release is not a tap.
        guard holdEngaged == false else {
            holdEngaged = false
            return
        }
        bloomTrigger &+= 1
        switch tapBehavior {
        case .addStep:
            commit(.add(step))
        case .perform(let action):
            Haptic.pick.play()
            action()
        }
    }

    private func beginHold() {
        holdEngaged = true
        holdStartedAt = Date()
        Haptic.pick.play()
        guard value < target else { return }
        let start = Date()
        holdTask?.cancel()
        holdTask = Task { @MainActor in
            var lastValue = value
            while Task.isCancelled == false {
                let elapsed = Date().timeIntervalSince(start) + HabitRingGeometry.holdDelay
                let progress = HabitRingGeometry.holdProgress(elapsed: elapsed) ?? 0
                let next = HabitRingGeometry.holdValue(progress: progress, saved: value, target: target)
                if HabitRingGeometry.detentsCrossed(from: lastValue, to: next, step: step, target: target) > 0 {
                    Haptic.pick.play()
                }
                lastValue = next
                liveValue = next
                if progress >= 1 {
                    Haptic.threshold.play()
                    holdTask = nil
                    commit(.set(target), fromHold: true)
                    return
                }
                try? await Task.sleep(for: .milliseconds(33))
            }
        }
    }

    private func beginScrub() {
        holdTask?.cancel()
        holdTask = nil
        isScrubbing = true
        liveValue = value
    }

    private func scrub(to location: CGPoint, center: CGPoint) {
        let previous = liveValue ?? value
        let next = HabitRingGeometry.scrubValue(at: location, center: center, previous: previous, target: target, step: step)
        guard next != previous else { return }
        if HabitRingGeometry.detentsCrossed(from: previous, to: next, step: step, target: target) > 0 {
            Haptic.pick.play()
        }
        if (previous < target) != (next < target) || next >= target * HabitRingGeometry.overachievementCeiling {
            Haptic.threshold.play()
        }
        liveValue = next
    }

    private func endHold() {
        holdStartedAt = nil
        if isScrubbing {
            isScrubbing = false
            if let liveValue, liveValue != value { commit(.set(liveValue)) }
            return
        }
        if let holdTask {
            // Released before the ring filled: spring back to what is saved.
            holdTask.cancel()
            self.holdTask = nil
            withAnimation(InteractionMotion.dragRelease(reduceMotion: motion.effectiveReduceMotion)) {
                liveValue = nil
            }
        }
    }

    // MARK: Commit

    private func commit(_ change: HabitAmountChange, fromHold: Bool = false) {
        guard isCommitting == false else { return }
        let before = value
        let optimistic = HabitAmountRule.apply(change, to: before, target: target)
        let wasComplete = before >= target
        let willComplete = optimistic >= target
        isCommitting = true
        withAnimation(LifeBoardAnimation.animationsDisabled(reduceMotion: motion.effectiveReduceMotion) ? nil : LifeBoardAnimation.numericUpdate) {
            liveValue = optimistic
        }
        if fromHold == false, HabitRingGeometry.detentsCrossed(from: before, to: optimistic, step: step, target: target) > 0 {
            if willComplete, wasComplete == false { Haptic.threshold.play() } else { Haptic.pick.play() }
        }
        Task { @MainActor in
            let saved = await onChange(change)
            isCommitting = false
            guard saved else {
                failed()
                return
            }
            if willComplete, wasComplete == false {
                celebrate()
            } else if willComplete == false, wasComplete {
                Haptic.decline.play()
                withAnimation(InteractionMotion.completion(reduceMotion: motion.effectiveReduceMotion)) {
                    completionProgress = 0
                }
            }
        }
    }

    /// Ring closes, tick draws, burst behind — after the save, never before.
    private func celebrate() {
        Haptic.commit.play()
        if spatialMotion { burstTrigger &+= 1 }
        withAnimation(spatialMotion ? InteractionMotion.completion(reduceMotion: false) : .easeOut(duration: 0.16)) {
            completionProgress = 1
        }
        if motion.comfortProfile == .playful, spatialMotion {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                Haptic.settle.play()
            }
        }
        UIAccessibility.post(notification: .announcement, argument: "\(title) done")
    }

    private func failed() {
        Haptic.fail.play()
        withAnimation(InteractionMotion.dragRelease(reduceMotion: motion.effectiveReduceMotion)) {
            liveValue = nil
        }
        guard spatialMotion else { return }
        Task { @MainActor in
            for offset in [4.0, -4.0, 3.0, -3.0, 0.0] {
                withAnimation(.easeInOut(duration: 0.048)) { shakeOffset = offset }
                try? await Task.sleep(for: .milliseconds(48))
            }
        }
    }
}

// MARK: - Pieces

/// Track, progress arc, overachievement lap, step ticks, the hold's ghost
/// arc, and the completed disc with its tick.
private struct HabitRingTrack: View {
    let fraction: Double
    let ticks: [Double]
    let ghostFraction: Double?
    let lineWidth: CGFloat
    let completionProgress: Double

    var body: some View {
        ZStack {
            // Inset so the stroke sits inside the frame: centred on the edge,
            // half of it was clipped flat by effects that rasterize to bounds,
            // which drew the ring as an octagon.
            Circle()
                .inset(by: lineWidth / 2)
                .stroke(Color(SemanticColorTokens.foundationSurfaceRecessed), lineWidth: lineWidth)
            if let ghostFraction {
                Circle()
                    .inset(by: lineWidth / 2)
                    .trim(from: 0, to: ghostFraction)
                    .stroke(
                        Color(SemanticColorTokens.foundationSageAccent).opacity(0.35),
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [2, lineWidth])
                    )
                    .rotationEffect(.degrees(-90))
                    .transition(.opacity)
            }
            Circle()
                .inset(by: lineWidth / 2)
                .trim(from: 0, to: min(1, fraction))
                .stroke(Color(SemanticColorTokens.foundationSageAccent), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if fraction > 1 {
                // Past the target: a second, lighter lap rather than a full ring
                // that stops saying anything.
                Circle()
                    .inset(by: lineWidth / 2)
                    .trim(from: 0, to: fraction - 1)
                    .stroke(Color(SemanticColorTokens.foundationSageAccent).opacity(0.45), style: StrokeStyle(lineWidth: lineWidth * 0.6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(lineWidth * 1.2)
            }
            ForEach(ticks, id: \.self) { tick in
                Circle()
                    .fill(Color(tick <= fraction ? SemanticColorTokens.foundationSurfaceSolid : SemanticColorTokens.inkTertiary).opacity(0.7))
                    .frame(width: lineWidth * 0.4, height: lineWidth * 0.4)
                    .offset(y: -1)
                    .modifier(RingTickPlacement(fraction: tick, lineWidth: lineWidth))
            }
            if completionProgress > 0 {
                Circle()
                    .fill(Color(SemanticColorTokens.foundationSageAccent))
                    .padding(lineWidth / 2)
                    .opacity(completionProgress)
                CompletionMark(progress: completionProgress)
                    .stroke(Color.lifeboard(.textInverse), style: StrokeStyle(lineWidth: max(2, lineWidth * 0.45), lineCap: .round, lineJoin: .round))
                    .padding(lineWidth * 2.2)
            }
        }
    }
}

private struct RingTickPlacement: ViewModifier {
    let fraction: Double
    let lineWidth: CGFloat

    func body(content: Content) -> some View {
        GeometryReader { proxy in
            let radius = (min(proxy.size.width, proxy.size.height) - lineWidth) / 2
            let angle = fraction * 2 * .pi
            content.position(
                x: proxy.size.width / 2 + radius * sin(angle),
                y: proxy.size.height / 2 - radius * cos(angle)
            )
        }
    }
}

private struct HabitRingBead: View {
    let fraction: Double
    let radius: CGFloat
    let diameter: CGFloat

    var body: some View {
        let angle = min(fraction, HabitRingGeometry.overachievementCeiling) * 2 * .pi
        Circle()
            .fill(Color(SemanticColorTokens.foundationSurfaceSolid))
            .overlay(Circle().stroke(Color(SemanticColorTokens.foundationSageAccent), lineWidth: 2))
            .frame(width: diameter, height: diameter)
            .offset(x: radius * sin(angle), y: -radius * cos(angle))
            .transition(.scale.combined(with: .opacity))
            .allowsHitTesting(false)
    }
}

private struct HabitRingCenter: View {
    let value: Double
    let target: Double
    let unit: String
    let isTimed: Bool
    let size: HabitProgressRing.Size
    let isComplete: Bool

    var body: some View {
        switch size {
        case .hero:
            VStack(spacing: 4) {
                NumericRoll(value: isTimed ? (value / 60).rounded(.down) : value, unit: nil, emphasis: .standard)
                Text(isTimed ? "of \(Int((target / 60).rounded())) min" : "of \(HabitRingGeometry.formatted(target)) \(unit)")
                    .lifeboardFont(.caption2)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            .opacity(isComplete ? 0 : 1)
        case .board:
            Text(HabitRingGeometry.centerText(value: value, target: target, isTimed: isTimed))
                .lifeboardFont(.caption2)
                .monospacedDigit()
                .contentTransition(.numericText(value: value))
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .opacity(isComplete ? 0 : 1)
        case .row:
            EmptyView()
        }
    }
}

/// At accessibility text sizes the ring gives way to buttons: the same
/// actions, laid out so they never overlap or shrink.
private struct HabitRingStepper: View {
    let title: String
    let value: Double
    let target: Double
    let unit: String
    let isTimed: Bool
    let onStep: (Double) -> Void
    let step: Double

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onStep(-step)
            } label: {
                Image(systemName: "minus").frame(width: 44, height: 44)
            }
            .disabled(value <= 0)
            .accessibilityLabel("Less \(title)")
            Text(HabitRingGeometry.accessibilityValue(value: value, target: target, unit: unit, isTimed: isTimed))
                .lifeboardFont(.body)
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .center)
            Button {
                onStep(step)
            } label: {
                Image(systemName: "plus").frame(width: 44, height: 44)
            }
            .accessibilityLabel("More \(title)")
        }
        .buttonStyle(.lifeBoardChip)
    }
}
