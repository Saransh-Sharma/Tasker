import AVFAudio
import CoreSpotlight
import Foundation
import JournalFoundation
import LocalAuthentication
import JournalSecurityKit
import Observation
import PhotosUI
import Speech
import SwiftUI
import TranscriptionKit
import UIKit
import UniformTypeIdentifiers

// MARK: - Track module

@MainActor
@Observable
final class LifeBoardTrackStore {
    private(set) var trackers: [LifeBoardTrackerDefinitionValue] = []
    private(set) var trackerEntries: [LifeBoardTrackerEntryValue] = []
    private(set) var checkIns: [LifeBoardMoodEnergyCheckInValue] = []
    private(set) var medications: [LifeBoardMedicationDefinitionValue] = []
    private(set) var medicationSchedules: [LifeBoardMedicationScheduleValue] = []
    private(set) var medicationEvents: [LifeBoardMedicationEventValue] = []
    private(set) var fastingSessions: [LifeBoardFastingSessionValue] = []
    private(set) var correctionReceipts: [TrackCorrectionReceipt] = []
    private(set) var isLoading = false
    var errorMessage: String?

    let healthStore: LifeBoardHealthStore
    let repository: any LifeBoardPhaseIIRepository
    private let fastingTimerStore: FastingTimerStore
    private let correctionReceiptRepository: any TrackCorrectionReceiptRepository

    init(
        repository: any LifeBoardPhaseIIRepository,
        healthStore: LifeBoardHealthStore = LifeBoardHealthStore(),
        correctionReceiptRepository: any TrackCorrectionReceiptRepository = LocalTrackCorrectionReceiptRepository.shared
    ) {
        self.repository = repository
        self.healthStore = healthStore
        fastingTimerStore = FastingTimerStore(
            repository: LifeBoardFastingRepositoryAdapter(repository: repository)
        )
        self.correctionReceiptRepository = correctionReceiptRepository
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
            let historyStart = calendar.date(byAdding: .day, value: -29, to: start) ?? start
            async let trackerValues = repository.fetchTrackers()
            async let entryValues = repository.fetchTrackerEntries(trackerID: nil)
            async let moodValues = repository.fetchMoodCheckIns(from: start, to: end)
            async let medicationValues = repository.fetchMedications()
            async let medicationScheduleValues = repository.fetchMedicationSchedules(medicationID: nil)
            async let eventValues = repository.fetchMedicationEvents(from: historyStart, to: end)
            async let fastingValues = fastingTimerStore.sessions(limit: 30)
            async let correctionValues = correctionReceiptRepository.fetchTrackCorrectionReceipts()
            (trackers, trackerEntries, checkIns, medications, medicationSchedules, medicationEvents, fastingSessions, correctionReceipts) = try await (
                trackerValues, entryValues, moodValues, medicationValues, medicationScheduleValues, eventValues, fastingValues, correctionValues
            )
            trackers.removeAll(where: \.isArchived)
            medications.removeAll(where: \.isArchived)
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
            await TrackerReminderCoordinator.shared.synchronize(tracker)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func archiveTracker(_ tracker: LifeBoardTrackerDefinitionValue) async {
        var archived = tracker
        archived.isArchived = true
        archived.updatedAt = Date()
        await saveTracker(archived)
    }

    func deleteTracker(_ tracker: LifeBoardTrackerDefinitionValue) async {
        var archived = tracker
        archived.isArchived = true
        do {
            await TrackerReminderCoordinator.shared.synchronize(archived)
            try await repository.deleteTracker(id: tracker.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func correct(_ entry: LifeBoardTrackerEntryValue, numericValue: Double?, booleanValue: Bool?, note: String?) async {
        var corrected = entry
        corrected.numericValue = numericValue
        corrected.booleanValue = booleanValue
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        corrected.note = trimmedNote.isEmpty ? nil : trimmedNote
        do {
            try await applyCorrection(previous: .tracker(entry), corrected: .tracker(corrected))
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

    func saveMedication(
        _ medication: LifeBoardMedicationDefinitionValue,
        schedule: LifeBoardMedicationScheduleValue
    ) async {
        do {
            try await repository.saveMedication(medication)
            try await repository.saveMedicationSchedule(schedule)
            await MedicationReminderCoordinator.shared.synchronize(medication: medication, schedule: schedule)
            if let scheduledAt = Self.nextScheduledDate(for: schedule, after: Date()) {
                let existing = medicationEvents.first(where: {
                    $0.medicationID == medication.id
                        && $0.status == .scheduled
                        && Calendar.current.isDate($0.scheduledAt, inSameDayAs: scheduledAt)
                })
                try await repository.saveMedicationEvent(.init(
                    id: existing?.id ?? UUID(),
                    medicationID: medication.id,
                    scheduledAt: scheduledAt,
                    status: .scheduled
                ))
            }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func archiveMedication(_ medication: LifeBoardMedicationDefinitionValue) async {
        var value = medication
        value.isArchived = true
        value.updatedAt = Date()
        do {
            try await repository.saveMedication(value)
            if let schedule = medicationSchedules.first(where: { $0.medicationID == medication.id }) {
                await MedicationReminderCoordinator.shared.synchronize(medication: value, schedule: schedule)
            }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteMedication(_ medication: LifeBoardMedicationDefinitionValue) async {
        var archived = medication
        archived.isArchived = true
        do {
            for schedule in medicationSchedules where schedule.medicationID == medication.id {
                await MedicationReminderCoordinator.shared.synchronize(medication: archived, schedule: schedule)
            }
            try await repository.deleteMedication(id: medication.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func resolveMedication(_ medication: LifeBoardMedicationDefinitionValue, status: LifeBoardMedicationEventStatus) async {
        let existing = medicationEvents.first(where: {
            $0.medicationID == medication.id
                && Calendar.current.isDateInToday($0.scheduledAt)
                && $0.status == .scheduled
        })
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

    func correctMedicationEvent(
        _ event: LifeBoardMedicationEventValue,
        status: LifeBoardMedicationEventStatus,
        scheduledAt: Date,
        resolvedAt: Date?,
        note: String?
    ) async {
        var corrected = event
        corrected.status = status
        corrected.scheduledAt = scheduledAt
        corrected.resolvedAt = status == .scheduled || status == .unresolved ? nil : (resolvedAt ?? Date())
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        corrected.note = trimmed.isEmpty ? nil : trimmed
        do {
            try await applyCorrection(previous: .medication(event), corrected: .medication(corrected))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func toggleFast(target: TimeInterval?, reminderOffsets: [TimeInterval] = []) async {
        do {
            if activeFast != nil {
                try await fastingTimerStore.finish()
            } else {
                try await fastingTimerStore.start(
                    targetDuration: target,
                    reminderOffsets: reminderOffsets
                )
            }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func cancelFast() async {
        do {
            try await fastingTimerStore.cancel()
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func correctFast(_ session: LifeBoardFastingSessionValue, startDelta: TimeInterval = 0, endDelta: TimeInterval = 0) async {
        var value = session
        value.startedAt = session.startedAt.addingTimeInterval(startDelta)
        if let endedAt = session.endedAt { value.endedAt = endedAt.addingTimeInterval(endDelta) }
        value.completionKind = .corrected
        value.updatedAt = Date()
        guard value.endedAt.map({ $0 > value.startedAt }) ?? true else {
            errorMessage = "A fasting session must end after it starts."
            return
        }
        do {
            try await applyCorrection(previous: .fasting(session), corrected: .fasting(value))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func activeCorrection(domain: TrackCorrectionDomain, sourceID: UUID) -> TrackCorrectionReceipt? {
        correctionReceipts
            .filter { $0.domain == domain && $0.sourceID == sourceID && $0.isReversed == false }
            .max { lhs, rhs in lhs.appliedAt < rhs.appliedAt }
    }

    func undoCorrection(_ receipt: TrackCorrectionReceipt) async {
        do {
            guard activeCorrection(domain: receipt.domain, sourceID: receipt.sourceID)?.id == receipt.id else {
                throw TrackCorrectionReceiptFailure.staleReceipt
            }
            try await saveCorrectionPayload(receipt.previous)
            var reversed = receipt
            reversed.reversedAt = Date()
            do {
                try await correctionReceiptRepository.saveTrackCorrectionReceipt(reversed)
            } catch {
                try? await saveCorrectionPayload(receipt.corrected)
                throw error
            }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    private func applyCorrection(previous: TrackCorrectionPayload, corrected: TrackCorrectionPayload) async throws {
        guard previous != corrected else { return }
        let receipt = try TrackCorrectionReceipt.deterministic(previous: previous, corrected: corrected)
        try await saveCorrectionPayload(corrected)
        do {
            try await correctionReceiptRepository.saveTrackCorrectionReceipt(receipt)
        } catch {
            try? await saveCorrectionPayload(previous)
            throw error
        }
    }

    private func saveCorrectionPayload(_ payload: TrackCorrectionPayload) async throws {
        switch payload {
        case .tracker(let value): try await repository.saveTrackerEntry(value)
        case .mood(let value): try await repository.saveMoodCheckIn(value)
        case .medication(let value): try await repository.saveMedicationEvent(value)
        case .fasting(let value): try await repository.saveFastingSession(value)
        case .hydration, .sleep: throw TrackCorrectionReceiptFailure.mismatchedPayload
        }
    }

    private static func nextScheduledDate(
        for schedule: LifeBoardMedicationScheduleValue,
        after date: Date,
        calendar: Calendar = .current
    ) -> Date? {
        let start = calendar.startOfDay(for: date)
        for offset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  schedule.weekdays.contains(calendar.component(.weekday, from: day)),
                  let candidate = calendar.date(byAdding: .minute, value: schedule.windowStartMinutes, to: day),
                  candidate >= date else { continue }
            return candidate
        }
        return nil
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
    @State private var editingTracker: LifeBoardTrackerDefinitionValue?
    @State private var historyTracker: LifeBoardTrackerDefinitionValue?
    @State private var showsMedicationComposer = false
    @State private var editingMedication: LifeBoardMedicationDefinitionValue?
    @State private var historyMedication: LifeBoardMedicationDefinitionValue?
    @State private var deletingTracker: LifeBoardTrackerDefinitionValue?
    @State private var deletingMedication: LifeBoardMedicationDefinitionValue?
    @State private var showsFastingComposer = false
    @State private var reviewsFastCompletion = false
    @State private var showsFastingHistory = false
    private let onOpenHabitBoard: () -> Void
    @Environment(LifeBoardPresentationPreferences.self) private var preferences

    init(
        repository: any LifeBoardPhaseIIRepository,
        initialModule: Module = .overview,
        onOpenHabitBoard: @escaping () -> Void = {}
    ) {
        _store = State(initialValue: LifeBoardTrackStore(repository: repository))
        _module = State(initialValue: initialModule)
        self.onOpenHabitBoard = onOpenHabitBoard
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
        .sheet(isPresented: $showsTrackerComposer, onDismiss: { editingTracker = nil }) {
            LifeBoardTrackerComposer(existing: editingTracker) { tracker in Task { await store.saveTracker(tracker) } }
        }
        .sheet(item: $historyTracker) { tracker in
            LifeBoardTrackerHistoryView(
                tracker: tracker,
                entries: store.trackerEntries.filter { $0.trackerID == tracker.id },
                activeReceipt: { store.activeCorrection(domain: .tracker, sourceID: $0) },
                onUndo: { await store.undoCorrection($0) },
                onCorrect: { entry, numeric, boolean, note in
                    await store.correct(entry, numericValue: numeric, booleanValue: boolean, note: note)
                }
            )
        }
        .sheet(isPresented: $showsMedicationComposer, onDismiss: { editingMedication = nil }) {
            LifeBoardMedicationComposer(
                existing: editingMedication,
                existingSchedule: editingMedication.flatMap { medication in
                    store.medicationSchedules.first(where: { $0.medicationID == medication.id })
                }
            ) { medication, schedule in
                Task { await store.saveMedication(medication, schedule: schedule) }
            }
        }
        .sheet(item: $historyMedication) { medication in
            LifeBoardMedicationHistoryView(
                medication: medication,
                events: store.medicationEvents.filter { $0.medicationID == medication.id },
                activeReceipt: { store.activeCorrection(domain: .medication, sourceID: $0) },
                onUndo: { await store.undoCorrection($0) },
                onCorrect: { event, status, scheduledAt, resolvedAt, note in
                    await store.correctMedicationEvent(
                        event,
                        status: status,
                        scheduledAt: scheduledAt,
                        resolvedAt: resolvedAt,
                        note: note
                    )
                }
            )
        }
        .sheet(isPresented: $showsFastingComposer) {
            LifeBoardFastingComposer { target, reminderOffsets in
                Task { await store.toggleFast(target: target, reminderOffsets: reminderOffsets) }
            }
        }
        .sheet(isPresented: $showsFastingHistory) {
            LifeBoardFastingHistoryView(
                sessions: store.fastingSessions,
                activeReceipt: { store.activeCorrection(domain: .fasting, sourceID: $0) },
                onUndo: { await store.undoCorrection($0) },
                onCorrect: { session, startDelta, endDelta in
                    await store.correctFast(session, startDelta: startDelta, endDelta: endDelta)
                }
            )
        }
        .confirmationDialog(
            "Finish this fasting timer?",
            isPresented: $reviewsFastCompletion,
            titleVisibility: .visible
        ) {
            Button("Finish and keep in history") {
                Task { await store.toggleFast(target: nil) }
            }
            Button("Cancel session", role: .destructive) {
                Task { await store.cancelFast() }
            }
            Button("Keep timer running", role: .cancel) {}
        } message: {
            Text("Finishing records the elapsed time. Cancelling keeps the session in history and marks it as cancelled. Neither action changes your target preferences.")
        }
        .confirmationDialog(
            "Delete tracker and its history?",
            isPresented: Binding(get: { deletingTracker != nil }, set: { if !$0 { deletingTracker = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete tracker", role: .destructive) {
                guard let tracker = deletingTracker else { return }
                deletingTracker = nil
                Task { await store.deleteTracker(tracker) }
            }
            Button("Cancel", role: .cancel) { deletingTracker = nil }
        } message: {
            Text("This permanently removes the definition and all recorded entries. Archive it if you may need the history later.")
        }
        .confirmationDialog(
            "Delete medication and its history?",
            isPresented: Binding(get: { deletingMedication != nil }, set: { if !$0 { deletingMedication = nil } }),
            titleVisibility: .visible
        ) {
            Button("Delete medication", role: .destructive) {
                guard let medication = deletingMedication else { return }
                deletingMedication = nil
                Task { await store.deleteMedication(medication) }
            }
            Button("Cancel", role: .cancel) { deletingMedication = nil }
        } message: {
            Text("This permanently removes its schedule and recorded event history. Archive it if you may need that record later.")
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
                            Divider()
                            Button("History", systemImage: "clock.arrow.circlepath") { historyMedication = medication }
                            Button("Edit", systemImage: "pencil") {
                                editingMedication = medication
                                showsMedicationComposer = true
                            }
                            Button("Archive medication", systemImage: "archivebox", role: .destructive) {
                                Task { await store.archiveMedication(medication) }
                            }
                            Button("Delete medication", systemImage: "trash", role: .destructive) {
                                deletingMedication = medication
                            }
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
        VStack(alignment: .leading, spacing: 14) {
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
                    if store.activeFast == nil { showsFastingComposer = true }
                    else { reviewsFastCompletion = true }
                } label: {
                    Text(store.activeFast == nil ? "Start" : "End")
                        .foregroundStyle(Color(LifeBoardColorTokens.foundationSurfaceSolid))
                }
                .buttonStyle(.borderedProminent)
                .tint(palette.color(for: .foreground))
            }
            if store.fastingSessions.contains(where: { $0.endedAt != nil }) {
                Button {
                    showsFastingHistory = true
                } label: {
                    Label("Full history", systemImage: "clock.arrow.circlepath")
                        .font(.caption.weight(.semibold))
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows every recorded fasting session with its outcome")
            }
            ForEach(store.fastingSessions.filter { $0.endedAt != nil }.prefix(3)) { session in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(session.startedAt.formatted(date: .abbreviated, time: .shortened)).font(.subheadline.weight(.medium))
                        Text(Self.duration(session.elapsed())).font(.caption).foregroundStyle(palette.color(for: .foregroundSecondary))
                    }
                    Spacer()
                    Menu {
                        Button("Start 15 minutes earlier") { Task { await store.correctFast(session, startDelta: -15 * 60) } }
                        Button("Start 15 minutes later") { Task { await store.correctFast(session, startDelta: 15 * 60) } }
                        Button("End 15 minutes earlier") { Task { await store.correctFast(session, endDelta: -15 * 60) } }
                        Button("End 15 minutes later") { Task { await store.correctFast(session, endDelta: 15 * 60) } }
                        if let receipt = store.activeCorrection(domain: .fasting, sourceID: session.id) {
                            Button("Undo last correction", systemImage: "arrow.uturn.backward") {
                                Task { await store.undoCorrection(receipt) }
                            }
                        }
                    } label: { Image(systemName: "ellipsis.circle") }
                    .accessibilityLabel("Correct fasting session")
                }
                .padding(.top, 6)
            }
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
            Menu {
                Button("History", systemImage: "clock.arrow.circlepath") { historyTracker = tracker }
                Button("Edit", systemImage: "pencil") {
                    editingTracker = tracker
                    showsTrackerComposer = true
                }
                Button("Archive", systemImage: "archivebox", role: .destructive) {
                    Task { await store.archiveTracker(tracker) }
                }
                Button("Delete", systemImage: "trash", role: .destructive) {
                    deletingTracker = tracker
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 44, height: 44)
            }
            .accessibilityLabel("More actions for \(tracker.title)")
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
                onOpenHabitBoard()
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

struct LifeBoardTrackerComposer: View {
    let onSave: (LifeBoardTrackerDefinitionValue) -> Void
    private let existing: LifeBoardTrackerDefinitionValue?
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var kind: LifeBoardTrackerKind = .boolean
    @State private var unit = ""
    @State private var target = 1.0
    @State private var weekdays = Set(1...7)
    @State private var reminderEnabled = false
    @State private var reminderTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()

    init(existing: LifeBoardTrackerDefinitionValue? = nil, onSave: @escaping (LifeBoardTrackerDefinitionValue) -> Void) {
        self.existing = existing
        self.onSave = onSave
        _title = State(initialValue: existing?.title ?? "")
        _kind = State(initialValue: existing?.kind ?? .boolean)
        _unit = State(initialValue: existing?.unitLabel ?? "")
        _target = State(initialValue: existing?.targetValue ?? 1)
        _weekdays = State(initialValue: existing?.schedule ?? Set(1...7))
        let minutes = existing?.reminderMinutes
        _reminderEnabled = State(initialValue: minutes != nil)
        if let minutes {
            _reminderTime = State(initialValue: Calendar.current.date(
                bySettingHour: minutes / 60,
                minute: minutes % 60,
                second: 0,
                of: Date()
            ) ?? Date())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("Tracker name", text: $title)
                Picker("Kind", selection: $kind) {
                    ForEach(LifeBoardTrackerKind.allCases, id: \.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                if kind == .quantity { TextField("Unit", text: $unit) }
                if kind != .boolean { Stepper("Daily target: \(target, format: .number)", value: $target, in: 1...10_000) }
                Section("Schedule") {
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
                    Toggle("Reminder", isOn: $reminderEnabled)
                    if reminderEnabled { DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute) }
                }
            }
            .navigationTitle(existing == nil ? "New Tracker" : "Edit Tracker")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let calendar = Calendar.current
                        let reminderMinutes = reminderEnabled
                            ? calendar.component(.hour, from: reminderTime) * 60 + calendar.component(.minute, from: reminderTime)
                            : nil
                        onSave(.init(
                            id: existing?.id ?? UUID(),
                            title: title,
                            kind: kind,
                            unitLabel: unit.isEmpty ? nil : unit,
                            targetValue: kind == .boolean ? nil : target,
                            schedule: weekdays,
                            reminderMinutes: reminderMinutes,
                            isArchived: existing?.isArchived ?? false,
                            createdAt: existing?.createdAt ?? Date(),
                            updatedAt: Date()
                        ))
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || weekdays.isEmpty)
                }
            }
        }
    }
}

private struct LifeBoardTrackerHistoryView: View {
    let tracker: LifeBoardTrackerDefinitionValue
    let entries: [LifeBoardTrackerEntryValue]
    let activeReceipt: (UUID) -> TrackCorrectionReceipt?
    let onUndo: (TrackCorrectionReceipt) async -> Void
    let onCorrect: (LifeBoardTrackerEntryValue, Double?, Bool?, String?) async -> Void
    @State private var correcting: LifeBoardTrackerEntryValue?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView("No entries yet", systemImage: "chart.xyaxis.line")
                } else {
                    List(entries.sorted(by: { $0.timestamp > $1.timestamp }).prefix(30)) { entry in
                        Button { correcting = entry } label: {
                            HStack {
                                Text(value(entry))
                                Spacer()
                                Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(minHeight: 44)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if let receipt = activeReceipt(entry.id) {
                                Button("Undo", systemImage: "arrow.uturn.backward") {
                                    Task { await onUndo(receipt) }
                                }
                                .tint(Color(LifeBoardColorTokens.foundationSageAccent))
                            }
                        }
                    }
                }
            }
            .navigationTitle(tracker.title)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $correcting) { entry in
                LifeBoardTrackerCorrectionView(tracker: tracker, entry: entry) { numeric, boolean, note in
                    await onCorrect(entry, numeric, boolean, note)
                    correcting = nil
                }
            }
        }
    }

    private func value(_ entry: LifeBoardTrackerEntryValue) -> String {
        if let number = entry.numericValue { return [number.formatted(), tracker.unitLabel].compactMap { $0 }.joined(separator: " ") }
        if let boolean = entry.booleanValue { return boolean ? "Done" : "Not done" }
        return "Recorded"
    }
}

private struct LifeBoardTrackerCorrectionView: View {
    let tracker: LifeBoardTrackerDefinitionValue
    let entry: LifeBoardTrackerEntryValue
    let onSave: (Double?, Bool?, String?) async -> Void
    @State private var numericValue: Double
    @State private var booleanValue: Bool
    @State private var note: String
    @Environment(\.dismiss) private var dismiss

    init(
        tracker: LifeBoardTrackerDefinitionValue,
        entry: LifeBoardTrackerEntryValue,
        onSave: @escaping (Double?, Bool?, String?) async -> Void
    ) {
        self.tracker = tracker
        self.entry = entry
        self.onSave = onSave
        _numericValue = State(initialValue: entry.numericValue ?? 0)
        _booleanValue = State(initialValue: entry.booleanValue ?? false)
        _note = State(initialValue: entry.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if tracker.kind == .boolean {
                    Toggle("Completed", isOn: $booleanValue)
                } else {
                    TextField("Value", value: $numericValue, format: .number)
                        .keyboardType(.decimalPad)
                }
                TextField("Correction note", text: $note, axis: .vertical)
                LabeledContent("Recorded", value: entry.timestamp.formatted(date: .abbreviated, time: .shortened))
            }
            .navigationTitle("Correct entry")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await onSave(tracker.kind == .boolean ? nil : numericValue, tracker.kind == .boolean ? booleanValue : nil, note)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

private struct LifeBoardMedicationComposer: View {
    let onSave: (LifeBoardMedicationDefinitionValue, LifeBoardMedicationScheduleValue) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var dosage = ""
    @State private var instructions = ""
    @State private var windowStart = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var windowEnd = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var weekdays = Set(1...7)
    @State private var reminderEnabled = true
    private let existing: LifeBoardMedicationDefinitionValue?
    private let existingSchedule: LifeBoardMedicationScheduleValue?

    init(
        existing: LifeBoardMedicationDefinitionValue? = nil,
        existingSchedule: LifeBoardMedicationScheduleValue? = nil,
        onSave: @escaping (LifeBoardMedicationDefinitionValue, LifeBoardMedicationScheduleValue) -> Void
    ) {
        self.existing = existing
        self.existingSchedule = existingSchedule
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _dosage = State(initialValue: existing?.dosageText ?? "")
        _instructions = State(initialValue: existing?.instructions ?? "")
        let startMinutes = existingSchedule?.windowStartMinutes ?? 8 * 60
        let endMinutes = existingSchedule?.windowEndMinutes ?? 9 * 60
        _windowStart = State(initialValue: Calendar.current.date(
            bySettingHour: startMinutes / 60, minute: startMinutes % 60, second: 0, of: Date()
        ) ?? Date())
        _windowEnd = State(initialValue: Calendar.current.date(
            bySettingHour: endMinutes / 60, minute: endMinutes % 60, second: 0, of: Date()
        ) ?? Date())
        _weekdays = State(initialValue: existingSchedule?.weekdays ?? Set(1...7))
        _reminderEnabled = State(initialValue: existingSchedule?.reminderEnabled ?? true)
    }

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
                Section("Schedule") {
                    DatePicker("Window starts", selection: $windowStart, displayedComponents: .hourAndMinute)
                    DatePicker("Window ends", selection: $windowEnd, displayedComponents: .hourAndMinute)
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
                    Toggle("Reminder enabled", isOn: $reminderEnabled)
                }
            }
            .navigationTitle(existing == nil ? "Add Medication" : "Edit Medication")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let medication = LifeBoardMedicationDefinitionValue(
                            id: existing?.id ?? UUID(),
                            name: name,
                            dosageText: dosage.isEmpty ? nil : dosage,
                            instructions: instructions.isEmpty ? nil : instructions,
                            healthCorrelationID: existing?.healthCorrelationID,
                            isArchived: existing?.isArchived ?? false,
                            createdAt: existing?.createdAt ?? Date(),
                            updatedAt: Date()
                        )
                        let calendar = Calendar.current
                        let startMinutes = calendar.component(.hour, from: windowStart) * 60 + calendar.component(.minute, from: windowStart)
                        let endMinutes = calendar.component(.hour, from: windowEnd) * 60 + calendar.component(.minute, from: windowEnd)
                        onSave(medication, .init(
                            id: existingSchedule?.id ?? UUID(),
                            medicationID: medication.id,
                            windowStartMinutes: startMinutes,
                            windowEndMinutes: endMinutes,
                            weekdays: weekdays,
                            reminderEnabled: reminderEnabled
                        ))
                        dismiss()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || weekdays.isEmpty || windowEnd <= windowStart)
                }
            }
        }
    }
}

private struct LifeBoardMedicationHistoryView: View {
    let medication: LifeBoardMedicationDefinitionValue
    let events: [LifeBoardMedicationEventValue]
    let activeReceipt: (UUID) -> TrackCorrectionReceipt?
    let onUndo: (TrackCorrectionReceipt) async -> Void
    let onCorrect: (LifeBoardMedicationEventValue, LifeBoardMedicationEventStatus, Date, Date?, String?) async -> Void
    @State private var correcting: LifeBoardMedicationEventValue?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    ContentUnavailableView("No medication history", systemImage: "pills")
                } else {
                    List(events.sorted(by: { $0.scheduledAt > $1.scheduledAt })) { event in
                        Button { correcting = event } label: {
                            HStack {
                                Label(event.status.rawValue.capitalized, systemImage: statusSymbol(event.status))
                                Spacer()
                                Text(event.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .frame(minHeight: 44)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            if let receipt = activeReceipt(event.id) {
                                Button("Undo", systemImage: "arrow.uturn.backward") {
                                    Task { await onUndo(receipt) }
                                }
                                .tint(Color(LifeBoardColorTokens.foundationSageAccent))
                            }
                        }
                    }
                }
            }
            .navigationTitle(medication.name)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $correcting) { event in
                LifeBoardMedicationCorrectionView(event: event) { status, scheduledAt, resolvedAt, note in
                    await onCorrect(event, status, scheduledAt, resolvedAt, note)
                    correcting = nil
                }
            }
        }
    }

    private func statusSymbol(_ status: LifeBoardMedicationEventStatus) -> String {
        switch status {
        case .taken: "checkmark.circle"
        case .skipped: "forward.end"
        case .snoozed, .rescheduled: "clock.arrow.circlepath"
        case .scheduled: "calendar"
        case .unresolved: "questionmark.circle"
        }
    }
}

private struct LifeBoardMedicationCorrectionView: View {
    let event: LifeBoardMedicationEventValue
    let onSave: (LifeBoardMedicationEventStatus, Date, Date?, String?) async -> Void
    @State private var status: LifeBoardMedicationEventStatus
    @State private var scheduledAt: Date
    @State private var resolvedAt: Date
    @State private var note: String
    @Environment(\.dismiss) private var dismiss

    init(
        event: LifeBoardMedicationEventValue,
        onSave: @escaping (LifeBoardMedicationEventStatus, Date, Date?, String?) async -> Void
    ) {
        self.event = event
        self.onSave = onSave
        _status = State(initialValue: event.status)
        _scheduledAt = State(initialValue: event.scheduledAt)
        _resolvedAt = State(initialValue: event.resolvedAt ?? Date())
        _note = State(initialValue: event.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("Status", selection: $status) {
                    ForEach(LifeBoardMedicationEventStatus.allCases, id: \.self) { value in
                        Text(value.rawValue.capitalized).tag(value)
                    }
                }
                DatePicker("Scheduled", selection: $scheduledAt)
                if status != .scheduled && status != .unresolved { DatePicker("Resolved", selection: $resolvedAt) }
                TextField("Correction note", text: $note, axis: .vertical)
            }
            .navigationTitle("Correct status")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            await onSave(status, scheduledAt, resolvedAt, note)
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

private struct LifeBoardFastingComposer: View {
    let onStart: (TimeInterval?, [TimeInterval]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var usesTarget = false
    @State private var targetHours = 12.0
    @State private var reminderEnabled = false

    var body: some View {
        NavigationStack {
            Form {
                Toggle("Use my own target", isOn: $usesTarget)
                if usesTarget {
                    Stepper("Target: \(Int(targetHours)) hours", value: $targetHours, in: 1...48)
                    Toggle("Remind one hour before target", isOn: $reminderEnabled)
                }
                Text("LifeBoard provides a neutral timer only. It does not recommend a protocol or make metabolic claims.")
                    .font(.caption)
            }
            .navigationTitle("Start fasting timer")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        let target = usesTarget ? targetHours * 3_600 : nil
                        let reminders = usesTarget && reminderEnabled ? [max(0, targetHours * 3_600 - 3_600)] : []
                        onStart(target, reminders)
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Complete fasting history with the recorded meaning of every session —
/// planned, early, cancelled, or corrected — plus the same 15-minute
/// correction and undo affordances the inline card offers.
private struct LifeBoardFastingHistoryView: View {
    let sessions: [LifeBoardFastingSessionValue]
    let activeReceipt: (UUID) -> TrackCorrectionReceipt?
    let onUndo: (TrackCorrectionReceipt) async -> Void
    let onCorrect: (LifeBoardFastingSessionValue, TimeInterval, TimeInterval) async -> Void
    @Environment(\.dismiss) private var dismiss

    private var finished: [LifeBoardFastingSessionValue] {
        sessions.filter { $0.endedAt != nil }.sorted { $0.startedAt > $1.startedAt }
    }

    var body: some View {
        NavigationStack {
            List {
                if finished.isEmpty {
                    ContentUnavailableView(
                        "No finished sessions",
                        systemImage: "timer",
                        description: Text("Sessions you finish or cancel appear here with their outcome.")
                    )
                } else {
                    ForEach(finished) { session in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Text(meaningTitle(session.completionKind))
                                    .font(.caption.weight(.semibold))
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 4)
                                    .background(Color(LifeBoardColorTokens.foundationSurfaceSelected), in: Capsule())
                            }
                            HStack {
                                Text(durationText(session))
                                    .font(.caption)
                                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                                    .monospacedDigit()
                                Spacer()
                                Menu {
                                    Button("Start 15 minutes earlier") { Task { await onCorrect(session, -15 * 60, 0) } }
                                    Button("Start 15 minutes later") { Task { await onCorrect(session, 15 * 60, 0) } }
                                    Button("End 15 minutes earlier") { Task { await onCorrect(session, 0, -15 * 60) } }
                                    Button("End 15 minutes later") { Task { await onCorrect(session, 0, 15 * 60) } }
                                    if let receipt = activeReceipt(session.id) {
                                        Button("Undo last correction", systemImage: "arrow.uturn.backward") {
                                            Task { await onUndo(receipt) }
                                        }
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle").frame(width: 44, height: 44)
                                }
                                .accessibilityLabel("Correct this session")
                            }
                            if let note = session.note, note.isEmpty == false {
                                Text(note).font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .navigationTitle("Fasting history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func meaningTitle(_ kind: LifeBoardFastingCompletionKind?) -> String {
        switch kind {
        case .planned: "Completed"
        case .early: "Ended early"
        case .cancelled: "Cancelled"
        case .corrected: "Corrected"
        case nil: "Recorded"
        }
    }

    private func durationText(_ session: LifeBoardFastingSessionValue) -> String {
        let elapsed = session.elapsed()
        let minutes = max(0, Int(elapsed / 60))
        let elapsedText = minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
        if let target = session.targetDuration {
            return "\(elapsedText) of a \(Int(target / 3_600))h target"
        }
        return elapsedText
    }
}

// MARK: - Journal module

@MainActor
private protocol JournalLockAuthenticating {
    func authenticate(reason: String) async throws
}

@MainActor
private struct SystemJournalLockAuthenticator: JournalLockAuthenticating {
    func authenticate(reason: String) async throws {
        guard await BiometricAppLock().authenticate(reason: reason) else {
            throw LAError(.authenticationFailed)
        }
    }
}

@MainActor
@Observable
private final class JournalPrivacyController {
    private(set) var state: JournalPrivacyGateState
    var policy: JournalPrivacyPolicy {
        didSet {
            do { try JournalPrivacyPolicyPersistence.save(policy, to: defaults) }
            catch { state = .recoveryRequired("Privacy preferences could not be saved.") }
        }
    }

    private let defaults: UserDefaults
    private let authenticator: any JournalLockAuthenticating

    init(
        defaults: UserDefaults = UserDefaults(suiteName: AppGroupConstants.suiteName) ?? .standard,
        authenticator: any JournalLockAuthenticating = SystemJournalLockAuthenticator(),
        initiallyUnlocked: Bool = false
    ) {
        self.defaults = defaults
        self.authenticator = authenticator
        let policy = JournalPrivacyPolicyPersistence.load(from: defaults)
        self.policy = policy
        state = policy.requiresAuthentication && initiallyUnlocked == false ? .locked : .unlocked
    }

    func authenticateIfNeeded() async {
        guard policy.requiresAuthentication, state != .unlocked, state != .authenticating else {
            if policy.requiresAuthentication == false { state = .unlocked }
            return
        }
        state = .authenticating
        do {
            try await authenticator.authenticate(reason: "Unlock your private LifeBoard Journal")
            state = .unlocked
        } catch is CancellationError {
            state = .locked
        } catch {
            let message = (error as? LocalizedError)?.errorDescription
                ?? "Authentication was not completed. Your Journal remains locked."
            state = .recoveryRequired(message)
        }
    }

    func updateAuthenticationRequirement(_ isRequired: Bool) {
        policy.requiresAuthentication = isRequired
        state = isRequired ? .locked : .unlocked
    }

    func lock() {
        if policy.requiresAuthentication { state = .locked }
    }
}

@MainActor
@Observable
final class LifeBoardJournalStore {
    enum Section: String, CaseIterable, Identifiable { case today = "Today", library = "Library", insights = "Insights"; var id: String { rawValue } }

    private(set) var today: LifeBoardJournalDayValue?
    private(set) var days: [LifeBoardJournalDayValue] = []
    private(set) var allDays: [LifeBoardJournalDayValue] = []
    private(set) var draft: LifeBoardJournalDraftValue?
    private(set) var isLoading = false
    private(set) var searchState: JournalSearchState = .idle
    private(set) var reflectionReports: [WeeklyReflectionReport] = []
    private(set) var selectedReflectionID: UUID?
    private(set) var reflectionSourceSelection: Set<UUID> = []
    private(set) var exportPhase: AsyncActionPhase<JournalExportReceipt> = .idle
    private(set) var backupPhase: AsyncActionPhase<JournalBackupReceipt> = .idle
    private(set) var importPhase: AsyncActionPhase<JournalImportReceipt> = .idle
    var section: Section = .today
    var searchText = ""
    var starredOnly = false
    var moodFilter: LifeBoardJournalMood?
    var errorMessage: String?

    let repository: any LifeBoardPhaseIIRepository
    private let derivedIndex: (any JournalDerivedIndexRepository)?
    private let derivedPipeline: JournalDerivedPipelineCoordinator?
    private let reflectionRepository: (any WeeklyReflectionHistoryRepository)?
    private let exportService: (any JournalExporting)?
    private let backupService: (any JournalBackupServicing)?
    private var hasBuiltDerivedIndex = false
    private var reflectionInvalidationTask: Task<Void, Never>?
    private var exportTask: Task<Void, Never>?
    private var lastExportFormat: JournalExportFormat?
    private var lastExportIncludedSensitiveFields = false

    init(
        repository: any LifeBoardPhaseIIRepository,
        derivedIndex: (any JournalDerivedIndexRepository)? = nil,
        derivedPipeline: JournalDerivedPipelineCoordinator? = nil,
        reflectionRepository: (any WeeklyReflectionHistoryRepository)? = nil,
        exportService: (any JournalExporting)? = nil,
        backupService: (any JournalBackupServicing)? = nil,
        initialSection: Section = .today
    ) {
        self.repository = repository
        section = initialSection
        if let derivedIndex {
            self.derivedIndex = derivedIndex
            self.derivedPipeline = derivedPipeline
        } else if V2FeatureFlags.journalParityV1Enabled {
            // Phase V: hybrid semantic + lexical search via SemanticMemoryKit.
            // Local-only sidecar; excluded entries are never ingested.
            let semanticIndex = SemanticJournalDerivedIndexRepository(
                snapshotProvider: { [repository] in
                    try await repository
                        .fetchJournalDays(search: nil, starredOnly: false, mood: nil)
                        .map(JournalEntrySnapshot.init(day:))
                }
            )
            self.derivedIndex = semanticIndex
            self.derivedPipeline = (repository as? CoreDataLifeBoardPhaseIIRepository)?
                .makeJournalDerivedPipeline(
                    derivedIndex: semanticIndex,
                    invalidateReflections: { changed in
                        await JournalProjectionInvalidationHub.shared
                            .broadcast(.reflectionsInvalidated(changed))
                    },
                    invalidateHomeAndEvidence: {
                        await JournalProjectionInvalidationHub.shared
                            .broadcast(.projectionsInvalidated)
                    }
                )
        } else {
            do {
                self.derivedIndex = try LocalJournalDerivedIndexRepository()
                self.derivedPipeline = derivedPipeline
            } catch {
                self.derivedIndex = nil
                self.derivedPipeline = nil
                searchState = .unavailable(error.localizedDescription)
            }
        }
        if let reflectionRepository {
            self.reflectionRepository = reflectionRepository
        } else {
            self.reflectionRepository = try? LocalWeeklyReflectionHistoryRepository()
        }
        if let exportService {
            self.exportService = exportService
        } else {
            self.exportService = try? LocalJournalExportService()
        }
        if let backupService {
            self.backupService = backupService
        } else {
            self.backupService = try? LocalJournalBackupService()
        }
    }

    func load() async {
        observeReflectionInvalidationIfNeeded()
        isLoading = true
        defer { isLoading = false }
        do {
            async let todayValue = repository.fetchJournalDay(containing: Date())
            async let dayValues = repository.fetchJournalDays(search: nil, starredOnly: false, mood: nil)
            async let draftValue = repository.fetchJournalDraft(dayID: nil)
            let (fetchedToday, fetchedDays, fetchedDraft) = try await (todayValue, dayValues, draftValue)
            var repairedDays: [LifeBoardJournalDayValue] = []
            var removedAudioPaths: [String] = []
            for value in fetchedDays {
                let reconciliation = JournalMediaReconciler.reconcile(value)
                if reconciliation.day != value {
                    try await repository.saveJournalDay(reconciliation.day)
                    removedAudioPaths += reconciliation.removedMedia.compactMap { media in
                        media.kind == .audio ? media.relativePath : nil
                    }
                }
                repairedDays.append(reconciliation.day)
            }
            allDays = repairedDays
            today = fetchedToday.flatMap { current in
                repairedDays.first(where: { $0.id == current.id }) ?? JournalMediaReconciler.reconcile(current).day
            }
            draft = fetchedDraft
            for path in removedAudioPaths { try? LifeBoardJournalAudioFiles.delete(relativePath: path) }
            let retainedAudioPaths = Set(
                repairedDays.flatMap(\.media).compactMap { $0.kind == .audio ? $0.relativePath : nil }
                + (fetchedDraft?.audioRelativePaths ?? [])
            )
            try? LifeBoardJournalAudioFiles.deleteOrphans(retaining: retainedAudioPaths)
            applyVisibleDays()
            if !hasBuiltDerivedIndex { await rebuildDerivedIndex() }
        } catch { errorMessage = error.localizedDescription }
    }

    var selectedReflection: WeeklyReflectionReport? {
        if let selectedReflectionID,
           let selected = reflectionReports.first(where: { $0.id == selectedReflectionID }) {
            return selected
        }
        return reflectionReports.first
    }

    /// Reflection reports derive from journal entries. When the derived
    /// pipeline invalidates entries that feed loaded reports, refresh them so
    /// stale summaries never linger behind an edited or deleted entry.
    private func observeReflectionInvalidationIfNeeded() {
        guard reflectionInvalidationTask == nil else { return }
        reflectionInvalidationTask = Task { [weak self] in
            let updates = await JournalProjectionInvalidationHub.shared.updates()
            for await event in updates {
                guard case .reflectionsInvalidated = event else { continue }
                guard let self else { return }
                guard self.reflectionReports.isEmpty == false else { continue }
                await self.loadReflections(weekContaining: Date())
            }
        }
    }

    func loadReflections(weekContaining date: Date) async {
        guard let reflectionRepository else {
            errorMessage = "Weekly reflection history is unavailable on this device."
            return
        }
        do {
            let reports = try await reflectionRepository.reports(weekContaining: date)
            reflectionReports = reports
            selectedReflectionID = reports.first?.id
            reflectionSourceSelection = reports.first?.sourceSelection.includedEntryIDs
                ?? WeeklyReflectionEngine.makeReport(
                    entries: allDays.map(JournalEntrySnapshot.init(day:)),
                    weekContaining: date
                ).sourceSelection.includedEntryIDs
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func selectReflection(id: UUID) {
        guard let report = reflectionReports.first(where: { $0.id == id }) else { return }
        selectedReflectionID = id
        reflectionSourceSelection = report.sourceSelection.includedEntryIDs
    }

    func toggleReflectionSource(_ entryID: UUID) {
        if reflectionSourceSelection.contains(entryID) {
            reflectionSourceSelection.remove(entryID)
        } else {
            reflectionSourceSelection.insert(entryID)
        }
    }

    func regenerateReflection(weekContaining date: Date) async {
        guard let reflectionRepository else { return }
        do {
            let selectedEntries = allDays
                .map(JournalEntrySnapshot.init(day:))
                .filter { reflectionSourceSelection.contains($0.id) }
            var report = WeeklyReflectionEngine.makeReport(
                entries: selectedEntries,
                weekContaining: date,
                previousVersions: reflectionReports
            )
            report.sourceSelection = WeeklyReflectionSourceSelection(
                includedEntryIDs: reflectionSourceSelection,
                excludesSensitiveEntries: true
            )
            try await reflectionRepository.save(report)
            await loadReflections(weekContaining: date)
            selectReflection(id: report.id)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveReflectionTakeaway(_ text: String) async {
        guard var report = selectedReflection, let reflectionRepository else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        report.takeaway = trimmed.isEmpty ? nil : trimmed
        do {
            try await reflectionRepository.save(report)
            replaceReflection(report)
        } catch { errorMessage = error.localizedDescription }
    }

    func setReflectionDismissed(_ isDismissed: Bool) async {
        guard var report = selectedReflection, let reflectionRepository else { return }
        report.dismissedAt = isDismissed ? Date() : nil
        do {
            try await reflectionRepository.save(report)
            replaceReflection(report)
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteSelectedReflection(weekContaining date: Date) async {
        guard let report = selectedReflection, let reflectionRepository else { return }
        do {
            try await reflectionRepository.delete(id: report.id)
            await loadReflections(weekContaining: date)
        } catch { errorMessage = error.localizedDescription }
    }

    func startReflectionExport(format: JournalExportFormat, includesSensitiveFields: Bool) {
        guard let report = selectedReflection, let exportService else {
            exportPhase = .recoverableFailure(.init(message: "Journal export is unavailable on this device.", recovery: .retry))
            return
        }
        exportTask?.cancel()
        lastExportFormat = format
        lastExportIncludedSensitiveFields = includesSensitiveFields
        exportPhase = .running(progress: nil)
        let entries = allDays.map(JournalEntrySnapshot.init(day:))
        exportTask = Task {
            do {
                let receipt = try await exportService.export(.init(
                    report: report,
                    entries: entries,
                    format: format,
                    includesSensitiveFields: includesSensitiveFields
                ))
                try Task.checkCancellation()
                exportPhase = .success(receipt: receipt)
            } catch is CancellationError {
                exportPhase = .cancelled
            } catch {
                exportPhase = .recoverableFailure(.init(message: error.localizedDescription, recovery: .retry))
            }
        }
    }

    func cancelReflectionExport() {
        exportTask?.cancel()
        exportTask = nil
        exportPhase = .cancelled
    }

    func retryReflectionExport() {
        guard let lastExportFormat else { return }
        startReflectionExport(
            format: lastExportFormat,
            includesSensitiveFields: lastExportIncludedSensitiveFields
        )
    }

    func resetReflectionExport() {
        exportPhase = .idle
    }

    func createEncryptedBackup(passphrase: String) async {
        guard let backupService else {
            backupPhase = .recoverableFailure(.init(message: "Encrypted backup is unavailable on this device.", recovery: .retry))
            return
        }
        backupPhase = .running(progress: nil)
        do {
            let allReports = try await reflectionRepository?.reports(weekContaining: nil) ?? []
            let receipt = try await backupService.createBackup(
                days: allDays,
                reflections: allReports,
                passphrase: passphrase
            )
            try Task.checkCancellation()
            backupPhase = .success(receipt: receipt)
        } catch is CancellationError {
            backupPhase = .cancelled
        } catch {
            backupPhase = .recoverableFailure(.init(message: error.localizedDescription, recovery: .retry))
        }
    }

    func importEncryptedBackup(
        fileURL: URL,
        passphrase: String,
        duplicatePolicy: JournalBackupDuplicatePolicy
    ) async {
        guard let backupService,
              let reflectionRepository,
              let applier = repository as? any JournalBackupImportApplying else {
            importPhase = .recoverableFailure(.init(message: "This Journal repository cannot import backups safely.", recovery: .retry))
            return
        }
        importPhase = .running(progress: nil)
        do {
            let receipt = try await backupService.restoreBackup(
                from: fileURL,
                passphrase: passphrase,
                duplicatePolicy: duplicatePolicy,
                applyingTo: applier,
                reflectionRepository: reflectionRepository
            )
            try Task.checkCancellation()
            importPhase = .success(receipt: receipt)
            await load()
        } catch is CancellationError {
            importPhase = .cancelled
        } catch {
            importPhase = .recoverableFailure(.init(message: error.localizedDescription, recovery: .retry))
        }
    }

    func resetBackupPhases() {
        backupPhase = .idle
        importPhase = .idle
    }

    private func replaceReflection(_ report: WeeklyReflectionReport) {
        if let index = reflectionReports.firstIndex(where: { $0.id == report.id }) {
            reflectionReports[index] = report
        }
    }

    func applyVisibleDays() {
        var filtered = allDays.filter { day in
            (!starredOnly || day.isStarred) && (moodFilter == nil || day.latestMood == moodFilter)
        }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            switch searchState {
            case .ready(let references):
                let rank = Dictionary(uniqueKeysWithValues: references.enumerated().map { ($0.element.entryID, $0.offset) })
                filtered = filtered.filter { rank[$0.id] != nil }.sorted { (rank[$0.id] ?? .max) < (rank[$1.id] ?? .max) }
            case .unavailable, .failed:
                filtered = filtered.filter { $0.displayText.localizedCaseInsensitiveContains(trimmed) }
            case .idle, .searching, .building:
                break
            }
        }
        days = filtered
    }

    func search() async {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchState = .idle
            applyVisibleDays()
            return
        }
        guard let derivedIndex else {
            searchState = .unavailable("Semantic search is unavailable. Exact text search is still available.")
            applyVisibleDays()
            return
        }
        searchState = .searching
        do {
            let references = try await derivedIndex.search(query: trimmed, limit: 40)
            try Task.checkCancellation()
            searchState = .ready(references)
            applyVisibleDays()
        } catch is CancellationError {
            return
        } catch {
            searchState = .failed(error.localizedDescription)
            applyVisibleDays()
        }
    }

    private func rebuildDerivedIndex() async {
        guard let derivedIndex else { return }
        searchState = .building(progress: 0, message: "Preparing private search…")
        do {
            if let derivedPipeline {
                try await derivedPipeline.reconcileAll()
            } else {
                try await derivedIndex.rebuild(entries: allDays.map(JournalEntrySnapshot.init(day:)))
            }
            hasBuiltDerivedIndex = true
            searchState = .idle
        } catch is CancellationError {
            searchState = .idle
        } catch {
            searchState = .unavailable(error.localizedDescription)
        }
    }

    func appendText(_ text: String, promptID: String? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var day = today ?? LifeBoardJournalDayValue(day: Date())
        day.blocks.append(.init(dayID: day.id, kind: .text, text: trimmed, promptID: promptID, ordinal: day.blocks.count))
        day.updatedAt = Date()
        if await save(day) { await clearDraft() }
    }

    func saveDraftText(_ text: String, promptID: String?, editPosition: Int? = nil) async {
        let now = Date()
        let value = LifeBoardJournalDraftValue(
            id: draft?.id ?? UUID(),
            dayID: draft?.dayID ?? today?.id ?? UUID(),
            day: draft?.day ?? today?.day ?? Calendar.current.startOfDay(for: now),
            text: text,
            mood: draft?.mood,
            energy: draft?.energy,
            photoPayloads: draft?.photoPayloads ?? [],
            audioRelativePaths: draft?.audioRelativePaths ?? [],
            promptID: promptID,
            editPosition: editPosition,
            updatedAt: now
        )
        do {
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let draft { try await repository.deleteJournalDraft(id: draft.id) }
                draft = nil
            } else {
                try await repository.saveJournalDraft(value)
                draft = value
            }
        } catch { errorMessage = error.localizedDescription }
    }

    func clearDraft() async {
        guard let draft else { return }
        do {
            try await repository.deleteJournalDraft(id: draft.id)
            self.draft = nil
        } catch { errorMessage = error.localizedDescription }
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
        await appendPhotos([data])
    }

    func appendPhotos(_ payloads: [Data]) async {
        guard !payloads.isEmpty else { return }
        var day = today ?? LifeBoardJournalDayValue(day: Date())
        for payload in payloads {
            let media = LifeBoardJournalMediaValue(dayID: day.id, kind: .photo, payload: payload, syncPolicy: .privateCloud)
            day.media.append(media)
            day.blocks.append(.init(dayID: day.id, kind: .photo, mediaID: media.id, ordinal: day.blocks.count))
        }
        day.updatedAt = Date()
        await save(day)
    }

    @discardableResult
    func appendAudio(relativePath: String, duration: TimeInterval, transcription: String?) async -> Bool {
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
        return await save(day)
    }

    func updateAudioTranscription(relativePath: String, text: String?) async {
        guard var day = allDays.first(where: { day in
            day.media.contains(where: { $0.kind == .audio && $0.relativePath == relativePath })
        }), let mediaID = day.media.first(where: { $0.relativePath == relativePath })?.id,
        let blockIndex = day.blocks.firstIndex(where: { $0.kind == .audio && $0.mediaID == mediaID }) else {
            errorMessage = "The saved recording could not be found. Its protected audio file has not been removed."
            return
        }
        let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        day.blocks[blockIndex].text = trimmed.isEmpty ? nil : trimmed
        day.blocks[blockIndex].updatedAt = Date()
        day.updatedAt = Date()
        await save(day)
    }

    func updatePhoto(dayID: UUID, mediaID: UUID, payload: Data) async {
        guard var day = allDays.first(where: { $0.id == dayID }),
              let mediaIndex = day.media.firstIndex(where: { $0.id == mediaID && $0.kind == .photo }) else {
            errorMessage = "The photo could not be found. No Journal data was changed."
            return
        }
        day.media[mediaIndex].payload = payload
        day.updatedAt = Date()
        await save(day)
    }

    func moveBlock(dayID: UUID, blockID: UUID, offset: Int) async {
        guard offset != 0,
              var day = allDays.first(where: { $0.id == dayID }),
              let source = day.blocks.firstIndex(where: { $0.id == blockID }) else { return }
        let destination = min(max(0, source + offset), day.blocks.count - 1)
        guard destination != source else { return }
        let block = day.blocks.remove(at: source)
        day.blocks.insert(block, at: destination)
        for index in day.blocks.indices { day.blocks[index].ordinal = index }
        day.updatedAt = Date()
        await save(day)
    }

    func deleteBlock(dayID: UUID, blockID: UUID) async {
        guard var day = allDays.first(where: { $0.id == dayID }),
              let block = day.blocks.first(where: { $0.id == blockID }) else { return }
        let media = block.mediaID.flatMap { id in day.media.first(where: { $0.id == id }) }
        day.blocks.removeAll { $0.id == blockID }
        if let media { day.media.removeAll { $0.id == media.id } }
        for index in day.blocks.indices { day.blocks[index].ordinal = index }
        day.updatedAt = Date()
        if await save(day), media?.kind == .audio, let path = media?.relativePath {
            try? LifeBoardJournalAudioFiles.delete(relativePath: path)
        }
    }

    func discardAudio(relativePath: String) async {
        guard var day = allDays.first(where: { day in
            day.media.contains(where: { $0.kind == .audio && $0.relativePath == relativePath })
        }), let mediaID = day.media.first(where: { $0.relativePath == relativePath })?.id else {
            try? LifeBoardJournalAudioFiles.delete(relativePath: relativePath)
            return
        }
        day.media.removeAll(where: { $0.id == mediaID })
        day.blocks.removeAll(where: { $0.mediaID == mediaID })
        for index in day.blocks.indices { day.blocks[index].ordinal = index }
        day.updatedAt = Date()
        if await save(day) {
            try? LifeBoardJournalAudioFiles.delete(relativePath: relativePath)
        }
    }

    func toggleStar(_ dayValue: LifeBoardJournalDayValue) async {
        var day = dayValue
        day.isStarred.toggle()
        day.updatedAt = Date()
        await save(day)
    }

    /// Per-entry AI participation. Changing it re-saves the day so every
    /// downstream index observes the new state on its next pass.
    func setAIExclusion(_ exclusion: JournalAIExclusion, for dayValue: LifeBoardJournalDayValue) async {
        guard dayValue.aiExclusion != exclusion else { return }
        var day = dayValue
        day.aiExclusion = exclusion
        day.updatedAt = Date()
        await save(day)
    }

    func delete(_ day: LifeBoardJournalDayValue) async {
        do {
            for media in day.media where media.kind == .audio {
                if let path = media.relativePath { try? LifeBoardJournalAudioFiles.delete(relativePath: path) }
            }
            try await repository.deleteJournalDay(id: day.id)
            if let derivedPipeline {
                try await derivedPipeline.processDeletion(entryID: day.id)
            } else if let derivedIndex {
                try await derivedIndex.remove(entryID: day.id)
            }
            await LifeBoardJournalSpotlightIndexer.remove(dayID: day.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    @discardableResult
    func save(_ day: LifeBoardJournalDayValue) async -> Bool {
        do {
            try await repository.saveJournalDay(day)
            if let derivedPipeline {
                try await derivedPipeline.processCommitted(JournalEntrySnapshot(day: day))
            } else if let derivedIndex {
                try await derivedIndex.upsert(entry: JournalEntrySnapshot(day: day))
            }
            await LifeBoardJournalSpotlightIndexer.index(day)
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    var insights: LifeBoardJournalInsightSnapshot {
        LifeBoardJournalInsightEngine.makeSnapshot(days: days)
    }
}

struct LifeBoardJournalModuleView: View {
    private enum BackupOperation: String, Identifiable {
        case create
        case importArchive
        var id: String { rawValue }
    }

    private struct PhotoEditRequest: Identifiable {
        let id = UUID()
        var dayID: UUID
        var mediaID: UUID
        var payload: Data
    }

    @State private var store: LifeBoardJournalStore
    @State private var privacy: JournalPrivacyController
    private let router: LifeBoardAppRouter?
    private let reflectionWeekDate: Date
    @State private var showsTextComposer = false
    @State private var showsMood = false
    @State private var mood: LifeBoardJournalMood = .none
    @State private var photoSelection: [PhotosPickerItem] = []
    @State private var showsRecorder = false
    @State private var showsVoiceSearch = false
    @State private var showsPrivacy = false
    @State private var reflectionDevelopProgress = 1.0
    @State private var developedReflectionID: UUID?
    @State private var showsTakeawayEditor = false
    @State private var takeawayDraft = ""
    @State private var shareReceipt: JournalExportReceipt?
    @State private var confirmsReflectionDeletion = false
    @State private var photoEditRequest: PhotoEditRequest?
    @State private var backupOperation: BackupOperation?
    @State private var backupPassphrase = ""
    @State private var backupPassphraseConfirmation = ""
    @State private var pendingImportURL: URL?
    @State private var importDuplicatePolicy: JournalBackupDuplicatePolicy = .keepExisting
    @State private var showsBackupImporter = false
    @State private var backupOperationTask: Task<Void, Never>?
    @Environment(LifeBoardPresentationPreferences.self) private var preferences
    @Environment(\.scenePhase) private var scenePhase

    init(
        repository: any LifeBoardPhaseIIRepository,
        initialSection: LifeBoardJournalStore.Section = .today,
        reflectionWeekDate: Date = Date(),
        router: LifeBoardAppRouter? = nil
    ) {
        _store = State(initialValue: LifeBoardJournalStore(repository: repository, initialSection: initialSection))
        _privacy = State(initialValue: JournalPrivacyController(initiallyUnlocked: router?.isJournalAccessUnlocked == true))
        self.reflectionWeekDate = reflectionWeekDate
        self.router = router
    }

    var body: some View {
        let palette = LifeBoardDaypartTokens.palette(for: preferences.resolvedDaypart())
        let surface = AnyView(journalSurface(palette: palette))
        let captureSheets = AnyView(surface.sheet(isPresented: $showsTextComposer) {
            LifeBoardJournalTextComposer(
                prompt: currentPrompt,
                initialText: store.draft?.text ?? "",
                onDraftChanged: { text, editPosition in
                    Task { await store.saveDraftText(text, promptID: currentPrompt.id, editPosition: editPosition) }
                },
                onSave: { text in Task { await store.appendText(text, promptID: currentPrompt.id) } }
            )
        }.sheet(isPresented: $showsMood) {
            LifeBoardJournalMoodDialSheet(selectedMood: $mood) { energy in Task { await store.appendMood(mood, energy: energy) } }
        }.sheet(isPresented: $showsRecorder) {
            LifeBoardJournalAudioCapture { path, duration, transcription in
                await store.appendAudio(relativePath: path, duration: duration, transcription: transcription)
            } onTranscription: { path, transcription in
                await store.updateAudioTranscription(relativePath: path, text: transcription)
            } onDiscard: { path in
                await store.discardAudio(relativePath: path)
            }
        }.sheet(isPresented: $showsVoiceSearch) {
            LifeBoardJournalAudioCapture(purpose: .search) { path, _, transcription in
                defer { try? LifeBoardJournalAudioFiles.delete(relativePath: path) }
                if let transcription = transcription?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !transcription.isEmpty {
                    store.searchText = transcription
                }
                return true
            }
        })
        let auxiliarySheets = AnyView(captureSheets.sheet(isPresented: $showsPrivacy) {
            JournalPrivacySettingsView(
                controller: privacy,
                onCreateBackup: {
                    showsPrivacy = false
                    backupOperation = .create
                },
                onImportBackup: {
                    showsPrivacy = false
                    showsBackupImporter = true
                }
            )
        }.sheet(isPresented: $showsTakeawayEditor) {
            takeawayEditor
        }.sheet(item: $shareReceipt, onDismiss: { store.resetReflectionExport() }) { receipt in
            JournalExportShareSheet(url: receipt.fileURL)
        }.sheet(item: $photoEditRequest) { request in
            LifeBoardJournalPhotoEditor(payload: request.payload) { editedPayload in
                photoEditRequest = nil
                Task { await store.updatePhoto(dayID: request.dayID, mediaID: request.mediaID, payload: editedPayload) }
            }
        }.sheet(item: $backupOperation, onDismiss: resetBackupPresentation) { operation in
            backupPassphraseSheet(operation: operation)
        }.fileImporter(
            isPresented: $showsBackupImporter,
            allowedContentTypes: [UTType(filenameExtension: "lifeboardjournal") ?? .data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                pendingImportURL = urls.first
                if pendingImportURL != nil { backupOperation = .importArchive }
            case .failure(let error):
                store.errorMessage = "The backup could not be opened: \(error.localizedDescription)"
            }
        })
        return auxiliarySheets.confirmationDialog(
            "Delete this reflection version?",
            isPresented: $confirmsReflectionDeletion,
            titleVisibility: .visible
        ) {
            Button("Delete version", role: .destructive) {
                Task { await store.deleteSelectedReflection(weekContaining: reflectionWeekDate) }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your Journal entries are not deleted. Only this derived reflection version is removed.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showsPrivacy = true } label: { Image(systemName: "lock.shield") }
                    .accessibilityLabel("Journal privacy")
            }
        }
        .alert("Journal is unavailable", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(store.errorMessage ?? "") }
    }

    private func journalSurface(palette: LifeBoardDaypartPalette) -> some View {
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
        .overlay {
            if privacy.state != .unlocked { journalPrivacyGate }
        }
        .task {
            await privacy.authenticateIfNeeded()
            guard privacy.state == .unlocked else { return }
            router?.journalDidUnlock()
            await store.load()
            if store.section == .insights { await store.loadReflections(weekContaining: reflectionWeekDate) }
        }
        .task(id: store.section) {
            guard store.section == .insights, privacy.state == .unlocked else { return }
            await store.loadReflections(weekContaining: reflectionWeekDate)
        }
        .task(id: store.searchText) {
            do {
                try await Task.sleep(for: .milliseconds(180))
                await store.search()
            } catch is CancellationError {
                return
            } catch {
                store.errorMessage = error.localizedDescription
            }
        }
        .onChange(of: store.starredOnly) { _, _ in store.applyVisibleDays() }
        .onChange(of: store.moodFilter) { _, _ in store.applyVisibleDays() }
        .onChange(of: privacy.state) { _, state in
            if state == .unlocked {
                router?.journalDidUnlock()
            } else if privacy.policy.requiresAuthentication {
                router?.journalDidLock()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .background else { return }
            privacy.lock()
            router?.journalDidLock()
        }
        .onChange(of: photoSelection) { _, items in
            Task {
                var payloads: [Data] = []
                do {
                    for item in items {
                        if let data = try await item.loadTransferable(type: Data.self) { payloads.append(data) }
                    }
                    await store.appendPhotos(payloads)
                } catch {
                    store.errorMessage = "A selected photo could not be added: \(error.localizedDescription)"
                }
                photoSelection = []
            }
        }
    }

    private var takeawayEditor: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $takeawayDraft)
                        .frame(minHeight: 140)
                        .accessibilityIdentifier("journal.reflection.takeaway")
                } header: {
                    Text("What do you want to carry forward?")
                }
            }
            .navigationTitle("Weekly takeaway")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showsTakeawayEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        showsTakeawayEditor = false
                        Task { await store.saveReflectionTakeaway(takeawayDraft) }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func backupPassphraseSheet(operation: BackupOperation) -> some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Passphrase", text: $backupPassphrase)
                        .textContentType(.password)
                    if operation == .create {
                        SecureField("Confirm passphrase", text: $backupPassphraseConfirmation)
                            .textContentType(.password)
                    }
                } header: {
                    Text(operation == .create ? "Protect this backup" : "Unlock this backup")
                } footer: {
                    Text("LifeBoard never stores this passphrase. If it is lost, the encrypted backup cannot be recovered.")
                }

                if operation == .importArchive {
                    Section("Duplicates") {
                        Picker("When an entry already exists", selection: $importDuplicatePolicy) {
                            Text("Keep existing").tag(JournalBackupDuplicatePolicy.keepExisting)
                            Text("Replace existing").tag(JournalBackupDuplicatePolicy.replaceExisting)
                            Text("Keep both").tag(JournalBackupDuplicatePolicy.duplicateWithNewIDs)
                        }
                    }
                }

                Section {
                    backupAction(operation: operation)
                    backupStatus(operation: operation)
                }
            }
            .navigationTitle(operation == .create ? "Encrypted backup" : "Import backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if isBackupBusy {
                        Button("Cancel", role: .cancel) {
                            backupOperationTask?.cancel()
                            backupOperationTask = nil
                        }
                    } else {
                        Button("Close") { backupOperation = nil }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isBackupBusy)
    }

    @ViewBuilder
    private func backupAction(operation: BackupOperation) -> some View {
        let phase = operation == .create ? backupPhaseForControl : importPhaseForControl
        LifeBoardAsyncActionControl(
            title: operation == .create ? "Create protected backup" : "Import safely",
            runningTitle: operation == .create ? "Encrypting" : "Validating",
            successTitle: operation == .create ? "Backup ready" : "Import complete",
            phase: phase
        ) {
            guard backupPassphrase.count >= 8 else { return }
            if operation == .create {
                guard backupPassphrase == backupPassphraseConfirmation else { return }
                backupOperationTask?.cancel()
                backupOperationTask = Task {
                    await store.createEncryptedBackup(passphrase: backupPassphrase)
                    backupOperationTask = nil
                }
            } else if let pendingImportURL {
                backupOperationTask?.cancel()
                backupOperationTask = Task {
                    let hasSecurityScope = pendingImportURL.startAccessingSecurityScopedResource()
                    defer {
                        if hasSecurityScope { pendingImportURL.stopAccessingSecurityScopedResource() }
                    }
                    await store.importEncryptedBackup(
                        fileURL: pendingImportURL,
                        passphrase: backupPassphrase,
                        duplicatePolicy: importDuplicatePolicy
                    )
                    backupOperationTask = nil
                }
            }
        }
        .disabled(
            backupPassphrase.count < 8
                || (operation == .create && backupPassphrase != backupPassphraseConfirmation)
                || (operation == .importArchive && pendingImportURL == nil)
                || isBackupBusy
        )
    }

    @ViewBuilder
    private func backupStatus(operation: BackupOperation) -> some View {
        if operation == .create, case .success(let receipt) = store.backupPhase {
            ShareLink(item: receipt.fileURL) {
                Label("Share encrypted backup", systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        } else if operation == .importArchive, case .success(let receipt) = store.importPhase {
            Label(
                "Imported \(receipt.insertedDayIDs.count), replaced \(receipt.replacedDayIDs.count), skipped \(receipt.skippedDayIDs.count)",
                systemImage: "checkmark.shield.fill"
            )
            .font(.footnote)
        } else if let failure = backupFailure(operation: operation) {
            Label(failure.message, systemImage: "exclamationmark.triangle")
                .font(.footnote)
                .foregroundStyle(.red)
        }
    }

    private func backupFailure(operation: BackupOperation) -> AsyncActionFailure? {
        if operation == .create, case .recoverableFailure(let failure) = store.backupPhase { return failure }
        if operation == .importArchive, case .recoverableFailure(let failure) = store.importPhase { return failure }
        return nil
    }

    private var backupPhaseForControl: AsyncActionPhase<Bool> {
        switch store.backupPhase {
        case .idle: .idle
        case .running(let progress): .running(progress: progress)
        case .success: .success(receipt: true)
        case .recoverableFailure(let failure): .recoverableFailure(failure)
        case .cancelled: .cancelled
        }
    }

    private var importPhaseForControl: AsyncActionPhase<Bool> {
        switch store.importPhase {
        case .idle: .idle
        case .running(let progress): .running(progress: progress)
        case .success: .success(receipt: true)
        case .recoverableFailure(let failure): .recoverableFailure(failure)
        case .cancelled: .cancelled
        }
    }

    private var isBackupBusy: Bool {
        if case .running = store.backupPhase { return true }
        if case .running = store.importPhase { return true }
        return false
    }

    private func resetBackupPresentation() {
        backupOperationTask?.cancel()
        backupOperationTask = nil
        backupPassphrase = ""
        backupPassphraseConfirmation = ""
        pendingImportURL = nil
        importDuplicatePolicy = .keepExisting
        store.resetBackupPhases()
    }

    private var journalPrivacyGate: some View {
        ZStack {
            Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea()
            VStack(spacing: 18) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                Text("Journal locked")
                    .font(.title2.weight(.semibold))
                Group {
                    switch privacy.state {
                    case .authenticating:
                        ProgressView("Checking your device")
                    case .recoveryRequired(let message):
                        Text(message)
                    case .locked:
                        Text("Your entries stay hidden until you authenticate.")
                    case .unlocked:
                        EmptyView()
                    }
                }
                .font(.subheadline)
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                .multilineTextAlignment(.center)
                if privacy.state != .authenticating {
                    Button("Unlock", systemImage: "faceid") {
                        Task {
                            await privacy.authenticateIfNeeded()
                            if privacy.state == .unlocked {
                                router?.journalDidUnlock()
                                await store.load()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                if case .recoveryRequired = privacy.state {
                    Button("Privacy settings", systemImage: "gearshape") { showsPrivacy = true }
                        .buttonStyle(.bordered)
                        .accessibilityHint("Lets you disable Journal authentication after device authentication becomes unavailable")
                }
            }
            .padding(28)
            .frame(maxWidth: 420)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.privacy.lock")
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
                    journalDayCard(today, palette: palette, onDelete: nil)
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
                Text(store.draft == nil ? (store.today == nil ? "Start with a sentence" : "Add another thought") : "Continue your draft")
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
            PhotosPicker(selection: $photoSelection, maxSelectionCount: 5, matching: .images) {
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
                searchStatus(palette: palette)
                if store.days.isEmpty {
                    ContentUnavailableView("No entries found", systemImage: "book.closed", description: Text("Try another search or add a thought today."))
                        .padding(.top, 40)
                } else {
                    ForEach(store.days) { day in
                        journalDayCard(day, palette: palette, onDelete: { Task { await store.delete(day) } })
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
    }

    private func journalDayCard(
        _ day: LifeBoardJournalDayValue,
        palette: LifeBoardDaypartPalette,
        onDelete: (() -> Void)?
    ) -> some View {
        LifeBoardJournalDayCard(
            day: day,
            palette: palette,
            onStar: { Task { await store.toggleStar(day) } },
            onDelete: onDelete,
            onEditPhoto: { media in
                guard let payload = media.payload else { return }
                photoEditRequest = .init(dayID: day.id, mediaID: media.id, payload: payload)
            },
            onMoveBlock: { blockID, offset in
                Task { await store.moveBlock(dayID: day.id, blockID: blockID, offset: offset) }
            },
            onDeleteBlock: { blockID in
                Task { await store.deleteBlock(dayID: day.id, blockID: blockID) }
            },
            onSetAIExclusion: V2FeatureFlags.journalParityV1Enabled
                ? { exclusion in Task { await store.setAIExclusion(exclusion, for: day) } }
                : nil
        )
    }

    @ViewBuilder
    private func searchStatus(palette: LifeBoardDaypartPalette) -> some View {
        switch store.searchState {
        case .idle:
            EmptyView()
        case .searching:
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Searching privately on this device…")
            }
            .font(.caption)
            .foregroundStyle(palette.color(for: .foregroundSecondary))
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        case .building(let progress, let message):
            HStack(spacing: 10) {
                LifeBoardJournalWorkIndicator(isActive: true, progress: progress)
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: progress)
                    Text(message)
                }
            }
            .font(.caption)
            .foregroundStyle(palette.color(for: .foregroundSecondary))
            .frame(maxWidth: .infinity, alignment: .leading)
        case .ready(let references):
            if !store.searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(references.isEmpty ? "No related moments found" : "\(references.count) evidence-linked result\(references.count == 1 ? "" : "s")")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        case .unavailable(let reason), .failed(let reason):
            Label(reason, systemImage: "lock.shield")
                .font(.caption)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func insights(palette: LifeBoardDaypartPalette) -> some View {
        let preview = WeeklyReflectionEngine.makeReport(
            entries: store.allDays.map(JournalEntrySnapshot.init(day:)),
            weekContaining: reflectionWeekDate,
            previousVersions: store.reflectionReports
        )
        let report = store.selectedReflection ?? preview
        let weekEntries = store.allDays.filter { day in
            day.day >= report.weekStart && day.day <= report.weekEnd
        }
        return ScrollView {
            VStack(spacing: 16) {
                let snapshot = store.insights
                HStack(spacing: 12) {
                    insightTile("Days", value: "\(snapshot.daysWritten)", symbol: "calendar", palette: palette)
                    insightTile("Streak", value: "\(snapshot.currentStreak)", symbol: "flame", palette: palette)
                    insightTile("Words", value: "\(snapshot.totalWords)", symbol: "text.word.spacing", palette: palette)
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Weekly reflection")
                            .font(.title3.weight(.semibold))
                            .accessibilityIdentifier("journal.weeklyReflection.header")
                        Spacer()
                        if store.reflectionReports.count > 1 {
                            Menu {
                                ForEach(store.reflectionReports) { version in
                                    Button {
                                        store.selectReflection(id: version.id)
                                    } label: {
                                        Label(
                                            "Version \(version.version) · \(version.createdAt.formatted(date: .abbreviated, time: .shortened))",
                                            systemImage: version.id == report.id ? "checkmark" : "clock.arrow.circlepath"
                                        )
                                    }
                                }
                            } label: {
                                Text("v\(report.version)")
                                    .font(.caption2.weight(.semibold))
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .accessibilityLabel("Reflection version \(report.version)")
                        }
                        Text(report.density.rawValue.capitalized)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(palette.color(for: .canvasSecondary), in: Capsule())
                    }
                    Text("\(report.weekStart.formatted(.dateTime.month(.abbreviated).day()))–\(report.weekEnd.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    Text(report.summary)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    if let takeaway = report.takeaway, takeaway.isEmpty == false {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Takeaway").font(.caption.weight(.semibold))
                            Text(takeaway)
                        }
                        .padding(.top, 2)
                    }
                    if !report.sourceSelection.includedEntryIDs.isEmpty {
                        Label(
                            "Based on \(report.sourceSelection.includedEntryIDs.count) selected Journal day\(report.sourceSelection.includedEntryIDs.count == 1 ? "" : "s")",
                            systemImage: "quote.bubble"
                        )
                            .font(.caption)
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                    }
                    if report.dismissedAt != nil {
                        Label("Set aside for now", systemImage: "archivebox")
                            .font(.caption)
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .lifeBoardPaperCard()
                .lifeboardMemoryDevelopReveal(progress: reflectionDevelopProgress)
                .onAppear { developReflectionIfNeeded(report.id) }
                .onChange(of: report.id) { _, id in developReflectionIfNeeded(id) }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Menu {
                            if weekEntries.isEmpty {
                                Text("No Journal days this week")
                            } else {
                                ForEach(weekEntries) { day in
                                    Button {
                                        store.toggleReflectionSource(day.id)
                                    } label: {
                                        Label(
                                            day.day.formatted(date: .abbreviated, time: .omitted),
                                            systemImage: store.reflectionSourceSelection.contains(day.id) ? "checkmark.circle.fill" : "circle"
                                        )
                                    }
                                }
                            }
                        } label: {
                            Label("Sources", systemImage: "quote.bubble")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)

                        Button {
                            Task { await store.regenerateReflection(weekContaining: reflectionWeekDate) }
                        } label: {
                            Label(store.reflectionReports.isEmpty ? "Save" : "Regenerate", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(report.density != .empty && store.reflectionSourceSelection.isEmpty)
                        .accessibilityIdentifier("journal.reflection.regenerate")
                    }

                    HStack(spacing: 10) {
                        Button {
                            takeawayDraft = report.takeaway ?? ""
                            showsTakeawayEditor = true
                        } label: {
                            Label(report.takeaway == nil ? "Add takeaway" : "Edit takeaway", systemImage: "bookmark")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.selectedReflection == nil)

                        Menu {
                            ForEach(JournalExportFormat.allCases, id: \.self) { format in
                                Button(format.rawValue.uppercased()) {
                                    store.startReflectionExport(
                                        format: format,
                                        includesSensitiveFields: privacy.policy.excludesSensitiveEntriesFromExport == false
                                    )
                                }
                            }
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.selectedReflection == nil)

                        Menu {
                            Button(report.dismissedAt == nil ? "Set aside" : "Restore") {
                                Task { await store.setReflectionDismissed(report.dismissedAt == nil) }
                            }
                            Button("Delete version", role: .destructive) { confirmsReflectionDeletion = true }
                        } label: {
                            Image(systemName: "ellipsis")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.bordered)
                        .disabled(store.selectedReflection == nil)
                        .accessibilityLabel("More reflection actions")
                    }
                    reflectionExportStatus(palette: palette)
                }
                Text("Insights are deterministic and evidence-linked. Eva can interpret them on device when its local model is available.")
                    .font(.caption)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            .padding(20)
        }
    }

    private func developReflectionIfNeeded(_ id: UUID) {
        guard developedReflectionID != id else { return }
        developedReflectionID = id
        reflectionDevelopProgress = 0
        withAnimation(.easeOut(duration: 0.72)) {
            reflectionDevelopProgress = 1
        }
    }

    @ViewBuilder
    private func reflectionExportStatus(palette: LifeBoardDaypartPalette) -> some View {
        switch store.exportPhase {
        case .idle:
            EmptyView()
        case .running:
            HStack(spacing: 10) {
                LifeBoardJournalWorkIndicator(isActive: true)
                Text("Preparing a protected export…").font(.caption)
                Spacer()
                Button("Cancel") { store.cancelReflectionExport() }
            }
            .foregroundStyle(palette.color(for: .foregroundSecondary))
            .accessibilityIdentifier("journal.export.running")
        case .success(let receipt):
            LifeBoardAsyncActionControl(
                title: "Export",
                runningTitle: "Preparing",
                successTitle: receipt.redactedSensitiveFields ? "Share redacted export" : "Share export",
                phase: store.exportPhase
            ) {
                shareReceipt = receipt
            }
            .accessibilityIdentifier("journal.export.share")
        case .recoverableFailure(let failure):
            VStack(alignment: .leading, spacing: 6) {
                Label(failure.message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                LifeBoardAsyncActionControl(
                    title: "Export",
                    runningTitle: "Preparing",
                    successTitle: "Share export",
                    phase: store.exportPhase,
                    action: store.retryReflectionExport
                )
            }
            .foregroundStyle(palette.color(for: .foregroundSecondary))
        case .cancelled:
            HStack {
                Text("Export cancelled").font(.caption)
                Spacer()
                Button("Dismiss") { store.resetReflectionExport() }
            }
            .foregroundStyle(palette.color(for: .foregroundSecondary))
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

}

public enum JournalPhotoCropMode: String, CaseIterable, Sendable {
    case original
    case square
    case portrait
}

@MainActor
public enum JournalPhotoProcessor {
    public static func edit(
        payload: Data,
        clockwiseQuarterTurns: Int,
        cropMode: JournalPhotoCropMode
    ) -> Data? {
        guard let source = UIImage(data: payload), let normalized = normalized(source) else { return nil }
        let turns = ((clockwiseQuarterTurns % 4) + 4) % 4
        let rotated = (0..<turns).reduce(normalized) { image, _ in rotateClockwise(image) }
        let cropped = crop(rotated, mode: cropMode)
        return cropped.jpegData(compressionQuality: 0.92) ?? cropped.pngData()
    }

    private static func normalized(_ image: UIImage) -> UIImage? {
        let size = CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
        guard size.width > 0, size.height > 0 else { return nil }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    private static func rotateClockwise(_ image: UIImage) -> UIImage {
        let outputSize = CGSize(width: image.size.height, height: image.size.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            context.cgContext.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            context.cgContext.rotate(by: .pi / 2)
            image.draw(in: CGRect(
                x: -image.size.width / 2,
                y: -image.size.height / 2,
                width: image.size.width,
                height: image.size.height
            ))
        }
    }

    private static func crop(_ image: UIImage, mode: JournalPhotoCropMode) -> UIImage {
        let targetAspect: CGFloat?
        switch mode {
        case .original: targetAspect = nil
        case .square: targetAspect = 1
        case .portrait: targetAspect = 4 / 5
        }
        guard let targetAspect else { return image }
        let imageAspect = image.size.width / image.size.height
        let cropSize: CGSize
        if imageAspect > targetAspect {
            cropSize = CGSize(width: image.size.height * targetAspect, height: image.size.height)
        } else {
            cropSize = CGSize(width: image.size.width, height: image.size.width / targetAspect)
        }
        let origin = CGPoint(
            x: (image.size.width - cropSize.width) / 2,
            y: (image.size.height - cropSize.height) / 2
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: cropSize, format: format).image { _ in
            image.draw(at: CGPoint(x: -origin.x, y: -origin.y))
        }
    }
}

private struct LifeBoardJournalPhotoEditor: View {
    let payload: Data
    let onSave: (Data) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var quarterTurns = 0
    @State private var cropMode: JournalPhotoCropMode = .original
    @State private var editedPayload: Data

    init(payload: Data, onSave: @escaping (Data) -> Void) {
        self.payload = payload
        self.onSave = onSave
        _editedPayload = State(initialValue: payload)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                if let image = UIImage(data: editedPayload) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .accessibilityLabel("Edited Journal photo preview")
                } else {
                    ContentUnavailableView("Photo unavailable", systemImage: "photo.badge.exclamationmark")
                }
                Picker("Crop", selection: $cropMode) {
                    Text("Original").tag(JournalPhotoCropMode.original)
                    Text("Square").tag(JournalPhotoCropMode.square)
                    Text("4:5").tag(JournalPhotoCropMode.portrait)
                }
                .pickerStyle(.segmented)
                HStack {
                    Button("Rotate", systemImage: "rotate.right") {
                        quarterTurns = (quarterTurns + 1) % 4
                        updatePreview()
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    Button("Reset", systemImage: "arrow.counterclockwise") {
                        quarterTurns = 0
                        cropMode = .original
                        editedPayload = payload
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.bordered)
            }
            .padding(20)
            .background(Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea())
            .navigationTitle("Edit photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { onSave(editedPayload) }
                        .disabled(UIImage(data: editedPayload) == nil)
                }
            }
            .onChange(of: cropMode) { _, _ in updatePreview() }
        }
    }

    private func updatePreview() {
        editedPayload = JournalPhotoProcessor.edit(
            payload: payload,
            clockwiseQuarterTurns: quarterTurns,
            cropMode: cropMode
        ) ?? payload
    }
}

private struct JournalExportShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct LifeBoardJournalDayCard: View {
    let day: LifeBoardJournalDayValue
    let palette: LifeBoardDaypartPalette
    let onStar: () -> Void
    let onDelete: (() -> Void)?
    let onEditPhoto: (LifeBoardJournalMediaValue) -> Void
    let onMoveBlock: (UUID, Int) -> Void
    let onDeleteBlock: (UUID) -> Void
    var onSetAIExclusion: ((JournalAIExclusion) -> Void)?
    @State private var confirmsDelete = false
    @State private var playback = LifeBoardJournalAudioPlaybackController()
    @State private var mediaRevealProgress = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(day.day.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                    .font(.headline)
                Spacer()
                if let onSetAIExclusion {
                    Menu {
                        Section("Eva and AI features") {
                            exclusionOption(.included, "Included", "sparkles", onSetAIExclusion)
                            exclusionOption(.excludedFromAI, "Keep out of Eva's memory", "sparkles.slash", onSetAIExclusion)
                            exclusionOption(.excludedFromAIAndReflection, "Keep out of AI and reflections", "eye.slash", onSetAIExclusion)
                        }
                    } label: {
                        Image(systemName: day.aiExclusion == .included ? "sparkles" : "sparkles.slash")
                            .foregroundStyle(day.aiExclusion == .included
                                ? palette.color(for: .foregroundSecondary)
                                : palette.color(for: .celestialCore))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("AI visibility for this day")
                    .accessibilityValue(exclusionAccessibilityValue)
                }
                Button(action: onStar) { Image(systemName: day.isStarred ? "star.fill" : "star") }
                    .accessibilityLabel(day.isStarred ? "Unstar journal day" : "Star journal day")
                if onDelete != nil {
                    Button(role: .destructive) { confirmsDelete = true } label: { Image(systemName: "trash") }
                        .accessibilityLabel("Delete journal day")
                }
            }
            if day.aiExclusion != .included {
                Label(
                    day.aiExclusion == .excludedFromAI
                        ? "Kept out of Eva's memory"
                        : "Kept out of AI and weekly reflections",
                    systemImage: "sparkles.slash"
                )
                .font(.caption)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
                .accessibilityIdentifier("journal.day.exclusionBadge")
            }
            ForEach(day.blocks) { block in
                HStack(alignment: .top, spacing: 10) {
                    blockIcon(block)
                    VStack(alignment: .leading, spacing: 4) {
                        if let mood = block.mood {
                            Text("Feeling \(mood.title.lowercased())\(block.energy.map { ", energy \($0) of 5" } ?? "")")
                        }
                        if let text = block.text, !text.isEmpty { Text(text).font(.body) }
                        if block.kind == .photo,
                           let media = day.media.first(where: { $0.id == block.mediaID }),
                           let payload = media.payload,
                           let image = UIImage(data: payload) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 260)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .lifeboardJournalMediaReveal(progress: mediaRevealProgress)
                                .accessibilityLabel("Journal photo")
                        } else if block.kind == .photo {
                            Label("Photo unavailable", systemImage: "photo.badge.exclamationmark")
                                .foregroundStyle(palette.color(for: .foregroundSecondary))
                        }
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
                    Spacer(minLength: 4)
                    Menu {
                        if block.kind == .photo,
                           let media = day.media.first(where: { $0.id == block.mediaID }),
                           media.payload != nil {
                            Button("Edit photo", systemImage: "crop.rotate") { onEditPhoto(media) }
                        }
                        if day.blocks.first?.id != block.id {
                            Button("Move earlier", systemImage: "arrow.up") { onMoveBlock(block.id, -1) }
                        }
                        if day.blocks.last?.id != block.id {
                            Button("Move later", systemImage: "arrow.down") { onMoveBlock(block.id, 1) }
                        }
                        Button("Delete block", systemImage: "trash", role: .destructive) { onDeleteBlock(block.id) }
                    } label: {
                        Image(systemName: "ellipsis")
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Actions for \(block.kind.rawValue) block")
                }
            }
        }
        .padding(18)
        .lifeBoardPaperCard()
        .confirmationDialog("Delete this entire journal day?", isPresented: $confirmsDelete, titleVisibility: .visible) {
            Button("Delete day", role: .destructive) { onDelete?() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("Text, mood, photos, and local audio for this day will be removed.") }
        .onAppear {
            mediaRevealProgress = reduceMotion ? 1 : 0
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.48)) {
                mediaRevealProgress = 1
            }
        }
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

    @ViewBuilder
    private func exclusionOption(
        _ exclusion: JournalAIExclusion,
        _ title: String,
        _ symbol: String,
        _ action: @escaping (JournalAIExclusion) -> Void
    ) -> some View {
        Button {
            action(exclusion)
        } label: {
            if day.aiExclusion == exclusion {
                Label(title, systemImage: "checkmark")
            } else {
                Label(title, systemImage: symbol)
            }
        }
    }

    private var exclusionAccessibilityValue: String {
        switch day.aiExclusion {
        case .included: return "Included in AI features"
        case .excludedFromAI: return "Kept out of Eva's memory"
        case .excludedFromAIAndReflection: return "Kept out of AI and weekly reflections"
        }
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
    let initialText: String
    let onDraftChanged: (String, Int?) -> Void
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var committed = false

    init(
        prompt: LifeBoardJournalPrompt,
        initialText: String,
        onDraftChanged: @escaping (String, Int?) -> Void,
        onSave: @escaping (String) -> Void
    ) {
        self.prompt = prompt
        self.initialText = initialText
        self.onDraftChanged = onDraftChanged
        self.onSave = onSave
        _text = State(initialValue: initialText)
    }

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
            .task(id: text) {
                do {
                    try await Task.sleep(for: .milliseconds(250))
                    guard committed == false else { return }
                    onDraftChanged(text, text.count)
                } catch is CancellationError {
                    return
                } catch {
                    return
                }
            }
            .onDisappear {
                guard committed == false else { return }
                onDraftChanged(text, text.count)
            }
            .navigationTitle("Write")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        committed = true
                        onSave(text)
                        dismiss()
                    }
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

enum LifeBoardJournalAudioFiles {
    static func newRecordingURL() throws -> URL {
        let root = try directory()
        return root.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")
    }

    static func relativePath(for url: URL) -> String { url.lastPathComponent }

    static func url(relativePath: String) throws -> URL {
        guard relativePath == URL(fileURLWithPath: relativePath).lastPathComponent,
              relativePath.contains("/") == false,
              relativePath.contains("\\") == false else {
            throw CocoaError(.fileReadInvalidFileName)
        }
        return try directory().appendingPathComponent(relativePath)
    }

    static func delete(relativePath: String) throws { try FileManager.default.removeItem(at: url(relativePath: relativePath)) }

    static func deleteOrphans(retaining relativePaths: Set<String>) throws {
        let root = try directory()
        let contents = try FileManager.default.contentsOfDirectory(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        for file in contents where file.pathExtension.lowercased() == "m4a" {
            guard relativePaths.contains(file.lastPathComponent) == false else { continue }
            try? FileManager.default.removeItem(at: file)
        }
    }

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
/// Journal transcription backed by the shared TranscriptionKit service:
/// iOS 26 on-device SpeechAnalyzer with legacy SFSpeechRecognizer fallback,
/// bounded concurrency, and an overall timeout (OffRecord parity).
private final class LifeBoardJournalSpeechTranscriber {
    /// One shared service so the two-job concurrency limiter spans every
    /// journal transcription in the process.
    private static let service = TranscriptionService(
        consentProvider: { UserDefaults.standard.bool(forKey: "lifeboard.journal.speech_consent.v1") }
    )

    func transcribe(_ url: URL) async -> String? {
        do {
            return try await Self.service.transcribe(from: url).text
        } catch {
            return nil
        }
    }
}

private struct JournalPrivacySettingsView: View {
    @Bindable var controller: JournalPrivacyController
    let onCreateBackup: () -> Void
    let onImportBackup: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Require device authentication", isOn: Binding(
                        get: { controller.policy.requiresAuthentication },
                        set: { controller.updateAuthenticationRequirement($0) }
                    ))
                    Toggle("Hide Journal in the app switcher", isOn: $controller.policy.shieldsAppSwitcher)
                } header: {
                    Text("Access")
                } footer: {
                    Text("Authentication uses Face ID, Touch ID, or the device passcode. Cancelling always leaves Journal locked.")
                }

                Section {
                    Toggle("Exclude sensitive entries from ordinary exports", isOn: $controller.policy.excludesSensitiveEntriesFromExport)
                    Toggle("Allow Journal evidence for Eva", isOn: $controller.policy.permitsJournalEvidenceForEva)
                } header: {
                    Text("Sharing")
                } footer: {
                    Text("Journal evidence is off by default. Enabling it permits eligible evidence references, not unrestricted entry access.")
                }

                Section {
                    Label("Semantic indexes remain protected and local-only, and are never included in ordinary exports.", systemImage: "internaldrive.fill")
                        .font(.footnote)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }

                Section("Encrypted recovery") {
                    Button("Create encrypted backup", systemImage: "lock.doc") { onCreateBackup() }
                    Button("Import encrypted backup", systemImage: "square.and.arrow.down") { onImportBackup() }
                }
            }
            .navigationTitle("Journal Privacy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

struct LifeBoardJournalAudioCapture: View {
    enum Purpose { case journal, search }

    let purpose: Purpose
    let onSave: (String, TimeInterval, String?) async -> Bool
    let onTranscription: (String, String?) async -> Void
    let onDiscard: (String) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = LifeBoardJournalAudioRecorder()
    @State private var capturedURL: URL?
    @State private var capturedDuration: TimeInterval = 0
    @State private var transcribes: Bool
    @State private var isTranscribing = false
    @State private var showsConsent = false
    @State private var transcription: String?
    @State private var manualTranscription = ""
    @State private var processingState: JournalMediaAttachment.ProcessingState = .ready
    @State private var didPersist = false

    init(
        purpose: Purpose = .journal,
        onSave: @escaping (String, TimeInterval, String?) async -> Bool,
        onTranscription: @escaping (String, String?) async -> Void = { _, _ in },
        onDiscard: @escaping (String) async -> Void = { _ in }
    ) {
        self.purpose = purpose
        self.onSave = onSave
        self.onTranscription = onTranscription
        self.onDiscard = onDiscard
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
                if isTranscribing { ProgressView("Transcribing saved audio…") }
                if let transcription { Text(transcription).padding().background(.background, in: RoundedRectangle(cornerRadius: 14)) }
                if processingState == .transcriptionFailed {
                    VStack(spacing: 10) {
                        Label("The recording is safe, but transcription did not finish.", systemImage: "exclamationmark.bubble")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                        TextField("Add transcription manually", text: $manualTranscription, axis: .vertical)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Button("Retry") { Task { await retryTranscription() } }
                            Button(purpose == .search ? "Use text" : "Save text") { Task { await saveManualTranscription() } }
                                .disabled(manualTranscription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        .buttonStyle(.bordered)
                        if purpose == .journal {
                            Button("Keep audio without text") { dismiss() }
                            Button("Discard recording", role: .destructive) { Task { await discardRecording() } }
                        }
                    }
                }
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
                        .disabled(isTranscribing || didPersist)
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(didPersist ? "Done" : "Cancel") {
                        if !didPersist { recorder.cancel() }
                        dismiss()
                    }
                }
            }
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
        let path = LifeBoardJournalAudioFiles.relativePath(for: capturedURL)
        if purpose == .journal {
            processingState = .queued
            guard await onSave(path, capturedDuration, nil) else {
                processingState = .transcriptionFailed
                return
            }
            didPersist = true
            guard transcribes else { dismiss(); return }
            await transcribeSavedAudio(capturedURL, path: path)
        } else {
            await transcribeSearchAudio(capturedURL, path: path)
        }
    }

    private func transcribeSavedAudio(_ url: URL, path: String) async {
        processingState = .transcribing
        isTranscribing = true
        let result = await LifeBoardJournalSpeechTranscriber().transcribe(url)
        isTranscribing = false
        guard let result, !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            processingState = .transcriptionFailed
            return
        }
        transcription = result
        processingState = .transcriptionComplete
        await onTranscription(path, result)
        dismiss()
    }

    private func transcribeSearchAudio(_ url: URL, path: String) async {
        processingState = .transcribing
        isTranscribing = true
        let result = await LifeBoardJournalSpeechTranscriber().transcribe(url)
        isTranscribing = false
        guard let result, !result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            processingState = .transcriptionFailed
            return
        }
        transcription = result
        processingState = .transcriptionComplete
        _ = await onSave(path, capturedDuration, result)
        dismiss()
    }

    private func retryTranscription() async {
        guard let capturedURL else { return }
        let path = LifeBoardJournalAudioFiles.relativePath(for: capturedURL)
        if purpose == .journal {
            await transcribeSavedAudio(capturedURL, path: path)
        } else {
            await transcribeSearchAudio(capturedURL, path: path)
        }
    }

    private func saveManualTranscription() async {
        guard let capturedURL else { return }
        let text = manualTranscription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let path = LifeBoardJournalAudioFiles.relativePath(for: capturedURL)
        processingState = .manualTranscription
        if purpose == .journal {
            await onTranscription(path, text)
        } else {
            _ = await onSave(path, capturedDuration, text)
        }
        dismiss()
    }

    private func discardRecording() async {
        guard let capturedURL else { return }
        let path = LifeBoardJournalAudioFiles.relativePath(for: capturedURL)
        processingState = .discarded
        if didPersist { await onDiscard(path) }
        else { try? LifeBoardJournalAudioFiles.delete(relativePath: path) }
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
        // Mood is protected journal content; Spotlight only ever sees the
        // day's existence, never what it contains.
        attributes.contentDescription = "Private journal day"
        attributes.contentCreationDate = day.day
        attributes.keywords = ["journal", "reflection"]
        attributes.contentURL = URL(string: "lifeboard://journal/\(day.id.uuidString)")
        let item = CSSearchableItem(uniqueIdentifier: "lifeboard-journal-\(day.id.uuidString)", domainIdentifier: "com.lifeboard.private-journal", attributeSet: attributes)
        try? await CSSearchableIndex.default().indexSearchableItems([item])
    }

    static func remove(dayID: UUID) async {
        try? await CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["lifeboard-journal-\(dayID.uuidString)"])
    }
}
