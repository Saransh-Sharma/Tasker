import XCTest
@testable import LifeBoard

/// The hero's ranking, exercised without a simulator.
///
/// Setup Center's hero is whatever `SetupCenterFocus.resolve` nominates, so the
/// decision the screen exists to present is a pure function and is tested here
/// rather than by looking at it.
final class SetupCenterFocusTests: XCTestCase {

    private func status(
        calendar: SetupCenterConnectorState = .ready,
        health: SetupCenterConnectorState = .ready,
        reminders: SetupCenterConnectorState = .deferred,
        eva: SetupCenterConnectorState = .ready,
        readState: HealthReadAccessState = .dataAvailable
    ) -> SetupCenterStatus {
        SetupCenterStatus(
            calendar: calendar,
            health: health,
            reminders: reminders,
            eva: eva,
            healthAccess: HealthAccessState(
                readState: readState,
                writeAuthorizationByCategory: [:]
            )
        )
    }

    // MARK: - Ranking

    func testBrokenConnectionOutranksOneNeverStarted() {
        // Calendar denied *and* EVA never set up: the thing that stopped working
        // is the more useful thing to say, because the person already asked for it.
        let focus = SetupCenterFocus.resolve(status(calendar: .attention, eva: .notStarted))

        XCTAssertEqual(focus.target, .calendar)
        XCTAssertEqual(focus.title, "Calendar needs attention")
    }

    func testEvaOutranksOtherUnstartedConnectors() {
        let focus = SetupCenterFocus.resolve(status(calendar: .notStarted, health: .notStarted, eva: .notStarted))

        XCTAssertEqual(focus.target, .eva)
    }

    func testCalendarOutranksHealthWhenBothUnstarted() {
        let focus = SetupCenterFocus.resolve(status(calendar: .notStarted, health: .notStarted))

        XCTAssertEqual(focus.target, .calendar)
    }

    // MARK: - Honest states

    func testRequestedHealthIsNotReportedAsComplete() {
        // Apple never reveals a read denial. Counting "requested" as done would
        // be inferring completion from missing evidence.
        let focus = SetupCenterFocus.resolve(status(health: .requested, readState: .requestPresented))

        XCTAssertEqual(focus.target, .health)
        XCTAssertNotNil(focus.primaryTitle)
    }

    func testDeferredRemindersNeverBecomeTheFocus() {
        // Notification permission is deliberately deferred to the first alert,
        // so it is not a task and must not be presented as one.
        let focus = SetupCenterFocus.resolve(status(reminders: .deferred))

        XCTAssertEqual(focus.target, .complete)
    }

    func testDeniedRemindersDoBecomeTheFocus() {
        let focus = SetupCenterFocus.resolve(status(reminders: .attention))

        XCTAssertEqual(focus.target, .reminders)
    }

    // MARK: - Withdrawal

    func testCompleteStateOffersNoPrimaryAction() {
        // The hero is withdrawn when there is nothing to decide; a hero with no
        // action is a card, and the screen becomes clay throughout.
        let focus = SetupCenterFocus.resolve(status())

        XCTAssertEqual(focus.target, .complete)
        XCTAssertNil(focus.primaryTitle)
        XCTAssertNil(focus.alternativeTitle)
    }

    // MARK: - Budget

    func testStatusIsOneLineAndCountsOnlyConnected() {
        let focus = SetupCenterFocus.resolve(status(calendar: .ready, health: .notStarted, reminders: .deferred, eva: .ready))

        XCTAssertEqual(focus.status, "2 of 4 connected")
        XCTAssertFalse(focus.status.contains("\n"))
    }

    func testEveryFocusFillsTheHeroBudgetExactlyOnce() {
        // One title, one line of context, one status. A hero that grew a second
        // metric has become a dashboard.
        let cases = [
            status(calendar: .attention),
            status(reminders: .attention),
            status(health: .attention),
            status(eva: .notStarted),
            status(calendar: .notStarted),
            status(health: .notStarted),
            status(health: .requested, readState: .requestPresented),
            status()
        ]

        for state in cases {
            let focus = SetupCenterFocus.resolve(state)
            XCTAssertFalse(focus.title.isEmpty)
            XCTAssertFalse(focus.context.isEmpty)
            XCTAssertFalse(focus.context.contains("\n"), "context must stay one line")
            XCTAssertEqual(focus.status, focus.status.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
