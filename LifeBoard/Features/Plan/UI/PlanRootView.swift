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
    private let rescueRefreshGeneration: Int
    @State private var store: PlanStore
    @State private var inboxStore: InboxStore
    @State private var taskExecutionStore: TaskExecutionStore
    @State private var lens: PlanLens = .day
    @State private var dayPresentation: PlanDayPresentation = .canvas
    @State private var scheduleGrouping: PlanScheduleGrouping = .timeOfDay
    @State private var showsBlockComposer = false
    @State private var showsWorkingHours = false
    @State private var showsTaskLibrary = false
    @State private var showsProjectTemplates = false
    @State private var projectTemplateReceipt: ProjectTemplateCreationReceipt?
    @State private var projectTemplateError: String?
    @State private var selectedTaskIDs: Set<UUID> = []
    @State private var pendingBacklogDeletionTaskIDs: Set<UUID> = []
    @State private var showsBacklogDeletionConfirmation = false
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

    init(
        dependencies: PlanFeatureDependencies,
        initialLens: PlanLens? = nil,
        rescueRefreshGeneration: Int = 0,
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
        self.rescueRefreshGeneration = rescueRefreshGeneration
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
            .toolbar { planToolbar }
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

            ScrollView {
                LazyVStack(spacing: 16) {
                    LensPicker(
                        "Plan lens",
                        selection: $lens,
                        values: PlanLens.allCases,
                        identifierPrefix: "plan.lens",
                        title: \.rawValue,
                        identifier: \.rawValue
                    )

                    PlanOrientationBar(store: store, lens: lens)

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
                .padding(.bottom, 36)
            }
            .refreshable { await store.load() }
        }
    }

    @ToolbarContentBuilder
    private var planToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                pendingFocusSetup = .init(
                    taskID: nil,
                    timeBlockID: nil,
                    title: "Unscoped focus",
                    suggestedDuration: 25 * 60,
                    subtaskID: nil
                )
            } label: {
                Label("Start unscoped focus", systemImage: "timer")
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("plan.focus.startUnscoped")
            Button {
                showsProjectTemplates = true
            } label: {
                Label("New project from template", systemImage: "folder.badge.plus")
            }
            .frame(minWidth: 44, minHeight: 44)
            .accessibilityIdentifier("plan.projectTemplates.open")
        }
    }

    private func withLifecycle<Content: View>(_ content: Content) -> some View {
        content
            .task(id: rescueRefreshGeneration) { await store.load() }
            .onChange(of: lens) { _, selectedLens in
                PlanLensRestoration.save(selectedLens)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await store.load() }
            }
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
            .sheet(item: $pendingFocusSetup) { context in
                FocusSetupSheet(
                    context: context,
                    onCancel: { pendingFocusSetup = nil },
                    onStart: { mode, intention in
                        pendingFocusSetup = nil
                        Task {
                            await store.startFocus(
                                taskID: context.taskID,
                                timeBlockID: context.timeBlockID,
                                targetDuration: mode.initialTargetDuration,
                                mode: mode,
                                intention: intention,
                                subtaskID: context.subtaskID
                            )
                            if let taskID = context.taskID { onOpenFocus(taskID) }
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

    private func withAlerts<Content: View>(_ content: Content) -> some View {
        content
            .alert("Plan needs attention", isPresented: errorBinding) {
                Button("OK", role: .cancel) { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
            .confirmationDialog(
                backlogDeletionTitle,
                isPresented: $showsBacklogDeletionConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete from LifeBoard", role: .destructive) {
                    let taskIDs = pendingBacklogDeletionTaskIDs
                    pendingBacklogDeletionTaskIDs.removeAll()
                    selectedTaskIDs.subtract(taskIDs)
                    Task { await store.deleteBacklogTasks(taskIDs) }
                }
                Button("Cancel", role: .cancel) { pendingBacklogDeletionTaskIDs.removeAll() }
            } message: {
                Text("These items will disappear from Plan and linked-source pickers on every synced device. You can undo this planning change immediately; LifeBoard keeps a tombstone instead of physically destroying the canonical task.")
            }
            .alert(
                "Project template needs attention",
                isPresented: Binding(
                    get: { projectTemplateError != nil },
                    set: { if $0 == false { projectTemplateError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { projectTemplateError = nil }
            } message: {
                Text(projectTemplateError ?? "")
            }
    }

    private var backlogDeletionTitle: String {
        let count = pendingBacklogDeletionTaskIDs.count
        return count == 1 ? "Delete this backlog item?" : "Delete \(count) backlog items?"
    }



    private func projectTemplateReceiptBar(
        _ receipt: ProjectTemplateCreationReceipt
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "folder.fill.badge.checkmark")
                .foregroundStyle(Color.lifeboard(.statusSuccess))
            VStack(alignment: .leading, spacing: 2) {
                Text("Project created")
                    .font(.subheadline.weight(.semibold))
                Text(receipt.createdProject.name)
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Button("Undo") {
                Task {
                    do {
                        try await projectTemplateService.undo(receipt)
                        projectTemplateReceipt = nil
                    } catch {
                        projectTemplateError = error.localizedDescription
                    }
                }
            }
            .frame(minHeight: 44)
            Button("Open") {
                projectTemplateReceipt = nil
                onOpenProject(receipt.createdProject.id)
            }
            .buttonStyle(.borderedProminent)
            .frame(minHeight: 44)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.lifeboard(.surfacePrimary).opacity(0.98))
        .overlay(alignment: .top) {
            Divider().opacity(0.35)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("plan.projectTemplates.receipt")
    }

    private var inboxContent: some View {
        InboxView(store: inboxStore, onReviewCapture: onReviewCapture)
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil && store.daySnapshot != nil },
            set: { if $0 == false { store.errorMessage = nil } }
        )
    }
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
