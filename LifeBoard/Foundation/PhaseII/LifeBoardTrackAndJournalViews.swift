import AVFAudio
import CoreSpotlight
import Foundation
import Observation
import PhotosUI
import Speech
import SwiftUI
import UIKit

// MARK: - Track module

@MainActor
@Observable
final class LifeBoardTrackStore {
    private(set) var trackers: [LifeBoardTrackerDefinitionValue] = []
    private(set) var trackerEntries: [LifeBoardTrackerEntryValue] = []
    private(set) var checkIns: [LifeBoardMoodEnergyCheckInValue] = []
    private(set) var medications: [LifeBoardMedicationDefinitionValue] = []
    private(set) var medicationEvents: [LifeBoardMedicationEventValue] = []
    private(set) var fastingSessions: [LifeBoardFastingSessionValue] = []
    private(set) var isLoading = false
    var errorMessage: String?

    let healthStore: LifeBoardHealthStore
    let repository: any LifeBoardPhaseIIRepository

    init(repository: any LifeBoardPhaseIIRepository, healthStore: LifeBoardHealthStore = LifeBoardHealthStore()) {
        self.repository = repository
        self.healthStore = healthStore
    }

    var activeFast: LifeBoardFastingSessionValue? {
        fastingSessions.first(where: { $0.endedAt == nil })
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let calendar = Calendar.current
            let start = calendar.startOfDay(for: Date())
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
            async let trackerValues = repository.fetchTrackers()
            async let entryValues = repository.fetchTrackerEntries(trackerID: nil)
            async let moodValues = repository.fetchMoodCheckIns(from: start, to: end)
            async let medicationValues = repository.fetchMedications()
            async let eventValues = repository.fetchMedicationEvents(from: start, to: end)
            async let fastingValues = repository.fetchFastingSessions(limit: 30)
            (trackers, trackerEntries, checkIns, medications, medicationEvents, fastingSessions) = try await (
                trackerValues, entryValues, moodValues, medicationValues, eventValues, fastingValues
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveMood(_ mood: LifeBoardJournalMood, energy: Int?) async {
        do {
            try await repository.saveMoodCheckIn(.init(mood: mood, energy: energy))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveTracker(_ tracker: LifeBoardTrackerDefinitionValue) async {
        do {
            try await repository.saveTracker(tracker)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func log(_ tracker: LifeBoardTrackerDefinitionValue, numericValue: Double? = nil, booleanValue: Bool? = nil) async {
        do {
            try await repository.saveTrackerEntry(.init(
                trackerID: tracker.id,
                numericValue: numericValue,
                booleanValue: booleanValue
            ))
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveMedication(_ medication: LifeBoardMedicationDefinitionValue) async {
        do {
            try await repository.saveMedication(medication)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func resolveMedication(_ medication: LifeBoardMedicationDefinitionValue, status: LifeBoardMedicationEventStatus) async {
        let existing = medicationEvents.first(where: { $0.medicationID == medication.id && $0.status == .scheduled })
        let event = LifeBoardMedicationEventValue(
            id: existing?.id ?? UUID(),
            medicationID: medication.id,
            scheduledAt: existing?.scheduledAt ?? Date(),
            status: status,
            resolvedAt: Date()
        )
        do {
            try await repository.saveMedicationEvent(event)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func toggleFast(target: TimeInterval?) async {
        do {
            if var activeFast {
                activeFast.endedAt = Date()
                try await repository.saveFastingSession(activeFast)
            } else {
                try await repository.saveFastingSession(.init(targetDuration: target))
            }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }
}

struct LifeBoardTrackRootView: View {
    enum Module: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case habits = "Habits"
        case trackers = "Trackers"
        case journal = "Journal"
        case notes = "Notes"
        var id: String { rawValue }
    }

    @State private var store: LifeBoardTrackStore
    @State private var module: Module = .overview
    @State private var showsMood = false
    @State private var mood: LifeBoardJournalMood = .none
    @State private var showsTrackerComposer = false
    @State private var showsMedicationComposer = false
    @Environment(LifeBoardPresentationPreferences.self) private var preferences

    init(repository: any LifeBoardPhaseIIRepository) {
        _store = State(initialValue: LifeBoardTrackStore(repository: repository))
    }

    var body: some View {
        let palette = LifeBoardDaypartTokens.palette(for: preferences.resolvedDaypart())
        ZStack {
            LifeBoardAtmosphereView(
                daypart: preferences.resolvedDaypart(),
                requestedTier: preferences.renderingTier,
                comfortProfile: preferences.comfortProfile
            )
            .ignoresSafeArea()
            VStack(spacing: 0) {
                modulePicker(palette: palette)
                Group {
                    switch module {
                    case .overview: overview(palette: palette)
                    case .habits: habitsBridge(palette: palette)
                    case .trackers: trackers(palette: palette)
                    case .journal:
                        LifeBoardJournalModuleView(repository: store.repository)
                    case .notes:
                        LifeBoardKnowledgeModuleView(repository: store.repository)
                    }
                }
            }
        }
        .foregroundStyle(palette.color(for: .foreground))
        .navigationTitle("Track")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .alert("Track is unavailable", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(store.errorMessage ?? "") }
        .sheet(isPresented: $showsMood) {
            LifeBoardJournalMoodDialSheet(selectedMood: $mood) { energy in
                Task { await store.saveMood(mood, energy: energy) }
            }
        }
        .sheet(isPresented: $showsTrackerComposer) {
            LifeBoardTrackerComposer { tracker in Task { await store.saveTracker(tracker) } }
        }
        .sheet(isPresented: $showsMedicationComposer) {
            LifeBoardMedicationComposer { medication in Task { await store.saveMedication(medication) } }
        }
    }

    private func modulePicker(palette: LifeBoardDaypartPalette) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableModules) { item in
                    Button(item.rawValue) { module = item }
                        .buttonStyle(.bordered)
                        .tint(module == item ? palette.color(for: .foreground) : palette.color(for: .foregroundSecondary))
                        .accessibilityAddTraits(module == item ? .isSelected : [])
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
    }

    private var availableModules: [Module] {
        var values: [Module] = [.overview, .habits]
        if V2FeatureFlags.trackersV1Enabled { values.append(.trackers) }
        if V2FeatureFlags.journalV1Enabled { values.append(.journal) }
        if V2FeatureFlags.knowledgeNotesV1Enabled { values.append(.notes) }
        return values
    }

    private func overview(palette: LifeBoardDaypartPalette) -> some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                HStack(spacing: 12) {
                    Button { showsMood = true } label: {
                        overviewTile(
                            title: "Mood & energy",
                            value: store.checkIns.first.map { $0.mood.title } ?? "Check in",
                            symbol: "face.smiling",
                            palette: palette
                        )
                    }
                    Button { Task { await store.healthStore.requestAccessAndRefresh() } } label: {
                        overviewTile(
                            title: "Health",
                            value: healthSummary,
                            symbol: "heart.text.clipboard",
                            palette: palette
                        )
                    }
                }
                .buttonStyle(.plain)

                careCard(palette: palette)
                fastingCard(palette: palette)
                dueTrackersCard(palette: palette)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .refreshable { await store.load() }
    }

    private func overviewTile(title: String, value: String, symbol: String, palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
            Spacer(minLength: 2)
            Text(value).font(.headline).lineLimit(2)
            Text(title).font(.caption).foregroundStyle(palette.color(for: .foregroundSecondary))
        }
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .leading)
        .padding(16)
        .lifeBoardPaperCard()
        .contentShape(Rectangle())
    }

    private var healthSummary: String {
        switch store.healthStore.snapshot.availability {
        case .notRequested: "Connect"
        case .unavailable: "No data"
        case .available:
            if let steps = store.healthStore.snapshot.steps { "\(Int(steps)) steps" } else { "No data" }
        }
    }

    private func careCard(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Medication", systemImage: "pills")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button("Add") { showsMedicationComposer = true }
            }
            if store.medications.isEmpty {
                Text("Add only what you want LifeBoard to remind you about. LifeBoard never infers a missed dose.")
                    .font(.subheadline)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            } else {
                ForEach(store.medications) { medication in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(medication.name).font(.headline)
                            if let dosage = medication.dosageText { Text(dosage).font(.caption) }
                        }
                        Spacer()
                        Menu("Resolve") {
                            Button("Taken", systemImage: "checkmark.circle") { Task { await store.resolveMedication(medication, status: .taken) } }
                            Button("Snoozed", systemImage: "clock.arrow.circlepath") { Task { await store.resolveMedication(medication, status: .snoozed) } }
                            Button("Skipped", systemImage: "forward.end") { Task { await store.resolveMedication(medication, status: .skipped) } }
                        }
                    }
                    .padding(12)
                    .background(palette.color(for: .layerOne).opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
                }
            }
        }
        .padding(18)
        .lifeBoardPaperCard()
    }

    private func fastingCard(palette: LifeBoardDaypartPalette) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "timer")
                .font(.title2)
                .frame(width: 44, height: 44)
                .background(palette.color(for: .layerOne).opacity(0.45), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(store.activeFast == nil ? "Fasting timer" : "Timer active")
                    .font(.headline)
                Text(store.activeFast.map { Self.duration($0.elapsed()) } ?? "Neutral timer—no coaching or claims")
                    .font(.caption)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            Spacer()
            Button {
                Task { await store.toggleFast(target: nil) }
            } label: {
                Text(store.activeFast == nil ? "Start" : "End")
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationSurfaceSolid))
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.color(for: .foreground))
        }
        .padding(18)
        .lifeBoardPaperCard()
    }

    private func dueTrackersCard(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Due check-ins").font(.title3.weight(.semibold))
                Spacer()
                Button("Add tracker") { showsTrackerComposer = true }
            }
            if store.trackers.isEmpty {
                Text("Create a check-in, count, quantity, rating, or timer.")
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            } else {
                ForEach(store.trackers.prefix(4)) { tracker in
                    trackerRow(tracker, palette: palette)
                }
            }
        }
        .padding(18)
        .lifeBoardPaperCard()
    }

    private func trackerRow(_ tracker: LifeBoardTrackerDefinitionValue, palette: LifeBoardDaypartPalette) -> some View {
        HStack {
            Image(systemName: trackerSymbol(tracker.kind)).frame(width: 28)
            VStack(alignment: .leading) {
                Text(tracker.title).font(.headline)
                Text(tracker.kind.rawValue.capitalized).font(.caption).foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            Spacer()
            Button(tracker.kind == .boolean ? "Check" : "+1") {
                Task {
                    await store.log(
                        tracker,
                        numericValue: tracker.kind == .boolean ? nil : 1,
                        booleanValue: tracker.kind == .boolean ? true : nil
                    )
                }
            }
            .buttonStyle(.bordered)
        }
        .frame(minHeight: 44)
    }

    private func trackers(palette: LifeBoardDaypartPalette) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                HStack {
                    Text("Your trackers").font(.title2.weight(.semibold))
                    Spacer()
                    Button("New", systemImage: "plus") { showsTrackerComposer = true }
                }
                ForEach(store.trackers) { tracker in
                    VStack(alignment: .leading, spacing: 12) {
                        trackerRow(tracker, palette: palette)
                        let recent = store.trackerEntries.filter { $0.trackerID == tracker.id }.prefix(7)
                        if !recent.isEmpty {
                            HStack(spacing: 6) {
                                ForEach(Array(recent)) { entry in
                                    Capsule()
                                        .fill(palette.color(for: .celestialPrimary))
                                        .frame(maxWidth: .infinity, minHeight: 8, maxHeight: CGFloat(8 + (entry.numericValue ?? 1) * 3))
                                        .accessibilityLabel("Entry \(entry.numericValue ?? (entry.booleanValue == true ? 1 : 0))")
                                }
                            }
                            .frame(height: 40, alignment: .bottom)
                        }
                    }
                    .padding(16)
                    .lifeBoardPaperCard()
                }
            }
            .padding(20)
        }
    }

    private func habitsBridge(palette: LifeBoardDaypartPalette) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "repeat.circle.fill").font(.system(size: 44))
            Text("Habits remain connected").font(.title2.weight(.semibold))
            Text("Open the existing habit board while its projections continue feeding Adaptive Home.")
                .multilineTextAlignment(.center)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
            Button {
                NotificationCenter.default.post(name: .lifeboardOpenHabitBoardDeepLink, object: nil)
            } label: {
                Text("Open Habits")
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationSurfaceSolid))
            }
            .buttonStyle(.borderedProminent)
            .tint(palette.color(for: .foreground))
        }
        .padding(24)
        .lifeBoardPaperCard()
        .padding(20)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func trackerSymbol(_ kind: LifeBoardTrackerKind) -> String {
        switch kind {
        case .boolean: "checkmark.circle"
        case .count: "number.circle"
        case .quantity: "ruler"
        case .rating: "slider.horizontal.3"
        case .duration: "timer"
        }
    }

    private static func duration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3_600
        let minutes = (Int(interval) % 3_600) / 60
        return "\(hours)h \(minutes)m elapsed"
    }
}

private struct LifeBoardTrackerComposer: View {
    let onSave: (LifeBoardTrackerDefinitionValue) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var kind: LifeBoardTrackerKind = .boolean
    @State private var unit = ""
    @State private var target = 1.0

    var body: some View {
        NavigationStack {
            Form {
                TextField("Tracker name", text: $title)
                Picker("Kind", selection: $kind) {
                    ForEach(LifeBoardTrackerKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                if kind == .quantity { TextField("Unit", text: $unit) }
                if kind != .boolean { Stepper("Daily target: \(target, format: .number)", value: $target, in: 1...10_000) }
            }
            .navigationTitle("New Tracker")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(.init(title: title, kind: kind, unitLabel: unit.isEmpty ? nil : unit, targetValue: kind == .boolean ? nil : target))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

private struct LifeBoardMedicationComposer: View {
    let onSave: (LifeBoardMedicationDefinitionValue) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var dosage = ""
    @State private var instructions = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Medication") {
                    TextField("Name", text: $name)
                    TextField("Dose label (optional)", text: $dosage)
                    TextField("Instructions (optional)", text: $instructions, axis: .vertical)
                }
                Section {
                    Text("LifeBoard records only the status you choose. A passed window becomes unresolved, not missed.")
                }
            }
            .navigationTitle("Add Medication")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(.init(name: name, dosageText: dosage.isEmpty ? nil : dosage, instructions: instructions.isEmpty ? nil : instructions))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

// MARK: - Journal module

@MainActor
@Observable
final class LifeBoardJournalStore {
    enum Section: String, CaseIterable, Identifiable { case today = "Today", library = "Library", insights = "Insights"; var id: String { rawValue } }

    private(set) var today: LifeBoardJournalDayValue?
    private(set) var days: [LifeBoardJournalDayValue] = []
    private(set) var isLoading = false
    var section: Section = .today
    var searchText = ""
    var starredOnly = false
    var moodFilter: LifeBoardJournalMood?
    var errorMessage: String?

    let repository: any LifeBoardPhaseIIRepository

    init(repository: any LifeBoardPhaseIIRepository) { self.repository = repository }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let todayValue = repository.fetchJournalDay(containing: Date())
            async let dayValues = repository.fetchJournalDays(search: searchText, starredOnly: starredOnly, mood: moodFilter)
            (today, days) = try await (todayValue, dayValues)
        } catch { errorMessage = error.localizedDescription }
    }

    func appendText(_ text: String, promptID: String? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var day = today ?? LifeBoardJournalDayValue(day: Date())
        day.blocks.append(.init(dayID: day.id, kind: .text, text: trimmed, promptID: promptID, ordinal: day.blocks.count))
        day.updatedAt = Date()
        await save(day)
    }

    func appendMood(_ mood: LifeBoardJournalMood, energy: Int?) async {
        var day = today ?? LifeBoardJournalDayValue(day: Date())
        let now = Date()
        day.blocks.append(.init(dayID: day.id, kind: .mood, mood: mood, energy: energy, createdAt: now, updatedAt: now, ordinal: day.blocks.count))
        day.updatedAt = now
        do {
            let checkIn = LifeBoardMoodEnergyCheckInValue(mood: mood, energy: energy, createdAt: now, representativeDay: day.day, isRepresentative: true)
            day.representativeCheckInID = checkIn.id
            try await repository.saveMoodCheckIn(checkIn)
            await save(day)
        } catch { errorMessage = error.localizedDescription }
    }

    func appendPhoto(_ data: Data) async {
        var day = today ?? LifeBoardJournalDayValue(day: Date())
        let media = LifeBoardJournalMediaValue(dayID: day.id, kind: .photo, payload: data, syncPolicy: .privateCloud)
        day.media.append(media)
        day.blocks.append(.init(dayID: day.id, kind: .photo, mediaID: media.id, ordinal: day.blocks.count))
        day.updatedAt = Date()
        await save(day)
    }

    func appendAudio(relativePath: String, duration: TimeInterval, transcription: String?) async {
        var day = today ?? LifeBoardJournalDayValue(day: Date())
        let media = LifeBoardJournalMediaValue(
            dayID: day.id,
            kind: .audio,
            relativePath: relativePath,
            duration: duration,
            syncPolicy: .protectedLocalOnly
        )
        day.media.append(media)
        day.blocks.append(.init(dayID: day.id, kind: .audio, text: transcription, mediaID: media.id, ordinal: day.blocks.count))
        day.updatedAt = Date()
        await save(day)
    }

    func toggleStar(_ dayValue: LifeBoardJournalDayValue) async {
        var day = dayValue
        day.isStarred.toggle()
        day.updatedAt = Date()
        await save(day)
    }

    func delete(_ day: LifeBoardJournalDayValue) async {
        do {
            for media in day.media where media.kind == .audio {
                if let path = media.relativePath { try? LifeBoardJournalAudioFiles.delete(relativePath: path) }
            }
            try await repository.deleteJournalDay(id: day.id)
            await LifeBoardJournalSpotlightIndexer.remove(dayID: day.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func save(_ day: LifeBoardJournalDayValue) async {
        do {
            try await repository.saveJournalDay(day)
            await LifeBoardJournalSpotlightIndexer.index(day)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    var insights: LifeBoardJournalInsightSnapshot {
        LifeBoardJournalInsightEngine.makeSnapshot(days: days)
    }
}

struct LifeBoardJournalModuleView: View {
    @State private var store: LifeBoardJournalStore
    @State private var showsTextComposer = false
    @State private var showsMood = false
    @State private var mood: LifeBoardJournalMood = .none
    @State private var photoSelection: PhotosPickerItem?
    @State private var showsRecorder = false
    @State private var showsVoiceSearch = false
    @Environment(LifeBoardPresentationPreferences.self) private var preferences

    init(repository: any LifeBoardPhaseIIRepository) {
        _store = State(initialValue: LifeBoardJournalStore(repository: repository))
    }

    var body: some View {
        let palette = LifeBoardDaypartTokens.palette(for: preferences.resolvedDaypart())
        VStack(spacing: 0) {
            Picker("Journal section", selection: $store.section) {
                ForEach(LifeBoardJournalStore.Section.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            switch store.section {
            case .today: today(palette: palette)
            case .library: library(palette: palette)
            case .insights: insights(palette: palette)
            }
        }
        .task { await store.load() }
        .onChange(of: store.searchText) { _, _ in Task { await store.load() } }
        .onChange(of: store.starredOnly) { _, _ in Task { await store.load() } }
        .onChange(of: store.moodFilter) { _, _ in Task { await store.load() } }
        .onChange(of: photoSelection) { _, item in
            Task {
                if let data = try? await item?.loadTransferable(type: Data.self) { await store.appendPhoto(data) }
                photoSelection = nil
            }
        }
        .sheet(isPresented: $showsTextComposer) {
            LifeBoardJournalTextComposer(prompt: currentPrompt) { text in Task { await store.appendText(text, promptID: currentPrompt.id) } }
        }
        .sheet(isPresented: $showsMood) {
            LifeBoardJournalMoodDialSheet(selectedMood: $mood) { energy in Task { await store.appendMood(mood, energy: energy) } }
        }
        .sheet(isPresented: $showsRecorder) {
            LifeBoardJournalAudioCapture { path, duration, transcription in
                Task { await store.appendAudio(relativePath: path, duration: duration, transcription: transcription) }
            }
        }
        .sheet(isPresented: $showsVoiceSearch) {
            LifeBoardJournalAudioCapture(purpose: .search) { path, _, transcription in
                defer { try? LifeBoardJournalAudioFiles.delete(relativePath: path) }
                if let transcription = transcription?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !transcription.isEmpty {
                    store.searchText = transcription
                }
            }
        }
        .alert("Journal is unavailable", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(store.errorMessage ?? "") }
    }

    private var currentPrompt: LifeBoardJournalPrompt {
        .contextual(daypart: preferences.resolvedDaypart(), hasEntry: store.today?.blocks.isEmpty == false)
    }

    private func today(palette: LifeBoardDaypartPalette) -> some View {
        ScrollView {
            VStack(spacing: 18) {
                journalHero(palette: palette)
                captureActions(palette: palette)
                if let today = store.today, !today.blocks.isEmpty {
                    LifeBoardJournalDayCard(day: today, palette: palette, onStar: { Task { await store.toggleStar(today) } }, onDelete: nil)
                } else {
                    Text("Your day stays private until you choose to add something.")
                        .font(.subheadline)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .padding(.top, 8)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    private func journalHero(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    Text(currentPrompt.title)
                        .font(.title2.weight(.semibold))
                }
                Spacer()
                if let mood = store.today?.latestMood, mood != .none {
                    Image(mood.largeAssetName).resizable().scaledToFit().frame(width: 72, height: 72)
                        .accessibilityLabel("\(mood.title) mood")
                }
            }
            Text(currentPrompt.supportiveCopy)
                .font(.body)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
            Button { showsTextComposer = true } label: {
                Text(store.today == nil ? "Start with a sentence" : "Add another thought")
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationSurfaceSolid))
            }
                .buttonStyle(.borderedProminent)
                .tint(palette.color(for: .foreground))
        }
        .padding(20)
        .lifeBoardPaperCard()
    }

    private func captureActions(palette: LifeBoardDaypartPalette) -> some View {
        HStack(spacing: 10) {
            captureAction("Mood", symbol: "face.smiling") { showsMood = true }
            captureAction("Voice", symbol: "waveform") { showsRecorder = true }
            PhotosPicker(selection: $photoSelection, matching: .images) {
                Label("Photo", systemImage: "photo").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.bordered)
            .tint(palette.color(for: .foreground))
        }
    }

    private func captureAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: symbol).frame(maxWidth: .infinity, minHeight: 44) }
            .buttonStyle(.bordered)
    }

    private func library(palette: LifeBoardDaypartPalette) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                HStack {
                    TextField("Search your journal", text: $store.searchText)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Search journal")
                    Button { showsVoiceSearch = true } label: {
                        Image(systemName: "mic.circle").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Search journal by voice")
                    Menu {
                        Toggle("Starred only", isOn: $store.starredOnly)
                        Button("All moods") { store.moodFilter = nil }
                        ForEach(LifeBoardJournalMood.allCases.filter { $0 != .none }) { mood in
                            Button(mood.title) { store.moodFilter = mood }
                        }
                    } label: { Image(systemName: "line.3.horizontal.decrease.circle").frame(width: 44, height: 44) }
                    .accessibilityLabel("Journal filters")
                }
                if store.days.isEmpty {
                    ContentUnavailableView("No entries found", systemImage: "book.closed", description: Text("Try another search or add a thought today."))
                        .padding(.top, 40)
                } else {
                    ForEach(store.days) { day in
                        LifeBoardJournalDayCard(
                            day: day,
                            palette: palette,
                            onStar: { Task { await store.toggleStar(day) } },
                            onDelete: { Task { await store.delete(day) } }
                        )
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    private func insights(palette: LifeBoardDaypartPalette) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                let snapshot = store.insights
                HStack(spacing: 12) {
                    insightTile("Days", value: "\(snapshot.daysWritten)", symbol: "calendar", palette: palette)
                    insightTile("Streak", value: "\(snapshot.currentStreak)", symbol: "flame", palette: palette)
                    insightTile("Words", value: "\(snapshot.totalWords)", symbol: "text.word.spacing", palette: palette)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Weekly reflection").font(.title3.weight(.semibold))
                    Text(reflectionText(snapshot))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    if !snapshot.evidenceDayIDs.isEmpty {
                        Text("Based on \(snapshot.evidenceDayIDs.count) journal days")
                            .font(.caption)
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .lifeBoardPaperCard()
                Text("Insights are deterministic and evidence-linked. Eva can interpret them on device when its local model is available.")
                    .font(.caption)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            .padding(20)
        }
    }

    private func insightTile(_ title: String, value: String, symbol: String, palette: LifeBoardDaypartPalette) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
            Text(value).font(.title2.weight(.semibold))
            Text(title).font(.caption).foregroundStyle(palette.color(for: .foregroundSecondary))
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .lifeBoardPaperCard()
    }

    private func reflectionText(_ snapshot: LifeBoardJournalInsightSnapshot) -> String {
        guard snapshot.daysWritten > 0 else { return "Your first entry will begin a private weekly pattern summary." }
        let mood = snapshot.dominantMood.map { "\($0.title.lowercased()) appeared most often" } ?? "your moods stayed varied"
        let energy = snapshot.averageEnergy.map { "Average energy was \(String(format: "%.1f", $0)) out of 5." } ?? "Energy was not captured often enough to summarize."
        return "This week, \(mood). \(energy) This is a pattern, not a diagnosis."
    }
}

private struct LifeBoardJournalDayCard: View {
    let day: LifeBoardJournalDayValue
    let palette: LifeBoardDaypartPalette
    let onStar: () -> Void
    let onDelete: (() -> Void)?
    @State private var confirmsDelete = false
    @State private var playback = LifeBoardJournalAudioPlaybackController()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(day.day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.headline)
                Spacer()
                Button(action: onStar) { Image(systemName: day.isStarred ? "star.fill" : "star") }
                    .accessibilityLabel(day.isStarred ? "Unstar journal day" : "Star journal day")
                if onDelete != nil {
                    Button(role: .destructive) { confirmsDelete = true } label: { Image(systemName: "trash") }
                        .accessibilityLabel("Delete journal day")
                }
            }
            ForEach(day.blocks) { block in
                HStack(alignment: .top, spacing: 10) {
                    blockIcon(block)
                    VStack(alignment: .leading, spacing: 4) {
                        if let mood = block.mood {
                            Text("Feeling \(mood.title.lowercased())\(block.energy.map { ", energy \($0) of 5" } ?? "")")
                        }
                        if let text = block.text, !text.isEmpty { Text(text).font(.body) }
                        if block.kind == .photo { Text("Photo").foregroundStyle(palette.color(for: .foregroundSecondary)) }
                        if block.kind == .audio, let media = day.media.first(where: { $0.id == block.mediaID }) {
                            Button { playback.toggle(media) } label: {
                                Label(
                                    playback.playingMediaID == media.id ? "Stop recording" : "Play recording",
                                    systemImage: playback.playingMediaID == media.id ? "stop.circle.fill" : "play.circle.fill"
                                )
                            }
                            .buttonStyle(.borderless)
                            .accessibilityHint("This protected recording stays on this device")
                            if let duration = media.duration {
                                Text(Self.duration(duration))
                                    .font(.caption)
                                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                            }
                        } else if block.kind == .audio {
                            Text("Private audio is unavailable on this device")
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                        }
                        Text(block.createdAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                    }
                }
            }
        }
        .padding(18)
        .lifeBoardPaperCard()
        .confirmationDialog("Delete this entire journal day?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete day", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Text, mood, photos, and local audio for this day will be removed.") }
        .onDisappear { playback.stop() }
    }

    @ViewBuilder
    private func blockIcon(_ block: LifeBoardJournalBlockValue) -> some View {
        if let mood = block.mood {
            Image(mood.faceAssetName).resizable().scaledToFit().frame(width: 28, height: 28)
                .accessibilityHidden(true)
        } else {
            Image(systemName: block.kind == .audio ? "waveform" : block.kind == .photo ? "photo" : "text.alignleft")
                .frame(width: 28)
                .accessibilityHidden(true)
        }
    }

    private static func duration(_ interval: TimeInterval) -> String {
        String(format: "%d:%02d", Int(interval) / 60, Int(interval) % 60)
    }
}

@MainActor
@Observable
private final class LifeBoardJournalAudioPlaybackController: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private(set) var playingMediaID: UUID?

    func toggle(_ media: LifeBoardJournalMediaValue) {
        if playingMediaID == media.id {
            stop()
            return
        }
        do {
            stop()
            guard let relativePath = media.relativePath else { return }
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            let player = try AVAudioPlayer(contentsOf: LifeBoardJournalAudioFiles.url(relativePath: relativePath))
            player.delegate = self
            player.prepareToPlay()
            guard player.play() else { return }
            self.player = player
            playingMediaID = media.id
        } catch {
            stop()
        }
    }

    func stop() {
        player?.stop()
        player = nil
        playingMediaID = nil
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.stop() }
    }
}

private struct LifeBoardJournalTextComposer: View {
    let prompt: LifeBoardJournalPrompt
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(prompt.title).font(.title2.weight(.semibold))
                Text(prompt.supportiveCopy).foregroundStyle(.secondary)
                TextEditor(text: $text)
                    .font(.body)
                    .padding(12)
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.separator))
                    .accessibilityLabel("Journal text")
            }
            .padding(20)
            .navigationTitle("Write")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { onSave(text); dismiss() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

@MainActor
@Observable
private final class LifeBoardJournalAudioRecorder: NSObject, AVAudioRecorderDelegate {
    private(set) var isRecording = false
    private(set) var duration: TimeInterval = 0
    private(set) var errorMessage: String?
    private var recorder: AVAudioRecorder?
    private var timer: Timer?
    private var startedAt: Date?

    func start() async {
        let permitted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { continuation.resume(returning: $0) }
        }
        guard permitted else { errorMessage = "Microphone access is unavailable."; return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            let url = try LifeBoardJournalAudioFiles.newRecordingURL()
            let recorder = try AVAudioRecorder(url: url, settings: [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44_100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ])
            recorder.delegate = self
            recorder.record()
            self.recorder = recorder
            startedAt = Date()
            isRecording = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.duration = Date().timeIntervalSince(self?.startedAt ?? Date()) }
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func stop() -> (url: URL, duration: TimeInterval)? {
        guard let recorder else { return nil }
        recorder.stop()
        timer?.invalidate()
        timer = nil
        isRecording = false
        duration = recorder.currentTime
        self.recorder = nil
        try? FileManager.default.setAttributes([.protectionKey: FileProtectionType.complete], ofItemAtPath: recorder.url.path)
        try? AVAudioSession.sharedInstance().setActive(false)
        return (recorder.url, duration)
    }

    func cancel() {
        let url = recorder?.url
        recorder?.stop()
        timer?.invalidate()
        recorder = nil
        isRecording = false
        if let url { try? FileManager.default.removeItem(at: url) }
    }
}

private enum LifeBoardJournalAudioFiles {
    static func newRecordingURL() throws -> URL {
        let root = try directory()
        return root.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
    }

    static func relativePath(for url: URL) -> String { url.lastPathComponent }

    static func url(relativePath: String) throws -> URL { try directory().appendingPathComponent(relativePath) }

    static func delete(relativePath: String) throws { try FileManager.default.removeItem(at: url(relativePath: relativePath)) }

    private static func directory() throws -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let root = base.appendingPathComponent("LifeBoardJournalAudio", isDirectory: true)
        if !FileManager.default.fileExists(atPath: root.path) {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.complete])
        }
        return root
    }
}

@MainActor
private final class LifeBoardJournalSpeechTranscriber {
    private var recognitionTask: SFSpeechRecognitionTask?
    private var continuation: CheckedContinuation<String?, Never>?

    func transcribe(_ url: URL) async -> String? {
        let authorized = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { continuation.resume(returning: $0 == .authorized) }
        }
        guard authorized, let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else { return nil }
        return await withCheckedContinuation { continuation in
            self.continuation = continuation
            let request = SFSpeechURLRecognitionRequest(url: url)
            request.shouldReportPartialResults = false
            recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
                Task { @MainActor in
                    guard let self, self.continuation != nil else { return }
                    if let result, result.isFinal {
                        self.finishTranscription(result.bestTranscription.formattedString)
                    } else if error != nil {
                        self.finishTranscription(nil)
                    }
                }
            }
        }
    }

    private func finishTranscription(_ text: String?) {
        let continuation = continuation
        self.continuation = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        continuation?.resume(returning: text)
    }
}

private struct LifeBoardJournalAudioCapture: View {
    enum Purpose { case journal, search }

    let purpose: Purpose
    let onSave: (String, TimeInterval, String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = LifeBoardJournalAudioRecorder()
    @State private var capturedURL: URL?
    @State private var capturedDuration: TimeInterval = 0
    @State private var transcribes: Bool
    @State private var isTranscribing = false
    @State private var showsConsent = false
    @State private var transcription: String?

    init(purpose: Purpose = .journal, onSave: @escaping (String, TimeInterval, String?) -> Void) {
        self.purpose = purpose
        self.onSave = onSave
        _transcribes = State(initialValue: purpose == .search)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: recorder.isRecording ? "waveform.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 76))
                    .symbolEffect(.pulse, isActive: recorder.isRecording)
                    .accessibilityHidden(true)
                Text(recorder.isRecording ? Self.duration(recorder.duration) : capturedURL == nil ? "Ready when you are" : "Recording ready")
                    .font(.title2.weight(.semibold))
                if let error = recorder.errorMessage { Text(error).foregroundStyle(.red) }
                if isTranscribing { ProgressView("Transcribing…") }
                if let transcription { Text(transcription).padding().background(.background, in: RoundedRectangle(cornerRadius: 14)) }
                if purpose == .journal {
                    Toggle("Transcribe after recording", isOn: Binding(
                        get: { transcribes },
                        set: { enabled in
                            if enabled && !Self.hasSpeechConsent { showsConsent = true }
                            else { transcribes = enabled }
                        }
                    ))
                    .disabled(recorder.isRecording)
                }
                Button {
                    if purpose == .search && !Self.hasSpeechConsent {
                        showsConsent = true
                        return
                    }
                    if recorder.isRecording {
                        if let result = recorder.stop() { capturedURL = result.url; capturedDuration = result.duration }
                    } else {
                        Task { await recorder.start() }
                    }
                } label: {
                    Label(recorder.isRecording ? "Stop recording" : "Start recording", systemImage: recorder.isRecording ? "stop.fill" : "mic.fill")
                        .frame(maxWidth: .infinity, minHeight: 50)
                }
                .buttonStyle(.borderedProminent)
                if capturedURL != nil {
                    Button(purpose == .search ? "Search journal" : "Save audio") { Task { await save() } }
                        .buttonStyle(.bordered)
                        .disabled(isTranscribing)
                }
                Text(purpose == .search
                    ? "The temporary recording is deleted after transcription. Journal content is searched only inside LifeBoard."
                    : "Audio is file-protected and stays on this device. Only its duration and optional transcription sync privately.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(24)
            .navigationTitle(purpose == .search ? "Voice Search" : "Voice Journal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { recorder.cancel(); dismiss() } } }
            .alert("About transcription", isPresented: $showsConsent) {
                Button("Continue") {
                    UserDefaults.standard.set(true, forKey: "lifeboard.journal.speech_consent.v1")
                    transcribes = true
                }
                Button("Not now", role: .cancel) { transcribes = false }
            } message: {
                Text("If you continue, Apple Speech may process this recording according to the system’s speech-recognition availability and privacy settings. You can keep audio without transcription.")
            }
        }
    }

    private func save() async {
        guard let capturedURL else { return }
        isTranscribing = transcribes
        if transcribes { transcription = await LifeBoardJournalSpeechTranscriber().transcribe(capturedURL) }
        isTranscribing = false
        onSave(LifeBoardJournalAudioFiles.relativePath(for: capturedURL), capturedDuration, transcription)
        dismiss()
    }

    private static var hasSpeechConsent: Bool {
        UserDefaults.standard.bool(forKey: "lifeboard.journal.speech_consent.v1")
    }

    private static func duration(_ interval: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(interval) / 60, Int(interval) % 60)
    }
}

enum LifeBoardJournalInsightEngine {
    static func makeSnapshot(days: [LifeBoardJournalDayValue], now: Date = Date(), calendar: Calendar = .current) -> LifeBoardJournalInsightSnapshot {
        let written = days.filter { !$0.blocks.isEmpty }
        guard !written.isEmpty else { return .empty }
        let words = written.reduce(0) { partial, day in
            partial + day.displayText.split(whereSeparator: \.isWhitespace).count
        }
        let moods = written.flatMap(\.blocks).compactMap(\.mood).filter { $0 != .none }
        let dominant = Dictionary(grouping: moods, by: { $0 }).max { $0.value.count < $1.value.count }?.key
        let energies = written.flatMap(\.blocks).compactMap(\.energy)
        let averageEnergy = energies.isEmpty ? nil : Double(energies.reduce(0, +)) / Double(energies.count)
        let daySet = Set(written.map { calendar.startOfDay(for: $0.day) })
        var cursor = calendar.startOfDay(for: now)
        var streak = 0
        while daySet.contains(cursor) {
            streak += 1
            guard let prior = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prior
        }
        return .init(
            daysWritten: written.count,
            currentStreak: streak,
            totalWords: words,
            dominantMood: dominant,
            averageEnergy: averageEnergy,
            evidenceDayIDs: Array(written.prefix(7).map(\.id))
        )
    }
}

enum LifeBoardJournalSpotlightIndexer {
    static func index(_ day: LifeBoardJournalDayValue) async {
        let attributes = CSSearchableItemAttributeSet(contentType: .text)
        attributes.title = "Journal — \(day.day.formatted(date: .abbreviated, time: .omitted))"
        attributes.contentDescription = day.latestMood.map { "Mood: \($0.title)" } ?? "Private journal day"
        attributes.contentCreationDate = day.day
        attributes.keywords = ["journal", "reflection"]
        let item = CSSearchableItem(uniqueIdentifier: "lifeboard-journal-\(day.id.uuidString)", domainIdentifier: "com.lifeboard.private-journal", attributeSet: attributes)
        try? await CSSearchableIndex.default().indexSearchableItems([item])
    }

    static func remove(dayID: UUID) async {
        try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["lifeboard-journal-\(dayID.uuidString)"])
    }
}
