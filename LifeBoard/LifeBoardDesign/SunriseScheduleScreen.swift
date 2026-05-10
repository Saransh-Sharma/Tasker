import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct SunriseScheduleScreen: View {
    @ObservedObject var service: CalendarIntegrationService
    @Binding var selectedDate: Date
    let weekStartsOn: Weekday
    let presentationMode: CalendarSchedulePresentationMode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.lifeboardLayoutClass) private var layoutClass

    @State private var selectedTab: CalendarScheduleTab = .today
    @State private var presentationState = CalendarSchedulePresentationState()
    @State private var selectedWeekDate: Date
    @State private var presentationCache = CalendarSchedulePresentationCache()
    @State private var schedulePresentation: CalendarSchedulePresentation
    @State private var isScrollActive = false
    @State private var scrollStopTask: Task<Void, Never>?

    init(
        service: CalendarIntegrationService,
        weekStartsOn: Weekday,
        presentationMode: CalendarSchedulePresentationMode,
        selectedDate: Binding<Date>
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

    var body: some View {
        Group {
            if presentationMode == .modal {
                NavigationStack {
                    screenBody
                        .toolbar(.hidden, for: .navigationBar)
                }
            } else {
                screenBody
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
            service.refreshContext(referenceDate: selectedDate, reason: "sunrise_schedule_appear")
        }
        .onChange(of: selectedDate) { _, newValue in
            let defaultWeekDate = CalendarSchedulePresentationBuilder.defaultSelectedWeekDate(
                selectedDate: newValue,
                weekStartsOn: weekStartsOn
            )
            selectedWeekDate = defaultWeekDate
            schedulePresentation = makePresentation(selectedWeekDate: defaultWeekDate)
            service.refreshContext(referenceDate: newValue, reason: "sunrise_schedule_selected_date_changed")
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
                .presentationBackground(LBColorTokens.canvas)
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
                .presentationBackground(LBColorTokens.canvas)
            }
        }
    }

    private var screenBody: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                LBColorTokens.canvas
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 0) {
                        header(safeAreaTop: proxy.safeAreaInsets.top)
                        content
                            .padding(.top, -contentOverlap)
                            .padding(.bottom, LBSpacingTokens.bottomDockClearance)
                    }
                }
                .refreshable {
                    service.refreshContext(referenceDate: selectedDate, reason: "sunrise_schedule_pull_to_refresh")
                }
                .scrollIndicators(.hidden)
                .ignoresSafeArea(edges: .top)
                .simultaneousGesture(
                    DragGesture(minimumDistance: 2)
                        .onChanged { _ in setScrolling(true) }
                        .onEnded { _ in scheduleScrollStop() }
                )
                .accessibilityIdentifier("schedule.list")
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
            segmentControl
            scheduleContent(presentation: schedulePresentation)
        }
        .padding(.horizontal, LBSpacingTokens.screenMargin)
    }

    private func header(safeAreaTop: CGFloat) -> some View {
        TimelineView(.periodic(from: .now, by: 60)) { timeline in
            let context = LBHeaderTimeContext.resolve(selectedDate: selectedDate, now: timeline.date)
            SunriseHeaderView(
                context: context,
                isScrollActive: isScrollActive,
                height: headerHeight
            ) {
                SunriseScheduleHeaderChrome(
                    selectedDate: selectedDate,
                    selectedTab: selectedTab,
                    context: context,
                    snapshot: service.snapshot,
                    isModal: presentationMode == .modal,
                    safeAreaTop: safeAreaTop,
                    onClose: dismiss.callAsFunction,
                    onPreviousDay: { shiftSelectedDate(by: -1) },
                    onNextDay: { shiftSelectedDate(by: 1) },
                    onOpenFilters: handleCalendarFilterTap
                )
                .frame(height: headerHeight, alignment: .top)
            }
        }
    }

    private var segmentControl: some View {
        HStack(spacing: LBSpacingTokens.xs) {
            ForEach(CalendarScheduleTab.allCases) { tab in
                scheduleSegmentButton(for: tab)
            }
        }
        .padding(5)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .background(LBColorTokens.glass.opacity(0.56), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(LBColorTokens.glassBorder, lineWidth: 1)
        }
        .accessibilityIdentifier("schedule.segmented")
    }

    private func scheduleSegmentButton(for tab: CalendarScheduleTab) -> some View {
        let isSelected = selectedTab == tab
        return Button {
            LifeBoardFeedback.selection()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.88)) {
                selectedTab = tab
                if tab == .week {
                    selectedWeekDate = schedulePresentation.weekDefaultSelectedDate
                }
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab == .today ? "sun.max" : "calendar")
                    .font(.system(size: 13, weight: .bold))
                Text(tab.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(LBTypographyTokens.chip)
            .foregroundStyle(isSelected ? Color.white : LBColorTokens.navy)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                if isSelected {
                    LinearGradient(
                        colors: [LBColorTokens.violet, LBColorTokens.violetDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("schedule.segment.\(tab.rawValue)")
        .accessibilityValue(isSelected ? String(localized: "selected") : String(localized: "unselected"))
    }

    @ViewBuilder
    private func scheduleContent(presentation: CalendarSchedulePresentation) -> some View {
        if service.snapshot.authorizationStatus.isAuthorizedForRead == false {
            permissionRequiredView
        } else if isInitialLoadingStateVisible {
            LBGlassCard(cornerRadius: LBRadiusTokens.largeCard, fill: LBColorTokens.glassStrong.opacity(0.82)) {
                VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
                    LBSectionHeader(title: "Loading schedule", systemImage: "calendar.badge.clock")
                    LBLoadingSkeleton(lineCount: 4)
                }
                .padding(LBSpacingTokens.lg)
            }
            .accessibilityIdentifier("schedule.loading.initial")
        } else if let error = service.snapshot.errorMessage, !error.isEmpty {
            stateCard(
                title: String(localized: "Unable to load calendar"),
                message: error,
                role: .error,
                bodyAccessibilityIdentifier: "schedule.error.message",
                buttonTitle: String(localized: "Retry"),
                buttonAccessibilityIdentifier: "schedule.error.retry",
                action: {
                    service.refreshContext(reason: "sunrise_schedule_error_retry")
                }
            )
        } else if service.snapshot.selectedCalendarIDs.isEmpty {
            stateCard(
                title: String(localized: "No calendars selected"),
                message: String(localized: "Choose the calendars that should shape the schedule view and Home day lane."),
                role: .meeting,
                bodyAccessibilityIdentifier: "schedule.noCalendars.body",
                buttonTitle: String(localized: "Choose Calendars"),
                buttonAccessibilityIdentifier: "schedule.noCalendars.choose",
                action: {
                    presentationState.presentChooser()
                }
            )
        } else {
            activeContent(presentation: presentation)
        }
    }

    private var permissionRequiredView: some View {
        let action: (() -> Void)? = permissionButtonTitle == nil ? nil : { performPermissionAction() }
        return stateCard(
            title: permissionTitle,
            message: permissionSubtitle,
            role: permissionRole,
            bodyAccessibilityIdentifier: permissionStateAccessibilityID,
            buttonTitle: permissionButtonTitle,
            buttonAccessibilityIdentifier: "schedule.permission.connect",
            action: action
        )
    }

    @ViewBuilder
    private func activeContent(presentation: CalendarSchedulePresentation) -> some View {
        switch selectedTab {
        case .today:
            todayContent(events: presentation.todayEvents)
        case .week:
            weekContent(presentation: presentation)
        }
    }

    private func todayContent(events: [LifeBoardCalendarEventSnapshot]) -> some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
            nextUpCard
            timelineSection(
                date: selectedDate,
                events: events,
                emptyText: String(localized: "No timed blocks today.")
            )

            if events.isEmpty {
                emptyScheduleCard(
                    title: String(localized: "No events today"),
                    message: String(localized: "The schedule is open with the selected calendars."),
                    accessibilityIdentifier: "schedule.today.empty"
                )
            }
        }
    }

    private func weekContent(presentation: CalendarSchedulePresentation) -> some View {
        VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
            if presentation.weekEventCount == 0 {
                stateCard(
                    title: String(localized: "No events this week"),
                    message: String(localized: "The week horizon is clear with the currently selected calendars."),
                    role: .focus,
                    bodyAccessibilityIdentifier: "schedule.week.empty",
                    buttonTitle: nil,
                    buttonAccessibilityIdentifier: nil,
                    action: nil
                )
            } else {
                weekStrip(dates: presentation.weekDates)

                selectedDaySummary(count: presentation.selectedWeekEvents.count)

                timelineSection(
                    date: selectedWeekDate,
                    events: presentation.selectedWeekEvents,
                    emptyText: String(localized: "No timed blocks on selected day.")
                )
            }
        }
    }

    private var nextUpCard: some View {
        LBGlassCard(cornerRadius: LBRadiusTokens.card, borderColor: LBColorTokens.role(.meeting).border, fill: LBColorTokens.role(.meeting).softSurface.opacity(0.72)) {
            HStack(alignment: .top, spacing: LBSpacingTokens.md) {
                LBIconBadge(systemName: nextUpIconName, role: .meeting, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(nextUpPrimaryLine)
                        .font(LBTypographyTokens.cardTitle)
                        .foregroundStyle(LBColorTokens.navy)
                        .lineLimit(2)
                    Text(nextUpSecondaryLine)
                        .font(LBTypographyTokens.meta)
                        .foregroundStyle(LBColorTokens.navyMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .padding(LBSpacingTokens.md)
        }
        .accessibilityIdentifier("schedule.today.nextUp")
    }

    private func weekStrip(dates: [Date]) -> some View {
        LBGlassCard(cornerRadius: LBRadiusTokens.card, fill: LBColorTokens.glass.opacity(0.82), shadow: LBShadowTokens.card) {
            HStack(spacing: 6) {
                ForEach(dates, id: \.timeIntervalSince1970) { date in
                    weekDayButton(date)
                }
            }
            .padding(LBSpacingTokens.sm)
        }
    }

    private func weekDayButton(_ date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedWeekDate)
        let eventCount = eventCount(for: date)
        return Button {
            LifeBoardFeedback.selection()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
                selectedWeekDate = date
            }
        } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(LBTypographyTokens.habitDayLabel)
                    .foregroundStyle(isSelected ? Color.white.opacity(0.84) : LBColorTokens.textTertiary)
                Text(date.formatted(.dateTime.day()))
                    .font(LBTypographyTokens.bodyStrong)
                    .foregroundStyle(isSelected ? Color.white : LBColorTokens.navy)
                Circle()
                    .fill(isSelected ? Color.white.opacity(eventCount > 0 ? 0.94 : 0.0) : LBColorTokens.violet.opacity(eventCount > 0 ? 0.85 : 0.0))
                    .frame(width: 5, height: 5)
            }
            .frame(maxWidth: .infinity, minHeight: 58)
            .background {
                if isSelected {
                    LinearGradient(
                        colors: [LBColorTokens.violet, LBColorTokens.violetDeep],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                } else {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LBColorTokens.glassStrong.opacity(0.62))
                }
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.white.opacity(0.42) : LBColorTokens.hairline.opacity(0.62), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("schedule.week.day.\(dayIdentifier(for: date))")
        .accessibilityValue(isSelected ? String(localized: "selected") : String(localized: "unselected"))
    }

    private func selectedDaySummary(count: Int) -> some View {
        let suffix = count == 1 ? String(localized: "event") : String(localized: "events")
        return HStack(spacing: LBSpacingTokens.xs) {
            Image(systemName: "calendar")
            Text("Selected day: \(LifeBoardCalendarPresentation.scheduleDateText(for: selectedWeekDate)) • \(count) \(suffix)")
                .lineLimit(2)
                .minimumScaleFactor(0.86)
        }
        .font(LBTypographyTokens.meta)
        .foregroundStyle(LBColorTokens.navyMuted)
        .padding(.horizontal, LBSpacingTokens.sm)
        .padding(.vertical, LBSpacingTokens.xs)
        .background(LBColorTokens.glassStrong.opacity(0.82), in: Capsule())
        .overlay {
            Capsule().stroke(LBColorTokens.hairline.opacity(0.62), lineWidth: 1)
        }
        .accessibilityIdentifier("schedule.week.selectedDay")
    }

    private func timelineSection(
        date: Date,
        events: [LifeBoardCalendarEventSnapshot],
        emptyText: String
    ) -> some View {
        LBGlassCard(cornerRadius: LBRadiusTokens.largeCard, fill: LBColorTokens.glassStrong.opacity(0.84)) {
            VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
                HStack(alignment: .firstTextBaseline) {
                    LBSectionHeader(title: "Timeline", systemImage: "clock")
                    Spacer(minLength: 0)
                    Text(LifeBoardCalendarPresentation.scheduleDateText(for: date))
                        .font(LBTypographyTokens.meta)
                        .foregroundStyle(LBColorTokens.textTertiary)
                }

                let targetHour = LifeBoardCalendarTimelinePlanner.initialExpandedHour(
                    for: events,
                    on: date
                )
                LifeBoardCalendarTimelineView(
                    date: date,
                    events: events,
                    density: .expanded,
                    showsDateLabel: false,
                    emptyText: emptyText,
                    accessibilityIdentifier: "schedule.timeline.expanded",
                    accessibilityLabelText: String(localized: "Live timeline for the selected day."),
                    initialVisibleHour: targetHour,
                    onSelectEvent: { presentationState.selectEvent(id: $0.id) }
                )
            }
            .padding(LBSpacingTokens.md)
        }
    }

    private func emptyScheduleCard(title: String, message: String, accessibilityIdentifier: String) -> some View {
        LBGlassCard(cornerRadius: LBRadiusTokens.card, borderColor: LBColorTokens.role(.neutral).border, fill: LBColorTokens.role(.neutral).softSurface.opacity(0.74)) {
            HStack(alignment: .top, spacing: LBSpacingTokens.md) {
                LBIconBadge(systemName: "sun.max", role: .routine, size: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(LBTypographyTokens.cardTitle)
                        .foregroundStyle(LBColorTokens.navy)
                    Text(message)
                        .font(LBTypographyTokens.meta)
                        .foregroundStyle(LBColorTokens.navyMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(LBSpacingTokens.md)
        }
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func stateCard(
        title: String,
        message: String,
        role: LBRole,
        bodyAccessibilityIdentifier: String,
        buttonTitle: String?,
        buttonAccessibilityIdentifier: String?,
        action: (() -> Void)?
    ) -> some View {
        let style = LBColorTokens.role(role)
        return LBGlassCard(cornerRadius: LBRadiusTokens.largeCard, borderColor: style.border, fill: style.softSurface.opacity(0.78)) {
            VStack(alignment: .leading, spacing: LBSpacingTokens.md) {
                HStack(alignment: .top, spacing: LBSpacingTokens.md) {
                    LBIconBadge(systemName: style.symbolName, role: role, size: 40)
                    VStack(alignment: .leading, spacing: 6) {
                        Text(title)
                            .font(LBTypographyTokens.sectionTitle)
                            .foregroundStyle(LBColorTokens.navy)
                            .lineLimit(3)
                        Text(message)
                            .font(LBTypographyTokens.body)
                            .foregroundStyle(LBColorTokens.navyMuted)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier(bodyAccessibilityIdentifier)
                    }
                }

                if let buttonTitle, let action {
                    Button(action: action) {
                        HStack(spacing: LBSpacingTokens.xs) {
                            Text(buttonTitle)
                            Image(systemName: "arrow.right")
                        }
                        .font(LBTypographyTokens.bodyStrong)
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 50)
                        .background {
                            LinearGradient(
                                colors: [style.base, style.deep],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(buttonAccessibilityIdentifier ?? "")
                }
            }
            .padding(LBSpacingTokens.lg)
        }
    }

    private var isInitialLoadingStateVisible: Bool {
        service.snapshot.authorizationStatus.isAuthorizedForRead
            && service.snapshot.isLoading
            && service.snapshot.errorMessage?.isEmpty != false
            && service.snapshot.availableCalendars.isEmpty
            && service.snapshot.eventsInRange.isEmpty
    }

    private var nextUpIconName: String {
        service.snapshot.nextMeeting == nil ? "sun.max" : "calendar"
    }

    private var nextUpPrimaryLine: String {
        if let nextMeeting = service.snapshot.nextMeeting {
            return "Next up: \(nextMeeting.event.title)"
        }
        return String(localized: "Next up: Clear")
    }

    private var nextUpSecondaryLine: String {
        if let nextMeeting = service.snapshot.nextMeeting {
            return LifeBoardCalendarPresentation.timeRangeText(for: nextMeeting.event)
        }
        if let freeUntil = service.snapshot.freeUntil {
            return String(localized: "Free until \(freeUntil.formatted(date: .omitted, time: .shortened))")
        }
        return String(localized: "No upcoming meetings.")
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
            return String(localized: "Grant calendar access to bring Today and Week schedule context into LifeBoard.")
        case .denied:
            return String(localized: "Calendar access is denied by iOS. Enable LifeBoard in Settings > Privacy & Security > Calendars. If LifeBoard is missing, restart your device, reinstall LifeBoard, or reset Location & Privacy.")
        case .restricted:
            return String(localized: "Calendar access is restricted by system policy and cannot be changed here.")
        case .writeOnly:
            return String(localized: "LifeBoard has write-only access. Allow full calendar access so schedule events can appear.")
        case .authorized:
            return String(localized: "Calendar access is required.")
        }
    }

    private var permissionRole: LBRole {
        switch service.snapshot.authorizationStatus {
        case .denied, .restricted, .writeOnly:
            return .warning
        case .notDetermined, .authorized:
            return .meeting
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

    private var permissionAccessAction: CalendarAccessAction {
        service.accessAction(for: service.snapshot.authorizationStatus)
    }

    private var headerHeight: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? LBSpacingTokens.compactHeaderAccessibilityHeight : LBSpacingTokens.compactHeaderHeight
    }

    private var contentOverlap: CGFloat {
        dynamicTypeSize.isAccessibilitySize ? 16 : 30
    }

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

    private func handleCalendarFilterTap() {
        if service.snapshot.authorizationStatus.isAuthorizedForRead {
            presentationState.presentChooser()
        } else {
            performPermissionAction()
        }
    }

    private func performPermissionAction() {
        _ = service.performAccessAction(source: "sunrise_schedule", openSystemSettings: openSystemSettings)
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
        #endif
    }

    private func shiftSelectedDate(by dayOffset: Int) {
        guard let nextDate = Calendar.current.date(byAdding: .day, value: dayOffset, to: selectedDate) else { return }
        selectedDate = nextDate
    }

    private func eventCount(for date: Date) -> Int {
        schedulePresentation.weekAgenda.first { day in
            Calendar.current.isDate(day.date, inSameDayAs: date)
        }?.events.count ?? 0
    }

    private func dayIdentifier(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = Calendar.current.timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func setScrolling(_ scrolling: Bool) {
        scrollStopTask?.cancel()
        guard isScrollActive != scrolling else { return }
        isScrollActive = scrolling
    }

    private func scheduleScrollStop() {
        scrollStopTask?.cancel()
        scrollStopTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard Task.isCancelled == false else { return }
            isScrollActive = false
        }
    }
}

private struct SunriseScheduleHeaderChrome: View {
    let selectedDate: Date
    let selectedTab: CalendarScheduleTab
    let context: LBHeaderTimeContext
    let snapshot: LifeBoardCalendarSnapshot
    let isModal: Bool
    let safeAreaTop: CGFloat
    let onClose: () -> Void
    let onPreviousDay: () -> Void
    let onNextDay: () -> Void
    let onOpenFilters: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        ZStack(alignment: .top) {
            topChrome
                .padding(.top, safeHeaderTop + 8)

            titleGroup
                .padding(.top, dynamicTypeSize.isAccessibilitySize ? safeHeaderTop + 64 : safeHeaderTop + 48)

            navigatorRow
                .padding(.top, dynamicTypeSize.isAccessibilitySize ? safeHeaderTop + 170 : safeHeaderTop + 132)
        }
    }

    private var topChrome: some View {
        HStack(spacing: LBSpacingTokens.sm) {
            if isModal {
                headerCircleButton(systemName: "xmark", accessibilityLabel: "Close", action: onClose)
            } else {
                Image(systemName: "calendar")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(context.foregroundStyle.controlColor)
                    .frame(width: 44, height: 44)
                    .background {
                        clearCircleSurface(fill: Color.white.opacity(0.12), stroke: context.foregroundStyle.glassStroke.opacity(0.72))
                    }
                    .accessibilityHidden(true)
            }

            Spacer(minLength: 0)

            Button(action: onOpenFilters) {
                HStack(spacing: 7) {
                    Image(systemName: "line.3.horizontal.decrease")
                    Text(filterTitle)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                }
                .font(LBTypographyTokens.chip)
                .foregroundStyle(context.foregroundStyle.controlColor)
                .frame(minHeight: 44)
                .padding(.horizontal, LBSpacingTokens.sm)
                .background {
                    clearCapsuleSurface(fill: Color.white.opacity(0.14), stroke: context.foregroundStyle.glassStroke.opacity(0.72))
                }
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("schedule.toolbar.filters")
            .accessibilityLabel(String(localized: "Choose calendars"))
        }
        .padding(.horizontal, LBSpacingTokens.screenMargin)
    }

    private var titleGroup: some View {
        VStack(spacing: 5) {
            Text("Schedule")
                .font(.system(size: dynamicTypeSize.isAccessibilitySize ? 38 : 44, weight: .medium, design: .serif))
                .minimumScaleFactor(0.75)
                .lineLimit(1)
                .foregroundStyle(context.foregroundStyle.titleColor)
                .shadow(color: Color.black.opacity(0.12), radius: 6, y: 2)

            HStack(spacing: 6) {
                Image(systemName: context.period.symbolName)
                    .foregroundStyle(LBColorTokens.sunriseGold)
                Text(contextLine)
                    .font(LBTypographyTokens.heroOverline)
                    .tracking(2.8)
                    .foregroundStyle(context.foregroundStyle.controlColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .accessibilityIdentifier("schedule.header.context")
        }
        .padding(.horizontal, LBSpacingTokens.screenMargin * 2)
        .frame(maxWidth: .infinity)
    }

    private var navigatorRow: some View {
        HStack(spacing: LBSpacingTokens.xs) {
            headerCircleButton(systemName: "chevron.left", accessibilityLabel: "Previous day", action: onPreviousDay)
            HStack(spacing: LBSpacingTokens.sm) {
                Image(systemName: "calendar")
                Text(LBHeaderTimeContext.navigatorTitle(selectedDate: selectedDate))
            }
            .font(LBTypographyTokens.chip)
            .foregroundStyle(LBColorTokens.navy)
            .frame(minHeight: 44)
            .padding(.horizontal, LBSpacingTokens.md)
            .background {
                clearCapsuleSurface(fill: Color.white.opacity(0.18), stroke: Color.white.opacity(0.58))
            }
            headerCircleButton(systemName: "chevron.right", accessibilityLabel: "Next day", action: onNextDay)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, LBSpacingTokens.screenMargin)
    }

    private func headerCircleButton(systemName: String, accessibilityLabel: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(systemName == "xmark" ? context.foregroundStyle.controlColor : LBColorTokens.navy)
                .frame(width: 44, height: 44)
                .background {
                    clearCircleSurface(
                        fill: systemName == "xmark" ? Color.white.opacity(0.12) : Color.white.opacity(0.18),
                        stroke: systemName == "xmark" ? context.foregroundStyle.glassStroke.opacity(0.72) : Color.white.opacity(0.58)
                    )
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var contextLine: String {
        let prefix = selectedTab == .today ? String(localized: "Today") : String(localized: "Week")
        return "\(prefix) • \(LifeBoardCalendarPresentation.scheduleDateText(for: selectedDate))"
    }

    private var filterTitle: String {
        guard snapshot.authorizationStatus.isAuthorizedForRead else {
            return String(localized: "Connect")
        }
        let count = snapshot.selectedCalendarIDs.count
        switch count {
        case 0:
            return String(localized: "Calendars")
        case 1:
            return String(localized: "1 Calendar")
        default:
            return "\(count) Calendars"
        }
    }

    private var safeHeaderTop: CGFloat {
        max(safeAreaTop, 54)
    }

    @ViewBuilder
    private func clearCircleSurface(fill: Color, stroke: Color) -> some View {
        let shape = Circle()
        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.clear, in: shape)
                .overlay { shape.fill(fill) }
                .overlay { shape.fill(Color.black.opacity(0.05)) }
                .overlay { shape.stroke(stroke, lineWidth: 1) }
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay { shape.fill(fill) }
                .overlay { shape.fill(Color.black.opacity(0.04)) }
                .overlay { shape.stroke(stroke, lineWidth: 1) }
        }
    }

    @ViewBuilder
    private func clearCapsuleSurface(fill: Color, stroke: Color) -> some View {
        let shape = Capsule()
        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(.clear, in: shape)
                .overlay { shape.fill(fill) }
                .overlay { shape.fill(Color.black.opacity(0.05)) }
                .overlay { shape.stroke(stroke, lineWidth: 1) }
        } else {
            shape
                .fill(.ultraThinMaterial)
                .overlay { shape.fill(fill) }
                .overlay { shape.fill(Color.black.opacity(0.04)) }
                .overlay { shape.stroke(stroke, lineWidth: 1) }
        }
    }
}
