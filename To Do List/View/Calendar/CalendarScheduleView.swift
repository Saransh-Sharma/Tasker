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
            return "Today"
        case .week:
            return "Week"
        }
    }
}

struct SelectedCalendarEvent: Identifiable, Equatable {
    let id: String
}

struct CalendarSchedulePresentationState: Equatable {
    var selectedEvent: SelectedCalendarEvent?
    var showChooser = false

    mutating func presentChooser() {
        showChooser = true
    }

    mutating func cancelChooser() {
        showChooser = false
    }

    mutating func commitChooser() {
        showChooser = false
    }

    mutating func selectEvent(id: String) {
        selectedEvent = SelectedCalendarEvent(id: id)
    }

    mutating func dismissEventDetail() {
        selectedEvent = nil
    }
}

struct CalendarScheduleView: View {
    @ObservedObject var service: CalendarIntegrationService
    let weekStartsOn: Weekday

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(\.taskerLayoutClass) private var layoutClass

    @State private var selectedTab: CalendarScheduleTab = .today
    @State private var presentationState = CalendarSchedulePresentationState()
    @State private var isTimelineExpanded = false

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    private var todayEvents: [TaskerCalendarEventSnapshot] {
        service.eventsForDay(Date())
    }

    private var weekAgenda: [TaskerCalendarDayAgenda] {
        service.weekAgenda(anchorDate: Date(), weekStartsOn: weekStartsOn)
    }

    private var weekEventCount: Int {
        weekAgenda.reduce(into: 0) { result, day in
            result += day.events.count
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: spacing.s20) {
                    CalendarScheduleHeaderView(
                        snapshot: service.snapshot,
                        selectedTab: selectedTab,
                        todayEventCount: todayEvents.count,
                        weekEventCount: weekEventCount,
                        onSelectTab: { selectedTab = $0 }
                    )
                    .enhancedStaggeredAppearance(index: 0)

                    content
                        .accessibilityIdentifier("schedule.list")
                        .enhancedStaggeredAppearance(index: 1)
                }
                .taskerReadableContent(maxWidth: layoutClass.isPad ? 960 : .infinity, alignment: .center)
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.top, spacing.s16)
                .padding(.bottom, spacing.sectionGap)
            }
            .background(Color.tasker.bgCanvas.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close", action: dismiss.callAsFunction)
                }
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button(action: handleCalendarFilterTap) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityIdentifier("schedule.filters")
                    .accessibilityLabel("Choose calendars")

                    Button {
                        service.refreshContext(reason: "schedule_manual_refresh")
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityIdentifier("schedule.refresh")
                    .accessibilityLabel("Refresh schedule")
                }
            }
        }
        .task {
            isTimelineExpanded = false
            service.refreshContext(reason: "schedule_appear")
        }
        .sheet(item: $presentationState.selectedEvent) { selected in
            EventKitEventDetailView(
                eventID: selected.id,
                onDismiss: {
                    presentationState.dismissEventDetail()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationBackground(Color.tasker(.bgElevated))
        }
        .sheet(isPresented: $presentationState.showChooser) {
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

    @ViewBuilder
    private var content: some View {
        if service.snapshot.authorizationStatus.isAuthorizedForRead == false {
            permissionRequiredView
        } else if let error = service.snapshot.errorMessage, !error.isEmpty {
            errorView(error)
        } else if service.snapshot.selectedCalendarIDs.isEmpty {
            noCalendarSelectionView
        } else {
            activeContent
        }
    }

    @ViewBuilder
    private var activeContent: some View {
        switch selectedTab {
        case .today:
            CalendarScheduleTodayContent(
                snapshot: service.snapshot,
                events: todayEvents,
                isTimelineExpanded: $isTimelineExpanded,
                onChooseCalendars: handleCalendarFilterTap,
                onSelectEvent: { presentationState.selectEvent(id: $0.id) }
            )
            .accessibilityIdentifier("schedule.today.content")
        case .week:
            CalendarScheduleWeekContent(
                agenda: weekAgenda,
                onSelectEvent: { presentationState.selectEvent(id: $0.id) }
            )
            .accessibilityIdentifier("schedule.week.content")
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
            title: "No calendars selected",
            message: "Choose the calendars that should shape the schedule view and Home day lane.",
            accentColor: Color.tasker.accentSecondary,
            buttonTitle: "Choose Calendars",
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
            title: "Unable to load calendar",
            message: message,
            accentColor: Color.tasker.statusDanger,
            buttonTitle: "Retry",
            buttonAccessibilityIdentifier: "schedule.error.retry",
            bodyAccessibilityIdentifier: "schedule.error.message",
            action: {
                service.refreshContext(reason: "schedule_error_retry")
            }
        )
    }

    private var permissionButtonTitle: String? {
        switch service.snapshot.authorizationStatus {
        case .notDetermined:
            return "Connect Calendar"
        case .denied:
            return "Open Settings"
        case .restricted, .writeOnly, .authorized:
            return nil
        }
    }

    private var permissionTitle: String {
        switch service.snapshot.authorizationStatus {
        case .denied:
            return "Calendar access is off"
        case .restricted:
            return "Calendar access is restricted"
        case .writeOnly:
            return "Read access is required"
        case .notDetermined, .authorized:
            return "Calendar access is required"
        }
    }

    private var permissionSubtitle: String {
        switch service.snapshot.authorizationStatus {
        case .notDetermined:
            return "Grant calendar access to bring Today and Week schedule context into Tasker."
        case .denied:
            return "Open system Settings and allow Calendar access for Tasker."
        case .restricted:
            return "Calendar access is restricted by system policy and cannot be changed here."
        case .writeOnly:
            return "Tasker needs read access to compute schedule context."
        case .authorized:
            return "Calendar access is required."
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
        _ = service.performAccessAction(openSystemSettings: openSystemSettings)
    }

    private func openSystemSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
        #endif
    }
}

typealias HomeDayTimelineLayoutPlan = TaskerCalendarTimelineLayoutPlan
typealias HomeDayTimelineLayoutPlanner = TaskerCalendarTimelinePlanner

private struct CalendarScheduleHeaderView: View {
    let snapshot: TaskerCalendarSnapshot
    let selectedTab: CalendarScheduleTab
    let todayEventCount: Int
    let weekEventCount: Int
    let onSelectTab: (CalendarScheduleTab) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s16) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: spacing.s16) {
                    titleBlock
                    Spacer(minLength: spacing.s12)
                    calendarSelectionChip
                }

                VStack(alignment: .leading, spacing: spacing.s12) {
                    titleBlock
                    calendarSelectionChip
                }
            }

            HStack(spacing: spacing.s8) {
                ForEach(CalendarScheduleTab.allCases) { tab in
                    tabButton(for: tab)
                }
            }
            .padding(spacing.s4)
            .background(Color.tasker.surfaceSecondary.opacity(0.7))
            .overlay(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.xl, style: .continuous)
                    .stroke(Color.tasker.strokeHairline.opacity(0.75), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.xl, style: .continuous))
            .accessibilityIdentifier("schedule.segmented")
        }
        .padding(layoutClass.isPad ? spacing.s20 : spacing.s16)
        .background(Color.tasker.bgElevated)
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous)
                .stroke(Color.tasker.strokeHairline.opacity(0.78), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous))
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: spacing.s8) {
            Text("Schedule")
                .font(layoutClass.isPad ? .tasker(.screenTitle) : .tasker(.title1))
                .foregroundStyle(Color.tasker.textPrimary)

            Text(summaryLine)
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker.textSecondary)
                .lineLimit(3)

            Text("Today \(todayEventCount) • Week \(weekEventCount)")
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textTertiary)
        }
    }

    private var calendarSelectionChip: some View {
        HStack(spacing: spacing.s8) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.tasker.actionPrimary)

            Text(selectionLabel)
                .font(.tasker(.bodyStrong))
                .foregroundStyle(Color.tasker.textPrimary)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .background(Color.tasker.surfacePrimary)
        .overlay(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                .stroke(Color.tasker.strokeHairline.opacity(0.7), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
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
                .background(selectedTab == tab ? selectedBackground(for: tab) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous)
                        .stroke(selectedTab == tab ? selectedStroke(for: tab) : Color.clear, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.lg, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("schedule.segment.\(tab.rawValue)")
        .accessibilityValue(selectedTab == tab ? "selected" : "unselected")
    }

    private func selectedBackground(for tab: CalendarScheduleTab) -> Color {
        switch tab {
        case .today:
            return Color.tasker.actionPrimary
        case .week:
            return Color.tasker.accentSecondary
        }
    }

    private func selectedStroke(for tab: CalendarScheduleTab) -> Color {
        switch tab {
        case .today:
            return Color.tasker.accentRing
        case .week:
            return Color.tasker.accentSecondaryMuted
        }
    }

    private var summaryLine: String {
        if !snapshot.authorizationStatus.isAuthorizedForRead {
            return "Connect Calendar access to bring your real day into focus."
        }

        if snapshot.selectedCalendarIDs.isEmpty {
            return "Choose the calendars that should shape the Today and Week views."
        }

        if let nextMeeting = snapshot.nextMeeting {
            if nextMeeting.isInProgress {
                return "\(nextMeeting.event.title) is active right now."
            }
            return "\(nextMeeting.event.title) is the next anchor."
        }

        if let freeUntil = snapshot.freeUntil {
            return "You have open time until \(freeUntil.formatted(date: .omitted, time: .shortened))."
        }

        if todayEventCount == 0 {
            return "No timed blocks are pressuring the day right now."
        }

        return "\(todayEventCount) events today, with the full week one tap away."
    }

    private var selectionLabel: String {
        let count = snapshot.selectedCalendarIDs.count
        switch count {
        case 0:
            return "No calendars selected"
        case 1:
            return "1 calendar selected"
        default:
            return "\(count) calendars selected"
        }
    }
}

private struct CalendarScheduleTodayContent: View {
    let snapshot: TaskerCalendarSnapshot
    let events: [TaskerCalendarEventSnapshot]
    @Binding var isTimelineExpanded: Bool
    let onChooseCalendars: () -> Void
    let onSelectEvent: (TaskerCalendarEventSnapshot) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    private var timedEvents: [TaskerCalendarEventSnapshot] {
        events.filter { !$0.isAllDay && $0.isBusy }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s20) {
            sectionHeader(
                title: "Today",
                detail: events.isEmpty ? "No events" : "\(events.count) \(events.count == 1 ? "event" : "events")"
            )

            CalendarScheduleTodaySnapshotView(
                snapshot: snapshot,
                eventCount: events.count,
                timedEventCount: timedEvents.count
            )

            CalendarScheduleTimelineSection(
                date: Date(),
                events: events,
                isExpanded: $isTimelineExpanded
            )

            if events.isEmpty {
                CalendarScheduleStatePanel(
                    iconName: "sparkles",
                    title: "No events today",
                    message: "Your day is clear. Use the open space for focused work or planning.",
                    accentColor: Color.tasker.statusSuccess,
                    buttonTitle: "Choose Calendars",
                    buttonAccessibilityIdentifier: "schedule.today.chooseCalendars",
                    bodyAccessibilityIdentifier: "schedule.today.empty",
                    action: onChooseCalendars
                )
            } else {
                VStack(alignment: .leading, spacing: spacing.s12) {
                    sectionHeader(
                        title: "Agenda",
                        detail: timedEvents.isEmpty ? "All-day only" : "\(timedEvents.count) timed block\(timedEvents.count == 1 ? "" : "s")"
                    )

                    VStack(spacing: 0) {
                        ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                            CalendarScheduleEventRow(event: event) {
                                onSelectEvent(event)
                            }

                            if index < events.count - 1 {
                                Divider()
                                    .padding(.leading, 26)
                            }
                        }
                    }
                    .background(Color.tasker.surfacePrimary)
                    .overlay(
                        RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous)
                            .stroke(Color.tasker.strokeHairline.opacity(0.72), lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous))
                }
            }
        }
    }

    private func sectionHeader(title: String, detail: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
            Text(title)
                .font(.tasker(.sectionTitle))
                .foregroundStyle(Color.tasker.textPrimary)

            Spacer(minLength: 0)

            Text(detail)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)
        }
    }
}

private struct CalendarScheduleWeekContent: View {
    let agenda: [TaskerCalendarDayAgenda]
    let onSelectEvent: (TaskerCalendarEventSnapshot) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    private var totalEvents: Int {
        agenda.reduce(into: 0) { result, day in
            result += day.events.count
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s20) {
            HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                Text("Week")
                    .font(.tasker(.sectionTitle))
                    .foregroundStyle(Color.tasker.textPrimary)

                Spacer(minLength: 0)

                Text(totalEvents == 0 ? "Clear week" : "\(totalEvents) \(totalEvents == 1 ? "event" : "events")")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
            }

            if agenda.allSatisfy({ $0.events.isEmpty }) {
                CalendarScheduleStatePanel(
                    iconName: "calendar.badge.clock",
                    title: "No events this week",
                    message: "The week horizon is clear with the currently selected calendars.",
                    accentColor: Color.tasker.stateInfo,
                    buttonTitle: nil,
                    buttonAccessibilityIdentifier: nil,
                    bodyAccessibilityIdentifier: "schedule.week.empty",
                    action: nil
                )
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(agenda.enumerated()), id: \.element.id) { index, day in
                        CalendarScheduleWeekDaySection(day: day, onSelectEvent: onSelectEvent)
                            .padding(.vertical, spacing.s16)
                            .accessibilityIdentifier("schedule.week.day.\(day.id)")

                        if index < agenda.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }
}

private struct CalendarScheduleWeekDaySection: View {
    let day: TaskerCalendarDayAgenda
    let onSelectEvent: (TaskerCalendarEventSnapshot) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                Text(TaskerCalendarPresentation.scheduleDateText(for: day.date))
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker.textPrimary)

                Spacer(minLength: 0)

                Text(day.events.isEmpty ? "Clear" : "\(day.events.count)")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
            }

            if day.events.isEmpty {
                Text("No events")
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker.textSecondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(day.events.enumerated()), id: \.element.id) { index, event in
                        CalendarScheduleEventRow(event: event) {
                            onSelectEvent(event)
                        }

                        if index < day.events.count - 1 {
                            Divider()
                                .padding(.leading, 26)
                        }
                    }
                }
                .background(Color.tasker.surfacePrimary)
                .overlay(
                    RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous)
                        .stroke(Color.tasker.strokeHairline.opacity(0.72), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.card, style: .continuous))
            }
        }
    }
}

private struct CalendarScheduleTodaySnapshotView: View {
    let snapshot: TaskerCalendarSnapshot
    let eventCount: Int
    let timedEventCount: Int

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(primaryTitle)
                        .font(.tasker(.bodyStrong))
                        .foregroundStyle(Color.tasker.textPrimary)

                    Text(primaryDetail)
                        .font(.tasker(.callout))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(eventCount)")
                        .font(.tasker(.title3))
                        .foregroundStyle(Color.tasker.textPrimary)

                    Text(timedEventCount == 0 ? "all-day only" : "\(timedEventCount) timed")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                }
            }

            CalendarScheduleBusyStripView(
                busyBlocks: snapshot.busyBlocks,
                referenceDate: Date()
            )

            if let freeUntil = snapshot.freeUntil {
                Label("Free until \(freeUntil.formatted(date: .omitted, time: .shortened))", systemImage: "leaf")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.statusSuccess)
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

    private var primaryTitle: String {
        if let nextMeeting = snapshot.nextMeeting {
            return nextMeeting.isInProgress ? "Currently busy" : "Next meeting"
        }
        return "No upcoming meetings"
    }

    private var primaryDetail: String {
        if let nextMeeting = snapshot.nextMeeting {
            return "\(nextMeeting.event.title) • \(TaskerCalendarPresentation.timeRangeText(for: nextMeeting.event))"
        }
        return "Use the open space for focused work or planning."
    }
}

private struct CalendarScheduleTimelineSection: View {
    let date: Date
    let events: [TaskerCalendarEventSnapshot]
    @Binding var isExpanded: Bool

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
                Text("W\(Calendar.current.component(.weekOfYear, from: date))")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textTertiary)

                Spacer(minLength: 0)

                Text(timelineDateLabel)
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker.statusDanger)

                Spacer(minLength: 0)

                if timedEvents.isEmpty == false {
                    Button(action: toggleExpanded) {
                        Label(isExpanded ? "Collapse" : "Expand", systemImage: isExpanded ? "chevron.up" : "chevron.down")
                            .labelStyle(.titleAndIcon)
                    }
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("schedule.timeline.toggle")
                    .accessibilityLabel(isExpanded ? "Collapse live timeline" : "Expand live timeline")
                } else {
                    Text("Timeline")
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textTertiary)
                }
            }

            if timedEvents.isEmpty {
                Text("No timed blocks today. All-day events stay in the agenda below.")
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, spacing.s12)
                    .accessibilityIdentifier("schedule.timeline.compact")
            } else if isExpanded {
                TaskerCalendarTimelineView(
                    date: date,
                    events: events,
                    density: .expanded,
                    showsDateLabel: false,
                    emptyText: "No timed blocks today",
                    accessibilityIdentifier: "schedule.timeline.expanded",
                    accessibilityLabelText: "Expanded live timeline for the full day.",
                    initialVisibleHour: targetHour
                )
            } else {
                Button {
                    toggleExpanded()
                } label: {
                    TaskerCalendarTimelineView(
                        date: date,
                        events: events,
                        density: .compact,
                        showsDateLabel: false,
                        emptyText: "No timed blocks in view",
                        accessibilityIdentifier: "schedule.timeline.compact",
                        accessibilityLabelText: "Compact live timeline. Double tap to expand.",
                        initialVisibleHour: nil
                    )
                }
                .buttonStyle(.plain)
                .accessibilityHint("Expands to show the full day")
            }
        }
        .accessibilityIdentifier("schedule.timeline")
    }

    private var timelineDateLabel: String {
        let weekday = date.formatted(.dateTime.weekday(.abbreviated))
        let monthDay = date.formatted(.dateTime.month(.abbreviated).day())
        return "\(weekday) - \(monthDay)"
    }

    private func toggleExpanded() {
        if reduceMotion {
            isExpanded.toggle()
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                isExpanded.toggle()
            }
        }
    }
}

private struct CalendarScheduleBusyStripView: View {
    let busyBlocks: [TaskerCalendarBusyBlock]
    let referenceDate: Date

    var body: some View {
        GeometryReader { proxy in
            let segments = busySegments(width: proxy.size.width)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.tasker.surfaceSecondary)

                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.tasker.statusWarning.opacity(0.88))
                        .frame(width: segment.width, height: 10)
                        .offset(x: segment.x)
                }
            }
        }
        .frame(height: 10)
    }

    private func busySegments(width: CGFloat) -> [(x: CGFloat, width: CGFloat)] {
        guard width > 0 else { return [] }

        let calendar = Calendar.current
        let horizonStart = calendar.startOfDay(for: referenceDate)
        let horizonEnd = calendar.date(byAdding: .hour, value: 12, to: horizonStart) ?? horizonStart
        let horizonDuration = max(1, horizonEnd.timeIntervalSince(horizonStart))

        return busyBlocks.compactMap { block in
            let start = max(horizonStart, block.startDate)
            let end = min(horizonEnd, block.endDate)
            guard end > start else { return nil }

            let startRatio = start.timeIntervalSince(horizonStart) / horizonDuration
            let endRatio = end.timeIntervalSince(horizonStart) / horizonDuration
            let x = CGFloat(startRatio) * width
            let segmentWidth = max(2, CGFloat(endRatio - startRatio) * width)
            return (x: x, width: segmentWidth)
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

    let startHour: Int
    let endHour: Int
    let positionedEvents: [PositionedEvent]

    var hourMarkers: [Int] {
        Array(startHour...endHour)
    }
}

enum TaskerCalendarTimelinePlanner {
    static let defaultWorkdayStartHour = 8
    static let defaultWorkdayEndHour = 18

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

        let startHour = visibleRange.startMinute / 60
        let endHour = max(startHour, (visibleRange.endMinute / 60) - 1)

        return TaskerCalendarTimelineLayoutPlan(
            startHour: startHour,
            endHour: endHour,
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

        let currentHour = calendar.component(.hour, from: anchorDate)
        let earliestHour = selectedDayEvents.map { $0.startMinute / 60 }.min()
        let nextOrLaterHour = selectedDayEvents
            .map { $0.startMinute / 60 }
            .filter { $0 >= currentHour }
            .min()

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

        return workdayEndHour
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
            let defaultEnd = min(24 * 60, defaultStart + 180)
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
        let roundedStartHour = max(0, min(21, Int(floor(Double(startMinute) / 60.0))))
        let visibleStartMinute = roundedStartHour * 60
        let visibleEndMinute = min(24 * 60, visibleStartMinute + 180)
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

struct TaskerCalendarTimelineView: View {
    let date: Date
    let events: [TaskerCalendarEventSnapshot]
    var density: TaskerCalendarTimelineDensity = .compact
    var showsDateLabel = true
    var emptyText = "Nothing in this window"
    var accessibilityIdentifier: String? = nil
    var accessibilityLabelText: String? = nil
    var initialVisibleHour: Int? = nil

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
    }

    @ViewBuilder
    private func content(anchorDate: Date) -> some View {
        if let layoutPlan = TaskerCalendarTimelinePlanner.makePlan(
            for: events,
            on: date,
            density: density,
            anchorDate: anchorDate
        ) {
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
        }
    }

    private func compactTimelineBody(
        layoutPlan: TaskerCalendarTimelineLayoutPlan,
        anchorDate: Date
    ) -> some View {
        GeometryReader { proxy in
            timelineCanvas(layoutPlan: layoutPlan, anchorDate: anchorDate, totalWidth: proxy.size.width)
        }
        .frame(height: CGFloat(layoutPlan.endHour - layoutPlan.startHour + 1) * metrics.hourHeight)
    }

    private func expandedTimelineBody(
        layoutPlan: TaskerCalendarTimelineLayoutPlan,
        anchorDate: Date
    ) -> some View {
        GeometryReader { proxy in
            ScrollViewReader { scrollProxy in
                ScrollView(.vertical) {
                    timelineCanvas(layoutPlan: layoutPlan, anchorDate: anchorDate, totalWidth: proxy.size.width)
                        .frame(height: CGFloat(layoutPlan.endHour - layoutPlan.startHour + 1) * metrics.hourHeight)
                }
                .scrollIndicators(.visible)
                .onAppear {
                    let targetHour = min(
                        max(layoutPlan.startHour, initialVisibleHour ?? layoutPlan.startHour),
                        max(layoutPlan.startHour, layoutPlan.endHour)
                    )
                    DispatchQueue.main.async {
                        if reduceMotion {
                            scrollProxy.scrollTo(hourAnchorID(targetHour), anchor: .top)
                        } else {
                            withAnimation(.easeInOut(duration: 0.22)) {
                                scrollProxy.scrollTo(hourAnchorID(targetHour), anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: layoutClass.isPad ? 560 : 460)
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
        let totalHeight = CGFloat(plan.endHour - plan.startHour + 1) * metrics.hourHeight

        return ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(Color.clear)
                .frame(width: metrics.labelColumnWidth + width, height: totalHeight)

            Rectangle()
                .fill(Color.tasker.strokeHairline.opacity(0.55))
                .frame(width: 1, height: totalHeight)
                .offset(x: metrics.labelColumnWidth)

            ForEach(Array(plan.hourMarkers.enumerated()), id: \.offset) { offset, hour in
                let y = CGFloat(offset) * metrics.hourHeight

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
                TaskerCalendarTimelineEventCard(
                    event: positioned.event,
                    density: density,
                    height: frame.height,
                    differentiateWithoutColor: differentiateWithoutColor
                )
                .frame(width: frame.width, height: frame.height, alignment: .topLeading)
                .offset(x: metrics.labelColumnWidth + frame.minX, y: frame.minY)
            }
        }
    }

    private func timelineEmptyState(width: CGFloat, plan: TaskerCalendarTimelineLayoutPlan) -> some View {
        Text(emptyText)
            .font(.tasker(.callout))
            .foregroundStyle(Color.tasker.textSecondary)
            .frame(width: width, height: CGFloat(plan.endHour - plan.startHour + 1) * metrics.hourHeight)
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
        let minY = CGFloat(event.startMinute - (plan.startHour * 60)) / 60.0 * metrics.hourHeight + metrics.verticalInset
        let height = max(
            metrics.minimumCardHeight,
            CGFloat(event.endMinute - event.startMinute) / 60.0 * metrics.hourHeight - (metrics.verticalInset * 2)
        )
        return CGRect(x: minX, y: minY, width: contentWidth, height: height)
    }

    private func hourLabel(_ hour: Int) -> String {
        if hour == 12 {
            return "Noon"
        }

        let normalizedHour = hour == 24 ? 0 : hour
        let markerDate = Calendar.current.date(
            bySettingHour: normalizedHour,
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
        let startMinute = plan.startHour * 60
        let endMinute = (plan.endHour + 1) * 60
        guard nowMinute >= startMinute, nowMinute <= endMinute else { return nil }

        return CGFloat(nowMinute - startMinute) / 60.0 * metrics.hourHeight
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
                .accessibilityElement(children: .ignore)
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
