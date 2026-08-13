import XCTest
import LifeBoardUI

/// The resistance curve shared by the magnetic toggle, the composer over-scroll
/// and the directional deck.
///
/// It is pure and synchronous specifically so it can be pinned here rather than
/// inferred from watching a gesture — the properties below are the ones a
/// reviewer would otherwise have to take on faith.
final class RubberBandTests: XCTestCase {
    func testTravelInsideTheLimitIsUntouched() {
        // Inside the detent the object must track the finger exactly, or the
        // gesture feels laggy rather than resistant.
        XCTAssertEqual(RubberBand.offset(0, limit: 100), 0)
        XCTAssertEqual(RubberBand.offset(50, limit: 100), 50)
        XCTAssertEqual(RubberBand.offset(100, limit: 100), 100)
    }

    func testTravelBeyondTheLimitIsCompressedButNotStopped() {
        let past = RubberBand.offset(300, limit: 100)
        XCTAssertGreaterThan(past, 100, "A hard stop at the limit reads as a broken gesture")
        XCTAssertLessThan(past, 300, "Past the limit must resist")
    }

    func testCompressionIsMonotonicAndBounded() {
        // Further always means further — a curve that folds back would make the
        // object move against the finger.
        var previous = RubberBand.offset(100, limit: 100)
        for raw in stride(from: CGFloat(120), through: 4000, by: 40) {
            let value = RubberBand.offset(raw, limit: 100)
            XCTAssertGreaterThanOrEqual(value, previous)
            previous = value
        }
        // And the tail must stay flat enough that a surface cannot be dragged
        // off screen no matter how far the finger travels.
        XCTAssertLessThan(RubberBand.offset(10_000, limit: 100), 220)
    }

    func testResistanceIsSymmetricAroundZero() {
        XCTAssertEqual(RubberBand.offset(-300, limit: 100), -RubberBand.offset(300, limit: 100))
    }

    func testZeroResistanceClampsAtTheLimit() {
        XCTAssertEqual(RubberBand.offset(500, limit: 100, resistance: 0), 100)
    }

    func testNonPositiveLimitIsInert() {
        // Guards a division that would otherwise produce NaN and silently
        // corrupt every offset downstream of it.
        XCTAssertEqual(RubberBand.offset(50, limit: 0), 0)
        XCTAssertEqual(RubberBand.offset(50, limit: -10), 0)
    }

    func testProgressReportsDirectionMeaningBeforeTheThreshold() {
        // DESIGN.md requires a drag to "reveal direction meaning before
        // threshold", which needs a fraction rather than a crossed/not-crossed
        // boolean.
        XCTAssertEqual(RubberBand.progress(0, threshold: 100), 0)
        XCTAssertEqual(RubberBand.progress(50, threshold: 100), 0.5)
        XCTAssertEqual(RubberBand.progress(100, threshold: 100), 1)
        XCTAssertEqual(RubberBand.progress(400, threshold: 100), 1, "Clamped")
        XCTAssertEqual(RubberBand.progress(-50, threshold: 100), 0.5, "Direction-agnostic")
        XCTAssertEqual(RubberBand.progress(50, threshold: 0), 0)
    }
}
