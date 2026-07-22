import SwiftUI
import UIKit

private enum BacklogContextFilter: String, CaseIterable, Identifiable {
    case all = "All contexts"
    case work = "Work"
    case personal = "Personal"
    case neutral = "Neutral"
    var id: String { rawValue }
}

private enum BacklogReadinessFilter: String, CaseIterable, Identifiable {
    case all = "All readiness"
    case ready = "Ready"
    case blocked = "Blocked"
    case estimateMissing = "Estimate missing"
    case hasDeadline = "Has deadline"
    var id: String { rawValue }
}

private enum BacklogEnergyFilter: String, CaseIterable, Identifiable {
    case all = "All energy"
    case low = "Low energy"
    case medium = "Medium energy"
    case high = "High energy"
    case missing = "Energy missing"
    var id: String { rawValue }
}

private enum BacklogDurationFilter: String, CaseIterable, Identifiable {
    case all = "All durations"
    case quick = "15 minutes or less"
    case short = "30 minutes or less"
    case hour = "60 minutes or less"
    case long = "More than 60 minutes"
    case missing = "Estimate missing"
    var id: String { rawValue }
}

private enum BacklogProjectFilter: String, CaseIterable, Identifiable {
    case all = "All projects"
    case assigned = "Has project"
    case unassigned = "No project"
    var id: String { rawValue }
}

private enum PlanDayPresentation: String, CaseIterable, Identifiable {
    case canvas = "Timeline"
    case agenda = "Agenda"
    var id: String { rawValue }
}

struct LifeBoardPlanRootView: View {
    private let onOpenFocus: (UUID) -> Void
    private let onAskEva: () -> Void
    private let onOpenWeeklyPlanner: () -> Void
    private let onOpenWeeklyReview: () -> Void
    @State private var store: PlanStore
    @State private var lens: PlanLens = .day
    @State private var dayPresentation: PlanDayPresentation = .canvas
    @State private var showsBlockComposer = false
    @State private var showsWorkingHours = false
    @State private var selectedTaskIDs: Set<UUID> = []
    @State private var pendingBacklogDeletionTaskIDs: Set<UUID> = []
    @State private var showsBacklogDeletionConfirmation = false
    @FocusState private var focusedWeekTaskID: UUID?
    @State private var backlogSearch = ""
    @State private var backlogContextFilter: BacklogContextFilter = .all
    @State private var backlogReadinessFilter: BacklogReadinessFilter = .all
    @State private var backlogEnergyFilter: BacklogEnergyFilter = .all
    @State private var backlogDurationFilter: BacklogDurationFilter = .all
    @State private var backlogProjectFilter: BacklogProjectFilter = .all
    @Environment(LifeBoardPresentationPreferences.self) private var preferences
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(
        repository: CoreDataPlanningRepository,
        initialLens: PlanLens? = nil,
        onOpenFocus: @escaping (UUID) -> Void = { _ in },
        onAskEva: @escaping () -> Void = {},
        onOpenWeeklyPlanner: @escaping () -> Void = {},
        onOpenWeeklyReview: @escaping () -> Void = {}
    ) {
        _store = State(initialValue: PlanStore(planningRepository: repository, blockRepository: repository))
        _lens = State(initialValue: initialLens ?? PlanLensRestoration.load())
        self.onOpenFocus = onOpenFocus
        self.onAskEva = onAskEva
        self.onOpenWeeklyPlanner = onOpenWeeklyPlanner
        self.onOpenWeeklyReview = onOpenWeeklyReview
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea()
            LifeBoardScenicBackdrop(
                scene: .plan,
                daypart: preferences.resolvedDaypart(),
                requestedTier: preferences.renderingTier,
                comfortProfile: preferences.comfortProfile
            )
            .frame(height: 230)
            .clipped()
            .ignoresSafeArea(edges: .top)

            ScrollView {
                LazyVStack(spacing: 16) {
                    header
                    Picker("Plan lens", selection: $lens) {
                        ForEach(PlanLens.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("plan.lens")

                    switch lens {
                    case .day: dayContent
                    case .week: weekContent
                    case .backlog: backlogContent
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .refreshable { await store.load() }
        }
        .navigationTitle("Plan")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .onChange(of: lens) { _, selectedLens in
            PlanLensRestoration.save(selectedLens)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await store.load() }
        }
        .sheet(isPresented: $showsBlockComposer) {
            PlanBlockComposer(day: store.selectedDay) { title, start, duration in
                Task { await store.createBlock(title: title, start: start, duration: duration) }
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showsWorkingHours) {
            PlanWorkingHoursComposer(profile: store.workingProfile) { weekdays, start, end, buffer in
                Task { await store.saveWorkingHours(activeWeekdays: weekdays, startMinute: start, endMinute: end, bufferDuration: buffer) }
            }
        }
        .alert("Plan needs attention", isPresented: errorBinding) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
        .confirmationDialog(
            backlogDeletionTitle,
            isPresented: $showsBacklogDeletionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete from LifeBoard", role: .destructive) {
                let taskIDs = pendingBacklogDeletionTaskIDs
                pendingBacklogDeletionTaskIDs.removeAll()
                selectedTaskIDs.subtract(taskIDs)
                Task { await store.deleteBacklogTasks(taskIDs) }
            }
            Button("Cancel", role: .cancel) { pendingBacklogDeletionTaskIDs.removeAll() }
        } message: {
            Text("These items will disappear from Plan and linked-source pickers on every synced device. You can undo this planning change immediately; LifeBoard keeps a tombstone instead of physically destroying the canonical task.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Plan with room to breathe")
                        .font(LifeBoardFoundationTypography.screenTitle())
                        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                    Text(dayTitle(store.selectedDay))
                        .font(LifeBoardFoundationTypography.body())
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                Spacer()
                Button { Task { await store.select(day: PlanningDay(date: Date())) } } label: {
                    Image(systemName: "calendar.circle.fill").font(.title2)
                }
                .accessibilityLabel("Return to today")
                if store.lastMutationReceiptID != nil {
                    Button { Task { await store.undoLastMutation() } } label: {
                        Image(systemName: "arrow.uturn.backward.circle")
                    }
                    .accessibilityLabel("Undo last planning change")
                }
            }

            HStack(spacing: 14) {
                Button { Task { await store.moveSelection(by: -1) } } label: { Image(systemName: "chevron.left") }
                Spacer()
                Text(contextLine)
                    .font(LifeBoardFoundationTypography.metric())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                Spacer()
                Button { Task { await store.moveSelection(by: 1) } } label: { Image(systemName: "chevron.right") }
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 18)
        .frame(minHeight: 142, alignment: .bottom)
        .accessibilityIdentifier("plan.header")
    }

    @ViewBuilder private var dayContent: some View {
        if store.isLoading && store.daySnapshot == nil {
            LifeBoardStatusSurface(
                state: .loading,
                title: "Building your day",
                message: "Gathering commitments, blocks, and the next usable window."
            )
        } else if let errorMessage = store.errorMessage, store.daySnapshot == nil {
            LifeBoardStatusSurface(
                state: .recoverableError,
                title: "Your plan is still safe",
                message: errorMessage,
                actionTitle: "Try again",
                action: { Task { await store.load() } }
            )
        } else if let snapshot = store.daySnapshot {
            if let session = store.activeFocusSession { activeFocusCard(session) }
            capacityCard(snapshot.capacity)
            calendarState(snapshot)

            dayPresentationControl
            if effectiveDayPresentation == .canvas {
                PlanDayTimeCanvas(
                    snapshot: snapshot,
                    taskForID: store.task(for:),
                    createBlock: { title, start, duration, taskID in
                        Task { await store.createBlock(title: title, start: start, duration: duration, taskID: taskID) }
                    },
                    moveBlock: { block, minutes in Task { await store.moveBlock(block, minutesDelta: minutes) } },
                    resizeBlock: { block, minutes in Task { await store.resizeBlock(block, minutesDelta: minutes) } },
                    splitBlock: { block in Task { await store.splitBlock(block) } },
                    deleteBlock: { block in Task { await store.deleteBlock(block) } },
                    startFocus: { block in
                        Task {
                            await store.startFocus(taskID: block.taskID, timeBlockID: block.id, targetDuration: block.duration)
                            if let taskID = block.taskID { onOpenFocus(taskID) }
                        }
                    }
                )
            } else {
                if snapshot.freeWindows.isEmpty == false {
                    sectionHeader("Free windows", systemImage: "clock.badge.checkmark")
                    ScrollView(.horizontal) {
                        HStack(spacing: 10) {
                            ForEach(snapshot.freeWindows) { window in freeWindowButton(window) }
                        }
                    }
                    .scrollIndicators(.hidden)
                }

                if snapshot.commitments.isEmpty == false {
                    sectionHeader("Fixed commitments", systemImage: "calendar")
                    ForEach(snapshot.commitments) { commitmentCard($0) }
                }
                sectionHeader("Time blocks", systemImage: "rectangle.split.3x1", trailing: {
                    Button { showsBlockComposer = true } label: { Image(systemName: "plus") }
                        .accessibilityLabel("Add time block")
                })
                if snapshot.blocks.isEmpty {
                    emptyCard("No LifeBoard blocks yet", detail: "Add a calm focus window without changing your external calendar.", symbol: "calendar.badge.plus")
                } else {
                    ForEach(snapshot.blocks) { blockCard($0) }
                }
            }

            sectionHeader("Planned work", systemImage: "checklist")
            if snapshot.plannedTasks.isEmpty {
                emptyCard("This day is open", detail: "Choose work from the backlog when you are ready.", symbol: "sun.max")
            } else {
                ForEach(snapshot.plannedTasks) { taskCard($0, planned: true) }
            }

            sectionHeader("Unscheduled", systemImage: "tray")
            ForEach(snapshot.unscheduledTasks.prefix(8)) { taskCard($0, planned: false) }

            if !store.repairProposals.isEmpty {
                repairCard(store.repairProposals)
            }
        }
    }

    @ViewBuilder private var weekContent: some View {
        if let snapshot = store.weekSnapshot {
            weeklyOperatingLayerActions(snapshot)
            if horizontalSizeClass == .regular && dynamicTypeSize.isAccessibilitySize == false && voiceOverEnabled == false {
                ScrollView(.horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        ForEach(snapshot.days) { day in
                            weekDayCard(day)
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
                    ForEach(snapshot.days) { day in weekDayCard(day) }
                }
                .accessibilityIdentifier("plan.week.compactList")
            }
            if !snapshot.unplannedTasks.isEmpty {
                emptyCard("\(snapshot.unplannedTasks.count) items still need a day", detail: "Open Backlog to place them in the week.", symbol: "rectangle.stack.badge.plus")
            }
            let weekTasks = snapshot.days.flatMap { store.plannedTasks(on: $0.day) }
            if !weekTasks.isEmpty {
                sectionHeader("Redistribute work", systemImage: "arrow.left.arrow.right")
                ForEach(weekTasks) { task in weekTaskRow(task) }
            }
        }
    }

    private func weeklyOperatingLayerActions(_ snapshot: PlanWeekSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "calendar.badge.checkmark")
                    .font(.title2)
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                    .frame(width: 34)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shape the week")
                        .font(.headline)
                    Text("Set outcomes and a minimum viable week, then review unfinished work without losing this seven-day capacity view.")
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
            }
            HStack(spacing: 10) {
                Button("Plan the week", systemImage: "arrow.right.circle.fill", action: onOpenWeeklyPlanner)
                    .buttonStyle(.borderedProminent)
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

    @ViewBuilder private var backlogContent: some View {
        if let snapshot = store.backlogSnapshot {
            backlogControls
            if let undoState = store.backlogDeletionUndoState {
                backlogDeletionUndoBanner(undoState)
            }
            if !selectedTaskIDs.isEmpty { bulkActionBar }
            ForEach(BacklogGroup.allCases, id: \.self) { group in
                let values = filteredBacklogTasks(snapshot.groups[group] ?? [])
                if !values.isEmpty {
                    sectionHeader(backlogTitle(group), systemImage: backlogSymbol(group))
                    ForEach(values) { taskCard($0, planned: taskIsPlanned($0)) }
                }
            }
            if snapshot.groups.values.allSatisfy(\.isEmpty) {
                emptyCard("Backlog clear", detail: "Everything open has a home.", symbol: "checkmark.seal")
            }
        }
    }

    private func capacityCard(_ capacity: CapacityBudget) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(capacity.overloadDuration > 0 ? "Over capacity" : "Room in the day")
                        .font(.headline)
                    Text(loadLabel(capacity))
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                Spacer()
                Text(duration(capacity.usableDuration))
                    .font(.title3.weight(.semibold))
                    .accessibilityLabel("\(duration(capacity.usableDuration)) usable")
                Button { showsWorkingHours = true } label: { Image(systemName: "slider.horizontal.3") }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit working hours and buffer")
            }
            ProgressView(value: loadFraction(capacity)).tint(loadColor(capacity))
            HStack {
                Label("\(duration(capacity.plannedEstimatedDuration)) planned", systemImage: "checkmark.circle")
                Spacer()
                if capacity.isEstimateIncomplete {
                    Label("\(capacity.missingEstimateCount) estimates missing", systemImage: "questionmark.circle")
                } else {
                    Label("High confidence", systemImage: "checkmark.shield")
                }
            }
            .font(.caption)
            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.capacity")
    }

    private func activeFocusCard(_ session: FocusSessionV2) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(session.state == .paused ? "Focus paused" : "Focus in progress", systemImage: session.state == .paused ? "pause.circle.fill" : "timer")
                    .font(.headline)
                Spacer()
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    Text(duration(session.focusedDuration(at: context.date)))
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
            }
            ProgressView(value: min(1, session.focusedDuration() / max(1, session.targetDuration)))
                .tint(Color(LifeBoardColorTokens.foundationFocusRing))
            HStack {
                if session.state == .paused {
                    Button("Resume", systemImage: "play.fill") { Task { await store.resumeFocus() } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Pause", systemImage: "pause.fill") { Task { await store.pauseFocus() } }
                        .buttonStyle(.borderedProminent)
                }
                Menu("End", systemImage: "stop.fill") {
                    Button("Completed") { Task { await store.endFocus(outcome: .completed) } }
                    Button("Stopped") { Task { await store.endFocus(outcome: .stopped) } }
                    Button("Interrupted") { Task { await store.endFocus(outcome: .interrupted) } }
                    Button("Intentionally deferred") { Task { await store.endFocus(outcome: .intentionallyDeferred) } }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(18)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSelected), in: RoundedRectangle(cornerRadius: 20))
        .overlay { RoundedRectangle(cornerRadius: 20).stroke(Color(LifeBoardColorTokens.foundationFocusRing).opacity(0.25), lineWidth: 1) }
        .accessibilityIdentifier("plan.activeFocus")
    }

    @ViewBuilder
    private func calendarState(_ snapshot: PlanDaySnapshot) -> some View {
        switch snapshot.calendarAuthorization {
        case .notDetermined:
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.plus")
                VStack(alignment: .leading, spacing: 3) {
                    Text("See real openings").font(.headline)
                    Text("Calendar stays read-only. LifeBoard only uses it to calculate free windows.")
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                Spacer()
                Button("Allow") { Task { await store.requestCalendarAccess() } }
                    .buttonStyle(.bordered)
            }
            .foundationClayCard()
        case .denied, .restricted:
            Label("Calendar context is unavailable. Planning still works with LifeBoard blocks.", systemImage: "calendar.badge.exclamationmark")
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
        case .authorized, .unavailable:
            EmptyView()
        }
    }

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
                Text("\(time(window.startAt))–\(time(window.endAt))").font(.subheadline.weight(.semibold))
                Text("\(duration(window.duration)) open").font(.caption)
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

    private func commitmentCard(_ commitment: PlanningFixedCommitment) -> some View {
        HStack(spacing: 14) {
            Image(systemName: commitment.source == .externalCalendar ? "calendar" : "rectangle.inset.filled")
                .font(.title3).frame(width: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(commitment.title).font(.headline)
                Text("\(time(commitment.startAt))–\(time(commitment.endAt)) · read-only context")
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
                Text("\(time(block.startAt))–\(time(block.endAt)) · \(duration(block.duration))")
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
            Menu {
                Button("Start focus", systemImage: "timer") {
                    Task {
                        await store.startFocus(taskID: block.taskID, timeBlockID: block.id, targetDuration: block.duration)
                        if let taskID = block.taskID { onOpenFocus(taskID) }
                    }
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

    private func taskCard(_ task: PlanningTaskSummary, planned: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: task.dependenciesReady ? "circle" : "lock.circle")
                .foregroundStyle(
                    task.dependenciesReady
                        ? Color(LifeBoardColorTokens.inkTertiary)
                        : Color(LifeBoardColorTokens.foundationApricotAccent)
                )
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(task.title).font(.body.weight(.medium)).lineLimit(2)
                    if task.metadata.commitmentLevel == .mustDo {
                        Text("MUST DO").font(.caption2.weight(.bold)).padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.22), in: Capsule())
                    }
                }
                Text(taskMetadataLine(task))
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
            Menu {
                if lens == .backlog {
                    Button(selectedTaskIDs.contains(task.id) ? "Deselect" : "Select", systemImage: selectedTaskIDs.contains(task.id) ? "checkmark.circle.fill" : "circle") {
                        if selectedTaskIDs.contains(task.id) { selectedTaskIDs.remove(task.id) }
                        else { selectedTaskIDs.insert(task.id) }
                    }
                }
                Button(planned ? "Remove from day" : "Plan for this day", systemImage: "calendar") {
                    Task { await store.updateTask(task, planningDay: planned ? nil : store.selectedDay) }
                }
                Button(task.metadata.commitmentLevel == .mustDo ? "Make standard" : "Mark Must Do", systemImage: "exclamationmark.circle") {
                    Task { await store.updateTask(task, preserveDay: true, commitment: task.metadata.commitmentLevel == .mustDo ? .standard : .mustDo) }
                }
                Button("Waiting", systemImage: "hourglass") { Task { await store.updateTask(task, preserveDay: true, availability: .waiting) } }
                Button("Paused", systemImage: "pause.circle") { Task { await store.updateTask(task, preserveDay: true, availability: .paused) } }
                if task.metadata.unscheduledDisposition == .archived {
                    Button("Restore to inbox", systemImage: "tray.and.arrow.up") {
                        Task { await store.bulkUpdate([task.id], disposition: .inbox) }
                    }
                } else {
                    Button("Archive", systemImage: "archivebox") {
                        Task { await store.bulkUpdate([task.id], disposition: .archived) }
                    }
                }
                if lens == .backlog {
                    Divider()
                    Button("Delete from LifeBoard", systemImage: "trash", role: .destructive) {
                        pendingBacklogDeletionTaskIDs = [task.id]
                        showsBacklogDeletionConfirmation = true
                    }
                }
                Button("Start focus", systemImage: "timer") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    Task {
                        await store.startFocus(
                            taskID: task.id,
                            timeBlockID: nil,
                            targetDuration: task.estimatedDuration ?? 25 * 60
                        )
                        onOpenFocus(task.id)
                    }
                }
            } label: { Image(systemName: "ellipsis.circle") }
            .accessibilityLabel("Actions for \(task.title)")
        }
        .foundationClayCard()
        .draggable(task.id.uuidString)
        .accessibilityIdentifier("plan.task.\(task.id.uuidString)")
    }

    private func repairCard(_ proposals: [PlanRepairProposal]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Plan repair", systemImage: "wand.and.stars")
                .font(.headline)
            Text(proposals.first?.explanation ?? "Your day has changed. Choose what should move; nothing changes automatically.")
                .font(.subheadline).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            ScrollView(.horizontal) {
                HStack {
                    ForEach(Array((proposals.first?.actions ?? []).prefix(5)), id: \.self) { action in
                        Button(repairActionTitle(action), systemImage: repairActionSymbol(action)) {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            if action == .askEva {
                                onAskEva()
                            } else if let proposal = proposals.first {
                                Task { await store.applyRepair(proposal, action: action) }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.repair")
    }

    private func emptyCard(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            if symbol == "sun.max" {
                Image(decorative: "SunDayPlan")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .accessibilityHidden(true)
            } else {
                Image(systemName: symbol)
                    .font(.title2)
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
        }
        .foundationClayCard()
    }

    private func sectionHeader<Content: View>(_ title: String, systemImage: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack {
            Label(title, systemImage: systemImage).font(LifeBoardFoundationTypography.sectionTitle())
            Spacer()
            trailing()
        }
        .padding(.top, 6)
        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
    }

    private func sectionHeader(_ title: String, systemImage: String) -> some View {
        sectionHeader(title, systemImage: systemImage) { EmptyView() }
    }

    private var dayPresentationControl: some View {
        VStack(alignment: .leading, spacing: 7) {
            Picker("Day presentation", selection: $dayPresentation) {
                ForEach(PlanDayPresentation.allCases) { presentation in
                    Text(presentation.rawValue).tag(presentation)
                }
            }
            .pickerStyle(.segmented)
            .disabled(requiresAgendaPresentation)
            .accessibilityIdentifier("plan.day.presentation")
            if requiresAgendaPresentation {
                Text("Agenda is active for VoiceOver, accessibility text, or Reduce Motion so every time block remains linear and fully operable.")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
        }
    }

    private var requiresAgendaPresentation: Bool {
        voiceOverEnabled || dynamicTypeSize.isAccessibilitySize || reduceMotion
    }

    private var effectiveDayPresentation: PlanDayPresentation {
        requiresAgendaPresentation ? .agenda : dayPresentation
    }

    private var contextLine: String {
        guard let capacity = store.daySnapshot?.capacity else { return "Loading capacity…" }
        return capacity.overloadDuration > 0 ? "\(duration(capacity.overloadDuration)) overloaded" : "\(duration(capacity.remainingKnownCapacity)) known room"
    }

    private func taskIsPlanned(_ task: PlanningTaskSummary) -> Bool { task.metadata.planningDay != nil }
    private func loadFraction(_ value: CapacityBudget) -> Double { value.usableDuration > 0 ? min(1, value.plannedEstimatedDuration / value.usableDuration) : 0 }
    private func loadColor(_ value: CapacityBudget) -> Color {
        value.overloadDuration > 0
            ? Color(LifeBoardColorTokens.foundationApricotAccent)
            : Color(LifeBoardColorTokens.foundationFocusRing)
    }
    private func loadLabel(_ value: CapacityBudget) -> String {
        if value.overloadDuration > 0 { return "\(duration(value.overloadDuration)) over usable capacity" }
        return "\(duration(value.remainingKnownCapacity)) known capacity remains"
    }
    private func taskMetadataLine(_ task: PlanningTaskSummary) -> String {
        var values: [String] = [task.estimatedDuration.map(duration) ?? "Estimate incomplete"]
        if let due = task.dueDate { values.append("Due \(due.formatted(date: .abbreviated, time: .omitted))") }
        if task.metadata.availability != .actionable { values.append(task.metadata.availability.rawValue.capitalized) }
        if !task.dependenciesReady { values.append("Waiting on dependency") }
        return values.joined(separator: " · ")
    }
    private func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(0, Int((seconds / 60).rounded()))
        if minutes < 60 { return "\(minutes)m" }
        let hours = minutes / 60, remainder = minutes % 60
        return remainder == 0 ? "\(hours)h" : "\(hours)h \(remainder)m"
    }
    private func dayTitle(_ day: PlanningDay) -> String { day.startDate()?.formatted(.dateTime.weekday(.wide).month(.wide).day()) ?? "Selected day" }
    private func shortDayTitle(_ day: PlanningDay) -> String { day.startDate()?.formatted(.dateTime.weekday(.abbreviated).day()) ?? "Day" }
    private func time(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
    private func backlogTitle(_ group: BacklogGroup) -> String {
        switch group { case .thisWeek: "This Week"; case .nextWeek: "Next Week"; default: group.rawValue.capitalized }
    }
    private func backlogSymbol(_ group: BacklogGroup) -> String {
        switch group {
        case .inbox: "tray"; case .thisWeek: "calendar"; case .nextWeek: "calendar.badge.plus"
        case .later: "clock"; case .someday: "sparkles"; case .waiting: "hourglass"; case .paused: "pause.circle"; case .archived: "archivebox"
        }
    }

    private var backlogControls: some View {
        VStack(spacing: 10) {
            TextField("Search backlog", text: $backlogSearch)
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("plan.backlog.search")
            ScrollView(.horizontal) {
                HStack {
                Menu(backlogContextFilter.rawValue) {
                    Picker("Context", selection: $backlogContextFilter) {
                        ForEach(BacklogContextFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Menu(backlogReadinessFilter.rawValue) {
                    Picker("Readiness", selection: $backlogReadinessFilter) {
                        ForEach(BacklogReadinessFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Menu(backlogEnergyFilter.rawValue) {
                    Picker("Energy", selection: $backlogEnergyFilter) {
                        ForEach(BacklogEnergyFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Menu(backlogDurationFilter.rawValue) {
                    Picker("Duration", selection: $backlogDurationFilter) {
                        ForEach(BacklogDurationFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                Menu(backlogProjectFilter.rawValue) {
                    Picker("Project", selection: $backlogProjectFilter) {
                        ForEach(BacklogProjectFilter.allCases) { Text($0.rawValue).tag($0) }
                    }
                }
                if !selectedTaskIDs.isEmpty {
                    Button("Clear") { selectedTaskIDs.removeAll() }
                }
                }
            }
            .scrollIndicators(.hidden)
            .font(.subheadline)
        }
        .padding(12)
        .background(Color(LifeBoardColorTokens.foundationSurfaceRecessed), in: RoundedRectangle(cornerRadius: 14))
    }

    private var bulkActionBar: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("\(selectedTaskIDs.count) selected").font(.subheadline.weight(.semibold))
            ScrollView(.horizontal) {
                HStack {
                    Button("Plan today", systemImage: "calendar") {
                        Task { await store.bulkPlan(selectedTaskIDs, on: PlanningDay(date: Date())); selectedTaskIDs.removeAll() }
                    }
                    Button("Someday", systemImage: "sparkles") {
                        Task { await store.bulkUpdate(selectedTaskIDs, disposition: .someday); selectedTaskIDs.removeAll() }
                    }
                    Button("Waiting", systemImage: "hourglass") {
                        Task { await store.bulkUpdate(selectedTaskIDs, availability: .waiting); selectedTaskIDs.removeAll() }
                    }
                    Button("Paused", systemImage: "pause.circle") {
                        Task { await store.bulkUpdate(selectedTaskIDs, availability: .paused); selectedTaskIDs.removeAll() }
                    }
                    Button("Archive", systemImage: "archivebox") {
                        Task { await store.bulkUpdate(selectedTaskIDs, disposition: .archived); selectedTaskIDs.removeAll() }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        pendingBacklogDeletionTaskIDs = selectedTaskIDs
                        showsBacklogDeletionConfirmation = true
                    }
                    Menu("Context", systemImage: "person.2") {
                        ForEach(PlanningContext.allCases, id: \.self) { context in
                            Button(context.rawValue.capitalized) {
                                Task { await store.bulkUpdate(selectedTaskIDs, context: context); selectedTaskIDs.removeAll() }
                            }
                        }
                    }
                }
                .buttonStyle(.bordered)
            }
            .scrollIndicators(.hidden)
        }
        .padding(12)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSelected), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityIdentifier("plan.backlog.bulkActions")
    }

    private func backlogDeletionUndoBanner(_ state: BacklogDeletionUndoState) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "trash.slash.fill")
                .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
            VStack(alignment: .leading, spacing: 2) {
                Text("\(state.deletedCount) item\(state.deletedCount == 1 ? "" : "s") removed")
                    .font(.subheadline.weight(.semibold))
                Text("Deletion is synced as a reversible tombstone.")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
            Button("Undo") { Task { await store.undoLastMutation() } }
                .buttonStyle(.bordered)
                .accessibilityHint("Restores the deleted backlog items exactly as they were")
        }
        .foundationClayCard()
        .accessibilityIdentifier("plan.backlog.deletionUndo")
    }

    private var backlogDeletionTitle: String {
        let count = pendingBacklogDeletionTaskIDs.count
        return count == 1 ? "Delete this backlog item?" : "Delete \(count) backlog items?"
    }

    private func filteredBacklogTasks(_ values: [PlanningTaskSummary]) -> [PlanningTaskSummary] {
        values.filter { task in
            let matchesSearch = backlogSearch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || task.title.localizedCaseInsensitiveContains(backlogSearch)
            let matchesContext: Bool
            switch backlogContextFilter {
            case .all: matchesContext = true
            case .work: matchesContext = task.metadata.planningContext == .work
            case .personal: matchesContext = task.metadata.planningContext == .personal
            case .neutral: matchesContext = task.metadata.planningContext == .neutral
            }
            let matchesReadiness: Bool
            switch backlogReadinessFilter {
            case .all: matchesReadiness = true
            case .ready: matchesReadiness = task.dependenciesReady
            case .blocked: matchesReadiness = !task.dependenciesReady
            case .estimateMissing: matchesReadiness = task.estimatedDuration == nil
            case .hasDeadline: matchesReadiness = task.dueDate != nil
            }
            let matchesEnergy: Bool
            switch backlogEnergyFilter {
            case .all: matchesEnergy = true
            case .low: matchesEnergy = task.requiredEnergy.map { $0 <= 2 } ?? false
            case .medium: matchesEnergy = task.requiredEnergy == 3
            case .high: matchesEnergy = task.requiredEnergy.map { $0 >= 4 } ?? false
            case .missing: matchesEnergy = task.requiredEnergy == nil
            }
            let matchesDuration: Bool
            switch backlogDurationFilter {
            case .all: matchesDuration = true
            case .quick: matchesDuration = task.estimatedDuration.map { $0 <= 15 * 60 } ?? false
            case .short: matchesDuration = task.estimatedDuration.map { $0 <= 30 * 60 } ?? false
            case .hour: matchesDuration = task.estimatedDuration.map { $0 <= 60 * 60 } ?? false
            case .long: matchesDuration = task.estimatedDuration.map { $0 > 60 * 60 } ?? false
            case .missing: matchesDuration = task.estimatedDuration == nil
            }
            let matchesProject: Bool
            switch backlogProjectFilter {
            case .all: matchesProject = true
            case .assigned: matchesProject = task.projectID != nil
            case .unassigned: matchesProject = task.projectID == nil
            }
            return matchesSearch && matchesContext && matchesReadiness && matchesEnergy && matchesDuration && matchesProject
        }
    }

    private func weekDayCard(_ day: PlanWeekDaySummary) -> some View {
        Button {
            lens = .day
            Task { await store.select(day: day.day) }
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(shortDayTitle(day.day)).font(.headline)
                    Spacer()
                    if day.mustDoCount > 0 {
                        Label("\(day.mustDoCount)", systemImage: "exclamationmark.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                }
                ProgressView(value: loadFraction(day.capacity)).tint(loadColor(day.capacity))
                VStack(alignment: .leading, spacing: 3) {
                    Text(loadLabel(day.capacity)).lineLimit(2)
                    Text("\(day.deadlineCount) due")
                }
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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
        .accessibilityLabel("\(shortDayTitle(day.day)), \(loadLabel(day.capacity)), \(day.deadlineCount) due")
        .accessibilityHint("Open the day. Tasks can be dropped here to move them to this day.")
        .accessibilityIdentifier("plan.week.\(day.day.year)-\(day.day.month)-\(day.day.day)")
    }

    private func weekTaskRow(_ task: PlanningTaskSummary) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title).font(.body.weight(.medium))
                Text(task.metadata.planningDay.map(shortDayTitle) ?? "No day")
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
            Menu {
                Button("Move one day earlier", systemImage: "arrow.left") {
                    if let day = task.metadata.planningDay, let moved = shifted(day, by: -1) {
                        Task { await store.updateTask(task, planningDay: moved) }
                    }
                }
                Button("Move one day later", systemImage: "arrow.right") {
                    if let day = task.metadata.planningDay, let moved = shifted(day, by: 1) {
                        Task { await store.updateTask(task, planningDay: moved) }
                    }
                }
                Button("Remove from week", systemImage: "tray") {
                    Task { await store.updateTask(task, planningDay: nil) }
                }
            } label: { Image(systemName: "arrow.left.arrow.right.circle") }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .draggable(task.id.uuidString)
        .hoverEffect(.highlight)
        .focusable()
        .focused($focusedWeekTaskID, equals: task.id)
        .onKeyPress(.leftArrow) {
            moveWeekTask(task, by: -1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            moveWeekTask(task, by: 1)
            return .handled
        }
        .accessibilityIdentifier("plan.week.task.\(task.id.uuidString)")
    }

    private func moveWeekTask(_ task: PlanningTaskSummary, by offset: Int) {
        guard let day = task.metadata.planningDay, let moved = shifted(day, by: offset) else { return }
        Task { await store.updateTask(task, planningDay: moved) }
    }

    private func shifted(_ day: PlanningDay, by offset: Int) -> PlanningDay? {
        guard let date = day.startDate(), let moved = Calendar.current.date(byAdding: .day, value: offset, to: date) else { return nil }
        return PlanningDay(date: moved, timeZone: TimeZone(identifier: day.timeZoneIdentifier) ?? .current)
    }

    private func repairActionTitle(_ action: PlanRepairAction) -> String {
        switch action {
        case .resume: "Resume"
        case .moveLaterToday: "Later today"
        case .moveToAnotherDay: "Another day"
        case .split: "Split"
        case .defer: "Defer"
        case .leaveUnchanged: "Leave unchanged"
        case .askEva: "Ask Eva"
        }
    }

    private func repairActionSymbol(_ action: PlanRepairAction) -> String {
        switch action {
        case .resume: "play.fill"
        case .moveLaterToday: "clock.arrow.circlepath"
        case .moveToAnotherDay: "calendar.badge.plus"
        case .split: "rectangle.split.2x1"
        case .defer: "tray"
        case .leaveUnchanged: "minus.circle"
        case .askEva: "sparkles"
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil && store.daySnapshot != nil },
            set: { if $0 == false { store.errorMessage = nil } }
        )
    }
}

private struct PlanDayTimeCanvas: View {
    let snapshot: PlanDaySnapshot
    let taskForID: (UUID) -> PlanningTaskSummary?
    let createBlock: (String, Date, TimeInterval, UUID?) -> Void
    let moveBlock: (InternalTimeBlock, Int) -> Void
    let resizeBlock: (InternalTimeBlock, Int) -> Void
    let splitBlock: (InternalTimeBlock) -> Void
    let deleteBlock: (InternalTimeBlock) -> Void
    let startFocus: (InternalTimeBlock) -> Void

    private let hourHeight: CGFloat = 66
    private let rulerWidth: CGFloat = 52

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Label("Time canvas", systemImage: "clock")
                    .font(.headline)
                Spacer()
                if conflictCount > 0 {
                    Label("\(conflictCount) conflict\(conflictCount == 1 ? "" : "s")", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                        .accessibilityHint("Overlapping commitments and LifeBoard blocks are highlighted in the timeline")
                }
            }

            GeometryReader { proxy in
                ZStack(alignment: .topLeading) {
                    hourGrid(width: proxy.size.width)
                    freeWindowLayer(width: proxy.size.width)
                    commitmentLayer(width: proxy.size.width)
                    blockLayer(width: proxy.size.width)
                }
            }
            .frame(height: timelineHeight)
            .accessibilityIdentifier("plan.day.canvas")

            HStack(spacing: 14) {
                canvasLegend("Open", color: Color(LifeBoardColorTokens.foundationSageAccent).opacity(0.28))
                canvasLegend("Calendar", color: Color(LifeBoardColorTokens.foundationSurfaceRecessed))
                canvasLegend("LifeBoard", color: Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.62))
            }
            .font(.caption2)
            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
        }
        .foundationClayCard()
    }

    private func hourGrid(width: CGFloat) -> some View {
        ForEach(0...hourSpan, id: \.self) { offset in
            let hour = startHour + offset
            HStack(spacing: 8) {
                Text(hourLabel(hour))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                    .frame(width: rulerWidth - 8, alignment: .trailing)
                Rectangle()
                    .fill(Color(LifeBoardColorTokens.foundationHairline).opacity(offset % 2 == 0 ? 0.72 : 0.42))
                    .frame(width: max(0, width - rulerWidth), height: 1)
            }
            .offset(y: CGFloat(offset) * hourHeight)
        }
    }

    private func freeWindowLayer(width: CGFloat) -> some View {
        ForEach(snapshot.freeWindows) { window in
            Button {
                createBlock("Focus block", window.startAt, min(window.duration, 60 * 60), nil)
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Open · \(durationLabel(window.duration))")
                        .font(.caption.weight(.semibold))
                    if blockHeight(from: window.startAt, to: window.endAt) >= 46 {
                        Text("Drop a task or tap to reserve")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                .padding(.horizontal, 9)
                .frame(width: max(1, width - rulerWidth - 8), height: blockHeight(from: window.startAt, to: window.endAt), alignment: .topLeading)
                .background(Color(LifeBoardColorTokens.foundationSageAccent).opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color(LifeBoardColorTokens.foundationSageAccent).opacity(0.34), style: StrokeStyle(lineWidth: 1, dash: [5, 4])) }
            }
            .buttonStyle(.plain)
            .offset(x: rulerWidth, y: yPosition(window.startAt))
            .dropDestination(for: String.self) { values, _ in
                guard let id = values.lazy.compactMap(UUID.init(uuidString:)).first,
                      let task = taskForID(id), task.dependenciesReady else { return false }
                createBlock(task.title, window.startAt, min(window.duration, task.estimatedDuration ?? 60 * 60), task.id)
                return true
            } isTargeted: { _ in }
            .accessibilityLabel("Open window, \(timeLabel(window.startAt)) to \(timeLabel(window.endAt))")
            .accessibilityHint("Creates a focus block. A task can also be dropped here.")
            .accessibilityIdentifier("plan.canvas.freeWindow.\(window.id)")
        }
    }

    private func commitmentLayer(width: CGFloat) -> some View {
        ForEach(snapshot.commitments) { commitment in
            let conflict = conflicts(
                start: commitment.startAt,
                end: commitment.endAt,
                excludingCommitmentID: commitment.id,
                excludingBlockID: UUID(uuidString: commitment.id)
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: commitment.source == .externalCalendar ? "calendar" : "lock.fill")
                    Text(commitment.title).lineLimit(1)
                    if conflict { Image(systemName: "exclamationmark.triangle.fill") }
                }
                .font(.caption.weight(.semibold))
                Text("\(timeLabel(commitment.startAt))–\(timeLabel(commitment.endAt)) · read-only")
                    .font(.caption2).lineLimit(1)
            }
            .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
            .padding(.horizontal, 9)
            .frame(width: max(1, width - rulerWidth - 18), height: blockHeight(from: commitment.startAt, to: commitment.endAt), alignment: .topLeading)
            .background(
                conflict
                    ? Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.20)
                    : Color(LifeBoardColorTokens.foundationSurfaceRecessed),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1) }
            .offset(x: rulerWidth + 6, y: yPosition(commitment.startAt))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(commitment.title), \(timeLabel(commitment.startAt)) to \(timeLabel(commitment.endAt))\(conflict ? ", conflicts with another item" : "")")
        }
    }

    private func blockLayer(width: CGFloat) -> some View {
        ForEach(snapshot.blocks) { block in
            PlanCanvasBlock(
                block: block,
                width: max(1, width - rulerWidth - 30),
                height: blockHeight(from: block.startAt, to: block.endAt),
                hourHeight: hourHeight,
                hasConflict: conflicts(
                    start: block.startAt,
                    end: block.endAt,
                    excludingCommitmentID: block.id.uuidString,
                    excludingBlockID: block.id
                ),
                move: { moveBlock(block, $0) },
                resize: { resizeBlock(block, $0) },
                split: { splitBlock(block) },
                delete: { deleteBlock(block) },
                focus: { startFocus(block) }
            )
            .offset(x: rulerWidth + 18, y: yPosition(block.startAt))
        }
    }

    private var timelineStart: Date {
        let base = snapshot.day.startDate() ?? Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(bySettingHour: startHour, minute: 0, second: 0, of: base) ?? base
    }

    private var startHour: Int {
        let dates = snapshot.commitments.map(\.startAt) + snapshot.blocks.map(\.startAt) + snapshot.freeWindows.map(\.startAt)
        guard let first = dates.min() else { return 8 }
        return max(0, Calendar.current.component(.hour, from: first) - 1)
    }

    private var endHour: Int {
        let dates = snapshot.commitments.map(\.endAt) + snapshot.blocks.map(\.endAt) + snapshot.freeWindows.map(\.endAt)
        guard let last = dates.max() else { return 18 }
        let components = Calendar.current.dateComponents([.hour, .minute], from: last)
        return min(24, max(startHour + 4, (components.hour ?? 17) + ((components.minute ?? 0) > 0 ? 2 : 1)))
    }

    private var hourSpan: Int { max(4, endHour - startHour) }
    private var timelineHeight: CGFloat { CGFloat(hourSpan) * hourHeight + 1 }

    private func yPosition(_ date: Date) -> CGFloat {
        max(0, CGFloat(date.timeIntervalSince(timelineStart) / 3_600) * hourHeight)
    }

    private func blockHeight(from start: Date, to end: Date) -> CGFloat {
        max(30, CGFloat(max(0, end.timeIntervalSince(start)) / 3_600) * hourHeight - 3)
    }

    private var conflictCount: Int {
        let commitments = snapshot.commitments.filter {
            conflicts(start: $0.startAt, end: $0.endAt, excludingCommitmentID: $0.id, excludingBlockID: UUID(uuidString: $0.id))
        }.count
        let blocks = snapshot.blocks.filter {
            conflicts(start: $0.startAt, end: $0.endAt, excludingCommitmentID: $0.id.uuidString, excludingBlockID: $0.id)
        }.count
        return commitments + blocks
    }

    private func conflicts(start: Date, end: Date, excludingCommitmentID: String?, excludingBlockID: UUID?) -> Bool {
        let overlapsCommitment = snapshot.commitments.contains { value in
            value.id != excludingCommitmentID && value.startAt < end && value.endAt > start
        }
        let overlapsBlock = snapshot.blocks.contains { value in
            value.id != excludingBlockID && value.startAt < end && value.endAt > start
        }
        return overlapsCommitment || overlapsBlock
    }

    private func canvasLegend(_ title: String, color: Color) -> some View {
        Label {
            Text(title)
        } icon: {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 8)
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        guard hour < 24 else { return "12 AM" }
        let base = Calendar.current.startOfDay(for: Date())
        let date = Calendar.current.date(byAdding: .hour, value: hour, to: base) ?? base
        return date.formatted(date: .omitted, time: .shortened)
    }

    private func timeLabel(_ date: Date) -> String { date.formatted(date: .omitted, time: .shortened) }
    private func durationLabel(_ interval: TimeInterval) -> String {
        let minutes = max(0, Int((interval / 60).rounded()))
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h\(minutes % 60 == 0 ? "" : " \(minutes % 60)m")"
    }
}

private struct PlanCanvasBlock: View {
    let block: InternalTimeBlock
    let width: CGFloat
    let height: CGFloat
    let hourHeight: CGFloat
    let hasConflict: Bool
    let move: (Int) -> Void
    let resize: (Int) -> Void
    let split: () -> Void
    let delete: () -> Void
    let focus: () -> Void

    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: 7) {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(LifeBoardColorTokens.foundationApricotAccent))
                .frame(width: 5)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(block.title).lineLimit(1)
                    if hasConflict { Image(systemName: "exclamationmark.triangle.fill") }
                }
                .font(.caption.weight(.semibold))
                Text("\(block.startAt.formatted(date: .omitted, time: .shortened))–\(block.endAt.formatted(date: .omitted, time: .shortened))")
                    .font(.caption2).lineLimit(1)
            }
            Spacer(minLength: 2)
            Menu {
                Button("Start focus", systemImage: "timer", action: focus)
                Button("Move 15 minutes earlier", systemImage: "arrow.up") { move(-15) }
                Button("Move 15 minutes later", systemImage: "arrow.down") { move(15) }
                Button("Add 15 minutes", systemImage: "plus") { resize(15) }
                Button("Remove 15 minutes", systemImage: "minus") { resize(-15) }
                Button("Split", systemImage: "rectangle.split.2x1", action: split)
                Button("Remove", systemImage: "trash", role: .destructive, action: delete)
            } label: {
                Image(systemName: "ellipsis").frame(width: 30, height: 30)
            }
        }
        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
        .padding(.leading, 7)
        .padding(.trailing, 5)
        .frame(width: width, height: height, alignment: .topLeading)
        .background(
            hasConflict
                ? Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.34)
                : Color(LifeBoardColorTokens.foundationSurfaceSelected),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
        .overlay { RoundedRectangle(cornerRadius: 11).stroke(Color(LifeBoardColorTokens.foundationApricotAccent).opacity(0.48), lineWidth: 1) }
        .offset(y: dragOffset)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 7)
                .updating($dragOffset) { value, state, _ in state = value.translation.height }
                .onEnded { value in
                    let rawMinutes = Double(value.translation.height / hourHeight * 60)
                    let snapped = Int((rawMinutes / 15).rounded()) * 15
                    if snapped != 0 { move(snapped) }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(block.title), \(block.startAt.formatted(date: .omitted, time: .shortened)) to \(block.endAt.formatted(date: .omitted, time: .shortened))\(hasConflict ? ", conflicts with another item" : "")")
        .accessibilityAdjustableAction { direction in move(direction == .increment ? 15 : -15) }
        .accessibilityAction(named: "Add 15 minutes") { resize(15) }
        .accessibilityAction(named: "Remove 15 minutes") { resize(-15) }
        .accessibilityAction(named: "Start focus", focus)
        .accessibilityIdentifier("plan.canvas.block.\(block.id.uuidString)")
    }
}

private struct PlanBlockComposer: View {
    let day: PlanningDay
    let save: (String, Date, TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var start: Date
    @State private var minutes = 45.0

    init(day: PlanningDay, save: @escaping (String, Date, TimeInterval) -> Void) {
        self.day = day
        self.save = save
        let base = day.startDate() ?? Date()
        _start = State(initialValue: Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: base) ?? base)
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Block title", text: $title)
                DatePicker("Starts", selection: $start, displayedComponents: [.hourAndMinute])
                VStack(alignment: .leading) {
                    Text("Duration: \(Int(minutes)) minutes")
                    Slider(value: $minutes, in: 15...180, step: 15)
                }
            }
            .navigationTitle("New time block")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save(title, start, minutes * 60); dismiss() }
                }
            }
        }
    }
}

private struct PlanWorkingHoursComposer: View {
    let save: (Set<Int>, Int, Int, TimeInterval) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var activeWeekdays: Set<Int>
    @State private var start: Date
    @State private var end: Date
    @State private var bufferMinutes: Double

    init(profile: WorkingHoursProfile?, save: @escaping (Set<Int>, Int, Int, TimeInterval) -> Void) {
        self.save = save
        let intervals = profile?.intervalsByWeekday ?? [:]
        let first = intervals.values.flatMap { $0 }.first ?? WorkingHoursInterval(startMinute: 8 * 60, endMinute: 18 * 60)
        let base = Calendar.current.startOfDay(for: Date())
        _activeWeekdays = State(initialValue: Set(intervals.keys.isEmpty ? Array(2...6) : Array(intervals.keys)))
        _start = State(initialValue: Calendar.current.date(byAdding: .minute, value: first.startMinute, to: base) ?? base)
        _end = State(initialValue: Calendar.current.date(byAdding: .minute, value: first.endMinute, to: base) ?? base.addingTimeInterval(10 * 3_600))
        _bufferMinutes = State(initialValue: (profile?.bufferDuration ?? 30 * 60) / 60)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Working days") {
                    HStack {
                        ForEach(1...7, id: \.self) { weekday in
                            Button {
                                if activeWeekdays.contains(weekday) { activeWeekdays.remove(weekday) }
                                else { activeWeekdays.insert(weekday) }
                            } label: {
                                Text(weekdayLabel(weekday))
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .background(activeWeekdays.contains(weekday) ? Color(LifeBoardColorTokens.foundationSurfaceSelected) : .clear, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(activeWeekdays.contains(weekday) ? .isSelected : [])
                        }
                    }
                }
                Section("Daily window") {
                    DatePicker("Starts", selection: $start, displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: $end, displayedComponents: .hourAndMinute)
                }
                Section("Protected buffer") {
                    Text("\(Int(bufferMinutes)) minutes remains unallocated.")
                    Slider(value: $bufferMinutes, in: 0...180, step: 15)
                }
            }
            .navigationTitle("Working hours")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let startMinute = Calendar.current.component(.hour, from: start) * 60 + Calendar.current.component(.minute, from: start)
                        let endMinute = Calendar.current.component(.hour, from: end) * 60 + Calendar.current.component(.minute, from: end)
                        save(activeWeekdays, startMinute, endMinute, bufferMinutes * 60)
                        dismiss()
                    }
                    .disabled(activeWeekdays.isEmpty)
                }
            }
        }
    }

    private func weekdayLabel(_ weekday: Int) -> String {
        let symbols = Calendar.current.veryShortStandaloneWeekdaySymbols
        return symbols.indices.contains(weekday - 1) ? symbols[weekday - 1] : "\(weekday)"
    }
}

private extension View {
    func foundationClayCard() -> some View {
        self
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: LifeBoardFoundationRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: LifeBoardFoundationRadius.card, style: .continuous).stroke(Color(LifeBoardColorTokens.foundationHairline).opacity(0.72), lineWidth: 0.75))
            .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow), radius: 4, y: 2)
    }
}
