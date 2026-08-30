import XCTest
import UIKit
@testable import LifeBoard

/// The clay material has to be *visible*, and nothing used to check that.
///
/// `claySpecularRim` shipped as `#FFFDF7` at 0.6 on a `foundationSurfaceSolid`
/// fill of `#FFFDF7` — the same hex. `SpecularRimModifier` composites in
/// `.plusLighter`, so the rim did not disappear outright; it saturated to white
/// and stopped, because a plus-lighter stroke can only brighten by the distance
/// between the surface and white, and on a surface at 98% of maximum luminance
/// that distance was 3.3 of 255. The inner highlight, an inner shadow toward
/// white, was clipped by the same ceiling at 3.3.
///
/// Both were within a rounding error of invisible for months, and every existing
/// token test passed the whole time, because they all compare a token to a hex
/// literal. A token can be exactly the value the spec asked for and still paint
/// nothing once it is composited onto the thing it sits on.
///
/// So these tests measure the composite, through the blend mode each layer
/// actually uses, in both appearances.
@MainActor
final class ClayMaterialContrastTests: XCTestCase {

    // MARK: - Colour maths

    private struct Channels {
        var r: CGFloat, g: CGFloat, b: CGFloat
    }

    private func channels(_ color: UIColor, _ style: UIUserInterfaceStyle) -> Channels {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.resolvedColor(with: .init(userInterfaceStyle: style)).getRed(&r, green: &g, blue: &b, alpha: &a)
        return Channels(r: r, g: g, b: b)
    }

    private func alpha(_ color: UIColor, _ style: UIUserInterfaceStyle) -> CGFloat {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.resolvedColor(with: .init(userInterfaceStyle: style)).getRed(&r, green: &g, blue: &b, alpha: &a)
        return a
    }

    /// Mean 8-bit value. Used rather than WCAG relative luminance because these
    /// are *material* deltas, not text legibility: linearised luminance
    /// compresses the dark end so hard that a clearly visible contact shade in
    /// dark appearance measures near zero and would fail a luminance threshold
    /// it visibly passes.
    private func value(_ c: Channels) -> CGFloat { (c.r + c.g + c.b) / 3 * 255 }

    /// Source-over: what `.shadow(.inner(...))` and ordinary fills do.
    private func over(_ src: Channels, _ a: CGFloat, _ dst: Channels) -> Channels {
        Channels(
            r: src.r * a + dst.r * (1 - a),
            g: src.g * a + dst.g * (1 - a),
            b: src.b * a + dst.b * (1 - a)
        )
    }

    /// Plus-lighter: what `SpecularRimModifier` does. Additive and clamped,
    /// which is exactly why the surface's headroom to white is the rim's whole
    /// dynamic range.
    private func plusLighter(_ src: Channels, _ a: CGFloat, _ dst: Channels) -> Channels {
        Channels(
            r: min(1, src.r * a + dst.r),
            g: min(1, src.g * a + dst.g),
            b: min(1, src.b * a + dst.b)
        )
    }

    /// The floor a material layer must clear to be doing any work at all.
    /// Eight of 255 is roughly where a soft-edged 1px stroke stops being
    /// deniable on a calibrated display.
    private let minimumMaterialDelta: CGFloat = 8

    // MARK: - The three layers

    func testSpecularRimIsPerceptibleInBothAppearances() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let surface = channels(SemanticColorTokens.foundationSurfaceSolid, style)
            let rim = channels(SemanticColorTokens.claySpecularRim, style)
            // `raised` intensity, per SpecularRimModifier.
            let peak = alpha(SemanticColorTokens.claySpecularRim, style) * 0.85
            let lit = plusLighter(rim, peak, surface)
            let delta = abs(value(lit) - value(surface))

            XCTAssertGreaterThanOrEqual(
                delta, minimumMaterialDelta,
                """
                The specular rim moves the raised surface by only \(delta) of 255 in \
                \(style == .light ? "light" : "dark") appearance. Under .plusLighter the rim's \
                ceiling is the surface's headroom to white, so this is almost always a sign that \
                foundationSurfaceSolid has drifted back toward white rather than that the rim \
                token is wrong.
                """
            )
        }
    }

    func testInnerHighlightIsPerceptibleInBothAppearances() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let surface = channels(SemanticColorTokens.foundationSurfaceSolid, style)
            let highlight = channels(SemanticColorTokens.clayHighlight, style)
            let lit = over(highlight, alpha(SemanticColorTokens.clayHighlight, style), surface)
            XCTAssertGreaterThanOrEqual(
                abs(value(lit) - value(surface)), minimumMaterialDelta,
                "The clay inner highlight is invisible in \(style == .light ? "light" : "dark") appearance."
            )
        }
    }

    func testContactShadeIsPerceptibleInBothAppearances() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let surface = channels(SemanticColorTokens.foundationSurfaceSolid, style)
            let shade = channels(SemanticColorTokens.clayInnerShade, style)
            let shaded = over(shade, alpha(SemanticColorTokens.clayInnerShade, style), surface)
            XCTAssertGreaterThanOrEqual(
                abs(value(shaded) - value(surface)), minimumMaterialDelta,
                "The clay contact shade is invisible in \(style == .light ? "light" : "dark") appearance."
            )
        }
    }

    /// The lit half of the form is the rim plus the highlight. A card can have a
    /// perfectly good contact shade and still read as flat paper if nothing
    /// above it catches light — which is precisely the state the app shipped in.
    func testTheLitHalfOfTheMaterialCarriesRealWeight() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let surface = channels(SemanticColorTokens.foundationSurfaceSolid, style)
            let rim = channels(SemanticColorTokens.claySpecularRim, style)
            let highlight = channels(SemanticColorTokens.clayHighlight, style)
            let rimDelta = abs(value(plusLighter(rim, alpha(SemanticColorTokens.claySpecularRim, style) * 0.85, surface)) - value(surface))
            let hlDelta = abs(value(over(highlight, alpha(SemanticColorTokens.clayHighlight, style), surface)) - value(surface))

            XCTAssertGreaterThanOrEqual(
                rimDelta + hlDelta, 20,
                """
                The lit layers together move the surface by \(rimDelta + hlDelta) of 255 in \
                \(style == .light ? "light" : "dark"). Clay reads as a soft solid because light \
                lands on it; with only a bottom shade it is a flat rectangle with a drop shadow.
                """
            )
        }
    }

    // MARK: - Surface separation

    /// Two roles resolving to the same hex is not a near miss, it is a surface
    /// that cannot be seen. `foundationCanvasSoft` and `foundationSurfaceSolid`
    /// were both `#24243B` in dark appearance, so a card on a soft canvas was
    /// separated from it by nothing at all; `foundationCanvasMuted` and
    /// `foundationSurfaceSelected` were both `#343754`, so was a selection.
    func testDistinctSurfaceRolesResolveToDistinctColours() {
        let roles: [(String, UIColor)] = [
            ("canvas", SemanticColorTokens.foundationCanvas),
            ("canvasSoft", SemanticColorTokens.foundationCanvasSoft),
            ("canvasMuted", SemanticColorTokens.foundationCanvasMuted),
            ("surfaceRecessed", SemanticColorTokens.foundationSurfaceRecessed),
            ("surfaceSolid", SemanticColorTokens.foundationSurfaceSolid),
            ("surfaceRaised", SemanticColorTokens.foundationSurfaceRaised),
            ("surfaceSelected", SemanticColorTokens.foundationSurfaceSelected)
        ]

        for style in [UIUserInterfaceStyle.light, .dark] {
            for i in roles.indices {
                for j in roles.index(after: i)..<roles.endIndex {
                    let a = value(channels(roles[i].1, style))
                    let b = value(channels(roles[j].1, style))
                    XCTAssertGreaterThan(
                        abs(a - b), 0.01,
                        "\(roles[i].0) and \(roles[j].0) resolve to the same colour in \(style == .light ? "light" : "dark") appearance."
                    )
                }
            }
        }
    }

    /// A background must never read as more elevated than a card sitting on it.
    func testMutedCanvasNeverOutranksTheCardAboveIt() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let muted = value(channels(SemanticColorTokens.foundationCanvasMuted, style))
            let solid = value(channels(SemanticColorTokens.foundationSurfaceSolid, style))
            if style == .dark {
                XCTAssertLessThan(muted, solid, "A muted canvas is lighter than the card on it in dark appearance.")
            } else {
                XCTAssertLessThan(muted, solid, "A muted canvas is lighter than the card on it in light appearance.")
            }
        }
    }

    /// Reseating `foundationSurfaceSolid` to buy the rim its headroom must not
    /// have cost body text its contrast floor.
    func testInkStillClearsTheBodyFloorOnEveryClaySurface() {
        let surfaces: [(String, UIColor)] = [
            ("surfaceSolid", SemanticColorTokens.foundationSurfaceSolid),
            ("surfaceRaised", SemanticColorTokens.foundationSurfaceRaised),
            ("surfaceRecessed", SemanticColorTokens.foundationSurfaceRecessed),
            ("surfaceSelected", SemanticColorTokens.foundationSurfaceSelected)
        ]
        for style in [UIUserInterfaceStyle.light, .dark] {
            for (name, surface) in surfaces {
                for (inkName, ink) in [("inkPrimary", SemanticColorTokens.inkPrimary),
                                       ("inkSecondary", SemanticColorTokens.inkSecondary)] {
                    let ratio = contrastRatio(
                        channels(ink, style),
                        channels(surface, style)
                    )
                    XCTAssertGreaterThanOrEqual(
                        ratio, 4.5,
                        "\(inkName) on \(name) is \(ratio):1 in \(style == .light ? "light" : "dark") appearance."
                    )
                }
            }
        }
    }

    // MARK: - The two vocabularies must agree

    /// The app draws cards two ways. `ClaySurfaceModifier` fills from the
    /// `foundation*` statics; roughly 1,200 call sites fill from
    /// `Color.lifeboard(.surfacePrimary)` and friends. Those are not two names
    /// for one palette — `TokenBridge` measured that only 2 of 13 such pairs
    /// resolved identically — but for the *surface planes* they must, because
    /// both vocabularies put cards on the same screen and a mismatch is two
    /// different card colours side by side.
    ///
    /// This is the pairing that broke when the clay material was reseated: the
    /// foundation static moved to buy the specular rim its headroom and the
    /// semantic role stayed at the old near-white value.
    func testClayPlanesAgreeAcrossBothColourVocabularies() {
        let colors = Theme(index: 0).tokens.color
        let pairs: [(String, UIColor, UIColor)] = [
            ("card", colors.surfacePrimary, SemanticColorTokens.foundationSurfaceSolid),
            ("raised", colors.bgElevated, SemanticColorTokens.foundationSurfaceRaised),
            ("recessed", colors.surfaceSecondary, SemanticColorTokens.foundationSurfaceRecessed),
            ("selected", colors.surfaceTertiary, SemanticColorTokens.foundationSurfaceSelected)
        ]
        for style in [UIUserInterfaceStyle.light, .dark] {
            for (plane, semantic, foundation) in pairs {
                let a = channels(semantic, style)
                let b = channels(foundation, style)
                XCTAssertEqual(value(a), value(b), accuracy: 0.6, """
                    The \(plane) plane resolves differently in the two colour vocabularies in \
                    \(style == .light ? "light" : "dark") appearance. A card drawn through \
                    lifeBoardClaySurface and a card drawn through Color.lifeboard(...) would not \
                    match on the same screen.
                    """)
            }
        }
    }

    /// Clay is a solid. `surfacePrimary` used to carry 0.96/0.92 alpha, so a
    /// card's final colour depended on whatever happened to be behind it — the
    /// canvas, a scenic backdrop, or another card. Translucency belongs to
    /// glass; a material whose colour is contextual is not a material.
    func testClayPlanesAreOpaque() {
        let colors = Theme(index: 0).tokens.color
        let planes: [(String, UIColor)] = [
            ("surfacePrimary", colors.surfacePrimary),
            ("surfaceSecondary", colors.surfaceSecondary),
            ("surfaceTertiary", colors.surfaceTertiary),
            ("bgElevated", colors.bgElevated)
        ]
        for style in [UIUserInterfaceStyle.light, .dark] {
            for (name, color) in planes {
                XCTAssertEqual(
                    alpha(color, style), 1, accuracy: 0.001,
                    "\(name) is translucent in \(style == .light ? "light" : "dark") appearance."
                )
            }
        }
    }

    private func contrastRatio(_ a: Channels, _ b: Channels) -> CGFloat {
        func linear(_ c: CGFloat) -> CGFloat {
            c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        func luminance(_ c: Channels) -> CGFloat {
            0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b)
        }
        let la = luminance(a), lb = luminance(b)
        return (max(la, lb) + 0.05) / (min(la, lb) + 0.05)
    }
}
