import Foundation
import Combine

public enum CalendarAccessAction: Equatable {
    case requestPermission
    case openSystemSettings
    case unavailable(LifeBoardCalendarAuthorizationStatus)
    case noneNeeded
}

public enum CalendarAccessAttemptOutcome: String, Codable, Equatable {
    case started
    case granted
    case denied
    case failed
    case systemRequestFailed
}

public struct CalendarAccessAttemptRecord: Codable, Equatable {
    public let attemptedAt: Date
    public let source: String
    public let statusBefore: LifeBoardCalendarAuthorizationStatus
    public let statusAfter: LifeBoardCalendarAuthorizationStatus?
    public let outcome: CalendarAccessAttemptOutcome
    public let errorDomain: String?
    public let errorCode: Int?
    public let errorMessage: String?
    public let appVersion: String

    public init(
        attemptedAt: Date = Date(),
        source: String,
        statusBefore: LifeBoardCalendarAuthorizationStatus,
        statusAfter: LifeBoardCalendarAuthorizationStatus?,
        outcome: CalendarAccessAttemptOutcome,
        errorDomain: String? = nil,
        errorCode: Int? = nil,
        errorMessage: String? = nil,
        appVersion: String
    ) {
        self.attemptedAt = attemptedAt
        self.source = source
        self.statusBefore = statusBefore
        self.statusAfter = statusAfter
        self.outcome = outcome
        self.errorDomain = errorDomain
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.appVersion = appVersion
    }

    public var countsAsTerminalFullAccessAttempt: Bool {
        switch outcome {
        case .granted, .denied:
            return true
        case .started, .failed, .systemRequestFailed:
            return false
        }
    }

    public var isSystemRequestFailure: Bool {
        if outcome == .systemRequestFailed {
            return true
        }

        return errorDomain == CalendarAccessDiagnostics.eventKitDaemonErrorDomain &&
            errorCode == CalendarAccessDiagnostics.eventKitDaemonXPCErrorCode
    }
}

public protocol CalendarAccessAttemptStore: AnyObject, Sendable {
    var hasAttemptedFullAccessRequest: Bool { get }
    var lastFullAccessAttempt: CalendarAccessAttemptRecord? { get }
    func recordFullAccessAttempt(_ record: CalendarAccessAttemptRecord)
    func reset()
}

public final class UserDefaultsCalendarAccessAttemptStore: CalendarAccessAttemptStore, @unchecked Sendable {
    public static let shared = UserDefaultsCalendarAccessAttemptStore()

    private let defaults: UserDefaults
    private let appVersionProvider: () -> String
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        defaults: UserDefaults = .standard,
        appVersionProvider: @escaping () -> String = UserDefaultsCalendarAccessAttemptStore.defaultAppVersion
    ) {
        self.defaults = defaults
        self.appVersionProvider = appVersionProvider
    }

    public var hasAttemptedFullAccessRequest: Bool {
        lastFullAccessAttempt?.countsAsTerminalFullAccessAttempt == true
    }

    public var lastFullAccessAttempt: CalendarAccessAttemptRecord? {
        guard let data = defaults.data(forKey: storageKey) else { return nil }
        return try? decoder.decode(CalendarAccessAttemptRecord.self, from: data)
    }

    public func recordFullAccessAttempt(_ record: CalendarAccessAttemptRecord) {
        guard let data = try? encoder.encode(record) else { return }
        defaults.set(data, forKey: storageKey)
    }

    public func reset() {
        defaults.removeObject(forKey: storageKey)
    }

    public static func defaultAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown"
        return "\(version)-\(build)"
    }

    private var storageKey: String {
        "calendar.fullAccessAttempt.\(appVersionProvider())"
    }
}

public final class CalendarDiagnosticsStore: @unchecked Sendable {
    public static let shared = CalendarDiagnosticsStore()

    private let defaults: UserDefaults
    private let lock = NSLock()
    private let storageKey = "calendar.diagnostics.recentEntries"
    private let maxStoredEntries = 20

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func record(
        level: String,
        event: String,
        message: String,
        fields: [String: String]
    ) {
        let line = formattedLine(level: level, event: event, message: message, fields: fields)
        lock.lock()
        var entries = defaults.stringArray(forKey: storageKey) ?? []
        entries.append(line)
        if entries.count > maxStoredEntries {
            entries = Array(entries.suffix(maxStoredEntries))
        }
        defaults.set(entries, forKey: storageKey)
        lock.unlock()
    }

    public func recentEntriesText(limit: Int = 20) -> String {
        lock.lock()
        let entries = defaults.stringArray(forKey: storageKey) ?? []
        lock.unlock()

        let limitedEntries = entries.suffix(max(1, limit))
        guard limitedEntries.isEmpty == false else {
            return "No calendar diagnostics recorded yet."
        }
        return limitedEntries.joined(separator: "\n")
    }

    public func reset() {
        lock.lock()
        defaults.removeObject(forKey: storageKey)
        lock.unlock()
    }

    private func formattedLine(
        level: String,
        event: String,
        message: String,
        fields: [String: String]
    ) -> String {
        var chunks = [
            "lvl=\(level)",
            "cmp=CalendarIntegration",
            "evt=\(event)",
            "msg=\"\(singleLine(message))\""
        ]
        for key in fields.keys.sorted() {
            guard key.isEmpty == false else { continue }
            chunks.append("\(key)=\(formattedValue(fields[key] ?? ""))")
        }
        return chunks.joined(separator: " ")
    }

    private func formattedValue(_ value: String) -> String {
        let singleLineValue = singleLine(value)
        guard singleLineValue.rangeOfCharacter(from: .whitespacesAndNewlines) == nil,
              singleLineValue.contains("\"") == false else {
            return "\"\(singleLineValue.replacingOccurrences(of: "\"", with: "\\\""))\""
        }
        return singleLineValue
    }

    private func singleLine(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
    }
}

public enum CalendarAccessDiagnostics {
    public static let eventKitDaemonErrorDomain = "EKCADErrorDomain"
    public static let eventKitDaemonXPCErrorCode = 1015
}

/// Observable calendar state service. Mutable state is owned by the main actor; provider callbacks
/// are allowed to arrive on arbitrary queues and hop to `MainActor` before mutating `snapshot`.
public final class CalendarIntegrationService: ObservableObject, @unchecked Sendable {
    private struct DayProjectionKey: Hashable {
        let revision: UInt64
        let startOfDay: Date
    }

    private struct WeekProjectionKey: Hashable {
        let revision: UInt64
        let weekStart: Date
        let weekStartsOn: Weekday
    }

    @Published public private(set) var snapshot: LifeBoardCalendarSnapshot

    private let provider: CalendarEventsProviderProtocol?
    private let workspacePreferencesStore: LifeBoardWorkspacePreferencesStore
    private let accessAttemptStore: CalendarAccessAttemptStore
    private let filterEvents = FilterCalendarEventsUseCase()
    private let buildBusyBlocks = BuildCalendarBusyBlocksUseCase()
    private let resolveNextMeeting = ResolveNextMeetingUseCase()
    private let buildWeekAgenda = BuildCalendarWeekAgendaUseCase()
    private let taskFitUseCase = ComputeTaskFitHintUseCase(bufferMinutes: 15)

    private var contextEvents: [LifeBoardCalendarEventSnapshot] = []
    private var contextEventFetchRange: ClosedRange<Date>?
    private var refreshGeneration: UInt64 = 0
    private var projectionRevision: UInt64 = 0
    private var dayProjectionCache: [DayProjectionKey: [LifeBoardCalendarEventSnapshot]] = [:]
    private var weekProjectionCache: [WeekProjectionKey: [LifeBoardCalendarDayAgenda]] = [:]
    private var cancellables: Set<AnyCancellable> = []

    public nonisolated init(
        provider: CalendarEventsProviderProtocol?,
        workspacePreferencesStore: LifeBoardWorkspacePreferencesStore = .shared,
        accessAttemptStore: CalendarAccessAttemptStore = UserDefaultsCalendarAccessAttemptStore.shared
    ) {
        self.provider = provider
        self.workspacePreferencesStore = workspacePreferencesStore
        self.accessAttemptStore = accessAttemptStore

        let prefs = workspacePreferencesStore.load()
        self.snapshot = LifeBoardCalendarSnapshot(
            authorizationStatus: provider?.authorizationStatus() ?? .denied,
            availableCalendars: [],
            selectedCalendarIDs: prefs.selectedCalendarIDs,
            includeDeclined: prefs.includeDeclinedCalendarEvents,
            includeCanceled: prefs.includeCanceledCalendarEvents,
            includeAllDayInAgenda: prefs.includeAllDayInAgenda,
            includeAllDayInBusyStrip: prefs.includeAllDayInBusyStrip,
            eventsInRange: [],
            busyBlocks: [],
            nextMeeting: nil,
            freeUntil: nil,
            isLoading: false,
            errorMessage: nil
        )

        provider?.storeChangedPublisher()
            .debounce(for: .milliseconds(600), scheduler: RunLoop.main)
            .sink { [weak self] in
                self?.refreshContext(reason: "event_store_changed")
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: LifeBoardWorkspacePreferencesStore.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadPreferencesAndRefresh(reason: "workspace_preferences_changed")
            }
            .store(in: &cancellables)
    }

    public var selectedCalendarCount: Int {
        snapshot.selectedCalendarIDs.count
    }

    public var weekStartsOn: Weekday {
        workspacePreferencesStore.load().weekStartsOn
    }

    public var hasAttemptedFullCalendarAccessRequest: Bool {
        accessAttemptStore.hasAttemptedFullAccessRequest
    }

    public var lastFullCalendarAccessAttempt: CalendarAccessAttemptRecord? {
        accessAttemptStore.lastFullAccessAttempt
    }

    public func refreshAuthorizationStatus() {
        let status = provider?.authorizationStatus() ?? .denied
        snapshot.authorizationStatus = status
        if status.isAuthorizedForRead == false {
            snapshot.isLoading = false
            snapshot.errorMessage = nil
            clearCalendarContext(keepAvailableCalendars: false)
        }
    }

    public func accessAction() -> CalendarAccessAction {
        guard let provider else {
            snapshot.authorizationStatus = .denied
            let action = CalendarAccessAction.unavailable(.denied)
            logCalendarAccessPolicy(status: .denied, action: action)
            return action
        }

        let status = provider.authorizationStatus()
        snapshot.authorizationStatus = status
        let action = accessAction(for: status)
        logCalendarAccessPolicy(status: status, action: action)
        return action
    }

    public func accessAction(for status: LifeBoardCalendarAuthorizationStatus) -> CalendarAccessAction {
        switch status {
        case .notDetermined:
            return .requestPermission
        case .writeOnly:
            return .requestPermission
        case .denied:
            return .openSystemSettings
        case .restricted:
            return .unavailable(status)
        case .authorized:
            return .noneNeeded
        }
    }

    @discardableResult
    public func performAccessAction(
        source: String = "unknown",
        openSystemSettings: @escaping () -> Void,
        completion: (@Sendable (Bool) -> Void)? = nil
    ) -> CalendarAccessAction {
        let action = accessAction()
        switch action {
        case .requestPermission:
            requestAccess(source: source, completion: completion)
        case .openSystemSettings:
            logCalendarWarning(
                event: "calendar_open_system_settings",
                message: "Opening app Settings for calendar access recovery",
                fields: calendarDiagnosticFields(
                    status: snapshot.authorizationStatus,
                    extra: ["source": source]
                )
            )
            openSystemSettings()
            completion?(false)
        case .unavailable:
            completion?(false)
        case .noneNeeded:
            completion?(true)
        }
        return action
    }

    public func requestAccess(source: String = "unknown", completion: (@Sendable (Bool) -> Void)? = nil) {
        guard let provider else {
            logCalendarWarning(
                event: "calendar_full_access_request_completed",
                message: "Calendar provider unavailable for full access request",
                fields: calendarDiagnosticFields(
                    status: .denied,
                    extra: [
                        "source": source,
                        "granted": "false",
                        "attemptOutcome": CalendarAccessAttemptOutcome.failed.rawValue,
                        "statusAfter": LifeBoardCalendarAuthorizationStatus.denied.rawValue,
                        "errorMessage": "provider_unavailable"
                    ]
                )
            )
            completion?(false)
            return
        }

        let statusBefore = provider.authorizationStatus()
        recordFullAccessAttempt(
            source: source,
            statusBefore: statusBefore,
            statusAfter: nil,
            outcome: .started
        )
        logCalendarWarning(
            event: "calendar_full_access_request_started",
            message: "Requesting full calendar access",
            fields: calendarDiagnosticFields(
                status: statusBefore,
                extra: ["source": source]
            )
        )

        provider.requestAccess { [weak self] result in
            Task { @MainActor in
                guard let self else { return }
                switch result {
                case .success(let granted):
                    if granted {
                        provider.resetStoreStateAfterPermissionChange()
                    }
                    let statusAfter = self.provider?.authorizationStatus() ?? (granted ? .authorized : .denied)
                    let outcome: CalendarAccessAttemptOutcome = granted ? .granted : .denied
                    self.recordFullAccessAttempt(
                        source: source,
                        statusBefore: statusBefore,
                        statusAfter: statusAfter,
                        outcome: outcome
                    )
                    self.logFullAccessRequestCompleted(
                        source: source,
                        granted: granted,
                        statusBefore: statusBefore,
                        statusAfter: statusAfter,
                        outcome: outcome,
                        error: nil
                    )
                    self.snapshot.authorizationStatus = statusAfter
                    if granted {
                        self.refreshContext(reason: "permission_granted")
                    }
                    completion?(granted)
                case .failure(let error):
                    let statusAfter = self.provider?.authorizationStatus() ?? .denied
                    let outcome = self.fullAccessFailureOutcome(for: error)
                    self.recordFullAccessAttempt(
                        source: source,
                        statusBefore: statusBefore,
                        statusAfter: statusAfter,
                        outcome: outcome,
                        error: error
                    )
                    self.logFullAccessRequestCompleted(
                        source: source,
                        granted: false,
                        statusBefore: statusBefore,
                        statusAfter: statusAfter,
                        outcome: outcome,
                        error: error
                    )
                    self.snapshot.errorMessage = error.localizedDescription
                    self.snapshot.authorizationStatus = statusAfter
                    completion?(false)
                }
            }
        }
    }

    public func updateSelectedCalendarIDs(_ calendarIDs: [String]) {
        let normalizedCalendarIDs = LifeBoardWorkspacePreferences.normalizeSelectedCalendarIDs(calendarIDs)
        guard normalizedCalendarIDs != snapshot.selectedCalendarIDs else { return }

        workspacePreferencesStore.update { preferences in
            preferences.selectedCalendarIDs = normalizedCalendarIDs
        }
        snapshot.selectedCalendarIDs = normalizedCalendarIDs
    }

    public func setIncludeDeclined(_ include: Bool) {
        guard snapshot.includeDeclined != include else { return }
        workspacePreferencesStore.update { preferences in
            preferences.includeDeclinedCalendarEvents = include
        }
        snapshot.includeDeclined = include
    }

    public func setIncludeCanceled(_ include: Bool) {
        guard snapshot.includeCanceled != include else { return }
        workspacePreferencesStore.update { preferences in
            preferences.includeCanceledCalendarEvents = include
        }
        snapshot.includeCanceled = include
    }

    public func setIncludeAllDayInAgenda(_ include: Bool) {
        guard snapshot.includeAllDayInAgenda != include else { return }
        workspacePreferencesStore.update { preferences in
            preferences.includeAllDayInAgenda = include
        }
        snapshot.includeAllDayInAgenda = include
    }

    public func setIncludeAllDayInBusyStrip(_ include: Bool) {
        guard snapshot.includeAllDayInBusyStrip != include else { return }
        workspacePreferencesStore.update { preferences in
            preferences.includeAllDayInBusyStrip = include
        }
        snapshot.includeAllDayInBusyStrip = include
    }

    public func refreshContext(referenceDate: Date = Date(), reason: String = "manual") {
        let generation = beginRefreshGeneration()

        guard let provider else {
            snapshot.authorizationStatus = .denied
            snapshot.errorMessage = "Calendar provider unavailable."
            clearCalendarContext(keepAvailableCalendars: false)
            logCalendarWarning(
                event: "calendar_context_refresh_skipped",
                message: "Calendar provider unavailable",
                fields: calendarDiagnosticFields(
                    status: .denied,
                    extra: ["reason": reason]
                )
            )
            return
        }

        refreshAuthorizationStatus()

        guard snapshot.authorizationStatus.isAuthorizedForRead else {
            clearCalendarContext(keepAvailableCalendars: false)
            snapshot.errorMessage = nil
            snapshot.isLoading = false
            logCalendarWarning(
                event: "calendar_context_refresh_skipped",
                message: "Calendar context refresh skipped without readable access",
                fields: calendarDiagnosticFields(
                    status: snapshot.authorizationStatus,
                    extra: ["reason": reason]
                )
            )
            return
        }

        let workspacePreferences = workspacePreferencesStore.load()
        let calendar = Calendar.current
        let weekStart = XPCalculationEngine.startOfWeek(
            for: referenceDate,
            startingOn: workspacePreferences.weekStartsOn
        )
        let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart
        let startOfToday = calendar.startOfDay(for: referenceDate)
        let todayForwardEnd = calendar.date(byAdding: .day, value: 7, to: startOfToday) ?? startOfToday
        let fetchStart = weekStart
        let fetchEnd = max(weekEnd, todayForwardEnd)

        snapshot.isLoading = true
        snapshot.errorMessage = nil

        provider.fetchCalendars { [weak self] calendarsResult in
            Task { @MainActor in
                guard let self, self.isCurrentRefreshGeneration(generation) else { return }
                switch calendarsResult {
                case .failure(let error):
                    self.snapshot.isLoading = false
                    self.snapshot.errorMessage = error.localizedDescription
                    self.clearCalendarContext(keepAvailableCalendars: true)
                    self.logCalendarContextLoadFailed(error: error, reason: reason, stage: "calendars")
                case .success(let calendars):
                    self.snapshot.availableCalendars = calendars
                    let availableCalendarIDs = Set(calendars.map(\.id))
                    let reconciledSelection = self.snapshot.selectedCalendarIDs.filter { availableCalendarIDs.contains($0) }
                    if reconciledSelection != self.snapshot.selectedCalendarIDs {
                        self.persistSelectedCalendarIDs(reconciledSelection)
                        self.snapshot.selectedCalendarIDs = reconciledSelection
                    }

                    guard self.snapshot.selectedCalendarIDs.isEmpty == false else {
                        self.snapshot.isLoading = false
                        self.snapshot.errorMessage = nil
                        self.clearCalendarContext(keepAvailableCalendars: true)
                        return
                    }

                    self.provider?.fetchEvents(
                        startDate: fetchStart,
                        endDate: fetchEnd,
                        calendarIDs: Set(self.snapshot.selectedCalendarIDs)
                    ) { [weak self] eventsResult in
                        Task { @MainActor in
                            guard let self, self.isCurrentRefreshGeneration(generation) else { return }
                            self.snapshot.isLoading = false
                            switch eventsResult {
                            case .failure(let error):
                                self.snapshot.errorMessage = error.localizedDescription
                                self.clearCalendarContext(keepAvailableCalendars: true)
                                self.logCalendarContextLoadFailed(error: error, reason: reason, stage: "events")
                            case .success(let events):
                                self.reconcile(
                                    events: events,
                                    referenceDate: referenceDate,
                                    loadedRange: fetchStart...fetchEnd
                                )
                                self.logCalendarContextLoaded(reason: reason)
                            }
                        }
                    }
                }
            }
        }
    }

    public func eventsForDay(_ day: Date) -> [LifeBoardCalendarEventSnapshot] {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: day)
        let cacheKey = DayProjectionKey(revision: projectionRevision, startOfDay: startOfDay)
        if let cached = dayProjectionCache[cacheKey] {
            return cached
        }

        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        let events = snapshot.eventsInRange
            .filter { $0.endDate > startOfDay && $0.startDate < endOfDay }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.endDate < rhs.endDate
            }
        dayProjectionCache[cacheKey] = events
        return events
    }

    public func weekAgenda(anchorDate: Date, weekStartsOn: Weekday) -> [LifeBoardCalendarDayAgenda] {
        let weekStart = XPCalculationEngine.startOfWeek(for: anchorDate, startingOn: weekStartsOn)
        let cacheKey = WeekProjectionKey(
            revision: projectionRevision,
            weekStart: weekStart,
            weekStartsOn: weekStartsOn
        )
        if let cached = weekProjectionCache[cacheKey] {
            return cached
        }

        let agenda = buildWeekAgenda.execute(events: snapshot.eventsInRange, weekStart: weekStart)
        weekProjectionCache[cacheKey] = agenda
        return agenda
    }

    @MainActor
    public func taskFitHint(for task: TaskDefinition, now: Date = Date()) -> LifeBoardTaskFitHintResult {
        guard let dueDate = task.dueDate,
              dueDate >= now else {
            return .unknown
        }

        let calendar = Calendar.current
        let rangeStart = calendar.startOfDay(for: dueDate)
        let rangeEnd = dueDate
        guard rangeEnd > rangeStart else {
            return .unknown
        }
        guard let contextEventFetchRange,
              rangeStart >= contextEventFetchRange.lowerBound,
              rangeEnd <= contextEventFetchRange.upperBound else {
            return .unknown
        }

        let busyBlocks = buildBusyBlocks.execute(
            events: contextEvents,
            includeAllDayEvents: snapshot.includeAllDayInBusyStrip,
            referenceStart: rangeStart,
            referenceEnd: rangeEnd
        )

        return taskFitUseCase.execute(
            now: now,
            taskDueDate: task.dueDate,
            estimatedDuration: task.estimatedDuration,
            busyBlocks: busyBlocks
        )
    }

    public func event(withID eventID: String) -> LifeBoardCalendarEventSnapshot? {
        snapshot.eventsInRange.first { $0.id == eventID }
    }

    private func beginRefreshGeneration() -> UInt64 {
        refreshGeneration &+= 1
        return refreshGeneration
    }

    private func isCurrentRefreshGeneration(_ generation: UInt64) -> Bool {
        generation == refreshGeneration
    }

    private func reloadPreferencesAndRefresh(reason: String) {
        let preferences = workspacePreferencesStore.load()
        snapshot.selectedCalendarIDs = LifeBoardWorkspacePreferences.normalizeSelectedCalendarIDs(preferences.selectedCalendarIDs)
        snapshot.includeDeclined = preferences.includeDeclinedCalendarEvents
        snapshot.includeCanceled = preferences.includeCanceledCalendarEvents
        snapshot.includeAllDayInAgenda = preferences.includeAllDayInAgenda
        snapshot.includeAllDayInBusyStrip = preferences.includeAllDayInBusyStrip
        refreshContext(reason: reason)
    }

    private func persistSelectedCalendarIDs(_ calendarIDs: [String]) {
        let normalizedCalendarIDs = LifeBoardWorkspacePreferences.normalizeSelectedCalendarIDs(calendarIDs)
        workspacePreferencesStore.update { preferences in
            preferences.selectedCalendarIDs = normalizedCalendarIDs
        }
    }

    private func clearCalendarContext(keepAvailableCalendars: Bool) {
        invalidateProjectionCaches()
        contextEvents = []
        contextEventFetchRange = nil
        snapshot.eventsInRange = []
        snapshot.busyBlocks = []
        snapshot.nextMeeting = nil
        snapshot.freeUntil = nil
        if keepAvailableCalendars == false {
            snapshot.availableCalendars = []
        }
    }

    private func reconcile(
        events: [LifeBoardCalendarEventSnapshot],
        referenceDate: Date,
        loadedRange: ClosedRange<Date>
    ) {
        invalidateProjectionCaches()
        let selectedCalendarIDs = Set(snapshot.selectedCalendarIDs)
        let contextEvents = filterEvents.execute(
            events: events,
            selectedCalendarIDs: selectedCalendarIDs,
            includeDeclined: snapshot.includeDeclined,
            includeCanceled: snapshot.includeCanceled,
            includeAllDayInAgenda: true
        )
        let agendaEvents = filterEvents.execute(
            events: events,
            selectedCalendarIDs: selectedCalendarIDs,
            includeDeclined: snapshot.includeDeclined,
            includeCanceled: snapshot.includeCanceled,
            includeAllDayInAgenda: snapshot.includeAllDayInAgenda
        )

        let now = referenceDate
        let busyHorizonEnd = Calendar.current.date(byAdding: .hour, value: 12, to: now) ?? now
        let busyBlocks = buildBusyBlocks.execute(
            events: contextEvents,
            includeAllDayEvents: snapshot.includeAllDayInBusyStrip,
            referenceStart: now,
            referenceEnd: busyHorizonEnd
        )

        let timedContextEvents = contextEvents.filter { !$0.isAllDay }
        let nextMeeting = resolveNextMeeting.execute(events: timedContextEvents, now: now)
        let isCurrentlyBusy = busyBlocks.contains { $0.startDate <= now && $0.endDate > now }
        let nextBusyStart = busyBlocks.first(where: { $0.startDate > now })?.startDate
        let freeUntil = isCurrentlyBusy ? nil : nextBusyStart

        self.contextEvents = contextEvents
        self.contextEventFetchRange = loadedRange
        snapshot.eventsInRange = agendaEvents
        snapshot.busyBlocks = busyBlocks
        snapshot.nextMeeting = nextMeeting
        snapshot.freeUntil = freeUntil
        snapshot.errorMessage = nil
    }

    private func invalidateProjectionCaches() {
        projectionRevision &+= 1
        dayProjectionCache.removeAll(keepingCapacity: true)
        weekProjectionCache.removeAll(keepingCapacity: true)
    }

    private func recordFullAccessAttempt(
        source: String,
        statusBefore: LifeBoardCalendarAuthorizationStatus,
        statusAfter: LifeBoardCalendarAuthorizationStatus?,
        outcome: CalendarAccessAttemptOutcome,
        error: Error? = nil
    ) {
        let nsError = error.map { $0 as NSError }
        accessAttemptStore.recordFullAccessAttempt(
            CalendarAccessAttemptRecord(
                source: source,
                statusBefore: statusBefore,
                statusAfter: statusAfter,
                outcome: outcome,
                errorDomain: nsError?.domain,
                errorCode: nsError?.code,
                errorMessage: error?.localizedDescription,
                appVersion: UserDefaultsCalendarAccessAttemptStore.defaultAppVersion()
            )
        )
    }

    private func logCalendarAccessPolicy(
        status: LifeBoardCalendarAuthorizationStatus,
        action: CalendarAccessAction
    ) {
        logCalendarWarning(
            event: "calendar_access_policy_resolved",
            message: "Resolved calendar access action",
            fields: calendarDiagnosticFields(
                status: status,
                extra: ["selectedAction": diagnosticName(for: action)]
            )
        )
    }

    private func logFullAccessRequestCompleted(
        source: String,
        granted: Bool,
        statusBefore: LifeBoardCalendarAuthorizationStatus,
        statusAfter: LifeBoardCalendarAuthorizationStatus,
        outcome: CalendarAccessAttemptOutcome,
        error: Error?
    ) {
        var extra = [
            "source": source,
            "granted": String(granted),
            "attemptOutcome": outcome.rawValue,
            "statusBefore": statusBefore.rawValue,
            "statusAfter": statusAfter.rawValue
        ]
        if let error {
            let nsError = error as NSError
            extra["errorDomain"] = nsError.domain
            extra["errorCode"] = String(nsError.code)
            extra["errorMessage"] = error.localizedDescription
        }

        logCalendarWarning(
            event: "calendar_full_access_request_completed",
            message: "Full calendar access request completed",
            fields: calendarDiagnosticFields(status: statusAfter, extra: extra)
        )
    }

    private func logCalendarContextLoadFailed(error: Error, reason: String, stage: String) {
        let nsError = error as NSError
        logCalendarWarning(
            event: "calendar_context_load_failed",
            message: "Calendar context load failed",
            fields: calendarDiagnosticFields(
                status: snapshot.authorizationStatus,
                extra: [
                    "reason": reason,
                    "stage": stage,
                    "errorDomain": nsError.domain,
                    "errorCode": String(nsError.code),
                    "errorMessage": error.localizedDescription
                ]
            )
        )
    }

    private func logCalendarContextLoaded(reason: String) {
        logCalendarInfo(
            event: "calendar_context_loaded",
            message: "Calendar context loaded",
            fields: calendarDiagnosticFields(
                status: snapshot.authorizationStatus,
                extra: [
                    "reason": reason,
                    "availableCalendarCount": String(snapshot.availableCalendars.count),
                    "selectedCalendarCount": String(snapshot.selectedCalendarIDs.count),
                    "eventCount": String(snapshot.eventsInRange.count),
                    "busyBlockCount": String(snapshot.busyBlocks.count)
                ]
            )
        )
    }

    private func fullAccessFailureOutcome(for error: Error) -> CalendarAccessAttemptOutcome {
        let nsError = error as NSError
        if nsError.domain == CalendarAccessDiagnostics.eventKitDaemonErrorDomain &&
            nsError.code == CalendarAccessDiagnostics.eventKitDaemonXPCErrorCode {
            return .systemRequestFailed
        }
        return .failed
    }

    private func logCalendarWarning(
        event: String,
        message: String,
        fields: [String: String]
    ) {
        CalendarDiagnosticsStore.shared.record(
            level: LogLevel.warning.label,
            event: event,
            message: message,
            fields: fields
        )
        logWarning(
            event: event,
            message: message,
            component: "CalendarIntegration",
            fields: fields
        )
    }

    private func logCalendarInfo(
        event: String,
        message: String,
        fields: [String: String]
    ) {
        CalendarDiagnosticsStore.shared.record(
            level: LogLevel.info.label,
            event: event,
            message: message,
            fields: fields
        )
        logInfo(
            event: event,
            message: message,
            component: "CalendarIntegration",
            fields: fields
        )
    }

    private func calendarDiagnosticFields(
        status: LifeBoardCalendarAuthorizationStatus,
        extra: [String: String] = [:]
    ) -> [String: String] {
        var fields = [
            "currentStatus": status.rawValue,
            "hasAttemptedFullAccess": String(accessAttemptStore.hasAttemptedFullAccessRequest),
            "lastAttemptOutcome": accessAttemptStore.lastFullAccessAttempt?.outcome.rawValue ?? "none",
            "hasFullAccessUsageKey": String(Bundle.main.object(forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription") != nil),
            "osVersion": ProcessInfo.processInfo.operatingSystemVersionString
        ]
        extra.forEach { fields[$0.key] = $0.value }
        return fields
    }

    private func diagnosticName(for action: CalendarAccessAction) -> String {
        switch action {
        case .requestPermission:
            return "requestFullAccess"
        case .openSystemSettings:
            return "openSystemSettings"
        case .unavailable(let status):
            return "unavailable:\(status.rawValue)"
        case .noneNeeded:
            return "noneNeeded"
        }
    }
}
