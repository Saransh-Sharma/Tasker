import SwiftUI
import LifeBoardDomain

/// One row of Home's "Up next": a calendar event, a planned block, or a timed
/// task, whichever the person will meet next.
struct HomeUpNextItem: Identifiable, Equatable {
    enum Kind: Equatable { case event, block, task }

    let id: String
    let title: String
    let startAt: Date
    let endAt: Date?
    let kind: Kind
    let isHappeningNow: Bool

    var symbol: String {
        switch kind {
        case .event: "calendar"
        case .block: "square.stack.3d.up"
        case .task: "checkmark.circle"
        }
    }

    /// The task behind a task row, so tapping it opens that task rather than
    /// the whole day. Blocks and calendar events have no single entity.
    var taskID: UUID? {
        guard kind == .task, id.hasPrefix("task:") else { return nil }
        return UUID(uuidString: String(id.dropFirst("task:".count)))
    }

    /// Everything still ahead today (or under way), soonest first. A block that
    /// carries a task and the task itself are one thing, so the task row is
    /// dropped; so are duplicates of the same title at the same minute, which is
    /// how an internal block reappears as a fixed commitment.
    static func build(
        commitments: [PlanningFixedCommitment],
        blocks: [InternalTimeBlock],
        plannedTasks: [PlanningTaskSummary],
        now: Date,
        calendar: Calendar = .current,
        limit: Int = 3
    ) -> [HomeUpNextItem] {
        var items: [HomeUpNextItem] = []
        var seen: Set<String> = []
        func key(_ title: String, _ start: Date) -> String {
            "\(title.lowercased())|\(Int(start.timeIntervalSince1970 / 60))"
        }
        func append(_ item: HomeUpNextItem) {
            guard calendar.isDate(item.startAt, inSameDayAs: now) || item.isHappeningNow else { return }
            guard seen.insert(key(item.title, item.startAt)).inserted else { return }
            items.append(item)
        }
        for event in commitments where event.endAt > now {
            append(.init(
                id: "event:\(event.id)", title: event.title, startAt: event.startAt, endAt: event.endAt,
                kind: event.source == .externalCalendar ? .event : .block,
                isHappeningNow: event.startAt <= now
            ))
        }
        let blockTaskIDs = Set(blocks.compactMap(\.taskID))
        for block in blocks where block.endAt > now {
            append(.init(
                id: "block:\(block.id.uuidString)", title: block.title, startAt: block.startAt, endAt: block.endAt,
                kind: .block, isHappeningNow: block.startAt <= now
            ))
        }
        var seenTaskIDs: Set<UUID> = []
        for task in plannedTasks where blockTaskIDs.contains(task.id) == false {
            guard seenTaskIDs.insert(task.id).inserted, let start = task.scheduledStartAt else { continue }
            let end = task.scheduledEndAt
            guard (end ?? start) > now else { continue }
            append(.init(
                id: "task:\(task.id.uuidString)", title: task.title, startAt: start, endAt: end,
                kind: .task, isHappeningNow: start <= now
            ))
        }
        return Array(items.sorted { $0.startAt < $1.startAt }.prefix(limit))
    }
}

/// "Up next" — what the person will meet next today, with times, and the one
/// recovery door (overdue work) that used to be reachable only by typing
/// "/overdue". It replaced "Day ahead", which never showed an event and whose
/// empty state sent people to Eva instead of letting them capture.
struct HomeTodayStorySection: View {
    let projectionAdapter: HomeProjectionCoordinator
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    var captureRouter: CaptureRouter? = nil
    let palette: DaypartPalette

    var body: some View {
        TimelineView(.everyMinute) { context in
            let items = Self.upNextItems(lifeOSStore: lifeOSStore, now: context.date)
            VStack(alignment: .leading, spacing: 12) {
                HomeSectionHeading(
                    "Up next",
                    state: items.isEmpty ? nil : "Today",
                    palette: palette
                )
                VStack(spacing: 0) {
                    if items.isEmpty {
                        HomeUpNextEmptyRow(
                            palette: palette,
                            hasTasksToday: lifeOSStore.taskAgenda.dueTasks.isEmpty == false
                        ) {
                            if let captureRouter {
                                captureRouter.request(kind: .task, source: .shell)
                            } else {
                                router.navigate(.planDay, in: .plan)
                            }
                        }
                    }
                    ForEach(items) { item in
                        HomeUpNextRow(item: item, now: context.date, palette: palette) {
                            // A task opens itself on Home's stack; a block or a
                            // calendar event only makes sense inside the day.
                            if let taskID = item.taskID {
                                router.navigate(.taskDetail(taskID), in: .home)
                            } else {
                                router.navigate(.planDay, in: .plan)
                            }
                        }
                        if item.id != items.last?.id {
                            Divider().padding(.leading, 70)
                        }
                    }

                }
                .padding(.horizontal, 16)
                .lifeBoardRaisedClayCard(palette: palette)
            }
        }
        .accessibilityIdentifier("home.todayStory")
    }

    /// Plan's day snapshot only counts tasks that carry a planning day, but a
    /// task given a time in the editor is on today's agenda without one — the
    /// same agenda "Today's tasks" reads. Both sources, deduplicated by ID.
    static func upNextItems(lifeOSStore: HomeLifeOSProjectionStore, now: Date) -> [HomeUpNextItem] {
        let snapshot = lifeOSStore.planSnapshot
        return HomeUpNextItem.build(
            commitments: snapshot?.commitments ?? [],
            blocks: snapshot?.blocks ?? [],
            plannedTasks: (snapshot?.plannedTasks ?? []) + lifeOSStore.taskAgenda.dueTasks,
            now: now
        )
    }
}

private struct HomeUpNextRow: View {
    /// Grows with Dynamic Type; a fixed 58 wrapped "10:30 AM" onto two or three
    /// lines at large sizes.
    @ScaledMetric(relativeTo: .caption) var timeColumnWidth: CGFloat = 58

    let item: HomeUpNextItem
    let now: Date
    let palette: DaypartPalette
    let onOpen: () -> Void

    private var timeText: String {
        item.isHappeningNow ? "Now" : item.startAt.formatted(date: .omitted, time: .shortened)
    }

    private var detailText: String {
        let kind = switch item.kind {
        case .event: String(localized: "Calendar")
        case .block: String(localized: "Time block")
        case .task: String(localized: "Task")
        }
        guard let end = item.endAt else { return kind }
        if item.isHappeningNow {
            let minutes = max(1, Int(end.timeIntervalSince(now) / 60))
            return String(localized: "\(kind) · \(minutes) min left")
        }
        let endText = end.formatted(date: .omitted, time: .shortened)
        return String(localized: "\(kind) · until \(endText)")
    }

    var body: some View {
        Button(action: onOpen) {
            HStack(alignment: .center, spacing: 12) {
                Text(timeText)
                    .lifeboardFont(.caption1)
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(item.isHappeningNow ? palette.color(for: .foreground) : palette.color(for: .foregroundSecondary))
                    .frame(width: timeColumnWidth, alignment: .leading)
                VStack(alignment: .leading, spacing: 4) {
                    Label(item.title, systemImage: item.symbol)
                        .lifeboardFont(.support)
                        .fontWeight(.semibold)
                        .lineLimit(2)
                    Text(detailText)
                        .lifeboardFont(.caption1)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .lifeboardFont(.caption1)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityHint(item.taskID == nil ? "Opens today in Plan" : "Opens the task")
    }
}

struct HomeUpNextRescueRow: View {
    /// Grows with Dynamic Type; a fixed 58 wrapped "10:30 AM" onto two or three
    /// lines at large sizes.
    @ScaledMetric(relativeTo: .caption) var timeColumnWidth: CGFloat = 58

    let count: Int
    let palette: DaypartPalette
    let onRescue: () -> Void

    var body: some View {
        Button(action: onRescue) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.uturn.forward.circle")
                    .lifeboardFont(.headline)
                    .frame(width: timeColumnWidth, alignment: .leading)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(count == 1 ? "1 task from earlier" : "\(count) tasks from earlier")
                        .lifeboardFont(.support)
                        .fontWeight(.semibold)
                    Text("Sort what’s left")
                        .lifeboardFont(.caption1)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
                Spacer(minLength: 8)
                Text("Rescue")
                    .lifeboardFont(.caption1)
                    .fontWeight(.semibold)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.upNext.rescue")
    }
}

private struct HomeUpNextEmptyRow: View {
    /// Grows with Dynamic Type; a fixed 58 wrapped "10:30 AM" onto two or three
    /// lines at large sizes.
    @ScaledMetric(relativeTo: .caption) var timeColumnWidth: CGFloat = 58

    let palette: DaypartPalette
    /// Today's task list sits right below; "nothing is scheduled" would read
    /// as a contradiction next to it, so the line talks about times instead.
    var hasTasksToday: Bool = false
    let onCapture: () -> Void

    var body: some View {
        Button(action: onCapture) {
            HStack(spacing: 12) {
                Image(systemName: "sun.max")
                    .lifeboardFont(.headline)
                    .frame(width: timeColumnWidth, alignment: .leading)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(hasTasksToday ? "Nothing else scheduled today" : "Nothing planned today")
                        .lifeboardFont(.support)
                        .fontWeight(.semibold)
                    Text("Add a task")
                        .lifeboardFont(.caption1)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
                Spacer(minLength: 8)
                Image(systemName: "plus.circle")
                    .lifeboardFont(.headline)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("home.upNext.empty")
    }
}

@MainActor
enum HomePlanningHandoff {
    static var pending: (PlanningDay, PlanningScenario)?
}

/// Whether Home's day is quiet enough to say so once.
///
/// "Up next" and "Today's tasks" used to render two large empty cards saying
/// nearly the same thing. When both are empty — and only once the agenda has
/// actually loaded, so a slow launch never hides a real task list — Home says
/// it in one line.
enum HomeQuietDay {
    static func isQuiet(upNextCount: Int, agendaTaskCount: Int, hasLoaded: Bool) -> Bool {
        hasLoaded && upNextCount == 0 && agendaTaskCount == 0
    }
}
