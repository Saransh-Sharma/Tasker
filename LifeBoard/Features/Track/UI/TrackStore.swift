import AVFAudio
import CoreSpotlight
import Foundation
import LifeBoardDomain
import LocalAuthentication
import LifeBoardPersistence
import Observation
import PhotosUI
import LifeBoardDomain
import Speech
import SwiftUI
import LifeBoardTranscription
import UIKit
import UniformTypeIdentifiers
import LifeBoardContracts

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
            errorMessage = TrackFoundationStore.readableFailure(error)
        }
    }

    func saveMood(_ mood: JournalMood, energy: Int?) async {
        do {
            try await repository.saveMoodCheckIn(.init(mood: mood, energy: energy))
            await load()
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
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
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
    }

    func archiveTracker(_ tracker: TrackerDefinitionValue) async {
        do {
            try await trackerService.archiveDefinition(tracker)
            var archived = tracker
            archived.isArchived = true
            await TrackerReminderCoordinator.shared.synchronize(archived)
            await load()
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
    }

    func deleteTracker(_ tracker: TrackerDefinitionValue) async {
        var archived = tracker
        archived.isArchived = true
        do {
            await TrackerReminderCoordinator.shared.synchronize(archived)
            try await trackerService.deleteDefinition(id: tracker.id)
            await load()
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
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
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
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
            Haptic.commit.play()
            await load()
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
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
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
    }

    func prepareMedicationExport(_ medication: MedicationDefinitionValue) async {
        do {
            let data = try await medicationService.export(medication: medication)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("LifeBoard-Medication-\(medication.id.uuidString).json")
            try data.write(to: url, options: [.atomic, .completeFileProtection])
            medicationExportURLs[medication.id] = url
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
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
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
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
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
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
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
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
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
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
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
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
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
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
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
    }

    func cancelFast() async {
        do {
            try await fastingTimerStore.cancel()
            await load()
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
    }

    func correctFast(_ session: FastingSessionValue, startDelta: TimeInterval = 0, endDelta: TimeInterval = 0) async {
        var value = session
        value.startedAt = session.startedAt.addingTimeInterval(startDelta)
        if let endedAt = session.endedAt { value.endedAt = endedAt.addingTimeInterval(endDelta) }
        value.completionKind = .corrected
        value.updatedAt = Date()
        guard value.endedAt.map({ $0 > value.startedAt }) ?? true else {
            errorMessage = String(localized: "End time must be after start.")
            return
        }
        do {
            try await applyCorrection(previous: .fasting(session), corrected: .fasting(value))
            await load()
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
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
        } catch { errorMessage = TrackFoundationStore.readableFailure(error) }
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
