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
    #if DEBUG
    private var designFixtureDate: Date?

    /// Installs canonical projection values for explicit visual evidence runs.
    /// This does not load repositories or replace live mutation handlers.
    func installDesignFixture(date: Date, tasks: [PlanningTaskSummary], plan: PlanDaySnapshot,
                              track: TrackTodaySnapshot, hero: AdaptiveHeroSnapshot,
                              snapshots: [String: HomeCardSnapshot]) {
        designFixtureDate = date
        planningTasks = tasks
        taskAgendaDate = date
        taskAgenda = HomeTaskAgendaProjection(selectedDate: date, overdueTasks: [], dueTasks: tasks)
        planSnapshot = plan
        trackSnapshot = track
        heroSnapshot = hero
        focusTask = tasks.first
        cardSnapshots = snapshots
        hasLoadedCore = true
    }
    #endif

    var presentationDate: Date {
        #if DEBUG
        if let designFixtureDate { return designFixtureDate }
        #endif
        return HomeReferenceClock.now
    }

    private(set) var planSnapshot: PlanDaySnapshot?
    var taskAgendaDate: Date {
        didSet { rebuildTaskAgenda() }
    }

    /// Midnight passed (or the clock or time zone changed) while Home stayed
    /// open. The task list was showing "today", so it follows today; a day the
    /// person picked further away is left alone. Returns whether it moved.
    @discardableResult
    func rollAgendaToToday(now: Date = HomeReferenceClock.now, calendar: Calendar = .current) -> Bool {
        guard calendar.isDate(taskAgendaDate, inSameDayAs: now) == false else { return false }
        let start = calendar.startOfDay(for: now)
        let agendaStart = calendar.startOfDay(for: taskAgendaDate)
        let distance = abs(calendar.dateComponents([.day], from: agendaStart, to: start).day ?? 0)
        guard distance <= 1 else { return false }
        taskAgendaDate = now
        return true
    }
    private(set) var taskAgenda: HomeTaskAgendaProjection
    /// The task most recently completed from Home, and the reason its Undo
    /// control is offered. Cleared once taken back.
    private(set) var lastCompletedTask: PlanningTaskSummary?
    private(set) var trackSnapshot: TrackTodaySnapshot?
    /// Medication names by ID, read with the track snapshot.
    private(set) var medicationNames: [UUID: String] = [:]
    var focusTask: PlanningTaskSummary?
    var focusResult: FocusRankResult?
    private(set) var latestMood: MoodEnergyCheckInValue?
    private(set) var activeFast: FastingSessionValue?
    /// The most recently completed session anchors the open-window clock on
    /// Home. Keeping this beside `activeFast` means the signal never reaches
    /// into persistence from its TimelineView redraws.
    private(set) var latestEndedFast: FastingSessionValue?
    private(set) var recentMealAt: Date?
    var fastingMutationError: String?
    /// Set when completing, reopening, or undoing a task from Home fails, so
    /// the card can say so instead of leaving the row as it was.
    private(set) var taskMutationError: String?
    var fastEndUndoSession: FastingSessionValue?
    private(set) var activeFocusSession: FocusSessionV2?
    /// Today's repair proposals, already stripped of the ones the person
    /// resolved. Home reads these rather than recomputing from `planSnapshot`:
    /// resolving a repair with "leave today as it is" writes a receipt but does
    /// **not** change the snapshot, so a recompute would resurface a dismissed
    /// repair every time Home loaded, forever.
    var repairProposals: [PlanRepairProposal] = []
    /// How much drift is worth surfacing, per `PlanDriftPolicy`. Feeds the loop
    /// spine's stage resolution; `0` means the spine stays in `.act`.
    var driftCount: Int = 0
    var heroSnapshot: AdaptiveHeroSnapshot?
    private(set) var isLoading = false
    private(set) var hasLoadedCore = false
    @ObservationIgnored private var cardAuthorizationGeneration = 0
    @ObservationIgnored private var cardRefreshGeneration = 0
    var mutationRevision = 0
    private(set) var lastTaskMutationRefreshOutcome: ProjectionRefreshOutcome?
    @ObservationIgnored private let taskMutationRefresh = CommittedProjectionRefresh()
    @ObservationIgnored private let hydrationMutationRefresh = CommittedProjectionRefresh()
    @ObservationIgnored private let moodMutationRefresh = CommittedProjectionRefresh()
    // Protocol-only hosts still need revisions for writes owned by this screen.
    // External provider writes require a provider-level revision contract.
    @ObservationIgnored private var moodFallbackRevisions = SourceRevisionVector()
    @ObservationIgnored private var committedPresentationGeneration = 0
    @ObservationIgnored private var committedPresentationIsActive = true
    @ObservationIgnored private var lastHydrationRevision: UInt64?
    @ObservationIgnored private var lastHydrationDay: Date?
    @ObservationIgnored private(set) var hydrationReadCount = 0
    @ObservationIgnored private var hydrationSubscription: ProjectionInvalidationSubscription?
    @ObservationIgnored private var lastMoodRevision: UInt64?
    @ObservationIgnored private var lastMoodDay: Date?
    @ObservationIgnored private(set) var moodReadCount = 0
    @ObservationIgnored private var moodSubscription: ProjectionInvalidationSubscription?
    private(set) var hydrationObservationActive = false
    private(set) var hydrationRefreshError: String?
    private(set) var moodObservationActive = false
    private(set) var moodRefreshError: String?
    /// A second invalidation arriving during a load is folded into one more
    /// pass. Callers still await the completed pass, which prevents a card
    /// snapshot refresh from racing ahead of the canonical projections.
    @ObservationIgnored private(set) var loadCommitCount = 0
    /// Provider-resolved card snapshots keyed by "kind|size". Home widget
    /// bodies read these instead of reaching into domain snapshots directly.
    private(set) var cardSnapshots: [String: HomeCardSnapshot] = [:]
    /// App-only navigation metadata. Kept separate from Codable snapshots so
    /// record identifiers never cross into widgets or other system surfaces.
    private(set) var cardResolutions: [String: HomeCardResolution] = [:]
    @ObservationIgnored private var journalInvalidationTask: Task<Void, Never>?

    private let planningRepository: CoreDataPlanningRepository?
    private let trackRepository: CoreDataTrackFoundationRepository?
    private let projectionReader: HomeProjectionReader
    @ObservationIgnored var projectionFailures: Set<DashboardWidgetKind> = []
    @ObservationIgnored var planningTasks: [PlanningTaskSummary] = []
    @ObservationIgnored var loadedRepairProposals: [PlanRepairProposal] = []
    @ObservationIgnored private var lastCompletionReceiptID: UUID?
    private let phaseIIRepository: (any PhaseIIRepository)?
    let fastingTimerStore: FastingTimerStore?
    let rankingService: any FocusRankingService
    let wellnessRepository: (any WellnessRepository)?
    let nutritionRepository: (any NutritionRepository)?
    let lifeMomentRepository: (any LifeMomentRepository)?
    let healthMetrics: (any HealthMetricsReading)?

    init(
        planningRepository: CoreDataPlanningRepository?,
        trackRepository: CoreDataTrackFoundationRepository?,
        phaseIIRepository: (any PhaseIIRepository)?,
        goalSampleProvider: (any GoalSampleRepository)? = nil,
        wellnessRepository: (any WellnessRepository)? = nil,
        nutritionRepository: (any NutritionRepository)? = nil,
        lifeMomentRepository: (any LifeMomentRepository)? = nil,
        healthMetrics: (any HealthMetricsReading)? = nil,
        rankingService: any FocusRankingService = DeterministicFocusRankingService(),
        taskAgendaDate: Date = HomeReferenceClock.now,
        calendarRepository: any PlanningCalendarContextRepository = SystemPlanningCalendarContextRepository()
    ) {
        self.taskAgendaDate = taskAgendaDate
        self.taskAgenda = HomeTaskAgendaProjection.build(
            tasks: [],
            selectedDate: taskAgendaDate
        )
        self.planningRepository = planningRepository
        self.trackRepository = trackRepository
        projectionReader = HomeProjectionReader(planning: planningRepository, track: trackRepository,
            phaseII: phaseIIRepository, goalSamples: goalSampleProvider, calendarRepository: calendarRepository)
        self.phaseIIRepository = phaseIIRepository
        fastingTimerStore = phaseIIRepository.map {
            FastingTimerStore(repository: FastingRepositoryAdapter(repository: $0))
        }
        self.wellnessRepository = wellnessRepository
        self.nutritionRepository = nutritionRepository
        self.lifeMomentRepository = lifeMomentRepository
        self.healthMetrics = healthMetrics
        self.rankingService = rankingService
    }

    deinit {
        journalInvalidationTask?.cancel()
        hydrationSubscription?.cancel()
        moodSubscription?.cancel()
    }

    /// Journal saves invalidate derived projections through the pipeline hub.
    /// Home listens so journal-backed cards refresh without a manual pull.
    private func observeJournalInvalidationIfNeeded() {
        guard journalInvalidationTask == nil else { return }
        // Weak capture ends the subscription on the first event after this
        // store deallocates; the hub then drops the finished continuation.
        journalInvalidationTask = Task { [weak self] in
            let updates = await JournalProjectionInvalidationService.shared.updates()
            for await event in updates {
                guard case .projectionsInvalidated = event else { continue }
                guard let self else { return }
                await self.load()
            }
        }
    }

    func setContinuousUpdatesEnabled(_ enabled: Bool) {
        if enabled {
            observeJournalInvalidationIfNeeded()
        } else {
            journalInvalidationTask?.cancel()
            journalInvalidationTask = nil
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
        guard let planningRepository else { return false }
        do {
            let receipt = try await planningRepository.prepare(
                .setTaskCompletion(taskID: task.id, before: !isComplete, after: isComplete),
                source: "home.task.completion", summary: isComplete ? "Completed \(task.title)" : "Reopened \(task.title)")
            try await planningRepository.apply(receiptID: receipt.id)
            lastCompletionReceiptID = receipt.id
            lastCompletedTask = isComplete ? task : nil
            taskMutationError = nil
            mutationRevision &+= 1
            await refreshCommittedTaskAgenda(required: planningRepository.sourceRevisions.snapshot())
            return true
        } catch {
            taskMutationError = isComplete
                ? "Couldn\u{2019}t complete \u{201C}\(task.title)\u{201D}. Try again."
                : "Couldn\u{2019}t reopen \u{201C}\(task.title)\u{201D}. Try again."
            return false
        }
    }

    /// Reopens the task completed from Home.
    ///
    /// Plan's Undo control reads *its own* `PlanStore`, and Home holds a
    /// separate instance, so a completion made here was unreachable from that
    /// button. Home therefore owns a receipt of its own rather than leaving the
    /// most repeated mutation in the product one-way.
    func undoLastTaskCompletion() async {
        guard let planningRepository, let receiptID = lastCompletionReceiptID else { return }
        do {
            try await planningRepository.undo(receiptID: receiptID)
            lastCompletionReceiptID = nil
            lastCompletedTask = nil
            taskMutationError = nil
            mutationRevision &+= 1
            await refreshCommittedTaskAgenda(required: planningRepository.sourceRevisions.snapshot())
        } catch {
            taskMutationError = "Couldn\u{2019}t undo. The task is still complete."
        }
    }

    func retryTaskMutationRefresh() async {
        guard let planningRepository else { return }
        await refreshCommittedTaskAgenda(required: planningRepository.sourceRevisions.snapshot())
    }

    private func refreshCommittedTaskAgenda(required: SourceRevisionVector) async {
        guard committedPresentationIsActive, !Task.isCancelled else {
            lastTaskMutationRefreshOutcome = .cancelled
            return
        }
        let presentation = committedPresentationGeneration
        let mutation = mutationRevision
        let outcome = await taskMutationRefresh.run(required: required, domains: [.tasks]) { [weak self] in
            guard let self else { return .cancelled }
            do {
                // External writes may invalidate a suspended read. Retry fresh
                // core inputs without waiting for calendar or optional providers.
                for _ in 0..<3 {
                    let core = try await self.projectionReader.readCore()
                    guard !Task.isCancelled, presentation == self.committedPresentationGeneration else { return .cancelled }
                    guard let revision = core.sourceRevisions else {
                        return .failed(String(localized: "Couldn’t load tasks."))
                    }
                    guard self.sourceIsCurrent(revision, domains: [.tasks, .focus]) else { continue }
                    self.publishCore(core, now: HomeReferenceClock.now)
                    return .applied(revision)
                }
                return .failed(String(localized: "Tasks changed. Refresh again."))
            } catch { return .failed(error.localizedDescription) }
        }
        if mutation == mutationRevision { lastTaskMutationRefreshOutcome = outcome }
    }

    @ObservationIgnored private let refreshDrain = PresentationRefreshDrain()

    func load(isCurrent: @escaping @MainActor () -> Bool = { true }) async {
        await refreshDrain.run { [weak self] in
            guard let self else { return }
            self.isLoading = planSnapshot == nil && trackSnapshot == nil
            await self.performLoadPass(isCurrent: isCurrent)
            self.isLoading = false
        }
    }

    /// Publish canonical tasks and the active focus session as soon as they are
    /// available. Calendar capacity, Track and meal providers complete separately;
    /// each publication validates the same refresh and mutation ownership.
    private func performLoadPass(now: Date = HomeReferenceClock.now, isCurrent: @escaping @MainActor () -> Bool) async {
        let mutation = mutationRevision
        let revision = refreshDrain.revision
        async let canonical = projectionReader.read(now: now, onCore: { [weak self] core in
            guard let self, !Task.isCancelled, isCurrent(),
                  mutation == self.mutationRevision, revision == self.refreshDrain.revision else { return }
            self.publishCore(core, now: now)
        }, onPlan: { [weak self] inputs in
            guard let self, !Task.isCancelled, isCurrent(),
                  mutation == self.mutationRevision, revision == self.refreshDrain.revision else { return }
            self.publishPlan(inputs, now: now)
        }, onTrack: { [weak self] inputs in
            guard let self, !Task.isCancelled, isCurrent(),
                  mutation == self.mutationRevision, revision == self.refreshDrain.revision else { return }
            self.publishTrack(inputs, now: now)
        })
        async let fastingSessions: Void = loadFasting(now: now, mutation: mutation, revision: revision, isCurrent: isCurrent)
        async let localMealAt = fetchRecentLocalMeal(now: now)
        async let externalMealAt = fetchRecentExternalMeal(now: now)

        let (inputs, _, localMeal, externalMeal) = await (
            canonical,
            fastingSessions,
            localMealAt,
            externalMealAt
        )
        guard !Task.isCancelled, isCurrent(), mutation == mutationRevision,
              revision == refreshDrain.revision else { return }

        projectionFailures.subtract([.focusNow, .tasks, .scheduleCapacity, .compactTimeline, .lifeSnapshot])
        if inputs.trackFailed { projectionFailures.insert(.lifeSnapshot) }
        if inputs.planFailed { projectionFailures.formUnion([.focusNow, .tasks, .scheduleCapacity, .compactTimeline, .lifeSnapshot]) }
        let previousHero = heroSnapshot
        let previousAgenda = taskAgenda
        let previousRepairs = repairProposals
        let before = HomeProjectionCandidate(plan: planSnapshot, track: trackSnapshot, mood: latestMood,
            fast: activeFast, endedFast: latestEndedFast, meal: recentMealAt, focus: activeFocusSession)
        let nextMealAt = HealthFastingSuggestion.latestStart(
            localMealAt: localMeal,
            externalDietaryEnergyAt: externalMeal
        )
        if recentMealAt != nextMealAt { recentMealAt = nextMealAt }
        rebuildTaskAgenda()
        rebuildDrift(now: now)
        rebuildFocus()
        rebuildHero(now: now)
        let after = HomeProjectionCandidate(plan: planSnapshot, track: trackSnapshot, mood: latestMood,
            fast: activeFast, endedFast: latestEndedFast, meal: recentMealAt, focus: activeFocusSession)
        if before != after || previousHero != heroSnapshot || previousAgenda != taskAgenda || previousRepairs != repairProposals {
            loadCommitCount &+= 1
            PerformanceTrace.event("HomeProjectionCommitted", value: loadCommitCount)
        }
    }

    private func publishTrack(_ inputs: HomeProjectionInputs, now: Date) {
        let kinds: Set<DashboardWidgetKind> = [.care, .routines, .goals, .journal, .progressReflection, .lifeSnapshot]
        if inputs.trackFailed { projectionFailures.formUnion(kinds); return }
        guard var next = inputs.track,
              revisionsAreCurrent(inputs.trackSourceRevisions, ledger: trackRepository?.sourceRevisions,
                                  domains: [.tracking, .goals, .routines]),
              revisionsAreCurrent(inputs.moodSourceRevisions, ledger: moodRevisionLedger,
                                  domains: [.wellness]) else { return }
        projectionFailures.subtract(kinds)
        lastHydrationRevision = inputs.trackSourceRevisions?[.tracking]
        lastHydrationDay = Calendar.current.startOfDay(for: now)
        lastMoodRevision = inputs.moodSourceRevisions?[.wellness]
        lastMoodDay = Calendar.current.startOfDay(for: now)
        if let current = trackSnapshot {
            var comparable = next
            comparable.generatedAt = current.generatedAt
            if comparable == current { next = current }
        }
        let previousHero = heroSnapshot
        let previousFocus = focusResult
        let changed = trackSnapshot != next || latestMood != inputs.mood || hydrationRefreshError != nil
        hydrationRefreshError = nil
        if trackSnapshot != next { trackSnapshot = next }
        if inputs.medicationNames.isEmpty == false, medicationNames != inputs.medicationNames {
            medicationNames = inputs.medicationNames
        }
        if latestMood != inputs.mood { latestMood = inputs.mood }
        rebuildFocus()
        rebuildHero(now: now)
        if changed || previousHero != heroSnapshot || previousFocus != focusResult {
            loadCommitCount &+= 1
            PerformanceTrace.event("HomeProjectionCommitted", value: loadCommitCount)
        }
    }

    private func loadFasting(now: Date, mutation: Int, revision: UInt64,
                             isCurrent: @escaping @MainActor () -> Bool) async {
        let result = await fetchFastingSessions()
        guard !Task.isCancelled, isCurrent(), mutation == mutationRevision,
              revision == refreshDrain.revision else { return }
        guard let sessions = result else { projectionFailures.insert(.fasting); return }
        projectionFailures.remove(.fasting)
        let nextActiveFast = sessions
            .filter { $0.endedAt == nil }
            .max { $0.startedAt < $1.startedAt }
        let nextEndedFast = sessions
            .filter { $0.endedAt != nil }
            .max { ($0.endedAt ?? .distantPast) < ($1.endedAt ?? .distantPast) }
        let previousHero = heroSnapshot
        let changed = activeFast != nextActiveFast || latestEndedFast != nextEndedFast
        if activeFast != nextActiveFast { activeFast = nextActiveFast }
        if latestEndedFast != nextEndedFast { latestEndedFast = nextEndedFast }
        rebuildHero(now: now)
        if changed || previousHero != heroSnapshot {
            loadCommitCount &+= 1
            PerformanceTrace.event("HomeProjectionCommitted", value: loadCommitCount)
        }
    }

    private func publishPlan(_ inputs: HomeProjectionInputs, now: Date) {
        guard inputs.plan != nil,
              sourceIsCurrent(inputs.sourceRevisions, domains: [.tasks, .planning, .focus]) else { return }
        var nextPlanSnapshot = inputs.plan
        if var value = nextPlanSnapshot, let current = planSnapshot {
            value.generatedAt = current.generatedAt
            if case .fresh = value.calendarState, case .fresh = current.calendarState {
                value.calendarState = current.calendarState
            }
            if value == current { nextPlanSnapshot = current }
        }
        let previousPlan = planSnapshot
        let previousHero = heroSnapshot
        let previousRepairs = repairProposals
        let previousFocusTask = focusTask
        let previousFocusResult = focusResult
        if planSnapshot != nextPlanSnapshot { planSnapshot = nextPlanSnapshot }
        loadedRepairProposals = inputs.repairs ?? loadedRepairProposals
        rebuildDrift(now: now)
        rebuildFocus()
        rebuildHero(now: now)
        if previousPlan != planSnapshot || previousHero != heroSnapshot || previousRepairs != repairProposals
            || previousFocusTask != focusTask || previousFocusResult != focusResult {
            loadCommitCount &+= 1
            PerformanceTrace.event("HomeProjectionCommitted", value: loadCommitCount)
        }
    }

    private func sourceIsCurrent(_ captured: SourceRevisionVector?, domains: Set<ProjectionDomain>) -> Bool {
        guard let captured, let planningRepository else { return true }
        return captured.matches(planningRepository.sourceRevisions.snapshot(), domains: domains)
    }

    private var moodRevisionLedger: ProjectionRevisionLedger? {
        (phaseIIRepository as? CoreDataLifeBoardPhaseIIRepository)?.sourceRevisions
    }

    private func revisionsAreCurrent(_ captured: SourceRevisionVector?, ledger: ProjectionRevisionLedger?,
                                     domains: Set<ProjectionDomain>) -> Bool {
        guard let captured, let ledger else { return true }
        return captured.matches(ledger.snapshot(), domains: domains)
    }

    private func publishCore(_ core: HomeCoreProjectionInputs, now: Date) {
        guard sourceIsCurrent(core.sourceRevisions, domains: [.tasks, .focus]) else { return }
        guard !hasLoadedCore || planningTasks != core.tasks || activeFocusSession != core.focus else { return }
        let previousAgenda = taskAgenda
        let previousFocus = activeFocusSession
        let previousRank = focusResult
        let previousTask = focusTask
        let previousHero = heroSnapshot
        planningTasks = core.tasks
        activeFocusSession = core.focus
        rebuildTaskAgenda()
        rebuildFocus()
        rebuildHero(now: now)
        if !hasLoadedCore {
            hasLoadedCore = true
            PerformanceTrace.event("HomeCoreContentReady", value: core.tasks.count)
        }
        if previousAgenda != taskAgenda || previousFocus != activeFocusSession || previousHero != heroSnapshot
            || previousRank != focusResult || previousTask != focusTask {
            loadCommitCount &+= 1
            PerformanceTrace.event("HomeProjectionCommitted", value: loadCommitCount)
        }
    }

    private func fetchFastingSessions() async -> [FastingSessionValue]? {
        guard let phaseIIRepository else { return [] }
        return try? await phaseIIRepository.fetchFastingSessions(limit: 30)
    }

    private func fetchRecentLocalMeal(now: Date) async -> Date? {
        guard let nutritionRepository else { return nil }
        let oneDayAgo = now.addingTimeInterval(-HomeFastingAnchorPolicy.recentMealWindow)
        return try? await nutritionRepository
            .logs(from: oneDayAgo, to: now.addingTimeInterval(1))
            .first?
            .loggedAt
    }

    private func fetchRecentExternalMeal(now: Date) async -> Date? {
        await healthMetrics?
            .currentSnapshot(now: now)
            .aggregates[.dietaryEnergy]?
            .lastSampleAt
    }

    func resetTaskAgendaDateToToday(now: Date = HomeReferenceClock.now) {
        taskAgendaDate = now
    }

    private func rebuildTaskAgenda(calendar: Calendar = .current) {
        let next = HomeTaskAgendaProjection.build(
            tasks: planningTasks,
            selectedDate: taskAgendaDate,
            calendar: calendar
        )
        if taskAgenda != next { taskAgenda = next }
    }

    @discardableResult
    func saveMood(_ mood: JournalMood, energy: Int?) async -> ProjectionRefreshOutcome {
        guard let phaseIIRepository else { return .failed(String(localized: "Couldn’t load check-ins.")) }
        do {
            try await phaseIIRepository.saveMoodCheckIn(.init(mood: mood, energy: energy))
            if moodRevisionLedger == nil { moodFallbackRevisions.advance([.wellness]) }
            mutationRevision &+= 1
            return await refreshCommittedMood()
        } catch { return .failed(error.localizedDescription) }
    }

    /// Refreshing after a successful save never repeats that save.
    func refreshCommittedMood() async -> ProjectionRefreshOutcome {
        guard committedPresentationIsActive, !Task.isCancelled else { return .cancelled }
        let presentation = committedPresentationGeneration
        let required = moodRevisionLedger?.snapshot() ?? moodFallbackRevisions
        return await moodMutationRefresh.run(required: required, domains: [.wellness]) { [weak self] in
            guard let self else { return .cancelled }
            do {
                for _ in 0..<3 {
                    let fallback = self.moodFallbackRevisions
                    self.moodReadCount &+= 1
                    PerformanceTrace.event("HomeMoodRead", value: self.moodReadCount)
                    let input = try await self.projectionReader.readMood(now: HomeReferenceClock.now)
                    guard !Task.isCancelled, presentation == self.committedPresentationGeneration else { return .cancelled }
                    guard input.revisions != nil || fallback == self.moodFallbackRevisions else { continue }
                    guard self.revisionsAreCurrent(input.revisions, ledger: self.moodRevisionLedger,
                                                   domains: [.wellness]) else { continue }
                    let previousHero = self.heroSnapshot
                    let previousFocus = self.focusResult
                    let changed = self.latestMood != input.value
                    if changed { self.latestMood = input.value }
                    self.rebuildFocus()
                    self.rebuildHero(now: HomeReferenceClock.now)
                    if changed || previousHero != self.heroSnapshot || previousFocus != self.focusResult {
                        self.loadCommitCount &+= 1
                        PerformanceTrace.event("HomeProjectionCommitted", value: self.loadCommitCount)
                    }
                    self.lastMoodRevision = input.revisions?[.wellness] ?? fallback[.wellness]
                    self.lastMoodDay = Calendar.current.startOfDay(for: HomeReferenceClock.now)
                    self.moodRefreshError = nil
                    return .applied(input.revisions ?? fallback)
                }
                return .failed(String(localized: "Mood saved. Couldn’t refresh check-ins."))
            } catch { return .failed(String(localized: "Couldn’t refresh mood. \(error.localizedDescription)")) }
        }
    }

    /// Covers shared mood saves from Journal, Track, Eva and shortcuts on the
    /// same persistence coordinator. The writer remains independent of Home.
    func observeCommittedMoodChanges() async {
        guard !Task.isCancelled else { return }
        activateCommittedProjectionWork()
        guard let repository = moodRevisionLedger else { return }
        let presentation = committedPresentationGeneration
        let subscription = repository.subscribe(recordKinds: [.mood])
        moodSubscription = subscription
        moodObservationActive = true
        defer {
            subscription.cancel()
            if presentation == committedPresentationGeneration {
                moodSubscription = nil
                moodObservationActive = false
            }
        }
        for await _ in subscription.wakes {
            guard !Task.isCancelled, presentation == committedPresentationGeneration else { return }
            guard let event = subscription.takePending() else { continue }
            if let revision = lastMoodRevision, revision >= event.revisions[.wellness],
               lastMoodDay == Calendar.current.startOfDay(for: HomeReferenceClock.now) { continue }
            let outcome = await refreshCommittedMood()
            guard !Task.isCancelled, presentation == committedPresentationGeneration else { return }
            if case .failed(let message) = outcome, moodRefreshError != message {
                moodRefreshError = message
                loadCommitCount &+= 1
                PerformanceTrace.event("HomeProjectionCommitted", value: loadCommitCount)
            }
        }
    }

    /// Fallback mood read for configurations without a Track store. Keeps the
    /// Home view from querying repositories directly.
    func latestMoodCheckInToday() async -> MoodEnergyCheckInValue? {
        if let latestMood { return latestMood }
        guard let phaseIIRepository else { return nil }
        let start = Calendar.current.startOfDay(for: HomeReferenceClock.now)
        let values = try? await phaseIIRepository.fetchMoodCheckIns(from: start, to: HomeReferenceClock.now.addingTimeInterval(1))
        return values?.first
    }

    nonisolated static func cardSnapshotKey(_ kind: DashboardWidgetKind, _ size: HomeCardSize) -> String {
        "\(kind.rawValue)|\(size.rawValue)"
    }

    func cardSnapshot(kind: DashboardWidgetKind, size: HomeCardSize) -> HomeCardSnapshot? {
        cardSnapshots[Self.cardSnapshotKey(kind, size)]
    }

    func cardResolution(kind: DashboardWidgetKind, size: HomeCardSize) -> HomeCardResolution? {
        cardResolutions[Self.cardSnapshotKey(kind, size)]
    }

    /// Resolves display-ready snapshots for the requested kind/size pairs
    /// through the domain provider registry. Home calls this after `load()`
    /// and at meaningful refresh boundaries; card bodies never read canonical
    /// domain state themselves.
    func refreshCardSnapshots(
        requests: [(kind: DashboardWidgetKind, size: HomeCardSize)],
        permitsSensitive: Bool,
        at date: Date = HomeReferenceClock.now,
        isCurrent: @escaping @MainActor () -> Bool = { true },
        providerRegistry: HomeCardProviderRegistry? = nil
    ) async {
        cardRefreshGeneration &+= 1
        let refresh = cardRefreshGeneration
        let authorization = cardAuthorizationGeneration
        guard !Task.isCancelled, isCurrent() else { return }
        var uniqueKeys: Set<String> = []
        let requests = requests.filter { uniqueKeys.insert(Self.cardSnapshotKey($0.kind, $0.size)).inserted }
        let requestedSizes = Dictionary(grouping: requests, by: \.kind).mapValues { Set($0.map(\.size)) }
        guard let registry = providerRegistry ?? (try? makeHomeCardProviderRegistry(at: date, requestedSizes: requestedSizes)) else { return }
        var permitted: Set<DataSensitivity> = [.privateStandard, .shareEligible]
        if permitsSensitive { permitted.insert(.privateSensitive) }
        let requestedKeys = Set(requests.map { Self.cardSnapshotKey($0.kind, $0.size) })
        var resolved = cardResolutions.filter { requestedKeys.contains($0.key) }
        let permissions = permitted
        await withTaskGroup(of: (String, HomeCardResolution?).self) { group in
            var iterator = requests.makeIterator()
            func enqueue(_ request: (kind: DashboardWidgetKind, size: HomeCardSize)) {
                let key = Self.cardSnapshotKey(request.kind, request.size)
                group.addTask {
                    let context = HomeCardSnapshotContext(date: date, semanticSize: request.size, permittedSensitivities: permissions)
                    return (key, try? await registry.resolution(for: request.kind, context: context))
                }
            }
            for _ in 0..<4 { if let request = iterator.next() { enqueue(request) } }
            while let (key, resolution) = await group.next() {
                guard !Task.isCancelled, isCurrent(), refresh == cardRefreshGeneration,
                      authorization == cardAuthorizationGeneration else {
                    group.cancelAll()
                    return
                }
                if var resolution {
                    if let previous = resolved[key], previous.snapshot.availability != .redacted,
                       (resolution.snapshot.availability == .unavailable ||
                        (resolution.snapshot.availability == .degraded && resolution.snapshot.value == nil && resolution.snapshot.payload.isEmpty)) {
                        let failureDetail = resolution.snapshot.detail
                        resolution = previous
                        resolution.snapshot.availability = .degraded
                        resolution.snapshot.detail = failureDetail ?? String(localized: "Couldn’t refresh. Showing last update.")
                    }
                    if resolved[key]?.hasSamePresentation(as: resolution) != true { resolved[key] = resolution }
                } else if var previous = resolved[key], previous.snapshot.availability != .redacted {
                    previous.snapshot.availability = .degraded
                    previous.snapshot.detail = String(localized: "Couldn’t refresh. Showing last update.")
                    resolved[key] = previous
                }
                publishCardResolutions(resolved)
                if let request = iterator.next() { enqueue(request) }
            }
        }
        guard !Task.isCancelled, isCurrent(), refresh == cardRefreshGeneration,
              authorization == cardAuthorizationGeneration else { return }
        publishCardResolutions(resolved)
    }

    private func publishCardResolutions(_ resolved: [String: HomeCardResolution]) {
        if cardResolutions != resolved {
            cardResolutions = resolved
            cardSnapshots = resolved.mapValues(\.snapshot)
            PerformanceTrace.event("HomeCardPresentationCommitted")
        }
    }

    func invalidateCardPrivacy() {
        cardAuthorizationGeneration &+= 1
        cardSnapshots = [:]
        cardResolutions = [:]
    }

    @discardableResult
    func quickAddHydration(_ milliliters: Double) async -> ProjectionRefreshOutcome {
        guard let trackRepository else { return .failed(String(localized: "Couldn’t load water.")) }
        do {
            try await trackRepository.saveHydrationLog(.init(amount: milliliters, unit: .milliliters))
            mutationRevision &+= 1
            return await refreshCommittedHydration()
        } catch { return .failed(error.localizedDescription) }
    }

    func refreshCommittedHydration() async -> ProjectionRefreshOutcome {
        guard committedPresentationIsActive, !Task.isCancelled else { return .cancelled }
        let presentation = committedPresentationGeneration
        guard let trackRepository else { return .failed(String(localized: "Couldn’t load water.")) }
        let required = trackRepository.sourceRevisions.snapshot()
        return await hydrationMutationRefresh.run(required: required, domains: [.tracking]) { [weak self] in
            guard let self else { return .cancelled }
            do {
                for _ in 0..<3 {
                    self.hydrationReadCount &+= 1
                    PerformanceTrace.event("HomeHydrationRead", value: self.hydrationReadCount)
                    let input = try await self.projectionReader.readHydration(now: HomeReferenceClock.now)
                    guard !Task.isCancelled, presentation == self.committedPresentationGeneration else { return .cancelled }
                    guard input.day == Calendar.current.startOfDay(for: HomeReferenceClock.now) else { continue }
                    guard self.revisionsAreCurrent(input.revisions, ledger: trackRepository.sourceRevisions,
                                                   domains: [.tracking]) else { continue }
                    // A first hydration action can finish before the other Track
                    // inputs. Preserve existing content and mark a new shell partial.
                    var next = self.trackSnapshot ?? TrackTodaySnapshot(unresolvedMedicationEvents: [],
                        habitGrades: [], dueRoutines: [], goals: [], hydrationAmountMilliliters: nil,
                        hydrationTargetMilliliters: nil, completeness: .partial, generatedAt: HomeReferenceClock.now)
                    next.hydrationAmountMilliliters = input.amount
                    next.hydrationTargetMilliliters = input.target
                    let changed = self.trackSnapshot != next || self.hydrationRefreshError != nil
                    if self.trackSnapshot != next {
                        next.generatedAt = HomeReferenceClock.now
                        self.trackSnapshot = next
                        self.rebuildHero(now: HomeReferenceClock.now)
                    }
                    if changed {
                        self.loadCommitCount &+= 1
                        PerformanceTrace.event("HomeProjectionCommitted", value: self.loadCommitCount)
                    }
                    self.lastHydrationRevision = input.revisions[.tracking]
                    self.lastHydrationDay = input.day
                    self.hydrationRefreshError = nil
                    return .applied(input.revisions)
                }
                return .failed(String(localized: "Water changed. Refresh again."))
            } catch { return .failed(String(localized: "Couldn’t refresh water. \(error.localizedDescription)")) }
        }
    }

    /// Covers saves from the shared water composer, Track, Eva, shortcuts and
    /// external contexts without making those writers own Home's presentation.
    func observeCommittedHydrationChanges() async {
        guard !Task.isCancelled else { return }
        activateCommittedProjectionWork()
        guard let trackRepository else { return }
        let presentation = committedPresentationGeneration
        let subscription = trackRepository.sourceRevisions.subscribe(recordKinds: [.hydration])
        hydrationSubscription = subscription
        hydrationObservationActive = true
        defer {
            subscription.cancel()
            if presentation == committedPresentationGeneration {
                hydrationSubscription = nil
                hydrationObservationActive = false
            }
        }
        for await _ in subscription.wakes {
            guard !Task.isCancelled, presentation == committedPresentationGeneration else { return }
            guard let event = subscription.takePending() else { continue }
            if let revision = lastHydrationRevision, revision >= event.revisions[.tracking],
               lastHydrationDay == Calendar.current.startOfDay(for: HomeReferenceClock.now) { continue }
            let outcome = await refreshCommittedHydration()
            guard !Task.isCancelled, presentation == committedPresentationGeneration else { return }
            if case .failed(let message) = outcome, hydrationRefreshError != message {
                hydrationRefreshError = message
                loadCommitCount &+= 1
                PerformanceTrace.event("HomeProjectionCommitted", value: loadCommitCount)
            }
        }
    }

    func beginCommittedProjectionWork() {
        stopCommittedProjectionWork()
        committedPresentationIsActive = true
    }

    private func activateCommittedProjectionWork() {
        if !committedPresentationIsActive {
            committedPresentationGeneration &+= 1
            committedPresentationIsActive = true
        }
    }

    /// Stops presentation only. Durable saves, Health outbox delivery, reminders
    /// and canonical timers continue under their existing domain owners.
    func stopCommittedProjectionWork() {
        committedPresentationGeneration &+= 1
        committedPresentationIsActive = false
        hydrationSubscription?.cancel()
        hydrationSubscription = nil
        hydrationObservationActive = false
        moodSubscription?.cancel()
        moodSubscription = nil
        moodObservationActive = false
        taskMutationRefresh.cancel()
        moodMutationRefresh.cancel()
        hydrationMutationRefresh.cancel()
    }
}
