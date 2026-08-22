import SwiftUI
import UIKit

extension StarterPack: Identifiable {
    public var id: String { rawValue }
}

struct TrackFoundationRootView: View {
    @State private var store: TrackFoundationStore
    @State private var healthStore = HealthCoordinator.shared.connectionStore
    private let sourcePickerRepository: any TypedSourcePickerRepository
    private let onOpenHabitBoard: () -> Void
    private let onOpenHealth: () -> Void
    private let nutritionRepository: any NutritionRepository
    private let lifeMomentRepository: any LifeMomentRepository
    private let wellnessRepository: any WellnessRepository
    private let fastingTimerStore: FastingTimerStore
    @State private var showsMood = false
    @State private var editingMood: MoodEnergyCheckInValue?
    @State private var showsSleep = false
    @State private var editingSleep: SleepContextRecord?
    @State private var careHistoryDays = 7
    @State private var showsGoal = false
    @State private var editingGoal: GoalDefinition?
    @State private var goalPendingDeletion: GoalDefinition?
    @State private var goalUndoReceipt: GoalTransitionReceipt?
    @State private var showsStarterPacks = false
    @State private var showsRoutineComposer = false
    @State private var showsHabitResilience = false
    @State private var editingRoutine: RoutineDefinition?
    @State private var routinePendingDeletion: RoutineDefinition?
    @State private var showsHydrationTarget = false
    @State private var captureLensTrigger = 0
    // Fasting used to exist only inside the legacy Track root, which was
    // presented as a sheet from inside this one. It is a first-class module
    // here now, so nothing is reachable through the legacy tree alone.
    @State private var fastingSessions: [FastingSessionValue] = []
    @State private var showsFastingComposer = false
    @State private var showsFastingHistory = false
    @State private var fastingError: String?
    @State private var linkingGoal: GoalDefinition?
    @State private var selectedLens: TrackLens = .today
    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.lifeBoardAtmosphereIsHosted) private var atmosphereIsHosted

    init(
        repository: CoreDataTrackFoundationRepository,
        phaseIIRepository: any PhaseIIRepository,
        habitProjectionService: (any TrackHabitProjectionService)? = nil,
        linkedMutationApplier: (any RoutineLinkedMutationApplying)? = nil,
        goalSampleProvider: (any GoalSampleRepository)? = nil,
        starterPackMutationApplier: (any StarterPackCanonicalMutationApplying)? = nil,
        habitRecoveryMutationApplier: (any HabitRecoveryMutationApplying)? = nil,
        sourcePickerRepository: (any TypedSourcePickerRepository)? = nil,
        nutritionRepository: any NutritionRepository,
        lifeMomentRepository: any LifeMomentRepository,
        wellnessRepository: any WellnessRepository,
        initialLens: TrackLens = .today,
        onOpenHabitBoard: @escaping () -> Void = {},
        onOpenHealth: @escaping () -> Void = {}
    ) {
        _store = State(initialValue: TrackFoundationStore(
            repository: repository,
            phaseIIRepository: phaseIIRepository,
            goalSampleProvider: goalSampleProvider,
            habitProjectionService: habitProjectionService,
            linkedMutationApplier: linkedMutationApplier,
            starterPackMutationApplier: starterPackMutationApplier,
            habitRecoveryMutationApplier: habitRecoveryMutationApplier
        ))
        // Fall back to a picker over the repositories we already hold (routines + trackers)
        // when the shell hasn't injected the richer task/habit-aware one.
        self.sourcePickerRepository = sourcePickerRepository
            ?? ComposedTypedSourcePickerRepository(trackFoundation: repository, phaseII: phaseIIRepository)
        self.onOpenHabitBoard = onOpenHabitBoard
        self.onOpenHealth = onOpenHealth
        self.nutritionRepository = nutritionRepository
        self.lifeMomentRepository = lifeMomentRepository
        self.wellnessRepository = wellnessRepository
        fastingTimerStore = FastingTimerStore(
            repository: FastingRepositoryAdapter(repository: phaseIIRepository)
        )
        _selectedLens = State(initialValue: initialLens)
    }

    private var activeFast: FastingSessionValue? {
        fastingSessions.first { $0.endedAt == nil }
    }

    private func reloadFasting() async {
        do {
            fastingSessions = try await fastingTimerStore.sessions(limit: 60)
            fastingError = nil
        } catch {
            fastingError = error.localizedDescription
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear.ignoresSafeArea()
            if atmosphereIsHosted == false {
                AtmosphereView(
                    daypart: preferences.resolvedDaypart(),
                    requestedTier: preferences.renderingTier,
                    comfortProfile: preferences.comfortProfile
                )
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 112 : 180)
                .clipped()
                .ignoresSafeArea(edges: .top)
            }

            ScrollView {
                LazyVStack(spacing: 16) {
                    TrackHeaderSection()
                    TrackQuickLogStrip(
                        store: store,
                        showsMood: $showsMood,
                        editingMood: $editingMood,
                        showsSleep: $showsSleep,
                        editingSleep: $editingSleep
                    )
                    categoryRail
                    categoryContent
                }
                .padding(.horizontal, 20)
                .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 56 : 36)
            }
            .refreshable { await store.load() }
            .lifeBoardReportsComposerScroll()
        }
        // No opaque canvas here. `GrainedCanvas` fills with `foundationCanvas`
        // and ignores the safe area, and the shell's atmosphere is a sibling
        // layer *behind* this root — so painting it full-bleed hid the daypart
        // scene and its celestial on Track alone. Home does not paint one
        // either: its grain rides on `ScenicBackdrop`, which is `Color.clear`
        // whenever the atmosphere is hosted.
        .navigationTitle("Track")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .task { await reloadFasting() }
        .task {
            let updates = await HealthSyncInvalidationService.shared.updates()
            for await _ in updates {
                guard Task.isCancelled == false else { return }
                await store.load()
                await reloadFasting()
            }
        }
        // The presentation chain is split across two modifiers rather than
        // chained inline for the same reason the sections below are structs:
        // see the note on `categoryContent`.
        .modifier(TrackComposerSheets(
            store: store,
            fastingTimerStore: fastingTimerStore,
            sourcePickerRepository: sourcePickerRepository,
            fastingSessions: fastingSessions,
            reloadFasting: { await reloadFasting() },
            showsFastingComposer: $showsFastingComposer,
            showsFastingHistory: $showsFastingHistory,
            fastingError: $fastingError,
            showsMood: $showsMood,
            editingMood: $editingMood,
            showsSleep: $showsSleep,
            editingSleep: $editingSleep,
            showsGoal: $showsGoal,
            editingGoal: $editingGoal,
            linkingGoal: $linkingGoal,
            showsStarterPacks: $showsStarterPacks,
            showsHabitResilience: $showsHabitResilience,
            showsRoutineComposer: $showsRoutineComposer,
            editingRoutine: $editingRoutine,
            showsHydrationTarget: $showsHydrationTarget
        ))
        .modifier(TrackDestructiveDialogs(
            store: store,
            goalUndoReceipt: $goalUndoReceipt,
            routinePendingDeletion: $routinePendingDeletion,
            goalPendingDeletion: $goalPendingDeletion
        ))
        // DESIGN.md reserves `contextLens` for "capture or composer mode
        // handoff", and until now it had exactly one production use in the whole
        // app. Every Track composer is that handoff: the root refracts once as
        // the sheet takes over, which is what makes the sheet feel like it came
        // from here rather than from nowhere.
        .lifeboardContextLens(center: .top, trigger: captureLensTrigger)
        .onChange(of: isPresentingComposer) { _, isPresenting in
            guard isPresenting else { return }
            captureLensTrigger &+= 1
        }
    }

    /// True while any Track composer owns the screen. Used only to fire the
    /// capture lens once per presentation — never to gate content.
    private var isPresentingComposer: Bool {
        showsMood || showsSleep || showsGoal || showsStarterPacks
            || showsRoutineComposer || showsHydrationTarget || showsFastingComposer
    }

    private var categoryRail: some View {
        LensPicker(
            "Track lens",
            selection: $selectedLens,
            values: TrackLens.allCases,
            identifierPrefix: "track.lens",
            title: \.title,
            identifier: \.rawValue
        )
        .lifeBoardMotion(.selection, value: selectedLens)
        .accessibilityIdentifier("track.lens")
    }

    /// Every module below is a `View` struct rather than a computed
    /// `some View` property, and it has to stay that way.
    ///
    /// A computed property is inlined into its caller's frame, so the whole
    /// screen's view value used to be built inside two frames — `body` and this
    /// getter. Debug builds at `-Onone`, which gives every SwiftUI temporary its
    /// own stack slot instead of reusing them, and once this branch carried five
    /// modules the getter walked off the bottom of the main thread's 1 MB stack
    /// during generic metadata instantiation: `EXC_BAD_ACCESS (code=2)` on the
    /// guard page, on launch, before a single pixel was drawn.
    ///
    /// A struct gets its own `body` call and therefore its own frame. Add the
    /// next module as a struct too; do not fold one back into a property, and do
    /// not collapse a whole lens into a single wrapper — `LazyVStack` needs one
    /// child per module to stay lazy.
    @ViewBuilder private var categoryContent: some View {
        switch selectedLens {
        case .today:
            TrackDueAndUnresolvedSection(store: store)
            TrackHealthSummarySection(healthStore: healthStore, onOpenHealth: onOpenHealth)
            // A running fast is time-sensitive, so it earns a place in Today.
            // When nothing is running it stays in Body rather than adding a
            // permanent empty module to the day.
            if activeFast != nil { fastingModule(isHero: true) }
            TrackTodayRoutinesSection(store: store)
            TrackCareSnapshotSection(
                store: store,
                showsMood: $showsMood,
                editingMood: $editingMood,
                showsSleep: $showsSleep,
                showsHydrationTarget: $showsHydrationTarget,
                onOpenHabitBoard: onOpenHabitBoard,
                onOpenHealth: onOpenHealth
            )
        case .areas:
            TrackBodyCareSection(
                store: store,
                careHistoryDays: $careHistoryDays,
                showsSleep: $showsSleep,
                editingSleep: $editingSleep,
                showsHydrationTarget: $showsHydrationTarget,
                onOpenHabitBoard: onOpenHabitBoard,
                onOpenHealth: onOpenHealth
            )
            if activeFast == nil { fastingModule(isHero: false) }
            TrackMindCareSection(
                store: store,
                showsMood: $showsMood,
                editingMood: $editingMood
            )
            TrackRoutinesAndHabitsSection(
                store: store,
                showsRoutineComposer: $showsRoutineComposer,
                editingRoutine: $editingRoutine,
                routinePendingDeletion: $routinePendingDeletion,
                showsHabitResilience: $showsHabitResilience,
                onOpenHabitBoard: onOpenHabitBoard
            )
            TrackGoalsSection(
                store: store,
                showsGoal: $showsGoal,
                editingGoal: $editingGoal,
                linkingGoal: $linkingGoal,
                goalPendingDeletion: $goalPendingDeletion,
                goalUndoReceipt: $goalUndoReceipt
            )
            TrackModulesSection(
                store: store,
                nutritionRepository: nutritionRepository,
                lifeMomentRepository: lifeMomentRepository,
                wellnessRepository: wellnessRepository,
                showsStarterPacks: $showsStarterPacks
            )
        case .history:
            TrackHistorySection(
                store: store,
                fastingSessions: fastingSessions,
                careHistoryDays: $careHistoryDays,
                showsSleep: $showsSleep,
                editingSleep: $editingSleep
            )
        }
    }

    /// - Parameter isHero: whether this lens has nominated fasting as its one
    ///   hero. Only Today does, and only while a fast is actually running: in
    ///   Areas the module is a resting entry point among several peers, and
    ///   giving it glass there would make an idle timer the loudest thing on a
    ///   screen about routines, goals and body care.
    private func fastingModule(isHero: Bool) -> TrackFastingSection {
        TrackFastingSection(
            fastingTimerStore: fastingTimerStore,
            sessions: fastingSessions,
            fastingError: $fastingError,
            showsFastingComposer: $showsFastingComposer,
            showsFastingHistory: $showsFastingHistory,
            reloadFasting: { await reloadFasting() },
            isHero: isHero
        )
    }
}

// MARK: - Track section chrome
//
// These are the pieces more than one module draws. They are structs for the
// same stack-budget reason as the modules themselves — see `categoryContent`.

private struct TrackEmptyStateRow: View {
    private let title: String
    private let detail: String
    private let symbol: String

    init(_ title: String, detail: String, symbol: String) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
    }

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            Spacer()
        }.trackClayCard()
    }
}

private struct TrackModuleRow: View {
    private let title: String
    private let detail: String
    private let symbol: String

    init(_ title: String, detail: String, symbol: String) {
        self.title = title
        self.detail = detail
        self.symbol = symbol
    }

    var body: some View {
        rowBody
            .lifeBoardTransitionSource("track.module.\(title)")
    }

    private var rowBody: some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title3).frame(width: 28).foregroundStyle(Color(SemanticColorTokens.foundationFocusRing))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            Spacer()
            Image(systemName: "chevron.right")
        }.trackClayCard()
    }
}

private struct TrackCareTile: View {
    let title: String
    let value: String
    let symbol: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: symbol).font(.headline)
                Text(value).font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "plus.circle").frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(minHeight: 112, alignment: .topLeading)
            .trackClayCard()
        }
        .buttonStyle(.plain)
    }
}

private struct TrackBehaviorAreaLink: View {
    let repository: any PhaseIIRepository
    let area: BehaviorNativeAreasView.Area
    let title: String
    let value: String
    let symbol: String
    let onOpenHabitBoard: () -> Void
    let onOpenHealth: () -> Void

    var body: some View {
        NavigationLink {
            BehaviorAreaRouteView(
                repository: repository,
                initialArea: area,
                onOpenHabitBoard: onOpenHabitBoard,
                onOpenHealth: onOpenHealth
            )
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Label(title, systemImage: symbol).font(.headline)
                Text(value).font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(minHeight: 112, alignment: .topLeading)
            .trackClayCard()
        }
        .buttonStyle(.plain)
    }
}

private struct TrackHistoryRow: View {
    let symbol: String
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.body.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct TrackHydrationTile: View {
    let store: TrackFoundationStore
    @Binding var showsHydrationTarget: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Hydration", systemImage: "drop.fill")
                .font(.headline)
            Text(TrackSectionCopy.hydrationLabel(store)).font(.title3.weight(.semibold))
            if let amount = store.snapshot.hydrationAmountMilliliters, let target = store.snapshot.hydrationTargetMilliliters, target > 0 {
                ProgressView(value: min(1, amount / target)).tint(Color(SemanticColorTokens.foundationSageAccent))
                Button("Edit target") { showsHydrationTarget = true }
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("track.hydration.target")
            } else {
                HStack(spacing: 8) {
                    Text("No target yet")
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    Spacer(minLength: 0)
                    Button("Set target") { showsHydrationTarget = true }
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("track.hydration.target")
                }
            }
            HStack(spacing: 8) {
                Button("+250 ml") {
                    Task { await store.quickAddHydration(250); await trackOfferHealthConnect() }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("track.hydration.add250")
                Button("+500 ml") {
                    Task { await store.quickAddHydration(500); await trackOfferHealthConnect() }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("track.hydration.add500")
            }
            .buttonStyle(.lifeBoardChip)
        }
        .trackClayCard()
        .accessibilityIdentifier("track.hydration")
    }
}

private struct TrackHydrationHistoryRow: View {
    let store: TrackFoundationStore
    let log: HydrationLog

    var body: some View {
        let amount = HydrationMeasurementService.milliliters(log.amount, unit: log.unit)
        HStack(spacing: 12) {
            Image(systemName: "drop.fill").foregroundStyle(Color(SemanticColorTokens.foundationSageAccent))
            VStack(alignment: .leading, spacing: 4) {
                Text("\(Int(amount)) ml").font(.body.weight(.medium))
                Text(log.timestamp.formatted(date: .omitted, time: .shortened) + (log.correctedAt == nil ? "" : " · corrected"))
                    .font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            Spacer()
            Menu {
                Button("Add 50 ml") { Task { await store.correctHydration(log, amountMilliliters: amount + 50) } }
                Button("Remove 50 ml") { Task { await store.correctHydration(log, amountMilliliters: max(0, amount - 50)) } }
                if let receipt = store.activeCorrection(domain: .hydration, sourceID: log.id) {
                    Button("Undo last correction", systemImage: "arrow.uturn.backward") {
                        Task { await store.undoCorrection(receipt) }
                    }
                }
                Button("Delete entry", systemImage: "trash", role: .destructive) { Task { await store.deleteHydration(log) } }
            } label: { Image(systemName: "ellipsis.circle") }
        }
        .padding(.vertical, 8)
        .accessibilityIdentifier("track.hydration.history.\(log.id.uuidString)")
    }
}

private struct TrackSleepHistoryRow: View {
    let store: TrackFoundationStore
    let record: SleepContextRecord
    @Binding var showsSleep: Bool
    @Binding var editingSleep: SleepContextRecord?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz").foregroundStyle(Color(SemanticColorTokens.foundationSageAccent))
            VStack(alignment: .leading, spacing: 4) {
                Text("\(record.bedtime.formatted(date: .abbreviated, time: .shortened))–\(record.wakeTime.formatted(date: .omitted, time: .shortened))")
                    .font(.body.weight(.medium))
                Text(record.perceivedRest.map { "Rest \($0)/5 · \(record.interruptionCount) interruptions" } ?? "\(record.interruptionCount) interruptions")
                    .font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            Spacer()
            Menu {
                Button("Edit", systemImage: "pencil") {
                    editingSleep = record
                    showsSleep = true
                }
                if let receipt = store.activeCorrection(domain: .sleep, sourceID: record.id) {
                    Button("Undo last correction", systemImage: "arrow.uturn.backward") {
                        Task { await store.undoCorrection(receipt) }
                    }
                }
                Button("Delete", systemImage: "trash", role: .destructive) { Task { await store.deleteSleep(record) } }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Actions for sleep context")
        }
        .padding(.vertical, 8)
        .privacySensitive()
    }
}

private struct TrackQuickLogButton: View {
    let title: String
    let detail: String
    let symbol: String
    let identifier: String
    let action: () -> Void

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    /// Opaque under Reduce Transparency, with the same geometry. Glass is the
    /// enhancement; the capture affordance is not.
    @ViewBuilder
    private var quickLogSurface: some View {
        if reduceTransparency {
            RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                .fill(Color.lifeboard(.bgElevated))
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .stroke(Color.lifeboard(.strokeStrong), lineWidth: 1)
                )
        } else {
            Color.clear.lifeBoardSystemGlass(
                .regular,
                in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous),
                interactive: true
            )
        }
    }

    var body: some View {
        Button {
            Haptic.pick.play()
            action()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background(
                        Color(SemanticColorTokens.foundationSurfaceSelected),
                        in: Circle()
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 56)
            // Glass, because a quick-log button is a control rather than
            // content — it captures rather than reports. `DESIGN.md` reserves
            // the control layer for exactly this, and it is what separates the
            // strip from the recorded cards below it.
            .background { quickLogSurface }
            .contentShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .lifeBoardPressResponse(.control, haptic: nil)
        .accessibilityIdentifier(identifier)
    }
}

private struct TrackHabitQualitySummary: View {
    let store: TrackFoundationStore

    var body: some View {
        let graded = store.snapshot.habitGrades.compactMap(\.grade)
        let average = graded.isEmpty ? nil : graded.reduce(0, +) / Double(graded.count)
        let streak = store.snapshot.habitGrades.map(\.streak).max() ?? 0
        HStack(spacing: 12) {
            metric(
                title: "30-day grade",
                value: average.map { "\(Int(($0 * 100).rounded()))%" } ?? "Building",
                symbol: "chart.line.uptrend.xyaxis"
            )
            metric(title: "Current streak", value: "\(streak) days", symbol: "flame")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("track.habitQuality")
    }

    private func metric(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(12)
        // `ClaySurfaceModifier` strokes the hairline itself. The overlay that
        // used to follow this line drew a second one on the same boundary.
        .lifeBoardClaySurface(.raised)
    }
}

private struct TrackMoodTrendView: View {
    let store: TrackFoundationStore

    var body: some View {
        switch MoodTrendProjector.project(store.checkIns) {
        case .empty:
            TrackEmptyStateRow("No mood trend yet", detail: "Check in when it feels useful. Missing data is never treated as neutral.", symbol: "chart.line.downtrend.xyaxis")
        case let .light(sampleCount):
            TrackEmptyStateRow(
                "A trend needs a little more context",
                detail: "\(sampleCount) of 3 check-ins recorded. LifeBoard will not infer a pattern yet.",
                symbol: "ellipsis"
            )
        case let .ready(summary):
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("30-day rhythm").font(.headline)
                        Text(TrackSectionCopy.moodTrendDescription(summary))
                            .font(.caption)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                    Spacer()
                    Text("\(summary.sampleCount) check-ins")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                MoodTrendStrip(points: summary.dailyPoints)
            }
            .trackClayCard()
            .privacySensitive()
            .accessibilityElement(children: .combine)
        }
    }
}

// MARK: - Track section copy and derivations
//
// Shared by more than one module. Keeping them in one namespace is what stops
// the same date-window or label logic being pasted into each section struct.

@MainActor
enum TrackSectionCopy {
    static func careGridColumns(_ dynamicTypeSize: DynamicTypeSize) -> [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 12)]
        }
        return [GridItem(.adaptive(minimum: 150), spacing: 12)]
    }

    static func daypartTitle(_ preferences: PresentationPreferences) -> String {
        switch preferences.resolvedDaypart() {
        case .morning: "Good morning"
        case .afternoon: "Good afternoon"
        case .evening: "Good evening"
        case .night: "A gentler night"
        }
    }

    static func daypartSymbol(_ preferences: PresentationPreferences) -> String {
        switch preferences.resolvedDaypart() {
        case .morning: "sunrise"
        case .afternoon: "sun.max"
        case .evening: "sunset"
        case .night: "moon.stars"
        }
    }

    static func latestMood(_ store: TrackFoundationStore) -> String {
        guard let latest = store.checkIns.first else { return "Check in when useful" }
        return latest.energy.map { "\(latest.mood.title) · energy \($0)/5" } ?? latest.mood.title
    }

    static func latestSleep(_ store: TrackFoundationStore) -> String {
        guard let record = store.sleepRecords.first else { return "No manual context" }
        return record.perceivedRest.map { "Rest \($0)/5" } ?? "Recorded"
    }

    static func hydrationLabel(_ store: TrackFoundationStore) -> String {
        guard let amount = store.snapshot.hydrationAmountMilliliters else { return "No data yet" }
        if let target = store.snapshot.hydrationTargetMilliliters { return "\(Int(amount)) / \(Int(target)) ml" }
        return "\(Int(amount)) ml"
    }

    static func moodCheckInDetail(_ checkIn: MoodEnergyCheckInValue) -> String {
        let time = checkIn.createdAt.formatted(date: .abbreviated, time: .shortened)
        guard let energy = checkIn.energy else { return time }
        return "Energy \(energy)/5 · \(time)"
    }

    static func moodTrendDescription(_ summary: MoodTrendSummary) -> String {
        let feeling: String
        switch summary.averageValence {
        case 1.5...: feeling = "mostly lighter"
        case ..<(-1.5): feeling = "mostly heavier"
        default: feeling = "varied"
        }
        guard let energy = summary.averageEnergy else { return "Your recorded mood has felt \(feeling). Energy was not consistently recorded." }
        return "Your recorded mood has felt \(feeling), with average energy \(energy.formatted(.number.precision(.fractionLength(1))))/5."
    }

    static func progressLabel(_ progress: GoalProgressSnapshot?) -> String {
        guard let progress else { return "Not linked" }
        if let fraction = progress.progressFraction { return "\(Int(fraction * 100))%" }
        return progress.missingLinkCount > 0 ? "Data incomplete" : "Ready"
    }

    static func starterPackTitle(_ pack: StarterPack) -> String {
        switch pack {
        case .morningFoundation: "Morning Foundation"
        case .workdayReset: "Workday Reset"
        case .lowEnergyRecovery: "Low Energy Recovery"
        case .medicationSupport: "Medication Support"
        case .eveningWindDown: "Evening Wind-down"
        }
    }

    static func fastingClock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%d:%02d:%02d", total / 3_600, (total % 3_600) / 60, total % 60)
    }

    /// The care lenses and History share one window, expressed in whole days
    /// back from the start of today so a record logged this morning is never
    /// filtered out by a clock-time cutoff.
    static func careHistoryCutoff(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -(days - 1), to: Calendar.current.startOfDay(for: Date())) ?? .distantPast
    }

    static func historyCutoff(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
    }

    static func hydrationHistory(_ store: TrackFoundationStore, days: Int) -> [HydrationLog] {
        store.hydrationHistory.filter { $0.timestamp >= careHistoryCutoff(days: days) }
    }

    static func sleepHistory(_ store: TrackFoundationStore, days: Int) -> [SleepContextRecord] {
        store.sleepRecords.filter { $0.bedtime >= careHistoryCutoff(days: days) }
    }

    static func fastingHistory(_ sessions: [FastingSessionValue], days: Int) -> [FastingSessionValue] {
        sessions
            .filter { $0.endedAt != nil && $0.startedAt >= historyCutoff(days: days) }
            .sorted { $0.startedAt > $1.startedAt }
    }

    static func routineHistory(_ store: TrackFoundationStore, days: Int) -> [RoutineRun] {
        store.routineRuns
            .filter { $0.startedAt >= historyCutoff(days: days) }
            .sorted { $0.startedAt > $1.startedAt }
            .prefix(12)
            .map { $0 }
    }

    static func routineTitle(_ store: TrackFoundationStore, for run: RoutineRun) -> String {
        store.routines.first { $0.id == run.routineID }?.title ?? "Routine"
    }

    static func goalTitle(_ store: TrackFoundationStore, for id: UUID) -> String {
        store.definitions.first { $0.id == id }?.title ?? "Goal"
    }
}

/// After a hydration log lands (and its fill animates), gently invite a
/// not-yet-connected user to mirror water with Apple Health. Never blocks.
@MainActor
private func trackOfferHealthConnect() async {
    await HealthCoordinator.shared.jitCoordinator.offerConnectAfterReward(
        leadDomain: .hydration,
        trigger: "track_hydration_quick_add"
    )
}

// MARK: - Track modules

/// The greeting, with the day's position beside it.
///
/// Track is where a person records what their day was actually like, so which
/// part of the day it is now is load-bearing context rather than decoration.
/// `CelestialDaypartIndicator` answers it with the same sun and moon artwork the
/// scenic backdrop uses — `CelestialDawn` through `CelestialNight` — riding an
/// arc at the height the real clock has reached.
///
/// The scenic celestial behind the header is deliberately anchored away from the
/// reading column so it never sits behind the greeting, which means the backdrop
/// alone cannot answer "how much of the day is left". This can, at a glance, and
/// it carries a VoiceOver description the backdrop does not.
private struct TrackHeaderSection: View {
    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let palette = DaypartTokens.appearancePalette(for: preferences.resolvedDaypart(), colorScheme: colorScheme)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 16))

        layout {
            VStack(alignment: .leading, spacing: 6) {
                Text(TrackSectionCopy.daypartTitle(preferences))
                    .font(Typography.screenTitle())
                    .foregroundStyle(palette.color(for: .foreground))
                Text("What would feel useful to record?")
                    .font(Typography.body())
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Below the greeting at accessibility sizes rather than shrunk
            // beside it: `DESIGN.md` forbids shrinking to preserve a one-line
            // layout, and an arc this small stops being readable before the
            // text does.
            CelestialDaypartIndicator()
                .frame(width: dynamicTypeSize.isAccessibilitySize ? 132 : 96, height: 52)
                .accessibilityIdentifier("track.header.daypart")
        }
        .padding(.top, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("track.header")
    }
}

private struct TrackQuickLogStrip: View {
    let store: TrackFoundationStore
    @Binding var showsMood: Bool
    @Binding var editingMood: MoodEnergyCheckInValue?
    @Binding var showsSleep: Bool
    @Binding var editingSleep: SleepContextRecord?
    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let palette = DaypartTokens.appearancePalette(for: preferences.resolvedDaypart(), colorScheme: colorScheme)
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick log")
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.color(for: .foregroundSecondary))

            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    TrackQuickLogButton(
                        title: "Water",
                        detail: "+250 mL",
                        symbol: "drop.fill",
                        identifier: "track.quick.water"
                    ) {
                        Task {
                            await store.quickAddHydration(250)
                            await trackOfferHealthConnect()
                        }
                    }
                    trackersLink
                    TrackQuickLogButton(
                        title: "Mood",
                        detail: TrackSectionCopy.latestMood(store),
                        symbol: "face.smiling",
                        identifier: "track.quick.mood"
                    ) {
                        editingMood = nil
                        showsMood = true
                    }
                    TrackQuickLogButton(
                        title: "Sleep",
                        detail: TrackSectionCopy.latestSleep(store),
                        symbol: "moon.zzz",
                        identifier: "track.quick.sleep"
                    ) {
                        editingSleep = nil
                        showsSleep = true
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var trackersLink: some View {
        NavigationLink {
            BehaviorAreaRouteView(
                repository: store.phaseIIRepository,
                initialArea: .trackers
            )
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "square.grid.3x3.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .background(
                        Color(SemanticColorTokens.foundationSurfaceSelected),
                        in: Circle()
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Trackers")
                        .font(.subheadline.weight(.semibold))
                    Text("Your own")
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 56)
            .lifeBoardClaySurface(.well, cornerRadius: 16)
            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded { Haptic.pick.play() })
        .accessibilityIdentifier("track.quick.trackers")
    }
}

private struct TrackDueAndUnresolvedSection: View {
    let store: TrackFoundationStore

    var body: some View {
        if !store.snapshot.unresolvedMedicationEvents.isEmpty {
            // 16 rather than 12: this module used to be a `@ViewBuilder`
            // property whose header and cards landed directly in the screen's
            // `LazyVStack(spacing: 16)`. Now that it is one child, the spacing
            // has to be restated here to look the same.
            VStack(spacing: 16) {
                SectionHeader("Needs a decision", symbol: "exclamationmark.circle")
                ForEach(store.snapshot.unresolvedMedicationEvents) { event in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "pills.fill").foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
                            VStack(alignment: .leading) {
                                Text(store.medicationName(id: event.medicationID)).font(.headline)
                                Text(event.status == .unresolved ? "The window passed — choose what happened" : "Scheduled \(event.scheduledAt.formatted(date: .omitted, time: .shortened))")
                                    .font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                            Spacer()
                        }
                        HStack {
                            Button("Taken") { Task { await store.resolveMedication(event: event, status: .taken) } }.buttonStyle(.lifeBoardPrimaryCompact)
                            Button("Skipped") { Task { await store.resolveMedication(event: event, status: .skipped) } }.buttonStyle(.bordered)
                            Button("Snooze 15m") { Task { await store.snoozeMedication(event: event) } }.buttonStyle(.bordered)
                        }
                        .controlSize(.small)
                    }
                    .trackClayCard()
                    .accessibilityIdentifier("track.medication.\(event.id.uuidString)")
                }
            }
        }
    }
}

private struct TrackHealthSummarySection: View {
    let healthStore: HealthConnectionStore
    let onOpenHealth: () -> Void

    var body: some View {
        Button(action: onOpenHealth) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("From Apple Health", systemImage: "heart.text.clipboard")
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }

                HStack(alignment: .firstTextBaseline, spacing: 18) {
                    value(.steps, title: "Steps")
                    value(.activeEnergy, title: "Active")
                    value(.walkingRunningDistance, title: "Distance")
                }

                Text(status)
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.resting, cornerRadius: 20)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("track.healthSummary")
    }

    private func value(_ metric: HealthMetric, title: String) -> some View {
        let aggregate = healthStore.aggregates[metric]
        return VStack(alignment: .leading, spacing: 2) {
            Text(aggregate.map { Self.text($0.value, metric: metric) } ?? "—")
                .font(.title3.weight(.bold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var status: String {
        if healthStore.isRefreshing { return "Updating from Apple Health…" }
        if let date = healthStore.lastSuccessfulSync {
            return "Updated \(date.formatted(.relative(presentation: .named)))"
        }
        return HealthAuthorizationPromptState.hasRequested
            ? "No recent Health records"
            : "Connect Apple Health to see movement here"
    }

    private static func text(_ value: Double, metric: HealthMetric) -> String {
        switch metric {
        case .steps: value.formatted(.number.precision(.fractionLength(0)))
        case .walkingRunningDistance: "\((value / 1_000).formatted(.number.precision(.fractionLength(1)))) km"
        case .activeEnergy: "\(Int(value)) kcal"
        default: value.formatted(.number.precision(.fractionLength(0...1)))
        }
    }
}

/// Fasting as a first-class Track module. Leads with the running timer
/// when there is one, because that is the only state that is time-sensitive.
/// Hero glass when this lens nominated fasting, raised clay otherwise.
///
/// A `ViewModifier` rather than an `if` around the whole card body: branching on
/// the material inside the view would give SwiftUI two structurally different
/// subtrees, and the running timer's `TimelineView` would be torn down and
/// rebuilt — restarting the ember ring — every time the nomination changed.
private struct TrackTodayRoutinesSection: View {
    let store: TrackFoundationStore

    var body: some View {
        if store.snapshot.dueRoutines.isEmpty == false {
            // See `TrackDueAndUnresolvedSection` on why this is 16.
            VStack(spacing: 16) {
                SectionHeader("Useful today", symbol: "sun.max")
                ForEach(store.snapshot.dueRoutines) { routine in
                    Button { Task { await store.startRoutine(routine) } } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "play.circle.fill")
                                .font(.title2)
                                .foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(routine.title).font(.headline)
                                Text("\(routine.steps.count) calm steps")
                                    .font(.caption)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .trackClayCard()
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct TrackCareSnapshotSection: View {
    let store: TrackFoundationStore
    @Binding var showsMood: Bool
    @Binding var editingMood: MoodEnergyCheckInValue?
    @Binding var showsSleep: Bool
    @Binding var showsHydrationTarget: Bool
    let onOpenHabitBoard: () -> Void
    let onOpenHealth: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader("Care snapshot", symbol: "heart.text.square")
            TrackHydrationTile(store: store, showsHydrationTarget: $showsHydrationTarget)
            LazyVGrid(columns: TrackSectionCopy.careGridColumns(dynamicTypeSize), spacing: 12) {
                TrackCareTile(title: "Mood + energy", value: TrackSectionCopy.latestMood(store), symbol: "face.smiling") {
                    editingMood = nil
                    showsMood = true
                }
                TrackBehaviorAreaLink(
                    repository: store.phaseIIRepository,
                    area: .medication,
                    title: "Medication",
                    value: store.snapshot.unresolvedMedicationEvents.isEmpty ? "Up to date" : "Decision needed",
                    symbol: "pills",
                    onOpenHabitBoard: onOpenHabitBoard,
                    onOpenHealth: onOpenHealth
                )
                TrackCareTile(title: "Sleep context", value: TrackSectionCopy.latestSleep(store), symbol: "moon.zzz") { showsSleep = true }
                    .privacySensitive()
            }
        }
    }
}

private struct TrackBodyCareSection: View {
    let store: TrackFoundationStore
    @Binding var careHistoryDays: Int
    @Binding var showsSleep: Bool
    @Binding var editingSleep: SleepContextRecord?
    @Binding var showsHydrationTarget: Bool
    let onOpenHabitBoard: () -> Void
    let onOpenHealth: () -> Void
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        let hydrationHistory = TrackSectionCopy.hydrationHistory(store, days: careHistoryDays)
        let sleepHistory = TrackSectionCopy.sleepHistory(store, days: careHistoryDays)
        VStack(spacing: 12) {
            SectionHeader("Body", symbol: "heart.text.square")
            TrackHydrationTile(store: store, showsHydrationTarget: $showsHydrationTarget)
            LazyVGrid(columns: TrackSectionCopy.careGridColumns(dynamicTypeSize), spacing: 12) {
                TrackBehaviorAreaLink(
                    repository: store.phaseIIRepository,
                    area: .medication,
                    title: "Medication",
                    value: store.snapshot.unresolvedMedicationEvents.isEmpty ? "Up to date" : "Decision needed",
                    symbol: "pills",
                    onOpenHabitBoard: onOpenHabitBoard,
                    onOpenHealth: onOpenHealth
                )
                TrackCareTile(title: "Sleep context", value: TrackSectionCopy.latestSleep(store), symbol: "moon.zzz") { showsSleep = true }
                    .privacySensitive()
            }
            if !store.hydrationHistory.isEmpty || !store.sleepRecords.isEmpty {
                OptionRail(
                    "Care history range",
                    selection: $careHistoryDays,
                    values: [7, 30],
                    identifierPrefix: "track.care.historyRange",
                    title: { "\($0) days" },
                    showsLabel: false
                )
            }
            if !hydrationHistory.isEmpty {
                SectionHeader("Hydration history", symbol: "drop")
                ForEach(hydrationHistory) { TrackHydrationHistoryRow(store: store, log: $0) }
            }
            if !sleepHistory.isEmpty {
                SectionHeader("Recent sleep context", symbol: "moon.zzz")
                ForEach(sleepHistory) { record in
                    TrackSleepHistoryRow(
                        store: store,
                        record: record,
                        showsSleep: $showsSleep,
                        editingSleep: $editingSleep
                    )
                }
            }
            Button(action: onOpenHealth) {
                // Fasting is its own module now, so it no longer belongs in
                // this row's promise.
                TrackModuleRow("Health and care library", detail: "Medication, trackers, steps, and active energy", symbol: "heart.circle")
            }
            .buttonStyle(.plain)
        }
    }
}

private struct TrackMindCareSection: View {
    let store: TrackFoundationStore
    @Binding var showsMood: Bool
    @Binding var editingMood: MoodEnergyCheckInValue?

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader("Mind", symbol: "brain.head.profile")
            TrackCareTile(title: "Mood + energy", value: TrackSectionCopy.latestMood(store), symbol: "face.smiling") {
                editingMood = nil
                showsMood = true
            }
            TrackMoodTrendView(store: store)
            if !store.checkIns.isEmpty {
                SectionHeader("Recent check-ins", symbol: "clock.arrow.circlepath")
                ForEach(Array(store.checkIns.prefix(8)), id: \.id) { checkIn in
                    HStack(spacing: 12) {
                        Image(systemName: "face.smiling").foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(checkIn.mood.title).font(.body.weight(.medium))
                            Text(TrackSectionCopy.moodCheckInDetail(checkIn))
                                .font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        }
                        Spacer()
                        Menu {
                            Button("Edit", systemImage: "pencil") {
                                editingMood = checkIn
                                showsMood = true
                            }
                            if let receipt = store.activeCorrection(domain: .mood, sourceID: checkIn.id) {
                                Button("Undo last correction", systemImage: "arrow.uturn.backward") {
                                    Task { await store.undoCorrection(receipt) }
                                }
                            }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                Task { await store.deleteMood(checkIn) }
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 44, height: 44)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel("Actions for \(checkIn.mood.title) check-in")
                    }
                    .padding(.vertical, 6)
                    .privacySensitive()
                }
            }
        }
    }
}

private struct TrackRoutinesAndHabitsSection: View {
    let store: TrackFoundationStore
    @Binding var showsRoutineComposer: Bool
    @Binding var editingRoutine: RoutineDefinition?
    @Binding var routinePendingDeletion: RoutineDefinition?
    @Binding var showsHabitResilience: Bool
    let onOpenHabitBoard: () -> Void
    @Environment(PresentationPreferences.self) private var preferences

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader("Current daypart", symbol: TrackSectionCopy.daypartSymbol(preferences), trailing: {
                Button { editingRoutine = nil; showsRoutineComposer = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Create routine")
            })
            if store.snapshot.dueRoutines.isEmpty {
                TrackEmptyStateRow("No routines due", detail: "Start progressively or preview a starter pack.", symbol: "figure.cooldown")
            } else {
                ForEach(store.snapshot.dueRoutines) { routine in
                    HStack(spacing: 8) {
                    Button { Task { await store.startRoutine(routine) } } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(routine.title).font(.headline)
                                Text("\(routine.steps.count) calm steps · version \(routine.version)")
                                    .font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                        }
                        .trackClayCard()
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("track.routine.\(routine.id.uuidString)")
                    Menu {
                        Button("Edit routine", systemImage: "pencil") {
                            editingRoutine = routine
                            showsRoutineComposer = true
                        }
                        Button("Archive routine", systemImage: "archivebox", role: .destructive) {
                            Task { await store.archiveRoutine(routine) }
                        }
                        Button("Delete routine", systemImage: "trash", role: .destructive) {
                            routinePendingDeletion = routine
                        }
                    } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                    .accessibilityLabel("Actions for \(routine.title)")
                    }
                }
            }
            Button {
                onOpenHabitBoard()
            } label: {
                HStack {
                    Image(systemName: "repeat.circle.fill").foregroundStyle(Color(SemanticColorTokens.foundationFocusRing))
                    VStack(alignment: .leading) {
                        Text("Habits and resilience").font(.headline)
                        Text("Grade, streak, off days, recovery, and full history")
                            .font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                    Spacer(); Image(systemName: "arrow.up.right")
                }
                .trackClayCard()
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("track.habits")
            Button {
                showsHabitResilience = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "shield.lefthalf.filled")
                        .foregroundStyle(Color(SemanticColorTokens.foundationSageAccent))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Resilience settings").font(.headline)
                        Text("Choose intentional off days, recovery, and how streaks are framed.")
                            .font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                }
                .padding(.horizontal, 4)
                .frame(minHeight: 52)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("track.habits.resilience")
            if !store.snapshot.habitGrades.isEmpty {
                TrackHabitQualitySummary(store: store)
            }
        }
    }
}

private struct TrackGoalsSection: View {
    let store: TrackFoundationStore
    @Binding var showsGoal: Bool
    @Binding var editingGoal: GoalDefinition?
    @Binding var linkingGoal: GoalDefinition?
    @Binding var goalPendingDeletion: GoalDefinition?
    @Binding var goalUndoReceipt: GoalTransitionReceipt?

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader("Goals and progress", symbol: "target", trailing: {
                Button { editingGoal = nil; showsGoal = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add goal")
            })
            if store.definitions.isEmpty {
                TrackEmptyStateRow("No goals required", detail: "Goals are optional. Add one only when it helps organize action.", symbol: "scope")
            } else {
                ForEach(store.definitions) { goal in
                    let progress = store.snapshot.goals.first(where: { $0.goalID == goal.id })
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(goal.title).font(.headline)
                                Text("\(goal.effectiveIntent.rawValue.capitalized) · \(goal.effectiveStatus.rawValue.capitalized)")
                                    .font(.caption)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                            Spacer()
                            Text(TrackSectionCopy.progressLabel(progress)).font(.caption.weight(.semibold))
                            Menu {
                                Button("Link progress source", systemImage: "link.badge.plus") { linkingGoal = goal }
                                Button("Edit goal", systemImage: "pencil") { editingGoal = goal; showsGoal = true }
                                switch goal.effectiveStatus {
                                case .active, .revised:
                                    Button("Pause goal", systemImage: "pause.circle") { transition(goal, to: .paused, reason: "Paused by user") }
                                    Button("Complete goal", systemImage: "checkmark.circle") { transition(goal, to: .completed, reason: "Completed by user") }
                                    Button("Revise goal", systemImage: "arrow.triangle.2.circlepath") {
                                        transition(goal, to: .revised, reason: "Revision started by user", editAfter: true)
                                    }
                                case .paused:
                                    Button("Resume goal", systemImage: "play.circle") { transition(goal, to: .active, reason: "Resumed by user") }
                                    Button("Revise goal", systemImage: "arrow.triangle.2.circlepath") {
                                        transition(goal, to: .revised, reason: "Revision started by user", editAfter: true)
                                    }
                                case .completed:
                                    Button("Reactivate goal", systemImage: "arrow.uturn.backward.circle") { transition(goal, to: .active, reason: "Reactivated by user") }
                                case .archived:
                                    Button("Restore goal", systemImage: "tray.and.arrow.up") { transition(goal, to: .active, reason: "Restored by user") }
                                }
                                Button("Archive goal", systemImage: "archivebox") { transition(goal, to: .archived, reason: "Archived by user") }
                                Button("Delete goal", systemImage: "trash", role: .destructive) { goalPendingDeletion = goal }
                            } label: {
                                Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Actions for \(goal.title)")
                        }
                        if let fraction = progress?.progressFraction { ProgressView(value: fraction).tint(Color(SemanticColorTokens.foundationFocusRing)) }
                        if let why = goal.whyItMatters, !why.isEmpty {
                            Text(why)
                                .font(.subheadline)
                                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        }
                        Text(progress?.nextUsefulAction ?? "Link a source to measure progress.")
                            .font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                    .trackClayCard()
                    .accessibilityIdentifier("track.goal.\(goal.id.uuidString)")
                }
            }
        }
    }

    private func transition(
        _ goal: GoalDefinition,
        to status: GoalStatus,
        reason: String,
        editAfter: Bool = false
    ) {
        Task {
            let receipt = await store.transitionGoal(goal, to: status, reason: reason)
            goalUndoReceipt = receipt
            if editAfter, let receipt {
                editingGoal = receipt.after
                showsGoal = true
            }
        }
    }
}

private struct TrackModulesSection: View {
    let store: TrackFoundationStore
    let nutritionRepository: any NutritionRepository
    let lifeMomentRepository: any LifeMomentRepository
    let wellnessRepository: any WellnessRepository
    @Binding var showsStarterPacks: Bool

    var body: some View {
        VStack(spacing: 12) {
            SectionHeader("Explore and reflect", symbol: "square.grid.2x2")
            Button { showsStarterPacks = true } label: { TrackModuleRow("Starter packs", detail: "Preview before creating anything", symbol: "shippingbox") }
                .buttonStyle(.plain)
            ForEach(store.starterPackInstallations.filter { $0.removedAt == nil }) { installation in
                HStack(spacing: 12) {
                    Image(systemName: "shippingbox.fill").foregroundStyle(Color(SemanticColorTokens.foundationFocusRing))
                    VStack(alignment: .leading, spacing: 4) {
                        Text(TrackSectionCopy.starterPackTitle(installation.pack)).font(.headline)
                        Text("Installed · history stays if removed")
                            .font(.caption).foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                    Spacer()
                    Button("Remove", role: .destructive) { Task { await store.removeStarterPack(installation) } }
                        .font(.caption.weight(.semibold))
                }
                .padding(.vertical, 6)
            }
            NavigationLink { JournalModuleView(repository: store.phaseIIRepository) } label: { TrackModuleRow("Journal", detail: "Write, reflect, and look back", symbol: "book.closed") }
                .buttonStyle(.plain)
            NavigationLink { KnowledgeModuleView(repository: store.phaseIIRepository) } label: { TrackModuleRow("Notes", detail: "Notes and the links between them", symbol: "note.text") }
                .buttonStyle(.plain)
            if V2FeatureFlags.nutritionV1Enabled {
                NavigationLink { NutritionView(repository: nutritionRepository) } label: { TrackModuleRow("Nutrition", detail: "What you ate today", symbol: "fork.knife") }
                    .buttonStyle(.plain)
            }
            if V2FeatureFlags.wellnessCoreV1Enabled {
                NavigationLink { WellnessView(repository: wellnessRepository) } label: { TrackModuleRow("Wellness", detail: "Weight, sleep, workouts, and trends", symbol: "heart.text.square") }
                    .buttonStyle(.plain)
            }
            if V2FeatureFlags.lifeMomentsV1Enabled {
                NavigationLink { LifeMomentsView(repository: lifeMomentRepository) } label: { TrackModuleRow("Life Moments", detail: "Countdowns and dates that matter", symbol: "calendar.badge.heart") }
                    .buttonStyle(.plain)
            }
            NavigationLink {
                BehaviorAreaRouteView(
                    repository: store.phaseIIRepository,
                    initialArea: .trackers
                )
            } label: {
                TrackModuleRow(
                    "Trackers and medication",
                    detail: "Typed values, neutral schedules, corrections, and history",
                    symbol: "square.grid.3x3"
                )
            }
                .buttonStyle(.plain)
                .accessibilityIdentifier("track.module.behavior")
        }
    }
}

private struct TrackHistorySection: View {
    let store: TrackFoundationStore
    let fastingSessions: [FastingSessionValue]
    @Binding var careHistoryDays: Int
    @Binding var showsSleep: Bool
    @Binding var editingSleep: SleepContextRecord?

    var body: some View {
        let hydrationHistory = TrackSectionCopy.hydrationHistory(store, days: careHistoryDays)
        let sleepHistory = TrackSectionCopy.sleepHistory(store, days: careHistoryDays)
        let fastingHistory = TrackSectionCopy.fastingHistory(fastingSessions, days: careHistoryDays)
        let routineHistory = TrackSectionCopy.routineHistory(store, days: careHistoryDays)
        VStack(alignment: .leading, spacing: 14) {
            OptionRail(
                "History range",
                selection: $careHistoryDays,
                values: [7, 30],
                identifierPrefix: "track.history.range",
                title: { "\($0) days" },
                showsLabel: false
            )

            if hydrationHistory.isEmpty
                && sleepHistory.isEmpty
                && store.checkIns.isEmpty
                && fastingHistory.isEmpty
                && routineHistory.isEmpty
                && store.snapshot.goals.isEmpty {
                TrackEmptyStateRow(
                    "No history yet",
                    detail: "Explicit records will appear here. Missing data is never treated as zero.",
                    symbol: "clock.arrow.circlepath"
                )
            } else {
                if hydrationHistory.isEmpty == false {
                    SectionHeader("Hydration", symbol: "drop")
                    ForEach(hydrationHistory) { TrackHydrationHistoryRow(store: store, log: $0) }
                }
                if sleepHistory.isEmpty == false {
                    SectionHeader("Sleep context", symbol: "moon.zzz")
                    ForEach(sleepHistory) { record in
                        TrackSleepHistoryRow(
                            store: store,
                            record: record,
                            showsSleep: $showsSleep,
                            editingSleep: $editingSleep
                        )
                    }
                }
                if store.checkIns.isEmpty == false {
                    SectionHeader("Mind check-ins", symbol: "face.smiling")
                    ForEach(Array(store.checkIns.prefix(12)), id: \.id) { checkIn in
                        HStack(spacing: 12) {
                            Image(systemName: "face.smiling")
                                .foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(checkIn.mood.title).font(.body.weight(.medium))
                                Text(TrackSectionCopy.moodCheckInDetail(checkIn))
                                    .font(.caption)
                                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                    }
                }
                // History used to stop at hydration, sleep and mood, which
                // made it read as a care log rather than a record of the
                // whole tracked life.
                if fastingHistory.isEmpty == false {
                    SectionHeader("Fasting", symbol: "timer")
                    ForEach(fastingHistory) { session in
                        TrackHistoryRow(
                            symbol: "timer",
                            title: TrackSectionCopy.fastingClock(session.elapsed(at: session.endedAt ?? Date())),
                            detail: session.startedAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                }
                if routineHistory.isEmpty == false {
                    SectionHeader("Routines", symbol: "repeat")
                    ForEach(routineHistory) { run in
                        TrackHistoryRow(
                            symbol: "repeat",
                            title: TrackSectionCopy.routineTitle(store, for: run),
                            detail: run.startedAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                }
                if store.snapshot.goals.isEmpty == false {
                    SectionHeader("Goals", symbol: "target")
                    ForEach(store.snapshot.goals, id: \.goalID) { goal in
                        TrackHistoryRow(
                            symbol: "target",
                            title: TrackSectionCopy.goalTitle(store, for: goal.goalID),
                            detail: goal.nextUsefulAction
                        )
                    }
                }
            }
        }
        .accessibilityIdentifier("track.history")
    }
}

// MARK: - Track presentation

private struct TrackComposerSheets: ViewModifier {
    let store: TrackFoundationStore
    let fastingTimerStore: FastingTimerStore
    let sourcePickerRepository: any TypedSourcePickerRepository
    let fastingSessions: [FastingSessionValue]
    let reloadFasting: () async -> Void
    @Binding var showsFastingComposer: Bool
    @Binding var showsFastingHistory: Bool
    @Binding var fastingError: String?
    @Binding var showsMood: Bool
    @Binding var editingMood: MoodEnergyCheckInValue?
    @Binding var showsSleep: Bool
    @Binding var editingSleep: SleepContextRecord?
    @Binding var showsGoal: Bool
    @Binding var editingGoal: GoalDefinition?
    @Binding var linkingGoal: GoalDefinition?
    @Binding var showsStarterPacks: Bool
    @Binding var showsHabitResilience: Bool
    @Binding var showsRoutineComposer: Bool
    @Binding var editingRoutine: RoutineDefinition?
    @Binding var showsHydrationTarget: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showsFastingComposer) {
                FastingComposer { target, _ in
                    Task {
                        do {
                            _ = try await fastingTimerStore.start(targetDuration: target)
                            await reloadFasting()
                        } catch {
                            fastingError = error.localizedDescription
                        }
                    }
                }
            }
            .sheet(isPresented: $showsFastingHistory) {
                FastingHistoryView(
                    sessions: fastingSessions,
                    activeReceipt: { store.activeCorrection(domain: .fasting, sourceID: $0) },
                    onUndo: { receipt in
                        await store.undoCorrection(receipt)
                        await reloadFasting()
                    },
                    onCorrect: { session, startDelta, endDelta in
                        do {
                            _ = try await fastingTimerStore.correct(
                                sessionID: session.id,
                                startedAt: session.startedAt.addingTimeInterval(startDelta),
                                endedAt: session.endedAt?.addingTimeInterval(endDelta),
                                targetDuration: session.targetDuration,
                                note: session.note
                            )
                            await reloadFasting()
                        } catch {
                            fastingError = error.localizedDescription
                        }
                    }
                )
            }
            .sheet(isPresented: $showsMood, onDismiss: { editingMood = nil }) {
                MoodEnergyComposer(checkIn: editingMood) { value in
                    await store.saveMood(value)
                    return store.errorMessage == nil
                } delete: { value in
                    Task { await store.deleteMood(value) }
                }
            }
            .sheet(isPresented: $showsSleep, onDismiss: { editingSleep = nil }) {
                SleepContextComposer(existing: editingSleep) { record in
                    await store.saveSleep(record)
                    return store.errorMessage == nil
                }
            }
            .sheet(isPresented: $showsGoal, onDismiss: { editingGoal = nil }) {
                GoalComposer(existing: editingGoal) { draft in
                    await store.saveGoal(existing: editingGoal, draft: draft)
                    return store.errorMessage == nil
                }
            }
            .sheet(item: $linkingGoal) { goal in
                GoalLinkComposer(goal: goal, sourcePickerRepository: sourcePickerRepository) { source, sourceID in
                    Task { await store.saveGoalLink(goalID: goal.id, source: source, sourceID: sourceID) }
                }
            }
            .sheet(isPresented: $showsStarterPacks) { StarterPackBrowser { preview in Task { await store.installStarterPack(preview) } } }
            .sheet(isPresented: $showsHabitResilience) {
                HabitResilienceLibrary(
                    repository: sourcePickerRepository,
                    policies: store.habitPolicies,
                    groups: store.habitGroups,
                    history: store.habitOccurrenceHistory,
                    save: { policy in
                        await store.saveHabitPolicy(policy)
                        return store.errorMessage == nil
                    },
                    recover: { habitID, day in await store.recoverHabit(habitID: habitID, day: day) },
                    undoRecovery: { habitID, day in await store.undoHabitRecovery(habitID: habitID, day: day) },
                    saveGroup: { group in Task { await store.saveHabitGroup(group) } },
                    deleteGroup: { group in Task { await store.deleteHabitGroup(group) } }
                )
            }
            .sheet(isPresented: $showsRoutineComposer, onDismiss: { editingRoutine = nil }) {
                RoutineComposer(
                    existing: editingRoutine,
                    schedule: editingRoutine.flatMap { routine in store.routineSchedules.first(where: { $0.routineID == routine.id }) },
                    sourcePickerRepository: sourcePickerRepository
                ) { title, steps, weekdays, daypart in
                    await store.saveRoutine(existing: editingRoutine, title: title, steps: steps, weekdays: weekdays, daypart: daypart)
                    let succeeded = store.errorMessage == nil
                    if succeeded {
                        await PermissionPrimingCoordinator.shared.offerAfterReward(
                            kind: .notifications,
                            trigger: "routine_scheduled"
                        )
                    }
                    return succeeded
                }
            }
            .sheet(isPresented: $showsHydrationTarget) {
                HydrationTargetComposer(currentTarget: store.snapshot.hydrationTargetMilliliters) { milliliters in
                    await store.setHydrationTarget(milliliters)
                    return store.errorMessage == nil
                }
            }
            .fullScreenCover(isPresented: Binding(
                get: { store.activeRoutineRun != nil },
                set: { _ in }
            )) {
                if let run = store.activeRoutineRun {
                    RoutineRunner(
                        run: run,
                        advance: { response, skip in
                            Task { await store.advanceRoutine(response: response, skip: skip) }
                        },
                        pause: { Task { await store.pauseRoutine() } },
                        resume: { Task { await store.resumeRoutine() } },
                        abandon: { Task { await store.abandonRoutine() } }
                    )
                        .interactiveDismissDisabled()
                }
            }
    }
}

private struct TrackDestructiveDialogs: ViewModifier {
    let store: TrackFoundationStore
    @Binding var goalUndoReceipt: GoalTransitionReceipt?
    @Binding var routinePendingDeletion: RoutineDefinition?
    @Binding var goalPendingDeletion: GoalDefinition?

    func body(content: Content) -> some View {
        content
            .alert("Track needs attention", isPresented: Binding(
                get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } }
            )) { Button("OK", role: .cancel) { store.errorMessage = nil } } message: { Text(store.errorMessage ?? "") }
            .safeAreaInset(edge: .bottom) {
                if let receipt = goalUndoReceipt {
                    HStack(spacing: 12) {
                        Text("Goal \(receipt.after.effectiveStatus.rawValue).")
                            .font(.subheadline)
                        Spacer()
                        Button("Undo") {
                            goalUndoReceipt = nil
                            Task { await store.undoGoalTransition(receipt) }
                        }
                        .frame(minHeight: 44)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .lifeBoardClaySurface(.floating, cornerRadius: Radius.pill)
                    .padding(.horizontal, 20)
                    .accessibilityElement(children: .contain)
                }
            }
            .confirmationDialog(
                "Delete this routine?",
                isPresented: Binding(get: { routinePendingDeletion != nil }, set: { if !$0 { routinePendingDeletion = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete routine", role: .destructive) {
                    guard let routine = routinePendingDeletion else { return }
                    routinePendingDeletion = nil
                    Task { await store.deleteRoutine(routine) }
                }
                Button("Cancel", role: .cancel) { routinePendingDeletion = nil }
            } message: {
                Text("The definition and schedule are removed. Completed and abandoned run history remains available for evidence and review.")
            }
            .confirmationDialog(
                "Delete this goal?",
                isPresented: Binding(get: { goalPendingDeletion != nil }, set: { if !$0 { goalPendingDeletion = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete goal", role: .destructive) {
                    guard let goal = goalPendingDeletion else { return }
                    goalPendingDeletion = nil
                    Task { await store.deleteGoal(goal) }
                }
                Button("Cancel", role: .cancel) { goalPendingDeletion = nil }
            } message: {
                Text("The goal and its explicit progress links are removed. Source tasks, habits, routines, and tracker entries are unchanged.")
            }
    }
}

// MARK: - Typed Track destinations

/// A focused goals library used by Home and external deep links. Goal detail
/// remains ID-based so restoration always resolves the current repository copy.
struct GoalsDestinationView: View {
    @State private var store: TrackFoundationStore
    private let sourcePickerRepository: any TypedSourcePickerRepository
    private let router: AppRouter
    @State private var showsComposer = false
    @State private var editingGoal: GoalDefinition?
    @State private var linkingGoal: GoalDefinition?
    @State private var pendingDeletion: GoalDefinition?
    @State private var undoReceipt: GoalTransitionReceipt?

    init(
        repository: CoreDataTrackFoundationRepository,
        phaseIIRepository: any PhaseIIRepository,
        goalSampleProvider: (any GoalSampleRepository)?,
        sourcePickerRepository: any TypedSourcePickerRepository,
        router: AppRouter
    ) {
        _store = State(initialValue: TrackFoundationStore(
            repository: repository,
            phaseIIRepository: phaseIIRepository,
            goalSampleProvider: goalSampleProvider
        ))
        self.sourcePickerRepository = sourcePickerRepository
        self.router = router
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Goals and progress")
                            .font(Typography.screenTitle())
                        Text("Progress comes from the sources you choose to link.")
                            .font(.subheadline)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    }
                    Spacer(minLength: 8)
                    Button("Add goal", systemImage: "plus") {
                        editingGoal = nil
                        showsComposer = true
                    }
                    .buttonStyle(.lifeBoardPrimaryCompact)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("goals.add")
                }

                if store.isLoading, store.definitions.isEmpty {
                    ProgressView("Loading goals")
                        .frame(maxWidth: .infinity, minHeight: 160)
                } else if let error = store.errorMessage, store.definitions.isEmpty {
                    ContentUnavailableView(
                        "Goals are unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    Button("Try again") { Task { await store.load() } }
                        .buttonStyle(.lifeBoardPrimaryCompact)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else if store.definitions.isEmpty {
                    ContentUnavailableView(
                        "No goals yet",
                        systemImage: "target",
                        description: Text("Add a goal when it helps organize action.")
                    )
                    Button("Add goal") {
                        editingGoal = nil
                        showsComposer = true
                    }
                    .buttonStyle(.lifeBoardPrimaryCompact)
                    .frame(maxWidth: .infinity, minHeight: 48)
                } else {
                    ForEach(groupedGoals, id: \.status) { group in
                        Text(group.status.rawValue.capitalized)
                            .font(Typography.sectionTitle())
                        ForEach(group.goals) { goal in
                            goalRow(goal)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 80)
        }
        .background { GrainedCanvas() }
        .navigationTitle("Goals")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .sheet(isPresented: $showsComposer, onDismiss: { editingGoal = nil }) {
            GoalComposer(existing: editingGoal) { draft in
                await store.saveGoal(existing: editingGoal, draft: draft)
                return store.errorMessage == nil
            }
        }
        .sheet(item: $linkingGoal) { goal in
            GoalLinkComposer(goal: goal, sourcePickerRepository: sourcePickerRepository) { source, sourceID in
                Task { await store.saveGoalLink(goalID: goal.id, source: source, sourceID: sourceID) }
            }
        }
        .confirmationDialog(
            "Delete this goal?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete goal", role: .destructive) {
                guard let goal = pendingDeletion else { return }
                pendingDeletion = nil
                Task { await store.deleteGoal(goal) }
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("The goal and its progress links are removed. Linked source records are unchanged.")
        }
        .safeAreaInset(edge: .bottom) {
            if let undoReceipt {
                HStack {
                    Text("Goal updated.")
                    Spacer()
                    Button("Undo") {
                        self.undoReceipt = nil
                        Task { await store.undoGoalTransition(undoReceipt) }
                    }
                    .frame(minHeight: 44)
                }
                .padding(.horizontal, 16)
                .lifeBoardClaySurface(.floating, cornerRadius: Radius.pill)
                .padding(.horizontal, 20)
            }
        }
    }

    private var groupedGoals: [(status: GoalStatus, goals: [GoalDefinition])] {
        GoalStatus.allCases.compactMap { status in
            let goals = store.definitions
                .filter { $0.effectiveStatus == status }
                .sorted { $0.updatedAt > $1.updatedAt }
            return goals.isEmpty ? nil : (status, goals)
        }
    }

    private func goalRow(_ goal: GoalDefinition) -> some View {
        let progress = store.snapshot.goals.first(where: { $0.goalID == goal.id })
        return HStack(spacing: 10) {
            Button {
                router.push(.goal(goal.id), in: .track)
            } label: {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(goal.title).font(.headline)
                        Spacer()
                        Text(TrackSectionCopy.progressLabel(progress))
                            .font(.caption.weight(.semibold))
                    }
                    if let fraction = progress?.progressFraction {
                        ProgressView(value: fraction)
                            .tint(Color(SemanticColorTokens.foundationFocusRing))
                    }
                    Text(progress?.nextUsefulAction ?? "Link a source to measure progress.")
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(goal.title), \(TrackSectionCopy.progressLabel(progress))")

            Menu {
                Button("Link progress source", systemImage: "link.badge.plus") { linkingGoal = goal }
                Button("Edit goal", systemImage: "pencil") {
                    editingGoal = goal
                    showsComposer = true
                }
                goalTransitionActions(goal)
                Button("Delete goal", systemImage: "trash", role: .destructive) { pendingDeletion = goal }
            } label: {
                Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Actions for \(goal.title)")
        }
        .padding(14)
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.largeCard)
        .accessibilityIdentifier("goals.goal.\(goal.id.uuidString)")
    }

    @ViewBuilder
    private func goalTransitionActions(_ goal: GoalDefinition) -> some View {
        switch goal.effectiveStatus {
        case .active, .revised:
            Button("Pause goal", systemImage: "pause.circle") { transition(goal, to: .paused) }
            Button("Complete goal", systemImage: "checkmark.circle") { transition(goal, to: .completed) }
        case .paused:
            Button("Resume goal", systemImage: "play.circle") { transition(goal, to: .active) }
        case .completed, .archived:
            Button("Reactivate goal", systemImage: "arrow.uturn.backward.circle") { transition(goal, to: .active) }
        }
        if goal.effectiveStatus != .archived {
            Button("Archive goal", systemImage: "archivebox") { transition(goal, to: .archived) }
        }
    }

    private func transition(_ goal: GoalDefinition, to status: GoalStatus) {
        Task { undoReceipt = await store.transitionGoal(goal, to: status, reason: "Changed by user") }
    }
}

enum RoutineDestinationFocus: Hashable {
    case collection(RoutineCollectionFocus)
    case routine(UUID)
}

struct RoutinesDestinationView: View {
    @State private var store: TrackFoundationStore
    private let focus: RoutineDestinationFocus
    private let sourcePickerRepository: any TypedSourcePickerRepository
    private let router: AppRouter
    @State private var showsComposer = false
    @State private var editingRoutine: RoutineDefinition?
    @State private var pendingDeletion: RoutineDefinition?
    @State private var showsRunner = false

    init(
        repository: CoreDataTrackFoundationRepository,
        phaseIIRepository: any PhaseIIRepository,
        linkedMutationApplier: (any RoutineLinkedMutationApplying)?,
        sourcePickerRepository: any TypedSourcePickerRepository,
        router: AppRouter,
        focus: RoutineDestinationFocus
    ) {
        _store = State(initialValue: TrackFoundationStore(
            repository: repository,
            phaseIIRepository: phaseIIRepository,
            linkedMutationApplier: linkedMutationApplier
        ))
        self.sourcePickerRepository = sourcePickerRepository
        self.router = router
        self.focus = focus
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if store.isLoading, store.routines.isEmpty {
                    ProgressView("Loading routines")
                        .frame(maxWidth: .infinity, minHeight: 180)
                } else if let error = store.errorMessage, store.routines.isEmpty {
                    ContentUnavailableView(
                        "Routines are unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    Button("Try again") { Task { await store.load() } }
                        .buttonStyle(.lifeBoardPrimaryCompact)
                        .frame(maxWidth: .infinity, minHeight: 44)
                } else {
                    destinationContent
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 80)
        }
        .background { GrainedCanvas() }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .sheet(isPresented: $showsComposer, onDismiss: { editingRoutine = nil }) {
            RoutineComposer(
                existing: editingRoutine,
                schedule: editingRoutine.flatMap { routine in
                    store.routineSchedules.first(where: { $0.routineID == routine.id })
                },
                sourcePickerRepository: sourcePickerRepository
            ) { title, steps, weekdays, daypart in
                await store.saveRoutine(
                    existing: editingRoutine,
                    title: title,
                    steps: steps,
                    weekdays: weekdays,
                    daypart: daypart
                )
                return store.errorMessage == nil
            }
        }
        .fullScreenCover(isPresented: $showsRunner) {
            if let run = store.activeRoutineRun {
                RoutineRunner(
                    run: run,
                    advance: { response, skip in Task { await store.advanceRoutine(response: response, skip: skip) } },
                    pause: { Task { await store.pauseRoutine() } },
                    resume: { Task { await store.resumeRoutine() } },
                    abandon: { Task { await store.abandonRoutine() } }
                )
                .interactiveDismissDisabled()
            }
        }
        .confirmationDialog(
            "Delete this routine?",
            isPresented: Binding(get: { pendingDeletion != nil }, set: { if !$0 { pendingDeletion = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete routine", role: .destructive) {
                guard let routine = pendingDeletion else { return }
                pendingDeletion = nil
                Task {
                    await store.deleteRoutine(routine)
                    if case .routine = focus, store.errorMessage == nil { router.pop(in: .track) }
                }
            }
            Button("Cancel", role: .cancel) { pendingDeletion = nil }
        } message: {
            Text("The definition and schedule are removed. Existing run history remains available.")
        }
        .alert("Routines need attention", isPresented: Binding(
            get: { store.errorMessage != nil && store.routines.isEmpty == false },
            set: { if !$0 { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var destinationContent: some View {
        switch focus {
        case .collection:
            collectionContent
        case .routine(let id):
            if let routine = store.routines.first(where: { $0.id == id }) {
                routineDetail(routine)
            } else {
                ContentUnavailableView(
                    "Routine unavailable",
                    systemImage: "archivebox",
                    description: Text("It may have been archived or removed.")
                )
                Button("View all routines") {
                    router.openLeaf(.routines(.library), in: .track)
                }
                .buttonStyle(.lifeBoardPrimaryCompact)
                .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
    }

    private var collectionContent: some View {
        Group {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(collectionHeading).font(Typography.screenTitle())
                    Text("Review the steps first, then start when it fits.")
                        .font(.subheadline)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                Spacer(minLength: 8)
                Button("Add routine", systemImage: "plus") {
                    editingRoutine = nil
                    showsComposer = true
                }
                .buttonStyle(.lifeBoardPrimaryCompact)
                .frame(minHeight: 44)
            }

            if let run = store.activeRoutineRun {
                Button {
                    showsRunner = true
                } label: {
                    Label("Continue \(run.versionSnapshot.title)", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.lifeBoardPrimaryCompact)
                .accessibilityIdentifier("routines.continueActive")
            }

            if displayedRoutines.isEmpty {
                ContentUnavailableView(
                    "No routines here",
                    systemImage: "figure.mind.and.body",
                    description: Text("Add a routine or review the complete library.")
                )
                if case .collection(.daypart) = focus {
                    Button("View all routines") { router.openLeaf(.routines(.library), in: .track) }
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
            } else {
                ForEach(displayedRoutines) { routine in routineRow(routine) }
            }
        }
    }

    private func routineDetail(_ routine: RoutineDefinition) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(routine.title).font(Typography.screenTitle())
            if let schedule = store.routineSchedules.first(where: { $0.routineID == routine.id }) {
                Text(scheduleDescription(schedule))
                    .font(.subheadline)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }

            Button {
                primaryRoutineAction(routine)
            } label: {
                Label(primaryRoutineActionTitle(routine), systemImage: "play.fill")
                    .frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.lifeBoardPrimaryCompact)
            .accessibilityIdentifier("routine.primaryAction")

            HStack(spacing: 10) {
                Button("Edit routine", systemImage: "pencil") {
                    editingRoutine = routine
                    showsComposer = true
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity, minHeight: 44)
                Menu {
                    Button("Archive routine", systemImage: "archivebox") {
                        Task { await store.archiveRoutine(routine) }
                    }
                    Button("Delete routine", systemImage: "trash", role: .destructive) {
                        pendingDeletion = routine
                    }
                } label: {
                    Label("More", systemImage: "ellipsis.circle").frame(minHeight: 44)
                }
            }

            Text("Steps").font(Typography.sectionTitle())
            ForEach(routine.steps.sorted(by: { $0.ordinal < $1.ordinal })) { step in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "circle")
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(step.title).font(.body)
                        if let duration = step.duration {
                            Text("About \(max(1, Int(duration / 60))) minutes")
                                .font(.caption)
                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        }
                    }
                }
                .frame(minHeight: 44)
            }

            Text("Run history").font(Typography.sectionTitle())
            let history = store.routineRuns
                .filter { $0.routineID == routine.id }
                .sorted { $0.startedAt > $1.startedAt }
            if history.isEmpty {
                Text("No runs recorded yet.")
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            } else {
                ForEach(history.prefix(30)) { run in
                    LabeledContent(
                        run.startedAt.formatted(date: .abbreviated, time: .shortened),
                        value: run.status.rawValue.capitalized
                    )
                    .frame(minHeight: 44)
                }
            }
        }
    }

    private func routineRow(_ routine: RoutineDefinition) -> some View {
        HStack(spacing: 10) {
            Button {
                router.push(.routine(routine.id), in: .track)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(routine.title).font(.headline)
                    Text("\(routine.steps.count) steps")
                        .font(.caption)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            Image(systemName: "chevron.right")
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
        }
        .padding(14)
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.largeCard)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(routine.title), \(routine.steps.count) steps")
    }

    private var displayedRoutines: [RoutineDefinition] {
        let active = store.routines.filter { $0.isArchived == false }
        guard case .collection(.daypart(let daypart)) = focus else {
            return active.sorted { $0.updatedAt > $1.updatedAt }
        }
        let matchingIDs = Set(store.routineSchedules.filter {
            $0.isEnabled && ($0.daypart == nil || $0.daypart == daypart)
        }.map(\.routineID))
        return active.filter { matchingIDs.contains($0.id) }.sorted { $0.updatedAt > $1.updatedAt }
    }

    private var collectionHeading: String {
        guard case .collection(.daypart(let daypart)) = focus else { return "Routines" }
        return "\(daypart.rawValue.capitalized) routines"
    }

    private var navigationTitle: String {
        if case .routine = focus { return "Routine" }
        return "Routines"
    }

    private func primaryRoutineActionTitle(_ routine: RoutineDefinition) -> String {
        guard let active = store.activeRoutineRun else { return "Start routine" }
        return active.routineID == routine.id ? "Continue routine" : "Continue \(active.versionSnapshot.title)"
    }

    private func primaryRoutineAction(_ routine: RoutineDefinition) {
        if store.activeRoutineRun != nil {
            showsRunner = true
        } else {
            Task {
                await store.startRoutine(routine)
                if store.activeRoutineRun != nil { showsRunner = true }
            }
        }
    }

    private func scheduleDescription(_ schedule: RoutineSchedule) -> String {
        let daypart = schedule.daypart?.rawValue.capitalized ?? "Any daypart"
        return "\(daypart) · \(schedule.weekdays.count) days each week"
    }
}

struct TrackUniversalCaptureView: View {
    let kind: CaptureKind
    @State private var store: TrackFoundationStore
    @Environment(\.dismiss) private var dismiss

    init(
        kind: CaptureKind,
        repository: CoreDataTrackFoundationRepository,
        phaseIIRepository: any PhaseIIRepository,
        linkedMutationApplier: (any RoutineLinkedMutationApplying)? = nil
    ) {
        self.kind = kind
        _store = State(initialValue: TrackFoundationStore(
            repository: repository,
            phaseIIRepository: phaseIIRepository,
            linkedMutationApplier: linkedMutationApplier
        ))
    }

    var body: some View {
        Group {
            switch kind {
            case .mood:
                MoodEnergyComposer { value in
                    await store.saveMood(value)
                    return store.errorMessage == nil
                }
            case .hydration:
                HydrationCaptureComposer(
                    todayAmount: store.snapshot.hydrationAmountMilliliters ?? 0,
                    target: store.snapshot.hydrationTargetMilliliters
                ) { amount in
                    await store.quickAddHydration(amount)
                    return store.errorMessage == nil
                }
            case .medicationEvent:
                // composer-kit:allow-list selection list of due events with swipe
                // resolution; row semantics are the surface, not chrome.
                List {
                    if store.snapshot.unresolvedMedicationEvents.isEmpty {
                        ContentUnavailableView("No medication event due", systemImage: "checkmark.circle", description: Text("Scheduled and unresolved events appear here."))
                    } else {
                        ForEach(store.snapshot.unresolvedMedicationEvents) { event in
                            Section(store.medicationName(id: event.medicationID)) {
                                Button("Taken", systemImage: "checkmark.circle") { resolve(event, .taken) }
                                Button("Skipped", systemImage: "forward.circle") { resolve(event, .skipped) }
                                Button("Snoozed", systemImage: "clock") { resolve(event, .snoozed) }
                            }
                        }
                    }
                }
                .lifeBoardFormSurface()
                .navigationTitle("Medication event")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            case .routineRun:
                List(store.routines) { routine in
                    Button {
                        Task { await store.startRoutine(routine) }
                    } label: {
                        Label(routine.title, systemImage: "play.circle.fill")
                    }
                }
                .overlay { if store.routines.isEmpty { ContentUnavailableView("No routines yet", systemImage: "figure.mind.and.body") } }
                .navigationTitle("Start routine")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
                .fullScreenCover(isPresented: Binding(get: { store.activeRoutineRun != nil }, set: { _ in })) {
                    if let run = store.activeRoutineRun {
                        RoutineRunner(
                            run: run,
                            advance: { response, skip in
                                Task { await store.advanceRoutine(response: response, skip: skip) }
                            },
                            pause: { Task { await store.pauseRoutine() } },
                            resume: { Task { await store.resumeRoutine() } },
                            abandon: { Task { await store.abandonRoutine() } }
                        )
                        .interactiveDismissDisabled()
                    }
                }
            default:
                ContentUnavailableView("Capture unavailable", systemImage: "exclamationmark.triangle")
            }
        }
        .task { await store.load() }
    }

    private func resolve(_ event: MedicationEventValue, _ status: MedicationEventStatus) {
        Task { await store.resolveMedication(event: event, status: status); dismiss() }
    }
}

private struct HydrationCaptureComposer: View {
    let todayAmount: Double
    let target: Double?
    let save: (Double) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var amount = 250.0
    @State private var commitPhase: LifeBoardComposerPhase = .idle
    @State private var bloomTrigger = 0

    private let presets: [(amount: Double, title: String, detail: String, symbol: String)] = [
        (150, "Sip", "150 mL", "drop"),
        (250, "Glass", "250 mL", "drop.fill"),
        (500, "Bottle", "500 mL", "waterbottle.fill"),
        (750, "Large", "750 mL", "waterbottle")
    ]

    var body: some View {
        ZStack {
            Color(SemanticColorTokens.foundationCanvas)
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 24 : 20) {
                    VStack(spacing: 6) {
                        Text("A little water for right now")
                            .font(Typography.sectionTitle().weight(.bold))
                            .multilineTextAlignment(.center)
                        Text("Choose what feels true. You can fine-tune it below.")
                            .font(.subheadline)
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)

                    HydrationSelectionOrb(
                        amount: amount,
                        todayAmount: todayAmount,
                        target: target,
                        bloomTrigger: bloomTrigger
                    )

                    LazyVGrid(
                        columns: dynamicTypeSize.isAccessibilitySize
                            ? [GridItem(.flexible())]
                            : [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(presets, id: \.amount) { preset in
                            hydrationPreset(preset)
                        }
                    }

                    fineAdjustment

                    if let target, target > 0 {
                        let projected = todayAmount + amount
                        Label(
                            "This would bring today to \(Int(projected)) of \(Int(target)) mL.",
                            systemImage: projected >= target ? "checkmark.circle.fill" : "circle.dotted"
                        )
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .lifeBoardClaySurface(.well, cornerRadius: 14)
                    } else {
                        Label(
                            "This records what you drank; it does not prescribe a target.",
                            systemImage: "heart.text.clipboard"
                        )
                        .font(.footnote)
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .lifeBoardClaySurface(.well, cornerRadius: 14)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 110)
            }
        }
        .navigationTitle("Log hydration")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            ComposerCommitBar(
                title: "Add \(Int(amount)) mL",
                phase: commitPhase,
                isEnabled: amount > 0,
                action: commit
            )
            .accessibilityIdentifier("track.hydration.commit")
        }
        .interactiveDismissDisabled(isRunning)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("track.hydration.composer")
    }

    private func hydrationPreset(
        _ preset: (amount: Double, title: String, detail: String, symbol: String)
    ) -> some View {
        let isSelected = amount == preset.amount
        return Button {
            withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                amount = preset.amount
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 11) {
                Image(systemName: preset.symbol)
                    .font(.body.weight(.semibold))
                    .frame(width: 30, height: 30)
                    .background(
                        Color(SemanticColorTokens.foundationSageAccent)
                            .opacity(isSelected ? 0.52 : 0.25),
                        in: Circle()
                    )
                VStack(alignment: .leading, spacing: 1) {
                    Text(preset.title).font(.subheadline.weight(.semibold))
                    Text(preset.detail)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        .symbolEffect(.bounce, options: .nonRepeating, value: amount)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .lifeBoardClaySurface(isSelected ? .raised : .well, cornerRadius: 16)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        Color(isSelected
                            ? SemanticColorTokens.inkPrimary.withAlphaComponent(0.34)
                            : SemanticColorTokens.foundationHairline),
                        lineWidth: isSelected ? 1.25 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(preset.title), \(preset.detail)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var fineAdjustment: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Fine tune")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Int(amount)) mL")
                    .font(.subheadline.monospaced().weight(.semibold))
                    .contentTransition(.numericText())
            }
            HStack(spacing: 12) {
                adjustmentButton(symbol: "minus", delta: -50)
                Slider(value: $amount, in: 50...1_500, step: 50)
                    .tint(Color(SemanticColorTokens.inkPrimary))
                    .accessibilityLabel("Water amount")
                    .accessibilityValue("\(Int(amount)) milliliters")
                adjustmentButton(symbol: "plus", delta: 50)
            }
        }
        .padding(14)
        .lifeBoardClaySurface(.well, cornerRadius: 16)
    }

    private func adjustmentButton(symbol: String, delta: Double) -> some View {
        Button {
            withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) {
                amount = min(1_500, max(50, amount + delta))
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(ClayButtonStyle(depth: .raised, cornerRadius: 22))
        .accessibilityLabel(delta > 0 ? "Add 50 milliliters" : "Remove 50 milliliters")
    }

    private var isRunning: Bool {
        if case .running = commitPhase { return true }
        return false
    }

    private func commit() {
        guard isRunning == false, amount > 0 else { return }
        commitPhase = .running(progress: nil)
        let committedAmount = amount
        Task {
            if await save(committedAmount) {
                commitPhase = .success(receipt: .init())
                bloomTrigger &+= 1
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 180 : 620))
                dismiss()
            } else {
                commitPhase = .recoverableFailure(.init(
                    message: "Your water was not saved. Nothing was changed.",
                    recovery: .retry
                ))
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        }
    }
}

private struct HydrationSelectionOrb: View {
    let amount: Double
    let todayAmount: Double
    let target: Double?
    let bloomTrigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.lifeBoardTransitionCoordinator) private var transitions
    @State private var targetCrossedTrigger = 0

    private var level: Double {
        min(0.92, max(0.16, amount / 1_000))
    }

    private var hasReachedTarget: Bool {
        guard let target, target > 0 else { return false }
        return todayAmount >= target
    }

    private static func dayKey() -> String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color(SemanticColorTokens.foundationSurfaceSolid))
            LiquidFill(
                level: level,
                tint: Color(SemanticColorTokens.foundationSageAccent)
            )
            .clipShape(Circle().inset(by: 7))
            Circle()
                .stroke(Color(SemanticColorTokens.inkPrimary).opacity(0.28), lineWidth: 1.25)
            Circle()
                .inset(by: 7)
                .stroke(Color(SemanticColorTokens.foundationSurfaceSolid).opacity(0.42), lineWidth: 1)

            VStack(spacing: 4) {
                Image(systemName: "drop.fill")
                    .font(.body.weight(.semibold))
                Text("\(Int(amount))")
                    .font(Typography.hero().weight(.bold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text("milliliters")
                    .font(.caption.weight(.medium))
                Text(projectedContext)
                    .font(.caption2)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
            .padding(.top, 4)
        }
        .frame(width: 174, height: 174)
        // Fires once per day, when the recorded total first crosses the target
        // — a "corresponding recorded state change", which is the only thing
        // DESIGN.md permits this shader for. Explicitly NOT on every +250 mL:
        // the orb already blooms on selection, and doubling that per tap is
        // exactly the ambient failure the design law names.
        .lifeboardVitalOrbWarp(trigger: targetCrossedTrigger)
        .onChange(of: hasReachedTarget) { _, reached in
            guard reached else { return }
            let key = "track.hydration.target.\(Self.dayKey())"
            guard transitions?.claimOneShot(key) == true else { return }
            targetCrossedTrigger &+= 1
        }
        .lifeBoardClaySurface(.raised, cornerRadius: Radius.pill)
        .scaleEffect(reduceMotion ? 1 : 1.0)
        .lifeBoardMotion(.controlMorph, value: level)
        .lifeboardClayPressBloom(
            center: .center,
            trigger: bloomTrigger,
            tint: Color(SemanticColorTokens.foundationSageAccent)
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Selected water amount")
        .accessibilityValue("\(Int(amount)) milliliters. \(projectedContext)")
    }

    private var projectedContext: String {
        let projected = todayAmount + amount
        guard let target, target > 0 else { return "\(Int(projected)) mL today" }
        return "\(Int(min(100, projected / target * 100)))% of today"
    }
}


private struct HydrationTargetComposer: View {
    let save: (Double) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double
    @State private var commitPhase: LifeBoardComposerPhase = .idle
    @State private var successTrigger = 0

    init(currentTarget: Double?, save: @escaping (Double) async -> Bool) {
        self.save = save
        _amount = State(initialValue: currentTarget ?? 2_000)
    }

    var body: some View {
        ComposerScaffold(
            title: "Hydration target",
            subtitle: "A number you chose, not one the app decided.",
            identifier: "track.hydration.target.composer"
        ) {
            HydrationTargetSection(amount: $amount)
        } commit: {
            ComposerCommitBar(
                title: "Save target",
                phase: commitPhase,
                isEnabled: amount > 0,
                identifier: "track.hydration.target.commit",
                action: commit
            )
        }
        .lifeboardCompletionBurst(trigger: successTrigger)
    }

    private func commit() {
        guard case .running = commitPhase else {
            commitPhase = .running(progress: nil)
            Task {
                if await save(amount) {
                    commitPhase = .success(receipt: .init())
                    successTrigger &+= 1
                    dismiss()
                } else {
                    commitPhase = .recoverableFailure(.init(
                        message: "The hydration target could not be saved.",
                        recovery: .retry
                    ))
                }
            }
            return
        }
    }
}

private struct HydrationTargetSection: View {
    @Binding var amount: Double

    private static let presets: [Double] = [1_500, 2_000, 2_500, 3_000]

    var body: some View {
        ComposerSection(
            "Your daily target",
            footer: "This is your own tracking target. LifeBoard does not calculate or recommend a medical hydration amount."
        ) {
            ValueDrum(
                "Daily target",
                value: $amount,
                in: 0...5_000,
                step: 50,
                coarseStep: 500,
                unit: "mL",
                fractionDigits: 0,
                identifier: "track.hydration.target.value"
            )
            OptionRail(
                "Common targets",
                selection: $amount,
                values: Self.presets,
                identifierPrefix: "track.hydration.target.preset",
                title: { "\(Int($0).formatted()) mL" }
            )
        }
    }
}

private struct RoutineRunner: View {
    let run: RoutineRun
    let advance: (String?, Bool) -> Void
    let pause: () -> Void
    let resume: () -> Void
    let abandon: () -> Void
    @State private var response: String?
    @State private var isChoosingSkipReason = false
    @State private var confirmsAbandon = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var step: RoutineStep? { run.versionSnapshot.steps.first { $0.id == run.currentStepID } }
    private var index: Int { max(0, run.versionSnapshot.steps.firstIndex(where: { $0.id == run.currentStepID }) ?? 0) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 22) {
                        RoutineRunnerProgressHeader(
                            index: index,
                            stepCount: run.versionSnapshot.steps.count
                        )

                        if let step {
                            RoutineStepCard(
                                step: step,
                                run: run,
                                response: $response,
                                reduceMotion: reduceMotion
                            )
                        }

                        if run.status == .running {
                            runningControls
                        } else {
                            pausedControls
                        }
                    }
                    .padding(20)
                    .lifeBoardMotion(.cardReflow, value: run.currentStepID)
                }
            }
            .navigationTitle(run.versionSnapshot.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("End", role: .destructive) { confirmsAbandon = true }
                        .accessibilityIdentifier("track.routine.end")
                }
            }
            .confirmationDialog(
                "End this routine?",
                isPresented: $confirmsAbandon,
                titleVisibility: .visible
            ) {
                Button("End routine", role: .destructive) { abandon() }
                Button("Keep going", role: .cancel) {}
            } message: {
                Text("Your completed steps remain in the run history. The routine template is unchanged.")
            }
            .confirmationDialog(
                "Why are you skipping this step?",
                isPresented: $isChoosingSkipReason,
                titleVisibility: .visible
            ) {
                Button("Not needed today") { advance("Not needed today", true) }
                Button("Not now") { advance("Not now", true) }
                Button("Blocked") { advance("Blocked", true) }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("The reason appears in the run review without changing the routine template.")
            }
        }
    }

    @ViewBuilder private var primaryAction: some View {
        if let step, step.kind == .timer, let duration = step.duration {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                Button(timerRemaining(duration: duration, at: context.date) > 0 ? "Timer running" : "Continue") {
                    advance(response, false)
                }
                .buttonStyle(.lifeBoardPrimaryCompact)
                .controlSize(.large)
                .disabled(timerRemaining(duration: duration, at: context.date) > 0)
            }
        } else {
            Button("Continue") { advance(response, false) }
                .buttonStyle(.lifeBoardPrimaryCompact)
                .controlSize(.large)
                .disabled(step?.kind == .choice && response == nil)
        }
    }

    private var runningControls: some View {
        VStack(spacing: 10) {
            primaryAction
                .frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                Button("Pause", systemImage: "pause.fill", action: pause)
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 48)
                if step?.isSkippable == true {
                    Button("Skip", systemImage: "forward.fill") {
                        isChoosingSkipReason = true
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity, minHeight: 48)
                }
            }
        }
    }

    private var pausedControls: some View {
        let title = run.status == .interrupted ? "Routine interrupted" : "Routine paused"
        return VStack(spacing: 10) {
            Text(title)
                .font(Typography.sectionTitle())
            Text("Your place and timer are saved.")
                .font(.subheadline)
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            Button("Resume", systemImage: "play.fill", action: resume)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .padding(18)
        .lifeBoardClaySurface(.well, cornerRadius: 20)
        .buttonStyle(.lifeBoardPrimaryCompact)
    }

    private func timerRemaining(duration: TimeInterval, at date: Date) -> TimeInterval {
        let activatedAt = run.events.last?.occurredAt ?? run.startedAt
        let effectiveDate = run.pausedAt ?? date
        let elapsed = max(
            0,
            effectiveDate.timeIntervalSince(activatedAt) - run.effectiveCurrentStepPausedDuration
        )
        return max(0, duration - elapsed)
    }

}

private struct RoutineRunnerProgressHeader: View {
    let index: Int
    let stepCount: Int

    var body: some View {
        VStack(spacing: 7) {
            Text("Step \(min(index + 1, stepCount)) of \(stepCount)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            ProgressView(
                value: Double(index + 1),
                total: Double(max(1, stepCount))
            )
            .tint(Color(SemanticColorTokens.foundationFocusRing))
        }
    }
}

private struct RoutineStepCard: View {
    let step: RoutineStep
    let run: RoutineRun
    @Binding var response: String?
    let reduceMotion: Bool

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: symbol)
                .font(.largeTitle)
                .foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
                .symbolEffect(.breathe, options: .nonRepeating, value: step.id)
            Text(step.title)
                .font(Typography.screenTitle())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if step.kind == .timer, let duration = step.duration {
                RoutineTimerProgress(run: run, duration: duration)
            } else if let duration = step.duration {
                Text("About \(Int(duration / 60)) minutes")
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            if step.choices.isEmpty == false {
                RoutineResponseMenu(choices: step.choices, response: $response)
                    .frame(minHeight: 44)
            }
        }
        .id(step.id)
        .padding(24)
        .frame(maxWidth: .infinity, minHeight: 300)
        .lifeBoardClaySurface(.raised, cornerRadius: 28)
        .transition(
            reduceMotion
                ? .opacity
                : .asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .move(edge: .leading).combined(with: .opacity)
                )
        )
    }

    private var symbol: String {
        switch step.kind {
        case .task: "checkmark.circle"
        case .habit: "repeat.circle"
        case .checkIn: "heart.text.square"
        case .timer: "timer"
        case .instruction: "hand.point.up.left"
        case .choice: "point.3.connected.trianglepath.dotted"
        }
    }
}

private struct RoutineTimerProgress: View {
    let run: RoutineRun
    let duration: TimeInterval

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = timerRemaining(at: context.date)
            VStack(spacing: 8) {
                Text(durationLabel(remaining))
                    .font(Typography.screenTitle().monospacedDigit())
                    .contentTransition(.numericText(countsDown: true))
                ProgressView(
                    value: max(0, duration - remaining),
                    total: max(1, duration)
                )
                .tint(Color(SemanticColorTokens.foundationFocusRing))
            }
        }
    }

    private func timerRemaining(at date: Date) -> TimeInterval {
        let activatedAt = run.events.last?.occurredAt ?? run.startedAt
        let effectiveDate = run.pausedAt ?? date
        let elapsed = max(
            0,
            effectiveDate.timeIntervalSince(activatedAt) - run.effectiveCurrentStepPausedDuration
        )
        return max(0, duration - elapsed)
    }

    private func durationLabel(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.up)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct RoutineResponseMenu: View {
    let choices: [String]
    @Binding var response: String?

    var body: some View {
        Menu {
            ForEach(choices, id: \.self) { choice in
                Button(choice) { response = choice }
            }
        } label: {
            LabeledContent("Response", value: response ?? "Choose")
        }
    }
}

private struct HabitResilienceLibrary: View {
    private enum LoadState {
        case loading
        case loaded([TypedSourcePickerItem])
        case failed(String)
    }

    let repository: any TypedSourcePickerRepository
    let policies: [HabitResiliencePolicy]
    let groups: [HabitGroup]
    let history: [UUID: [HabitOccurrenceEvidence]]
    let save: (HabitResiliencePolicy) async -> Bool
    let recover: (UUID, PlanningDay) async -> HabitRecoveryReceipt?
    let undoRecovery: (UUID, PlanningDay) async -> Bool
    let saveGroup: (HabitGroup) -> Void
    let deleteGroup: (HabitGroup) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var state: LoadState = .loading
    @State private var groupPendingDeletion: HabitGroup?

    var body: some View {
        NavigationStack {
            Group {
                switch state {
                case .loading:
                    ProgressView("Loading habits")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .failed(let message):
                    ContentUnavailableView(
                        "Couldn’t load habits",
                        systemImage: "exclamationmark.triangle",
                        description: Text(message)
                    )
                case .loaded(let habits) where habits.isEmpty:
                    ContentUnavailableView(
                        "No active habits",
                        systemImage: "repeat",
                        description: Text("Create or resume a habit, then its resilience policy will appear here.")
                    )
                case .loaded(let habits):
                    // composer-kit:allow-list navigation list of groups and habits;
                    // NavigationLink rows and Section headers are load-bearing.
                    List {
                        Section("Groups") {
                            NavigationLink {
                                HabitGroupEditor(group: nil, nextOrdinal: groups.count, save: saveGroup)
                            } label: {
                                Label("Create group", systemImage: "plus.circle")
                            }
                            ForEach(groups) { group in
                                HStack {
                                    NavigationLink {
                                        HabitGroupEditor(group: group, nextOrdinal: group.ordinal, save: saveGroup)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(group.title)
                                            Text(group.planningContext.rawValue.capitalized)
                                                .font(.caption)
                                                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                                        }
                                    }
                                    Menu {
                                        Button("Delete group", systemImage: "trash", role: .destructive) {
                                            groupPendingDeletion = group
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                                    }
                                    .accessibilityLabel("Actions for \(group.title)")
                                }
                            }
                        }
                        Section("Habit policies") {
                            ForEach(habits) { habit in
                                NavigationLink {
                                    HabitResilienceEditor(
                                        habit: habit,
                                        policy: policy(for: habit.id),
                                        groups: groups,
                                        history: history[habit.id] ?? [],
                                        recover: recover,
                                        undoRecovery: undoRecovery,
                                        save: save
                                    )
                                } label: {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(habit.title)
                                        Text(policySummary(policy(for: habit.id)))
                                            .font(.caption)
                                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                                    }
                                    .padding(.vertical, 4)
                                }
                                .accessibilityIdentifier("track.habit.resilience.\(habit.id.uuidString)")
                            }
                        }
                    }
                    .lifeBoardFormSurface()
                }
            }
            .navigationTitle("Habit resilience")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } }
            }
            .task { await load() }
            .confirmationDialog(
                "Delete this habit group?",
                isPresented: Binding(get: { groupPendingDeletion != nil }, set: { if !$0 { groupPendingDeletion = nil } }),
                titleVisibility: .visible
            ) {
                Button("Delete group", role: .destructive) {
                    guard let group = groupPendingDeletion else { return }
                    groupPendingDeletion = nil
                    deleteGroup(group)
                }
                Button("Cancel", role: .cancel) { groupPendingDeletion = nil }
            } message: {
                Text("Habits keep their histories and policies. They simply return to the ungrouped state.")
            }
        }
    }

    private func load() async {
        state = .loading
        do {
            state = .loaded(try await repository.candidates(for: .habit, query: ""))
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private func policy(for habitID: UUID) -> HabitResiliencePolicy {
        policies.first(where: { $0.habitID == habitID }) ?? HabitResiliencePolicy(habitID: habitID)
    }

    private func policySummary(_ policy: HabitResiliencePolicy) -> String {
        let recovery = policy.recoveryEnabled ? "recovery on" : "recovery off"
        let framing = policy.streakPresentation == .gradeAndStreak ? "grade + streak" : "counts only"
        let exceptionCount = policy.offDays.count + policy.vacationRanges.count
        let offDays = exceptionCount == 0 ? "no exceptions" : "\(exceptionCount) intentional exception\(exceptionCount == 1 ? "" : "s")"
        return "\(recovery) · \(framing) · \(offDays)"
    }
}

private struct HabitGroupEditor: View {
    let group: HabitGroup?
    let nextOrdinal: Int
    let save: (HabitGroup) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var planningContext: PlanningContext

    init(group: HabitGroup?, nextOrdinal: Int, save: @escaping (HabitGroup) -> Void) {
        self.group = group
        self.nextOrdinal = nextOrdinal
        self.save = save
        _title = State(initialValue: group?.title ?? "")
        _planningContext = State(initialValue: group?.planningContext ?? .neutral)
    }

    var body: some View {
        ComposerScaffold(
            title: group == nil ? "New habit group" : "Edit habit group",
            confirmTitle: "Save",
            isConfirmEnabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false,
            identifier: "track.habitGroup.composer",
            onConfirm: commit
        ) {
            HabitGroupDetailSection(title: $title, planningContext: $planningContext)
        }
    }

    private func commit() {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        save(HabitGroup(
            id: group?.id ?? UUID(),
            title: trimmed,
            planningContext: planningContext,
            ordinal: group?.ordinal ?? nextOrdinal,
            createdAt: group?.createdAt ?? Date()
        ))
        dismiss()
    }
}

private struct HabitGroupDetailSection: View {
    @Binding var title: String
    @Binding var planningContext: PlanningContext

    var body: some View {
        ComposerSection(
            "Group",
            footer: "Groups organize presentation only. Moving a habit never rewrites its occurrence history or recurrence schedule."
        ) {
            ComposerField(
                "Group name",
                prompt: "Mornings, wind-down, admin…",
                text: $title,
                showsLabel: false,
                identifier: "track.habitGroup.name"
            )
            OptionRail(
                "Planning context",
                selection: $planningContext,
                values: PlanningContext.allCases,
                identifierPrefix: "track.habitGroup.context",
                title: { $0.rawValue.capitalized }
            )
        }
    }
}


private struct ResilienceGroupSection: View {
    @Binding var groupID: UUID?
    let groups: [HabitGroup]

    var body: some View {
        ComposerSection("Group") {
            MenuRow(
                "Habit group",
                selection: $groupID,
                values: [UUID?.none] + groups.map { UUID?.some($0.id) },
                title: { id in
                    guard let id else { return "Ungrouped" }
                    return groups.first { $0.id == id }?.title ?? "Ungrouped"
                },
                identifier: "track.resilience.group"
            )
        }
    }
}

private struct ResilienceRecoverySection: View {
    @Binding var recoveryEnabled: Bool
    @Binding var streakPresentation: HabitStreakPresentation

    var body: some View {
        ComposerSection(
            "Recovery",
            footer: "Recovered days count as completed eligible days, but remain visibly identified in history."
        ) {
            // Stays a real `Toggle` with a restyled `ToggleStyle`. The
            // accessibility-XXXL suite drives `app.switches["Allow recovery
            // completions"]`, and only a genuine Toggle reports as `.switch`.
            Toggle("Allow recovery completions", isOn: $recoveryEnabled)
                .toggleStyle(.lifeBoardClay)
            OptionRail(
                "Habit progress",
                selection: $streakPresentation,
                values: [.gradeAndStreak, .countsOnly],
                identifierPrefix: "track.resilience.presentation",
                title: { $0 == .gradeAndStreak ? "Grade and streak" : "Counts only" }
            )
        }
    }
}

private struct ResilienceMinimumSection: View {
    @Binding var minimumKind: HabitResilienceEditor.MinimumKind
    @Binding var minimumValue: Double
    @Binding var minimumUnit: String

    var body: some View {
        ComposerSection(
            "Gentle fallback",
            footer: "Low Energy can offer this kinder version without changing the full target or silently completing it."
        ) {
            OptionRail(
                "Low-energy minimum",
                selection: $minimumKind,
                values: HabitResilienceEditor.MinimumKind.allCases,
                identifierPrefix: "track.resilience.minimum",
                title: \.title
            )
            if [.quota, .timed, .quantitative].contains(minimumKind) {
                ComposerNumberField(
                    "Amount",
                    value: $minimumValue,
                    unit: minimumKind == .timed ? "minutes" : (minimumKind == .quantitative ? nil : "times")
                )
                if minimumKind == .quantitative {
                    ComposerField("Unit", prompt: "grams, pages, reps…", text: $minimumUnit)
                }
            }
        }
    }
}

private struct HabitResilienceEditor: View {
    fileprivate enum MinimumKind: String, CaseIterable, Identifiable {
        case none, binary, avoidance, quota, timed, quantitative
        var id: String { rawValue }
        var title: String {
            switch self {
            case .none: "None"
            case .binary: "One small check-in"
            case .avoidance: "Stay within the boundary"
            case .quota: "Reduced count"
            case .timed: "Reduced time"
            case .quantitative: "Reduced amount"
            }
        }
    }

    let habit: TypedSourcePickerItem
    let originalPolicy: HabitResiliencePolicy
    let groups: [HabitGroup]
    let history: [HabitOccurrenceEvidence]
    let recover: (UUID, PlanningDay) async -> HabitRecoveryReceipt?
    let undoRecovery: (UUID, PlanningDay) async -> Bool
    let save: (HabitResiliencePolicy) async -> Bool

    @Environment(\.dismiss) private var dismiss
    @State private var recoveryEnabled: Bool
    @State private var streakPresentation: HabitStreakPresentation
    @State private var offDays: Set<PlanningDay>
    @State private var groupID: UUID?
    @State private var recoveryReceipts: [HabitRecoveryReceipt]
    @State private var vacationRanges: [HabitVacationRange]
    @State private var backfillDays: Int
    @State private var minimumKind: MinimumKind
    @State private var minimumValue: Double
    @State private var minimumUnit: String
    @State private var vacationStart = Date()
    @State private var vacationEnd = Date()
    @State private var mutatingDays: Set<PlanningDay> = []
    @State private var commitPhase: LifeBoardComposerPhase = .idle

    init(
        habit: TypedSourcePickerItem,
        policy: HabitResiliencePolicy,
        groups: [HabitGroup],
        history: [HabitOccurrenceEvidence],
        recover: @escaping (UUID, PlanningDay) async -> HabitRecoveryReceipt?,
        undoRecovery: @escaping (UUID, PlanningDay) async -> Bool,
        save: @escaping (HabitResiliencePolicy) async -> Bool
    ) {
        self.habit = habit
        originalPolicy = policy
        self.groups = groups
        self.history = history
        self.recover = recover
        self.undoRecovery = undoRecovery
        self.save = save
        _recoveryEnabled = State(initialValue: policy.recoveryEnabled)
        _streakPresentation = State(initialValue: policy.streakPresentation)
        _offDays = State(initialValue: policy.offDays)
        _groupID = State(initialValue: policy.groupID)
        _recoveryReceipts = State(initialValue: policy.recoveryReceipts)
        _vacationRanges = State(initialValue: policy.vacationRanges)
        _backfillDays = State(initialValue: policy.backfillPolicy.allowedDays)
        _minimumKind = State(initialValue: Self.minimumKind(for: policy.minimumTarget))
        _minimumValue = State(initialValue: Self.minimumValue(for: policy.minimumTarget))
        _minimumUnit = State(initialValue: Self.minimumUnit(for: policy.minimumTarget))
    }

    var body: some View {
        // A pushed editor, so `ComposerPage` rather than the sheet
        // scaffold: the host already owns the navigation stack and the title.
        ComposerPage(
            subtitle: "How this habit behaves on the days it does not go to plan.",
            identifier: "track.resilience.editor"
        ) {
            ResilienceGroupSection(groupID: $groupID, groups: groups)
            ResilienceRecoverySection(
                recoveryEnabled: $recoveryEnabled,
                streakPresentation: $streakPresentation
            )
            ResilienceMinimumSection(
                minimumKind: $minimumKind,
                minimumValue: $minimumValue,
                minimumUnit: $minimumUnit
            )
            backfillAndVacationSection
            historySection
            exceptionsSection
        } commit: {
            ComposerCommitBar(
                title: "Save resilience",
                phase: commitPhase,
                isEnabled: true,
                identifier: "track.resilience.commit",
                action: commit
            )
        }
    }

    /// The last three sections stay computed rather than becoming structs
    /// because each closes over instance helpers (`recoveryHistoryRow`,
    /// `recentHistory`, `exceptionDays`). Extracting them would mean threading
    /// four more bindings and a view builder through an initializer for no
    /// structural gain; the first three sections carry the frame reduction.
    @ViewBuilder
    private var backfillAndVacationSection: some View {
        ComposerSection(
            "Backfill and vacation",
            footer: "Vacation days and intentional off days remain distinct from missing data and never lower the eligible grade denominator."
        ) {
            OptionRail(
                "Correction window",
                selection: $backfillDays,
                values: [0, 7, 30],
                identifierPrefix: "track.resilience.backfill",
                title: { $0 == 0 ? "Same day only" : "\($0) days" }
            )
            DateCapsuleRow("Vacation starts", selection: $vacationStart, components: [.date])
            DateCapsuleRow(
                "Vacation ends",
                selection: $vacationEnd,
                components: [.date],
                minimum: vacationStart
            )
            Button {
                let calendar = Calendar.current
                Haptic.commit.play()
                vacationRanges.append(HabitVacationRange(
                    startDay: PlanningDay(date: vacationStart, timeZone: calendar.timeZone, calendar: calendar),
                    endDay: PlanningDay(date: vacationEnd, timeZone: calendar.timeZone, calendar: calendar),
                    label: "Vacation"
                ))
            } label: {
                Label("Add vacation range", systemImage: "plus.circle")
            }
            .buttonStyle(.lifeBoardChip)

            ForEach(vacationRanges) { range in
                ComposerRow(range.label ?? "Intentional pause", detail: vacationSummary(range)) {
                    Button {
                        vacationRanges.removeAll { $0.id == range.id }
                    } label: {
                        Image(systemName: "trash")
                            .font(.lifeboard(.support))
                            .foregroundStyle(Color.lifeboard(.statusDanger))
                            .frame(width: 34, height: 34)
                            .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove vacation range")
                }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        ComposerSection(
            "30-day history",
            footer: "Recovery completes the canonical occurrence first, then stores a reversible receipt. Existing completions can be labelled as recovered without changing their completion state."
        ) {
            if recentHistory.isEmpty {
                Text("No due occurrences are available in the last 30 days.")
                    .font(.lifeboard(.support))
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            } else {
                ForEach(recentHistory) { occurrence in
                    recoveryHistoryRow(occurrence)
                }
            }
        }
    }

    @ViewBuilder
    private var exceptionsSection: some View {
        ComposerSection(
            "Intentional off-day exceptions",
            footer: "Exceptions use the local calendar day, survive travel and daylight-saving changes, and do not reduce the eligible grade denominator."
        ) {
            ForEach(exceptionDays, id: \.self) { day in
                Button {
                    Haptic.pick.play()
                    if offDays.contains(day) { offDays.remove(day) } else { offDays.insert(day) }
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exceptionTitle(day))
                                .font(.lifeboard(.body))
                                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                            Text(day.timeZoneIdentifier)
                                .font(.lifeboard(.caption2))
                                .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                        }
                        Spacer(minLength: 8)
                        Image(systemName: offDays.contains(day) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(Color(offDays.contains(day)
                                ? SemanticColorTokens.foundationApricotAccent
                                : SemanticColorTokens.inkTertiary))
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 48)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.lifeBoardClay(
                    offDays.contains(day) ? .resting : .well,
                    cornerRadius: Radius.compact + 2
                ))
                .accessibilityAddTraits(offDays.contains(day) ? [.isButton, .isSelected] : .isButton)
            }
        }
    }

    private func commit() {
        if case .running = commitPhase { return }
        var policy = originalPolicy
        policy.habitID = habit.id
        policy.groupID = groupID
        policy.recoveryEnabled = recoveryEnabled
        policy.streakPresentation = streakPresentation
        policy.offDays = offDays
        policy.recoveryReceipts = recoveryReceipts
        policy.vacationRanges = vacationRanges
        policy.backfillPolicy = backfillDays == 0 ? .disabled : .window(days: backfillDays)
        policy.minimumTarget = resolvedMinimumTarget
        policy.updatedAt = Date()
        commitPhase = .running(progress: nil)
        Task {
            if await save(policy) {
                commitPhase = .success(receipt: .init())
                dismiss()
            } else {
                commitPhase = .recoverableFailure(.init(
                    message: "Habit resilience could not be saved.",
                    recovery: .retry
                ))
            }
        }
    }

    @ViewBuilder
    private func recoveryHistoryRow(_ occurrence: HabitOccurrenceEvidence) -> some View {
        let receipt = recoveryReceipts.first(where: { $0.day == occurrence.day })
        let isRecovered = receipt != nil && occurrence.resolution == .completed
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(exceptionTitle(occurrence.day))
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                Text(historyStatus(occurrence, recovered: isRecovered))
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            Spacer(minLength: 8)
            if mutatingDays.contains(occurrence.day) {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Updating recovery")
            } else if let receipt {
                Button("Undo") {
                    Task {
                        mutatingDays.insert(occurrence.day)
                        let reverted = await undoRecovery(habit.id, occurrence.day)
                        if reverted { recoveryReceipts.removeAll { $0.id == receipt.id } }
                        mutatingDays.remove(occurrence.day)
                    }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Undo recovery for \(exceptionTitle(occurrence.day))")
            } else if recoveryEnabled && offDays.contains(occurrence.day) == false {
                Button(occurrence.resolution == .completed ? "Label recovered" : "Recover") {
                    Task {
                        mutatingDays.insert(occurrence.day)
                        if let receipt = await recover(habit.id, occurrence.day) {
                            recoveryReceipts.removeAll { $0.day == occurrence.day }
                            recoveryReceipts.append(receipt)
                        }
                        mutatingDays.remove(occurrence.day)
                    }
                }
                .buttonStyle(.lifeBoardPrimaryCompact)
                .tint(Color(SemanticColorTokens.foundationSageAccent))
                .accessibilityIdentifier("track.habit.recover.\(occurrence.id)")
            }
        }
        .frame(minHeight: 44)
    }

    private var recentHistory: [HabitOccurrenceEvidence] {
        history
            .filter(\.isDue)
            .sorted { $0.day > $1.day }
            .prefix(30)
            .map { $0 }
    }

    private func historyStatus(_ occurrence: HabitOccurrenceEvidence, recovered: Bool) -> String {
        if offDays.contains(occurrence.day) { return "Intentional off day" }
        if recovered { return "Recovered · counts toward grade" }
        switch occurrence.resolution {
        case .due, .missing: return "No data"
        case .explicitZero: return "Recorded zero"
        case .partial:
            if let value = occurrence.recordedValue { return "In progress · \(value.formatted())" }
            return "In progress"
        case .completed: return "Completed"
        case .abstained: return "Abstained"
        case .lapsed: return "Lapsed"
        case .manuallySkipped: return "Skipped"
        case .offDay: return "Intentional off day"
        case .paused: return "Paused"
        case .failed: return occurrence.failureReason.map { "Couldn’t update · \($0)" } ?? "Couldn’t update"
        case .unresolved: return "Needs review"
        case .recovered: return "Recovered · counts toward grade"
        }
    }

    private var resolvedMinimumTarget: HabitTarget? {
        let positiveValue = max(0, minimumValue)
        switch minimumKind {
        case .none: return nil
        case .binary: return .binary
        case .avoidance: return .avoidance
        case .quota: return positiveValue >= 1 ? .quota(count: Int(positiveValue.rounded()), period: .day) : nil
        case .timed: return positiveValue > 0 ? .timed(seconds: positiveValue * 60) : nil
        case .quantitative:
            let unit = minimumUnit.trimmingCharacters(in: .whitespacesAndNewlines)
            return positiveValue > 0 && !unit.isEmpty ? .quantitative(value: positiveValue, unit: unit) : nil
        }
    }

    private static func minimumKind(for target: HabitTarget?) -> MinimumKind {
        switch target {
        case nil: .none
        case .binary: .binary
        case .avoidance: .avoidance
        case .quota: .quota
        case .timed: .timed
        case .quantitative: .quantitative
        }
    }

    private static func minimumValue(for target: HabitTarget?) -> Double {
        switch target {
        case let .quota(count, _): Double(count)
        case let .timed(seconds): seconds / 60
        case let .quantitative(value, _): value
        default: 1
        }
    }

    private static func minimumUnit(for target: HabitTarget?) -> String {
        if case let .quantitative(_, unit) = target { return unit }
        return ""
    }

    private func vacationSummary(_ range: HabitVacationRange) -> String {
        let start = range.startDay.startDate()?.formatted(.dateTime.month(.abbreviated).day()) ?? "Start"
        let end = range.endDay.startDate()?.formatted(.dateTime.month(.abbreviated).day()) ?? "End"
        return "\(start) – \(end)"
    }

    private var exceptionDays: [PlanningDay] {
        let calendar = Calendar.current
        let anchor = calendar.startOfDay(for: Date())
        return (-7...14).compactMap { offset in
            calendar.date(byAdding: .day, value: offset, to: anchor).map {
                PlanningDay(date: $0, timeZone: calendar.timeZone, calendar: calendar)
            }
        }
    }

    private func exceptionTitle(_ day: PlanningDay) -> String {
        guard let date = day.startDate() else { return "Local day" }
        if Calendar.current.isDateInToday(date) { return "Today · \(date.formatted(.dateTime.month(.abbreviated).day()))" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}


/// One editable routine step.
///
/// Extracted from `RoutineComposer.body`, which was type-checking at 518 ms —
/// over the 500 ms threshold this repo treats as a required split. The step row
/// is the expensive part: six conditional branches over `RoutineStepKind`, two
/// nested `Picker`s and a link button, all previously inlined into the enclosing
/// `Form`'s tuple. Splitting it gives the row its own `body` call and its own
/// stack frame, which is the same discipline the clay composers follow.
private struct RoutineStepEditorRow: View {
    @Binding var step: RoutineComposer.DraftStep
    let choices: [String]
    let forwardDestinations: [RoutineComposer.DraftStep]
    let branchDestination: (String) -> Binding<UUID?>
    let pickLink: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("Step title", text: $step.title)
            Picker("Kind", selection: $step.kind) {
                ForEach(RoutineStepKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
            }
            if step.kind == .timer {
                Stepper("Duration: \(Int(step.durationMinutes)) minutes", value: $step.durationMinutes, in: 1...120)
            }
            if step.kind == .choice {
                choiceEditor
            }
            if step.kind == .task || step.kind == .habit {
                linkButton
            }
            Toggle("Required", isOn: $step.isRequired)
            Toggle("May skip", isOn: $step.isSkippable)
        }
    }

    @ViewBuilder
    private var choiceEditor: some View {
        TextField("Choices, separated by commas", text: $step.choices)
        ForEach(choices, id: \.self) { choice in
            Picker("If \u{201C}\(choice)\u{201D}", selection: branchDestination(choice)) {
                Text("Continue in order").tag(UUID?.none)
                ForEach(forwardDestinations) { destination in
                    Text(destination.title).tag(UUID?.some(destination.id))
                }
            }
        }
    }

    private var linkButton: some View {
        Button(action: pickLink) {
            HStack {
                Text(step.linkedTitle.isEmpty ? "Link a \(step.kind == .task ? "task" : "habit")" : step.linkedTitle)
                    .foregroundStyle(Color(step.linkedTitle.isEmpty ? SemanticColorTokens.inkSecondary : SemanticColorTokens.inkPrimary))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
            }
            .contentShape(Rectangle())
        }
        .accessibilityIdentifier("routine.step.link")
    }
}

private struct RoutineComposer: View {
    fileprivate struct DraftStep: Identifiable {
        var id: UUID
        var title: String
        var kind: RoutineStepKind
        var durationMinutes: Double
        var isRequired: Bool
        var isSkippable: Bool
        var choices: String
        var branches: [RoutineBranchCondition]
        var linkedID: String
        var linkedTitle: String

        init(step: RoutineStep? = nil) {
            id = step?.id ?? UUID()
            title = step?.title ?? ""
            kind = step?.kind ?? .instruction
            durationMinutes = max(1, (step?.duration ?? 120) / 60)
            isRequired = step?.isRequired ?? true
            isSkippable = step?.isSkippable ?? false
            choices = step?.choices.joined(separator: ", ") ?? ""
            branches = step?.branches ?? []
            linkedID = step?.linkedEntityID?.uuidString ?? ""
            linkedTitle = step?.linkedEntityID == nil ? "" : "Linked \((step?.kind ?? .task) == .habit ? "habit" : "task")"
        }
    }

    let existing: RoutineDefinition?
    let schedule: RoutineSchedule?
    let sourcePickerRepository: any TypedSourcePickerRepository
    let save: (String, [RoutineStep], Set<Int>, ResolvedDaypart?) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var steps: [DraftStep]
    @State private var weekdays: Set<Int>
    @State private var daypart: ResolvedDaypart?
    @State private var pickingStep: StepLinkTarget?
    @State private var commitPhase: LifeBoardComposerPhase = .idle

    private struct StepLinkTarget: Identifiable { let id: UUID }

    init(
        existing: RoutineDefinition? = nil,
        schedule: RoutineSchedule? = nil,
        sourcePickerRepository: any TypedSourcePickerRepository,
        save: @escaping (String, [RoutineStep], Set<Int>, ResolvedDaypart?) async -> Bool
    ) {
        self.existing = existing
        self.schedule = schedule
        self.sourcePickerRepository = sourcePickerRepository
        self.save = save
        _title = State(initialValue: existing?.title ?? "")
        _steps = State(initialValue: existing.map { definition in
            definition.steps.map { DraftStep(step: $0) }
        } ?? [.init()])
        _weekdays = State(initialValue: schedule?.weekdays ?? Set(1...7))
        _daypart = State(initialValue: schedule == nil ? .morning : schedule?.daypart)
    }

    var body: some View {
        NavigationStack {
            // composer-kit:allow-form — the step list below depends on List
            // semantics (.onDelete, .onMove, editMode). Moving this to the clay
            // scaffold would silently remove reorder and swipe-delete from a
            // fifteen-step editor, which is a functional regression the visual
            // win does not justify. The step row is extracted to
            // `RoutineStepEditorRow` so the stack-budget rule still holds.
            Form {
                Section("Routine") {
                    TextField("Routine title", text: $title)
                    if existing == nil {
                        Menu("Start from a template", systemImage: "sparkles.rectangle.stack") {
                            ForEach(
                                RoutineTemplateKind.allCases.filter { $0 != .custom },
                                id: \.self
                            ) { kind in
                                Button(templateTitle(kind)) { applyTemplate(kind) }
                            }
                        }
                        .frame(minHeight: 44)
                    }
                    Picker("Daypart", selection: $daypart) {
                        Text("Any daypart").tag(ResolvedDaypart?.none)
                        ForEach(ResolvedDaypart.allCases, id: \.self) { Text($0.rawValue.capitalized).tag(ResolvedDaypart?.some($0)) }
                    }
                    HStack {
                        ForEach(1...7, id: \.self) { weekday in
                            Button {
                                if weekdays.contains(weekday) { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
                            } label: {
                                Text(Calendar.current.veryShortStandaloneWeekdaySymbols[weekday - 1])
                                    .font(.lifeboard(weekdays.contains(weekday) ? .bodyStrong : .body))
                                    .foregroundStyle(Color(weekdays.contains(weekday)
                                        ? SemanticColorTokens.inkPrimary
                                        : SemanticColorTokens.inkSecondary))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .lifeBoardClaySurface(
                                        weekdays.contains(weekday) ? .raised : .well,
                                        cornerRadius: Radius.pill
                                    )
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                            .accessibilityAddTraits(weekdays.contains(weekday) ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }
                Section("Steps") {
                    ForEach($steps) { $step in
                        RoutineStepEditorRow(
                            step: $step,
                            choices: parsedChoices(step.choices),
                            forwardDestinations: forwardDestinations(after: step.id),
                            branchDestination: { response in
                                branchDestinationBinding(stepID: step.id, response: response)
                            },
                            pickLink: { pickingStep = StepLinkTarget(id: step.id) }
                        )
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                    Button("Add step", systemImage: "plus") { steps.append(.init()) }
                }
                Text("Routine history stores this version. Future edits never rewrite prior runs.")
                    .font(.caption)
                    .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
            }
            .lifeBoardFormSurface()
            .navigationTitle(existing == nil ? "New routine" : "Edit routine")
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                ComposerCommitBar(
                    title: existing == nil ? "Create routine" : "Save routine",
                    phase: commitPhase,
                    isEnabled: isValid,
                    action: saveRoutine
                )
                .accessibilityIdentifier("track.routine.commit")
            }
            .sheet(item: $pickingStep) { target in
                let kind: TypedSourceKind = steps.first { $0.id == target.id }?.kind == .habit ? .habit : .task
                TypedSourcePickerView(
                    title: "Link a \(kind.title.lowercased())",
                    kinds: [kind],
                    repository: sourcePickerRepository
                ) { item in
                    if let index = steps.firstIndex(where: { $0.id == target.id }) {
                        steps[index].linkedID = item.id.uuidString
                        steps[index].linkedTitle = item.title
                    }
                }
            }
        }
    }

    private var isValid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && weekdays.isEmpty == false
            && steps.isEmpty == false
            && steps.allSatisfy { $0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
            && RoutineValidator().validate(
                RoutineDefinition(title: title, steps: routineSteps())
            ).isValid
    }

    private func saveRoutine() {
        if case .running = commitPhase { return }
        let committedTitle = title
        let committedSteps = routineSteps()
        let committedWeekdays = weekdays
        let committedDaypart = daypart
        commitPhase = .running(progress: nil)
        Task {
            if await save(committedTitle, committedSteps, committedWeekdays, committedDaypart) {
                commitPhase = .success(receipt: .init())
                dismiss()
            } else {
                commitPhase = .recoverableFailure(.init(
                    message: "The routine could not be saved.",
                    recovery: .retry
                ))
            }
        }
    }

    private func routineSteps() -> [RoutineStep] {
        steps.enumerated().map { index, draft in
            let linkedID = UUID(uuidString: draft.linkedID.trimmingCharacters(in: .whitespacesAndNewlines))
            return RoutineStep(
                id: draft.id,
                title: draft.title,
                kind: draft.kind,
                ordinal: index,
                duration: draft.kind == .timer ? draft.durationMinutes * 60 : nil,
                isRequired: draft.isRequired,
                isSkippable: draft.isSkippable,
                linkedEntityID: linkedID,
                linkedMutation: draft.kind == .task ? .completeTask : draft.kind == .habit ? .completeHabitOccurrence : nil,
                choices: draft.kind == .choice
                    ? parsedChoices(draft.choices)
                    : [],
                branches: draft.kind == .choice
                    ? draft.branches.filter { branch in
                        parsedChoices(draft.choices).contains(branch.expectedResponse)
                            && forwardDestinations(after: draft.id).contains(where: { destination in
                                destination.id == branch.destinationStepID
                            })
                    }
                    : []
            )
        }
    }

    private func parsedChoices(_ value: String) -> [String] {
        value.split(separator: ",", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func forwardDestinations(after stepID: UUID) -> [DraftStep] {
        guard let index = steps.firstIndex(where: { $0.id == stepID }) else { return [] }
        return Array(steps.dropFirst(index + 1))
    }

    private func branchDestinationBinding(
        stepID: UUID,
        response: String
    ) -> Binding<UUID?> {
        Binding(
            get: {
                steps.first(where: { $0.id == stepID })?.branches.first(where: {
                    $0.sourceStepID == stepID && $0.expectedResponse == response
                })?.destinationStepID
            },
            set: { destinationID in
                guard let index = steps.firstIndex(where: { $0.id == stepID }) else { return }
                steps[index].branches.removeAll {
                    $0.sourceStepID == stepID && $0.expectedResponse == response
                }
                if let destinationID {
                    steps[index].branches.append(.init(
                        sourceStepID: stepID,
                        operation: .equals,
                        expectedResponse: response,
                        destinationStepID: destinationID
                    ))
                }
            }
        )
    }

    private func applyTemplate(_ kind: RoutineTemplateKind) {
        guard let template = RoutineTemplateCatalog.definition(for: kind) else { return }
        title = template.title
        steps = template.steps.map { DraftStep(step: $0) }
        daypart = switch kind {
        case .morning, .workStart: .morning
        case .evening, .shutdown: .evening
        case .workout, .care, .custom: nil
        }
    }

    private func templateTitle(_ kind: RoutineTemplateKind) -> String {
        switch kind {
        case .morning: "Morning"
        case .evening: "Evening"
        case .workStart: "Work start"
        case .shutdown: "Shutdown"
        case .workout: "Workout"
        case .care: "Care"
        case .custom: "Custom"
        }
    }
}

private struct MoodTrendStrip: View {
    let points: [MoodTrendPoint]

    var body: some View {
        GeometryReader { geometry in
            let coordinates = Array(points.enumerated()).map { index, point in
                CGPoint(
                    x: points.count == 1 ? geometry.size.width / 2 : geometry.size.width * CGFloat(index) / CGFloat(points.count - 1),
                    y: geometry.size.height * CGFloat(1 - ((point.valence + 4) / 8))
                )
            }
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height / 2))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height / 2))
                }
                .stroke(Color(SemanticColorTokens.foundationHairline), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                Path { path in
                    guard let first = coordinates.first else { return }
                    path.move(to: first)
                    for coordinate in coordinates.dropFirst() { path.addLine(to: coordinate) }
                }
                .stroke(
                    Color(SemanticColorTokens.foundationApricotAccent),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                ForEach(Array(points.enumerated()), id: \.element.id) { index, _ in
                    Circle()
                        .fill(Color(SemanticColorTokens.foundationSurfaceSolid))
                        .overlay {
                            Circle().stroke(Color(SemanticColorTokens.foundationApricotAccent), lineWidth: 2)
                        }
                        .frame(width: 9, height: 9)
                        .position(coordinates[index])
                }
            }
        }
        .frame(height: 62)
        .accessibilityHidden(true)
    }
}

private struct MoodEnergyComposer: View {
    let checkIn: MoodEnergyCheckInValue?
    let save: (MoodEnergyCheckInValue) async -> Bool
    let delete: ((MoodEnergyCheckInValue) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var mood: JournalMood
    @State private var energy: Int
    @State private var includesEnergy: Bool
    @State private var commitPhase: LifeBoardComposerPhase = .idle
    @State private var successTrigger = 0

    init(
        checkIn: MoodEnergyCheckInValue? = nil,
        save: @escaping (MoodEnergyCheckInValue) async -> Bool,
        delete: ((MoodEnergyCheckInValue) -> Void)? = nil
    ) {
        self.checkIn = checkIn
        self.save = save
        self.delete = delete
        _mood = State(initialValue: checkIn?.mood ?? .none)
        _energy = State(initialValue: checkIn?.energy ?? 3)
        _includesEnergy = State(initialValue: checkIn?.energy != nil || checkIn == nil)
    }

    var body: some View {
        ComposerScaffold(
            title: checkIn == nil ? "Mood + energy" : "Edit check-in",
            subtitle: "However today actually is.",
            identifier: "track.mood.composer"
        ) {
            MoodChoiceSection(mood: $mood)
            MoodEnergySection(includesEnergy: $includesEnergy, energy: $energy)
            MoodDeleteSection(isDeletable: checkIn != nil && delete != nil) {
                guard let checkIn else { return }
                delete?(checkIn)
                dismiss()
            }
        } commit: {
            ComposerCommitBar(
                title: checkIn == nil ? "Save check-in" : "Save changes",
                phase: commitPhase,
                isEnabled: true,
                identifier: "track.mood.commit",
                action: saveValue
            )
        }
        .lifeboardCompletionBurst(trigger: successTrigger)
    }

    private func saveValue() {
        if case .running = commitPhase { return }
        var value = checkIn ?? MoodEnergyCheckInValue(mood: mood, energy: includesEnergy ? energy : nil)
        value.mood = mood
        value.energy = includesEnergy ? energy : nil
        commitPhase = .running(progress: nil)
        Task {
            if await save(value) {
                commitPhase = .success(receipt: .init())
                // Inside the success arm on purpose: the burst is a claim that
                // something was recorded, so it cannot be allowed to fire on a
                // path where the write failed.
                successTrigger &+= 1
                dismiss()
            } else {
                commitPhase = .recoverableFailure(.init(
                    message: "The check-in could not be saved.",
                    recovery: .retry
                ))
            }
        }
    }
}

/// One struct per section, never a computed `some View`. See the note on
/// `ComposerScaffold`: a composer body that inlines every section
/// builds all of their view values inside a single frame, which is the shape
/// that exhausts the main thread's stack at `-Onone`.
private struct MoodChoiceSection: View {
    @Binding var mood: JournalMood

    var body: some View {
        ComposerSection(
            "Mood",
            detail: "Pick the nearest one. There is no wrong answer and no score."
        ) {
            OptionRail(
                "Mood",
                selection: $mood,
                values: JournalMood.dialOrder,
                identifierPrefix: "track.mood.choice",
                title: \.title,
                showsLabel: false,
                // Mood is the one choice on this screen that carries weight, so
                // it is the one that earns the bloom.
                pressBloomTint: Color(SemanticColorTokens.foundationSunAccent)
            )
            Text(mood.supportiveCopy)
                .font(.lifeboard(.support))
                .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                .lifeBoardMotion(.contentInsertion, value: mood)
        }
    }
}

private struct MoodEnergySection: View {
    @Binding var includesEnergy: Bool
    @Binding var energy: Int

    var body: some View {
        ComposerSection(
            "Energy",
            footer: "This records your signal. LifeBoard does not assign a clinical interpretation."
        ) {
            Toggle("Record energy", isOn: $includesEnergy)
                .toggleStyle(.lifeBoardClay)
            if includesEnergy {
                BeadStepper(
                    "Energy",
                    value: $energy,
                    in: 1...5,
                    beadSymbol: "bolt.fill",
                    caption: Self.caption
                )
            }
        }
    }

    private static func caption(_ level: Int) -> String {
        switch level {
        case 1: "Running on empty"
        case 2: "Low"
        case 3: "Steady"
        case 4: "Good"
        default: "Full tank"
        }
    }
}

private struct MoodDeleteSection: View {
    let isDeletable: Bool
    let perform: () -> Void

    var body: some View {
        if isDeletable {
            DangerRow(
                "Delete check-in",
                confirmationTitle: "Delete this check-in?",
                confirmationMessage: "This removes only this recorded check-in. Other Journal and Track data stays intact.",
                perform: perform
            )
        }
    }
}

private struct SleepContextComposer: View {
    let existing: SleepContextRecord?
    let save: (SleepContextRecord) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var bedtime: Date
    @State private var wake: Date
    @State private var rest: Int
    @State private var interruptions: Int
    @State private var notes: String
    @State private var commitPhase: LifeBoardComposerPhase = .idle
    @State private var successTrigger = 0

    init(existing: SleepContextRecord? = nil, save: @escaping (SleepContextRecord) async -> Bool) {
        self.existing = existing
        self.save = save
        let defaultWake = Date()
        _bedtime = State(initialValue: existing?.bedtime ?? Calendar.current.date(byAdding: .hour, value: -8, to: defaultWake) ?? defaultWake)
        _wake = State(initialValue: existing?.wakeTime ?? defaultWake)
        _rest = State(initialValue: existing?.perceivedRest ?? 3)
        _interruptions = State(initialValue: existing?.interruptionCount ?? 0)
        _notes = State(initialValue: existing?.notes ?? "")
    }

    var body: some View {
        ComposerScaffold(
            title: existing == nil ? "Sleep context" : "Edit sleep context",
            subtitle: "Record what the night was actually like.",
            isPrivacySensitive: true,
            identifier: "track.sleep.composer"
        ) {
            SleepWindowSection(bedtime: $bedtime, wake: $wake)
            SleepQualitySection(rest: $rest, interruptions: $interruptions)
            SleepNotesSection(notes: $notes)
        } commit: {
            ComposerCommitBar(
                title: existing == nil ? "Save sleep context" : "Save changes",
                phase: commitPhase,
                isEnabled: wake >= bedtime,
                identifier: "track.sleep.commit",
                action: saveValue
            )
        }
        .lifeboardCompletionBurst(trigger: successTrigger)
    }

    private func saveValue() {
        if case .running = commitPhase { return }
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let record = SleepContextRecord(
            id: existing?.id ?? UUID(),
            bedtime: bedtime,
            wakeTime: wake,
            perceivedRest: rest,
            interruptionCount: interruptions,
            notes: trimmed.isEmpty ? nil : trimmed,
            createdAt: existing?.createdAt ?? Date()
        )
        commitPhase = .running(progress: nil)
        Task {
            if await save(record) {
                commitPhase = .success(receipt: .init())
                successTrigger &+= 1
                dismiss()
            } else {
                commitPhase = .recoverableFailure(.init(
                    message: "The sleep context could not be saved.",
                    recovery: .retry
                ))
            }
        }
    }
}

private struct SleepWindowSection: View {
    @Binding var bedtime: Date
    @Binding var wake: Date

    var body: some View {
        ComposerSection(
            "The night",
            detail: "Bedtime and wake time as you remember them."
        ) {
            DateCapsuleRow("Bedtime", selection: $bedtime)
            // The old `in: bedtime...` validation moves onto the control, so an
            // impossible wake time cannot be entered and then rejected by a
            // disabled commit button the person has to reason about.
            DateCapsuleRow("Wake time", selection: $wake, minimum: bedtime)
        }
    }
}

private struct SleepQualitySection: View {
    @Binding var rest: Int
    @Binding var interruptions: Int

    var body: some View {
        ComposerSection("How it felt") {
            BeadStepper(
                "Perceived rest",
                value: $rest,
                in: 1...5,
                beadSymbol: "moon.fill",
                caption: Self.restCaption
            )
            ComposerDial(
                "Times awake",
                value: Binding(
                    get: { Double(interruptions) },
                    set: { interruptions = Int($0.rounded()) }
                ),
                in: 0...20,
                step: 1,
                unit: "Interruptions",
                diameter: 132
            )
        }
    }

    private static func restCaption(_ level: Int) -> String {
        switch level {
        case 1: "Wrecked"
        case 2: "Rough"
        case 3: "Okay"
        case 4: "Good"
        default: "Rested"
        }
    }
}

private struct SleepNotesSection: View {
    @Binding var notes: String

    var body: some View {
        ComposerSection(
            "Anything worth remembering",
            footer: "Sleep context stays out of widgets, Spotlight, Siri, and lock-screen previews."
        ) {
            ComposerField(
                "Private notes",
                prompt: "Woke at 3, back asleep by 4…",
                text: $notes,
                shape: .prose(lineLimit: 3...8),
                showsLabel: false
            )
        }
    }
}

struct GoalComposer: View {
    let existing: GoalDefinition?
    let save: (GoalDraft) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var type: GoalType
    @State private var target: Double
    @State private var hasBaseline: Bool
    @State private var baseline: Double
    @State private var unit: String
    @State private var targetDate: Date
    @State private var intent: GoalIntent
    @State private var confidence: GoalConfidence?
    @State private var whyItMatters: String
    @State private var checkInCadence: GoalCheckInCadence
    @State private var commitPhase: LifeBoardComposerPhase = .idle
    @State private var successTrigger = 0

    init(
        existing: GoalDefinition? = nil,
        save: @escaping (GoalDraft) async -> Bool
    ) {
        self.existing = existing
        self.save = save
        _title = State(initialValue: existing?.title ?? "")
        _type = State(initialValue: existing?.type ?? .completion)
        let storedTarget = existing?.targetValue ?? 1
        _target = State(initialValue: existing?.type == .duration ? storedTarget / 60 : storedTarget)
        _hasBaseline = State(initialValue: existing?.baselineValue != nil)
        _baseline = State(initialValue: existing?.type == .duration
            ? (existing?.baselineValue ?? 0) / 60
            : existing?.baselineValue ?? 0)
        _unit = State(initialValue: existing?.unitLabel == "seconds" ? "" : existing?.unitLabel ?? "")
        _targetDate = State(initialValue: existing?.targetDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
        _intent = State(initialValue: existing?.effectiveIntent ?? .outcome)
        _confidence = State(initialValue: existing?.confidenceRaw.flatMap(GoalConfidence.init(rawValue:)))
        _whyItMatters = State(initialValue: existing?.whyItMatters ?? "")
        _checkInCadence = State(initialValue: existing?.checkInCadenceRaw.flatMap(GoalCheckInCadence.init(rawValue:)) ?? .weekly)
    }

    var body: some View {
        ComposerScaffold(
            title: existing == nil ? "New goal" : "Edit goal",
            subtitle: "One thing you want to be true later.",
            identifier: "track.goal.composer"
        ) {
            GoalIdentitySection(title: $title, type: $type, intent: $intent)
            GoalTargetSection(
                type: type,
                target: $target,
                hasBaseline: $hasBaseline,
                baseline: $baseline,
                unit: $unit,
                targetDate: $targetDate
            )
            GoalCadenceSection(confidence: $confidence, checkInCadence: $checkInCadence)
            GoalMeaningSection(whyItMatters: $whyItMatters)
        } commit: {
            ComposerCommitBar(
                title: existing == nil ? "Create goal" : "Save goal",
                phase: commitPhase,
                isEnabled: canCommit,
                identifier: "track.goal.commit",
                action: commit
            )
        }
        .lifeboardCompletionBurst(trigger: successTrigger)
    }

    private var usesNumericTarget: Bool { type == .count || type == .quantity || type == .duration }
    private var canCommit: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && (usesNumericTarget == false || target > 0)
    }

    private func commit() {
        if case .running = commitPhase { return }
        let draft = GoalDraft(
            areaID: existing?.areaID,
            title: title,
            type: type,
            intent: intent,
            targetValue: usesNumericTarget ? (type == .duration ? target * 60 : target) : nil,
            baselineValue: usesNumericTarget && hasBaseline
                ? (type == .duration ? baseline * 60 : baseline)
                : nil,
            unitLabel: type == .quantity ? unit : type == .duration ? "seconds" : nil,
            targetDate: type == .targetDate ? targetDate : nil,
            confidence: confidence,
            whyItMatters: whyItMatters,
            checkInCadence: checkInCadence
        )
        commitPhase = .running(progress: nil)
        Task {
            if await save(draft) {
                commitPhase = .success(receipt: .init())
                successTrigger &+= 1
                dismiss()
            } else {
                commitPhase = .recoverableFailure(.init(
                    message: "The goal could not be saved.",
                    recovery: .retry
                ))
            }
        }
    }

    private func goalTypeTitle(_ type: GoalType) -> String {
        switch type {
        case .completion: "Completion"
        case .count: "Count"
        case .quantity: "Quantity"
        case .duration: "Duration"
        case .targetDate: "Target date"
        }
    }
    private func goalIntentTitle(_ intent: GoalIntent) -> String {
        switch intent {
        case .outcome: "Outcome"
        case .maintenance: "Maintenance"
        case .milestone: "Milestone"
        case .cumulative: "Cumulative"
        case .directional: "Directional"
        }
    }
    private func checkInTitle(_ cadence: GoalCheckInCadence) -> String {
        switch cadence {
        case .weekly: "Weekly"
        case .biweekly: "Every two weeks"
        case .monthly: "Monthly"
        case .manual: "When I choose"
        }
    }
}

private struct GoalIdentitySection: View {
    @Binding var title: String
    @Binding var type: GoalType
    @Binding var intent: GoalIntent

    var body: some View {
        ComposerSection("Goal") {
            ComposerField(
                "Goal title",
                prompt: "What you want to be true",
                text: $title,
                showsLabel: false,
                identifier: "track.goal.title"
            )
            OptionRail(
                "Goal type",
                selection: $type,
                values: GoalType.allCases,
                identifierPrefix: "track.goal.type",
                title: GoalComposerCopy.typeTitle,
                pressBloomTint: Color(SemanticColorTokens.foundationSunAccent)
            )
            OptionRail(
                "Intent",
                selection: $intent,
                values: GoalIntent.allCases,
                identifierPrefix: "track.goal.intent",
                title: GoalComposerCopy.intentTitle
            )
        }
    }
}

private struct GoalTargetSection: View {
    let type: GoalType
    @Binding var target: Double
    @Binding var hasBaseline: Bool
    @Binding var baseline: Double
    @Binding var unit: String
    @Binding var targetDate: Date

    private var usesNumericTarget: Bool { type == .count || type == .quantity || type == .duration }

    var body: some View {
        if usesNumericTarget || type == .targetDate {
            ComposerSection("Target") {
                if usesNumericTarget {
                    ValueDrum(
                        type == .duration ? "Target minutes" : "Target",
                        value: $target,
                        in: 0...1_000,
                        step: 1,
                        coarseStep: 10,
                        unit: type == .duration ? "minutes" : (unit.isEmpty ? "units" : unit),
                        fractionDigits: 0,
                        identifier: "track.goal.target"
                    )
                    Toggle("Use a baseline", isOn: $hasBaseline)
                        .toggleStyle(.lifeBoardClay)
                    if hasBaseline {
                        ComposerNumberField(
                            type == .duration ? "Baseline minutes" : "Baseline",
                            value: $baseline
                        )
                    }
                    if type == .quantity {
                        ComposerField("Unit", prompt: "Optional", text: $unit)
                    }
                }
                if type == .targetDate {
                    DateCapsuleRow("Target date", selection: $targetDate, components: [.date])
                }
            }
        }
    }
}

private struct GoalCadenceSection: View {
    @Binding var confidence: GoalConfidence?
    @Binding var checkInCadence: GoalCheckInCadence

    var body: some View {
        ComposerSection("Rhythm") {
            OptionRail(
                "Confidence",
                selection: $confidence,
                values: [GoalConfidence?.none] + GoalConfidence.allCases.map(Optional.some),
                identifierPrefix: "track.goal.confidence",
                title: { $0.map { $0.rawValue.capitalized } ?? "Not set" }
            )
            MenuRow(
                "Check in",
                selection: $checkInCadence,
                values: GoalCheckInCadence.allCases,
                title: GoalComposerCopy.checkInTitle,
                identifier: "track.goal.checkIn"
            )
        }
    }
}

private struct GoalMeaningSection: View {
    @Binding var whyItMatters: String

    var body: some View {
        ComposerSection(
            "Why it matters",
            footer: "Progress comes only from sources you explicitly link after creating the goal."
        ) {
            ComposerField(
                "Why it matters",
                prompt: "The reason, in your words…",
                text: $whyItMatters,
                shape: .prose(lineLimit: 3...8),
                showsLabel: false
            )
        }
    }
}

/// Shared display copy so the sections and the parent agree on one spelling.
private enum GoalComposerCopy {
    static func typeTitle(_ type: GoalType) -> String {
        switch type {
        case .completion: "Completion"
        case .count: "Count"
        case .quantity: "Quantity"
        case .duration: "Duration"
        case .targetDate: "Target date"
        }
    }

    static func intentTitle(_ intent: GoalIntent) -> String {
        switch intent {
        case .outcome: "Outcome"
        case .maintenance: "Maintenance"
        case .milestone: "Milestone"
        case .cumulative: "Cumulative"
        case .directional: "Directional"
        }
    }

    static func checkInTitle(_ cadence: GoalCheckInCadence) -> String {
        switch cadence {
        case .weekly: "Weekly"
        case .biweekly: "Every two weeks"
        case .monthly: "Monthly"
        case .manual: "When I choose"
        }
    }
}

struct GoalLinkComposer: View {
    let goal: GoalDefinition
    let sourcePickerRepository: any TypedSourcePickerRepository
    let save: (GoalLinkSource, UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selection: TypedSourcePickerItem?
    @State private var showsPicker = false

    var body: some View {
        ComposerScaffold(
            title: "Link \(goal.title)",
            confirmTitle: "Link",
            isConfirmEnabled: selection != nil,
            identifier: "goal.link.composer",
            onConfirm: {
                guard let selection else { return }
                save(Self.goalSource(for: selection.kind), selection.id)
                dismiss()
            }
        ) {
            GoalLinkSourceSection(selection: selection) { showsPicker = true }
        }
        .sheet(isPresented: $showsPicker) {
            TypedSourcePickerView(
                title: "Link \(goal.title)",
                kinds: TypedSourceKind.allCases,
                repository: sourcePickerRepository
            ) { item in selection = item }
        }
    }

    private static func goalSource(for kind: TypedSourceKind) -> GoalLinkSource {
        switch kind {
        case .task: .task
        case .project: .project
        case .habit: .habit
        case .routine: .routine
        case .trackerMeasure: .trackerMeasure
        }
    }
}

private struct GoalLinkSourceSection: View {
    let selection: TypedSourcePickerItem?
    let choose: () -> Void

    var body: some View {
        ComposerSection(
            "Progress source",
            footer: "LifeBoard aggregates only this explicit link. Unrelated activity never completes a goal."
        ) {
            Button(action: choose) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selection?.kind.title ?? "Choose a source")
                            .font(.lifeboard(.body))
                            .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                        if let selection {
                            Text(selection.title)
                                .font(.lifeboard(.bodyStrong))
                                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                        }
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.right")
                        .font(.lifeboard(.caption1))
                        .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 48)
                .contentShape(Rectangle())
            }
            .buttonStyle(.lifeBoardClay(.well, cornerRadius: Radius.compact + 2))
            .accessibilityIdentifier("goal.link.chooseSource")
        }
    }
}

private struct StarterPackBrowser: View {
    let install: (StarterPackPreview) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPack: StarterPack?
    @State private var preview: StarterPackPreview?
    var body: some View {
        ComposerScaffold(
            title: "Starter packs",
            subtitle: "Look before anything is created.",
            cancelTitle: "Close",
            identifier: "track.starterPacks"
        ) {
            StarterPackListSection { pack in
                selectedPack = pack
                preview = StarterPackCatalog.preview(pack)
            }
        } commit: {
            EmptyView()
        }
        .sheet(item: $selectedPack) { _ in
            if let preview { StarterPackPreviewSheet(preview: preview) { install($0); dismiss() } }
        }
    }
}


private struct StarterPackListSection: View {
    let open: (StarterPack) -> Void

    var body: some View {
        ComposerSection(
            footer: "Previewing a pack creates nothing. You choose which pieces to keep on the next screen."
        ) {
            ForEach(StarterPack.allCases, id: \.self) { pack in
                StarterPackRow(title: StarterPackCopy.title(pack)) { open(pack) }
            }
        }
    }
}

private struct StarterPackSelectionSection: View {
    @Binding var preview: StarterPackPreview

    var body: some View {
        ComposerSection(
            "Nothing is created until you confirm",
            footer: "Selected items use LifeBoard’s canonical creation flows. You can edit them afterward; removing the pack archives its definitions and preserves completed history."
        ) {
            ForEach($preview.items) { $item in
                Toggle(isOn: $item.isSelected) {
                    Label(item.title, systemImage: StarterPackCopy.symbol(item.kind))
                }
                .toggleStyle(.lifeBoardClay)
            }
        }
    }
}

/// Shared so the browser and the preview sheet cannot drift on naming.
private enum StarterPackCopy {
    static func title(_ pack: StarterPack) -> String {
        switch pack {
        case .morningFoundation: "Morning Foundation"
        case .workdayReset: "Workday Reset"
        case .lowEnergyRecovery: "Low Energy Recovery"
        case .medicationSupport: "Medication Support"
        case .eveningWindDown: "Evening Wind-down"
        }
    }

    static func symbol(_ kind: StarterPackItemKind) -> String {
        switch kind {
        case .goal: "target"
        case .habit: "repeat.circle"
        case .routine: "figure.mind.and.body"
        case .reminder: "bell"
        }
    }
}

private struct StarterPackRow: View {
    let title: String
    let open: () -> Void

    var body: some View {
        Button(action: open) {
            HStack(spacing: 12) {
                Image(systemName: "shippingbox")
                    .font(.lifeboard(.title3))
                    .foregroundStyle(Color(SemanticColorTokens.foundationApricotAccent))
                    .frame(width: 32, height: 32)
                    .accessibilityHidden(true)
                Text(title)
                    .font(.lifeboard(.bodyStrong))
                    .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.lifeboard(.caption1))
                    .foregroundStyle(Color(SemanticColorTokens.inkTertiary))
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.lifeBoardClay(.well, cornerRadius: Radius.card))
        .accessibilityIdentifier("track.starterPacks.\(title)")
    }
}

private struct StarterPackPreviewSheet: View {
    @State var preview: StarterPackPreview
    let install: (StarterPackPreview) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        ComposerScaffold(
            title: "Preview pack",
            confirmTitle: "Create selected",
            isConfirmEnabled: preview.items.contains(where: \.isSelected),
            identifier: "track.starterPacks.preview",
            onConfirm: { install(preview); dismiss() }
        ) {
            StarterPackSelectionSection(preview: $preview)
        }
    }
}

private extension View {
    /// Delegates to the canonical clay depth scale. Previously carried a
    /// radius-9 shadow and a 0.5pt stroke, so Track cards sat at a different
    /// apparent height from the identical-looking cards on Plan and Home.
    func trackClayCard() -> some View {
        self.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised, cornerRadius: Radius.card)
    }
}
