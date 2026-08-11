import LifeBoardTokens
import SwiftUI

/// The lit edge of raised clay.
///
/// `ClaySurfaceModifier` already draws three tonal layers — an ambient shadow
/// below, an inner highlight across the top of the fill, and an inner contact
/// shade. What it lacked was an edge: the boundary itself was a single flat
/// hairline all the way round, so a card read as a tinted rectangle with soft
/// shading rather than as a solid object with a lit side.
///
/// This adds that edge. It is a stroke, not a fill, and it fades from the lit
/// quadrant to nothing by roughly the midpoint, which is what makes the form
/// read as curved. `DESIGN.md` calls it the quiet half of "claymorphic liquid
/// glass" — the half that appears on every card rather than once per screen.
///
/// It is deliberately static. Animating it would put a continuous timeline on
/// every surface in the product, which the ambient motion budget forbids
/// outright, and a moving highlight reads as a shimmer effect rather than as
/// material.
public struct SpecularRimModifier: ViewModifier {
    public let depth: ClayDepth
    public let cornerRadius: CGFloat
    /// Where the light is coming from, as a fraction of the day. Shifts the lit
    /// quadrant so a surface at dusk is not lit from the same side as one at
    /// nine in the morning.
    public let lightAngle: Angle

    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    public init(
        depth: ClayDepth,
        cornerRadius: CGFloat? = nil,
        lightAngle: Angle = .degrees(-60)
    ) {
        self.depth = depth
        self.cornerRadius = cornerRadius ?? depth.cornerRadius
        self.lightAngle = lightAngle
    }

    public func body(content: Content) -> some View {
        if isSuppressed {
            content
        } else {
            content.overlay(rim)
        }
    }

    /// Under Increase Contrast the semantic hairline takes over: boundary
    /// clarity outranks material character, and two competing edges on the same
    /// boundary is worse than either alone. Reduce Transparency flattens the
    /// surface entirely, so a rim would be lighting a form that is no longer
    /// there.
    ///
    /// Wells are excluded because they are *below* the canvas plane. A lit top
    /// edge on a carved surface inverts the read and makes the inset pop out.
    private var isSuppressed: Bool {
        contrast == .increased
            || reduceTransparency
            || VisualAppearanceFixture.active?.usesReducedTransparency == true
            || depth == .well
    }

    private var rim: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: rimColor.opacity(intensity), location: 0),
                        .init(color: rimColor.opacity(intensity * 0.45), location: 0.28),
                        .init(color: .clear, location: 0.62)
                    ],
                    startPoint: start,
                    endPoint: end
                ),
                lineWidth: 1
            )
            .blendMode(.plusLighter)
            .allowsHitTesting(false)
    }

    private var rimColor: Color { Color(SemanticColorTokens.claySpecularRim) }

    /// Floating sits highest and catches the most light; resting barely lifts
    /// off the canvas and gets a correspondingly faint edge.
    private var intensity: Double {
        switch depth {
        case .well: return 0
        case .resting: return 0.55
        case .raised: return 0.85
        case .floating: return 1
        }
    }

    private var start: UnitPoint {
        UnitPoint(
            x: 0.5 + 0.5 * cos(lightAngle.radians),
            y: 0.5 + 0.5 * sin(lightAngle.radians)
        )
    }

    private var end: UnitPoint {
        UnitPoint(x: 1 - start.x, y: 1 - start.y)
    }
}

public extension View {
    /// The lit edge of raised clay.
    ///
    /// Applied automatically by `lifeBoardClaySurface`, so call this directly
    /// only when a surface builds its own background and still wants the edge —
    /// the hero surface's glass presentation is the motivating case.
    func lifeBoardSpecularRim(
        _ depth: ClayDepth,
        cornerRadius: CGFloat? = nil,
        lightAngle: Angle = .degrees(-60)
    ) -> some View {
        modifier(
            SpecularRimModifier(
                depth: depth,
                cornerRadius: cornerRadius,
                lightAngle: lightAngle
            )
        )
    }
}
