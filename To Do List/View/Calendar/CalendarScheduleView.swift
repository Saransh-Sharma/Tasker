import SwiftUI

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

private struct SelectedCalendarEvent: Identifiable, Equatable {
    let id: String
}

struct CalendarScheduleView: View {
    @ObservedObject var service: CalendarIntegrationService
    let weekStartsOn: Weekday

    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: CalendarScheduleTab = .today
    @State private var selectedEvent: SelectedCalendarEvent?
    @State private var showChooser = false

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
                        showChooser = true
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .accessibilityIdentifier("schedule.filters")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        service.refreshContext(reason: "schedule_manual_refresh")
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .accessibilityIdentifier("schedule.refresh")
                }
            }
        }
        .onAppear {
            service.refreshContext(reason: "schedule_appear")
        }
        .sheet(item: $selectedEvent) { selected in
            EventKitEventDetailView(eventID: selected.id)
        }
        .sheet(isPresented: $showChooser) {
            EventKitCalendarChooserSheet(
                initialSelectedCalendarIDs: service.snapshot.selectedCalendarIDs,
                onCancel: {},
                onCommit: { selectedIDs in
                    service.updateSelectedCalendarIDs(selectedIDs)
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
            selectedEvent = SelectedCalendarEvent(id: event.id)
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
            Text("Calendar access is required")
                .font(.tasker(.headline))
                .foregroundStyle(Color.tasker.textPrimary)
            Button("Connect Calendar") {
                service.requestAccess()
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("schedule.permission.connect")
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
                showChooser = true
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
}
