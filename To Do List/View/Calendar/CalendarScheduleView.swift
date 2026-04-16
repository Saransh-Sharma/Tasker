import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

private enum CalendarScheduleTab: String, CaseIterable, Identifiable {
    case today
    case week

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .week: return "Week"
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
    @State private var selectedTab: CalendarScheduleTab = .today
    @State private var presentationState = CalendarSchedulePresentationState()

    var body: some View {
        NavigationStack {
            Group {
                if service.snapshot.authorizationStatus.isAuthorizedForRead == false {
                    permissionRequiredView
                } else if let error = service.snapshot.errorMessage, error.isEmpty == false {
                    errorView(error)
                } else if service.snapshot.selectedCalendarIDs.isEmpty {
                    noCalendarSelectionView
                } else {
                    agendaContent
                }
            }
            .navigationTitle("Schedule")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        handleCalendarFilterTap()
                    } label: {
                        Label("Calendar Filters", systemImage: "slider.horizontal.3")
                            .labelStyle(.iconOnly)
                    }
                    .disabled(service.snapshot.authorizationStatus == .restricted || service.snapshot.authorizationStatus == .writeOnly)
                    .accessibilityIdentifier("schedule.filters")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        service.refreshContext(reason: "schedule_manual_refresh")
                    } label: {
                        Label("Refresh Schedule", systemImage: "arrow.clockwise")
                            .labelStyle(.iconOnly)
                    }
                    .accessibilityIdentifier("schedule.refresh")
                }
            }
        }
        .onAppear {
            service.refreshContext(reason: "schedule_appear")
        }
        .sheet(item: $presentationState.selectedEvent) { selected in
            EventKitEventDetailView(
                eventID: selected.id,
                onDismiss: {
                    presentationState.dismissEventDetail()
                }
            )
        }
        .sheet(isPresented: $presentationState.showChooser) {
            EventKitCalendarChooserSheet(
                initialSelectedCalendarIDs: service.snapshot.selectedCalendarIDs,
                onCancel: {
                    presentationState.cancelChooser()
                },
                onCommit: { selectedIDs in
                    service.updateSelectedCalendarIDs(selectedIDs)
                    presentationState.commitChooser()
                }
            )
        }
    }

    private var agendaContent: some View {
        VStack(spacing: 0) {
            Picker("Schedule Range", selection: $selectedTab) {
                ForEach(CalendarScheduleTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, TaskerTheme.Spacing.screenHorizontal)
            .padding(.vertical, TaskerTheme.Spacing.sm)
            .accessibilityIdentifier("schedule.segmented")

            List {
                switch selectedTab {
                case .today:
                    let events = service.eventsForDay(Date())
                    if events.isEmpty {
                        Text("No events today")
                            .font(.tasker(.callout))
                            .foregroundStyle(Color.tasker.textSecondary)
                    } else {
                        ForEach(events) { event in
                            calendarEventRow(event)
                        }
                    }
                case .week:
                    ForEach(service.weekAgenda(anchorDate: Date(), weekStartsOn: weekStartsOn)) { day in
                        Section(day.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())) {
                            if day.events.isEmpty {
                                Text("No events")
                                    .font(.tasker(.caption1))
                                    .foregroundStyle(Color.tasker.textSecondary)
                            } else {
                                ForEach(day.events) { event in
                                    calendarEventRow(event)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .accessibilityIdentifier("schedule.list")
        }
    }

    private func calendarEventRow(_ event: TaskerCalendarEventSnapshot) -> some View {
        Button {
            presentationState.selectEvent(id: event.id)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.tasker(.bodyStrong))
                    .foregroundStyle(Color.tasker.textPrimary)
                    .lineLimit(2)

                Text(calendarEventTimeLine(event))
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker.textSecondary)
                    .lineLimit(1)

                if let location = event.location, location.isEmpty == false {
                    Text(location)
                        .font(.tasker(.caption2))
                        .foregroundStyle(Color.tasker.textTertiary)
                        .lineLimit(1)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("schedule.event.\(event.id)")
    }

    private func calendarEventTimeLine(_ event: TaskerCalendarEventSnapshot) -> String {
        if event.isAllDay {
            return "All day"
        }
        let start = event.startDate.formatted(date: .omitted, time: .shortened)
        let end = event.endDate.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }

    private var permissionRequiredView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 36, weight: .semibold))
                .foregroundStyle(Color.tasker.statusWarning)
            Text(permissionTitle)
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker.textPrimary)
            Text(permissionSubtitle)
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker.textSecondary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier(permissionStateAccessibilityID)

            if permissionButtonTitle != nil {
                Button(permissionButtonTitle ?? "Connect Calendar") {
                    performPermissionAction()
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("schedule.permission.connect")
            }
        }
        .padding(24)
    }

    private var noCalendarSelectionView: some View {
        VStack(spacing: 12) {
            Text("No calendars selected")
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker.textPrimary)
            Text("Choose one or more calendars to populate the schedule.")
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker.textSecondary)
                .multilineTextAlignment(.center)
            Button("Choose Calendars") {
                presentationState.presentChooser()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("schedule.noCalendars.choose")
        }
        .padding(24)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Text("Unable to load calendar")
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker.textPrimary)
            Text(message)
                .font(.tasker(.callout))
                .foregroundStyle(Color.tasker.statusWarning)
                .multilineTextAlignment(.center)
            Button("Retry") {
                service.refreshContext(reason: "schedule_error_retry")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("schedule.error.retry")
        }
        .padding(24)
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
            return "Grant calendar access to show Today and Week schedule context."
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
            return
        }
        performPermissionAction()
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
