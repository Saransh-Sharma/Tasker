import SwiftUI
import UIKit

extension StarterPack: Identifiable {
    public var id: String { rawValue }
}

private enum TrackCategory: String, CaseIterable, Identifiable {
    case today = "Today"
    case body = "Body"
    case mind = "Mind"
    case routines = "Routines"
    case goals = "Goals"
    case library = "Library"

    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .today: "sun.max"
        case .body: "heart.text.square"
        case .mind: "brain.head.profile"
        case .routines: "repeat"
        case .goals: "target"
        case .library: "books.vertical"
        }
    }
}

struct LifeBoardTrackFoundationRootView: View {
    @State private var store: TrackFoundationStore
    private let sourcePickerRepository: any TypedSourcePickerRepository
    private let onOpenHabitBoard: () -> Void
    private let nutritionRepository: any NutritionRepository
    private let lifeMomentRepository: any LifeMomentRepository
    private let wellnessRepository: any WellnessRepository
    @State private var showsMood = false
    @State private var editingMood: LifeBoardMoodEnergyCheckInValue?
    @State private var showsSleep = false
    @State private var editingSleep: SleepContextRecord?
    @State private var careHistoryDays = 7
    @State private var showsGoal = false
    @State private var editingGoal: GoalDefinition?
    @State private var goalPendingDeletion: GoalDefinition?
    @State private var showsStarterPacks = false
    @State private var showsRoutineComposer = false
    @State private var showsHabitResilience = false
    @State private var editingRoutine: RoutineDefinition?
    @State private var routinePendingDeletion: RoutineDefinition?
    @State private var showsCareLibrary = false
    @State private var showsHydrationTarget = false
    @State private var linkingGoal: GoalDefinition?
    @State private var selectedCategory: TrackCategory = .today
    @Environment(LifeBoardPresentationPreferences.self) private var preferences

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
        onOpenHabitBoard: @escaping () -> Void = {}
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
        self.nutritionRepository = nutritionRepository
        self.lifeMomentRepository = lifeMomentRepository
        self.wellnessRepository = wellnessRepository
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(LifeBoardColorTokens.foundationSurfaceSolid).ignoresSafeArea()
            LifeBoardAtmosphereView(
                daypart: preferences.resolvedDaypart(),
                requestedTier: preferences.renderingTier,
                comfortProfile: preferences.comfortProfile
            )
            .frame(height: 230).clipped().ignoresSafeArea(edges: .top)

            ScrollView {
                LazyVStack(spacing: 16) {
                    header
                    categoryRail
                    categoryContent
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .refreshable { await store.load() }
        }
        .navigationTitle("Track")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .sheet(isPresented: $showsMood, onDismiss: { editingMood = nil }) {
            MoodEnergyComposer(checkIn: editingMood) { value in
                Task { await store.saveMood(value) }
            } delete: { value in
                Task { await store.deleteMood(value) }
            }
        }
        .sheet(isPresented: $showsSleep, onDismiss: { editingSleep = nil }) {
            SleepContextComposer(existing: editingSleep) { record in Task { await store.saveSleep(record) } }
        }
        .sheet(isPresented: $showsGoal, onDismiss: { editingGoal = nil }) {
            GoalComposer(existing: editingGoal) { title, type, target, unit, targetDate in
                Task { await store.saveGoal(existing: editingGoal, title: title, type: type, target: target, unit: unit, targetDate: targetDate) }
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
                save: { policy in Task { await store.saveHabitPolicy(policy) } },
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
                Task { await store.saveRoutine(existing: editingRoutine, title: title, steps: steps, weekdays: weekdays, daypart: daypart) }
            }
        }
        .sheet(isPresented: $showsCareLibrary) {
            NavigationStack {
                LifeBoardTrackRootView(
                    repository: store.phaseIIRepository,
                    onOpenHabitBoard: onOpenHabitBoard
                )
            }
        }
        .sheet(isPresented: $showsHydrationTarget) {
            HydrationTargetComposer(currentTarget: store.snapshot.hydrationTargetMilliliters) { milliliters in
                Task { await store.setHydrationTarget(milliliters) }
            }
        }
        .sheet(isPresented: Binding(
            get: { store.activeRoutineRun != nil },
            set: { if !$0 && store.activeRoutineRun != nil { Task { await store.abandonRoutine() } } }
        )) {
            if let run = store.activeRoutineRun {
                RoutineRunner(run: run, advance: { response, skip in Task { await store.advanceRoutine(response: response, skip: skip) } }, abandon: { Task { await store.abandonRoutine() } })
                    .interactiveDismissDisabled()
            }
        }
        .alert("Track needs attention", isPresented: Binding(
            get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } }
        )) { Button("OK", role: .cancel) { store.errorMessage = nil } } message: { Text(store.errorMessage ?? "") }
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
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(TrackCategory.allCases) { category in
                    categoryChip(category)
                }
            }
        }
        .scrollIndicators(.hidden)
        .accessibilityLabel("Track categories")
    }

    private func categoryChip(_ category: TrackCategory) -> some View {
        let isSelected = selectedCategory == category
        let fill = Color(isSelected
            ? LifeBoardColorTokens.foundationSurfaceSelected
            : LifeBoardColorTokens.foundationSurfaceSolid)
        return Button {
            withAnimation(LifeBoardAnimation.roleLocalState) { selectedCategory = category }
        } label: {
            Label(category.rawValue, systemImage: category.symbol)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, 13)
                .frame(minHeight: 44)
                .background(fill, in: Capsule())
                .overlay { Capsule().stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1) }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("track.category.\(category.rawValue.lowercased())")
    }

    @ViewBuilder private var categoryContent: some View {
        switch selectedCategory {
        case .today:
            dueAndUnresolved
            routinesAndHabits
            careSnapshot
            goals
            modules
        case .body:
            dueAndUnresolved
            bodyCare
        case .mind:
            mindCare
        case .routines:
            routinesAndHabits
        case .goals:
            goals
        case .library:
            modules
        }
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
        .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1) }
    }

    private var careSnapshot: some View {
        VStack(spacing: 12) {
            trackSectionHeader("Care snapshot", symbol: "heart.text.square")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                hydrationTile
                careButton(title: "Mood + energy", value: latestMood, symbol: "face.smiling") { presentMoodComposer() }
                careButton(title: "Medication", value: store.snapshot.unresolvedMedicationEvents.isEmpty ? "Up to date" : "Decision needed", symbol: "pills") {
                    showsCareLibrary = true
                }
                careButton(title: "Sleep context", value: latestSleep, symbol: "moon.zzz") { showsSleep = true }
                    .privacySensitive()
            }
        }
    }

    private var bodyCare: some View {
        VStack(spacing: 12) {
            trackSectionHeader("Body", symbol: "heart.text.square")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                hydrationTile
                careButton(title: "Medication", value: store.snapshot.unresolvedMedicationEvents.isEmpty ? "Up to date" : "Decision needed", symbol: "pills") {
                    showsCareLibrary = true
                }
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
            Button { showsCareLibrary = true } label: {
                moduleRow("Health and care library", detail: "Medication, fasting, trackers, steps, and active energy", symbol: "heart.circle")
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
            NavigationLink { LifeBoardJournalModuleView(repository: store.phaseIIRepository) } label: {
                moduleRow("Journal", detail: "Capture and revisit private meaning", symbol: "book.closed")
            }
            .buttonStyle(.plain)
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

    private var hydrationTile: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Hydration", systemImage: "drop.fill").font(.headline)
            Text(hydrationLabel).font(.title3.weight(.semibold))
            if let amount = store.snapshot.hydrationAmountMilliliters, let target = store.snapshot.hydrationTargetMilliliters, target > 0 {
                ProgressView(value: min(1, amount / target)).tint(Color(LifeBoardColorTokens.foundationSageAccent))
            } else {
                Text("Set your own target").font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            HStack(spacing: 6) {
                Button("+250") { Task { await store.quickAddHydration(250) } }
                Button("+500") { Task { await store.quickAddHydration(500) } }
                Button("Target") { showsHydrationTarget = true }
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .trackClayCard()
        .accessibilityIdentifier("track.hydration")
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
                            Text(goal.title).font(.headline)
                            Spacer()
                            Text(progressLabel(progress)).font(.caption.weight(.semibold))
                            Menu {
                                Button("Link progress source", systemImage: "link.badge.plus") { linkingGoal = goal }
                                Button("Edit goal", systemImage: "pencil") { editingGoal = goal; showsGoal = true }
                                Button("Archive goal", systemImage: "archivebox") { Task { await store.archiveGoal(goal) } }
                                Button("Delete goal", systemImage: "trash", role: .destructive) { goalPendingDeletion = goal }
                            } label: {
                                Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Actions for \(goal.title)")
                        }
                        if let fraction = progress?.progressFraction { ProgressView(value: fraction).tint(Color(LifeBoardColorTokens.foundationFocusRing)) }
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
            NavigationLink { LifeBoardJournalModuleView(repository: store.phaseIIRepository) } label: { moduleRow("Journal", detail: "Phase II reflection and check-in history", symbol: "book.closed") }
                .buttonStyle(.plain)
            NavigationLink { LifeBoardKnowledgeModuleView(repository: store.phaseIIRepository) } label: { moduleRow("Notes", detail: "Knowledge spaces and typed links", symbol: "note.text") }
                .buttonStyle(.plain)
            if V2FeatureFlags.nutritionV1Enabled {
                NavigationLink { LifeBoardNutritionView(repository: nutritionRepository) } label: { moduleRow("Nutrition", detail: "Meal timeline, local foods, and factual summaries", symbol: "fork.knife") }
                    .buttonStyle(.plain)
            }
            if V2FeatureFlags.wellnessCoreV1Enabled {
                NavigationLink { LifeBoardWellnessView(repository: wellnessRepository) } label: { moduleRow("Wellness", detail: "Measurements, history, and accessible trends", symbol: "heart.text.square") }
                    .buttonStyle(.plain)
            }
            if V2FeatureFlags.lifeMomentsV1Enabled {
                NavigationLink { LifeBoardLifeMomentsView(repository: lifeMomentRepository) } label: { moduleRow("Life Moments", detail: "Countdowns, anniversaries, and meaningful dates", symbol: "calendar.badge.heart") }
                    .buttonStyle(.plain)
            }
            Button { showsCareLibrary = true } label: { moduleRow("Tracker and care library", detail: "Definitions, schedules, corrections, and history", symbol: "square.grid.3x3") }
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
                    Task { await store.saveMood(value); dismiss() }
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
                .sheet(isPresented: Binding(get: { store.activeRoutineRun != nil }, set: { _ in })) {
                    if let run = store.activeRoutineRun {
                        RoutineRunner(run: run, advance: { response, skip in Task { await store.advanceRoutine(response: response, skip: skip) } }, abandon: { Task { await store.abandonRoutine() } })
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
        .navigationTitle("Log hydration")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Add") { save(amount) }.disabled(amount <= 0) }
        }
    }
}

private struct HydrationTargetComposer: View {
    let save: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var amount: Double

    init(currentTarget: Double?, save: @escaping (Double) -> Void) {
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
            .navigationTitle("Hydration target")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(amount); dismiss() }
                        .disabled(amount <= 0)
                }
            }
        }
    }
}

private struct RoutineRunner: View {
    let run: RoutineRun
    let advance: (String?, Bool) -> Void
    let abandon: () -> Void
    @State private var response: String?

    private var step: RoutineStep? { run.versionSnapshot.steps.first { $0.id == run.currentStepID } }
    private var index: Int { max(0, run.versionSnapshot.steps.firstIndex(where: { $0.id == run.currentStepID }) ?? 0) }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(LifeBoardColorTokens.foundationSurfaceSolid).ignoresSafeArea()
                VStack(spacing: 22) {
                    ProgressView(value: Double(index + 1), total: Double(max(1, run.versionSnapshot.steps.count))).tint(Color(LifeBoardColorTokens.foundationFocusRing))
                    Spacer()
                    if let step {
                        Image(systemName: symbol(step.kind)).font(.system(size: 44)).foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                        Text(step.title).font(LifeBoardFoundationTypography.screenTitle()).multilineTextAlignment(.center)
                        if step.kind == .timer, let duration = step.duration {
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                let remaining = timerRemaining(duration: duration, at: context.date)
                                VStack(spacing: 8) {
                                    Text(durationLabel(remaining))
                                        .font(.system(.title, design: .rounded, weight: .semibold).monospacedDigit())
                                    ProgressView(value: max(0, duration - remaining), total: max(1, duration))
                                        .tint(Color(LifeBoardColorTokens.foundationFocusRing))
                                }
                            }
                        } else if let duration = step.duration {
                            Text("About \(Int(duration / 60)) minutes").foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                        if !step.choices.isEmpty {
                            Picker("Response", selection: $response) {
                                Text("Choose").tag(String?.none)
                                ForEach(step.choices, id: \.self) { Text($0).tag(String?.some($0)) }
                            }.pickerStyle(.menu)
                        }
                    }
                    Spacer()
                    primaryAction
                    if step?.isSkippable == true { Button("Skip this step") { advance(nil, true) }.buttonStyle(.bordered) }
                }
                .padding(28)
            }
            .navigationTitle(run.versionSnapshot.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("End", role: .destructive) { abandon() } } }
        }
    }

    private func symbol(_ kind: RoutineStepKind) -> String {
        switch kind { case .task: "checkmark.circle"; case .habit: "repeat.circle"; case .checkIn: "heart.text.square"; case .timer: "timer"; case .instruction: "hand.point.up.left"; case .choice: "point.3.connected.trianglepath.dotted" }
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

    private func timerRemaining(duration: TimeInterval, at date: Date) -> TimeInterval {
        let activatedAt = run.events.last?.occurredAt ?? run.startedAt
        return max(0, duration - date.timeIntervalSince(activatedAt))
    }

    private func durationLabel(_ interval: TimeInterval) -> String {
        let seconds = max(0, Int(interval.rounded(.up)))
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
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
    let save: (HabitResiliencePolicy) -> Void
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
        let offDays = policy.offDays.isEmpty ? "no exceptions" : "\(policy.offDays.count) off-day exception\(policy.offDays.count == 1 ? "" : "s")"
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
    let habit: TypedSourcePickerItem
    let originalPolicy: HabitResiliencePolicy
    let groups: [HabitGroup]
    let history: [HabitOccurrenceEvidence]
    let recover: (UUID, PlanningDay) async -> HabitRecoveryReceipt?
    let undoRecovery: (UUID, PlanningDay) async -> Bool
    let save: (HabitResiliencePolicy) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var recoveryEnabled: Bool
    @State private var streakPresentation: HabitStreakPresentation
    @State private var offDays: Set<PlanningDay>
    @State private var groupID: UUID?
    @State private var recoveryReceipts: [HabitRecoveryReceipt]
    @State private var mutatingDays: Set<PlanningDay> = []

    init(
        habit: TypedSourcePickerItem,
        policy: HabitResiliencePolicy,
        groups: [HabitGroup],
        history: [HabitOccurrenceEvidence],
        recover: @escaping (UUID, PlanningDay) async -> HabitRecoveryReceipt?,
        undoRecovery: @escaping (UUID, PlanningDay) async -> Bool,
        save: @escaping (HabitResiliencePolicy) -> Void
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
        .navigationTitle(habit.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    var policy = originalPolicy
                    policy.habitID = habit.id
                    policy.groupID = groupID
                    policy.recoveryEnabled = recoveryEnabled
                    policy.streakPresentation = streakPresentation
                    policy.offDays = offDays
                    policy.recoveryReceipts = recoveryReceipts
                    policy.updatedAt = Date()
                    save(policy)
                    dismiss()
                }
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
        case .due: return "Due · not completed"
        case .completed: return "Completed"
        case .manuallySkipped: return "Skipped"
        case .recovered: return "Recovered · counts toward grade"
        }
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
            linkedID = step?.linkedEntityID?.uuidString ?? ""
            linkedTitle = step?.linkedEntityID == nil ? "" : "Linked \((step?.kind ?? .task) == .habit ? "habit" : "task")"
        }
    }

    let existing: RoutineDefinition?
    let schedule: RoutineSchedule?
    let sourcePickerRepository: any TypedSourcePickerRepository
    let save: (String, [RoutineStep], Set<Int>, ResolvedDaypart?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var steps: [DraftStep]
    @State private var weekdays: Set<Int>
    @State private var daypart: ResolvedDaypart?
    @State private var pickingStep: StepLinkTarget?

    private struct StepLinkTarget: Identifiable { let id: UUID }

    init(
        existing: RoutineDefinition? = nil,
        schedule: RoutineSchedule? = nil,
        sourcePickerRepository: any TypedSourcePickerRepository,
        save: @escaping (String, [RoutineStep], Set<Int>, ResolvedDaypart?) -> Void
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
            .navigationTitle(existing == nil ? "New routine" : "Edit routine")
            .environment(\.editMode, .constant(.active))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button(existing == nil ? "Create" : "Save") { saveRoutine(); dismiss() }
                        .disabled(!isValid)
                }
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
    }

    private func saveRoutine() {
        let values = steps.enumerated().map { index, draft in
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
                    ? draft.choices.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                    : []
            )
        }
        save(title, values, weekdays, daypart)
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
    let save: (LifeBoardMoodEnergyCheckInValue) -> Void
    let delete: ((LifeBoardMoodEnergyCheckInValue) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var mood: LifeBoardJournalMood
    @State private var energy: Int
    @State private var includesEnergy: Bool
    @State private var confirmsDelete = false

    init(
        checkIn: LifeBoardMoodEnergyCheckInValue? = nil,
        save: @escaping (LifeBoardMoodEnergyCheckInValue) -> Void,
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
            .navigationTitle(checkIn == nil ? "Mood + energy" : "Edit check-in")
            .toolbar { composerToolbar { saveValue() } }
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
        var value = checkIn ?? LifeBoardMoodEnergyCheckInValue(mood: mood, energy: includesEnergy ? energy : nil)
        value.mood = mood
        value.energy = includesEnergy ? energy : nil
        save(value)
        dismiss()
    }
}

private struct SleepContextComposer: View {
    let existing: SleepContextRecord?
    let save: (SleepContextRecord) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var bedtime: Date
    @State private var wake: Date
    @State private var rest: Int
    @State private var interruptions: Int
    @State private var notes: String

    init(existing: SleepContextRecord? = nil, save: @escaping (SleepContextRecord) -> Void) {
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
            .privacySensitive()
            .navigationTitle(existing == nil ? "Sleep context" : "Edit sleep context")
            .toolbar { composerToolbar { saveValue() } }
        }
    }

    private func saveValue() {
        let trimmed = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        save(SleepContextRecord(
            id: existing?.id ?? UUID(),
            bedtime: bedtime,
            wakeTime: wake,
            perceivedRest: rest,
            interruptionCount: interruptions,
            notes: trimmed.isEmpty ? nil : trimmed,
            createdAt: existing?.createdAt ?? Date()
        ))
        dismiss()
    }
}

private struct GoalComposer: View {
    let existing: GoalDefinition?
    let save: (String, GoalType, Double?, String?, Date?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var type: GoalType
    @State private var target: Double
    @State private var unit: String
    @State private var targetDate: Date

    init(
        existing: GoalDefinition? = nil,
        save: @escaping (String, GoalType, Double?, String?, Date?) -> Void
    ) {
        self.existing = existing
        self.save = save
        _title = State(initialValue: existing?.title ?? "")
        _type = State(initialValue: existing?.type ?? .completion)
        let storedTarget = existing?.targetValue ?? 1
        _target = State(initialValue: existing?.type == .duration ? storedTarget / 60 : storedTarget)
        _unit = State(initialValue: existing?.unitLabel == "seconds" ? "" : existing?.unitLabel ?? "")
        _targetDate = State(initialValue: existing?.targetDate ?? Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Goal title", text: $title)
                Picker("Goal type", selection: $type) {
                    ForEach(GoalType.allCases, id: \.self) { Text(goalTypeTitle($0)).tag($0) }
                }
                if usesNumericTarget {
                    TextField(type == .duration ? "Target minutes" : "Target", value: $target, format: .number)
                        .keyboardType(.decimalPad)
                    if type == .quantity { TextField("Unit (optional)", text: $unit) }
                }
                if type == .targetDate { DatePicker("Target date", selection: $targetDate, displayedComponents: .date) }
                Text("Progress comes only from sources you explicitly link after creating the goal.")
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            .navigationTitle(existing == nil ? "New goal" : "Edit goal")
            .toolbar {
                composerToolbar(disabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (usesNumericTarget && target <= 0)) {
                    save(
                        title,
                        type,
                        usesNumericTarget ? (type == .duration ? target * 60 : target) : nil,
                        type == .quantity ? unit : type == .duration ? "seconds" : nil,
                        type == .targetDate ? targetDate : nil
                    )
                    dismiss()
                }
            }
        }
    }

    private var usesNumericTarget: Bool { type == .count || type == .quantity || type == .duration }
    private func goalTypeTitle(_ type: GoalType) -> String {
        switch type {
        case .completion: "Completion"
        case .count: "Count"
        case .quantity: "Quantity"
        case .duration: "Duration"
        case .targetDate: "Target date"
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

@ToolbarContentBuilder
private func composerToolbar(disabled: Bool = false, save: @escaping () -> Void) -> some ToolbarContent {
    ToolbarItem(placement: .cancellationAction) { DismissComposerButton() }
    ToolbarItem(placement: .confirmationAction) { Button("Save", action: save).disabled(disabled) }
}

private struct DismissComposerButton: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View { Button("Cancel") { dismiss() } }
}

private extension View {
    func trackClayCard() -> some View {
        self.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(LifeBoardColorTokens.foundationSurfaceSolid), in: RoundedRectangle(cornerRadius: LifeBoardFoundationRadius.card, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: LifeBoardFoundationRadius.card, style: .continuous).stroke(Color(LifeBoardColorTokens.foundationHairline).opacity(0.55), lineWidth: 0.5))
            .shadow(color: Color(LifeBoardColorTokens.foundationWarmShadow), radius: 9, y: 4)
    }
}
