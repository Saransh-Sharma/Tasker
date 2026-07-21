import Foundation
import Observation

@MainActor
@Observable
final class HomeLifeOSProjectionStore {
    private(set) var planSnapshot: PlanDaySnapshot?
    private(set) var trackSnapshot: TrackTodaySnapshot?
    private(set) var focusTask: PlanningTaskSummary?
    private(set) var focusResult: FocusRankResult?
    private(set) var latestMood: LifeBoardMoodEnergyCheckInValue?
    private(set) var activeFast: LifeBoardFastingSessionValue?
    private(set) var activeFocusSession: FocusSessionV2?
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
        rankingService: any FocusRankingService = DeterministicFocusRankingService()
    ) {
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
        } else {
            activeFast = nil
        }
        activeFocusSession = planStore?.activeFocusSession
        rebuildFocus()
        rebuildHero()
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

    func endActiveFast(at date: Date = Date()) async {
        guard var activeFast, let phaseIIRepository else { return }
        activeFast.endedAt = max(activeFast.startedAt, date)
        try? await phaseIIRepository.saveFastingSession(activeFast)
        await load()
    }

    /// Home renders only these display-ready projections. The provider registry
    /// is deliberately assembled at the domain boundary so card views do not
    /// know which repositories produced the values.
    func makeHomeCardProviderRegistry() throws -> HomeCardProviderRegistry {
        let registry = DefaultDashboardWidgetRegistry.shared
        let kinds: [(DashboardWidgetKind, LifeBoardDestination)] = [
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
            guard let focusTask else { return emptySnapshot(title, "Choose a useful next step.", date) }
            return densitySnapshot(
                title: title,
                value: focusTask.title,
                compactDetail: focusResult?.reasons.first?.text ?? "Ready when you are.",
                storyDetail: "This fits the time and context available now. Open Plan to adjust it before starting.",
                size: size,
                date: date
            )
        case .tasks:
            guard let planSnapshot else { return unavailableSnapshot(title, date) }
            let count = planSnapshot.plannedTasks.count + planSnapshot.unscheduledTasks.count
            return densitySnapshot(
                title: title,
                value: "\(count)",
                compactDetail: count == 1 ? "task in view" : "tasks in view",
                storyDetail: "\(planSnapshot.plannedTasks.count) planned · \(planSnapshot.unscheduledTasks.count) still flexible",
                size: size,
                date: date
            )
        case .scheduleCapacity, .compactTimeline:
            guard let planSnapshot else { return unavailableSnapshot(title, date) }
            let count = planSnapshot.commitments.count
            return densitySnapshot(
                title: title,
                value: "\(count)",
                compactDetail: count == 1 ? "fixed commitment" : "fixed commitments",
                storyDetail: planSnapshot.freeWindows.isEmpty
                    ? "No open window is projected yet."
                    : "\(planSnapshot.freeWindows.count) open windows remain flexible.",
                size: size,
                date: date
            )
        case .lifeSnapshot:
            guard let latestMood else { return emptySnapshot(title, "A gentle check-in can start your snapshot.", date) }
            return densitySnapshot(
                title: title,
                value: latestMood.mood.title,
                compactDetail: latestMood.energy.map { "Energy \($0)/5" } ?? "Mood checked in",
                storyDetail: "Your latest check-in is shown without judging or turning it into a score.",
                size: size,
                date: date
            )
        case .care:
            guard let trackSnapshot else { return unavailableSnapshot(title, date) }
            let unresolved = trackSnapshot.unresolvedMedicationEvents.filter { $0.status == .unresolved }.count
            return densitySnapshot(
                title: title,
                value: unresolved == 0 ? "Clear" : "\(unresolved)",
                compactDetail: unresolved == 0 ? "Nothing needs acknowledgement" : "needs your acknowledgement",
                storyDetail: "LifeBoard waits for your confirmation and never assumes what happened.",
                size: size,
                date: date
            )
        case .routines:
            guard let trackSnapshot else { return unavailableSnapshot(title, date) }
            let count = trackSnapshot.dueRoutines.count
            return densitySnapshot(
                title: title,
                value: count == 0 ? "All clear" : "\(count)",
                compactDetail: count == 1 ? "routine is ready" : "routines are ready",
                storyDetail: "Start one when it fits; there is no penalty for changing the plan.",
                size: size,
                date: date
            )
        case .goals:
            guard let trackSnapshot else { return unavailableSnapshot(title, date) }
            let count = trackSnapshot.goals.count
            return count == 0
                ? emptySnapshot(title, "Add a goal when there is something meaningful to follow.", date)
                : densitySnapshot(
                    title: title,
                    value: "\(count)",
                    compactDetail: count == 1 ? "goal in view" : "goals in view",
                    storyDetail: "Open Track for progress, evidence, and the next useful action.",
                    size: size,
                    date: date
                )
        case .fasting:
            guard let activeFast else { return emptySnapshot(title, "No fast is active.", date) }
            let elapsed = max(0, Int(activeFast.elapsed(at: date)))
            let hours = elapsed / 3_600
            let minutes = (elapsed % 3_600) / 60
            return densitySnapshot(
                title: title,
                value: String(format: "%d:%02d", hours, minutes),
                compactDetail: activeFast.targetDuration.map { "Target \(Int($0 / 3_600))h" } ?? "Your timer is active",
                storyDetail: "Started \(activeFast.startedAt.formatted(date: .omitted, time: .shortened)). You can finish, correct, or cancel without judgment.",
                size: size,
                date: date
            )
        case .journal:
            return HomeCardSnapshot(
                availability: .degraded,
                title: title,
                value: size == .compact ? nil : "Open Journal",
                detail: "Journal previews stay hidden until this card receives explicit Home permission.",
                updatedAt: date
            )
        case .progressReflection:
            guard let planSnapshot, let trackSnapshot else { return unavailableSnapshot(title, date) }
            let planned = planSnapshot.plannedTasks.count
            let goals = trackSnapshot.goals.count
            return densitySnapshot(
                title: title,
                value: planned == 0 ? "A quiet day" : "\(planned) planned",
                compactDetail: goals == 0 ? "Reflect without a score" : "\(goals) goals in context",
                storyDetail: "Look for what helped, what changed, and one adjustment worth carrying forward.",
                size: size,
                date: date
            )
        case .quickCapture:
            return densitySnapshot(
                title: title,
                value: "Capture",
                compactDetail: "Task, note, journal, mood, or metric",
                storyDetail: "Write naturally. LifeBoard will show a review before saving any interpreted change.",
                size: size,
                date: date
            )
        case .evaConversation:
            return emptySnapshot(title, "Save an Eva insight to place it here.", date)
        default:
            return unavailableSnapshot(title, date)
        }
    }

    private func densitySnapshot(
        title: String,
        value: String,
        compactDetail: String,
        storyDetail: String,
        size: HomeCardSize,
        date: Date
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
            updatedAt: date
        )
    }

    private func emptySnapshot(_ title: String, _ detail: String, _ date: Date) -> HomeCardSnapshot {
        HomeCardSnapshot(availability: .empty, title: title, detail: detail, updatedAt: date)
    }

    private func unavailableSnapshot(_ title: String, _ date: Date) -> HomeCardSnapshot {
        HomeCardSnapshot(
            availability: .unavailable,
            title: title,
            detail: "This source is unavailable right now. Your Home layout is unchanged.",
            updatedAt: date
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
