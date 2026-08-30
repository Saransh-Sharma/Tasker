import XCTest
@testable import LifeBoard

final class SetupCenterFocusTests: XCTestCase {
    private func snapshot(_ integration: SetupCenterIntegration, _ state: SetupCenterConnectorState) -> SetupCenterIntegrationSnapshot {
        .init(integration: integration, state: state, status: "Status", explanation: "Detail", recoveryAction: "Action")
    }

    private func status(
        calendar: SetupCenterConnectorState = .ready,
        health: SetupCenterConnectorState = .ready,
        eva: SetupCenterConnectorState = .ready
    ) -> SetupCenterStatus {
        .init(calendar: snapshot(.calendar, calendar), health: snapshot(.health, health), eva: snapshot(.eva, eva))
    }

    func testBrokenIntegrationOutranksNewSetup() {
        XCTAssertEqual(status(calendar: .attention, eva: .notStarted).recommendedNextAction, .calendar)
    }

    func testUnstartedPriorityIsCalendarThenHealthThenEva() {
        XCTAssertEqual(status(calendar: .notStarted, health: .notStarted, eva: .notStarted).recommendedNextAction, .calendar)
        XCTAssertEqual(status(health: .notStarted, eva: .notStarted).recommendedNextAction, .health)
        XCTAssertEqual(status(eva: .notStarted).recommendedNextAction, .eva)
    }

    func testWaitingHealthIsHandledAndSkipped() {
        let value = status(health: .waiting)
        XCTAssertTrue(value.allRowsHandled)
        XCTAssertNil(value.recommendedNextAction)
    }

    func testTruthfulSummarySeparatesReadyWaitingAndActionable() {
        XCTAssertEqual(status(calendar: .ready, health: .waiting, eva: .notStarted).summary, "3 integrations · 1 ready · 1 waiting · 1 to set up")
    }

    func testOfflineEvaRequiresUsableInstalledModel() {
        let missing = SetupCenterStatus.resolve(
            calendarAuthorization: .authorized,
            selectedCalendarCount: 1,
            healthStatuses: [:],
            healthHasObservableData: true,
            evaAccessState: .needsDisclosure,
            evaUsesOfflineProvider: true,
            offlineModelReady: false
        )
        let ready = SetupCenterStatus.resolve(
            calendarAuthorization: .authorized,
            selectedCalendarCount: 1,
            healthStatuses: [:],
            healthHasObservableData: true,
            evaAccessState: .needsDisclosure,
            evaUsesOfflineProvider: true,
            offlineModelReady: true
        )
        XCTAssertEqual(missing.eva.state, .attention)
        XCTAssertEqual(ready.eva.status, "Offline ready")
    }

    func testCalendarAuthorizationWithoutSelectionIsNotReady() {
        let value = SetupCenterStatus.resolve(
            calendarAuthorization: .authorized,
            selectedCalendarCount: 0,
            healthStatuses: [:],
            healthHasObservableData: false,
            evaAccessState: .needsDisclosure,
            evaUsesOfflineProvider: false,
            offlineModelReady: false
        )
        XCTAssertEqual(value.calendar.state, .actionRequired)
        XCTAssertEqual(value.calendar.status, "Choose calendars")
        XCTAssertEqual(value.calendar.recoveryActionKind, .chooseCalendars)
    }

    func testStaleCalendarSelectionsDoNotCountAsUsable() {
        XCTAssertEqual(
            SetupCenterStatus.validCalendarSelectionCount(
                selectedIDs: ["deleted-calendar", "work"],
                availableIDs: ["work", "personal"]
            ),
            1
        )
        XCTAssertEqual(
            SetupCenterStatus.validCalendarSelectionCount(
                selectedIDs: ["deleted-calendar"],
                availableIDs: ["work", "personal"]
            ),
            0
        )
    }

    func testRequestedHealthIsWaitingNotProofOfAccess() {
        let health = HealthDomainStatus(domain: .activity, readRequestState: .requestCompleted, signal: .noRecord)
        let value = SetupCenterStatus.resolve(
            calendarAuthorization: .authorized,
            selectedCalendarCount: 1,
            healthStatuses: [.activity: health],
            healthHasObservableData: false,
            evaAccessState: .ready,
            evaUsesOfflineProvider: false,
            offlineModelReady: false
        )
        XCTAssertEqual(value.health.state, .waiting)
        XCTAssertEqual(value.health.status, "Access requested")
        XCTAssertEqual(value.health.recoveryActionKind, .syncHealth)
    }

    func testEnabledDeniedHealthWriteIsActionable() {
        let health = HealthDomainStatus(
            domain: .hydration,
            readRequestState: .requestCompleted,
            writeAuthorizations: [.water: .denied],
            writeEnabled: true,
            signal: .writeDenied
        )
        let value = SetupCenterStatus.resolve(
            calendarAuthorization: .authorized,
            selectedCalendarCount: 1,
            healthStatuses: [.hydration: health],
            healthHasObservableData: false,
            evaAccessState: .ready,
            evaUsesOfflineProvider: false,
            offlineModelReady: false
        )
        XCTAssertEqual(value.health.state, .attention)
        XCTAssertEqual(value.health.recoveryActionKind, .openSystemSettings)
    }
}
