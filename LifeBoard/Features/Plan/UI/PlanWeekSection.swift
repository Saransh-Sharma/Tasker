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

    var body: some View {
        // The parent's `LazyVStack(spacing: 16)` no longer applies to these
        // children once they live inside a struct, so the spacing is restated
        // here or the section silently tightens.
        VStack(spacing: 16) {
            if let snapshot = store.weekSnapshot {
                operatingLayerActions(snapshot)
                if horizontalSizeClass == .regular && dynamicTypeSize.isAccessibilitySize == false && voiceOverEnabled == false {
                    ScrollView(.horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            ForEach(snapshot.days) { day in
                                dayCard(day)
                                    .frame(width: 176)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    .scrollIndicators(.hidden)
                    .accessibilityIdentifier("plan.week.sevenDayBoard")
                } else {
                    let columns = [GridItem(.adaptive(minimum: 220), spacing: 12)]
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(snapshot.days) { day in dayCard(day).lifeBoardScrollEntrance() }
                    }
                    .accessibilityIdentifier("plan.week.compactList")
                }
                if !snapshot.unplannedTasks.isEmpty {
                    PlanEmptyCard(
                        title: "\(snapshot.unplannedTasks.count) items still need a day",
                        detail: "Open Backlog to place them in the week.",
                        symbol: "rectangle.stack.badge.plus"
                    )
                }
                let weekTasks = snapshot.days.flatMap { store.plannedTasks(on: $0.day) }
                if !weekTasks.isEmpty {
                    PlanSectionHeader("Redistribute work", systemImage: "arrow.left.arrow.right")
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
                    .foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shape the week")
                        .font(.headline)
                    Text("Set outcomes and a minimum viable week, then review unfinished work without losing this seven-day capacity view.")
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
            }
            HStack(spacing: 10) {
                Button("Plan the week", systemImage: "arrow.right.circle.fill", action: onOpenWeeklyPlanner)
                    .buttonStyle(.borderedProminent)
                    .lifeBoardTransitionSource("route.weekly.week")
                    .accessibilityHint("Opens outcomes, triage, capacity, and minimum viable week planning")
                Button("Weekly review", systemImage: "checklist", action: onOpenWeeklyReview)
                    .buttonStyle(.bordered)
                    .accessibilityHint("Opens carry-forward decisions, outcomes, and reflection")
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
                VStack(alignment: .leading, spacing: 3) {
                    Text(PlanSectionCopy.loadLabel(day.capacity)).lineLimit(2)
                    Text("\(day.deadlineCount) due")
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
            guard let taskID = values.lazy.compactMap(UUID.init(uuidString:)).first,
                  let task = store.task(for: taskID), task.dependenciesReady else { return false }
            Task { await store.updateTask(task, planningDay: day.day) }
            return true
        } isTargeted: { _ in }
        .accessibilityLabel("\(PlanSectionCopy.shortDayTitle(day.day)), \(PlanSectionCopy.loadLabel(day.capacity)), \(day.deadlineCount) due")
        .accessibilityHint("Open the day. Tasks can be dropped here to move them to this day.")
        .accessibilityIdentifier("plan.week.\(day.day.year)-\(day.day.month)-\(day.day.day)")
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
                Button("Move one day earlier", systemImage: "arrow.left") {
                    if let day = task.metadata.planningDay, let moved = PlanSectionCopy.shifted(day, by: -1) {
                        Task { await store.updateTask(task, planningDay: moved) }
                    }
                }
                Button("Move one day later", systemImage: "arrow.right") {
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
