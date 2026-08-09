import XCTest
import SwiftUI
import UIKit
@testable import LifeBoard

/// The accessibility guarantees that can be checked without a running screen.
///
/// Deliberately narrow. Truncation at AX5, focus traversal order and real touch
/// geometry need a device and belong in `LifeBoardUITests`; what lives here is
/// the set of properties a new token, profile or widget kind could silently
/// break without anyone noticing until someone with that setting turned on
/// opened the app.
@MainActor
final class AccessibilityContractTests: XCTestCase {

    // MARK: - Contrast

    /// Every (ink, surface) pair the app actually composes, in all four
    /// appearances.
    ///
    /// `LifeOSFoundationTests` checked exactly one pair out of roughly twenty.
    /// The gap mattered: the foundation statics and the semantic roles are two
    /// different palettes (see `TokenBridge`), so a pair that passes on
    /// one vocabulary says nothing about the other.
    func testInkOverSurfaceContrastClearsWCAGInEveryAppearance() {
        let inks: [(String, UIColor, CGFloat)] = [
            // 4.5:1 is the body-text floor; tertiary is metadata-only at 3:1.
            ("inkPrimary", LifeBoardColorTokens.inkPrimary, 4.5),
            ("inkSecondary", LifeBoardColorTokens.inkSecondary, 4.5),
            ("inkTertiary", LifeBoardColorTokens.inkTertiary, 3.0)
        ]
        let surfaces: [(String, UIColor)] = [
            ("foundationCanvas", LifeBoardColorTokens.foundationCanvas),
            ("foundationCanvasSoft", LifeBoardColorTokens.foundationCanvasSoft),
            ("foundationCanvasMuted", LifeBoardColorTokens.foundationCanvasMuted),
            ("foundationSurfaceSolid", LifeBoardColorTokens.foundationSurfaceSolid),
            ("foundationSurfaceRecessed", LifeBoardColorTokens.foundationSurfaceRecessed),
            ("foundationSurfaceSelected", LifeBoardColorTokens.foundationSurfaceSelected)
        ]
        let appearances: [(UIUserInterfaceStyle, UIAccessibilityContrast, String)] = [
            (.light, .normal, "light"),
            (.dark, .normal, "dark"),
            (.light, .high, "light+contrast"),
            (.dark, .high, "dark+contrast")
        ]

        for (inkName, ink, floor) in inks {
            for (surfaceName, surface) in surfaces {
                for (style, contrast, label) in appearances {
                    let foreground = resolvedColor(Color(ink), style: style, contrast: contrast)
                    let background = resolvedColor(Color(surface), style: style, contrast: contrast)
                    let ratio = contrastRatio(foreground, background)
                    XCTAssertGreaterThanOrEqual(
                        ratio, floor,
                        "\(inkName) on \(surfaceName) is \(String(format: "%.2f", ratio)):1 in \(label), below \(floor):1"
                    )
                }
            }
        }
    }

    /// Increased Contrast must not be a no-op.
    ///
    /// A token that resolves identically at both contrast settings is not
    /// necessarily wrong — plenty already clear the floor — but the *primary*
    /// ink over the *primary* canvas is the pairing the setting exists for.
    func testIncreasedContrastNeverWeakensPrimaryInk() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let normal = contrastRatio(
                resolvedColor(Color(LifeBoardColorTokens.inkPrimary), style: style, contrast: .normal),
                resolvedColor(Color(LifeBoardColorTokens.foundationCanvas), style: style, contrast: .normal)
            )
            let high = contrastRatio(
                resolvedColor(Color(LifeBoardColorTokens.inkPrimary), style: style, contrast: .high),
                resolvedColor(Color(LifeBoardColorTokens.foundationCanvas), style: style, contrast: .high)
            )
            XCTAssertGreaterThanOrEqual(
                high, normal,
                "Increased Contrast made primary ink *worse* in \(style == .light ? "light" : "dark")"
            )
        }
    }

    // MARK: - Reduce Motion

    /// No motion profile may ignore Reduce Motion.
    ///
    /// The resolver funnels every profile through one guard today, but the
    /// switch is per-case — a new profile added below that guard, or one that
    /// returns a literal animation, would silently animate for someone who
    /// asked the system not to.
    func testEveryMotionProfileRespectsReduceMotion() {
        for profile in MotionProfile.allCases {
            XCTAssertNil(
                profile.animation(reduceMotion: true),
                "\(profile) still animates under Reduce Motion"
            )
        }
    }

    func testMotionProfilesDoAnimateWhenReduceMotionIsOff() {
        // The mirror of the above: a resolver that returned nil unconditionally
        // would pass the Reduce Motion test while disabling the whole app.
        let animated = MotionProfile.allCases.filter {
            $0.animation(reduceMotion: false) != nil
        }
        XCTAssertFalse(
            animated.isEmpty,
            "No profile animates at all — the Reduce Motion guard is swallowing everything"
        )
    }

    // MARK: - Note on what is NOT here
    //
    // Dynamic Type truncation, focus traversal order and real 44pt touch
    // geometry are deliberately absent: none is decidable without a rendered
    // screen, and an assertion that only checks "the enum case exists" would
    // read as coverage while proving nothing. Those belong in LifeBoardUITests
    // against a seeded simulator.
}
