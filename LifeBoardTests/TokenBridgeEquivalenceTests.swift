import XCTest
import SwiftUI
import UIKit
@testable import LifeBoard

/// Proves the legacy colour accessors and their canonical roles resolve to the
/// same colour, so migrating a call site is a rename rather than a redesign.
///
/// Without this, "replace `LifeBoardColorTokens.inkPrimary` with
/// `Color.lifeboard(.textPrimary)`" is a leap of faith across 81 files. With it,
/// any divergence surfaces here as a concrete pair of hex values that somebody
/// decides about deliberately.
@MainActor
final class TokenBridgeEquivalenceTests: XCTestCase {

    private func hex(_ color: UIColor) -> String {
        let c = rgbaComponents(color)
        return String(
            format: "#%02X%02X%02X@%.2f",
            Int((c.red * 255).rounded()),
            Int((c.green * 255).rounded()),
            Int((c.blue * 255).rounded()),
            c.alpha
        )
    }

    func testEveryMappedLegacyTokenMatchesItsCanonicalRole() {
        let appearances: [(UIUserInterfaceStyle, UIAccessibilityContrast, String)] = [
            (.light, .normal, "light"),
            (.dark, .normal, "dark"),
            (.light, .high, "light+contrast"),
            (.dark, .high, "dark+contrast")
        ]

        for entry in TokenBridge.assertableEntries {
            guard let role = entry.role else { continue }
            for (style, contrast, label) in appearances {
                let legacy = resolvedColor(Color(entry.resolve()), style: style, contrast: contrast)
                let canonical = resolvedColor(Color.lifeboard(role), style: style, contrast: contrast)
                XCTAssertEqual(
                    hex(legacy),
                    hex(canonical),
                    """
                    \(entry.legacyName) does not match .\(role.rawValue) in \(label). \
                    Either the mapping is wrong or the two vocabularies have already \
                    drifted — decide which, do not delete the assertion.
                    """
                )
            }
        }
    }

    /// The recorded divergences must stay divergent until somebody
    /// deliberately unifies them.
    ///
    /// Asserting they still differ sounds backwards, but it is the only way the
    /// table stays honest: if a future change makes one of these equal, this
    /// fails and tells you to promote it to an assertable rename rather than
    /// leaving a stale "these differ" note that nobody rereads.
    func testRecordedDivergencesAreStillReal() {
        for entry in TokenBridge.divergentEntries {
            guard let role = entry.role else { continue }
            let appearances: [(UIUserInterfaceStyle, UIAccessibilityContrast)] = [
                (.light, .normal), (.dark, .normal), (.light, .high), (.dark, .high)
            ]
            let stillDiffers = appearances.contains { style, contrast in
                hex(resolvedColor(Color(entry.resolve()), style: style, contrast: contrast))
                    != hex(resolvedColor(Color.lifeboard(role), style: style, contrast: contrast))
            }
            XCTAssertTrue(
                stillDiffers,
                """
                \(entry.legacyName) now matches .\(role.rawValue) everywhere. \
                Add it to LifeBoardTokenBridge.equivalentNames — its migration is now a safe rename.
                """
            )
        }
    }

    func testTheBridgeCoversEveryFoundationStaticColour() {
        // A static in neither list is a token nobody has decided about, which is
        // how a fourth vocabulary starts.
        XCTAssertEqual(
            TokenBridge.mappedCount + TokenBridge.unmappedCount,
            TokenBridge.foundationEntries.count
        )
        XCTAssertGreaterThan(TokenBridge.mappedCount, 0)
        XCTAssertEqual(
            TokenBridge.divergentEntries.count, 9,
            """
            Measured 2026-08-03: of 13 statics with a role, 4 resolve identically after \
            the hairline and focus accessibility defects were corrected. A change here \
            means the palette moved — read the notes, do not just bump the number.
            """
        )
    }

    /// The redesign brief specifies `ink.secondary #746757` and
    /// `ink.tertiary #9B8F7E`. Both were measured and rejected — 4.446:1 against
    /// the 4.5:1 body floor, and ~2.95:1 against the 3:1 non-text floor. This
    /// pins the rejection so a future "align with the design doc" pass cannot
    /// quietly reintroduce them.
    func testInkTokensStayAboveTheContrastFloorsTheBriefWouldHaveBroken() {
        let canvas = resolvedColor(Color.lifeboard(.bgCanvas), style: .light)
        let secondary = resolvedColor(Color.lifeboard(.textSecondary), style: .light)
        let tertiary = resolvedColor(Color.lifeboard(.textTertiary), style: .light)

        XCTAssertGreaterThanOrEqual(
            contrastRatio(secondary, canvas), 4.5,
            "Secondary ink carries body copy and must clear the 4.5:1 floor"
        )
        XCTAssertGreaterThanOrEqual(
            contrastRatio(tertiary, canvas), 3.0,
            "Tertiary ink is non-essential metadata but must still clear 3:1"
        )
    }
}
