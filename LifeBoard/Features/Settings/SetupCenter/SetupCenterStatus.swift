import Foundation

enum SetupCenterConnectorState: Equatable, Sendable {
    case notStarted
    case requested
    case ready
    case attention
    case deferred
}

enum HealthReadAccessState: String, Codable, Sendable {
    case notRequested
    case requestPresented
    case dataAvailable
}

struct HealthAccessState: Equatable, Sendable {
    let readState: HealthReadAccessState
    let writeAuthorizationByCategory: [HealthDomain: [HealthMetric: HealthWriteAuthorization]]

    static func resolve(
        statuses: [HealthDomain: HealthDomainStatus],
        hasObservableData: Bool
    ) -> HealthAccessState {
        let readState: HealthReadAccessState
        if hasObservableData || statuses.values.contains(where: { $0.readRequestState == .receivingData }) {
            readState = .dataAvailable
        } else if statuses.values.contains(where: { $0.readRequestState != .neverRequested }) {
            readState = .requestPresented
        } else {
            readState = .notRequested
        }

        return HealthAccessState(
            readState: readState,
            writeAuthorizationByCategory: Dictionary(uniqueKeysWithValues: statuses.compactMap { domain, status in
                guard domain.supportsWriteBack else { return nil }
                return (domain, status.writeAuthorizations)
            })
        )
    }

    var authorizedWriteCount: Int {
        writeAuthorizationByCategory.values
            .flatMap(\.values)
            .filter { $0 == .authorized }
            .count
    }

    var observableWriteCount: Int {
        writeAuthorizationByCategory.values.flatMap(\.values).count
    }
}

struct SetupCenterStatus: Equatable, Sendable {
    let calendar: SetupCenterConnectorState
    let health: SetupCenterConnectorState
    let reminders: SetupCenterConnectorState
    let eva: SetupCenterConnectorState
    let healthAccess: HealthAccessState

    var allRowsHandled: Bool {
        [calendar, health, reminders, eva].allSatisfy { state in
            switch state {
            case .notStarted: false
            case .requested, .ready, .attention, .deferred: true
            }
        }
    }

    @MainActor
    static func resolve(
        calendarAuthorization: CalendarAuthorizationStatus,
        notificationPermissionRequested: Bool,
        notificationPermissionDenied: Bool,
        healthStatuses: [HealthDomain: HealthDomainStatus],
        healthHasObservableData: Bool,
        evaIsActivated: Bool
    ) -> SetupCenterStatus {
        let healthAccess = HealthAccessState.resolve(
            statuses: healthStatuses,
            hasObservableData: healthHasObservableData
        )
        let calendar: SetupCenterConnectorState = switch calendarAuthorization {
        case .authorized: .ready
        case .notDetermined: .notStarted
        case .denied, .restricted, .writeOnly: .attention
        }
        let health: SetupCenterConnectorState = switch healthAccess.readState {
        case .notRequested: .notStarted
        case .requestPresented: .requested
        case .dataAvailable: .ready
        }
        let reminders: SetupCenterConnectorState
        if notificationPermissionDenied {
            reminders = .attention
        } else if notificationPermissionRequested {
            reminders = .ready
        } else {
            // Permission is intentionally deferred to the first alert-enabled
            // reminder or routine, so Setup Center has no permission task here.
            reminders = .deferred
        }

        return SetupCenterStatus(
            calendar: calendar,
            health: health,
            reminders: reminders,
            eva: evaIsActivated ? .ready : .notStarted,
            healthAccess: healthAccess
        )
    }
}

enum SetupCenterHomeCardPreference {
    static let didChange = Notification.Name("LifeBoardSetupCenterHomeCardPreferenceDidChange")
    private static let dismissalKey = "setup_center.home_card.dismissed.v1"

    static var isDismissed: Bool {
        UserDefaults.standard.bool(forKey: dismissalKey)
    }

    static func dismiss() {
        UserDefaults.standard.set(true, forKey: dismissalKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }

    static func resetForNewOnboarding() {
        UserDefaults.standard.removeObject(forKey: dismissalKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}
