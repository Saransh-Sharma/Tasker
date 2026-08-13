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

    public var cornerRadius: CGFloat {
        switch self {
        case .well: return 14
        case .resting: return 16
        case .raised: return 18
        case .floating: return 24
        }
    }

    /// Ambient occlusion under the surface. `well` casts none — it is below
    /// the canvas plane, not above it.
    var dropShadow: (radius: CGFloat, y: CGFloat, opacity: CGFloat)? {
        switch self {
        case .well: return nil
        case .resting: return (radius: 4, y: 1, opacity: 0.5)
        case .raised: return (radius: 10, y: 5, opacity: 1.0)
        case .floating: return (radius: 20, y: 10, opacity: 1.35)
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
            .modifier(SpecularRimModifier(depth: depth, cornerRadius: cornerRadius))
            .modifier(ClayDropShadow(depth: depth, isPressed: isPressed))
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }

    private var resolvedFill: Color {
        fill ?? Color(depth == .well
            ? SemanticColorTokens.foundationSurfaceRecessed
            : SemanticColorTokens.foundationSurfaceSolid)
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
                            .opacity(depth.innerHighlight.opacity),
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

    private var hairline: some View {
        shape.stroke(
            Color(SemanticColorTokens.foundationHairline)
                .opacity(contrast == .increased ? 1 : depth.strokeOpacity),
            lineWidth: contrast == .increased ? 1.5 : 1
        )
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    public init(fill: Color? = nil) {
        self.fill = fill
    }

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Color.lifeboard(.onAccent, on: .accent))
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, 14)
            .background(
                Capsule(style: .continuous)
                    .fill(fill ?? Color.lifeboard(.actionPrimary))
                    .opacity(configuration.isPressed ? 0.88 : 1)
            )
            .opacity(isEnabled ? 1 : 0.45)
            .scaleEffect(reduceMotion || configuration.isPressed == false ? 1 : 0.98)
            .animation(
                MotionProfile.press.animation(reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }
}

public extension ButtonStyle where Self == PrimaryActionStyle {
    static var lifeBoardPrimary: PrimaryActionStyle { PrimaryActionStyle() }
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

    public init() {}

    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.footnote.weight(.semibold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 12)
            .frame(minHeight: 34)
            .lifeBoardClaySurface(
                .well,
                cornerRadius: Radius.pill,
                isPressed: configuration.isPressed
            )
            .contentShape(Capsule())
            .scaleEffect(reduceMotion || configuration.isPressed == false ? 1 : 0.97)
            .animation(
                MotionProfile.press.animation(reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
    }
}

public extension ButtonStyle where Self == ChipButtonStyle {
    static var lifeBoardChip: ChipButtonStyle { ChipButtonStyle() }
}
