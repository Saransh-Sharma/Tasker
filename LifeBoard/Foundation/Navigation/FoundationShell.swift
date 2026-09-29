import SwiftUI
import SwiftData
import CoreData
import LifeBoardTranscription
import UIKit
import VisionKit

struct FoundationCompactChromeVisibilityPolicy {
    static func isVisible(
        destination: Destination,
        screenMode: ScreenMode,
        usesDockChrome: Bool,
        isEvaComposerFocused: Bool,
        showsGlobalChrome: Bool
    ) -> Bool {
        guard showsGlobalChrome, screenMode != .utility else { return false }
        return destination != .eva || usesDockChrome == false || isEvaComposerFocused == false
    }
}

/// The bottom space the shell's floating chrome occupies over a root.
///
/// A tab's `safeAreaInset` does not reach inside its navigation stack, so a
/// fixed-height root (Plan's day canvas) that cannot scroll out from under the
/// composer and dock reads the measured height here instead of a constant
/// measured once on one iPhone — which was wrong on iPad, where there is no
/// dock, and in any short window.
private struct ShellBottomClearanceKey: EnvironmentKey {
    static let defaultValue: CGFloat = 0
}

extension EnvironmentValues {
    var lifeBoardShellBottomClearance: CGFloat {
        get { self[ShellBottomClearanceKey.self] }
        set { self[ShellBottomClearanceKey.self] = newValue }
    }
}

/// How the shell offers the five roots: the floating bottom dock, or the top
/// switcher `DESIGN.md` asks for at iPad and Mac widths.
enum FoundationShellChromeStyle: Equatable {
    case dock
    case topSwitcher
}

/// Chooses the chrome from the window's layout class, not the device.
///
/// A ⅓ Split View pane or Slide Over is phone-shaped and gets the dock; a
/// full-width iPad or a Mac window gets the switcher. Accessibility text needs
/// the full content width, so it keeps the dock at any width — the dock is
/// keyboard and VoiceOver complete, so nothing becomes unreachable.
enum FoundationShellChromePolicy {
    static func style(layoutClass: LayoutClass, isAccessibilitySize: Bool) -> FoundationShellChromeStyle {
        guard isAccessibilitySize == false else { return .dock }
        switch layoutClass {
        case .phone, .padCompact:
            return .dock
        case .padRegular, .padExpanded:
            return .topSwitcher
        }
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

    @Environment(\.lifeboardLayoutClass) var layoutClass
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.dynamicTypeSize) var dynamicTypeSize
    @Environment(\.scenePhase) var scenePhase
    @State var compactCaptureState = CaptureOrbPresentationState()
    @State var measuredChromeHeight: CGFloat = 132
    /// Distance from the dock's top edge to the bottom of the shell.
    ///
    /// `measuredChromeHeight` covers the whole compact container, which on most
    /// destinations also holds the global LifeThread composer, and even the
    /// dock's own layout height overshoots the pill that is actually drawn.
    /// Eva hides the global composer and supplies its own, so insetting it by
    /// either of those reserved room for chrome that was not on screen and left
    /// the composer floating well above the dock. This measures the answer
    /// directly instead of deriving it.
    @State var measuredDockClearance: CGFloat = 96

    /// The compact chrome container's bottom inset.
    static let compactChromeBottomPadding: CGFloat = 6

    /// Separation between Eva's composer and the dock, folded into the measured
    /// clearance rather than added by the composer.
    ///
    /// It belongs here because it is a contract, not a taste: the composer's
    /// *interactive* bounds run lower than its visible pill — the mic and send
    /// buttons overhang it — and `assertRequiredEvaDockSpacing` requires every
    /// one of those controls to clear the dock by the md token. Sizing the gap
    /// against the pill instead left the mic a point from the dock while looking
    /// correct in a screenshot.
    ///
    /// Twice the md token, and the doubling is the overhang rather than taste:
    /// the mic and send buttons hang roughly a token's worth below the pill, so
    /// a 12pt gap measured from the pill leaves them ~1pt from the dock. Sizing
    /// it here keeps the whole control cluster clear in every Dynamic Type and
    /// compact-height state the dock-spacing tests cover.
    static let evaComposerDockGap: CGFloat = 24

    /// Names the shell's own coordinate space so chrome can be measured against
    /// it rather than against the screen.
    static let shellCoordinateSpace = "lifeboard.shell"
    @State var isEvaComposerFocused = false
    /// Drives the composer's capsule↔orb compression. Owned here because the
    /// composer is drawn once at shell level over five root scroll views it has
    /// no reference to; see `ComposerScrollReporter`.
    @State var composerScrollObserver = ComposerScrollObserver()
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
    @State var bridgedScenePhase: ScenePhase = UIApplication.shared.applicationState == .background
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
                    // One tree for every width. Two shells behind an `if` meant a
                    // Split View or Mac window resize across the breakpoint
                    // rebuilt every root below it — Eva's unsent draft and open
                    // thread were thrown away. Only the chrome's values change.
                    shellBody(router: router, atmosphereSnapshot: atmosphereSnapshot)
                    // Light every clay surface in the shell from the current
                    // daypart. `SpecularRimModifier` has always taken a
                    // `lightAngle` and nothing ever passed one, so the lit edge
                    // on every card in the product pointed the same way at dawn
                    // and at dusk. One injection, at the one place that knows
                    // the time of day.
                    .lifeBoardClayLight(atmosphereSnapshot.semanticDaypart)
                    // The day's first habit completion lights the shell once;
                    // inside the reader so the sweep tints with the daypart.
                    .lifeBoardFirstLightOnFirstCommitment()
                    // Every toggle in the app, in one line. `ToggleStyle`
                    // propagates through the environment, and `ClayToggleStyle`
                    // had been sitting complete and unused while 81 stock green
                    // switches shipped on a cocoa palette.
                    .modifier(ClayToggleStyleModifier())
                    // The four one-time root cues that replaced v6's root
                    // tour. No-ops for anyone who finished under v5, who has
                    // already been told these things once.
                    .lifeBoardOnboardingTip(
                        destination: router.selectedDestination,
                        isRootVisible: router.path(for: router.selectedDestination).isEmpty
                    )
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
        // without tinting each control individually. `foundationSystemTint`,
        // not `inkPrimary`: that is near-white in dark, and system controls
        // draw white on their tint.
        .tint(Color(SemanticColorTokens.foundationSystemTint))
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
                makeEvaSheet: { _ in evaSheetRoot(router: router) }
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
        #if DEBUG
        .modifier(HomeProductionEvidenceModifier())
        .task { HomeProductionEvidenceProfile.activate(runtime: runtime) }
        #endif
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
            // The composer and its focus are shared by every root, so a
            // keyboard raised on Home used to follow the user onto Plan,
            // Track and Insights. A tab switch always puts it away — and an
            // open tools tray with it; the draft stays on the coordinator.
            lifeThreadComposerIsFocused = false
            lifeThreadComposer.closeTools()
            if destination != .eva {
                updateEvaComposerFocus(false)
            }
            // Each root keeps its own scroll position, so carrying the previous
            // root's offset across would land the composer already compressed
            // over a screen sitting at its top.
            composerScrollObserver.reset()
        }
        // A rescue notification asks for the deck; the shell owns it.
        .onChange(of: router.overdueRescueRequest, initial: true) { _, request in
            guard let request else { return }
            router.overdueRescueRequest = nil
            presentPlanOverdueRescue(.home(referenceDate: max(request, Date())))
        }
        // Navigation ends typing (`DESIGN.md`, keyboard contract). The composer
        // stays mounted on detail routes, so a push used to leave its keyboard
        // over a screen that has nothing to type into.
        .onChange(of: router.path(for: router.selectedDestination).count) { _, _ in
            lifeThreadComposerIsFocused = false
            lifeThreadComposer.closeTools()
        }
        // Sending ends editing, so the keyboard goes away and nothing moves
        // VoiceOver to the receipt; say what happened once, when it is made.
        .onChange(of: lifeBoardActionReceipt?.id) { _, id in
            guard id != nil, let receipt = lifeBoardActionReceipt else { return }
            AccessibilityNotification.Announcement(
                ActionReceiptPresentation.announcement(message: receipt.message, canUndo: receipt.canUndo)
            ).post()
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
            if phase != .active {
                Task { await router.flushPersistence() }
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
        // `\.accessibilityReduceMotion` is a get-only key path, so the app
        // preference is combined with it inside `MotionOverride`. The system
        // accessibility setting always wins. `initial: true` avoids a launch
        // window where the stored in-app preference has not been published.
        .onChange(of: fullMotionIsEnabled, initial: true) { _, isEnabled in
            MotionOverride.fullMotionEnabled = isEnabled
        }
        .preferredColorScheme(visualAppearanceFixture?.preferredColorScheme)
        // The high-contrast *trait* is applied on the hosting controller via
        // `traitOverrides` (see `ApplicationHostController`), because
        // `\.colorSchemeContrast` is read-only in SwiftUI — it is derived from
        // the trait collection and cannot be set from here. This filter stays
        // only as a visual nudge for the screenshot fixtures; it is the trait,
        // not the filter, that makes `adaptive(...)` take its high-contrast
        // branch.
        .contrast(visualAppearanceFixture?.usesHighContrast == true ? 1.16 : 1)
        .saturation(visualAppearanceFixture?.usesGrayscale == true ? 0 : 1)
        // Presentation modifiers live outside the shell's visual subtree. Keep
        // the observable preferences at the outermost level so sheets and
        // navigation destinations receive the same environment as root views.
        .environment(runtime.preferences)
        .overlay(alignment: .topLeading) {
            if ProcessInfo.processInfo.arguments.contains("-LIFEBOARD_UI_TEST_ANIMATIONS_ENABLED") {
                FoundationPerformanceReadiness(preferences: runtime.preferences)
            }
        }
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

    var chromeStyle: FoundationShellChromeStyle {
        FoundationShellChromePolicy.style(
            layoutClass: layoutClass,
            isAccessibilitySize: dynamicTypeSize.isAccessibilitySize
        )
    }

    var usesExpandedShell: Bool {
        chromeStyle == .topSwitcher
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
            && activeScreenMode != .utility
            && (destination != .home || dynamicTypeSize.isAccessibilitySize == false)
    }

    func showsGlobalChrome(for destination: Destination) -> Bool {
        destination != .home || homeIsCustomizing == false
    }

    func showsCompactChrome(for destination: Destination) -> Bool {
        FoundationCompactChromeVisibilityPolicy.isVisible(
            destination: destination,
            screenMode: activeScreenMode,
            usesDockChrome: chromeStyle == .dock,
            isEvaComposerFocused: isEvaComposerFocused,
            showsGlobalChrome: showsGlobalChrome(for: destination)
        )
    }

    func reservedChromeHeight(for destination: Destination) -> CGFloat {
        showsCompactChrome(for: destination) ? measuredChromeHeight : 0
    }

    /// How far Eva's own composer must sit above the bottom edge.
    ///
    /// This is the dock's occupied height, not the chrome stack's: Eva is the one
    /// destination that replaces the global composer rather than stacking under
    /// it, so the stack height would over-reserve by exactly the composer it hid.
    func evaComposerBottomClearance(for destination: Destination) -> CGFloat {
        guard destination == .eva, chromeStyle == .dock, showsCompactChrome(for: destination) else { return 0 }
        return measuredDockClearance + Self.evaComposerDockGap
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
        if selection != nil { Haptic.pick.play() }
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
        Haptic.pick.play()
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

    /// What Home's Quick Capture card does: raise the floating composer where
    /// it is on screen, otherwise open the header's capture tray — Home hides
    /// the composer at accessibility text sizes.
    var homeFocusCaptureAction: HomeFocusCaptureAction {
        HomeFocusCaptureAction {
            if showsFloatingComposer(for: .home), showsGlobalChrome(for: .home) {
                lifeThreadComposer.requestFocus()
            } else {
                withAnimation(MotionProfile.controlMorph.animation(reduceMotion: reduceMotion)) {
                    compactCaptureState.isExpanded = true
                }
            }
        }
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
