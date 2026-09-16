import SwiftUI
import UIKit

/// The `day` lens of `PlanRootView`.
///
/// Composed of one decision card, a presentation control, either the canvas or
/// the agenda, and the planned/unscheduled lists. Every piece of state stays
/// owned by the root and arrives as a `@Binding`, so switching lenses does not
/// reset it.
struct PlanDaySection: View {
    let store: PlanStore
    let lens: PlanLens
    @Binding var dayPresentation: PlanDayPresentation
    @Binding var scheduleGrouping: PlanScheduleGrouping
    @Binding var showsBlockComposer: Bool
    @Binding var showsWorkingHours: Bool
    @Binding var selectedTaskIDs: Set<UUID>
    @Binding var pendingBacklogDeletionTaskIDs: Set<UUID>
    @Binding var showsBacklogDeletionConfirmation: Bool
    @Binding var pendingFocusSetup: FocusSetupContext?
    @Binding var pendingFocusEndOutcome: FocusCompletionOutcome?
    @Binding var focusReflectionEnergy: Int
    @Binding var focusReflectionNote: String
    let onAskEva: () -> Void
    let onMakeItFit: () -> Void
    let onOpenTask: (UUID) -> Void
    let onOpenOverdueRescue: (OverdueRescueLaunchContext) -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // Restated from the root's `LazyVStack(spacing: 16)`; see the `-Onone`
        // note at the foot of `PlanRootView.swift` for why these
        // children live behind a struct at all.
        VStack(spacing: 12) {
            if store.isLoading && store.daySnapshot == nil {
                StatusSurface(
                    state: .loading,
                    title: "Building your day",
                    message: "Gathering commitments, blocks, and the next usable window."
                )
            } else if let errorMessage = store.errorMessage, store.daySnapshot == nil {
                StatusSurface(
                    state: .recoverableError,
                    title: "Your plan is still safe",
                    message: errorMessage,
                    actionTitle: "Try again",
                    action: { Task { await store.load() } }
                )
            } else if let snapshot = store.daySnapshot {
                if effectiveDayPresentation == .canvas {
                    decisionLine(snapshot)
                        // The line folds away (or changes) as its decision is made,
                        // instead of vanishing between two frames.
                        .animation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion), value: PlanRescuePool.count(store.tasks))
                        .onChange(of: PlanRescuePool.count(store.tasks)) { previous, current in
                            if previous > 0, current == 0 {
                                AccessibilityNotification.Announcement("Today has what it needs").post()
                            }
                        }
                } else {
                    decisionSlot(snapshot)
                    PlanCalendarStateSection(store: store, snapshot: snapshot)
                }

                if requiresAgendaPresentation {
                    Text("Agenda keeps every block linear and operable.")
                        .lifeboardFont(.caption1)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                if effectiveDayPresentation == .canvas {
                    // The drawer floats over the canvas's lower edge rather than
                    // sitting under it, so opening it never reflows the day.
                    if anytimeToday(snapshot).isEmpty == false {
                        PlanAnytimeRow(tasks: anytimeToday(snapshot), onOpenTask: onOpenTask)
                    }
                    ZStack(alignment: .bottom) {
                        VStack(spacing: 0) {
                            PlanDayTimeCanvas(
                                snapshot: snapshot,
                                taskForID: store.task(for:),
                                createBlock: { title, start, duration, taskID in
                                    Task { await store.createBlock(title: title, start: start, duration: duration, taskID: taskID) }
                                },
                                moveBlock: { block, minutes in Task { await store.moveBlock(block, minutesDelta: minutes) } },
                                resizeBlock: { block, minutes in Task { await store.resizeBlock(block, minutesDelta: minutes) } },
                                resizeBlockEdges: { block, start, end in
                                    Task {
                                        await store.resizeBlockEdges(
                                            block,
                                            startMinutesDelta: start,
                                            endMinutesDelta: end
                                        )
                                    }
                                },
                                splitBlock: { block in Task { await store.splitBlock(block) } },
                                deleteBlock: { block in Task { await store.deleteBlock(block) } },
                                startFocus: { block in
                                    pendingFocusSetup = .init(
                                        taskID: block.taskID,
                                        timeBlockID: block.id,
                                        title: block.title,
                                        suggestedDuration: block.duration,
                                        subtaskID: nil
                                    )
                                },
                                onOpenTask: onOpenTask,
                                changeDay: { delta in Task { await store.moveSelection(by: delta) } }
                            )
                            if PlanDrawerGeometry.isVisible(anytimeCount: 0, unscheduledCount: snapshot.unscheduledTasks.count) {
                                Color.clear.frame(height: PlanDrawerGeometry.lipHeight + 8)
                            }
                        }
                        PlanUnscheduledDrawer(
                            // Anytime work has its own row above the canvas.
                            anytime: [],
                            unscheduled: snapshot.unscheduledTasks,
                            placement: { task in snapshot.fitsNextCandidates.first { $0.taskID == task.id } },
                            onPlace: { candidate in
                                Task {
                                    await store.createBlock(
                                        title: candidate.taskTitle,
                                        start: candidate.window.startAt,
                                        duration: candidate.estimate,
                                        taskID: candidate.taskID
                                    )
                                    if store.errorMessage == nil { Haptic.settle.play() }
                                }
                            },
                            row: { task, planned in taskCard(task, planned: planned) }
                        )
                    }
                } else {
                    PlanScheduleSection(
                        store: store,
                        snapshot: snapshot,
                        scheduleGrouping: $scheduleGrouping,
                        showsBlockComposer: $showsBlockComposer,
                        pendingFocusSetup: $pendingFocusSetup
                    )
                }

                if effectiveDayPresentation != .canvas {
                    PlanSectionHeader(
                        "Planned work",
                        systemImage: "checklist",
                        count: snapshot.plannedTasks.isEmpty ? nil : snapshot.plannedTasks.count
                    )
                    if snapshot.plannedTasks.isEmpty {
                        PlanOpenDayRescueCard(store: store, onOpenOverdueRescue: onOpenOverdueRescue)
                    } else {
                        ForEach(snapshot.plannedTasks) { taskCard($0, planned: true) }
                    }
                    // A header over nothing is a heading VoiceOver announces and a
                    // line the eye has to skip.
                    if snapshot.unscheduledTasks.isEmpty == false {
                        PlanSectionHeader("Unscheduled", systemImage: "tray", count: snapshot.unscheduledTasks.count)
                        ForEach(snapshot.unscheduledTasks) { taskCard($0, planned: false) }
                    }
                }
            }
        }
    }

    /// One decision at a time.
    ///
    /// These five could all render at once — an active focus session, a
    /// reflection waiting to be filed, a staged scenario, drifted work, and an
    /// overloaded capacity budget — giving Plan five competing prominent cards,
    /// several with their own primary button. Ordered by what is most immediate
    /// to the person rather than by what is most interesting to the app, the
    /// same shape `rebuildHero` already uses on Home.
    ///
    /// Nothing is lost by not drawing: capacity still reads in the header, the
    /// staged scenario stays staged, and drifted work is still listed below.
    /// Only the *ask* is deferred.
    @ViewBuilder
    private func decisionSlot(_ snapshot: PlanDaySnapshot) -> some View {
        if let session = store.activeFocusSession {
            PlanActiveFocusCard(
                store: store,
                session: session,
                pendingFocusEndOutcome: $pendingFocusEndOutcome
            )
        } else if let receipt = store.pendingFocusReflection {
            PlanFocusReflectionCard(
                store: store,
                receipt: receipt,
                focusReflectionEnergy: $focusReflectionEnergy,
                focusReflectionNote: $focusReflectionNote
            )
        } else if store.pendingScenario != nil {
            PlanMinimumViableDayCard(store: store)
        } else if store.repairProposals.isEmpty == false {
            VStack(spacing: 12) {
                PlanRepairDeck(proposals: store.repairProposals) { action, proposal in
                    Haptic.pick.play()
                    if action == .askEva {
                        onAskEva()
                    } else if let proposal {
                        store.previewRepair(proposal, action: action)
                    }
                }
                makeItFitEntry(for: snapshot)
            }
        } else {
            // Always drawn once the other four are quiet, overloaded or not:
            // the capacity card holds the only entry to the working-hours
            // composer, so hiding it on a calm day would strand the editor for
            // the very inputs capacity is computed from.
            PlanCapacityCard(
                capacity: snapshot.capacity,
                showsWorkingHours: $showsWorkingHours,
                onMakeItFit: isToday(snapshot.day) ? onMakeItFit : nil
            )
        }
    }

    /// The canvas layout's decision slot: the same five occupants as
    /// `decisionSlot`, folded to one line so the day stays above the fold.
    @ViewBuilder
    private func decisionLine(_ snapshot: PlanDaySnapshot) -> some View {
        let kind = PlanDecisionLineKind.resolve(
            hasActiveFocus: store.activeFocusSession != nil,
            hasPendingReflection: store.pendingFocusReflection != nil,
            hasStagedScenario: store.pendingScenario != nil,
            repairCount: store.repairProposals.count,
            isOverCapacityToday: V2FeatureFlags.evaMakeItFitTodayV1Enabled
                && isToday(snapshot.day)
                && snapshot.capacity.overloadDuration > 0,
            calendarNotRequested: snapshot.calendarState == .notRequested,
            rescueCount: isToday(snapshot.day) ? PlanRescuePool.count(store.tasks) : 0
        )
        switch kind {
        case .activeFocus:
            if let session = store.activeFocusSession {
                PlanDecisionLine(
                    title: "\(session.state == .paused ? "Focus paused" : "Focus in progress")\(focusSuffix(session))",
                    systemImage: session.state == .paused ? "pause.circle.fill" : "timer",
                    actionTitle: "Controls"
                ) {
                    PlanActiveFocusCard(store: store, session: session, pendingFocusEndOutcome: $pendingFocusEndOutcome)
                }
            }
        case .focusReflection:
            if let receipt = store.pendingFocusReflection {
                PlanDecisionLine(title: "How did that focus go?", systemImage: "sparkles", actionTitle: "Reflect") {
                    PlanFocusReflectionCard(
                        store: store,
                        receipt: receipt,
                        focusReflectionEnergy: $focusReflectionEnergy,
                        focusReflectionNote: $focusReflectionNote
                    )
                }
            }
        case .stagedScenario:
            PlanDecisionLine(title: "", systemImage: "", actionTitle: "", isAlwaysExpanded: true) {
                PlanMinimumViableDayCard(store: store)
            }
        case .repair(let count):
            PlanDecisionLine(
                title: count == 1 ? "One thing didn't get its window" : "\(count) things didn't get their window",
                systemImage: "arrow.triangle.2.circlepath",
                actionTitle: "Review"
            ) {
                VStack(spacing: 12) {
                    PlanRepairDeck(proposals: store.repairProposals) { action, proposal in
                        Haptic.pick.play()
                        if action == .askEva {
                            onAskEva()
                        } else if let proposal {
                            store.previewRepair(proposal, action: action)
                        }
                    }
                    makeItFitEntry(for: snapshot)
                }
            }
        case .overCapacity:
            PlanDecisionLine(
                title: "\(PlanCapacityCopy.duration(snapshot.capacity.overloadDuration)) more planned than fits",
                systemImage: "arrow.left.and.right.circle",
                actionTitle: "Make it fit",
                action: onMakeItFit
            ) { EmptyView() }
        case .rescue(let count):
            PlanDecisionLine(
                title: count == 1
                    ? "One thing from earlier still needs a decision"
                    : "\(count) things from earlier still need a decision",
                systemImage: "arrow.uturn.forward.circle",
                actionTitle: "Rescue",
                actionIdentifier: "plan.day.openRescue",
                action: { PlanOpenDayRescueCard.open(store: store, onOpenOverdueRescue: onOpenOverdueRescue) }
            ) { EmptyView() }
        case .calendarPrompt:
            PlanDecisionLine(
                title: "Show your read-only calendar here",
                systemImage: "calendar.badge.plus",
                actionTitle: "Allow",
                action: {
                    Task {
                        PermissionPromptState.recordRequested(.calendar)
                        await store.requestCalendarAccess()
                    }
                }
            ) { EmptyView() }
        case .none:
            EmptyView()
        }
    }

    private func anytimeToday(_ snapshot: PlanDaySnapshot) -> [PlanningTaskSummary] {
        PlanAnytimeRow.tasks(from: snapshot)
    }

    private func focusSuffix(_ session: FocusSessionV2) -> String {
        guard let taskID = session.taskID, let title = store.task(for: taskID)?.title else { return "" }
        return " · \(title)"
    }

    @ViewBuilder
    private func makeItFitEntry(for snapshot: PlanDaySnapshot) -> some View {
        if V2FeatureFlags.evaMakeItFitTodayV1Enabled, isToday(snapshot.day) {
            Button(action: onMakeItFit) {
                Label(
                    snapshot.capacity.overloadDuration > 0 ? "Make today fit" : "Renegotiate today",
                    systemImage: "arrow.left.and.right.circle.fill"
                )
                .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.lifeBoardChip)
            .accessibilityHint("Opens EVA's capacity ritual; no task changes happen yet")
            .accessibilityIdentifier("plan.repair.makeItFit")
        }
    }

    private func isToday(_ day: PlanningDay) -> Bool {
        guard let date = day.startDate(calendar: .current) else { return false }
        return Calendar.current.isDateInToday(date)
    }

    private var requiresAgendaPresentation: Bool {
        // Reduce Motion is not on this list: it changes how the canvas moves, not
        // whether it can be operated, so it keeps the timeline.
        voiceOverEnabled || dynamicTypeSize.isAccessibilitySize
    }

    private var effectiveDayPresentation: PlanDayPresentation {
        requiresAgendaPresentation ? .agenda : dayPresentation
    }

    private func taskCard(_ task: PlanningTaskSummary, planned: Bool) -> some View {
        PlanTaskCard(
            store: store,
            task: task,
            planned: planned,
            lens: lens,
            selectedTaskIDs: $selectedTaskIDs,
            pendingBacklogDeletionTaskIDs: $pendingBacklogDeletionTaskIDs,
            showsBacklogDeletionConfirmation: $showsBacklogDeletionConfirmation,
            pendingFocusSetup: $pendingFocusSetup,
            onOpenTask: onOpenTask
        )
    }
}

/// Shown in place of the planned list when a day has nothing on it: the entry
/// point into Overdue Rescue.
struct PlanOpenDayRescueCard: View {
    let store: PlanStore
    let onOpenOverdueRescue: (OverdueRescueLaunchContext) -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 14) {
                Image(decorative: AtmosphereDescriptor.descriptor(for: .midday).celestialAsset)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 58, height: 58)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 3) {
                    Text("This day is open")
                        .font(.headline)
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    Text("Choose overdue work that still deserves a place.")
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 12)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .foundationClayCard()
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .hoverEffect(.highlight)
        .accessibilityIdentifier("plan.day.openRescue")
        .accessibilityLabel("Plan this day with Overdue Rescue")
        .accessibilityHint("Review overdue tasks and keep, move, edit, or remove them.")
    }

    private func open() {
        Self.open(store: store, onOpenOverdueRescue: onOpenOverdueRescue)
    }

    static func open(store: PlanStore, onOpenOverdueRescue: (OverdueRescueLaunchContext) -> Void) {
        let metadataByTaskID = Dictionary(uniqueKeysWithValues: store.tasks.map { ($0.id, $0.metadata) })
        let context = OverdueRescueLaunchContext.plan(
            selectedDay: store.selectedDay,
            planningMetadataByTaskID: metadataByTaskID
        )
        onOpenOverdueRescue(context)
        Haptic.pick.play()
    }
}


/// Unscheduled work, kept under the canvas instead of below it.
///
/// Collapsed it is one line naming what is waiting; pulled up it lists every
/// item (no `prefix(8)`), each draggable onto the canvas and each with a
/// Place button, the non-gesture way to do the same thing. It stops at about
/// 40% of the screen so the canvas it feeds stays visible as a drop target.
/// Mechanics mirror `WeeklyWorkspaceShelfHandle` (the same handle, travel
/// threshold, spring, and haptic) without extracting it; see the plan note.
struct PlanUnscheduledDrawer<Row: View>: View {
    let anytime: [PlanningTaskSummary]
    let unscheduled: [PlanningTaskSummary]
    let placement: (PlanningTaskSummary) -> TaskFreeWindowCandidate?
    let onPlace: (TaskFreeWindowCandidate) -> Void
    @ViewBuilder let row: (PlanningTaskSummary, Bool) -> Row
    @State private var isExpanded = false
    @State private var pull: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if PlanDrawerGeometry.isVisible(anytimeCount: anytime.count, unscheduledCount: unscheduled.count) {
            VStack(alignment: .leading, spacing: 0) {
                handle
                if isExpanded {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 12) {
                            // Group titles only earn their place when there are two
                            // groups; with one, the handle already says what this is.
                            if anytime.isEmpty == false, unscheduled.isEmpty == false {
                                PlanSectionHeader("Anytime today", systemImage: "sun.max")
                            }
                            if anytime.isEmpty == false {
                                ForEach(anytime) { task in row(task, true) }
                            }
                            if anytime.isEmpty == false, unscheduled.isEmpty == false {
                                PlanSectionHeader("Unscheduled", systemImage: "tray")
                            }
                            if unscheduled.isEmpty == false {
                                ForEach(unscheduled) { task in
                                    VStack(alignment: .trailing, spacing: 4) {
                                        row(task, false)
                                        if let candidate = placement(task) {
                                            Button("Place at \(PlanSectionCopy.time(candidate.window.startAt))") {
                                                onPlace(candidate)
                                            }
                                            .buttonStyle(.lifeBoardChip)
                                            .accessibilityHint("Puts \(task.title) in the next open window that fits it")
                                            .accessibilityIdentifier("plan.day.unscheduled.place.\(task.id.uuidString)")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(16)
                    }
                    .frame(height: max(96, PlanDrawerGeometry.expandedHeight(
                        itemCount: anytime.count + unscheduled.count,
                        screenHeight: UIScreen.main.bounds.height
                    ) + pull))
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
            .accessibilityIdentifier("plan.day.unscheduled.drawer")
        }
    }

    private var summary: String {
        PlanDrawerGeometry.summary(anytimeCount: anytime.count, unscheduledCount: unscheduled.count)
    }

    private var handle: some View {
        VStack(spacing: 4) {
            Capsule()
                .fill(Color(SemanticColorTokens.inkTertiary).opacity(0.34))
                .frame(width: 36, height: 4)
            HStack(spacing: 8) {
                Text(summary)
                    .lifeboardFont(.support)
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                Spacer(minLength: 8)
                Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                    .lifeboardFont(.caption2)
                    .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .frame(minHeight: PlanDrawerGeometry.lipHeight)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 4)
                .onChanged { value in
                    guard isExpanded else { return }
                    pull = RubberBand.offset(-value.translation.height, limit: 40)
                }
                .onEnded { value in settle(travel: -value.predictedEndTranslation.height) }
        )
        .onTapGesture { settle(travel: isExpanded ? -120 : 120) }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(isExpanded ? "Hides unscheduled work" : "Shows unscheduled work")
        .accessibilityAction { settle(travel: isExpanded ? -120 : 120) }
        .accessibilityIdentifier("plan.day.unscheduled.handle")
    }

    private func settle(travel: CGFloat) {
        let next = PlanDrawerGeometry.isExpanded(afterTravel: travel, wasExpanded: isExpanded)
        withAnimation(InteractionMotion.dragRelease(reduceMotion: reduceMotion)) {
            pull = 0
            isExpanded = next
        }
        Haptic.pick.play()
    }
}

enum PlanDrawerGeometry {
    static func summary(anytimeCount: Int, unscheduledCount: Int) -> String {
        var parts: [String] = []
        if unscheduledCount > 0 { parts.append("\(unscheduledCount) unscheduled") }
        if anytimeCount > 0 { parts.append("\(anytimeCount) anytime today") }
        return parts.joined(separator: " · ")
    }

    /// The same 56 pt travel threshold the Weekly shelf uses.
    static func isExpanded(afterTravel travel: CGFloat, wasExpanded: Bool) -> Bool {
        if travel > 56 { return true }
        if travel < -56 { return false }
        return wasExpanded
    }

    static let lipHeight: CGFloat = 52

    static func isVisible(anytimeCount: Int, unscheduledCount: Int) -> Bool {
        anytimeCount + unscheduledCount > 0
    }

    /// As tall as its rows need, never more than 40% of the screen, so a
    /// single task does not open a mostly empty panel over the day.
    static func expandedHeight(itemCount: Int, screenHeight: CGFloat) -> CGFloat {
        let rows = CGFloat(itemCount) * 76 + 32
        return min(rows, (screenHeight * 0.4).rounded())
    }
}


/// Today's work with a day but no time, as one row above the canvas — the
/// all-day strip calendars use. Hidden in the drawer, a task kept "for today"
/// seemed to vanish the moment it was placed.
struct PlanAnytimeRow: View {
    let tasks: [PlanningTaskSummary]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Planned for this day with no time on it. A start time left over from
    /// another day (work kept from Overdue Rescue) does not place a task on
    /// today's timeline, so it belongs here too — otherwise it is planned for
    /// today yet drawn nowhere.
    static func tasks(from snapshot: PlanDaySnapshot, calendar: Calendar = .current) -> [PlanningTaskSummary] {
        let dayStart = snapshot.day.startDate(calendar: calendar)
        return snapshot.plannedTasks.filter { task in
            guard let start = task.scheduledStartAt, let dayStart else { return true }
            return calendar.isDate(start, inSameDayAs: dayStart) == false
        }
    }
    let onOpenTask: (UUID) -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Anytime")
                .lifeboardFont(.caption1)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(tasks) { task in
                        Button(task.title) {
                            Haptic.pick.play()
                            onOpenTask(task.id)
                        }
                            .buttonStyle(.lifeBoardChip)
                            .lineLimit(1)
                            // Drag a chip onto the canvas to give it a time.
                            .draggable(task.id.uuidString)
                            .accessibilityHint("Opens the task. Drag onto the timeline to give it a time.")
                            // Work kept for today arrives rather than appearing.
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                    }
                }
                .animation(MotionProfile.contentInsertion.animation(reduceMotion: reduceMotion), value: tasks.map(\.id))
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.day.anytime")
    }
}


/// Open work whose deadline fell before today — what Overdue Rescue decides.
enum PlanRescuePool {
    static func count(_ tasks: [PlanningTaskSummary], now: Date = Date(), calendar: Calendar = .current) -> Int {
        let startOfToday = calendar.startOfDay(for: now)
        return tasks.filter { task in
            guard let due = task.dueDate, due < startOfToday else { return false }
            // Already given a day from today on: that was the decision.
            if let planned = PlanDayProjectionInputs.effectivePlanningDay(for: task, calendar: calendar)?.startDate(calendar: calendar),
               planned >= startOfToday {
                return false
            }
            switch task.metadata.unscheduledDisposition {
            case .deleted, .archived: return false
            default: return true
            }
        }.count
    }
}
