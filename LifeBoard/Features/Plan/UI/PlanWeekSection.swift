import SwiftUI
import UIKit

struct PlanWeekSection: View {
    let store: PlanStore
    @Binding var lens: PlanLens
    @FocusState.Binding var focusedWeekTaskID: UUID?
    let onOpenTask: (UUID) -> Void
    let onOpenWeeklyPlanner: () -> Void
    let onOpenWeeklyReview: () -> Void
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @State private var boardWidth: CGFloat = 0

    /// Seven 120-point columns and six 12-point gaps.
    private static let minimumFlexibleBoardWidth: CGFloat = 7 * 120 + 6 * 12
    /// Titles a day column shows before "+N more": enough to read the day's
    /// shape without letting one heavy day stretch the whole board.
    private static let columnTaskLimit = 5

    private var usesSevenDayBoard: Bool {
        horizontalSizeClass == .regular && dynamicTypeSize.isAccessibilitySize == false && voiceOverEnabled == false
    }

    /// True only when the seven flexible columns are on screen, since only
    /// they list each day's tasks. `boardWidth` is last measured while the
    /// board was mounted, so it is gated on the board being in use at all.
    private var showsTasksInColumns: Bool {
        usesSevenDayBoard && boardWidth >= Self.minimumFlexibleBoardWidth
    }

    var body: some View {
        // The parent's `LazyVStack(spacing: 16)` no longer applies to these
        // children once they live inside a struct, so the spacing is restated
        // here or the section silently tightens.
        VStack(spacing: 16) {
            if store.isLoading && store.weekSnapshot == nil {
                StatusSurface(
                    state: .loading,
                    title: String(localized: "Loading…"),
                    message: ""
                )
            } else if let errorMessage = store.errorMessage, store.weekSnapshot == nil {
                StatusSurface(
                    state: .recoverableError,
                    title: String(localized: "Couldn’t load week"),
                    message: errorMessage,
                    actionTitle: String(localized: "Try again"),
                    action: { Task { await store.load() } }
                )
            } else if let snapshot = store.weekSnapshot {
                operatingLayerActions(snapshot)
                if usesSevenDayBoard {
                    // Seven stable day columns that share the width they are
                    // given. A fixed 176 each needed 1300 points, so every iPad
                    // but a 13-inch in landscape scrolled the week sideways
                    // with the indicator hidden. Below 7 × 120 it still scrolls.
                    Group {
                        if showsTasksInColumns {
                            HStack(alignment: .top, spacing: 12) {
                                ForEach(snapshot.days) { day in
                                    // Each day's work sits in its own column,
                                    // so the week reads as a board and a task
                                    // moves by dragging it to another day.
                                    VStack(alignment: .leading, spacing: 8) {
                                        dayCard(day)
                                        dayColumnTasks(day)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .top)
                                }
                            }
                            .padding(.vertical, 4)
                        } else {
                            ScrollView(.horizontal) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(snapshot.days) { day in
                                        dayCard(day)
                                            .frame(width: 176)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                            .scrollIndicators(.automatic)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { boardWidth = $0 }
                    .accessibilityIdentifier("plan.week.sevenDayBoard")
                } else {
                    let columns = [GridItem(.adaptive(minimum: 220), spacing: 12)]
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(snapshot.days) { day in dayCard(day).lifeBoardScrollEntrance() }
                    }
                    .accessibilityIdentifier("plan.week.compactList")
                }
                if !snapshot.unplannedTasks.isEmpty {
                    let count = snapshot.unplannedTasks.count
                    PlanEmptyCard(
                        title: count == 1
                            ? String(localized: "1 task without a day")
                            : String(localized: "\(count) tasks without a day"),
                        detail: nil,
                        symbol: "rectangle.stack.badge.plus",
                        actionTitle: String(localized: "Open Backlog"),
                        actionIdentifier: "plan.week.openBacklog",
                        action: { lens = .backlog }
                    )
                }
                // The columns already list and move these tasks; a second copy
                // below would repeat the week. Narrower layouts keep the list,
                // since their day cards carry only the load summary.
                let weekTasks: [PlanningTaskSummary] = showsTasksInColumns ? [] : snapshot.days.flatMap { store.plannedTasks(on: $0.day) }
                if !weekTasks.isEmpty {
                    PlanSectionHeader("Planned tasks", systemImage: "arrow.left.arrow.right")
                    ForEach(weekTasks) { task in taskRow(task).lifeBoardScrollEntrance() }
                }
            }
        }
    }

    private func operatingLayerActions(_ snapshot: PlanWeekSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(Color(SemanticColorTokens.foundationApricotInk))
                    .frame(width: 34)
                Text("Plan your week")
                    .font(.headline)
            }
            HStack(spacing: 12) {
                Button("Plan week", systemImage: "arrow.right.circle.fill", action: onOpenWeeklyPlanner)
                    .buttonStyle(.lifeBoardPrimaryCompact)
                    .lifeBoardTransitionSource("route.weekly.week")
                    .accessibilityIdentifier("plan.week.openWorkspace")
                Button("Review week", systemImage: "checklist", action: onOpenWeeklyReview)
                    .buttonStyle(.lifeBoardChip)
            }
            .controlSize(.large)
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.week.operatingLayer")
    }

    private func dayCard(_ day: PlanWeekDaySummary) -> some View {
        Button {
            lens = .day
            Task { await store.select(day: day.day) }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(PlanSectionCopy.shortDayTitle(day.day)).font(.headline)
                    Spacer()
                    if day.mustDoCount > 0 {
                        Label("\(day.mustDoCount)", systemImage: "exclamationmark.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                }
                ProgressView(value: PlanSectionCopy.loadFraction(day.capacity))
                    .tint(PlanSectionCopy.loadColor(day.capacity))
                VStack(alignment: .leading, spacing: 4) {
                    Text(PlanSectionCopy.loadLabel(day.capacity)).lineLimit(2)
                    // A day with nothing due says nothing, rather than "0 due".
                    if day.deadlineCount > 0 {
                        Text("\(day.deadlineCount) due")
                    }
                }
                .font(.caption)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            .frame(maxWidth: .infinity, minHeight: 116, alignment: .topLeading)
            .foundationClayCard()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .dropDestination(for: String.self) { values, _ in
            moveDroppedTask(values, to: day)
        } isTargeted: { _ in }
        .accessibilityLabel(
            "\(PlanSectionCopy.shortDayTitle(day.day)), \(PlanSectionCopy.loadLabel(day.capacity))"
                + (day.deadlineCount > 0 ? ", \(day.deadlineCount) due" : "")
        )
        .accessibilityHint("Opens the day")
        .accessibilityIdentifier("plan.week.\(day.day.year)-\(day.day.month)-\(day.day.day)")
    }

    private func moveDroppedTask(_ values: [String], to day: PlanWeekDaySummary) -> Bool {
        guard let taskID = values.lazy.compactMap(UUID.init(uuidString:)).first,
              let task = store.task(for: taskID), task.dependenciesReady else { return false }
        Task { await store.updateTask(task, planningDay: day.day) }
        return true
    }

    /// The day's planned tasks under its card in the seven-column board. The
    /// titles sit outside the card's button so each one opens its own task
    /// rather than the day.
    @ViewBuilder
    private func dayColumnTasks(_ day: PlanWeekDaySummary) -> some View {
        let tasks = store.plannedTasks(on: day.day)
        if !tasks.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(tasks.prefix(Self.columnTaskLimit)) { task in
                    columnTaskButton(task)
                }
                if tasks.count > Self.columnTaskLimit {
                    // The overflow opens the day, where every task is listed;
                    // the separate week list is hidden while columns show.
                    Button {
                        lens = .day
                        Task { await store.select(day: day.day) }
                    } label: {
                        Text("+\(tasks.count - Self.columnTaskLimit) more")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .hoverEffect(.highlight)
                    .accessibilityHint("Opens the day")
                    .accessibilityIdentifier("plan.week.column.more.\(day.day.year)-\(day.day.month)-\(day.day.day)")
                }
            }
            .padding(.horizontal, 4)
            // Dropping onto a column's list moves the task as the card does,
            // so a long column is a target along its whole height.
            .dropDestination(for: String.self) { values, _ in
                moveDroppedTask(values, to: day)
            } isTargeted: { _ in }
        }
    }

    private func columnTaskButton(_ task: PlanningTaskSummary) -> some View {
        Button {
            onOpenTask(task.id)
        } label: {
            Text(task.title)
                .font(.caption)
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .hoverEffect(.highlight)
        .draggable(task.id.uuidString)
        // The hidden week list carried keyboard redistribution; the column
        // title keeps it so a hardware keyboard can still move work by a day.
        .focusable()
        .focused($focusedWeekTaskID, equals: task.id)
        .onKeyPress(.leftArrow) {
            moveTask(task, by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            moveTask(task, by: 1)
            return .handled
        }
        .accessibilityHint("Opens the task")
        .accessibilityIdentifier("plan.week.column.task.\(task.id.uuidString)")
        .lifeBoardTransitionSource("route.task.\(task.id.uuidString)")
    }

    private func taskRow(_ task: PlanningTaskSummary) -> some View {
        HStack(spacing: 12) {
            Button {
                onOpenTask(task.id)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    Text(task.title).font(.body.weight(.medium))
                    Text(task.metadata.planningDay.map(PlanSectionCopy.shortDayTitle) ?? "No day")
                        .font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("plan.week.task.\(task.id.uuidString)")
            .accessibilityHint("Opens the task")
            Menu {
                Button("1 day earlier", systemImage: "arrow.left") {
                    if let day = task.metadata.planningDay, let moved = PlanSectionCopy.shifted(day, by: -1) {
                        Task { await store.updateTask(task, planningDay: moved) }
                    }
                }
                Button("1 day later", systemImage: "arrow.right") {
                    if let day = task.metadata.planningDay, let moved = PlanSectionCopy.shifted(day, by: 1) {
                        Task { await store.updateTask(task, planningDay: moved) }
                    }
                }
                Button("Remove from week", systemImage: "tray") {
                    Task { await store.updateTask(task, planningDay: nil) }
                }
            } label: {
                Image(systemName: "arrow.left.arrow.right.circle")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Move \(task.title)")
            .accessibilityIdentifier("plan.weekTaskMenu.\(task.id.uuidString)")
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .draggable(task.id.uuidString)
        .hoverEffect(.highlight)
        .focusable()
        .focused($focusedWeekTaskID, equals: task.id)
        .onKeyPress(.leftArrow) {
            moveTask(task, by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            moveTask(task, by: 1)
            return .handled
        }
        .lifeBoardTransitionSource("route.task.\(task.id.uuidString)")
    }

    private func moveTask(_ task: PlanningTaskSummary, by offset: Int) {
        guard let day = task.metadata.planningDay,
              let moved = PlanSectionCopy.shifted(day, by: offset) else { return }
        Task { await store.updateTask(task, planningDay: moved) }
    }
}
