import SwiftUI
import SwiftData
import LifeBoardTranscription
import UIKit
import VisionKit

struct FoundationCompactChromeVisibilityPolicy {
    static func isVisible(
        destination: Destination,
        isPhoneInterface: Bool,
        isEvaComposerFocused: Bool,
        showsGlobalChrome: Bool
    ) -> Bool {
        guard showsGlobalChrome else { return false }
        return destination != .eva || isPhoneInterface == false || isEvaComposerFocused == false
    }
}

public struct FoundationShell: View {
    let homeViewModel: HomeViewModel
    let runtime: FoundationCoordinator
    let showsReferenceHome: Bool
    let homeProjectionAdapter: HomeProjectionCoordinator
    let dashboardLayoutRepository: any DashboardLayoutRepository
    let phaseIIRepository: any PhaseIIRepository
    let planningRepository: CoreDataPlanningRepository
    let planDependencies: PlanFeatureDependencies?
    let trackFoundationRepository: CoreDataTrackFoundationRepository
    let habitRuntimeReadRepository: any HabitRuntimeReadRepositoryProtocol
    let routineLinkedMutationApplier: any RoutineLinkedMutationApplying
    let goalSampleProvider: any GoalSampleRepository
    let starterPackMutationApplier: any StarterPackCanonicalMutationApplying
    let habitRecoveryMutationApplier: any HabitRecoveryMutationApplying
    let nutritionRepository: any NutritionRepository
    let lifeMomentRepository: any LifeMomentRepository
    let wellnessRepository: any WellnessRepository
    let gamificationRepository: (any GamificationRepositoryProtocol)?
    private let visualFixture: VisualFixture?
    private let visualAppearanceFixture: VisualAppearanceFixture?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State var compactCaptureState = CaptureOrbPresentationState()
    @State var measuredChromeHeight: CGFloat = 132
    @State var isEvaComposerFocused = false
    /// Roots that have been opened at least once. Dashboard roots stay built so
    /// their scroll position and navigation depth survive a root change. Eva is
    /// intentionally evicted when inactive because its chat/runtime hierarchy
    /// is substantially heavier and owns visibility-scoped work.
    @State var visitedRoots: Set<Destination> = []
    /// Drives the composer's capsule↔orb compression. Owned here because the
    /// composer is drawn once at shell level over five root scroll views it has
    /// no reference to; see `ComposerScrollReporter`.
    @State var composerScrollObserver = ComposerScrollObserver()
    /// Where the eye left from, and how far the arriving root has settled.
    /// Both feed `lifeboardRootTravel`; see `RootTransition`.
    @State var previousRoot: Destination?
    @State var rootTravelProgress: Double = 1
    @State private var compactCaptureTargetFrames: [CaptureKind: CGRect] = [:]
    @State var compactCaptureRippleTrigger = 0
    @State var planRescueRefreshGeneration = 0
    @State var homeCardReceipt: HomeCardPlacementReceipt?
    @State var homeCardPlacementRequest: HomeCardPlacementRequest?
    @State var composerAudioStore: JournalStore?
    @State var showsComposerAudioCapture = false
    @State var lifeThreadComposer = LifeThreadComposerCoordinator()
    @State var dictationController = UniversalDictationController()
    @State var liveIntentResolveTask: Task<Void, Never>?
    @State var showsDocumentScanner = false
    @State var showsHomeDisplayPanel = false
    @State private var homeDisplayPanelHeight: CGFloat = 420
    /// True while a finger is on the atmosphere slider. Suppresses the daypart
    /// bloom, which would otherwise fire once per daypart crossed mid-drag.
    @State private var atmosphereSliderIsDragging = false
    /// Deferred so a `push` never lands under a still-animating sheet.
    @State private var pendingDisplayPanelSettingsPush = false
    @State private var scannedDraft: ScannedDraft?
    @State private var bridgedScenePhase: ScenePhase = UIApplication.shared.applicationState == .background
        ? .background : .active
    @State var lifeBoardActionReceipt: ActionReceipt?
    /// Fires the one-shot background warp when a card zooms into its detail
    /// route. Incremented on a real push, never on a redraw.
    @State var routeTransitionTrigger = 0
    @State var daypartBloomTrigger = 0
    @State var homeIsCustomizing = false
    @AppStorage("lifeOS.home.dashboardDensity.v1") private var dashboardDensity: DashboardDensity = .balanced
    @FocusState var lifeThreadComposerIsFocused: Bool
    @Namespace var dockSelectionNamespace
    let lifeBoardMutationCoordinator: MutationCoordinator
    let universalInputCoordinator: UniversalInputCoordinator

    init(
        homeViewModel: HomeViewModel,
        runtime: FoundationCoordinator = .shared,
        homeProjectionAdapter: HomeProjectionCoordinator,
        dashboardLayoutRepository: any DashboardLayoutRepository,
        phaseIIRepository: any PhaseIIRepository,
        planningRepository: CoreDataPlanningRepository,
        planDependencies: PlanFeatureDependencies?,
        trackFoundationRepository: CoreDataTrackFoundationRepository,
        habitRuntimeReadRepository: any HabitRuntimeReadRepositoryProtocol,
        routineLinkedMutationApplier: any RoutineLinkedMutationApplying,
        goalSampleProvider: any GoalSampleRepository,
        starterPackMutationApplier: any StarterPackCanonicalMutationApplying,
        habitRecoveryMutationApplier: any HabitRecoveryMutationApplying,
        nutritionRepository: any NutritionRepository,
        lifeMomentRepository: any LifeMomentRepository,
        wellnessRepository: any WellnessRepository,
        gamificationRepository: (any GamificationRepositoryProtocol)? = nil,
        showsReferenceHome: Bool = ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_FOUNDATION_REFERENCE_DASHBOARD")
    ) {
        self.homeViewModel = homeViewModel
        self.runtime = runtime
        self.homeProjectionAdapter = homeProjectionAdapter
        self.dashboardLayoutRepository = dashboardLayoutRepository
        self.phaseIIRepository = phaseIIRepository
        self.planningRepository = planningRepository
        self.planDependencies = planDependencies
        self.trackFoundationRepository = trackFoundationRepository
        self.habitRuntimeReadRepository = habitRuntimeReadRepository
        self.routineLinkedMutationApplier = routineLinkedMutationApplier
        self.goalSampleProvider = goalSampleProvider
        self.starterPackMutationApplier = starterPackMutationApplier
        self.habitRecoveryMutationApplier = habitRecoveryMutationApplier
        self.nutritionRepository = nutritionRepository
        self.lifeMomentRepository = lifeMomentRepository
        self.wellnessRepository = wellnessRepository
        self.gamificationRepository = gamificationRepository
        visualFixture = VisualFixture(arguments: ProcessInfo.processInfo.arguments)
        visualAppearanceFixture = VisualAppearanceFixture(arguments: ProcessInfo.processInfo.arguments)
        self.showsReferenceHome = showsReferenceHome
        let mutationCoordinator = MutationCoordinator()
        lifeBoardMutationCoordinator = mutationCoordinator
        universalInputCoordinator = UniversalInputCoordinator(mutationCoordinator: mutationCoordinator)
    }

    public var body: some View {
        @Bindable var router = runtime.router
        TransitionHost {
            AtmosphereHost(
                preferences: runtime.preferences,
                placement: .root(router.selectedDestination)
            ) {
                AtmosphereSnapshotReader { atmosphereSnapshot in
                    Group {
                        if usesExpandedShell {
                            expandedShell(router: router, atmosphereSnapshot: atmosphereSnapshot)
                        } else {
                            compactShell(router: router, atmosphereSnapshot: atmosphereSnapshot)
                        }
                    }
                    .onChange(of: atmosphereSnapshot.semanticDaypart) { oldValue, newValue in
                        guard oldValue != newValue else { return }
                        // Dragging the atmosphere slider from Auto to Night
                        // crosses four dayparts in a few hundred milliseconds.
                        // One bloom per crossing would stack four Metal passes
                        // on top of each other; the drag gets a single bloom
                        // when the finger lifts.
                        guard atmosphereSliderIsDragging == false else { return }
                        daypartBloomTrigger &+= 1
                    }
                    // Attached here, inside the atmosphere host's content,
                    // rather than at the shell root with the other sheets:
                    // `AtmosphereHost` injects the snapshot and the
                    // `isHosted` flag onto its *content*, and the root sheets
                    // are chained above it. A panel presented from there would
                    // draw the wall-clock atmosphere and would not retint as
                    // the slider moves — which is the whole point of it.
                    .sheet(isPresented: $showsHomeDisplayPanel, onDismiss: {
                        guard pendingDisplayPanelSettingsPush else { return }
                        pendingDisplayPanelSettingsPush = false
                        runtime.router.push(.settings, in: .home)
                    }) {
                        PresentationScaffold(mode: .utility, readableWidth: 520) {
                            DisplayPanel(
                                mode: dashboardModeBinding,
                                density: dashboardDensityBinding,
                                daypart: daypartSelectionBinding,
                                resolvedDaypart: atmosphereSnapshot.semanticDaypart,
                                activeOverride: runtime.preferences.activeDaypartOverride,
                                onDragStateChange: { atmosphereSliderIsDragging = $0 },
                                onOpenSettings: {
                                    pendingDisplayPanelSettingsPush = true
                                    showsHomeDisplayPanel = false
                                },
                                onMeasure: { homeDisplayPanelHeight = $0 }
                            )
                        }
                        .environment(\.lifeBoardAtmosphereSnapshot, atmosphereSnapshot)
                        .presentationDetents(
                            dynamicTypeSize.isAccessibilitySize
                                ? [.large]
                                : [.height(homeDisplayPanelHeight), .large]
                        )
                        .presentationDragIndicator(.visible)
                    }
                }
            }
        }
        // Default-tinted controls (menu labels, plain buttons) resolve to cocoa
        // ink instead of system blue, keeping the warm palette everywhere
        // without tinting each control individually.
        .tint(Color(SemanticColorTokens.inkPrimary))
        .background {
            // Hardware-keyboard capture shortcut for iPad / Mac Catalyst (⌘N).
            Button {
                runtime.captureRouter.request(kind: .task, source: .shell)
            } label: { EmptyView() }
            .keyboardShortcut("n", modifiers: .command)
            .accessibilityHidden(true)
            .frame(width: 0, height: 0)
            .opacity(0)
        }
        .modifier(
            ShellSheets(
                runtime: runtime,
                phaseIIRepository: phaseIIRepository,
                planningRepository: planningRepository,
                trackFoundationRepository: trackFoundationRepository,
                routineLinkedMutationApplier: routineLinkedMutationApplier,
                lifeBoardMutationCoordinator: lifeBoardMutationCoordinator,
                lifeThreadComposer: lifeThreadComposer,
                capturePresentationBinding: capturePresentationBinding,
                onAddCardToHome: { kind, size, destination in
                    Task { await addCardToHome(kind, size: size, from: destination) }
                },
                router: router,
                lifeBoardActionReceipt: $lifeBoardActionReceipt,
                homeCardPlacementRequest: $homeCardPlacementRequest,
                showsComposerAudioCapture: $showsComposerAudioCapture,
                composerAudioStore: $composerAudioStore,
                showsDocumentScanner: $showsDocumentScanner,
                scannedDraft: $scannedDraft,
                composerIsFocused: $lifeThreadComposerIsFocused
            )
        )
        .modifier(
            ShellOverlays(
                runtime: runtime,
                homeViewModel: homeViewModel,
                dashboardLayoutRepository: dashboardLayoutRepository,
                planningRepository: planningRepository,
                visualFixture: visualFixture,
                onDismissRescue: dismissPlanOverdueRescue,
                homeCardReceipt: $homeCardReceipt
            )
        )
        .task(id: visualFixture?.id) {
            guard let visualFixture else { return }
            switch visualFixture.root {
            case .home: router.activateRoot(.home)
            case .plan: router.activateRoot(.plan)
            case .track: router.activateRoot(.track)
            case .insights: router.activateRoot(.insights)
            case .eva: router.activateRoot(.eva)
            }
        }
        .onChange(of: router.selectedDestination, initial: true) { _, destination in
            MotionDiagnosticsState.shared.record("root:\(destination.rawValue)")
            lifeThreadComposer.move(to: destination)
            if destination != .eva {
                updateEvaComposerFocus(false)
            }
            // Each root keeps its own scroll position, so carrying the previous
            // root's offset across would land the composer already compressed
            // over a screen sitting at its top.
            composerScrollObserver.reset()
        }
        // The comfort gate for Metal effects.
        //
        // `MotionPolicy.allowsCustomShaders` has encoded this rule since it was
        // written and had no readers at all, so a person who chose Calm still
        // got every shader. Publishing it here is what makes the setting mean
        // something. `initial: true` matters: without it the gate stays at its
        // permissive default until the first navigation, which is exactly the
        // launch window a Calm user notices.
        //
        // The active screen mode is deliberately not an input. Feeding
        // `.focused` in here took every shader in the app down for the duration
        // of Focus Session, Day Open and Close the Day — see
        // `SignatureShaderComfortGate`. Focused surfaces quiet their *ambience*
        // through `AtmospherePlacement.suppressesAmbientDetail`, not their
        // commitment effects.
        .onChange(of: runtime.preferences.comfortProfile, initial: true) { _, profile in
            SignatureShaders.updateComfort(profile: profile)
        }
        .onChange(of: scenePhase) { _, phase in
            // Interrupt live dictation when the app loses the foreground so
            // SpeechAnalyzer's audio engine doesn't keep recording into
            // the void and the user's draft is preserved.
            if phase != .active,
               (
                    dictationController.phase == .preparing
                        || dictationController.phase == .recording
                        || dictationController.phase == .finalizing
               ) {
                LifeThreadComposerHost.cancelDictation(
                    composer: lifeThreadComposer,
                    controller: dictationController
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            bridgedScenePhase = .active
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            bridgedScenePhase = .inactive
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            bridgedScenePhase = .background
        }
        // "Full motion". `\.accessibilityReduceMotion` is a get-only key path,
        // so this cannot be injected into the environment; `MotionOverride`
        // applies the rule inside the motion policy instead and every token
        // entry point defers to it. `initial: true` matters for the same reason
        // as the comfort gate: without it the launch window uses the default.
        .onChange(of: fullMotionIsEnabled, initial: true) { _, isEnabled in
            MotionOverride.fullMotionEnabled = isEnabled
        }
        .preferredColorScheme(visualAppearanceFixture?.preferredColorScheme)
        .contrast(visualAppearanceFixture?.usesHighContrast == true ? 1.16 : 1)
        .saturation(visualAppearanceFixture?.usesGrayscale == true ? 0 : 1)
        // Presentation modifiers live outside the shell's visual subtree. Keep
        // the observable preferences at the outermost level so sheets and
        // navigation destinations receive the same environment as root views.
        .environment(runtime.preferences)
        .lifeBoardMotionDiagnostics(preferences: runtime.preferences)
        .environment(\.scenePhase, bridgedScenePhase)
        // Outermost, and after the scene-phase bridge it depends on. This is the
        // single observation-tracked read of `ShaderReadinessStore` in the shell:
        // warm-up finishing now invalidates this modifier and re-publishes
        // readiness downward, which is what the static gate could never do.
        .lifeBoardResolvedMotion(
            comfortProfile: runtime.preferences.comfortProfile,
            requestedAmbientTierID: runtime.preferences.renderingTier.rawValue
        )
    }

    /// Whether the Full motion override is live.
    ///
    /// The screenshot fixture stays authoritative: `-LIFEBOARD_VISUAL_APPEARANCE=reduced-motion`
    /// exists precisely to capture the reduced-motion appearance, so a user
    /// preference must not be able to overrule it during a capture run.
    private var fullMotionIsEnabled: Bool {
        if visualAppearanceFixture?.usesReducedMotion == true { return false }
        return runtime.preferences.fullMotionEnabled
    }

    /// Accessibility text needs the full content width even on regular-width
    /// iPad and Catalyst windows. The same compact shell remains keyboard and
    /// VoiceOver complete, so collapsing here never removes a destination.
    private var usesExpandedShell: Bool {
        horizontalSizeClass == .regular && dynamicTypeSize.isAccessibilitySize == false
    }

    func dockSelectionCenter(for destination: Destination) -> UnitPoint {
        let all = Destination.allCases
        guard let index = all.firstIndex(of: destination), all.isEmpty == false else {
            return .center
        }
        let slot = 1.0 / Double(all.count)
        return UnitPoint(x: (Double(index) + 0.5) * slot, y: 0.5)
    }

    // These three bindings deliberately carry no haptic. The controls they now
    // feed — `AtmosphereSlider` and `LensPicker` — fire
    // `Haptic.pick` themselves, routed through `MotionPolicy`
    // so Low Power Mode and Catalyst are honoured. A tap in the binding as well
    // would buzz twice per selection.
    private var daypartSelectionBinding: Binding<DaypartSelection> {
        Binding(
            get: { runtime.preferences.daypartSelection },
            set: { selection in
                runtime.preferences.daypartSelection = selection
            }
        )
    }

    private var dashboardModeBinding: Binding<DashboardMode> {
        Binding(
            get: { runtime.router.dashboardMode },
            set: { mode in
                withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
                    runtime.router.dashboardMode = mode
                }
            }
        )
    }

    private var dashboardDensityBinding: Binding<DashboardDensity> {
        Binding(
            get: { dashboardDensity },
            set: { density in
                withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
                    dashboardDensity = density
                }
            }
        )
    }

    /// Eva owns its own keyboard-safe composer; a second text field in the
    /// shared chrome would put two on screen at once.
    /// The screen mode of whatever is deepest on the current stack.
    ///
    /// The dock and composer are drawn once at shell level, outside every
    /// per-route `ScreenScaffold`, so a route cannot influence them
    /// through the scaffold's `mode` alone — the shell has to ask.
    private var activeScreenMode: ScreenMode {
        let router = runtime.router
        return router.path(for: router.selectedDestination).last?.screenMode ?? .detail
    }

    /// Eva owns its own composer, and focused/editor routes own their input
    /// plane. Keeping the global capture field over a form obscures the form's
    /// commit control and gives keyboard users two competing text targets.
    ///
    /// The concrete failure this prevents: Home's capture bar floating over
    /// Close the Day's "Save this line" and its commit control. `.focused`
    /// already means "this surface holds attention on its own" — it was simply
    /// never consulted here, so the focus session route had the same overlap.
    func showsFloatingComposer(for destination: Destination) -> Bool {
        destination != .eva
            && activeScreenMode != .focused
            && activeScreenMode != .editor
            && (destination != .home || dynamicTypeSize.isAccessibilitySize == false)
    }

    func showsGlobalChrome(for destination: Destination) -> Bool {
        destination != .home || homeIsCustomizing == false
    }

    func showsCompactChrome(for destination: Destination) -> Bool {
        FoundationCompactChromeVisibilityPolicy.isVisible(
            destination: destination,
            isPhoneInterface: usesPhoneChromeBehavior,
            isEvaComposerFocused: isEvaComposerFocused,
            showsGlobalChrome: showsGlobalChrome(for: destination)
        )
    }

    private var usesPhoneChromeBehavior: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    func reservedChromeHeight(for destination: Destination) -> CGFloat {
        showsCompactChrome(for: destination) ? measuredChromeHeight : 0
    }

    func evaComposerBottomClearance(for destination: Destination) -> CGFloat {
        guard destination == .eva else { return 0 }
        return reservedChromeHeight(for: destination)
    }

    func reservedDestinationChromeHeight(for destination: Destination) -> CGFloat {
        evaComposerBottomClearance(for: destination) > 0 ? 0 : reservedChromeHeight(for: destination)
    }

    func updateEvaComposerFocus(_ focused: Bool) {
        guard isEvaComposerFocused != focused else { return }
        withAnimation(MotionProfile.controlMorph.animation(reduceMotion: reduceMotion)) {
            isEvaComposerFocused = focused
        }
    }

    private func updateCompactCaptureDrag(at location: CGPoint) {
        if compactCaptureState.isExpanded == false {
            withAnimation(MotionProfile.controlMorph.animation(reduceMotion: reduceMotion)) {
                compactCaptureState.isExpanded = true
            }
        }
        let targets = compactCaptureTargetFrames.map { CaptureOrbDragTarget(kind: $0.key, frame: $0.value) }
        let selection = CaptureOrbDragSelectionPolicy.selection(at: location, targets: targets)
        guard selection != compactCaptureState.highlightedKind else { return }
        compactCaptureState.highlightedKind = selection
        if selection != nil { HapticFeedback.selection() }
    }

    private func finishCompactCaptureDrag(at location: CGPoint) {
        let targets = compactCaptureTargetFrames.map { CaptureOrbDragTarget(kind: $0.key, frame: $0.value) }
        if let kind = CaptureOrbDragSelectionPolicy.selection(at: location, targets: targets)
            ?? compactCaptureState.highlightedKind {
            commitCompactCapture(kind)
        }
    }

    func commitCompactCapture(_ kind: CaptureKind) {
        compactCaptureState = .init(isExpanded: false, highlightedKind: kind)
        compactCaptureRippleTrigger &+= 1
        runtime.captureRouter.request(
            kind: kind,
            source: .shell,
            presentationContext: .init(
                sourceRoot: runtime.router.selectedDestination,
                sourcePoint: .init(x: 0.91, y: 0.08),
                preferredCaptureKind: kind
            )
        )
        HapticFeedback.light()
    }

    private var availableCaptureKinds: [CaptureKind] {
        CaptureKind.allCases.filter { kind in
            switch kind {
            case .task, .habit: true
            case .journal: V2FeatureFlags.journalV1Enabled
            case .note: V2FeatureFlags.knowledgeNotesV1Enabled
            case .trackerEntry: V2FeatureFlags.trackersV1Enabled
            case .mood, .hydration, .medicationEvent:
                V2FeatureFlags.careModulesV2Enabled
            case .routineRun:
                V2FeatureFlags.goalsRoutinesV1Enabled
            case .timeBlock:
                V2FeatureFlags.planningCoreV1Enabled
            }
        }
    }

    var primaryCaptureKinds: [CaptureKind] {
        [.task, .journal, .note, .trackerEntry, .mood].filter(availableCaptureKinds.contains)
    }

    private var capturePresentationBinding: Binding<Bool> {
        Binding(
            get: { runtime.captureRouter.activeRequest != nil },
            set: { isPresented in
                if isPresented == false {
                    runtime.captureRouter.completeActiveRequest()
                }
            }
        )
    }

    func pathBinding(for destination: Destination) -> Binding<[AppRoute]> {
        Binding(
            get: { runtime.router.path(for: destination) },
            set: { runtime.router.setPath($0, for: destination) }
        )
    }

    func presentPlanOverdueRescue(_ context: OverdueRescueLaunchContext) {
        compactCaptureState = CaptureOrbPresentationState()
        lifeThreadComposerIsFocused = false
        homeViewModel.launchOverdueRescue(context)
    }

    private func dismissPlanOverdueRescue() {
        homeViewModel.setEvaRescuePresented(false)
        planRescueRefreshGeneration &+= 1
    }

}
