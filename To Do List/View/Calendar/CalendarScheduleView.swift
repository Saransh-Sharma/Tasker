import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

enum CalendarScheduleTab: String, CaseIterable, Identifiable {
    case today
    case week

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today:
            return String(localized: "Today")
        case .week:
            return String(localized: "Week")
        }
    }
}

enum CalendarScheduleSheet: Identifiable, Equatable {
    case chooser
    case event(id: String)

    var id: String {
        switch self {
        case .chooser:
            return "chooser"
        case .event(let id):
            return "event.\(id)"
        }
    }
}

struct CalendarSchedulePresentationState: Equatable {
    var activeSheet: CalendarScheduleSheet? = nil

    mutating func presentChooser() {
        activeSheet = .chooser
    }

    mutating func cancelChooser() {
        if activeSheet == .chooser {
            activeSheet = nil
        }
    }

    mutating func commitChooser() {
        if activeSheet == .chooser {
            activeSheet = nil
        }
    }

    mutating func selectEvent(id: String) {
        activeSheet = .event(id: id)
    }

    mutating func dismissEventDetail() {
        if case .event = activeSheet {
            activeSheet = nil
        }
    }
}

enum CalendarSchedulePresentationMode {
    case modal
    case embedded
}

struct CalendarSchedulePresentation: Equatable {
    let selectedDate: Date
    let selectedWeekDate: Date
    let weekStartsOn: Weekday
    let weekDefaultSelectedDate: Date
    let currentWeekStart: Date
    let weekRangeLabel: String
    let todayEvents: [TaskerCalendarEventSnapshot]
    let weekAgenda: [TaskerCalendarDayAgenda]
    let weekDates: [Date]
    let selectedWeekEvents: [TaskerCalendarEventSnapshot]

    var weekEventCount: Int {
        weekAgenda.reduce(into: 0) { result, day in
            result += day.events.count
        }
    }
}

private struct CalendarScheduleEventSignature: Equatable {
    let id: String
    let calendarID: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let availability: TaskerCalendarEventAvailability
    let eventStatus: TaskerCalendarEventStatus
    let participationStatus: TaskerCalendarEventParticipationStatus
    let lastModifiedAt: Date?

    init(_ event: TaskerCalendarEventSnapshot) {
        id = event.id
        calendarID = event.calendarID
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        availability = event.availability
        eventStatus = event.eventStatus
        participationStatus = event.participationStatus
        lastModifiedAt = event.lastModifiedAt
    }
}

private struct CalendarSchedulePresentationCacheKey: Equatable {
    let selectedDate: Date
    let selectedWeekDate: Date
    let weekStartsOn: Weekday
    let calendarIdentifier: Calendar.Identifier
    let calendarTimeZone: TimeZone
    let authorizationStatus: TaskerCalendarAuthorizationStatus
    let selectedCalendarIDs: [String]
    let includeDeclined: Bool
    let includeCanceled: Bool
    let includeAllDayInAgenda: Bool
    let events: [CalendarScheduleEventSignature]

    init(
        snapshot: TaskerCalendarSnapshot,
        selectedDate: Date,
        selectedWeekDate: Date,
        weekStartsOn: Weekday,
        calendar: Calendar
    ) {
        self.selectedDate = calendar.startOfDay(for: selectedDate)
        self.selectedWeekDate = calendar.startOfDay(for: selectedWeekDate)
        self.weekStartsOn = weekStartsOn
        self.calendarIdentifier = calendar.identifier
        self.calendarTimeZone = calendar.timeZone
        self.authorizationStatus = snapshot.authorizationStatus
        self.selectedCalendarIDs = snapshot.selectedCalendarIDs.sorted()
        self.includeDeclined = snapshot.includeDeclined
        self.includeCanceled = snapshot.includeCanceled
        self.includeAllDayInAgenda = snapshot.includeAllDayInAgenda
        self.events = snapshot.eventsInRange.map(CalendarScheduleEventSignature.init)
    }
}

struct CalendarSchedulePresentationCache {
    private var cachedKey: CalendarSchedulePresentationCacheKey?
    private var cachedPresentation: CalendarSchedulePresentation?
    private(set) var buildCount = 0
    private(set) var cacheHitCount = 0

    mutating func presentation(
        snapshot: TaskerCalendarSnapshot,
        selectedDate: Date,
        selectedWeekDate: Date,
        weekStartsOn: Weekday,
        calendar: Calendar = .current
    ) -> CalendarSchedulePresentation {
        let key = CalendarSchedulePresentationCacheKey(
            snapshot: snapshot,
            selectedDate: selectedDate,
            selectedWeekDate: selectedWeekDate,
            weekStartsOn: weekStartsOn,
            calendar: calendar
        )
        if let cachedKey, cachedKey == key, let cachedPresentation {
            cacheHitCount += 1
            return cachedPresentation
        }
        let presentation = CalendarSchedulePresentationBuilder.build(
            snapshot: snapshot,
            selectedDate: selectedDate,
            selectedWeekDate: selectedWeekDate,
            weekStartsOn: weekStartsOn,
            calendar: calendar
        )
        cachedKey = key
        cachedPresentation = presentation
        buildCount += 1
        return presentation
    }
}

enum CalendarSchedulePresentationBuilder {
    static func empty(
        selectedDate: Date,
        selectedWeekDate: Date,
        weekStartsOn: Weekday,
        calendar: Calendar = .current
    ) -> CalendarSchedulePresentation {
        build(
            snapshot: TaskerCalendarSnapshot.empty,
            selectedDate: selectedDate,
            selectedWeekDate: selectedWeekDate,
            weekStartsOn: weekStartsOn,
            calendar: calendar
        )
    }

    static func build(
        snapshot: TaskerCalendarSnapshot,
        selectedDate: Date,
        selectedWeekDate: Date,
        weekStartsOn: Weekday,
        calendar: Calendar = .current
    ) -> CalendarSchedulePresentation {
        let interval = TaskerPerformanceTrace.begin("CalendarScheduleProjectionBuild")
        defer { TaskerPerformanceTrace.end(interval) }

        let weekStart = XPCalculationEngine.startOfWeek(for: selectedDate, startingOn: weekStartsOn)
        let weekDates = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
        let weekDefaultSelectedDate = defaultSelectedWeekDate(
            selectedDate: selectedDate,
            weekDates: weekDates,
            calendar: calendar
        )
        let weekRangeLabel = rangeLabel(weekStart: weekStart, calendar: calendar)
        let weekAgenda = weekDates.map { day in
            let dayStart = calendar.startOfDay(for: day)
            return TaskerCalendarDayAgenda(
                date: dayStart,
                events: eventsForDay(dayStart, in: snapshot.eventsInRange, calendar: calendar)
            )
        }

        return CalendarSchedulePresentation(
            selectedDate: selectedDate,
            selectedWeekDate: selectedWeekDate,
            weekStartsOn: weekStartsOn,
            weekDefaultSelectedDate: weekDefaultSelectedDate,
            currentWeekStart: weekStart,
            weekRangeLabel: weekRangeLabel,
            todayEvents: eventsForDay(selectedDate, in: snapshot.eventsInRange, calendar: calendar),
            weekAgenda: weekAgenda,
            weekDates: weekDates,
            selectedWeekEvents: eventsForDay(selectedWeekDate, in: snapshot.eventsInRange, calendar: calendar)
        )
    }

    private static func eventsForDay(
        _ day: Date,
        in events: [TaskerCalendarEventSnapshot],
        calendar: Calendar
    ) -> [TaskerCalendarEventSnapshot] {
        let startOfDay = calendar.startOfDay(for: day)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay
        return events
            .filter { $0.endDate > startOfDay && $0.startDate < endOfDay }
            .sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate {
                    return lhs.startDate < rhs.startDate
                }
                return lhs.endDate < rhs.endDate
            }
    }

    static func defaultSelectedWeekDate(
        selectedDate: Date,
        weekStartsOn: Weekday,
        calendar: Calendar = .current
    ) -> Date {
        let weekStart = XPCalculationEngine.startOfWeek(for: selectedDate, startingOn: weekStartsOn)
        let weekDates = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: weekStart)
        }
        return defaultSelectedWeekDate(selectedDate: selectedDate, weekDates: weekDates, calendar: calendar)
    }

    private static func defaultSelectedWeekDate(
        selectedDate: Date,
        weekDates: [Date],
        calendar: Calendar
    ) -> Date {
        if weekDates.contains(where: { calendar.isDate($0, inSameDayAs: selectedDate) }) {
            return selectedDate
        }
        return weekDates.first ?? selectedDate
    }

    private static func rangeLabel(weekStart: Date, calendar: Calendar) -> String {
        guard let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) else {
            return TaskerCalendarPresentation.scheduleDateText(for: weekStart)
        }
        return "\(TaskerCalendarPresentation.compactDateText(for: weekStart))-\(TaskerCalendarPresentation.compactDateText(for: weekEnd))"
    }
}

struct CalendarScheduleView: View {
    @ObservedObject var service: CalendarIntegrationService
    @Binding var selectedDate: Date
    let weekStartsOn: Weekday
    let presentationMode: CalendarSchedulePresentationMode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.taskerLayoutClass) private var layoutClass

    @State private var selectedTab: CalendarScheduleTab = .today
    @State private var presentationState = CalendarSchedulePresentationState()
    @State private var selectedWeekDate: Date
    @State private var presentationCache = CalendarSchedulePresentationCache()
    @State private var schedulePresentation: CalendarSchedulePresentation

    init(
        service: CalendarIntegrationService,
        weekStartsOn: Weekday,
        presentationMode: CalendarSchedulePresentationMode,
        selectedDate: Binding<Date> = .constant(Date())
    ) {
        let initialSelectedDate = selectedDate.wrappedValue
        self.service = service
        self._selectedDate = selectedDate
        self.weekStartsOn = weekStartsOn
        self.presentationMode = presentationMode
        self._selectedWeekDate = State(initialValue: initialSelectedDate)
        self._schedulePresentation = State(
            initialValue: CalendarSchedulePresentationBuilder.empty(
                selectedDate: initialSelectedDate,
                selectedWeekDate: initialSelectedDate,
                weekStartsOn: weekStartsOn
            )
        )
    }

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    private func makePresentation(selectedWeekDate: Date) -> CalendarSchedulePresentation {
        var cache = presentationCache
        let presentation = cache.presentation(
            snapshot: service.snapshot,
            selectedDate: selectedDate,
            selectedWeekDate: selectedWeekDate,
            weekStartsOn: weekStartsOn
        )
        presentationCache = cache
        return presentation
    }

    var body: some View {
        Group {
            if presentationMode == .modal {
                NavigationStack {
                    scheduleContent
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(String(localized: "Close"), action: dismiss.callAsFunction)
                            }
                        }
                }
            } else {
                scheduleContent
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
        .task {
            let defaultWeekDate = CalendarSchedulePresentationBuilder.defaultSelectedWeekDate(
                selectedDate: selectedDate,
                weekStartsOn: weekStartsOn
            )
            selectedWeekDate = defaultWeekDate
            schedulePresentation = makePresentation(selectedWeekDate: defaultWeekDate)
            service.refreshContext(referenceDate: selectedDate, reason: "schedule_appear")
        }
        .onChange(of: selectedDate) { _, newValue in
            let defaultWeekDate = CalendarSchedulePresentationBuilder.defaultSelectedWeekDate(
                selectedDate: newValue,
                weekStartsOn: weekStartsOn
            )
            selectedWeekDate = defaultWeekDate
            schedulePresentation = makePresentation(selectedWeekDate: defaultWeekDate)
            service.refreshContext(referenceDate: newValue, reason: "schedule_selected_date_changed")
        }
        .onChange(of: selectedWeekDate) { _, newValue in
            schedulePresentation = makePresentation(selectedWeekDate: newValue)
        }
        .onChange(of: service.snapshot) { _, _ in
            schedulePresentation = makePresentation(selectedWeekDate: selectedWeekDate)
        }
        .sheet(item: $presentationState.activeSheet) { sheet in
            switch sheet {
            case .event(let eventID):
                EventKitEventDetailView(
                    eventID: eventID,
                    onDismiss: {
                        presentationState.dismissEventDetail()
                    }
                )
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.tasker(.bgElevated))
            case .chooser:
                EventKitCalendarChooserSheet(
                    service: service,
                    initialSelectedCalendarIDs: service.snapshot.selectedCalendarIDs,
                    onCancel: {
                        presentationState.cancelChooser()
                    },
                    onCommit: { selectedIDs in
                        service.updateSelectedCalendarIDs(selectedIDs)
                        presentationState.commitChooser()
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Color.tasker(.bgElevated))
            }
        }
    }

    private var scheduleContent: some View {
        let currentPresentation = schedulePresentation
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: spacing.s20) {
                CalendarScheduleHeaderView(
                    snapshot: service.snapshot,
                    selectedTab: selectedTab,
                    contextLabel: selectedTab == .today
                        ? "Today \u{00B7} \(TaskerCalendarPresentation.scheduleDateText(for: selectedDate))"
                        : "Week \u{00B7} \(currentPresentation.weekRangeLabel)",
                    onSelectTab: { tab in
                        selectedTab = tab
                        if tab == .week {
                            selectedWeekDate = currentPresentation.weekDefaultSelectedDate
                        }
                    },
                    onOpenFilters: handleCalendarFilterTap
                )
                .enhancedStaggeredAppearance(index: 0)

                content(presentation: currentPresentation)
                    .enhancedStaggeredAppearance(index: 1)
            }
            .taskerReadableContent(maxWidth: layoutClass.isPad ? 960 : .infinity, alignment: .center)
            .padding(.horizontal, spacing.screenHorizontal)
            .padding(.top, spacing.s16)
            .padding(.bottom, spacing.sectionGap)
        }
        .refreshable {
            service.refreshContext(referenceDate: selectedDate, reason: "schedule_pull_to_refresh")
        }
        .accessibilityIdentifier("schedule.list")
        .background(Color.tasker.bgCanvas.ignoresSafeArea())
    }

    @ViewBuilder
    private func content(presentation: CalendarSchedulePresentation) -> some View {
        if service.snapshot.authorizationStatus.isAuthorizedForRead == false {
            permissionRequiredView
        } else if isInitialLoadingStateVisible {
            initialLoadingView
        } else if let error = service.snapshot.errorMessage, !error.isEmpty {
            errorView(error)
        } else if service.snapshot.selectedCalendarIDs.isEmpty {
            noCalendarSelectionView
        } else {
            activeContent(presentation: presentation)
        }
    }

    private var isInitialLoadingStateVisible: Bool {
        service.snapshot.authorizationStatus.isAuthorizedForRead
            && service.snapshot.isLoading
            && service.snapshot.errorMessage?.isEmpty != false
            && service.snapshot.availableCalendars.isEmpty
            && service.snapshot.eventsInRange.isEmpty
    }

    private var initialLoadingView: some View {
        CalendarScheduleStatePanel(
            iconName: "calendar.badge.clock",
            title: String(localized: "Loading schedule"),
            message: String(localized: "Fetching calendars and events for this workspace."),
            accentColor: Color.tasker.stateInfo,
            buttonTitle: nil,
            buttonAccessibilityIdentifier: nil,
            bodyAccessibilityIdentifier: "schedule.loading.initial",
            action: nil
        )
    }

    @ViewBuilder
    private func activeContent(presentation: CalendarSchedulePresentation) -> some View {
        switch selectedTab {
        case .today:
            CalendarScheduleTodayContent(
                snapshot: service.snapshot,
                date: selectedDate,
                events: presentation.todayEvents,
                onSelectEvent: { presentationState.selectEvent(id: $0.id) }
            )
        case .week:
            CalendarScheduleWeekContent(
                weekDates: presentation.weekDates,
                selectedDate: $selectedWeekDate,
                eventsForSelectedDay: presentation.selectedWeekEvents,
                weekEventCount: presentation.weekEventCount,
                onSelectEvent: { presentationState.selectEvent(id: $0.id) }
            )
        }
    }

    private var permissionRequiredView: some View {
        CalendarScheduleStatePanel(
            iconName: "calendar.badge.exclamationmark",
            title: permissionTitle,
            message: permissionSubtitle,
            accentColor: Color.tasker.statusWarning,
            buttonTitle: permissionButtonTitle,
            buttonAccessibilityIdentifier: "schedule.permission.connect",
            bodyAccessibilityIdentifier: permissionStateAccessibilityID,
            action: performPermissionAction
        )
    }

    private var noCalendarSelectionView: some View {
        CalendarScheduleStatePanel(
            iconName: "calendar.badge.plus",
            title: String(localized: "No calendars selected"),
            message: String(localized: "Choose the calendars that should shape the schedule view and Home day lane."),
            accentColor: Color.tasker.accentSecondary,
            buttonTitle: String(localized: "Choose Calendars"),
            buttonAccessibilityIdentifier: "schedule.noCalendars.choose",
            bodyAccessibilityIdentifier: "schedule.noCalendars.body",
            action: {
                presentationState.presentChooser()
            }
        )
    }

    private func errorView(_ message: String) -> some View {
        CalendarScheduleStatePanel(
            iconName: "wifi.exclamationmark",
            title: String(localized: "Unable to load calendar"),
            message: message,
            accentColor: Color.tasker.statusDanger,
            buttonTitle: String(localized: "Retry"),
            buttonAccessibilityIdentifier: "schedule.error.retry",
            bodyAccessibilityIdentifier: "schedule.error.message",
            action: {
                service.refreshContext(reason: "schedule_error_retry")
            }
        )
    }

    private var permissionButtonTitle: String? {
        switch permissionAccessAction {
        case .requestPermission:
            return String(localized: "Allow Full Calendar Access")
        case .openSystemSettings:
            return String(localized: "Open Settings")
        case .unavailable, .noneNeeded:
            return nil
        }
    }

    private var permissionTitle: String {
        switch service.snapshot.authorizationStatus {
        case .denied:
            return String(localized: "Calendar access is off")
        case .restricted:
            return String(localized: "Calendar access is restricted")
        case .writeOnly:
            return String(localized: "Write-only access detected")
        case .notDetermined, .authorized:
            return String(localized: "Calendar access is required")
        }
    }

    private var permissionSubtitle: String {
        switch service.snapshot.authorizationStatus {
        case .notDetermined:
            return String(localized: "Grant calendar access to bring Today and Week schedule context into Tasker.")
        case .denied:
            return String(localized: "Calendar access is denied by iOS. Enable Tasker in Settings > Privacy & Security > Calendars. If Tasker is missing, restart your device, reinstall Tasker, or reset Location & Privacy.")
        case .restricted:
            return String(localized: "Calendar access is restricted by system policy and cannot be changed here.")
        case .writeOnly:
            return String(localized: "Tasker has write-only access. Allow full calendar access so schedule events can appear.")
        case .authorized:
            return String(localized: "Calendar access is required.")
        }
    }

    private var permissionStateAccessibilityID: String {
        switch service.snapshot.authorizationStatus {
        case .notDetermined:
            return "schedule.permission.state.notDetermined"
        case .denied:
            return "schedule.permission.state.denied"
        case .restricted:
            return "schedule.permission.state.restricted"
        case .writeOnly:
            return "schedule.permission.state.writeOnly"
        case .authorized:
            return "schedule.permission.state.authorized"
        }
    }

    private func handleCalendarFilterTap() {
        if service.snapshot.authorizationStatus.isAuthorizedForRead {
            presentationState.presentChooser()
        } else {
            performPermissionAction()
        }
    }

    private func performPermissionAction() {
        _ = service.performAccessAction(source: "schedule", openSystemSettings: openSystemSettings)
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
        #endif
    }

    private var permissionAccessAction: CalendarAccessAction {
        service.accessAction(for: service.snapshot.authorizationStatus)
    }
}

typealias HomeDayTimelineLayoutPlan = TaskerCalendarTimelineLayoutPlan
typealias HomeDayTimelineLayoutPlanner = TaskerCalendarTimelinePlanner

private struct CalendarScheduleHeaderView: View {
    let snapshot: TaskerCalendarSnapshot
    let selectedTab: CalendarScheduleTab
    let contextLabel: String
    let onSelectTab: (CalendarScheduleTab) -> Void
    let onOpenFilters: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(contextLabel)
                        .font(layoutClass.isPad ? .tasker(.title2) : .tasker(.title3))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .accessibilityIdentifier("schedule.header.context")

                    Text(selectionLabel)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                }

                Spacer(minLength: 0)

                Button(action: onOpenFilters) {
                    Text(String(localized: "Filters"))
                        .font(.tasker(.bodyStrong))
                        .foregroundStyle(Color.tasker.textPrimary)
                        .padding(.horizontal, spacing.s12)
                        .padding(.vertical, spacing.s8)
                        .background(
                            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                                .fill(Color.tasker.surfacePrimary)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                                .stroke(Color.tasker.strokeHairline.opacity(0.8), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("schedule.toolbar.filters")
                .accessibilityLabel(String(localized: "Choose calendars"))
            }

            HStack(spacing: spacing.s8) {
                ForEach(CalendarScheduleTab.allCases) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(spacing.s4)
            .background(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.xl, style: .continuous)
                    .fill(Color.tasker.surfaceSecondary.opacity(0.8))
            )
            .overlay(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.xl, style: .continuous)
                    .stroke(Color.tasker.strokeHairline.opacity(0.75), lineWidth: 1)
            )
            .accessibilityIdentifier("schedule.segmented")
        }
        .padding(layoutClass.isPad ? spacing.s20 : spacing.s16)
        .background(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous)
                .fill(Color.tasker.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous)
                .stroke(Color.tasker.strokeHairline.opacity(0.78), lineWidth: 1)
        )
    }

    private func tabButton(for tab: CalendarScheduleTab) -> some View {
        Button {
            onSelectTab(tab)
        } label: {
            Text(tab.title)
                .font(.tasker(.bodyStrong))
                .foregroundStyle(selectedTab == tab ? Color.tasker.textInverse : Color.tasker.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, spacing.s12)
                .padding(.vertical, spacing.s12)
                .background(
                    RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                        .fill(selectedTab == tab ? Color.tasker.actionPrimary : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("schedule.segment.\(tab.rawValue)")
        .accessibilityValue(selectedTab == tab ? String(localized: "selected") : String(localized: "unselected"))
    }

    private var selectionLabel: String {
        if snapshot.authorizationStatus.isAuthorizedForRead == false {
            return String(localized: "Calendar access required")
        }

        let count = snapshot.selectedCalendarIDs.count
        switch count {
        case 0:
            return String(localized: "No calendars selected")
        case 1:
            return String(localized: "1 calendar selected")
        default:
            return String(localized: "\(count) calendars selected")
        }
    }
}

private struct CalendarScheduleTodayContent: View {
    let snapshot: TaskerCalendarSnapshot
    let date: Date
    let events: [TaskerCalendarEventSnapshot]
    let onSelectEvent: (TaskerCalendarEventSnapshot) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            CalendarScheduleNextUpCard(snapshot: snapshot)

            CalendarScheduleTimelineSection(
                date: date,
                events: events,
                emptyText: String(localized: "No timed blocks today."),
                accessibilityIdentifier: "schedule.timeline.expanded",
                onSelectEvent: onSelectEvent
            )

            if events.isEmpty {
                Text(String(localized: "No events today"))
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .accessibilityIdentifier("schedule.today.empty")
            }
        }
    }
}

private struct CalendarScheduleWeekContent: View {
    let weekDates: [Date]
    @Binding var selectedDate: Date
    let eventsForSelectedDay: [TaskerCalendarEventSnapshot]
    let weekEventCount: Int
    let onSelectEvent: (TaskerCalendarEventSnapshot) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            if weekEventCount == 0 {
                CalendarScheduleStatePanel(
                    iconName: "calendar.badge.clock",
                    title: String(localized: "No events this week"),
                    message: String(localized: "The week horizon is clear with the currently selected calendars."),
                    accentColor: Color.tasker.stateInfo,
                    buttonTitle: nil,
                    buttonAccessibilityIdentifier: nil,
                    bodyAccessibilityIdentifier: "schedule.week.empty",
                    action: nil
                )
            } else {
                weekStrip

                Text(selectedDaySummary)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .padding(.horizontal, spacing.s12)
                    .padding(.vertical, spacing.s8)
                    .background(
                        RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                            .fill(Color.tasker.surfaceSecondary)
                    )
                    .accessibilityIdentifier("schedule.week.selectedDay")

                CalendarScheduleTimelineSection(
                    date: selectedDate,
                    events: eventsForSelectedDay,
                    emptyText: String(localized: "No timed blocks on selected day."),
                    accessibilityIdentifier: "schedule.timeline.expanded",
                    onSelectEvent: onSelectEvent
                )
            }
        }
    }

    private var weekStrip: some View {
        HStack(spacing: spacing.s8) {
            ForEach(weekDates, id: \.timeIntervalSince1970) { date in
                let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
                Button {
                    selectedDate = date
                } label: {
                    VStack(spacing: 2) {
                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(.tasker(.caption2))
                            .foregroundStyle(isSelected ? Color.tasker.textInverse : Color.tasker.textSecondary)
                        Text(date.formatted(.dateTime.day()))
                            .font(.tasker(.bodyStrong))
                            .foregroundStyle(isSelected ? Color.tasker.textInverse : Color.tasker.textPrimary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, spacing.s8)
                    .background(
                        RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                            .fill(isSelected ? Color.tasker.actionPrimary : Color.tasker.surfacePrimary)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                            .stroke(Color.tasker.strokeHairline.opacity(0.7), lineWidth: isSelected ? 0 : 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("schedule.week.day.\(dayIdentifier(for: date))")
            }
        }
    }

    private var selectedDaySummary: String {
        let dayText = TaskerCalendarPresentation.scheduleDateText(for: selectedDate)
        let count = eventsForSelectedDay.count
        let suffix = count == 1 ? "event" : "events"
        return "Selected day: \(dayText) \u{00B7} \(count) \(suffix)"
    }

    private func dayIdentifier(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct CalendarScheduleNextUpCard: View {
    let snapshot: TaskerCalendarSnapshot

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text(primaryLine)
                .font(.tasker(.bodyStrong))
                .foregroundStyle(Color.tasker.textPrimary)
            Text(secondaryLine)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous)
                .fill(Color.tasker.surfacePrimary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous)
                .stroke(Color.tasker.strokeHairline.opacity(0.7), lineWidth: 1)
        )
        .accessibilityIdentifier("schedule.today.nextUp")
    }

    private var primaryLine: String {
        if let nextMeeting = snapshot.nextMeeting {
            return "Next up: \(nextMeeting.event.title)"
        }
        return String(localized: "Next up: Clear")
    }

    private var secondaryLine: String {
        if let nextMeeting = snapshot.nextMeeting {
            return TaskerCalendarPresentation.timeRangeText(for: nextMeeting.event)
        }
        if let freeUntil = snapshot.freeUntil {
            return String(localized: "Free until \(freeUntil.formatted(date: .omitted, time: .shortened))")
        }
        return String(localized: "No upcoming meetings.")
    }
}

private struct CalendarScheduleTimelineSection: View {
    let date: Date
    let events: [TaskerCalendarEventSnapshot]
    let emptyText: String
    let accessibilityIdentifier: String
    let onSelectEvent: (TaskerCalendarEventSnapshot) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    private var timedEvents: [TaskerCalendarEventSnapshot] {
        events.filter { !$0.isAllDay && $0.isBusy }
    }

    private var targetHour: Int {
        TaskerCalendarTimelinePlanner.initialExpandedHour(for: events, on: date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                Text(String(localized: "Timeline"))
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker.textPrimary)

                Spacer(minLength: 0)

                Text(TaskerCalendarPresentation.scheduleDateText(for: date))
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
            }

            if timedEvents.isEmpty {
                Text(emptyText)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, spacing.s12)
                    .accessibilityIdentifier("schedule.timeline.empty")
            } else {
                TaskerCalendarTimelineView(
                    date: date,
                    events: events,
                    density: .expanded,
                    showsDateLabel: false,
                    emptyText: emptyText,
                    accessibilityIdentifier: accessibilityIdentifier,
                    accessibilityLabelText: String(localized: "Live timeline for the selected day."),
                    initialVisibleHour: targetHour,
                    onSelectEvent: onSelectEvent
                )
            }
        }
    }
}

private struct CalendarScheduleStatePanel: View {
    let iconName: String
    let title: String
    let message: String
    let accentColor: Color
    let buttonTitle: String?
    let buttonAccessibilityIdentifier: String?
    let bodyAccessibilityIdentifier: String
    let action: (() -> Void)?

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            Image(systemName: iconName)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(accentColor)

            Text(title)
                .font(.tasker(.sectionTitle))
                .foregroundStyle(Color.tasker.textPrimary)

            Text(message)
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker.textSecondary)
                .accessibilityIdentifier(bodyAccessibilityIdentifier)

            if let buttonTitle, let action {
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.tasker(.bodyStrong))
                        .foregroundStyle(Color.tasker.textInverse)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier(buttonAccessibilityIdentifier ?? "")
            }
        }
        .padding(spacing.s16)
        .background(Color.tasker.bgElevated)
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous)
                .stroke(Color.tasker.strokeHairline.opacity(0.75), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous))
    }
}

private struct CalendarScheduleEventRow: View {
    let event: TaskerCalendarEventSnapshot
    let action: () -> Void

    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor

    private var badges: [TaskerCalendarEventBadge] {
        TaskerCalendarPresentation.badges(for: event)
    }

    private var accentColor: Color {
        TaskerHexColor.color(event.calendarColorHex, fallback: Color.tasker.accentPrimary)
    }

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: TaskerTheme.Spacing.md) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(accentColor)
                    .frame(width: differentiateWithoutColor ? 8 : 4, height: 44)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Color.tasker.textInverse.opacity(differentiateWithoutColor ? 0.4 : 0), lineWidth: 1)
                    )
                    .padding(.top, 2)

                VStack(alignment: .leading, spacing: TaskerTheme.Spacing.xs) {
                    HStack(alignment: .top, spacing: TaskerTheme.Spacing.xs) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(event.title)
                                .font(.tasker(.headline))
                                .foregroundStyle(Color.tasker.textPrimary)
                                .strikethrough(event.isCanceled, color: Color.tasker.textSecondary)
                                .lineLimit(3)

                            Text(TaskerCalendarPresentation.timeRangeText(for: event))
                                .font(.tasker(.callout))
                                .foregroundStyle(Color.tasker.textSecondary)
                        }

                        Spacer(minLength: 0)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Color.tasker.textTertiary)
                            .padding(.top, 4)
                    }

                    if let metadataLine {
                        Text(metadataLine)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker.textTertiary)
                            .lineLimit(1)
                    }

                    if !badges.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(Array(badges.prefix(3))) { badge in
                                CalendarScheduleBadgePill(badge: badge)
                            }
                        }
                        .accessibilityElement(children: .contain)
                    }
                }
            }
            .padding(TaskerTheme.Spacing.md)
            .opacity(event.isCanceled ? 0.72 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("schedule.event.\(event.id)")
        .accessibilityLabel(accessibilityLabel)
    }

    private var metadataLine: String? {
        let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let location, !location.isEmpty {
            return "\(event.calendarTitle) • \(location)"
        }
        return event.calendarTitle
    }

    private var accessibilityLabel: String {
        var components = [event.title, TaskerCalendarPresentation.timeRangeText(for: event), event.calendarTitle]
        components.append(contentsOf: badges.map(\.title))
        return components.joined(separator: ", ")
    }
}

private struct CalendarScheduleBadgePill: View {
    let badge: TaskerCalendarEventBadge

    var body: some View {
        Label(badge.title, systemImage: badge.systemImage)
            .font(.tasker(.caption2))
            .foregroundStyle(textColor)
            .padding(.horizontal, TaskerTheme.Spacing.xs)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
    }

    private var backgroundColor: Color {
        switch badge.tone {
        case .accent:
            return Color.tasker.accentWash
        case .warning:
            return Color.tasker.statusWarning.opacity(0.12)
        case .danger:
            return Color.tasker.statusDanger.opacity(0.1)
        case .neutral:
            return Color.tasker.surfaceSecondary
        }
    }

    private var borderColor: Color {
        switch badge.tone {
        case .accent:
            return Color.tasker.actionFocus.opacity(0.52)
        case .warning:
            return Color.tasker.statusWarning.opacity(0.34)
        case .danger:
            return Color.tasker.statusDanger.opacity(0.34)
        case .neutral:
            return Color.tasker.strokeHairline
        }
    }

    private var textColor: Color {
        switch badge.tone {
        case .accent:
            return Color.tasker.actionPrimary
        case .warning:
            return Color.tasker.statusWarning
        case .danger:
            return Color.tasker.statusDanger
        case .neutral:
            return Color.tasker.textSecondary
        }
    }
}

enum TaskerCalendarTimelineDensity {
    case compact
    case expanded
}

struct TaskerCalendarTimelineLayoutPlan: Equatable {
    struct PositionedEvent: Equatable, Identifiable {
        let event: TaskerCalendarEventSnapshot
        let lane: Int
        let laneCount: Int
        let columnSpan: Int
        let startMinute: Int
        let endMinute: Int

        var id: String { event.id }
    }

    let startMinute: Int
    let endMinute: Int
    let positionedEvents: [PositionedEvent]

    var startHour: Int {
        startMinute / 60
    }

    var endHour: Int {
        let inclusiveEndMinute = max(startMinute, endMinute - 1)
        return max(startHour, inclusiveEndMinute / 60)
    }

    var hourMarkers: [Int] {
        Array(startHour...endHour)
    }
}

enum TaskerCalendarTimelinePlanner {
    static let defaultWorkdayStartHour = 8
    static let defaultWorkdayEndHour = 18
    private static let compactWindowDurationMinutes = 135

    private struct ClippedEvent {
        let event: TaskerCalendarEventSnapshot
        let startMinute: Int
        let endMinute: Int
    }

    static func makePlan(
        for events: [TaskerCalendarEventSnapshot],
        on date: Date,
        anchorDate: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskerCalendarTimelineLayoutPlan? {
        makePlan(
            for: events,
            on: date,
            density: .compact,
            anchorDate: anchorDate,
            calendar: calendar
        )
    }

    static func makePlan(
        for events: [TaskerCalendarEventSnapshot],
        on date: Date,
        density: TaskerCalendarTimelineDensity,
        anchorDate: Date = Date(),
        calendar: Calendar = .current
    ) -> TaskerCalendarTimelineLayoutPlan? {
        let selectedDayEvents = events
            .filter { !$0.isAllDay && $0.isBusy }
            .compactMap { clip($0, to: date, calendar: calendar) }
            .sorted { lhs, rhs in
                if lhs.startMinute != rhs.startMinute {
                    return lhs.startMinute < rhs.startMinute
                }
                return lhs.endMinute < rhs.endMinute
            }

        guard !selectedDayEvents.isEmpty else { return nil }

        let visibleRange = visibleRange(
            for: selectedDayEvents,
            density: density,
            anchorDate: anchorDate,
            calendar: calendar
        )

        let visibleEvents = selectedDayEvents.compactMap { event in
            clip(event, visibleStartMinute: visibleRange.startMinute, visibleEndMinute: visibleRange.endMinute)
        }

        let clusters = overlapClusters(for: visibleEvents)
        let positionedEvents = clusters.flatMap { cluster -> [TaskerCalendarTimelineLayoutPlan.PositionedEvent] in
            var laneEndMinutes: [Int] = []
            var positionedCluster: [TaskerCalendarTimelineLayoutPlan.PositionedEvent] = []

            for event in cluster {
                if let reusableLane = laneEndMinutes.firstIndex(where: { $0 <= event.startMinute }) {
                    laneEndMinutes[reusableLane] = event.endMinute
                    positionedCluster.append(
                        TaskerCalendarTimelineLayoutPlan.PositionedEvent(
                            event: event.event,
                            lane: reusableLane,
                            laneCount: 0,
                            columnSpan: 1,
                            startMinute: event.startMinute,
                            endMinute: event.endMinute
                        )
                    )
                } else {
                    laneEndMinutes.append(event.endMinute)
                    positionedCluster.append(
                        TaskerCalendarTimelineLayoutPlan.PositionedEvent(
                            event: event.event,
                            lane: laneEndMinutes.count - 1,
                            laneCount: 0,
                            columnSpan: 1,
                            startMinute: event.startMinute,
                            endMinute: event.endMinute
                        )
                    )
                }
            }

            let laneCount = max(1, laneEndMinutes.count)
            return positionedCluster.map { positioned in
                let columnSpan = maxColumnSpan(
                    for: positioned,
                    in: positionedCluster,
                    laneCount: laneCount
                )
                return TaskerCalendarTimelineLayoutPlan.PositionedEvent(
                    event: positioned.event,
                    lane: positioned.lane,
                    laneCount: laneCount,
                    columnSpan: columnSpan,
                    startMinute: positioned.startMinute,
                    endMinute: positioned.endMinute
                )
            }
        }

        return TaskerCalendarTimelineLayoutPlan(
            startMinute: visibleRange.startMinute,
            endMinute: visibleRange.endMinute,
            positionedEvents: positionedEvents
        )
    }

    static func initialExpandedHour(
        for events: [TaskerCalendarEventSnapshot],
        on date: Date,
        anchorDate: Date = Date(),
        workdayStartHour: Int = defaultWorkdayStartHour,
        workdayEndHour: Int = defaultWorkdayEndHour,
        calendar: Calendar = .current
    ) -> Int {
        let selectedDayEvents = events
            .filter { !$0.isAllDay && $0.isBusy }
            .compactMap { clip($0, to: date, calendar: calendar) }
            .sorted { $0.startMinute < $1.startMinute }

        let isToday = calendar.isDate(anchorDate, inSameDayAs: date)
        let currentHour = isToday
            ? calendar.component(.hour, from: anchorDate)
            : calendar.component(.hour, from: date)
        let earliestHour = selectedDayEvents.map { $0.startMinute / 60 }.min()
        let nextOrLaterHour = selectedDayEvents
            .map { $0.startMinute / 60 }
            .filter { $0 >= currentHour }
            .min()

        guard isToday else {
            if let earliestHour {
                return min(23, max(0, earliestHour))
            }
            return workdayStartHour
        }

        if currentHour < workdayStartHour {
            if let earliestHour, earliestHour < workdayStartHour {
                return max(0, earliestHour)
            }
            return workdayStartHour
        }

        if currentHour <= workdayEndHour {
            return currentHour
        }

        if let nextOrLaterHour {
            return min(23, nextOrLaterHour)
        }

        return min(23, currentHour)
    }

    private static func visibleRange(
        for events: [ClippedEvent],
        density: TaskerCalendarTimelineDensity,
        anchorDate: Date,
        calendar: Calendar
    ) -> (startMinute: Int, endMinute: Int) {
        switch density {
        case .expanded:
            return (0, 24 * 60)
        case .compact:
            let anchorMinute = calendar.component(.hour, from: anchorDate) * 60
                + calendar.component(.minute, from: anchorDate)
            let defaultStart = max(0, anchorMinute - 60)
            let defaultEnd = min(24 * 60, defaultStart + compactWindowDurationMinutes)
            let defaultWindowContainsEvent = events.contains { event in
                event.endMinute > defaultStart && event.startMinute < defaultEnd
            }

            if defaultWindowContainsEvent {
                return alignedCompactWindow(startMinute: defaultStart)
            }

            if let nextEvent = events.first(where: { $0.startMinute >= anchorMinute }) {
                return alignedCompactWindow(startMinute: max(0, nextEvent.startMinute - 60))
            }

            if let lastEvent = events.last {
                return alignedCompactWindow(startMinute: max(0, lastEvent.startMinute - 60))
            }

            return alignedCompactWindow(startMinute: defaultStart)
        }
    }

    private static func alignedCompactWindow(startMinute: Int) -> (startMinute: Int, endMinute: Int) {
        let latestAllowedStartHour = Int(floor(Double((24 * 60) - compactWindowDurationMinutes) / 60.0))
        let roundedStartHour = max(0, min(latestAllowedStartHour, Int(floor(Double(startMinute) / 60.0))))
        let visibleStartMinute = roundedStartHour * 60
        let visibleEndMinute = min(24 * 60, visibleStartMinute + compactWindowDurationMinutes)
        return (visibleStartMinute, visibleEndMinute)
    }

    private static func overlapClusters(for events: [ClippedEvent]) -> [[ClippedEvent]] {
        var clusters: [[ClippedEvent]] = []
        var currentCluster: [ClippedEvent] = []
        var currentClusterEndMinute = 0

        for event in events {
            if currentCluster.isEmpty {
                currentCluster = [event]
                currentClusterEndMinute = event.endMinute
                continue
            }

            if event.startMinute < currentClusterEndMinute {
                currentCluster.append(event)
                currentClusterEndMinute = max(currentClusterEndMinute, event.endMinute)
            } else {
                clusters.append(currentCluster)
                currentCluster = [event]
                currentClusterEndMinute = event.endMinute
            }
        }

        if !currentCluster.isEmpty {
            clusters.append(currentCluster)
        }

        return clusters
    }

    private static func maxColumnSpan(
        for event: TaskerCalendarTimelineLayoutPlan.PositionedEvent,
        in cluster: [TaskerCalendarTimelineLayoutPlan.PositionedEvent],
        laneCount: Int
    ) -> Int {
        guard laneCount > 1 else { return 1 }

        var span = 1

        for candidateLane in (event.lane + 1)..<laneCount {
            let hasOverlapInLane = cluster.contains { other in
                other.lane == candidateLane
                    && other.id != event.id
                    && intervalsOverlap(
                        lhsStart: event.startMinute,
                        lhsEnd: event.endMinute,
                        rhsStart: other.startMinute,
                        rhsEnd: other.endMinute
                    )
            }

            if hasOverlapInLane {
                break
            }

            span += 1
        }

        return span
    }

    private static func intervalsOverlap(
        lhsStart: Int,
        lhsEnd: Int,
        rhsStart: Int,
        rhsEnd: Int
    ) -> Bool {
        lhsStart < rhsEnd && rhsStart < lhsEnd
    }

    private static func clip(
        _ event: TaskerCalendarEventSnapshot,
        to date: Date,
        calendar: Calendar
    ) -> ClippedEvent? {
        let dayStart = calendar.startOfDay(for: date)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) ?? dayStart
        let clippedStart = max(event.startDate, dayStart)
        let clippedEnd = min(event.endDate, dayEnd)
        guard clippedEnd > clippedStart else { return nil }

        let startMinute = max(0, Int(clippedStart.timeIntervalSince(dayStart) / 60.0))
        let endMinute = min(24 * 60, max(startMinute + 1, Int(ceil(clippedEnd.timeIntervalSince(dayStart) / 60.0))))
        return ClippedEvent(event: event, startMinute: startMinute, endMinute: endMinute)
    }

    private static func clip(
        _ event: ClippedEvent,
        visibleStartMinute: Int,
        visibleEndMinute: Int
    ) -> ClippedEvent? {
        let clippedStart = max(event.startMinute, visibleStartMinute)
        let clippedEnd = min(event.endMinute, visibleEndMinute)
        guard clippedEnd > clippedStart else { return nil }

        return ClippedEvent(
            event: event.event,
            startMinute: clippedStart,
            endMinute: clippedEnd
        )
    }
}

enum TaskerCalendarTimelineVisibleWindowPolicy: Equatable {
    case fixed(anchorDate: Date)

    var anchorDate: Date {
        switch self {
        case .fixed(let anchorDate):
            return anchorDate
        }
    }

    static func fixedToCurrentMinute(_ date: Date = Date()) -> TaskerCalendarTimelineVisibleWindowPolicy {
        let minuteStamp = floor(date.timeIntervalSinceReferenceDate / 60.0) * 60.0
        return .fixed(anchorDate: Date(timeIntervalSinceReferenceDate: minuteStamp))
    }
}

struct TaskerCalendarTimelinePlanEventSignature: Equatable {
    let id: String
    let calendarID: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let availability: TaskerCalendarEventAvailability
    let eventStatus: TaskerCalendarEventStatus
    let participationStatus: TaskerCalendarEventParticipationStatus
    let lastModifiedAt: Date?

    init(_ event: TaskerCalendarEventSnapshot) {
        id = event.id
        calendarID = event.calendarID
        startDate = event.startDate
        endDate = event.endDate
        isAllDay = event.isAllDay
        availability = event.availability
        eventStatus = event.eventStatus
        participationStatus = event.participationStatus
        lastModifiedAt = event.lastModifiedAt
    }
}

struct TaskerCalendarTimelinePlanCacheKey: Equatable {
    let date: Date
    let density: TaskerCalendarTimelineDensity
    let visibleWindowPolicy: TaskerCalendarTimelineVisibleWindowPolicy
    let calendarIdentifier: Calendar.Identifier
    let calendarTimeZone: TimeZone
    let events: [TaskerCalendarTimelinePlanEventSignature]

    init(
        events: [TaskerCalendarEventSnapshot],
        date: Date,
        density: TaskerCalendarTimelineDensity,
        visibleWindowPolicy: TaskerCalendarTimelineVisibleWindowPolicy,
        calendar: Calendar = .current
    ) {
        self.date = calendar.startOfDay(for: date)
        self.density = density
        self.visibleWindowPolicy = visibleWindowPolicy
        self.calendarIdentifier = calendar.identifier
        self.calendarTimeZone = calendar.timeZone
        self.events = events.map(TaskerCalendarTimelinePlanEventSignature.init)
    }
}

struct TaskerCalendarTimelinePlanCache {
    private var cachedKey: TaskerCalendarTimelinePlanCacheKey?
    private var cachedPlan: TaskerCalendarTimelineLayoutPlan?
    private(set) var buildCount = 0
    private(set) var cacheHitCount = 0

    mutating func plan(
        for events: [TaskerCalendarEventSnapshot],
        on date: Date,
        density: TaskerCalendarTimelineDensity,
        visibleWindowPolicy: TaskerCalendarTimelineVisibleWindowPolicy,
        calendar: Calendar = .current
    ) -> TaskerCalendarTimelineLayoutPlan? {
        let key = TaskerCalendarTimelinePlanCacheKey(
            events: events,
            date: date,
            density: density,
            visibleWindowPolicy: visibleWindowPolicy,
            calendar: calendar
        )
        if let cachedKey, cachedKey == key {
            cacheHitCount += 1
            return cachedPlan
        }

        let interval = TaskerPerformanceTrace.begin("CalendarTimelinePlanBuild")
        let plan = TaskerCalendarTimelinePlanner.makePlan(
            for: events,
            on: date,
            density: density,
            anchorDate: visibleWindowPolicy.anchorDate,
            calendar: calendar
        )
        TaskerPerformanceTrace.end(interval)
        cachedKey = key
        cachedPlan = plan
        buildCount += 1
        return plan
    }
}

struct TaskerCalendarTimelineView: View {
    let date: Date
    let events: [TaskerCalendarEventSnapshot]
    let density: TaskerCalendarTimelineDensity
    let showsDateLabel: Bool
    let emptyText: String
    let accessibilityIdentifier: String?
    let accessibilityLabelText: String?
    let initialVisibleHour: Int?
    let eventAccessibilityIdentifierPrefix: String
    let onSelectEvent: ((TaskerCalendarEventSnapshot) -> Void)?
    private let visibleWindowPolicy: TaskerCalendarTimelineVisibleWindowPolicy
    private let layoutPlanCacheKey: TaskerCalendarTimelinePlanCacheKey

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var layoutPlan: TaskerCalendarTimelineLayoutPlan?
    @State private var layoutPlanCache = TaskerCalendarTimelinePlanCache()

    init(
        date: Date,
        events: [TaskerCalendarEventSnapshot],
        density: TaskerCalendarTimelineDensity = .compact,
        showsDateLabel: Bool = true,
        emptyText: String = "Nothing in this window",
        accessibilityIdentifier: String? = nil,
        accessibilityLabelText: String? = nil,
        initialVisibleHour: Int? = nil,
        eventAccessibilityIdentifierPrefix: String = "schedule.event",
        onSelectEvent: ((TaskerCalendarEventSnapshot) -> Void)? = nil
    ) {
        self.date = date
        self.events = events
        self.density = density
        self.showsDateLabel = showsDateLabel
        self.emptyText = emptyText
        self.accessibilityIdentifier = accessibilityIdentifier
        self.accessibilityLabelText = accessibilityLabelText
        self.initialVisibleHour = initialVisibleHour
        self.eventAccessibilityIdentifierPrefix = eventAccessibilityIdentifierPrefix
        self.onSelectEvent = onSelectEvent
        let visibleWindowPolicy = TaskerCalendarTimelineVisibleWindowPolicy.fixedToCurrentMinute()
        self.visibleWindowPolicy = visibleWindowPolicy
        self.layoutPlanCacheKey = TaskerCalendarTimelinePlanCacheKey(
            events: events,
            date: date,
            density: density,
            visibleWindowPolicy: visibleWindowPolicy
        )
    }

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    private var metrics: TimelineMetrics {
        TimelineMetrics(density: density, layoutClass: layoutClass)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            content(anchorDate: timeline.date)
        }
        .modifier(
            TaskerCalendarTimelineAccessibilityModifier(
                identifier: accessibilityIdentifier,
                label: accessibilityLabelText
            )
        )
        .onAppear(perform: refreshLayoutPlan)
        .onChange(of: layoutPlanCacheKey) { _, _ in
            refreshLayoutPlan()
        }
    }

    private func refreshLayoutPlan() {
        var cache = layoutPlanCache
        layoutPlan = cache.plan(
            for: events,
            on: date,
            density: density,
            visibleWindowPolicy: visibleWindowPolicy
        )
        layoutPlanCache = cache
    }

    @ViewBuilder
    private func content(anchorDate: Date) -> some View {
        if let layoutPlan {
            VStack(alignment: .leading, spacing: spacing.s8) {
                if showsDateLabel {
                    Text(TaskerCalendarPresentation.compactDateText(for: date))
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                }

                switch density {
                case .compact:
                    compactTimelineBody(layoutPlan: layoutPlan, anchorDate: anchorDate)
                case .expanded:
                    expandedTimelineBody(layoutPlan: layoutPlan, anchorDate: anchorDate)
                }
            }
            .padding(.top, spacing.s4)
        } else {
            VStack(alignment: .leading, spacing: spacing.s8) {
                if showsDateLabel {
                    Text(TaskerCalendarPresentation.compactDateText(for: date))
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                }
                Text(emptyText)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker.textSecondary)
            }
            .padding(.top, spacing.s4)
        }
    }

    private func compactTimelineBody(
        layoutPlan: TaskerCalendarTimelineLayoutPlan,
        anchorDate: Date
    ) -> some View {
        GeometryReader { proxy in
            timelineCanvas(layoutPlan: layoutPlan, anchorDate: anchorDate, totalWidth: proxy.size.width)
        }
        .frame(height: timelineHeight(for: layoutPlan))
    }

    private func expandedTimelineBody(
        layoutPlan: TaskerCalendarTimelineLayoutPlan,
        anchorDate: Date
    ) -> some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    timelineCanvas(layoutPlan: layoutPlan, anchorDate: anchorDate, totalWidth: proxy.size.width)
                        .frame(height: timelineHeight(for: layoutPlan))
                }
                .scrollIndicators(.visible)
                .onAppear {
                    scrollExpandedTimeline(
                        scrollProxy: scrollProxy,
                        layoutPlan: layoutPlan,
                        targetHour: initialVisibleHour
                    )
                }
                .onChange(of: initialVisibleHour) { _, updatedHour in
                    scrollExpandedTimeline(
                        scrollProxy: scrollProxy,
                        layoutPlan: layoutPlan,
                        targetHour: updatedHour
                    )
                }
            }
        }
        .frame(height: layoutClass.isPad ? 560 : 460)
    }

    private func scrollExpandedTimeline(
        scrollProxy: ScrollViewProxy,
        layoutPlan: TaskerCalendarTimelineLayoutPlan,
        targetHour: Int?
    ) {
        let clampedHour = min(
            max(layoutPlan.startHour, targetHour ?? layoutPlan.startHour),
            max(layoutPlan.startHour, layoutPlan.endHour)
        )
        DispatchQueue.main.async {
            if reduceMotion {
                scrollProxy.scrollTo(hourAnchorID(clampedHour), anchor: .top)
            } else {
                withAnimation(.easeInOut(duration: 0.22)) {
                    scrollProxy.scrollTo(hourAnchorID(clampedHour), anchor: .top)
                }
            }
        }
    }

    private func timelineCanvas(
        layoutPlan: TaskerCalendarTimelineLayoutPlan,
        anchorDate: Date,
        totalWidth: CGFloat
    ) -> some View {
        let timelineWidth = max(0, totalWidth - metrics.labelColumnWidth)

        return ZStack(alignment: .topLeading) {
            timelineGrid(layoutPlan, width: timelineWidth, anchorDate: anchorDate)
            timelineEvents(layoutPlan, width: timelineWidth)
            if layoutPlan.positionedEvents.isEmpty {
                timelineEmptyState(width: timelineWidth, plan: layoutPlan)
            }
        }
    }

    private func timelineGrid(
        _ plan: TaskerCalendarTimelineLayoutPlan,
        width: CGFloat,
        anchorDate: Date
    ) -> some View {
        let totalHeight = timelineHeight(for: plan)

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: metrics.labelColumnWidth + width, height: totalHeight)

            Rectangle()
                .fill(Color.tasker.strokeHairline.opacity(0.55))
                .frame(width: 1, height: totalHeight)
                .offset(x: metrics.labelColumnWidth)

            ForEach(Array(plan.hourMarkers.enumerated()), id: \.offset) { _, hour in
                let y = CGFloat((hour * 60) - plan.startMinute) / 60.0 * metrics.hourHeight

                HStack(spacing: spacing.s8) {
                    Text(hourLabel(hour))
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textTertiary)
                        .frame(width: metrics.labelColumnWidth - spacing.s4, alignment: .trailing)

                    Rectangle()
                        .fill(Color.tasker.strokeHairline.opacity(hour == 12 ? 0.8 : 0.48))
                        .frame(height: 1)
                }
                .offset(y: y)
                .id(hourAnchorID(hour))
            }

            if let nowOffset = currentTimeOffset(in: plan, anchorDate: anchorDate) {
                currentTimeIndicator(label: currentTimeLabel(for: anchorDate), width: width)
                    .offset(y: nowOffset - (metrics.currentTimeIndicatorHeight / 2))
            }
        }
    }

    private func timelineEvents(_ plan: TaskerCalendarTimelineLayoutPlan, width: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(plan.positionedEvents) { positioned in
                let frame = eventFrame(for: positioned, in: plan, width: width)
                Group {
                    if let onSelectEvent {
                        Button {
                            onSelectEvent(positioned.event)
                        } label: {
                            TaskerCalendarTimelineEventCard(
                                event: positioned.event,
                                density: density,
                                height: frame.height,
                                differentiateWithoutColor: differentiateWithoutColor
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("\(eventAccessibilityIdentifierPrefix).\(positioned.event.id)")
                        .accessibilityLabel(timelineEventAccessibilityLabel(for: positioned.event))
                        .accessibilityHint(String(localized: "Open event details"))
                    } else {
                        TaskerCalendarTimelineEventCard(
                            event: positioned.event,
                            density: density,
                            height: frame.height,
                            differentiateWithoutColor: differentiateWithoutColor
                        )
                    }
                }
                .frame(width: frame.width, height: frame.height, alignment: .topLeading)
                .offset(x: metrics.labelColumnWidth + frame.minX, y: frame.minY)
            }
        }
    }

    private func timelineEventAccessibilityLabel(for event: TaskerCalendarEventSnapshot) -> String {
        [
            event.title,
            TaskerCalendarPresentation.timeRangeText(for: event),
            event.calendarTitle
        ]
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }

    private func timelineEmptyState(width: CGFloat, plan: TaskerCalendarTimelineLayoutPlan) -> some View {
        Text(emptyText)
            .font(.tasker(.callout))
            .foregroundStyle(Color.tasker.textSecondary)
            .frame(width: width, height: timelineHeight(for: plan))
            .offset(x: metrics.labelColumnWidth + metrics.laneInset, y: 0)
    }

    private func eventFrame(
        for event: TaskerCalendarTimelineLayoutPlan.PositionedEvent,
        in plan: TaskerCalendarTimelineLayoutPlan,
        width: CGFloat
    ) -> CGRect {
        let columnWidth = width / CGFloat(max(1, event.laneCount))
        let minX = CGFloat(event.lane) * columnWidth + metrics.laneInset
        let contentWidth = max(40, (columnWidth * CGFloat(event.columnSpan)) - (metrics.laneInset * 2) - 1)
        let minY = CGFloat(event.startMinute - plan.startMinute) / 60.0 * metrics.hourHeight + metrics.verticalInset
        let height = max(
            metrics.minimumCardHeight,
            CGFloat(event.endMinute - event.startMinute) / 60.0 * metrics.hourHeight - (metrics.verticalInset * 2)
        )
        return CGRect(x: minX, y: minY, width: contentWidth, height: height)
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 12 {
            return String(localized: "Noon")
        }

        let markerDate = Calendar.current.date(
            bySettingHour: hour,
            minute: 0,
            second: 0,
            of: date
        ) ?? date
        return markerDate.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated)))
    }

    private func currentTimeOffset(
        in plan: TaskerCalendarTimelineLayoutPlan,
        anchorDate: Date
    ) -> CGFloat? {
        let calendar = Calendar.current
        guard calendar.isDate(anchorDate, inSameDayAs: date) else { return nil }

        let nowMinute = calendar.component(.hour, from: anchorDate) * 60
            + calendar.component(.minute, from: anchorDate)
        let startMinute = plan.startMinute
        let endMinute = plan.endMinute
        guard nowMinute >= startMinute, nowMinute <= endMinute else { return nil }

        return CGFloat(nowMinute - startMinute) / 60.0 * metrics.hourHeight
    }

    private func timelineHeight(for plan: TaskerCalendarTimelineLayoutPlan) -> CGFloat {
        CGFloat(max(1, plan.endMinute - plan.startMinute)) / 60.0 * metrics.hourHeight
    }

    private func currentTimeIndicator(label: String, width: CGFloat) -> some View {
        HStack(spacing: spacing.s8) {
            Text(label)
                .font(.system(size: metrics.currentTimeLabelSize, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .frame(height: metrics.currentTimeIndicatorHeight)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.tasker.statusDanger)
                )

            Rectangle()
                .fill(Color.tasker.statusDanger)
                .frame(width: width, height: metrics.currentTimeRuleHeight)
        }
    }

    private func currentTimeLabel(for anchorDate: Date) -> String {
        anchorDate.formatted(
            .dateTime
                .hour(.defaultDigits(amPM: .omitted))
                .minute()
        )
    }

    private func hourAnchorID(_ hour: Int) -> String {
        "timeline.hour.\(hour)"
    }
}

private struct TaskerCalendarTimelineAccessibilityModifier: ViewModifier {
    let identifier: String?
    let label: String?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let identifier {
            content
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(identifier)
                .accessibilityLabel(label ?? "")
        } else {
            content
        }
    }
}

private struct TaskerCalendarTimelineEventCard: View {
    let event: TaskerCalendarEventSnapshot
    let density: TaskerCalendarTimelineDensity
    let height: CGFloat
    let differentiateWithoutColor: Bool

    private var accentColor: Color {
        TaskerHexColor.color(event.calendarColorHex, fallback: Color.tasker.accentPrimary)
    }

    private var badges: [TaskerCalendarEventBadge] {
        TaskerCalendarPresentation.badges(for: event)
    }

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )

            if event.isCanceled {
                TaskerCalendarTimelineStripeOverlay(
                    color: accentColor,
                    cornerRadius: cornerRadius
                )
            }

            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(accentColor)
                .frame(width: differentiateWithoutColor ? 5 : 3)
                .padding(.vertical, railVerticalPadding)
                .padding(.leading, railLeadingPadding)

            VStack(alignment: .leading, spacing: contentSpacing) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Circle()
                        .fill(accentColor)
                        .frame(width: 4, height: 4)
                        .opacity(showsAccentDot ? 1 : 0)
                        .accessibilityHidden(true)

                    Text(event.title)
                        .font(titleFont)
                        .foregroundStyle(titleColor)
                        .strikethrough(event.isCanceled, color: Color.tasker.textSecondary)
                        .lineLimit(titleLineLimit)
                        .minimumScaleFactor(0.9)

                    if differentiateWithoutColor, let firstBadge = badges.first {
                        Image(systemName: firstBadge.systemImage)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .accessibilityHidden(true)
                    }
                }

                if showsTimeLine {
                    Text(TaskerCalendarPresentation.timeRangeText(for: event))
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.9)
                }

                if showsSupportingLine, let supportingLine {
                    Text(supportingLine)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.88)
                }
            }
            .padding(.leading, contentLeadingPadding)
            .padding(.trailing, contentTrailingPadding)
            .padding(.vertical, contentVerticalPadding)
            .opacity(event.isCanceled ? 0.72 : 1)
        }
    }

    private var supportingLine: String? {
        if let location = event.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty {
            return location
        }
        return event.calendarTitle
    }

    private var cardFillColor: Color {
        if event.isCanceled {
            return Color.tasker.surfaceSecondary.opacity(0.6)
        }
        return accentColor.opacity(density == .compact ? 0.14 : 0.16)
    }

    private var cardStrokeColor: Color {
        event.isCanceled ? Color.tasker.strokeHairline.opacity(0.6) : accentColor.opacity(0.26)
    }

    private var titleColor: Color {
        event.isCanceled ? Color.tasker.textSecondary : Color.tasker.textPrimary
    }

    private var cornerRadius: CGFloat {
        density == .compact ? 8 : 10
    }

    private var railLeadingPadding: CGFloat {
        density == .compact ? 4 : 5
    }

    private var railVerticalPadding: CGFloat {
        density == .compact ? 4 : 5
    }

    private var contentLeadingPadding: CGFloat {
        density == .compact ? 12 : 14
    }

    private var contentTrailingPadding: CGFloat {
        density == .compact ? 5 : 6
    }

    private var contentVerticalPadding: CGFloat {
        density == .compact ? 4 : 5
    }

    private var contentSpacing: CGFloat {
        height < 34 ? 1 : 2
    }

    private var titleFont: Font {
        density == .compact ? .tasker(.caption1) : .tasker(.bodyStrong)
    }

    private var titleLineLimit: Int {
        if density == .compact {
            return 1
        }
        return height >= 64 ? 2 : 1
    }

    private var showsAccentDot: Bool {
        height >= 24
    }

    private var showsTimeLine: Bool {
        height >= (density == .compact ? 34 : 38)
    }

    private var showsSupportingLine: Bool {
        height >= (density == .compact ? 52 : 60)
    }
}

private struct TaskerCalendarTimelineStripeOverlay: View {
    let color: Color
    let cornerRadius: CGFloat

    var body: some View {
        GeometryReader { proxy in
            Path { path in
                let height = proxy.size.height
                let width = proxy.size.width
                let step: CGFloat = 10
                var x: CGFloat = -height

                while x < width {
                    path.move(to: CGPoint(x: x, y: height))
                    path.addLine(to: CGPoint(x: x + height, y: 0))
                    x += step
                }
            }
            .stroke(color.opacity(0.22), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .allowsHitTesting(false)
    }
}

private struct TaskerCalendarBadgeView: View {
    let badge: TaskerCalendarEventBadge

    var body: some View {
        Label(badge.title, systemImage: badge.systemImage)
            .font(.tasker(.caption2))
            .foregroundStyle(textColor)
            .padding(.horizontal, TaskerTheme.Spacing.sm)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .overlay(
                Capsule(style: .continuous)
                    .stroke(borderColor, lineWidth: 1)
            )
            .clipShape(Capsule(style: .continuous))
    }

    private var backgroundColor: Color {
        switch badge.tone {
        case .accent:
            return Color.tasker.accentWash
        case .warning:
            return Color.tasker.statusWarning.opacity(0.14)
        case .danger:
            return Color.tasker.statusDanger.opacity(0.12)
        case .neutral:
            return Color.tasker.surfaceSecondary
        }
    }

    private var borderColor: Color {
        switch badge.tone {
        case .accent:
            return Color.tasker.actionFocus
        case .warning:
            return Color.tasker.statusWarning.opacity(0.4)
        case .danger:
            return Color.tasker.statusDanger.opacity(0.4)
        case .neutral:
            return Color.tasker.strokeHairline
        }
    }

    private var textColor: Color {
        switch badge.tone {
        case .accent:
            return Color.tasker.actionPrimary
        case .warning:
            return Color.tasker.statusWarning
        case .danger:
            return Color.tasker.statusDanger
        case .neutral:
            return Color.tasker.textSecondary
        }
    }
}

private struct TimelineMetrics {
    let labelColumnWidth: CGFloat
    let hourHeight: CGFloat
    let laneInset: CGFloat
    let verticalInset: CGFloat
    let minimumCardHeight: CGFloat
    let currentTimeIndicatorHeight: CGFloat
    let currentTimeRuleHeight: CGFloat
    let currentTimeLabelSize: CGFloat

    init(density: TaskerCalendarTimelineDensity, layoutClass: TaskerLayoutClass) {
        switch density {
        case .compact:
            labelColumnWidth = 52
            hourHeight = 42
            laneInset = 2
            verticalInset = 3
            minimumCardHeight = 24
            currentTimeIndicatorHeight = 18
            currentTimeRuleHeight = 2
            currentTimeLabelSize = 11
        case .expanded:
            labelColumnWidth = layoutClass.isPad ? 62 : 56
            hourHeight = layoutClass.isPad ? 52 : 46
            laneInset = 3
            verticalInset = 4
            minimumCardHeight = 28
            currentTimeIndicatorHeight = 20
            currentTimeRuleHeight = 2
            currentTimeLabelSize = 12
        }
    }
}
