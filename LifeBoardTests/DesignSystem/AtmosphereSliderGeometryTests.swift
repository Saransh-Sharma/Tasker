import XCTest
@testable import LifeBoard

/// The atmosphere slider's stops are deliberately uneven — Auto owns a wider
/// lane than any daypart — so none of this is checkable by eye. A lane that is
/// one point off, or an RTL mirror applied to the touch but not the knob, looks
/// perfectly fine on screen and puts the wrong daypart under the finger.
final class AtmosphereSliderGeometryTests: XCTestCase {
    private typealias Geometry = AtmosphereSliderGeometry

    private let width: CGFloat = 323 // a 375pt phone inside the panel's margins

    func testAutoStopIsCentredInItsOwnWiderLane() {
        let centers = Geometry.stopCenters(innerWidth: width)
        XCTAssertEqual(centers.count, Geometry.stopCount)
        XCTAssertEqual(centers[0], Geometry.autoLaneWidth / 2, accuracy: 0.001)
    }

    func testDaypartStopsAreEvenlySpacedAmongThemselves() {
        let centers = Geometry.stopCenters(innerWidth: width)
        let gaps = zip(centers.dropFirst(), centers.dropFirst(2)).map { $1 - $0 }
        let quarter = Geometry.dayLaneWidth(innerWidth: width) / 4
        for gap in gaps {
            XCTAssertEqual(gap, quarter, accuracy: 0.001)
        }
    }

    /// The gap between Auto and morning is wider than the gap between two
    /// dayparts. If this ever equalises, the "styled apart" lane has silently
    /// become an ordinary stop.
    func testAutoIsFurtherFromMorningThanDaypartsAreFromEachOther() {
        let centers = Geometry.stopCenters(innerWidth: width)
        let autoToMorning = centers[1] - centers[0]
        let morningToAfternoon = centers[2] - centers[1]
        XCTAssertGreaterThan(autoToMorning, morningToAfternoon)
    }

    func testEveryStopCentreResolvesBackToItsOwnIndex() {
        let centers = Geometry.stopCenters(innerWidth: width)
        for (index, center) in centers.enumerated() {
            XCTAssertEqual(
                Geometry.index(atX: center, innerWidth: width, isRTL: false),
                index,
                "stop \(index) at x=\(center) did not resolve to itself"
            )
        }
    }

    /// A touch in the separator gap belongs to whichever side is closer, never
    /// to nothing and never to a jump across the track.
    func testTouchInSeparatorGapResolvesToTheNearerNeighbour() {
        let leadingEdgeOfGap = Geometry.autoLaneWidth + 1
        XCTAssertEqual(Geometry.index(atX: leadingEdgeOfGap, innerWidth: width, isRTL: false), 0)

        let trailingEdgeOfGap = Geometry.dayLaneOrigin() - 1
        let resolved = Geometry.index(atX: trailingEdgeOfGap, innerWidth: width, isRTL: false)
        XCTAssertTrue(resolved == 0 || resolved == 1)
    }

    func testTouchesBeyondEitherEndClampToTheEndStops() {
        XCTAssertEqual(Geometry.index(atX: -400, innerWidth: width, isRTL: false), 0)
        XCTAssertEqual(Geometry.index(atX: width + 400, innerWidth: width, isRTL: false), 4)
    }

    // MARK: Right-to-left

    func testRightToLeftMirrorsStopPositions() {
        for index in 0..<Geometry.stopCount {
            let ltr = Geometry.x(forIndex: index, innerWidth: width, isRTL: false)
            let rtl = Geometry.x(forIndex: index, innerWidth: width, isRTL: true)
            XCTAssertEqual(ltr + rtl, width, accuracy: 0.001)
        }
    }

    /// The mirror has to be applied to reading a touch *and* to placing the
    /// knob. Applying it to only one is the failure this catches: the knob
    /// would land at the opposite end of the track from the finger.
    func testRightToLeftTouchAndKnobAgree() {
        for index in 0..<Geometry.stopCount {
            let knobX = Geometry.x(forIndex: index, innerWidth: width, isRTL: true)
            XCTAssertEqual(
                Geometry.index(atX: knobX, innerWidth: width, isRTL: true),
                index
            )
        }
    }

    func testRightToLeftPutsAutoOnTheTrailingSide() {
        let auto = Geometry.x(forIndex: 0, innerWidth: width, isRTL: true)
        let night = Geometry.x(forIndex: 4, innerWidth: width, isRTL: true)
        XCTAssertGreaterThan(auto, night)
    }

    // MARK: Degenerate widths

    func testZeroWidthDoesNotDivideByZeroOrCrash() {
        XCTAssertEqual(Geometry.dayLaneWidth(innerWidth: 0), 0)
        XCTAssertEqual(Geometry.index(atX: 10, innerWidth: 0, isRTL: false), 0)
        XCTAssertEqual(Geometry.stopCenters(innerWidth: 0).count, Geometry.stopCount)
    }

    func testWidthNarrowerThanTheAutoLaneStillProducesOrderedStops() {
        let centers = Geometry.stopCenters(innerWidth: 20)
        XCTAssertEqual(centers.count, Geometry.stopCount)
        XCTAssertEqual(centers, centers.sorted())
    }

    /// The day lane needs four 44pt targets. Below this the caller must fall
    /// back to the row list rather than shipping 30pt taps.
    func testMinimumInnerWidthGivesEveryDaypartAFullTouchTarget() {
        let quarter = Geometry.dayLaneWidth(innerWidth: Geometry.minimumInnerWidth) / 4
        XCTAssertGreaterThanOrEqual(quarter, 44)
    }

    // MARK: Gradient

    func testGradientStopsSitOnTheirOwnDetentsAndStayInUnitRange() {
        let locations = Geometry.dayGradientLocations(innerWidth: width)
        XCTAssertEqual(locations.count, 4)
        XCTAssertEqual(locations, locations.sorted())
        for location in locations {
            XCTAssertGreaterThanOrEqual(location, 0)
            XCTAssertLessThanOrEqual(location, 1)
        }
        // Each daypart peaks in the middle of its own quarter.
        XCTAssertEqual(locations[0], 0.125, accuracy: 0.001)
        XCTAssertEqual(locations[3], 0.875, accuracy: 0.001)
    }
}
