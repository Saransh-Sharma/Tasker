import SwiftUI

// MARK: - Value drum geometry

/// Tape arithmetic for `ValueDrum`, kept apart from the view.
///
/// Everything that can be wrong on a scrubbing tape is arithmetic: which way the
/// value runs relative to the finger, what happens past the ends, and whether a
/// detent fires once or on every touch sample. That is only catchable in
/// isolation, which is the same reason `ArcDialGeometry` exists.
public enum ValueDrumGeometry {
    /// Travel for one `step`. Tuned so a 300-point tape spans roughly twenty
    /// detents — dense enough to feel like a scale, loose enough to land on one.
    public static let pointsPerStep: CGFloat = 14

    /// The value a drag lands on.
    ///
    /// Dragging left pulls the tape left and brings larger values into the
    /// centre, which is how every physical dial and every scale in the world
    /// behaves. Getting this backwards is the classic bug.
    public static func value(
        from start: Double,
        translation: CGFloat,
        range: ClosedRange<Double>,
        step: Double
    ) -> Double {
        guard step > 0 else { return start }
        let steps = Double(-translation / pointsPerStep)
        let raw = start + steps * step
        let quantised = (raw / step).rounded() * step
        return rubberBanded(quantised, range: range, step: step)
    }

    /// Past either end the tape keeps moving but logarithmically less, so the
    /// bound is felt rather than hit like a wall — and it can never be dragged
    /// somewhere the value cannot go.
    public static func rubberBanded(
        _ value: Double,
        range: ClosedRange<Double>,
        step: Double
    ) -> Double {
        if value < range.lowerBound {
            let excess = range.lowerBound - value
            return range.lowerBound - log10(1 + excess / max(step, 0.0001)) * step
        }
        if value > range.upperBound {
            let excess = value - range.upperBound
            return range.upperBound + log10(1 + excess / max(step, 0.0001)) * step
        }
        return value
    }

    /// Where the tape settles once the finger lifts.
    public static func settled(_ value: Double, range: ClosedRange<Double>, step: Double) -> Double {
        let clamped = min(max(value, range.lowerBound), range.upperBound)
        guard step > 0 else { return clamped }
        let quantised = (clamped / step).rounded() * step
        return min(max(quantised, range.lowerBound), range.upperBound)
    }

    /// Horizontal offset of `tick` when the tape is centred on `value`.
    public static func offset(ofTick tick: Double, centeredOn value: Double, step: Double) -> CGFloat {
        guard step > 0 else { return 0 }
        return CGFloat((tick - value) / step) * pointsPerStep
    }

    /// The inclusive tick values visible on a tape of `width` centred on `value`.
    ///
    /// Ticks are built from an integer index times `step`, never by accumulating
    /// `current += step`. With a 0.1 kg step the accumulated form drifts off the
    /// exact multiples within a few dozen iterations, so `isCoarse` below never
    /// matched and a weight tape rendered with no major ticks and no labels at
    /// all — a ruler with no numbers on it.
    ///
    /// Clamped to the range so the tape shows genuine emptiness past the ends
    /// rather than inventing readings nobody can have.
    public static func visibleTicks(
        centeredOn value: Double,
        width: CGFloat,
        range: ClosedRange<Double>,
        step: Double
    ) -> [Double] {
        guard step > 0, width > 0 else { return [] }
        let halfSteps = Double(width / 2 / pointsPerStep) + 2
        let lowest = max(range.lowerBound, value - halfSteps * step)
        let highest = min(range.upperBound, value + halfSteps * step)
        guard lowest <= highest else { return [] }

        let firstIndex = Int((lowest / step).rounded(.up))
        let lastIndex = Int((highest / step).rounded(.down))
        guard firstIndex <= lastIndex else { return [] }
        // Bounded so a pathological step can never allocate without limit.
        let count = min(lastIndex - firstIndex + 1, 512)
        return (0..<count).map { Double(firstIndex + $0) * step }
    }

    /// Whether a tick is a labelled major division.
    ///
    /// Compared as a ratio rather than with `truncatingRemainder`, because the
    /// remainder of two binary-inexact decimals is itself inexact and the naive
    /// test fails for exactly the steps this control uses most (0.1, 0.25, 0.5).
    public static func isCoarse(_ tick: Double, coarseStep: Double) -> Bool {
        guard coarseStep > 0 else { return false }
        let ratio = tick / coarseStep
        return abs(ratio - ratio.rounded()) < 1e-6
    }
}

// MARK: - Value drum

/// Free numeric entry as a tape you scrub.
///
/// The flagship of the entry layer, and the replacement for the single most
/// off-brand control in the app: a bare `.decimalPad` field beside a
/// `Stepper("Adjust")` that moved weight one kilogram at a time.
///
/// The readout is a real, always-visible `TextField`. Typing is never the
/// fallback path here — it is the fast path for someone who already knows the
/// number, and it is also what keeps `app.textFields["track.tracker.value.numeric"]`
/// bound. The tape is for the far more common case of nudging from yesterday's
/// value, where a keyboard is the slow way to move 1.4 kilograms.
public struct ValueDrum: View {
    private let label: String
    private let range: ClosedRange<Double>
    private let step: Double
    private let coarseStep: Double?
    private let unit: String
    private let fractionDigits: Int
    private let identifier: String?
    private let keyboardPrompt: String
    @Binding private var value: Double

    @FocusState private var isTyping: Bool
    @State private var dragStart: Double?
    @State private var lastDetent: Double?
    @State private var grip: Double = 0

    public init(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double,
        coarseStep: Double? = nil,
        unit: String,
        fractionDigits: Int = 1,
        identifier: String? = nil,
        keyboardPrompt: String = "Value"
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.coarseStep = coarseStep
        self.unit = unit
        self.fractionDigits = fractionDigits
        self.identifier = identifier
        self.keyboardPrompt = keyboardPrompt
    }

    public var body: some View {
        VStack(spacing: 12) {
            readout
            tape
        }
        .frame(maxWidth: .infinity)
    }

    private var readout: some View {
        VStack(spacing: 2) {
            TextField(
                keyboardPrompt,
                value: $value,
                format: .number.precision(.fractionLength(0...fractionDigits))
            )
            .font(Typography.hero())
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .padKeyboard(.decimalPad, isFocused: $isTyping)
            .focused($isTyping)
            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .modifier(FieldIdentity(identifier: identifier))
            .accessibilityLabel(Text(label))

            Text(unit)
                .font(.lifeboard(.meta))
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
    }

    private var tape: some View {
        GeometryReader { proxy in
            ValueDrumTape(
                value: value,
                range: range,
                step: step,
                coarseStep: coarseStep ?? step * 10,
                fractionDigits: fractionDigits
            )
            .frame(width: proxy.size.width, height: proxy.size.height)
            // The warp rides the tape and only the tape. The readout, the unit
            // and the label are siblings outside this modifier, so the shader
            // is structurally incapable of softening a number anyone is reading.
            .lifeboardValueDrumWarp(grip: grip, center: 0.5)
            .overlay { centreIndicator }
            .contentShape(Rectangle())
            .gesture(scrub)
        }
        .frame(height: 64)
        .clipShape(RoundedRectangle(
            cornerRadius: Radius.compact + 2,
            style: .continuous
        ))
        .lifeBoardClaySurface(.well, cornerRadius: Radius.compact + 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(label) tape"))
        .accessibilityValue(Text("\(formatted(value)) \(unit)"))
        .accessibilityHint(Text("Swipe left or right to change the value"))
        .accessibilityAdjustableAction { direction in
            let delta = coarseStep ?? step
            let next = ValueDrumGeometry.settled(
                value + (direction == .increment ? delta : -delta),
                range: range,
                step: step
            )
            guard next != value else { return }
            value = next
            Haptic.pick.play()
        }
    }

    /// Spans the tick band only. Running it the full height put the accent bar
    /// straight through the coarse tick's own label, so the number under the
    /// needle was the one number you could not read.
    private var centreIndicator: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(SemanticColorTokens.foundationApricotAccent))
                .frame(width: 2.5, height: 30)
            Spacer(minLength: 0)
        }
        .padding(.top, 8)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var scrub: some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { drag in
                if dragStart == nil {
                    dragStart = value
                    grip = 1
                    isTyping = false
                    Haptic.lift.play()
                }
                guard let dragStart else { return }
                let next = ValueDrumGeometry.value(
                    from: dragStart,
                    translation: drag.translation.width,
                    range: range,
                    step: step
                )
                guard next != value else { return }
                value = next
                tick(next)
            }
            .onEnded { _ in
                value = ValueDrumGeometry.settled(value, range: range, step: step)
                dragStart = nil
                lastDetent = nil
                grip = 0
                Haptic.settle.play()
            }
    }

    /// A coarse detent gets a firmer tap than a fine one, so the tape has two
    /// felt resolutions rather than one undifferentiated buzz.
    private func tick(_ next: Double) {
        guard lastDetent != next else { return }
        lastDetent = next
        if let coarse = coarseStep,
           ValueDrumGeometry.isCoarse(next, coarseStep: coarse) {
            Haptic.threshold.play()
        } else {
            Haptic.pick.play()
        }
    }

    private func formatted(_ number: Double) -> String {
        number.formatted(.number.precision(.fractionLength(0...fractionDigits)))
    }
}
