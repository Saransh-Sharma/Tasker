import LifeBoardTokens
import LifeBoardUI
import SwiftUI

/// The Life Weave.
///
/// One object that the whole flow mutates, rather than a visual per screen: the
/// payoff is legible only if the user watches a single thing accumulate their
/// answers. It is deliberately **not** replaced between steps.
///
/// It carries no ambient motion. The hero video behind it is the screen's one
/// ambient timeline and `DESIGN.md` permits exactly one, so everything here is
/// boundary motion — it moves when the user changes something, then settles.
struct LifeWeaveCanvas: View {
    let presentation: LifeWeavePresentation

    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Bumped when the map gains something. Drives the one-shot light bloom.
    @State private var lightTrigger = 0

    private var reduceMotion: Bool { MotionOverride.resolve(systemReduceMotion) }
    private var isMirrored: Bool { layoutDirection == .rightToLeft }

    /// Labels are the first thing to go when type grows. Never the body copy
    /// below: the map yields to the question, not the other way round.
    private var showsAreaLabels: Bool { dynamicTypeSize <= .accessibility1 }

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            let now = LifeWeaveGeometry.now(in: size, isMirrored: isMirrored)

            ZStack {
                strandLayer(size: size)
                threadLayer(size: size, now: now)
                dayArc(size: size, now: now)

                LifeWeaveNowAnchor()
                    .position(now)

                ForEach(Array(presentation.areas.enumerated()), id: \.element.id) { index, area in
                    LifeWeaveAreaNode(area: area, showsLabel: showsAreaLabels)
                        .position(
                            LifeWeaveGeometry.areaCenter(
                                index: index,
                                count: presentation.areas.count,
                                isPrimary: area.isPrimary,
                                in: size,
                                isMirrored: isMirrored
                            )
                        )
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .scale(scale: 0.86).combined(with: .opacity)
                        )
                }
            }
            .lifeBoardMotion(.cardReflow, value: presentation.areas)
            .lifeBoardMotion(.contentInsertion, value: presentation.dayWindow)
            // `firstLight` is the sanctioned Metal for this surface: DESIGN.md
            // allows it for "the first daily commitment **and onboarding
            // arrival**", it is a `colorEffect` so nothing is rasterised
            // offscreen, and its `TimelineView` stops once settled — so it never
            // becomes a second ambient timeline competing with the hero video,
            // which owns the screen's entire ambient budget.
            //
            // `paperGrain` is deliberately *not* here. It is a `layerEffect`,
            // and SIGNATURE_EFFECT_DEPLOYMENT.md is explicit that it "sits
            // behind content, never over it". Applied over the weave it replaced
            // the subtree's rasterisation and swallowed the strands and the
            // anchor entirely — the map rendered blank in both appearances.
            // There is nothing for it to sit behind here anyway: the map is
            // transparent geometry over the hero video.
            .lifeboardFirstLight(trigger: lightTrigger, tint: bloomTint)
            .onChange(of: presentation.areas) { _, _ in lightTrigger &+= 1 }
            .onChange(of: presentation.phase) { _, _ in lightTrigger &+= 1 }
        }
        .frame(maxWidth: .infinity)
        // One semantic summary instead of a dozen decorative paths. The rows
        // below already publish every actionable state.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your Life Map")
        .accessibilityValue(presentation.accessibilitySummary)
    }

    /// The bloom takes the emphasised area's own colour when there is one, so the
    /// light that arrives is the light of the thing the user just chose.
    private var bloomTint: Color {
        guard let primary = presentation.areas.first(where: \.isPrimary) ?? presentation.areas.last
        else { return Color.lifeboard(.accentPrimary) }
        if let role = primary.accentRole { return Color.lifeboardArea(role) }
        return Color.lifeboard(.accentPrimary)
    }

    /// The five operating strands: structure, unlabelled until the reveal.
    ///
    /// Drawn in `textTertiary`, not `strokeHairline`. The hairline token is a
    /// *separator* — it is designed to sit on a surface, so in light appearance
    /// it is pale cream, which on the equally pale scrimmed sky rendered the
    /// whole weave invisible while dark appearance looked correct. An ink token
    /// carries contrast in both directions because it inverts with the scheme.
    private func strandLayer(size: CGSize) -> some View {
        Canvas { context, _ in
            for (index, strand) in presentation.strands.enumerated() {
                let path = Path(
                    LifeWeaveGeometry.strandPath(
                        index: index,
                        of: presentation.strands.count,
                        in: size,
                        isMirrored: isMirrored
                    )
                )
                context.stroke(
                    path,
                    with: .color(Color.lifeboard(.textTertiary).opacity(0.30 * strand.emphasis)),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                )
            }
        }
        // Fades out toward the edges so the strands read as passing through the
        // band rather than as lines drawn to the bezel.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.22),
                    .init(color: .black, location: 0.78),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .accessibilityHidden(true)
    }

    /// One thread per chosen area, tying it into the weave.
    private func threadLayer(size: CGSize, now: CGPoint) -> some View {
        Canvas { context, _ in
            for (index, area) in presentation.areas.enumerated() {
                let center = LifeWeaveGeometry.areaCenter(
                    index: index,
                    count: presentation.areas.count,
                    isPrimary: area.isPrimary,
                    in: size,
                    isMirrored: isMirrored
                )
                let path = Path(LifeWeaveGeometry.threadPath(from: center, to: now))
                context.stroke(
                    path,
                    with: .color(Color.lifeboard(.textTertiary).opacity(area.isPrimary ? 0.58 : 0.40)),
                    style: StrokeStyle(lineWidth: area.isPrimary ? 1.6 : 1.2, lineCap: .round)
                )
            }
        }
        .accessibilityHidden(true)
    }

    /// The day's available window, as atmosphere rather than a clock.
    ///
    /// Appears only once the user has answered the day-shape question, so it
    /// never shows a boundary they have not chosen.
    @ViewBuilder
    private func dayArc(size: CGSize, now: CGPoint) -> some View {
        if let window = presentation.dayWindow {
            let radius = min(size.width, size.height) * 0.44
            Circle()
                .trim(from: window.start, to: window.end)
                // Faint and thin: `accentPrimary` is cocoa, so at half opacity and
                // four points this read as a heavy dark gauge cutting across the
                // threads rather than as the atmospheric horizon it is meant to be.
                .stroke(
                    Color.lifeboard(.accentPrimary).opacity(0.26),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(90))
                .frame(width: radius * 2, height: radius * 2)
                .position(now)
                .accessibilityHidden(true)
        }
    }
}

/// The quiet origin. Unlabelled: it is the user's system, and naming it
/// "Daily Loop" before they have used the product explains internal vocabulary
/// to somebody with no way to interpret it.
private struct LifeWeaveNowAnchor: View {
    var body: some View {
        Circle()
            .fill(Color.lifeboard(.accentPrimary).opacity(0.9))
            .frame(width: 14, height: 14)
            .overlay(
                Circle()
                    .stroke(Color.lifeboard(.accentPrimary).opacity(0.22), lineWidth: 10)
            )
            .accessibilityHidden(true)
    }
}

/// One life area, woven on.
private struct LifeWeaveAreaNode: View {
    let area: LifeWeaveAreaPresentation
    let showsLabel: Bool

    private var accent: Color {
        if let role = area.accentRole {
            return Color.lifeboardArea(role)
        }
        // A user-created area keeps whatever colour they picked for it.
        return HexColor.color(area.fallbackColorHex, fallback: Color.lifeboard(.textPrimary))
    }

    private var accentWash: Color {
        if let role = area.accentRole {
            return Color.lifeboardAreaWash(role)
        }
        return accent.opacity(0.18)
    }

    var body: some View {
        VStack(spacing: 3) {
            Image(systemName: area.symbol)
                .lifeboardFont(.caption1)
                .foregroundStyle(accent)
                .frame(width: 22, height: 22)
                .background(accentWash, in: Circle())
            if showsLabel {
                    Text(area.title)
                    .lifeboardFont(.caption2)
                    .foregroundStyle(Color.lifeboard(.textPrimary))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: 92)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(minWidth: 56, maxWidth: 112)
        .lifeBoardClaySurface(area.isPrimary ? .raised : .resting, cornerRadius: 16)
        // Emphasis is a rim, not a size. See `LifeWeaveGeometry.primaryPullPoints`.
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(accent.opacity(area.isPrimary ? 0.85 : 0), lineWidth: 1.5)
        )
        .accessibilityHidden(true)
    }
}
