import SwiftUI

// MARK: - Option rail

/// A wrapping rail of clay chips for a small closed set.
///
/// Selection is carried by *depth* — chosen options sit on raised clay, the rest
/// are carved into the surface — so the state survives greyscale and
/// Differentiate Without Colour without the tint doing any work on its own.
///
/// This is not `LifeBoardLensPicker`, and the difference matters. The lens
/// picker is a view switcher: one travelling thumb, equal-weight segments, and a
/// `matchedGeometryEffect` id that is a global constant, so two of them on one
/// screen fight over the same thumb. It stays reserved for replacing
/// `.pickerStyle(.segmented)`. This is for choosing a *value*, where labels have
/// wildly different lengths and more than one rail per screen is normal.
public struct LifeBoardOptionRail<Value: Hashable>: View {
    private let label: String
    private let values: [Value]
    private let identifierPrefix: String
    private let title: (Value) -> String
    private let systemImage: ((Value) -> String)?
    private let detail: ((Value) -> String)?
    private let pressBloomTint: Color?
    private let showsLabel: Bool
    @Binding private var selection: Value

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var bloomTrigger = 0
    @State private var bloomCenter: UnitPoint = .center

    public init(
        _ label: String,
        selection: Binding<Value>,
        values: [Value],
        identifierPrefix: String,
        title: @escaping (Value) -> String,
        systemImage: ((Value) -> String)? = nil,
        detail: ((Value) -> String)? = nil,
        /// Set false when the enclosing section header already names this
        /// choice. Two headings for one control is the "repeated headings"
        /// failure DESIGN.md calls out, and it read as a bug on screen.
        showsLabel: Bool = true,
        pressBloomTint: Color? = nil
    ) {
        self.label = label
        self._selection = selection
        self.values = values
        self.identifierPrefix = identifierPrefix
        self.title = title
        self.systemImage = systemImage
        self.detail = detail
        self.showsLabel = showsLabel
        self.pressBloomTint = pressBloomTint
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if showsLabel {
                Text(label)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            rail
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifierPrefix)
        .modifier(LifeBoardOptionRailBloom(
            tint: pressBloomTint,
            center: bloomCenter,
            trigger: bloomTrigger
        ))
    }

    /// A grid at accessibility sizes rather than a horizontal scroll: long
    /// labels at AX5 make a scrolling rail a guessing game about how many
    /// options exist.
    @ViewBuilder
    private var rail: some View {
        if dynamicTypeSize.isAccessibilitySize {
            LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading)], spacing: 8) {
                ForEach(values, id: \.self) { chip($0) }
            }
        } else {
            LifeBoardOptionFlow(spacing: 8) {
                ForEach(values, id: \.self) { chip($0) }
            }
        }
    }

    private func chip(_ value: Value) -> some View {
        let isSelected = value == selection
        return Button {
            guard isSelected == false else { return }
            LifeBoardHaptic.pick.play()
            selection = value
            if pressBloomTint != nil { bloomTrigger &+= 1 }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    if let systemImage {
                        Image(systemName: systemImage(value))
                            .font(.lifeboard(.caption1))
                            .accessibilityHidden(true)
                    }
                    Text(title(value))
                        .font(.lifeboard(isSelected ? .bodyStrong : .body))
                }
                if let detail {
                    Text(detail(value))
                        .font(.lifeboard(.caption2))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                }
            }
            .foregroundStyle(
                Color(isSelected
                    ? LifeBoardColorTokens.inkPrimary
                    : LifeBoardColorTokens.inkSecondary)
            )
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .lifeBoardClaySurface(
                isSelected ? .raised : .well,
                cornerRadius: LifeBoardFoundationRadius.pill
            )
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .lifeBoardMotion(.selection, value: selection)
        .accessibilityIdentifier("\(identifierPrefix).\(chipIdentifier(value))")
        .accessibilityLabel(Text(title(value)))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }

    /// Enum-backed values expose a stable raw value; anything else falls back to
    /// its description. The tracker flow drives `track.tracker.kind.quantity`,
    /// so this composition has to match what `Picker` tags produced before.
    private func chipIdentifier(_ value: Value) -> String {
        if let raw = (value as? any RawRepresentable)?.rawValue as? String {
            return raw
        }
        return String(describing: value)
    }
}

/// Applies the press bloom only when a call site opted in.
///
/// Deliberately opt-in per rail. A bloom on every option in the app is exactly
/// the "animate every state change" failure DESIGN.md warns about; it belongs on
/// choices that carry weight — the kind of tracker you are creating, the mood
/// you are recording — and not on a unit toggle.
private struct LifeBoardOptionRailBloom: ViewModifier {
    let tint: Color?
    let center: UnitPoint
    let trigger: Int

    @ViewBuilder
    func body(content: Content) -> some View {
        if let tint {
            content.lifeboardClayPressBloom(center: center, trigger: trigger, tint: tint)
        } else {
            content
        }
    }
}

/// A flow layout that wraps chips onto new lines instead of scrolling them off
/// the edge. Chips whose labels vary from "Yes" to "Recurring meaningful event"
/// cannot share a fixed grid without either truncating or leaving half the row
/// empty.
struct LifeBoardOptionFlow: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var rowWidth: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0
        var widestRow: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if rowWidth > 0, rowWidth + spacing + size.width > maxWidth {
                totalHeight += rowHeight + spacing
                widestRow = max(widestRow, rowWidth)
                rowWidth = size.width
                rowHeight = size.height
            } else {
                rowWidth += rowWidth > 0 ? spacing + size.width : size.width
                rowHeight = max(rowHeight, size.height)
            }
        }
        widestRow = max(widestRow, rowWidth)
        totalHeight += rowHeight
        return CGSize(width: min(widestRow, maxWidth), height: totalHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        var x = bounds.minX
        var y = bounds.minY
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(
                at: CGPoint(x: x, y: y),
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}

// MARK: - Bead stepper

/// A bounded ordinal as a row of beads you can tap or sweep across.
///
/// This is what "Perceived rest: 3/5" and "Energy: 3/5" should always have been.
/// A `Stepper` makes a five-point scale into two arrow taps and a number, which
/// hides the one thing that matters: that this is a *scale*, and where the
/// current answer sits on it. Beads show the range and the answer in one glance,
/// and one continuous drag across them is faster than four taps.
public struct LifeBoardBeadStepper: View {
    private let label: String
    private let range: ClosedRange<Int>
    private let beadSymbol: String?
    private let caption: ((Int) -> String)?
    private let identifier: String?
    @Binding private var value: Int

    @State private var lastDetent: Int?

    public init(
        _ label: String,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        beadSymbol: String? = nil,
        caption: ((Int) -> String)? = nil,
        identifier: String? = nil
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.beadSymbol = beadSymbol
        self.caption = caption
        self.identifier = identifier
    }

    private var steps: [Int] { Array(range) }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                Spacer(minLength: 8)
                if let caption {
                    Text(caption(value))
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                }
            }
            GeometryReader { proxy in
                HStack(spacing: 6) {
                    ForEach(steps, id: \.self) { bead($0) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(sweep(width: proxy.size.width))
            }
            .frame(height: 52)
            .padding(.horizontal, 6)
            .lifeBoardClaySurface(.well, cornerRadius: LifeBoardFoundationRadius.pill)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(LifeBoardFieldIdentity(identifier: identifier))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(caption.map { "\($0(value)), \(value) of \(range.upperBound)" }
            ?? "\(value) of \(range.upperBound)"))
        .accessibilityAdjustableAction { direction in
            let next = direction == .increment ? value + 1 : value - 1
            guard range.contains(next) else { return }
            value = next
            LifeBoardHaptic.pick.play()
        }
    }

    private func bead(_ step: Int) -> some View {
        let filled = step <= value
        return ZStack {
            Circle()
                .fill(Color(filled
                    ? LifeBoardColorTokens.foundationApricotAccent
                    : LifeBoardColorTokens.foundationSurfaceSolid))
            if let beadSymbol {
                Image(systemName: beadSymbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(filled
                        ? LifeBoardColorTokens.foundationOnCelestialAccent
                        : LifeBoardColorTokens.inkTertiary))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .overlay {
            // Shape as well as fill: the current value gets a ring, so the
            // answer is legible with no colour at all.
            if step == value {
                Capsule()
                    .stroke(Color(LifeBoardColorTokens.inkPrimary), lineWidth: 2)
            }
        }
        .clipShape(Capsule())
        .lifeBoardMotion(.selection, value: value)
        .onTapGesture {
            guard step != value else { return }
            value = step
            LifeBoardHaptic.pick.play()
        }
    }

    /// One tick per detent crossed, never per touch sample — the same rule the
    /// arc dial follows. A haptic on every frame of a sweep is a buzz, not
    /// feedback.
    private func sweep(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard width > 0 else { return }
                let fraction = min(max(drag.location.x / width, 0), 1)
                let index = Int((fraction * CGFloat(steps.count - 1)).rounded())
                let next = steps[min(max(index, 0), steps.count - 1)]
                guard next != value else { return }
                value = next
                if lastDetent != next {
                    lastDetent = next
                    LifeBoardHaptic.pick.play()
                }
            }
            .onEnded { _ in lastDetent = nil }
    }
}

// MARK: - Composer dial

/// A bounded but wide value, set on an arc.
///
/// Wraps the existing `LifeBoardArcDial` with a backing plate and explicit −/+
/// buttons. The bare dial ships no visible control at all, and DESIGN.md
/// requires every gesture to have a button, a keyboard route and a VoiceOver
/// action; the dial supplied only the last of those.
public struct LifeBoardComposerDial: View {
    private let label: String
    private let range: ClosedRange<Double>
    private let step: Double
    private let unit: String?
    private let diameter: CGFloat
    private let format: (Double) -> String
    @Binding private var value: Double

    public init(
        _ label: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1,
        unit: String? = nil,
        diameter: CGFloat = 148,
        format: @escaping (Double) -> String = { String(Int($0.rounded())) }
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.diameter = diameter
        self.format = format
    }

    public var body: some View {
        VStack(spacing: 10) {
            LifeBoardArcDial(
                title: unit ?? label,
                value: $value,
                range: range,
                step: step,
                format: format
            )
            .frame(width: diameter, height: diameter)

            HStack(spacing: 12) {
                nudge(-step, systemImage: "minus", label: "Decrease \(label)")
                Text(label)
                    .font(.lifeboard(.meta))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
                nudge(step, systemImage: "plus", label: "Increase \(label)")
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private func nudge(_ delta: Double, systemImage: String, label: String) -> some View {
        Button {
            let next = min(max(value + delta, range.lowerBound), range.upperBound)
            guard next != value else { return }
            value = next
            LifeBoardHaptic.pick.play()
        } label: {
            Image(systemName: systemImage)
                .font(.lifeboard(.bodyStrong))
                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                .frame(width: 44, height: 44)
                .lifeBoardClaySurface(.well, cornerRadius: LifeBoardFoundationRadius.pill)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

// MARK: - Value drum geometry

/// Tape arithmetic for `LifeBoardValueDrum`, kept apart from the view.
///
/// Everything that can be wrong on a scrubbing tape is arithmetic: which way the
/// value runs relative to the finger, what happens past the ends, and whether a
/// detent fires once or on every touch sample. That is only catchable in
/// isolation, which is the same reason `LifeBoardArcDialGeometry` exists.
public enum LifeBoardValueDrumGeometry {
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
public struct LifeBoardValueDrum: View {
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
        VStack(spacing: 10) {
            readout
            tape
        }
        .frame(maxWidth: .infinity)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { isTyping = false }
            }
        }
    }

    private var readout: some View {
        VStack(spacing: 2) {
            TextField(
                keyboardPrompt,
                value: $value,
                format: .number.precision(.fractionLength(0...fractionDigits))
            )
            .font(LifeBoardFoundationTypography.hero())
            .monospacedDigit()
            .multilineTextAlignment(.center)
            .keyboardType(.decimalPad)
            .focused($isTyping)
            .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
            .frame(maxWidth: .infinity)
            .frame(minHeight: 52)
            .modifier(LifeBoardFieldIdentity(identifier: identifier))
            .accessibilityLabel(Text(label))

            Text(unit)
                .font(.lifeboard(.meta))
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
        }
    }

    private var tape: some View {
        GeometryReader { proxy in
            LifeBoardValueDrumTape(
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
            cornerRadius: LifeBoardFoundationRadius.compact + 2,
            style: .continuous
        ))
        .lifeBoardClaySurface(.well, cornerRadius: LifeBoardFoundationRadius.compact + 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(label) tape"))
        .accessibilityValue(Text("\(formatted(value)) \(unit)"))
        .accessibilityHint(Text("Swipe left or right to change the value"))
        .accessibilityAdjustableAction { direction in
            let delta = coarseStep ?? step
            let next = LifeBoardValueDrumGeometry.settled(
                value + (direction == .increment ? delta : -delta),
                range: range,
                step: step
            )
            guard next != value else { return }
            value = next
            LifeBoardHaptic.pick.play()
        }
    }

    /// Spans the tick band only. Running it the full height put the accent bar
    /// straight through the coarse tick's own label, so the number under the
    /// needle was the one number you could not read.
    private var centreIndicator: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(Color(LifeBoardColorTokens.foundationApricotAccent))
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
                    LifeBoardHaptic.lift.play()
                }
                guard let dragStart else { return }
                let next = LifeBoardValueDrumGeometry.value(
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
                value = LifeBoardValueDrumGeometry.settled(value, range: range, step: step)
                dragStart = nil
                lastDetent = nil
                grip = 0
                LifeBoardHaptic.settle.play()
            }
    }

    /// A coarse detent gets a firmer tap than a fine one, so the tape has two
    /// felt resolutions rather than one undifferentiated buzz.
    private func tick(_ next: Double) {
        guard lastDetent != next else { return }
        lastDetent = next
        if let coarse = coarseStep,
           LifeBoardValueDrumGeometry.isCoarse(next, coarseStep: coarse) {
            LifeBoardHaptic.threshold.play()
        } else {
            LifeBoardHaptic.pick.play()
        }
    }

    private func formatted(_ number: Double) -> String {
        number.formatted(.number.precision(.fractionLength(0...fractionDigits)))
    }
}

/// The tick track, drawn once per value change.
///
/// A `Canvas` rather than a stack of `Rectangle`s: a tape shows forty to sixty
/// ticks at a time and re-lays them out on every frame of a drag, which is
/// exactly the workload SwiftUI's layout engine is worst at and immediate-mode
/// drawing is best at.
private struct LifeBoardValueDrumTape: View {
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let coarseStep: Double
    let fractionDigits: Int

    var body: some View {
        Canvas { context, size in
            let ticks = LifeBoardValueDrumGeometry.visibleTicks(
                centeredOn: value,
                width: size.width,
                range: range,
                step: step
            )
            let midX = size.width / 2

            for tick in ticks {
                let x = midX + LifeBoardValueDrumGeometry.offset(
                    ofTick: tick, centeredOn: value, step: step
                )
                guard x >= -4, x <= size.width + 4 else { continue }

                let isCoarse = LifeBoardValueDrumGeometry.isCoarse(tick, coarseStep: coarseStep)
                let height: CGFloat = isCoarse ? 22 : 12
                // Ticks fade toward the rims so the tape reads as continuing
                // past the edge rather than being cut off.
                let falloff = 1 - min(1, abs(x - midX) / midX) * 0.65

                context.fill(
                    Path(CGRect(
                        x: x - 1,
                        y: size.height / 2 - height / 2,
                        width: 2,
                        height: height
                    )),
                    with: .color(
                        Color(isCoarse
                            ? LifeBoardColorTokens.inkSecondary
                            : LifeBoardColorTokens.inkTertiary)
                        .opacity(falloff)
                    )
                )

                if isCoarse {
                    let text = Text(tick.formatted(.number.precision(.fractionLength(0))))
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary).opacity(falloff))
                    context.draw(text, at: CGPoint(x: x, y: size.height / 2 + 22))
                }
            }
        }
        .drawingGroup(opaque: false)
        .accessibilityHidden(true)
    }
}
