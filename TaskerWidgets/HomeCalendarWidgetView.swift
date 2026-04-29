import SwiftUI
import WidgetKit

struct HomeCalendarWidgetView: View {
    let entry: TaskListEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                HomeCalendarSmallWidget(calendar: entry.snapshot.calendar, isStale: entry.snapshot.snapshotHealth.isStale)
            case .systemMedium:
                HomeCalendarMediumWidget(calendar: entry.snapshot.calendar, isStale: entry.snapshot.snapshotHealth.isStale)
            case .systemLarge:
                HomeCalendarLargeWidget(calendar: entry.snapshot.calendar, isStale: entry.snapshot.snapshotHealth.isStale)
            case .systemExtraLarge:
                HomeCalendarExtraLargeWidget(calendar: entry.snapshot.calendar, isStale: entry.snapshot.snapshotHealth.isStale)
            default:
                HomeCalendarMediumWidget(calendar: entry.snapshot.calendar, isStale: entry.snapshot.snapshotHealth.isStale)
            }
        }
        .widgetURL(TaskWidgetRoutes.calendarSchedule)
        .accessibilityElement(children: .contain)
    }
}

private struct HomeCalendarSmallWidget: View {
    let calendar: TaskListWidgetCalendarSnapshot
    let isStale: Bool

    var body: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                HomeCalendarWidgetHeader(calendar: calendar, detail: HomeCalendarWidgetFormatter.countText(calendar.eventsTodayCount))

                if let nextMeeting = calendar.nextMeeting, calendar.status == .active {
                    HomeCalendarNextMeetingSummary(nextMeeting: nextMeeting, freeUntil: calendar.freeUntil)
                } else {
                    HomeCalendarStatusSummary(calendar: calendar, isStale: isStale, compact: true)
                }

                Spacer(minLength: 0)

                HomeCalendarWidgetFooter(calendar: calendar, isStale: isStale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityLabel(HomeCalendarWidgetFormatter.accessibilitySummary(calendar: calendar, isStale: isStale))
    }
}

private struct HomeCalendarMediumWidget: View {
    let calendar: TaskListWidgetCalendarSnapshot
    let isStale: Bool

    var body: some View {
        TaskWidgetScene { context in
            HStack(alignment: .top, spacing: context.sectionSpacing) {
                VStack(alignment: .leading, spacing: context.sectionSpacing) {
                    HomeCalendarWidgetHeader(calendar: calendar, detail: HomeCalendarWidgetFormatter.countText(calendar.eventsTodayCount))
                    HomeCalendarWeekStrip(calendar: calendar)
                    HomeCalendarWidgetFooter(calendar: calendar, isStale: isStale)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                HomeCalendarEventStack(
                    calendar: calendar,
                    limit: 3,
                    emptyCompact: true,
                    isStale: isStale
                )
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .accessibilityLabel(HomeCalendarWidgetFormatter.accessibilitySummary(calendar: calendar, isStale: isStale))
    }
}

private struct HomeCalendarLargeWidget: View {
    let calendar: TaskListWidgetCalendarSnapshot
    let isStale: Bool

    var body: some View {
        TaskWidgetScene { context in
            VStack(alignment: .leading, spacing: context.sectionSpacing) {
                HomeCalendarWidgetHeader(calendar: calendar, detail: HomeCalendarWidgetFormatter.countText(calendar.eventsTodayCount))
                HomeCalendarStatusBand(calendar: calendar, isStale: isStale)
                HomeCalendarDayTimeline(calendar: calendar, eventLimit: 5, isStale: isStale)
                Spacer(minLength: 0)
                HomeCalendarWidgetFooter(calendar: calendar, isStale: isStale)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .accessibilityLabel(HomeCalendarWidgetFormatter.accessibilitySummary(calendar: calendar, isStale: isStale))
    }
}

private struct HomeCalendarExtraLargeWidget: View {
    let calendar: TaskListWidgetCalendarSnapshot
    let isStale: Bool

    var body: some View {
        TaskWidgetScene { context in
            HStack(alignment: .top, spacing: context.sectionSpacing + 2) {
                VStack(alignment: .leading, spacing: context.sectionSpacing) {
                    HomeCalendarWidgetHeader(calendar: calendar, detail: HomeCalendarWidgetFormatter.countText(calendar.eventsTodayCount))
                    HomeCalendarStatusBand(calendar: calendar, isStale: isStale)
                    HomeCalendarDayTimeline(calendar: calendar, eventLimit: 6, isStale: isStale)
                    Spacer(minLength: 0)
                    HomeCalendarWidgetFooter(calendar: calendar, isStale: isStale)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)

                HomeCalendarWeekAgenda(calendar: calendar)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .accessibilityLabel(HomeCalendarWidgetFormatter.accessibilitySummary(calendar: calendar, isStale: isStale))
    }
}

private struct HomeCalendarWidgetHeader: View {
    let calendar: TaskListWidgetCalendarSnapshot
    let detail: String

    var body: some View {
        TaskWidgetSectionHeader(
            eyebrow: "Calendar",
            title: HomeCalendarWidgetFormatter.dateText(calendar.date),
            detail: detail,
            accent: WidgetBrand.textPrimary
        )
    }
}

private struct HomeCalendarStatusBand: View {
    let calendar: TaskListWidgetCalendarSnapshot
    let isStale: Bool

    var body: some View {
        TaskWidgetPanel(accent: HomeCalendarWidgetFormatter.statusTint(calendar.status), style: .accentWash, padding: 10) {
            HomeCalendarStatusSummary(calendar: calendar, isStale: isStale, compact: false)
        }
    }
}

private struct HomeCalendarStatusSummary: View {
    let calendar: TaskListWidgetCalendarSnapshot
    let isStale: Bool
    let compact: Bool

    var body: some View {
        Label {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(compact ? TaskWidgetTypography.bodyStrong : TaskWidgetTypography.title)
                    .foregroundStyle(WidgetBrand.textPrimary)
                    .lineLimit(compact ? 2 : 1)
                Text(detail)
                    .font(TaskWidgetTypography.support)
                    .foregroundStyle(WidgetBrand.textSecondary)
                    .lineLimit(compact ? 3 : 2)
            }
        } icon: {
            Image(systemName: symbol)
                .widgetAccentedRenderingMode(.accented)
                .foregroundStyle(HomeCalendarWidgetFormatter.statusTint(calendar.status))
                .widgetAccentable()
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        if isStale {
            return "Schedule may be stale"
        }

        switch calendar.status {
        case .permissionRequired:
            return "Connect Calendar"
        case .noCalendarsSelected:
            return "No Calendars"
        case .empty:
            return "Clear Window"
        case .allDayOnly:
            return "All-Day Only"
        case .error:
            return "Calendar Needs Attention"
        case .active:
            return calendar.nextMeeting?.event.title ?? "Schedule Ready"
        }
    }

    private var detail: String {
        if isStale {
            return "Open Tasker to refresh schedule context."
        }

        switch calendar.status {
        case .permissionRequired:
            return "Allow full calendar access in Tasker."
        case .noCalendarsSelected:
            return "Choose at least one calendar for schedule insights."
        case .empty:
            if let freeUntil = calendar.freeUntil {
                return "Free until \(HomeCalendarWidgetFormatter.timeText(freeUntil))."
            }
            return "No events are scheduled. Use this open window for focused work."
        case .allDayOnly:
            return "Only all-day events are scheduled today."
        case .error:
            return calendar.errorMessage?.isEmpty == false ? calendar.errorMessage ?? "Open Tasker to refresh." : "Open Tasker to refresh."
        case .active:
            if let nextMeeting = calendar.nextMeeting {
                return HomeCalendarWidgetFormatter.nextMeetingDetail(nextMeeting, freeUntil: calendar.freeUntil)
            }
            return HomeCalendarWidgetFormatter.countText(calendar.eventsTodayCount)
        }
    }

    private var symbol: String {
        switch calendar.status {
        case .permissionRequired:
            return "calendar.badge.exclamationmark"
        case .noCalendarsSelected:
            return "calendar.badge.minus"
        case .empty:
            return "calendar"
        case .allDayOnly:
            return "sun.max"
        case .error:
            return "exclamationmark.triangle"
        case .active:
            return "calendar.badge.clock"
        }
    }
}

private struct HomeCalendarNextMeetingSummary: View {
    let nextMeeting: TaskListWidgetCalendarNextMeeting
    let freeUntil: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(nextMeeting.isInProgress ? "Now" : "Next Up")
                .font(TaskWidgetTypography.eyebrow)
                .foregroundStyle(WidgetBrand.textSecondary)
            Text(nextMeeting.event.title)
                .font(TaskWidgetTypography.titleLarge)
                .foregroundStyle(WidgetBrand.textPrimary)
                .lineLimit(3)
            Text(HomeCalendarWidgetFormatter.nextMeetingDetail(nextMeeting, freeUntil: freeUntil))
                .font(TaskWidgetTypography.support)
                .foregroundStyle(WidgetBrand.textSecondary)
                .lineLimit(2)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct HomeCalendarDayTimeline: View {
    let calendar: TaskListWidgetCalendarSnapshot
    let eventLimit: Int
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if calendar.allDayEvents.isEmpty == false {
                HomeCalendarAllDayStrip(events: calendar.allDayEvents)
            }

            HomeCalendarEventStack(
                calendar: calendar,
                limit: eventLimit,
                emptyCompact: false,
                isStale: isStale
            )
        }
    }
}

private struct HomeCalendarEventStack: View {
    let calendar: TaskListWidgetCalendarSnapshot
    let limit: Int
    let emptyCompact: Bool
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if calendar.timedEvents.isEmpty || calendar.status != .active {
                HomeCalendarStatusSummary(calendar: calendar, isStale: isStale, compact: emptyCompact)
            } else {
                ForEach(Array(calendar.timedEvents.prefix(limit))) { event in
                    HomeCalendarEventRow(event: event)
                }
            }
        }
    }
}

private struct HomeCalendarEventRow: View {
    let event: TaskListWidgetCalendarEvent

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(spacing: 3) {
                Circle()
                    .fill(HomeCalendarWidgetFormatter.tint(for: event))
                    .frame(width: 8, height: 8)
                    .widgetAccentable()
                Rectangle()
                    .fill(HomeCalendarWidgetFormatter.tint(for: event).opacity(0.42))
                    .frame(width: 2)
            }
            .frame(width: 10)
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Image(systemName: HomeCalendarWidgetFormatter.symbol(for: event))
                        .font(TaskWidgetTypography.caption)
                        .foregroundStyle(HomeCalendarWidgetFormatter.tint(for: event))
                        .accessibilityHidden(true)
                    Text(event.title)
                        .font(TaskWidgetTypography.bodyStrong)
                        .foregroundStyle(WidgetBrand.textPrimary)
                        .lineLimit(1)
                }
                Text(HomeCalendarWidgetFormatter.eventTimeText(event))
                    .font(TaskWidgetTypography.caption)
                    .foregroundStyle(WidgetBrand.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(HomeCalendarWidgetFormatter.eventAccessibilityText(event))
    }
}

private struct HomeCalendarAllDayStrip: View {
    let events: [TaskListWidgetCalendarEvent]

    var body: some View {
        HStack(spacing: 6) {
            Label("All Day", systemImage: "sun.max")
                .font(TaskWidgetTypography.captionStrong)
                .foregroundStyle(WidgetBrand.textSecondary)
                .lineLimit(1)

            ForEach(Array(events.prefix(2))) { event in
                Text(event.title)
                    .font(TaskWidgetTypography.caption)
                    .foregroundStyle(WidgetBrand.textPrimary)
                    .lineLimit(1)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 4)
                    .background(HomeCalendarWidgetFormatter.tint(for: event).opacity(0.14), in: Capsule())
            }

            if events.count > 2 {
                Text("+\(events.count - 2)")
                    .font(TaskWidgetTypography.captionStrong)
                    .foregroundStyle(WidgetBrand.textSecondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(events.count) all-day event\(events.count == 1 ? "" : "s")")
    }
}

private struct HomeCalendarWeekStrip: View {
    let calendar: TaskListWidgetCalendarSnapshot

    var body: some View {
        HStack(spacing: 4) {
            ForEach(calendar.weekDays) { day in
                VStack(spacing: 3) {
                    Text(HomeCalendarWidgetFormatter.weekdayText(day.date))
                        .font(TaskWidgetTypography.eyebrow)
                        .foregroundStyle(WidgetBrand.textSecondary)
                    Text("\(day.eventCount)")
                        .font(TaskWidgetTypography.captionStrong)
                        .foregroundStyle(HomeCalendarWidgetFormatter.dayTint(day))
                        .taskWidgetAccentable(if: day.eventCount > 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(HomeCalendarWidgetFormatter.dayTint(day).opacity(day.eventCount > 0 ? 0.12 : 0.04), in: RoundedRectangle(cornerRadius: 8))
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(WidgetBrand.line.opacity(day.eventCount > 0 ? 0.5 : 0.28), lineWidth: 1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(HomeCalendarWidgetFormatter.fullDateText(day.date)), \(HomeCalendarWidgetFormatter.countText(day.eventCount))")
            }
        }
    }
}

private struct HomeCalendarWeekAgenda: View {
    let calendar: TaskListWidgetCalendarSnapshot

    var body: some View {
        TaskWidgetPanel(style: .quiet, padding: 10) {
            TaskWidgetSectionHeader(eyebrow: "Week", title: "Agenda", detail: nil, accent: WidgetBrand.textPrimary)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(calendar.weekDays) { day in
                    HomeCalendarWeekAgendaDay(day: day)
                }
            }
        }
    }
}

private struct HomeCalendarWeekAgendaDay: View {
    let day: TaskListWidgetCalendarDay

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(HomeCalendarWidgetFormatter.weekdayText(day.date))
                .font(TaskWidgetTypography.captionStrong)
                .foregroundStyle(HomeCalendarWidgetFormatter.dayTint(day))
                .frame(width: 32, alignment: .leading)
            Text(summary)
                .font(TaskWidgetTypography.caption)
                .foregroundStyle(day.eventCount > 0 ? WidgetBrand.textPrimary : WidgetBrand.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(day.eventCount)")
                .font(TaskWidgetTypography.captionStrong)
                .foregroundStyle(WidgetBrand.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(HomeCalendarWidgetFormatter.fullDateText(day.date)), \(summary)")
    }

    private var summary: String {
        if let first = day.timedEvents.first {
            return "\(HomeCalendarWidgetFormatter.timeText(first.startDate)) \(first.title)"
        }
        if let first = day.allDayEvents.first {
            return "All day \(first.title)"
        }
        return "Clear"
    }
}

private struct HomeCalendarWidgetFooter: View {
    let calendar: TaskListWidgetCalendarSnapshot
    let isStale: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isStale ? "arrow.clockwise.circle" : "arrow.up.right")
                .font(TaskWidgetTypography.caption)
                .foregroundStyle(WidgetBrand.textSecondary)
                .accessibilityHidden(true)
            Text(isStale ? "Open to refresh" : "Open schedule")
                .font(TaskWidgetTypography.captionStrong)
                .foregroundStyle(WidgetBrand.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(calendar.selectedCalendarCount)/\(max(calendar.availableCalendarCount, calendar.selectedCalendarCount))")
                .font(TaskWidgetTypography.caption)
                .foregroundStyle(WidgetBrand.textTertiary)
                .lineLimit(1)
                .accessibilityLabel("\(calendar.selectedCalendarCount) selected calendars")
        }
    }
}

@MainActor
private enum HomeCalendarWidgetFormatter {
    static func dateText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }

    static func fullDateText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    static func weekdayText(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.narrow))
    }

    static func timeText(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func countText(_ count: Int) -> String {
        "\(count) event\(count == 1 ? "" : "s")"
    }

    static func eventTimeText(_ event: TaskListWidgetCalendarEvent) -> String {
        if event.isAllDay {
            return "All day"
        }
        return "\(timeText(event.startDate)) - \(timeText(event.endDate))"
    }

    static func nextMeetingDetail(
        _ nextMeeting: TaskListWidgetCalendarNextMeeting,
        freeUntil: Date?
    ) -> String {
        if nextMeeting.isInProgress {
            return "In progress until \(timeText(nextMeeting.event.endDate))"
        }
        if nextMeeting.minutesUntilStart <= 0 {
            return eventTimeText(nextMeeting.event)
        }
        if nextMeeting.minutesUntilStart < 60 {
            return "Starts in \(nextMeeting.minutesUntilStart)m"
        }
        if let freeUntil {
            return "Free until \(timeText(freeUntil))"
        }
        return eventTimeText(nextMeeting.event)
    }

    static func statusTint(_ status: TaskListWidgetCalendarStatus) -> Color {
        switch status {
        case .permissionRequired, .error:
            return WidgetBrand.marigold
        case .noCalendarsSelected, .allDayOnly:
            return WidgetBrand.sandstone
        case .empty:
            return WidgetBrand.emerald
        case .active:
            return WidgetBrand.actionPrimary
        }
    }

    static func dayTint(_ day: TaskListWidgetCalendarDay) -> Color {
        day.eventCount > 0 ? WidgetBrand.actionPrimary : WidgetBrand.textTertiary
    }

    static func tint(for event: TaskListWidgetCalendarEvent) -> Color {
        guard let hex = event.calendarColorHex, let color = Color(taskWidgetHex: hex) else {
            return event.isBusy ? WidgetBrand.actionPrimary : WidgetBrand.textSecondary
        }
        return color
    }

    static func symbol(for event: TaskListWidgetCalendarEvent) -> String {
        if event.isCanceled {
            return "xmark.circle"
        }
        if event.isTentative {
            return "questionmark.circle"
        }
        if event.isAllDay {
            return "sun.max"
        }
        return event.isBusy ? "calendar.badge.clock" : "circle.dotted"
    }

    static func eventAccessibilityText(_ event: TaskListWidgetCalendarEvent) -> String {
        [event.title, eventTimeText(event), event.calendarTitle]
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
    }

    static func accessibilitySummary(
        calendar: TaskListWidgetCalendarSnapshot,
        isStale: Bool
    ) -> String {
        if isStale {
            return "Calendar schedule may be stale. Open Tasker to refresh."
        }
        if let nextMeeting = calendar.nextMeeting, calendar.status == .active {
            return "Calendar, \(dateText(calendar.date)), next up \(nextMeeting.event.title), \(nextMeetingDetail(nextMeeting, freeUntil: calendar.freeUntil))."
        }
        return "Calendar, \(dateText(calendar.date)), \(countText(calendar.eventsTodayCount))."
    }
}

private extension Color {
    init?(taskWidgetHex hex: String) {
        let value = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard value.count == 6, let intValue = Int(value, radix: 16) else {
            return nil
        }
        let red = Double((intValue >> 16) & 0xFF) / 255.0
        let green = Double((intValue >> 8) & 0xFF) / 255.0
        let blue = Double(intValue & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue)
    }
}
