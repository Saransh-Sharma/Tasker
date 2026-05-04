import SwiftUI
import WidgetKit

@main
struct TaskerWatchWidgetBundle: WidgetBundle {
    var body: some Widget {
        WatchTimelineComplication()
        WatchMeetingScheduleComplication()
        WatchHabitStreakComplication()
    }
}

struct WatchSnapshotEntry: TimelineEntry {
    let date: Date
    let taskSnapshot: TaskListWidgetSnapshot
    let gamificationSnapshot: GamificationWidgetSnapshot
}

struct WatchSnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> WatchSnapshotEntry {
        WatchSnapshotEntry(
            date: Date(),
            taskSnapshot: .watchPreview,
            gamificationSnapshot: GamificationWidgetSnapshot(streakDays: 5, bestStreak: 9)
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (WatchSnapshotEntry) -> Void) {
        completion(entry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WatchSnapshotEntry>) -> Void) {
        let current = entry()
        let next = Calendar.current.date(byAdding: .minute, value: 20, to: current.date) ?? current.date.addingTimeInterval(20 * 60)
        completion(Timeline(entries: [current], policy: .after(next)))
    }

    private func entry() -> WatchSnapshotEntry {
        WatchSnapshotEntry(
            date: Date(),
            taskSnapshot: .load(),
            gamificationSnapshot: .load()
        )
    }
}

struct WatchTimelineComplication: Widget {
    let kind = "WatchTimelineComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchSnapshotProvider()) { entry in
            WatchTimelineComplicationView(entry: entry)
        }
        .configurationDisplayName("Tasker Timeline")
        .description("Current and next tasks or calendar events.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}

struct WatchMeetingScheduleComplication: Widget {
    let kind = "WatchMeetingScheduleComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchSnapshotProvider()) { entry in
            WatchMeetingScheduleComplicationView(entry: entry)
        }
        .configurationDisplayName("Tasker Meetings")
        .description("Next meeting, countdown, and clear-window status.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}

struct WatchHabitStreakComplication: Widget {
    let kind = "WatchHabitStreakComplication"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WatchSnapshotProvider()) { entry in
            WatchHabitStreakComplicationView(entry: entry)
        }
        .configurationDisplayName("Tasker Streak")
        .description("Primary habit streak and today status.")
        .supportedFamilies([.accessoryInline, .accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}

private struct WatchTimelineComplicationView: View {
    let entry: WatchSnapshotEntry

    @Environment(\.widgetFamily) private var family

    private var timeline: TaskListWidgetTimelineSnapshot { entry.taskSnapshot.timeline }
    private var primary: TaskListWidgetTimelineItem? { timeline.watchDisplayItems(limit: 1).first }
    private var secondary: TaskListWidgetTimelineItem? { timeline.watchDisplayItems(limit: 2).dropFirst().first }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label(inlineText, systemImage: primary?.systemImageName ?? "calendar")
            case .accessoryCircular:
                WatchAccessoryBackground {
                    VStack(spacing: 1) {
                        Image(systemName: primary?.systemImageName ?? "calendar")
                            .font(.caption)
                            .widgetAccentable()
                        Text(primary.map(WatchFormat.timeOrCount(_:)) ?? "\(timeline.watchDisplayItems(limit: 9).count)")
                            .font(.caption2.weight(.semibold))
                            .minimumScaleFactor(0.7)
                    }
                }
            case .accessoryCorner:
                Gauge(value: timeline.watchDayProgress(on: entry.date), in: 0...1) {
                    Image(systemName: primary?.systemImageName ?? "calendar")
                } currentValueLabel: {
                    Text(primary.map(WatchFormat.timeOrCount(_:)) ?? "Open")
                }
                .gaugeStyle(.accessoryCircular)
                .widgetLabel(primary?.title ?? "Timeline")
                .widgetURL(WatchRoutes.timeline)
            case .accessoryRectangular:
                WatchRectangularShell(title: primary?.isCurrent == true ? "Now" : "Next") {
                    WatchRectangularLine(
                        symbol: primary?.systemImageName ?? "calendar",
                        title: primary?.title ?? "Open timeline",
                        detail: primary.map(WatchFormat.itemDetail(_:)) ?? "No scheduled items"
                    )
                    if let secondary {
                        WatchRectangularLine(
                            symbol: secondary.systemImageName,
                            title: secondary.title,
                            detail: WatchFormat.itemDetail(secondary)
                        )
                    }
                }
            default:
                EmptyView()
            }
        }
        .widgetURL(WatchRoutes.timeline)
        .accessibilityLabel(accessibilityText)
    }

    private var inlineText: String {
        guard let primary else { return "Timeline clear" }
        return "\(primary.isCurrent ? "Now" : "Next") \(WatchFormat.shortItem(primary))"
    }

    private var accessibilityText: String {
        guard let primary else { return "Tasker timeline has no scheduled items." }
        return "Tasker timeline. \(primary.title). \(WatchFormat.itemDetail(primary))."
    }
}

private struct WatchMeetingScheduleComplicationView: View {
    let entry: WatchSnapshotEntry

    @Environment(\.widgetFamily) private var family

    private var calendar: TaskListWidgetCalendarSnapshot { entry.taskSnapshot.calendar }
    private var meeting: TaskListWidgetCalendarNextMeeting? { calendar.nextMeeting }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label(inlineText, systemImage: "calendar.badge.clock")
            case .accessoryCircular:
                WatchAccessoryBackground {
                    VStack(spacing: 1) {
                        Image(systemName: meeting == nil ? "checkmark.circle" : "calendar.badge.clock")
                            .font(.caption)
                            .widgetAccentable()
                        Text(circularText)
                            .font(.caption2.weight(.semibold))
                            .minimumScaleFactor(0.7)
                    }
                }
            case .accessoryCorner:
                Gauge(value: meetingProgress, in: 0...1) {
                    Image(systemName: "calendar.badge.clock")
                } currentValueLabel: {
                    Text(circularText)
                }
                .gaugeStyle(.accessoryCircular)
                .widgetLabel(meeting?.event.title ?? "Clear")
            case .accessoryRectangular:
                WatchRectangularShell(title: meeting?.isInProgress == true ? "Meeting Now" : "Next Meeting") {
                    if let meeting {
                        WatchRectangularLine(
                            symbol: "calendar.badge.clock",
                            title: meeting.event.title,
                            detail: WatchFormat.meetingDetail(meeting, freeUntil: calendar.freeUntil)
                        )
                        Text(meeting.event.calendarTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    } else {
                        WatchRectangularLine(
                            symbol: "checkmark.circle",
                            title: "No meetings",
                            detail: calendar.freeUntil.map { "Free until \(WatchFormat.time($0))" } ?? "Clear window"
                        )
                    }
                }
            default:
                EmptyView()
            }
        }
        .widgetURL(WatchRoutes.calendar)
        .accessibilityLabel(accessibilityText)
    }

    private var inlineText: String {
        guard let meeting else {
            if let freeUntil = calendar.freeUntil {
                return "Free until \(WatchFormat.time(freeUntil))"
            }
            return "No meetings"
        }
        return "\(meeting.isInProgress ? "Now" : WatchFormat.relativeMinutes(meeting.minutesUntilStart)) \(meeting.event.title)"
    }

    private var circularText: String {
        guard let meeting else { return "Clear" }
        return meeting.isInProgress ? "Now" : WatchFormat.relativeMinutes(meeting.minutesUntilStart)
    }

    private var meetingProgress: Double {
        guard let meeting else { return 1 }
        if meeting.isInProgress {
            let total = max(60, meeting.event.endDate.timeIntervalSince(meeting.event.startDate))
            let elapsed = max(0, entry.date.timeIntervalSince(meeting.event.startDate))
            return min(1, elapsed / total)
        }
        let minutes = max(0, meeting.minutesUntilStart)
        return max(0, min(1, 1 - Double(minutes) / 60.0))
    }

    private var accessibilityText: String {
        guard let meeting else { return "No upcoming meeting. \(inlineText)." }
        return "\(meeting.isInProgress ? "Current meeting" : "Next meeting") \(meeting.event.title). \(WatchFormat.meetingDetail(meeting, freeUntil: calendar.freeUntil))."
    }
}

private struct WatchHabitStreakComplicationView: View {
    let entry: WatchSnapshotEntry

    @Environment(\.widgetFamily) private var family

    private var habit: TaskListWidgetHabitSnapshot { entry.taskSnapshot.habit }
    private var primary: TaskListWidgetHabitPrimary? { habit.primaryHabit }

    var body: some View {
        Group {
            switch family {
            case .accessoryInline:
                Label(inlineText, systemImage: primary?.iconSymbolName ?? "flame")
            case .accessoryCircular:
                WatchAccessoryBackground {
                    Gauge(value: Double(primary?.currentStreak ?? entry.gamificationSnapshot.streakDays), in: 0...Double(max(primary?.bestStreak ?? entry.gamificationSnapshot.bestStreak, 1))) {
                        Image(systemName: primary?.iconSymbolName ?? "flame")
                    } currentValueLabel: {
                        Text("\(primary?.currentStreak ?? entry.gamificationSnapshot.streakDays)d")
                            .font(.caption2.weight(.semibold))
                            .minimumScaleFactor(0.65)
                    }
                    .gaugeStyle(.accessoryCircular)
                }
            case .accessoryCorner:
                Gauge(value: Double(primary?.currentStreak ?? entry.gamificationSnapshot.streakDays), in: 0...Double(max(primary?.bestStreak ?? entry.gamificationSnapshot.bestStreak, 1))) {
                    Image(systemName: primary?.iconSymbolName ?? "flame")
                } currentValueLabel: {
                    Text("\(primary?.currentStreak ?? entry.gamificationSnapshot.streakDays)d")
                }
                .gaugeStyle(.accessoryCircular)
                .widgetLabel(primary?.title ?? "Streak")
            case .accessoryRectangular:
                WatchRectangularShell(title: "Habit Streak") {
                    WatchRectangularLine(
                        symbol: primary?.iconSymbolName ?? "flame",
                        title: primary?.title ?? "No habit selected",
                        detail: rectangularDetail
                    )
                    WatchHabitWeekDots(days: primary?.week ?? [])
                }
            default:
                EmptyView()
            }
        }
        .widgetURL(primary.map { WatchRoutes.habit($0.habitID) } ?? WatchRoutes.habits)
        .accessibilityLabel(accessibilityText)
    }

    private var inlineText: String {
        if let primary {
            return "\(primary.title) \(primary.currentStreak)d"
        }
        let fallback = entry.gamificationSnapshot.streakDays
        return fallback > 0 ? "Streak \(fallback)d" : "Start a streak"
    }

    private var rectangularDetail: String {
        guard let primary else {
            return "Open Tasker to choose a habit"
        }
        let status = WatchFormat.habitStatus(primary.todayState)
        return "\(primary.currentStreak)d current, best \(primary.bestStreak)d. \(status)"
    }

    private var accessibilityText: String {
        guard let primary else { return "No primary habit for Tasker streak." }
        return "\(primary.title). Current streak \(primary.currentStreak) days. Best streak \(primary.bestStreak) days. \(WatchFormat.habitStatus(primary.todayState))."
    }
}

private struct WatchAccessoryBackground<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack {
            AccessoryWidgetBackground()
            content()
        }
        .containerBackground(.clear, for: .widget)
    }
}

private struct WatchRectangularShell<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            content()
        }
        .containerBackground(.clear, for: .widget)
    }
}

private struct WatchRectangularLine: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: symbol)
                .font(.caption2)
                .widgetAccentable()
                .frame(width: 12)
            VStack(alignment: .leading, spacing: 0) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct WatchHabitWeekDots: View {
    let days: [TaskListWidgetHabitDay]

    var body: some View {
        HStack(spacing: 3) {
            ForEach(days.prefix(7)) { day in
                Circle()
                    .fill(color(for: day.state))
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityHidden(true)
    }

    private func color(for state: TaskListWidgetHabitDayState) -> Color {
        switch state {
        case .success:
            return .green
        case .failure:
            return .red
        case .skipped:
            return .yellow
        case .none:
            return .secondary.opacity(0.35)
        case .future:
            return .secondary.opacity(0.18)
        }
    }
}

private enum WatchFormat {
    static func time(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    static func shortItem(_ item: TaskListWidgetTimelineItem) -> String {
        if let start = item.startDate {
            return "\(time(start)) \(item.title)"
        }
        return item.title
    }

    static func itemDetail(_ item: TaskListWidgetTimelineItem) -> String {
        if item.isAllDay { return "All day" }
        if let start = item.startDate, let end = item.endDate {
            return "\(time(start))-\(time(end))"
        }
        if let accessory = item.accessoryText, accessory.isEmpty == false {
            return accessory
        }
        return item.subtitle ?? "Tasker"
    }

    static func timeOrCount(_ item: TaskListWidgetTimelineItem) -> String {
        if item.isCurrent { return "Now" }
        if let start = item.startDate { return time(start) }
        return item.accessoryText ?? "Next"
    }

    static func relativeMinutes(_ minutes: Int) -> String {
        if minutes <= 0 { return "Now" }
        if minutes < 60 { return "\(minutes)m" }
        return "\(Int(ceil(Double(minutes) / 60.0)))h"
    }

    static func meetingDetail(_ meeting: TaskListWidgetCalendarNextMeeting, freeUntil: Date?) -> String {
        if meeting.isInProgress {
            return "Until \(time(meeting.event.endDate))"
        }
        return "\(relativeMinutes(meeting.minutesUntilStart)) at \(time(meeting.event.startDate))"
    }

    static func habitStatus(_ state: TaskListWidgetHabitTodayState) -> String {
        switch state {
        case .due:
            return "Due today"
        case .overdue:
            return "Overdue"
        case .completedToday:
            return "Done today"
        case .lapsedToday:
            return "Lapsed today"
        case .skippedToday:
            return "Skipped today"
        case .tracking:
            return "Tracking"
        case .empty:
            return "No habit"
        }
    }
}

private enum WatchRoutes {
    static let timeline = URL(string: "tasker://tasks/today")!
    static let calendar = URL(string: "tasker://calendar/schedule")!
    static let habits = URL(string: "tasker://habits")!

    static func habit(_ id: UUID) -> URL {
        URL(string: "tasker://habits/habit/\(id.uuidString)")!
    }
}

private extension TaskListWidgetTimelineSnapshot {
    func watchDisplayItems(limit: Int) -> [TaskListWidgetTimelineItem] {
        let active = day.timedItems.filter { $0.isCurrent }
        let upcoming = day.timedItems.filter { item in
            guard let start = item.startDate else { return item.isCurrent == false }
            return start >= day.currentTime || item.isCurrent
        }
        let fallback = day.inboxItems + day.allDayItems
        let merged = active + upcoming.filter { item in active.contains(where: { $0.id == item.id }) == false } + fallback
        return Array(merged.prefix(limit))
    }

    func watchDayProgress(on date: Date) -> Double {
        let start = day.wakeAnchor
        let end = max(day.sleepAnchor, start.addingTimeInterval(60))
        return min(1, max(0, date.timeIntervalSince(start) / end.timeIntervalSince(start)))
    }
}

private extension TaskListWidgetSnapshot {
    static var watchPreview: TaskListWidgetSnapshot {
        let now = Date()
        let meeting = TaskListWidgetCalendarEvent(
            id: "watch-preview-meeting",
            title: "Design review",
            calendarTitle: "Work",
            calendarColorHex: "#2F7CF6",
            startDate: now.addingTimeInterval(28 * 60),
            endDate: now.addingTimeInterval(58 * 60),
            isAllDay: false,
            isBusy: true
        )
        let item = TaskListWidgetTimelineItem(
            id: "watch-preview-item",
            source: .calendarEvent,
            eventID: meeting.id,
            title: meeting.title,
            subtitle: meeting.calendarTitle,
            startDate: meeting.startDate,
            endDate: meeting.endDate,
            tintHex: meeting.calendarColorHex,
            systemImageName: "calendar.badge.clock"
        )
        let habitID = UUID()
        return TaskListWidgetSnapshot(
            calendar: TaskListWidgetCalendarSnapshot(
                status: .active,
                date: now,
                selectedCalendarCount: 1,
                availableCalendarCount: 1,
                eventsTodayCount: 2,
                nextMeeting: TaskListWidgetCalendarNextMeeting(
                    event: meeting,
                    isInProgress: false,
                    minutesUntilStart: 28
                ),
                freeUntil: meeting.startDate,
                timedEvents: [meeting]
            ),
            timeline: TaskListWidgetTimelineSnapshot(
                date: now,
                day: TaskListWidgetTimelineDay(
                    date: now,
                    wakeAnchor: Calendar.current.startOfDay(for: now).addingTimeInterval(8 * 60 * 60),
                    sleepAnchor: Calendar.current.startOfDay(for: now).addingTimeInterval(22 * 60 * 60),
                    currentTime: now,
                    timedItems: [item]
                ),
                calendarPlottingEnabled: true
            ),
            habit: TaskListWidgetHabitSnapshot(
                date: now,
                updatedAt: now,
                primaryHabit: TaskListWidgetHabitPrimary(
                    habitID: habitID,
                    title: "Move 10 minutes",
                    iconSymbolName: "figure.walk",
                    currentStreak: 5,
                    bestStreak: 9,
                    todayState: .due,
                    week: (0..<7).map { offset in
                        let day = Calendar.current.date(byAdding: .day, value: offset - 6, to: now) ?? now
                        return TaskListWidgetHabitDay(
                            date: day,
                            dayKey: "\(offset)",
                            state: offset < 5 ? .success : .none
                        )
                    }
                ),
                dueCount: 1,
                completedTodayCount: 2,
                atRiskCount: 0
            )
        )
    }
}
