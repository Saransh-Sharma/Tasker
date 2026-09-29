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
final class JournalStore {
    enum Section: String, CaseIterable, Identifiable {
        case today = "Today", library = "Library", calendar = "Calendar", gallery = "Gallery", insights = "Insights"
        var id: String { rawValue }

        /// What the lens is called. The raw value stays the accessibility
        /// identifier; the Insights lens reads "Patterns" because the app
        /// already has an Insights root.
        var title: String {
            switch self {
            case .today: return String(localized: "Today")
            case .library: return String(localized: "Library")
            case .calendar: return String(localized: "Calendar")
            case .gallery: return String(localized: "Gallery")
            case .insights: return String(localized: "Patterns")
            }
        }
    }

    private(set) var today: JournalDayValue?
    private(set) var days: [JournalDayValue] = []
    private(set) var allDays: [JournalDayValue] = []
    private(set) var draft: JournalDraftValue?
    private(set) var isLoading = false
    private(set) var searchState: JournalSearchState = .idle
    var reflectionReports: [WeeklyReflectionReport] = []
    var selectedReflectionID: UUID?
    var reflectionSourceSelection: Set<UUID> = []
    var exportPhase: AsyncActionPhase<JournalExportReceipt> = .idle
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
    /// What "Try again" on the error alert does; nil when retrying cannot help.
    var errorRetry: (@MainActor () async -> Void)?
    /// The week's reflection as it would read now, rebuilt when the days or
    /// saved versions change rather than on every render of the lens.
    private(set) var reflectionPreview: WeeklyReflectionReport?
    var reflectionPreviewWeek = Date()

    var hasActiveFilters: Bool { starredOnly || moodFilter != nil }

    func clearFilters() {
        starredOnly = false
        moodFilter = nil
        applyVisibleDays()
    }

    /// Plain words for the alert, and what "Try again" does.
    func reportProblem(_ message: String, retry: (@MainActor () async -> Void)? = nil) {
        errorRetry = retry
        errorMessage = message
    }

    let repository: any PhaseIIRepository
    private let derivedIndex: (any JournalDerivedIndexRepository)?
    private let derivedPipeline: JournalDerivedPipelineCoordinator?
    let reflectionRepository: (any WeeklyReflectionHistoryRepository)?
    let exportService: (any JournalExporting)?
    private let backupService: (any JournalBackupServicing)?
    private let proactiveRepository: LocalProactiveReflectionRepository?
    private var proactiveFeedback: [String: ReflectionCardFeedback] = [:]
    private var proactiveFollowUps: [DecisionFollowUpState] = []
    private var hasBuiltDerivedIndex = false
    private var reflectionInvalidationTask: Task<Void, Never>?
    var exportTask: Task<Void, Never>?
    var lastExportFormat: JournalExportFormat?
    var lastExportIncludedSensitiveFields = false

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
                searchState = .unavailable(String(localized: "Showing exact matches only."))
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
            // Repair and compare every day off the main actor: the walk
            // touches each day's blocks and media (photo payloads included)
            // and used to stall the first frame of the Journal.
            let repairs = await Task.detached(priority: .userInitiated) {
                fetchedDays.map { value -> (day: JournalDayValue, changed: Bool, removedAudio: [String]) in
                    let reconciliation = JournalMediaReconciler.reconcile(value)
                    let changed = reconciliation.day != value
                    let removedAudio = changed
                        ? reconciliation.removedMedia.compactMap { $0.kind == .audio ? $0.relativePath : nil }
                        : []
                    return (reconciliation.day, changed, removedAudio)
                }
            }.value
            var repairedDays: [JournalDayValue] = []
            repairedDays.reserveCapacity(repairs.count)
            var removedAudioPaths: [String] = []
            for repair in repairs {
                if repair.changed {
                    try await repository.saveJournalDay(repair.day)
                    removedAudioPaths += repair.removedAudio
                }
                repairedDays.append(repair.day)
            }
            allDays = repairedDays
            today = fetchedToday.flatMap { current in
                repairedDays.first(where: { $0.id == current.id }) ?? JournalMediaReconciler.reconcile(current).day
            }
            draft = fetchedDraft
            let retainedAudioPaths = Set(
                repairedDays.flatMap(\.media).compactMap { $0.kind == .audio ? $0.relativePath : nil }
                + (fetchedDraft?.audioRelativePaths ?? [])
            )
            // File cleanup enumerates the protected audio directory; it never
            // needs the main actor.
            let audioToRemove = removedAudioPaths
            Task.detached(priority: .utility) {
                for path in audioToRemove { try? JournalAudioFiles.delete(relativePath: path) }
                try? JournalAudioFiles.deleteOrphans(retaining: retainedAudioPaths)
            }
            applyVisibleDays()
            if reflectionPreview != nil || section == .insights { refreshReflectionPreview() }
            if !hasBuiltDerivedIndex { await rebuildDerivedIndex() }
            await refreshProactiveReflections()
            await loadWatchRecovery()
        } catch is CancellationError {
            return
        } catch {
            reportProblem(String(localized: "Couldn’t open your journal. Nothing was lost.")) { [weak self] in
                await self?.load()
            }
        }
    }

    /// Rebuilds the week's preview report. Called when the lens opens and
    /// when the days or saved versions change, never from a view body.
    func refreshReflectionPreview() {
        reflectionPreview = WeeklyReflectionService.makeReport(
            entries: allDays.map(JournalEntrySnapshot.init(day:)),
            weekContaining: reflectionPreviewWeek,
            previousVersions: reflectionReports
        )
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
            let eligible = result.insights.filter { insight in
                let feedback = proactiveFeedback[insight.feedbackKey]
                return feedback?.saved != true
                    && feedback?.isDismissed != true
                    && feedback?.isSnoozed(now: now) != true
            }
            let candidates = eligible.map { insight in
                let usefulProbability: Double
                switch insight.confidence {
                case .low: usefulProbability = 0.65
                case .medium: usefulProbability = 0.78
                case .high: usefulProbability = 0.9
                }
                return EvaProactiveCandidate(
                    kind: insight.kind.rawValue,
                    insight: insight.asUnifiedInsight(),
                    usefulProbability: usefulProbability
                )
            }
            let admittedIDs = Set(await EvaProactiveCoordinator.shared.admitted(candidates, now: now).map(\.insight.id))
            proactiveInsights = eligible.filter { admittedIDs.contains($0.id) }
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
        await EvaProactiveCoordinator.shared.dismiss(.init(
            kind: insight.kind.rawValue,
            insight: insight.asUnifiedInsight(),
            usefulProbability: 1
        ))
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

    func createEncryptedBackup(passphrase: String) async {
        guard let backupService else {
            backupPhase = .recoverableFailure(.init(message: String(localized: "Backups aren’t available on this device."), recovery: .retry))
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
            backupPhase = .recoverableFailure(.init(message: String(localized: "Couldn’t create backup. Check free space and try again."), recovery: .retry))
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
            importPhase = .recoverableFailure(.init(message: String(localized: "Import isn’t available on this device."), recovery: .retry))
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
            importPhase = .recoverableFailure(.init(message: String(localized: "Couldn’t import backup. Check the passphrase and file."), recovery: .retry))
        }
    }

    func resetBackupPhases() {
        backupPhase = .idle
        importPhase = .idle
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
            searchState = .unavailable(String(localized: "Showing exact matches only."))
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
            searchState = .failed(String(localized: "Couldn’t finish search. Showing exact matches."))
            applyVisibleDays()
        }
    }

    private func rebuildDerivedIndex() async {
        guard let derivedIndex else { return }
        searchState = .building(progress: 0, message: String(localized: "Preparing search…"))
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
            searchState = .unavailable(String(localized: "Showing exact matches only."))
        }
    }

    /// Reports whether the entry reached disk. `@discardableResult` so the
    /// existing Void call sites keep compiling untouched.
    @discardableResult
    func appendText(_ text: String, promptID: String? = nil) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        var day = today ?? JournalDayValue(day: Date())
        day.blocks.append(.init(dayID: day.id, kind: .text, text: trimmed, promptID: promptID, ordinal: day.blocks.count))
        day.updatedAt = Date()
        guard await save(day) else { return false }
        await clearDraft()
        return true
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
        } catch {
            reportProblem(String(localized: "Couldn’t save draft. Keep this open and try again."))
        }
    }

    func clearDraft() async {
        guard let draft else { return }
        do {
            try await repository.deleteJournalDraft(id: draft.id)
            self.draft = nil
        } catch {
            reportProblem(String(localized: "Couldn’t clear the old draft. Your entry was saved."))
        }
    }

    /// What a mood check-in wrote, so its receipt can take it back.
    struct MoodEntry: Equatable {
        let dayID: UUID
        let blockID: UUID
        let checkInID: UUID
        let previousRepresentativeCheckInID: UUID?
    }

    /// `nil` when the check-in did not reach disk; the caller's haptic and
    /// receipt wait for this answer.
    @discardableResult
    func appendMood(_ mood: JournalMood, energy: Int?, reasons: [String] = []) async -> MoodEntry? {
        var day = today ?? JournalDayValue(day: Date())
        let now = Date()
        // Reasons live on the mood block's text column, namespaced (no schema change).
        let block = JournalBlockValue(dayID: day.id, kind: .mood, text: JournalMoodReasons.encode(reasons), mood: mood, energy: energy, createdAt: now, updatedAt: now, ordinal: day.blocks.count)
        day.blocks.append(block)
        day.updatedAt = now
        let previousRepresentative = day.representativeCheckInID
        do {
            let checkIn = MoodEnergyCheckInValue(mood: mood, energy: energy, createdAt: now, representativeDay: day.day, isRepresentative: true)
            day.representativeCheckInID = checkIn.id
            try await repository.saveMoodCheckIn(checkIn)
            guard await save(day) else { return nil }
            return MoodEntry(dayID: day.id, blockID: block.id, checkInID: checkIn.id, previousRepresentativeCheckInID: previousRepresentative)
        } catch {
            reportProblem(String(localized: "Couldn’t save check-in.")) { [weak self] in
                await self?.appendMood(mood, energy: energy, reasons: reasons)
            }
            return nil
        }
    }

    /// Undo for a mood check-in: the block goes, the check-in goes, and the
    /// day's representative check-in is what it was before.
    @discardableResult
    func undoMood(_ entry: MoodEntry) async -> Bool {
        let source = today?.id == entry.dayID ? today : allDays.first(where: { $0.id == entry.dayID })
        guard var day = source else { return false }
        day.blocks.removeAll { $0.id == entry.blockID }
        for index in day.blocks.indices { day.blocks[index].ordinal = index }
        day.representativeCheckInID = entry.previousRepresentativeCheckInID
        day.updatedAt = Date()
        guard await save(day) else { return false }
        do {
            try await repository.deleteMoodCheckIn(id: entry.checkInID)
        } catch {
            reportProblem(String(localized: "Couldn’t fully remove the check-in."))
        }
        return true
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
            errorMessage = String(localized: "Couldn’t find the recording. Nothing was removed.")
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
            errorMessage = String(localized: "Couldn’t find the photo. Nothing changed.")
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

    /// Saved words can be corrected. The store could only append, move, and
    /// delete, so fixing a typo meant deleting the entry and retyping it.
    /// Empty text is refused rather than saved: removing words is "Delete".
    @discardableResult
    func updateBlockText(dayID: UUID, blockID: UUID, text: String) async -> Bool {
        guard var day = allDays.first(where: { $0.id == dayID }),
              let index = day.blocks.firstIndex(where: { $0.id == blockID }) else { return false }
        guard let updated = JournalBlockTextEdit.apply(text, to: day.blocks[index]) else { return false }
        day.blocks[index] = updated
        day.updatedAt = updated.updatedAt
        return await save(day)
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

    /// The day's title lives in the persisted `summary`. Empty clears it.
    func setTitle(_ title: String, for dayValue: JournalDayValue) async -> Bool {
        var day = dayValue
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        day.summary = trimmed.isEmpty ? nil : trimmed
        day.updatedAt = Date()
        return await save(day)
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
            try await JournalIndexingService(
                repository: repository,
                derivedIndex: derivedIndex,
                derivedPipeline: derivedPipeline
            ).remove(dayID: day.id)
            await load()
        } catch {
            reportProblem(String(localized: "Couldn’t delete this day.")) { [weak self] in
                await self?.delete(day)
            }
        }
    }

    @discardableResult
    func save(_ day: JournalDayValue) async -> Bool {
        do {
            try await repository.saveJournalDay(day)
            try await JournalIndexingService(
                repository: repository,
                derivedIndex: derivedIndex,
                derivedPipeline: derivedPipeline
            ).upsert(day)
            await load()
            return true
        } catch {
            reportProblem(String(localized: "Couldn’t save that change.")) { [weak self] in
                await self?.save(day)
            }
            return false
        }
    }

    var insights: JournalInsightSnapshot {
        JournalInsightService.makeSnapshot(days: days)
    }
}
