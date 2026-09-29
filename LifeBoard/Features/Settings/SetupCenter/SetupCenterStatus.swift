import Foundation

enum HealthReadAccessState: String, Codable, Sendable { case notRequested, requestPresented, dataAvailable }

struct HealthAccessState: Equatable, Sendable {
    let readState: HealthReadAccessState
    let writeAuthorizationByCategory: [HealthDomain: [HealthMetric: HealthWriteAuthorization]]
    static func resolve(statuses: [HealthDomain: HealthDomainStatus], hasObservableData: Bool) -> HealthAccessState {
        let values = Array(statuses.values)
        let readState: HealthReadAccessState = hasObservableData
            ? .dataAvailable : (values.contains(where: { $0.readRequestState != .neverRequested }) ? .requestPresented : .notRequested)
        return .init(readState: readState, writeAuthorizationByCategory: Dictionary(uniqueKeysWithValues: statuses.compactMap { domain, status in
            domain.supportsWriteBack ? (domain, status.writeAuthorizations) : nil
        }))
    }
    var authorizedWriteCount: Int { writeAuthorizationByCategory.values.flatMap(\.values).filter { $0 == .authorized }.count }
}

enum SetupCenterIntegration: String, CaseIterable, Identifiable, Hashable, Sendable {
    case calendar, health, eva
    var id: String { rawValue }
}

enum SetupCenterConnectorState: Equatable, Sendable {
    case notStarted, actionRequired, checking, waiting, ready, limited, attention

    var isHandled: Bool {
        switch self {
        case .checking, .waiting, .ready, .limited: true
        case .notStarted, .actionRequired, .attention: false
        }
    }
    var isReady: Bool { self == .ready || self == .limited }
    var isWaiting: Bool { self == .checking || self == .waiting }
    var symbolName: String {
        switch self {
        case .ready: "checkmark.circle.fill"
        case .limited: "gauge.with.dots.needle.33percent"
        case .attention: "exclamationmark.triangle.fill"
        case .checking: "arrow.triangle.2.circlepath"
        case .waiting: "clock"
        case .actionRequired: "arrow.right.circle"
        case .notStarted: "circle"
        }
    }
    var tone: SettingsTone {
        switch self {
        case .ready: .success
        case .limited, .attention: .warning
        case .notStarted, .actionRequired, .checking, .waiting: .accent
        }
    }
}

enum SetupCenterRecoveryAction: Equatable, Sendable {
    case none
    case requestCalendarAccess
    case chooseCalendars
    case refreshCalendars
    case openSystemSettings
    case requestHealthAccess
    case syncHealth
    case manageHealthAccess
}

struct SetupCenterIntegrationSnapshot: Equatable, Sendable, Identifiable {
    let integration: SetupCenterIntegration
    let state: SetupCenterConnectorState
    let status: String
    let explanation: String
    let recoveryAction: String
    let recoveryActionKind: SetupCenterRecoveryAction
    var id: SetupCenterIntegration { integration }

    init(
        integration: SetupCenterIntegration,
        state: SetupCenterConnectorState,
        status: String,
        explanation: String,
        recoveryAction: String,
        recoveryActionKind: SetupCenterRecoveryAction = .none
    ) {
        self.integration = integration
        self.state = state
        self.status = status
        self.explanation = explanation
        self.recoveryAction = recoveryAction
        self.recoveryActionKind = recoveryActionKind
    }
}

struct SetupCenterStatus: Equatable, Sendable {
    let calendar: SetupCenterIntegrationSnapshot
    let health: SetupCenterIntegrationSnapshot
    let eva: SetupCenterIntegrationSnapshot

    var snapshots: [SetupCenterIntegrationSnapshot] { [calendar, health, eva] }
    var allRowsHandled: Bool { snapshots.allSatisfy(\.state.isHandled) }
    var summary: String {
        let ready = snapshots.filter(\.state.isReady).count
        let waiting = snapshots.filter(\.state.isWaiting).count
        return String(localized: "\(ready) ready · \(waiting) waiting · \(3 - ready - waiting) to set up")
    }
    var recommendedNextAction: SetupCenterIntegration? {
        snapshots.first(where: { $0.state == .attention })?.integration
            ?? snapshots.first(where: { $0.state == .notStarted || $0.state == .actionRequired })?.integration
    }

    static func validCalendarSelectionCount(selectedIDs: [String], availableIDs: [String]) -> Int {
        Set(selectedIDs).intersection(availableIDs).count
    }

    static func secondaryEvaErrorMessage(
        _ errorMessage: String?,
        explanation: String
    ) -> String? {
        guard let errorMessage else { return nil }
        let sanitizedError = errorMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitizedError.isEmpty else { return nil }
        let sanitizedExplanation = explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitizedError == sanitizedExplanation ? nil : sanitizedError
    }

    static func resolve(
        calendarAuthorization: CalendarAuthorizationStatus,
        selectedCalendarCount: Int,
        calendarIsLoading: Bool = false,
        calendarError: String? = nil,
        healthStatuses: [HealthDomain: HealthDomainStatus],
        healthHasObservableData: Bool,
        healthIsRefreshing: Bool = false,
        healthErrorCode: String? = nil,
        healthPresentation: HealthFirstSyncOutcome? = nil,
        evaAccessState: EvaCloudAccessState,
        evaUsesOfflineProvider: Bool,
        offlineModelReady: Bool
    ) -> SetupCenterStatus {
        .init(
            calendar: resolveCalendar(authorization: calendarAuthorization, selectedCalendarCount: selectedCalendarCount, isLoading: calendarIsLoading, error: calendarError),
            health: resolveHealth(statuses: healthStatuses, hasObservableData: healthHasObservableData, isRefreshing: healthIsRefreshing, errorCode: healthErrorCode, presentation: healthPresentation),
            eva: resolveEva(accessState: evaAccessState, usesOfflineProvider: evaUsesOfflineProvider, offlineModelReady: offlineModelReady)
        )
    }

    private static func resolveCalendar(authorization: CalendarAuthorizationStatus, selectedCalendarCount: Int, isLoading: Bool, error: String?) -> SetupCenterIntegrationSnapshot {
        if isLoading { return .init(integration: .calendar, state: .checking, status: String(localized: "Checking"), explanation: String(localized: "Loading calendars…"), recoveryAction: "") }
        if error?.isEmpty == false { return .init(integration: .calendar, state: .attention, status: String(localized: "Couldn’t load"), explanation: String(localized: "Couldn’t load your calendars."), recoveryAction: String(localized: "Try again"), recoveryActionKind: .refreshCalendars) }
        switch authorization {
        case .authorized where selectedCalendarCount > 0:
            return .init(integration: .calendar, state: .ready, status: String(localized: "Ready"), explanation: selectedCalendarCount == 1 ? String(localized: "1 calendar selected.") : String(localized: "\(selectedCalendarCount) calendars selected."), recoveryAction: String(localized: "Change calendars"), recoveryActionKind: .chooseCalendars)
        case .authorized:
            return .init(integration: .calendar, state: .actionRequired, status: String(localized: "Choose calendars"), explanation: String(localized: "Choose at least one calendar."), recoveryAction: String(localized: "Choose calendars"), recoveryActionKind: .chooseCalendars)
        case .notDetermined:
            return .init(integration: .calendar, state: .notStarted, status: String(localized: "Not set up"), explanation: String(localized: "Allow access, then choose which calendars to show."), recoveryAction: String(localized: "Allow calendar access"), recoveryActionKind: .requestCalendarAccess)
        case .denied:
            return .init(integration: .calendar, state: .attention, status: String(localized: "Off"), explanation: String(localized: "Calendar access is off in Settings."), recoveryAction: String(localized: "Open Settings"), recoveryActionKind: .openSystemSettings)
        case .restricted:
            return .init(integration: .calendar, state: .attention, status: String(localized: "Restricted"), explanation: String(localized: "Blocked by a device restriction."), recoveryAction: String(localized: "Open Settings"), recoveryActionKind: .openSystemSettings)
        case .writeOnly:
            return .init(integration: .calendar, state: .attention, status: String(localized: "Limited"), explanation: String(localized: "Can add events but can’t read them."), recoveryAction: String(localized: "Allow full access"), recoveryActionKind: .requestCalendarAccess)
        }
    }

    private static func resolveHealth(statuses: [HealthDomain: HealthDomainStatus], hasObservableData: Bool, isRefreshing: Bool, errorCode: String?, presentation: HealthFirstSyncOutcome?) -> SetupCenterIntegrationSnapshot {
        // Older callers supply observable facts; never use a sync timestamp as
        // proof that Health data was read. Live surfaces pass the shared state.
        let state = presentation ?? LifeWeaveHealthFirstSync.resolve(
            statuses: statuses, aggregates: [:], isRefreshing: isRefreshing,
            lastSuccessfulSync: nil, nonSensitiveErrorCode: errorCode, isAvailable: true
        )
        if statuses.values.contains(where: { $0.writeEnabled && ($0.signal == .writeDenied || $0.writeAuthorizations.values.contains(.denied)) }) {
            return .init(integration: .health, state: .attention, status: String(localized: "Saving is off"), explanation: String(localized: "Saving to Apple Health is off in Health settings."), recoveryAction: String(localized: "Manage Health access"), recoveryActionKind: .manageHealthAccess)
        }
        switch state {
        case .unavailable:
            return .init(integration: .health, state: .waiting, status: String(localized: "Not available"), explanation: state.summary, recoveryAction: "")
        case .authorizationFailed:
            return .init(integration: .health, state: .attention, status: String(localized: "Not connected"), explanation: state.summary, recoveryAction: String(localized: "Try again"), recoveryActionKind: .requestHealthAccess)
        case .requesting, .syncing:
            return .init(integration: .health, state: .checking, status: state == .requesting ? String(localized: "Connecting") : String(localized: "Syncing"), explanation: state.summary, recoveryAction: "")
        case .protectedDataLocked:
            return .init(integration: .health, state: .waiting, status: String(localized: "Paused"), explanation: state.summary, recoveryAction: "")
        case .partial:
            return .init(integration: .health, state: .attention, status: String(localized: "Partly synced"), explanation: state.summary, recoveryAction: String(localized: "Sync again"), recoveryActionKind: .syncHealth)
        case .ready:
            return .init(integration: .health, state: .ready, status: String(localized: "Connected"), explanation: state.summary, recoveryAction: String(localized: "Sync now"), recoveryActionKind: .syncHealth)
        case .notRequested, .reviewedNoDataYet:
            if hasObservableData {
                return .init(integration: .health, state: .ready, status: String(localized: "Connected"), explanation: String(localized: "Reading your Health data."), recoveryAction: String(localized: "Sync now"), recoveryActionKind: .syncHealth)
            }
            if state == .notRequested {
                return .init(integration: .health, state: .notStarted, status: String(localized: "Not connected"), explanation: state.summary, recoveryAction: String(localized: "Connect Apple Health"), recoveryActionKind: .requestHealthAccess)
            }
            return .init(integration: .health, state: .waiting, status: String(localized: "Waiting"), explanation: state.summary, recoveryAction: String(localized: "Manage Health access"), recoveryActionKind: .manageHealthAccess)
        }
    }

    private static func resolveEva(accessState: EvaCloudAccessState, usesOfflineProvider: Bool, offlineModelReady: Bool) -> SetupCenterIntegrationSnapshot {
        if usesOfflineProvider {
            return offlineModelReady
                ? .init(integration: .eva, state: .ready, status: String(localized: "On this device"), explanation: String(localized: "Eva runs on this device."), recoveryAction: String(localized: "Manage model"))
                : .init(integration: .eva, state: .attention, status: String(localized: "No model"), explanation: String(localized: "Download a model to run Eva on this device."), recoveryAction: String(localized: "Choose a model"))
        }
        switch accessState {
        case .hydrating, .activating: return .init(integration: .eva, state: .checking, status: String(localized: "Connecting"), explanation: String(localized: "Connecting to Eva in the cloud…"), recoveryAction: "")
        case .ready: return .init(integration: .eva, state: .ready, status: String(localized: "Cloud"), explanation: String(localized: "Eva uses only the data you allowed."), recoveryAction: String(localized: "Eva settings"))
        case .needsActivation: return .init(integration: .eva, state: .notStarted, status: String(localized: "Not set up"), explanation: String(localized: "Eva runs in the cloud or on this device."), recoveryAction: String(localized: "Set up Eva"))
        case .quotaExhausted: return .init(integration: .eva, state: .limited, status: String(localized: "Limit reached"), explanation: String(localized: "Cloud limit reached. Eva can run on this device."), recoveryAction: String(localized: "Use this device"))
        case .temporarilyUnavailable(let message):
            let explanation = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return .init(
                integration: .eva,
                state: .attention,
                status: String(localized: "Unavailable"),
                explanation: explanation.isEmpty ? String(localized: "Couldn’t reach Eva in the cloud.") : explanation,
                recoveryAction: String(localized: "Try again")
            )
        case .appleReauthenticationRequired: return .init(integration: .eva, state: .attention, status: String(localized: "Signed out"), explanation: String(localized: "Reconnect with Apple to use Eva in the cloud."), recoveryAction: String(localized: "Reconnect with Apple"))
        }
    }
}

enum SetupCenterHomeCardPreference {
    static let didChange = Notification.Name("LifeBoardSetupCenterHomeCardPreferenceDidChange")
    private static let dismissalKey = "setup_center.home_card.dismissed.v1"
    static var isDismissed: Bool { UserDefaults.standard.bool(forKey: dismissalKey) }
    static func dismiss() {
        UserDefaults.standard.set(true, forKey: dismissalKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }
    static func resetForNewOnboarding() {
        UserDefaults.standard.removeObject(forKey: dismissalKey)
        NotificationCenter.default.post(name: didChange, object: nil)
    }
}
