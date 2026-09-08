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
    private(set) var latestMood: MoodEnergyCheckInValue?
    private(set) var activeFast: FastingSessionValue?
    /// The most recently completed session anchors the open-window clock on
    /// Home. Keeping this beside `activeFast` means the signal never reaches
    /// into persistence from its TimelineView redraws.
    private(set) var latestEndedFast: FastingSessionValue?
    private(set) var recentMealAt: Date?
    private(set) var fastingMutationError: String?
    private var fastEndUndoSession: FastingSessionValue?
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
    private(set) var hasLoadedCore = false
    @ObservationIgnored private var cardAuthorizationGeneration = 0
    @ObservationIgnored private var cardRefreshGeneration = 0
    private(set) var mutationRevision = 0
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
    private(set) var hydrationObservationActive = false
    private(set) var hydrationRefreshError: String?
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
    @ObservationIgnored private var projectionFailures: Set<DashboardWidgetKind> = []
    @ObservationIgnored private var planningTasks: [PlanningTaskSummary] = []
    @ObservationIgnored private var loadedRepairProposals: [PlanRepairProposal] = []
    @ObservationIgnored private var lastCompletionReceiptID: UUID?
    private let phaseIIRepository: (any PhaseIIRepository)?
    private let fastingTimerStore: FastingTimerStore?
    private let rankingService: any FocusRankingService
    private let wellnessRepository: (any WellnessRepository)?
    private let nutritionRepository: (any NutritionRepository)?
    private let lifeMomentRepository: (any LifeMomentRepository)?
    private let healthMetrics: (any HealthMetricsReading)?

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
        taskAgendaDate: Date = Date(),
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

    deinit { journalInvalidationTask?.cancel(); hydrationSubscription?.cancel() }

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
            mutationRevision &+= 1
            await refreshCommittedTaskAgenda(required: planningRepository.sourceRevisions.snapshot())
            return true
        } catch { return false }
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
            mutationRevision &+= 1
            await refreshCommittedTaskAgenda(required: planningRepository.sourceRevisions.snapshot())
        } catch { return }
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
                        return .failed("Task projection is unavailable.")
                    }
                    guard self.sourceIsCurrent(revision, domains: [.tasks, .focus]) else { continue }
                    self.publishCore(core, now: Date())
                    return .applied(revision)
                }
                return .failed("Tasks changed while refreshing. Refresh again to see the latest changes.")
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
    private func performLoadPass(now: Date = Date(), isCurrent: @escaping @MainActor () -> Bool) async {
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

    func resetTaskAgendaDateToToday(now: Date = Date()) {
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
        guard let phaseIIRepository else { return .failed("Mood check-ins are unavailable.") }
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
                    let input = try await self.projectionReader.readMood(now: Date())
                    guard !Task.isCancelled, presentation == self.committedPresentationGeneration else { return .cancelled }
                    guard input.revisions != nil || fallback == self.moodFallbackRevisions else { continue }
                    guard self.revisionsAreCurrent(input.revisions, ledger: self.moodRevisionLedger,
                                                   domains: [.wellness]) else { continue }
                    let previousHero = self.heroSnapshot
                    let previousFocus = self.focusResult
                    let changed = self.latestMood != input.value
                    if changed { self.latestMood = input.value }
                    self.rebuildFocus()
                    self.rebuildHero(now: Date())
                    if changed || previousHero != self.heroSnapshot || previousFocus != self.focusResult {
                        self.loadCommitCount &+= 1
                        PerformanceTrace.event("HomeProjectionCommitted", value: self.loadCommitCount)
                    }
                    return .applied(input.revisions ?? fallback)
                }
                return .failed("Your mood was saved, but the latest check-in could not be refreshed. Try refreshing again.")
            } catch { return .failed("Your mood was saved. Refresh unavailable: \(error.localizedDescription)") }
        }
    }

    /// Fallback mood read for configurations without a Track store. Keeps the
    /// Home view from querying repositories directly.
    func latestMoodCheckInToday() async -> MoodEnergyCheckInValue? {
        if let latestMood { return latestMood }
        guard let phaseIIRepository else { return nil }
        let start = Calendar.current.startOfDay(for: Date())
        let values = try? await phaseIIRepository.fetchMoodCheckIns(from: start, to: Date().addingTimeInterval(1))
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
        at date: Date = Date(),
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
                        resolution.snapshot.detail = failureDetail ?? "Refresh unavailable. Showing the last available information."
                    }
                    if resolved[key]?.hasSamePresentation(as: resolution) != true { resolved[key] = resolution }
                } else if var previous = resolved[key], previous.snapshot.availability != .redacted {
                    previous.snapshot.availability = .degraded
                    previous.snapshot.detail = "Refresh unavailable. Showing the last available information."
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
        guard let trackRepository else { return .failed("Hydration is unavailable.") }
        do {
            try await trackRepository.saveHydrationLog(.init(amount: milliliters, unit: .milliliters))
            mutationRevision &+= 1
            return await refreshCommittedHydration()
        } catch { return .failed(error.localizedDescription) }
    }

    func refreshCommittedHydration() async -> ProjectionRefreshOutcome {
        guard committedPresentationIsActive, !Task.isCancelled else { return .cancelled }
        let presentation = committedPresentationGeneration
        guard let trackRepository else { return .failed("Hydration is unavailable.") }
        let required = trackRepository.sourceRevisions.snapshot()
        return await hydrationMutationRefresh.run(required: required, domains: [.tracking]) { [weak self] in
            guard let self else { return .cancelled }
            do {
                for _ in 0..<3 {
                    self.hydrationReadCount &+= 1
                    PerformanceTrace.event("HomeHydrationRead", value: self.hydrationReadCount)
                    let input = try await self.projectionReader.readHydration(now: Date())
                    guard !Task.isCancelled, presentation == self.committedPresentationGeneration else { return .cancelled }
                    guard input.day == Calendar.current.startOfDay(for: Date()) else { continue }
                    guard self.revisionsAreCurrent(input.revisions, ledger: trackRepository.sourceRevisions,
                                                   domains: [.tracking]) else { continue }
                    // A first hydration action can finish before the other Track
                    // inputs. Preserve existing content and mark a new shell partial.
                    var next = self.trackSnapshot ?? TrackTodaySnapshot(unresolvedMedicationEvents: [],
                        habitGrades: [], dueRoutines: [], goals: [], hydrationAmountMilliliters: nil,
                        hydrationTargetMilliliters: nil, completeness: .partial, generatedAt: Date())
                    next.hydrationAmountMilliliters = input.amount
                    next.hydrationTargetMilliliters = input.target
                    let changed = self.trackSnapshot != next || self.hydrationRefreshError != nil
                    if self.trackSnapshot != next {
                        next.generatedAt = Date()
                        self.trackSnapshot = next
                        self.rebuildHero(now: Date())
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
                return .failed("Hydration changed while refreshing. Refresh again to see the latest total.")
            } catch { return .failed("Water totals could not be refreshed: \(error.localizedDescription)") }
        }
    }

    /// Covers saves from the shared water composer, Track, Eva, shortcuts and
    /// external contexts without making those writers own Home's presentation.
    func observeCommittedHydrationChanges() async {
        guard !Task.isCancelled else { return }
        beginCommittedProjectionWork()
        guard let trackRepository else { return }
        let presentation = committedPresentationGeneration
        let subscription = trackRepository.sourceRevisions.subscribe(recordKinds: [.hydration])
        hydrationSubscription = subscription
        hydrationObservationActive = true
        defer {
            subscription.cancel()
            if presentation == committedPresentationGeneration { stopCommittedProjectionWork() }
        }
        for await _ in subscription.wakes {
            guard !Task.isCancelled, presentation == committedPresentationGeneration else { return }
            guard let event = subscription.takePending() else { continue }
            if let revision = lastHydrationRevision, revision >= event.revisions[.tracking],
               lastHydrationDay == Calendar.current.startOfDay(for: Date()) { continue }
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

    /// Stops presentation only. Durable saves, Health outbox delivery, reminders
    /// and canonical timers continue under their existing domain owners.
    func stopCommittedProjectionWork() {
        committedPresentationGeneration &+= 1
        committedPresentationIsActive = false
        hydrationSubscription?.cancel()
        hydrationSubscription = nil
        hydrationObservationActive = false
        taskMutationRefresh.cancel()
        moodMutationRefresh.cancel()
        hydrationMutationRefresh.cancel()
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
            mutationRevision &+= 1
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
            mutationRevision &+= 1
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
            mutationRevision &+= 1
            return true
        } catch {
            fastingMutationError = error.localizedDescription
            return false
        }
    }

    /// Home renders only these display-ready projections. The provider registry
    /// is deliberately assembled at the domain boundary so card views do not
    /// know which repositories produced the values.
    func makeHomeCardProviderRegistry(at date: Date = Date(),
        requestedSizes: [DashboardWidgetKind: Set<HomeCardSize>]? = nil) throws -> HomeCardProviderRegistry {
        let registry = DefaultDashboardWidgetRegistry.shared
        let kinds: [(DashboardWidgetKind, Destination)] = [
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
        var providers: [any HomeCardSource] = kinds.compactMap { kind, destination in
            guard requestedSizes == nil || requestedSizes?[kind] != nil,
                  let definition = registry.descriptor(for: kind) else { return nil }
            let sizes = definition.supportedSizes.filter { requestedSizes?[kind]?.contains($0) ?? true }
            let snapshots = Dictionary(uniqueKeysWithValues: sizes.map { size in
                var snapshot = homeCardSnapshot(kind: kind, size: size, date: date)
                if projectionFailures.contains(kind) {
                    snapshot.availability = .degraded
                    snapshot.detail = "Refresh unavailable. Showing the last available information."
                }
                return (size, snapshot)
            })
            let route = homeCardPrimaryRoute(kind: kind)
            return ProjectionHomeCardSource(
                definition: definition,
                destination: destination,
                snapshotBuilder: { size, date in
                    snapshots[size] ?? HomeCardSnapshot(availability: .unavailable, title: "Unavailable", updatedAt: date)
                },
                routeBuilder: { route }
            )
        }
        if let wellnessRepository {
            let focuses: [(DashboardWidgetKind, WellnessHomeCardFocus)] = [
                (.bodyMetric, .bodyMetric(.bodyMass)), (.workout, .workouts), (.sleep, .sleep), (.movement, .movement)
            ]
            providers += focuses.compactMap { kind, focus -> (any HomeCardSource)? in
                guard requestedSizes == nil || requestedSizes?[kind] != nil else { return nil }
                return registry.descriptor(for: kind).map {
                    WellnessHomeCardSource(
                        definition: $0,
                        focus: focus,
                        repository: wellnessRepository,
                        healthMetrics: healthMetrics
                    )
                }
            }
        }
        if let nutritionRepository {
            let focuses: [(DashboardWidgetKind, NutritionHomeCardFocus)] = [
                (.nutritionSummary, .dailySummary), (.recentMeal, .recentMeal), (.logMeal, .logMeal)
            ]
            providers += focuses.compactMap { kind, focus -> (any HomeCardSource)? in
                guard requestedSizes == nil || requestedSizes?[kind] != nil else { return nil }
                return registry.descriptor(for: kind).map {
                    NutritionHomeCardSource(
                        definition: $0,
                        focus: focus,
                        repository: nutritionRepository,
                        healthMetrics: healthMetrics
                    )
                }
            }
        }
        if requestedSizes == nil || requestedSizes?[.lifeMoment] != nil,
           let lifeMomentRepository, let definition = registry.descriptor(for: .lifeMoment) {
            providers.append(LifeMomentsOverviewHomeCardSource(definition: definition, repository: lifeMomentRepository))
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
                return emptySnapshot(title, "Everything you asked for is connected.", date)
            }
            return densitySnapshot(
                title: title,
                value: first,
                compactDetail: outstanding.count == 1 ? "1 optional step" : "\(outstanding.count) optional steps",
                storyDetail: outstanding.prefix(3).joined(separator: " \u{00B7} "),
                size: size,
                date: date
            )
        default:
            return unavailableSnapshot(title, date)
        }
    }

    private func homeCardPrimaryRoute(kind: DashboardWidgetKind) -> AppRoute? {
        guard kind == .goals,
              let ranked = trackSnapshot?.goals.max(by: {
                  Self.goalFraction($0) < Self.goalFraction($1)
              }) else { return nil }
        return .goal(ranked.goalID)
    }

    /// What the user still has not set up, in the order worth offering it.
    ///
    /// Onboarding deliberately does not ask for everything; this is where the
    /// remainder lives so the flow can stay short. Each row disappears as soon as
    /// it is satisfied, and the card removes itself when the list empties.
    private func outstandingSetupItems() -> [String] {
        var items: [String] = []

        if PermissionPromptState.hasRequested(.notifications) == false {
            items.append("Turn on reminders")
        }
        if PermissionKind.appleHealth.isSupportedOnThisDevice,
           PermissionPromptState.hasRequested(.appleHealth) == false {
            items.append("Connect Apple Health")
        }
        if PermissionPromptState.hasRequested(.calendar) == false {
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
    private func rebuildDrift(now: Date = Date()) {
        guard let snapshot = planSnapshot else {
            if repairProposals.isEmpty == false { repairProposals = [] }
            if driftCount != 0 { driftCount = 0 }
            return
        }
        let nextProposals = loadedRepairProposals
        let nextDriftCount = PlanDriftPolicy.default.surfacedCount(
            proposals: nextProposals,
            in: snapshot,
            now: now
        )
        if repairProposals != nextProposals { repairProposals = nextProposals }
        if driftCount != nextDriftCount { driftCount = nextDriftCount }
    }

    private func rebuildFocus() {
        guard let snapshot = planSnapshot else {
            if focusTask != nil { focusTask = nil }
            if focusResult != nil { focusResult = nil }
            return
        }
        let currentTasks = Dictionary(planningTasks.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        let tasks = (snapshot.plannedTasks + snapshot.unscheduledTasks).compactMap { currentTasks[$0.id] }
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
        guard let first = results.first(where: \.isEligible) else {
            if focusTask != nil { focusTask = nil }
            if focusResult != nil { focusResult = nil }
            return
        }
        let nextTask = tasks.first { $0.id == first.candidateID }
        if focusResult != first { focusResult = first }
        if focusTask != nextTask { focusTask = nextTask }
    }

    private func rebuildHero(now: Date = Date()) {
        if let session = activeFocusSession, session.state == .running || session.state == .paused {
            publishHero(.init(
                id: "active-focus:\(session.id.uuidString)", priority: .activeFocus,
                title: session.state == .paused ? "Focus is paused" : "Focus in progress",
                detail: "Your active session stays in control until you end it.",
                primaryActionTitle: session.state == .paused ? "Resume" : "Open focus",
                secondaryActionTitles: ["End"], sourceID: session.id, generatedAt: now
            ))
            return
        }
        if let event = trackSnapshot?.unresolvedMedicationEvents.first(where: { $0.status == .unresolved }) {
            publishHero(.init(
                id: "care:\(event.id.uuidString)", priority: .safetySensitiveCare,
                title: "A medication window needs a decision",
                detail: "Choose what happened. LifeBoard will not assume an outcome.",
                primaryActionTitle: "Review", secondaryActionTitles: ["Later"],
                sourceID: event.id, generatedAt: now
            ))
            return
        }
        if let commitment = planSnapshot?.commitments
            .filter({ $0.endAt > now })
            .sorted(by: { $0.startAt < $1.startAt }).first {
            publishHero(.init(
                id: "commitment:\(commitment.id)", priority: .fixedCommitment,
                title: commitment.startAt <= now ? commitment.title : "Next: \(commitment.title)",
                detail: commitment.startAt.formatted(date: .omitted, time: .shortened),
                primaryActionTitle: "Open day", sourceID: nil, generatedAt: now
            ))
            return
        }
        let currentTasks = Dictionary(planningTasks.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        if let mustDo = planSnapshot?.plannedTasks.compactMap({ currentTasks[$0.id] })
            .first(where: { $0.metadata.commitmentLevel == .mustDo }) {
            publishHero(.init(
                id: "must-do:\(mustDo.id.uuidString)", priority: .urgentPlannedWork,
                title: mustDo.title, detail: "Marked Must Do for today",
                primaryActionTitle: "Start", secondaryActionTitles: ["Why this?"],
                sourceID: mustDo.id, generatedAt: now
            ))
            return
        }
        if let routine = trackSnapshot?.dueRoutines.first {
            publishHero(.init(
                id: "routine:\(routine.id.uuidString)", priority: .timedRoutine,
                title: routine.title, detail: "Ready for this part of the day",
                primaryActionTitle: "Begin", sourceID: routine.id, generatedAt: now
            ))
            return
        }
        if let task = focusTask {
            publishHero(.init(
                id: "focus:\(task.id.uuidString)", priority: .generalFocus,
                title: task.title, detail: focusResult?.reasons.first?.text,
                primaryActionTitle: "Start", secondaryActionTitles: ["Why this?"],
                sourceID: task.id, generatedAt: now
            ))
            return
        }
        publishHero(.init(
            id: "choose-focus", priority: .generalFocus,
            title: "Choose one useful next step", detail: "Capture first; organize when you are ready.",
            primaryActionTitle: "Choose a focus", generatedAt: now
        ))
    }

    private func publishHero(_ next: AdaptiveHeroSnapshot) {
        if let current = heroSnapshot,
           current.id == next.id,
           current.priority == next.priority,
           current.title == next.title,
           current.detail == next.detail,
           current.primaryActionTitle == next.primaryActionTitle,
           current.secondaryActionTitles == next.secondaryActionTitles,
           current.sourceID == next.sourceID {
            return
        }
        heroSnapshot = next
    }
}

private struct ProjectionHomeCardSource: HomeCardSource {
    let definition: HomeCardDefinition
    let primaryDestination: Destination
    let privacyClassification: DataSensitivity
    private let snapshotBuilder: @MainActor @Sendable (HomeCardSize, Date) -> HomeCardSnapshot
    private let routeBuilder: @MainActor @Sendable () -> AppRoute?

    init(
        definition: HomeCardDefinition,
        destination: Destination,
        snapshotBuilder: @escaping @MainActor @Sendable (HomeCardSize, Date) -> HomeCardSnapshot,
        routeBuilder: @escaping @MainActor @Sendable () -> AppRoute? = { nil }
    ) {
        self.definition = definition
        primaryDestination = destination
        privacyClassification = definition.sensitivity
        self.snapshotBuilder = snapshotBuilder
        self.routeBuilder = routeBuilder
    }

    func snapshot(
        configuration: HomeCardConfiguration,
        size: HomeCardSize,
        at date: Date
    ) async -> HomeCardSnapshot {
        await snapshotBuilder(size, date)
    }

    func resolution(context: HomeCardSnapshotContext) async -> HomeCardResolution {
        let resolvedSnapshot = await snapshot(context: context)
        let route = await routeBuilder()
        let actionTitle: String
        if definition.kind == .goals {
            actionTitle = route == nil ? "View goals" : "View goal"
        } else {
            actionTitle = resolvedSnapshot.actions.first?.title ?? "Open"
        }
        return HomeCardResolution(
            snapshot: resolvedSnapshot,
            primaryRoute: route,
            primaryActionTitle: actionTitle
        )
    }
}

struct HomeProjectionCandidate: Equatable, Sendable {
    let plan: PlanDaySnapshot?
    let track: TrackTodaySnapshot?
    let mood: MoodEnergyCheckInValue?
    let fast: FastingSessionValue?
    let endedFast: FastingSessionValue?
    let meal: Date?
    let focus: FocusSessionV2?
}

struct HomeCoreProjectionInputs: Sendable {
    let tasks: [PlanningTaskSummary]
    let focus: FocusSessionV2?
    var sourceRevisions: SourceRevisionVector? = nil
}

struct HomeProjectionInputs: Sendable {
    var plan: PlanDaySnapshot?
    var tasks: [PlanningTaskSummary]?
    var repairs: [PlanRepairProposal]?
    var focus: FocusSessionV2?
    var track: TrackTodaySnapshot?
    var mood: MoodEnergyCheckInValue?
    var planFailed = false
    var trackFailed = false
    var sourceRevisions: SourceRevisionVector? = nil
    var trackSourceRevisions: SourceRevisionVector? = nil
    var moodSourceRevisions: SourceRevisionVector? = nil
}

struct HomeHydrationProjectionInputs: Sendable {
    let day: Date
    let amount: Double?
    let target: Double?
    let revisions: SourceRevisionVector
}

struct HomeMoodProjectionInputs: Sendable {
    let value: MoodEnergyCheckInValue?
    let revisions: SourceRevisionVector?
}

/// Reads only what Home displays; no screen stores, writes or Live Activity updates.
actor HomeProjectionReader {
    let planning: CoreDataPlanningRepository?
    let track: CoreDataTrackFoundationRepository?
    let phaseII: (any PhaseIIRepository)?
    let goalSamples: (any GoalSampleRepository)?
    private let calendarRepository: any PlanningCalendarContextRepository
    private var cachedCalendar: (start: Date, end: Date, context: PlanningCalendarContext)?

    init(planning: CoreDataPlanningRepository?, track: CoreDataTrackFoundationRepository?,
         phaseII: (any PhaseIIRepository)?, goalSamples: (any GoalSampleRepository)?,
         calendarRepository: any PlanningCalendarContextRepository = SystemPlanningCalendarContextRepository()) {
        self.planning = planning; self.track = track; self.phaseII = phaseII; self.goalSamples = goalSamples
        self.calendarRepository = calendarRepository
    }

    func readCore() async throws -> HomeCoreProjectionInputs {
        guard let planning else {
            return .init(tasks: [], focus: nil)
        }
        let revisions = planning.sourceRevisions.snapshot()
        async let tasks = planning.fetchOpenPlanningTasks()
        async let focus = planning.activeSession()
        return try await .init(tasks: tasks, focus: focus, sourceRevisions: revisions)
    }

    func read(now: Date,
              onCore: @escaping @MainActor @Sendable (HomeCoreProjectionInputs) -> Void = { _ in },
              onPlan: @escaping @MainActor @Sendable (HomeProjectionInputs) -> Void = { _ in },
              onTrack: @escaping @MainActor @Sendable (HomeProjectionInputs) -> Void = { _ in }) async -> HomeProjectionInputs {
        async let plan = readPlan(now: now, onCore: onCore, onPlan: onPlan)
        async let track = readTrackAndPublish(now: now, onTrack: onTrack)
        let (planValues, trackValues) = await (plan, track)
        var result = planValues
        result.track = trackValues.track
        result.mood = trackValues.mood
        result.trackFailed = trackValues.trackFailed
        return result
    }

    private func readTrackAndPublish(now: Date,
        onTrack: @escaping @MainActor @Sendable (HomeProjectionInputs) -> Void) async -> HomeProjectionInputs {
        let result = await readTrack(now: now)
        guard !Task.isCancelled else { return .init() }
        await onTrack(result)
        return result
    }

    private func readPlan(now: Date,
                          onCore: @escaping @MainActor @Sendable (HomeCoreProjectionInputs) -> Void,
                          onPlan: @escaping @MainActor @Sendable (HomeProjectionInputs) -> Void) async -> HomeProjectionInputs {
        guard let planning else { return .init() }
        let sourceRevisions = planning.sourceRevisions.snapshot()
        let calendar = Calendar.current
        let day = PlanningDay(date: now, timeZone: calendar.timeZone, calendar: calendar)
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        do {
            async let tasksValue = planning.fetchOpenPlanningTasks()
            async let blocksValue = planning.fetchTimeBlocks(from: start, to: end)
            async let profilesValue = planning.fetchWorkingHoursProfiles()
            async let calendarValue = readCalendar(from: start, to: end)
            async let focusValue = planning.activeSession()
            let (tasks, focus) = try await (tasksValue, focusValue)
            guard !Task.isCancelled else { return .init() }
            await onCore(.init(tasks: tasks, focus: focus, sourceRevisions: sourceRevisions))
            let (blocks, profiles, context) = try await (blocksValue, profilesValue, calendarValue)
            let profile = profiles.first(where: \.isDefault) ?? profiles.first ?? PlanStore.defaultWorkingProfile()
            let snapshot = PlanDayProjectionInputs(tasks: tasks, allBlocks: blocks, workingProfile: profile,
                calendarContext: context.0, calendarState: context.1, calendar: calendar, now: now)
                .snapshot(for: day)
            let proposals = DeterministicPlanRepairService().proposals(for: snapshot, now: now)
            let applied = try await planning.appliedReceiptSources(in: Set(proposals.map { "plan.repair.\($0.id.uuidString)" }))
            let result = HomeProjectionInputs(plan: snapshot, tasks: tasks,
                repairs: proposals.filter { !applied.contains("plan.repair.\($0.id.uuidString)") }, focus: focus, sourceRevisions: sourceRevisions)
            guard !Task.isCancelled else { return .init() }
            await onPlan(result)
            return result
        } catch { return .init(planFailed: true) }
    }

    private func readCalendar(from start: Date, to end: Date) async -> (PlanningCalendarContext, PlanningCalendarState) {
        let authorization = await calendarRepository.authorization()
        guard authorization == .authorized else {
            cachedCalendar = nil
            let state: PlanningCalendarState = switch authorization {
            case .notDetermined: .notRequested
            case .denied, .restricted: .denied
            default: .failed(message: "Calendar context is unavailable.")
            }
            return (.init(authorization: authorization), state)
        }
        do {
            let context = try await calendarRepository.fetchCommitments(from: start, to: end)
            cachedCalendar = (start, end, context)
            return (context, .fresh(fetchedAt: context.fetchedAt))
        } catch {
            if let cached = cachedCalendar, cached.start == start, cached.end == end {
                return (cached.context, .staleCached(fetchedAt: cached.context.fetchedAt,
                    message: error.localizedDescription))
            }
            return (.init(authorization: authorization), .failed(message: error.localizedDescription))
        }
    }

    func readHydration(now: Date) async throws -> HomeHydrationProjectionInputs {
        guard let track else { throw CocoaError(.featureUnsupported) }
        let revisions = track.sourceRevisions.snapshot()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        async let logsValue = track.fetchHydrationLogs(from: start, to: end)
        async let targetValue = track.fetchHydrationTarget()
        let (logs, target) = try await (logsValue, targetValue)
        let amount = logs.reduce(0) { $0 + HydrationMeasurementService.convert($1.amount, from: $1.unit, to: .milliliters) }
        return .init(day: start, amount: logs.isEmpty && target == nil ? nil : amount,
                     target: target.map { HydrationMeasurementService.convert($0.amount, from: $0.unit, to: .milliliters) },
                     revisions: revisions)
    }

    func readMood(now: Date) async throws -> HomeMoodProjectionInputs {
        guard let phaseII else { throw CocoaError(.featureUnsupported) }
        let revisions = (phaseII as? CoreDataLifeBoardPhaseIIRepository)?.sourceRevisions.snapshot()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        let values = try await phaseII.fetchMoodCheckIns(from: calendar.date(byAdding: .day, value: -29, to: start), to: end)
        return .init(value: values.first, revisions: revisions)
    }

    private func readTrack(now: Date) async -> HomeProjectionInputs {
        guard let track, let phaseII else { return .init() }
        let trackRevisions = track.sourceRevisions.snapshot()
        let moodRevisions = (phaseII as? CoreDataLifeBoardPhaseIIRepository)?.sourceRevisions.snapshot()
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        do {
            async let goalsValue = track.fetchGoals()
            async let linksValue = track.fetchGoalLinks(goalID: nil)
            async let routinesValue = track.fetchRoutines()
            async let schedulesValue = track.fetchRoutineSchedules(routineID: nil)
            async let hydrationValue = track.fetchHydrationLogs(from: start, to: end)
            async let targetValue = track.fetchHydrationTarget()
            async let eventsValue = phaseII.fetchMedicationEvents(from: start, to: end)
            async let moodValue = phaseII.fetchMoodCheckIns(from: calendar.date(byAdding: .day, value: -29, to: start), to: end)
            let (goals, links, routines, schedules, hydration, target, events, moods) = try await
                (goalsValue, linksValue, routinesValue, schedulesValue, hydrationValue, targetValue, eventsValue, moodValue)
            let samples = try await goalSamples?.samples(for: links, asOf: now) ?? []
            let linksByGoal = Dictionary(grouping: links, by: \.goalID)
            let progress = goals.map { DefaultGoalProgressService().progress(for: $0, links: linksByGoal[$0.id] ?? [], samples: samples) }
            let due = TrackFoundationStore.dueRoutines(routines: routines, schedules: schedules, at: now, calendar: calendar)
            let amount = hydration.reduce(0) { $0 + HydrationMeasurementService.convert($1.amount, from: $1.unit, to: .milliliters) }
            let snapshot = TrackTodaySnapshot(unresolvedMedicationEvents: events.filter { $0.status == .unresolved || $0.status == .scheduled },
                habitGrades: [], dueRoutines: due, goals: progress,
                hydrationAmountMilliliters: hydration.isEmpty && target == nil ? nil : amount,
                hydrationTargetMilliliters: target.map { HydrationMeasurementService.convert($0.amount, from: $0.unit, to: .milliliters) },
                completeness: .complete, generatedAt: now)
            return .init(track: snapshot, mood: moods.first, trackSourceRevisions: trackRevisions, moodSourceRevisions: moodRevisions)
        } catch { return .init(trackFailed: true) }
    }
}
