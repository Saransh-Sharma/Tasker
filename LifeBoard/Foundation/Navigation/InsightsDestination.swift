import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

/// A verdict's receipt remembers which experiment it answered, so Undo puts
/// that question back rather than whichever was answered last.
private struct VerdictReceipt: Equatable {
    let experiment: InsightExperiment
    let presentation: ActionReceiptPresentation
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
    @State private var dailySeries: [DailySeries] = []
    @State private var seriesRange: InsightsRange = .week
    @State private var seriesIsLoading = false
    @State private var correlations: [DailyCorrelationEngine.Result] = []
    @State private var openExperiments: [InsightExperiment] = []
    @State private var correlationRecordedDays = 0
    @State private var correlationsLoaded = false
    @State private var monthlyReviewLoaded = false
    @State private var experimentReceipt: ActionReceiptPresentation?
    @State private var lastStartedExperiment: InsightExperiment?
    @State private var verdictReceipt: VerdictReceipt?
    @State private var monthlySummary: MonthlyReviewSummary?
    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.lifeBoardAtmosphereIsHosted) private var atmosphereIsHosted
    @Environment(\.lifeBoardRootActivity) private var rootActivity
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let router: AppRouter
    private let phaseIIRepository: any PhaseIIRepository
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
        self.phaseIIRepository = phaseIIRepository
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
        // The exclusion list is read and decoded once per rebuild. Asking the
        // store per event decoded it from UserDefaults for every record, on
        // the main thread.
        let excludedKeys = Set(EvaEvidenceExclusionStore.all().map(\.id))
        return SnapshotLifeEventProjectionRepository(events: store.snapshot.normalizedEvents + persistedPlanningEvents + wellnessEvents)
            .authorizedEvents(for: .insights, journalConsentGranted: false)
            .map { event in
                let kind = event.evidence.first?.kind ?? event.kind
                guard excludedKeys.isEmpty == false,
                      excludedKeys.contains("\(kind.lowercased()):\(event.sourceID.uuidString)") else { return event }
                var value = event
                value.allowedDestinations.subtract([.eva, .insights, .home])
                return value
            }
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
                        title: { $0.title },
                        identifier: \.rawValue
                    )

                    if planningEvidenceError != nil {
                        HStack(spacing: 12) {
                            Label("Couldn’t load plan and focus history.", systemImage: "exclamationmark.triangle")
                                .lifeboardFont(.support)
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                            Spacer(minLength: 0)
                            Button("Try again") { Task { await loadEvidence() } }
                                .font(.subheadline.weight(.semibold))
                                .minimumHitTarget()
                        }
                    }

                    // `DESIGN.md`: "Scrolling is not a quiet moment." Insights
                    // was one of three roots with no scroll entrance at all.
                    if lens == .experience {
                        insightContent
                            .lifeBoardScrollEntrance()
                    } else if store.isLoading && events.isEmpty && healthStore.aggregates.isEmpty {
                        ProgressView("Loading…")
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else if events.isEmpty
                                && renderSnapshot.hasPatternWindowEvidence == false
                                && healthStore.aggregates.isEmpty {
                        VStack(spacing: 12) {
                            StatusSurface(
                                state: .noRecord,
                                title: "Nothing recorded yet",
                                message: "Logs from Track show up here."
                            )
                            Button("Open Track") {
                                router.select(.track)
                            }
                            .buttonStyle(.lifeBoardPrimaryCompact)
                            .tint(Color(SemanticColorTokens.foundationApricotInk))
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("insights.empty.openTrack")
                        }
                        .frame(maxWidth: .infinity, minHeight: 240)
                    } else {
                        if lens == .overview, events.isEmpty {
                            // The claim above still reads two weeks; today is
                            // simply quiet so far.
                            InsightsQuietTodayRow { router.select(.track) }
                        }
                        insightContent
                            // Keyed on the lens so a switch crossfades rather
                            // than cutting between two different screens.
                            .id(lens)
                            .transition(.opacity)
                            .lifeBoardScrollEntrance()
                    }
                }
                .animation(MotionProfile.localState.animation(reduceMotion: reduceMotion), value: lens)
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
        .onChange(of: seriesRange) { _, _ in rebuildRenderSnapshot() }
        .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
            // A new day means new pairs and a new month read.
            correlationsLoaded = false
            monthlyReviewLoaded = false
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
        .refreshable {
            await loadEvidence()
            // Pull to refresh is the explicit way to re-read the heavy lenses.
            switch lens {
            case .overview: await loadCorrelations()
            case .review: await loadMonthlyReview()
            default: break
            }
        }
        .accessibilityIdentifier("foundation.insights")
    }
}

extension InsightsDestination {
    @ViewBuilder
    private var insightContent: some View {
        switch lens {
        case .overview:
            if isUnifiedInsightDismissed {
                SurfaceCard {
                    HStack {
                        Text("Insight hidden")
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
                    completenessDescription: evidenceCompletenessDescription,
                    exploreWithEva: { askEva() },
                    dismissEverywhere: {
                        EvaInsightStateStore.dismiss(insightID: unifiedInsight.id, kind: "insights_overview")
                        insightStateRevision += 1
                    }
                )
            }

            // Evidence follows the interpretation. The health section — which
            // carries a metric at hero scale — used to render *above* the hero,
            // so the screen opened on a number rather than on the claim.
            // `DESIGN.md`: "the interpretation is the hero … charts, tallies,
            // and evidence follow in clay".
            InsightsHealthSection(healthStore: healthStore, router: router)
            InsightsCorrelationsSection(
                results: correlations,
                openExperiments: openExperiments,
                startExperiment: { result, template in await startExperiment(from: result, template: template) },
                recordedDays: correlationRecordedDays
            )
            // Once per visit, not on every return to Overview: the month of
            // series behind this is the heaviest read on the screen.
            .task { if correlationsLoaded == false { await loadCorrelations() } }
            if let experimentReceipt {
                // Undo is offered only by the receipt of the experiment it
                // would cancel. A failed start used to carry Undo too, and
                // that cancelled whichever experiment had last succeeded.
                ReceiptBar(
                    experimentReceipt,
                    undo: InsightsExperimentUndoPolicy.canUndo(
                        receiptID: experimentReceipt.id,
                        lastStartedID: lastStartedExperiment?.id
                    ) ? { Task { await undoExperiment(receiptID: experimentReceipt.id) } } : nil,
                    destination: nil,
                    onDismiss: { self.experimentReceipt = nil }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        case .trends:
            InsightsSeriesSection(series: dailySeries, isLoading: seriesIsLoading, range: $seriesRange)
                .task(id: seriesRange) { await loadDailySeries() }
            InsightsTrendsSection(
                interpretation: interpretation,
                sourceCounts: sourceCounts,
                rangeDays: seriesRange.days
            )
        case .review:
            InsightsInlineWeeklyReview(router: router)
            InsightsMonthlyReviewSection(
                summary: monthlySummary,
                recordVerdict: { experiment, verdict in
                    await recordVerdict(verdict, for: experiment)
                }
            )
            .task { if monthlyReviewLoaded == false { await loadMonthlyReview() } }
            if let verdictReceipt {
                ReceiptBar(
                    verdictReceipt.presentation,
                    undo: { Task { await undoVerdict(verdictReceipt) } },
                    destination: nil,
                    onDismiss: { self.verdictReceipt = nil }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityIdentifier("insights.review.verdict.receipt")
            }
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
        // Typed evidence ids travel with the request; the prose stays as the
        // composer's prefill only.
        router.presentEva(
            context: EvaLaunchContext(kind: .insight, recordIDs: context.evidenceReferences, summary: resolved.claim),
            prompt: summary
        )
    }

    private func loadEvidence() async {
        async let trackLoad: Void = store.load()
        async let experienceLoad: Void = loadExperience()
        async let healthLoad: Void = loadHealthEvidence()
        if let planningRepository {
            do {
                // Bounded to the longest range Insights can show (a year),
                // not every receipt ever written.
                let since = Calendar.current.date(
                    byAdding: .day,
                    value: -(InsightsRange.year.days + 1),
                    to: Calendar.current.startOfDay(for: Date())
                )
                let records = try await planningRepository.fetchMutationReceipts(since: since)
                let proposalSignals = (try? await DayOpenProposalSignalStore.shared.signals()) ?? []
                let sessions = try await planningRepository.sessions(since: since)
                let focusCommands = try await planningRepository.commandReceipts(since: since)
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
            trendsDays: seriesRange.days,
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
    /// One value per day per domain from the stores that already exist. The
    /// closures keep the loader pure and the root free of the container
    /// except for the habit use cases, which only the coordinator owns.
    private func loadDailySeries() async {
        seriesIsLoading = true
        defer { seriesIsLoading = false }
        dailySeries = await InsightsDailySeriesLoader.load(range: seriesRange, sources: dailySeriesSources)
    }

    private var dailySeriesSources: InsightsDailySeriesSources {
        let planning = planningRepository
        let journal = phaseIIRepository
        let gamification = gamificationRepository
        var sources = InsightsDailySeriesSources()
        sources.health = { domain, range, now in
            await HealthCoordinator.shared.metricsReader.cachedHistory(domain: domain, range: range, now: now)
        }
        sources.focusSessions = { since in
            (try? await planning?.sessions(since: since)) ?? []
        }
        sources.journalDays = { from, to in
            (try? await journal.fetchJournalDays(from: from, to: to)) ?? []
        }
        sources.thingsDone = { from, to in
            guard let gamification else { return [] }
            let aggregates: [DailyXPAggregateDefinition] = (try? await withCheckedThrowingContinuation { continuation in
                gamification.fetchDailyAggregates(
                    from: XPCalculationService.periodKey(for: from),
                    to: XPCalculationService.periodKey(for: to)
                ) { continuation.resume(with: $0) }
            }) ?? []
            return aggregates.compactMap { aggregate in
                XPCalculationService.date(forPeriodKey: aggregate.dateKey).map { ($0, Double(aggregate.eventCount)) }
            }
        }
        sources.habitHistory = { endingOn, dayCount in
            guard let coordinator = CompositionRoot.shared.useCaseCoordinator else { return [] }
            let rows: [HabitLibraryRow] = (try? await withCheckedThrowingContinuation { continuation in
                coordinator.getHabitLibrary.execute(includeArchived: false) { continuation.resume(with: $0) }
            }) ?? []
            guard rows.isEmpty == false else { return [] }
            return (try? await withCheckedThrowingContinuation { continuation in
                coordinator.getHabitHistory.execute(habitIDs: rows.map(\.habitID), endingOn: endingOn, dayCount: dayCount) { continuation.resume(with: $0) }
            }) ?? []
        }
        return sources
    }

    /// This month against the month before: the same series, loaded twice
    /// with `now` moved back, plus the loop's own notes and open experiments.
    private func loadMonthlyReview() async {
        let calendar = Calendar.current
        let now = Date()
        let monthAgo = calendar.date(byAdding: .day, value: -30, to: now) ?? now
        async let current = InsightsDailySeriesLoader.load(range: .month, sources: dailySeriesSources, now: now)
        async let previous = InsightsDailySeriesLoader.load(range: .month, sources: dailySeriesSources, now: monthAgo)
        let notes: [ReflectionNote] = await {
            guard let repository = CompositionRoot.shared.useCaseCoordinator?.reflectionNoteRepository else { return [] }
            return (try? await withCheckedThrowingContinuation { continuation in
                repository.fetchNotes(query: ReflectionNoteQuery(kinds: [.dayClose, .weeklyReview])) { continuation.resume(with: $0) }
            }) ?? []
        }()
        let experiments = await experimentStore.experiments()
        monthlyReviewLoaded = true
        monthlySummary = MonthlyReviewSummary.make(
            notes: notes,
            current: await current,
            previous: await previous,
            experiments: experiments,
            now: now,
            calendar: calendar
        )
    }

    /// Correlations read a month of the same series the Trends lens draws;
    /// ten paired days is the floor, so a week could never say anything.
    private func loadCorrelations() async {
        let saved = seriesRange
        if seriesRange != .month { seriesRange = .month }
        await loadDailySeries()
        seriesRange = saved
        correlations = DailyCorrelationEngine.rank(dailySeries)
        correlationRecordedDays = dailySeries.map(\.points.count).max() ?? 0
        correlationsLoaded = true
        openExperiments = await experimentStore.open()
    }

    private var experimentStore: InsightExperimentStore {
        let coordinator = CompositionRoot.shared.useCaseCoordinator
        var dependencies = InsightExperimentStore.Dependencies()
        dependencies.notes = coordinator?.reflectionNoteRepository
        dependencies.createHabit = { template in
            guard let coordinator else { throw CocoaError(.featureUnsupported) }
            let areas: [LifeArea] = try await withCheckedThrowingContinuation { continuation in
                coordinator.lifeAreaRepository.fetchAll { continuation.resume(with: $0) }
            }
            guard let area = areas.first else { throw CocoaError(.fileNoSuchFile) }
            let request = CreateHabitRequest(
                title: template.title,
                lifeAreaID: area.id,
                kind: template.kind == .negative ? .negative : .positive,
                trackingMode: .dailyCheckIn,
                icon: HabitIconMetadata(symbolName: template.systemImage, categoryKey: "insights"),
                colorHex: template.colorHex,
                targetConfig: HabitTargetConfig(target: template.target),
                metricConfig: HabitMetricConfig(),
                cadence: template.cadence
            )
            let record: HabitDefinitionRecord = try await withCheckedThrowingContinuation { continuation in
                coordinator.createHabit.execute(request: request) { continuation.resume(with: $0) }
            }
            return record.id
        }
        dependencies.deleteHabit = { id in
            guard let coordinator else { return }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                coordinator.deleteHabit.execute(id: id) { continuation.resume(with: $0) }
            }
        }
        return InsightExperimentStore(dependencies: dependencies)
    }

    private func startExperiment(from result: DailyCorrelationEngine.Result, template: HabitTemplate) async -> Bool {
        do {
            let experiment = try await experimentStore.start(
                hypothesis: DailyCorrelationEngine.sentence(for: result),
                correlationID: result.id,
                template: template
            )
            lastStartedExperiment = experiment
            openExperiments = await experimentStore.open()
            Haptic.commit.play()
            withAnimation(InteractionMotion.sheetRise(reduceMotion: reduceMotion)) {
                experimentReceipt = ActionReceiptPresentation(
                    id: experiment.id,
                    message: ReceiptCopy.experimentStarted(template.title),
                    detail: ReceiptCopy.experimentStartedDetail
                )
            }
            NotificationCenter.default.post(name: .homeHabitMutation, object: nil)
            return true
        } catch {
            Haptic.fail.play()
            withAnimation(InteractionMotion.sheetRise(reduceMotion: reduceMotion)) {
                experimentReceipt = ActionReceiptPresentation(
                    id: UUID(),
                    message: ReceiptCopy.experimentFailed,
                    detail: error.localizedDescription
                )
            }
            return false
        }
    }

    private func recordVerdict(_ verdict: InsightExperiment.Verdict, for experiment: InsightExperiment) async -> Bool {
        do {
            try await experimentStore.record(verdict, for: experiment)
        } catch {
            Haptic.fail.play()
            return false
        }
        // Persistence first, then the haptic and the receipt.
        Haptic.commit.play()
        withAnimation(InteractionMotion.sheetRise(reduceMotion: reduceMotion)) {
            verdictReceipt = VerdictReceipt(
                experiment: experiment,
                presentation: ActionReceiptPresentation(message: ReceiptCopy.verdict(verdict))
            )
        }
        await loadMonthlyReview()
        return true
    }

    private func undoVerdict(_ receipt: VerdictReceipt) async {
        do {
            try await experimentStore.clearVerdict(for: receipt.experiment)
        } catch {
            Haptic.fail.play()
            return
        }
        withAnimation(InteractionMotion.sheetRise(reduceMotion: reduceMotion)) {
            verdictReceipt = nil
        }
        await loadMonthlyReview()
    }

    private func undoExperiment(receiptID: UUID) async {
        guard let experiment = lastStartedExperiment,
              InsightsExperimentUndoPolicy.canUndo(receiptID: receiptID, lastStartedID: experiment.id)
        else { return }
        try? await experimentStore.cancel(experiment)
        lastStartedExperiment = nil
        withAnimation(InteractionMotion.sheetRise(reduceMotion: reduceMotion)) {
            experimentReceipt = nil
        }
        openExperiments = await experimentStore.open()
        NotificationCenter.default.post(name: .homeHabitMutation, object: nil)
    }

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

/// Overview on a day with nothing recorded yet, when earlier days still
/// support the claim: one quiet line and the one relevant next step.
private struct InsightsQuietTodayRow: View {
    let openTrack: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("Nothing logged today")
                .lifeboardFont(.support)
                .foregroundStyle(Color.lifeboard(.textSecondary))
            Spacer(minLength: 8)
            Button("Open Track", action: openTrack)
                .buttonStyle(.lifeBoardChip)
                .frame(minHeight: 44)
                .accessibilityIdentifier("insights.empty.openTrack")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insights.overview.quietToday")
    }
}
