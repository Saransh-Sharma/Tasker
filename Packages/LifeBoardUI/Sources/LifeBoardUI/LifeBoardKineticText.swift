import SwiftUI
import LifeBoardTokens
// MARK: - Kinetic text
//
// Per-glyph proximity response. Interaction concept adapted from Shubham Kumar
// Singh's Apache-2.0 SwiftUI-Animations `TextBouncingView`, which lays each
// character out as its own `Text` inside an `HStack` and offsets it by distance
// from the finger.
//
// That construction is not viable here. An HStack of characters cannot wrap, so
// it breaks at larger Dynamic Type sizes; it replaces one accessibility element
// with N; it defeats text selection; and splitting a `String` into `Character`s
// mis-handles grapheme clusters, bidirectional text, and every localization
// where the greeting is not English.
//
// `TextRenderer` gets the same effect without any of that. SwiftUI performs real
// text layout — line breaking, Dynamic Type, RTL, localization, semantics — and
// this only draws the glyphs it produced, each with its own translation. The
// design contract forbids distorting text; glyphs are *displaced* here, never
// scaled, sheared, rotated, or blurred, and the displacement is bounded so the
// line never becomes hard to read.

/// Draws a line of text with each glyph nudged along y by its distance from the
/// finger.
///
/// `intensity` is the animatable channel: it rises when the finger lands and
/// settles back to zero on release, so the effect eases in and out instead of
/// snapping.
public struct KineticTextRenderer: TextRenderer, Animatable {
    /// Horizontal touch position in the text's own coordinate space, or `nil`
    /// when nothing is touching it.
    public var touchX: CGFloat?
    /// 0 at rest, 1 fully engaged.
    public var intensity: Double

    /// The furthest a glyph may travel. Small on purpose: this is a greeting,
    /// not a toy, and it has to stay legible mid-gesture.
    static let maximumRise: CGFloat = KineticTextMetrics.maximumRise
    /// How far the influence spreads either side of the finger, in points.
    static let falloff: CGFloat = KineticTextMetrics.falloff

    public init(touchX: CGFloat?, intensity: Double) {
        self.touchX = touchX
        self.intensity = intensity
    }

    public var animatableData: Double {
        get { intensity }
        set { intensity = newValue }
    }

    /// Vertical offset for a glyph centred at `glyphMidX`.
    ///
    /// A gaussian keeps the crest smooth: a linear falloff produces a visible
    /// kink at the edge of the influence radius.
    static func rise(glyphMidX: CGFloat, touchX: CGFloat?, intensity: Double) -> CGFloat {
        KineticTextMetrics.rise(glyphMidX: glyphMidX, touchX: touchX, intensity: intensity)
    }

    public func draw(layout: Text.Layout, in context: inout GraphicsContext) {
        for line in layout {
            for run in line {
                for glyph in run {
                    let rise = Self.rise(
                        glyphMidX: glyph.typographicBounds.rect.midX,
                        touchX: touchX,
                        intensity: intensity
                    )
                    var copy = context
                    copy.translateBy(x: 0, y: rise)
                    copy.draw(glyph)
                }
            }
        }
    }
}

/// Applies the kinetic response to the view's text.
///
/// Suppressed wholesale — not merely reduced — whenever motion is unwelcome:
/// Reduce Motion, Low Power, thermal pressure, an inactive scene, the calm
/// comfort profile, and the reduced-motion screenshot fixture. At accessibility
/// Dynamic Type sizes the greeting wraps and per-glyph displacement stops
/// reading as intentional, so it is dropped there too.
private struct KineticTextModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    @State private var touchX: CGFloat?
    @State private var intensity: Double = 0

    private var isEnabled: Bool {
        guard dynamicTypeSize.isAccessibilitySize == false else { return false }
        guard LifeBoardAnimation.areProcessAnimationsDisabled == false else { return false }
        guard VisualAppearanceFixture.active?.usesReducedMotion != true else { return false }
        return MotionPolicy.resolve(
            reduceMotion: reduceMotion,
            reduceTransparency: reduceTransparency,
            sceneIsActive: scenePhase == .active
        ).allowsSpatialMotion
    }

    func body(content: Content) -> some View {
        if isEnabled {
            content
                .textRenderer(
                    KineticTextRenderer(touchX: touchX, intensity: intensity)
                )
                // Simultaneous and zero-distance so the greeting responds to a
                // touch without ever taking a scroll away from the page.
                .simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            touchX = value.location.x
                            guard intensity < 1 else { return }
                            withAnimation(InteractionMotion.cardLift(reduceMotion: false)) {
                                intensity = 1
                            }
                        }
                        .onEnded { _ in
                            withAnimation(InteractionMotion.dragRelease(reduceMotion: false)) {
                                intensity = 0
                            }
                            touchX = nil
                        }
                )
        } else {
            content
        }
    }
}

public extension View {
    /// Per-glyph proximity response for a short, prominent line of text.
    ///
    /// Intended for the Home greeting. Do not apply to body copy, evidence,
    /// health values, or anything the reader has to parse carefully.
    func lifeBoardKineticGreeting() -> some View {
        modifier(KineticTextModifier())
    }
}

/// Applies `lifeBoardKineticGreeting()` only when the header opted in, without
/// forcing callers into an `if` that would change the `Text`'s identity.
public struct OptionalKineticGreeting: ViewModifier {
    public let isEnabled: Bool

    public init(isEnabled: Bool) {
        self.isEnabled = isEnabled
    }

    public func body(content: Content) -> some View {
        if isEnabled {
            content.lifeBoardKineticGreeting()
        } else {
            content
        }
    }
}
