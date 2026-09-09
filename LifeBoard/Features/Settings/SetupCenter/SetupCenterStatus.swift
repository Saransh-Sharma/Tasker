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
        return "3 integrations · \(ready) ready · \(waiting) waiting · \(3 - ready - waiting) to set up"
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
        if isLoading { return .init(integration: .calendar, state: .checking, status: "Checking", explanation: "LifeBoard is refreshing the calendars available on this device.", recoveryAction: "") }
        if error?.isEmpty == false { return .init(integration: .calendar, state: .attention, status: "Needs attention", explanation: "LifeBoard could not refresh your available calendars.", recoveryAction: "Retry", recoveryActionKind: .refreshCalendars) }
        switch authorization {
        case .authorized where selectedCalendarCount > 0:
            return .init(integration: .calendar, state: .ready, status: "Ready", explanation: "LifeBoard can plan around events from \(selectedCalendarCount) selected calendar\(selectedCalendarCount == 1 ? "" : "s").", recoveryAction: "Change calendars", recoveryActionKind: .chooseCalendars)
        case .authorized:
            return .init(integration: .calendar, state: .actionRequired, status: "Choose calendars", explanation: "Access is allowed. Choose at least one calendar so planning has real context.", recoveryAction: "Choose calendars", recoveryActionKind: .chooseCalendars)
        case .notDetermined:
            return .init(integration: .calendar, state: .notStarted, status: "Not set up", explanation: "Allow read access, then choose exactly which calendars LifeBoard may use.", recoveryAction: "Allow calendar access", recoveryActionKind: .requestCalendarAccess)
        case .denied:
            return .init(integration: .calendar, state: .attention, status: "Needs attention", explanation: "Calendar access is off in Settings.", recoveryAction: "Open Settings", recoveryActionKind: .openSystemSettings)
        case .restricted:
            return .init(integration: .calendar, state: .attention, status: "Needs attention", explanation: "Calendar access is restricted on this device.", recoveryAction: "Open Settings", recoveryActionKind: .openSystemSettings)
        case .writeOnly:
            return .init(integration: .calendar, state: .attention, status: "Needs attention", explanation: "LifeBoard can add events but cannot read your day.", recoveryAction: "Request full access", recoveryActionKind: .requestCalendarAccess)
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
            return .init(integration: .health, state: .attention, status: "Write access needs attention", explanation: "A write-back option you enabled is off in Apple Health. Reading and local logging remain separate.", recoveryAction: "Manage Health access", recoveryActionKind: .manageHealthAccess)
        }
        switch state {
        case .unavailable:
            return .init(integration: .health, state: .waiting, status: "Unavailable here", explanation: state.summary, recoveryAction: "")
        case .authorizationFailed:
            return .init(integration: .health, state: .attention, status: "Access request incomplete", explanation: state.summary, recoveryAction: "Retry Health access", recoveryActionKind: .requestHealthAccess)
        case .requesting, .syncing:
            return .init(integration: .health, state: .checking, status: state == .requesting ? "Requesting" : "Importing", explanation: state.summary, recoveryAction: "")
        case .protectedDataLocked:
            return .init(integration: .health, state: .waiting, status: "Paused", explanation: state.summary, recoveryAction: "")
        case .partial:
            return .init(integration: .health, state: .attention, status: "Import needs attention", explanation: state.summary, recoveryAction: "Retry sync", recoveryActionKind: .syncHealth)
        case .ready:
            return .init(integration: .health, state: .ready, status: "Data available", explanation: state.summary, recoveryAction: "Sync now", recoveryActionKind: .syncHealth)
        case .notRequested, .reviewedNoDataYet:
            if hasObservableData {
                return .init(integration: .health, state: .ready, status: "Data available", explanation: "Health data is available on this device.", recoveryAction: "Sync now", recoveryActionKind: .syncHealth)
            }
            if state == .notRequested {
                return .init(integration: .health, state: .notStarted, status: "Not connected", explanation: state.summary, recoveryAction: "Connect Apple Health", recoveryActionKind: .requestHealthAccess)
            }
            return .init(integration: .health, state: .waiting, status: "No readable data yet", explanation: state.summary, recoveryAction: "Manage Health access", recoveryActionKind: .manageHealthAccess)
        }
    }

    private static func resolveEva(accessState: EvaCloudAccessState, usesOfflineProvider: Bool, offlineModelReady: Bool) -> SetupCenterIntegrationSnapshot {
        if usesOfflineProvider {
            return offlineModelReady
                ? .init(integration: .eva, state: .ready, status: "Offline ready", explanation: "EVA uses the selected model on this device.", recoveryAction: "Manage model")
                : .init(integration: .eva, state: .attention, status: "Needs attention", explanation: "Offline EVA is selected, but no usable local model is selected and installed.", recoveryAction: "Choose a model")
        }
        switch accessState {
        case .hydrating, .activating: return .init(integration: .eva, state: .checking, status: "Connecting", explanation: "LifeBoard is checking Cloud EVA readiness.", recoveryAction: "")
        case .ready: return .init(integration: .eva, state: .ready, status: "Cloud ready", explanation: "Cloud EVA can use only the context categories you approved.", recoveryAction: "Manage EVA")
        case .needsDisclosure: return .init(integration: .eva, state: .notStarted, status: "Not set up", explanation: "Choose Cloud EVA with explicit context grants, or use an installed Offline EVA model.", recoveryAction: "Set up EVA")
        case .quotaExhausted: return .init(integration: .eva, state: .limited, status: "Limited", explanation: "Cloud EVA is set up, but its current allowance is exhausted.", recoveryAction: "Use Offline EVA")
        case .temporarilyUnavailable(let message):
            let explanation = message.trimmingCharacters(in: .whitespacesAndNewlines)
            return .init(
                integration: .eva,
                state: .attention,
                status: "Needs attention",
                explanation: explanation.isEmpty ? "Cloud EVA is temporarily unavailable." : explanation,
                recoveryAction: "Retry"
            )
        case .appleReauthenticationRequired: return .init(integration: .eva, state: .attention, status: "Needs attention", explanation: "Reconnect with Apple to restore the linked Cloud EVA account.", recoveryAction: "Reconnect with Apple")
        case .ageBlocked(let message): return .init(integration: .eva, state: .attention, status: "Needs attention", explanation: message, recoveryAction: "Use Offline EVA")
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
