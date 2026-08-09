import AVFAudio
import CoreSpotlight
import Foundation
import JournalFoundation
import LocalAuthentication
import JournalSecurityKit
import Observation
import PhotosUI
import ReflectionKit
import Speech
import SwiftUI
import TranscriptionKit
import UIKit
import UniformTypeIdentifiers
import WatchCaptureKit

// MARK: - Track module

@MainActor
@Observable
final class TrackStore {
    private(set) var trackers: [TrackerDefinitionValue] = []
    private(set) var trackerEntries: [TrackerEntryValue] = []
    private(set) var checkIns: [MoodEnergyCheckInValue] = []
    private(set) var medications: [MedicationDefinitionValue] = []
    private(set) var medicationSchedules: [MedicationScheduleValue] = []
    private(set) var medicationEvents: [MedicationEventValue] = []
    private(set) var fastingSessions: [FastingSessionValue] = []
    private(set) var correctionReceipts: [TrackCorrectionReceipt] = []
    private(set) var trackerExportURLs: [UUID: URL] = [:]
    private(set) var medicationExportURLs: [UUID: URL] = [:]
    private(set) var isLoading = false
    var errorMessage: String?

    let healthStore: HealthStore
    let repository: any PhaseIIRepository
    private let trackerService: TrackerDefinitionService
    private let medicationService: MedicationScheduleService
    private let fastingTimerStore: FastingTimerStore
    private let correctionReceiptRepository: any TrackCorrectionReceiptRepository

    init(
        repository: any PhaseIIRepository,
        healthStore: HealthStore = HealthStore(),
        correctionReceiptRepository: any TrackCorrectionReceiptRepository = LocalTrackCorrectionReceiptRepository.shared
    ) {
        self.repository = repository
        self.healthStore = healthStore
        trackerService = TrackerDefinitionService(repository: repository)
        medicationService = MedicationScheduleService(repository: repository)
        fastingTimerStore = FastingTimerStore(
            repository: FastingRepositoryAdapter(repository: repository)
        )
        self.correctionReceiptRepository = correctionReceiptRepository
    }

    var activeFast: FastingSessionValue? {
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

    func saveMood(_ mood: JournalMood, energy: Int?) async {
        do {
            try await repository.saveMoodCheckIn(.init(mood: mood, energy: energy))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveTracker(
        _ tracker: TrackerDefinitionValue,
        sensitiveHomeAuthorized: Bool = false
    ) async {
        do {
            try await trackerService.saveDefinition(
                tracker,
                sensitiveHomeAuthorized: sensitiveHomeAuthorized
            )
            await TrackerReminderCoordinator.shared.synchronize(tracker)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func archiveTracker(_ tracker: TrackerDefinitionValue) async {
        do {
            try await trackerService.archiveDefinition(tracker)
            var archived = tracker
            archived.isArchived = true
            await TrackerReminderCoordinator.shared.synchronize(archived)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteTracker(_ tracker: TrackerDefinitionValue) async {
        var archived = tracker
        archived.isArchived = true
        do {
            await TrackerReminderCoordinator.shared.synchronize(archived)
            try await trackerService.deleteDefinition(id: tracker.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func correct(_ entry: TrackerEntryValue, numericValue: Double?, booleanValue: Bool?, note: String?) async {
        if let tracker = trackers.first(where: { $0.id == entry.trackerID }) {
            let value = Self.trackerValue(
                for: tracker,
                numericValue: numericValue,
                booleanValue: booleanValue,
                note: note
            )
            guard let value else {
                errorMessage = TrackerDefinitionServiceError.valueTypeMismatch.localizedDescription
                return
            }
            await correct(entry, tracker: tracker, value: value, note: note)
            return
        }
        errorMessage = TrackerDefinitionServiceError.valueTypeMismatch.localizedDescription
    }

    func correct(
        _ entry: TrackerEntryValue,
        tracker: TrackerDefinitionValue,
        value: TrackerValue,
        note: String?
    ) async {
        var corrected = entry
        Self.apply(value, to: &corrected, tracker: tracker)
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        corrected.note = trimmedNote.isEmpty ? nil : trimmedNote
        do {
            try await applyCorrection(previous: .tracker(entry), corrected: .tracker(corrected))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func log(_ tracker: TrackerDefinitionValue, numericValue: Double? = nil, booleanValue: Bool? = nil) async {
        guard let value = Self.trackerValue(
            for: tracker,
            numericValue: numericValue,
            booleanValue: booleanValue,
            note: nil
        ) else {
            errorMessage = TrackerDefinitionServiceError.valueTypeMismatch.localizedDescription
            return
        }
        await log(tracker, value: value)
    }

    func log(
        _ tracker: TrackerDefinitionValue,
        value: TrackerValue,
        note: String? = nil,
        at timestamp: Date = Date()
    ) async {
        var entry = TrackerEntryValue(
            trackerID: tracker.id,
            timestamp: timestamp,
            note: note,
            value: value
        )
        Self.apply(value, to: &entry, tracker: tracker)
        do {
            try await trackerService.saveEntry(entry)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func prepareTrackerExport(
        _ tracker: TrackerDefinitionValue,
        format: TrackerExportFormat
    ) async {
        do {
            let authorized = tracker.effectivePrivacyClass == .sensitive ? Set([tracker.id]) : []
            let data = try await trackerService.export(
                trackerIDs: Set([tracker.id]),
                format: format,
                authorizedSensitiveIDs: authorized
            )
            let fileExtension: String
            switch format {
            case .csv: fileExtension = "csv"
            case .json: fileExtension = "json"
            }
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("LifeBoard-\(tracker.id.uuidString).\(fileExtension)")
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            trackerExportURLs[tracker.id] = url
        } catch { errorMessage = error.localizedDescription }
    }

    func prepareMedicationExport(_ medication: MedicationDefinitionValue) async {
        do {
            let data = try await medicationService.export(medication: medication)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("LifeBoard-Medication-\(medication.id.uuidString).json")
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            medicationExportURLs[medication.id] = url
        } catch { errorMessage = error.localizedDescription }
    }

    private static func trackerValue(
        for tracker: TrackerDefinitionValue,
        numericValue: Double?,
        booleanValue: Bool?,
        note: String?
    ) -> TrackerValue? {
        switch tracker.effectiveValueType {
        case .boolean:
            return booleanValue.map(TrackerValue.boolean)
        case .count:
            return numericValue.map { .count(Int($0.rounded())) }
        case .quantity:
            return numericValue.map { .quantity($0, unit: tracker.unitLabel) }
        case .rating:
            return numericValue.map(TrackerValue.rating)
        case .duration:
            return numericValue.map(TrackerValue.duration)
        case .text:
            return note.flatMap { $0.isEmpty ? nil : .text($0) }
        case .choice:
            return note.flatMap { $0.isEmpty ? nil : .choice($0) }
        case .timestamp:
            return .timestamp(Date())
        }
    }

    private static func apply(
        _ value: TrackerValue,
        to entry: inout TrackerEntryValue,
        tracker: TrackerDefinitionValue
    ) {
        entry.value = value
        entry.numericValue = nil
        entry.booleanValue = nil
        switch value {
        case .boolean(let value):
            entry.booleanValue = value
        case .count(let value):
            entry.numericValue = Double(value)
        case .quantity(let value, _), .rating(let value), .duration(let value):
            entry.numericValue = value
        case .text(let value), .choice(let value):
            if entry.note?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                entry.note = value
            }
        case .timestamp(let value):
            entry.timestamp = value
        }
        if case .quantity(let value, let unit) = value,
           unit == nil,
           tracker.unitLabel != nil {
            entry.value = .quantity(value, unit: tracker.unitLabel)
        }
    }

    func saveMedication(
        _ medication: MedicationDefinitionValue,
        schedule: MedicationScheduleValue
    ) async {
        do {
            try medicationService.validateSchedule(schedule)
            try await medicationService.saveDefinition(medication)
            try await medicationService.saveSchedule(schedule)
            await MedicationReminderCoordinator.shared.synchronize(medication: medication, schedule: schedule)
            if let scheduledAt = Self.nextScheduledDate(for: schedule, after: Date()) {
                let existing = medicationEvents.first(where: {
                    $0.medicationID == medication.id
                        && $0.status == .scheduled
                        && Calendar.current.isDate($0.scheduledAt, inSameDayAs: scheduledAt)
                })
                try await medicationService.saveEvent(medication: medication, event: .init(
                    id: existing?.id ?? UUID(),
                    medicationID: medication.id,
                    scheduledAt: scheduledAt,
                    status: .scheduled
                ))
            }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func archiveMedication(_ medication: MedicationDefinitionValue) async {
        var value = medication
        value.isArchived = true
        value.updatedAt = Date()
        do {
            try await medicationService.archiveDefinition(value)
            if let schedule = medicationSchedules.first(where: { $0.medicationID == medication.id }) {
                await MedicationReminderCoordinator.shared.synchronize(medication: value, schedule: schedule)
            }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func deleteMedication(_ medication: MedicationDefinitionValue) async {
        var archived = medication
        archived.isArchived = true
        do {
            for schedule in medicationSchedules where schedule.medicationID == medication.id {
                await MedicationReminderCoordinator.shared.synchronize(medication: archived, schedule: schedule)
            }
            try await medicationService.deleteDefinition(id: medication.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func resolveMedication(_ medication: MedicationDefinitionValue, status: MedicationEventStatus) async {
        let existing = medicationEvents.first(where: {
            $0.medicationID == medication.id
                && Calendar.current.isDateInToday($0.scheduledAt)
                && $0.status == .scheduled
        })
        let event = MedicationEventValue(
            id: existing?.id ?? UUID(),
            medicationID: medication.id,
            scheduledAt: existing?.scheduledAt ?? Date(),
            status: status,
            resolvedAt: Date()
        )
        do {
            _ = try await medicationService.resolve(
                medication: medication,
                event: event,
                as: status,
                at: event.resolvedAt ?? Date()
            )
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func resolveMedication(
        _ medication: MedicationDefinitionValue,
        event: MedicationEventValue,
        status: MedicationEventStatus
    ) async {
        do {
            _ = try await medicationService.resolve(
                medication: medication,
                event: event,
                as: status
            )
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func correctMedicationEvent(
        _ event: MedicationEventValue,
        status: MedicationEventStatus,
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

    func correctFast(_ session: FastingSessionValue, startDelta: TimeInterval = 0, endDelta: TimeInterval = 0) async {
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
        case .tracker(let value): try await trackerService.saveEntry(value)
        case .mood(let value): try await repository.saveMoodCheckIn(value)
        case .medication(let value):
            guard let medication = medications.first(where: { $0.id == value.medicationID }) else {
                throw MedicationScheduleServiceError.eventOutsideActiveRange
            }
            try await medicationService.saveEvent(medication: medication, event: value)
        case .fasting(let value): try await repository.saveFastingSession(value)
        case .hydration, .sleep: throw TrackCorrectionReceiptFailure.mismatchedPayload
        }
    }

    private static func nextScheduledDate(
        for schedule: MedicationScheduleValue,
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

struct TrackRootView: View {
    enum Module: String, CaseIterable, Identifiable {
        case overview = "Overview"
        case habits = "Habits"
        case trackers = "Trackers"
        case journal = "Journal"
        case notes = "Notes"
        var id: String { rawValue }
    }

    @State private var store: TrackStore
    @State private var module: Module = .overview
    @State private var showsMood = false
    @State private var mood: JournalMood = .none
    @State private var showsTrackerComposer = false
    @State private var editingTracker: TrackerDefinitionValue?
    @State private var loggingTracker: TrackerDefinitionValue?
    @State private var trackerTemplateSeed: TrackerDefinitionValue?
    @State private var showsTrackerTemplates = false
    @State private var historyTracker: TrackerDefinitionValue?
    @State private var showsMedicationComposer = false
    @State private var editingMedication: MedicationDefinitionValue?
    @State private var historyMedication: MedicationDefinitionValue?
    @State private var deletingTracker: TrackerDefinitionValue?
    @State private var deletingMedication: MedicationDefinitionValue?
    @State private var showsFastingComposer = false
    @State private var reviewsFastCompletion = false
    @State private var showsFastingHistory = false
    private let onOpenHabitBoard: () -> Void
    private let onOpenHealth: () -> Void
    @Environment(PresentationPreferences.self) private var preferences

    init(
        repository: any PhaseIIRepository,
        initialModule: Module = .overview,
        onOpenHabitBoard: @escaping () -> Void = {},
        onOpenHealth: @escaping () -> Void = {}
    ) {
        _store = State(initialValue: TrackStore(repository: repository))
        _module = State(initialValue: initialModule)
        self.onOpenHabitBoard = onOpenHabitBoard
        self.onOpenHealth = onOpenHealth
    }

    var body: some View {
        let palette = DaypartTokens.palette(for: preferences.resolvedDaypart())
        ZStack {
            AtmosphereView(
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
                        JournalModuleView(repository: store.repository)
                    case .notes:
                        KnowledgeModuleView(repository: store.repository)
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
            JournalMoodDialSheet(selectedMood: $mood) { energy in
                Task { await store.saveMood(mood, energy: energy) }
            }
        }
        .sheet(isPresented: $showsTrackerComposer, onDismiss: {
            editingTracker = nil
            trackerTemplateSeed = nil
        }) {
            TrackerComposer(
                existing: editingTracker,
                seed: trackerTemplateSeed
            ) { tracker, sensitiveHomeAuthorized in
                await store.saveTracker(
                    tracker,
                    sensitiveHomeAuthorized: sensitiveHomeAuthorized
                )
                return store.errorMessage == nil
            }
        }
        .sheet(isPresented: $showsTrackerTemplates) {
            TrackerTemplatePicker { template in
                trackerTemplateSeed = template.instantiate()
                showsTrackerTemplates = false
                showsTrackerComposer = true
            }
        }
        .sheet(item: $loggingTracker) { tracker in
            TrackerValueCaptureView(tracker: tracker) { value, note, timestamp in
                await store.log(tracker, value: value, note: note, at: timestamp)
                loggingTracker = nil
                return store.errorMessage == nil
            }
        }
        .sheet(item: $historyTracker) { tracker in
            TrackerHistoryView(
                tracker: tracker,
                entries: store.trackerEntries.filter { $0.trackerID == tracker.id },
                activeReceipt: { store.activeCorrection(domain: .tracker, sourceID: $0) },
                onUndo: { await store.undoCorrection($0) },
                onCorrect: { (
                    entry: TrackerEntryValue,
                    value: TrackerValue,
                    note: String?
                ) async -> Bool in
                    await store.correct(entry, tracker: tracker, value: value, note: note)
                    return store.errorMessage == nil
                }
            )
        }
        .sheet(isPresented: $showsMedicationComposer, onDismiss: { editingMedication = nil }) {
            MedicationComposer(
                existing: editingMedication,
                existingSchedule: editingMedication.flatMap { medication in
                    store.medicationSchedules.first(where: { $0.medicationID == medication.id })
                }
            ) { medication, schedule in
                Task {
                    await store.saveMedication(medication, schedule: schedule)
                    // A dose window with no notification is a window the user
                    // has to remember unaided, which defeats the point.
                    await PermissionPrimingCoordinator.shared.offerAfterReward(
                        kind: .notifications,
                        trigger: "medication_scheduled"
                    )
                }
            }
        }
        .sheet(item: $historyMedication) { medication in
            MedicationHistoryView(
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
            FastingComposer { target, reminderOffsets in
                Task {
                    await store.toggleFast(target: target, reminderOffsets: reminderOffsets)
                    // Connecting nutrition powers the "last meal" fasting suggestion;
                    // fasting itself is never written to Apple Health.
                    await HealthCoordinator.shared.jitCoordinator.offerConnectAfterReward(
                        leadDomain: .nutrition,
                        trigger: "fasting_start"
                    )
                }
            }
        }
        .sheet(isPresented: $showsFastingHistory) {
            FastingHistoryView(
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

    private func modulePicker(palette: DaypartPalette) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableModules) { item in
                    Button(item.rawValue) { module = item }
                        .buttonStyle(.lifeBoardChip)
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

    private func overview(palette: DaypartPalette) -> some View {
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
                    Button(action: onOpenHealth) {
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

    private func overviewTile(title: String, value: String, symbol: String, palette: DaypartPalette) -> some View {
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

    private func careCard(palette: DaypartPalette) -> some View {
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

    private func fastingCard(palette: DaypartPalette) -> some View {
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

    private func dueTrackersCard(palette: DaypartPalette) -> some View {
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

    private func trackerRow(_ tracker: TrackerDefinitionValue, palette: DaypartPalette) -> some View {
        HStack {
            Image(systemName: trackerSymbol(tracker.kind)).frame(width: 28)
            VStack(alignment: .leading) {
                Text(tracker.title).font(.headline)
                Text(tracker.kind.rawValue.capitalized).font(.caption).foregroundStyle(palette.color(for: .foregroundSecondary))
            }
            Spacer()
            Button("Record") {
                loggingTracker = tracker
            }
            .buttonStyle(.lifeBoardChip)
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

    private func trackers(palette: DaypartPalette) -> some View {
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

    private func habitsBridge(palette: DaypartPalette) -> some View {
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

    private func trackerSymbol(_ kind: TrackerKind) -> String {
        switch kind {
        case .boolean: "checkmark.circle"
        case .count: "number.circle"
        case .quantity: "ruler"
        case .rating: "slider.horizontal.3"
        case .duration: "timer"
        case .text: "text.cursor"
        case .choice: "list.bullet.circle"
        case .timestamp: "clock.badge.checkmark"
        }
    }

    private static func duration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3_600
        let minutes = (Int(interval) % 3_600) / 60
        return "\(hours)h \(minutes)m elapsed"
    }
}

/// Native Phase 2 Track areas.
///
/// This is intentionally not another root or modal mini-app. It is the
/// Medication/Tracker content mounted by `TrackLens.areas`, deep links, and
/// universal capture. All entry points share this store and the same composer,
/// history, correction, and receipt components.
struct BehaviorNativeAreasView: View {
    enum Area: String, CaseIterable, Identifiable {
        case medication = "Medication"
        case trackers = "Trackers"
        var id: String { rawValue }
    }

    @State private var store: TrackStore
    @State private var area: Area
    @State private var showsTrackerComposer = false
    @State private var editingTracker: TrackerDefinitionValue?
    @State private var loggingTracker: TrackerDefinitionValue?
    @State private var trackerTemplateSeed: TrackerDefinitionValue?
    @State private var showsTrackerTemplates = false
    @State private var historyTracker: TrackerDefinitionValue?
    @State private var deletingTracker: TrackerDefinitionValue?
    @State private var showsMedicationComposer = false
    @State private var editingMedication: MedicationDefinitionValue?
    @State private var historyMedication: MedicationDefinitionValue?
    @State private var deletingMedication: MedicationDefinitionValue?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(
        repository: any PhaseIIRepository,
        initialArea: Area = .medication
    ) {
        _store = State(initialValue: TrackStore(repository: repository))
        _area = State(initialValue: initialArea)
    }

    var body: some View {
        ZStack {
            Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea()
            ScrollView {
                LazyVStack(spacing: dynamicTypeSize.isAccessibilitySize ? 24 : 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(area == .trackers ? "Your signals" : "Care, clearly recorded")
                            .font(Typography.screenTitle())
                        Text(area == .trackers
                            ? "Keep only what helps you notice something useful."
                            : "A calm place for schedules, decisions, and the history you chose to keep.")
                            .font(Typography.body())
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    LensPicker(
                        "Care area",
                        selection: $area,
                        values: Area.allCases,
                        identifierPrefix: "track.behavior.area",
                        title: \.rawValue,
                        identifier: { $0.rawValue.lowercased() }
                    )

                    Group {
                        switch area {
                        case .medication: medicationArea
                        case .trackers: trackerArea
                        }
                    }
                    .id(area)
                    .transition(.blurReplace.combined(with: .opacity))
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
        .lifeBoardMotion(.selection, value: area)
        .navigationTitle(area.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.load() }
        .refreshable { await store.load() }
        .alert("Track needs attention", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if $0 == false { store.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: {
            Text(store.errorMessage ?? "")
        }
        .sheet(isPresented: $showsTrackerComposer, onDismiss: {
            editingTracker = nil
            trackerTemplateSeed = nil
        }) {
            TrackerComposer(
                existing: editingTracker,
                seed: trackerTemplateSeed
            ) { tracker, sensitiveHomeAuthorized in
                await store.saveTracker(
                    tracker,
                    sensitiveHomeAuthorized: sensitiveHomeAuthorized
                )
                return store.errorMessage == nil
            }
        }
        .sheet(isPresented: $showsTrackerTemplates) {
            TrackerTemplatePicker { template in
                trackerTemplateSeed = template.instantiate()
                showsTrackerTemplates = false
                showsTrackerComposer = true
            }
        }
        .sheet(item: $loggingTracker) { tracker in
            TrackerValueCaptureView(tracker: tracker) { value, note, timestamp in
                await store.log(tracker, value: value, note: note, at: timestamp)
                loggingTracker = nil
                return store.errorMessage == nil
            }
        }
        .sheet(item: $historyTracker) { tracker in
            TrackerHistoryView(
                tracker: tracker,
                entries: store.trackerEntries.filter { $0.trackerID == tracker.id },
                activeReceipt: { store.activeCorrection(domain: .tracker, sourceID: $0) },
                onUndo: { await store.undoCorrection($0) },
                onCorrect: { (
                    entry: TrackerEntryValue,
                    value: TrackerValue,
                    note: String?
                ) async -> Bool in
                    await store.correct(entry, tracker: tracker, value: value, note: note)
                    return store.errorMessage == nil
                }
            )
        }
        .sheet(isPresented: $showsMedicationComposer, onDismiss: { editingMedication = nil }) {
            MedicationComposer(
                existing: editingMedication,
                existingSchedule: editingMedication.flatMap { medication in
                    store.medicationSchedules.first { $0.medicationID == medication.id }
                }
            ) { medication, schedule in
                Task {
                    await store.saveMedication(medication, schedule: schedule)
                    await PermissionPrimingCoordinator.shared.offerAfterReward(
                        kind: .notifications,
                        trigger: "medication_scheduled"
                    )
                }
            }
        }
        .sheet(item: $historyMedication) { medication in
            MedicationHistoryView(
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
        .confirmationDialog(
            "Delete tracker and its history?",
            isPresented: Binding(
                get: { deletingTracker != nil },
                set: { if $0 == false { deletingTracker = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete tracker", role: .destructive) {
                guard let tracker = deletingTracker else { return }
                deletingTracker = nil
                Task { await store.deleteTracker(tracker) }
            }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog(
            "Delete medication and its history?",
            isPresented: Binding(
                get: { deletingMedication != nil },
                set: { if $0 == false { deletingMedication = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete medication", role: .destructive) {
                guard let medication = deletingMedication else { return }
                deletingMedication = nil
                Task { await store.deleteMedication(medication) }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var medicationArea: some View {
        VStack(spacing: 12) {
            areaHeader(
                title: "Medication",
                detail: "Only the status you choose is recorded. Silence remains unresolved.",
                symbol: "pills",
                actionTitle: "Add"
            ) {
                editingMedication = nil
                showsMedicationComposer = true
            }
            if store.medications.isEmpty {
                nativeEmpty(
                    "No medication reminders",
                    detail: "Add one only when a neutral schedule and history would be useful.",
                    symbol: "pills"
                )
            } else {
                ForEach(store.medications) { medication in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "pills.fill")
                                .foregroundStyle(Color(LifeBoardColorTokens.foundationApricotAccent))
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(medication.name).font(.headline)
                                Text(medication.dosageText ?? "No dose label")
                                    .font(.caption)
                                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                                Text(medicationDefinitionSummary(medication))
                                    .font(.caption2)
                                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            }
                            Spacer()
                            Menu {
                                Button("History", systemImage: "clock.arrow.circlepath") {
                                    historyMedication = medication
                                }
                                Button("Edit", systemImage: "pencil") {
                                    editingMedication = medication
                                    showsMedicationComposer = true
                                }
                                Button("Archive", systemImage: "archivebox") {
                                    Task { await store.archiveMedication(medication) }
                                }
                                Button("Prepare history export", systemImage: "square.and.arrow.up") {
                                    Task { await store.prepareMedicationExport(medication) }
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deletingMedication = medication
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Actions for \(medication.name)")
                        }

                        let event = store.medicationEvents
                            .filter { $0.medicationID == medication.id }
                            .sorted { $0.scheduledAt > $1.scheduledAt }
                            .first
                        if let event, event.status == .scheduled || event.status == .unresolved {
                            HStack(spacing: 8) {
                                medicationResolution("Taken", event: event, status: .taken)
                                medicationResolution("Skipped", event: event, status: .skipped)
                                Menu {
                                    medicationResolutionMenu(
                                        "Snooze 15 minutes",
                                        event: event,
                                        status: .snoozed,
                                        scheduledAt: event.scheduledAt.addingTimeInterval(15 * 60)
                                    )
                                    medicationResolutionMenu(
                                        "Reschedule one hour",
                                        event: event,
                                        status: .rescheduled,
                                        scheduledAt: event.scheduledAt.addingTimeInterval(60 * 60)
                                    )
                                    medicationResolutionMenu(
                                        "Leave unresolved",
                                        event: event,
                                        status: .unresolved,
                                        scheduledAt: event.scheduledAt
                                    )
                                    Button("Choose another time", systemImage: "calendar.badge.clock") {
                                        historyMedication = medication
                                    }
                                } label: {
                                    Label("More", systemImage: "ellipsis")
                                        .frame(minHeight: 44)
                                }
                                .buttonStyle(.lifeBoardChip)
                                .accessibilityLabel("More status choices for \(medication.name)")
                            }
                        } else {
                            Label("No decision waiting", systemImage: "checkmark.circle")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color(LifeBoardColorTokens.foundationSageAccent))
                        }
                        if let exportURL = store.medicationExportURLs[medication.id] {
                            ShareLink(item: exportURL) {
                                Label("Share history export", systemImage: "square.and.arrow.up")
                                    .frame(minHeight: 44)
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }
                    .nativeBehaviorOpenRow()
                }
            }
        }
    }

    private var trackerArea: some View {
        VStack(spacing: 12) {
            areaHeader(
                title: "Trackers",
                detail: "One honest signal at a time. Every entry stays editable.",
                symbol: "chart.bar.doc.horizontal",
                actionTitle: "New"
            ) {
                editingTracker = nil
                showsTrackerComposer = true
            }
            Button {
                showsTrackerTemplates = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.title3)
                        .frame(width: 36, height: 36)
                        .background(Color(LifeBoardColorTokens.foundationSurfaceSelected), in: Circle())
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Start with a gentle template")
                            .font(.body.weight(.semibold))
                        Text("A useful starting point, fully yours to edit")
                            .font(.caption)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                }
                .padding(14)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
                .lifeBoardClaySurface(.well, cornerRadius: 16)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("track.tracker.templates")
            if store.trackers.isEmpty {
                nativeEmpty(
                    "Nothing to track yet",
                    detail: "Start with one signal that helps you make a decision.",
                    symbol: "chart.xyaxis.line"
                )
            } else {
                ForEach(store.trackers) { tracker in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 12) {
                            Image(systemName: trackerSymbol(tracker.kind))
                                .foregroundStyle(Color(LifeBoardColorTokens.foundationFocusRing))
                                .frame(width: 32, height: 32)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(tracker.title).font(.headline)
                                Text(trackerDefinitionSummary(tracker))
                                    .font(.caption)
                                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            }
                            Spacer()
                            Menu {
                                Button("History", systemImage: "clock.arrow.circlepath") {
                                    historyTracker = tracker
                                }
                                Button("Edit", systemImage: "pencil") {
                                    editingTracker = tracker
                                    showsTrackerComposer = true
                                }
                                Button("Archive", systemImage: "archivebox") {
                                    Task { await store.archiveTracker(tracker) }
                                }
                                Button("Prepare CSV export", systemImage: "tablecells") {
                                    Task { await store.prepareTrackerExport(tracker, format: .csv) }
                                }
                                Button("Prepare JSON export", systemImage: "curlybraces") {
                                    Task { await store.prepareTrackerExport(tracker, format: .json) }
                                }
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    deletingTracker = tracker
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .frame(width: 44, height: 44)
                            }
                            .accessibilityLabel("Actions for \(tracker.title)")
                        }
                        Button("Record value") {
                            Haptic.pick.play()
                            loggingTracker = tracker
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color(LifeBoardColorTokens.inkPrimary))
                        .frame(minHeight: 44)
                        .accessibilityIdentifier("track.tracker.log.\(tracker.id.uuidString)")
                        if let exportURL = store.trackerExportURLs[tracker.id] {
                            ShareLink(item: exportURL) {
                                Label("Share prepared export", systemImage: "square.and.arrow.up")
                                    .frame(minHeight: 44)
                            }
                            .font(.caption.weight(.semibold))
                        }
                    }
                    .nativeBehaviorOpenRow()
                    .privacySensitive(tracker.effectivePrivacyClass != .standard)
                }
            }
        }
    }

    private func areaHeader(
        title: String,
        detail: String,
        symbol: String,
        actionTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Label(title, systemImage: symbol)
                    .font(.title3.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            Spacer()
            Button(actionTitle, systemImage: "plus", action: action)
                .buttonStyle(.lifeBoardChip)
                .frame(minHeight: 44)
                .accessibilityIdentifier(title == "Trackers" ? "track.tracker.new" : "track.medication.new")
        }
        .padding(.top, 4)
    }

    private func medicationResolution(
        _ title: String,
        event: MedicationEventValue,
        status: MedicationEventStatus
    ) -> some View {
        Button(title) {
            Task {
                if status == .snoozed {
                    await store.correctMedicationEvent(
                        event,
                        status: .snoozed,
                        scheduledAt: event.scheduledAt,
                        resolvedAt: Date(),
                        note: event.note
                    )
                } else {
                    guard let medication = store.medications.first(where: {
                        $0.id == event.medicationID
                    }) else { return }
                    await store.resolveMedication(medication, event: event, status: status)
                }
            }
        }
        .buttonStyle(.lifeBoardChip)
        .controlSize(.small)
        .frame(minHeight: 44)
    }

    private func medicationResolutionMenu(
        _ title: String,
        event: MedicationEventValue,
        status: MedicationEventStatus,
        scheduledAt: Date
    ) -> some View {
        Button(title) {
            Task {
                await store.correctMedicationEvent(
                    event,
                    status: status,
                    scheduledAt: scheduledAt,
                    resolvedAt: status == .unresolved ? nil : Date(),
                    note: event.note
                )
            }
        }
    }

    private func nativeEmpty(_ title: String, detail: String, symbol: String) -> some View {
        ContentUnavailableView {
            Label(title, systemImage: symbol)
        } description: {
            Text(detail)
        }
        .frame(maxWidth: .infinity, minHeight: 190)
        .nativeBehaviorSurface()
    }

    private func trackerSymbol(_ kind: TrackerKind) -> String {
        switch kind {
        case .boolean: "checkmark.circle"
        case .count: "number.circle"
        case .quantity: "ruler"
        case .rating: "slider.horizontal.3"
        case .duration: "timer"
        case .text: "text.cursor"
        case .choice: "list.bullet.circle"
        case .timestamp: "clock.badge.checkmark"
        }
    }

    private func trackerDefinitionSummary(_ tracker: TrackerDefinitionValue) -> String {
        var parts = [tracker.effectiveValueType.rawValue.capitalized]
        parts.append(tracker.effectiveAggregation.displayName)
        parts.append(tracker.effectivePrivacyClass.displayName)
        if tracker.permitsHomeProjection { parts.append("Home allowed") }
        return parts.joined(separator: " · ")
    }

    private func medicationDefinitionSummary(_ medication: MedicationDefinitionValue) -> String {
        var parts: [String] = []
        if let form = medication.formRaw, form.isEmpty == false { parts.append(form.capitalized) }
        if let end = medication.endDate {
            parts.append("through \(end.formatted(date: .abbreviated, time: .omitted))")
        } else if medication.startDate != nil {
            parts.append("no end date")
        }
        if let remaining = medication.refillRemaining {
            parts.append("\(remaining.formatted()) remaining")
        }
        return parts.isEmpty ? "Active schedule" : parts.joined(separator: " · ")
    }
}

/// Route-level rollback for the Phase 2 behavior flagship. The disabled branch
/// restores the previous production Track composer; it does not initialize any
/// of the new native-area state.
struct BehaviorAreaRouteView: View {
    let repository: any PhaseIIRepository
    var initialArea: BehaviorNativeAreasView.Area = .medication
    var onOpenHabitBoard: () -> Void = {}
    var onOpenHealth: () -> Void = {}

    @ViewBuilder
    var body: some View {
        if V2FeatureFlags.trackBehaviorFlagshipV1Enabled {
            BehaviorNativeAreasView(
                repository: repository,
                initialArea: initialArea
            )
        } else {
            TrackRootView(
                repository: repository,
                initialModule: initialArea == .trackers ? .trackers : .overview,
                onOpenHabitBoard: onOpenHabitBoard,
                onOpenHealth: onOpenHealth
            )
        }
    }
}

private extension View {
    func nativeBehaviorSurface() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .lifeBoardClaySurface(.resting, cornerRadius: 20)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Color(LifeBoardColorTokens.foundationHairline), lineWidth: 1)
            }
    }

    func nativeBehaviorOpenRow() -> some View {
        padding(.horizontal, 4)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(LifeBoardColorTokens.foundationHairline))
                    .frame(height: 1)
            }
    }
}

private extension TrackerAggregation {
    var displayName: String {
        switch self {
        case .latest: "Latest"
        case .sum: "Total"
        case .average: "Average"
        case .minimum: "Minimum"
        case .maximum: "Maximum"
        case .count: "Entry count"
        }
    }
}

private extension TrackerPrivacyClass {
    var displayName: String {
        switch self {
        case .standard: "Standard"
        case .personal: "Personal"
        case .sensitive: "Sensitive"
        }
    }
}

private struct TrackerTemplatePicker: View {
    let onSelect: (TrackerTemplate) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ZStack {
                Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea()
                ScrollView {
                    LazyVStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Begin with something familiar")
                                .font(Typography.screenTitle())
                            Text("Pick a starting shape. You’ll review every detail before anything is created.")
                                .font(Typography.body())
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.bottom, 8)

                        ForEach(TrackerTemplate.allCases) { template in
                            Button {
                                Haptic.pick.play()
                                onSelect(template)
                            } label: {
                                HStack(alignment: .top, spacing: 14) {
                                    Image(systemName: symbol(for: template))
                                        .font(.title3.weight(.semibold))
                                        .frame(width: 42, height: 42)
                                        .background(
                                            Color(LifeBoardColorTokens.foundationSurfaceSelected),
                                            in: Circle()
                                        )
                                    VStack(alignment: .leading, spacing: 5) {
                                        HStack(spacing: 7) {
                                            Text(template.title)
                                                .font(.headline)
                                            if template.isHealthLike {
                                                Text("Personal note")
                                                    .font(.caption2.weight(.semibold))
                                                    .padding(.horizontal, 7)
                                                    .padding(.vertical, 3)
                                                    .background(
                                                        Color(LifeBoardColorTokens.foundationSurfaceRecessed),
                                                        in: Capsule()
                                                    )
                                            }
                                        }
                                        Text(template.detail)
                                            .font(.subheadline)
                                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.right")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(Color(LifeBoardColorTokens.inkTertiary))
                                        .padding(.top, 13)
                                }
                                .padding(16)
                                .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                                .lifeBoardClaySurface(.resting, cornerRadius: 20)
                                .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Creates an editable tracker draft")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, dynamicTypeSize.isAccessibilitySize ? 48 : 32)
                }
            }
            .navigationTitle("Choose a template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationCornerRadius(28)
    }

    private func symbol(for template: TrackerTemplate) -> String {
        switch template {
        case .pain: "waveform.path.ecg"
        case .symptoms: "text.bubble"
        case .caffeine: "cup.and.saucer.fill"
        case .reading: "book.pages.fill"
        case .spending: "creditcard.fill"
        case .screenTime: "hourglass"
        }
    }
}

private struct TrackerCommitReceipt: Equatable, Sendable {
    let id = UUID()
}

private struct TrackerCommitBar: View {
    let title: String
    let phase: AsyncActionPhase<TrackerCommitReceipt>
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if case .recoverableFailure(let failure) = phase {
                Label(failure.message, systemImage: "exclamationmark.circle")
                    .font(.footnote)
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            CommitControl(
                title: title,
                runningTitle: "Saving",
                successTitle: "Saved",
                phase: phase,
                isEnabled: isEnabled,
                action: action
            )
        }
        .padding(10)
        .lifeBoardSystemGlass(
            .regular,
            in: RoundedRectangle(cornerRadius: 28, style: .continuous)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 4)
    }
}

struct TrackerComposer: View {
    let onSave: (TrackerDefinitionValue, Bool) async -> Bool
    private let existing: TrackerDefinitionValue?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var title = ""
    @State private var kind: TrackerKind = .boolean
    @State private var unit = ""
    @State private var target = 1.0
    @State private var rangeEnabled = false
    @State private var rangeMinimum = 0.0
    @State private var rangeMaximum = 10.0
    @State private var aggregation: TrackerAggregation = .latest
    @State private var privacyClass: TrackerPrivacyClass = .personal
    @State private var isHomeEligible = false
    @State private var choiceOptionsText = ""
    @State private var weekdays = Set(1...7)
    @State private var reminderEnabled = false
    @State private var reminderTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var commitPhase: AsyncActionPhase<TrackerCommitReceipt> = .idle
    @State private var typeBloomTrigger = 0
    @FocusState private var titleIsFocused: Bool

    init(
        existing: TrackerDefinitionValue? = nil,
        seed: TrackerDefinitionValue? = nil,
        onSave: @escaping (TrackerDefinitionValue, Bool) async -> Bool
    ) {
        self.existing = existing
        self.onSave = onSave
        let source = existing ?? seed
        _title = State(initialValue: source?.title ?? "")
        _kind = State(initialValue: source?.kind ?? .boolean)
        _unit = State(initialValue: source?.unitLabel ?? "")
        _target = State(initialValue: source?.targetValue ?? 1)
        _rangeEnabled = State(initialValue: source?.rangeMin != nil || source?.rangeMax != nil)
        _rangeMinimum = State(initialValue: source?.rangeMin ?? 0)
        _rangeMaximum = State(initialValue: source?.rangeMax ?? 10)
        _aggregation = State(initialValue: source?.effectiveAggregation ?? .latest)
        _privacyClass = State(initialValue: source?.effectivePrivacyClass ?? .personal)
        _isHomeEligible = State(initialValue: source?.isHomeEligible ?? false)
        _choiceOptionsText = State(initialValue: (source?.choiceOptions ?? []).joined(separator: "\n"))
        _weekdays = State(initialValue: source?.schedule ?? Set(1...7))
        let minutes = source?.reminderMinutes
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
            ZStack {
                Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 28 : 24) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(existing == nil ? "Make a signal yours" : "Tune this signal")
                                .font(Typography.screenTitle())
                            Text("Give it one clear purpose. You can change the details whenever life changes.")
                                .font(Typography.body())
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        trackerBuilderSection(
                            "The signal",
                            detail: "A short name is easiest to spot when you’re in a hurry."
                        ) {
                            TextField("What do you want to notice?", text: $title)
                                .focused($titleIsFocused)
                                .textFieldStyle(LifeBoardTextFieldStyle(isFocused: titleIsFocused))
                                .submitLabel(.next)
                                .accessibilityIdentifier("track.tracker.name")

                            Text("How will you record it?")
                                .font(.subheadline.weight(.semibold))
                            ScrollView(.horizontal) {
                                HStack(spacing: 10) {
                                    ForEach(TrackerKind.allCases, id: \.self) { value in
                                        trackerKindButton(value)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .scrollIndicators(.hidden)
                            .lifeboardClayPressBloom(
                                center: .center,
                                trigger: typeBloomTrigger,
                                tint: Color(LifeBoardColorTokens.foundationApricotAccent)
                            )

                    if kind == .quantity || kind == .duration {
                                labeledField(kind == .duration ? "Display unit" : "Unit") {
                                    TextField(kind == .duration ? "minutes, hours…" : "mL, km, ₹…", text: $unit)
                                        .multilineTextAlignment(.trailing)
                                }
                    }
                    if numericKinds.contains(kind) {
                                labeledField("Optional target") {
                                    TextField("Target", value: $target, format: .number)
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                }
                                Toggle("Keep entries within a range", isOn: $rangeEnabled)
                                    .tint(Color(LifeBoardColorTokens.foundationSageAccent))
                        if rangeEnabled {
                                    ViewThatFits {
                                        HStack(spacing: 10) { rangeField("Minimum", value: $rangeMinimum); rangeField("Maximum", value: $rangeMaximum) }
                                        VStack(spacing: 10) { rangeField("Minimum", value: $rangeMinimum); rangeField("Maximum", value: $rangeMaximum) }
                                    }
                            }
                        }
                    if kind == .choice {
                        TextField(
                            "Choices, one per line",
                            text: $choiceOptionsText,
                            axis: .vertical
                        )
                        .lineLimit(3...8)
                                .padding(12)
                                .background(Color(LifeBoardColorTokens.foundationSurfaceRecessed), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        Text("Keep at least two choices. Their wording stays unchanged in history and exports.")
                            .font(.caption)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    }

                            labeledField("Show in summaries") {
                                Picker("Show in summaries", selection: $aggregation) {
                                    ForEach(availableAggregations, id: \.self) {
                                        Text($0.displayName).tag($0)
                                    }
                                }
                                .labelsHidden()
                            }
                        }

                        trackerBuilderSection(
                            "Privacy",
                            detail: "Choose how quietly LifeBoard should hold this signal."
                        ) {
                            HStack(spacing: 8) {
                                ForEach(TrackerPrivacyClass.allCases, id: \.self) { value in
                                    privacyButton(value)
                                }
                            }
                            Toggle("May appear on Home", isOn: $isHomeEligible)
                                .tint(Color(LifeBoardColorTokens.foundationSageAccent))
                                .frame(minHeight: 44)
                            privacyExplanation
                        }

                        trackerBuilderSection(
                            "Rhythm",
                            detail: "Select the days when this should be easy to reach."
                        ) {
                            ScrollView(.horizontal) {
                                HStack(spacing: 8) {
                                    ForEach(1...7, id: \.self) { weekday in
                                        weekdayButton(weekday)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                            .scrollIndicators(.hidden)
                            Toggle("Give me a gentle reminder", isOn: $reminderEnabled)
                                .tint(Color(LifeBoardColorTokens.foundationSageAccent))
                                .frame(minHeight: 44)
                            if reminderEnabled {
                                DatePicker("Reminder time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                                    .datePickerStyle(.compact)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 120)
                }
            }
            .navigationTitle(existing == nil ? "New Tracker" : "Edit Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: kind) { _, newKind in
                if availableAggregations.contains(aggregation) == false {
                    aggregation = defaultAggregation(for: newKind)
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) {
                TrackerCommitBar(
                    title: existing == nil ? "Create tracker" : "Save changes",
                    phase: commitPhase,
                    isEnabled: isInvalid == false,
                    action: commit
                )
                .accessibilityIdentifier("track.tracker.commit")
            }
        }
        .presentationCornerRadius(28)
        .interactiveDismissDisabled(isRunning)
    }

    private var isRunning: Bool {
        if case .running = commitPhase { return true }
        return false
    }

    private func trackerBuilderSection<Content: View>(
        _ heading: String,
        detail: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text(heading).font(Typography.sectionTitle())
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.resting, cornerRadius: 20)
    }

    private func trackerKindButton(_ value: TrackerKind) -> some View {
        let selected = value == kind
        return Button {
            guard selected == false else { return }
            Haptic.pick.play()
            typeBloomTrigger += 1
            withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                kind = value
            }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: trackerKindSymbol(value))
                    .font(.body.weight(.semibold))
                Text(trackerKindTitle(value))
                    .font(.subheadline.weight(selected ? .bold : .semibold))
            }
            .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
            .padding(12)
            .frame(width: 112, height: 74, alignment: .leading)
            .lifeBoardClaySurface(selected ? .raised : .well, cornerRadius: 16)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(
                        selected
                            ? Color.lifeboard(.borderStrong)
                            : Color(LifeBoardColorTokens.foundationHairline),
                        lineWidth: selected ? 1.5 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("track.tracker.kind.\(value.rawValue)")
    }

    private func privacyButton(_ value: TrackerPrivacyClass) -> some View {
        let selected = value == privacyClass
        return Button {
            Haptic.pick.play()
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.24)) {
                privacyClass = value
                if value == .sensitive { isHomeEligible = false }
            }
        } label: {
            Text(value.displayName)
                .font(.footnote.weight(selected ? .bold : .semibold))
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    selected
                        ? Color(LifeBoardColorTokens.foundationSurfaceSelected)
                        : Color.clear,
                    in: Capsule()
                )
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder
    private var privacyExplanation: some View {
        let text = switch privacyClass {
        case .standard: "Available to the LifeBoard surfaces you choose, including Home."
        case .personal: "Kept private by default, with Home visibility under your control."
        case .sensitive: isHomeEligible
            ? "Home visibility is explicitly allowed. Widgets, notifications, and ordinary exports still stay private."
            : "Hidden from Home, widgets, notifications, summaries, and ordinary exports."
        }
        Label(text, systemImage: privacyClass == .sensitive ? "lock.fill" : "hand.raised.fill")
            .font(.caption)
            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func weekdayButton(_ weekday: Int) -> some View {
        let selected = weekdays.contains(weekday)
        return Button {
            Haptic.pick.play()
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                if selected { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
            }
        } label: {
            Text(Calendar.current.veryShortStandaloneWeekdaySymbols[weekday - 1])
                .font(.caption.weight(.bold))
                .frame(width: 44, height: 44)
                .background(
                    selected
                        ? Color(LifeBoardColorTokens.foundationSurfaceSelected)
                        : Color(LifeBoardColorTokens.foundationSurfaceRecessed),
                    in: Circle()
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func labeledField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.subheadline)
            Spacer(minLength: 8)
            content()
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 48)
        .background(Color(LifeBoardColorTokens.foundationSurfaceRecessed), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func rangeField(_ label: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.caption).foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            TextField(label, value: value, format: .number)
                .keyboardType(.decimalPad)
                .textFieldStyle(LifeBoardTextFieldStyle())
        }
    }

    private func trackerKindTitle(_ kind: TrackerKind) -> String {
        switch kind {
        case .boolean: "Yes / no"
        case .count: "Count"
        case .quantity: "Amount"
        case .rating: "Rating"
        case .duration: "Duration"
        case .text: "Note"
        case .choice: "Choice"
        case .timestamp: "Time"
        }
    }

    private func trackerKindSymbol(_ kind: TrackerKind) -> String {
        switch kind {
        case .boolean: "checkmark.circle"
        case .count: "number.circle"
        case .quantity: "ruler"
        case .rating: "slider.horizontal.3"
        case .duration: "timer"
        case .text: "text.cursor"
        case .choice: "list.bullet.circle"
        case .timestamp: "clock.badge.checkmark"
        }
    }

    private func commit() {
        guard isInvalid == false, isRunning == false else { return }
        let calendar = Calendar.current
        let reminderMinutes = reminderEnabled
            ? calendar.component(.hour, from: reminderTime) * 60 + calendar.component(.minute, from: reminderTime)
            : nil
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedUnit = unit.trimmingCharacters(in: .whitespacesAndNewlines)
        let definition = TrackerDefinitionValue(
            id: existing?.id ?? UUID(),
            title: trimmedTitle,
            kind: kind,
            unitLabel: trimmedUnit.isEmpty ? nil : trimmedUnit,
            targetValue: numericKinds.contains(kind) ? target : nil,
            schedule: weekdays,
            reminderMinutes: reminderMinutes,
            isArchived: existing?.isArchived ?? false,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date(),
            valueType: kind,
            rangeMin: rangeEnabled && numericKinds.contains(kind) ? rangeMinimum : nil,
            rangeMax: rangeEnabled && numericKinds.contains(kind) ? rangeMaximum : nil,
            aggregation: aggregation,
            privacyClass: privacyClass,
            isHomeEligible: isHomeEligible,
            choiceOptions: kind == .choice ? choiceOptions : nil
        )
        commitPhase = .running(progress: nil)
        Task {
            if await onSave(definition, privacyClass == .sensitive && isHomeEligible) {
                commitPhase = .success(receipt: .init())
                Haptic.commit.play()
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 360))
                dismiss()
            } else {
                commitPhase = .recoverableFailure(.init(
                    message: "This tracker could not be saved. Your choices are still here.",
                    recovery: .retry
                ))
                Haptic.fail.play()
            }
        }
    }

    private var numericKinds: Set<TrackerKind> {
        [.count, .quantity, .rating, .duration]
    }

    private var choiceOptions: [String] {
        choiceOptionsText
            .components(separatedBy: CharacterSet(charactersIn: ",\n"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .reduce(into: [String]()) { result, option in
                if result.contains(option) == false { result.append(option) }
            }
    }

    private var availableAggregations: [TrackerAggregation] {
        switch kind {
        case .boolean: [.latest, .count]
        case .count, .quantity, .duration: [.latest, .sum, .average, .minimum, .maximum, .count]
        case .rating: [.latest, .average, .minimum, .maximum, .count]
        case .text, .choice, .timestamp: [.latest, .count]
        }
    }

    private func defaultAggregation(for kind: TrackerKind) -> TrackerAggregation {
        switch kind {
        case .count, .quantity, .duration: .sum
        case .rating: .average
        case .boolean, .text, .choice, .timestamp: .latest
        }
    }

    private var isInvalid: Bool {
        title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || weekdays.isEmpty
            || (rangeEnabled && rangeMinimum > rangeMaximum)
            || (kind == .choice && choiceOptions.count < 2)
    }
}

private struct TrackerValueCaptureView: View {
    let tracker: TrackerDefinitionValue
    let title: String
    let onSave: (TrackerValue, String?, Date) async -> Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var booleanValue: Bool
    @State private var countValue: Int
    @State private var numericValue: Double
    @State private var durationMinutes: Double
    @State private var textValue: String
    @State private var choiceValue: String
    @State private var timestampValue: Date
    @State private var note: String
    @State private var commitPhase: AsyncActionPhase<TrackerCommitReceipt> = .idle
    @State private var saveBloomTrigger = 0

    init(
        tracker: TrackerDefinitionValue,
        entry: TrackerEntryValue? = nil,
        title: String = "Record value",
        onSave: @escaping (TrackerValue, String?, Date) async -> Bool
    ) {
        self.tracker = tracker
        self.title = title
        self.onSave = onSave
        let value = entry?.value
        if case .boolean(let current) = value {
            _booleanValue = State(initialValue: current)
        } else {
            _booleanValue = State(initialValue: entry?.booleanValue ?? true)
        }
        if case .count(let current) = value {
            _countValue = State(initialValue: current)
        } else {
            _countValue = State(initialValue: Int(entry?.numericValue ?? 0))
        }
        switch value {
        case .quantity(let current, _), .rating(let current):
            _numericValue = State(initialValue: current)
        default:
            _numericValue = State(initialValue:
                entry?.numericValue
                    ?? tracker.rangeMin
                    ?? (tracker.effectiveValueType == .rating ? 1 : 0)
            )
        }
        if case .duration(let seconds) = value {
            _durationMinutes = State(initialValue: seconds / 60)
        } else {
            _durationMinutes = State(initialValue: (entry?.numericValue ?? 0) / 60)
        }
        if case .text(let current) = value {
            _textValue = State(initialValue: current)
        } else {
            _textValue = State(initialValue: tracker.effectiveValueType == .text ? entry?.note ?? "" : "")
        }
        if case .choice(let current) = value {
            _choiceValue = State(initialValue: current)
        } else {
            _choiceValue = State(initialValue: tracker.choiceOptions?.first ?? "")
        }
        if case .timestamp(let current) = value {
            _timestampValue = State(initialValue: current)
        } else {
            _timestampValue = State(initialValue: entry?.timestamp ?? Date())
        }
        _note = State(initialValue: tracker.effectiveValueType == .text ? "" : entry?.note ?? "")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: dynamicTypeSize.isAccessibilitySize ? 28 : 22) {
                        VStack(spacing: 8) {
                            Image(systemName: trackerSymbol)
                                .font(.title2.weight(.semibold))
                                .frame(width: 52, height: 52)
                                .background(
                                    Color(LifeBoardColorTokens.foundationSurfaceSelected),
                                    in: Circle()
                                )
                            Text(tracker.title)
                                .font(Typography.sectionTitle().weight(.bold))
                                .multilineTextAlignment(.center)
                            Text("Record what is true right now.")
                                .font(.subheadline)
                                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        }
                        .frame(maxWidth: .infinity)
                        .lifeboardClayPressBloom(
                            center: .center,
                            trigger: saveBloomTrigger,
                            tint: Color(LifeBoardColorTokens.foundationSageAccent)
                        )

                        VStack(alignment: .leading, spacing: 14) {
                            valueEditor
                        }
                        .padding(16)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .lifeBoardClaySurface(.resting, cornerRadius: 20)

                        if tracker.effectiveValueType != .text {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("A note, if it helps")
                                    .font(.subheadline.weight(.semibold))
                                TextField("Anything you want to remember…", text: $note, axis: .vertical)
                                    .lineLimit(2...5)
                                    .padding(12)
                                    .background(
                                        Color(LifeBoardColorTokens.foundationSurfaceRecessed),
                                        in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    )
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        if let minimum = tracker.rangeMin, let maximum = tracker.rangeMax {
                            Label(
                                "This tracker accepts \(minimum.formatted()) through \(maximum.formatted()).",
                                systemImage: "slider.horizontal.below.rectangle"
                            )
                            .font(.caption)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if tracker.effectivePrivacyClass != .standard {
                            Label(
                                tracker.effectivePrivacyClass == .sensitive
                                    ? "This entry stays on your sensitive-content path."
                                    : "This entry is held as personal.",
                                systemImage: "lock.fill"
                            )
                            .font(.caption)
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 112)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                TrackerCommitBar(
                    title: title == "Correct entry" ? "Save correction" : "Record value",
                    phase: commitPhase,
                    isEnabled: typedValue != nil,
                    action: commit
                )
                .accessibilityIdentifier("track.tracker.value.commit")
            }
        }
        .presentationCornerRadius(28)
        .interactiveDismissDisabled(isRunning)
    }

    @ViewBuilder
    private var valueEditor: some View {
        switch tracker.effectiveValueType {
        case .boolean:
            HStack(spacing: 10) {
                binaryChoice("Yes", symbol: "checkmark", value: true)
                binaryChoice("No", symbol: "xmark", value: false)
            }
        case .count:
            stepperEditor(
                value: Binding(
                    get: { Double(countValue) },
                    set: { countValue = max(0, Int($0.rounded())) }
                ),
                unit: "count",
                step: 1
            )
        case .quantity:
            numericEditor(value: $numericValue, unit: tracker.unitLabel ?? "amount")
        case .rating:
            ratingEditor
        case .duration:
            stepperEditor(value: $durationMinutes, unit: tracker.unitLabel ?? "minutes", step: 5)
        case .text:
            TextField("What did you notice?", text: $textValue, axis: .vertical)
                .lineLimit(4...10)
                .padding(14)
                .background(
                    Color(LifeBoardColorTokens.foundationSurfaceRecessed),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
        case .choice:
            if let choices = tracker.choiceOptions, choices.isEmpty == false {
                LazyVGrid(
                    columns: dynamicTypeSize.isAccessibilitySize
                        ? [GridItem(.flexible())]
                        : [GridItem(.adaptive(minimum: 120), spacing: 10)],
                    spacing: 10
                ) {
                    ForEach(choices, id: \.self) { choice in
                        choiceButton(choice)
                    }
                }
            } else {
                Text("This tracker has no saved choices.")
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
        case .timestamp:
            DatePicker("When", selection: $timestampValue)
                .datePickerStyle(.compact)
        }
    }

    private var isRunning: Bool {
        if case .running = commitPhase { return true }
        return false
    }

    private var trackerSymbol: String {
        switch tracker.effectiveValueType {
        case .boolean: "checkmark.circle"
        case .count: "number.circle"
        case .quantity: "ruler"
        case .rating: "slider.horizontal.3"
        case .duration: "timer"
        case .text: "text.bubble"
        case .choice: "list.bullet.circle"
        case .timestamp: "clock.badge.checkmark"
        }
    }

    private func binaryChoice(_ label: String, symbol: String, value: Bool) -> some View {
        let selected = booleanValue == value
        return Button {
            Haptic.pick.play()
            withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                booleanValue = value
            }
        } label: {
            VStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.title3.weight(.bold))
                Text(label).font(.body.weight(.semibold))
            }
            .frame(maxWidth: .infinity, minHeight: 78)
            .lifeBoardClaySurface(selected ? .raised : .well, cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func numericEditor(value: Binding<Double>, unit: String) -> some View {
        VStack(spacing: 8) {
            TextField("Value", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(Typography.hero().weight(.bold))
                .monospacedDigit()
                .accessibilityIdentifier("track.tracker.value.numeric")
            Text(unit)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
        }
        .padding(.vertical, 18)
        .frame(maxWidth: .infinity)
        .background(
            Color(LifeBoardColorTokens.foundationSurfaceRecessed),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }

    private func stepperEditor(value: Binding<Double>, unit: String, step: Double) -> some View {
        HStack(spacing: 14) {
            stepButton("minus", enabled: value.wrappedValue >= step) {
                value.wrappedValue = max(0, value.wrappedValue - step)
            }
            VStack(spacing: 3) {
            TextField("Value", value: value, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(Typography.hero().weight(.bold))
                    .monospacedDigit()
                    .accessibilityIdentifier("track.tracker.value.numeric")
                Text(unit)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }
            .frame(maxWidth: .infinity)
            stepButton("plus", enabled: true) { value.wrappedValue += step }
        }
    }

    private func stepButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button {
            Haptic.pick.play()
            withAnimation(reduceMotion ? nil : .snappy(duration: 0.2)) { action() }
        } label: {
            Image(systemName: symbol)
                .font(.headline)
                .frame(width: 48, height: 48)
                .lifeBoardClaySurface(.well, cornerRadius: 24)
        }
        .buttonStyle(.plain)
        .disabled(enabled == false)
        .opacity(enabled ? 1 : 0.42)
    }

    private var ratingEditor: some View {
        let lower = tracker.rangeMin ?? 1
        let upper = max(lower + 1, tracker.rangeMax ?? 5)
        return VStack(spacing: 14) {
            Text(numericValue.formatted(.number.precision(.fractionLength(0...1))))
                .font(Typography.hero().weight(.bold))
                .contentTransition(.numericText())
                .monospacedDigit()
            Slider(value: $numericValue, in: lower...upper, step: 1)
                .tint(Color(LifeBoardColorTokens.foundationSageAccent))
            HStack {
                Text(lower.formatted())
                Spacer()
                Text(upper.formatted())
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
        }
    }

    private func choiceButton(_ choice: String) -> some View {
        let selected = choiceValue == choice
        return Button {
            Haptic.pick.play()
            withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                choiceValue = choice
            }
        } label: {
            HStack(spacing: 8) {
                Text(choice)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                if selected { Image(systemName: "checkmark.circle.fill") }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .lifeBoardClaySurface(selected ? .raised : .well, cornerRadius: 16)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func commit() {
        guard let value = typedValue, isRunning == false else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        commitPhase = .running(progress: nil)
        Task {
            if await onSave(value, trimmedNote.isEmpty ? nil : trimmedNote, timestampValue) {
                commitPhase = .success(receipt: .init())
                saveBloomTrigger += 1
                Haptic.commit.play()
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 80 : 360))
                dismiss()
            } else {
                commitPhase = .recoverableFailure(.init(
                    message: "That value could not be recorded. Nothing you entered was lost.",
                    recovery: .retry
                ))
                Haptic.fail.play()
            }
        }
    }

    private var typedValue: TrackerValue? {
        let numericCandidate: Double?
        switch tracker.effectiveValueType {
        case .count: numericCandidate = Double(countValue)
        case .quantity, .rating: numericCandidate = numericValue
        case .duration: numericCandidate = durationMinutes * 60
        default: numericCandidate = nil
        }
        if let numericCandidate {
            guard numericCandidate.isFinite,
                  tracker.rangeMin.map({ numericCandidate >= $0 }) ?? true,
                  tracker.rangeMax.map({ numericCandidate <= $0 }) ?? true else {
                return nil
            }
        }
        switch tracker.effectiveValueType {
        case .boolean: return .boolean(booleanValue)
        case .count: return countValue >= 0 ? .count(countValue) : nil
        case .quantity: return .quantity(numericValue, unit: tracker.unitLabel)
        case .rating: return .rating(numericValue)
        case .duration: return durationMinutes >= 0 ? .duration(durationMinutes * 60) : nil
        case .text:
            let value = textValue.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : .text(value)
        case .choice:
            return tracker.choiceOptions?.contains(choiceValue) == true ? .choice(choiceValue) : nil
        case .timestamp: return .timestamp(timestampValue)
        }
    }
}

private struct TrackerHistoryView: View {
    let tracker: TrackerDefinitionValue
    let entries: [TrackerEntryValue]
    let activeReceipt: (UUID) -> TrackCorrectionReceipt?
    let onUndo: (TrackCorrectionReceipt) async -> Void
    let onCorrect: (TrackerEntryValue, TrackerValue, String?) async -> Bool
    @State private var correcting: TrackerEntryValue?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        NavigationStack {
            ZStack {
                Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea()
                if entries.isEmpty {
                    ContentUnavailableView {
                        Label("A clear page", systemImage: "chart.xyaxis.line")
                    } description: {
                        Text("Your first recorded value will begin this history.")
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            historySummary
                                .padding(.bottom, 24)

                            HStack {
                                Text("Recent entries")
                                    .font(Typography.sectionTitle())
                                Spacer()
                                Text("Tap any entry to correct it")
                                    .font(.caption)
                                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                            }
                            .padding(.bottom, 8)

                            ForEach(sortedEntries.prefix(30)) { entry in
                                HStack(spacing: 10) {
                                    Button {
                                        Haptic.pick.play()
                                        correcting = entry
                                    } label: {
                                        ViewThatFits(in: .horizontal) {
                                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                                historyValue(entry)
                                                Spacer(minLength: 8)
                                                historyTimestamp(entry)
                                            }
                                            VStack(alignment: .leading, spacing: 4) {
                                                historyValue(entry)
                                                historyTimestamp(entry)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)

                                    Menu {
                                        Button("Correct entry", systemImage: "pencil") {
                                            correcting = entry
                                        }
                                        if let receipt = activeReceipt(entry.id) {
                                            Button("Undo last correction", systemImage: "arrow.uturn.backward") {
                                                Task { await onUndo(receipt) }
                                            }
                                        }
                                    } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .frame(width: 44, height: 44)
                                    }
                                    .accessibilityLabel("Actions for entry from \(entry.timestamp.formatted())")
                                }
                                .overlay(alignment: .bottom) {
                                    Rectangle()
                                        .fill(Color(LifeBoardColorTokens.foundationHairline))
                                        .frame(height: 1)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 14)
                        .padding(.bottom, 40)
                    }
                }
            }
            .navigationTitle(tracker.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(item: $correcting) { entry in
                TrackerValueCaptureView(
                    tracker: tracker,
                    entry: entry,
                    title: "Correct entry"
                ) { value, note, _ in
                    let succeeded = await onCorrect(entry, value, note)
                    if succeeded { correcting = nil }
                    return succeeded
                }
            }
        }
        .presentationCornerRadius(28)
    }

    private var sortedEntries: [TrackerEntryValue] {
        entries.sorted { $0.timestamp > $1.timestamp }
    }

    private var historySummary: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(entries.count) \(entries.count == 1 ? "entry" : "entries")")
                        .font(Typography.sectionTitle().weight(.bold))
                        .contentTransition(.numericText())
                    Text(lastRecordedDescription)
                        .font(.caption)
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                }
                Spacer()
                Label(tracker.effectiveAggregation.displayName, systemImage: "function")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            }

            if let magnitudes = recentMagnitudes, magnitudes.isEmpty == false {
                if magnitudes.count == 1, let entry = sortedEntries.first {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(Color(LifeBoardColorTokens.foundationSageAccent))
                            .frame(width: 9, height: 9)
                        Text("First value")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                        Spacer()
                        Text(value(entry))
                            .font(.body.weight(.semibold).monospacedDigit())
                    }
                    .padding(.horizontal, 14)
                    .frame(minHeight: 52)
                    .background(
                        Color(LifeBoardColorTokens.foundationSurfaceRecessed),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
                } else {
                    GeometryReader { proxy in
                        let maximum = max(magnitudes.max() ?? 1, 1)
                        HStack(alignment: .bottom, spacing: 6) {
                            ForEach(Array(magnitudes.enumerated()), id: \.offset) { _, magnitude in
                                Capsule()
                                    .fill(Color(LifeBoardColorTokens.foundationSageAccent))
                                    .frame(
                                        maxWidth: .infinity,
                                        minHeight: 6,
                                        maxHeight: max(6, proxy.size.height * CGFloat(magnitude / maximum))
                                    )
                            }
                        }
                        .frame(maxHeight: .infinity, alignment: .bottom)
                    }
                    .frame(height: dynamicTypeSize.isAccessibilitySize ? 64 : 78)
                    .lifeboardChartRevealSweep(progress: 1)
                    .accessibilityHidden(true)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .lifeBoardClaySurface(.raised, cornerRadius: 20)
        .privacySensitive(tracker.effectivePrivacyClass != .standard)
        .accessibilityIdentifier("track.tracker.history.summary")
    }

    private var lastRecordedDescription: String {
        guard let latest = sortedEntries.first else { return "No recorded values" }
        return "Last recorded \(latest.timestamp.formatted(.relative(presentation: .named)))"
    }

    private var recentMagnitudes: [Double]? {
        let values = sortedEntries.prefix(12).reversed().compactMap { magnitude($0) }
        return values.isEmpty ? nil : values
    }

    private func magnitude(_ entry: TrackerEntryValue) -> Double? {
        if let value = entry.value {
            switch value {
            case .boolean(let flag): return flag ? 1 : 0
            case .count(let count): return Double(count)
            case .quantity(let number, _), .rating(let number): return max(0, number)
            case .duration(let seconds): return max(0, seconds)
            case .text, .choice, .timestamp: return nil
            }
        }
        if let number = entry.numericValue { return max(0, number) }
        if let flag = entry.booleanValue { return flag ? 1 : 0 }
        return nil
    }

    private func historyValue(_ entry: TrackerEntryValue) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value(entry))
                .font(.body.weight(.semibold))
                .foregroundStyle(Color(LifeBoardColorTokens.inkPrimary))
            if let note = entry.note, note.isEmpty == false {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    .lineLimit(2)
            }
        }
    }

    private func historyTimestamp(_ entry: TrackerEntryValue) -> some View {
        Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
            .font(.caption.monospacedDigit())
            .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
    }

    private func value(_ entry: TrackerEntryValue) -> String {
        if let value = entry.value {
            switch value {
            case .boolean(let value): return value ? "Yes" : "No"
            case .count(let value): return value.formatted()
            case .quantity(let value, let unit):
                return [value.formatted(), unit].compactMap { $0 }.joined(separator: " ")
            case .rating(let value): return value.formatted()
            case .duration(let seconds):
                return Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes]))
            case .text(let value), .choice(let value): return value
            case .timestamp(let value): return value.formatted(date: .abbreviated, time: .shortened)
            }
        }
        if let number = entry.numericValue { return [number.formatted(), tracker.unitLabel].compactMap { $0 }.joined(separator: " ") }
        if let boolean = entry.booleanValue { return boolean ? "Done" : "Not done" }
        return entry.note ?? "Recorded"
    }
}

private struct MedicationComposer: View {
    let onSave: (MedicationDefinitionValue, MedicationScheduleValue) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var dosage = ""
    @State private var instructions = ""
    @State private var form = ""
    @State private var hasStartDate = false
    @State private var startDate = Date()
    @State private var hasEndDate = false
    @State private var endDate = Date()
    @State private var refillEnabled = false
    @State private var refillQuantity = 30.0
    @State private var refillRemaining = 30.0
    @State private var refillThreshold = 5.0
    @State private var recordsLastRefill = false
    @State private var lastRefilledAt = Date()
    @State private var windowStart = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var windowEnd = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var weekdays = Set(1...7)
    @State private var reminderEnabled = true
    private let existing: MedicationDefinitionValue?
    private let existingSchedule: MedicationScheduleValue?

    init(
        existing: MedicationDefinitionValue? = nil,
        existingSchedule: MedicationScheduleValue? = nil,
        onSave: @escaping (MedicationDefinitionValue, MedicationScheduleValue) -> Void
    ) {
        self.existing = existing
        self.existingSchedule = existingSchedule
        self.onSave = onSave
        _name = State(initialValue: existing?.name ?? "")
        _dosage = State(initialValue: existing?.dosageText ?? "")
        _instructions = State(initialValue: existing?.instructions ?? "")
        _form = State(initialValue: existing?.formRaw ?? "")
        _hasStartDate = State(initialValue: existing?.startDate != nil)
        _startDate = State(initialValue: existing?.startDate ?? Date())
        _hasEndDate = State(initialValue: existing?.endDate != nil)
        _endDate = State(initialValue: existing?.endDate ?? Date())
        let hasRefill = existing?.refillQuantity != nil
            || existing?.refillRemaining != nil
            || existing?.refillThreshold != nil
        _refillEnabled = State(initialValue: hasRefill)
        _refillQuantity = State(initialValue: existing?.refillQuantity ?? 30)
        _refillRemaining = State(initialValue: existing?.refillRemaining ?? existing?.refillQuantity ?? 30)
        _refillThreshold = State(initialValue: existing?.refillThreshold ?? 5)
        _recordsLastRefill = State(initialValue: existing?.lastRefilledAt != nil)
        _lastRefilledAt = State(initialValue: existing?.lastRefilledAt ?? Date())
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
        ComposerScaffold(
            title: existing == nil ? "Add Medication" : "Edit Medication",
            subtitle: "An informational record you control.",
            confirmTitle: "Save",
            isConfirmEnabled: isInvalid == false,
            isPrivacySensitive: true,
            identifier: "track.medication.composer",
            onConfirm: commit
        ) {
            MedicationIdentitySection(
                name: $name,
                form: $form,
                dosage: $dosage,
                instructions: $instructions
            )
            MedicationActiveDatesSection(
                hasStartDate: $hasStartDate,
                startDate: $startDate,
                hasEndDate: $hasEndDate,
                endDate: $endDate
            )
            MedicationRefillSection(
                refillEnabled: $refillEnabled,
                refillQuantity: $refillQuantity,
                refillRemaining: $refillRemaining,
                refillThreshold: $refillThreshold,
                recordsLastRefill: $recordsLastRefill,
                lastRefilledAt: $lastRefilledAt
            )
            MedicationScheduleSection(
                windowStart: $windowStart,
                windowEnd: $windowEnd,
                weekdays: $weekdays,
                reminderEnabled: $reminderEnabled
            )
        }
    }

    private func commit() {
        let trimmedForm = form.trimmingCharacters(in: .whitespacesAndNewlines)
        let medication = MedicationDefinitionValue(
            id: existing?.id ?? UUID(),
            name: name,
            dosageText: dosage.isEmpty ? nil : dosage,
            instructions: instructions.isEmpty ? nil : instructions,
            healthCorrelationID: existing?.healthCorrelationID,
            isArchived: existing?.isArchived ?? false,
            createdAt: existing?.createdAt ?? Date(),
            updatedAt: Date(),
            formRaw: trimmedForm.isEmpty ? nil : trimmedForm,
            startDate: hasStartDate ? Calendar.current.startOfDay(for: startDate) : nil,
            endDate: hasEndDate ? Calendar.current.date(
                bySettingHour: 23,
                minute: 59,
                second: 59,
                of: endDate
            ) : nil,
            refillQuantity: refillEnabled ? refillQuantity : nil,
            refillRemaining: refillEnabled ? refillRemaining : nil,
            refillThreshold: refillEnabled ? refillThreshold : nil,
            lastRefilledAt: refillEnabled && recordsLastRefill ? lastRefilledAt : nil
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

    private var isInvalid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || weekdays.isEmpty
            || windowEnd <= windowStart
            || (hasStartDate && hasEndDate && Calendar.current.startOfDay(for: endDate) < Calendar.current.startOfDay(for: startDate))
            || (refillEnabled && (
                refillQuantity.isFinite == false
                    || refillRemaining.isFinite == false
                    || refillThreshold.isFinite == false
                    || refillQuantity < 0
                    || refillRemaining < 0
                    || refillThreshold < 0
                    || refillRemaining > refillQuantity
            ))
    }
}

private struct MedicationIdentitySection: View {
    @Binding var name: String
    @Binding var form: String
    @Binding var dosage: String
    @Binding var instructions: String

    var body: some View {
        ComposerSection(
            "Medication",
            footer: "LifeBoard keeps an informational record only. It does not provide dose, interaction, diagnosis, or treatment advice."
        ) {
            ComposerField("Name", prompt: "What it is called", text: $name, identifier: "track.medication.name")
            ComposerField("Form", prompt: "Tablet, capsule, liquid…", text: $form)
            ComposerField("Dose label", prompt: "Optional", text: $dosage)
            ComposerField("Instructions", prompt: "Optional", text: $instructions, shape: .prose(lineLimit: 2...5))
        }
    }
}

private struct MedicationActiveDatesSection: View {
    @Binding var hasStartDate: Bool
    @Binding var startDate: Date
    @Binding var hasEndDate: Bool
    @Binding var endDate: Date

    var body: some View {
        ComposerSection("Active dates") {
            Toggle("Use a start date", isOn: $hasStartDate)
                .toggleStyle(.lifeBoardClay)
            if hasStartDate {
                DateCapsuleRow("Starts", selection: $startDate, components: [.date])
            }
            Toggle("Use an end date", isOn: $hasEndDate)
                .toggleStyle(.lifeBoardClay)
            if hasEndDate {
                DateCapsuleRow(
                    "Ends",
                    selection: $endDate,
                    components: [.date],
                    minimum: hasStartDate ? startDate : nil
                )
            }
        }
    }
}

private struct MedicationRefillSection: View {
    @Binding var refillEnabled: Bool
    @Binding var refillQuantity: Double
    @Binding var refillRemaining: Double
    @Binding var refillThreshold: Double
    @Binding var recordsLastRefill: Bool
    @Binding var lastRefilledAt: Date

    var body: some View {
        ComposerSection(
            "Refill information",
            footer: refillEnabled
                ? "Refill tracking is opt-in and informational. LifeBoard does not tell you when or how to take medication."
                : nil
        ) {
            Toggle("Track refill count", isOn: $refillEnabled)
                .toggleStyle(.lifeBoardClay)
            if refillEnabled {
                ComposerNumberField("Quantity after refill", value: $refillQuantity)
                ComposerNumberField("Remaining", value: $refillRemaining)
                ComposerNumberField("Inform me at or below", value: $refillThreshold)
                Toggle("Record last refill date", isOn: $recordsLastRefill)
                    .toggleStyle(.lifeBoardClay)
                if recordsLastRefill {
                    DateCapsuleRow("Last refilled", selection: $lastRefilledAt, components: [.date])
                }
            }
        }
    }
}

private struct MedicationScheduleSection: View {
    @Binding var windowStart: Date
    @Binding var windowEnd: Date
    @Binding var weekdays: Set<Int>
    @Binding var reminderEnabled: Bool

    var body: some View {
        ComposerSection("Schedule") {
            DateCapsuleRow("Window starts", selection: $windowStart, components: [.time])
            DateCapsuleRow("Window ends", selection: $windowEnd, components: [.time])
            MedicationWeekdayRail(weekdays: $weekdays)
            Toggle("Reminder enabled", isOn: $reminderEnabled)
                .toggleStyle(.lifeBoardClay)
        }
    }
}

/// Weekdays as clay chips.
///
/// The previous row painted a bare `Capsule` behind selected days, so selection
/// was carried by tint alone — invisible under Differentiate Without Colour.
/// Clay depth carries it here instead.
private struct MedicationWeekdayRail: View {
    @Binding var weekdays: Set<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Days")
                .font(.lifeboard(.meta))
                .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { weekday in
                    let isOn = weekdays.contains(weekday)
                    Button {
                        Haptic.pick.play()
                        if isOn { weekdays.remove(weekday) } else { weekdays.insert(weekday) }
                    } label: {
                        Text(Calendar.current.veryShortStandaloneWeekdaySymbols[weekday - 1])
                            .font(.lifeboard(isOn ? .bodyStrong : .body))
                            .foregroundStyle(Color(isOn
                                ? LifeBoardColorTokens.inkPrimary
                                : LifeBoardColorTokens.inkSecondary))
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .lifeBoardClaySurface(
                                isOn ? .raised : .well,
                                cornerRadius: Radius.pill
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Calendar.current.weekdaySymbols[weekday - 1])
                    .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                }
            }
            .lifeBoardMotion(.selection, value: weekdays)
        }
    }
}

private struct MedicationHistoryView: View {
    let medication: MedicationDefinitionValue
    let events: [MedicationEventValue]
    let activeReceipt: (UUID) -> TrackCorrectionReceipt?
    let onUndo: (TrackCorrectionReceipt) async -> Void
    let onCorrect: (MedicationEventValue, MedicationEventStatus, Date, Date?, String?) async -> Void
    @State private var correcting: MedicationEventValue?
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
                MedicationCorrectionView(event: event) { status, scheduledAt, resolvedAt, note in
                    await onCorrect(event, status, scheduledAt, resolvedAt, note)
                    correcting = nil
                }
            }
        }
    }

    private func statusSymbol(_ status: MedicationEventStatus) -> String {
        switch status {
        case .taken: "checkmark.circle"
        case .skipped: "forward.end"
        case .snoozed, .rescheduled: "clock.arrow.circlepath"
        case .scheduled: "calendar"
        case .unresolved: "questionmark.circle"
        }
    }
}

private struct MedicationCorrectionView: View {
    let event: MedicationEventValue
    let onSave: (MedicationEventStatus, Date, Date?, String?) async -> Void
    @State private var status: MedicationEventStatus
    @State private var scheduledAt: Date
    @State private var resolvedAt: Date
    @State private var note: String
    @Environment(\.dismiss) private var dismiss

    init(
        event: MedicationEventValue,
        onSave: @escaping (MedicationEventStatus, Date, Date?, String?) async -> Void
    ) {
        self.event = event
        self.onSave = onSave
        _status = State(initialValue: event.status)
        _scheduledAt = State(initialValue: event.scheduledAt)
        _resolvedAt = State(initialValue: event.resolvedAt ?? Date())
        _note = State(initialValue: event.note ?? "")
    }

    var body: some View {
        ComposerScaffold(
            title: "Correct status",
            subtitle: "Record what actually happened.",
            confirmTitle: "Save",
            identifier: "track.medication.correction",
            onConfirm: {
                Task {
                    await onSave(status, scheduledAt, resolvedAt, note)
                    dismiss()
                }
            }
        ) {
            ComposerSection("Status") {
                OptionRail(
                    "Status",
                    selection: $status,
                    values: MedicationEventStatus.allCases,
                    identifierPrefix: "track.medication.status",
                    title: { $0.rawValue.capitalized },
                    showsLabel: false
                )
            }
            ComposerSection("Times") {
                DateCapsuleRow("Scheduled", selection: $scheduledAt)
                if status != .scheduled && status != .unresolved {
                    DateCapsuleRow("Resolved", selection: $resolvedAt)
                }
            }
            ComposerSection("Note") {
                ComposerField(
                    "Correction note",
                    prompt: "Optional",
                    text: $note,
                    shape: .prose(lineLimit: 2...5),
                    showsLabel: false
                )
            }
        }
    }
}

/// Shared with the Track foundation root so fasting is not reachable
/// only through the legacy Track tree.
struct FastingComposer: View {
    let onStart: (TimeInterval?, [TimeInterval]) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var usesTarget = false
    @State private var targetHours = 12.0
    @State private var reminderEnabled = false

    var body: some View {
        ComposerScaffold(
            title: "Start fasting timer",
            subtitle: "A neutral clock. Nothing is prescribed.",
            confirmTitle: "Start",
            identifier: "track.fasting.composer",
            onConfirm: {
                let target = usesTarget ? targetHours * 3_600 : nil
                let reminders = usesTarget && reminderEnabled ? [max(0, targetHours * 3_600 - 3_600)] : []
                onStart(target, reminders)
                dismiss()
            }
        ) {
            FastingTargetSection(
                usesTarget: $usesTarget,
                targetHours: $targetHours,
                reminderEnabled: $reminderEnabled
            )
        }
    }
}

private struct FastingTargetSection: View {
    @Binding var usesTarget: Bool
    @Binding var targetHours: Double
    @Binding var reminderEnabled: Bool

    var body: some View {
        ComposerSection(
            "Target",
            footer: "LifeBoard provides a neutral timer only. It does not recommend a protocol or make metabolic claims."
        ) {
            Toggle("Use my own target", isOn: $usesTarget)
                .toggleStyle(.lifeBoardClay)
            if usesTarget {
                ComposerDial(
                    "Target",
                    value: $targetHours,
                    in: 1...48,
                    step: 1,
                    unit: "hours",
                    diameter: 140
                )
                Toggle("Remind one hour before target", isOn: $reminderEnabled)
                    .toggleStyle(.lifeBoardClay)
            }
        }
    }
}

/// Complete fasting history with the recorded meaning of every session —
/// planned, early, cancelled, or corrected — plus the same 15-minute
/// correction and undo affordances the inline card offers.
/// Shared with the Track foundation root so fasting is not reachable
/// only through the legacy Track tree.
struct FastingHistoryView: View {
    let sessions: [FastingSessionValue]
    let activeReceipt: (UUID) -> TrackCorrectionReceipt?
    let onUndo: (TrackCorrectionReceipt) async -> Void
    let onCorrect: (FastingSessionValue, TimeInterval, TimeInterval) async -> Void
    @Environment(\.dismiss) private var dismiss

    private var finished: [FastingSessionValue] {
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
            .lifeBoardFormSurface()
            .navigationTitle("Fasting history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }

    private func meaningTitle(_ kind: FastingCompletionKind?) -> String {
        switch kind {
        case .planned: "Completed"
        case .early: "Ended early"
        case .cancelled: "Cancelled"
        case .corrected: "Corrected"
        case nil: "Recorded"
        }
    }

    private func durationText(_ session: FastingSessionValue) -> String {
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
final class JournalStore {
    enum Section: String, CaseIterable, Identifiable { case today = "Today", library = "Library", insights = "Insights"; var id: String { rawValue } }

    private(set) var today: JournalDayValue?
    private(set) var days: [JournalDayValue] = []
    private(set) var allDays: [JournalDayValue] = []
    private(set) var draft: JournalDraftValue?
    private(set) var isLoading = false
    private(set) var searchState: JournalSearchState = .idle
    private(set) var reflectionReports: [WeeklyReflectionReport] = []
    private(set) var selectedReflectionID: UUID?
    private(set) var reflectionSourceSelection: Set<UUID> = []
    private(set) var exportPhase: AsyncActionPhase<JournalExportReceipt> = .idle
    private(set) var backupPhase: AsyncActionPhase<JournalBackupReceipt> = .idle
    private(set) var importPhase: AsyncActionPhase<JournalImportReceipt> = .idle
    private(set) var watchRecoveryRecords: [WatchCaptureRecoveryRecord] = []
    private(set) var proactiveInsights: [ReflectionInsight] = []
    private(set) var savedProactiveInsights: [ReflectionInsight] = []
    var section: Section = .today
    var searchText = ""
    var starredOnly = false
    var moodFilter: JournalMood?
    var errorMessage: String?

    let repository: any PhaseIIRepository
    private let derivedIndex: (any JournalDerivedIndexRepository)?
    private let derivedPipeline: JournalDerivedPipelineCoordinator?
    private let reflectionRepository: (any WeeklyReflectionHistoryRepository)?
    private let exportService: (any JournalExporting)?
    private let backupService: (any JournalBackupServicing)?
    private let proactiveRepository: LocalProactiveReflectionRepository?
    private var proactiveFeedback: [String: ReflectionCardFeedback] = [:]
    private var proactiveFollowUps: [DecisionFollowUpState] = []
    private var hasBuiltDerivedIndex = false
    private var reflectionInvalidationTask: Task<Void, Never>?
    private var exportTask: Task<Void, Never>?
    private var lastExportFormat: JournalExportFormat?
    private var lastExportIncludedSensitiveFields = false

    init(
        repository: any PhaseIIRepository,
        derivedIndex: (any JournalDerivedIndexRepository)? = nil,
        derivedPipeline: JournalDerivedPipelineCoordinator? = nil,
        reflectionRepository: (any WeeklyReflectionHistoryRepository)? = nil,
        exportService: (any JournalExporting)? = nil,
        backupService: (any JournalBackupServicing)? = nil,
        proactiveRepository: LocalProactiveReflectionRepository? = nil,
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
                        await JournalProjectionInvalidationService.shared
                            .broadcast(.reflectionsInvalidated(changed))
                    },
                    invalidateHomeAndEvidence: {
                        await JournalProjectionInvalidationService.shared
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
        if let proactiveRepository {
            self.proactiveRepository = proactiveRepository
        } else {
            self.proactiveRepository = try? LocalProactiveReflectionRepository()
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
            var repairedDays: [JournalDayValue] = []
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
            for path in removedAudioPaths { try? JournalAudioFiles.delete(relativePath: path) }
            let retainedAudioPaths = Set(
                repairedDays.flatMap(\.media).compactMap { $0.kind == .audio ? $0.relativePath : nil }
                + (fetchedDraft?.audioRelativePaths ?? [])
            )
            try? JournalAudioFiles.deleteOrphans(retaining: retainedAudioPaths)
            applyVisibleDays()
            if !hasBuiltDerivedIndex { await rebuildDerivedIndex() }
            await refreshProactiveReflections()
            await loadWatchRecovery()
        } catch { errorMessage = error.localizedDescription }
    }

    func loadWatchRecovery() async {
        #if canImport(WatchConnectivity) && os(iOS)
        watchRecoveryRecords = await WatchConnectivityCoordinator.shared.journalRecoveryRecords()
        #endif
    }

    func retryWatchRecovery() async {
        #if canImport(WatchConnectivity) && os(iOS)
        await WatchConnectivityCoordinator.shared.retryJournalRecovery()
        try? await Task.sleep(for: .milliseconds(220))
        await loadWatchRecovery()
        #endif
    }

    func discardWatchRecoveryRecord(id: UUID) async {
        #if canImport(WatchConnectivity) && os(iOS)
        await WatchConnectivityCoordinator.shared.discardJournalRecoveryRecord(id: id)
        await loadWatchRecovery()
        #endif
    }

    func refreshProactiveReflections(now: Date = Date()) async {
        do {
            if let proactiveRepository {
                let state = try await proactiveRepository.load()
                proactiveFeedback = state.feedback
                proactiveFollowUps = state.followUps
            }
            let snapshots = allDays
                .filter { $0.aiExclusion.permitsReflection }
                .map {
                    ReflectionEntrySnapshot(
                        id: $0.id,
                        date: $0.day,
                        updatedAt: $0.updatedAt,
                        mood: $0.latestMood?.rawValue,
                        text: $0.displayText
                    )
                }
            let result = ProactiveReflectionAnalyzer.analyze(
                entries: snapshots,
                existingFollowUps: proactiveFollowUps,
                now: now
            )
            proactiveFollowUps = result.followUpStates
            savedProactiveInsights = result.insights.filter { proactiveFeedback[$0.feedbackKey]?.saved == true }
            proactiveInsights = result.insights.filter { insight in
                let feedback = proactiveFeedback[insight.feedbackKey]
                return feedback?.saved != true
                    && feedback?.isDismissed != true
                    && feedback?.isSnoozed(now: now) != true
            }
            try await persistProactiveState()
        } catch is CancellationError {
            return
        } catch {
            // Reflection is derived and optional; primary Journal loading must
            // remain successful when protected data is temporarily unavailable.
            proactiveInsights = []
            savedProactiveInsights = []
        }
    }

    func toggleSaved(_ insight: ReflectionInsight) async {
        var feedback = proactiveFeedback[insight.feedbackKey]
            ?? ReflectionCardFeedback(insightID: insight.feedbackKey)
        feedback.saved.toggle()
        feedback.updatedAt = Date()
        proactiveFeedback[insight.feedbackKey] = feedback
        try? await persistProactiveState()
        await refreshProactiveReflections()
    }

    func snooze(_ insight: ReflectionInsight, until: Date) async {
        var feedback = proactiveFeedback[insight.feedbackKey]
            ?? ReflectionCardFeedback(insightID: insight.feedbackKey)
        feedback.snoozedUntil = until
        feedback.dismissedAt = nil
        feedback.updatedAt = Date()
        proactiveFeedback[insight.feedbackKey] = feedback
        try? await persistProactiveState()
        await refreshProactiveReflections()
    }

    func dismiss(_ insight: ReflectionInsight) async {
        var feedback = proactiveFeedback[insight.feedbackKey]
            ?? ReflectionCardFeedback(insightID: insight.feedbackKey)
        feedback.dismissedAt = Date()
        feedback.snoozedUntil = nil
        feedback.updatedAt = Date()
        proactiveFeedback[insight.feedbackKey] = feedback
        try? await persistProactiveState()
        await refreshProactiveReflections()
    }

    func isSaved(_ insight: ReflectionInsight) -> Bool {
        proactiveFeedback[insight.feedbackKey]?.saved == true
    }

    private func persistProactiveState() async throws {
        guard let proactiveRepository else { return }
        try await proactiveRepository.save(.init(
            feedback: proactiveFeedback,
            followUps: proactiveFollowUps
        ))
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
            let updates = await JournalProjectionInvalidationService.shared.updates()
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
                ?? WeeklyReflectionService.makeReport(
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
            var report = WeeklyReflectionService.makeReport(
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
        var day = today ?? JournalDayValue(day: Date())
        day.blocks.append(.init(dayID: day.id, kind: .text, text: trimmed, promptID: promptID, ordinal: day.blocks.count))
        day.updatedAt = Date()
        if await save(day) { await clearDraft() }
    }

    func saveDraftText(_ text: String, promptID: String?, editPosition: Int? = nil) async {
        let now = Date()
        let value = JournalDraftValue(
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

    func appendMood(_ mood: JournalMood, energy: Int?) async {
        var day = today ?? JournalDayValue(day: Date())
        let now = Date()
        day.blocks.append(.init(dayID: day.id, kind: .mood, mood: mood, energy: energy, createdAt: now, updatedAt: now, ordinal: day.blocks.count))
        day.updatedAt = now
        do {
            let checkIn = MoodEnergyCheckInValue(mood: mood, energy: energy, createdAt: now, representativeDay: day.day, isRepresentative: true)
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
        var day = today ?? JournalDayValue(day: Date())
        for payload in payloads {
            let media = JournalMediaValue(dayID: day.id, kind: .photo, payload: payload, syncPolicy: .privateCloud)
            day.media.append(media)
            day.blocks.append(.init(dayID: day.id, kind: .photo, mediaID: media.id, ordinal: day.blocks.count))
        }
        day.updatedAt = Date()
        await save(day)
    }

    @discardableResult
    func appendAudio(relativePath: String, duration: TimeInterval, transcription: String?) async -> Bool {
        var day = today ?? JournalDayValue(day: Date())
        let media = JournalMediaValue(
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
            try? JournalAudioFiles.delete(relativePath: path)
        }
    }

    func discardAudio(relativePath: String) async {
        guard var day = allDays.first(where: { day in
            day.media.contains(where: { $0.kind == .audio && $0.relativePath == relativePath })
        }), let mediaID = day.media.first(where: { $0.relativePath == relativePath })?.id else {
            try? JournalAudioFiles.delete(relativePath: relativePath)
            return
        }
        day.media.removeAll(where: { $0.id == mediaID })
        day.blocks.removeAll(where: { $0.mediaID == mediaID })
        for index in day.blocks.indices { day.blocks[index].ordinal = index }
        day.updatedAt = Date()
        if await save(day) {
            try? JournalAudioFiles.delete(relativePath: relativePath)
        }
    }

    func toggleStar(_ dayValue: JournalDayValue) async {
        var day = dayValue
        day.isStarred.toggle()
        day.updatedAt = Date()
        await save(day)
    }

    /// Per-entry AI participation. Changing it re-saves the day so every
    /// downstream index observes the new state on its next pass.
    func setAIExclusion(_ exclusion: JournalAIExclusion, for dayValue: JournalDayValue) async {
        guard dayValue.aiExclusion != exclusion else { return }
        var day = dayValue
        day.aiExclusion = exclusion
        day.updatedAt = Date()
        await save(day)
    }

    func delete(_ day: JournalDayValue) async {
        do {
            for media in day.media where media.kind == .audio {
                if let path = media.relativePath { try? JournalAudioFiles.delete(relativePath: path) }
            }
            try await repository.deleteJournalDay(id: day.id)
            if let derivedPipeline {
                try await derivedPipeline.processDeletion(entryID: day.id)
            } else if let derivedIndex {
                try await derivedIndex.remove(entryID: day.id)
            }
            await JournalSpotlightIndexer.remove(dayID: day.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    @discardableResult
    func save(_ day: JournalDayValue) async -> Bool {
        do {
            try await repository.saveJournalDay(day)
            if let derivedPipeline {
                try await derivedPipeline.processCommitted(JournalEntrySnapshot(day: day))
            } else if let derivedIndex {
                try await derivedIndex.upsert(entry: JournalEntrySnapshot(day: day))
            }
            await JournalSpotlightIndexer.index(day)
            await load()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    var insights: JournalInsightSnapshot {
        JournalInsightService.makeSnapshot(days: days)
    }
}

struct JournalModuleView: View {
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

    @State private var store: JournalStore
    @State private var privacy: JournalPrivacyController
    private let router: AppRouter?
    private let reflectionWeekDate: Date
    @State private var showsTextComposer = false
    @State private var showsMood = false
    @State private var mood: JournalMood = .none
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
    @State private var showsWatchRecovery = false
    @State private var backupOperationTask: Task<Void, Never>?
    @Environment(PresentationPreferences.self) private var preferences
    @Environment(\.scenePhase) private var scenePhase

    private let initialText: String?

    init(
        repository: any PhaseIIRepository,
        initialSection: JournalStore.Section = .today,
        reflectionWeekDate: Date = Date(),
        router: AppRouter? = nil,
        initialText: String? = nil,
        startsWithTextComposer: Bool = false
    ) {
        _store = State(initialValue: JournalStore(repository: repository, initialSection: initialSection))
        _privacy = State(initialValue: JournalPrivacyController(initiallyUnlocked: router?.isJournalAccessUnlocked == true))
        _showsTextComposer = State(initialValue: startsWithTextComposer)
        self.reflectionWeekDate = reflectionWeekDate
        self.router = router
        self.initialText = initialText
    }

    var body: some View {
        let palette = DaypartTokens.palette(for: preferences.resolvedDaypart())
        let surface = AnyView(journalSurface(palette: palette))
        let captureSheets = AnyView(surface.sheet(isPresented: $showsTextComposer) {
            JournalTextComposer(
                prompt: currentPrompt,
                initialText: initialText ?? store.draft?.text ?? "",
                onDraftChanged: { text, editPosition in
                    Task { await store.saveDraftText(text, promptID: currentPrompt.id, editPosition: editPosition) }
                },
                onSave: { text in Task { await store.appendText(text, promptID: currentPrompt.id) } }
            )
        }.sheet(isPresented: $showsMood) {
            JournalMoodDialSheet(selectedMood: $mood) { energy in Task { await store.appendMood(mood, energy: energy) } }
        }.sheet(isPresented: $showsRecorder) {
            JournalAudioCapture { path, duration, transcription in
                await store.appendAudio(relativePath: path, duration: duration, transcription: transcription)
            } onTranscription: { path, transcription in
                await store.updateAudioTranscription(relativePath: path, text: transcription)
            } onDiscard: { path in
                await store.discardAudio(relativePath: path)
            }
        }.sheet(isPresented: $showsVoiceSearch) {
            JournalAudioCapture(purpose: .search) { path, _, transcription in
                defer { try? JournalAudioFiles.delete(relativePath: path) }
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
            JournalPhotoEditor(payload: request.payload) { editedPayload in
                photoEditRequest = nil
                Task { await store.updatePhoto(dayID: request.dayID, mediaID: request.mediaID, payload: editedPayload) }
            }
        }.sheet(item: $backupOperation, onDismiss: resetBackupPresentation) { operation in
            backupPassphraseSheet(operation: operation)
        }.sheet(isPresented: $showsWatchRecovery) {
            watchRecoverySheet
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

    private func journalSurface(palette: DaypartPalette) -> some View {
        VStack(spacing: 0) {
            LensPicker(
                "Journal section",
                selection: $store.section,
                values: JournalStore.Section.allCases,
                identifierPrefix: "journal.section",
                title: \.rawValue,
                identifier: \.rawValue
            )
            .padding(.horizontal, 20)
            .padding(.vertical, 10)

            if !store.watchRecoveryRecords.isEmpty {
                watchRecoveryBanner
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
            }

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
        .onReceive(NotificationCenter.default.publisher(for: .lifeboardJournalWatchCaptureNeedsAttention)) { _ in
            Task { await store.loadWatchRecovery() }
        }
    }

    private var watchRecoveryBanner: some View {
        Button { showsWatchRecovery = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "applewatch.radiowaves.left.and.right")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                    .frame(width: 36, height: 36)
                    .background(Color.lifeboard(.statusWarning).opacity(0.14), in: Circle())
                VStack(alignment: .leading, spacing: 2) {
                    Text("Watch capture needs attention")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.lifeboard(.textPrimary))
                    Text("\(store.watchRecoveryRecords.count) private capture\(store.watchRecoveryRecords.count == 1 ? "" : "s") held safely")
                        .font(.caption)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }
            .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
            .padding(12)
            .background(Color.lifeboard(.surfacePrimary), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.lifeboard(.statusWarning).opacity(0.34), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows recovery details and retry actions")
    }

    private var watchRecoverySheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.watchRecoveryRecords) { record in
                        VStack(alignment: .leading, spacing: 6) {
                            Label(watchRecoveryTitle(record.reason), systemImage: watchRecoverySymbol(record.reason))
                                .font(.headline)
                            Text(watchRecoveryMessage(record.reason))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(record.receivedAtUTC, format: .dateTime.month().day().hour().minute())
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            HStack {
                                if record.isRetryable {
                                    Button("Retry") { Task { await store.retryWatchRecovery() } }
                                        .buttonStyle(.borderedProminent)
                                }
                                Button("Remove", role: .destructive) {
                                    Task { await store.discardWatchRecoveryRecord(id: record.id) }
                                }
                                .buttonStyle(.lifeBoardChip)
                            }
                            .controlSize(.small)
                        }
                        .padding(.vertical, 4)
                        .accessibilityElement(children: .contain)
                    }
                } header: {
                    Text("Held privately")
                } footer: {
                    Text("LifeBoard never includes the capture’s text or recording in diagnostics. Remove only if you no longer need this recovery record.")
                }
            }
            .lifeBoardFormSurface()
            .navigationTitle("Watch recovery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { showsWatchRecovery = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func watchRecoveryTitle(_ reason: WatchCaptureRecoveryReason) -> String {
        switch reason {
        case .awaitingAudio: "Waiting for recording"
        case .protectedDataUnavailable: "Waiting for unlock"
        case .persistenceUnavailable: "Couldn’t save yet"
        case .unsupportedSchema: "Watch update needed"
        case .malformedPayload: "Capture couldn’t be read"
        }
    }

    private func watchRecoveryMessage(_ reason: WatchCaptureRecoveryReason) -> String {
        switch reason {
        case .awaitingAudio: "The capture details arrived before its audio. Keep both devices nearby and retry."
        case .protectedDataUnavailable: "Unlock iPhone, then retry so the protected Journal store can open."
        case .persistenceUnavailable: "The capture is still held and can be safely retried."
        case .unsupportedSchema: "Update LifeBoard on iPhone and Apple Watch before trying this capture again."
        case .malformedPayload: "The protected transfer was incomplete and cannot be imported automatically."
        }
    }

    private func watchRecoverySymbol(_ reason: WatchCaptureRecoveryReason) -> String {
        switch reason {
        case .awaitingAudio: "waveform.badge.exclamationmark"
        case .protectedDataUnavailable: "lock.fill"
        case .persistenceUnavailable: "arrow.clockwise.circle"
        case .unsupportedSchema: "applewatch.and.arrow.forward"
        case .malformedPayload: "exclamationmark.triangle"
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
            .lifeBoardFormSurface()
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
            .lifeBoardFormSurface()
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
        AsyncActionControl(
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
                .foregroundStyle(Color.lifeboard(.statusDanger))
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
                        .buttonStyle(.lifeBoardChip)
                        .accessibilityHint("Lets you disable Journal authentication after device authentication becomes unavailable")
                }
            }
            .padding(28)
            .frame(maxWidth: 420)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.privacy.lock")
    }

    private var currentPrompt: JournalPrompt {
        .contextual(daypart: preferences.resolvedDaypart(), hasEntry: store.today?.blocks.isEmpty == false)
    }

    private func today(palette: DaypartPalette) -> some View {
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

    private func journalHero(palette: DaypartPalette) -> some View {
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

    private func captureActions(palette: DaypartPalette) -> some View {
        HStack(spacing: 10) {
            captureAction("Mood", symbol: "face.smiling") { showsMood = true }
            captureAction("Voice", symbol: "waveform") { showsRecorder = true }
            PhotosPicker(selection: $photoSelection, maxSelectionCount: 5, matching: .images) {
                Label("Photo", systemImage: "photo").frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.lifeBoardChip)
            .tint(palette.color(for: .foreground))
        }
    }

    private func captureAction(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Label(title, systemImage: symbol).frame(maxWidth: .infinity, minHeight: 44) }
            .buttonStyle(.lifeBoardChip)
    }

    private func library(palette: DaypartPalette) -> some View {
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
                        ForEach(JournalMood.allCases.filter { $0 != .none }) { mood in
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
        _ day: JournalDayValue,
        palette: DaypartPalette,
        onDelete: (() -> Void)?
    ) -> some View {
        JournalDayCard(
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
    private func searchStatus(palette: DaypartPalette) -> some View {
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
                JournalWorkIndicator(isActive: true, progress: progress)
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

    private func insights(palette: DaypartPalette) -> some View {
        let preview = WeeklyReflectionService.makeReport(
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
                if store.proactiveInsights.isEmpty == false {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Noticed for you")
                                    .font(.title3.weight(.semibold))
                                Text("Private, on-device patterns with their supporting moments.")
                                    .font(.caption)
                                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                            }
                            Spacer(minLength: 8)
                            Image(systemName: "sparkles")
                                .foregroundStyle(Color.lifeboard(.accentPrimary))
                                .accessibilityHidden(true)
                        }
                        ForEach(store.proactiveInsights.prefix(3)) { insight in
                            proactiveInsightCard(insight, palette: palette)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                if store.savedProactiveInsights.isEmpty == false {
                    DisclosureGroup {
                        VStack(spacing: 10) {
                            ForEach(store.savedProactiveInsights) { insight in
                                proactiveInsightCard(insight, palette: palette)
                            }
                        }
                        .padding(.top, 10)
                    } label: {
                        Label(
                            "Saved insights (\(store.savedProactiveInsights.count))",
                            systemImage: "bookmark.fill"
                        )
                        .font(.headline)
                    }
                    .padding(16)
                    .lifeBoardPaperCard()
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
                        .buttonStyle(.lifeBoardChip)

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
                        .buttonStyle(.lifeBoardChip)
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
                        .buttonStyle(.lifeBoardChip)
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
                        .buttonStyle(.lifeBoardChip)
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
        withAnimation(LifeBoardAnimation.roleAmbient) {
            reflectionDevelopProgress = 1
        }
    }

    @ViewBuilder
    private func reflectionExportStatus(palette: DaypartPalette) -> some View {
        switch store.exportPhase {
        case .idle:
            EmptyView()
        case .running:
            HStack(spacing: 10) {
                JournalWorkIndicator(isActive: true)
                Text("Preparing a protected export…").font(.caption)
                Spacer()
                Button("Cancel") { store.cancelReflectionExport() }
            }
            .foregroundStyle(palette.color(for: .foregroundSecondary))
            .accessibilityIdentifier("journal.export.running")
        case .success(let receipt):
            AsyncActionControl(
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
                AsyncActionControl(
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

    private func insightTile(_ title: String, value: String, symbol: String, palette: DaypartPalette) -> some View {
        VStack(spacing: 7) {
            Image(systemName: symbol)
            Text(value).font(.title2.weight(.semibold))
            Text(title).font(.caption).foregroundStyle(palette.color(for: .foregroundSecondary))
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .lifeBoardPaperCard()
    }

    private func proactiveInsightCard(
        _ insight: ReflectionInsight,
        palette: DaypartPalette
    ) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: proactiveInsightSymbol(insight))
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.lifeboard(.accentPrimary))
                    .frame(width: 32, height: 32)
                    .background(Color.lifeboard(.accentPrimary).opacity(0.12), in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text(insight.category.rawValue.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    Text(insight.title)
                        .font(.headline)
                    Text(insight.message)
                        .font(.subheadline)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
                Spacer(minLength: 4)
                Menu {
                    Button(store.isSaved(insight) ? "Remove bookmark" : "Save insight") {
                        Task { await store.toggleSaved(insight) }
                    }
                    Button("Remind me tomorrow") {
                        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date().addingTimeInterval(86_400)
                        Task { await store.snooze(insight, until: tomorrow) }
                    }
                    Button("Dismiss", role: .destructive) {
                        Task { await store.dismiss(insight) }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel("Actions for \(insight.title)")
            }

            if insight.evidence.isEmpty == false {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(insight.evidence.prefix(4)) { evidence in
                            Button {
                                router?.openProtectedJournalRoute(.journalDay(evidence.entryID), in: .track)
                            } label: {
                                Label(
                                    evidence.date.formatted(.dateTime.month(.abbreviated).day()),
                                    systemImage: evidence.role == .baseline ? "clock.arrow.circlepath" : "quote.bubble"
                                )
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 11)
                                .frame(minHeight: 44)
                                .background(palette.color(for: .canvasSecondary), in: Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityHint("Opens the supporting Journal entry")
                        }
                    }
                }
                .scrollIndicators(.hidden)
            }

            HStack(spacing: 8) {
                Label(insight.confidence.rawValue.capitalized, systemImage: "checkmark.seal")
                Text("•")
                Text(insight.explanation)
                    .lineLimit(2)
            }
            .font(.caption2)
            .foregroundStyle(palette.color(for: .foregroundSecondary))
            .accessibilityElement(children: .combine)
        }
        .padding(16)
        .lifeBoardPaperCard()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("journal.proactive.\(insight.id)")
    }

    private func proactiveInsightSymbol(_ insight: ReflectionInsight) -> String {
        switch insight.kind {
        case .decisionFollowUp: return "arrow.trianglehead.2.clockwise.rotate.90"
        case .weeklyRecap: return "calendar.badge.clock"
        case .moodTrajectory, .moodAssociation: return "waveform.path.ecg"
        case .resurfacedThread, .quietEntity: return "point.3.connected.trianglepath.dotted"
        case .repeatedQuestion: return "questionmark.bubble"
        case .carryForward: return "leaf"
        default: return "sparkles"
        }
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

private struct JournalPhotoEditor: View {
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
                .buttonStyle(.lifeBoardChip)
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

private struct JournalPhotoActivitySheet: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [image], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct JournalPhotoInspector: View {
    let media: JournalMediaValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var zoom: CGFloat = 1
    @State private var startingZoom: CGFloat = 1
    @State private var showsShare = false

    private var image: UIImage? {
        media.payload.flatMap(UIImage.init(data:))
    }

    var body: some View {
        NavigationStack {
            Group {
                if let image {
                    ScrollView([.horizontal, .vertical]) {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .scaleEffect(zoom)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(24)
                            .accessibilityLabel("Journal photo, full screen")
                            .accessibilityHint("Pinch to zoom. Double tap to return to the full photo.")
                            .onTapGesture(count: 2) {
                                withAnimation(reduceMotion ? nil : .snappy(duration: 0.22)) {
                                    zoom = 1
                                    startingZoom = 1
                                }
                            }
                            .gesture(
                                MagnifyGesture()
                                    .onChanged { value in
                                        zoom = min(max(startingZoom * value.magnification, 1), 5)
                                    }
                                    .onEnded { _ in
                                        startingZoom = zoom
                                    }
                            )
                    }
                    .scrollIndicators(.hidden)
                    .background(Color.lifeboard(.overlayScrim).ignoresSafeArea())
                } else {
                    ContentUnavailableView(
                        "Photo unavailable",
                        systemImage: "photo.badge.exclamationmark",
                        description: Text("The attachment record is safe, but its image is not available on this device.")
                    )
                }
            }
            .navigationTitle("Journal photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(Color.lifeboard(.overlayScrim), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                if image != nil {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Share", systemImage: "square.and.arrow.up") {
                            showsShare = true
                        }
                        .accessibilityHint("Shares a copy of this photo using the system share sheet")
                    }
                }
            }
            .sheet(isPresented: $showsShare) {
                if let image { JournalPhotoActivitySheet(image: image) }
            }
        }
    }
}

private struct JournalDayCard: View {
    let day: JournalDayValue
    let palette: DaypartPalette
    let onStar: () -> Void
    let onDelete: (() -> Void)?
    let onEditPhoto: (JournalMediaValue) -> Void
    let onMoveBlock: (UUID, Int) -> Void
    let onDeleteBlock: (UUID) -> Void
    var onSetAIExclusion: ((JournalAIExclusion) -> Void)?
    @State private var confirmsDelete = false
    @State private var playback = JournalAudioPlaybackController()
    @State private var mediaRevealProgress = 0.0
    @State private var inspectedPhoto: JournalMediaValue?
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
                            Button {
                                inspectedPhoto = media
                            } label: {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 260)
                                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                    .lifeboardJournalMediaReveal(progress: mediaRevealProgress)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Open Journal photo")
                            .accessibilityHint("Shows the full photo with zoom and sharing controls")
                        } else if block.kind == .photo {
                            unavailableAttachment(
                                title: "Photo unavailable",
                                detail: "Its place is preserved. Restore an encrypted backup or remove this block.",
                                symbol: "photo.badge.exclamationmark",
                                blockID: block.id
                            )
                        }
                        if block.kind == .audio,
                           let media = day.media.first(where: { $0.id == block.mediaID }),
                           media.relativePath?.isEmpty == false {
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
                            unavailableAttachment(
                                title: "Private audio unavailable",
                                detail: "The recording is not stored on this device. Restore an encrypted backup or remove this block.",
                                symbol: "waveform.badge.exclamationmark",
                                blockID: block.id
                            )
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
                            Button("View full screen", systemImage: "arrow.up.left.and.arrow.down.right") {
                                inspectedPhoto = media
                            }
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
        .sheet(item: $inspectedPhoto) { media in
            JournalPhotoInspector(media: media)
        }
    }

    @ViewBuilder
    private func blockIcon(_ block: JournalBlockValue) -> some View {
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

    private func unavailableAttachment(
        title: String,
        detail: String,
        symbol: String,
        blockID: UUID
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.subheadline.weight(.semibold))
            Text(detail)
                .font(.caption)
                .foregroundStyle(palette.color(for: .foregroundSecondary))
            Button("Remove unavailable attachment", role: .destructive) {
                onDeleteBlock(blockID)
            }
            .font(.caption.weight(.semibold))
            .frame(minHeight: 44)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(palette.color(for: .layerOne).opacity(0.22), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
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
private final class JournalAudioPlaybackController: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private(set) var playingMediaID: UUID?

    func toggle(_ media: JournalMediaValue) {
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
            let player = try AVAudioPlayer(contentsOf: JournalAudioFiles.url(relativePath: relativePath))
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

private struct JournalTextComposer: View {
    let prompt: JournalPrompt
    let initialText: String
    let onDraftChanged: (String, Int?) -> Void
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var committed = false

    init(
        prompt: JournalPrompt,
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
private final class JournalAudioRecorder: NSObject, AVAudioRecorderDelegate {
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
        // iOS asks at this moment, which is the right time — onboarding only
        // explains it. Record the outcome so nothing offers to prime it later.
        await MainActor.run { PermissionPromptState.recordRequested(.microphone) }
        guard permitted else {
            errorMessage = "Microphone is off. Turn it on in Settings to record."
            return
        }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.record, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            let url = try JournalAudioFiles.newRecordingURL()
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

enum JournalAudioFiles {
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
/// on-device SpeechAnalyzer with bounded concurrency and an overall timeout
/// (OffRecord parity).
private final class JournalSpeechTranscriber {
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
        ComposerScaffold(
            title: "Journal Privacy",
            subtitle: "What leaves Journal, and what never does.",
            cancelTitle: "Done",
            titleDisplayMode: .inline,
            isPrivacySensitive: true,
            identifier: "journal.privacy"
        ) {
            JournalAccessSection(controller: controller)
            JournalSharingSection(controller: controller)
            JournalRecoverySection(onCreateBackup: onCreateBackup, onImportBackup: onImportBackup)
        } commit: {
            EmptyView()
        }
    }
}

private struct JournalAccessSection: View {
    @Bindable var controller: JournalPrivacyController

    var body: some View {
        ComposerSection(
            "Access",
            footer: "Authentication uses Face ID, Touch ID, or the device passcode. Cancelling always leaves Journal locked."
        ) {
            Toggle("Require device authentication", isOn: Binding(
                get: { controller.policy.requiresAuthentication },
                set: { controller.updateAuthenticationRequirement($0) }
            ))
            .toggleStyle(.lifeBoardClay)
            .accessibilityIdentifier("journal.privacy.lock")
            Toggle("Hide Journal in the app switcher", isOn: $controller.policy.shieldsAppSwitcher)
                .toggleStyle(.lifeBoardClay)
        }
    }
}

private struct JournalSharingSection: View {
    @Bindable var controller: JournalPrivacyController

    var body: some View {
        ComposerSection(
            "Sharing",
            footer: "Journal evidence is off by default. Enabling it permits eligible evidence references, not unrestricted entry access. Semantic indexes remain protected and local-only, and are never included in ordinary exports."
        ) {
            Toggle("Exclude sensitive entries from ordinary exports", isOn: $controller.policy.excludesSensitiveEntriesFromExport)
                .toggleStyle(.lifeBoardClay)
            Toggle("Allow Journal evidence for Eva", isOn: $controller.policy.permitsJournalEvidenceForEva)
                .toggleStyle(.lifeBoardClay)
            // The Home journal card was hard-coded to a degraded state with no
            // way to grant consent anywhere in the app. This is that switch.
            Toggle("Show Journal on Home", isOn: Binding(
                get: { JournalHomeConsentStore.isGranted },
                set: { JournalHomeConsentStore.isGranted = $0 }
            ))
            .toggleStyle(.lifeBoardClay)
            .accessibilityIdentifier("journal.privacy.homeConsent")
        }
    }
}

private struct JournalRecoverySection: View {
    let onCreateBackup: () -> Void
    let onImportBackup: () -> Void

    var body: some View {
        ComposerSection("Encrypted recovery") {
            Button("Create encrypted backup", systemImage: "lock.doc", action: onCreateBackup)
                .buttonStyle(.lifeBoardPrimary)
            Button("Import encrypted backup", systemImage: "square.and.arrow.down", action: onImportBackup)
                .buttonStyle(.lifeBoardClay(.well, cornerRadius: Radius.pill))
        }
    }
}

struct JournalAudioCapture: View {
    enum Purpose { case journal, search }

    let purpose: Purpose
    let onSave: (String, TimeInterval, String?) async -> Bool
    let onTranscription: (String, String?) async -> Void
    let onDiscard: (String) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = JournalAudioRecorder()
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
                if let error = recorder.errorMessage {
                    Text(error).foregroundStyle(Color.lifeboard(.statusDanger))
                }
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
                        .buttonStyle(.lifeBoardChip)
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
                        .buttonStyle(.lifeBoardChip)
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
        let path = JournalAudioFiles.relativePath(for: capturedURL)
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
        let result = await JournalSpeechTranscriber().transcribe(url)
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
        let result = await JournalSpeechTranscriber().transcribe(url)
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
        let path = JournalAudioFiles.relativePath(for: capturedURL)
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
        let path = JournalAudioFiles.relativePath(for: capturedURL)
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
        let path = JournalAudioFiles.relativePath(for: capturedURL)
        processingState = .discarded
        if didPersist { await onDiscard(path) }
        else { try? JournalAudioFiles.delete(relativePath: path) }
        dismiss()
    }

    private static var hasSpeechConsent: Bool {
        UserDefaults.standard.bool(forKey: "lifeboard.journal.speech_consent.v1")
    }

    private static func duration(_ interval: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(interval) / 60, Int(interval) % 60)
    }
}

enum JournalInsightService {
    static func makeSnapshot(days: [JournalDayValue], now: Date = Date(), calendar: Calendar = .current) -> JournalInsightSnapshot {
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

enum JournalSpotlightIndexer {
    static func index(_ day: JournalDayValue) async {
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
