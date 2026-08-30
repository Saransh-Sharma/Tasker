import LifeBoardTokens
import LifeBoardUI
import SwiftUI
import UIKit

// MARK: - The per-screen claim

private struct HeroGlassClaimedKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// Whether something above this point in the hierarchy has already taken the
    /// screen's one hero.
    ///
    /// `DESIGN.md` says exactly one object per screen may be hero glass. This
    /// enforces the half that can be enforced mechanically: a hero *nested*
    /// inside another hero resolves to floating clay rather than stacking glass
    /// on glass, which is the failure the rule most needs to prevent.
    ///
    /// It cannot settle the other half. Two hero surfaces that are *siblings*
    /// each see an unclaimed environment, because SwiftUI environment values
    /// flow down and not across. Choosing between siblings is a composition
    /// decision that belongs to the screen, and screens make it by passing an
    /// explicit flag to the section they nominate — see `TrackFastingSection`'s
    /// `isHero`. Anything else would mean a view deciding its own prominence
    /// without knowing what is next to it.
    var lifeBoardHeroGlassClaimed: Bool {
        get { self[HeroGlassClaimedKey.self] }
        set { self[HeroGlassClaimedKey.self] = newValue }
    }
}

// MARK: - Contrast

/// The contrast arithmetic behind the hero's scrim.
///
/// `DESIGN.md` sizes the scrim "by the contrast it must achieve, not by taste".
/// That is only meaningful if something actually measures it, so this does:
/// given the scene the hero floats over, it returns the least scrim opacity that
/// still clears the ratio the text needs.
enum HeroContrastFloor {
    /// WCAG AA for body text.
    static let bodyRatio: Double = 4.5
    /// WCAG AA for large text — the metric numeral qualifies.
    static let largeTextRatio: Double = 3.0

    /// Relative luminance, per WCAG 2.1.
    static func luminance(of color: UIColor, traits: UITraitCollection) -> Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.resolvedColor(with: traits).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    static func ratio(_ first: Double, _ second: Double) -> Double {
        let lighter = max(first, second), darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// The least scrim opacity that lets `ink` clear `ratio` over `scene`.
    ///
    /// Returns the base opacity when the scene is already comfortable, and
    /// climbs toward opaque when it is not — a bright midday sky behind dark
    /// cocoa ink needs a great deal more veil than a night canvas does.
    ///
    /// Searched rather than solved because the composite is alpha-blended in
    /// *sRGB* while contrast is measured in linearised luminance, so there is no
    /// closed form. Sixty steps resolves finer than a percent, which is well
    /// below what any display can show.
    static func scrimOpacity(
        scene: UIColor,
        scrim: UIColor,
        ink: UIColor,
        base: Double,
        ratio requiredRatio: Double,
        traits: UITraitCollection
    ) -> Double {
        let inkLuminance = luminance(of: ink, traits: traits)
        var sceneRGB = (red: CGFloat(0), green: CGFloat(0), blue: CGFloat(0), alpha: CGFloat(0))
        var scrimRGB = sceneRGB
        scene.resolvedColor(with: traits)
            .getRed(&sceneRGB.red, green: &sceneRGB.green, blue: &sceneRGB.blue, alpha: &sceneRGB.alpha)
        scrim.resolvedColor(with: traits)
            .getRed(&scrimRGB.red, green: &scrimRGB.green, blue: &scrimRGB.blue, alpha: &scrimRGB.alpha)

        let steps = 60
        for step in 0...steps {
            let candidate = base + (1 - base) * Double(step) / Double(steps)
            let blended = UIColor(
                red: scrimRGB.red * candidate + sceneRGB.red * (1 - candidate),
                green: scrimRGB.green * candidate + sceneRGB.green * (1 - candidate),
                blue: scrimRGB.blue * candidate + sceneRGB.blue * (1 - candidate),
                alpha: 1
            )
            if ratio(inkLuminance, luminance(of: blended, traits: traits)) >= requiredRatio {
                return candidate
            }
        }
        // Nothing short of opaque clears it. Opaque is the honest answer: the
        // decision has to be readable, and glass is the part that is optional.
        return 1
    }
}

// MARK: - The surface

/// Regular Liquid Glass over the scenic atmosphere, for the one dominant object
/// on a screen.
///
/// This is the only content material in the product permitted glass, and the
/// four constraints in `DESIGN.md`'s Elevation chapter are all enforced here
/// rather than asked of callers:
///
/// - **One per screen** — via `lifeBoardHeroGlassClaimed`; a second resolves to
///   floating clay.
/// - **Contrast floor** — the scrim is measured against the scrimmed composite
///   by `HeroContrastFloor`, not guessed.
/// - **One silhouette, two materials** — geometry, radius and padding are
///   resolved *before* the material branch, so the fallback cannot reflow.
/// - **Never over evidence** — not expressible here; it is the caller's content
///   budget, which is why the hero presentation is offered through
///   `DecisionSurface` rather than as a free-floating card wrapper.
public struct HeroSurfaceModifier: ViewModifier {
    public let palette: DaypartPalette
    public let cornerRadius: CGFloat

    @Environment(\.lifeBoardHeroGlassClaimed) private var claimed
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    /// Observed, not static. Reading `ShaderReadiness.allowsShaderRendering`
    /// here is not an observation-tracked access, so this modifier rendered once
    /// before warm-up finished and never re-evaluated — every hero in the app
    /// fell back to clay for the whole session.
    @Environment(\.lifeBoardShaderReadiness) private var shaderReadiness

    public init(palette: DaypartPalette, cornerRadius: CGFloat = Radius.hero) {
        self.palette = palette
        self.cornerRadius = cornerRadius
    }

    public func body(content: Content) -> some View {
        // Resolved once, shared by both branches. This is the "one silhouette"
        // rule made structural: there is no path where the two materials can
        // disagree about geometry.
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        Group {
            if usesGlass {
                content
                    .background(scrim, in: shape)
                    .lifeBoardSystemGlass(.regular, in: shape)
                    .lifeBoardSpecularRim(.floating, cornerRadius: cornerRadius)
                    // Only the glass arm settles. The effect is *about* glass
                    // arriving, so the opaque fallback staying still is correct
                    // rather than a degradation.
                    .modifier(HeroGlassSettleModifier())
            } else {
                content
                    .lifeBoardClaySurface(.floating, cornerRadius: cornerRadius)
            }
        }
        // Claimed for everything below, so a nested hero cannot take a second.
        .environment(\.lifeBoardHeroGlassClaimed, true)
    }

    /// Every condition that withdraws glass. `DESIGN.md`: "Glass is an
    /// enhancement; the decision it carries is not."
    private var usesGlass: Bool {
        guard claimed == false else { return false }
        guard reduceTransparency == false else { return false }
        guard contrast != .increased else { return false }
        guard scenePhase == .active else { return false }
        guard VisualAppearanceFixture.active?.usesReducedTransparency != true else { return false }
        return shaderReadiness
    }

    /// The veil, sized by measurement.
    private var scrim: Color {
        Color(SemanticColorTokens.heroScrim).opacity(resolvedScrimOpacity)
    }

    private var resolvedScrimOpacity: Double {
        let traits = UITraitCollection { mutable in
            mutable.userInterfaceStyle = colorScheme == .dark ? .dark : .light
        }

        // `DESIGN.md`: the scrim is measured "across the scene's full luminance
        // range". This used to measure the daypart *canvas* alone, on the stated
        // assumption that the canvas is "the brightest thing it ever sits on" —
        // which is not true. A hero floats over the scenic atmosphere, and the
        // celestial body and its highlight are considerably brighter than the
        // canvas behind them. A hero that happens to sit under the sun was
        // getting a scrim sized for the sky.
        //
        // Every stop the scene can put behind the hero, so the worst case is
        // measured rather than assumed.
        let sceneStops: [DaypartColorRole] = [
            .canvas, .canvasSecondary, .layerOne, .layerTwo,
            .celestialPrimary, .celestialCore, .decorativeHighlight
        ]

        // Both inks, not just the primary. The hero renders its context line,
        // its status and its metric footnote in `inkSecondary`, which is lighter
        // than `inkPrimary` and therefore needs *more* veil to clear the same
        // floor — so sizing the scrim for the title alone left the supporting
        // line below the body floor on exactly the bright scenes that need it
        // most.
        let inks: [(UIColor, Double)] = [
            (SemanticColorTokens.inkPrimary, HeroContrastFloor.bodyRatio),
            (SemanticColorTokens.inkSecondary, HeroContrastFloor.bodyRatio)
        ]

        var required = 0.0
        for stop in sceneStops {
            let scene = palette.uiColor(for: stop)
            for (ink, ratio) in inks {
                required = max(required, HeroContrastFloor.scrimOpacity(
                    scene: scene,
                    scrim: SemanticColorTokens.heroScrim,
                    ink: ink,
                    base: 0,
                    ratio: ratio,
                    traits: traits
                ))
            }
        }
        return required
    }
}

public extension View {
    /// Present this object as the screen's hero.
    ///
    /// Safe to call on more than one object in a hierarchy — the second and
    /// subsequent calls resolve to floating clay rather than competing for
    /// attention. That is a deliberate design: the alternative, asserting, turns
    /// a composition mistake into a crash in a shipping build.
    func lifeBoardHeroSurface(
        palette: DaypartPalette,
        cornerRadius: CGFloat = Radius.hero
    ) -> some View {
        modifier(HeroSurfaceModifier(palette: palette, cornerRadius: cornerRadius))
    }
}


// MARK: - heroGlassSettle

/// The one-shot refraction a hero plays as its glass arrives.
///
/// `DESIGN.md` names `heroGlassSettle` in the signature vocabulary — "once, when
/// a hero surface arrives or commits; never on scroll, and never while its
/// content is still loading" — but nothing in the app implemented it, so the one
/// material the product reserves for its most important object appeared with no
/// acknowledgement at all.
///
/// It is built from `liquidGlassRefract`, which `DESIGN.md` already approves for
/// "dock, lens, composer, and hero-surface transitions", rather than from a new
/// Metal function. That is deliberate: `SignatureShaders.warmUp()` materializes
/// `functionNames` all-or-nothing, so a new entry that failed to load would
/// disable *every* effect in the app. Reusing a function the preload already
/// verifies costs nothing and cannot regress the rest.
///
/// Applied by `HeroSurfaceModifier` itself rather than offered to callers, so no
/// screen can forget it and no screen can double it.
private struct HeroGlassSettleModifier: ViewModifier {
    /// Matches the settle half of the spatial-transition budget (280-500ms).
    private static let duration: TimeInterval = 0.42
    private static let peakStrength: Double = 0.5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.lifeBoardShaderReadiness) private var shaderReadiness

    /// Latched, not a counter. A hero settles when it arrives; a `LazyVStack`
    /// recycling its host must not read as a second arrival, which is what
    /// "never on scroll" rules out.
    @State private var hasSettled = false
    @State private var startDate: Date?

    func body(content: Content) -> some View {
        Group {
            if let startDate, usesFallback == false {
                TimelineView(.animation) { context in
                    let elapsed = context.date.timeIntervalSince(startDate)
                    let progress = min(1, max(0, elapsed / Self.duration))
                    if progress >= 1 {
                        content
                    } else {
                        // Decays to identity: the settle is the glass coming to
                        // rest, so the last frame it draws must be the same
                        // picture as no effect at all.
                        let eased = 1 - pow(1 - progress, 3)
                        content.lifeboardLiquidGlassRefract(
                            center: .center,
                            radius: 0.9,
                            strength: Self.peakStrength * (1 - eased)
                        )
                    }
                }
            } else {
                content
            }
        }
        .onAppear {
            guard hasSettled == false, usesFallback == false else { return }
            hasSettled = true
            startDate = Date()
        }
    }

    private var usesFallback: Bool {
        MotionOverride.resolve(reduceMotion)
            || reduceTransparency
            || scenePhase != .active
            || shaderReadiness == false
    }
}
