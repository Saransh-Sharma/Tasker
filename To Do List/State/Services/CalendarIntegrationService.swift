import Foundation
import Combine

public enum CalendarAccessAction: Equatable {
    case requestPermission
    case openSystemSettings
    case unavailable(TaskerCalendarAuthorizationStatus)
    case noneNeeded
}

public final class CalendarIntegrationService: ObservableObject {
    private struct DayProjectionKey: Hashable {
        let revision: UInt64
        let startOfDay: Date
    }

    private struct WeekProjectionKey: Hashable {
        let revision: UInt64
        let weekStart: Date
        let weekStartsOn: Weekday
    }

    @Published public private(set) var snapshot: TaskerCalendarSnapshot

    private let provider: CalendarEventsProviderProtocol?
    private let workspacePreferencesStore: TaskerWorkspacePreferencesStore
    private let filterEvents = FilterCalendarEventsUseCase()
    private let buildBusyBlocks = BuildCalendarBusyBlocksUseCase()
    private let resolveNextMeeting = ResolveNextMeetingUseCase()
    private let buildWeekAgenda = BuildCalendarWeekAgendaUseCase()
    private let taskFitUseCase = ComputeTaskFitHintUseCase(bufferMinutes: 15)

    private var contextEvents: [TaskerCalendarEventSnapshot] = []
    private var refreshGeneration: UInt64 = 0
    private var projectionRevision: UInt64 = 0
    private var dayProjectionCache: [DayProjectionKey: [TaskerCalendarEventSnapshot]] = [:]
    private var weekProjectionCache: [WeekProjectionKey: [TaskerCalendarDayAgenda]] = [:]
    private var cancellables: Set<AnyCancellable> = []

    public init(
        provider: CalendarEventsProviderProtocol?,
        workspacePreferencesStore: TaskerWorkspacePreferencesStore = .shared
    ) {
        self.provider = provider
        self.workspacePreferencesStore = workspacePreferencesStore

        let prefs = workspacePreferencesStore.load()
        self.snapshot = TaskerCalendarSnapshot(
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

        NotificationCenter.default.publisher(for: TaskerWorkspacePreferencesStore.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.reloadPreferencesAndRefresh(reason: "workspace_preferences_changed")
            }
            .store(in: &cancellables)
    }

    public var selectedCalendarCount: Int {
        snapshot.selectedCalendarIDs.count
    }

    public func refreshAuthorizationStatus() {
        snapshot.authorizationStatus = provider?.authorizationStatus() ?? .denied
    }

    public func accessAction() -> CalendarAccessAction {
        refreshAuthorizationStatus()
        switch snapshot.authorizationStatus {
        case .notDetermined:
            return .requestPermission
        case .denied, .writeOnly:
            return .openSystemSettings
        case .restricted:
            return .unavailable(snapshot.authorizationStatus)
        case .authorized:
            return .noneNeeded
        }
    }

    @discardableResult
    public func performAccessAction(
        openSystemSettings: @escaping () -> Void,
        completion: ((Bool) -> Void)? = nil
    ) -> CalendarAccessAction {
        let action = accessAction()
        switch action {
        case .requestPermission:
            requestAccess(completion: completion)
        case .openSystemSettings:
            openSystemSettings()
            completion?(false)
        case .unavailable:
            completion?(false)
        case .noneNeeded:
            completion?(true)
        }
        return action
    }

    public func requestAccess(completion: ((Bool) -> Void)? = nil) {
        guard let provider else {
            completion?(false)
            return
        }

        provider.requestAccess { [weak self] result in
            DispatchQueue.main.async {
                guard let self else { return }
                switch result {
                case .success(let granted):
                    if granted {
                        provider.resetStoreStateAfterPermissionChange()
                    }
                    self.snapshot.authorizationStatus = self.provider?.authorizationStatus() ?? (granted ? .authorized : .denied)
                    if granted {
                        self.refreshContext(reason: "permission_granted")
                    }
                    completion?(granted)
                case .failure(let error):
                    self.snapshot.errorMessage = error.localizedDescription
                    self.snapshot.authorizationStatus = self.provider?.authorizationStatus() ?? .denied
                    completion?(false)
                }
            }
        }
    }

    public func updateSelectedCalendarIDs(_ calendarIDs: [String]) {
        let normalizedCalendarIDs = TaskerWorkspacePreferences.normalizeSelectedCalendarIDs(calendarIDs)
        guard normalizedCalendarIDs != snapshot.selectedCalendarIDs else { return }

        workspacePreferencesStore.update { preferences in
            preferences.selectedCalendarIDs = normalizedCalendarIDs
        }
        snapshot.selectedCalendarIDs = normalizedCalendarIDs
        refreshContext(reason: "selected_calendars_changed")
    }

    public func setIncludeDeclined(_ include: Bool) {
        workspacePreferencesStore.update { preferences in
            preferences.includeDeclinedCalendarEvents = include
        }
        snapshot.includeDeclined = include
        refreshContext(reason: "include_declined_changed")
    }

    public func setIncludeCanceled(_ include: Bool) {
        workspacePreferencesStore.update { preferences in
            preferences.includeCanceledCalendarEvents = include
        }
        snapshot.includeCanceled = include
        refreshContext(reason: "include_canceled_changed")
    }

    public func setIncludeAllDayInAgenda(_ include: Bool) {
        workspacePreferencesStore.update { preferences in
            preferences.includeAllDayInAgenda = include
        }
        snapshot.includeAllDayInAgenda = include
        refreshContext(reason: "all_day_agenda_changed")
    }

    public func setIncludeAllDayInBusyStrip(_ include: Bool) {
        workspacePreferencesStore.update { preferences in
            preferences.includeAllDayInBusyStrip = include
        }
        snapshot.includeAllDayInBusyStrip = include
        refreshContext(reason: "all_day_busy_changed")
    }

    public func refreshContext(referenceDate: Date = Date(), reason: String = "manual") {
        _ = reason
        let generation = beginRefreshGeneration()

        guard let provider else {
            snapshot.authorizationStatus = .denied
            snapshot.errorMessage = "Calendar provider unavailable."
            clearCalendarContext(keepAvailableCalendars: false)
            return
        }

        refreshAuthorizationStatus()

        guard snapshot.authorizationStatus.isAuthorizedForRead else {
            clearCalendarContext(keepAvailableCalendars: false)
            snapshot.errorMessage = nil
            snapshot.isLoading = false
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
            DispatchQueue.main.async {
                guard let self, self.isCurrentRefreshGeneration(generation) else { return }
                switch calendarsResult {
                case .failure(let error):
                    self.snapshot.isLoading = false
                    self.snapshot.errorMessage = error.localizedDescription
                    self.clearCalendarContext(keepAvailableCalendars: true)
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
                        DispatchQueue.main.async {
                            guard let self, self.isCurrentRefreshGeneration(generation) else { return }
                            self.snapshot.isLoading = false
                            switch eventsResult {
                            case .failure(let error):
                                self.snapshot.errorMessage = error.localizedDescription
                                self.clearCalendarContext(keepAvailableCalendars: true)
                            case .success(let events):
                                self.reconcile(events: events, referenceDate: referenceDate)
                            }
                        }
                    }
                }
            }
        }
    }

    public func eventsForDay(_ day: Date) -> [TaskerCalendarEventSnapshot] {
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

    public func weekAgenda(anchorDate: Date, weekStartsOn: Weekday) -> [TaskerCalendarDayAgenda] {
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

    public func taskFitHint(for task: TaskDefinition, now: Date = Date()) -> TaskerTaskFitHintResult {
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

    public func event(withID eventID: String) -> TaskerCalendarEventSnapshot? {
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
        snapshot.selectedCalendarIDs = TaskerWorkspacePreferences.normalizeSelectedCalendarIDs(preferences.selectedCalendarIDs)
        snapshot.includeDeclined = preferences.includeDeclinedCalendarEvents
        snapshot.includeCanceled = preferences.includeCanceledCalendarEvents
        snapshot.includeAllDayInAgenda = preferences.includeAllDayInAgenda
        snapshot.includeAllDayInBusyStrip = preferences.includeAllDayInBusyStrip
        refreshContext(reason: reason)
    }

    private func persistSelectedCalendarIDs(_ calendarIDs: [String]) {
        let normalizedCalendarIDs = TaskerWorkspacePreferences.normalizeSelectedCalendarIDs(calendarIDs)
        workspacePreferencesStore.update { preferences in
            preferences.selectedCalendarIDs = normalizedCalendarIDs
        }
    }

    private func clearCalendarContext(keepAvailableCalendars: Bool) {
        invalidateProjectionCaches()
        contextEvents = []
        snapshot.eventsInRange = []
        snapshot.busyBlocks = []
        snapshot.nextMeeting = nil
        snapshot.freeUntil = nil
        if keepAvailableCalendars == false {
            snapshot.availableCalendars = []
        }
    }

    private func reconcile(events: [TaskerCalendarEventSnapshot], referenceDate: Date) {
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
}
