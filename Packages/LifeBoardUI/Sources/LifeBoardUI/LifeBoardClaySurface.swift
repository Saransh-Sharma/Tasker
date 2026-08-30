import SwiftUI
import UIKit
import LifeBoardTokens
// MARK: - Clay depth scale

/// The canonical depth scale for LifeBoard content surfaces.
///
/// Every clay surface in the app resolves through this one type. Before it
/// existed there were six near-duplicate card modifiers whose shadow radii
/// (4, 6, 8, 9, 18) and stroke widths (0.5, 0.75, 1, 1.5) had drifted apart,
/// so "raised" meant something different on each screen.
///
/// Real claymorphism needs three coordinated layers, not just a drop shadow:
/// a warm ambient shadow *below* the surface, a light rim on the *inside top*
/// edge where the light lands, and a soft shade on the inside bottom edge that
/// gives the form its puffiness. `well` inverts the two inner layers so a
/// recessed surface reads as genuinely carved into the paper rather than
/// merely tinted darker.
public enum ClayDepth: String, CaseIterable, Sendable {
    /// Carved into the canvas: inputs, segmented tracks, metric wells.
    case well
    /// Barely lifted: list rows and grouped reading surfaces.
    case resting
    /// The standard content card.
    case raised
    /// One hero per screen, plus transient overlays.
    case floating

    /// `DESIGN.md`'s shape vocabulary: 14 fields, 16 rows, 20 raised decisions,
    /// 24 hero.
    ///
    /// `raised` was 18 — a value the contract does not contain, and only two
    /// points from `resting`, which is not a difference anyone can see. It is
    /// now the contract's 20.
    ///
    /// `floating` was 24 and has come down to the same 20. Twenty-four is the
    /// hero radius, and `DESIGN.md` calls it "the continuity" between the card
    /// that represents a surface, the hero it opens into, and the opaque
    /// fallback that replaces it. A continuity only works if it is exclusive,
    /// so no content plane may share it. Floating now separates from raised by
    /// its shadow and its lit edge, which is what actually distinguishes height
    /// in this material.
    public var cornerRadius: CGFloat {
        switch self {
        case .well: return 14
        case .resting: return 16
        case .raised: return 20
        case .floating: return 20
        }
    }

    /// The body tone for this plane.
    ///
    /// `well` is carved below the canvas. `resting` and `raised` share the clay
    /// body tone — they are the same material at different heights, and in a
    /// physical model height changes the light and the shadow, not the pigment.
    /// `floating` alone lifts to `surfaceRaised`, because it is near enough the
    /// light source to catch more of it.
    var fillToken: UIColor {
        switch self {
        case .well: return SemanticColorTokens.foundationSurfaceRecessed
        case .resting, .raised: return SemanticColorTokens.foundationSurfaceSolid
        case .floating: return SemanticColorTokens.foundationSurfaceRaised
        }
    }

    /// Ambient occlusion under the surface. `well` casts none — it is below
    /// the canvas plane, not above it.
    var dropShadow: (radius: CGFloat, y: CGFloat, opacity: CGFloat)? {
        switch self {
        case .well: return nil
        case .resting: return (radius: 4, y: 1, opacity: 0.5)
        case .raised: return (radius: 10, y: 5, opacity: 1.0)
        // Deepened from (20, 10, 1.35). Floating used to be four points rounder
        // than raised as well as taller; now that it shares the 20pt radius so
        // the hero can own 24, the shadow carries the whole height difference.
        case .floating: return (radius: 26, y: 13, opacity: 1.5)
        }
    }

    /// Light rim. Positive `y` pushes the inner shadow down from the top edge,
    /// which is what reads as a lit upper lip.
    var innerHighlight: (radius: CGFloat, y: CGFloat, opacity: CGFloat) {
        switch self {
        case .well: return (radius: 5, y: -2, opacity: 0.55)
        case .resting: return (radius: 4, y: 2, opacity: 0.7)
        case .raised: return (radius: 6, y: 3, opacity: 0.9)
        case .floating: return (radius: 8, y: 4, opacity: 1.0)
        }
    }

    /// Contact shade. Negative `y` lifts it from the bottom edge.
    var innerShade: (radius: CGFloat, y: CGFloat, opacity: CGFloat) {
        switch self {
        case .well: return (radius: 6, y: 3, opacity: 1.0)
        case .resting: return (radius: 3, y: -1, opacity: 0.5)
        case .raised: return (radius: 5, y: -2, opacity: 0.7)
        case .floating: return (radius: 6, y: -3, opacity: 0.85)
        }
    }

    var strokeOpacity: CGFloat {
        switch self {
        case .well: return 0.72
        case .resting: return 0.55
        case .raised: return 0.62
        case .floating: return 0.7
        }
    }
}

// MARK: - Surface modifier

public struct ClaySurfaceModifier: ViewModifier {
    public let depth: ClayDepth
    public let cornerRadius: CGFloat
    public let fill: Color?
    public let isPressed: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.lifeBoardClayLightDaypart) private var lightDaypart
    @Environment(\.colorScheme) private var colorScheme

    public init(
        depth: ClayDepth,
        cornerRadius: CGFloat? = nil,
        fill: Color? = nil,
        isPressed: Bool = false
    ) {
        self.depth = depth
        self.cornerRadius = cornerRadius ?? depth.cornerRadius
        self.fill = fill
        self.isPressed = isPressed
    }

    public func body(content: Content) -> some View {
        content
            .background(claySurface)
            .overlay(hairline)
            .modifier(
                SpecularRimModifier(
                    depth: depth,
                    cornerRadius: cornerRadius,
                    lightAngle: lightAngle
                )
            )
            .modifier(ClayDropShadow(depth: depth, isPressed: isPressed))
    }

    /// The sun for this surface, if the screen has told us where it is.
    private var lightAngle: Angle {
        guard let daypart = lightDaypart else { return .degrees(-60) }
        return .degrees(daypart.specularLightAngleDegrees)
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var resolvedFill: Color {
        fill ?? Color(depth.fillToken)
    }

    /// Whether the fill is dark enough that the standard lit layers would
    /// overwhelm it.
    ///
    /// `clayHighlight` is a near-opaque white inner shadow, which is right on a
    /// warm paper surface and completely wrong on a cocoa pill — it would put a
    /// white sheen across the top of the primary action. Real clay's lit edge is
    /// a lighter version of the object's own colour, so on a dark body the
    /// highlight has to retreat to a fraction of its strength. Scaling it here
    /// rather than at the call site means every surface that passes a custom
    /// `fill` gets the right material, not just the one that motivated it.
    private var fillIsDark: Bool {
        let traits = UITraitCollection(userInterfaceStyle: colorScheme == .dark ? .dark : .light)
        var white: CGFloat = 0
        var alpha: CGFloat = 0
        guard UIColor(resolvedFill).resolvedColor(with: traits).getWhite(&white, alpha: &alpha) else {
            return false
        }
        return white < 0.5
    }

    private var highlightOpacity: CGFloat {
        fillIsDark ? depth.innerHighlight.opacity * 0.22 : depth.innerHighlight.opacity
    }

    /// Under Reduce Transparency the soft inner layers are dropped entirely and
    /// the surface becomes flat and opaque with a stronger hairline. Depth is a
    /// decoration; legibility is not.
    @ViewBuilder
    private var claySurface: some View {
        if usesFlatSurface {
            shape.fill(resolvedFill)
        } else {
            shape.fill(
                resolvedFill
                    .shadow(.inner(
                        color: Color(SemanticColorTokens.clayHighlight)
                            .opacity(highlightOpacity),
                        radius: depth.innerHighlight.radius,
                        y: depth.innerHighlight.y
                    ))
                    .shadow(.inner(
                        color: Color(SemanticColorTokens.clayInnerShade)
                            .opacity(pressedShadeOpacity),
                        radius: depth.innerShade.radius,
                        y: depth.innerShade.y
                    ))
            )
        }
    }

    /// Pressing deepens the contact shade, so the surface reads as compressed
    /// rather than merely dimmed.
    private var pressedShadeOpacity: CGFloat {
        isPressed ? min(1, depth.innerShade.opacity * 1.6) : depth.innerShade.opacity
    }

    /// One edge per boundary.
    ///
    /// Raised clay used to carry the semantic hairline *and* the specular rim on
    /// the identical boundary. `SpecularRimModifier` suppresses itself under
    /// Increase Contrast for exactly this reason — "two competing edges on the
    /// same boundary is worse than either alone" — and then the default path
    /// drew both anyway. With the material rendering (see
    /// `foundationSurfaceSolid`), the rim is the edge, and the hairline is
    /// redundant outlining that made every card read as a bordered rectangle.
    ///
    /// The hairline still owns the boundary wherever the rim does not: on wells,
    /// which are below the canvas plane and get no lit edge; and under Increase
    /// Contrast and Reduce Transparency, where the rim stands down and boundary
    /// clarity outranks material character.
    @ViewBuilder
    private var hairline: some View {
        if drawsHairline {
            shape.stroke(
                Color(SemanticColorTokens.foundationHairline)
                    .opacity(contrast == .increased ? 1 : depth.strokeOpacity),
                lineWidth: contrast == .increased ? 1.5 : 1
            )
        }
    }

    private var drawsHairline: Bool {
        depth == .well
            || contrast == .increased
            || usesFlatSurface
    }

    private var usesFlatSurface: Bool {
        reduceTransparency || VisualAppearanceFixture.active?.usesReducedTransparency == true
    }
}

/// Split out so the `.shadow` call stays inside `DesignSystem/`, which is the
/// only place the token-law guardrail permits raw shadow geometry.
private struct ClayDropShadow: ViewModifier {
    let depth: ClayDepth
    let isPressed: Bool

    func body(content: Content) -> some View {
        if let drop = depth.dropShadow {
            let compression: CGFloat = isPressed ? 0.45 : 1
            content.shadow(
                color: Color(SemanticColorTokens.foundationWarmShadow)
                    .opacity(drop.opacity * compression),
                radius: drop.radius * compression,
                y: drop.y * compression
            )
        } else {
            content
        }
    }
}

// MARK: - Public surface API

public extension View {
    /// The single sanctioned content elevation. Glass remains reserved for
    /// navigation and control chrome.
    func lifeBoardClaySurface(
        _ depth: ClayDepth,
        cornerRadius: CGFloat? = nil,
        fill: Color? = nil,
        isPressed: Bool = false
    ) -> some View {
        modifier(ClaySurfaceModifier(
            depth: depth,
            cornerRadius: cornerRadius,
            fill: fill,
            isPressed: isPressed
        ))
    }
}

// MARK: - Interactive clay

/// Gives any clay surface its tactile press: the surface compresses into the
/// canvas, its contact shade deepens, and the drop shadow pulls in. Scale is
/// deliberately small (0.985) — clay is heavy, and a large bounce would read as
/// plastic.
public struct ClayButtonStyle: ButtonStyle {
    public let depth: ClayDepth
    public let cornerRadius: CGFloat?
    public let fill: Color?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        depth: ClayDepth = .raised,
        cornerRadius: CGFloat? = nil,
        fill: Color? = nil
    ) {
        self.depth = depth
        self.cornerRadius = cornerRadius
        self.fill = fill
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lifeBoardClaySurface(
                depth,
                cornerRadius: cornerRadius,
                fill: fill,
                isPressed: configuration.isPressed
            )
            .scaleEffect(reduceMotion || configuration.isPressed == false ? 1 : 0.985)
            .hoverEffect(.lift)
            .animation(
                MotionProfile.press.animation(reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }
}

public extension ButtonStyle where Self == ClayButtonStyle {
    static var lifeBoardClay: ClayButtonStyle { ClayButtonStyle() }

    static func lifeBoardClay(
        _ depth: ClayDepth,
        cornerRadius: CGFloat? = nil,
        fill: Color? = nil
    ) -> ClayButtonStyle {
        ClayButtonStyle(depth: depth, cornerRadius: cornerRadius, fill: fill)
    }
}

// MARK: - Primary action

/// The canonical primary action.
///
/// `.borderedProminent` with a `.tint(...)` is not safe inside LifeBoard's
/// roots: Home applies an ambient `foregroundStyle` for its daypart ink, which
/// propagates into button labels and defeats the system's automatic contrasting
/// label. The Journal card's primary button rendered as a completely blank
/// cocoa pill for exactly this reason. Pinning the on-accent role explicitly is
/// the only arrangement that survives an ambient foreground style.
public struct PrimaryActionStyle: ButtonStyle {
    public let fill: Color?
    /// Whether the pill claims the full available width.
    ///
    /// `true` for a screen's dominant action — a commit bar, a hero's primary.
    /// `false` for an action that sits inline beside siblings, where claiming
    /// the row would push them onto their own lines. `.borderedProminent`, which
    /// this style replaces, is intrinsically sized, so the compact variant is
    /// what preserves an existing layout during that swap.
    public let expands: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    public init(fill: Color? = nil, expands: Bool = true) {
        self.fill = fill
        self.expands = expands
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // `DESIGN.md`'s `primary-action`: button typography, 48pt tall, xl
            // padding. This was `.subheadline` (about 15pt) at 44pt with 14pt
            // padding — a raw font inside the canonical primitive, and three
            // metrics adrift from the contract.
            .lifeboardFont(.button)
            .foregroundStyle(
                isEnabled
                    ? Color.lifeboard(.onAccent, on: .accent)
                    : Color.lifeboard(.textTertiary)
            )
            .frame(maxWidth: expands ? .infinity : nil, minHeight: 48)
            .padding(.horizontal, 24)
            // The primary action is the most important control on the screen and
            // it used to be the flattest object in the app: a bare filled
            // capsule with no inner layers, no lit edge and no shadow, in a
            // system whose whole premise is tactile material. It is clay now,
            // and it presses like clay.
            .lifeBoardClaySurface(
                .raised,
                cornerRadius: Radius.pill,
                fill: isEnabled
                    ? (fill ?? Color.lifeboard(.actionPrimary))
                    : Color.lifeboard(.surfaceSecondary),
                isPressed: configuration.isPressed
            )
            .scaleEffect(reduceMotion || configuration.isPressed == false ? 1 : 0.98)
            // `DESIGN.md` iPad: "Pointer targets, hover treatment, keyboard
            // focus, and root shortcuts are part of the design." There were 12
            // `.hoverEffect` call sites in the entire app and none of them was
            // in a control style, so almost nothing responded to a pointer.
            // Applying it here gives every button built on this style pointer
            // treatment at once; it is inert on a touch-only device.
            .hoverEffect(.lift)
            .animation(
                MotionProfile.press.animation(reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }
}

public extension ButtonStyle where Self == PrimaryActionStyle {
    static var lifeBoardPrimary: PrimaryActionStyle { PrimaryActionStyle() }

    /// Intrinsically-sized primary action, for buttons that sit inline beside
    /// siblings. Same fill and same `.onAccent` ink — only the width differs.
    ///
    /// This is the safe replacement for `.borderedProminent`, whose real defect
    /// is that the system pins a **white** label against the app tint: in dark
    /// appearance that tint resolves to cream, so it draws white on cream.
    static var lifeBoardPrimaryCompact: PrimaryActionStyle {
        PrimaryActionStyle(expands: false)
    }
}

// MARK: - Form surface

/// Puts a `Form` or `List` on the warm canvas instead of the grey system
/// grouped background.
///
/// Composers and settings-style sheets across Track, Nutrition, Wellness and
/// Life Moments used a bare `Form`, which renders on `systemGroupedBackground`
/// — a cool grey that belongs to no part of this design system. Hiding the
/// scroll background and substituting the canvas is what brings those screens
/// back into the clay language; individual sections can still opt into a raised
/// row fill where grouping needs to be explicit.
public struct FormSurfaceModifier: ViewModifier {
    public init() {}

    public func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea())
    }
}

public extension View {
    /// Apply directly to a `Form` or `List`.
    func lifeBoardFormSurface() -> some View {
        modifier(FormSurfaceModifier())
    }

    /// The row fill for grouped form content that needs to read as a card.
    func lifeBoardFormRowSurface() -> some View {
        listRowBackground(
            RoundedRectangle(cornerRadius: ClayDepth.resting.cornerRadius, style: .continuous)
                .fill(Color(SemanticColorTokens.foundationSurfaceSolid))
        )
    }
}

// MARK: - Compact chip action

/// A small recessed clay chip for quick actions inside a card.
///
/// `.bordered` chips render in the system grey and, inside a half-width card,
/// squeeze their labels until they wrap mid-word — the hydration quick-adds
/// were showing as "+2 50" and "Tar- get" in grey circles. This keeps the label
/// on one line and lets the caller stack the row when it genuinely will not fit.
public struct ChipButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .lifeboardFont(.buttonSmall)
            // `.lineLimit(1)` with `.fixedSize()` meant the label could never
            // wrap: at accessibility text sizes the chip grew straight out of
            // whatever contained it instead of reflowing. It may take a second
            // line now, and only refuses to compress below its intrinsic width
            // at ordinary sizes, which is what stopped "+2 50" and "Tar- get".
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            // Was 34, below the 44pt floor `DESIGN.md` sets for every
            // interactive target.
            .frame(minHeight: 44)
            // Was `.well`. A well is carved *into* the canvas, which is the
            // wrong read for something you press: an action should start raised
            // and compress under the finger, and `isPressed` already deepens the
            // contact shade to sell that.
            .lifeBoardClaySurface(
                .resting,
                cornerRadius: Radius.pill,
                isPressed: configuration.isPressed
            )
            .contentShape(Capsule())
            .scaleEffect(reduceMotion || configuration.isPressed == false ? 1 : 0.97)
            .hoverEffect(.lift)
            .animation(
                MotionProfile.press.animation(reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }
}

public extension ButtonStyle where Self == ChipButtonStyle {
    static var lifeBoardChip: ChipButtonStyle { ChipButtonStyle() }
}
