import SwiftUI

// MARK: - Option rail

/// A wrapping rail of clay chips for a small closed set.
///
/// Selection is carried by *depth* — chosen options sit on raised clay, the rest
/// are carved into the surface — so the state survives greyscale and
/// Differentiate Without Colour without the tint doing any work on its own.
///
/// This is not `LensPicker`, and the difference matters. The lens
/// picker is a view switcher: one travelling thumb, equal-weight segments, and a
/// `matchedGeometryEffect` id that is a global constant, so two of them on one
/// screen fight over the same thumb. It stays reserved for replacing
/// `.pickerStyle(.segmented)`. This is for choosing a *value*, where labels have
/// wildly different lengths and more than one rail per screen is normal.
public struct OptionRail<Value: Hashable>: View {
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
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            rail
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifierPrefix)
        .modifier(OptionRailBloom(
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
            OptionFlow(spacing: 8) {
                ForEach(values, id: \.self) { chip($0) }
            }
        }
    }

    private func chip(_ value: Value) -> some View {
        let isSelected = value == selection
        return Button {
            guard isSelected == false else { return }
            Haptic.pick.play()
            selection = value
            if pressBloomTint != nil { bloomTrigger &+= 1 }
        } label: {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 8) {
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
                        .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                }
            }
            .foregroundStyle(
                Color(isSelected
                    ? SemanticColorTokens.inkPrimary
                    : SemanticColorTokens.inkSecondary)
            )
            .lineLimit(2)
            .multilineTextAlignment(.leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .frame(minHeight: 44)
            .lifeBoardClaySurface(
                isSelected ? .raised : .well,
                cornerRadius: Radius.pill
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
private struct OptionRailBloom: ViewModifier {
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
struct OptionFlow: Layout {
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
public struct BeadStepper: View {
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
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                Spacer(minLength: 8)
                if let caption {
                    Text(caption(value))
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                }
            }
            GeometryReader { proxy in
                HStack(spacing: 8) {
                    ForEach(steps, id: \.self) { bead($0) }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
                .gesture(sweep(width: proxy.size.width))
            }
            .frame(height: 52)
            .padding(.horizontal, 8)
            .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modifier(FieldIdentity(identifier: identifier))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label))
        .accessibilityValue(Text(caption.map { "\($0(value)), \(value) of \(range.upperBound)" }
            ?? "\(value) of \(range.upperBound)"))
        .accessibilityAdjustableAction { direction in
            let next = direction == .increment ? value + 1 : value - 1
            guard range.contains(next) else { return }
            value = next
            Haptic.pick.play()
        }
    }

    private func bead(_ step: Int) -> some View {
        let filled = step <= value
        return ZStack {
            Circle()
                .fill(Color(filled
                    ? SemanticColorTokens.foundationApricotAccent
                    : SemanticColorTokens.foundationSurfaceSolid))
            if let beadSymbol {
                Image(systemName: beadSymbol)
                    .font(.footnote.weight(.semibold))
                    .dynamicTypeSize(...DynamicTypeSize.xxLarge)
                    .foregroundStyle(Color(filled
                        ? SemanticColorTokens.foundationOnCelestialAccent
                        : SemanticColorTokens.inkTertiary))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 38)
        .overlay {
            // Shape as well as fill: the current value gets a ring, so the
            // answer is legible with no colour at all.
            if step == value {
                Capsule()
                    .stroke(Color(SemanticColorTokens.inkPrimary), lineWidth: 2)
            }
        }
        .clipShape(Capsule())
        .lifeBoardMotion(.selection, value: value)
        .onTapGesture {
            guard step != value else { return }
            value = step
            Haptic.pick.play()
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
                    Haptic.pick.play()
                }
            }
            .onEnded { _ in lastDetent = nil }
    }
}

// MARK: - Composer dial

/// A bounded but wide value, set on an arc.
///
/// Wraps the existing `ArcDial` with a backing plate and explicit −/+
/// buttons. The bare dial ships no visible control at all, and DESIGN.md
/// requires every gesture to have a button, a keyboard route and a VoiceOver
/// action; the dial supplied only the last of those.
public struct ComposerDial: View {
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
        VStack(spacing: 12) {
            ArcDial(
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
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
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
            Haptic.pick.play()
        } label: {
            Image(systemName: systemImage)
                .font(.lifeboard(.bodyStrong))
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .frame(width: 44, height: 44)
                .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}

/// The tick track, drawn once per value change.
///
/// A `Canvas` rather than a stack of `Rectangle`s: a tape shows forty to sixty
/// ticks at a time and re-lays them out on every frame of a drag, which is
/// exactly the workload SwiftUI's layout engine is worst at and immediate-mode
/// drawing is best at.
struct ValueDrumTape: View {
    let value: Double
    let range: ClosedRange<Double>
    let step: Double
    let coarseStep: Double
    let fractionDigits: Int

    /// 10pt at the default size, scaling with Dynamic Type but capped where
    /// neighbouring coarse labels would start to collide on the tape.
    @ScaledMetric(relativeTo: .caption2) private var scaledTickLabelSize: CGFloat = 10
    private var tickLabelSize: CGFloat { min(scaledTickLabelSize, 14) }

    var body: some View {
        Canvas { context, size in
            let ticks = ValueDrumGeometry.visibleTicks(
                centeredOn: value,
                width: size.width,
                range: range,
                step: step
            )
            let midX = size.width / 2

            for tick in ticks {
                let x = midX + ValueDrumGeometry.offset(
                    ofTick: tick, centeredOn: value, step: step
                )
                guard x >= -4, x <= size.width + 4 else { continue }

                let isCoarse = ValueDrumGeometry.isCoarse(tick, coarseStep: coarseStep)
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
                            ? SemanticColorTokens.inkSecondary
                            : SemanticColorTokens.inkTertiary)
                        .opacity(falloff)
                    )
                )

                if isCoarse {
                    let text = Text(tick.formatted(.number.precision(.fractionLength(0))))
                        .font(.system(size: tickLabelSize, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(SemanticColorTokens.inkTertiary).opacity(falloff))
                    context.draw(text, at: CGPoint(x: x, y: size.height / 2 + 22))
                }
            }
        }
        .drawingGroup(opaque: false)
        .accessibilityHidden(true)
    }
}
