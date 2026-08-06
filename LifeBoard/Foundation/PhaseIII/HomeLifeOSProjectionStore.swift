import Foundation
import Observation

enum HomeFastingAnchorPolicy {
    static let recentMealWindow: TimeInterval = 24 * 60 * 60

    /// A meal may transparently anchor a one-tap fast only while it is recent.
    /// Future-dated records and older history deliberately fall back to a
    /// manual start, so the signal never fabricates an extreme duration.
    static func recentMealAnchor(
        latestMealAt: Date?,
        now: Date,
        maximumAge: TimeInterval = recentMealWindow
    ) -> Date? {
        guard let latestMealAt else { return nil }
        let age = now.timeIntervalSince(latestMealAt)
        guard age >= 0, age <= maximumAge else { return nil }
        return latestMealAt
    }
}

struct HomeTaskAgendaProjection: Equatable, Sendable {
    let selectedDate: Date
    let overdueTasks: [PlanningTaskSummary]
    let dueTasks: [PlanningTaskSummary]

    var tasks: [PlanningTaskSummary] { overdueTasks + dueTasks }

    static func build(
        tasks: [PlanningTaskSummary],
        selectedDate: Date,
        calendar: Calendar = .current
    ) -> HomeTaskAgendaProjection {
        let dayStart = calendar.startOfDay(for: selectedDate)
        let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            ?? dayStart.addingTimeInterval(24 * 60 * 60)
        var seenTaskIDs: Set<UUID> = []

        let eligible = tasks.filter { task in
            guard task.dueDate != nil,
                  task.metadata.unscheduledDisposition.isVisibleInHomeTaskAgenda,
                  seenTaskIDs.insert(task.id).inserted else {
                return false
            }
            return true
        }

        let overdue = eligible
            .filter { ($0.dueDate ?? .distantFuture) < dayStart }
            .sorted(by: taskOrder)
        let due = eligible
            .filter {
                guard let dueDate = $0.dueDate else { return false }
                return dueDate >= dayStart && dueDate < dayEnd
            }
            .sorted(by: taskOrder)

        return HomeTaskAgendaProjection(
            selectedDate: dayStart,
            overdueTasks: overdue,
            dueTasks: due
        )
    }

    private static func taskOrder(_ lhs: PlanningTaskSummary, _ rhs: PlanningTaskSummary) -> Bool {
        let lhsDueDate = lhs.dueDate ?? .distantFuture
        let rhsDueDate = rhs.dueDate ?? .distantFuture
        if lhsDueDate != rhsDueDate { return lhsDueDate < rhsDueDate }

        let titleOrder = lhs.title.localizedStandardCompare(rhs.title)
        if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
        return lhs.id.uuidString < rhs.id.uuidString
    }
}

private extension UnscheduledDisposition {
    var isVisibleInHomeTaskAgenda: Bool {
        switch self {
        case .inbox, .someday:
            return true
        case .archived, .deleted, .reference:
            return false
        }
    }
}

@MainActor
@Observable
final class HomeLifeOSProjectionStore {
    private(set) var planSnapshot: PlanDaySnapshot?
    var taskAgendaDate: Date {
        didSet { rebuildTaskAgenda() }
    }
    private(set) var taskAgenda: HomeTaskAgendaProjection
    /// The task most recently completed from Home, and the reason its Undo
    /// control is offered. Cleared once taken back.
    private(set) var lastCompletedTask: PlanningTaskSummary?
    private(set) var trackSnapshot: TrackTodaySnapshot?
    private(set) var focusTask: PlanningTaskSummary?
    private(set) var focusResult: FocusRankResult?
    private(set) var latestMood: LifeBoardMoodEnergyCheckInValue?
    private(set) var activeFast: LifeBoardFastingSessionValue?
    /// The most recently completed session anchors the open-window clock on
    /// Home. Keeping this beside `activeFast` means the signal never reaches
    /// into persistence from its TimelineView redraws.
    private(set) var latestEndedFast: LifeBoardFastingSessionValue?
    private(set) var recentMealAt: Date?
    private(set) var fastingMutationError: String?
    private var fastEndUndoSession: LifeBoardFastingSessionValue?
    private(set) var activeFocusSession: FocusSessionV2?
    /// Today's repair proposals, already stripped of the ones the person
    /// resolved. Home reads these rather than recomputing from `planSnapshot`:
    /// resolving a repair with "leave today as it is" writes a receipt but does
    /// **not** change the snapshot, so a recompute would resurface a dismissed
    /// repair every time Home loaded, forever.
    private(set) var repairProposals: [PlanRepairProposal] = []
    /// How much drift is worth surfacing, per `PlanDriftPolicy`. Feeds the loop
    /// spine's stage resolution; `0` means the spine stays in `.act`.
    private(set) var driftCount: Int = 0
    private(set) var heroSnapshot: AdaptiveHeroSnapshot?
    private(set) var isLoading = false
    /// Provider-resolved card snapshots keyed by "kind|size". Home widget
    /// bodies read these instead of reaching into domain snapshots directly.
    private(set) var cardSnapshots: [String: HomeCardSnapshot] = [:]
    private var cardProviderRegistry: HomeCardProviderRegistry?
    private var journalInvalidationTask: Task<Void, Never>?

    private let planStore: PlanStore?
    private let trackStore: TrackFoundationStore?
    private let phaseIIRepository: (any LifeBoardPhaseIIRepository)?
    private let fastingTimerStore: FastingTimerStore?
    private let rankingService: any FocusRankingService
    private let wellnessRepository: (any WellnessRepository)?
    private let nutritionRepository: (any NutritionRepository)?
    private let lifeMomentRepository: (any LifeMomentRepository)?

    init(
        planningRepository: CoreDataPlanningRepository?,
        trackRepository: CoreDataTrackFoundationRepository?,
        phaseIIRepository: (any LifeBoardPhaseIIRepository)?,
        goalSampleProvider: (any GoalSampleProvider)? = nil,
        wellnessRepository: (any WellnessRepository)? = nil,
        nutritionRepository: (any NutritionRepository)? = nil,
        lifeMomentRepository: (any LifeMomentRepository)? = nil,
        rankingService: any FocusRankingService = DeterministicFocusRankingService(),
        taskAgendaDate: Date = Date()
    ) {
        self.taskAgendaDate = taskAgendaDate
        self.taskAgenda = HomeTaskAgendaProjection.build(
            tasks: [],
            selectedDate: taskAgendaDate
        )
        if let planningRepository {
            planStore = PlanStore(planningRepository: planningRepository, blockRepository: planningRepository)
        } else {
            planStore = nil
        }
        if let trackRepository, let phaseIIRepository {
            trackStore = TrackFoundationStore(
                repository: trackRepository,
                phaseIIRepository: phaseIIRepository,
                goalSampleProvider: goalSampleProvider
            )
        } else {
            trackStore = nil
        }
        self.phaseIIRepository = phaseIIRepository
        fastingTimerStore = phaseIIRepository.map {
            FastingTimerStore(repository: LifeBoardFastingRepositoryAdapter(repository: $0))
        }
        self.wellnessRepository = wellnessRepository
        self.nutritionRepository = nutritionRepository
        self.lifeMomentRepository = lifeMomentRepository
        self.rankingService = rankingService
    }

    /// Journal saves invalidate derived projections through the pipeline hub.
    /// Home listens so journal-backed cards refresh without a manual pull.
    private func observeJournalInvalidationIfNeeded() {
        guard journalInvalidationTask == nil else { return }
        // Weak capture ends the subscription on the first event after this
        // store deallocates; the hub then drops the finished continuation.
        journalInvalidationTask = Task { [weak self] in
            let updates = await JournalProjectionInvalidationHub.shared.updates()
            for await event in updates {
                guard case .projectionsInvalidated = event else { continue }
                guard let self else { return }
                await self.load()
            }
        }
    }

    /// Completes or reopens a task from Home.
    ///
    /// Home reads plan data through a projection, so it has no writer of its
    /// own; this delegates to the same receipted `PlanStore` mutation the Plan
    /// root uses, then rebuilds the projection so the row leaves Today.
    /// Returns `false` when planning data is unavailable, so the caller can
    /// leave the control in its previous state rather than lying about a write.
    @discardableResult
    func setTaskCompletion(_ task: PlanningTaskSummary, to isComplete: Bool) async -> Bool {
        guard let planStore else { return false }
        await planStore.setCompletion(task, to: isComplete)
        lastCompletedTask = planStore.errorMessage == nil && isComplete ? task : nil
        await load()
        return true
    }

    /// Reopens the task completed from Home.
    ///
    /// Plan's Undo control reads *its own* `PlanStore`, and Home holds a
    /// separate instance, so a completion made here was unreachable from that
    /// button. Home therefore owns a receipt of its own rather than leaving the
    /// most repeated mutation in the product one-way.
    func undoLastTaskCompletion() async {
        guard let planStore, lastCompletedTask != nil else { return }
        await planStore.undoLastMutation()
        lastCompletedTask = nil
        await load()
    }

    func load() async {
        observeJournalInvalidationIfNeeded()
        guard isLoading == false else { return }
        isLoading = true
        defer { isLoading = false }
        if let planStore { await planStore.load() }
        if let trackStore { await trackStore.load() }
        planSnapshot = planStore?.daySnapshot
        trackSnapshot = trackStore?.snapshot
        latestMood = trackStore?.checkIns.first
        if let phaseIIRepository {
            let sessions = (try? await phaseIIRepository.fetchFastingSessions(limit: 30)) ?? []
            activeFast = sessions
                .filter { $0.endedAt == nil }
                .sorted { $0.startedAt > $1.startedAt }
                .first
            latestEndedFast = sessions
                .filter { $0.endedAt != nil }
                .sorted { ($0.endedAt ?? .distantPast) > ($1.endedAt ?? .distantPast) }
                .first
        } else {
            activeFast = nil
            latestEndedFast = nil
        }
        if let nutritionRepository {
            let now = Date()
            let oneDayAgo = now.addingTimeInterval(-HomeFastingAnchorPolicy.recentMealWindow)
            recentMealAt = try? await nutritionRepository
                .logs(from: oneDayAgo, to: now.addingTimeInterval(1))
                .first?
                .loggedAt
        } else {
            recentMealAt = nil
        }
        activeFocusSession = planStore?.activeFocusSession
        rebuildTaskAgenda()
        rebuildDrift()
        rebuildFocus()
        rebuildHero()
    }

    func resetTaskAgendaDateToToday(now: Date = Date()) {
        taskAgendaDate = now
    }

    private func rebuildTaskAgenda(calendar: Calendar = .current) {
        taskAgenda = HomeTaskAgendaProjection.build(
            tasks: planStore?.tasks ?? [],
            selectedDate: taskAgendaDate,
            calendar: calendar
        )
    }

    func saveMood(_ mood: LifeBoardJournalMood, energy: Int?) async {
        if let trackStore {
            await trackStore.saveMood(mood, energy: energy)
        } else if let phaseIIRepository {
            try? await phaseIIRepository.saveMoodCheckIn(.init(mood: mood, energy: energy))
        }
        await load()
    }

    /// Fallback mood read for configurations without a Track store. Keeps the
    /// Home view from querying repositories directly.
    func latestMoodCheckInToday() async -> LifeBoardMoodEnergyCheckInValue? {
        if let latestMood { return latestMood }
        guard let phaseIIRepository else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let values = try? await phaseIIRepository.fetchMoodCheckIns(from: start, to: Date().addingTimeInterval(1))
        return values?.first
    }

    static func cardSnapshotKey(_ kind: DashboardWidgetKind, _ size: HomeCardSize) -> String {
        "\(kind.rawValue)|\(size.rawValue)"
    }

    func cardSnapshot(kind: DashboardWidgetKind, size: HomeCardSize) -> HomeCardSnapshot? {
        cardSnapshots[Self.cardSnapshotKey(kind, size)]
    }

    /// Resolves display-ready snapshots for the requested kind/size pairs
    /// through the domain provider registry. Home calls this after `load()`
    /// and at meaningful refresh boundaries; card bodies never read canonical
    /// domain state themselves.
    func refreshCardSnapshots(
        requests: [(kind: DashboardWidgetKind, size: HomeCardSize)],
        permitsSensitive: Bool,
        at date: Date = Date()
    ) async {
        let registry: HomeCardProviderRegistry
        if let cardProviderRegistry {
            registry = cardProviderRegistry
        } else {
            guard let built = try? makeHomeCardProviderRegistry() else { return }
            cardProviderRegistry = built
            registry = built
        }
        var permitted: Set<DataSensitivity> = [.privateStandard, .shareEligible]
        if permitsSensitive { permitted.insert(.privateSensitive) }
        var resolved: [String: HomeCardSnapshot] = [:]
        for request in requests {
            let context = HomeCardSnapshotContext(
                date: date,
                semanticSize: request.size,
                permittedSensitivities: permitted
            )
            guard let snapshot = try? await registry.snapshot(for: request.kind, context: context) else { continue }
            resolved[Self.cardSnapshotKey(request.kind, request.size)] = snapshot
        }
        cardSnapshots = resolved
    }

    func quickAddHydration(_ milliliters: Double) async {
        await trackStore?.quickAddHydration(milliliters)
        await load()
    }

    @discardableResult
    func startFast(
        targetDuration: TimeInterval?,
        reminderOffsets: [TimeInterval] = [],
        at date: Date = Date()
    ) async -> Bool {
        guard let fastingTimerStore else {
            fastingMutationError = "Fasting is unavailable right now."
            return false
        }
        do {
            _ = try await fastingTimerStore.start(
                targetDuration: targetDuration,
                reminderOffsets: reminderOffsets,
                at: date
            )
            fastingMutationError = nil
            await load()
            return true
        } catch {
            fastingMutationError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func endActiveFast(at date: Date = Date()) async -> Bool {
        guard let fastingTimerStore else {
            fastingMutationError = "Fasting is unavailable right now."
            return false
        }
        do {
            let undoSession = activeFast
            _ = try await fastingTimerStore.finish(at: date)
            fastEndUndoSession = undoSession
            fastingMutationError = nil
            await load()
            return true
        } catch {
            fastingMutationError = error.localizedDescription
            return false
        }
    }

    @discardableResult
    func undoLastFastEnd() async -> Bool {
        guard let fastingTimerStore, let session = fastEndUndoSession else { return false }
        do {
            _ = try await fastingTimerStore.correct(
                sessionID: session.id,
                startedAt: session.startedAt,
                endedAt: nil,
                targetDuration: session.targetDuration,
                note: session.note
            )
            fastEndUndoSession = nil
            fastingMutationError = nil
            await load()
            return true
        } catch {
            fastingMutationError = error.localizedDescription
            return false
        }
    }

    /// Home renders only these display-ready projections. The provider registry
    /// is deliberately assembled at the domain boundary so card views do not
    /// know which repositories produced the values.
    func makeHomeCardProviderRegistry() throws -> HomeCardProviderRegistry {
        let registry = DefaultDashboardWidgetRegistry.shared
        let kinds: [(DashboardWidgetKind, LifeBoardDestination)] = [
            (.setupChecklist, .track),
            (.focusNow, .plan),
            (.tasks, .plan),
            (.scheduleCapacity, .plan),
            (.compactTimeline, .plan),
            (.lifeSnapshot, .track),
            (.care, .track),
            (.routines, .track),
            (.goals, .track),
            (.fasting, .track),
            (.journal, .track),
            (.progressReflection, .insights),
            (.quickCapture, .home),
            (.evaConversation, .eva)
        ]
        var providers: [any HomeCardProvider] = kinds.compactMap { kind, destination in
            guard let definition = registry.descriptor(for: kind) else { return nil }
            return ProjectionHomeCardProvider(
                definition: definition,
                destination: destination,
                snapshotBuilder: { [self] size, date in
                    homeCardSnapshot(kind: kind, size: size, date: date)
                }
            )
        }
        if let wellnessRepository {
            let focuses: [(DashboardWidgetKind, WellnessHomeCardFocus)] = [
                (.bodyMetric, .bodyMetric(.bodyMass)), (.workout, .workouts), (.sleep, .sleep), (.movement, .movement)
            ]
            providers += focuses.compactMap { kind, focus in
                registry.descriptor(for: kind).map { WellnessHomeCardProvider(definition: $0, focus: focus, repository: wellnessRepository) }
            }
        }
        if let nutritionRepository {
            let focuses: [(DashboardWidgetKind, NutritionHomeCardFocus)] = [
                (.nutritionSummary, .dailySummary), (.recentMeal, .recentMeal), (.logMeal, .logMeal)
            ]
            providers += focuses.compactMap { kind, focus in
                registry.descriptor(for: kind).map { NutritionHomeCardProvider(definition: $0, focus: focus, repository: nutritionRepository) }
            }
        }
        if let lifeMomentRepository, let definition = registry.descriptor(for: .lifeMoment) {
            providers.append(LifeMomentsOverviewHomeCardProvider(definition: definition, repository: lifeMomentRepository))
        }
        return try HomeCardProviderRegistry(providers: providers)
    }

    private func homeCardSnapshot(
        kind: DashboardWidgetKind,
        size: HomeCardSize,
        date: Date
    ) -> HomeCardSnapshot {
        let title = DefaultDashboardWidgetRegistry.shared.descriptor(for: kind)?.title ?? "Home"
        switch kind {
        case .focusNow:
            guard let focusTask else { return emptySnapshot(title, "Choose what is next.", date) }
            return densitySnapshot(
                title: title,
                value: focusTask.title,
                compactDetail: focusResult?.reasons.first?.text ?? "Pick this up next.",
                storyDetail: "Fits the time you have now.",
                size: size,
                date: date
            )
        case .tasks:
            guard let planSnapshot else { return unavailableSnapshot(title, date) }
            let planned = planSnapshot.plannedTasks
            let unscheduled = planSnapshot.unscheduledTasks
            let count = planned.count + unscheduled.count
            guard count > 0 else {
                return emptySnapshot(title, "Nothing is asking for your attention.", date)
            }
            // Planned work first, then flexible; overdue rises above both.
            let rows = (planned + unscheduled).map { task in
                HomeQueueItem(
                    id: task.id.uuidString,
                    title: task.title,
                    supporting: task.dueDate.map {
                        "Due \($0.formatted(date: .abbreviated, time: .omitted))"
                    },
                    state: Self.queueState(for: task, at: date)
                )
            }
            .sorted { lhs, rhs -> Bool in
                let lhsRank = lhs.state == .overdue ? 0 : 1
                let rhsRank = rhs.state == .overdue ? 0 : 1
                return lhsRank < rhsRank
            }
            return densitySnapshot(
                title: title,
                value: "\(count)",
                compactDetail: count == 1 ? "task in view" : "tasks in view",
                storyDetail: "\(planned.count) planned · \(unscheduled.count) still flexible",
                size: size,
                date: date,
                payload: .queue(rows)
            )
        case .scheduleCapacity, .compactTimeline:
            guard let planSnapshot else { return unavailableSnapshot(title, date) }
            let count = planSnapshot.commitments.count
            // The spine reads as the day's shape: what is fixed, in order.
            let spine = planSnapshot.commitments
                .sorted { $0.startAt < $1.startAt }
                .map { commitment in
                    HomeQueueItem(
                        id: commitment.id,
                        title: commitment.title,
                        supporting: commitment.startAt.formatted(date: .omitted, time: .shortened),
                        state: commitment.endAt < date ? .done : .pending,
                        systemImage: "circle.fill"
                    )
                }
            return densitySnapshot(
                title: title,
                value: "\(count)",
                compactDetail: count == 1 ? "fixed commitment" : "fixed commitments",
                storyDetail: planSnapshot.freeWindows.isEmpty
                    ? "No open window is projected yet."
                    : "\(planSnapshot.freeWindows.count) open windows remain flexible.",
                size: size,
                date: date,
                payload: .queue(spine)
            )
        case .lifeSnapshot:
            guard let latestMood else { return emptySnapshot(title, "A gentle check-in can start your snapshot.", date) }
            return densitySnapshot(
                title: title,
                value: latestMood.mood.title,
                compactDetail: latestMood.energy.map { "Energy \($0)/5" } ?? "Mood checked in",
                storyDetail: "Your last check-in.",
                size: size,
                date: date
            )
        case .care:
            guard let trackSnapshot else { return unavailableSnapshot(title, date) }
            let pending = trackSnapshot.unresolvedMedicationEvents.filter { $0.status == .unresolved }
            guard pending.isEmpty == false else {
                return emptySnapshot(title, "No unresolved care decisions.", date)
            }
            // The event carries only a medication ID; the snapshot has no name
            // lookup, so the row leads with its scheduled time and Care owns
            // the detail. Better an honest time than an invented label.
            let rows = pending.map { event in
                HomeQueueItem(
                    id: event.id.uuidString,
                    title: event.scheduledAt.formatted(date: .omitted, time: .shortened),
                    supporting: event.note,
                    state: event.scheduledAt < date ? .overdue : .pending,
                    systemImage: "cross.case"
                )
            }
            return densitySnapshot(
                title: title,
                value: "\(pending.count)",
                compactDetail: pending.count == 1 ? "waiting on you" : "waiting on you",
                storyDetail: "Confirm each one when you have taken it.",
                size: size,
                date: date,
                payload: .queue(rows)
            )
        case .routines:
            guard let trackSnapshot else { return unavailableSnapshot(title, date) }
            let due = trackSnapshot.dueRoutines
            guard due.isEmpty == false else {
                return emptySnapshot(title, "Nothing due right now.", date)
            }
            let rows = due.map { routine in
                HomeQueueItem(
                    id: routine.id.uuidString,
                    title: routine.title,
                    supporting: routine.steps.isEmpty ? nil : "\(routine.steps.count) steps",
                    state: .pending,
                    systemImage: "repeat"
                )
            }
            return densitySnapshot(
                title: title,
                value: "\(due.count)",
                compactDetail: due.count == 1 ? "routine ready" : "routines ready",
                storyDetail: "Start one when it fits.",
                size: size,
                date: date,
                payload: .queue(rows)
            )
        case .goals:
            guard let trackSnapshot else { return unavailableSnapshot(title, date) }
            let goals = trackSnapshot.goals
            guard goals.isEmpty == false else {
                return emptySnapshot(title, "Add a goal to follow.", date)
            }
            // Lead with the goal nearest completion rather than an arbitrary
            // first row, so the ring reads as momentum.
            let ranked = goals.max { Self.goalFraction($0) < Self.goalFraction($1) }
            let fraction = ranked.map(Self.goalFraction) ?? 0
            let percent = Int((fraction * 100).rounded())
            return densitySnapshot(
                title: title,
                value: "\(goals.count)",
                compactDetail: goals.count == 1 ? "goal in view" : "goals in view",
                storyDetail: ranked?.nextUsefulAction ?? "Open Track for progress and evidence.",
                size: size,
                date: date,
                payload: .progress(fraction: fraction, label: "\(percent)%")
            )
        case .fasting:
            guard let activeFast else { return emptySnapshot(title, "No fast running.", date) }
            let elapsed = max(0, activeFast.elapsed(at: date))
            let hours = Int(elapsed) / 3_600
            let minutes = (Int(elapsed) % 3_600) / 60
            let fraction = activeFast.targetDuration.map { target in
                target > 0 ? min(1, elapsed / target) : 0
            } ?? 0
            return densitySnapshot(
                title: title,
                value: String(format: "%d:%02d", hours, minutes),
                compactDetail: activeFast.targetDuration.map { "Target \(Int($0 / 3_600))h" } ?? "Running",
                storyDetail: "Started \(activeFast.startedAt.formatted(date: .omitted, time: .shortened)).",
                size: size,
                date: date,
                payload: .progress(
                    fraction: fraction,
                    label: String(format: "%d:%02d", hours, minutes)
                )
            )
        case .journal:
            // Previously hard-coded to `.degraded` with no way to grant consent,
            // so this card could never become useful. It now reflects a real
            // setting the user can turn on in Journal privacy.
            guard JournalHomeConsentStore.isGranted else {
                return HomeCardSnapshot(
                    availability: .degraded,
                    title: title,
                    value: size == .compact ? nil : "Show journal here?",
                    detail: "Turn on in Journal privacy.",
                    updatedAt: date
                )
            }
            return densitySnapshot(
                title: title,
                value: "Open",
                compactDetail: "Today\u{2019}s entry",
                storyDetail: "Words, photos, or audio \u{2014} whatever fits.",
                size: size,
                date: date
            )
        case .progressReflection:
            guard let planSnapshot, let trackSnapshot else { return unavailableSnapshot(title, date) }
            let planned = planSnapshot.plannedTasks.count
            let goals = trackSnapshot.goals.count
            return densitySnapshot(
                title: title,
                value: planned == 0 ? "A quiet day" : "\(planned) planned",
                compactDetail: goals == 0 ? "Look back on today" : "\(goals) goals in context",
                storyDetail: "What helped, and what to carry forward.",
                size: size,
                date: date
            )
        case .quickCapture:
            return densitySnapshot(
                title: title,
                value: "Capture",
                compactDetail: "Task, note, journal, mood, or metric",
                storyDetail: "Write naturally. You review before anything saves.",
                size: size,
                date: date
            )
        case .evaConversation:
            return emptySnapshot(title, "Save an Eva insight to place it here.", date)
        case .setupChecklist:
            let outstanding = outstandingSetupItems()
            guard let first = outstanding.first else {
                // Nothing left to offer: the card reports empty and the Home
                // canvas drops it rather than leaving a permanent placeholder.
                return emptySnapshot(title, "Nothing left to set up.", date)
            }
            return densitySnapshot(
                title: title,
                value: first,
                compactDetail: outstanding.count == 1 ? "1 left" : "\(outstanding.count) left",
                storyDetail: outstanding.prefix(3).joined(separator: " \u{00B7} "),
                size: size,
                date: date
            )
        default:
            return unavailableSnapshot(title, date)
        }
    }

    /// What the user still has not set up, in the order worth offering it.
    ///
    /// Onboarding deliberately does not ask for everything; this is where the
    /// remainder lives so the flow can stay short. Each row disappears as soon as
    /// it is satisfied, and the card removes itself when the list empties.
    private func outstandingSetupItems() -> [String] {
        var items: [String] = []

        if LifeBoardPermissionPromptState.hasRequested(.notifications) == false {
            items.append("Turn on reminders")
        }
        if LifeBoardPermissionKind.appleHealth.isSupportedOnThisDevice,
           LifeBoardPermissionPromptState.hasRequested(.appleHealth) == false {
            items.append("Connect Apple Health")
        }
        if LifeBoardPermissionPromptState.hasRequested(.calendar) == false {
            items.append("Connect your calendar")
        }
        if let trackSnapshot {
            if trackSnapshot.hydrationTargetMilliliters == nil {
                items.append("Set a hydration target")
            }
            if trackSnapshot.dueRoutines.isEmpty, trackSnapshot.goals.isEmpty {
                items.append("Add a routine")
            }
        }
        if V2FeatureFlags.journalV1Enabled, JournalHomeConsentStore.isGranted == false {
            items.append("Show journal on Home")
        }
        return items
    }

    private func densitySnapshot(
        title: String,
        value: String,
        compactDetail: String,
        storyDetail: String,
        size: HomeCardSize,
        date: Date,
        payload: HomeCardPayload = .none
    ) -> HomeCardSnapshot {
        let detail: String?
        switch size {
        case .compact: detail = nil
        case .standard, .wide: detail = compactDetail
        case .tall, .expanded: detail = storyDetail
        }
        return HomeCardSnapshot(
            availability: .ready,
            title: title,
            value: value,
            detail: detail,
            payload: payload,
            updatedAt: date
        )
    }

    private func emptySnapshot(
        _ title: String,
        _ detail: String,
        _ date: Date,
        payload: HomeCardPayload = .none
    ) -> HomeCardSnapshot {
        HomeCardSnapshot(
            availability: .empty,
            title: title,
            detail: detail,
            payload: payload,
            updatedAt: date
        )
    }

    /// Overdue is the only state worth surfacing distinctly on Home — the rest
    /// is noise at glance size.
    private static func queueState(
        for task: PlanningTaskSummary,
        at date: Date
    ) -> HomeQueueItem.State {
        if let due = task.dueDate, due < date { return .overdue }
        switch task.metadata.availability {
        case .waiting, .paused: return .skipped
        case .actionable: return .pending
        }
    }

    private static func goalFraction(_ goal: GoalProgressSnapshot) -> Double {
        if let fraction = goal.progressFraction { return max(0, min(1, fraction)) }
        guard let current = goal.currentValue, let target = goal.targetValue, target > 0 else { return 0 }
        return max(0, min(1, current / target))
    }

    private func unavailableSnapshot(_ title: String, _ date: Date) -> HomeCardSnapshot {
        HomeCardSnapshot(
            availability: .unavailable,
            title: title,
            detail: "Unavailable right now.",
            updatedAt: date
        )
    }

    /// Reads the day's drift from `PlanStore`, which has already removed the
    /// repairs this person resolved.
    ///
    /// A failed load leaves `repairProposals` holding either the previous day's
    /// values or an unfiltered list, so a partial load must surface nothing at
    /// all. Absent is not zero drift, but the honest rendering of "we don't
    /// know" on the spine is the same as "nothing to show" — and it is far
    /// better than asking someone to repair a day we failed to read.
    private func rebuildDrift() {
        guard let planStore, planStore.errorMessage == nil, let snapshot = planSnapshot else {
            repairProposals = []
            driftCount = 0
            return
        }
        repairProposals = planStore.repairProposals
        driftCount = PlanDriftPolicy.default.surfacedCount(
            proposals: repairProposals,
            in: snapshot,
            now: Date()
        )
    }

    private func rebuildFocus() {
        guard let snapshot = planSnapshot else { focusTask = nil; focusResult = nil; return }
        let tasks = snapshot.plannedTasks + snapshot.unscheduledTasks
        let candidates = tasks.map { task in
            FocusRankCandidate(
                id: task.id,
                title: task.title,
                availability: task.metadata.availability,
                dependenciesReady: task.dependenciesReady,
                pinOrder: task.metadata.pinOrder,
                commitmentLevel: task.metadata.commitmentLevel,
                priority: task.metadata.commitmentLevel == .mustDo ? .urgent : .medium,
                planningDay: task.metadata.planningDay,
                dueDate: task.dueDate,
                estimatedDuration: task.estimatedDuration,
                planningContext: task.metadata.planningContext
            )
        }
        let results = rankingService.rank(
            candidates,
            context: FocusRankContext(
                freeWindowDuration: snapshot.capacity.remainingKnownCapacity,
                availableEnergy: latestMood?.energy,
                planningContext: nil
            )
        )
        guard let first = results.first(where: \.isEligible) else { focusTask = nil; focusResult = nil; return }
        focusResult = first
        focusTask = tasks.first { $0.id == first.candidateID }
    }

    private func rebuildHero(now: Date = Date()) {
        if let session = activeFocusSession, session.state == .running || session.state == .paused {
            heroSnapshot = .init(
                id: "active-focus:\(session.id.uuidString)", priority: .activeFocus,
                title: session.state == .paused ? "Focus is paused" : "Focus in progress",
                detail: "Your active session stays in control until you end it.",
                primaryActionTitle: session.state == .paused ? "Resume" : "Open focus",
                secondaryActionTitles: ["End"], sourceID: session.id, generatedAt: now
            )
            return
        }
        if let event = trackSnapshot?.unresolvedMedicationEvents.first(where: { $0.status == .unresolved }) {
            heroSnapshot = .init(
                id: "care:\(event.id.uuidString)", priority: .safetySensitiveCare,
                title: "A medication window needs a decision",
                detail: "Choose what happened. LifeBoard will not assume an outcome.",
                primaryActionTitle: "Review", secondaryActionTitles: ["Later"],
                sourceID: event.id, generatedAt: now
            )
            return
        }
        if let commitment = planSnapshot?.commitments
            .filter({ $0.endAt > now })
            .sorted(by: { $0.startAt < $1.startAt }).first {
            heroSnapshot = .init(
                id: "commitment:\(commitment.id)", priority: .fixedCommitment,
                title: commitment.startAt <= now ? commitment.title : "Next: \(commitment.title)",
                detail: commitment.startAt.formatted(date: .omitted, time: .shortened),
                primaryActionTitle: "Open day", sourceID: nil, generatedAt: now
            )
            return
        }
        if let mustDo = planSnapshot?.plannedTasks.first(where: { $0.metadata.commitmentLevel == .mustDo }) {
            heroSnapshot = .init(
                id: "must-do:\(mustDo.id.uuidString)", priority: .urgentPlannedWork,
                title: mustDo.title, detail: "Marked Must Do for today",
                primaryActionTitle: "Start", secondaryActionTitles: ["Why this?"],
                sourceID: mustDo.id, generatedAt: now
            )
            return
        }
        if let routine = trackSnapshot?.dueRoutines.first {
            heroSnapshot = .init(
                id: "routine:\(routine.id.uuidString)", priority: .timedRoutine,
                title: routine.title, detail: "Ready for this part of the day",
                primaryActionTitle: "Begin", sourceID: routine.id, generatedAt: now
            )
            return
        }
        if let task = focusTask {
            heroSnapshot = .init(
                id: "focus:\(task.id.uuidString)", priority: .generalFocus,
                title: task.title, detail: focusResult?.reasons.first?.text,
                primaryActionTitle: "Start", secondaryActionTitles: ["Why this?"],
                sourceID: task.id, generatedAt: now
            )
            return
        }
        heroSnapshot = .init(
            id: "choose-focus", priority: .generalFocus,
            title: "Choose one useful next step", detail: "Capture first; organize when you are ready.",
            primaryActionTitle: "Choose a focus", generatedAt: now
        )
    }
}

private struct ProjectionHomeCardProvider: HomeCardProvider {
    let definition: HomeCardDefinition
    let primaryDestination: LifeBoardDestination
    let privacyClassification: DataSensitivity
    private let snapshotBuilder: @MainActor @Sendable (HomeCardSize, Date) -> HomeCardSnapshot

    init(
        definition: HomeCardDefinition,
        destination: LifeBoardDestination,
        snapshotBuilder: @escaping @MainActor @Sendable (HomeCardSize, Date) -> HomeCardSnapshot
    ) {
        self.definition = definition
        primaryDestination = destination
        privacyClassification = definition.sensitivity
        self.snapshotBuilder = snapshotBuilder
    }

    func snapshot(
        configuration: HomeCardConfiguration,
        size: HomeCardSize,
        at date: Date
    ) async -> HomeCardSnapshot {
        await snapshotBuilder(size, date)
    }
}
