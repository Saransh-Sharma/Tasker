import SwiftUI
import SwiftData
import UIKit
import VisionKit

public struct LifeOSFoundationShell: View {
    private let legacyHomeController: UIViewController
    private let runtime: LifeOSFoundationRuntime
    private let showsReferenceHome: Bool
    private let homeProjectionAdapter: HomeProjectionAdapter?
    private let dashboardLayoutRepository: any DashboardLayoutRepository
    private let phaseIIRepository: any LifeBoardPhaseIIRepository
    private let planningRepository: CoreDataPlanningRepository
    private let trackFoundationRepository: CoreDataTrackFoundationRepository
    private let habitRuntimeReadRepository: any HabitRuntimeReadRepositoryProtocol
    private let routineLinkedMutationApplier: any RoutineLinkedMutationApplying
    private let goalSampleProvider: any GoalSampleProvider
    private let starterPackMutationApplier: any StarterPackCanonicalMutationApplying
    private let habitRecoveryMutationApplier: any HabitRecoveryMutationApplying
    private let nutritionRepository: any NutritionRepository
    private let lifeMomentRepository: any LifeMomentRepository
    private let wellnessRepository: any WellnessRepository

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var compactCaptureState = CaptureOrbPresentationState()
    @State private var measuredChromeHeight: CGFloat = 132
    @State private var compactCaptureTargetFrames: [CaptureKind: CGRect] = [:]
    @State private var compactCaptureRippleTrigger = 0
    @State private var homeCardReceipt: HomeCardPlacementReceipt?
    @State private var homeCardPlacementRequest: HomeCardPlacementRequest?
    @State private var composerAudioStore: LifeBoardJournalStore?
    @State private var showsComposerAudioCapture = false
    @State private var lifeThreadComposer = LifeThreadComposerCoordinator()
    @State private var showsDocumentScanner = false
    @State private var scannedDraft: LifeBoardScannedDraft?
    @State private var lifeBoardActionReceipt: LifeBoardActionReceipt?
    @FocusState private var lifeThreadComposerIsFocused: Bool
    private let lifeBoardMutationCoordinator: LifeBoardMutationCoordinator
    private let lifeThreadIntentResolver: LifeThreadIntentResolver

    init(
        legacyHomeController: UIViewController,
        runtime: LifeOSFoundationRuntime = .shared,
        homeProjectionAdapter: HomeProjectionAdapter? = nil,
        dashboardLayoutRepository: any DashboardLayoutRepository,
        phaseIIRepository: any LifeBoardPhaseIIRepository,
        planningRepository: CoreDataPlanningRepository,
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
        self.legacyHomeController = legacyHomeController
        self.runtime = runtime
        self.homeProjectionAdapter = homeProjectionAdapter
        self.dashboardLayoutRepository = dashboardLayoutRepository
        self.phaseIIRepository = phaseIIRepository
        self.planningRepository = planningRepository
        self.trackFoundationRepository = trackFoundationRepository
        self.habitRuntimeReadRepository = habitRuntimeReadRepository
        self.routineLinkedMutationApplier = routineLinkedMutationApplier
        self.goalSampleProvider = goalSampleProvider
        self.starterPackMutationApplier = starterPackMutationApplier
        self.habitRecoveryMutationApplier = habitRecoveryMutationApplier
        self.nutritionRepository = nutritionRepository
        self.lifeMomentRepository = lifeMomentRepository
        self.wellnessRepository = wellnessRepository
        self.showsReferenceHome = showsReferenceHome
        let mutationCoordinator = LifeBoardMutationCoordinator()
        lifeBoardMutationCoordinator = mutationCoordinator
        lifeThreadIntentResolver = LifeThreadIntentResolver(mutationCoordinator: mutationCoordinator)
    }

    public var body: some View {
        @Bindable var router = runtime.router
        Group {
            if horizontalSizeClass == .regular {
                expandedShell(router: router)
            } else {
                compactShell(router: router)
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
        .sheet(item: $homeCardPlacementRequest) { request in
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
        .sheet(isPresented: $showsComposerAudioCapture, onDismiss: {
            if lifeThreadComposer.state == .recording { lifeThreadComposer.focus() }
        }) {
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
        .alert(item: $router.activeAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
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
        .onChange(of: router.selectedDestination, initial: true) { _, destination in
            lifeThreadComposer.move(to: destination)
        }
        // Presentation modifiers live outside the shell's visual subtree. Keep
        // the observable preferences at the outermost level so sheets and
        // navigation destinations receive the same environment as root views.
        .environment(runtime.preferences)
    }

    private func compactShell(router: LifeBoardAppRouter) -> some View {
        @Bindable var router = router
        // The floating chrome draws as a bottom overlay, and each root reserves
        // its measured height as a clear bottom inset. This is the measured
        // content clearance the plan calls for: every root's final row clears
        // the dock and composer, with no blank footer band and no content
        // resting under the translucent composer. (A TabView's own
        // safeAreaInset does not propagate into per-tab scroll views.)
        return GeometryReader { geometry in
            TabView(selection: $router.selectedDestination) {
                ForEach(LifeBoardDestination.allCases, id: \.self) { destination in
                    destinationNavigation(destination, router: router)
                        .safeAreaInset(edge: .bottom, spacing: 0) {
                            Color.clear.frame(height: measuredChromeHeight)
                        }
                        .tag(destination)
                }
            }
            .toolbar(.hidden, for: .tabBar)
            .overlay(alignment: .bottom) {
                compactNavigationChrome(
                    router: router,
                    paletteMaxHeight: max(176, min(320, geometry.size.height * 0.38))
                )
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .background(alignment: .bottom) {
                    // A short fade at the very top dissolves scrolling content
                    // into the canvas; below it the canvas is solid so nothing
                    // reads through the translucent composer.
                    VStack(spacing: 0) {
                        LinearGradient(
                            colors: [
                                Color(LifeBoardColorTokens.foundationCanvas).opacity(0),
                                Color(LifeBoardColorTokens.foundationCanvas)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 28)
                        Color(LifeBoardColorTokens.foundationCanvas)
                    }
                    .frame(height: measuredChromeHeight + 28)
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
        .background(Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea())
    }

    private func compactNavigationChrome(router: LifeBoardAppRouter, paletteMaxHeight: CGFloat) -> some View {
        VStack(spacing: 8) {
            if compactCaptureState.isExpanded, sharedComposerIsVisible == false {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                        ForEach(availableCaptureKinds, id: \.self) { kind in
                            Button {
                                commitCompactCapture(kind)
                            } label: {
                                Label(kind.title, systemImage: kind.systemImage)
                                    .font(.subheadline.weight(.medium))
                                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    .padding(.horizontal, 10)
                                    .background(
                                        compactCaptureState.highlightedKind == kind
                                            ? Color(LifeBoardColorTokens.foundationSurfaceSelected)
                                            : Color.clear,
                                        in: RoundedRectangle(cornerRadius: 15, style: .continuous)
                                    )
                            }
                            .buttonStyle(.plain)
                            .onGeometryChange(for: CGRect.self) { proxy in
                                proxy.frame(in: .global)
                            } action: { frame in
                                compactCaptureTargetFrames[kind] = frame
                            }
                            .accessibilityLabel("Capture \(kind.title)")
                        }
                    }
                    .padding(10)
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxWidth: 340, maxHeight: paletteMaxHeight)
                .accessibilityIdentifier("foundation.capture.palette")
                .lifeBoardGlassSurface(cornerRadius: 24, interactive: true)
                .overlay { RoundedRectangle(cornerRadius: 24).stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1) }
                .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.24), radius: 18, y: 10)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            if sharedComposerIsVisible {
                lifeThreadComposerHost(router: router)
            }

            ZStack(alignment: .top) {
                HStack(spacing: 0) {
                    ForEach(LifeBoardDestination.allCases, id: \.self) { destination in
                        Button {
                            router.activateRoot(destination)
                            UISelectionFeedbackGenerator().selectionChanged()
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: destination.systemImage)
                                    .font(.system(size: 17, weight: router.selectedDestination == destination ? .semibold : .regular))
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
                .lifeBoardGlassSurface(cornerRadius: 30, interactive: true)
                .overlay { RoundedRectangle(cornerRadius: 30).stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1) }
                .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.18), radius: 12, y: 6)

                if sharedComposerIsVisible == false {
                    Button {
                        withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                            compactCaptureState.isExpanded.toggle()
                        }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    } label: {
                        Image(systemName: compactCaptureState.isExpanded ? "xmark" : "plus")
                            .font(.system(size: 21, weight: .bold))
                            .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                            .frame(width: 56, height: 56)
                            .background(Color(LifeBoardColorTokens.foundationSunAccent), in: Circle())
                            .lifeboardConfirmationRipple(
                                trigger: compactCaptureRippleTrigger,
                                tint: Color(LifeBoardColorTokens.inkPrimary)
                            )
                            .overlay { Circle().stroke(Color(LifeBoardColorTokens.foundationSurfaceSolid), lineWidth: 3) }
                            .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow).opacity(0.25), radius: 12, y: 6)
                    }
                    // Capture is an action layer above navigation, never a sixth tab or
                    // an obstruction over the center destination. Half-overlapping the
                    // dock keeps it raised without reserving a dead band above.
                    .offset(y: -30)
                    .accessibilityLabel("Universal capture")
                    .accessibilityValue(compactCaptureState.isExpanded ? "Expanded" : "Collapsed")
                    .accessibilityIdentifier("foundation.capture")
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 12, coordinateSpace: .global)
                            .onChanged { value in updateCompactCaptureDrag(at: value.location) }
                            .onEnded { value in finishCompactCaptureDrag(at: value.location) }
                    )
                    .accessibilityActions {
                        ForEach(availableCaptureKinds, id: \.self) { kind in
                            Button("Capture \(kind.title)") { commitCompactCapture(kind) }
                        }
                    }
                }
            }
            .padding(.top, sharedComposerIsVisible ? 0 : 30)
        }
    }

    private var sharedComposerIsVisible: Bool {
        V2FeatureFlags.lifeOSUnifiedPresentationV2Enabled
    }

    private func updateCompactCaptureDrag(at location: CGPoint) {
        if compactCaptureState.isExpanded == false {
            withAnimation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.84)) {
                compactCaptureState.isExpanded = true
            }
        }
        let targets = compactCaptureTargetFrames.map { CaptureOrbDragTarget(kind: $0.key, frame: $0.value) }
        let selection = CaptureOrbDragSelectionPolicy.selection(at: location, targets: targets)
        guard selection != compactCaptureState.highlightedKind else { return }
        compactCaptureState.highlightedKind = selection
        if selection != nil { UISelectionFeedbackGenerator().selectionChanged() }
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
        runtime.captureRouter.request(kind: kind, source: .shell)
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
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

    private func expandedShell(router: LifeBoardAppRouter) -> some View {
        @Bindable var router = router
        return NavigationSplitView {
            List {
                ForEach(LifeBoardDestination.allCases, id: \.self) { destination in
                    Button {
                        router.activateRoot(destination)
                    } label: {
                        Label(destination.title, systemImage: destination.systemImage)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("foundation.destination.\(destination.rawValue)")
                    .listRowBackground(
                        router.selectedDestination == destination
                            ? Color(LifeBoardColorTokens.foundationSurfaceSelected)
                            : Color.clear
                    )
                }
            }
            .navigationTitle("LifeBoard")
        } detail: {
            VStack(spacing: 0) {
                destinationNavigation(router.selectedDestination, router: router)
                if sharedComposerIsVisible {
                    lifeThreadComposerHost(router: router)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    private func destinationNavigation(
        _ destination: LifeBoardDestination,
        router: LifeBoardAppRouter
    ) -> some View {
        NavigationStack(path: pathBinding(for: destination)) {
            destinationRoot(destination, router: router)
                .navigationDestination(for: AppRoute.self) { route in
                    routeView(route)
                }
                .toolbar {
                    if destination != .home || showsReferenceHome {
                        ToolbarItemGroup(placement: .topBarTrailing) {
                            if let kinds = homeCardKinds(for: destination), kinds.isEmpty == false {
                                Menu {
                                    ForEach(kinds, id: \.rawValue) { kind in
                                        if let descriptor = DefaultDashboardWidgetRegistry.shared.descriptor(for: kind) {
                                            Button(descriptor.title, systemImage: descriptor.systemImage) {
                                                homeCardPlacementRequest = .init(kind: kind, destination: destination)
                                            }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "rectangle.badge.plus")
                                }
                                .accessibilityLabel("Add a card from \(destination.title) to Home")
                            }

                            Button {
                                router.push(.tokenGallery, in: destination)
                            } label: {
                                Image(systemName: "swatchpalette")
                            }
                            .accessibilityLabel("Open token gallery")

                            if horizontalSizeClass == .regular {
                            Menu {
                                Button("Task", systemImage: "checkmark.circle") {
                                    runtime.captureRouter.request(kind: .task, source: .shell)
                                }
                                Button("Habit", systemImage: "repeat.circle") {
                                    runtime.captureRouter.request(kind: .habit, source: .shell)
                                }
                                if V2FeatureFlags.journalV1Enabled {
                                    Button("Journal", systemImage: "book.closed") {
                                        runtime.captureRouter.request(kind: .journal, source: .shell)
                                    }
                                }
                                if V2FeatureFlags.knowledgeNotesV1Enabled {
                                    Button("Note", systemImage: "note.text") {
                                        runtime.captureRouter.request(kind: .note, source: .shell)
                                    }
                                }
                                if V2FeatureFlags.trackersV1Enabled {
                                    Button("Tracker Entry", systemImage: "chart.bar.doc.horizontal") {
                                        runtime.captureRouter.request(kind: .trackerEntry, source: .shell)
                                    }
                                }
                                if V2FeatureFlags.careModulesV2Enabled {
                                    Button("Mood + Energy", systemImage: "face.smiling") {
                                        runtime.captureRouter.request(kind: .mood, source: .shell)
                                    }
                                    Button("Hydration", systemImage: "drop.fill") {
                                        runtime.captureRouter.request(kind: .hydration, source: .shell)
                                    }
                                    Button("Medication Event", systemImage: "pills") {
                                        runtime.captureRouter.request(kind: .medicationEvent, source: .shell)
                                    }
                                }
                                if V2FeatureFlags.goalsRoutinesV1Enabled {
                                    Button("Routine Run", systemImage: "figure.mind.and.body") {
                                        runtime.captureRouter.request(kind: .routineRun, source: .shell)
                                    }
                                }
                            } label: {
                                Image(systemName: "plus.circle.fill")
                            }
                            .accessibilityLabel("Universal capture")
                            }
                        }
                    }
                }
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

    @ViewBuilder
    private func destinationRoot(
        _ destination: LifeBoardDestination,
        router: LifeBoardAppRouter
    ) -> some View {
        if destination == .home,
           V2FeatureFlags.adaptiveHomeV2Enabled,
           V2FeatureFlags.lifeOSUnifiedPresentationV2Enabled,
           let homeProjectionAdapter {
            LifeBoardAdaptiveHome(
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
                showsEmbeddedComposer: false
            )
        } else if destination == .home, showsReferenceHome == false {
            LegacyHomeControllerHost(controller: legacyHomeController)
                .ignoresSafeArea()
        } else if destination == .plan {
            LifeBoardPlanRootView(
                repository: planningRepository,
                onOpenFocus: { _ in router.select(.plan) },
                onAskEva: { router.select(.eva) },
                onOpenWeeklyPlanner: { router.push(.weeklyPlanner, in: .plan) },
                onOpenWeeklyReview: { router.push(.weeklyReview, in: .plan) }
            )
        } else if destination == .track,
                  V2FeatureFlags.trackFoundationsV2Enabled {
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
                onOpenHabitBoard: { router.push(.habitBoard, in: .track) }
            )
        } else if destination == .track {
            LifeBoardTrackRootView(
                repository: phaseIIRepository,
                onOpenHabitBoard: { router.push(.habitBoard, in: .track) }
            )
        } else if destination == .home {
            LifeBoardReferenceDashboard(preferences: runtime.preferences)
                .navigationTitle("Home")
                .navigationBarTitleDisplayMode(.inline)
        } else if destination == .insights {
            FoundationInsightsDestination(
                repository: trackFoundationRepository,
                phaseIIRepository: phaseIIRepository,
                planningRepository: planningRepository,
                habitProjectionService: CanonicalTrackHabitProjectionService(repository: habitRuntimeReadRepository),
                goalSampleProvider: goalSampleProvider,
                router: router
            )
        } else if destination == .eva {
            FoundationEvaDestination(
                repository: trackFoundationRepository,
                phaseIIRepository: phaseIIRepository,
                planningRepository: planningRepository,
                habitProjectionService: CanonicalTrackHabitProjectionService(repository: habitRuntimeReadRepository),
                goalSampleProvider: goalSampleProvider,
                router: router
            )
        }
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

            if composer.state == .tools {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        composerCaptureButton("Task", systemImage: "checkmark.circle", kind: .task)
                        if V2FeatureFlags.journalV1Enabled {
                            composerCaptureButton("Journal", systemImage: "book.closed", kind: .journal)
                        }
                        if V2FeatureFlags.careModulesV2Enabled {
                            composerCaptureButton("Mood", systemImage: "face.smiling", kind: .mood)
                            composerCaptureButton("Metric", systemImage: "waveform.path.ecg", kind: .hydration)
                        }
                        composerToolButton("Voice", systemImage: "waveform") {
                            beginComposerAudioCapture()
                        }
                        composerToolButton("Scan", systemImage: "doc.viewfinder") {
                            beginDocumentScan(router: router)
                        }
                        if V2FeatureFlags.knowledgeNotesV1Enabled {
                            composerCaptureButton("Note", systemImage: "note.text", kind: .note)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .scrollIndicators(.hidden)
                .transition(.move(edge: .bottom).combined(with: .opacity))
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
                    withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.86)) {
                        composer.state == .tools ? composer.focus() : composer.showTools()
                    }
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Image(systemName: composer.state == .tools ? "xmark" : "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(composer.state == .tools ? "Close capture tools" : "Open capture tools")

                TextField(composerPlaceholder(for: composer.destination), text: $composer.draftText, axis: .vertical)
                    .lineLimit(1...4)
                    .focused($lifeThreadComposerIsFocused)
                    .submitLabel(.send)
                    .onSubmit { submitLifeThreadComposer(router: router) }
                    .onChange(of: lifeThreadComposerIsFocused) { _, focused in
                        if focused { composer.focus() }
                    }
                    .accessibilityIdentifier("lifeThread.composer.field")

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
                .accessibilityLabel(composer.hasDraft ? "Send" : "Record audio")
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

    private func composerCaptureButton(
        _ title: String,
        systemImage: String,
        kind: CaptureKind
    ) -> some View {
        Button {
            if title == "Voice" { lifeThreadComposer.beginRecording() }
            runtime.captureRouter.request(kind: kind, source: .shell)
            UISelectionFeedbackGenerator().selectionChanged()
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
    /// full Journal module.
    private func beginComposerAudioCapture() {
        guard V2FeatureFlags.journalV1Enabled else {
            runtime.captureRouter.request(kind: .journal, source: .shell)
            return
        }
        if composerAudioStore == nil {
            composerAudioStore = LifeBoardJournalStore(repository: phaseIIRepository)
        }
        lifeThreadComposer.beginRecording()
        showsComposerAudioCapture = true
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

    private func submitLifeThreadComposer(router: LifeBoardAppRouter) {
        let text = lifeThreadComposer.draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.isEmpty == false else { return }
        let input = LifeThreadIntentInput(
            text: text,
            attachments: lifeThreadComposer.attachments.map(\.localIdentifier),
            destination: lifeThreadComposer.destination
        )
        lifeThreadComposer.beginWorking("Understanding what you need")
        Task {
            let resolution = await lifeThreadIntentResolver.resolve(input)
            await MainActor.run {
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
                    runtime.captureRouter.request(kind: draft.kind, source: .shell)
                case .transactionPreview(let preview):
                    lifeThreadComposer.review(preview)
                case .navigation(let request):
                    lifeThreadComposer.focus()
                    router.activateRoot(request.destination)
                }
            }
        }
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
        LifeBoardPlanRootView(
            repository: planningRepository,
            initialLens: lens,
            onOpenFocus: { _ in runtime.router.select(.plan) },
            onAskEva: { runtime.router.select(.eva) },
            onOpenWeeklyPlanner: { runtime.router.push(.weeklyPlanner, in: .plan) },
            onOpenWeeklyReview: { runtime.router.push(.weeklyReview, in: .plan) }
        )
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
            FoundationWeeklyReviewRoute(
                onClose: { runtime.router.pop(in: .plan) }
            )
        case .settings:
            FoundationSettingsRouteView()
        case .taskDetail(let id):
            FoundationTaskRouteView(id: id, repository: planningRepository, router: runtime.router)
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
            FoundationTrackerRouteView(id: id, repository: phaseIIRepository)
        case .careLibrary:
            LifeBoardTrackRootView(
                repository: phaseIIRepository,
                initialModule: .overview,
                onOpenHabitBoard: { runtime.router.push(.habitBoard, in: .track) }
            )
        case .project(let id):
            FoundationProjectRouteView(id: id, repository: planningRepository, router: runtime.router)
        case .routine(let id):
            FoundationRoutineRouteView(id: id, repository: trackFoundationRepository, router: runtime.router)
        case .goal(let id):
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
        case .note(let id):
            FoundationNoteRouteView(id: id, repository: phaseIIRepository)
        case .knowledgeFolder(let id):
            LifeBoardKnowledgeModuleView(repository: phaseIIRepository, initialFolderID: id)
        case .focusSession(let id):
            FoundationFocusSessionRouteView(sessionID: id, repository: planningRepository, router: runtime.router)
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

}

private struct LegacyHomeControllerHost: UIViewControllerRepresentable {
    let controller: UIViewController

    func makeUIViewController(context: Context) -> UIViewController {
        controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

private enum FoundationRouteLoadState<Value> {
    case loading
    case loaded(Value)
    case missing
    case failed(String)
}

private struct FoundationFocusSessionRouteView: View {
    let sessionID: UUID?
    let repository: CoreDataPlanningRepository
    let router: LifeBoardAppRouter
    @State private var state: FoundationRouteLoadState<FocusSessionV2> = .loading

    var body: some View {
        Group {
            switch state {
            case .loading:
                ProgressView("Opening focus session…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case let .loaded(session) where session.state == .running || session.state == .paused:
                LifeBoardPlanRootView(
                    repository: repository,
                    initialLens: .day,
                    onOpenFocus: { _ in },
                    onAskEva: { router.select(.eva) }
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
    private enum Scope: String, CaseIterable, Identifiable {
        case today = "Today"
        case week = "Week"
        case system = "System"
        var id: String { rawValue }
    }

    @State private var store: TrackFoundationStore
    @State private var scope: Scope = .today
    @State private var persistedPlanningEvents: [NormalizedLifeEvent] = []
    @State private var planningEvidenceError: String?
    @Environment(LifeBoardPresentationPreferences.self) private var preferences
    let router: LifeBoardAppRouter
    private let planningRepository: CoreDataPlanningRepository?

    init(
        repository: CoreDataTrackFoundationRepository,
        phaseIIRepository: any LifeBoardPhaseIIRepository,
        planningRepository: CoreDataPlanningRepository?,
        habitProjectionService: (any TrackHabitProjectionService)?,
        goalSampleProvider: (any GoalSampleProvider)?,
        router: LifeBoardAppRouter
    ) {
        _store = State(initialValue: TrackFoundationStore(
            repository: repository,
            phaseIIRepository: phaseIIRepository,
            goalSampleProvider: goalSampleProvider,
            habitProjectionService: habitProjectionService
        ))
        self.planningRepository = planningRepository
        self.router = router
    }

    private var authorizedEvents: [NormalizedLifeEvent] {
        SnapshotLifeEventProjectionRepository(events: store.snapshot.normalizedEvents + persistedPlanningEvents)
            .authorizedEvents(for: .insights, journalConsentGranted: false)
    }

    private var events: [NormalizedLifeEvent] {
        let calendar = Calendar.current
        let startToday = calendar.startOfDay(for: Date())
        switch scope {
        case .today:
            return authorizedEvents.filter { $0.occurredAt >= startToday }
        case .week:
            let start = calendar.date(byAdding: .day, value: -6, to: startToday) ?? startToday
            return authorizedEvents.filter { $0.occurredAt >= start }
        case .system:
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
            LifeBoardAtmosphereView(
                daypart: preferences.resolvedDaypart(),
                requestedTier: preferences.renderingTier,
                comfortProfile: preferences.comfortProfile
            )
            .frame(height: 260)
            .clipped()
            .ignoresSafeArea(edges: .top)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("A quieter view of your day")
                            .font(.largeTitle.weight(.bold))
                            .tracking(-0.8)
                        Text("Only recorded signals appear here. Missing data stays missing.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: 680, alignment: .leading)
                    .padding(.top, 46)

                    Picker("Insight scope", selection: $scope) {
                        ForEach(Scope.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 12) {
                        FoundationInsightMetric(value: "\(events.count)", label: "recorded signals")
                        FoundationInsightMetric(value: confidence.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? "—", label: "evidence confidence")
                        FoundationInsightMetric(value: "\(sourceCounts.count)", label: "source domains")
                    }

                    if sourceCounts.isEmpty == false {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(sourceCounts, id: \.domain) { item in
                                    Text("\(item.domain.capitalized) · \(item.count)")
                                        .font(.caption.weight(.semibold))
                                        .padding(.horizontal, 12).frame(minHeight: 36)
                                        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(0.8), in: Capsule())
                                }
                            }
                        }
                    }

                    if missingDomains.isEmpty == false {
                        Label(
                            "No authorized \(missingDomains.joined(separator: ", ")) evidence in this scope.",
                            systemImage: "info.circle"
                        )
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }

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
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Today’s evidence").font(.title2.weight(.semibold))
                            Text("Transparent sources, no inferred claims.").font(.subheadline).foregroundStyle(.secondary)
                        }
                        ForEach(events) { event in
                            FoundationEvidenceRow(event: event) { evidence in open(evidence) }
                        }
                    }
                }
                .frame(maxWidth: 760)
                .padding(.horizontal, 20)
                .padding(.bottom, 48)
            }
        }
        .background(Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea())
        .navigationTitle("Insights")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadEvidence() }
        .refreshable { await loadEvidence() }
        .accessibilityIdentifier("foundation.insights")
    }

    private func loadEvidence() async {
        async let trackLoad: Void = store.load()
        if let planningRepository {
            do {
                let records = try await planningRepository.fetchMutationReceipts(since: nil)
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
                planningEvidenceError = nil
            } catch {
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
            kind: reversed ? "mutation_reversed" : "mutation_applied",
            occurredAt: occurredAt,
            provenance: "Persisted LifeBoard planning receipt",
            evidenceDisplay: record.receipt.summary,
            receipt: .init(receiptID: record.receipt.id, summary: record.receipt.summary),
            reversal: reversed
                ? .reversed(receiptID: record.receipt.id)
                : .reversible(receiptID: record.receipt.id)
        )
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
        case "hydration": router.select(.track)
        case "routine": router.push(.routine(id), in: .insights)
        case "goal": router.push(.goal(id), in: .insights)
        case "journal": router.openProtectedJournalRoute(.journalDay(id), in: .insights)
        case "plan", "task": router.select(.plan)
        case "focus": router.push(.focusSession(id), in: .insights)
        default: router.select(.track)
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

    @ViewBuilder
    var body: some View {
        Group {
            if let container = LLMDataController.shared {
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
            } else {
                LLMStoreUnavailableView()
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 10) {
                Label("Private on-device context", systemImage: "lock.shield")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                Spacer(minLength: 8)
                evidenceSharingMenu
            }
            .padding(.horizontal, 16)
            .frame(minHeight: 44)
            .background(Color(LifeBoardColorTokens.foundationCanvasSoft).opacity(0.96))
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(LifeBoardColorTokens.foundationHairline)).frame(height: 0.5)
            }
        }
        .navigationTitle("Eva")
        .navigationBarTitleDisplayMode(.inline)
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
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content
        }
    }
}

private struct FoundationSettingsRouteView: View {
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
        .navigationTitle("Settings")
        .accessibilityIdentifier("foundation.settings")
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

private struct FoundationTaskRouteView: View {
    let id: UUID
    let repository: CoreDataPlanningRepository?
    let router: LifeBoardAppRouter
    @State private var state: FoundationRouteLoadState<PlanningTaskSummary> = .loading

    var body: some View {
        FoundationEntityRouteScaffold(title: "Task", systemImage: "checkmark.circle", state: state) { task in
            VStack(alignment: .leading, spacing: 16) {
                Text(task.title).font(.title2.weight(.semibold))
                LabeledContent("Priority", value: task.priority.rawValue.capitalized)
                LabeledContent("Estimate", value: task.estimatedDuration.map(Self.duration) ?? "Not set")
                LabeledContent("Due", value: task.dueDate?.formatted(date: .abbreviated, time: .shortened) ?? "Not set")
                Label(task.dependenciesReady ? "Ready to schedule" : "Waiting on a dependency", systemImage: task.dependenciesReady ? "checkmark.seal" : "link.badge.plus")
                Button("Open in Plan", systemImage: "calendar") { router.select(.plan) }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(LifeBoardColorTokens.inkPrimary))
            }
        }
        .task(id: id) { await load() }
    }

    private func load() async {
        guard let repository else { state = .failed("Planning data is unavailable."); return }
        do {
            state = try await repository.fetchOpenPlanningTasks().first(where: { $0.id == id }).map(FoundationRouteLoadState.loaded) ?? .missing
        } catch { state = .failed(error.localizedDescription) }
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
    let id: UUID
    let repository: CoreDataPlanningRepository?
    let router: LifeBoardAppRouter
    @State private var state: FoundationRouteLoadState<[PlanningTaskSummary]> = .loading

    var body: some View {
        FoundationEntityRouteScaffold(title: "Project", systemImage: "folder", state: state) { tasks in
            VStack(alignment: .leading, spacing: 14) {
                Text(tasks.isEmpty ? "No open work" : "\(tasks.count) open tasks")
                    .font(.title2.weight(.semibold))
                ForEach(tasks.prefix(12)) { task in
                    Label(task.title, systemImage: task.dependenciesReady ? "circle" : "link")
                        .font(.body)
                }
                Button("Open project work in Plan", systemImage: "calendar") { router.select(.plan) }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(LifeBoardColorTokens.inkPrimary))
            }
        }
        .task(id: id) { await load() }
    }

    private func load() async {
        guard let repository else { state = .failed("Planning data is unavailable."); return }
        do { state = .loaded(try await repository.fetchOpenPlanningTasks().filter { $0.projectID == id }) }
        catch { state = .failed(error.localizedDescription) }
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
        let seconds = max(0, (run.endedAt ?? run.updatedAt).timeIntervalSince(run.startedAt))
        let minutes = max(1, Int((seconds / 60).rounded()))
        return minutes < 60 ? "\(minutes)m" : "\(minutes / 60)h \(minutes % 60)m"
    }

    private func routineStatusSymbol(_ status: RoutineRunStatus) -> String {
        switch status {
        case .running: "play.circle"
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
            FoundationTaskCaptureHost()
        case .habit:
            FoundationHabitCaptureHost()
        case .journal:
            if V2FeatureFlags.journalV1Enabled, let phaseIIRepository {
                NavigationStack { LifeBoardJournalModuleView(repository: phaseIIRepository) }
            } else { EmptyView() }
        case .note:
            if V2FeatureFlags.knowledgeNotesV1Enabled, let phaseIIRepository {
                NavigationStack { LifeBoardKnowledgeModuleView(repository: phaseIIRepository) }
            } else { EmptyView() }
        case .trackerEntry:
            if V2FeatureFlags.trackersV1Enabled, let phaseIIRepository {
                NavigationStack {
                    LifeBoardTrackRootView(
                        repository: phaseIIRepository,
                        initialModule: .trackers,
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
    @StateObject private var viewModel = PresentationDependencyContainer.shared.makeNewAddTaskViewModel()

    var body: some View {
        SunriseAddTaskSheetView(viewModel: viewModel)
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
