import SwiftUI
import LifeBoardDomain

struct HomeTaskAgendaDatePicker: View {
    @Bindable var store: HomeLifeOSProjectionStore

    var body: some View {
        DatePicker(
            "Task date",
            selection: $store.taskAgendaDate,
            displayedComponents: .date
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        .frame(minHeight: 44)
        .accessibilityLabel("Task date")
        .accessibilityValue(
            store.taskAgenda.selectedDate.formatted(
                .dateTime.weekday(.wide).month(.wide).day().year()
            )
        )
        .accessibilityIdentifier("home.tasks.datePicker")
    }
}

/// Starts a Focus session on a task without leaving Home's intent behind: the
/// session begins, then its surface opens. Absent where Plan's focus commands
/// are not wired, in which case "Start" opens Plan as it always did.
struct HomeStartFocusAction {
    /// What Home already knows about the task's slot, so starting does not
    /// have to reload the whole day first. `nil` when Home has no plan loaded.
    struct Hint {
        let timeBlockID: UUID?
        let duration: TimeInterval
    }

    /// Returns whether a session is running afterwards.
    let start: @MainActor (_ taskID: UUID, _ hint: Hint?) async -> Bool
}

/// Opens the Overdue Rescue deck — the same one Plan's Rescue card presents —
/// from Home's "Needs you" row. Absent where the shell has no rescue host, in
/// which case the row falls back to the week's overdue workspace.
struct HomeOpenOverdueRescueAction {
    let open: @MainActor () -> Void
}

extension EnvironmentValues {
    @Entry var homeStartFocus: HomeStartFocusAction? = nil
    @Entry var homeOpenOverdueRescue: HomeOpenOverdueRescueAction? = nil
}

struct HomeFocusNowWidget: View {
    @Environment(\.homeStartFocus) private var startFocus
    @State private var isStarting = false
    @State private var startFailure: String?
    let preset: WidgetSizePreset
    let lifeOSStore: HomeLifeOSProjectionStore
    let projectionAdapter: HomeProjectionCoordinator
    let router: AppRouter
    let captureRouter: CaptureRouter
    let palette: DaypartPalette

    var body: some View {
        let hero = lifeOSStore.heroSnapshot
        let primary = hero?.title ?? lifeOSStore.focusTask?.title ?? projectionAdapter.snapshot.focusTitles.first
        let lowEnergy = router.dashboardMode == .lowEnergy
        HomeFocusCardContent(
            title: lowEnergy ? String(localized: "Low energy") : HomeSectionCopy.heroLabel(for: hero?.priority),
            primary: primary ?? (lowEnergy ? String(localized: "Water break") : String(localized: "Pick a task")),
            reason: hero?.detail ?? lifeOSStore.focusResult?.reasons.first?.text,
            symbol: lowEnergy ? "leaf.fill" : HomeSectionCopy.heroSymbol(for: hero?.priority),
            actionTitle: HomeSectionCopy.compactHeroActionTitle(hero?.primaryActionTitle ?? (primary == nil ? String(localized: "Choose") : String(localized: "Start"))),
            actionHint: hero?.secondaryActionTitles.first.map { action in String(localized: "Also: \(action)") } ?? "",
            preset: preset, palette: palette, onOpen: { performHeroPrimaryAction(hero) },
            isBusy: isStarting,
            failureMessage: startFailure
        )
    }

    /// The task's block today, or its estimate, from the plan Home already
    /// holds. Plan's default of 25 minutes when neither exists.
    private func focusHint(for taskID: UUID) -> HomeStartFocusAction.Hint? {
        guard let snapshot = lifeOSStore.planSnapshot else { return nil }
        if let block = snapshot.blocks.first(where: { $0.taskID == taskID }) {
            return .init(timeBlockID: block.id, duration: block.endAt.timeIntervalSince(block.startAt))
        }
        let task = (snapshot.plannedTasks + lifeOSStore.taskAgenda.dueTasks).first { $0.id == taskID }
        return .init(timeBlockID: nil, duration: task?.estimatedDuration ?? 25 * 60)
    }

    private func performHeroPrimaryAction(_ hero: AdaptiveHeroSnapshot?) {
        guard let hero else {
            captureRouter.request(kind: .task, source: .shell)
            return
        }
        switch hero.priority {
        case .safetySensitiveCare, .timedRoutine:
            router.select(.track)
        case .urgentPlannedWork, .generalFocus:
            // "Start" means start. It used to switch to the Plan tab and leave
            // the person to find the task and start it again from there.
            // The haptic follows the session actually starting; a start that
            // fails says so on the card instead of switching tabs silently.
            if let taskID = hero.sourceID, let startFocus {
                guard isStarting == false else { return }
                isStarting = true
                startFailure = nil
                Task { @MainActor in
                    let started = await startFocus.start(taskID, focusHint(for: taskID))
                    isStarting = false
                    if started {
                        Haptic.commit.play()
                    } else {
                        Haptic.fail.play()
                        startFailure = String(localized: "Couldn’t start focus. End any running session first.")
                    }
                }
                return
            }
            router.select(.plan)
        case .activeFocus, .fixedCommitment, .recovery:
            router.select(.plan)
        }
        Haptic.pick.play()
    }
}

struct HomeLifeSnapshotWidget: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    let captureRouter: CaptureRouter
    let palette: DaypartPalette
    let selectedMood: JournalMood
    let moodEnergy: Int?
    @Binding var showsMoodDial: Bool

    var body: some View {
        HomeLifeSnapshotCardContent(
            mood: selectedMood == .none ? String(localized: "Check in") : selectedMood.title,
            moodLabel: moodEnergy.map { energy in String(localized: "Mood · energy \(energy)") } ?? String(localized: "Mood"),
            hydration: HomeSectionCopy.hydrationLabel(lifeOSStore), lowEnergy: router.dashboardMode == .lowEnergy,
            palette: palette, onMood: { showsMoodDial = true },
            onHydration: { captureRouter.request(kind: .hydration, source: .shell) },
            onTrack: { router.select(.track) }
        )
    }
}

struct HomeCareWidget: View {
    let preset: WidgetSizePreset
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    let daypart: ResolvedDaypart
    let palette: DaypartPalette

    var body: some View {
        let events = lifeOSStore.trackSnapshot?.unresolvedMedicationEvents ?? []
        HomeActionQueueCardContent(
            title: String(localized: "\(HomeSectionCopy.daypartName(daypart)) care"), symbol: "cross.case.fill",
            rows: events.map { event in
                let row = HomeSectionCopy.medicationRow(
                    name: lifeOSStore.medicationNames[event.medicationID],
                    scheduledAt: event.scheduledAt,
                    isPastDue: event.status == .unresolved || event.scheduledAt < Date()
                )
                return .init(id: event.id, title: row.title, symbol: "pills", detail: row.detail)
            },
            limit: HomeCardPresentationStyle(kind: .care, preset: preset).rowLimit(lowEnergy: router.dashboardMode == .lowEnergy),
            statusMessage: events.isEmpty ? String(localized: "No doses to log") : nil,
            statusSymbol: "checkmark.circle", actionTitle: String(localized: "Open Care"), identifier: "care", palette: palette,
            onOpen: { router.navigate(.careLibrary, in: .track) },
            onOpenRow: { _ in router.navigate(.careLibrary, in: .track) }
        )
    }
}

struct HomeTasksWidget: View {
    let preset: WidgetSizePreset
    let placementID: UUID
    let lifeOSStore: HomeLifeOSProjectionStore
    let router: AppRouter
    let captureRouter: CaptureRouter
    let hasPlanningRepository: Bool
    let palette: DaypartPalette
    let motionAnimation: Animation?
    let reduceMotion: Bool
    @Binding var expandedTaskWidgetIDs: Set<UUID>

    var body: some View {
        HomeTasksCardContent(
            tasks: lifeOSStore.taskAgenda.tasks,
            title: HomeSectionCopy.taskWidgetTitle(lifeOSStore),
            emptyMessage: HomeSectionCopy.taskWidgetEmptyMessage(lifeOSStore),
            isLoading: lifeOSStore.isLoading && !lifeOSStore.hasLoadedCore,
            hasPlanningRepository: hasPlanningRepository,
            collapsedLimit: HomeCardPresentationStyle(kind: .tasks, preset: preset).rowLimit(lowEnergy: router.dashboardMode == .lowEnergy),
            isExpanded: expandedTaskWidgetIDs.contains(placementID),
            allowsCompletion: V2FeatureFlags.lifeBoardDailyLoopV1Enabled,
            completedTask: lifeOSStore.lastCompletedTask,
            refreshFailure: refreshFailure,
            palette: palette,
            dateControls: HomeTaskAgendaDatePicker(store: lifeOSStore),
            taskWidgetAnimation: reduceMotion ? nil : motionAnimation,
            mutationError: lifeOSStore.taskMutationError,
            onComplete: { task in await lifeOSStore.setTaskCompletion(task, to: true) },
            onOpen: { router.navigate(.taskDetail($0.id), in: .home) },
            onAdd: { captureRouter.request(kind: .task, source: .widget) },
            onUndo: { Task { await lifeOSStore.undoLastTaskCompletion() } },
            onRetry: { Task { await lifeOSStore.retryTaskMutationRefresh() } },
            onToggleExpansion: {
                withAnimation(reduceMotion ? nil : motionAnimation) {
                    lifeOSStore.resetTaskAgendaDateToToday()
                    if expandedTaskWidgetIDs.contains(placementID) {
                        expandedTaskWidgetIDs.remove(placementID)
                    } else {
                        expandedTaskWidgetIDs.insert(placementID)
                    }
                }
            }
        )
    }

    private var refreshFailure: String? {
        if case .failed(let message) = lifeOSStore.lastTaskMutationRefreshOutcome { return message }
        return nil
    }
}

struct HomeRoutinesWidget: View {
    let preset: WidgetSizePreset
    let lifeOSStore: HomeLifeOSProjectionStore
    let projectionAdapter: HomeProjectionCoordinator
    let router: AppRouter
    let hasTrackFoundationRepository: Bool
    let daypart: ResolvedDaypart
    let palette: DaypartPalette

    var body: some View {
        HomeActionQueueCardContent(
            title: String(localized: "\(HomeSectionCopy.daypartName(daypart)) routines"), symbol: "repeat", rows: rows,
            limit: HomeCardPresentationStyle(kind: .routines, preset: preset).rowLimit(lowEnergy: router.dashboardMode == .lowEnergy),
            statusMessage: statusMessage, statusSymbol: statusSymbol,
            actionTitle: String(localized: "View routines"), identifier: "routines", palette: palette,
            titleIsAction: true, onOpen: openDaypart,
            onOpenRow: { id in
                if lifeOSStore.trackSnapshot?.dueRoutines.isEmpty != false {
                    router.navigate(.habitBoard, in: .track)
                } else {
                    router.openLeaf(.routine(id), in: .track)
                }
            }
        )
    }

    private var rows: [HomeCardQueueRow] {
        let routines = lifeOSStore.trackSnapshot?.dueRoutines ?? []
        if !routines.isEmpty { return routines.map { .init(id: $0.id, title: $0.title, symbol: "figure.mind.and.body", accessibilityIdentifier: "home.routine.\($0.id.uuidString)") } }
        if let habit = (projectionAdapter.snapshot.recoveryHabits + projectionAdapter.snapshot.currentHabits).first {
            return [.init(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, title: habit, symbol: "repeat", accessibilityIdentifier: "home.routines.openHabitBoard")]
        }
        return []
    }

    private var statusMessage: String? {
        if !hasTrackFoundationRepository { return String(localized: "Couldn’t load routines.") }
        if lifeOSStore.isLoading && lifeOSStore.trackSnapshot == nil { return String(localized: "Loading…") }
        return rows.isEmpty ? String(localized: "No routines due now") : nil
    }

    private var statusSymbol: String {
        if !hasTrackFoundationRepository { return "exclamationmark.triangle" }
        return lifeOSStore.isLoading && lifeOSStore.trackSnapshot == nil ? "hourglass" : "checkmark.circle"
    }

    private func openDaypart() {
        router.openLeaf(.routines(.daypart(daypart)), in: .track)
    }
}

struct HomeCapacityWidget: View {
    let lifeOSStore: HomeLifeOSProjectionStore
    let projectionAdapter: HomeProjectionCoordinator
    let router: AppRouter
    let palette: DaypartPalette

    var body: some View {
        HomeCapacityCardContent(
            title: router.dashboardMode == .lowEnergy ? String(localized: "Protected rest") : String(localized: "Capacity"),
            summary: summary,
            detail: detail,
            needsSetup: lifeOSStore.planSnapshot?.capacity == nil && projectionAdapter.snapshot.calendarNeedsSetup,
            palette: palette,
            onOpen: { router.navigate(.planDay, in: .plan) }
        )
    }

    private var summary: String {
        if let capacity = lifeOSStore.planSnapshot?.capacity {
            return capacity.overloadDuration > 0
                ? String(localized: "\(HomeSectionCopy.duration(capacity.overloadDuration)) over capacity")
                : String(localized: "\(HomeSectionCopy.duration(capacity.remainingKnownCapacity)) free")
        }
        if let freeUntil = projectionAdapter.snapshot.freeUntil {
            let time = freeUntil.formatted(date: .omitted, time: .shortened)
            return String(localized: "Free until \(time)")
        }
        return String(localized: "Free time unknown")
    }

    private var detail: String {
        if let capacity = lifeOSStore.planSnapshot?.capacity {
            return capacity.isEstimateIncomplete
                ? String(localized: "Some tasks have no estimate")
                : String(localized: "\(HomeSectionCopy.duration(capacity.usableDuration)) available today")
        }
        if projectionAdapter.snapshot.freeUntil != nil {
            return HomeSectionCopy.capacityDescription(router: router, projectionAdapter: projectionAdapter)
        }
        return String(localized: "Add estimates to see free time.")
    }
}
