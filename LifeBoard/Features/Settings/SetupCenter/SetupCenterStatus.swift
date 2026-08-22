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

/// Which connector Setup Center is asking about right now.
enum SetupCenterFocusTarget: Equatable, Sendable {
    case calendar
    case health
    case reminders
    case eva
    /// Nothing is left to ask for. The screen keeps its shape and loses its hero.
    case complete
}

/// The one thing Setup Center is for, resolved from the connector states.
///
/// `SetupCenterStatus` already knew everything needed to answer "what should I
/// do next?", but nothing consumed it beyond tinting four glyphs, so the screen
/// presented four equal-weight cards and left the ranking to the reader.
/// `DESIGN.md` gives a hero a fixed budget — one title, one line of context, one
/// truthful status, one primary action and at most one quiet alternative — and
/// this is that budget as a value, so the ranking is testable without a
/// simulator and the view cannot invent a second metric.
struct SetupCenterFocus: Equatable, Sendable {
    let target: SetupCenterFocusTarget
    let title: String
    let context: String
    /// One status line. Never four chips — that is the dashboard the hero rule
    /// exists to prevent.
    let status: String
    /// `nil` only when there is nothing left to do.
    let primaryTitle: String?
    let alternativeTitle: String?

    static func resolve(_ status: SetupCenterStatus) -> SetupCenterFocus {
        let connected = [status.calendar, status.health, status.reminders, status.eva]
            .filter { $0 == .ready }
            .count
        let summary = "\(connected) of 4 connected"

        // A connection that broke outranks one that was never started: the
        // person already asked for this and it has stopped working.
        if status.calendar == .attention {
            return SetupCenterFocus(
                target: .calendar,
                title: "Calendar needs attention",
                context: "LifeBoard cannot read your events, so plans are being made around a day that looks empty.",
                status: summary,
                primaryTitle: "Review calendar access",
                alternativeTitle: nil
            )
        }
        if status.reminders == .attention {
            return SetupCenterFocus(
                target: .reminders,
                title: "Reminders can't alert you",
                context: "Notifications are turned off, so reminders you create will stay silent.",
                status: summary,
                primaryTitle: "Open Reminders",
                alternativeTitle: nil
            )
        }
        if status.health == .attention {
            return SetupCenterFocus(
                target: .health,
                title: "Apple Health needs attention",
                context: "LifeBoard cannot read the categories you approved.",
                status: summary,
                primaryTitle: "Review Health settings",
                alternativeTitle: nil
            )
        }

        // Then what has never been started, EVA first: it changes more about how
        // the app behaves than any single data connection.
        if status.eva == .notStarted {
            return SetupCenterFocus(
                target: .eva,
                title: "Set up EVA",
                context: "EVA can plan with the categories you approve, and nothing else.",
                status: summary,
                primaryTitle: "Continue with Cloud EVA",
                alternativeTitle: "Not now"
            )
        }
        if status.calendar == .notStarted {
            return SetupCenterFocus(
                target: .calendar,
                title: "Connect your calendar",
                context: "Seeing real events is what lets LifeBoard plan around the day you actually have.",
                status: summary,
                primaryTitle: "Connect Calendar",
                alternativeTitle: nil
            )
        }
        if status.health == .notStarted {
            return SetupCenterFocus(
                target: .health,
                title: "Connect Apple Health",
                context: "Bring wellness context in, and send supported entries back.",
                status: summary,
                primaryTitle: "Review Health access",
                alternativeTitle: nil
            )
        }

        // Requested but nothing observed. Apple never reveals a read denial, so
        // this is reported as what it is rather than quietly counted as done —
        // completion must not be inferred from missing evidence.
        if status.health == .requested {
            return SetupCenterFocus(
                target: .health,
                title: "Apple Health hasn't shared anything yet",
                context: "Access was requested. LifeBoard reports data only once it actually sees some.",
                status: summary,
                primaryTitle: "Review Health settings",
                alternativeTitle: nil
            )
        }

        // Reminders sitting at `.deferred` is deliberate and is not a task, so
        // it never becomes the focus — see `resolve(...)` above.
        return SetupCenterFocus(
            target: .complete,
            title: "Everything you chose is connected",
            context: "Come back from Settings whenever something changes.",
            status: summary,
            primaryTitle: nil,
            alternativeTitle: nil
        )
    }
}

extension SetupCenterConnectorState {
    /// Presentation of a connector state, kept beside the state it describes.
    ///
    /// These were three `private func`s on the view, which is what made the
    /// connector card a generic `@ViewBuilder` taking a state it then had to
    /// re-interpret. They are properties of the state, not of the screen.
    var symbolName: String {
        switch self {
        case .ready: "checkmark.circle.fill"
        case .attention: "exclamationmark.triangle.fill"
        case .requested: "checkmark.circle"
        case .deferred: "clock"
        case .notStarted: "circle"
        }
    }

    /// Always rendered as text beside the glyph. `DESIGN.md` is explicit that
    /// colour alone must never communicate state, and the previous presentation
    /// carried it in a tint and a VoiceOver label only — invisible to a sighted
    /// person who cannot distinguish the tints.
    var label: String {
        switch self {
        case .ready: "Ready"
        case .attention: "Needs attention"
        case .requested: "Access requested"
        case .deferred: "Deferred until needed"
        case .notStarted: "Not started"
        }
    }

    var tone: SettingsTone {
        switch self {
        case .ready: .success
        case .attention: .warning
        case .requested, .deferred, .notStarted: .accent
        }
    }
}
