import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

struct InsightsDestination: View {
    @State private var store: TrackFoundationStore
    @State private var healthStore = HealthCoordinator.shared.connectionStore
    @State private var lens: InsightsLens = .overview
    @State private var persistedPlanningEvents: [NormalizedLifeEvent] = []
    @State private var wellnessEvents: [NormalizedLifeEvent] = []
    @State private var planningEvidenceError: String?
    @State private var dayLoopEvidenceReport: DayLoopEvidenceReport?
    @State private var experienceAggregates: [DailyXPAggregateDefinition] = []
    @State private var experienceLoadFinished = false
    @State private var experienceError: String?
    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.lifeBoardAtmosphereIsHosted) private var atmosphereIsHosted
    let router: AppRouter
    private let planningRepository: CoreDataPlanningRepository?
    private let gamificationRepository: (any GamificationRepositoryProtocol)?
    private let wellnessRepository: any WellnessRepository
    /// The record a deep link asked for. `.insightEvidence` carried a UUID that
    /// was discarded, so the route landed on a generic Insights screen and the
    /// user had to find the record again themselves.
    private let focusedEvidenceID: UUID?
    @State private var evidenceExpanded = false
    @State private var evidenceExclusionRevision = 0
    @State private var insightStateRevision = 0

    init(
        repository: CoreDataTrackFoundationRepository,
        phaseIIRepository: any PhaseIIRepository,
        wellnessRepository: any WellnessRepository,
        planningRepository: CoreDataPlanningRepository?,
        gamificationRepository: (any GamificationRepositoryProtocol)?,
        habitProjectionService: (any TrackHabitProjectionService)?,
        goalSampleProvider: (any GoalSampleRepository)?,
        router: AppRouter,
        initialLens: InsightsLens = .overview,
        focusedEvidenceID: UUID? = nil
    ) {
        _store = State(initialValue: TrackFoundationStore(
            repository: repository,
            phaseIIRepository: phaseIIRepository,
            goalSampleProvider: goalSampleProvider,
            habitProjectionService: habitProjectionService
        ))
        self.planningRepository = planningRepository
        self.gamificationRepository = gamificationRepository
        self.wellnessRepository = wellnessRepository
        self.router = router
        self.focusedEvidenceID = focusedEvidenceID
        _lens = State(initialValue: initialLens)
        // A named record means the caller wants the evidence list, not the
        // interpretation, so the disclosure starts open.
        _evidenceExpanded = State(initialValue: focusedEvidenceID != nil)
    }

    private var authorizedEvents: [NormalizedLifeEvent] {
        _ = evidenceExclusionRevision
        return SnapshotLifeEventProjectionRepository(events: store.snapshot.normalizedEvents + persistedPlanningEvents + wellnessEvents)
            .authorizedEvents(for: .insights, journalConsentGranted: false)
            .map { event in EvaEvidenceExclusionStore.applying(to: event) }
            .filter { $0.allowedDestinations.contains(.insights) }
    }

    private var events: [NormalizedLifeEvent] {
        let calendar = Calendar.current
        let startToday = calendar.startOfDay(for: Date())
        switch lens {
        case .overview:
            return authorizedEvents.filter { $0.occurredAt >= startToday }
        case .trends:
            let start = calendar.date(byAdding: .day, value: -6, to: startToday) ?? startToday
            return authorizedEvents.filter { $0.occurredAt >= start }
        case .review:
            return authorizedEvents
        case .experience:
            return []
        }
    }

    private var confidence: Double? {
        guard events.isEmpty == false else { return nil }
        let complete = events.filter { $0.completeness == .complete && $0.freshness == .complete }.count
        return Double(complete) / Double(events.count)
    }

    private var missingDomains: [String] {
        let present = Set(events.map(\.domain))
        return ["hydration", "habit", "tracker", "routine", "goal", "plan"].filter { present.contains($0) == false }
    }

    private var sourceCounts: [(domain: String, count: Int)] {
        Dictionary(grouping: events, by: \.domain)
            .map { (domain: $0.key, count: $0.value.count) }
            .sorted { $0.domain < $1.domain }
    }

    var body: some View {
        ZStack(alignment: .top) {
            if atmosphereIsHosted == false {
                ScenicBackdrop(
                    scene: .secondary,
                    daypart: preferences.resolvedDaypart(),
                    requestedTier: preferences.renderingTier,
                    comfortProfile: preferences.comfortProfile
                )
                .frame(height: 260)
                .clipped()
                .ignoresSafeArea(edges: .top)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    LensPicker(
                        "Insights lens",
                        selection: $lens,
                        values: InsightsLens.allCases,
                        identifierPrefix: "insights.lens",
                        title: \.title,
                        identifier: \.rawValue
                    )

                    if let planningEvidenceError {
                        Label("Planning history is temporarily unavailable: \(planningEvidenceError)", systemImage: "exclamationmark.triangle")
                            .lifeboardFont(.support)
                            .foregroundStyle(.secondary)
                    }

                    if lens == .experience {
                        insightContent
                    } else if store.isLoading && events.isEmpty && healthStore.aggregates.isEmpty {
                        ProgressView("Reading today’s evidence…")
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else if events.isEmpty && healthStore.aggregates.isEmpty {
                        VStack(spacing: 12) {
                            ContentUnavailableView(
                                "Nothing recorded yet",
                                systemImage: "sparkles",
                                description: Text("A check-in, routine, care event, or hydration log will appear here with its source.")
                            )
                            Button("Record something in Track") {
                                router.select(.track)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Color(SemanticColorTokens.foundationApricotAccent))
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("insights.empty.openTrack")
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        insightContent
                    }
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 48)
            }
            // Insights was the one root that never reported its offset, so the
            // shared observer sat at whatever the last root left behind — reset
            // to zero on every switch. The celestial's parallax was pinned
            // still here while the other three roots moved.
            .lifeBoardReportsComposerScroll()
        }
        .background(Color.clear.ignoresSafeArea())
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEvidence() }
        .task {
            let updates = await HealthSyncInvalidationService.shared.updates()
            for await _ in updates {
                guard Task.isCancelled == false else { return }
                await loadHealthEvidence()
            }
        }
        .refreshable { await loadEvidence() }
        .accessibilityIdentifier("foundation.insights")
    }

    @ViewBuilder
    private var insightContent: some View {
        switch lens {
        case .overview:
            InsightsHealthSection(healthStore: healthStore, router: router)
            if isUnifiedInsightDismissed {
                SurfaceCard {
                    HStack {
                        Text("This insight is dismissed everywhere.")
                            .lifeboardFont(.support)
                        Spacer()
                        Button("Restore") {
                            EvaInsightStateStore.restore(insightID: unifiedInsight.id)
                            insightStateRevision += 1
                        }
                    }
                }
            } else {
                InsightsInterpretationSurface(
                    interpretation: interpretation,
                    completenessDescription: evidenceCompletenessDescription
                )
                Button {
                    askEva()
                } label: {
                    Label("Explore this with Eva", systemImage: "sparkles")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(SemanticColorTokens.foundationApricotAccent))
                Button("Dismiss everywhere", systemImage: "xmark.circle") {
                    EvaInsightStateStore.dismiss(insightID: unifiedInsight.id, kind: "insights_overview")
                    insightStateRevision += 1
                }
                .buttonStyle(.bordered)
            }
        case .trends:
            InsightsTrendsSection(
                interpretation: interpretation,
                sourceCounts: sourceCounts
            )
        case .review:
            InsightsReviewSection(
                events: events,
                dayLoopEvidenceReport: dayLoopEvidenceReport,
                router: router
            )
        case .experience:
            InsightsExperienceSection(
                isAvailable: gamificationRepository != nil,
                loadFinished: experienceLoadFinished,
                errorMessage: experienceError,
                aggregates: experienceAggregates,
                lens: $lens,
                reload: { Task { await loadExperience() } }
            )
        }

        if lens != .experience {
            InsightsEvidenceDisclosure(
                isExpanded: $evidenceExpanded,
                completenessDescription: evidenceCompletenessDescription,
                events: events,
                focusedEvidenceID: focusedEvidenceID,
                open: open,
                exclude: exclude
            )
        }
    }

    private func exclude(_ event: NormalizedLifeEvent) {
        EvaEvidenceExclusionStore.exclude(event)
        evidenceExclusionRevision += 1
    }

    /// Ranked by how consistently something is recorded, not how often. The
    /// previous headline picked whichever domain had the most rows, which
    /// always meant the chattiest tracker rather than the clearest signal.
    private var interpretation: InsightsInterpretation {
        InsightsInterpretationService().interpret(events: events)
    }

    private var unifiedInsight: Insight {
        InsightsInterpretationService().unifiedInsight(events: events)
    }

    private var isUnifiedInsightDismissed: Bool {
        _ = insightStateRevision
        return EvaInsightStateStore.isDismissed(unifiedInsight.id)
    }

    private var evidenceCompletenessDescription: String {
        guard let confidence else { return "Completeness is not available yet." }
        let formatted = confidence.formatted(.percent.precision(.fractionLength(0)))
        return "\(formatted) of these records are complete and current."
    }

    private func askEva() {
        let resolved = unifiedInsight
        // Hand over the interpretation Insights actually made, not a generic
        // "help me understand this pattern" — Eva was being asked to re-derive
        // a claim the user had just read.
        let context = EvaEntryContext(
            origin: .insights,
            evidenceReferences: resolved.evidence.map(\.reference.recordID),
            requestedAssistance: resolved.confidence != .low
                ? "Insights found: \(resolved.claim) Help me understand what that suggests and choose one safe next step."
                : "Help me understand what my recorded history so far suggests, without over-reading it."
        )
        let summary = """
        \(context.requestedAssistance) \
        Use only the \(context.evidenceReferences.count) authorized evidence \
        references shown in Insights.
        """
        try? EvaChatLaunchRequestStore.shared.submit(.init(prompt: summary))
        router.select(.eva)
    }

    private func loadEvidence() async {
        async let trackLoad: Void = store.load()
        async let experienceLoad: Void = loadExperience()
        async let healthLoad: Void = loadHealthEvidence()
        if let planningRepository {
            do {
                let records = try await planningRepository.fetchMutationReceipts(since: nil)
                let proposalSignals = (try? await DayOpenProposalSignalStore.shared.signals()) ?? []
                let sessions = try await planningRepository.sessions(since: nil)
                let focusCommands = try await planningRepository.commandReceipts(since: nil)
                let sessionsWithDurableCommands = Set(focusCommands.map(\.sessionID))
                persistedPlanningEvents = records.compactMap(InsightsLifeEventMappers.planningEvent)
                    + sessions.flatMap {
                        InsightsLifeEventMappers.focusEvents(
                            $0,
                            includesLegacyStateFallback: sessionsWithDurableCommands.contains($0.id) == false
                        )
                    }
                    + focusCommands.map(InsightsLifeEventMappers.focusCommandEvent)
                dayLoopEvidenceReport = DayLoopLedger.evidenceReport(
                    records: records,
                    proposalSignals: proposalSignals,
                    calendar: .current
                )
                planningEvidenceError = nil
            } catch {
                dayLoopEvidenceReport = nil
                planningEvidenceError = error.localizedDescription
            }
        }
        await trackLoad
        await experienceLoad
        await healthLoad
    }

    @MainActor
    private func loadHealthEvidence() async {
        do {
            async let body = wellnessRepository.bodyMetricSamples(kind: nil)
            async let workouts = wellnessRepository.workoutRecords()
            async let sleep = wellnessRepository.sleepNotes()
            async let movement = wellnessRepository.movementRecords()
            let projector = WellnessNormalizedEventProjector()
            let (bodyValues, workoutValues, sleepValues, movementValues) = try await (body, workouts, sleep, movement)
            let bodyEvents = bodyValues.map { projector.bodyMetric($0) }
            let workoutEvents = workoutValues.map { projector.workout($0, timeZone: .autoupdatingCurrent) }
            let sleepEvents = sleepValues.map { projector.sleep($0) }
            let movementEvents = movementValues.map { projector.movement($0, timeZone: .autoupdatingCurrent) }
            wellnessEvents = bodyEvents + workoutEvents + sleepEvents + movementEvents
        } catch {
            wellnessEvents = []
        }
    }

    @MainActor
    private func loadExperience() async {
        guard let gamificationRepository else {
            experienceAggregates = []
            experienceError = nil
            experienceLoadFinished = true
            return
        }
        experienceLoadFinished = false
        experienceError = nil
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today
        do {
            experienceAggregates = try await withCheckedThrowingContinuation { continuation in
                gamificationRepository.fetchDailyAggregates(
                    from: XPCalculationService.periodKey(for: start),
                    to: XPCalculationService.periodKey(for: today)
                ) { continuation.resume(with: $0) }
            }
            experienceError = nil
        } catch {
            experienceAggregates = []
            experienceError = error.localizedDescription
        }
        experienceLoadFinished = true
    }

    private func open(_ evidence: EvidenceReference) {
        guard let reference = RecordRouteResolver.reference(for: evidence) else {
            router.push(.trackHistory, in: .insights)
            return
        }
        RecordRouteResolver.open(reference, with: router)
    }
}
