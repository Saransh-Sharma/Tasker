import SwiftUI
import UIKit

extension StarterPack: Identifiable {
    public var id: String { rawValue }
}

struct LifeBoardTrackFoundationRootView: View {
    @State private var store: TrackFoundationStore
    private let sourcePickerRepository: any TypedSourcePickerRepository
    private let onOpenHabitBoard: () -> Void
    private let onOpenHealth: () -> Void
    private let nutritionRepository: any NutritionRepository
    private let lifeMomentRepository: any LifeMomentRepository
    private let wellnessRepository: any WellnessRepository
    private let fastingTimerStore: FastingTimerStore
    @State private var showsMood = false
    @State private var editingMood: LifeBoardMoodEnergyCheckInValue?
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
    // Fasting used to exist only inside the legacy Track root, which was
    // presented as a sheet from inside this one. It is a first-class module
    // here now, so nothing is reachable through the legacy tree alone.
    @State private var fastingSessions: [LifeBoardFastingSessionValue] = []
    @State private var showsFastingComposer = false
    @State private var showsFastingHistory = false
    @State private var fastingError: String?
    @State private var linkingGoal: GoalDefinition?
    @State private var selectedLens: TrackLens = .today
    @Environment(LifeBoardPresentationPreferences.self) private var preferences
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.lifeBoardAtmosphereIsHosted) private var atmosphereIsHosted

    init(
        repository: CoreDataTrackFoundationRepository,
        phaseIIRepository: any LifeBoardPhaseIIRepository,
        habitProjectionService: (any TrackHabitProjectionService)? = nil,
        linkedMutationApplier: (any RoutineLinkedMutationApplying)? = nil,
        goalSampleProvider: (any GoalSampleProvider)? = nil,
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
            repository: LifeBoardFastingRepositoryAdapter(repository: phaseIIRepository)
        )
        _selectedLens = State(initialValue: initialLens)
    }

    private var activeFast: LifeBoardFastingSessionValue? {
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
                LifeBoardAtmosphereView(
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
                    categoryRail
                    categoryContent
                }
                .padding(.horizontal, 20)
                .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 56 : 36)
            }
            .refreshable { await store.load() }
        }
        .navigationTitle("Track")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .task { await reloadFasting() }
        .sheet(isPresented: $showsFastingComposer) {
            LifeBoardFastingComposer { target, _ in
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
            LifeBoardFastingHistoryView(
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
                    await LifeBoardPermissionPrimingCoordinator.shared.offerAfterReward(
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
                .background(.regularMaterial, in: Capsule())
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

    private var categoryRail: some View {
        Picker("Track lens", selection: $selectedLens) {
            ForEach(TrackLens.allCases) { lens in
                Text(lens.title)
                    .tag(lens)
                    .accessibilityIdentifier("track.lens.\(lens.rawValue)")
            }
        }
        .pickerStyle(.segmented)
        .lifeBoardMotion(.selection, value: selectedLens)
        .accessibilityIdentifier("track.lens")
    }

    @ViewBuilder private var categoryContent: some View {
        switch selectedLens {
        case .today:
            dueAndUnresolved
            // A running fast is time-sensitive, so it earns a place in Today.
            // When nothing is running it stays in Body rather than adding a
            // permanent empty module to the day.
            if activeFast != nil { fastingSection }
            todayRoutines
            careSnapshot
        case .areas:
            bodyCare
            if activeFast == nil { fastingSection }
            mindCare
            routinesAndHabits
            goals
            modules
        case .history:
            historyContent
        }
    }

    @ViewBuilder
    private var todayRoutines: some View {
        if store.snapshot.dueRoutines.isEmpty == false {
            trackSectionHeader("Useful today", symbol: "sun.max")
            ForEach(store.snapshot.dueRoutines) { routine in
                Button { Task { await store.startRoutine(routine) } } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "play.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(routine.title).font(.headline)
                            Text("\(routine.steps.count) calm steps")
                                .font(.caption)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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

    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("History range", selection: $careHistoryDays) {
                Text("7 days").tag(7)
                Text("30 days").tag(30)
            }
            .pickerStyle(.segmented)

            if filteredHydrationHistory.isEmpty
                && filteredSleepHistory.isEmpty
                && store.checkIns.isEmpty
                && filteredFastingHistory.isEmpty
                && filteredRoutineHistory.isEmpty
                && store.snapshot.goals.isEmpty {
                trackEmpty(
                    "No history yet",
                    detail: "Explicit records will appear here. Missing data is never treated as zero.",
                    symbol: "clock.arrow.circlepath"
                )
            } else {
                if filteredHydrationHistory.isEmpty == false {
                    trackSectionHeader("Hydration", symbol: "drop")
                    ForEach(filteredHydrationHistory) { hydrationHistoryRow($0) }
                }
                if filteredSleepHistory.isEmpty == false {
                    trackSectionHeader("Sleep context", symbol: "moon.zzz")
                    ForEach(filteredSleepHistory) { sleepHistoryRow($0) }
                }
                if store.checkIns.isEmpty == false {
                    trackSectionHeader("Mind check-ins", symbol: "face.smiling")
                    ForEach(Array(store.checkIns.prefix(12)), id: \.id) { checkIn in
                        HStack(spacing: 12) {
                            Image(systemName: "face.smiling")
                                .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(checkIn.mood.title).font(.body.weight(.medium))
                                Text(moodCheckInDetail(checkIn))
                                    .font(.caption)
                                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 7)
                    }
                }
                // History used to stop at hydration, sleep and mood, which
                // made it read as a care log rather than a record of the
                // whole tracked life.
                if filteredFastingHistory.isEmpty == false {
                    trackSectionHeader("Fasting", symbol: "timer")
                    ForEach(filteredFastingHistory) { session in
                        historyRow(
                            symbol: "timer",
                            title: Self.fastingClock(session.elapsed(at: session.endedAt ?? Date())),
                            detail: session.startedAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                }
                if filteredRoutineHistory.isEmpty == false {
                    trackSectionHeader("Routines", symbol: "repeat")
                    ForEach(filteredRoutineHistory) { run in
                        historyRow(
                            symbol: "repeat",
                            title: routineTitle(for: run),
                            detail: run.startedAt.formatted(date: .abbreviated, time: .shortened)
                        )
                    }
                }
                if store.snapshot.goals.isEmpty == false {
                    trackSectionHeader("Goals", symbol: "target")
                    ForEach(store.snapshot.goals, id: \.goalID) { goal in
                        historyRow(
                            symbol: "target",
                            title: goalTitle(for: goal.goalID),
                            detail: goal.nextUsefulAction
                        )
                    }
                }
            }
        }
        .accessibilityIdentifier("track.history")
    }

    private func historyRow(symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.body.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(.vertical, 7)
        .accessibilityElement(children: .combine)
    }

    private var historyCutoff: Date {
        Calendar.current.date(byAdding: .day, value: -careHistoryDays, to: Date()) ?? .distantPast
    }

    private var filteredFastingHistory: [LifeBoardFastingSessionValue] {
        fastingSessions
            .filter { $0.endedAt != nil && $0.startedAt >= historyCutoff }
            .sorted { $0.startedAt > $1.startedAt }
    }

    private var filteredRoutineHistory: [RoutineRun] {
        store.routineRuns
            .filter { $0.startedAt >= historyCutoff }
            .sorted { $0.startedAt > $1.startedAt }
            .prefix(12)
            .map { $0 }
    }

    private func routineTitle(for run: RoutineRun) -> String {
        store.routines.first { $0.id == run.routineID }?.title ?? "Routine"
    }

    private func goalTitle(for id: UUID) -> String {
        store.definitions.first { $0.id == id }?.title ?? "Goal"
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(daypartTitle)
                .font(LifeBoardFoundationTypography.screenTitle())
                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
            Text("Care, routines, and progress — without judgment.")
                .font(LifeBoardFoundationTypography.body())
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            HStack(spacing: 8) {
                statusPill("\(store.snapshot.dueRoutines.count) routines", symbol: "figure.mind.and.body")
                statusPill(store.snapshot.unresolvedMedicationEvents.isEmpty ? "Care clear" : "\(store.snapshot.unresolvedMedicationEvents.count) unresolved", symbol: "cross.case")
            }
            .padding(.top, 6)
        }
        .frame(minHeight: 150, alignment: .bottomLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("track.header")
    }

    @ViewBuilder private var dueAndUnresolved: some View {
        if !store.snapshot.unresolvedMedicationEvents.isEmpty {
            trackSectionHeader("Needs a decision", symbol: "exclamationmark.circle")
            ForEach(store.snapshot.unresolvedMedicationEvents) { event in
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "pills.fill").foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                        VStack(alignment: .leading) {
                            Text(store.medicationName(id: event.medicationID)).font(.headline)
                            Text(event.status == .unresolved ? "The window passed — choose what happened" : "Scheduled \(event.scheduledAt.formatted(date: .omitted, time: .shortened))")
                                .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                        Spacer()
                    }
                    HStack {
                        Button("Taken") { Task { await store.resolveMedication(event: event, status: .taken) } }.buttonStyle(.borderedProminent)
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

    private var routinesAndHabits: some View {
        VStack(spacing: 12) {
            trackSectionHeader("Current daypart", symbol: daypartSymbol, trailing: {
                Button { editingRoutine = nil; showsRoutineComposer = true } label: { Image(systemName: "plus") }
                    .accessibilityLabel("Create routine")
            })
            if store.snapshot.dueRoutines.isEmpty {
                trackEmpty("No routines due", detail: "Start progressively or preview a starter pack.", symbol: "figure.cooldown")
            } else {
                ForEach(store.snapshot.dueRoutines) { routine in
                    HStack(spacing: 8) {
                    Button { Task { await store.startRoutine(routine) } } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(routine.title).font(.headline)
                                Text("\(routine.steps.count) calm steps · version \(routine.version)")
                                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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
                    Image(systemName: "repeat.circle.fill").foregroundStyle(Color(LifeBoardColorTokens.foundationFocusRing))
                    VStack(alignment: .leading) {
                        Text("Habits and resilience").font(.headline)
                        Text("Grade, streak, off days, recovery, and full history")
                            .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Resilience settings").font(.headline)
                        Text("Choose intentional off days, recovery, and how streaks are framed.")
                            .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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
                habitQualitySummary
            }
        }
    }

    private var habitQualitySummary: some View {
        let graded = store.snapshot.habitGrades.compactMap(\.grade)
        let average = graded.isEmpty ? nil : graded.reduce(0, +) / Double(graded.count)
        let streak = store.snapshot.habitGrades.map(\.streak).max() ?? 0
        return HStack(spacing: 12) {
            habitMetric(
                title: "30-day grade",
                value: average.map { "\(Int(($0 * 100).rounded()))%" } ?? "Building",
                symbol: "chart.line.uptrend.xyaxis"
            )
            habitMetric(title: "Current streak", value: "\(streak) days", symbol: "flame")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("track.habitQuality")
    }

    private func habitMetric(title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.medium))
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            Text(value)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
        }
        .frame(maxWidth: .infinity, minHeight: 76, alignment: .leading)
        .padding(12)
        .lifeBoardClaySurface(.raised, cornerRadius: 16)
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1) }
    }

    /// Fasting as a first-class Track module. Leads with the running timer
    /// when there is one, because that is the only state that is time-sensitive.
    @ViewBuilder
    private var fastingSection: some View {
        VStack(spacing: 12) {
            trackSectionHeader("Fasting", symbol: "timer")

            VStack(alignment: .leading, spacing: 12) {
                if let activeFast {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        let elapsed = max(0, activeFast.elapsed(at: context.date))
                        HStack(spacing: 14) {
                            LifeBoardProgressRing(
                                fraction: activeFast.targetDuration.map { target in
                                    target > 0 ? min(1, elapsed / target) : 0
                                } ?? 0,
                                tint: Color(LifeBoardColorTokens.foundationSunAccent),
                                trackTint: Color(LifeBoardColorTokens.foundationSurfaceRecessed),
                                lineWidth: 7
                            )
                            .frame(width: 56, height: 56)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(Self.fastingClock(elapsed))
                                    .font(.system(.title2, design: .rounded, weight: .bold))
                                    .monospacedDigit()
                                Text(
                                    activeFast.targetDuration
                                        .map { "Target \(Int($0 / 3_600))h" } ?? "No target set"
                                )
                                .font(.caption)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            }
                            Spacer(minLength: 0)
                        }
                    }

                    HStack(spacing: 10) {
                        Button("Finish") {
                            Task {
                                _ = try? await fastingTimerStore.finish()
                                await reloadFasting()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        Button("Cancel fast") {
                            Task {
                                _ = try? await fastingTimerStore.cancel()
                                await reloadFasting()
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(minHeight: 44)
                } else {
                    Text("No fast is running.")
                        .font(.subheadline)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    Button("Start a fast") { showsFastingComposer = true }
                        .buttonStyle(.borderedProminent)
                        .frame(minHeight: 44)
                }

                if let fastingError {
                    Text(fastingError)
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationDanger))
                }

                if fastingSessions.contains(where: { $0.endedAt != nil }) {
                    Divider()
                    Button {
                        showsFastingHistory = true
                    } label: {
                        HStack {
                            Text("Fasting history")
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised, cornerRadius: 20)
            .accessibilityIdentifier("track.fasting")
        }
    }

    private static func fastingClock(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval))
        return String(format: "%d:%02d:%02d", total / 3_600, (total % 3_600) / 60, total % 60)
    }

    private var careSnapshot: some View {
        VStack(spacing: 12) {
            trackSectionHeader("Care snapshot", symbol: "heart.text.square")
            LazyVGrid(columns: careGridColumns, spacing: 12) {
                hydrationTile
                careButton(title: "Mood + energy", value: latestMood, symbol: "face.smiling") { presentMoodComposer() }
                behaviorAreaLink(
                    area: .medication,
                    title: "Medication",
                    value: store.snapshot.unresolvedMedicationEvents.isEmpty ? "Up to date" : "Decision needed",
                    symbol: "pills"
                )
                careButton(title: "Sleep context", value: latestSleep, symbol: "moon.zzz") { showsSleep = true }
                    .privacySensitive()
            }
        }
    }

    private var bodyCare: some View {
        VStack(spacing: 12) {
            trackSectionHeader("Body", symbol: "heart.text.square")
            LazyVGrid(columns: careGridColumns, spacing: 12) {
                hydrationTile
                behaviorAreaLink(
                    area: .medication,
                    title: "Medication",
                    value: store.snapshot.unresolvedMedicationEvents.isEmpty ? "Up to date" : "Decision needed",
                    symbol: "pills"
                )
                careButton(title: "Sleep context", value: latestSleep, symbol: "moon.zzz") { showsSleep = true }
                    .privacySensitive()
            }
            if !store.hydrationHistory.isEmpty || !store.sleepRecords.isEmpty {
                Picker("Care history range", selection: $careHistoryDays) {
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("track.care.historyRange")
            }
            if !filteredHydrationHistory.isEmpty {
                trackSectionHeader("Hydration history", symbol: "drop")
                ForEach(filteredHydrationHistory) { hydrationHistoryRow($0) }
            }
            if !filteredSleepHistory.isEmpty {
                trackSectionHeader("Recent sleep context", symbol: "moon.zzz")
                ForEach(filteredSleepHistory) { sleepHistoryRow($0) }
            }
            Button(action: onOpenHealth) {
                // Fasting is its own module now, so it no longer belongs in
                // this row's promise.
                moduleRow("Health and care library", detail: "Medication, trackers, steps, and active energy", symbol: "heart.circle")
            }
            .buttonStyle(.plain)
        }
    }

    private var mindCare: some View {
        VStack(spacing: 12) {
            trackSectionHeader("Mind", symbol: "brain.head.profile")
            careButton(title: "Mood + energy", value: latestMood, symbol: "face.smiling") { presentMoodComposer() }
            moodTrend
            if !store.checkIns.isEmpty {
                trackSectionHeader("Recent check-ins", symbol: "clock.arrow.circlepath")
                ForEach(Array(store.checkIns.prefix(8)), id: \.id) { checkIn in
                    HStack(spacing: 12) {
                        Image(systemName: "face.smiling").foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(checkIn.mood.title).font(.body.weight(.medium))
                            Text(moodCheckInDetail(checkIn))
                                .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                        Spacer()
                        Menu {
                            Button("Edit", systemImage: "pencil") { presentMoodComposer(checkIn) }
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

    @ViewBuilder private var moodTrend: some View {
        switch MoodTrendProjector.project(store.checkIns) {
        case .empty:
            trackEmpty("No mood trend yet", detail: "Check in when it feels useful. Missing data is never treated as neutral.", symbol: "chart.line.downtrend.xyaxis")
        case let .light(sampleCount):
            trackEmpty(
                "A trend needs a little more context",
                detail: "\(sampleCount) of 3 check-ins recorded. LifeBoard will not infer a pattern yet.",
                symbol: "ellipsis"
            )
        case let .ready(summary):
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("30-day rhythm").font(.headline)
                        Text(moodTrendDescription(summary))
                            .font(.caption)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }
                    Spacer()
                    Text("\(summary.sampleCount) check-ins")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                MoodTrendStrip(points: summary.dailyPoints)
            }
            .trackClayCard()
            .privacySensitive()
            .accessibilityElement(children: .combine)
        }
    }

    private var careGridColumns: [GridItem] {
        if dynamicTypeSize.isAccessibilitySize {
            return [GridItem(.flexible(), spacing: 12)]
        }
        return [GridItem(.adaptive(minimum: 150), spacing: 12)]
    }

    private var hydrationTile: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Hydration", systemImage: "drop.fill").font(.headline)
                Spacer(minLength: 8)
                Button("Edit target") { showsHydrationTarget = true }
                    .font(.caption.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("track.hydration.target")
            }
            Text(hydrationLabel).font(.title3.weight(.semibold))
            if let amount = store.snapshot.hydrationAmountMilliliters, let target = store.snapshot.hydrationTargetMilliliters, target > 0 {
                ProgressView(value: min(1, amount / target)).tint(Color(LifeBoardColorTokens.foundationSageAccent))
            } else {
                Text("Set your own target").font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            HStack(spacing: 8) {
                Button("+250 ml") {
                    Task { await store.quickAddHydration(250); await offerHealthConnect() }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("track.hydration.add250")
                Button("+500 ml") {
                    Task { await store.quickAddHydration(500); await offerHealthConnect() }
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .accessibilityIdentifier("track.hydration.add500")
            }
            .buttonStyle(.lifeBoardChip)
        }
        .trackClayCard()
        .accessibilityIdentifier("track.hydration")
    }

    /// After a hydration log lands (and its fill animates), gently invite a
    /// not-yet-connected user to mirror water with Apple Health. Never blocks.
    @MainActor
    private func offerHealthConnect() async {
        await LifeBoardHealthRuntime.shared.jitCoordinator.offerConnectAfterReward(
            leadDomain: .hydration,
            trigger: "track_hydration_quick_add"
        )
    }

    private var goals: some View {
        VStack(spacing: 12) {
            trackSectionHeader("Goals and progress", symbol: "target", trailing: {
                Button { editingGoal = nil; showsGoal = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add goal")
            })
            if store.definitions.isEmpty {
                trackEmpty("No goals required", detail: "Goals are optional. Add one only when it helps organize action.", symbol: "scope")
            } else {
                ForEach(store.definitions) { goal in
                    let progress = store.snapshot.goals.first(where: { $0.goalID == goal.id })
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(goal.title).font(.headline)
                                Text("\(goal.effectiveIntent.rawValue.capitalized) · \(goal.effectiveStatus.rawValue.capitalized)")
                                    .font(.caption)
                                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            }
                            Spacer()
                            Text(progressLabel(progress)).font(.caption.weight(.semibold))
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
                        if let fraction = progress?.progressFraction { ProgressView(value: fraction).tint(Color(LifeBoardColorTokens.foundationFocusRing)) }
                        if let why = goal.whyItMatters, !why.isEmpty {
                            Text(why)
                                .font(.subheadline)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                        }
                        Text(progress?.nextUsefulAction ?? "Link a source to measure progress.")
                            .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }
                    .trackClayCard()
                    .accessibilityIdentifier("track.goal.\(goal.id.uuidString)")
                }
            }
        }
    }

    private var modules: some View {
        VStack(spacing: 12) {
            trackSectionHeader("Explore and reflect", symbol: "square.grid.2x2")
            Button { showsStarterPacks = true } label: { moduleRow("Starter packs", detail: "Preview before creating anything", symbol: "shippingbox") }
                .buttonStyle(.plain)
            ForEach(store.starterPackInstallations.filter { $0.removedAt == nil }) { installation in
                HStack(spacing: 12) {
                    Image(systemName: "shippingbox.fill").foregroundStyle(Color(LifeBoardColorTokens.foundationFocusRing))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(starterPackTitle(installation.pack)).font(.headline)
                        Text("Installed · history stays if removed")
                            .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }
                    Spacer()
                    Button("Remove", role: .destructive) { Task { await store.removeStarterPack(installation) } }
                        .font(.caption.weight(.semibold))
                }
                .padding(.vertical, 6)
            }
            NavigationLink { LifeBoardJournalModuleView(repository: store.phaseIIRepository) } label: { moduleRow("Journal", detail: "Write, reflect, and look back", symbol: "book.closed") }
                .buttonStyle(.plain)
            NavigationLink { LifeBoardKnowledgeModuleView(repository: store.phaseIIRepository) } label: { moduleRow("Notes", detail: "Notes and the links between them", symbol: "note.text") }
                .buttonStyle(.plain)
            if V2FeatureFlags.nutritionV1Enabled {
                NavigationLink { LifeBoardNutritionView(repository: nutritionRepository) } label: { moduleRow("Nutrition", detail: "What you ate today", symbol: "fork.knife") }
                    .buttonStyle(.plain)
            }
            if V2FeatureFlags.wellnessCoreV1Enabled {
                NavigationLink { LifeBoardWellnessView(repository: wellnessRepository) } label: { moduleRow("Wellness", detail: "Weight, sleep, workouts, and trends", symbol: "heart.text.square") }
                    .buttonStyle(.plain)
            }
            if V2FeatureFlags.lifeMomentsV1Enabled {
                NavigationLink { LifeBoardLifeMomentsView(repository: lifeMomentRepository) } label: { moduleRow("Life Moments", detail: "Countdowns and dates that matter", symbol: "calendar.badge.heart") }
                    .buttonStyle(.plain)
            }
            NavigationLink {
                LifeBoardBehaviorAreaRouteView(
                    repository: store.phaseIIRepository,
                    initialArea: .trackers
                )
            } label: {
                moduleRow(
                    "Trackers and medication",
                    detail: "Typed values, neutral schedules, corrections, and history",
                    symbol: "square.grid.3x3"
                )
            }
                .buttonStyle(.plain)
        }
    }

    private func moduleRow(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title3).frame(width: 28).foregroundStyle(Color(LifeBoardColorTokens.foundationFocusRing))
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary)) }
            Spacer(); Image(systemName: "chevron.right")
        }.trackClayCard()
    }

    private func hydrationHistoryRow(_ log: HydrationLog) -> some View {
        let amount = HydrationMeasurementService.milliliters(log.amount, unit: log.unit)
        return HStack(spacing: 12) {
            Image(systemName: "drop.fill").foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(Int(amount)) ml").font(.body.weight(.medium))
                Text(log.timestamp.formatted(date: .omitted, time: .shortened) + (log.correctedAt == nil ? "" : " · corrected"))
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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
        .padding(.vertical, 7)
        .accessibilityIdentifier("track.hydration.history.\(log.id.uuidString)")
    }

    private func sleepHistoryRow(_ record: SleepContextRecord) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "moon.zzz").foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
            VStack(alignment: .leading, spacing: 3) {
                Text("\(record.bedtime.formatted(date: .abbreviated, time: .shortened))–\(record.wakeTime.formatted(date: .omitted, time: .shortened))")
                    .font(.body.weight(.medium))
                Text(record.perceivedRest.map { "Rest \($0)/5 · \(record.interruptionCount) interruptions" } ?? "\(record.interruptionCount) interruptions")
                    .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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
        .padding(.vertical, 7)
        .privacySensitive()
    }

    private var careHistoryCutoff: Date {
        Calendar.current.date(byAdding: .day, value: -(careHistoryDays - 1), to: Calendar.current.startOfDay(for: Date())) ?? .distantPast
    }
    private var filteredHydrationHistory: [HydrationLog] {
        store.hydrationHistory.filter { $0.timestamp >= careHistoryCutoff }
    }
    private var filteredSleepHistory: [SleepContextRecord] {
        store.sleepRecords.filter { $0.bedtime >= careHistoryCutoff }
    }

    private func starterPackTitle(_ pack: StarterPack) -> String {
        switch pack {
        case .morningFoundation: "Morning Foundation"
        case .workdayReset: "Workday Reset"
        case .lowEnergyRecovery: "Low Energy Recovery"
        case .medicationSupport: "Medication Support"
        case .eveningWindDown: "Evening Wind-down"
        }
    }

    private func careButton(title: String, value: String, symbol: String, action: @escaping () -> Void) -> some View {
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

    private func behaviorAreaLink(
        area: LifeBoardBehaviorNativeAreasView.Area,
        title: String,
        value: String,
        symbol: String
    ) -> some View {
        NavigationLink {
            LifeBoardBehaviorAreaRouteView(
                repository: store.phaseIIRepository,
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

    private func trackEmpty(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title2).foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary)) }
            Spacer()
        }.trackClayCard()
    }

    private func trackSectionHeader<Content: View>(_ title: String, symbol: String, @ViewBuilder trailing: () -> Content) -> some View {
        HStack { Label(title, systemImage: symbol).font(LifeBoardFoundationTypography.sectionTitle()); Spacer(); trailing() }
            .padding(.top, 6).foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
    }
    private func trackSectionHeader(_ title: String, symbol: String) -> some View { trackSectionHeader(title, symbol: symbol) { EmptyView() } }
    private func statusPill(_ title: String, symbol: String) -> some View {
        Label(title, systemImage: symbol).font(.caption.weight(.medium)).padding(.horizontal, 10).padding(.vertical, 7)
            .background(Color(LifeBoardColorTokens.foundationSurfaceSolid).opacity(0.84), in: Capsule())
    }
    private var daypartTitle: String {
        switch preferences.resolvedDaypart() { case .morning: "Good morning"; case .afternoon: "Good afternoon"; case .evening: "Good evening"; case .night: "A gentler night" }
    }
    private var daypartSymbol: String {
        switch preferences.resolvedDaypart() { case .morning: "sunrise"; case .afternoon: "sun.max"; case .evening: "sunset"; case .night: "moon.stars" }
    }
    private var latestMood: String {
        guard let latest = store.checkIns.first else { return "Check in when useful" }
        return latest.energy.map { "\(latest.mood.title) · energy \($0)/5" } ?? latest.mood.title
    }
    private func moodCheckInDetail(_ checkIn: LifeBoardMoodEnergyCheckInValue) -> String {
        let time = checkIn.createdAt.formatted(date: .abbreviated, time: .shortened)
        guard let energy = checkIn.energy else { return time }
        return "Energy \(energy)/5 · \(time)"
    }
    private func presentMoodComposer(_ checkIn: LifeBoardMoodEnergyCheckInValue? = nil) {
        editingMood = checkIn
        showsMood = true
    }
    private func moodTrendDescription(_ summary: MoodTrendSummary) -> String {
        let feeling: String
        switch summary.averageValence {
        case 1.5...: feeling = "mostly lighter"
        case ..<(-1.5): feeling = "mostly heavier"
        default: feeling = "varied"
        }
        guard let energy = summary.averageEnergy else { return "Your recorded mood has felt \(feeling). Energy was not consistently recorded." }
        return "Your recorded mood has felt \(feeling), with average energy \(energy.formatted(.number.precision(.fractionLength(1))))/5."
    }
    private var latestSleep: String {
        guard let record = store.sleepRecords.first else { return "No manual context" }
        return record.perceivedRest.map { "Rest \($0)/5" } ?? "Recorded"
    }
    private var hydrationLabel: String {
        guard let amount = store.snapshot.hydrationAmountMilliliters else { return "No data yet" }
        if let target = store.snapshot.hydrationTargetMilliliters { return "\(Int(amount)) / \(Int(target)) ml" }
        return "\(Int(amount)) ml"
    }
    private func progressLabel(_ progress: GoalProgressSnapshot?) -> String {
        guard let progress else { return "Not linked" }
        if let fraction = progress.progressFraction { return "\(Int(fraction * 100))%" }
        return progress.missingLinkCount > 0 ? "Data incomplete" : "Ready"
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

struct TrackUniversalCaptureView: View {
    let kind: CaptureKind
    @State private var store: TrackFoundationStore
    @Environment(\.dismiss) private var dismiss

    init(
        kind: CaptureKind,
        repository: CoreDataTrackFoundationRepository,
        phaseIIRepository: any LifeBoardPhaseIIRepository,
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
                HydrationCaptureComposer { amount in
                    Task { await store.quickAddHydration(amount); dismiss() }
                }
            case .medicationEvent:
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

    private func resolve(_ event: LifeBoardMedicationEventValue, _ status: LifeBoardMedicationEventStatus) {
        Task { await store.resolveMedication(event: event, status: status); dismiss() }
    }
}

private struct HydrationCaptureComposer: View {
    let save: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var amount = 250.0

    var body: some View {
        Form {
            Section("Amount") {
                Picker("Quick amount", selection: $amount) {
                    Text("250 ml").tag(250.0)
                    Text("350 ml").tag(350.0)
                    Text("500 ml").tag(500.0)
                    Text("750 ml").tag(750.0)
                }
                TextField("Milliliters", value: $amount, format: .number).keyboardType(.decimalPad)
            }
            Text("LifeBoard records the amount against your own target; it does not generate a hydration recommendation.").font(.caption)
        }
        .lifeBoardFormSurface()
        .navigationTitle("Log hydration")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Add") { save(amount) }.disabled(amount <= 0) }
        }
    }
}

private struct TrackComposerReceipt: Equatable, Sendable {
    let operationID: UUID
    let completedAt: Date

    init(operationID: UUID = UUID(), completedAt: Date = Date()) {
        self.operationID = operationID
        self.completedAt = completedAt
    }
}

private struct TrackComposerCommitBar: View {
    let title: String
    let phase: AsyncActionPhase<TrackComposerReceipt>
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if case .recoverableFailure(let failure) = phase {
                Label(failure.message, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(Color.lifeboard.statusWarning)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            LifeBoardCommitControl(
                title: title,
                runningTitle: "Saving",
                successTitle: "Saved",
                phase: phase,
                isEnabled: isEnabled,
                action: action
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}

private struct HydrationTargetComposer: View {
    let save: (Double) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double
    @State private var commitPhase: AsyncActionPhase<TrackComposerReceipt> = .idle

    init(currentTarget: Double?, save: @escaping (Double) async -> Bool) {
        self.save = save
        _amount = State(initialValue: currentTarget ?? 2_000)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Your daily target") {
                    TextField("Milliliters", value: $amount, format: .number)
                        .keyboardType(.decimalPad)
                    Picker("Preset", selection: $amount) {
                        Text("1,500 ml").tag(1_500.0)
                        Text("2,000 ml").tag(2_000.0)
                        Text("2,500 ml").tag(2_500.0)
                        Text("3,000 ml").tag(3_000.0)
                    }
                }
                Section {
                    Text("This is your own tracking target. LifeBoard does not calculate or recommend a medical hydration amount.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .lifeBoardFormSurface()
            .navigationTitle("Hydration target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                TrackComposerCommitBar(
                    title: "Save target",
                    phase: commitPhase,
                    isEnabled: amount > 0,
                    action: commit
                )
                .accessibilityIdentifier("track.hydration.target.commit")
            }
        }
    }

    private func commit() {
        guard case .running = commitPhase else {
            commitPhase = .running(progress: nil)
            Task {
                if await save(amount) {
                    commitPhase = .success(receipt: .init())
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
                Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea()
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
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(timerRemaining(duration: duration, at: context.date) > 0)
            }
        } else {
            Button("Continue") { advance(response, false) }
                .buttonStyle(.borderedProminent)
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
                .font(LifeBoardFoundationTypography.sectionTitle())
            Text("Your place and timer are saved.")
                .font(.subheadline)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            Button("Resume", systemImage: "play.fill", action: resume)
                .frame(maxWidth: .infinity, minHeight: 48)
        }
        .padding(18)
        .lifeBoardClaySurface(.well, cornerRadius: 20)
        .buttonStyle(.borderedProminent)
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
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            ProgressView(
                value: Double(index + 1),
                total: Double(max(1, stepCount))
            )
            .tint(Color(LifeBoardColorTokens.foundationFocusRing))
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
                .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                .symbolEffect(.breathe, options: .nonRepeating, value: step.id)
            Text(step.title)
                .font(LifeBoardFoundationTypography.screenTitle())
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if step.kind == .timer, let duration = step.duration {
                RoutineTimerProgress(run: run, duration: duration)
            } else if let duration = step.duration {
                Text("About \(Int(duration / 60)) minutes")
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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
                    .font(LifeBoardFoundationTypography.screenTitle().monospacedDigit())
                    .contentTransition(.numericText(countsDown: true))
                ProgressView(
                    value: max(0, duration - remaining),
                    total: max(1, duration)
                )
                .tint(Color(LifeBoardColorTokens.foundationFocusRing))
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
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(group.title)
                                            Text(group.planningContext.rawValue.capitalized)
                                                .font(.caption)
                                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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
                                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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
        Form {
            TextField("Group name", text: $title)
            Picker("Planning context", selection: $planningContext) {
                ForEach(PlanningContext.allCases, id: \.self) { context in
                    Text(context.rawValue.capitalized).tag(context)
                }
            }
            Text("Groups organize presentation only. Moving a habit never rewrites its occurrence history or recurrence schedule.")
                .font(.caption)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
        }
        .lifeBoardFormSurface()
        .navigationTitle(group == nil ? "New habit group" : "Edit habit group")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
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
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

private struct HabitResilienceEditor: View {
    private enum MinimumKind: String, CaseIterable, Identifiable {
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
    @State private var commitPhase: AsyncActionPhase<TrackComposerReceipt> = .idle

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
        Form {
            Section("Group") {
                Picker("Habit group", selection: $groupID) {
                    Text("Ungrouped").tag(UUID?.none)
                    ForEach(groups) { group in
                        Text(group.title).tag(UUID?.some(group.id))
                    }
                }
            }
            Section("Recovery") {
                Toggle("Allow recovery completions", isOn: $recoveryEnabled)
                Text("Recovered days count as completed eligible days, but remain visibly identified in history.")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }

            Section("Progress framing") {
                Picker("Habit progress", selection: $streakPresentation) {
                    Text("Grade and streak").tag(HabitStreakPresentation.gradeAndStreak)
                    Text("Counts only").tag(HabitStreakPresentation.countsOnly)
                }
                .pickerStyle(.inline)
            }

            Section("Gentle fallback") {
                Picker("Low-energy minimum", selection: $minimumKind) {
                    ForEach(MinimumKind.allCases) { kind in
                        Text(kind.title).tag(kind)
                    }
                }
                if [.quota, .timed, .quantitative].contains(minimumKind) {
                    HStack {
                        TextField("Amount", value: $minimumValue, format: .number)
                            .keyboardType(.decimalPad)
                        if minimumKind == .quantitative {
                            TextField("Unit", text: $minimumUnit)
                                .multilineTextAlignment(.trailing)
                        } else {
                            Text(minimumKind == .timed ? "minutes" : "times")
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                    }
                }
                Text("Low Energy can offer this kinder version without changing the full target or silently completing it.")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }

            Section {
                Picker("Correction window", selection: $backfillDays) {
                    Text("Same day only").tag(0)
                    Text("7 days").tag(7)
                    Text("30 days").tag(30)
                }
                DatePicker("Vacation starts", selection: $vacationStart, displayedComponents: .date)
                DatePicker("Vacation ends", selection: $vacationEnd, in: vacationStart..., displayedComponents: .date)
                Button {
                    let calendar = Calendar.current
                    vacationRanges.append(HabitVacationRange(
                        startDay: PlanningDay(date: vacationStart, timeZone: calendar.timeZone, calendar: calendar),
                        endDay: PlanningDay(date: vacationEnd, timeZone: calendar.timeZone, calendar: calendar),
                        label: "Vacation"
                    ))
                } label: {
                    Label("Add vacation range", systemImage: "plus.circle")
                        .frame(minHeight: 44)
                }
                ForEach(vacationRanges) { range in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(range.label ?? "Intentional pause")
                            Text(vacationSummary(range))
                                .font(.caption)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                        Spacer()
                        Button(role: .destructive) {
                            vacationRanges.removeAll { $0.id == range.id }
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Remove vacation range")
                    }
                }
            } header: {
                Text("Backfill and vacation")
            } footer: {
                Text("Vacation days and intentional off days remain distinct from missing data and never lower the eligible grade denominator.")
            }

            Section {
                if recentHistory.isEmpty {
                    Text("No due occurrences are available in the last 30 days.")
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                } else {
                    ForEach(recentHistory) { occurrence in
                        recoveryHistoryRow(occurrence)
                    }
                }
            } header: {
                Text("30-day history")
            } footer: {
                Text("Recovery completes the canonical occurrence first, then stores a reversible receipt. Existing completions can be labelled as recovered without changing their completion state.")
            }

            Section {
                ForEach(exceptionDays, id: \.self) { day in
                    Button {
                        if offDays.contains(day) { offDays.remove(day) }
                        else { offDays.insert(day) }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exceptionTitle(day))
                                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                                Text(day.timeZoneIdentifier)
                                    .font(.caption2)
                                    .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                            }
                            Spacer()
                            if offDays.contains(day) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(offDays.contains(day) ? .isSelected : [])
                }
            } header: {
                Text("Intentional off-day exceptions")
            } footer: {
                Text("Exceptions use the local calendar day, survive travel and daylight-saving changes, and do not reduce the eligible grade denominator.")
            }
        }
        .lifeBoardFormSurface()
        .navigationTitle(habit.title)
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            TrackComposerCommitBar(
                title: "Save resilience",
                phase: commitPhase,
                isEnabled: true,
                action: commit
            )
            .accessibilityIdentifier("track.resilience.commit")
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
            VStack(alignment: .leading, spacing: 3) {
                Text(exceptionTitle(occurrence.day))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                Text(historyStatus(occurrence, recovered: isRecovered))
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
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
                .buttonStyle(.borderedProminent)
                .tint(Color(LifeBoardColorTokens.foundationSageAccent))
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

private struct RoutineComposer: View {
    private struct DraftStep: Identifiable {
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
    @State private var commitPhase: AsyncActionPhase<TrackComposerReceipt> = .idle

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
                                    .font(.caption.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 36)
                                    .background(weekdays.contains(weekday) ? Color(LifeBoardColorTokens.foundationSurfaceSelected) : .clear, in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(weekdays.contains(weekday) ? .isSelected : [])
                        }
                    }
                }
                Section("Steps") {
                    ForEach($steps) { $step in
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Step title", text: $step.title)
                            Picker("Kind", selection: $step.kind) {
                                ForEach(RoutineStepKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                            }
                            if step.kind == .timer {
                                Stepper("Duration: \(Int(step.durationMinutes)) minutes", value: $step.durationMinutes, in: 1...120)
                            }
                            if step.kind == .choice {
                                TextField("Choices, separated by commas", text: $step.choices)
                                ForEach(parsedChoices(step.choices), id: \.self) { choice in
                                    Picker(
                                        "If “\(choice)”",
                                        selection: branchDestinationBinding(
                                            stepID: step.id,
                                            response: choice
                                        )
                                    ) {
                                        Text("Continue in order").tag(UUID?.none)
                                        ForEach(forwardDestinations(after: step.id)) { destination in
                                            Text(destination.title).tag(UUID?.some(destination.id))
                                        }
                                    }
                                }
                            }
                            if step.kind == .task || step.kind == .habit {
                                Button {
                                    pickingStep = StepLinkTarget(id: step.id)
                                } label: {
                                    HStack {
                                        Text(step.linkedTitle.isEmpty ? "Link a \(step.kind == .task ? "task" : "habit")" : step.linkedTitle)
                                            .foregroundStyle(Color(step.linkedTitle.isEmpty ? LifeBoardColorTokens.inkSecondary : LifeBoardColorTokens.inkPrimary))
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                                    }
                                    .contentShape(Rectangle())
                                }
                                .accessibilityIdentifier("routine.step.link")
                            }
                            Toggle("Required", isOn: $step.isRequired)
                            Toggle("May skip", isOn: $step.isSkippable)
                        }
                    }
                    .onDelete { steps.remove(atOffsets: $0) }
                    .onMove { steps.move(fromOffsets: $0, toOffset: $1) }
                    Button("Add step", systemImage: "plus") { steps.append(.init()) }
                }
                Text("Routine history stores this version. Future edits never rewrite prior runs.")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            .lifeBoardFormSurface()
            .navigationTitle(existing == nil ? "New routine" : "Edit routine")
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                TrackComposerCommitBar(
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
                .stroke(Color(LifeBoardColorTokens.foundationHairline), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                Path { path in
                    guard let first = coordinates.first else { return }
                    path.move(to: first)
                    for coordinate in coordinates.dropFirst() { path.addLine(to: coordinate) }
                }
                .stroke(
                    Color(LifeBoardColorTokens.foundationApricotAccent),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round)
                )

                ForEach(Array(points.enumerated()), id: \.element.id) { index, _ in
                    Circle()
                        .fill(Color(LifeBoardColorTokens.foundationSurfaceSolid))
                        .overlay {
                            Circle().stroke(Color(LifeBoardColorTokens.foundationApricotAccent), lineWidth: 2)
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
    let checkIn: LifeBoardMoodEnergyCheckInValue?
    let save: (LifeBoardMoodEnergyCheckInValue) async -> Bool
    let delete: ((LifeBoardMoodEnergyCheckInValue) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var mood: LifeBoardJournalMood
    @State private var energy: Int
    @State private var includesEnergy: Bool
    @State private var confirmsDelete = false
    @State private var commitPhase: AsyncActionPhase<TrackComposerReceipt> = .idle

    init(
        checkIn: LifeBoardMoodEnergyCheckInValue? = nil,
        save: @escaping (LifeBoardMoodEnergyCheckInValue) async -> Bool,
        delete: ((LifeBoardMoodEnergyCheckInValue) -> Void)? = nil
    ) {
        self.checkIn = checkIn
        self.save = save
        self.delete = delete
        _mood = State(initialValue: checkIn?.mood ?? .none)
        _energy = State(initialValue: checkIn?.energy ?? 3)
        _includesEnergy = State(initialValue: checkIn?.energy != nil || checkIn == nil)
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mood", selection: $mood) { ForEach(LifeBoardJournalMood.allCases) { Text($0.title).tag($0) } }
                Toggle("Record energy", isOn: $includesEnergy)
                if includesEnergy {
                    Stepper("Energy: \(energy)/5", value: $energy, in: 1...5)
                }
                Text("This records your signal. LifeBoard does not assign a clinical interpretation.").font(.caption)
                if checkIn != nil, delete != nil {
                    Button("Delete check-in", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                }
            }
            .lifeBoardFormSurface()
            .navigationTitle(checkIn == nil ? "Mood + energy" : "Edit check-in")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                TrackComposerCommitBar(
                    title: checkIn == nil ? "Save check-in" : "Save changes",
                    phase: commitPhase,
                    isEnabled: true,
                    action: saveValue
                )
                .accessibilityIdentifier("track.mood.commit")
            }
            .confirmationDialog("Delete this check-in?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    guard let checkIn else { return }
                    delete?(checkIn)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes only this recorded check-in. Other Journal and Track data stays intact.")
            }
        }
    }

    private func saveValue() {
        if case .running = commitPhase { return }
        var value = checkIn ?? LifeBoardMoodEnergyCheckInValue(mood: mood, energy: includesEnergy ? energy : nil)
        value.mood = mood
        value.energy = includesEnergy ? energy : nil
        commitPhase = .running(progress: nil)
        Task {
            if await save(value) {
                commitPhase = .success(receipt: .init())
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

private struct SleepContextComposer: View {
    let existing: SleepContextRecord?
    let save: (SleepContextRecord) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @State private var bedtime: Date
    @State private var wake: Date
    @State private var rest: Int
    @State private var interruptions: Int
    @State private var notes: String
    @State private var commitPhase: AsyncActionPhase<TrackComposerReceipt> = .idle

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
        NavigationStack {
            Form {
                DatePicker("Bedtime", selection: $bedtime)
                DatePicker("Wake time", selection: $wake, in: bedtime...)
                Stepper("Perceived rest: \(rest)/5", value: $rest, in: 1...5)
                Stepper("Interruptions: \(interruptions)", value: $interruptions, in: 0...20)
                TextField("Private notes", text: $notes, axis: .vertical)
                Text("Sleep context stays out of widgets, Spotlight, Siri, and lock-screen previews.").font(.caption)
            }
            .lifeBoardFormSurface()
            .privacySensitive()
            .navigationTitle(existing == nil ? "Sleep context" : "Edit sleep context")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                TrackComposerCommitBar(
                    title: existing == nil ? "Save sleep context" : "Save changes",
                    phase: commitPhase,
                    isEnabled: wake >= bedtime,
                    action: saveValue
                )
                .accessibilityIdentifier("track.sleep.commit")
            }
        }
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

private struct GoalComposer: View {
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
    @State private var commitPhase: AsyncActionPhase<TrackComposerReceipt> = .idle

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
        NavigationStack {
            Form {
                TextField("Goal title", text: $title)
                Picker("Goal type", selection: $type) {
                    ForEach(GoalType.allCases, id: \.self) { Text(goalTypeTitle($0)).tag($0) }
                }
                Picker("Intent", selection: $intent) {
                    ForEach(GoalIntent.allCases, id: \.self) { Text(goalIntentTitle($0)).tag($0) }
                }
                if usesNumericTarget {
                    TextField(type == .duration ? "Target minutes" : "Target", value: $target, format: .number)
                        .keyboardType(.decimalPad)
                        .frame(minHeight: 44)
                    Toggle("Use a baseline", isOn: $hasBaseline)
                        .frame(minHeight: 44)
                    if hasBaseline {
                        TextField(type == .duration ? "Baseline minutes" : "Baseline", value: $baseline, format: .number)
                            .keyboardType(.decimalPad)
                            .frame(minHeight: 44)
                    }
                    if type == .quantity { TextField("Unit (optional)", text: $unit) }
                }
                if type == .targetDate { DatePicker("Target date", selection: $targetDate, displayedComponents: .date) }
                Picker("Confidence", selection: $confidence) {
                    Text("Not set").tag(GoalConfidence?.none)
                    ForEach(GoalConfidence.allCases, id: \.self) { value in
                        Text(value.rawValue.capitalized).tag(GoalConfidence?.some(value))
                    }
                }
                Picker("Check in", selection: $checkInCadence) {
                    ForEach(GoalCheckInCadence.allCases, id: \.self) { value in
                        Text(checkInTitle(value)).tag(value)
                    }
                }
                Section("Why it matters") {
                    TextEditor(text: $whyItMatters)
                        .frame(minHeight: 88)
                }
                Text("Progress comes only from sources you explicitly link after creating the goal.")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            .lifeBoardFormSurface()
            .navigationTitle(existing == nil ? "New goal" : "Edit goal")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                TrackComposerCommitBar(
                    title: existing == nil ? "Create goal" : "Save goal",
                    phase: commitPhase,
                    isEnabled: canCommit,
                    action: commit
                )
                .accessibilityIdentifier("track.goal.commit")
            }
        }
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

private struct GoalLinkComposer: View {
    let goal: GoalDefinition
    let sourcePickerRepository: any TypedSourcePickerRepository
    let save: (GoalLinkSource, UUID) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selection: TypedSourcePickerItem?
    @State private var showsPicker = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Progress source") {
                    Button {
                        showsPicker = true
                    } label: {
                        HStack {
                            Text(selection == nil ? "Choose a source" : selection!.kind.title)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            Spacer()
                            if let selection {
                                Text(selection.title).foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier("goal.link.chooseSource")
                }
                Text("LifeBoard aggregates only this explicit link. Unrelated activity never completes a goal.")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            .lifeBoardFormSurface()
            .navigationTitle("Link \(goal.title)")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Link") {
                        guard let selection else { return }
                        save(Self.goalSource(for: selection.kind), selection.id)
                        dismiss()
                    }
                    .disabled(selection == nil)
                }
            }
            .sheet(isPresented: $showsPicker) {
                TypedSourcePickerView(
                    title: "Link \(goal.title)",
                    kinds: TypedSourceKind.allCases,
                    repository: sourcePickerRepository
                ) { item in selection = item }
            }
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

private struct StarterPackBrowser: View {
    let install: (StarterPackPreview) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPack: StarterPack?
    @State private var preview: StarterPackPreview?
    var body: some View {
        NavigationStack {
            List {
                ForEach(StarterPack.allCases, id: \.self) { pack in
                    Button { selectedPack = pack; preview = StarterPackCatalog.preview(pack) } label: {
                        HStack { Label(packTitle(pack), systemImage: "shippingbox"); Spacer(); Image(systemName: "chevron.right") }
                    }
                }
            }
            .lifeBoardFormSurface()
            .navigationTitle("Starter packs")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() } } }
            .sheet(item: $selectedPack) { _ in
                if let preview { StarterPackPreviewSheet(preview: preview) { install($0); dismiss() } }
            }
        }
    }
    private func packTitle(_ pack: StarterPack) -> String {
        switch pack { case .morningFoundation: "Morning Foundation"; case .workdayReset: "Workday Reset"; case .lowEnergyRecovery: "Low Energy Recovery"; case .medicationSupport: "Medication Support"; case .eveningWindDown: "Evening Wind-down" }
    }
}

private struct StarterPackPreviewSheet: View {
    @State var preview: StarterPackPreview
    let install: (StarterPackPreview) -> Void
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Section("Nothing is created until you confirm") {
                    ForEach($preview.items) { $item in
                        Toggle(isOn: $item.isSelected) { Label(item.title, systemImage: itemSymbol(item.kind)) }
                    }
                }
                Text("Selected items use LifeBoard’s canonical creation flows. You can edit them afterward; removing the pack archives its definitions and preserves completed history.").font(.caption)
            }
            .lifeBoardFormSurface()
            .navigationTitle("Preview pack")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Create selected") { install(preview); dismiss() }.disabled(!preview.items.contains(where: \.isSelected)) }
            }
        }
    }
    private func itemSymbol(_ kind: StarterPackItemKind) -> String {
        switch kind { case .goal: "target"; case .habit: "repeat.circle"; case .routine: "figure.mind.and.body"; case .reminder: "bell" }
    }
}

private extension View {
    /// Delegates to the canonical clay depth scale. Previously carried a
    /// radius-9 shadow and a 0.5pt stroke, so Track cards sat at a different
    /// apparent height from the identical-looking cards on Plan and Home.
    func trackClayCard() -> some View {
        self.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.raised, cornerRadius: LifeBoardFoundationRadius.card)
    }
}
