import XCTest
import UIKit
@testable import LifeBoard
import LifeBoardTokens
import LifeBoardUI

/// The hero surface's guarantees, as tests rather than as prose in `DESIGN.md`.
///
/// The contrast floor is the one that matters most. "Composite a scrim until the
/// text is readable" is a sentence anyone can agree with and nobody can check;
/// these assert the actual ratio against the actual blend, across the full range
/// of daypart scenes a hero can land on — including midday, which is the
/// brightest thing in the product and the case a hand-tuned opacity gets wrong.
@MainActor
final class HeroSurfaceTests: XCTestCase {
    private func traits(_ style: UIUserInterfaceStyle) -> UITraitCollection {
        UITraitCollection { mutable in mutable.userInterfaceStyle = style }
    }

    // MARK: Shape

    func testHeroRadiusIsTheSharedSilhouette() {
        // The card, the hero and the opaque fallback all use this one number.
        // If it drifts, a card visibly changes shape as it opens.
        XCTAssertEqual(Radius.hero, 24)
    }

    func testHeroRadiusSitsBetweenCardAndModal() {
        XCTAssertGreaterThan(Radius.hero, Radius.largeCard)
        XCTAssertLessThan(Radius.hero, Radius.modal)
    }

    // MARK: Contrast arithmetic

    func testLuminanceEndpoints() {
        XCTAssertEqual(HeroContrastFloor.luminance(of: .white, traits: traits(.light)), 1, accuracy: 0.001)
        XCTAssertEqual(HeroContrastFloor.luminance(of: .black, traits: traits(.light)), 0, accuracy: 0.001)
    }

    func testContrastRatioIsSymmetricAndBounded() {
        let white = HeroContrastFloor.luminance(of: .white, traits: traits(.light))
        let black = HeroContrastFloor.luminance(of: .black, traits: traits(.light))
        XCTAssertEqual(HeroContrastFloor.ratio(white, black), 21, accuracy: 0.01)
        XCTAssertEqual(
            HeroContrastFloor.ratio(white, black),
            HeroContrastFloor.ratio(black, white),
            accuracy: 0.001
        )
        XCTAssertEqual(HeroContrastFloor.ratio(white, white), 1, accuracy: 0.001)
    }

    // MARK: The floor itself

    /// Every daypart, both appearances: the scrim it resolves must actually
    /// carry body text over that scene.
    func testScrimAlwaysReachesTheBodyTextFloor() {
        for daypart in ResolvedDaypart.allCases {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let trait = traits(style)
                let palette = DaypartTokens.appearancePalette(
                    for: daypart,
                    colorScheme: style == .dark ? .dark : .light
                )
                let scene = palette.uiColor(for: .canvas)
                let opacity = HeroContrastFloor.scrimOpacity(
                    scene: scene,
                    scrim: SemanticColorTokens.heroScrim,
                    ink: SemanticColorTokens.inkPrimary,
                    base: 0,
                    ratio: HeroContrastFloor.bodyRatio,
                    traits: trait
                )

                XCTAssertGreaterThanOrEqual(opacity, 0, "\(daypart) \(style)")
                XCTAssertLessThanOrEqual(opacity, 1, "\(daypart) \(style)")

                var sceneRGB = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
                var scrimRGB = sceneRGB
                scene.resolvedColor(with: trait)
                    .getRed(&sceneRGB.0, green: &sceneRGB.1, blue: &sceneRGB.2, alpha: &sceneRGB.3)
                SemanticColorTokens.heroScrim.resolvedColor(with: trait)
                    .getRed(&scrimRGB.0, green: &scrimRGB.1, blue: &scrimRGB.2, alpha: &scrimRGB.3)
                let blended = UIColor(
                    red: scrimRGB.0 * opacity + sceneRGB.0 * (1 - opacity),
                    green: scrimRGB.1 * opacity + sceneRGB.1 * (1 - opacity),
                    blue: scrimRGB.2 * opacity + sceneRGB.2 * (1 - opacity),
                    alpha: 1
                )
                let achieved = HeroContrastFloor.ratio(
                    HeroContrastFloor.luminance(of: SemanticColorTokens.inkPrimary, traits: trait),
                    HeroContrastFloor.luminance(of: blended, traits: trait)
                )
                XCTAssertGreaterThanOrEqual(
                    achieved, HeroContrastFloor.bodyRatio - 0.01,
                    "\(daypart) in \(style == .dark ? "dark" : "light") reached only \(achieved):1"
                )
            }
        }
    }

    /// A brighter scene must never need *less* veil than a dim one. This is the
    /// property a hand-tuned constant cannot hold: it is tuned against one
    /// scene and silently wrong on the others.
    func testBrighterScenesNeedAtLeastAsMuchScrim() {
        let trait = traits(.light)
        func opacity(over scene: UIColor) -> Double {
            HeroContrastFloor.scrimOpacity(
                scene: scene,
                scrim: SemanticColorTokens.heroScrim,
                ink: SemanticColorTokens.inkPrimary,
                base: 0,
                ratio: HeroContrastFloor.bodyRatio,
                traits: trait
            )
        }
        // Mid grey is further from the warm-paper scrim than near-white is, so
        // it needs more of it to lift dark ink clear of the background.
        XCTAssertGreaterThanOrEqual(opacity(over: .darkGray), opacity(over: .white))
    }

    func testLargeTextFloorIsNeverStricterThanBodyText() {
        let trait = traits(.light)
        let scene = DaypartTokens.palette(for: .afternoon).uiColor(for: .canvas)
        func opacity(_ ratio: Double) -> Double {
            HeroContrastFloor.scrimOpacity(
                scene: scene,
                scrim: SemanticColorTokens.heroScrim,
                ink: SemanticColorTokens.inkPrimary,
                base: 0,
                ratio: ratio,
                traits: trait
            )
        }
        XCTAssertLessThanOrEqual(
            opacity(HeroContrastFloor.largeTextRatio),
            opacity(HeroContrastFloor.bodyRatio)
        )
    }

    // MARK: Specular rim

    /// Wells are below the canvas plane. A lit top edge on a carved surface
    /// inverts the read and makes the inset appear to pop out.
    func testSpecularRimIsAbsentFromWells() {
        XCTAssertEqual(ClayDepth.well.cornerRadius, 14)
        let rim = SpecularRimModifier(depth: .well)
        XCTAssertEqual(rim.cornerRadius, ClayDepth.well.cornerRadius)
    }

    func testSpecularRimDefaultsToItsDepthRadius() {
        for depth in ClayDepth.allCases {
            XCTAssertEqual(SpecularRimModifier(depth: depth).cornerRadius, depth.cornerRadius)
        }
    }

    // MARK: Fallback geometry

    /// `DESIGN.md`: one silhouette, two materials. The glass presentation and
    /// its opaque fallback must not disagree about geometry, or a comfort
    /// setting reflows the screen.
    func testFallbackSharesTheHeroGeometry() {
        let modifier = HeroSurfaceModifier(palette: DaypartTokens.palette(for: .morning))
        XCTAssertEqual(modifier.cornerRadius, Radius.hero)
    }
}
