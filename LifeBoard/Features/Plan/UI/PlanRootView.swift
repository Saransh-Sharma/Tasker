import SwiftUI
import UIKit

struct PlanRootView: View {
    private let onOpenFocus: (UUID) -> Void
    private let onAskEva: () -> Void
    private let onOpenWeeklyPlanner: () -> Void
    private let onOpenWeeklyReview: () -> Void
    private let onOpenOverdueRescue: (OverdueRescueLaunchContext) -> Void
    private let onReviewCapture: (InboxItem) -> Void
    private let onOpenTask: (UUID) -> Void
    private let onOpenProject: (UUID) -> Void
    private let taskBatchCoordinator: TaskBatchMutationCoordinator
    private let projectTemplateService: ProjectTemplateInstantiationService
    private let projectRepository: any ProjectRepositoryProtocol
    private let sectionRepository: (any SectionRepositoryProtocol)?
    private let tagRepository: any TagRepositoryProtocol
    @Environment(\.planRescueRefreshGeneration) private var rescueRefreshGeneration
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    private var usesTimeline: Bool {
        lens == .day && dayPresentation == .canvas && !dynamicTypeSize.isAccessibilitySize && !voiceOverEnabled
    }
    @State var store: PlanStore
    @State private var inboxStore: InboxStore
    @State private var taskExecutionStore: TaskExecutionStore
    @State private var lens: PlanLens = .day
    @State private var dayPresentation: PlanDayPresentation = .canvas
    @State private var scheduleGrouping: PlanScheduleGrouping = .timeOfDay
    @State private var showsBlockComposer = false
    @State private var showsWorkingHours = false
    @State private var showsTaskLibrary = false
    @State private var showsProjectTemplates = false
    @State private var showsMakeItFitToday = false
    @State private var projectTemplateReceipt: ProjectTemplateCreationReceipt?
    @State var projectTemplateError: String?
    @State var selectedTaskIDs: Set<UUID> = []
    @State var pendingBacklogDeletionTaskIDs: Set<UUID> = []
    @State var showsBacklogDeletionConfirmation = false
    @FocusState private var focusedWeekTaskID: UUID?
    @State private var backlogSearch = ""
    @State private var backlogContextFilter: BacklogContextFilter = .all
    @State private var backlogReadinessFilter: BacklogReadinessFilter = .all
    @State private var backlogEnergyFilter: BacklogEnergyFilter = .all
    @State private var backlogDurationFilter: BacklogDurationFilter = .all
    @State private var backlogProjectFilter: BacklogProjectFilter = .all
    @State private var focusReflectionEnergy = 3
    @State private var focusReflectionNote = ""
    @State private var pendingFocusSetup: FocusSetupContext?
    @State private var pendingFocusEndOutcome: FocusCompletionOutcome?
    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.lifeBoardAtmosphereIsHosted) private var atmosphereIsHosted
    @Environment(\.lifeBoardRootActivity) private var rootActivity

    init(
        dependencies: PlanFeatureDependencies,
        initialLens: PlanLens? = nil,
        onOpenFocus: @escaping (UUID) -> Void = { _ in },
        onAskEva: @escaping () -> Void = {},
        onOpenWeeklyPlanner: @escaping () -> Void = {},
        onOpenWeeklyReview: @escaping () -> Void = {},
        onOpenOverdueRescue: @escaping (OverdueRescueLaunchContext) -> Void = { _ in },
        onReviewCapture: @escaping (InboxItem) -> Void = { _ in },
        onOpenTask: @escaping (UUID) -> Void = { _ in },
        onOpenProject: @escaping (UUID) -> Void = { _ in }
    ) {
        let repository = dependencies.planningRepository
        _store = State(initialValue: PlanStore(
            planningRepository: repository,
            blockRepository: repository,
            scenarioCoordinator: DefaultPlanningScenarioCoordinator(
                planning: repository,
                mutations: repository
            ),
            taskDefinitionRepository: dependencies.taskDefinitionRepository,
            focusCommands: dependencies.focusCommands
        ))
        _inboxStore = State(
            initialValue: InboxStore(
                reader: InboxReader(repository: repository),
                planningRepository: repository,
                mutationRepository: repository,
                commitCoordinator: dependencies.inboxCommitCoordinator
            )
        )
        _taskExecutionStore = State(
            initialValue: TaskExecutionStore(
                query: TaskExecutionQuery(scope: .all, sort: .recentlyUpdated),
                projection: dependencies.taskExecutionProjection
            )
        )
        _lens = State(initialValue: initialLens ?? PlanLensRestoration.load())
        self.onOpenFocus = onOpenFocus
        self.onAskEva = onAskEva
        self.onOpenWeeklyPlanner = onOpenWeeklyPlanner
        self.onOpenWeeklyReview = onOpenWeeklyReview
        self.onOpenOverdueRescue = onOpenOverdueRescue
        self.onReviewCapture = onReviewCapture
        self.onOpenTask = onOpenTask
        self.onOpenProject = onOpenProject
        taskBatchCoordinator = dependencies.taskBatchMutationCoordinator
        projectTemplateService = dependencies.projectTemplateInstantiationService
        projectRepository = dependencies.projectRepository
        sectionRepository = dependencies.sectionRepository
        tagRepository = dependencies.tagRepository
    }


    // The chain that used to hang off this `body` directly — a toolbar, five
    // sheets, a safe-area inset, two alerts and a confirmation dialog — put the
    // whole thing past the type checker's budget once the sections became
    // structs. Each group is applied by its own generic function so the solver
    // sees four small expressions instead of one 120-line one.
    var body: some View {
        withAlerts(withSheets(withLifecycle(chrome)))
    }

    private var chrome: some View {
        canvas
            .navigationTitle("Plan")
            .navigationBarTitleDisplayMode(.inline)
    }

    private var canvas: some View {
        ZStack(alignment: .top) {
            Color.clear.ignoresSafeArea()
            if atmosphereIsHosted == false {
                ScenicBackdrop(
                    scene: .plan,
                    daypart: preferences.resolvedDaypart(),
                    requestedTier: preferences.renderingTier,
                    comfortProfile: preferences.comfortProfile
                )
                .frame(height: 230)
                .clipped()
                .ignoresSafeArea(edges: .top)
            }

            PlanRootScrollContainer(fillsHeight: usesTimeline) {
                VStack(spacing: 16) {
                    HStack(spacing: 8) {
                        LensPicker(
                            "Plan lens",
                            selection: $lens,
                            values: PlanLens.allCases,
                            identifierPrefix: "plan.lens",
                            title: \.rawValue,
                            identifier: \.rawValue
                        )
                        PlanActionsMenu(
                            onStartFocus: startFocusSession,
                            onNewProjectFromTemplate: { showsProjectTemplates = true }
                        )
                    }

                    PlanOrientationBar(
                        store: store,
                        lens: lens,
                        onEditWorkingHours: { showsWorkingHours = true },
                        onAskEva: onAskEva,
                        presentation: .init(
                            showsAgenda: dayPresentation == .agenda || dynamicTypeSize.isAccessibilitySize || voiceOverEnabled,
                            isForced: dynamicTypeSize.isAccessibilitySize || voiceOverEnabled,
                            toggle: { dayPresentation = dayPresentation == .canvas ? .agenda : .canvas }
                        )
                    )

                    switch lens {
                    case .inbox: inboxContent
                    case .day:
                        PlanDaySection(
                            store: store,
                            lens: lens,
                            dayPresentation: $dayPresentation,
                            scheduleGrouping: $scheduleGrouping,
                            showsBlockComposer: $showsBlockComposer,
                            showsWorkingHours: $showsWorkingHours,
                            selectedTaskIDs: $selectedTaskIDs,
                            pendingBacklogDeletionTaskIDs: $pendingBacklogDeletionTaskIDs,
                            showsBacklogDeletionConfirmation: $showsBacklogDeletionConfirmation,
                            pendingFocusSetup: $pendingFocusSetup,
                            pendingFocusEndOutcome: $pendingFocusEndOutcome,
                            focusReflectionEnergy: $focusReflectionEnergy,
                            focusReflectionNote: $focusReflectionNote,
                            onAskEva: onAskEva,
                            onMakeItFit: { showsMakeItFitToday = true },
                            onOpenTask: onOpenTask,
                            onOpenOverdueRescue: onOpenOverdueRescue
                        )
                    case .week:
                        PlanWeekSection(
                            store: store,
                            lens: $lens,
                            focusedWeekTaskID: $focusedWeekTaskID,
                            onOpenTask: onOpenTask,
                            onOpenWeeklyPlanner: onOpenWeeklyPlanner,
                            onOpenWeeklyReview: onOpenWeeklyReview
                        )
                    case .backlog:
                        PlanBacklogSection(
                            store: store,
                            lens: lens,
                            showsTaskLibrary: $showsTaskLibrary,
                            backlogSearch: $backlogSearch,
                            backlogContextFilter: $backlogContextFilter,
                            backlogReadinessFilter: $backlogReadinessFilter,
                            backlogEnergyFilter: $backlogEnergyFilter,
                            backlogDurationFilter: $backlogDurationFilter,
                            backlogProjectFilter: $backlogProjectFilter,
                            selectedTaskIDs: $selectedTaskIDs,
                            pendingBacklogDeletionTaskIDs: $pendingBacklogDeletionTaskIDs,
                            showsBacklogDeletionConfirmation: $showsBacklogDeletionConfirmation,
                            pendingFocusSetup: $pendingFocusSetup,
                            onOpenTask: onOpenTask
                        )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, usesTimeline ? 8 : 40)
            }
            .refreshable { await store.load() }
            .lifeBoardReportsComposerScroll()
            // A containing element: without it this identifier is stamped onto
            // every child and hides theirs (the orientation bar's "plan.header"
            // on pushed Plan routes, which have no shared root header).
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("foundation.plan.scroll")
        }
    }
}

extension PlanRootView {
    /// Plan's root draws its own header and hides the navigation bar, so the
    /// toolbar that used to hold these two actions was invisible at the root.
    /// They now live in the orientation bar's menu, on every Plan surface.
    private func startFocusSession() {
        pendingFocusSetup = .init(
            taskID: nil,
            timeBlockID: nil,
            title: String(localized: "Focus session"),
            suggestedDuration: 25 * 60,
            subtaskID: nil
        )
    }

    private func withLifecycle<Content: View>(_ content: Content) -> some View {
        content
            .task(id: PlanActivityTaskID(activity: rootActivity, rescueGeneration: rescueRefreshGeneration)) {
                guard rootActivity.performsContinuousWork else { return }
                await store.load()
                if let (day, scenario) = HomePlanningHandoff.pending {
                    HomePlanningHandoff.pending = nil
                    store.selectedDay = day
                    await store.load()
                    store.adoptScenario(scenario)
                    lens = .day
                }
                await consumeDayHandoff()
            }
            .onReceive(NotificationCenter.default.publisher(for: PlanDayHandoff.didRequest)) { _ in
                Task { await consumeDayHandoff() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSCalendarDayChanged)) { _ in
                Task { await store.rollToToday() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.significantTimeChangeNotification)) { _ in
                Task { await store.rollToToday() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
                Task { await store.rollToToday() }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await store.rollToToday() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .foundationDomainMaintenanceCommitted)) { _ in
                guard rootActivity.performsContinuousWork else { return }
                Task { await store.load() }
            }
            .onChange(of: lens) { _, selectedLens in
                PlanLensRestoration.save(selectedLens)
            }
    }

    /// "Show in Plan" from a task: lands on the task's day, in the Day lens.
    private func consumeDayHandoff() async {
        guard let day = PlanDayHandoff.pendingDay else { return }
        PlanDayHandoff.pendingDay = nil
        lens = .day
        await store.select(day: day)
    }

    private func withSheets<Content: View>(_ content: Content) -> some View {
        content
            .sheet(isPresented: $showsBlockComposer) {
                PlanBlockComposer(day: store.selectedDay) { title, start, duration in
                    Task { await store.createBlock(title: title, start: start, duration: duration) }
                }
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showsWorkingHours) {
                PlanWorkingHoursComposer(profile: store.workingProfile) { weekdays, start, end, buffer in
                    Task { await store.saveWorkingHours(activeWeekdays: weekdays, startMinute: start, endMinute: end, bufferDuration: buffer) }
                }
            }
            .sheet(isPresented: $showsTaskLibrary) {
                NavigationStack {
                    TaskExecutionLibraryView(
                        store: taskExecutionStore,
                        batchCoordinator: taskBatchCoordinator,
                        projectRepository: projectRepository,
                        sectionRepository: sectionRepository,
                        tagRepository: tagRepository
                    ) { taskID in
                        showsTaskLibrary = false
                        onOpenTask(taskID)
                    }
                }
            }
            .sheet(isPresented: $showsProjectTemplates) {
                ProjectTemplatePicker(
                    service: projectTemplateService
                ) { receipt in
                    projectTemplateReceipt = receipt
                    showsProjectTemplates = false
                }
            }
            .lifeboardCover(isPresented: $showsMakeItFitToday) {
                MakeItFitTodayView(
                    store: store,
                    onOpenTask: { taskID in
                        showsMakeItFitToday = false
                        onOpenTask(taskID)
                    },
                    onClose: { showsMakeItFitToday = false }
                )
            }
            .sheet(item: $pendingFocusSetup) { context in
                FocusSetupSheet(
                    context: context,
                    onCancel: { pendingFocusSetup = nil },
                    onStart: { mode, intention in
                        pendingFocusSetup = nil
                        Task {
                            let started = await store.startFocus(
                                taskID: context.taskID,
                                timeBlockID: context.timeBlockID,
                                targetDuration: mode.initialTargetDuration,
                                mode: mode,
                                intention: intention,
                                subtaskID: context.subtaskID
                            )
                            // Entering a focus session was the quietest action in
                            // the app while dragging a calendar block fired six
                            // haptics. It commits, so it gets the commit haptic —
                            // after the store confirms the session exists, never
                            // for a start that failed. Unscoped sessions open too.
                            guard started, let session = store.activeFocusSession else { return }
                            Haptic.commit.play()
                            onOpenFocus(session.id)
                        }
                    }
                )
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if let receipt = projectTemplateReceipt {
                    projectTemplateReceiptBar(receipt)
                }
            }
    }

    /// One of six hand-rolled receipt bars in the app, now the shared one.
    ///
    /// What the local version got wrong and `ReceiptBar` fixes: it laid Undo and
    /// Open out in a fixed `HStack`, so at accessibility text sizes the message
    /// and both controls competed for one line. The shared bar stacks them.
    private func projectTemplateReceiptBar(
        _ receipt: ProjectTemplateCreationReceipt
    ) -> some View {
        ReceiptBar(
            ActionReceiptPresentation(
                message: "Project created",
                detail: receipt.createdProject.name
            ),
            undo: {
                Task {
                    do {
                        try await projectTemplateService.undo(receipt)
                        projectTemplateReceipt = nil
                    } catch {
                        projectTemplateError = error.localizedDescription
                    }
                }
            },
            destination: .init(title: "Open") {
                onOpenProject(receipt.createdProject.id)
            },
            onDismiss: { projectTemplateReceipt = nil }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
        .accessibilityIdentifier("plan.projectTemplates.receipt")
    }

    private var inboxContent: some View {
        InboxView(store: inboxStore, onReviewCapture: onReviewCapture)
    }
}

/// A day another surface asked Plan to show — the task editor's "Show in Plan".
///
/// Plan's store belongs to the root view, so a caller cannot select a day on
/// it directly. The request is left here and announced; whichever Plan root
/// is mounted consumes it, and one mounted later picks it up when it loads.
@MainActor
enum PlanDayHandoff {
    static var pendingDay: PlanningDay?
    static let didRequest = Notification.Name("lifeboard.plan.showDay")

    static func request(_ day: PlanningDay) {
        pendingDay = day
        NotificationCenter.default.post(name: didRequest, object: nil)
    }
}

private struct PlanActivityTaskID: Hashable {
    let activity: RootActivityState
    let rescueGeneration: Int
}

// MARK: - Shared section vocabulary
//
// Debug builds at `-Onone`, so every SwiftUI temporary gets its own stack slot
// and a computed `some View` property is inlined into its caller's frame. A root
// whose sections are all computed properties therefore builds its entire view
// value inside two frames and walks off the 1 MB main stack during generic
// metadata instantiation — `EXC_BAD_ACCESS (code=2)`, top frame
// `swift::SubstGenericParametersFromMetadata`. Release (`-O`) coalesces the
// slots, so it only ever reproduces in Debug.
//
// The fix is that each `LazyVStack` child is a `struct: View`, which gets its own
// `body` call and therefore its own frame. This mirrors the same repair already
// made in `LifeBoardTrackFoundationViews.swift`.

private struct PlanRootScrollContainer<Content: View>: View {
    let fillsHeight: Bool
    @ViewBuilder let content: () -> Content
    @Environment(\.lifeBoardShellBottomClearance) private var shellBottomClearance
    var body: some View {
        if fillsHeight {
            // Scrolling roots let content pass under the floating composer and
            // dock; a fixed-height day cannot scroll out from under them, so it
            // stops above that chrome instead (and the drawer stays reachable).
            VStack(spacing: 0) {
                content().frame(maxHeight: .infinity, alignment: .top)
                Color.clear.frame(height: shellBottomClearance)
            }
        } else {
            ScrollView { content() }
        }
    }
}

