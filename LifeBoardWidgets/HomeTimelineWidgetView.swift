import SwiftUI
import WidgetKit

struct HomeTimelineWidgetView: View {
    let entry: TaskListEntry

    @Environment(\.widgetFamily) private var family

    var body: some View {
        Group {
            switch family {
            case .systemSmall:
                HomeTimelineSmallWidget(timeline: entry.snapshot.timeline, isStale: entry.snapshot.snapshotHealth.isStale)
            case .systemMedium:
                HomeTimelineMediumWidget(timeline: entry.snapshot.timeline, isStale: entry.snapshot.snapshotHealth.isStale)
            case .systemLarge:
                HomeTimelineLargeWidget(timeline: entry.snapshot.timeline, isStale: entry.snapshot.snapshotHealth.isStale)
            case .systemExtraLarge:
                HomeTimelineExtraLargeWidget(timeline: entry.snapshot.timeline, isStale: entry.snapshot.snapshotHealth.isStale)
            default:
                HomeTimelineMediumWidget(timeline: entry.snapshot.timeline, isStale: entry.snapshot.snapshotHealth.isStale)
            }
        }
        .widgetURL(TaskWidgetRoutes.today)
        .accessibilityElement(children: .contain)
    }
}

private struct HomeTimelineSmallWidget: View {
    let timeline: TaskListWidgetTimelineSnapshot
    let isStale: Bool

    var body: some View {
        HomeTimelineWidgetChrome {
            TaskWidgetScene { context in
                VStack(alignment: .leading, spacing: context.sectionSpacing) {
                    HomeTimelineWidgetHeader(timeline: timeline, detail: HomeTimelineFormatter.compactCountText(timeline))

                    if let item = timeline.primaryItem {
                        HomeTimelineHeroItem(item: item)
                    } else {
                        HomeTimelineEmptyState(timeline: timeline, isStale: isStale, compact: true)
                    }

                    Spacer(minLength: 0)
                    HomeTimelineStatusFooter(timeline: timeline, isStale: isStale)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .accessibilityLabel(HomeTimelineFormatter.accessibilitySummary(timeline: timeline, isStale: isStale))
    }
}

private struct HomeTimelineMediumWidget: View {
    let timeline: TaskListWidgetTimelineSnapshot
    let isStale: Bool

    var body: some View {
        HomeTimelineWidgetChrome {
            TaskWidgetScene { context in
                HStack(alignment: .top, spacing: context.sectionSpacing) {
                    VStack(alignment: .leading, spacing: context.sectionSpacing) {
                        HomeTimelineWidgetHeader(timeline: timeline, detail: HomeTimelineFormatter.compactCountText(timeline))
                        HomeTimelineWeekStrip(days: timeline.weekDays)
                        HomeTimelineStatusFooter(timeline: timeline, isStale: isStale)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    HomeTimelineItemStack(timeline: timeline, limit: 3, emptyCompact: true, isStale: isStale)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .accessibilityLabel(HomeTimelineFormatter.accessibilitySummary(timeline: timeline, isStale: isStale))
    }
}

private struct HomeTimelineLargeWidget: View {
    let timeline: TaskListWidgetTimelineSnapshot
    let isStale: Bool

    var body: some View {
        HomeTimelineWidgetChrome {
            TaskWidgetScene { context in
                VStack(alignment: .leading, spacing: context.sectionSpacing) {
                    HomeTimelineWidgetHeader(timeline: timeline, detail: HomeTimelineFormatter.compactCountText(timeline))
                    HomeTimelineAllDayStrip(items: timeline.day.allDayItems)
                    HomeTimelineItemStack(timeline: timeline, limit: 5, emptyCompact: false, isStale: isStale)
                    HomeTimelineGapPanel(gap: timeline.day.gaps.first)
                    Spacer(minLength: 0)
                    HomeTimelineStatusFooter(timeline: timeline, isStale: isStale)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        }
        .accessibilityLabel(HomeTimelineFormatter.accessibilitySummary(timeline: timeline, isStale: isStale))
    }
}

private struct HomeTimelineExtraLargeWidget: View {
    let timeline: TaskListWidgetTimelineSnapshot
    let isStale: Bool

    var body: some View {
        HomeTimelineWidgetChrome {
            TaskWidgetScene { context in
                HStack(alignment: .top, spacing: context.sectionSpacing + 2) {
                    VStack(alignment: .leading, spacing: context.sectionSpacing) {
                        HomeTimelineWidgetHeader(timeline: timeline, detail: HomeTimelineFormatter.compactCountText(timeline))
                        HomeTimelineAllDayStrip(items: timeline.day.allDayItems)
                        HomeTimelineItemStack(timeline: timeline, limit: 7, emptyCompact: false, isStale: isStale)
                        HomeTimelineGapPanel(gap: timeline.day.gaps.first)
                        Spacer(minLength: 0)
                        HomeTimelineStatusFooter(timeline: timeline, isStale: isStale)
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)

                    HomeTimelineWeekAgenda(days: timeline.weekDays)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .accessibilityLabel(HomeTimelineFormatter.accessibilitySummary(timeline: timeline, isStale: isStale))
    }
}

private struct HomeTimelineWidgetChrome<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            content()
            HomeTimelineAddTaskButton()
                .padding(8)
        }
    }
}

private struct HomeTimelineAddTaskButton: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        Link(destination: TaskWidgetRoutes.quickAdd) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: reduceTransparency ? [WidgetBrand.actionPrimary, WidgetBrand.actionPrimary] : [WidgetBrand.actionPrimary, WidgetBrand.violetDeep],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay {
                        Circle()
                            .stroke(WidgetBrand.glassBorder.opacity(0.58), lineWidth: 1)
                    }
                Image(systemName: "plus")
                    .font(TaskWidgetTypography.bodyStrong)
                    .foregroundStyle(WidgetBrand.textInverse)
                    .accessibilityHidden(true)
            }
            .frame(width: 44, height: 44)
            .shadow(color: WidgetBrand.floatingShadow.opacity(reduceTransparency ? 0.12 : 0.26), radius: reduceTransparency ? 4 : 10, x: 0, y: 5)
        }
        .accessibilityLabel("Add Task")
    }
}

private struct HomeTimelineWidgetHeader: View {
    let timeline: TaskListWidgetTimelineSnapshot
    let detail: String

    var body: some View {
        TaskWidgetSectionHeader(
            eyebrow: "Timeline",
            title: HomeTimelineFormatter.dateText(timeline.date),
            detail: detail,
            accent: WidgetBrand.textPrimary
        )
    }
}

private struct HomeTimelineHeroItem: View {
    let item: TaskListWidgetTimelineItem

    var body: some View {
        Link(destination: HomeTimelineFormatter.destination(for: item)) {
            TaskWidgetPanel(accent: HomeTimelineFormatter.tint(for: item), style: .accentWash, padding: 10) {
                Label {
                    Text(item.isCurrent ? "Now" : "Next")
                        .font(TaskWidgetTypography.eyebrow)
                        .foregroundStyle(WidgetBrand.textSecondary)
                } icon: {
                    Image(systemName: item.systemImageName)
                        .foregroundStyle(HomeTimelineFormatter.tint(for: item))
                        .widgetAccentable()
                }
                Text(item.title)
                    .font(TaskWidgetTypography.titleLarge)
                    .foregroundStyle(WidgetBrand.textPrimary)
                    .lineLimit(3)
                Text(HomeTimelineFormatter.itemDetailText(item))
                    .font(TaskWidgetTypography.support)
                    .foregroundStyle(WidgetBrand.textSecondary)
                    .lineLimit(2)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(HomeTimelineFormatter.itemAccessibilityText(item))
    }
}

private struct HomeTimelineItemStack: View {
    let timeline: TaskListWidgetTimelineSnapshot
    let limit: Int
    let emptyCompact: Bool
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            let items = timeline.displayItems(limit: limit)
            if items.isEmpty {
                HomeTimelineEmptyState(timeline: timeline, isStale: isStale, compact: emptyCompact)
            } else {
                ForEach(items) { item in
                    HomeTimelineItemRow(item: item)
                }
            }
        }
    }
}

private struct HomeTimelineItemRow: View {
    let item: TaskListWidgetTimelineItem

    var body: some View {
        let roleStyle = WidgetBrand.role(WidgetBrand.timelineRole(source: item.source))

        Link(destination: HomeTimelineFormatter.destination(for: item)) {
            HStack(alignment: .top, spacing: 8) {
                VStack(spacing: 3) {
                    Circle()
                        .fill(HomeTimelineFormatter.tint(for: item))
                        .frame(width: item.isCurrent ? 10 : 8, height: item.isCurrent ? 10 : 8)
                        .widgetAccentable()
                    Rectangle()
                        .fill(HomeTimelineFormatter.tint(for: item).opacity(0.35))
                        .frame(width: 2)
                }
                .frame(width: 12)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Image(systemName: item.systemImageName)
                            .font(TaskWidgetTypography.caption)
                            .foregroundStyle(HomeTimelineFormatter.tint(for: item))
                            .accessibilityHidden(true)
                        Text(item.title)
                            .font(item.isCurrent ? TaskWidgetTypography.bodyStrong : TaskWidgetTypography.body)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .lineLimit(1)
                    }
                    Text(HomeTimelineFormatter.itemDetailText(item))
                        .font(TaskWidgetTypography.caption)
                        .foregroundStyle(WidgetBrand.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 7)
            .background(roleStyle.soft.opacity(item.isCurrent ? 0.82 : 0.58), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(roleStyle.border.opacity(item.isCurrent ? 0.86 : 0.52), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(HomeTimelineFormatter.itemAccessibilityText(item))
    }
}

private struct HomeTimelineAllDayStrip: View {
    let items: [TaskListWidgetTimelineItem]

    var body: some View {
        if items.isEmpty == false {
            HStack(spacing: 6) {
                Label("All Day", systemImage: "sun.max")
                    .font(TaskWidgetTypography.captionStrong)
                    .foregroundStyle(WidgetBrand.sunriseGoldDeep)
                    .lineLimit(1)

                ForEach(Array(items.prefix(2))) { item in
                    Link(destination: HomeTimelineFormatter.destination(for: item)) {
                        Text(item.title)
                            .font(TaskWidgetTypography.caption)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .lineLimit(1)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(WidgetBrand.role(.routine).soft, in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(WidgetBrand.role(.routine).border.opacity(0.72), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }

                if items.count > 2 {
                    Text("+\(items.count - 2)")
                        .font(TaskWidgetTypography.captionStrong)
                        .foregroundStyle(WidgetBrand.textSecondary)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(items.count) all-day timeline item\(items.count == 1 ? "" : "s")")
        }
    }
}

private struct HomeTimelineGapPanel: View {
    let gap: TaskListWidgetTimelineGap?

    var body: some View {
        if let gap {
            TaskWidgetPanel(accent: WidgetBrand.role(.focus).base, style: .accentWash, padding: 9) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(gap.headline)
                            .font(TaskWidgetTypography.bodyStrong)
                            .foregroundStyle(WidgetBrand.textPrimary)
                            .lineLimit(1)
                        Text(gap.supportingText)
                            .font(TaskWidgetTypography.caption)
                            .foregroundStyle(WidgetBrand.textSecondary)
                            .lineLimit(2)
                    }
                } icon: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(WidgetBrand.role(.focus).base)
                        .widgetAccentable()
                }
                .accessibilityElement(children: .combine)
            }
        }
    }
}

private struct HomeTimelineWeekStrip: View {
    let days: [TaskListWidgetTimelineWeekDay]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(days) { day in
                VStack(spacing: 3) {
                    Text(HomeTimelineFormatter.weekdayText(day.date))
                        .font(TaskWidgetTypography.eyebrow)
                        .foregroundStyle(WidgetBrand.textSecondary)
                    Text("\(day.allDayCount + day.timedCount)")
                        .font(TaskWidgetTypography.captionStrong)
                        .foregroundStyle(HomeTimelineFormatter.tint(for: day))
                        .taskWidgetAccentable(if: day.allDayCount + day.timedCount > 0)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(WidgetBrand.glass.opacity(day.timedCount + day.allDayCount > 0 ? 0.86 : 0.42), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(WidgetBrand.glassBorder.opacity(day.timedCount + day.allDayCount > 0 ? 0.78 : 0.42), lineWidth: 1)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(HomeTimelineFormatter.fullDateText(day.date)), \(day.timedCount) timed, \(day.allDayCount) all-day")
            }
        }
    }
}

private struct HomeTimelineWeekAgenda: View {
    let days: [TaskListWidgetTimelineWeekDay]

    var body: some View {
        TaskWidgetPanel(style: .quiet, padding: 10) {
            TaskWidgetSectionHeader(eyebrow: "Week", title: "Timeline Load", detail: nil, accent: WidgetBrand.textPrimary)

            VStack(alignment: .leading, spacing: 7) {
                ForEach(days) { day in
                    HomeTimelineWeekAgendaDay(day: day)
                }
            }
        }
    }
}

private struct HomeTimelineWeekAgendaDay: View {
    let day: TaskListWidgetTimelineWeekDay

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(HomeTimelineFormatter.weekdayText(day.date))
                .font(TaskWidgetTypography.captionStrong)
                .foregroundStyle(HomeTimelineFormatter.tint(for: day))
                .frame(width: 32, alignment: .leading)
            Text(summary)
                .font(TaskWidgetTypography.caption)
                .foregroundStyle(day.timedCount + day.allDayCount > 0 ? WidgetBrand.textPrimary : WidgetBrand.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text("\(day.timedCount + day.allDayCount)")
                .font(TaskWidgetTypography.captionStrong)
                .foregroundStyle(WidgetBrand.textSecondary)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(HomeTimelineFormatter.fullDateText(day.date)), \(summary)")
    }

    private var summary: String {
        let total = day.timedCount + day.allDayCount
        guard total > 0 else { return "Clear" }
        let itemSuffix = total == 1 ? "item" : "items"
        switch day.loadLevel {
        case .light:
            return "\(total) light \(itemSuffix)"
        case .balanced:
            return "\(total) balanced \(itemSuffix)"
        case .busy:
            return "\(total) busy \(itemSuffix)"
        }
    }
}

private struct HomeTimelineStatusFooter: View {
    let timeline: TaskListWidgetTimelineSnapshot
    let isStale: Bool

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isStale ? "arrow.clockwise.circle" : "arrow.up.right")
                .font(TaskWidgetTypography.caption)
                .foregroundStyle(isStale ? WidgetBrand.sunriseGoldDeep : WidgetBrand.violet)
                .accessibilityHidden(true)
            Text(isStale ? "Refresh day" : "Open day")
                .font(TaskWidgetTypography.captionStrong)
                .foregroundStyle(WidgetBrand.textSecondary)
                .lineLimit(1)
            Spacer(minLength: 0)
            Text(HomeTimelineFormatter.anchorText(timeline))
                .font(TaskWidgetTypography.caption)
                .foregroundStyle(WidgetBrand.textTertiary)
                .lineLimit(1)
        }
    }
}

private struct HomeTimelineEmptyState: View {
    let timeline: TaskListWidgetTimelineSnapshot
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
            Image(systemName: isStale ? "arrow.clockwise.circle" : "calendar.badge.plus")
                .foregroundStyle(isStale ? WidgetBrand.sunriseGoldDeep : WidgetBrand.actionPrimary)
                .widgetAccentable()
        }
        .accessibilityElement(children: .combine)
    }

    private var title: String {
        if isStale {
            return "Timeline may be stale"
        }
        if timeline.day.inboxItems.isEmpty == false {
            return "Inbox ready"
        }
        return "Open timeline"
    }

    private var detail: String {
        if isStale {
            return "Open LifeBoard to refresh today's timeline."
        }
        if timeline.day.inboxItems.isEmpty == false {
            return "\(timeline.day.inboxItems.count) unscheduled task\(timeline.day.inboxItems.count == 1 ? "" : "s") to place."
        }
        return "No scheduled items yet. Add a task to give today a target."
    }
}

@MainActor
private enum HomeTimelineFormatter {
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

    static func compactCountText(_ timeline: TaskListWidgetTimelineSnapshot) -> String {
        let count = timeline.day.timedItems.count + timeline.day.allDayItems.count
        return "\(count) item\(count == 1 ? "" : "s")"
    }

    static func anchorText(_ timeline: TaskListWidgetTimelineSnapshot) -> String {
        "\(timeText(timeline.day.wakeAnchor))-\(timeText(timeline.day.sleepAnchor))"
    }

    static func itemDetailText(_ item: TaskListWidgetTimelineItem) -> String {
        var parts: [String] = []
        if item.isAllDay {
            parts.append("All day")
        } else if let start = item.startDate, let end = item.endDate {
            parts.append("\(timeText(start))-\(timeText(end))")
        } else if item.source == .task {
            parts.append("Inbox")
        }
        if let subtitle = item.subtitle, subtitle.isEmpty == false {
            parts.append(subtitle)
        }
        if let accessoryText = item.accessoryText, accessoryText.isEmpty == false {
            parts.append(accessoryText)
        }
        return parts.joined(separator: " • ")
    }

    static func itemAccessibilityText(_ item: TaskListWidgetTimelineItem) -> String {
        [item.title, itemDetailText(item)]
            .filter { $0.isEmpty == false }
            .joined(separator: ", ")
    }

    static func accessibilitySummary(
        timeline: TaskListWidgetTimelineSnapshot,
        isStale: Bool
    ) -> String {
        if isStale {
            return "Home timeline may be stale. Open LifeBoard to refresh."
        }
        if let primary = timeline.primaryItem {
            return "Home timeline, \(dateText(timeline.date)), \(primary.title), \(itemDetailText(primary))."
        }
        return "Home timeline, \(dateText(timeline.date)), \(compactCountText(timeline))."
    }

    static func destination(for item: TaskListWidgetTimelineItem) -> URL {
        if let taskID = item.taskID {
            return TaskWidgetRoutes.task(taskID)
        }
        if item.source == .calendarEvent {
            return TaskWidgetRoutes.calendarSchedule
        }
        return TaskWidgetRoutes.today
    }

    static func tint(for item: TaskListWidgetTimelineItem) -> Color {
        if let hex = item.tintHex, let color = Color(widgetHex: hex) {
            return color
        }
        return WidgetBrand.role(WidgetBrand.timelineRole(source: item.source)).base
    }

    static func tint(for day: TaskListWidgetTimelineWeekDay) -> Color {
        switch day.loadLevel {
        case .light:
            return day.timedCount + day.allDayCount > 0 ? WidgetBrand.leaf : WidgetBrand.textTertiary
        case .balanced:
            return WidgetBrand.sky
        case .busy:
            return WidgetBrand.sunriseGoldDeep
        }
    }
}

private extension TaskListWidgetTimelineSnapshot {
    var primaryItem: TaskListWidgetTimelineItem? {
        day.timedItems.first(where: \.isCurrent)
            ?? day.timedItems.first
            ?? day.allDayItems.first
            ?? day.inboxItems.first
    }

    func displayItems(limit: Int) -> [TaskListWidgetTimelineItem] {
        let prioritized = day.timedItems.filter(\.isCurrent) + day.timedItems.filter { !$0.isCurrent }
        let items = prioritized + day.allDayItems + day.inboxItems
        var seen = Set<String>()
        return Array(items.filter { seen.insert($0.id).inserted }.prefix(limit))
    }
}
