import SwiftUI

/// Lane and stop arithmetic for the atmosphere slider.
///
/// Kept apart from the view for the same reason `ArcDialGeometry` is:
/// everything that can be wrong here is arithmetic. The stops are deliberately
/// *not* evenly spaced — Auto is a mode rather than a time of day, so it gets
/// its own wider lane at the leading end — which is exactly why the arc dial's
/// even-detent math cannot be reused. Off-by-one lane widths are invisible on
/// screen and obvious in a test.
///
/// Coordinates are in the track's inner space (the capsule minus its inset),
/// measured from the leading edge. `isRTL` mirrors at the two — and only two —
/// places it matters: reading a touch, and placing the knob.
public enum AtmosphereSliderGeometry {
    /// Width of the Auto lane. Wider than a daypart lane on purpose: the width
    /// difference is one of the three non-colour cues separating Auto from the
    /// day.
    public static let autoLaneWidth: CGFloat = 52
    /// Gap between the Auto lane and the day lane, holding the hairline rule.
    public static let separatorWidth: CGFloat = 10
    /// Below this the day lane cannot give four stops a 44pt target, and the
    /// caller should fall back to the row list.
    public static let minimumInnerWidth: CGFloat = 238

    public static let stopCount = 5

    /// Width available to the four dayparts.
    public static func dayLaneWidth(innerWidth: CGFloat) -> CGFloat {
        max(0, innerWidth - autoLaneWidth - separatorWidth)
    }

    /// Where the day lane starts.
    public static func dayLaneOrigin() -> CGFloat {
        autoLaneWidth + separatorWidth
    }

    /// Stop centres in layout order — Auto first, then the four dayparts, each
    /// centred in its quarter of the day lane.
    public static func stopCenters(innerWidth: CGFloat) -> [CGFloat] {
        let day: CGFloat = dayLaneWidth(innerWidth: innerWidth)
        let origin: CGFloat = dayLaneOrigin()
        let quarter: CGFloat = day / 4
        var centers: [CGFloat] = [autoLaneWidth / 2]
        for index in 0..<4 {
            let laneStart: CGFloat = origin + quarter * CGFloat(index)
            centers.append(laneStart + quarter / 2)
        }
        return centers
    }

    /// Visual x for a stop, mirrored under right-to-left layout.
    public static func x(forIndex index: Int, innerWidth: CGFloat, isRTL: Bool) -> CGFloat {
        let centers = stopCenters(innerWidth: innerWidth)
        let clamped = min(max(index, 0), centers.count - 1)
        let x = centers[clamped]
        return isRTL ? innerWidth - x : x
    }

    /// Nearest stop to a touch. Distance, not lane containment: a finger that
    /// lands in the separator gap belongs to whichever side it is closer to
    /// rather than to nothing.
    public static func index(atX x: CGFloat, innerWidth: CGFloat, isRTL: Bool) -> Int {
        guard innerWidth > 0 else { return 0 }
        let clamped = min(max(x, 0), innerWidth)
        let logical = isRTL ? innerWidth - clamped : clamped
        let centers = stopCenters(innerWidth: innerWidth)
        var best = 0
        var bestDistance = CGFloat.greatestFiniteMagnitude
        for (index, center) in centers.enumerated() {
            let distance = abs(logical - center)
            if distance < bestDistance {
                bestDistance = distance
                best = index
            }
        }
        return best
    }

    /// Gradient stop positions inside the day lane, so each daypart's colour
    /// peaks on its own detent instead of halfway between two.
    public static func dayGradientLocations(innerWidth: CGFloat) -> [CGFloat] {
        let day = dayLaneWidth(innerWidth: innerWidth)
        guard day > 0 else { return [0, 0.25, 0.75, 1] }
        let origin = dayLaneOrigin()
        return stopCenters(innerWidth: innerWidth).dropFirst().map { center in
            min(max((center - origin) / day, 0), 1)
        }
    }
}

/// The day, as one thing you drag across.
///
/// Replaces a nested `Picker` in a menu, which made the four dayparts feel like
/// unrelated list items and hid the fact that they are a sequence. Here the
/// track *is* the day: the fill runs morning-gold through night-indigo, and the
/// knob carries the selected symbol along it.
///
/// Auto leads the track but is fenced off from the day by a hairline, a
/// recessed fill instead of the gradient, and a wider lane — three cues, none of
/// them colour, because Differentiate Without Colour has to hold for the one
/// stop whose meaning is not a time.
public struct AtmosphereSlider: View {
    private let title: String
    @Binding private var selection: DaypartSelection
    private let resolvedDaypart: ResolvedDaypart
    private let activeOverride: DaypartOverride?
    private let onDragStateChange: (Bool) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var colorSchemeContrast
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.scenePhase) private var scenePhase
    @State private var lastHapticIndex: Int?

    /// - Parameters:
    ///   - resolvedDaypart: what Auto currently resolves to. Passed in rather
    ///     than read from preferences, because `resolvedDaypart(at:)` *mutates*
    ///     — it lapses expired overrides and writes to UserDefaults — and this
    ///     view's body runs on every frame of a drag.
    ///   - activeOverride: supplies the expiry shown in the readout. A manual
    ///     daypart lapses at the next natural boundary, and a control that says
    ///     nothing about that looks broken when the canvas reverts on its own.
    ///   - onDragStateChange: lets the host suppress per-daypart effects while
    ///     the finger is down. A drag from Auto to Night crosses four dayparts
    ///     in a few hundred milliseconds.
    public init(
        title: String = "Atmosphere",
        selection: Binding<DaypartSelection>,
        resolvedDaypart: ResolvedDaypart,
        activeOverride: DaypartOverride? = nil,
        onDragStateChange: @escaping (Bool) -> Void = { _ in }
    ) {
        self.title = title
        self._selection = selection
        self.resolvedDaypart = resolvedDaypart
        self.activeOverride = activeOverride
        self.onDragStateChange = onDragStateChange
    }

    private static let stops = DaypartSelection.allCases

    private var selectedIndex: Int {
        Self.stops.firstIndex(of: selection) ?? 0
    }

    private var isRTL: Bool { layoutDirection == .rightToLeft }

    /// Track inset, and therefore the knob's margin inside the groove.
    private let inset: CGFloat = 6
    private let trackHeight: CGFloat = 56
    private var knobSide: CGFloat { trackHeight - inset * 2 }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // A slider cannot answer large type the way `LensPicker`
            // does. That control scrolls instead of truncating, but here the
            // drag axis *is* the value axis, so scrolling it would fight the
            // gesture. Precise horizontal dragging is also the interaction
            // least available to someone who has turned accessibility sizes on.
            if dynamicTypeSize.isAccessibilitySize {
                rowList
            } else {
                track
            }
            readout
        }
        .accessibilityElement(children: dynamicTypeSize.isAccessibilitySize ? .contain : .ignore)
        .accessibilityLabel(Text(title))
        .accessibilityValue(Text(readoutAccessibilityValue))
        .accessibilityIdentifier("foundation.atmosphere.slider")
        .modifier(
            AdjustableSelection(
                isEnabled: dynamicTypeSize.isAccessibilitySize == false,
                index: selectedIndex,
                onChange: { commit(index: $0, playsHaptic: false) }
            )
        )
    }

    // MARK: Track

    private var track: some View {
        GeometryReader { proxy in
            let innerWidth = max(0, proxy.size.width - inset * 2)
            ZStack(alignment: .leading) {
                dayGradient(innerWidth: innerWidth)
                autoLane(innerWidth: innerWidth)
                separator(innerWidth: innerWidth)
                stopGlyphs(innerWidth: innerWidth)
                knob(innerWidth: innerWidth)
            }
            // Size the content to the *inner* width and then pad, not the
            // reverse: padding a full-width ZStack makes the content 12pt wider
            // than the groove, and the night end of the gradient spills past
            // the capsule's right edge.
            .frame(width: innerWidth, height: knobSide, alignment: .leading)
            .padding(inset)
            .contentShape(Capsule())
            .gesture(dragGesture(innerWidth: innerWidth))
        }
        .frame(height: trackHeight)
        .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
    }

    private func dragGesture(innerWidth: CGFloat) -> some Gesture {
        // `minimumDistance: 0` so a tap anywhere on the track selects the
        // nearest stop — the control should not require a drag to be usable.
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                onDragStateChange(true)
                let index = AtmosphereSliderGeometry.index(
                    atX: value.location.x - inset,
                    innerWidth: innerWidth,
                    isRTL: isRTL
                )
                commit(index: index, playsHaptic: true)
            }
            .onEnded { _ in
                lastHapticIndex = nil
                onDragStateChange(false)
            }
    }

    /// Writes only when the stop changes. Each write re-encodes and persists an
    /// override envelope, so a per-sample write would hit UserDefaults dozens of
    /// times per drag.
    private func commit(index: Int, playsHaptic: Bool) {
        let clamped = min(max(index, 0), Self.stops.count - 1)
        let next = Self.stops[clamped]
        guard next != selection else { return }
        selection = next
        guard playsHaptic, lastHapticIndex != clamped else { return }
        lastHapticIndex = clamped
        Haptic.pick.play(policy: motionPolicy)
    }

    private func dayGradient(innerWidth: CGFloat) -> some View {
        let locations = AtmosphereSliderGeometry.dayGradientLocations(innerWidth: innerWidth)
        let colors = ResolvedDaypart.allCases.map { daypartTint($0) }
        return Capsule()
            .fill(
                LinearGradient(
                    stops: zip(colors, locations).map { Gradient.Stop(color: $0, location: $1) },
                    startPoint: isRTL ? .trailing : .leading,
                    endPoint: isRTL ? .leading : .trailing
                )
            )
            .frame(width: AtmosphereSliderGeometry.dayLaneWidth(innerWidth: innerWidth))
            .offset(x: laneOffset(
                AtmosphereSliderGeometry.dayLaneOrigin(),
                width: AtmosphereSliderGeometry.dayLaneWidth(innerWidth: innerWidth),
                innerWidth: innerWidth
            ))
    }

    /// Colour is the *third* cue, so it can be quieted without the control
    /// losing meaning.
    private var tintOpacity: Double {
        reduceTransparency || colorSchemeContrast == .increased ? 0.35 : 0.55
    }

    /// The *art* palette, not `appearancePalette`.
    ///
    /// `appearancePalette` deliberately gives Night a cream canvas in Light
    /// appearance so text stays legible on the real backdrop. That is right for
    /// a screen and wrong for this track, where the point is that the far end
    /// looks like night — through it, Night rendered as the palest stop of the
    /// five.
    private func artPalette(_ daypart: ResolvedDaypart) -> DaypartPalette {
        colorScheme == .dark
            ? DaypartTokens.darkPalette(for: daypart)
            : DaypartTokens.palette(for: daypart)
    }

    private func daypartTint(_ daypart: ResolvedDaypart) -> Color {
        // Night reads by its canvas, not its celestial body: a moon-silver
        // gradient stop would make the darkest part of the day the brightest
        // part of the track.
        let role: DaypartColorRole = daypart == .night ? .canvas : .celestialPrimary
        return artPalette(daypart).color(for: role).opacity(tintOpacity)
    }

    private func autoLane(innerWidth: CGFloat) -> some View {
        Capsule()
            .fill(Color(LifeBoardColorTokens.foundationSurfaceRecessed).opacity(0.6))
            .frame(width: AtmosphereSliderGeometry.autoLaneWidth)
            .offset(x: laneOffset(
                0,
                width: AtmosphereSliderGeometry.autoLaneWidth,
                innerWidth: innerWidth
            ))
    }

    private func separator(innerWidth: CGFloat) -> some View {
        let origin = AtmosphereSliderGeometry.autoLaneWidth
            + AtmosphereSliderGeometry.separatorWidth / 2
        return Rectangle()
            .fill(Color(LifeBoardColorTokens.foundationHairline))
            .frame(width: 1, height: knobSide - 16)
            .offset(x: laneOffset(origin, width: 1, innerWidth: innerWidth))
    }

    /// Converts a logical leading offset into a visual one, mirroring for RTL.
    private func laneOffset(_ leading: CGFloat, width: CGFloat, innerWidth: CGFloat) -> CGFloat {
        isRTL ? innerWidth - leading - width : leading
    }

    private func stopGlyphs(innerWidth: CGFloat) -> some View {
        ForEach(Array(Self.stops.enumerated()), id: \.element) { index, stop in
            Image(systemName: stop.systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(glyphInk(for: stop).opacity(0.5))
                .frame(width: 24, height: 24)
                .offset(
                    x: AtmosphereSliderGeometry.x(
                        forIndex: index, innerWidth: innerWidth, isRTL: isRTL
                    ) - 12
                )
                // The knob carries the selected glyph; two copies of the same
                // symbol at the same place reads as a rendering fault.
                .opacity(index == selectedIndex ? 0 : 1)
        }
    }

    /// Ink follows the tint the glyph actually sits on, not the app appearance.
    /// The night stop is dark even in Light appearance.
    private func glyphInk(for stop: DaypartSelection) -> Color {
        guard let daypart = ResolvedDaypart(rawValue: stop.rawValue) else {
            return Color(LifeBoardColorTokens.inkSecondary)
        }
        return artPalette(daypart).isNocturnal
            ? Color(LifeBoardColorTokens.foundationOnScenicDark)
            : Color(LifeBoardColorTokens.inkSecondary)
    }

    private func knob(innerWidth: CGFloat) -> some View {
        let x = AtmosphereSliderGeometry.x(
            forIndex: selectedIndex, innerWidth: innerWidth, isRTL: isRTL
        )
        return Circle()
            .fill(Color(LifeBoardColorTokens.foundationSurfaceSolid))
            .overlay {
                Image(systemName: selection.systemImage)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
            }
            .frame(width: knobSide, height: knobSide)
            .lifeBoardClaySurface(.raised, cornerRadius: knobSide / 2)
            .offset(x: x - knobSide / 2)
            // A plain offset, not `matchedGeometryEffect`: five discrete
            // anchors and one continuous drag pull the effect in opposite
            // directions, and the knob visibly stutters.
            .animation(reduceMotion ? nil : LifeBoardAnimation.directManipulation, value: selectedIndex)
            .animation(reduceMotion ? nil : LifeBoardAnimation.directManipulation, value: innerWidth)
    }

    // MARK: Accessibility-size variant

    private var rowList: some View {
        VStack(spacing: 0) {
            ForEach(Array(Self.stops.enumerated()), id: \.element) { index, stop in
                Button {
                    commit(index: index, playsHaptic: true)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: stop.systemImage)
                            // `minWidth`, not a fixed width: these symbols scale
                            // with Dynamic Type, and a hard 24pt frame let the
                            // glyph grow straight through the title beside it.
                            .frame(minWidth: 24)
                        Text(stop.title)
                            .font(.lifeboard(index == selectedIndex ? .bodyStrong : .body))
                        Spacer(minLength: 8)
                        if index == selectedIndex {
                            Image(systemName: "checkmark")
                        }
                    }
                    .foregroundStyle(
                        Color(
                            index == selectedIndex
                                ? LifeBoardColorTokens.inkPrimary
                                : LifeBoardColorTokens.inkSecondary
                        )
                    )
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("foundation.atmosphere.stop.\(stop.rawValue)")
                .accessibilityAddTraits(index == selectedIndex ? [.isButton, .isSelected] : .isButton)
            }
        }
        .padding(.vertical, 4)
        .lifeBoardClaySurface(.well, cornerRadius: Radius.card)
    }

    // MARK: Readout

    private var readout: some View {
        (
            Text(selection.title)
                .font(.lifeboard(.bodyStrong))
                .foregroundColor(Color(LifeBoardColorTokens.inkPrimary))
                + Text(readoutSuffix)
                .font(.lifeboard(.caption1))
                .foregroundColor(Color(LifeBoardColorTokens.inkSecondary))
        )
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityHidden(true)
    }

    private var readoutSuffix: String {
        if selection == .automatic {
            return " · following \(resolvedDaypart.rawValue.capitalized)"
        }
        guard let expiresAt = activeOverride?.expiresAt else { return "" }
        return " · until \(Self.expiryFormatter.string(from: expiresAt))"
    }

    private var readoutAccessibilityValue: String {
        selection.title + readoutSuffix
    }

    private static let expiryFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter
    }()

    private var motionPolicy: MotionPolicy {
        MotionPolicy.resolve(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        )
    }
}

/// VoiceOver's adjust gesture, applied only to the slider form.
///
/// The row-list variant is five real buttons, and an adjustable action on their
/// container would give VoiceOver two contradictory ways to change one value.
private struct AdjustableSelection: ViewModifier {
    let isEnabled: Bool
    let index: Int
    let onChange: (Int) -> Void

    func body(content: Content) -> some View {
        if isEnabled {
            content.accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onChange(index + 1)
                case .decrement: onChange(index - 1)
                @unknown default: break
                }
            }
        } else {
            content
        }
    }
}
