import XCTest
@testable import LifeBoard

/// The ambient-motion budget `DESIGN.md` states normatively and the code did
/// not express at all.
///
/// The document is explicit — one ambient timeline per screen, 30fps or fewer,
/// amplitude at or below 2% — and closes with "Ambient motion that cannot state
/// its envelope is not ambient motion; it is a distraction, and it does not
/// ship." Before this there was no constant, no clamp, no claim and no test,
/// while the neighbouring hero rule had a full environment-key mechanism.
@MainActor
final class AmbientMotionBudgetTests: XCTestCase {

    func testAmplitudeCeilingMatchesTheContract() {
        XCTAssertEqual(AmbientMotionBudget.maximumAmplitudeFraction, 0.02)
        XCTAssertEqual(AmbientMotionBudget.maximumFrameRate, 30)
    }

    /// 2% is meaningless without the dimension it is 2% *of*, which is how an
    /// "ambient" effect ends up displacing a 40-point element by 12 points.
    func testAmplitudeIsClampedRelativeToTheElement() {
        XCTAssertEqual(AmbientMotionBudget.clampAmplitude(12, of: 40), 0.8, accuracy: 0.0001)
        XCTAssertEqual(AmbientMotionBudget.clampAmplitude(1, of: 400), 1, accuracy: 0.0001)
        XCTAssertEqual(AmbientMotionBudget.clampAmplitude(100, of: 100), 2, accuracy: 0.0001)
    }

    func testClampPreservesDirection() {
        XCTAssertEqual(AmbientMotionBudget.clampAmplitude(-12, of: 40), -0.8, accuracy: 0.0001)
        XCTAssertEqual(AmbientMotionBudget.clampAmplitude(0, of: 40), 0, accuracy: 0.0001)
    }

    /// A zero dimension has no 2%, so nothing may move.
    func testDegenerateDimensionYieldsNoMotion() {
        XCTAssertEqual(AmbientMotionBudget.clampAmplitude(50, of: 0), 0, accuracy: 0.0001)
    }
}
