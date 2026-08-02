import SwiftUI
import SwiftData
import TranscriptionKit
import UIKit
import VisionKit

private struct LifeBoardAtmosphereSnapshotReader<Content: View>: View {
    @Environment(\.lifeBoardAtmosphereSnapshot) private var snapshot
    private let content: (LifeBoardAtmosphereSnapshot) -> Content

    init(@ViewBuilder content: @escaping (LifeBoardAtmosphereSnapshot) -> Content) {
        self.content = content
    }

    var body: some View {
        content(snapshot)
    }
}

/// Keeps a type-erased destination value stable across shell-level updates.
///
/// `AnyView` caps generic metadata, but recreating the erased value on every
/// destination selection still copies the complete dashboard value graph. The
/// storage belongs to SwiftUI identity, so retained dashboards keep one root
/// value while an evicted Eva host releases its cached value with the host.
@MainActor
private final class LifeBoardDestinationRootStorage: ObservableObject {
    private var root: AnyView?

    func resolve(_ makeRoot: () -> AnyView) -> AnyView {
        if let root {
            return root
        }
        let root = makeRoot()
        self.root = root
        return root
    }
}

private struct LifeBoardStableDestinationRoot: View {
    @StateObject private var storage = LifeBoardDestinationRootStorage()
    let makeRoot: () -> AnyView

    var body: some View {
        storage.resolve(makeRoot)
    }
}

public struct LifeOSFoundationShell: View {
    private let homeViewModel: HomeViewModel
    private let runtime: LifeOSFoundationRuntime
    private let showsReferenceHome: Bool
    private let homeProjectionAdapter: HomeProjectionCoordinator
    private let dashboardLayoutRepository: any DashboardLayoutRepository
    private let phaseIIRepository: any LifeBoardPhaseIIRepository
    private let planningRepository: CoreDataPlanningRepository
    private let planDependencies: PlanFeatureDependencies?
    private let trackFoundationRepository: CoreDataTrackFoundationRepository
    private let habitRuntimeReadRepository: any HabitRuntimeReadRepositoryProtocol
    private let routineLinkedMutationApplier: any RoutineLinkedMutationApplying
    private let goalSampleProvider: any GoalSampleProvider
    private let starterPackMutationApplier: any StarterPackCanonicalMutationApplying
    private let habitRecoveryMutationApplier: any HabitRecoveryMutationApplying
    private let nutritionRepository: any NutritionRepository
    private let lifeMomentRepository: any LifeMomentRepository
    private let wellnessRepository: any WellnessRepository
    private let visualFixture: LifeBoardVisualFixture?
    private let visualAppearanceFixture: LifeBoardVisualAppearanceFixture?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @State private var compactCaptureState = CaptureOrbPresentationState()
    @State private var measuredChromeHeight: CGFloat = 132
    /// Roots that have been opened at least once. Dashboard roots stay built so
    /// their scroll position and navigation depth survive a root change. Eva is
    /// intentionally evicted when inactive because its chat/runtime hierarchy
    /// is substantially heavier and owns visibility-scoped work.
    @State private var visitedRoots: Set<LifeBoardDestination> = []
    @State private var compactCaptureTargetFrames: [CaptureKind: CGRect] = [:]
    @State private var compactCaptureRippleTrigger = 0
    @State private var planRescueRefreshGeneration = 0
    @State private var homeCardReceipt: HomeCardPlacementReceipt?
    @State private var homeCardPlacementRequest: HomeCardPlacementRequest?
    @State private var composerAudioStore: LifeBoardJournalStore?
    @State private var showsComposerAudioCapture = false
    @State private var lifeThreadComposer = LifeThreadComposerCoordinator()
    @State private var dictationController = UniversalDictationController()
    @State private var liveIntentResolveTask: Task<Void, Never>?
    @State private var showsDocumentScanner = false
    @State private var scannedDraft: LifeBoardScannedDraft?
    @State private var lifeBoardActionReceipt: LifeBoardActionReceipt?
    /// Fires the one-shot background warp when a card zooms into its detail
    /// route. Incremented on a real push, never on a redraw.
    @State private var routeTransitionTrigger = 0
    @State private var daypartBloomTrigger = 0
    @State private var homeIsCustomizing = false
    @AppStorage("lifeOS.home.dashboardDensity.v1") private var dashboardDensity: DashboardDensity = .balanced
    @FocusState private var lifeThreadComposerIsFocused: Bool
    @Namespace private var dockSelectionNamespace
    private let lifeBoardMutationCoordinator: LifeBoardMutationCoordinator
    private let universalInputCoordinator: UniversalInputCoordinator

    init(
        homeViewModel: HomeViewModel,
        runtime: LifeOSFoundationRuntime = .shared,
        homeProjectionAdapter: HomeProjectionCoordinator,
        dashboardLayoutRepository: any DashboardLayoutRepository,
        phaseIIRepository: any LifeBoardPhaseIIRepository,
        planningRepository: CoreDataPlanningRepository,
        planDependencies: PlanFeatureDependencies?,
        trackFoundationRepository: CoreDataTrackFoundationRepository,
        habitRuntimeReadRepository: any HabitRuntimeReadRepositoryProtocol,
        routineLinkedMutationApplier: any RoutineLinkedMutationApplying,
        goalSampleProvider: any GoalSampleProvider,
        starterPackMutationApplier: any StarterPackCanonicalMutationApplying,
        habitRecoveryMutationApplier: any HabitRecoveryMutationApplying,
        nutritionRepository: any NutritionRepository,
        lifeMomentRepository: any LifeMomentRepository,
        wellnessRepository: any WellnessRepository,
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
        visualFixture = LifeBoardVisualFixture(arguments: ProcessInfo.processInfo.arguments)
        visualAppearanceFixture = LifeBoardVisualAppearanceFixture(arguments: ProcessInfo.processInfo.arguments)
        self.showsReferenceHome = showsReferenceHome
        let mutationCoordinator = LifeBoardMutationCoordinator()
        lifeBoardMutationCoordinator = mutationCoordinator
        universalInputCoordinator = UniversalInputCoordinator(mutationCoordinator: mutationCoordinator)
    }

    public var body: some View {
        @Bindable var router = runtime.router
        LifeBoardTransitionHost {
            LifeBoardAtmosphereHost(
                preferences: runtime.preferences,
                placement: .root(router.selectedDestination)
            ) {
                LifeBoardAtmosphereSnapshotReader { atmosphereSnapshot in
                    Group {
                        if usesExpandedShell {
                            expandedShell(router: router, atmosphereSnapshot: atmosphereSnapshot)
                        } else {
                            compactShell(router: router, atmosphereSnapshot: atmosphereSnapshot)
                        }
                    }
                    .onChange(of: atmosphereSnapshot.semanticDaypart) { oldValue, newValue in
                        guard oldValue != newValue else { return }
                        daypartBloomTrigger &+= 1
                    }
                }
            }
        }
        // Default-tinted controls (menu labels, plain buttons) resolve to cocoa
        // ink instead of system blue, keeping the warm palette everywhere
        // without tinting each control individually.
        .tint(Color(LifeBoardColorTokens.inkPrimary))
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
        .sheet(isPresented: capturePresentationBinding) {
            LifeBoardPresentationScaffold(mode: .editor, readableWidth: 720) {
                if let request = runtime.captureRouter.activeRequest {
                    FoundationCaptureSheet(
                        request: request,
                        phaseIIRepository: phaseIIRepository,
                        planningRepository: planningRepository,
                        trackFoundationRepository: trackFoundationRepository,
                        routineLinkedMutationApplier: routineLinkedMutationApplier,
                        mutationCoordinator: lifeBoardMutationCoordinator,
                        onReceipt: { receipt in lifeBoardActionReceipt = receipt },
                        onClose: { runtime.captureRouter.cancelActiveRequest() },
                        onOpenHabitBoard: {
                            runtime.captureRouter.completeActiveRequest()
                            runtime.router.push(.habitBoard, in: .track)
                        }
                    )
                }
            }
        }
        .sheet(item: $homeCardPlacementRequest) { request in
            LifeBoardPresentationScaffold(mode: .utility, readableWidth: 640) {
                if let descriptor = DefaultDashboardWidgetRegistry.shared.descriptor(for: request.kind) {
                    HomeCardPlacementSheet(
                        descriptor: descriptor,
                        destination: request.destination,
                        onCancel: { homeCardPlacementRequest = nil },
                        onAdd: { size in
                            homeCardPlacementRequest = nil
                            Task { await addCardToHome(request.kind, size: size, from: request.destination) }
                        }
                    )
                }
            }
        }
        .sheet(isPresented: $showsComposerAudioCapture, onDismiss: {
            if lifeThreadComposer.state == .recording { lifeThreadComposer.focus() }
        }) {
            LifeBoardPresentationScaffold(mode: .editor, readableWidth: 720) {
                if let store = composerAudioStore {
                    NavigationStack {
                        LifeBoardJournalAudioCapture(
                        onSave: { path, duration, transcription in
                            if store.allDays.isEmpty { await store.load() }
                            return await store.appendAudio(
                                relativePath: path,
                                duration: duration,
                                transcription: transcription
                            )
                        },
                        onTranscription: { path, text in
                            await store.updateAudioTranscription(relativePath: path, text: text)
                        },
                        onDiscard: { path in
                            await store.discardAudio(relativePath: path)
                        }
                    )
                        .navigationTitle("Voice note")
                        .navigationBarTitleDisplayMode(.inline)
                    }
                    .presentationDetents([.medium, .large])
                } else {
                    // Without this the sheet presented completely empty with no
                    // way to tell whether it was broken or still working. The
                    // store is built synchronously in `beginComposerAudioCapture`,
                    // so reaching here means the state write had not landed when
                    // the sheet body first evaluated — recoverable, so it rebuilds
                    // the store rather than stranding the recording the user came
                    // here to make.
                    NavigationStack {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Preparing voice capture…")
                                .font(.subheadline)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .navigationTitle("Voice note")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button("Cancel") { showsComposerAudioCapture = false }
                            }
                        }
                        .task {
                            guard composerAudioStore == nil else { return }
                            composerAudioStore = LifeBoardJournalStore(repository: phaseIIRepository)
                        }
                    }
                    .presentationDetents([.medium, .large])
                    .accessibilityLabel("Preparing voice capture")
                }
            }
        }
        .fullScreenCover(isPresented: $showsDocumentScanner) {
            LifeBoardDocumentScannerView(
                completion: { result in
                    showsDocumentScanner = false
                    switch result {
                    case .success(let draft): scannedDraft = draft
                    case .failure(let error):
                        router.activeAlert = .init(
                            title: "Couldn’t read scan",
                            message: error.localizedDescription
                        )
                    }
                },
                cancellation: { showsDocumentScanner = false }
            )
            .ignoresSafeArea()
        }
        .sheet(item: $scannedDraft) { draft in
            LifeBoardPresentationScaffold(mode: .editor, readableWidth: 720) {
                LifeBoardScanReviewView(
                    draft: draft,
                    onUse: { text in
                        lifeThreadComposer.draftText = text
                        lifeThreadComposer.focus()
                        scannedDraft = nil
                        lifeThreadComposerIsFocused = true
                    },
                    onCancel: { scannedDraft = nil }
                )
            }
        }
        .sheet(item: Binding(
            get: { LifeBoardPermissionPrimingCoordinator.shared.pendingPrompt },
            set: { if $0 == nil { LifeBoardPermissionPrimingCoordinator.shared.decline() } }
        )) { prompt in
            LifeBoardPermissionPrimingSheet(
                prompt: prompt,
                onGrant: { domains in
                    Task { await LifeBoardPermissionPrimingCoordinator.shared.grant(healthDomains: domains) }
                },
                onDecline: { LifeBoardPermissionPrimingCoordinator.shared.decline() }
            )
        }
        .alert(item: $router.activeAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
        .task {
            // Announce once the shell is genuinely on screen so first run can be
            // presented. Previously this depended on the legacy Home controller
            // reaching its tasks face, which never happens when the adaptive Home
            // is the root — onboarding simply never appeared.
            NotificationCenter.default.post(name: .lifeboardShellDidBecomeInteractive, object: nil)
        }
        .overlay(alignment: .top) {
            if let receipt = homeCardReceipt {
                HomeCardPlacementReceiptView(
                    receipt: receipt,
                    onView: {
                        homeCardReceipt = nil
                        runtime.router.activateRoot(.home)
                    },
                    onUndo: {
                        homeCardReceipt = nil
                        Task { try? await dashboardLayoutRepository.saveHome(receipt.transaction.undoLayout) }
                    },
                    onDismiss: { homeCardReceipt = nil }
                )
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .zIndex(20)
            }
        }
        .overlay {
            if homeViewModel.overdueRescueLaunchCoordinator.presentation != nil {
                OverdueRescuePresentationHost(
                    coordinator: homeViewModel.overdueRescueLaunchCoordinator,
                    projectsByID: Dictionary(uniqueKeysWithValues: homeViewModel.projects.map { ($0.id, $0) }),
                    bottomInset: 0,
                    onRetry: {
                        guard let context = homeViewModel.overdueRescueLaunchCoordinator.presentation else { return }
                        homeViewModel.launchOverdueRescue(context)
                    },
                    onUpdate: { request, completion in
                        Task { @MainActor in
                            homeViewModel.updateTask(taskID: request.id, request: request, completion: completion)
                        }
                    },
                    onDelete: { taskID, completion in
                        Task { @MainActor in
                            homeViewModel.deleteTask(taskID: taskID, scope: .single, completion: completion)
                        }
                    },
                    onRestore: { task, completion in
                        Task { @MainActor in
                            homeViewModel.restoreDeletedTaskSnapshot(task, completion: completion)
                        }
                    },
                    onApply: { mutations, completion in
                        Task { @MainActor in
                            homeViewModel.applyRescuePlan(mutations: mutations, completion: completion)
                        }
                    },
                    onUndo: { completion in
                        Task { @MainActor in homeViewModel.undoRescueRun(completion: completion) }
                    },
                    onSavePlanningMetadata: { metadata, completion in
                        Task {
                            do {
                                try await planningRepository.saveTaskMetadata(metadata)
                                completion(.success(()))
                            } catch {
                                completion(.failure(error))
                            }
                        }
                    },
                    onTrack: { action, metadata in
                        homeViewModel.trackHomeInteraction(action: action, metadata: metadata)
                    },
                    onDismiss: dismissPlanOverdueRescue
                )
                .transition(.opacity.combined(with: .scale(scale: 0.992)))
                .zIndex(90)
            }
        }
        .overlay {
            if let visualFixture, visualFixture.state != .populated {
                LifeBoardVisualFixtureSurface(fixture: visualFixture)
                    .zIndex(100)
            }
        }
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
            lifeThreadComposer.move(to: destination)
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
                cancelComposerDictation()
            }
        }
        .preferredColorScheme(visualAppearanceFixture?.preferredColorScheme)
        .contrast(visualAppearanceFixture?.usesHighContrast == true ? 1.16 : 1)
        .saturation(visualAppearanceFixture?.usesGrayscale == true ? 0 : 1)
        // Presentation modifiers live outside the shell's visual subtree. Keep
        // the observable preferences at the outermost level so sheets and
        // navigation destinations receive the same environment as root views.
        .environment(runtime.preferences)
    }

    /// Accessibility text needs the full content width even on regular-width
    /// iPad and Catalyst windows. The same compact shell remains keyboard and
    /// VoiceOver complete, so collapsing here never removes a destination.
    private var usesExpandedShell: Bool {
        horizontalSizeClass == .regular && dynamicTypeSize.isAccessibilitySize == false
    }

    private func compactShell(
        router: LifeBoardAppRouter,
        atmosphereSnapshot: LifeBoardAtmosphereSnapshot
    ) -> some View {
        @Bindable var router = router
        // The floating chrome draws as a bottom overlay, and each root reserves
        // its measured height as a clear bottom inset. This is the measured
        // content clearance the plan calls for: every root's final row clears
        // the dock and composer, with no blank footer band and no content
        // resting under the translucent composer. (A TabView's own
        // safeAreaInset does not propagate into per-tab scroll views.)
        return GeometryReader { geometry in
            // A plain stack rather than a TabView.
            //
            // At compact width the TabView switched nothing: the floating dock
            // is the switcher and the system tab bar was hidden, so all it
            // contributed was a container whose cross-dissolve could not be
            // replaced. Holding the roots in a stack lets a root change read as
            // travel — the arriving root slides in from the side it sits on in
            // the dock — while visited dashboard roots stay in the hierarchy,
            // so their scroll position and navigation depth survive. Eva is
            // rebuilt on demand to release its visibility-scoped runtime work.
            //
            // The regular-width shell keeps its TabView: there the sidebar and
            // top bar are the switcher, and there is nothing to replace it with.
            ZStack {
                ForEach(LifeBoardDestination.allCases, id: \.self) { destination in
                    // Built on first visit. Dashboard roots stay alive; Eva is
                    // removed when inactive. Building all five up front would
                    // wake every root's stores on launch.
                    if visitedRoots.contains(destination) {
                        let isCurrent = router.selectedDestination == destination
                        destinationNavigation(destination, router: router, atmosphereSnapshot: atmosphereSnapshot)
                            .safeAreaInset(edge: .bottom, spacing: 0) {
                                Color.clear.frame(height: reservedChromeHeight(for: destination))
                            }
                            .offset(
                                x: LifeBoardRootTransition.offset(
                                    for: destination,
                                    selected: router.selectedDestination,
                                    distance: reduceMotion ? 0 : LifeBoardRootTransition.slideDistance
                                )
                            )
                            .opacity(isCurrent ? 1 : 0)
                            .zIndex(isCurrent ? 1 : 0)
                            // A root that is not on screen must not take taps or
                            // hold VoiceOver focus while it sits in the stack.
                            .allowsHitTesting(isCurrent)
                            .accessibilityHidden(isCurrent == false)
                    }
                }
            }
            .onChange(of: router.selectedDestination, initial: true) { previous, destination in
                visitedRoots.insert(destination)
                if previous == .eva, destination != .eva {
                    visitedRoots.remove(.eva)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .background(Color.clear)
            .overlay(alignment: .bottom) {
                // Composer and dock share one GlassEffectContainer so the two
                // chrome layers refract and morph as a single surface rather
                // than two stacked panes.
                if showsGlobalChrome(for: router.selectedDestination) {
                    GlassEffectContainer(spacing: 10) {
                        VStack(spacing: 10) {
                            if showsFloatingComposer(for: router.selectedDestination) {
                                lifeThreadComposerHost(router: router)
                            }
                            compactNavigationChrome(
                                router: router,
                                paletteMaxHeight: max(176, min(320, geometry.size.height * 0.38))
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 6)
                    .background(alignment: .bottom) {
                        LinearGradient(
                            colors: [
                                Color.clear,
                                Color(LifeBoardColorTokens.foundationCanvas)
                                    .opacity(HomeBottomBarVisibilityPolicy.chromeBackdropMaximumOpacity),
                                Color.clear
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 44)
                        .offset(y: -(measuredChromeHeight - 22))
                        .allowsHitTesting(false)
                    }
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.height
                    } action: { height in
                        measuredChromeHeight = height
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("LifeBoardCompactChrome")
                }
            }
        }
        .background(Color.clear.ignoresSafeArea())
    }

    /// Horizontal centre of a dock slot in unit space, so the refraction lens
    /// tracks the selection pill rather than sitting at a fixed point.
    private func dockSelectionCenter(for destination: LifeBoardDestination) -> UnitPoint {
        let all = LifeBoardDestination.allCases
        guard let index = all.firstIndex(of: destination), all.isEmpty == false else {
            return .center
        }
        let slot = 1.0 / Double(all.count)
        return UnitPoint(x: (Double(index) + 0.5) * slot, y: 0.5)
    }

    private var daypartSelectionBinding: Binding<DaypartSelection> {
        Binding(
            get: { runtime.preferences.daypartSelection },
            set: { selection in
                runtime.preferences.daypartSelection = selection
                LifeBoardFeedback.selection()
            }
        )
    }

    private var dashboardModeBinding: Binding<DashboardMode> {
        Binding(
            get: { runtime.router.dashboardMode },
            set: { mode in
                withAnimation(LifeBoardMotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
                    runtime.router.dashboardMode = mode
                }
                LifeBoardFeedback.selection()
            }
        )
    }

    private var dashboardDensityBinding: Binding<DashboardDensity> {
        Binding(
            get: { dashboardDensity },
            set: { density in
                withAnimation(LifeBoardMotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
                    dashboardDensity = density
                }
                LifeBoardFeedback.selection()
            }
        )
    }

    /// Eva owns its own keyboard-safe composer; a second text field in the
    /// shared chrome would put two on screen at once.
    /// The screen mode of whatever is deepest on the current stack.
    ///
    /// The dock and composer are drawn once at shell level, outside every
    /// per-route `LifeBoardScreenScaffold`, so a route cannot influence them
    /// through the scaffold's `mode` alone — the shell has to ask.
    private var activeScreenMode: LifeBoardScreenMode {
        let router = runtime.router
        return router.path(for: router.selectedDestination).last?.screenMode ?? .detail
    }

    /// Eva owns its own composer, and a focused route owns the whole screen.
    ///
    /// The concrete failure this prevents: Home's capture bar floating over
    /// Close the Day's "Save this line" and its commit control. `.focused`
    /// already means "this surface holds attention on its own" — it was simply
    /// never consulted here, so the focus session route had the same overlap.
    private func showsFloatingComposer(for destination: LifeBoardDestination) -> Bool {
        destination != .eva && activeScreenMode != .focused
    }

    private func showsGlobalChrome(for destination: LifeBoardDestination) -> Bool {
        destination != .home || homeIsCustomizing == false
    }

    private func reservedChromeHeight(for destination: LifeBoardDestination) -> CGFloat {
        showsGlobalChrome(for: destination) ? measuredChromeHeight : 0
    }

    private func compactNavigationChrome(router: LifeBoardAppRouter, paletteMaxHeight: CGFloat) -> some View {
        // The enclosing GlassEffectContainer lives in `compactShell` so the
        // dock and composer morph together.
        Group {
            ZStack {
                HStack(spacing: 0) {
                    ForEach(LifeBoardDestination.allCases, id: \.self) { destination in
                        Button {
                            withAnimation(LifeBoardMotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                                router.activateRoot(destination)
                            }
                            LifeBoardFeedback.selection()
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: destination.systemImage)
                                    .font(.system(size: 17, weight: router.selectedDestination == destination ? .semibold : .regular))
                                    .modifier(
                                        LifeBoardDockLift(
                                            isSelected: router.selectedDestination == destination,
                                            reduceMotion: reduceMotion
                                        )
                                    )
                                if dynamicTypeSize.isAccessibilitySize == false {
                                    Text(destination.title)
                                        .font(.caption2.weight(router.selectedDestination == destination ? .semibold : .regular))
                                }
                            }
                            .foregroundStyle(
                                router.selectedDestination == destination
                                    ? Color(LifeBoardColorTokens.inkPrimary)
                                    : Color(LifeBoardColorTokens.inkSecondary)
                            )
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background {
                                if router.selectedDestination == destination {
                                    Capsule()
                                        .fill(Color(LifeBoardColorTokens.foundationSurfaceSelected).opacity(0.9))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 5)
                                        .matchedGeometryEffect(id: "foundation.dock.selection", in: dockSelectionNamespace)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(destination.title)
                        .accessibilityValue(
                            router.path(for: destination).isEmpty
                                ? "Root"
                                : "Detail depth \(router.path(for: destination).count)"
                        )
                        .accessibilityAddTraits(router.selectedDestination == destination ? .isSelected : [])
                        .accessibilityIdentifier("foundation.destination.\(destination.rawValue)")
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 6)
                // The selected well genuinely bends the content beneath it, so
                // the dock reads as glass rather than a tinted capsule. Bounded
                // to six points and centred on the current target.
                .lifeboardLiquidGlassRefract(
                    center: dockSelectionCenter(for: router.selectedDestination),
                    radius: 0.16,
                    strength: 1
                )
                .lifeBoardGlassSurface(cornerRadius: 30, interactive: true)
                .lifeBoardGlassIdentity(.dockSelection)
                .overlay { RoundedRectangle(cornerRadius: 30).stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1) }
                .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.18), radius: 12, y: 6)
            }
        }
    }

    private func updateCompactCaptureDrag(at location: CGPoint) {
        if compactCaptureState.isExpanded == false {
            withAnimation(LifeBoardMotionProfile.controlMorph.animation(reduceMotion: reduceMotion)) {
                compactCaptureState.isExpanded = true
            }
        }
        let targets = compactCaptureTargetFrames.map { CaptureOrbDragTarget(kind: $0.key, frame: $0.value) }
        let selection = CaptureOrbDragSelectionPolicy.selection(at: location, targets: targets)
        guard selection != compactCaptureState.highlightedKind else { return }
        compactCaptureState.highlightedKind = selection
        if selection != nil { LifeBoardFeedback.selection() }
    }

    private func finishCompactCaptureDrag(at location: CGPoint) {
        let targets = compactCaptureTargetFrames.map { CaptureOrbDragTarget(kind: $0.key, frame: $0.value) }
        if let kind = CaptureOrbDragSelectionPolicy.selection(at: location, targets: targets)
            ?? compactCaptureState.highlightedKind {
            commitCompactCapture(kind)
        }
    }

    private func commitCompactCapture(_ kind: CaptureKind) {
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
        LifeBoardFeedback.light()
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

    private var primaryCaptureKinds: [CaptureKind] {
        [.task, .journal, .note, .trackerEntry, .mood].filter(availableCaptureKinds.contains)
    }

    private func sharedRootHeader(
        _ destination: LifeBoardDestination,
        atmosphereSnapshot: LifeBoardAtmosphereSnapshot
    ) -> some View {
        // Where the floating composer is mounted it owns capture; a second
        // "+" in the header would offer the same tray twice.
        let headerOwnsCapture = showsFloatingComposer(for: destination) == false
        let model = LifeBoardRootHeaderModel(
            title: rootHeaderTitle(for: destination),
            context: rootHeaderContext(for: destination),
            captureAvailable: headerOwnsCapture,
            secondaryActionTitle: "More",
            // Only Home's title is a greeting addressed to the person; the
            // other roots name a destination.
            titleRespondsToTouch: destination == .home
        )
        return VStack(alignment: .trailing, spacing: 8) {
            LifeBoardRootHeader(
                model: model,
                captureExpanded: compactCaptureState.isExpanded,
                usesInverseInk: LifeBoardAtmosphereDescriptor.usesInverseHeaderInk(
                    for: atmosphereSnapshot.phase
                ),
                onCapture: {
                    withAnimation(LifeBoardMotionProfile.controlMorph.animation(reduceMotion: reduceMotion)) {
                        compactCaptureState.isExpanded.toggle()
                        compactCaptureState.highlightedKind = nil
                        compactCaptureRippleTrigger &+= 1
                    }
                    LifeBoardFeedback.light()
                },
                secondaryActions: AnyView(
                    Menu {
                        // The mode control lived in `adaptiveHeader`, which was
                        // never called — so Smart/Work/Personal/Low Energy were
                        // persisted and restored with no way to change them.
                        if destination == .home {
                            Picker("Mode", selection: dashboardModeBinding) {
                                ForEach(DashboardMode.allCases, id: \.self) { mode in
                                    Label(mode.title, systemImage: mode.systemImage).tag(mode)
                                }
                            }
                            .pickerStyle(.menu)

                            Picker("Density", selection: dashboardDensityBinding) {
                                ForEach(DashboardDensity.allCases, id: \.self) { density in
                                    Text(density.title).tag(density)
                                }
                            }
                            .pickerStyle(.menu)

                            // The daypart override was stranded in the same
                            // dead header as the mode picker, so Auto was the
                            // only reachable behaviour.
                            Picker("Atmosphere", selection: daypartSelectionBinding) {
                                ForEach(DaypartSelection.allCases, id: \.self) { selection in
                                    Label(selection.title, systemImage: selection.systemImage).tag(selection)
                                }
                            }
                            .pickerStyle(.menu)

                            if runtime.preferences.activeDaypartOverride != nil {
                                Button("Return to Auto", systemImage: "clock.arrow.circlepath") {
                                    runtime.preferences.returnToAutomaticDaypart()
                                    LifeBoardFeedback.selection()
                                }
                            }
                            Divider()
                        }
                        // Add-to-Home was fully built — placement sheet, receipt
                        // and Undo — and nothing ever set the request, so the
                        // whole personalisation loop was unreachable.
                        if let kinds = homeCardKinds(for: destination), kinds.isEmpty == false {
                            Menu("Add to Home", systemImage: "plus.rectangle.on.rectangle") {
                                ForEach(kinds, id: \.self) { kind in
                                    if let descriptor = DefaultDashboardWidgetRegistry.shared.descriptor(for: kind) {
                                        Button(descriptor.title) {
                                            homeCardPlacementRequest = .init(kind: kind, destination: destination)
                                        }
                                    }
                                }
                            }
                            .accessibilityIdentifier("home.addToHome.\(destination.rawValue)")
                            Divider()
                        }
                        Button("Settings", systemImage: "gearshape") {
                            runtime.router.push(.settings, in: destination)
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    .lifeBoardSystemGlass(.regular, in: Circle(), interactive: true)
                    .accessibilityLabel("More")
                    .accessibilityIdentifier("foundation.more.\(destination.rawValue)")
                )
            )

            if compactCaptureState.isExpanded, headerOwnsCapture {
                HStack(spacing: 6) {
                    ForEach(primaryCaptureKinds, id: \.self) { kind in
                        Button {
                            commitCompactCapture(kind)
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: kind.systemImage)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(captureTrayTitle(kind))
                                    .font(.caption2.weight(.semibold))
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                        .accessibilityLabel("Capture \(captureTrayTitle(kind))")
                    }
                }
                .padding(8)
                .frame(maxWidth: 430)
                .lifeBoardGlassSurface(cornerRadius: 22, interactive: true)
                .lifeBoardGlassIdentity(.captureTray)
                .background {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color(LifeBoardColorTokens.foundationCanvasSoft).opacity(0.44))
                        .lifeboardContextLens(trigger: compactCaptureRippleTrigger)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.94, anchor: .topTrailing)))
                .accessibilityIdentifier("foundation.capture.palette")
            }
        }
        .zIndex(20)
    }

    private func rootHeaderTitle(for destination: LifeBoardDestination) -> String {
        switch destination {
        case .home: runtime.preferences.resolvedDaypart().greeting
        case .plan: "Plan"
        case .track: "Track"
        case .insights: "Insights"
        case .eva: "Eva"
        }
    }

    private func rootHeaderContext(for destination: LifeBoardDestination) -> String {
        switch destination {
        case .home:
            Date().formatted(.dateTime.weekday(.wide).month(.wide).day())
        case .plan: "Make room for what matters."
        case .track: "Record what helps, skip what doesn’t."
        case .insights: "Notice change without turning life into a score."
        case .eva: "Private context, shared only when you choose."
        }
    }

    private func captureTrayTitle(_ kind: CaptureKind) -> String {
        switch kind {
        case .trackerEntry: "Tracker"
        case .mood: "Care"
        default: kind.title
        }
    }

    private func expandedShell(
        router: LifeBoardAppRouter,
        atmosphereSnapshot: LifeBoardAtmosphereSnapshot
    ) -> some View {
        @Bindable var router = router
        // A hand-rolled split view left no way to change roots once the
        // sidebar collapsed. The adaptive tab style keeps a real switcher at
        // every regular width — sidebar when there is room, top bar when there
        // is not — and survives Split View and Slide Over transitions.
        return TabView(selection: $router.selectedDestination) {
            ForEach(LifeBoardDestination.allCases, id: \.self) { destination in
                Tab(destination.title, systemImage: destination.systemImage, value: destination) {
                    retainedDestinationNavigation(
                        destination,
                        router: router,
                        atmosphereSnapshot: atmosphereSnapshot
                    )
                    .safeAreaInset(edge: .bottom, spacing: 0) {
                        // Eva hosts its own composer, so it reserves nothing.
                        Color.clear.frame(
                            height: showsFloatingComposer(for: destination)
                                ? reservedChromeHeight(for: destination)
                                : 0
                        )
                    }
                }
                .accessibilityIdentifier("foundation.destination.\(destination.rawValue)")
            }
        }
        .tabViewStyle(.sidebarAdaptable)
        .overlay(alignment: .bottom) {
            // Capture is not iPhone-only: the composer anchors to the detail
            // column at regular width too.
            if showsFloatingComposer(for: router.selectedDestination),
               showsGlobalChrome(for: router.selectedDestination) {
                GlassEffectContainer(spacing: 10) {
                    lifeThreadComposerHost(router: router)
                }
                .frame(maxWidth: 720)
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    measuredChromeHeight = height
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("LifeBoardExpandedChrome")
            }
        }
    }

    private func retainedDestinationNavigation(
        _ destination: LifeBoardDestination,
        router: LifeBoardAppRouter,
        atmosphereSnapshot: LifeBoardAtmosphereSnapshot
    ) -> AnyView {
        guard destination != .eva || router.selectedDestination == .eva else {
            return AnyView(Color.clear.accessibilityHidden(true))
        }
        return AnyView(
            destinationNavigation(
                destination,
                router: router,
                atmosphereSnapshot: atmosphereSnapshot
            )
        )
    }

    private func destinationNavigation(
        _ destination: LifeBoardDestination,
        router: LifeBoardAppRouter,
        atmosphereSnapshot: LifeBoardAtmosphereSnapshot
    ) -> some View {
        NavigationStack(path: pathBinding(for: destination)) {
            ZStack {
                activeAtmosphere(for: destination, snapshot: atmosphereSnapshot)
                LifeBoardScreenScaffold(mode: .ambient, placement: .root(destination)) {
                    VStack(spacing: 0) {
                        if V2FeatureFlags.lifeBoardPremiumIAV5Enabled,
                           router.path(for: destination).isEmpty {
                            sharedRootHeader(destination, atmosphereSnapshot: atmosphereSnapshot)
                                .padding(.horizontal, 20)
                                .padding(.top, 8)
                                .padding(.bottom, 6)
                                .accessibilityIdentifier("\(destination.rawValue).header")
                        }
                        LifeBoardStableDestinationRoot {
                            destinationRoot(destination, router: router)
                        }
                    }
                }
                .toolbar(
                    V2FeatureFlags.lifeBoardPremiumIAV5Enabled ? .hidden : .visible,
                    for: .navigationBar
                )
            }
                .navigationDestination(for: AppRoute.self) { route in
                    if let transitionID = route.spatialTransitionID {
                        ZStack {
                            // The warp rides the background plane only. Card
                            // content, text and charts must never distort.
                            activeAtmosphere(for: destination, snapshot: atmosphereSnapshot)
                                .lifeboardCardMorphWarp(
                                    origin: .center,
                                    trigger: routeTransitionTrigger
                                )
                            LifeBoardScreenScaffold(mode: route.screenMode, placement: .root(destination)) {
                                routeView(route)
                            }
                        }
                        .lifeBoardZoomDestination(sourceID: transitionID)
                        .toolbar(.visible, for: .navigationBar)
                        .onAppear { routeTransitionTrigger &+= 1 }
                    } else {
                        ZStack {
                            activeAtmosphere(for: destination, snapshot: atmosphereSnapshot)
                            LifeBoardScreenScaffold(mode: route.screenMode, placement: .root(destination)) {
                                routeView(route)
                            }
                        }
                        .toolbar(.visible, for: .navigationBar)
                    }
                }
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .background(Color.clear)
    }

    @ViewBuilder
    private func activeAtmosphere(
        for destination: LifeBoardDestination,
        snapshot: LifeBoardAtmosphereSnapshot
    ) -> some View {
        if destination == runtime.router.selectedDestination {
            LifeBoardAdaptiveAtmosphere(
                snapshot: snapshot,
                placement: .root(destination),
                requestedTier: runtime.preferences.renderingTier,
                comfortProfile: runtime.preferences.comfortProfile
            )
            .lifeboardDaypartBloom(
                center: .topTrailing,
                trigger: daypartBloomTrigger,
                daypart: snapshot.semanticDaypart
            )
            .ignoresSafeArea()
        } else {
            Color.clear
        }
    }

    private func homeCardKinds(for destination: LifeBoardDestination) -> [DashboardWidgetKind]? {
        switch destination {
        case .home: return nil
        case .plan: return [.focusNow, .tasks, .scheduleCapacity, .compactTimeline]
        case .track:
            var kinds: [DashboardWidgetKind] = [.care, .routines, .goals, .fasting, .journal, .lifeSnapshot]
            if V2FeatureFlags.wellnessCoreV1Enabled {
                kinds += [.bodyMetric, .workout, .sleep, .movement]
            }
            if V2FeatureFlags.nutritionV1Enabled {
                kinds += [.nutritionSummary, .recentMeal, .logMeal]
            }
            if V2FeatureFlags.lifeMomentsV1Enabled {
                kinds.append(.lifeMoment)
            }
            return kinds
        case .insights: return [.progressReflection, .lifeSnapshot]
        case .eva: return [.progressReflection, .journal, .evaConversation]
        }
    }

    @MainActor
    private func addCardToHome(
        _ kind: DashboardWidgetKind,
        size: WidgetSizePreset,
        from destination: LifeBoardDestination
    ) async {
        do {
            let before = try await dashboardLayoutRepository.fetchHome()
                ?? DashboardLayoutValue(
                    mode: .smart,
                    isDefault: true,
                    placements: CoreDataDashboardLayoutRepository.curatedHomePlacements()
                )
            var draft = HomeLayoutDraft(layout: before)
            let registry = DefaultDashboardWidgetRegistry.shared
            guard let descriptor = registry.descriptor(for: kind) else { return }
            if let existing = draft.current.placements.first(where: { $0.widgetKind == kind.rawValue }),
               descriptor.multiplicity == .singleton {
                draft.setVisible(true, id: existing.id)
                draft.resize(id: existing.id, to: size, registry: registry)
                draft.setOwnership(.pinned, id: existing.id)
                draft.setSource(.init(destination: destination), id: existing.id)
            } else {
                draft.add(kind: kind, size: size, registry: registry)
                if let added = draft.current.placements.last(where: { $0.widgetKind == kind.rawValue }) {
                    draft.setSource(.init(destination: destination), id: added.id)
                }
            }
            let after = try draft.committedLayout()
            try await dashboardLayoutRepository.saveHome(after)
            let transaction = HomeLayoutTransaction(before: before, after: after)
            withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.86)) {
                homeCardReceipt = .init(
                    title: "\(descriptor.title) added to Home",
                    transaction: transaction
                )
            }
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        } catch {
            runtime.router.activeAlert = .init(
                title: "Couldn’t update Home",
                message: "Your current Home layout is unchanged. Please try again."
            )
        }
    }

    private func destinationRoot(
        _ destination: LifeBoardDestination,
        router: LifeBoardAppRouter
    ) -> AnyView {
        if destination == .home,
           showsReferenceHome == false {
            return AnyView(LifeBoardAdaptiveHome(
                projectionAdapter: homeProjectionAdapter,
                preferences: runtime.preferences,
                router: router,
                captureRouter: runtime.captureRouter,
                repository: dashboardLayoutRepository,
                phaseIIRepository: phaseIIRepository,
                planningRepository: planningRepository,
                trackFoundationRepository: trackFoundationRepository,
                goalSampleProvider: goalSampleProvider,
                wellnessRepository: wellnessRepository,
                nutritionRepository: nutritionRepository,
                lifeMomentRepository: lifeMomentRepository,
                showsEmbeddedComposer: false,
                onCustomizationChanged: { isCustomizing in
                    homeIsCustomizing = isCustomizing
                }
            ))
        } else if destination == .plan,
                  V2FeatureFlags.phase1ExecutionFlagshipEnabled,
                  let planDependencies {
            return AnyView(LifeBoardPlanRootView(
                dependencies: planDependencies,
                rescueRefreshGeneration: planRescueRefreshGeneration,
                onOpenFocus: { _ in router.select(.plan) },
                onAskEva: { router.select(.eva) },
                onOpenWeeklyPlanner: { router.push(.weeklyPlanner, in: .plan) },
                onOpenWeeklyReview: { router.push(.weeklyReview, in: .plan) },
                onOpenOverdueRescue: presentPlanOverdueRescue,
                onReviewCapture: { item in
                    // Filing an unreviewed capture goes through the ordinary task
                    // editor seeded with the raw text, so the parser's proposal is
                    // something the user confirms rather than inherits.
                    runtime.captureRouter.request(
                        CaptureRequest(kind: .task, source: .shell, prefilledText: item.title)
                    )
                },
                onOpenTask: { router.push(.taskDetail($0), in: .plan) },
                onOpenProject: { router.push(.project($0), in: .plan) }
            ))
        } else if destination == .plan {
            return AnyView(FoundationPlanRollbackRouteView(router: router))
        } else if destination == .track,
                  V2FeatureFlags.trackFoundationsV2Enabled,
                  V2FeatureFlags.trackBehaviorFlagshipV1Enabled {
            return AnyView(LifeBoardTrackFoundationRootView(
                repository: trackFoundationRepository,
                phaseIIRepository: phaseIIRepository,
                habitProjectionService: CanonicalTrackHabitProjectionService(repository: habitRuntimeReadRepository),
                linkedMutationApplier: routineLinkedMutationApplier,
                goalSampleProvider: goalSampleProvider,
                starterPackMutationApplier: starterPackMutationApplier,
                habitRecoveryMutationApplier: habitRecoveryMutationApplier,
                sourcePickerRepository: ComposedTypedSourcePickerRepository(
                    planningProjection: planningRepository,
                    trackFoundation: trackFoundationRepository,
                    phaseII: phaseIIRepository,
                    habitRuntime: habitRuntimeReadRepository
                ),
                nutritionRepository: nutritionRepository,
                lifeMomentRepository: lifeMomentRepository,
                wellnessRepository: wellnessRepository,
                onOpenHabitBoard: { router.push(.habitBoard, in: .track) },
                onOpenHealth: { router.push(.health, in: .track) }
            ))
        } else if destination == .track {
            return AnyView(LifeBoardBehaviorAreaRouteView(
                repository: phaseIIRepository,
                initialArea: .medication,
                onOpenHabitBoard: { router.push(.habitBoard, in: .track) },
                onOpenHealth: { router.push(.health, in: .track) }
            ))
        } else if destination == .home {
            return AnyView(LifeBoardReferenceDashboard(preferences: runtime.preferences)
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.inline)
            )
        } else if destination == .insights {
            return AnyView(FoundationInsightsDestination(
                repository: trackFoundationRepository,
                phaseIIRepository: phaseIIRepository,
                planningRepository: planningRepository,
                habitProjectionService: CanonicalTrackHabitProjectionService(repository: habitRuntimeReadRepository),
                goalSampleProvider: goalSampleProvider,
                router: router
            ))
        } else if destination == .eva {
            return AnyView(FoundationEvaDestination(
                repository: trackFoundationRepository,
                phaseIIRepository: phaseIIRepository,
                planningRepository: planningRepository,
                habitProjectionService: CanonicalTrackHabitProjectionService(repository: habitRuntimeReadRepository),
                goalSampleProvider: goalSampleProvider,
                router: router
            ))
        }
        return AnyView(EmptyView())
    }

    @ViewBuilder
    private func lifeThreadComposerHost(router: LifeBoardAppRouter) -> some View {
        @Bindable var composer = lifeThreadComposer
        VStack(spacing: 8) {
            if let preview = composer.preview {
                LifeBoardComposerPreviewCard(
                    preview: preview,
                    onApply: { applyLifeThreadPreview(preview, router: router) },
                    onEdit: {
                        composer.draftText = preview.summary
                        composer.focus()
                        lifeThreadComposerIsFocused = true
                        Task { await lifeBoardMutationCoordinator.discard(previewID: preview.id) }
                    },
                    onNotNow: {
                        composer.settle()
                        Task {
                            await lifeBoardMutationCoordinator.discard(previewID: preview.id)
                            try? await Task.sleep(for: .milliseconds(180))
                            await MainActor.run { composer.finishSettling() }
                        }
                    }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let receipt = lifeBoardActionReceipt {
                LifeBoardComposerReceiptView(
                    receipt: receipt,
                    onUndo: { undoLifeThreadReceipt(receipt, router: router) },
                    onDismiss: { lifeBoardActionReceipt = nil }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let clarification = composer.clarification {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(clarification.question)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        Spacer()
                        Button {
                            composer.dismissClarification()
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Dismiss clarification")
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(clarification.options) { option in
                                Button {
                                    composer.dismissClarification()
                                    handleLifeThreadResolution(option.resolution, router: router)
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: option.systemImage)
                                        Text(option.label)
                                    }
                                    .font(.subheadline.weight(.medium))
                                    .padding(.horizontal, 12)
                                    .frame(minHeight: 44)
                                    .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: Capsule())
                                    .overlay {
                                        Capsule()
                                            .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(12)
                .lifeBoardClaySurface(.raised, cornerRadius: LifeBoardFoundationRadius.card)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if let interpretation = composer.interpretation {
                HStack(spacing: 8) {
                    Button {
                        let res = interpretation.resolution
                        composer.dismissInterpretation()
                        handleLifeThreadResolution(res, router: router)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: interpretation.systemImage)
                                .foregroundColor(Color.lifeboard(.accentPrimary))
                            Text(interpretation.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))

                            ForEach(interpretation.chips) { chip in
                                Text(chip.label)
                                    .font(.caption2.weight(.medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: Capsule())
                                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            }
                            Spacer()
                            Image(systemName: "arrow.right.circle.fill")
                                .foregroundStyle(Color.lifeboard(.accentPrimary))
                        }
                        .padding(.horizontal, 12)
                        .frame(minHeight: 44)
                        .background(Color.lifeboard(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)

                    Button {
                        composer.dismissInterpretation()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(Color(LifeBoardColorTokens.inkSecondary))
                            .frame(width: 26, height: 26)
                            .background(Color.lifeboard(.surfaceSecondary), in: Circle())
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss interpretation")
                }
                .padding(.horizontal, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if dictationController.isRecording || dictationController.phase == .preparing || dictationController.phase == .finalizing {
                HStack(spacing: 8) {
                    let phaseLabel: String = {
                        switch dictationController.phase {
                        case .preparing: return "Preparing…"
                        case .finalizing: return "Finalizing…"
                        default: return "Recording"
                        }
                    }()
                    Circle()
                        .fill(dictationController.phase == .preparing || dictationController.phase == .finalizing
                              ? Color(LifeBoardColorTokens.inkSecondary)
                              : Color.lifeboard(.statusDanger))
                        .frame(width: 8, height: 8)
                        .opacity(dictationController.phase == .recording ? (reduceMotion ? 1 : 0.55) : 1)
                        .scaleEffect(dictationController.phase == .recording && !reduceMotion ? 1.1 : 1)
                        .animation(reduceMotion ? nil : .easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: dictationController.isRecording)
                    Text("\(phaseLabel) \(formatElapsedSeconds(dictationController.elapsedSeconds))")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        .accessibilityLabel("\(phaseLabel) elapsed \(dictationController.elapsedSeconds) seconds")
                        .accessibilityIdentifier("lifeThread.composer.dictation.badge")
                    Spacer()
                }
                .padding(.horizontal, 4)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if composer.state == .tools {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(Array(composerTools.enumerated()), id: \.element.id) { index, tool in
                            composerToolChip(tool, router: router)
                                .modifier(ComposerToolStagger(index: index, reduceMotion: reduceMotion))
                        }
                    }
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
                .transition(.opacity)
                .accessibilityIdentifier("lifeThread.composer.tools")
            }

            if let workingLabel = composer.workingLabel {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(workingLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    Spacer()
                }
                .padding(.horizontal, 12)
                .accessibilityElement(children: .combine)
            }

            if let recovery = composer.recovery {
                HStack(spacing: 10) {
                    Text(composer.recoveryMessage ?? "Your draft is still here.")
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    Spacer(minLength: 8)
                    Button(recovery == .continue ? "Continue" : "Retry") {
                        submitLifeThreadComposer(router: router)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityHint("Keeps the current draft and attachments")
                }
                .padding(.horizontal, 12)
                .accessibilityIdentifier("lifeThread.composer.recovery")
            }

            HStack(spacing: 8) {
                Button {
                    withAnimation(LifeBoardMotionProfile.controlMorph.animation(reduceMotion: reduceMotion)) {
                        composer.state == .tools ? composer.focus() : composer.showTools()
                    }
                    LifeBoardFeedback.light()
                } label: {
                    // The plus rotates into the close glyph rather than
                    // swapping, so the control reads as one object opening.
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .rotationEffect(.degrees(composer.state == .tools ? 45 : 0))
                        .frame(width: 44, height: 44)
                        // Without an explicit shape the hit region collapses to
                        // the glyph itself, well under the 44pt minimum.
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(
                    composer.state == .working
                        || dictationController.phase == .preparing
                        || dictationController.phase == .recording
                        || dictationController.phase == .finalizing
                )
                .accessibilityLabel(composer.state == .tools ? "Close capture tools" : "Open capture tools")
                .accessibilityIdentifier("lifeThread.composer.toolsToggle")

                TextField(text: $composer.draftText, axis: .vertical) {
                    Text(composerPlaceholder(for: composer.destination))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                    .lineLimit(1...4)
                    .disabled(
                        composer.state == .working
                            || dictationController.phase == .preparing
                            || dictationController.phase == .recording
                            || dictationController.phase == .finalizing
                    )
                    .focused($lifeThreadComposerIsFocused)
                    .submitLabel(.send)
                    .onSubmit { submitLifeThreadComposer(router: router) }
                    .onChange(of: lifeThreadComposerIsFocused) { _, focused in
                        if focused { composer.focus() }
                    }
                    .onChange(of: composer.draftText) { _, _ in
                        liveResolveComposerIntent(router: router)
                    }
                    .onChange(of: dictationController.draftText) { _, newValue in
                        // Pull the live transcript back into the composer's
                        // editable text during recording. Don't run intent
                        // resolution from here — it's driven by the
                        // `composer.draftText` change above (and is
                        // suppressed during active recording).
                        guard dictationController.isRecording else { return }
                        if lifeThreadComposer.draftText != newValue {
                            lifeThreadComposer.draftText = newValue
                        }
                    }
                    .onChange(of: dictationController.recovery) { _, recovery in
                        guard let recovery else { return }
                        switch recovery.phase {
                        case .denied, .unsupportedLocale, .assetInstallFailed:
                            runtime.router.activeAlert = .init(
                                title: "Dictation isn't available",
                                message: recovery.message
                            )
                            lifeThreadComposer.cancelDictating(
                                restoringText: dictationController.draftText.isEmpty ? lifeThreadComposer.draftText : dictationController.draftText
                            )
                        case .failed:
                            runtime.router.activeAlert = .init(
                                title: "Dictation paused",
                                message: recovery.message
                            )
                            lifeThreadComposer.finishDictating(composedText: dictationController.draftText)
                        case .idle, .preparing, .recording, .finalizing:
                            break
                        }
                    }
                    .accessibilityIdentifier("home.lifeThread.composer")

                if dictationController.isRecording || dictationController.phase == .preparing || dictationController.phase == .finalizing {
                    Button {
                        cancelComposerDictation()
                    } label: {
                        Label("Cancel", systemImage: "xmark.circle.fill")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            .frame(width: 44, height: 44)
                            .background(Color.lifeboard(.surfaceSecondary), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(composer.state == .working)
                    .accessibilityLabel("Cancel dictation")
                    .accessibilityIdentifier("lifeThread.composer.dictation.cancel")

                    Button {
                        stopComposerDictation()
                    } label: {
                        Label("Done", systemImage: "stop.fill")
                            .labelStyle(.iconOnly)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(LifeBoardColorTokens.foundationSurfaceSolid))
                            .frame(width: 44, height: 44)
                            .background(Color(LifeBoardColorTokens.inkPrimary), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(composer.state == .working)
                    .accessibilityLabel("Stop dictation")
                    .accessibilityIdentifier("lifeThread.composer.dictation.done")
                } else {
                    Button {
                        if composer.hasDraft {
                            submitLifeThreadComposer(router: router)
                        } else {
                            beginComposerAudioCapture()
                        }
                    } label: {
                        Image(systemName: composer.hasDraft ? "arrow.up" : "waveform")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(Color(LifeBoardColorTokens.foundationSurfaceSolid))
                            .frame(width: 44, height: 44)
                            .background(Color(LifeBoardColorTokens.inkPrimary), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .disabled(composer.state == .working)
                    .accessibilityLabel(
                        composer.hasDraft
                            ? "Interpret input"
                            : (V2FeatureFlags.universalInputDictationEnabled ? "Start dictation" : "Record journal audio")
                    )
                    .accessibilityIdentifier("lifeThread.composer.send")
                }
            }
            .padding(8)
            .lifeBoardGlassSurface(cornerRadius: 27, interactive: true)
            .overlay {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
            }
            .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.16), radius: 12, y: 6)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.88), value: composer.state)
    }

    /// One ordered capture tray. Kinds with a working capture host each get a
    /// visible control — `habit`, `trackerEntry` and `timeBlock` previously had
    /// hosts wired with no way to reach them.
    fileprivate struct ComposerToolDescriptor: Identifiable {
        enum Action { case capture(CaptureKind), voice, scan }
        let id: String
        let title: String
        let systemImage: String
        let action: Action
    }

    private var composerTools: [ComposerToolDescriptor] {
        var tools: [ComposerToolDescriptor] = [
            .init(id: "task", title: "Task", systemImage: "checkmark.circle", action: .capture(.task)),
            .init(id: "habit", title: "Habit", systemImage: "repeat", action: .capture(.habit))
        ]
        if V2FeatureFlags.planningCoreV1Enabled {
            tools.append(.init(id: "timeBlock", title: "Time block", systemImage: "clock", action: .capture(.timeBlock)))
        }
        if V2FeatureFlags.journalV1Enabled {
            tools.append(.init(id: "journal", title: "Journal", systemImage: "book.closed", action: .capture(.journal)))
        }
        if V2FeatureFlags.careModulesV2Enabled {
            tools.append(.init(id: "mood", title: "Mood", systemImage: "face.smiling", action: .capture(.mood)))
            tools.append(.init(id: "metric", title: "Metric", systemImage: "waveform.path.ecg", action: .capture(.hydration)))
        }
        if V2FeatureFlags.trackersV1Enabled {
            tools.append(.init(id: "tracker", title: "Tracker", systemImage: "list.bullet.rectangle", action: .capture(.trackerEntry)))
        }
        tools.append(.init(id: "voice", title: "Voice", systemImage: "waveform", action: .voice))
        tools.append(.init(id: "scan", title: "Scan", systemImage: "doc.viewfinder", action: .scan))
        if V2FeatureFlags.knowledgeNotesV1Enabled {
            tools.append(.init(id: "note", title: "Note", systemImage: "note.text", action: .capture(.note)))
        }
        return tools
    }

    @ViewBuilder
    private func composerToolChip(
        _ tool: ComposerToolDescriptor,
        router: LifeBoardAppRouter
    ) -> some View {
        Group {
            switch tool.action {
            case .capture(let kind):
                composerCaptureButton(tool.title, systemImage: tool.systemImage, kind: kind)
            case .voice:
                composerToolButton(tool.title, systemImage: tool.systemImage) { beginComposerAudioCapture() }
            case .scan:
                composerToolButton(tool.title, systemImage: tool.systemImage) { beginDocumentScan(router: router) }
            }
        }
        .accessibilityIdentifier("lifeThread.composer.tool.\(tool.id)")
    }

    private func composerCaptureButton(
        _ title: String,
        systemImage: String,
        kind: CaptureKind
    ) -> some View {
        Button {
            runtime.captureRouter.request(
                kind: kind,
                source: .shell,
                presentationContext: .init(
                    sourceRoot: runtime.router.selectedDestination,
                    sourcePoint: .init(x: 0.08, y: 0.92),
                    preferredCaptureKind: kind
                )
            )
            LifeBoardFeedback.light()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: Capsule())
                .overlay { Capsule().stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func composerToolButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 12)
                .frame(minHeight: 44)
                .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: Capsule())
                .overlay { Capsule().stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    /// Mounts the existing save-first Journal audio controls directly in the
    /// shared composer's recording state instead of detouring through the
    /// full Journal module. When the universal-input dictation kill switch
    /// is on, the microphone falls back to the Journal audio-attachment
    /// flow (pre-existing behavior) when the universal-input dictation kill
    /// switch is off.
    private func beginComposerAudioCapture() {
        guard V2FeatureFlags.universalInputDictationEnabled else {
            guard V2FeatureFlags.journalV1Enabled else {
                runtime.captureRouter.request(kind: .journal, source: .shell)
                return
            }
            if composerAudioStore == nil {
                composerAudioStore = LifeBoardJournalStore(repository: phaseIIRepository)
            }
            lifeThreadComposer.beginRecording()
            showsComposerAudioCapture = true
            return
        }
        if dictationController.isRecording || dictationController.phase == .preparing || dictationController.phase == .finalizing {
            stopComposerDictation()
            return
        }
        lifeThreadComposer.beginDictating()
        dictationController.start(existingDraft: lifeThreadComposer.draftText)
    }

    /// Stop the live dictation session: end input, await analyzer
    /// finalization, and retain the final transcript in the draft. The
    /// composer returns to the focused state with the combined typed +
    /// dictated text.
    private func stopComposerDictation() {
        Task { @MainActor in
            await dictationController.stop()
            if let recovery = dictationController.recovery, recovery.phase == .failed {
                runtime.router.activeAlert = .init(
                    title: "Dictation paused",
                    message: recovery.message
                )
            }
            lifeThreadComposer.finishDictating(composedText: dictationController.draftText)
        }
    }

    /// Cancel the live dictation session: tear down audio and restore the
    /// pre-dictation draft so the user can keep typing.
    private func cancelComposerDictation() {
        Task { @MainActor in
            await dictationController.cancel()
            lifeThreadComposer.cancelDictating(restoringText: dictationController.draftText)
        }
    }

    private func beginDocumentScan(router: LifeBoardAppRouter) {
        guard VNDocumentCameraViewController.isSupported else {
            router.activeAlert = .init(
                title: "Scanning isn’t available here",
                message: "Use LifeBoard on an iPhone or iPad with a camera, or paste text into the composer."
            )
            return
        }
        lifeThreadComposer.beginScanning()
        showsDocumentScanner = true
    }

    private func composerPlaceholder(for destination: LifeBoardDestination) -> String {
        switch destination {
        case .home: "Ask Eva or capture what is on your mind"
        case .plan: "Plan, move, or make sense of your time"
        case .track: "Log something or reflect on how you feel"
        case .insights: "Ask about a pattern or what to try next"
        case .eva: "Talk with Eva"
        }
    }

    private func formatElapsedSeconds(_ seconds: Int) -> String {
        let minutes = max(0, seconds) / 60
        let remainder = max(0, seconds) % 60
        return String(format: "%d:%02d", minutes, remainder)
    }

    private func liveResolveComposerIntent(router: LifeBoardAppRouter) {
        guard V2FeatureFlags.universalInputRoutingEnabled else { return }
        liveIntentResolveTask?.cancel()
        // An interpretation belongs to the exact draft that produced it.
        // Clear it synchronously before debouncing the replacement so a
        // quick edit-then-submit can never execute a stale action.
        lifeThreadComposer.dismissInterpretation()
        lifeThreadComposer.dismissClarification()
        // Don't interpret while recording — the composer text is volatile
        // (live transcript) and the user can't yet act on an interpretation
        // row. Resolution runs once on stop, via `submitLifeThreadComposer`.
        guard dictationController.isRecording == false else { return }
        let text = lifeThreadComposer.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else {
            return
        }
        liveIntentResolveTask = Task {
            try? await Task.sleep(for: .milliseconds(320))
            guard !Task.isCancelled else { return }
            let input = LifeThreadIntentInput(
                text: text,
                attachments: lifeThreadComposer.attachments.map(\.localIdentifier),
                destination: lifeThreadComposer.destination,
                origin: .conversation,
                inputSource: lifeThreadComposer.lastInputSource,
                selectedDate: router.selectedDestination == .home ? homeViewModel.selectedDate : nil,
                daypart: runtime.preferences.resolvedDaypart(),
                dashboardMode: router.dashboardMode,
                calendarAvailable: homeViewModel.homeCalendarSnapshot.authorizationStatus.isAuthorizedForRead,
                dayRescueEligible: !homeViewModel.dayRescueTasksByID.isEmpty,
                overdueRescueEligible: !homeViewModel.evaRescueTasksByID.isEmpty,
                overdueTaskCount: homeViewModel.evaRescueTasksByID.count
            )
            let resolution = await universalInputCoordinator.resolvePreview(input)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                switch resolution {
                case .captureDraft(let draft):
                    lifeThreadComposer.showInterpretation(for: draft)
                case .navigation(let navigation):
                    lifeThreadComposer.showInterpretation(for: navigation)
                case .surfaceAction(let action):
                    lifeThreadComposer.showInterpretation(for: action)
                case .clarification(let clarification):
                    lifeThreadComposer.showClarification(clarification)
                case .answer, .transactionPreview:
                    // No preview interpretation to show for free-text or
                    // transaction previews that already drive their own
                    // affordance. Leave the composer ready to submit
                    // directly via the Send button.
                    lifeThreadComposer.dismissInterpretation()
                    lifeThreadComposer.dismissClarification()
                }
            }
        }
    }

    private func submitLifeThreadComposer(router: LifeBoardAppRouter) {
        liveIntentResolveTask?.cancel()
        liveIntentResolveTask = nil
        if let interpretation = lifeThreadComposer.interpretation {
            let res = interpretation.resolution
            lifeThreadComposer.dismissInterpretation()
            handleLifeThreadResolution(res, router: router)
            return
        }
        let text = lifeThreadComposer.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        guard V2FeatureFlags.universalInputRoutingEnabled else {
            do {
                try EvaChatLaunchRequestStore.shared.submit(.init(prompt: text))
                lifeThreadComposer.dismissDraft()
                lifeThreadComposerIsFocused = false
                router.activateRoot(.eva)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } catch {
                lifeThreadComposer.focus()
                router.activeAlert = .init(
                    title: "Couldn’t open Eva",
                    message: "Your draft is still here. Please try again."
                )
            }
            return
        }
        let input = LifeThreadIntentInput(
            text: text,
            attachments: lifeThreadComposer.attachments.map(\.localIdentifier),
            destination: lifeThreadComposer.destination,
            origin: .conversation,
            inputSource: lifeThreadComposer.lastInputSource,
            selectedDate: router.selectedDestination == .home ? homeViewModel.selectedDate : nil,
            daypart: runtime.preferences.resolvedDaypart(),
            dashboardMode: router.dashboardMode,
            calendarAvailable: homeViewModel.homeCalendarSnapshot.authorizationStatus.isAuthorizedForRead,
            dayRescueEligible: !homeViewModel.dayRescueTasksByID.isEmpty,
            overdueRescueEligible: !homeViewModel.evaRescueTasksByID.isEmpty,
            overdueTaskCount: homeViewModel.evaRescueTasksByID.count
        )
        lifeThreadComposer.beginWorking("Understanding what you need")
        Task {
            let resolution = await universalInputCoordinator.resolve(input)
            await MainActor.run {
                handleLifeThreadResolution(resolution, router: router)
            }
        }
    }

    private func handleLifeThreadResolution(_ resolution: LifeThreadIntentResolution, router: LifeBoardAppRouter) {
        switch resolution {
        case .answer(let request):
            do {
                try EvaChatLaunchRequestStore.shared.submit(.init(prompt: request.prompt))
                lifeThreadComposer.dismissDraft()
                lifeThreadComposerIsFocused = false
                router.activateRoot(.eva)
                UIImpactFeedbackGenerator(style: .soft).impactOccurred()
            } catch {
                lifeThreadComposer.focus()
                router.activeAlert = .init(
                    title: "Couldn’t open Eva",
                    message: "Your draft is still here. Please try again."
                )
            }
        case .captureDraft(let draft):
            lifeThreadComposer.focus()
            runtime.captureRouter.request(
                kind: draft.kind,
                source: .shell,
                prefilledText: draft.seed?.rawText,
                captureSeed: draft.seed
            )
        case .transactionPreview(let preview):
            lifeThreadComposer.review(preview)
        case .navigation(let request):
            lifeThreadComposer.focus()
            router.activateRoot(request.destination)
            if let route = request.route {
                router.push(route, in: request.destination)
            }
        case .clarification(let clarification):
            lifeThreadComposer.showClarification(clarification)
        case .surfaceAction(let action):
            // Surface actions preserve the composer draft so the user can
            // resume if the action is cancelled. We don't dismiss the
            // keyboard or the draft; only the deck navigates over the
            // composer.
            lifeThreadComposerIsFocused = false
            switch action {
            case .showTodaySchedule:
                let calendarAvailable = homeViewModel.homeCalendarSnapshot
                    .authorizationStatus.isAuthorizedForRead
                router.activateRoot(.home)
                // Always focus today so "check my meetings" lands on the
                // current day even if Home was scrubbed.
                if calendarAvailable {
                    homeViewModel.returnToToday(source: .universalInput)
                    presentCalendarSchedule(router: router)
                } else {
                    // Calendar-unavailable: navigate to Home and surface
                    // the canonical permission-guidance body copy as a
                    // toast so the user can grant access and retry.
                    let accessAction = homeViewModel.homeCalendarSnapshot.accessAction
                    let guidance: String
                    switch accessAction {
                    case .requestPermission:
                        guidance = "Connect Calendar to surface next meetings and free windows."
                    case .openSystemSettings:
                        guidance = "Calendar access is denied. Enable LifeBoard in Settings > Privacy & Security > Calendars to see your meetings here."
                    case .unavailable:
                        guidance = "Calendar access is restricted by system policy."
                    case .noneNeeded:
                        guidance = "Calendar is connected, but no calendars are selected. Pick one in Home to see your meetings."
                    }
                    router.activeAlert = .init(
                        title: "Calendar isn’t connected",
                        message: guidance
                    )
                }
            case .dayRescue:
                presentPlanOverdueRescue(
                    OverdueRescueLaunchContext.universalInputDayRescue(
                        referenceDate: Date()
                    )
                )
            case .overdueRescue:
                presentPlanOverdueRescue(
                    OverdueRescueLaunchContext.home(
                        referenceDate: Date()
                    )
                )
            }
        }
    }

    /// Sends "check my meetings" to Plan's day lens.
    ///
    /// This route used to depend on a detached UIKit home and could silently
    /// no-op. The typed foundation route is now the sole authority.
    ///
    /// `.planDay` is not a compromise destination: it draws the same calendar
    /// events (`PlanDaySnapshot.commitments`, built from `externalCommitments`)
    /// on an hour grid with the free-window layer, and it is already where
    /// `lifeboard://calendar/schedule` lands from the widget — so the two paths
    /// that used to disagree now don't.
    private func presentCalendarSchedule(router: LifeBoardAppRouter) {
        router.select(.plan)
        router.push(.planDay, in: .plan)
    }

    private func applyLifeThreadPreview(
        _ preview: LifeBoardTransactionPreview,
        router: LifeBoardAppRouter
    ) {
        lifeThreadComposer.beginWorking("Saving locally")
        Task {
            do {
                let receipt = try await lifeBoardMutationCoordinator.apply(previewID: preview.id)
                await MainActor.run {
                    lifeBoardActionReceipt = receipt
                    lifeThreadComposer.dismissDraft()
                    lifeThreadComposer.settle()
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                try? await Task.sleep(for: .milliseconds(220))
                await MainActor.run { lifeThreadComposer.finishSettling() }
            } catch {
                await MainActor.run {
                    lifeThreadComposer.review(preview)
                    router.activeAlert = .init(
                        title: "Change wasn’t applied",
                        message: "Nothing was changed. Your preview is still here so you can try again."
                    )
                }
            }
        }
    }

    private func undoLifeThreadReceipt(
        _ receipt: LifeBoardActionReceipt,
        router: LifeBoardAppRouter
    ) {
        Task {
            do {
                try await lifeBoardMutationCoordinator.undo(receiptID: receipt.id)
                await MainActor.run {
                    lifeBoardActionReceipt = nil
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
            } catch {
                await MainActor.run {
                    router.activeAlert = .init(
                        title: "Couldn’t undo",
                        message: "The saved change is still in place. Please open its source and try again."
                    )
                }
            }
        }
    }

    @ViewBuilder
    private func planRoute(lens: PlanLens, title: String, systemImage: String) -> some View {
        if V2FeatureFlags.phase1ExecutionFlagshipEnabled,
           let planDependencies {
            LifeBoardPlanRootView(
                dependencies: planDependencies,
                initialLens: lens,
                rescueRefreshGeneration: planRescueRefreshGeneration,
                onOpenFocus: { _ in runtime.router.select(.plan) },
                onAskEva: { runtime.router.select(.eva) },
                onOpenWeeklyPlanner: { runtime.router.push(.weeklyPlanner, in: .plan) },
                onOpenWeeklyReview: { runtime.router.push(.weeklyReview, in: .plan) },
                onOpenOverdueRescue: presentPlanOverdueRescue,
                onOpenTask: { runtime.router.push(.taskDetail($0), in: .plan) },
                onOpenProject: { runtime.router.push(.project($0), in: .plan) }
            )
        } else {
            FoundationPlanRollbackRouteView(router: runtime.router)
        }
    }

    @ViewBuilder
    private func routeView(_ route: AppRoute) -> some View {
        switch route {
        case .tokenGallery:
            LifeBoardTokenGallery(preferences: runtime.preferences)
        case .referenceDashboard:
            LifeBoardReferenceDashboard(preferences: runtime.preferences)
                .navigationTitle("Reference dashboard")
                .navigationBarTitleDisplayMode(.inline)
        case .planDay:
            planRoute(lens: .day, title: "Day", systemImage: "sun.max")
        case .planWeek:
            planRoute(lens: .week, title: "Week", systemImage: "calendar")
        case .backlog:
            planRoute(lens: .backlog, title: "Backlog", systemImage: "tray.full")
        case .weeklyPlanner:
            FoundationWeeklyPlannerRoute(
                onClose: { runtime.router.pop(in: .plan) }
            )
        case .weeklyReview:
            // Insights pushes this into its own stack; popping `.plan`
            // unconditionally meant Close did nothing when opened from there.
            FoundationWeeklyReviewRoute(
                onClose: { runtime.router.pop(in: runtime.router.selectedDestination) }
            )
        case .trackHistory:
            if V2FeatureFlags.trackBehaviorFlagshipV1Enabled {
                LifeBoardTrackFoundationRootView(
                    repository: trackFoundationRepository,
                    phaseIIRepository: phaseIIRepository,
                    habitProjectionService: CanonicalTrackHabitProjectionService(repository: habitRuntimeReadRepository),
                    linkedMutationApplier: routineLinkedMutationApplier,
                    goalSampleProvider: goalSampleProvider,
                    starterPackMutationApplier: starterPackMutationApplier,
                    habitRecoveryMutationApplier: habitRecoveryMutationApplier,
                    sourcePickerRepository: ComposedTypedSourcePickerRepository(
                        planningProjection: planningRepository,
                        trackFoundation: trackFoundationRepository,
                        phaseII: phaseIIRepository,
                        habitRuntime: habitRuntimeReadRepository
                    ),
                    nutritionRepository: nutritionRepository,
                    lifeMomentRepository: lifeMomentRepository,
                    wellnessRepository: wellnessRepository,
                    initialLens: .history,
                    onOpenHabitBoard: { runtime.router.push(.habitBoard, in: .track) },
                    onOpenHealth: { runtime.router.push(.health, in: .track) }
                )
            } else {
                LifeBoardBehaviorAreaRouteView(
                    repository: phaseIIRepository,
                    initialArea: .medication,
                    onOpenHabitBoard: { runtime.router.push(.habitBoard, in: .track) },
                    onOpenHealth: { runtime.router.push(.health, in: .track) }
                )
            }
        case .insightEvidence(let evidenceID):
            FoundationInsightsDestination(
                repository: trackFoundationRepository,
                phaseIIRepository: phaseIIRepository,
                planningRepository: planningRepository,
                habitProjectionService: CanonicalTrackHabitProjectionService(repository: habitRuntimeReadRepository),
                goalSampleProvider: goalSampleProvider,
                router: runtime.router,
                // A named record wants the widest window, not just today.
                initialLens: evidenceID == nil ? .overview : .review,
                focusedEvidenceID: evidenceID
            )
        case .settings:
            FoundationSettingsRouteView()
        case .taskDetail(let id):
            if let planDependencies {
                FoundationTaskRouteView(
                    id: id,
                    dependencies: planDependencies,
                    router: runtime.router
                )
            } else {
                FoundationPlanRollbackRouteView(router: runtime.router)
            }
        case .habitDetail(let id):
            FoundationHabitRouteView(id: id, repository: habitRuntimeReadRepository, router: runtime.router)
        case .habitBoard:
            HabitBoardScreen(
                viewModel: PresentationDependencyContainer.shared.makeHabitBoardViewModel(),
                presentationStyle: .pushed,
                onManageHabits: { runtime.router.push(.habitLibrary, in: .track) }
            )
        case .habitLibrary:
            SunriseHabitLibraryView(
                viewModel: PresentationDependencyContainer.shared.makeNewHabitLibraryViewModel(),
                presentationStyle: .pushed
            )
        case .trackerDetail(let id):
            if V2FeatureFlags.trackBehaviorFlagshipV1Enabled {
                FoundationTrackerRouteView(id: id, repository: phaseIIRepository)
            } else {
                LifeBoardBehaviorAreaRouteView(
                    repository: phaseIIRepository,
                    initialArea: .trackers
                )
            }
        case .careLibrary:
            LifeBoardBehaviorAreaRouteView(
                repository: phaseIIRepository,
                initialArea: .medication,
                onOpenHabitBoard: { runtime.router.push(.habitBoard, in: .track) },
                onOpenHealth: { runtime.router.push(.health, in: .track) }
            )
        case .health:
            LifeBoardHealthHubView(
                trackRepository: trackFoundationRepository,
                wellnessRepository: wellnessRepository,
                nutritionRepository: nutritionRepository
            )
        case .project(let id):
            if let planDependencies {
                FoundationProjectRouteView(
                    id: id,
                    dependencies: planDependencies,
                    router: runtime.router
                )
            } else {
                FoundationPlanRollbackRouteView(router: runtime.router)
            }
        case .routine(let id):
            if V2FeatureFlags.trackBehaviorFlagshipV1Enabled {
                FoundationRoutineRouteView(
                    id: id,
                    repository: trackFoundationRepository,
                    router: runtime.router
                )
            } else {
                LifeBoardBehaviorAreaRouteView(repository: phaseIIRepository)
            }
        case .goal(let id):
            if V2FeatureFlags.trackBehaviorFlagshipV1Enabled {
                FoundationGoalRouteView(
                    id: id,
                    repository: trackFoundationRepository,
                    sampleProvider: goalSampleProvider,
                    sourceRepository: ComposedTypedSourcePickerRepository(
                        planningProjection: planningRepository,
                        trackFoundation: trackFoundationRepository,
                        phaseII: phaseIIRepository,
                        habitRuntime: habitRuntimeReadRepository
                    ),
                    router: runtime.router
                )
            } else {
                LifeBoardBehaviorAreaRouteView(repository: phaseIIRepository)
            }
        case .journalDay(let id):
            FoundationJournalDayRouteView(id: id, repository: phaseIIRepository)
        case .journalSearch:
            LifeBoardJournalModuleView(
                repository: phaseIIRepository,
                initialSection: .library,
                router: runtime.router
            )
        case .weeklyReflection(let date):
            LifeBoardJournalModuleView(
                repository: phaseIIRepository,
                initialSection: .insights,
                reflectionWeekDate: date,
                router: runtime.router
            )
        case .notesLibrary(let destination):
            LifeBoardKnowledgeModuleView(
                repository: phaseIIRepository,
                initialDestination: destination
            )
        case .note(let id):
            LifeBoardKnowledgeModuleView(repository: phaseIIRepository, initialNoteID: id)
        case .knowledgeFolder(let id):
            LifeBoardKnowledgeModuleView(repository: phaseIIRepository, initialFolderID: id)
        case .focusSession(let id):
            if let planDependencies {
                FoundationFocusSessionRouteView(
                    sessionID: id,
                    dependencies: planDependencies,
                    router: runtime.router,
                    rescueRefreshGeneration: planRescueRefreshGeneration,
                    onOpenOverdueRescue: presentPlanOverdueRescue
                )
            } else {
                FoundationPlanRollbackRouteView(router: runtime.router)
            }
        case .dayClose(let date):
            // Two gates, both required. The flag hides the ritual; the
            // dependencies are what it is built from. Either being absent
            // restores the previous end-of-day experience, which is no ritual
            // at all — and nothing written while it was on becomes unreachable,
            // because everything it writes lives in Plan's own ledger.
            if V2FeatureFlags.dayCloseV1Enabled, let planDependencies {
                FoundationDayCloseRouteView(
                    date: date,
                    mode: .close,
                    dependencies: planDependencies,
                    router: runtime.router
                )
                .lifeBoardZoomDestination(sourceID: LifeBoardDayLoopTransition.close)
            } else {
                FoundationPlanRollbackRouteView(router: runtime.router)
            }
        case .dayOpen(let date):
            if V2FeatureFlags.dayCloseV1Enabled, let planDependencies {
                FoundationDayCloseRouteView(
                    date: date,
                    mode: .open,
                    dependencies: planDependencies,
                    router: runtime.router
                )
                .lifeBoardZoomDestination(sourceID: LifeBoardDayLoopTransition.open)
            } else {
                FoundationPlanRollbackRouteView(router: runtime.router)
            }
        }
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

    private func pathBinding(for destination: LifeBoardDestination) -> Binding<[AppRoute]> {
        Binding(
            get: { runtime.router.path(for: destination) },
            set: { runtime.router.setPath($0, for: destination) }
        )
    }

    private func presentPlanOverdueRescue(_ context: OverdueRescueLaunchContext) {
        compactCaptureState = CaptureOrbPresentationState()
        lifeThreadComposerIsFocused = false
        homeViewModel.launchOverdueRescue(context)
    }

    private func dismissPlanOverdueRescue() {
        homeViewModel.setEvaRescuePresented(false)
        planRescueRefreshGeneration &+= 1
    }

}

/// Capture chips rise in sequence from the composer's leading control so the
/// tray reads as the "+" unfolding rather than a row appearing at once.
/// Total stagger stays inside the control-morph budget.
private struct ComposerToolStagger: ViewModifier {
    let index: Int
    let reduceMotion: Bool

    private static let perChipDelay: Double = 0.028
    private static let maximumDelay: Double = 0.22

    @State private var appeared = false

    func body(content: Content) -> some View {
        content
            .opacity(appeared ? 1 : 0)
            .scaleEffect(appeared ? 1 : 0.82, anchor: .bottomLeading)
            .offset(y: appeared ? 0 : 12)
            .onAppear {
                guard reduceMotion == false else {
                    appeared = true
                    return
                }
                let delay = min(Double(index) * Self.perChipDelay, Self.maximumDelay)
                withAnimation(.spring(response: 0.34, dampingFraction: 0.78).delay(delay)) {
                    appeared = true
                }
            }
    }
}

/// Data-preserving rollback destination for the Phase 1 route graph.
///
/// Work created while the flagship was enabled remains in the canonical task
/// repositories and is therefore visible through the previous Home task
/// experience. No Phase 1 store is initialized from this route.
private struct FoundationPlanRollbackRouteView: View {
    let router: LifeBoardAppRouter

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "checklist")
                .font(LifeBoardFoundationTypography.screenTitle())
                .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                .frame(width: 62, height: 62)
                .background(
                    Color(LifeBoardColorTokens.foundationSurfaceSelected),
                    in: RoundedRectangle(cornerRadius: 22, style: .continuous)
                )
            VStack(spacing: 7) {
                Text("Your tasks are on Home")
                    .font(LifeBoardFoundationTypography.sectionTitle())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                Text("The daily planning workspace is currently turned off. Nothing has been removed or rewritten.")
                    .font(LifeBoardFoundationTypography.body())
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    .multilineTextAlignment(.center)
            }
            Button {
                router.select(.home)
            } label: {
                Text("Open Home")
                    .font(LifeBoardFoundationTypography.body().weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationSurfaceSolid))
                    .frame(minWidth: 132, minHeight: 44)
                    .padding(.horizontal, 12)
                    .background(
                        Color(LifeBoardColorTokens.inkPrimary),
                        in: Capsule(style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("plan.rollback.openHome")
        }
        .padding(28)
        .frame(maxWidth: 430)
        .lifeBoardPaperCard()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid).ignoresSafeArea())
        .navigationTitle("Plan")
        .accessibilityIdentifier("plan.rollback")
    }
}

private enum FoundationRouteLoadState<Value> {
    case loading
    case loaded(Value)
    case missing
    case failed(String)
}

/// Route host for the end-of-day ritual.
///
/// Owns the store so the ritual's state survives a scroll, a keyboard, and a
/// sheet, and rebuilds it only when the *day* changes — `task(id:)` on the day
/// key rather than on the raw `Date`, because a `Date` that ticks would discard
/// every decision made so far.
private struct FoundationDayCloseRouteView: View {
    let date: Date
    let mode: DayCloseMode
    let dependencies: PlanFeatureDependencies
    let router: LifeBoardAppRouter

    private var day: PlanningDay { PlanningDay(date: date) }

    /// Opening reports on yesterday; closing reports on itself.
    ///
    /// Without this the morning showed *today's* open tasks beneath "What
    /// carried" and "Last night's decisions" — a claim that was false on any day
    /// that was never closed.
    private var retrospectiveDay: PlanningDay? {
        guard mode == .open else { return nil }
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) else { return nil }
        return PlanningDay(date: yesterday)
    }

    var body: some View {
        LifeBoardDayCloseRoute(
            store: DayCloseStore(
                reader: dependencies.planningRepository,
                completions: nil,
                scenarios: DefaultPlanningScenarioCoordinator(
                    planning: dependencies.planningRepository,
                    mutations: dependencies.planningRepository
                ),
                day: day,
                retrospectiveDay: retrospectiveDay
            ),
            mode: mode,
            reflections: dependencies.reflectionNoteRepository,
            onFinished: { router.popToRoot(in: router.selectedDestination) }
        )
        .id(dayKey)
    }

    private var dayKey: String {
        "\(day.year)-\(day.month)-\(day.day)"
    }
}

private struct FoundationFocusSessionRouteView: View {
    let sessionID: UUID?
    let dependencies: PlanFeatureDependencies
    let router: LifeBoardAppRouter
    let rescueRefreshGeneration: Int
    let onOpenOverdueRescue: (OverdueRescueLaunchContext) -> Void
    @State private var state: FoundationRouteLoadState<FocusSessionV2> = .loading

    private var repository: CoreDataPlanningRepository {
        dependencies.planningRepository
    }

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Opening focus session…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .loaded(session) where session.state == .running || session.state == .paused:
                LifeBoardPlanRootView(
                    dependencies: dependencies,
                    initialLens: .day,
                    rescueRefreshGeneration: rescueRefreshGeneration,
                    onOpenFocus: { _ in },
                    onAskEva: { router.select(.eva) },
                    onOpenOverdueRescue: onOpenOverdueRescue,
                    onOpenTask: { router.push(.taskDetail($0), in: .plan) },
                    onOpenProject: { router.push(.project($0), in: .plan) }
                )
                .accessibilityIdentifier("focus.session.\(session.id.uuidString)")
            case let .loaded(session):
                focusUnavailable(
                    title: "Focus session ended",
                    detail: "This session ended \(session.endedAt?.formatted(date: .abbreviated, time: .shortened) ?? "earlier"). Its history remains available in Plan."
                )
            case .missing:
                focusUnavailable(
                    title: "Focus session not found",
                    detail: "It may have been removed on another device or the link may be out of date. No replacement session was opened."
                )
            case let .failed(message):
                focusUnavailable(title: "Focus could not be opened", detail: message)
            }
        }
        .navigationTitle("Focus")
        .task(id: sessionID) { await load() }
    }

    private func focusUnavailable(title: String, detail: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: "timer")
        } description: {
            Text(detail)
        } actions: {
            Button("Open Plan") { router.popToRoot(in: .plan) }
                .buttonStyle(.borderedProminent)
        }
    }

    private func load() async {
        guard let sessionID else {
            do {
                if let active = try await repository.activeSession() { state = .loaded(active) }
                else { state = .missing }
            } catch { state = .failed(error.localizedDescription) }
            return
        }
        do {
            state = try await repository.session(id: sessionID).map(FoundationRouteLoadState.loaded) ?? .missing
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

private struct FoundationInsightsDestination: View {
    @State private var store: TrackFoundationStore
    @State private var lens: InsightsLens = .overview
    @State private var persistedPlanningEvents: [NormalizedLifeEvent] = []
    @State private var planningEvidenceError: String?
    @State private var dayLoopEvidenceReport: DayLoopEvidenceReport?
    @Environment(LifeBoardPresentationPreferences.self) private var preferences
    @Environment(\.lifeBoardAtmosphereIsHosted) private var atmosphereIsHosted
    let router: LifeBoardAppRouter
    private let planningRepository: CoreDataPlanningRepository?
    /// The record a deep link asked for. `.insightEvidence` carried a UUID that
    /// was discarded, so the route landed on a generic Insights screen and the
    /// user had to find the record again themselves.
    private let focusedEvidenceID: UUID?
    @State private var evidenceExpanded = false

    init(
        repository: CoreDataTrackFoundationRepository,
        phaseIIRepository: any LifeBoardPhaseIIRepository,
        planningRepository: CoreDataPlanningRepository?,
        habitProjectionService: (any TrackHabitProjectionService)?,
        goalSampleProvider: (any GoalSampleProvider)?,
        router: LifeBoardAppRouter,
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
        self.router = router
        self.focusedEvidenceID = focusedEvidenceID
        _lens = State(initialValue: initialLens)
        // A named record means the caller wants the evidence list, not the
        // interpretation, so the disclosure starts open.
        _evidenceExpanded = State(initialValue: focusedEvidenceID != nil)
    }

    private var authorizedEvents: [NormalizedLifeEvent] {
        SnapshotLifeEventProjectionRepository(events: store.snapshot.normalizedEvents + persistedPlanningEvents)
            .authorizedEvents(for: .insights, journalConsentGranted: false)
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
                LifeBoardScenicBackdrop(
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
                    LifeBoardLensPicker(
                        "Insights lens",
                        selection: $lens,
                        values: InsightsLens.allCases,
                        identifierPrefix: "insights.lens",
                        title: \.title,
                        identifier: \.rawValue
                    )

                    if let planningEvidenceError {
                        Label("Planning history is temporarily unavailable: \(planningEvidenceError)", systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if store.isLoading && events.isEmpty {
                        ProgressView("Reading today’s evidence…")
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else if events.isEmpty {
                        ContentUnavailableView(
                            "Nothing recorded yet",
                            systemImage: "sparkles",
                            description: Text("A check-in, routine, care event, or hydration log will appear here with its source.")
                        )
                        .frame(minHeight: 240)
                    } else {
                        insightContent
                    }
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 48)
            }
        }
        .background(Color.clear.ignoresSafeArea())
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEvidence() }
        .refreshable { await loadEvidence() }
        .accessibilityIdentifier("foundation.insights")
    }

    @ViewBuilder
    private var insightContent: some View {
        switch lens {
        case .overview:
            interpretationSurface
            Button {
                askEva()
            } label: {
                Label("Explore this with Eva", systemImage: "sparkles")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(LifeBoardColorTokens.foundationApricotAccent))
        case .trends:
            let resolved = interpretation
            VStack(alignment: .leading, spacing: 14) {
                Text("Recorded shape")
                    .font(.title2.weight(.semibold))

                // A real chart, with its prose equivalent always visible —
                // this lens used to be a list of per-domain row counts, which
                // is a tally, not a trend.
                if resolved.dailyCounts.count > 1 {
                    let chart = LifeBoardTrendChart(
                        points: resolved.dailyCounts,
                        tint: Color(LifeBoardColorTokens.foundationApricotAccent),
                        unit: "records"
                    )
                    chart.frame(height: 150)
                    Text(chart.textEquivalent)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("One day of history so far. A trend needs a few more.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()

                Text("By area")
                    .font(.headline)
                ForEach(sourceCounts, id: \.domain) { item in
                    HStack {
                        Text(item.domain.capitalized)
                        Spacer()
                        Text("\(item.count) \(item.count == 1 ? "record" : "records")")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised, cornerRadius: 22)
        case .review:
            VStack(alignment: .leading, spacing: 12) {
                Label("Reflection, not a report card", systemImage: "calendar.badge.clock")
                    .font(.title3.weight(.semibold))
                Text(reviewSummary)
                    .font(.body)
                    .foregroundStyle(.secondary)
                if let report = dayLoopEvidenceReport {
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 132), spacing: 10)],
                        spacing: 10
                    ) {
                        FoundationInsightMetric(value: "\(report.eligibleDays)", label: "Eligible days")
                        FoundationInsightMetric(value: "\(report.closes)", label: "Days closed")
                        FoundationInsightMetric(value: "\(report.opensBeforeEleven)", label: "Opened before 11")
                        FoundationInsightMetric(value: "\(report.daysWithBoth)", label: "Opened and closed")
                        FoundationInsightMetric(value: "\(report.reversals)", label: "Taken back")
                        FoundationInsightMetric(value: "\(report.knownProposalSignals)", label: "Known proposals")
                        FoundationInsightMetric(
                            value: report.uneditedShare?.formatted(.percent.precision(.fractionLength(0))) ?? "Unknown",
                            label: "Unedited proposal share"
                        )
                    }
                    Text("Proposal evidence is local and non-authoritative. Missing sidecars stay unknown; undone receipts stop counting.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Button("Open weekly review") {
                    router.push(.weeklyReview, in: .insights)
                }
                .buttonStyle(.bordered)
            }
            .padding(18)
            .lifeBoardClaySurface(.raised, cornerRadius: 22)
        }

        DisclosureGroup(isExpanded: $evidenceExpanded) {
            ScrollViewReader { proxy in
                VStack(alignment: .leading, spacing: 12) {
                    Text(evidenceCompletenessDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(events) { event in
                        FoundationEvidenceRow(event: event) { evidence in open(evidence) }
                            .id(event.sourceID)
                            .background {
                                if event.sourceID == focusedEvidenceID {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(LifeBoardColorTokens.foundationSurfaceSelected))
                                        .padding(.horizontal, -8)
                                }
                            }
                    }
                }
                .padding(.top, 12)
                .onAppear {
                    guard let focusedEvidenceID else { return }
                    // Land on the record the deep link named rather than the
                    // top of a long, undifferentiated evidence list.
                    withAnimation(.easeInOut(duration: 0.25)) {
                        proxy.scrollTo(focusedEvidenceID, anchor: .center)
                    }
                }
            }
        } label: {
            Label("Evidence", systemImage: "checkmark.shield")
                .font(.headline)
        }
        .padding(16)
        .lifeBoardClaySurface(.resting, cornerRadius: 20)
        .accessibilityIdentifier("insights.evidence")
    }

    private var interpretationSurface: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("What changed", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            Text(interpretationTitle)
                .font(.system(.title2, design: .rounded, weight: .bold))
            Text(recommendedAction)
                .font(.body)
                .foregroundStyle(.secondary)
            Label(evidenceCompletenessDescription, systemImage: "checkmark.shield")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 24)
        .accessibilityIdentifier("insights.interpretation")
    }

    /// Ranked by how consistently something is recorded, not how often. The
    /// previous headline picked whichever domain had the most rows, which
    /// always meant the chattiest tracker rather than the clearest signal.
    private var interpretation: InsightsInterpretation {
        InsightsInterpretationEngine().interpret(events: events)
    }

    private var interpretationTitle: String {
        interpretation.claim
    }

    private var recommendedAction: String {
        interpretation.recommendedAction
    }

    private var loopReview: DayLoopReview {
        DayLoopLedger.review(events: events)
    }

    /// What the loop did, in the loop's own vocabulary.
    ///
    /// Previously this counted records and domains — the same sentence whether
    /// you had closed fourteen days or dragged fourteen blocks around. The
    /// receipts now name themselves, so the lens can report the thing the
    /// person actually did.
    ///
    /// Reports and stops. No percentage, no score, no "you only closed 4 of
    /// 14": days that were not closed are days that were lived, and the review
    /// lens is not a place to be told otherwise.
    private var reviewSummary: String {
        let review = loopReview
        guard review.hasNoHistory == false else {
            // Nothing recorded is not zero days closed. It is no history.
            return "No days have been opened or closed yet. When you start closing days, what you did with them shows up here."
        }
        guard review.meetsFloor else {
            let days = review.recordedDays
            return "\(days) \(days == 1 ? "day" : "days") recorded so far — not yet enough to read as a pattern."
        }

        var parts: [String] = []
        if review.daysClosed > 0 {
            parts.append("closed \(review.daysClosed) \(review.daysClosed == 1 ? "day" : "days")")
        }
        if review.daysOpened > 0 {
            parts.append("began \(review.daysOpened) deliberately")
        }
        let opening = parts.isEmpty
            ? "You have \(review.recordedDays) days of loop history"
            : "You've \(parts.joined(separator: " and "))"

        var sentence = "\(opening)."
        if review.daysWithBoth > 0 {
            sentence += " \(review.daysWithBoth) had both a beginning and an end."
        }
        if review.reversals > 0 {
            // Named plainly: taking something back is a normal use of Undo, and
            // burying it would make the other numbers quietly wrong.
            sentence += " \(review.reversals) \(review.reversals == 1 ? "was" : "were") taken back."
        }
        return sentence + " Choose one win, one friction point, and one adjustment."
    }

    private var evidenceCompletenessDescription: String {
        guard let confidence else { return "Completeness is not available yet." }
        let formatted = confidence.formatted(.percent.precision(.fractionLength(0)))
        return "\(formatted) of these records are complete and current."
    }

    private func askEva() {
        let resolved = interpretation
        // Hand over the interpretation Insights actually made, not a generic
        // "help me understand this pattern" — Eva was being asked to re-derive
        // a claim the user had just read.
        let context = EvaEntryContext(
            origin: .insights,
            evidenceReferences: resolved.evidenceReferences,
            requestedAssistance: resolved.supportsClaim
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
        if let planningRepository {
            do {
                let records = try await planningRepository.fetchMutationReceipts(since: nil)
                let proposalSignals = (try? await DayOpenProposalSignalStore.shared.signals()) ?? []
                let sessions = try await planningRepository.sessions(since: nil)
                let focusCommands = try await planningRepository.commandReceipts(since: nil)
                let sessionsWithDurableCommands = Set(focusCommands.map(\.sessionID))
                persistedPlanningEvents = records.compactMap(Self.planningEvent)
                    + sessions.flatMap {
                        Self.focusEvents(
                            $0,
                            includesLegacyStateFallback: sessionsWithDurableCommands.contains($0.id) == false
                        )
                    }
                    + focusCommands.map(Self.focusCommandEvent)
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
    }

    fileprivate static func planningEvent(_ record: PlanningReceiptRecord) -> NormalizedLifeEvent? {
        guard record.state != .prepared else { return nil }
        let occurredAt = record.undoneAt ?? record.appliedAt ?? record.receipt.createdAt
        let reversed = record.state == .undone
        return NormalizedLifeEventProjector().event(
            sourceID: record.receipt.id,
            domain: "plan",
            // `source` used to be dropped here, so a day-close arrived at
            // Insights as a generic `mutation_applied` — indistinguishable from
            // dragging a block. Carrying it is what lets the review lens say
            // anything about the loop at all.
            kind: Self.planningEventKind(source: record.receipt.source, reversed: reversed),
            occurredAt: occurredAt,
            provenance: "Persisted LifeBoard planning receipt",
            evidenceDisplay: record.receipt.summary,
            receipt: .init(receiptID: record.receipt.id, summary: record.receipt.summary),
            reversal: reversed
                ? .reversed(receiptID: record.receipt.id)
                : .reversible(receiptID: record.receipt.id)
        )
    }

    /// Names the loop's own receipts so Insights can count days closed and
    /// opened rather than lumping them in with every plan edit.
    fileprivate static func planningEventKind(source: String, reversed: Bool) -> String {
        if source.hasPrefix(DayLoopLedger.closePrefix) {
            return reversed ? DayLoopLedger.EventKind.closeReversed : DayLoopLedger.EventKind.closed
        }
        if source.hasPrefix(DayLoopLedger.openPrefix) {
            return reversed ? DayLoopLedger.EventKind.openReversed : DayLoopLedger.EventKind.opened
        }
        return reversed ? "mutation_reversed" : "mutation_applied"
    }

    fileprivate static func focusEvents(
        _ session: FocusSessionV2,
        includesLegacyStateFallback: Bool
    ) -> [NormalizedLifeEvent] {
        let projector = NormalizedLifeEventProjector()
        var values = [projector.event(
            sourceID: session.id,
            domain: "focus",
            kind: "started",
            occurredAt: session.startedAt,
            numericValue: session.targetDuration,
            provenance: "Persisted LifeBoard Focus session",
            evidenceDisplay: "Focus session"
        )]
        if includesLegacyStateFallback, let endedAt = session.endedAt {
            values.append(projector.event(
                sourceID: session.id,
                domain: "focus",
                kind: "ended_\(session.outcome?.rawValue ?? "stopped")",
                occurredAt: endedAt,
                numericValue: session.focusedDuration(at: endedAt),
                provenance: "Persisted LifeBoard Focus completion",
                evidenceDisplay: "Focus completion",
                receipt: .init(receiptID: session.id, summary: "Focus \(session.outcome?.rawValue ?? "ended")")
            ))
        } else if includesLegacyStateFallback, session.state == .paused, let pausedAt = session.pausedAt {
            values.append(projector.event(
                sourceID: session.id,
                domain: "focus",
                kind: "paused",
                occurredAt: pausedAt,
                numericValue: session.focusedDuration(at: pausedAt),
                provenance: "Persisted LifeBoard Focus state",
                evidenceDisplay: "Paused Focus session"
            ))
        }
        return values
    }

    fileprivate static func focusCommandEvent(_ receipt: FocusCommandReceipt) -> NormalizedLifeEvent {
        let commandValues: (kind: String, summary: String) = switch receipt.kind {
        case .pause:
            ("paused", "Paused Focus session")
        case .resume:
            ("resumed", "Resumed Focus session")
        case .end(let outcome):
            ("ended_\(outcome.rawValue)", "Focus \(outcome.rawValue)")
        }
        let values: (kind: String, summary: String)
        if receipt.wasApplied {
            values = commandValues
        } else {
            values = (
                kind: "ignored_\(commandValues.kind)",
                summary: "Ignored duplicate or stale Focus command"
            )
        }
        return NormalizedLifeEventProjector().event(
            sourceID: receipt.sessionID,
            domain: "focus",
            kind: values.kind,
            occurredAt: receipt.occurredAt,
            numericValue: receipt.focusedDuration,
            provenance: "Persisted LifeBoard Focus command receipt",
            evidenceDisplay: values.summary,
            receipt: .init(receiptID: receipt.id, summary: values.summary)
        )
    }

    private func open(_ evidence: EvidenceReference) {
        let id = evidence.routeID ?? evidence.sourceID
        switch evidence.kind {
        case "habit": router.push(.habitDetail(id), in: .insights)
        case "tracker": router.push(.trackerDetail(id), in: .insights)
        // Hydration, sleep and mood have no detail route of their own; Track's
        // History lens is where those records actually live, so they open it
        // directly instead of dropping the user on Track's Today lens.
        case "hydration", "sleep", "mood": router.push(.trackHistory, in: .insights)
        case "routine": router.push(.routine(id), in: .insights)
        case "goal": router.push(.goal(id), in: .insights)
        case "journal": router.openProtectedJournalRoute(.journalDay(id), in: .insights)
        case "plan", "task": router.select(.plan)
        case "focus": router.push(.focusSession(id), in: .insights)
        default: router.push(.trackHistory, in: .insights)
        }
    }
}

private struct FoundationEvaDestination: View {
    @StateObject private var appManager: AppManager
    @StateObject private var activationCoordinator: EvaActivationCoordinator
    @State private var evidenceStore: TrackFoundationStore
    @State private var evidenceContext = EvaAuthorizedEvidenceContext.loading
    @State private var sharingPolicy: EvaEvidenceSharingPolicy
    private let planningRepository: CoreDataPlanningRepository?
    private let evidenceDefaults: UserDefaults
    let router: LifeBoardAppRouter

    init(
        repository: CoreDataTrackFoundationRepository,
        phaseIIRepository: any LifeBoardPhaseIIRepository,
        planningRepository: CoreDataPlanningRepository?,
        habitProjectionService: (any TrackHabitProjectionService)?,
        goalSampleProvider: (any GoalSampleProvider)?,
        router: LifeBoardAppRouter
    ) {
        let manager = AppManager()
        let defaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? .standard
        _appManager = StateObject(wrappedValue: manager)
        _activationCoordinator = StateObject(wrappedValue: EvaActivationCoordinator(appManager: manager))
        _evidenceStore = State(initialValue: TrackFoundationStore(
            repository: repository,
            phaseIIRepository: phaseIIRepository,
            goalSampleProvider: goalSampleProvider,
            habitProjectionService: habitProjectionService
        ))
        _sharingPolicy = State(initialValue: EvaEvidenceSharingPolicyPersistence.load(from: defaults))
        self.planningRepository = planningRepository
        self.evidenceDefaults = defaults
        self.router = router
    }

    var body: some View {
        LLMStoreContainerHost(
            onLoadingAppear: {
                EvaNavigationPerformanceTrace.markInteractive()
            }
        ) { container in
            AnyView(
                EvaActivationRootView(
                    coordinator: activationCoordinator,
                    onDismiss: { router.select(.home) },
                    onOpenTaskDetail: { router.push(.taskDetail($0.id), in: .eva) },
                    onOpenHabitDetail: { router.push(.habitDetail($0), in: .eva) }
                )
                .environmentObject(appManager)
                .environment(LLMRuntimeCoordinator.shared.evaluator)
                .environment(\.evaAuthorizedEvidenceContext, evidenceContext)
                .environment(\.evaEvidenceOpenAction, EvaEvidenceOpenAction(open: openEvidence))
                .modelContainer(container)
            )
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 10) {
                    Label("Private on-device context", systemImage: "lock.shield")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    Spacer(minLength: 8)
                    evidenceSharingMenu
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 44)
                .lifeBoardGlassSurface(cornerRadius: 18, interactive: true)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 4)
        }
        .navigationTitle("Eva")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("foundation.eva")
        .task { await loadAuthorizedEvidence() }
        .task {
            // The derived journal pipeline broadcasts after commits and
            // deletions; refresh Eva's authorized evidence live instead of
            // waiting for a manual pull.
            let updates = await JournalProjectionInvalidationHub.shared.updates()
            for await event in updates {
                guard case .projectionsInvalidated = event else { continue }
                await loadAuthorizedEvidence()
            }
        }
        .refreshable { await loadAuthorizedEvidence() }
        .onChange(of: sharingPolicy) { _, policy in
            do {
                try EvaEvidenceSharingPolicyPersistence.save(policy, to: evidenceDefaults)
                Task { await loadAuthorizedEvidence() }
            } catch {
                evidenceContext = EvaAuthorizedEvidenceContext(
                    availability: .failed,
                    failureMessage: "Evidence sharing preferences could not be saved."
                )
            }
        }
    }

    private var evidenceSharingMenu: some View {
        Menu {
            Toggle("Body signals", isOn: $sharingPolicy.permitsBody)
            Toggle("Mood check-ins", isOn: $sharingPolicy.permitsMood)
            Toggle("Medication and care", isOn: $sharingPolicy.permitsCare)
            Divider()
            Text("Journal sharing is managed in Journal Privacy")
        } label: {
            Label("Evidence", systemImage: "checkmark.shield")
                .font(.caption.weight(.semibold))
                .frame(minHeight: 44)
        }
        .accessibilityLabel("Eva evidence sharing")
        .accessibilityHint("Choose which sensitive LifeBoard evidence Eva may use")
    }

    private func loadAuthorizedEvidence() async {
        await evidenceStore.load()
        var rawEvents = evidenceStore.snapshot.normalizedEvents
        var planningFailure: String?

        if let planningRepository {
            do {
                async let records = planningRepository.fetchMutationReceipts(since: nil)
                async let sessions = planningRepository.sessions(since: nil)
                async let commands = planningRepository.commandReceipts(since: nil)
                let (resolvedRecords, resolvedSessions, resolvedCommands) = try await (records, sessions, commands)
                let sessionsWithDurableCommands = Set(resolvedCommands.map(\.sessionID))
                rawEvents += resolvedRecords.compactMap(FoundationInsightsDestination.planningEvent)
                    + resolvedSessions.flatMap {
                        FoundationInsightsDestination.focusEvents(
                            $0,
                            includesLegacyStateFallback: sessionsWithDurableCommands.contains($0.id) == false
                        )
                    }
                    + resolvedCommands.map(FoundationInsightsDestination.focusCommandEvent)
            } catch {
                planningFailure = error.localizedDescription
            }
        }

        var effectiveSharingPolicy = sharingPolicy
        effectiveSharingPolicy.permitsJournal = JournalPrivacyPolicyPersistence
            .load(from: evidenceDefaults)
            .permitsJournalEvidenceForEva
        let projected = SnapshotLifeEventProjectionRepository(events: rawEvents)
            .authorizedEvents(for: .eva, sharingPolicy: effectiveSharingPolicy)
        let projectedIDs = Set(projected.map(\.id))
        let withheld = rawEvents
            .filter { projectedIDs.contains($0.id) == false }
            .map(\.domain)

        let failures = [evidenceStore.errorMessage, planningFailure].compactMap { $0 }
        if projected.isEmpty, let failure = failures.first {
            evidenceContext = EvaAuthorizedEvidenceContext(
                availability: .failed,
                withheldDomains: withheld,
                failureMessage: failure
            )
        } else {
            evidenceContext = EvaAuthorizedEvidenceContext(
                availability: .ready,
                events: projected,
                withheldDomains: withheld,
                failureMessage: failures.first
            )
        }
    }

    private func openEvidence(_ evidence: EvidenceReference) {
        let id = evidence.routeID ?? evidence.sourceID
        switch evidence.kind {
        case "habit": router.push(.habitDetail(id), in: .eva)
        case "tracker": router.push(.trackerDetail(id), in: .eva)
        case "routine": router.push(.routine(id), in: .eva)
        case "goal": router.push(.goal(id), in: .eva)
        case "journal": router.openProtectedJournalRoute(.journalDay(id), in: .eva)
        case "focus": router.push(.focusSession(id), in: .eva)
        case "plan", "task": router.select(.plan)
        case "hydration", "mood", "sleep", "medication", "care": router.select(.track)
        default: router.select(.track)
        }
    }
}

private struct FoundationInsightMetric: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value).font(.title2.weight(.bold)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary).lineLimit(2)
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(13)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(0.86), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct FoundationEvidenceRow: View {
    let event: NormalizedLifeEvent
    let onOpenEvidence: (EvidenceReference) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "checkmark.shield")
                .foregroundStyle(Color(LifeBoardColorTokens.foundationFocusRing))
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(event.kind.replacingOccurrences(of: "_", with: " ").capitalized)
                    .font(.headline)
                Text(event.provenance)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(event.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if event.evidence.isEmpty == false {
                    HStack(spacing: 6) {
                        ForEach(event.evidence, id: \.self) { evidence in
                            Button(evidence.display) { onOpenEvidence(evidence) }
                                .font(.caption2.weight(.semibold))
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                        }
                    }
                }
            }
            Spacer(minLength: 8)
            if let value = event.numericValue { Text(value.formatted()).font(.headline.monospacedDigit()) }
        }
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Divider().opacity(0.55) }
        .accessibilityElement(children: .contain)
    }
}

private struct FoundationInteractiveGlassModifier: ViewModifier {
    let isEnabled: Bool
    let cornerRadius: CGFloat

    @ViewBuilder
    func body(content: Content) -> some View {
        if isEnabled {
            content.lifeBoardSystemGlass(
                .regular,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                interactive: true
            )
        } else {
            content
        }
    }
}

/// The Life OS shell's Settings destination.
///
/// This route used to be a ~40 line `Form` with three pickers, while the real
/// `SettingsRootView` — profile, notifications, quiet hours, rituals, calendar,
/// Life Management, assistant and account controls — was reachable *only* from
/// the legacy UIKit home. Anyone running the Life OS shell simply could not get
/// to most of the app's settings. The full screen is now the destination, with
/// the shell-owned atmosphere controls pushed from a row inside it.
private struct FoundationSettingsRouteView: View {
    @Environment(LifeBoardPresentationPreferences.self) private var preferences
    @StateObject private var viewModel = SettingsViewModel(
        calendarIntegrationService: PresentationDependencyContainer.shared
            .coordinator
            .calendarIntegrationService
    )
    @State private var showsAppearance = false

    var body: some View {
        SettingsRootView(viewModel: viewModel)
            .navigationTitle("Settings")
            .accessibilityIdentifier("foundation.settings")
            .onAppear {
                viewModel.onNavigateToAppearance = { showsAppearance = true }
                viewModel.reload()
            }
            .navigationDestination(isPresented: $showsAppearance) {
                FoundationAppearanceSettingsView()
            }
    }
}

private struct FoundationAppearanceSettingsView: View {
    @Environment(LifeBoardPresentationPreferences.self) private var preferences

    var body: some View {
        @Bindable var preferences = preferences
        Form {
            Section("Atmosphere") {
                Picker("Daypart", selection: $preferences.daypartSelection) {
                    ForEach(DaypartSelection.allCases, id: \.self) { selection in
                        Label(selection.title, systemImage: selection.systemImage).tag(selection)
                    }
                }
                Picker("Comfort", selection: $preferences.comfortProfile) {
                    ForEach(LifeBoardComfortProfile.allCases, id: \.self) { profile in
                        Text(profile.title).tag(profile)
                    }
                }
                Picker("Rendering", selection: $preferences.renderingTier) {
                    ForEach(AmbientRenderingTier.allCases, id: \.self) { tier in
                        Text(tier.title).tag(tier)
                    }
                }
            }
            Section("Privacy") {
                Label("Journal evidence stays off until you allow it", systemImage: "lock.shield")
                Label("Sensitive media uses protected local storage", systemImage: "externaldrive.badge.lock")
            }
            Section("About") {
                NavigationLink {
                    FoundationThirdPartyNoticesView()
                } label: {
                    Label("Third-party notices", systemImage: "doc.text")
                }
                .accessibilityIdentifier("foundation.settings.third-party-notices")
            }
        }
        .navigationTitle("Appearance & motion")
        .accessibilityIdentifier("foundation.settings.appearance")
    }
}

private struct FoundationThirdPartyNoticesView: View {
    private let notice: String = {
        guard let url = Bundle.main.url(forResource: "SwiftUI-Animations-NOTICE", withExtension: "txt"),
              let value = try? String(contentsOf: url, encoding: .utf8) else {
            return "The bundled third-party notice could not be loaded."
        }
        return value
    }()

    var body: some View {
        ScrollView {
            Text(notice)
                .font(.footnote.monospaced())
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
        }
        .navigationTitle("Third-party notices")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("foundation.third-party-notices")
    }
}

struct FoundationTaskRouteView: View {
    let id: UUID
    let dependencies: PlanFeatureDependencies
    let router: LifeBoardAppRouter
    @State private var store: TaskEditorStore
    @State private var confirmsDelete = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(id: UUID, dependencies: PlanFeatureDependencies, router: LifeBoardAppRouter) {
        self.id = id
        self.dependencies = dependencies
        self.router = router
        _store = State(initialValue: TaskEditorStore(taskID: id, dependencies: dependencies))
    }

    var body: some View {
        Group {
            switch store.loadState {
            case .loading:
                ProgressView("Opening task…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .missing:
                ContentUnavailableView(
                    "Task not found",
                    systemImage: "checkmark.circle.badge.questionmark",
                    description: Text("It may have been removed on another device.")
                )
            case .failed(let message):
                ContentUnavailableView {
                    Label("Task could not be opened", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { Task { await store.load() } }
                }
            case .ready:
                editor
            }
        }
        .navigationTitle("Task")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button("Open in Plan", systemImage: "calendar") { router.select(.plan) }
                    Button("Archive", systemImage: "archivebox") {
                        Task {
                            await store.archive()
                            if case .saved = store.mutationState { router.pop() }
                        }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        confirmsDelete = true
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Task actions")
            }
        }
        .task(id: id) { await load() }
        .safeAreaInset(edge: .bottom) {
            if store.loadState == .ready {
                VStack(spacing: 8) {
                    LifeBoardCommitControl(
                        title: "Save task",
                        runningTitle: "Saving task",
                        successTitle: "Task saved",
                        phase: store.commitPhase,
                        isEnabled: store.hasUnsavedChanges || {
                            if case .failed = store.mutationState { return true }
                            return false
                        }()
                    ) {
                        Task { _ = await store.save() }
                    }
                    .accessibilityIdentifier("task.editor.save")

                    if let receipt = store.activeReceipt {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
                            Text("Task updated")
                                .font(.subheadline.weight(.semibold))
                            Spacer()
                            Button("Undo") { Task { await store.undo() } }
                                .font(.subheadline.weight(.bold))
                        }
                        .padding(.horizontal, 16)
                        .frame(minHeight: 52)
                        .background(.regularMaterial, in: Capsule())
                        .transition(
                            reduceMotion
                                ? .opacity
                                : .asymmetric(
                                    insertion: .scale(scale: 0.92, anchor: .bottom).combined(with: .opacity),
                                    removal: .opacity
                                )
                        )
                        .animation(LifeBoardAnimation.contentInsertion, value: receipt.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
            }
        }
        .confirmationDialog(
            "Delete this task?",
            isPresented: $confirmsDelete,
            titleVisibility: .visible
        ) {
            Button("Delete task", role: .destructive) {
                Task {
                    await store.delete()
                    if case .saved = store.mutationState { router.pop() }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The task is removed from every task view. The receipt can restore it without rebuilding a second task.")
        }
    }

    private var editor: some View {
        @Bindable var editor = store
        return ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    TextField("What needs doing?", text: $editor.draft.title, axis: .vertical)
                        .font(.title2.weight(.semibold))
                        .textInputAutocapitalization(.sentences)
                        .accessibilityIdentifier("task.editor.title")
                    TextField(
                        "Notes, links, or the useful context future-you will need",
                        text: Binding(
                            get: { editor.draft.details ?? "" },
                            set: { editor.draft.details = $0.isEmpty ? nil : $0 }
                        ),
                        axis: .vertical
                    )
                    .lineLimit(3...10)
                    .accessibilityIdentifier("task.editor.notes")
                }
                .taskEditorSurface()

                VStack(alignment: .leading, spacing: 16) {
                    taskEditorHeader("Shape the work", symbol: "slider.horizontal.3")
                    Picker("Project", selection: $editor.draft.projectID) {
                        ForEach(editor.projects, id: \.id) { project in
                            Text(project.name).tag(project.id)
                        }
                    }
                    .onChange(of: editor.draft.projectID) {
                        editor.draft.projectName = editor.projects.first {
                            $0.id == editor.draft.projectID
                        }?.name
                        if editor.sections.contains(where: {
                            $0.id == editor.draft.sectionID
                                && $0.projectID == editor.draft.projectID
                        }) == false {
                            editor.draft.sectionID = nil
                        }
                    }
                    Picker(
                        "Section",
                        selection: Binding(
                            get: { editor.draft.sectionID },
                            set: { editor.draft.sectionID = $0 }
                        )
                    ) {
                        Text("No section").tag(UUID?.none)
                        ForEach(
                            editor.sections.filter { $0.projectID == editor.draft.projectID },
                            id: \.id
                        ) { section in
                            Text(section.name).tag(Optional(section.id))
                        }
                    }
                    .disabled(
                        editor.sections.contains { $0.projectID == editor.draft.projectID } == false
                    )
                    .accessibilityIdentifier("task.editor.section")
                    Picker(
                        "Life area",
                        selection: Binding(
                            get: { editor.draft.lifeAreaID },
                            set: { editor.draft.lifeAreaID = $0 }
                        )
                    ) {
                        Text("No life area").tag(UUID?.none)
                        ForEach(editor.lifeAreas, id: \.id) { area in
                            Text(area.name).tag(Optional(area.id))
                        }
                    }
                    .disabled(editor.lifeAreas.isEmpty)
                    .accessibilityIdentifier("task.editor.life-area")
                    LabeledContent("Priority") {
                        Picker("Priority", selection: $editor.draft.priority) {
                            ForEach(TaskPriority.allCases, id: \.self) {
                                Text($0.displayName).tag($0)
                            }
                        }
                        .labelsHidden()
                    }
                    LabeledContent("Energy") {
                        Picker("Energy", selection: $editor.draft.energy) {
                            ForEach(TaskEnergy.allCases, id: \.self) {
                                Text($0.rawValue.capitalized).tag($0)
                            }
                        }
                        .labelsHidden()
                    }
                    LabeledContent("Context") {
                        Picker("Context", selection: $editor.draft.context) {
                            ForEach(TaskContext.allCases, id: \.self) {
                                Text($0.rawValue.capitalized).tag($0)
                            }
                        }
                        .labelsHidden()
                    }
                    estimateControl(editor: $editor)
                }
                .taskEditorSurface()

                dateAndPlanning(editor: $editor)
                recurrence(editor: $editor)
                tags(editor: $editor)
                subtasks(editor: $editor)
                dependencies(editor: $editor)

                Toggle(isOn: Binding(
                    get: { editor.draft.isComplete },
                    set: {
                        editor.draft.isComplete = $0
                        editor.draft.dateCompleted = $0 ? Date() : nil
                    }
                )) {
                    Label(
                        editor.draft.isComplete ? "Completed" : "Mark complete",
                        systemImage: editor.draft.isComplete ? "checkmark.circle.fill" : "circle"
                    )
                    .font(.headline)
                }
                .tint(Color(LifeBoardColorTokens.foundationSageAccent))
                .taskEditorSurface()

                if case .failed(let message) = store.mutationState {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .font(.footnote)
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationDanger))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .taskEditorSurface()
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .padding(.bottom, 70)
        }
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid).ignoresSafeArea())
    }

    private func dateAndPlanning(editor: Bindable<TaskEditorStore>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            taskEditorHeader("Place it gently", symbol: "calendar")
            optionalDate(
                "Deadline",
                value: Binding(
                    get: { editor.wrappedValue.draft.dueDate },
                    set: { editor.wrappedValue.draft.dueDate = $0 }
                )
            )
            optionalPlanningDay(
                "Start day",
                value: Binding(
                    get: { editor.wrappedValue.planning.startDay },
                    set: { editor.wrappedValue.planning.startDay = $0 }
                )
            )
            optionalPlanningDay(
                "Planned day",
                value: Binding(
                    get: { editor.wrappedValue.planning.planningDay },
                    set: { editor.wrappedValue.planning.planningDay = $0 }
                )
            )
            optionalDate(
                "Scheduled start",
                value: Binding(
                    get: { editor.wrappedValue.draft.scheduledStartAt },
                    set: { newValue in
                        editor.wrappedValue.draft.scheduledStartAt = newValue
                        if let newValue, editor.wrappedValue.draft.scheduledEndAt == nil {
                            editor.wrappedValue.draft.scheduledEndAt = newValue.addingTimeInterval(
                                editor.wrappedValue.draft.estimatedDuration ?? 30 * 60
                            )
                        }
                    }
                ),
                components: [.date, .hourAndMinute]
            )
            optionalDate(
                "Scheduled end",
                value: Binding(
                    get: { editor.wrappedValue.draft.scheduledEndAt },
                    set: { editor.wrappedValue.draft.scheduledEndAt = $0 }
                ),
                components: [.date, .hourAndMinute]
            )
            if let start = editor.wrappedValue.draft.scheduledStartAt,
               let end = editor.wrappedValue.draft.scheduledEndAt,
               end <= start {
                Label(
                    "Scheduled end must be after the start.",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.foundationDanger))
                .accessibilityIdentifier("task.editor.schedule-error")
            }
        }
        .taskEditorSurface()
    }

    private func recurrence(editor: Bindable<TaskEditorStore>) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            taskEditorHeader("Rhythm", symbol: "repeat")
            Picker(
                "Repeat",
                selection: Binding(
                    get: { recurrenceChoice(editor.wrappedValue.draft.repeatPattern) },
                    set: { editor.wrappedValue.draft.repeatPattern = repeatPattern($0) }
                )
            ) {
                Text("Never").tag(0)
                Text("Daily").tag(1)
                Text("Weekdays").tag(2)
                Text("Weekly").tag(3)
                Text("Every two weeks").tag(4)
                Text("Monthly on a date").tag(5)
                Text("Monthly by weekday").tag(6)
                Text("Yearly").tag(7)
                Text("Custom interval").tag(8)
            }
            if editor.wrappedValue.draft.repeatPattern != nil {
                recurrenceDetails(editor: editor)
                Picker("Anchor", selection: editor.draft.recurrenceAnchor) {
                    Text("Scheduled date").tag(TaskRecurrenceRule.Anchor.scheduledDate)
                    Text("When completed").tag(TaskRecurrenceRule.Anchor.completionDate)
                }
                .pickerStyle(.segmented)
                Text(
                    editor.wrappedValue.draft.recurrenceAnchor == .completionDate
                        ? "The next occurrence begins from the day you finish this one."
                        : "Future occurrences stay on their intended calendar rhythm."
                )
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
        }
        .taskEditorSurface()
    }

    @ViewBuilder
    private func recurrenceDetails(editor: Bindable<TaskEditorStore>) -> some View {
        switch editor.wrappedValue.draft.repeatPattern {
        case .weekly(let days):
            weekdayButtons(days: days) {
                editor.wrappedValue.draft.repeatPattern = .weekly($0)
            }
        case .biweekly(let days):
            weekdayButtons(days: days) {
                editor.wrappedValue.draft.repeatPattern = .biweekly($0)
            }
        case .monthly(.onDate(let day)):
            Stepper(
                "Day \(day) of each month",
                value: Binding(
                    get: { day },
                    set: {
                        editor.wrappedValue.draft.repeatPattern = .monthly(
                            .onDate(min(max(1, $0), 31))
                        )
                    }
                ),
                in: 1...31
            )
        case .monthly(.onWeekday(let week, let weekday)):
            Picker(
                "Week",
                selection: Binding(
                    get: { week },
                    set: {
                        editor.wrappedValue.draft.repeatPattern = .monthly(
                            .onWeekday(weekOfMonth: $0, dayOfWeek: weekday)
                        )
                    }
                )
            ) {
                Text("First").tag(1)
                Text("Second").tag(2)
                Text("Third").tag(3)
                Text("Fourth").tag(4)
                Text("Fifth").tag(5)
            }
            Picker(
                "Weekday",
                selection: Binding(
                    get: { weekday },
                    set: {
                        editor.wrappedValue.draft.repeatPattern = .monthly(
                            .onWeekday(weekOfMonth: week, dayOfWeek: $0)
                        )
                    }
                )
            ) {
                ForEach(Array(Calendar.current.weekdaySymbols.enumerated()), id: \.offset) {
                    index, name in
                    Text(name).tag(index + 1)
                }
            }
        case .monthly(.lastWeekday(let weekday)):
            Picker(
                "Last weekday",
                selection: Binding(
                    get: { weekday },
                    set: {
                        editor.wrappedValue.draft.repeatPattern = .monthly(
                            .lastWeekday(dayOfWeek: $0)
                        )
                    }
                )
            ) {
                ForEach(Array(Calendar.current.weekdaySymbols.enumerated()), id: \.offset) {
                    index, name in
                    Text(name).tag(index + 1)
                }
            }
        case .yearly(let pattern):
            DatePicker(
                "Repeat date",
                selection: Binding(
                    get: { recurrenceYearlyDate(pattern) },
                    set: {
                        let components = Calendar.current.dateComponents(
                            [.month, .day],
                            from: $0
                        )
                        editor.wrappedValue.draft.repeatPattern = .yearly(
                            .onDate(
                                month: components.month ?? 1,
                                day: components.day ?? 1
                            )
                        )
                    }
                ),
                displayedComponents: .date
            )
        case .custom(let pattern):
            Stepper(
                "Every \(pattern.intervalDays) days",
                value: Binding(
                    get: { pattern.intervalDays },
                    set: {
                        editor.wrappedValue.draft.repeatPattern = .custom(
                            .init(
                                intervalDays: min(max(1, $0), 365),
                                endDate: pattern.endDate,
                                maxOccurrences: pattern.maxOccurrences
                            )
                        )
                    }
                ),
                in: 1...365
            )
            optionalDate(
                "End repeat",
                value: Binding(
                    get: { pattern.endDate },
                    set: {
                        editor.wrappedValue.draft.repeatPattern = .custom(
                            .init(
                                intervalDays: pattern.intervalDays,
                                endDate: $0,
                                maxOccurrences: pattern.maxOccurrences
                            )
                        )
                    }
                )
            )
            Toggle(
                "Limit occurrences",
                isOn: Binding(
                    get: { pattern.maxOccurrences != nil },
                    set: {
                        editor.wrappedValue.draft.repeatPattern = .custom(
                            .init(
                                intervalDays: pattern.intervalDays,
                                endDate: pattern.endDate,
                                maxOccurrences: $0 ? (pattern.maxOccurrences ?? 10) : nil
                            )
                        )
                    }
                )
            )
            if let maximum = pattern.maxOccurrences {
                Stepper(
                    "Stop after \(maximum)",
                    value: Binding(
                        get: { maximum },
                        set: {
                            editor.wrappedValue.draft.repeatPattern = .custom(
                                .init(
                                    intervalDays: pattern.intervalDays,
                                    endDate: pattern.endDate,
                                    maxOccurrences: min(max(1, $0), 999)
                                )
                            )
                        }
                    ),
                    in: 1...999
                )
            }
        case .daily, .weekdays, nil:
            EmptyView()
        }
    }

    private func weekdayButtons(
        days: TaskRepeatPattern.DaysOfWeek,
        onChange: @escaping (TaskRepeatPattern.DaysOfWeek) -> Void
    ) -> some View {
        let values: [(String, TaskRepeatPattern.DaysOfWeek)] = [
            ("S", .sunday),
            ("M", .monday),
            ("T", .tuesday),
            ("W", .wednesday),
            ("T", .thursday),
            ("F", .friday),
            ("S", .saturday)
        ]
        return HStack(spacing: 6) {
            ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                let selected = days.contains(value.1)
                Button {
                    var updated = days
                    if selected {
                        updated.remove(value.1)
                    } else {
                        updated.insert(value.1)
                    }
                    guard updated.isEmpty == false else { return }
                    onChange(updated)
                } label: {
                    Text(value.0)
                        .font(.caption.weight(.bold))
                        .frame(width: 36, height: 44)
                        .background(
                            selected
                                ? Color(LifeBoardColorTokens.foundationSageAccent)
                                : Color(LifeBoardColorTokens.foundationSurfaceSolid),
                            in: Capsule()
                        )
                        .foregroundStyle(
                            selected
                                ? Color(LifeBoardColorTokens.inkPrimary)
                                : Color(LifeBoardColorTokens.inkSecondary)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Calendar.current.weekdaySymbols[index])
                .accessibilityAddTraits(selected ? .isSelected : [])
            }
        }
    }

    private func tags(editor: Bindable<TaskEditorStore>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            taskEditorHeader("Tags", symbol: "tag")
            if editor.wrappedValue.tags.isEmpty {
                Text("No tags yet")
                    .font(.subheadline)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 104), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    ForEach(editor.wrappedValue.tags, id: \.id) { tag in
                        let selected = editor.wrappedValue.draft.tagIDs.contains(tag.id)
                        Button {
                            if selected {
                                editor.wrappedValue.draft.tagIDs.removeAll { $0 == tag.id }
                            } else {
                                editor.wrappedValue.draft.tagIDs.append(tag.id)
                            }
                        } label: {
                            Label(tag.name, systemImage: selected ? "checkmark" : "plus")
                                .font(.caption.weight(.semibold))
                                .frame(minHeight: 32)
                        }
                        .buttonStyle(.bordered)
                        .tint(selected
                            ? Color(LifeBoardColorTokens.foundationSageAccent)
                            : Color(LifeBoardColorTokens.inkSecondary))
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
        }
        .taskEditorSurface()
    }

    private func subtasks(editor: Bindable<TaskEditorStore>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                taskEditorHeader("Subtasks", symbol: "list.bullet.indent")
                Spacer()
                Menu {
                    let available = editor.wrappedValue.taskCandidates.filter {
                        $0.parentTaskID == nil
                            && editor.wrappedValue.draft.subtasks.contains($0.id) == false
                    }
                    if available.isEmpty {
                        Text("No available tasks")
                    } else {
                        ForEach(available, id: \.id) { candidate in
                            Button(candidate.title) {
                                editor.wrappedValue.toggleSubtask(candidate.id)
                            }
                        }
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityIdentifier("task.editor.subtask.add")
            }

            if editor.wrappedValue.draft.subtasks.isEmpty {
                Text("Break this down by linking an existing task.")
                    .font(.subheadline)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            } else {
                ForEach(
                    Array(editor.wrappedValue.draft.subtasks.enumerated()),
                    id: \.element
                ) { index, subtaskID in
                    HStack(spacing: 8) {
                        Text(taskTitle(subtaskID, editor: editor.wrappedValue))
                            .font(.subheadline)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Button {
                            guard index > 0 else { return }
                            editor.wrappedValue.moveSubtask(
                                fromOffsets: IndexSet(integer: index),
                                toOffset: index - 1
                            )
                        } label: {
                            Image(systemName: "arrow.up")
                                .frame(width: 44, height: 44)
                        }
                        .disabled(index == 0)
                        .accessibilityLabel("Move subtask earlier")
                        Button {
                            guard index + 1 < editor.wrappedValue.draft.subtasks.count else {
                                return
                            }
                            editor.wrappedValue.moveSubtask(
                                fromOffsets: IndexSet(integer: index),
                                toOffset: index + 2
                            )
                        } label: {
                            Image(systemName: "arrow.down")
                                .frame(width: 44, height: 44)
                        }
                        .disabled(index + 1 == editor.wrappedValue.draft.subtasks.count)
                        .accessibilityLabel("Move subtask later")
                        Button(role: .destructive) {
                            editor.wrappedValue.toggleSubtask(subtaskID)
                        } label: {
                            Image(systemName: "minus.circle")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Remove subtask")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("task.editor.subtask.\(subtaskID.uuidString)")
                }
            }
        }
        .taskEditorSurface()
    }

    private func dependencies(editor: Bindable<TaskEditorStore>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                taskEditorHeader("Dependencies", symbol: "link")
                Spacer()
                Menu {
                    let linked = Set(
                        editor.wrappedValue.draft.dependencies.map(\.dependsOnTaskID)
                    )
                    let available = editor.wrappedValue.taskCandidates.filter {
                        linked.contains($0.id) == false
                    }
                    if available.isEmpty {
                        Text("No available tasks")
                    } else {
                        ForEach(available, id: \.id) { candidate in
                            Button(candidate.title) {
                                editor.wrappedValue.toggleDependency(on: candidate.id)
                            }
                        }
                    }
                } label: {
                    Label("Add", systemImage: "plus")
                        .frame(minWidth: 44, minHeight: 44)
                }
                .accessibilityIdentifier("task.editor.dependency.add")
            }

            if editor.wrappedValue.draft.dependencies.isEmpty {
                Text("Nothing else has to finish first.")
                    .font(.subheadline)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            } else {
                ForEach(editor.wrappedValue.draft.dependencies, id: \.id) { link in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(taskTitle(link.dependsOnTaskID, editor: editor.wrappedValue))
                                .font(.subheadline.weight(.medium))
                            Text(link.kind == .blocks ? "Must finish first" : "Related")
                                .font(.caption)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                        Spacer()
                        Menu {
                            ForEach(TaskDependencyKind.allCases, id: \.self) { kind in
                                Button(kind == .blocks ? "Must finish first" : "Related") {
                                    guard let index = editor.wrappedValue.draft.dependencies
                                        .firstIndex(where: { $0.id == link.id }) else {
                                        return
                                    }
                                    editor.wrappedValue.draft.dependencies[index].kind = kind
                                }
                            }
                            Button("Remove", role: .destructive) {
                                editor.wrappedValue.toggleDependency(on: link.dependsOnTaskID)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Dependency actions")
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier(
                        "task.editor.dependency.\(link.dependsOnTaskID.uuidString)"
                    )
                }
            }
        }
        .taskEditorSurface()
    }

    private func taskTitle(_ id: UUID, editor: TaskEditorStore) -> String {
        editor.taskCandidates.first(where: { $0.id == id })?.title ?? "Unavailable task"
    }

    private func estimateControl(editor: Bindable<TaskEditorStore>) -> some View {
        let minutes = Int((editor.wrappedValue.draft.estimatedDuration ?? 0) / 60)
        return HStack {
            Text("Estimate")
            Spacer()
            Button {
                editor.wrappedValue.draft.estimatedDuration = max(0, minutes - 5) == 0
                    ? nil
                    : TimeInterval(max(0, minutes - 5) * 60)
            } label: {
                Image(systemName: "minus")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Reduce estimate")
            Text(minutes == 0 ? "Not set" : "\(minutes) min")
                .font(.body.monospacedDigit())
                .frame(minWidth: 72)
            Button {
                editor.wrappedValue.draft.estimatedDuration = TimeInterval(max(5, minutes + 5) * 60)
            } label: {
                Image(systemName: "plus")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Increase estimate")
        }
    }

    private func optionalDate(
        _ title: String,
        value: Binding<Date?>,
        components: DatePickerComponents = .date
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: Binding(
                get: { value.wrappedValue != nil },
                set: { value.wrappedValue = $0 ? (value.wrappedValue ?? Date()) : nil }
            ))
            if value.wrappedValue != nil {
                DatePicker(
                    title,
                    selection: Binding(
                        get: { value.wrappedValue ?? Date() },
                        set: { value.wrappedValue = $0 }
                    ),
                    displayedComponents: components
                )
                .labelsHidden()
            }
        }
    }

    private func optionalPlanningDay(
        _ title: String,
        value: Binding<PlanningDay?>
    ) -> some View {
        optionalDate(
            title,
            value: Binding(
                get: { value.wrappedValue?.startDate() },
                set: { date in
                    value.wrappedValue = date.map { PlanningDay(date: $0) }
                }
            )
        )
    }

    private func taskEditorHeader(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol)
            .font(.headline)
            .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
    }

    private func recurrenceChoice(_ pattern: TaskRepeatPattern?) -> Int {
        switch pattern {
        case nil: 0
        case .daily: 1
        case .weekdays: 2
        case .weekly: 3
        case .biweekly: 4
        case .monthly(.onDate): 5
        case .monthly: 6
        case .yearly: 7
        case .custom: 8
        }
    }

    private func repeatPattern(_ choice: Int) -> TaskRepeatPattern? {
        let components = Calendar.current.dateComponents([.month, .day], from: Date())
        return switch choice {
        case 1: .daily
        case 2: .weekdays
        case 3: .weekly(.allDays)
        case 4: .biweekly(.allDays)
        case 5: .monthly(.onDate(Calendar.current.component(.day, from: Date())))
        case 6: .monthly(
            .onWeekday(
                weekOfMonth: max(
                    1,
                    Calendar.current.component(.weekOfMonth, from: Date())
                ),
                dayOfWeek: Calendar.current.component(.weekday, from: Date())
            )
        )
        case 7: .yearly(
            .onDate(month: components.month ?? 1, day: components.day ?? 1)
        )
        case 8: .custom(.init(intervalDays: 3))
        default: nil
        }
    }

    private func recurrenceYearlyDate(_ pattern: TaskRepeatPattern.YearlyPattern) -> Date {
        let month: Int
        let day: Int
        switch pattern {
        case let .onDate(valueMonth, valueDay):
            month = valueMonth
            day = valueDay
        case let .onWeekday(valueMonth, weekOfMonth, dayOfWeek):
            var components = DateComponents()
            components.year = Calendar.current.component(.year, from: Date())
            components.month = valueMonth
            components.weekOfMonth = weekOfMonth
            components.weekday = dayOfWeek
            return Calendar.current.date(from: components) ?? Date()
        }
        return Calendar.current.date(
            from: DateComponents(
                year: Calendar.current.component(.year, from: Date()),
                month: month,
                day: day
            )
        ) ?? Date()
    }

    private func load() async {
        await store.load()
    }
}

private extension View {
    func taskEditorSurface() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised, cornerRadius: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
            }
    }
}

private struct FoundationHabitRouteView: View {
    let id: UUID
    let repository: (any HabitRuntimeReadRepositoryProtocol)?
    let router: LifeBoardAppRouter
    @State private var state: FoundationRouteLoadState<HabitLibraryRow> = .loading

    var body: some View {
        FoundationEntityRouteScaffold(title: "Habit", systemImage: "repeat.circle", state: state) { habit in
            VStack(alignment: .leading, spacing: 16) {
                Text(habit.title).font(.title2.weight(.semibold))
                LabeledContent("Area", value: habit.lifeAreaName)
                LabeledContent("Current streak", value: "\(habit.currentStreak) days")
                LabeledContent("Best streak", value: "\(habit.bestStreak) days")
                Label(habit.isPaused ? "Paused" : "Active", systemImage: habit.isPaused ? "pause.circle" : "checkmark.circle")
                if let notes = habit.notes, notes.isEmpty == false { Text(notes).font(.body).foregroundStyle(.secondary) }
                Button("Open in Track", systemImage: "chart.bar.fill") { router.select(.track) }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(LifeBoardColorTokens.inkPrimary))
            }
        }
        .task(id: id) { await load() }
    }

    private func load() async {
        guard let repository else { state = .failed("Habit data is unavailable."); return }
        do {
            let row = try await withCheckedThrowingContinuation { continuation in
                repository.fetchHabitDetailSummary(habitID: id, includeArchived: true) { continuation.resume(with: $0) }
            }
            state = row.map(FoundationRouteLoadState.loaded) ?? .missing
        } catch { state = .failed(error.localizedDescription) }
    }
}

private struct FoundationTrackerRouteView: View {
    private struct Snapshot {
        let definition: LifeBoardTrackerDefinitionValue
        let entries: [LifeBoardTrackerEntryValue]
    }

    let id: UUID
    let repository: (any LifeBoardPhaseIIRepository)?
    @State private var state: FoundationRouteLoadState<Snapshot> = .loading

    var body: some View {
        FoundationEntityRouteScaffold(title: "Tracker", systemImage: "chart.bar.doc.horizontal", state: state) { snapshot in
            VStack(alignment: .leading, spacing: 16) {
                Text(snapshot.definition.title).font(.title2.weight(.semibold))
                LabeledContent("Type", value: snapshot.definition.kind.rawValue.capitalized)
                if let unit = snapshot.definition.unitLabel, unit.isEmpty == false {
                    LabeledContent("Unit", value: unit)
                }
                if let target = snapshot.definition.targetValue {
                    LabeledContent("Target", value: target.formatted())
                }
                if snapshot.entries.isEmpty {
                    ContentUnavailableView(
                        "No entries yet",
                        systemImage: "chart.xyaxis.line",
                        description: Text("Your first recorded value will appear here with its timestamp.")
                    )
                } else {
                    Text("Recent history").font(.headline)
                    ForEach(snapshot.entries.prefix(30)) { entry in
                        HStack {
                            Text(Self.value(entry, unit: snapshot.definition.unitLabel))
                            Spacer()
                            Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                .foregroundStyle(.secondary)
                        }
                        .frame(minHeight: 44)
                    }
                }
            }
        }
        .task(id: id) { await load() }
    }

    private func load() async {
        guard let repository else { state = .failed("Tracker data is unavailable."); return }
        do {
            async let definitions = repository.fetchTrackers()
            async let entries = repository.fetchTrackerEntries(trackerID: id)
            let (loadedDefinitions, loadedEntries) = try await (definitions, entries)
            guard let definition = loadedDefinitions.first(where: { $0.id == id }) else {
                state = .missing
                return
            }
            state = .loaded(Snapshot(definition: definition, entries: loadedEntries))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private static func value(_ entry: LifeBoardTrackerEntryValue, unit: String?) -> String {
        if let numeric = entry.numericValue {
            return [numeric.formatted(), unit].compactMap { $0 }.joined(separator: " ")
        }
        if let boolean = entry.booleanValue { return boolean ? "Done" : "Not done" }
        return "Recorded"
    }
}

private struct FoundationProjectRouteView: View {
    private enum DisplayMode: String, CaseIterable {
        case list = "List"
        case board = "Board"
    }

    let id: UUID
    let dependencies: PlanFeatureDependencies
    let router: LifeBoardAppRouter
    @State private var state: FoundationRouteLoadState<ProjectExecutionSnapshot> = .loading
    @State private var displayMode: DisplayMode = .list
    @State private var showsMilestoneComposer = false
    @State private var milestoneTitle = ""
    @State private var lastReceiptID: UUID?
    @State private var taskBatchReceipt: TaskBatchReceipt?
    @State private var archivedProjectSnapshot: Project?

    var body: some View {
        FoundationEntityRouteScaffold(title: "Project", systemImage: "folder", state: state) { tasks in
            VStack(alignment: .leading, spacing: 16) {
                projectHeader(tasks)
                Picker("Project view", selection: $displayMode) {
                    ForEach(DisplayMode.allCases, id: \.self) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("project.mode")

                milestones(tasks)

                if displayMode == .list {
                    taskList(tasks)
                } else {
                    taskBoard(tasks)
                }
            }
        }
        .task(id: id) { await load() }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button("Add milestone", systemImage: "flag") {
                        milestoneTitle = ""
                        showsMilestoneComposer = true
                    }
                    Button("Open in Plan", systemImage: "calendar") { router.select(.plan) }
                    Button("Archive project", systemImage: "archivebox") {
                        Task { await archiveProject() }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .accessibilityLabel("Project actions")
            }
        }
        .sheet(isPresented: $showsMilestoneComposer) {
            NavigationStack {
                Form {
                    TextField("Milestone", text: $milestoneTitle)
                    Text("A milestone marks progress; it never appears as a task in Today.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .navigationTitle("New Milestone")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { showsMilestoneComposer = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            Task { await saveMilestone() }
                        }
                        .disabled(milestoneTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if lastReceiptID != nil
                || taskBatchReceipt != nil
                || archivedProjectSnapshot != nil {
                HStack {
                    Text(projectReceiptMessage)
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Button("Undo") { Task { await undoLastProjectAction() } }
                        .font(.subheadline.weight(.bold))
                }
                .padding(.horizontal, 18)
                .frame(minHeight: 52)
                .background(.regularMaterial, in: Capsule())
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
    }

    private func load() async {
        state = .loading
        do {
            async let sections = fetchSections()
            async let milestones = dependencies.projectMilestoneRepository.milestones(projectID: id)
            guard let snapshot = try await dependencies.taskExecutionProjection.projectSnapshot(
                projectID: id,
                completedTaskCount: 0,
                sections: sections,
                milestones: milestones
            ) else {
                state = .missing
                return
            }
            state = .loaded(snapshot)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func projectHeader(_ snapshot: ProjectExecutionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.name)
                        .font(.title2.weight(.semibold))
                    Text(projectStatus(snapshot))
                        .font(.subheadline)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                Spacer()
                if let fraction = snapshot.completionFraction {
                    Text("\(Int((fraction * 100).rounded()))%")
                        .font(.title3.monospacedDigit().weight(.semibold))
                }
            }
            if let fraction = snapshot.completionFraction {
                ProgressView(value: fraction)
                    .tint(Color(LifeBoardColorTokens.foundationSageAccent))
            }
            if let next = snapshot.nextAction {
                Button {
                    router.push(.taskDetail(next.id), in: .plan)
                } label: {
                    HStack {
                        Label("Next: \(next.title)", systemImage: "arrow.right.circle.fill")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .taskEditorSurface()
    }

    private func milestones(_ snapshot: ProjectExecutionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Milestones", systemImage: "flag")
                    .font(.headline)
                Spacer()
                Button("Add", systemImage: "plus") {
                    milestoneTitle = ""
                    showsMilestoneComposer = true
                }
                .font(.subheadline.weight(.semibold))
            }
            if snapshot.milestones.isEmpty {
                Text("No milestones yet")
                    .font(.subheadline)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            } else {
                ForEach(snapshot.milestones) { milestone in
                    HStack(spacing: 10) {
                        Button {
                            Task { await toggleMilestone(milestone) }
                        } label: {
                            Image(systemName: milestone.isComplete ? "checkmark.circle.fill" : "circle")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            milestone.isComplete ? "Mark \(milestone.title) incomplete" : "Complete \(milestone.title)"
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(milestone.title)
                                .strikethrough(milestone.isComplete)
                            if let target = milestone.targetDay?.startDate() {
                                Text(target.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption)
                                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
        .taskEditorSurface()
    }

    private func taskList(_ snapshot: ProjectExecutionSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                snapshot.tasks.isEmpty ? "No open work" : "\(snapshot.tasks.count) open tasks",
                systemImage: "checklist"
            )
            .font(.headline)
            ForEach(orderedTasks(snapshot)) { task in
                taskRow(task, snapshot: snapshot)
            }
        }
        .taskEditorSurface()
    }

    private func taskBoard(_ snapshot: ProjectExecutionSnapshot) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(boardSections(snapshot), id: \.id) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.name)
                            .font(.headline)
                        let tasks = orderedTasks(snapshot).filter {
                            section.sortOrder == Int.max
                                ? snapshot.sectionIDByTaskID[$0.id] == nil
                                : snapshot.sectionIDByTaskID[$0.id] == section.id
                        }
                        if tasks.isEmpty {
                            Text("No tasks")
                                .font(.caption)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                                .frame(maxWidth: .infinity, minHeight: 70)
                        } else {
                            ForEach(tasks) { task in
                                taskRow(task, snapshot: snapshot)
                            }
                        }
                    }
                    .frame(width: 286, alignment: .topLeading)
                    .taskEditorSurface()
                }
            }
            .padding(.vertical, 2)
        }
        .accessibilityIdentifier("project.board")
    }

    private func taskRow(
        _ task: PlanningTaskSummary,
        snapshot: ProjectExecutionSnapshot
    ) -> some View {
        HStack(spacing: 10) {
            Button {
                router.push(.taskDetail(task.id), in: .plan)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: task.dependenciesReady ? "circle" : "link")
                    VStack(alignment: .leading, spacing: 3) {
                        Text(task.title)
                            .font(.body.weight(.medium))
                            .multilineTextAlignment(.leading)
                        Text(task.estimatedDuration.map(Self.duration) ?? "No estimate")
                            .font(.caption)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }
                    Spacer()
                }
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Menu {
                Button("Move earlier", systemImage: "arrow.up") {
                    Task { await move(task, offset: -1, snapshot: snapshot) }
                }
                Button("Move later", systemImage: "arrow.down") {
                    Task { await move(task, offset: 1, snapshot: snapshot) }
                }
                Section("Move to section") {
                    Button("Unsectioned") {
                        Task {
                            await moveToSection(task, sectionID: nil, snapshot: snapshot)
                        }
                    }
                    ForEach(snapshot.sections, id: \.id) { section in
                        Button(section.name) {
                            Task {
                                await moveToSection(
                                    task,
                                    sectionID: section.id,
                                    snapshot: snapshot
                                )
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Reorder \(task.title)")
        }
        .padding(.horizontal, 12)
        .background(
            Color(LifeBoardColorTokens.foundationSurfaceRecessed),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
    }

    private func fetchSections() async throws -> [LifeBoardProjectSection] {
        guard let repository = dependencies.sectionRepository else { return [] }
        return try await withCheckedThrowingContinuation { continuation in
            repository.fetchSections(projectID: id) { continuation.resume(with: $0) }
        }
    }

    private func saveMilestone() async {
        let title = milestoneTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else { return }
        do {
            let existing = try await dependencies.projectMilestoneRepository.milestones(projectID: id)
            try await dependencies.projectMilestoneRepository.saveMilestone(
                ProjectMilestone(projectID: id, title: title, sortOrder: existing.count)
            )
            showsMilestoneComposer = false
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func toggleMilestone(_ milestone: ProjectMilestone) async {
        var changed = milestone
        changed.completedAt = milestone.isComplete ? nil : Date()
        do {
            try await dependencies.projectMilestoneRepository.saveMilestone(changed)
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func move(
        _ task: PlanningTaskSummary,
        offset: Int,
        snapshot: ProjectExecutionSnapshot
    ) async {
        var ordered = orderedTasks(snapshot)
        guard
            let source = ordered.firstIndex(where: { $0.id == task.id }),
            ordered.indices.contains(source + offset)
        else { return }
        ordered.swapAt(source, source + offset)
        let mutations = ordered.enumerated().map { index, item in
            var after = item.metadata
            after.pinOrder = index
            after.updatedAt = Date()
            return PlanMutation.saveTaskMetadata(before: item.metadata, after: after)
        }
        do {
            let receipt = try await dependencies.planningRepository.prepare(
                .batch(mutations),
                source: "project.manual-order.\(id.uuidString)",
                summary: "Reordered \(snapshot.name)"
            )
            try await dependencies.planningRepository.apply(receiptID: receipt.id)
            lastReceiptID = receipt.id
            taskBatchReceipt = nil
            archivedProjectSnapshot = nil
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func archiveProject() async {
        do {
            let project = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Project?, any Error>) in
                dependencies.projectRepository.fetchProject(withId: id) {
                    continuation.resume(with: $0)
                }
            }
            guard var project else { return }
            archivedProjectSnapshot = project
            project.isArchived = true
            project.status = .onHold
            project.modifiedDate = Date()
            _ = try await withCheckedThrowingContinuation {
                (continuation: CheckedContinuation<Project, any Error>) in
                dependencies.projectRepository.updateProject(project) {
                    continuation.resume(with: $0)
                }
            }
            lastReceiptID = nil
            taskBatchReceipt = nil
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func undoLastProjectAction() async {
        do {
            if let taskBatchReceipt {
                try await dependencies.taskBatchMutationCoordinator.undo(taskBatchReceipt)
                self.taskBatchReceipt = nil
            }
            if let receiptID = lastReceiptID {
                try await dependencies.planningRepository.undo(receiptID: receiptID)
                lastReceiptID = nil
            }
            if let project = archivedProjectSnapshot {
                _ = try await withCheckedThrowingContinuation {
                    (continuation: CheckedContinuation<Project, any Error>) in
                    dependencies.projectRepository.updateProject(project) {
                        continuation.resume(with: $0)
                    }
                }
                archivedProjectSnapshot = nil
            }
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func moveToSection(
        _ task: PlanningTaskSummary,
        sectionID: UUID?,
        snapshot: ProjectExecutionSnapshot
    ) async {
        guard snapshot.sectionIDByTaskID[task.id] != sectionID else { return }
        do {
            taskBatchReceipt = try await dependencies.taskBatchMutationCoordinator.apply(
                TaskBatchMutationRequest(
                    taskIDs: [task.id],
                    mutation: .move(
                        projectID: id,
                        projectName: snapshot.name,
                        sectionID: sectionID
                    ),
                    source: "project.section-move.\(id.uuidString)"
                )
            )
            lastReceiptID = nil
            archivedProjectSnapshot = nil
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private var projectReceiptMessage: String {
        if archivedProjectSnapshot != nil { return "Project archived" }
        if taskBatchReceipt != nil { return "Task moved" }
        return "Project reordered"
    }

    private func orderedTasks(_ snapshot: ProjectExecutionSnapshot) -> [PlanningTaskSummary] {
        snapshot.tasks.sorted {
            ($0.metadata.pinOrder ?? Int.max, $0.id.uuidString)
                < ($1.metadata.pinOrder ?? Int.max, $1.id.uuidString)
        }
    }

    private func boardSections(_ snapshot: ProjectExecutionSnapshot) -> [LifeBoardProjectSection] {
        var sections = snapshot.sections.sorted { $0.sortOrder < $1.sortOrder }
        if snapshot.tasks.contains(where: { snapshot.sectionIDByTaskID[$0.id] == nil }) {
            sections.append(
                LifeBoardProjectSection(
                    id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
                    projectID: id,
                    name: "Unsectioned",
                    sortOrder: Int.max
                )
            )
        }
        return sections
    }

    private func projectStatus(_ snapshot: ProjectExecutionSnapshot) -> String {
        if snapshot.isArchived { return "Archived" }
        if snapshot.isBlocked { return "Blocked — no task is ready yet" }
        if let milestone = snapshot.nextMilestone { return "Next milestone: \(milestone.title)" }
        return snapshot.tasks.isEmpty ? "A quiet project" : "\(snapshot.completedTaskCount) completed"
    }

    private static func duration(_ value: TimeInterval) -> String {
        let minutes = max(0, Int(value / 60))
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours == 0 { return "\(remainder)m" }
        if remainder == 0 { return "\(hours)h" }
        return "\(hours)h \(remainder)m"
    }
}

private struct FoundationRoutineRouteView: View {
    private struct Snapshot {
        let definition: RoutineDefinition?
        let runs: [RoutineRun]
    }

    let id: UUID
    let repository: CoreDataTrackFoundationRepository?
    let router: LifeBoardAppRouter
    @State private var state: FoundationRouteLoadState<Snapshot> = .loading

    var body: some View {
        FoundationEntityRouteScaffold(title: "Routine", systemImage: "figure.mind.and.body", state: state) { snapshot in
            VStack(alignment: .leading, spacing: 14) {
                if let routine = snapshot.definition {
                    Text(routine.title).font(.title2.weight(.semibold))
                    LabeledContent("Version", value: "\(routine.version)")
                    ForEach(routine.steps.sorted(by: { $0.ordinal < $1.ordinal })) { step in
                        Label(step.title, systemImage: "circle")
                    }
                } else {
                    Label("Definition removed", systemImage: "archivebox")
                        .font(.headline)
                    Text("Historical runs remain readable with their saved routine version.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider()
                Text("Run history").font(.headline)
                if snapshot.runs.isEmpty {
                    Text("No runs recorded yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.runs.prefix(30)) { run in
                        VStack(alignment: .leading, spacing: 5) {
                            HStack {
                                Label(run.status.rawValue.capitalized, systemImage: routineStatusSymbol(run.status))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(run.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Text("Version \(run.versionSnapshot.version) · \(run.events.count)/\(run.versionSnapshot.steps.count) steps · \(routineDuration(run))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(12)
                        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .accessibilityElement(children: .combine)
                    }
                }
                Button("Open in Track", systemImage: "chart.bar.fill") { router.select(.track) }
                    .buttonStyle(.borderedProminent).tint(Color(LifeBoardColorTokens.inkPrimary))
            }
        }
        .task(id: id) { await load() }
    }

    private func load() async {
        guard let repository else { state = .failed("Routine data is unavailable."); return }
        do {
            async let routines = repository.fetchRoutines()
            async let runs = repository.fetchRoutineRuns(routineID: id)
            let (definitions, history) = try await (routines, runs)
            let definition = definitions.first(where: { $0.id == id })
            guard definition != nil || history.isEmpty == false else { state = .missing; return }
            state = .loaded(Snapshot(
                definition: definition,
                runs: history.sorted { $0.startedAt > $1.startedAt }
            ))
        }
        catch { state = .failed(error.localizedDescription) }
    }

    private func routineDuration(_ run: RoutineRun) -> String {
        let seconds = max(
            0,
            (run.endedAt ?? run.updatedAt).timeIntervalSince(run.startedAt)
                - run.effectivePausedDuration
        )
        let minutes = max(1, Int((seconds / 60).rounded()))
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }

    private func routineStatusSymbol(_ status: RoutineRunStatus) -> String {
        switch status {
        case .running: "play.circle"
        case .paused: "pause.circle"
        case .interrupted: "exclamationmark.circle"
        case .completed: "checkmark.circle.fill"
        case .partial: "circle.lefthalf.filled"
        case .abandoned: "xmark.circle"
        case .skipped: "forward.circle"
        }
    }
}

private struct FoundationGoalRouteView: View {
    private struct ResolvedLink: Identifiable {
        let link: GoalLink
        let source: TypedSourcePickerItem?
        var id: UUID { link.id }
    }

    private struct HistoryPoint: Identifiable {
        let date: Date
        let progress: GoalProgressSnapshot
        var id: TimeInterval { date.timeIntervalSinceReferenceDate }
    }

    private struct Snapshot {
        let goal: GoalDefinition
        let links: [ResolvedLink]
        let current: GoalProgressSnapshot?
        let history: [HistoryPoint]
    }

    let id: UUID
    let repository: CoreDataTrackFoundationRepository?
    let sampleProvider: (any GoalSampleProvider)?
    let sourceRepository: any TypedSourcePickerRepository
    let router: LifeBoardAppRouter
    @State private var state: FoundationRouteLoadState<Snapshot> = .loading
    @State private var repairingLink: GoalLink?

    var body: some View {
        FoundationEntityRouteScaffold(title: "Goal", systemImage: "target", state: state) { snapshot in
            VStack(alignment: .leading, spacing: 14) {
                let goal = snapshot.goal
                Text(goal.title).font(.title2.weight(.semibold))
                LabeledContent("Type", value: goal.type.rawValue.capitalized)
                LabeledContent("Target", value: goal.targetValue.map { "\($0.formatted()) \(goal.unitLabel ?? "")" } ?? "Completion")
                LabeledContent("Target date", value: goal.targetDate?.formatted(date: .abbreviated, time: .omitted) ?? "Flexible")

                if let progress = snapshot.current {
                    Divider()
                    Text("Progress").font(.headline)
                    if let fraction = progress.progressFraction {
                        ProgressView(value: fraction)
                            .accessibilityValue(fraction.formatted(.percent.precision(.fractionLength(0))))
                        Text("\(fraction.formatted(.percent.precision(.fractionLength(0)))) · confidence \(progress.confidence.formatted(.percent.precision(.fractionLength(0))))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Progress is partial because linked evidence is missing.")
                            .foregroundStyle(.secondary)
                    }
                    Text(progress.nextUsefulAction)
                        .font(.subheadline)
                }

                Divider()
                Text("Linked sources").font(.headline)
                if snapshot.links.isEmpty {
                    Text("No sources linked yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(snapshot.links) { resolved in
                        HStack(spacing: 10) {
                            Image(systemName: sourceKind(resolved.link.source).systemImage)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(resolved.source?.title ?? "Linked source unavailable")
                                    .font(.subheadline.weight(.medium))
                                Text(resolved.link.source.rawValue.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if resolved.source == nil {
                                Button("Repair") { repairingLink = resolved.link }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                            }
                        }
                        .frame(minHeight: 44)
                    }
                }

                if snapshot.history.isEmpty == false {
                    Divider()
                    Text("30-day history").font(.headline)
                    ForEach(snapshot.history) { point in
                        HStack {
                            Text(point.date.formatted(date: .abbreviated, time: .omitted))
                            Spacer()
                            Text(point.progress.progressFraction?.formatted(.percent.precision(.fractionLength(0))) ?? "Partial")
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .combine)
                    }
                }
                Button("Open in Track", systemImage: "chart.bar.fill") { router.select(.track) }
                    .buttonStyle(.borderedProminent).tint(Color(LifeBoardColorTokens.inkPrimary))
            }
        }
        .task(id: id) { await load() }
        .sheet(item: $repairingLink) { link in
            TypedSourcePickerView(
                title: "Repair linked source",
                kinds: [sourceKind(link.source)],
                repository: sourceRepository
            ) { source in
                Task { await repair(link, with: source) }
            }
        }
    }

    private func load() async {
        guard let repository else { state = .failed("Goal data is unavailable."); return }
        do {
            async let goals = repository.fetchGoals()
            async let links = repository.fetchGoalLinks(goalID: id)
            let (definitions, resolvedLinks) = try await (goals, links)
            guard let goal = definitions.first(where: { $0.id == id }) else { state = .missing; return }

            var candidates: [TypedSourceKind: [TypedSourcePickerItem]] = [:]
            for kind in Set(resolvedLinks.map { sourceKind($0.source) }) {
                candidates[kind] = (try? await sourceRepository.candidates(for: kind, query: "")) ?? []
            }
            let displayLinks = resolvedLinks.map { link in
                ResolvedLink(
                    link: link,
                    source: candidates[sourceKind(link.source)]?.first(where: { $0.id == link.sourceID })
                )
            }

            var current: GoalProgressSnapshot?
            var history: [HistoryPoint] = []
            if let sampleProvider {
                let service = DefaultGoalProgressService()
                let samples = try await sampleProvider.samples(for: resolvedLinks, asOf: Date())
                current = service.progress(for: goal, links: resolvedLinks, samples: samples)
                history = await progressHistory(goal: goal, links: resolvedLinks, provider: sampleProvider, service: service)
            }
            state = .loaded(Snapshot(goal: goal, links: displayLinks, current: current, history: history))
        }
        catch { state = .failed(error.localizedDescription) }
    }

    private func progressHistory(
        goal: GoalDefinition,
        links: [GoalLink],
        provider: any GoalSampleProvider,
        service: DefaultGoalProgressService
    ) async -> [HistoryPoint] {
        await withTaskGroup(of: HistoryPoint?.self) { group in
            let calendar = Calendar.current
            for offset in 0..<30 {
                guard let date = calendar.date(byAdding: .day, value: -offset, to: Date()) else { continue }
                group.addTask {
                    guard let samples = try? await provider.samples(for: links, asOf: date) else { return nil }
                    return HistoryPoint(date: date, progress: service.progress(for: goal, links: links, samples: samples))
                }
            }
            var values: [HistoryPoint] = []
            for await point in group {
                if let point { values.append(point) }
            }
            return values.sorted { $0.date > $1.date }
        }
    }

    private func repair(_ link: GoalLink, with source: TypedSourcePickerItem) async {
        guard let repository else { return }
        var repaired = link
        repaired.sourceID = source.id
        do {
            try await repository.saveGoalLink(repaired)
            repairingLink = nil
            await load()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func sourceKind(_ source: GoalLinkSource) -> TypedSourceKind {
        switch source {
        case .project: .project
        case .task: .task
        case .habit: .habit
        case .routine: .routine
        case .trackerMeasure: .trackerMeasure
        }
    }
}

private struct FoundationJournalDayRouteView: View {
    let id: UUID
    let repository: (any LifeBoardPhaseIIRepository)?
    @State private var state: FoundationRouteLoadState<LifeBoardJournalDayValue> = .loading

    var body: some View {
        FoundationEntityRouteScaffold(title: "Journal", systemImage: "book.closed", state: state) { day in
            VStack(alignment: .leading, spacing: 14) {
                Text(day.day.formatted(date: .complete, time: .omitted)).font(.title2.weight(.semibold))
                if let summary = day.summary, summary.isEmpty == false { Text(summary).font(.headline) }
                ForEach(day.blocks) { block in
                    if let text = block.text, text.isEmpty == false { Text(text).font(.body) }
                    if let mood = block.mood { Label(mood.title, systemImage: "face.smiling") }
                }
                if day.media.isEmpty == false { Label("\(day.media.count) private attachments", systemImage: "paperclip") }
            }
        }
        .task(id: id) { await load() }
    }

    private func load() async {
        guard let repository else { state = .failed("Journal data is unavailable."); return }
        do { state = try await repository.fetchJournalDays(search: nil, starredOnly: false, mood: nil).first(where: { $0.id == id }).map(FoundationRouteLoadState.loaded) ?? .missing }
        catch { state = .failed(error.localizedDescription) }
    }
}

private struct FoundationNoteRouteView: View {
    let id: UUID
    let repository: (any LifeBoardPhaseIIRepository)?
    @State private var state: FoundationRouteLoadState<LifeBoardKnowledgeNoteValue> = .loading

    var body: some View {
        FoundationEntityRouteScaffold(title: "Note", systemImage: "note.text", state: state) { note in
            VStack(alignment: .leading, spacing: 14) {
                Text(note.title).font(.title2.weight(.semibold))
                ForEach(note.blocks) { block in
                    if block.kind == .divider { Divider() }
                    else { Text(block.text).font(block.kind == .heading1 ? .title3.weight(.semibold) : .body) }
                }
            }
        }
        .task(id: id) { await load() }
    }

    private func load() async {
        guard let repository else { state = .failed("Notes data is unavailable."); return }
        do { state = try await repository.fetchKnowledgeNotes(search: nil, spaceID: nil).first(where: { $0.id == id }).map(FoundationRouteLoadState.loaded) ?? .missing }
        catch { state = .failed(error.localizedDescription) }
    }
}

private struct FoundationEntityRouteScaffold<Value, Content: View>: View {
    let title: String
    let systemImage: String
    let state: FoundationRouteLoadState<Value>
    @ViewBuilder let content: (Value) -> Content

    var body: some View {
        ScrollView {
            Group {
                switch state {
                case .loading:
                    ProgressView("Loading \(title.lowercased())…")
                case .loaded(let value):
                    content(value)
                        .frame(maxWidth: 720, alignment: .leading)
                case .missing:
                    ContentUnavailableView("\(title) not found", systemImage: systemImage, description: Text("It may have been deleted or changed on another device."))
                case .failed(let message):
                    ContentUnavailableView("\(title) unavailable", systemImage: "exclamationmark.triangle", description: Text(message))
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .accessibilityIdentifier("foundation.route.\(title.lowercased())")
    }
}

private struct FoundationCaptureSheet: View {
    let request: CaptureRequest
    let phaseIIRepository: (any LifeBoardPhaseIIRepository)?
    let planningRepository: CoreDataPlanningRepository?
    let trackFoundationRepository: CoreDataTrackFoundationRepository?
    let routineLinkedMutationApplier: (any RoutineLinkedMutationApplying)?
    var mutationCoordinator: LifeBoardMutationCoordinator?
    var onReceipt: (LifeBoardActionReceipt) -> Void = { _ in }
    let onClose: () -> Void
    let onOpenHabitBoard: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            captureContent
            Button {
                onClose()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(.regularMaterial, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close capture")
            .accessibilityValue(request.kind.title)
            .accessibilityIdentifier("foundation.capture.dismiss")
            .padding(12)
            .zIndex(10)
        }
    }

    @ViewBuilder
    private var captureContent: some View {
        switch request.kind {
        case .task:
            FoundationTaskCaptureHost(
                prefilledText: request.prefilledText,
                captureSeed: request.captureSeed
            )
        case .habit:
            FoundationHabitCaptureHost()
        case .journal:
            if V2FeatureFlags.journalV1Enabled, let phaseIIRepository {
                NavigationStack {
                    LifeBoardJournalModuleView(
                        repository: phaseIIRepository,
                        initialText: request.captureSeed?.rawText ?? request.prefilledText,
                        startsWithTextComposer: request.captureSeed != nil || request.prefilledText != nil
                    )
                }
            } else { EmptyView() }
        case .note:
            if V2FeatureFlags.knowledgeNotesV1Enabled, let phaseIIRepository {
                NavigationStack {
                    LifeBoardKnowledgeModuleView(
                        repository: phaseIIRepository,
                        startsWithNewNote: true,
                        captureDraftID: request.draftID,
                        initialText: request.captureSeed?.rawText ?? request.prefilledText
                    )
                }
            } else { EmptyView() }
        case .trackerEntry:
            if V2FeatureFlags.trackersV1Enabled, let phaseIIRepository {
                NavigationStack {
                    LifeBoardBehaviorAreaRouteView(
                        repository: phaseIIRepository,
                        initialArea: .trackers,
                        onOpenHabitBoard: onOpenHabitBoard
                    )
                }
            } else { EmptyView() }
        case .mood where V2FeatureFlags.journalParityV1Enabled:
            if let phaseIIRepository, let trackFoundationRepository {
                JournalMoodCaptureView(
                    repository: trackFoundationRepository,
                    phaseIIRepository: phaseIIRepository
                )
            } else { EmptyView() }
        case .mood, .hydration, .medicationEvent, .routineRun:
            if let phaseIIRepository, let trackFoundationRepository {
                NavigationStack {
                    TrackUniversalCaptureView(
                        kind: request.kind,
                        repository: trackFoundationRepository,
                        phaseIIRepository: phaseIIRepository,
                        linkedMutationApplier: routineLinkedMutationApplier
                    )
                }
            } else { EmptyView() }
        case .timeBlock:
            if let planningRepository {
                NavigationStack {
                    FoundationTimeBlockCaptureHost(
                        repository: planningRepository,
                        mutationCoordinator: mutationCoordinator,
                        onReceipt: onReceipt
                    )
                }
            } else { EmptyView() }
        }
    }
}

private struct FoundationTimeBlockCaptureHost: View {
    let repository: CoreDataPlanningRepository
    var mutationCoordinator: LifeBoardMutationCoordinator?
    var onReceipt: (LifeBoardActionReceipt) -> Void = { _ in }
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var start = Date()
    @State private var minutes = 45.0
    @State private var isSaving = false
    @State private var errorMessage: String?

    var body: some View {
        Form {
            TextField("What is this time for?", text: $title)
            DatePicker("Starts", selection: $start)
            VStack(alignment: .leading, spacing: 8) {
                Text("Duration: \(Int(minutes)) minutes")
                Slider(value: $minutes, in: 15...240, step: 15)
            }
        }
        .navigationTitle("New time block")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) {
                Button(isSaving ? "Saving…" : "Add") { save() }
                    .disabled(isSaving)
            }
        }
        .alert("Time block wasn’t saved", isPresented: errorBinding) {
            Button("OK", role: .cancel) { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Please try again.")
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if $0 == false { errorMessage = nil } }
        )
    }

    private func save() {
        guard isSaving == false else { return }
        isSaving = true
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let block = InternalTimeBlock(
            title: cleanTitle.isEmpty ? "Focus block" : cleanTitle,
            startAt: start,
            endAt: start.addingTimeInterval(minutes * 60)
        )
        Task {
            do {
                // Canonical path: apply through the mutation coordinator so
                // this capture produces a receipt with working Undo, like
                // every conversational mutation.
                if let mutationCoordinator {
                    let repository = repository
                    let command = LifeBoardMutationCommand(
                        preview: .init(
                            destination: .plan,
                            summary: "Add time block “\(block.title)”",
                            changes: ["Reserves \(Int(minutes)) minutes starting \(start.formatted(date: .omitted, time: .shortened))"],
                            origin: .directTap
                        ),
                        apply: {
                            try await repository.saveTimeBlock(block)
                            return "Time block “\(block.title)” added"
                        },
                        undo: {
                            try await repository.deleteTimeBlock(id: block.id)
                        }
                    )
                    let preview = await mutationCoordinator.prepare(command)
                    let receipt = try await mutationCoordinator.apply(previewID: preview.id)
                    onReceipt(receipt)
                } else {
                    try await repository.saveTimeBlock(block)
                }
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isSaving = false
            }
        }
    }
}

/// Typed native route into the existing Weekly Operating Layer. This preserves
/// its persisted outcomes, triage, capacity, and minimum-viable-week workflow
/// instead of maintaining a second, divergent planner in the foundation shell.
@MainActor
private struct FoundationWeeklyPlannerRoute: View {
    let onClose: () -> Void
    @StateObject private var viewModel: WeeklyPlannerViewModel

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        _viewModel = StateObject(
            wrappedValue: PresentationDependencyContainer.shared.makeWeeklyPlannerViewModel()
        )
    }

    var body: some View {
        SunriseWeeklyPlannerView(viewModel: viewModel, onClose: onClose)
            .accessibilityIdentifier("plan.weeklyPlanner.route")
    }
}

/// Typed native route into the existing persisted weekly review and recovery
/// flow. Completion and cancellation both return deterministically to Week.
@MainActor
private struct FoundationWeeklyReviewRoute: View {
    let onClose: () -> Void
    @StateObject private var viewModel: WeeklyReviewViewModel

    init(onClose: @escaping () -> Void) {
        self.onClose = onClose
        _viewModel = StateObject(
            wrappedValue: PresentationDependencyContainer.shared.makeWeeklyReviewViewModel()
        )
    }

    var body: some View {
        SunriseWeeklyReviewView(
            viewModel: viewModel,
            onClose: onClose,
            onCompleted: { _ in onClose() }
        )
        .accessibilityIdentifier("plan.weeklyReview.route")
    }
}

private struct FoundationTaskCaptureHost: View {
    /// Raw text of an already-captured item being reviewed, if any.
    var prefilledText: String?
    var captureSeed: CaptureSeed? = nil
    @StateObject private var viewModel = PresentationDependencyContainer.shared.makeNewAddTaskViewModel()
    @State private var provisionalID = UUID()

    var body: some View {
        SunriseAddTaskSheetView(viewModel: viewModel)
            .task {
                // Seeded once, and only when the field is still untouched, so a
                // re-render cannot overwrite what the user has since typed.
                if let seed = captureSeed, viewModel.taskName.isEmpty {
                    if let parsed = seed.parsedCapture {
                        viewModel.taskName = parsed.cleanTitle.isEmpty ? seed.rawText : parsed.cleanTitle
                        if let date = parsed.dueDate { viewModel.dueDate = date }
                        if let priority = parsed.priority { viewModel.selectedPriority = priority }
                        if let duration = parsed.duration { viewModel.estimatedDuration = duration }
                        if let repeatPattern = parsed.repeatPattern { viewModel.repeatPattern = repeatPattern }
                        if let project = parsed.projectName { viewModel.selectedProject = project }
                    } else {
                        viewModel.taskName = seed.rawText
                    }
                    return
                }
                if let prefilledText, viewModel.taskName.isEmpty {
                    viewModel.taskName = prefilledText
                    return
                }
                guard captureSeed == nil,
                      prefilledText == nil,
                      viewModel.taskName.isEmpty,
                      let recovered = PendingCaptureInbox.read()
                        .filter({ $0.source == "in-app" && $0.isProvisional })
                        .max(by: { ($0.provisionalAt ?? $0.createdAt) < ($1.provisionalAt ?? $1.createdAt) })
                else { return }
                provisionalID = recovered.id
                viewModel.taskName = recovered.rawText
            }
            .onChange(of: viewModel.taskName) { _, newValue in
                let meaningful = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
                guard meaningful.count >= 3, viewModel.isTaskCreated == false else { return }
                PendingCaptureInbox.upsert(PendingCapture(
                    id: provisionalID,
                    rawText: newValue,
                    source: "in-app",
                    provisionalAt: Date()
                ))
            }
            .onChange(of: viewModel.isTaskCreated) { _, created in
                guard created else { return }
                LifeBoardIntentDonations.taskAdded(title: viewModel.taskName)
                PendingCaptureInbox.remove(ids: [provisionalID])
            }
    }
}

private struct HomeCardPlacementRequest: Identifiable {
    let kind: DashboardWidgetKind
    let destination: LifeBoardDestination
    var id: String { "\(destination.rawValue):\(kind.rawValue)" }
}

private struct HomeCardPlacementSheet: View {
    let descriptor: DashboardWidgetDescriptor
    let destination: LifeBoardDestination
    let onCancel: () -> Void
    let onAdd: (WidgetSizePreset) -> Void

    @State private var selectedSize: WidgetSizePreset
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        descriptor: DashboardWidgetDescriptor,
        destination: LifeBoardDestination,
        onCancel: @escaping () -> Void,
        onAdd: @escaping (WidgetSizePreset) -> Void
    ) {
        self.descriptor = descriptor
        self.destination = destination
        self.onCancel = onCancel
        self.onAdd = onAdd
        _selectedSize = State(initialValue: descriptor.defaultSize)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 7) {
                        Label("From \(destination.title)", systemImage: destination.systemImage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        Text("Add \(descriptor.title) to Home")
                            .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("Choose how much this card should reveal. You can resize or move it any time.")
                            .font(.body)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }

                    homeMiniature

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Size")
                            .font(.headline)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) { sizeButtons }
                            VStack(spacing: 8) { sizeButtons }
                        }
                    }

                    HStack(spacing: 10) {
                        Image(systemName: "hand.draw")
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        Text("LifeBoard will use the first open position. Your existing cards never move unless you choose to edit Home.")
                            .font(.caption)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }
                    .padding(14)
                    .background(Color(LifeBoardColorTokens.foundationSurfaceSelected), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(22)
            }
            .background(Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                Button {
                    onAdd(selectedSize)
                } label: {
                    Label("Add to Home", systemImage: "rectangle.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(LifeBoardColorTokens.inkPrimary))
                .padding(.horizontal, 22)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .accessibilityIdentifier("home.placement.add")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
            }
        }
        .presentationDetents([.large])
    }

    @ViewBuilder
    private var sizeButtons: some View {
        ForEach(WidgetSizePreset.allCases.filter(descriptor.supportedSizes.contains), id: \.self) { size in
            Button {
                withAnimation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.86)) {
                    selectedSize = size
                }
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                VStack(spacing: 3) {
                    Text(size.title).font(.subheadline.weight(.semibold))
                    Text("\(size.canonicalGridSpan.columns)×\(size.canonicalGridSpan.rows)")
                        .font(.caption2.monospacedDigit())
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.bordered)
            .tint(selectedSize == size
                  ? Color(LifeBoardColorTokens.inkPrimary)
                  : Color(LifeBoardColorTokens.inkSecondary))
            .accessibilityLabel(size.title)
            .accessibilityHint("Uses (size.canonicalGridSpan.columns) columns and (size.canonicalGridSpan.rows) rows")
            .accessibilityValue(selectedSize == size ? "Selected" : "")
        }
    }

    private var homeMiniature: some View {
        let span = selectedSize.canonicalGridSpan
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("My Home preview", systemImage: "house")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(selectedSize.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            GeometryReader { proxy in
                let gap: CGFloat = 7
                let unit = (proxy.size.width - (gap * 3)) / 4
                ZStack(alignment: .topLeading) {
                    ForEach(0..<16, id: \.self) { index in
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(LifeBoardColorTokens.foundationCanvas))
                            .frame(width: unit, height: unit * 0.58)
                            .offset(
                                x: CGFloat(index % 4) * (unit + gap),
                                y: CGFloat(index / 4) * ((unit * 0.58) + gap)
                            )
                    }
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Color(LifeBoardColorTokens.foundationSunAccent))
                        .overlay(alignment: .topLeading) {
                            Label(descriptor.title, systemImage: descriptor.systemImage)
                                .font(.caption.weight(.semibold))
                                .lineLimit(1)
                                .padding(10)
                        }
                        .frame(
                            width: (unit * CGFloat(span.columns)) + (gap * CGFloat(span.columns - 1)),
                            height: max(unit * 0.58, (unit * 0.58 * CGFloat(span.rows)) + (gap * CGFloat(span.rows - 1)))
                        )
                        .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.18), radius: 10, y: 5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
            .frame(height: 245)
            .clipped()
        }
        .padding(16)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
        }
    }
}

private struct LifeBoardComposerPreviewCard: View {
    let preview: LifeBoardTransactionPreview
    let onApply: () -> Void
    let onEdit: () -> Void
    let onNotNow: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: preview.destination.systemImage)
                    .font(.system(size: 15, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .background(Color(LifeBoardColorTokens.foundationSunAccent).opacity(0.2), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Review before applying")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    Text(preview.summary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                }
                Spacer(minLength: 0)
                Text(preview.destination.title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }

            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(preview.changes.enumerated()), id: \.offset) { _, change in
                    Label(change, systemImage: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                }
                ForEach(Array(preview.warnings.enumerated()), id: \.offset) { _, warning in
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
            }
            .accessibilityElement(children: .combine)

            HStack(spacing: 8) {
                Button("Not now", action: onNotNow)
                    .buttonStyle(.plain)
                    .frame(minHeight: 44)
                    .padding(.horizontal, 6)
                Button("Edit", action: onEdit)
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
                Button("Apply", action: onApply)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(LifeBoardColorTokens.inkPrimary))
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(15)
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
        }
        .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.14), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lifeThread.preview")
    }
}

private struct LifeBoardComposerReceiptView: View {
    let receipt: LifeBoardActionReceipt
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color(LifeBoardColorTokens.foundationSunAccent))
            Text(receipt.message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                .frame(maxWidth: .infinity, alignment: .leading)
            if receipt.canUndo {
                Button("Undo", action: onUndo)
                    .font(.caption.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44)
            }
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("Dismiss receipt")
        }
        .padding(.leading, 14)
        .padding(.trailing, 4)
        .lifeBoardGlassSurface(cornerRadius: 22, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("lifeThread.receipt")
    }
}

private struct HomeCardPlacementReceipt: Identifiable {
    let id = UUID()
    let title: String
    let transaction: HomeLayoutTransaction
}

private struct HomeCardPlacementReceiptView: View {
    let receipt: HomeCardPlacementReceipt
    let onView: () -> Void
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.title3)
                .foregroundStyle(Color(LifeBoardColorTokens.foundationSunAccent))
            Text(receipt.title)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("View", action: onView)
                .font(.subheadline.weight(.semibold))
            Button("Undo", action: onUndo)
                .font(.subheadline)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .frame(width: 32, height: 32)
            }
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .lifeBoardGlassSurface(cornerRadius: 22, interactive: true)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
        }
        .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.2), radius: 16, y: 8)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.addCard.receipt")
    }
}

private struct FoundationHabitCaptureHost: View {
    @StateObject private var viewModel = PresentationDependencyContainer.shared.makeNewAddHabitViewModel()

    var body: some View {
        SunriseAddHabitSheetView(viewModel: viewModel)
    }
}

/// The one-shot lift a dock icon makes when its root becomes the current one.
///
/// A `matchedGeometryEffect` already slides the selected well between slots, but
/// the icon itself stayed inert, so arriving somewhere read as the background
/// moving rather than the destination responding. The phases run once per
/// selection — rest, lift, settle — so the icon acknowledges the tap and then
/// gets out of the way, rather than looping and pulling the eye back down.
private struct LifeBoardDockLift: ViewModifier {
    let isSelected: Bool
    let reduceMotion: Bool

    enum Phase: CaseIterable {
        case rest, lift, settle

        var scale: Double {
            switch self {
            case .rest, .settle: 1
            case .lift: 1.18
            }
        }

        var offsetY: Double {
            switch self {
            case .rest, .settle: 0
            case .lift: -3
            }
        }
    }

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.phaseAnimator(Phase.allCases, trigger: isSelected) { view, phase in
                view
                    .scaleEffect(phase.scale)
                    .offset(y: phase.offsetY)
            } animation: { phase in
                switch phase {
                case .rest: .easeOut(duration: 0.01)
                case .lift: .spring(response: 0.22, dampingFraction: 0.55)
                case .settle: .spring(response: 0.32, dampingFraction: 0.78)
                }
            }
        }
    }
}

/// Where each root rests relative to the one on screen.
///
/// A root change should read as travelling along the dock rather than as one
/// screen dissolving into another, so a root waits on the side it occupies in
/// the dock order: roots to the left of the current one wait on the left, roots
/// to the right wait on the right. Moving from Home to Track therefore carries
/// the eye left-to-right, the same direction the selected well travels.
///
/// The distance is deliberately short. A full-width page slide would fight the
/// dock's own selection movement and make every root change feel like a journey.
enum LifeBoardRootTransition {
    /// Far enough to give the change a direction, near enough to stay calm.
    static let slideDistance: CGFloat = 24

    /// Horizontal resting offset for `destination` while `selected` is on screen.
    ///
    /// The sign comes from dock order, and the magnitude is capped: roots three
    /// slots away are no further off than roots one slot away, because they are
    /// invisible either way and a longer throw only makes the arrival slower.
    static func offset(
        for destination: LifeBoardDestination,
        selected: LifeBoardDestination,
        distance: CGFloat = slideDistance
    ) -> CGFloat {
        guard destination != selected else { return 0 }
        let order = LifeBoardDestination.allCases
        guard let from = order.firstIndex(of: destination),
              let to = order.firstIndex(of: selected) else { return 0 }
        return from < to ? -distance : distance
    }
}
