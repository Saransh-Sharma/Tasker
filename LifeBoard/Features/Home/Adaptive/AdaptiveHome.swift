import Combine
import Observation
import SwiftUI
import LifeBoardDomain
import UIKit

struct AdaptiveHome: View {
    let projectionAdapter: HomeProjectionCoordinator
    let preferences: PresentationPreferences
    let router: AppRouter
    let captureRouter: CaptureRouter
    let phaseIIRepository: (any PhaseIIRepository)?
    let hasPlanningRepository: Bool
    /// Retained so the day-loop stage can ask whether today already has an
    /// applied close receipt. Already passed in for the context providers; this
    /// keeps a reference rather than adding a new dependency.
    let planningRepository: CoreDataPlanningRepository?
    let hasTrackFoundationRepository: Bool
    let onCustomizationChanged: (Bool) -> Void
    let contextProviderRegistry: HomeContextCandidateProviderRegistry
    /// The one getting-started card, if any, rendered as Home's first item so
    /// it scrolls with the day instead of sitting above it.
    let gettingStarted: HomeGettingStartedCard?
    /// Resolves what each Home mode actually changes. Modes were persisted and
    /// restored but had no reachable control and no effect beyond Low Energy.
    let modePolicy: any DashboardModePolicy = DeterministicDashboardModePolicy()

    @State var store: AdaptiveHomeStore
    @State var lifeOSStore: HomeLifeOSProjectionStore
    @State var repairStore: PlanStore?
    @State var healthStore = HealthCoordinator.shared.connectionStore
    @State var selectedMood: JournalMood = .none
    @State var moodEnergy: Int?
    @State var moodSaveError: String?
    @State var showsMoodDial = false
    @State var captureOrbState = CaptureOrbPresentationState()
    @State var contextReasonCandidate: HomeContextCandidate?
    @State var expandedTaskWidgetIDs: Set<UUID> = []
    @State var showsFastingError = false
    @State var showsFastEndReceipt = false
    @State var fastStartReceiptAt: Date?
    @State var contextSuppressionReceipt: ActionReceiptPresentation?
    @State var suppressedContext: HomeContextCandidate?
    @State var fastingStateChangeTrigger = 0
    @State var refreshCoordinator = AdaptiveHomeRefreshCoordinator()
    @State var renderPlanCache = HomeDashboardRenderPlanCache()
    @State var presentedRenderPlan = HomeDashboardRenderPlan.empty
    @State var isScrolling = false
    /// Drives the one-shot daypart cross-dissolve. Incremented on a real
    /// daypart boundary or a manual override, never on a redraw.
    @State var daypartTransitionTrigger = 0
    /// Bumped when the evening ritual is snoozed, so the entry row re-evaluates
    /// without waiting for the next Home reload.
    @State var dayRitualSnoozeGeneration = 0
    /// True while the repair body is showing its applied receipt. The stage
    /// resolver would otherwise drop to `.act` the moment the drift is gone and
    /// unmount the body — taking the receipt and its Undo with it.
    @State var repairReceiptIsShowing = false
    /// Whether today already has an applied day-close receipt. Drives `.rest`,
    /// which is what stops the ritual re-offering itself all evening.
    @State var dayLoopClosedToday = false
    /// The loop's own continuity, read from applied receipts.
    @State var dayLoopSummary: DayLoopSummary?
    /// Whether today already has an applied day-open receipt. Stops the morning
    /// re-offering a commitment that has already been made.
    @State var dayLoopCommittedToday = false
    /// In-app Home is already behind the device unlock, so a glanceable card
    /// shows its real value here by default. Redaction is for surfaces that
    /// render outside the unlocked app — widgets, Spotlight, notification
    /// previews — and for Work mode, which is what gets screen-shared.
    @AppStorage("lifeOS.home.sensitive_cards.enabled") var permitsSensitiveHomeContent = true
    @AppStorage("lifeOS.home.dashboardDensity.v1") var dashboardDensity: DashboardDensity = .balanced
    @Environment(\.homeHabitsToday) var homeHabitsToday
    @Environment(\.homeFocusCapture) var homeFocusCapture
    @Environment(\.homeOpenOverdueRescue) var homeOpenOverdueRescue
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.accessibilityReduceTransparency) var reduceTransparency
    @Environment(\.accessibilityVoiceOverEnabled) var voiceOverEnabled
    @Environment(\.colorScheme) var colorScheme
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.lifeBoardAtmosphereSnapshot) var atmosphereSnapshot
    @Environment(\.lifeBoardAtmosphereIsHosted) var atmosphereIsHosted
    @Environment(\.lifeBoardRootActivity) var rootActivity

    init(
        projectionAdapter: HomeProjectionCoordinator,
        preferences: PresentationPreferences,
        router: AppRouter,
        captureRouter: CaptureRouter,
        repository: (any DashboardLayoutRepository)?,
        phaseIIRepository: (any PhaseIIRepository)? = nil,
        planningRepository: CoreDataPlanningRepository? = nil,
        trackFoundationRepository: CoreDataTrackFoundationRepository? = nil,
        goalSampleProvider: (any GoalSampleRepository)? = nil,
        wellnessRepository: (any WellnessRepository)? = nil,
        nutritionRepository: (any NutritionRepository)? = nil,
        lifeMomentRepository: (any LifeMomentRepository)? = nil,
        gettingStarted: HomeGettingStartedCard? = nil,
        onCustomizationChanged: @escaping (Bool) -> Void = { _ in }
    ) {
        self.gettingStarted = gettingStarted
        self.projectionAdapter = projectionAdapter
        self.preferences = preferences
        self.router = router
        self.captureRouter = captureRouter
        self.phaseIIRepository = phaseIIRepository
        self.hasPlanningRepository = planningRepository != nil
        self.planningRepository = planningRepository
        self.hasTrackFoundationRepository = trackFoundationRepository != nil
        self.onCustomizationChanged = onCustomizationChanged
        self.contextProviderRegistry = HomeContextCandidateProviderRegistry.forHome(
            planningRepository: planningRepository,
            phaseIIRepository: phaseIIRepository,
            trackFoundationRepository: trackFoundationRepository,
            lifeMomentRepository: lifeMomentRepository
        )
        _repairStore = State(initialValue: planningRepository.map {
            PlanStore(planningRepository: $0, blockRepository: $0,
                scenarioCoordinator: DefaultPlanningScenarioCoordinator(planning: $0, mutations: $0))
        })
        _store = State(initialValue: AdaptiveHomeStore(repository: repository))
        _lifeOSStore = State(initialValue: HomeLifeOSProjectionStore(
            planningRepository: planningRepository,
            trackRepository: trackFoundationRepository,
            phaseIIRepository: phaseIIRepository,
            goalSampleProvider: goalSampleProvider,
            wellnessRepository: wellnessRepository,
            nutritionRepository: nutritionRepository,
            lifeMomentRepository: lifeMomentRepository,
            healthMetrics: HealthCoordinator.shared.metricsReader
        ))
    }

    var body: some View {
        @Bindable var store = store
        let daypart = atmosphereSnapshot.semanticDaypart
        let palette = DaypartTokens.functionalPalette(for: daypart, colorScheme: colorScheme)
        let ambientPalette = daypart == .night && horizontalSizeClass == .regular
            ? DaypartTokens.palette(for: daypart)
            : palette
        let renderPlan = presentedRenderPlan
        let stage = dayLoopStage
        let builders = cardBuilders(daypart: daypart, palette: palette)

        ZStack(alignment: .bottom) {
            if atmosphereIsHosted == false {
                ScenicBackdrop(
                    scene: .home,
                    daypart: daypart,
                    requestedTier: preferences.renderingTier,
                    comfortProfile: preferences.comfortProfile
                )
                // A static warm tooth so the large flat canvas areas read as
                // pressed paper. No time input — this must never animate, and
                // it drops out entirely under Increased Contrast.
                .lifeboardPaperGrain()
                .ignoresSafeArea()
                .accessibilityHidden(true)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if let gettingStarted, store.isCustomizing == false {
                        gettingStarted
                    }

                    if let errorMessage = store.errorMessage {
                        StatusSurface(
                            state: .stale,
                            title: String(localized: "Home layout"),
                            message: errorMessage,
                            actionTitle: String(localized: "Dismiss"),
                            action: { store.dismissError() }
                        )
                    }

                    let budget = renderPlan.budget

                    if V2FeatureFlags.homeLoopSpineV1Enabled {
                        AdaptiveHomeLoopSpine(
                            stage: stage,
                            nowState: nowSectionState,
                            dayLoopSummary: dayLoopSummary,
                            now: nowSection(palette: palette, showsHeading: false),
                            ritual: dayRitualEntry(palette: palette),
                            repair: HomeSpineRepairBody(
                                lifeOSStore: lifeOSStore,
                                router: router,
                                repairStore: repairStore,
                                receiptIsShowing: $repairReceiptIsShowing
                            )
                        )
                    } else {
                        nowSection(palette: palette, showsHeading: true)
                    }

                    // On a quiet day Up next has nothing to show, and Today's task
                    // card already says so (and keeps its Add button), so the day
                    // is described once rather than by two empty cards.
                    if budget.showsDayAhead, HomeQuietDay.isQuiet(
                        upNextCount: HomeTodayStorySection.upNextItems(lifeOSStore: lifeOSStore, now: Date()).count,
                        agendaTaskCount: lifeOSStore.taskAgenda.tasks.count,
                        hasLoaded: lifeOSStore.hasLoadedCore
                    ) == false {
                        HomeTodayStorySection(
                            projectionAdapter: projectionAdapter,
                            lifeOSStore: lifeOSStore,
                            router: router,
                            captureRouter: captureRouter,
                            palette: palette
                        )
                    }

                    // Today's committed work sits directly under orientation.
                    // It previously fell through to "Your space" and rendered
                    // below wellbeing and reflection on a default install.
                    // Habits are logged here, where the day is read, rather than
                    // only behind a link to the Habit Board.
                    if let habitsToday = homeHabitsToday, habitsToday.isAvailable() {
                        HomeHabitsTodaySection(
                            router: router,
                            palette: ambientPalette,
                            viewModel: habitsToday.makeViewModel()
                        )
                    }

                    if budget.showsToday {
                        AdaptiveHomePlacementSection(
                            title: "Today",
                            placements: renderPlan.today,
                            renderPlan: renderPlan,
                            daypart: daypart,
                            palette: palette,
                            ambientPalette: ambientPalette,
                            store: store,
                            builders: builders
                        )
                    }

                    if lifeOSStore.taskAgenda.overdueTasks.isEmpty == false {
                        HomeSectionHeading("Needs you", palette: palette)
                        HomeUpNextRescueRow(count: lifeOSStore.taskAgenda.overdueTasks.count, palette: palette) {
                            // The same deck Plan's Rescue card opens, so "Rescue"
                            // means one thing wherever it is tapped.
                            if let homeOpenOverdueRescue {
                                Haptic.pick.play()
                                homeOpenOverdueRescue.open()
                            } else {
                                router.navigate(.weeklyPlanningWorkspace(.overdue), in: .plan)
                            }
                        }
                    }
                    if budget.showsNeedsAttention, store.contextSelection.candidates.count > 1 {
                        HomeNeedsAttentionSection(
                            store: store,
                            router: router,
                            palette: palette,
                            onPinAfterAction: pinContextAfterAction
                        )
                    }

                    HomeSectionHeading("Keep steady", palette: ambientPalette)
                    HomeSignalRow(
                        lifeOSStore: lifeOSStore,
                        healthStore: healthStore,
                        router: router,
                        captureRouter: captureRouter,
                        hasTrackFoundationRepository: hasTrackFoundationRepository,
                        hasPhaseIIRepository: phaseIIRepository != nil,
                        palette: ambientPalette,
                        reduceMotion: reduceMotion,
                        showsFastEndReceipt: $showsFastEndReceipt,
                        fastStartReceiptAt: $fastStartReceiptAt,
                        showsFastingError: $showsFastingError,
                        fastingStateChangeTrigger: $fastingStateChangeTrigger
                    )
                    if let fastStartReceiptAt {
                        HomeFastingStartReceipt(
                            startedAt: fastStartReceiptAt,
                            router: router,
                            reduceMotion: reduceMotion,
                            fastStartReceiptAt: $fastStartReceiptAt
                        )
                        .transition(.opacity)
                    }
                    if showsFastEndReceipt {
                        HomeFastingEndReceipt(
                            lifeOSStore: lifeOSStore,
                            palette: ambientPalette,
                            reduceMotion: reduceMotion,
                            showsFastEndReceipt: $showsFastEndReceipt,
                            showsFastingError: $showsFastingError,
                            fastingStateChangeTrigger: $fastingStateChangeTrigger
                        )
                            .transition(.asymmetric(
                                insertion: .scale(scale: 0.96, anchor: .top).combined(with: .opacity),
                                removal: .opacity
                            ))
                    }

                    // Same group as the signal row above, which already carries
                    // the "Keep steady" heading; a second one read as a stutter.
                    AdaptiveHomePlacementSection(
                        title: "Keep steady",
                        placements: renderPlan.keepSteady,
                        renderPlan: renderPlan,
                        daypart: daypart,
                        palette: palette,
                        ambientPalette: ambientPalette,
                        showsHeading: false,
                        store: store,
                        builders: builders
                    )

                    // Outside the budget on purpose. `showsCloseLoop` is false
                    // for both Low Energy and Minimal density, which hid the
                    // ritual on exactly the days that most need a gentle close.
                    // The *placement section* stays budgeted; the door does not.
                    //
                    // Under the spine the ritual is already the `.close` stage
                    // body, so repeating it here would restate the same
                    // projection twice on one screen.
                    if V2FeatureFlags.homeLoopSpineV1Enabled == false {
                        dayRitualEntry(palette: palette)
                    }

                    // Retired as a rendered section under the spine: "Close the
                    // loop" is what the spine now *is*, and two things by that
                    // name on one screen is the restatement DESIGN.md forbids.
                    // Its placements are not lost — `effectiveSectionRole`
                    // coalesces them into the pinned dashboard.
                    if budget.showsCloseLoop, V2FeatureFlags.homeLoopSpineV1Enabled == false {
                        AdaptiveHomePlacementSection(
                            title: "Close the loop",
                            placements: renderPlan.closeLoop,
                            renderPlan: renderPlan,
                            daypart: daypart,
                            palette: palette,
                            ambientPalette: ambientPalette,
                            store: store,
                            builders: builders
                        )
                    }

                    if budget.showsUserSpace {
                        AdaptiveHomeUserSpaceSection(
                            title: dashboardSectionTitle,
                            placements: renderPlan.supporting,
                            renderPlan: renderPlan,
                            daypart: daypart,
                            palette: palette,
                            ambientPalette: ambientPalette,
                            store: store,
                            builders: builders
                        )
                    }

                    if store.isCustomizing {
                        Button {
                            store.showsGallery = true
                        } label: {
                            Label("Add a card", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                        }
                        .buttonStyle(.bordered)
                        .tint(palette.color(for: .foreground))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                // Clears the floating composer + dock chrome. The shell's
                // atmosphere background ignores the safe area, so this root
                // pads explicitly rather than relying on inset propagation.
                .padding(.bottom, store.isCustomizing ? 16 : 150)
            }
            .scrollIndicators(.hidden)
            .onScrollPhaseChange { _, phase in
                isScrolling = phase != .idle
                store.setContextFrozen(isScrolling, reason: "home-scroll")
                if isScrolling == false, contextRefreshIsDeferred == false {
                    store.applyPendingContext()
                }
            }
            .lifeBoardReportsComposerScroll()
            .accessibilityIdentifier("foundation.home.scroll")

        }
        // The screen changing time of day should feel like weather moving
        // across it, not like a palette swap.
        .lifeboardDaypartCrossDissolve(trigger: daypartTransitionTrigger, daypart: daypart)
        .safeAreaInset(edge: .bottom, spacing: 8) {
            if store.isCustomizing {
                HomeCustomizationActionBar(
                    store: store,
                    palette: palette,
                    motionAnimation: motionAnimation
                )
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }
        }
        .foregroundStyle(palette.color(for: .foreground))
        .toolbar(.hidden, for: .navigationBar)
        .modifier(presentations(palette: palette))
        .modifier(lifecycle(daypart: daypart))
    }
}

// MARK: - Helpers
//
// Same-file private extension: private members stay reachable, and the
// file-size gate measures this span separately from the struct above.

extension AdaptiveHome {
    /// See `HomeDashboardRenderPlanner`; rebuilt per use, it holds only references.
    var renderPlanner: HomeDashboardRenderPlanner {
        HomeDashboardRenderPlanner(
            store: store,
            modePolicy: modePolicy,
            dashboardDensity: dashboardDensity,
            usesAccessibilityLayout: dynamicTypeSize.isAccessibilitySize
        )
    }

    /// The "Now" region as a concrete struct so its `body` runs in its own
    /// frame rather than inline here.
    func nowSection(palette: DaypartPalette, showsHeading: Bool) -> AdaptiveHomeNowSection {
        AdaptiveHomeNowSection(
            store: store,
            lifeOSStore: lifeOSStore,
            projectionAdapter: projectionAdapter,
            router: router,
            captureRouter: captureRouter,
            palette: palette,
            showsHeading: showsHeading,
            state: nowSectionState,
            contextReasonCandidate: $contextReasonCandidate,
            contextSuppressionReceipt: $contextSuppressionReceipt,
            suppressedContext: $suppressedContext,
            onPinAfterAction: { pinContextAfterAction($0) }
        )
    }

    /// Everything a placement section needs to build one card, captured once
    /// per `body` so the sections stay free of Home's own state.
    func cardBuilders(daypart: ResolvedDaypart, palette: DaypartPalette) -> HomeDashboardCardBuilders {
        HomeDashboardCardBuilders(
            resolvedKind: { placement in renderPlanner.resolvedWidgetKind(for: placement, daypart: daypart) },
            effectivePreset: { renderPlanner.effectivePreset(for: $0) },
            layoutRevision: { placement, kind, preset in layoutRevision(for: placement, kind: kind, preset: preset) },
            scrollEntranceIntensity: { placement in scrollEntranceIntensity(for: placement, daypart: daypart) },
            makeWidget: { placement, kind, preset in
                dashboardWidget(for: placement, kind: kind, preset: preset, daypart: daypart, palette: palette)
            }
        )
    }



    func refreshContextSelection(
        now: Date = HomeReferenceClock.now,
        boundary: HomeContextRefreshBoundary = .explicitRefresh,
        immediate: Bool = false
    ) {
        refreshCoordinator.request(
            now: now,
            boundary: boundary,
            immediate: immediate,
            deferred: contextRefreshIsDeferred,
            operation: performContextRefresh
        )
    }

    var contextRefreshIsDeferred: Bool {
        rootActivity.performsContinuousWork == false
    }

    @MainActor
    func performContextRefresh(
        _ request: AdaptiveHomeRefreshCoordinator.Request,
        generation: Int
    ) async {
        await lifeOSStore.load(isCurrent: { refreshCoordinator.isCurrent(generation) })
        guard refreshCoordinator.isCurrent(generation) else { return }
        let permitsSensitive = permitsSensitiveHomeContent
        let mode = router.dashboardMode
        // Always retain the newest candidate inputs. The context service owns
        // automatic structural deferral; idle applies these without another read.
        do {
            let local = HomeContextCandidateDerivation.homeContextCandidates(lifeOSStore: lifeOSStore, now: request.now)
            let domainCandidates = await contextProviderRegistry.candidates(
                context: .init(date: request.now, refreshBoundary: request.boundary)
            )
            guard refreshCoordinator.isCurrent(generation) else { return }
            let candidates = mode == .lowEnergy
                ? HomeContextCandidateDerivation.lowEnergyCandidates(from: local + domainCandidates, now: request.now)
                : local + domainCandidates
            store.refreshContext(
                candidates: candidates,
                permitsSensitiveHomeContent: permitsSensitive,
                now: request.now,
                force: request.urgency == .immediate
            )
        }
        guard refreshCoordinator.isCurrent(generation) else { return }
        await refreshCardSnapshots(now: request.now, generation: generation)
    }


    /// Resolves provider snapshots for every currently visible placement at
    /// its effective size, so glance/compact bodies read domain providers
    /// instead of canonical stores.
    func refreshCardSnapshots(now: Date = HomeReferenceClock.now, generation: Int? = nil) async {
        let daypart = atmosphereSnapshot.semanticDaypart
        let renderPlan = dashboardRenderPlan(daypart: daypart, now: now)
        var seen = Set<String>()
        var requests: [(kind: DashboardWidgetKind, size: HomeCardSize)] = []
        for placement in renderPlan.visible {
            let kind = renderPlan.resolvedKinds[placement.id]
                ?? renderPlanner.resolvedWidgetKind(for: placement, daypart: daypart, now: now)
            let size = renderPlan.effectivePresets[placement.id]
                ?? renderPlanner.effectivePreset(for: placement.semanticSize)
            let key = HomeLifeOSProjectionStore.cardSnapshotKey(kind, size)
            guard seen.insert(key).inserted else { continue }
            requests.append((kind, size))
        }
        await lifeOSStore.refreshCardSnapshots(
            requests: requests,
            permitsSensitive: permitsSensitiveHomeContent,
            at: now,
            isCurrent: { generation.map(refreshCoordinator.isCurrent) ?? true }
        )
    }



    /// Says how many things are actually asking for attention, which the user
    /// cannot count at a glance once the list is longer than one.
    var nowSectionState: String? {
        let count = store.contextSelection.candidates.count
        guard count > 1 else { return nil }
        return String(localized: "\(count) suggestions")
    }


    func pinContextAfterAction(_ candidate: HomeContextCandidate) {
        let section: HomeSectionRole = switch candidate.resolvedSemanticRole {
        case .primaryNow, .dayAheadStory: .today
        case .care: .keepSteady
        case .reflection: .closeLoop
        case .attention: .userSpace
        }
        store.pinContext(candidate, section: section)
        Task { await store.saveCustomization() }
    }




    var dashboardRenderPlanInput: HomeDashboardRenderPlanSignature {
        return HomeDashboardRenderPlanSignature(
            placements: store.activeLayout.placements,
            mode: router.dashboardMode,
            density: dashboardDensity,
            daypart: atmosphereSnapshot.semanticDaypart,
            calendarDay: Calendar.current.startOfDay(for: HomeReferenceClock.now),
            isRegular: horizontalSizeClass == .regular,
            usesAccessibilityLayout: dynamicTypeSize.isAccessibilitySize,
            loopSpineEnabled: V2FeatureFlags.homeLoopSpineV1Enabled,
            contextCandidates: [],
            candidateInputs: store.contextSelection.candidates,
            dynamicType: String(describing: dynamicTypeSize),
            locale: Locale.current.identifier,
            timeZone: TimeZone.current.identifier,
            permitsSensitive: permitsSensitiveHomeContent
        )
    }

    func dashboardRenderPlan(
        daypart: ResolvedDaypart,
        now: Date = HomeReferenceClock.now
    ) -> HomeDashboardRenderPlan {
        let mode = router.dashboardMode
        let signature = dashboardRenderPlanInput
        return renderPlanCache.resolve(signature: signature) {
            renderPlanner.buildDashboardRenderPlan(mode: mode, daypart: daypart, now: now)
        }
    }




    func layoutRevision(for placement: DashboardWidgetPlacementValue, kind: DashboardWidgetKind,
                                preset: WidgetSizePreset) -> DashboardLayoutRevision {
        var content = lifeOSStore.cardSnapshot(kind: kind, size: preset)
        content?.updatedAt = .distantPast
        return DashboardLayoutRevision(id: placement.id, expanded: expandedTaskWidgetIDs.contains(placement.id),
            content: content, dynamicType: String(describing: dynamicTypeSize), locale: Locale.current.identifier)
    }

    var motionAnimation: Animation? {
        // Calm keeps the quieter local-state curve; everything else reflows.
        preferences.comfortProfile == .calm
            ? MotionProfile.localState.animation(reduceMotion: reduceMotion)
            : MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)
    }

    func scrollEntranceIntensity(
        for placement: DashboardWidgetPlacementValue,
        daypart: ResolvedDaypart
    ) -> CGFloat {
        guard store.isCustomizing == false else { return 0 }
        let isExpandedTaskCard = renderPlanner.resolvedWidgetKind(for: placement, daypart: daypart) == .tasks
            && expandedTaskWidgetIDs.contains(placement.id)
        // The shared entrance transition blurs an entire widget while its
        // bottom edge enters the viewport. An expanded task card can be taller
        // than that viewport, so it never reaches the identity phase and its
        // already-visible header and rows stay blurred during normal scrolling.
        return isExpandedTaskCard ? 0 : 1
    }

    /// Builds one dashboard card. Deliberately returns the concrete
    /// `HomeDashboardWidget` rather than `some View`: the card's own `body`
    /// then runs in its own stack frame instead of being inlined here.
    func dashboardWidget(
        for placement: DashboardWidgetPlacementValue,
        kind: DashboardWidgetKind,
        preset: WidgetSizePreset,
        daypart: ResolvedDaypart,
        palette: DaypartPalette
    ) -> HomeDashboardWidget {
        HomeDashboardWidget(
            placement: placement,
            kind: kind,
            preset: preset,
            daypart: daypart,
            palette: palette,
            store: store,
            lifeOSStore: lifeOSStore,
            projectionAdapter: projectionAdapter,
            router: router,
            captureRouter: captureRouter,
            modePolicy: modePolicy,
            dashboardDensity: dashboardDensity,
            hasPlanningRepository: hasPlanningRepository,
            hasTrackFoundationRepository: hasTrackFoundationRepository,
            dayLoopSummary: dayLoopSummary,
            motionAnimation: motionAnimation,
            reduceMotion: reduceMotion,
            selectedMood: selectedMood,
            moodEnergy: moodEnergy,
            showsMoodDial: $showsMoodDial,
            expandedTaskWidgetIDs: $expandedTaskWidgetIDs,
            onOpenWidget: { kind in
                HomeWidgetRouteResolver.open(kind, router: router) { homeFocusCapture?.perform() }
            }
        )
    }

    /// The ritual row. Same reasoning as `dashboardWidget`: a concrete struct,
    /// not an inlined `some View`.
    func dayRitualEntry(palette: DaypartPalette) -> HomeDayRitualRow {
        HomeDayRitualRow(
            ritual: activeDayRitual,
            router: router,
            dayRitualSnoozeGeneration: $dayRitualSnoozeGeneration
        )
    }

    // MARK: - Loop spine


    var dashboardSectionTitle: String {
        let base = V2FeatureFlags.homeLoopSpineV1Enabled ? String(localized: "Your dashboard") : String(localized: "Your space")
        return store.isCustomizing ? String(localized: "\(base) · drag to reorder") : base
    }




    /// The day-loop stage Home is currently in; see `HomeDayLoopResolution`.
    var dayLoopStage: DayLoopStage {
        // Read so a snooze re-evaluates this without a full Home reload.
        _ = dayRitualSnoozeGeneration
        return HomeDayLoopResolution.stage(
            closedToday: dayLoopClosedToday,
            openedToday: dayLoopCommittedToday,
            // Already filtered by `PlanDriftPolicy`: one slipped block is a
            // normal day and stays at 0.
            driftCount: lifeOSStore.driftCount,
            // Low Energy changes the spine's *stage set*, not its visibility.
            suppressesRepair: router.dashboardMode == .lowEnergy,
            holdsRepair: repairReceiptIsShowing,
            now: HomeReferenceClock.now
        )
    }

    var activeDayRitual: HomeDayRitual? {
        HomeDayLoopResolution.ritual(for: dayLoopStage, now: HomeReferenceClock.now)
    }

    /// Refreshes `.rest` from the ledger. The receipt's applied/undone state is
    /// the record, so an undone close correctly reopens the ritual.
    func refreshDayLoopStage() async {
        guard let planningRepository else { return }
        let now = HomeReferenceClock.now
        let today = PlanningDay(date: now)
        let closeSource = DayCloseScenarioBuilder.receiptSource(for: today)
        let openSource = DayOpenScenarioBuilder.receiptSource(for: today)
        dayLoopClosedToday = (try? await planningRepository.hasAppliedReceipt(source: closeSource)) ?? false
        dayLoopCommittedToday = (try? await planningRepository.hasAppliedReceipt(source: openSource)) ?? false

        // One fetch covers both the stage and the rhythm. Bounded to the window
        // plus a day so this never walks the whole receipt history.
        let horizon = Calendar.current.date(
            byAdding: .day,
            value: -(DayLoopLedger.defaultWindow + 1),
            to: now
        )
        if let records = try? await planningRepository.fetchMutationReceipts(since: horizon) {
            dayLoopSummary = DayLoopLedger.summarize(records: records, now: now)
        }
    }




}
