import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

struct InsightsRenderSnapshot: Equatable {
    struct SourceCount: Equatable {
        let domain: String
        let count: Int
    }

    var events: [NormalizedLifeEvent] = []
    var authorizedEvidence: [NormalizedLifeEvent] = []
    var interpretation = InsightsInterpretationService().interpret(events: [])
    var unifiedInsight = InsightsInterpretationService().unifiedInsight(events: [])
    var completenessDescription = "Completeness is not available yet."
    var confidence: Double?
    var missingDomains: [String] = []
    var sourceCounts: [SourceCount] = []

    static func build(
        authorizedEvents: [NormalizedLifeEvent],
        lens: InsightsLens,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> InsightsRenderSnapshot {
        let startToday = calendar.startOfDay(for: now)
        let filtered: [NormalizedLifeEvent]
        switch lens {
        case .overview:
            filtered = authorizedEvents.filter { $0.occurredAt >= startToday }
        case .trends:
            let start = calendar.date(byAdding: .day, value: -6, to: startToday) ?? startToday
            filtered = authorizedEvents.filter { $0.occurredAt >= start }
        case .review:
            filtered = authorizedEvents
        case .experience:
            filtered = []
        }
        let complete = filtered.lazy.filter {
            $0.completeness == .complete && $0.freshness == .complete
        }.count
        let confidence = filtered.isEmpty ? nil : Double(complete) / Double(filtered.count)
        let present = Set(filtered.map(\.domain))
        let sourceCounts = Dictionary(grouping: filtered, by: \.domain)
            .map { SourceCount(domain: $0.key, count: $0.value.count) }
            .sorted { $0.domain < $1.domain }
        return InsightsRenderSnapshot(
            events: filtered,
            authorizedEvidence: authorizedEvents,
            interpretation: InsightsInterpretationService().interpret(events: filtered, now: now, calendar: calendar),
            unifiedInsight: InsightsInterpretationService().unifiedInsight(events: filtered, now: startToday, calendar: calendar),
            completenessDescription: confidence.map {
                "\($0.formatted(.percent.precision(.fractionLength(0)))) of these records are complete and current."
            } ?? "Completeness is not available yet.",
            confidence: confidence,
            missingDomains: ["hydration", "habit", "tracker", "routine", "goal", "plan"]
                .filter { present.contains($0) == false },
            sourceCounts: sourceCounts
        )
    }
}

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
    @Environment(\.lifeBoardRootActivity) private var rootActivity
    let router: AppRouter
    private let planningRepository: CoreDataPlanningRepository?
    private let gamificationRepository: (any GamificationRepositoryProtocol)?
    private let wellnessRepository: any WellnessRepository
    /// The record a deep link asked for. `.insightEvidence` carried a UUID that
    /// was discarded, so the route landed on a generic Insights screen and the
    /// user had to find the record again themselves.
    private let focusedEvidenceID: UUID?
    @State private var evidenceExpanded = false
    @State private var evidenceTop: CGFloat?
    @State private var revealedEvidenceID: String?
    @State private var evidenceExclusionRevision = 0
    @State private var insightStateRevision = 0
    @State private var renderSnapshot = InsightsRenderSnapshot()

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
        return SnapshotLifeEventProjectionRepository(events: store.snapshot.normalizedEvents + persistedPlanningEvents + wellnessEvents)
            .authorizedEvents(for: .insights, journalConsentGranted: false)
            .map { event in EvaEvidenceExclusionStore.applying(to: event) }
            .filter { $0.allowedDestinations.contains(.insights) }
    }

    private var events: [NormalizedLifeEvent] {
        renderSnapshot.events
    }

    private var confidence: Double? {
        renderSnapshot.confidence
    }

    private var missingDomains: [String] {
        renderSnapshot.missingDomains
    }

    private var sourceCounts: [(domain: String, count: Int)] {
        renderSnapshot.sourceCounts.map { (domain: $0.domain, count: $0.count) }
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

            ScrollViewReader { scrollProxy in
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
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }

                    // `DESIGN.md`: "Scrolling is not a quiet moment." Insights
                    // was one of three roots with no scroll entrance at all.
                    if lens == .experience {
                        insightContent
                            .lifeBoardScrollEntrance()
                    } else if store.isLoading && events.isEmpty && healthStore.aggregates.isEmpty {
                        ProgressView("Reading today’s evidence…")
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else if events.isEmpty && healthStore.aggregates.isEmpty {
                        VStack(spacing: 12) {
                            StatusSurface(
                                state: .noRecord,
                                title: "Nothing recorded yet",
                                message: "A check-in, routine, care event, or hydration log will appear here with its source."
                            )
                            Button("Record something in Track") {
                                router.select(.track)
                            }
                            .buttonStyle(.lifeBoardPrimaryCompact)
                            .tint(Color(SemanticColorTokens.foundationApricotAccent))
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("insights.empty.openTrack")
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        insightContent
                            .lifeBoardScrollEntrance()
                    }
                }
                .frame(maxWidth: 760)
                .coordinateSpace(name: "insights.content")
                .background {
                    GeometryReader { geometry in
                        if let top = evidenceTop, lens != .experience {
                            Color.clear
                                .frame(height: max(0, geometry.size.height - top))
                                .frame(maxWidth: .infinity)
                                .lifeBoardClaySurface(.resting)
                                .offset(y: top)
                                .allowsHitTesting(false)
                                .accessibilityHidden(true)
                        }
                    }
                }
                .onGeometryChange(for: InsightsEvidenceLayoutProbe.self) { proxy in
                    InsightsEvidenceLayoutProbe(height: proxy.size.height, expanded: evidenceExpanded,
                        target: focusedEvidenceID.flatMap { id in events.first(where: { $0.sourceID == id })?.id })
                } action: { probe in
                    guard probe.height > 0, probe.expanded, let target = probe.target,
                          target != revealedEvidenceID else { return }
                    scrollProxy.scrollTo(target, anchor: .center)
                    revealedEvidenceID = target
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 48)
            }
            // Insights was the one root that never reported its offset, so the
            // shared observer sat at whatever the last root left behind — reset
            // to zero on every switch. The celestial's parallax was pinned
            // still here while the other three roots moved.
            .lifeBoardReportsComposerScroll()
            .accessibilityIdentifier("foundation.insights.scroll")
            }
        }
        .background(Color.clear.ignoresSafeArea())
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: rootActivity) {
            guard rootActivity.performsContinuousWork else { return }
            await loadEvidence()
        }
        .task(id: rootActivity) {
            guard rootActivity.performsContinuousWork else { return }
            let updates = await HealthSyncInvalidationService.shared.updates()
            for await _ in updates {
                guard Task.isCancelled == false else { return }
                await loadHealthEvidence()
                rebuildRenderSnapshot()
            }
        }
        .onChange(of: lens) { _, _ in rebuildRenderSnapshot() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            guard rootActivity.performsContinuousWork else { return }
            rebuildRenderSnapshot()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
            guard rootActivity.performsContinuousWork else { return }
            rebuildRenderSnapshot()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            guard rootActivity.performsContinuousWork else { return }
            rebuildRenderSnapshot()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
            guard rootActivity.performsContinuousWork else { return }
            rebuildRenderSnapshot()
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
                .buttonStyle(.lifeBoardPrimaryCompact)
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
            InsightsEvidenceDisclosure(isExpanded: $evidenceExpanded,
                completenessDescription: evidenceCompletenessDescription)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.frame(in: .named("insights.content")).minY
                } action: { top in
                    if evidenceTop != top { evidenceTop = top }
                }
                .padding(.bottom, evidenceExpanded ? -12 : 0)
            if evidenceExpanded {
                ForEach(events) { event in
                    EvidenceRow(event: event, onOpenEvidence: open) { exclude(event) }
                        .id(event.id)
                        .padding(.horizontal, 16)
                        .padding(.bottom, event.id == events.last?.id ? 16 : -12)
                        .background {
                            if event.sourceID == focusedEvidenceID {
                                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                                    .fill(Color(SemanticColorTokens.foundationSurfaceSelected))
                                    .padding(.horizontal, 8)
                            }
                        }
                }
            }
        }
    }

    private func exclude(_ event: NormalizedLifeEvent) {
        EvaEvidenceExclusionStore.exclude(event)
        evidenceExclusionRevision += 1
        rebuildRenderSnapshot()
    }

    /// Ranked by how consistently something is recorded, not how often. The
    /// previous headline picked whichever domain had the most rows, which
    /// always meant the chattiest tracker rather than the clearest signal.
    private var interpretation: InsightsInterpretation {
        renderSnapshot.interpretation
    }

    private var unifiedInsight: Insight {
        renderSnapshot.unifiedInsight
    }

    private var isUnifiedInsightDismissed: Bool {
        _ = insightStateRevision
        return EvaInsightStateStore.isDismissed(unifiedInsight.id)
    }

    private var evidenceCompletenessDescription: String {
        renderSnapshot.completenessDescription
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
        rebuildRenderSnapshot()
    }

    @MainActor
    private func rebuildRenderSnapshot(now: Date = Date()) {
        _ = evidenceExclusionRevision
        let next = InsightsRenderSnapshot.build(
            authorizedEvents: authorizedEvents,
            lens: lens,
            now: now
        )
        guard next != renderSnapshot else { return }
        renderSnapshot = next
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

private struct InsightsEvidenceLayoutProbe: Equatable {
    let height: CGFloat
    let expanded: Bool
    let target: String?
}
