import SwiftUI
import UIKit

/// The agenda presentation of the day: free windows, "fits next" suggestions,
/// and the schedule itself either grouped by daypart or listed flat.
///
/// `PlanDayTimeCanvas` is the alternative presentation of the same data; the
/// root picks between them.
struct PlanScheduleSection: View {
    let store: PlanStore
    let snapshot: PlanDaySnapshot
    @Binding var scheduleGrouping: PlanScheduleGrouping
    @Binding var showsBlockComposer: Bool
    @Binding var pendingFocusSetup: FocusSetupContext?

    var body: some View {
        // Restated from the root's `LazyVStack(spacing: 16)`, which no longer
        // reaches these children now that they live behind a struct boundary.
        LazyVStack(spacing: 16) {
            if snapshot.freeWindows.isEmpty == false {
                PlanSectionHeader("Free windows", systemImage: "clock.badge.checkmark")
                ScrollView(.horizontal) {
                    HStack(spacing: 10) {
                        ForEach(snapshot.freeWindows) { window in freeWindowButton(window) }
                    }
                }
                .scrollIndicators(.hidden)
            }
            fitsNextSurface

            if scheduleGrouping == .timeOfDay {
                daypartGroupedSchedule
            } else {
                if snapshot.commitments.isEmpty == false {
                    PlanSectionHeader("Fixed commitments", systemImage: "calendar")
                    ForEach(snapshot.commitments) { commitmentCard($0) }
                }
                PlanSectionHeader(
                    title: "Time blocks",
                    systemImage: "rectangle.split.3x1",
                    trailing: { sectionTrailing }
                )
                if snapshot.blocks.isEmpty {
                    PlanEmptyCard(
                        title: "No LifeBoard blocks yet",
                        detail: "Add a calm focus window without changing your external calendar.",
                        symbol: "calendar.badge.plus"
                    )
                } else {
                    ForEach(snapshot.blocks) { blockCard($0) }
                }
            }
        }
    }

    // MARK: - Daypart-grouped schedule (agenda)

    /// The commitments + blocks merged and chronologically ordered.
    private var scheduledEntries: [PlanScheduledEntry] {
        let entries = snapshot.commitments.map(PlanScheduledEntry.commitment)
            + snapshot.blocks.map(PlanScheduledEntry.block)
        return entries.sorted { $0.startAt < $1.startAt }
    }

    @ViewBuilder
    private var daypartGroupedSchedule: some View {
        let entries = scheduledEntries
        PlanSectionHeader(
            title: "Schedule",
            systemImage: "calendar.day.timeline.left",
            trailing: { sectionTrailing }
        )
        if entries.isEmpty {
            PlanEmptyCard(
                title: "Nothing scheduled yet",
                detail: "Add a calm focus window or let a commitment sync in — your day stays open until then.",
                symbol: "calendar.badge.plus"
            )
        } else {
            ForEach(PlanScheduleDaypart.allCases) { daypart in
                let items = entries.filter { PlanScheduleDaypart.daypart(for: $0.startAt) == daypart }
                if items.isEmpty == false {
                    daypartSubheader(daypart, count: items.count)
                    ForEach(items) {
                        scheduledEntryCard($0)
                            .lifeBoardScrollEntrance()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func scheduledEntryCard(_ entry: PlanScheduledEntry) -> some View {
        switch entry {
        case .commitment(let commitment): commitmentCard(commitment)
        case .block(let block): blockCard(block)
        }
    }

    private func daypartSubheader(_ daypart: PlanScheduleDaypart, count: Int) -> some View {
        HStack(spacing: 7) {
            Image(systemName: daypart.symbolName)
                .font(.caption.weight(.semibold))
            Text(daypart.title)
                .font(.caption.weight(.semibold))
            Text("\(count)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.14), in: Capsule())
            Spacer(minLength: 0)
        }
        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
        .padding(.top, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(daypart.title), \(count) scheduled")
    }

    /// Group-by menu plus the add-block button for the schedule section header.
    private var sectionTrailing: some View {
        HStack(spacing: 12) {
            Menu {
                Picker("Group schedule by", selection: $scheduleGrouping) {
                    ForEach(PlanScheduleGrouping.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(scheduleGrouping.rawValue).font(.caption.weight(.medium))
                }
            }
            .accessibilityLabel("Group schedule by")
            .accessibilityValue(scheduleGrouping.rawValue)

            Button { showsBlockComposer = true } label: {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
                .buttonStyle(.borderless)
                .accessibilityLabel("Add time block")
                .accessibilityIdentifier("plan.day.addBlock")
        }
    }

    // MARK: - Cards

    @ViewBuilder
    private func freeWindowButton(_ window: FreeWindow) -> some View {
        Button {
            Task {
                await store.createBlock(
                    title: "Focus block",
                    start: window.startAt,
                    duration: min(window.duration, 60 * 60)
                )
            }
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(PlanSectionCopy.time(window.startAt))–\(PlanSectionCopy.time(window.endAt))")
                    .font(.subheadline.weight(.semibold))
                Text("\(PlanSectionCopy.duration(window.duration)) open").font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Color(LifeBoardColorTokens.foundationSurfaceRecessed), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityHint("Creates a one-hour LifeBoard block, or uses the full opening when shorter")
        .dropDestination(for: String.self) { values, _ in
            guard let taskID = values.lazy.compactMap({ UUID(uuidString: $0) }).first,
                  let task = store.task(for: taskID), task.dependenciesReady else { return false }
            Task {
                await store.createBlock(
                    title: task.title,
                    start: window.startAt,
                    duration: min(window.duration, task.estimatedDuration ?? 60 * 60),
                    taskID: task.id
                )
            }
            return true
        } isTargeted: { _ in }
    }

    @ViewBuilder
    private var fitsNextSurface: some View {
        if snapshot.fitsNextCandidates.isEmpty == false {
            PlanSectionHeader("Fits next", systemImage: "sparkles.rectangle.stack")
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(snapshot.fitsNextCandidates.prefix(12)) { candidate in
                        Button {
                            Task {
                                await store.createBlock(
                                    title: candidate.taskTitle,
                                    start: candidate.window.startAt,
                                    duration: candidate.estimate,
                                    taskID: candidate.taskID
                                )
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(candidate.taskTitle)
                                    .font(.subheadline.weight(.semibold))
                                    .lineLimit(1)
                                Text(
                                    "\(PlanSectionCopy.duration(candidate.estimate)) · "
                                        + "\(PlanSectionCopy.time(candidate.window.startAt))–"
                                        + "\(PlanSectionCopy.time(candidate.window.endAt))"
                                )
                                .font(.caption)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)
                            .frame(minHeight: 52)
                            .background(
                                Color(LifeBoardColorTokens.foundationSageAccent).opacity(0.14),
                                in: RoundedRectangle(cornerRadius: 13, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(
                            "Schedules this task into the displayed free window"
                        )
                        .accessibilityIdentifier(
                            "plan.fitsNext.\(candidate.taskID.uuidString)"
                        )
                    }
                }
            }
            .scrollIndicators(.hidden)
            .accessibilityIdentifier("plan.fitsNext")
        }
    }

    private func commitmentCard(_ commitment: PlanningFixedCommitment) -> some View {
        HStack(spacing: 14) {
            Image(systemName: commitment.source == .externalCalendar ? "calendar" : "rectangle.inset.filled")
                .font(.title3).frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(commitment.title).font(.headline)
                Text("\(PlanSectionCopy.time(commitment.startAt))–\(PlanSectionCopy.time(commitment.endAt)) · read-only context")
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.nextCommitment")
    }

    private func blockCard(_ block: InternalTimeBlock) -> some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4).fill(Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.72)).frame(width: 6)
            VStack(alignment: .leading, spacing: 4) {
                Text(block.title).font(.headline)
                Text("\(PlanSectionCopy.time(block.startAt))–\(PlanSectionCopy.time(block.endAt)) · \(PlanSectionCopy.duration(block.duration))")
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
            Menu {
                Button("Start focus", systemImage: "timer") {
                    pendingFocusSetup = .init(
                        taskID: block.taskID,
                        timeBlockID: block.id,
                        title: block.title,
                        suggestedDuration: block.duration,
                        subtaskID: nil
                    )
                }
                Button("Add 15 minutes", systemImage: "plus") { Task { await store.resizeBlock(block, minutesDelta: 15) } }
                Button("Remove 15 minutes", systemImage: "minus") { Task { await store.resizeBlock(block, minutesDelta: -15) } }
                Button("Move 15 minutes earlier", systemImage: "arrow.up") { Task { await store.moveBlock(block, minutesDelta: -15) } }
                Button("Move 15 minutes later", systemImage: "arrow.down") { Task { await store.moveBlock(block, minutesDelta: 15) } }
                Button("Split block", systemImage: "rectangle.split.2x1") { Task { await store.splitBlock(block) } }
                Button("Remove", systemImage: "trash", role: .destructive) { Task { await store.deleteBlock(block) } }
            } label: { Image(systemName: "ellipsis.circle") }
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.block.\(block.id.uuidString)")
    }
}
