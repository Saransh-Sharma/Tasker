import SwiftUI
import UIKit

extension StarterPack: Identifiable {
    public var id: String { rawValue }
}

struct LifeBoardTrackFoundationRootView: View {
    @State private var store: TrackFoundationStore
    @State private var showsMood = false
    @State private var showsSleep = false
    @State private var showsGoal = false
    @State private var showsStarterPacks = false
    @Environment(LifeBoardPresentationPreferences.self) private var preferences

    init(repository: CoreDataTrackFoundationRepository, phaseIIRepository: any LifeBoardPhaseIIRepository) {
        _store = State(initialValue: TrackFoundationStore(repository: repository, phaseIIRepository: phaseIIRepository))
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
                    dueAndUnresolved
                    routinesAndHabits
                    careSnapshot
                    goals
                    modules
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
            }
            .refreshable { await store.load() }
        }
        .navigationTitle("Track")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .sheet(isPresented: $showsMood) { MoodEnergyComposer { mood, energy in Task { await store.saveMood(mood, energy: energy) } } }
        .sheet(isPresented: $showsSleep) { SleepContextComposer { bedtime, wake, rest, interruptions, notes in Task { await store.saveSleep(bedtime: bedtime, wakeTime: wake, rest: rest, interruptions: interruptions, notes: notes) } } }
        .sheet(isPresented: $showsGoal) { GoalComposer { title, target in Task { await store.saveGoal(title: title, target: target) } } }
        .sheet(isPresented: $showsStarterPacks) { StarterPackBrowser { preview in Task { await store.installStarterPack(preview) } } }
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
                        Image(systemName: "pills.fill").foregroundStyle(.orange)
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
                        Button("Snooze") { Task { await store.resolveMedication(event: event, status: .snoozed) } }.buttonStyle(.bordered)
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
            trackSectionHeader("Current daypart", symbol: daypartSymbol)
            if store.snapshot.dueRoutines.isEmpty {
                trackEmpty("No routines due", detail: "Start progressively or preview a starter pack.", symbol: "figure.cooldown")
            } else {
                ForEach(store.snapshot.dueRoutines) { routine in
                    Button { Task { await store.startRoutine(routine) } } label: {
                        HStack(spacing: 14) {
                            Image(systemName: "play.circle.fill").font(.title2).foregroundStyle(.orange)
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
                }
            }
            Button {
                NotificationCenter.default.post(name: .lifeboardOpenHabitBoardDeepLink, object: nil)
            } label: {
                HStack {
                    Image(systemName: "repeat.circle.fill").foregroundStyle(.brown)
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
        }
    }

    private var careSnapshot: some View {
        VStack(spacing: 12) {
            trackSectionHeader("Care snapshot", symbol: "heart.text.square")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                hydrationTile
                careButton(title: "Mood + energy", value: latestMood, symbol: "face.smiling") { showsMood = true }
                careButton(title: "Medication", value: store.snapshot.unresolvedMedicationEvents.isEmpty ? "Up to date" : "Decision needed", symbol: "pills") {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
                careButton(title: "Sleep context", value: latestSleep, symbol: "moon.zzz") { showsSleep = true }
                    .privacySensitive()
            }
        }
    }

    private var hydrationTile: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Hydration", systemImage: "drop.fill").font(.headline)
            Text(hydrationLabel).font(.title3.weight(.semibold))
            if let amount = store.snapshot.hydrationAmountMilliliters, let target = store.snapshot.hydrationTargetMilliliters, target > 0 {
                ProgressView(value: min(1, amount / target)).tint(.blue)
            } else {
                Text("Set your own target").font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            HStack(spacing: 6) {
                Button("+250") { Task { await store.quickAddHydration(250) } }
                Button("+500") { Task { await store.quickAddHydration(500) } }
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .trackClayCard()
        .accessibilityIdentifier("track.hydration")
    }

    private var goals: some View {
        VStack(spacing: 12) {
            trackSectionHeader("Goals and progress", symbol: "target", trailing: {
                Button { showsGoal = true } label: { Image(systemName: "plus") }.accessibilityLabel("Add goal")
            })
            if store.definitions.isEmpty {
                trackEmpty("No goals required", detail: "Goals are optional. Add one only when it helps organize action.", symbol: "scope")
            } else {
                ForEach(store.definitions) { goal in
                    let progress = store.snapshot.goals.first(where: { $0.goalID == goal.id })
                    VStack(alignment: .leading, spacing: 10) {
                        HStack { Text(goal.title).font(.headline); Spacer(); Text(progressLabel(progress)).font(.caption.weight(.semibold)) }
                        if let fraction = progress?.progressFraction { ProgressView(value: fraction).tint(.brown) }
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
            NavigationLink { LifeBoardJournalModuleView(repository: store.phaseIIRepository) } label: { moduleRow("Journal", detail: "Phase II reflection and check-in history", symbol: "book.closed") }
                .buttonStyle(.plain)
            NavigationLink { LifeBoardKnowledgeModuleView(repository: store.phaseIIRepository) } label: { moduleRow("Notes", detail: "Knowledge spaces and typed links", symbol: "note.text") }
                .buttonStyle(.plain)
        }
    }

    private func moduleRow(_ title: String, detail: String, symbol: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol).font(.title3).frame(width: 28).foregroundStyle(.brown)
            VStack(alignment: .leading, spacing: 3) { Text(title).font(.headline); Text(detail).font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary)) }
            Spacer(); Image(systemName: "chevron.right")
        }.trackClayCard()
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
            Image(systemName: symbol).font(.title2).foregroundStyle(.orange)
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
        phaseIIRepository: any LifeBoardPhaseIIRepository
    ) {
        self.kind = kind
        _store = State(initialValue: TrackFoundationStore(repository: repository, phaseIIRepository: phaseIIRepository))
    }

    var body: some View {
        Group {
            switch kind {
            case .mood:
                MoodEnergyComposer { mood, energy in
                    Task { await store.saveMood(mood, energy: energy); dismiss() }
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
                    ProgressView(value: Double(index + 1), total: Double(max(1, run.versionSnapshot.steps.count))).tint(.brown)
                    Spacer()
                    if let step {
                        Image(systemName: symbol(step.kind)).font(.system(size: 44)).foregroundStyle(.orange)
                        Text(step.title).font(LifeBoardFoundationTypography.screenTitle()).multilineTextAlignment(.center)
                        if let duration = step.duration { Text("About \(Int(duration / 60)) minutes").foregroundStyle(Color(LifeBoardColorTokens.inkSecondary)) }
                        if !step.choices.isEmpty {
                            Picker("Response", selection: $response) {
                                Text("Choose").tag(String?.none)
                                ForEach(step.choices, id: \.self) { Text($0).tag(String?.some($0)) }
                            }.pickerStyle(.menu)
                        }
                    }
                    Spacer()
                    Button("Continue") { advance(response, false) }.buttonStyle(.borderedProminent).controlSize(.large).disabled(step?.kind == .choice && response == nil)
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
}

private struct MoodEnergyComposer: View {
    let save: (LifeBoardJournalMood, Int?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var mood: LifeBoardJournalMood = .none
    @State private var energy = 3
    var body: some View {
        NavigationStack {
            Form {
                Picker("Mood", selection: $mood) { ForEach(LifeBoardJournalMood.allCases) { Text($0.title).tag($0) } }
                Stepper("Energy: \(energy)/5", value: $energy, in: 1...5)
                Text("This records your signal. LifeBoard does not assign a clinical interpretation.").font(.caption)
            }
            .navigationTitle("Mood + energy")
            .toolbar { composerToolbar { save(mood, energy); dismiss() } }
        }
    }
}

private struct SleepContextComposer: View {
    let save: (Date, Date, Int?, Int, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var bedtime = Calendar.current.date(byAdding: .hour, value: -8, to: Date()) ?? Date()
    @State private var wake = Date()
    @State private var rest = 3
    @State private var interruptions = 0
    @State private var notes = ""
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
            .navigationTitle("Sleep context")
            .toolbar { composerToolbar { save(bedtime, wake, rest, interruptions, notes.isEmpty ? nil : notes); dismiss() } }
        }
    }
}

private struct GoalComposer: View {
    let save: (String, Double?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var hasTarget = false
    @State private var target = 1.0
    var body: some View {
        NavigationStack {
            Form {
                TextField("Goal title", text: $title)
                Toggle("Quantity target", isOn: $hasTarget)
                if hasTarget { TextField("Target", value: $target, format: .number).keyboardType(.decimalPad) }
            }
            .navigationTitle("New goal")
            .toolbar { composerToolbar(disabled: title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) { save(title, hasTarget ? target : nil); dismiss() } }
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
                Text("Habit and reminder templates open in their canonical editor so permissions and schedules stay explicit.").font(.caption)
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
