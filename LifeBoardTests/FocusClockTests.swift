import XCTest
@testable import LifeBoard

/// The Focus surface's clock and arc maths.
///
/// This logic used to be two `private` methods on `PlanActiveFocusCard`, so the
/// only way to exercise it was to render the card. Extracting it into `FocusClock`
/// while building the new surface made it directly testable — which matters
/// because the interesting cases are the unbounded modes, where the honest
/// answer is "there is no fraction" and the tempting one is to return 0 or 1.
/// `@MainActor` because `FocusClock` is: it formats through
/// `PlanSectionCopy.duration`, which is main-actor isolated. Annotating the test
/// case is the right side to fix — the alternative is making the copy layer
/// nonisolated to suit a test, which would weaken an invariant the app relies on.
@MainActor
final class FocusClockTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    private func session(
        target: TimeInterval = 1_800,
        state: FocusSessionState = .running
    ) -> FocusSessionV2 {
        FocusSessionV2(targetDuration: target, state: state, startedAt: start)
    }

    private func companion(_ mode: FocusMode, phase: FocusPomodoroPhase? = nil) -> FocusSessionCompanion {
        FocusSessionCompanion(sessionID: UUID(), mode: mode, pomodoroPhase: phase)
    }

    // MARK: Progress

    func testCountdownProgressTracksElapsedFraction() {
        let progress = FocusClock.progress(
            session: session(target: 1_000),
            companion: companion(.countdown(duration: 1_000)),
            at: start.addingTimeInterval(250)
        )
        XCTAssertEqual(try XCTUnwrap(progress), 0.25, accuracy: 0.001)
    }

    /// Unbounded modes have no fraction, and saying so is the point. Returning 0
    /// would draw an empty ring that reads as "no progress"; returning 1 would
    /// read as finished. `nil` draws the track alone.
    func testUnboundedModesReportNoProgress() {
        for mode in [FocusMode.stopwatch, .openEnded] {
            XCTAssertNil(
                FocusClock.progress(
                    session: session(),
                    companion: companion(mode),
                    at: start.addingTimeInterval(600)
                ),
                "\(mode) must not fabricate a fraction"
            )
        }
        // No companion at all is the same situation.
        XCTAssertNil(FocusClock.progress(session: session(), companion: nil, at: start))
    }

    func testCountdownWithNoTargetReportsNoProgress() {
        // Guards a division by zero that would otherwise produce NaN and put the
        // dial's trim into an undefined state.
        XCTAssertNil(
            FocusClock.progress(
                session: session(target: 0),
                companion: companion(.countdown(duration: 0)),
                at: start.addingTimeInterval(60)
            )
        )
    }

    func testProgressIsClampedToTheRing() {
        let overrun = FocusClock.progress(
            session: session(target: 100),
            companion: companion(.countdown(duration: 100)),
            at: start.addingTimeInterval(10_000)
        )
        XCTAssertEqual(try XCTUnwrap(overrun), 1, accuracy: 0.001, "A late session cannot exceed the ring")
    }

    // MARK: Display

    func testCountdownCountsDownRatherThanUp() {
        let display = FocusClock.display(
            session: session(target: 1_000),
            companion: companion(.countdown(duration: 1_000)),
            at: start.addingTimeInterval(400)
        )
        XCTAssertEqual(display.value, 600, accuracy: 0.001)
        XCTAssertTrue(display.showsClock)
        XCTAssertTrue(display.label.contains("remaining"))
    }

    func testExpiredCountdownAsksForADecisionInsteadOfShowingZero() {
        let display = FocusClock.display(
            session: session(target: 100),
            companion: companion(.countdown(duration: 100)),
            at: start.addingTimeInterval(5_000)
        )
        XCTAssertEqual(display.value, 0)
        XCTAssertEqual(display.label, "Time is up. Choose what happens next.")
    }

    func testStopwatchCountsUp() {
        let display = FocusClock.display(
            session: session(),
            companion: companion(.stopwatch),
            at: start.addingTimeInterval(90)
        )
        XCTAssertEqual(display.value, 90, accuracy: 0.001)
        XCTAssertTrue(display.label.contains("elapsed"))
    }

    /// Open-ended focus has no number worth showing, so the dial shows words.
    func testOpenEndedSuppressesTheClock() {
        let display = FocusClock.display(
            session: session(),
            companion: companion(.openEnded),
            at: start.addingTimeInterval(600)
        )
        XCTAssertFalse(display.showsClock)
        XCTAssertTrue(display.label.contains("Open-ended"))
    }

    /// Paused is announced in the dial's accessibility value, not only by the
    /// arc changing tint — DESIGN.md requires state to use text, shape and
    /// colour together.
    func testPausedIsAnnouncedInEveryMode() {
        let modes: [FocusMode] = [.countdown(duration: 1_000), .stopwatch, .openEnded]
        for mode in modes {
            let display = FocusClock.display(
                session: session(state: .paused),
                companion: companion(mode),
                at: start.addingTimeInterval(120)
            )
            XCTAssertTrue(display.label.hasSuffix(", paused"), "\(mode) should announce paused")
        }
    }

    func testRunningSessionsDoNotClaimToBePaused() {
        let display = FocusClock.display(
            session: session(),
            companion: companion(.stopwatch),
            at: start.addingTimeInterval(120)
        )
        XCTAssertFalse(display.label.contains("paused"))
    }
}
