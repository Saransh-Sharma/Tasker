import SwiftUI

/// The house lens control — one row of mutually exclusive views.
///
/// Replaces `.pickerStyle(.segmented)`, which this app cannot legitimately use:
/// the system segmented control is **32 pt tall**, so every lens row in the
/// product was a touch-target violation, and it truncates its labels to "…"
/// rather than reflowing when type gets large. DESIGN.md requires lens controls
/// to scroll instead of shrink, and forbids shrinking type to preserve a grid.
///
/// Selection is carried by shape *and* weight *and* the `.isSelected` trait,
/// never by colour alone — Differentiate Without Colour has to hold here, since
/// this control is the only thing telling you which view you are looking at.
///
/// Geometry comes entirely from `LifeBoardClaySurface`: a `.well` track with a
/// `.raised` thumb. Nothing here invents its own depth.
struct LensPicker<Value: Hashable & Identifiable>: View {
    private let label: String
    @Binding private var selection: Value
    private let values: [Value]
    private let identifierPrefix: String
    private let title: (Value) -> String
    private let identifier: (Value) -> String
    private let isEnabled: (Value) -> Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Namespace private var thumb
    @State private var refractionStrength: Double = 0

    /// - Parameters:
    ///   - label: the VoiceOver group name, e.g. "Plan lens".
    ///   - identifierPrefix: composed with `identifier(value)` into a per-value
    ///     accessibility id. Only Track had these before; UI tests could not
    ///     name an individual Plan or Insights lens at all.
    ///   - isEnabled: a lens the current context cannot offer. It stays visible
    ///     and legible rather than disappearing — a control whose options move
    ///     around is harder to trust than one where some are unavailable.
    init(
        _ label: String,
        selection: Binding<Value>,
        values: [Value],
        identifierPrefix: String,
        title: @escaping (Value) -> String,
        identifier: @escaping (Value) -> String,
        isEnabled: @escaping (Value) -> Bool = { _ in true }
    ) {
        self.label = label
        self._selection = selection
        self.values = values
        self.identifierPrefix = identifierPrefix
        self.title = title
        self.identifier = identifier
        self.isEnabled = isEnabled
    }

    /// 44 pt is the floor, not the target: the row grows with Dynamic Type.
    private let minimumHeight: CGFloat = 44

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                // Scroll rather than truncate. At AX sizes four lens titles
                // cannot share one screen width, and the system control's
                // answer — "…" on every segment — leaves the person unable to
                // tell the lenses apart at exactly the sizes they most need to.
                ScrollView(.horizontal) {
                    track
                }
                .scrollIndicators(.hidden)
            } else {
                track
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text(label))
        .accessibilityIdentifier(identifierPrefix)
    }

    private var track: some View {
        HStack(spacing: 4) {
            ForEach(values) { value in
                segment(value)
            }
        }
        .padding(4)
        .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
        // DESIGN.md names the lens explicitly as a `liquidGlassRefract` surface.
        // It lives here rather than at the call sites so the effect can never be
        // applied to something that is not a lens, and so all four roots get it
        // from one place. `strength` returns to 0 the moment the thumb settles,
        // and the modifier early-returns below 0.001 — there is no idle shader.
        .lifeboardLiquidGlassRefract(
            center: thumbCenter,
            radius: 0.42,
            strength: refractionStrength
        )
        .onChange(of: selection) { _, _ in
            guard reduceMotion == false else { return }
            refractionStrength = 1
            withAnimation(MotionProfile.controlMorph.animation(reduceMotion: reduceMotion)) {
                refractionStrength = 0
            }
        }
    }

    /// Where the selected thumb currently sits, in unit space, so the lens
    /// refracts around the segment the finger actually chose.
    private var thumbCenter: UnitPoint {
        guard values.count > 1,
              let index = values.firstIndex(where: { $0 == selection }) else {
            return .center
        }
        let fraction = (Double(index) + 0.5) / Double(values.count)
        return UnitPoint(x: fraction, y: 0.5)
    }

    @ViewBuilder
    private func segment(_ value: Value) -> some View {
        let selected = value == selection
        let enabled = isEnabled(value)

        Button {
            guard enabled, selected == false else { return }
            Haptic.pick.play()
            selection = value
        } label: {
            Text(title(value))
                // Weight carries selection alongside the thumb, so the state
                // survives Differentiate Without Colour and a greyscale screen.
                .font(.lifeboard(selected ? .bodyStrong : .body))
                .foregroundStyle(
                    Color(selected ? LifeBoardColorTokens.inkPrimary : LifeBoardColorTokens.inkSecondary)
                )
                .lineLimit(1)
                .frame(maxWidth: .infinity)
                .frame(minHeight: minimumHeight)
                .background {
                    if selected {
                        Capsule()
                            .fill(Color(LifeBoardColorTokens.foundationSurfaceSelected))
                            .matchedGeometryEffect(id: "lifeboard.lens.thumb", in: thumb)
                    }
                }
                // The whole slot is tappable, not just the glyph run.
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(enabled == false)
        .opacity(enabled ? 1 : 0.45)
        .lifeBoardMotion(.selection, value: selection)
        .accessibilityIdentifier("\(identifierPrefix).\(identifier(value))")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}
