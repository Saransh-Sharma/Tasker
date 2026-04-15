import Foundation
import Combine

public final class CalendarIntegrationService: ObservableObject {
    @Published public private(set) var snapshot: TaskerCalendarSnapshot

    private let provider: CalendarEventsProviderProtocol?
    private let workspacePreferencesStore: TaskerWorkspacePreferencesStore
    private let filterEvents = FilterCalendarEventsUseCase()
    private let buildBusyBlocks = BuildCalendarBusyBlocksUseCase()
    private let resolveNextMeeting = ResolveNextMeetingUseCase()
    private let buildWeekAgenda = BuildCalendarWeekAgendaUseCase()
    private let taskFitUseCase = ComputeTaskFitHintUseCase(bufferMinutes: 15)

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
        workspacePreferencesStore.update { preferences in
            preferences.selectedCalendarIDs = calendarIDs
        }
        snapshot.selectedCalendarIDs = calendarIDs
        refreshContext(reason: "selected_calendars_changed")
    }

    public func setIncludeDeclined(_ include: Bool) {
        workspacePreferencesStore.update { preferences in
            preferences.includeDeclinedCalendarEvents = include
        }
        snapshot.includeDeclined = include
        refreshContext(reason: "include_declined_changed")
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
        guard let provider else {
            snapshot.authorizationStatus = .denied
            snapshot.errorMessage = "Calendar provider unavailable."
            return
        }

        refreshAuthorizationStatus()

        guard snapshot.authorizationStatus.isAuthorizedForRead else {
            snapshot.eventsInRange = []
            snapshot.busyBlocks = []
            snapshot.nextMeeting = nil
            snapshot.freeUntil = nil
            snapshot.availableCalendars = []
            snapshot.errorMessage = nil
            return
        }

        let calendar = Calendar.current
        let start = calendar.startOfDay(for: referenceDate)
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start

        snapshot.isLoading = true
        snapshot.errorMessage = nil

        provider.fetchCalendars { [weak self] calendarsResult in
            DispatchQueue.main.async {
                guard let self else { return }
                switch calendarsResult {
                case .failure(let error):
                    self.snapshot.isLoading = false
                    self.snapshot.errorMessage = error.localizedDescription
                case .success(let calendars):
                    self.snapshot.availableCalendars = calendars
                    self.provider?.fetchEvents(
                        startDate: start,
                        endDate: end,
                        calendarIDs: Set(self.snapshot.selectedCalendarIDs)
                    ) { [weak self] eventsResult in
                        DispatchQueue.main.async {
                            guard let self else { return }
                            self.snapshot.isLoading = false
                            switch eventsResult {
                            case .failure(let error):
                                self.snapshot.errorMessage = error.localizedDescription
                                self.snapshot.eventsInRange = []
                                self.snapshot.busyBlocks = []
                                self.snapshot.nextMeeting = nil
                                self.snapshot.freeUntil = nil
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
        let start = calendar.startOfDay(for: day)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start
        return snapshot.eventsInRange
            .filter { $0.endDate > start && $0.startDate < end }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.endDate < rhs.endDate
            }
    }

    public func weekAgenda(anchorDate: Date, weekStartsOn: Weekday) -> [TaskerCalendarDayAgenda] {
        let weekStart = XPCalculationEngine.startOfWeek(for: anchorDate, startingOn: weekStartsOn)
        return buildWeekAgenda.execute(events: snapshot.eventsInRange, weekStart: weekStart)
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
            events: snapshot.eventsInRange,
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

    private func reloadPreferencesAndRefresh(reason: String) {
        let preferences = workspacePreferencesStore.load()
        snapshot.selectedCalendarIDs = preferences.selectedCalendarIDs
        snapshot.includeDeclined = preferences.includeDeclinedCalendarEvents
        snapshot.includeAllDayInAgenda = preferences.includeAllDayInAgenda
        snapshot.includeAllDayInBusyStrip = preferences.includeAllDayInBusyStrip
        refreshContext(reason: reason)
    }

    private func reconcile(events: [TaskerCalendarEventSnapshot], referenceDate: Date) {
        let filteredEvents = filterEvents.execute(
            events: events,
            selectedCalendarIDs: Set(snapshot.selectedCalendarIDs),
            includeDeclined: snapshot.includeDeclined,
            includeAllDayInAgenda: snapshot.includeAllDayInAgenda
        )

        let now = Date()
        let busyHorizonEnd = Calendar.current.date(byAdding: .hour, value: 12, to: now) ?? now
        let busyBlocks = buildBusyBlocks.execute(
            events: filteredEvents,
            includeAllDayEvents: snapshot.includeAllDayInBusyStrip,
            referenceStart: now,
            referenceEnd: busyHorizonEnd
        )

        let nextMeeting = resolveNextMeeting.execute(events: filteredEvents, now: now)
        let freeUntil = nextMeeting?.event.startDate

        snapshot.eventsInRange = filteredEvents
        snapshot.busyBlocks = busyBlocks
        snapshot.nextMeeting = nextMeeting
        snapshot.freeUntil = freeUntil
        snapshot.errorMessage = nil

        if Calendar.current.isDate(referenceDate, inSameDayAs: now) == false {
            // Maintain deterministic behavior for custom date calls by re-sorting only.
            snapshot.eventsInRange = filteredEvents.sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.endDate < rhs.endDate
            }
        }
    }
}
