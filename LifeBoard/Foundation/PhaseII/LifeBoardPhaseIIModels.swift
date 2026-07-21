import Foundation
import JournalFoundation
import ReflectionKit

// MARK: - Trackers and care

public enum LifeBoardTrackerKind: String, Codable, CaseIterable, Sendable {
    case boolean
    case count
    case quantity
    case rating
    case duration
}

public struct LifeBoardTrackerDefinitionValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var kind: LifeBoardTrackerKind
    public var unitLabel: String?
    public var targetValue: Double?
    public var schedule: Set<Int>
    public var reminderMinutes: Int?
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        kind: LifeBoardTrackerKind,
        unitLabel: String? = nil,
        targetValue: Double? = nil,
        schedule: Set<Int> = Set(1...7),
        reminderMinutes: Int? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.unitLabel = unitLabel
        self.targetValue = targetValue
        self.schedule = schedule
        self.reminderMinutes = reminderMinutes
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct LifeBoardTrackerEntryValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var trackerID: UUID
    public var timestamp: Date
    public var numericValue: Double?
    public var booleanValue: Bool?
    public var note: String?

    public init(
        id: UUID = UUID(),
        trackerID: UUID,
        timestamp: Date = Date(),
        numericValue: Double? = nil,
        booleanValue: Bool? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.trackerID = trackerID
        self.timestamp = timestamp
        self.numericValue = numericValue
        self.booleanValue = booleanValue
        self.note = note
    }
}

public struct LifeBoardMoodEnergyCheckInValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var mood: LifeBoardJournalMood
    public var energy: Int?
    public var createdAt: Date
    public var representativeDay: Date?
    public var isRepresentative: Bool

    public init(
        id: UUID = UUID(),
        mood: LifeBoardJournalMood,
        energy: Int?,
        createdAt: Date = Date(),
        representativeDay: Date? = nil,
        isRepresentative: Bool = false
    ) {
        self.id = id
        self.mood = mood
        self.energy = energy.map { min(5, max(1, $0)) }
        self.createdAt = createdAt
        self.representativeDay = representativeDay
        self.isRepresentative = isRepresentative
    }
}

public enum LifeBoardMedicationEventStatus: String, Codable, CaseIterable, Sendable {
    case scheduled
    case taken
    case skipped
    case snoozed
    case rescheduled
    case unresolved

    public var contributesToAdherence: Bool {
        switch self {
        case .taken, .skipped: true
        case .scheduled, .snoozed, .rescheduled, .unresolved: false
        }
    }
}

public struct LifeBoardMedicationDefinitionValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var dosageText: String?
    public var instructions: String?
    public var healthCorrelationID: String?
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        dosageText: String? = nil,
        instructions: String? = nil,
        healthCorrelationID: String? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.dosageText = dosageText
        self.instructions = instructions
        self.healthCorrelationID = healthCorrelationID
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct LifeBoardMedicationScheduleValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var medicationID: UUID
    public var windowStartMinutes: Int
    public var windowEndMinutes: Int
    public var weekdays: Set<Int>
    public var reminderEnabled: Bool

    public init(
        id: UUID = UUID(),
        medicationID: UUID,
        windowStartMinutes: Int,
        windowEndMinutes: Int,
        weekdays: Set<Int> = Set(1...7),
        reminderEnabled: Bool = true
    ) {
        self.id = id
        self.medicationID = medicationID
        self.windowStartMinutes = min(1_439, max(0, windowStartMinutes))
        self.windowEndMinutes = min(1_439, max(0, windowEndMinutes))
        self.weekdays = weekdays
        self.reminderEnabled = reminderEnabled
    }
}

public struct LifeBoardMedicationEventValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var medicationID: UUID
    public var scheduledAt: Date
    public var status: LifeBoardMedicationEventStatus
    public var resolvedAt: Date?
    public var note: String?

    public init(
        id: UUID = UUID(),
        medicationID: UUID,
        scheduledAt: Date,
        status: LifeBoardMedicationEventStatus = .scheduled,
        resolvedAt: Date? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.medicationID = medicationID
        self.scheduledAt = scheduledAt
        self.status = status
        self.resolvedAt = resolvedAt
        self.note = note
    }
}

public enum LifeBoardFastingCompletionKind: String, Codable, CaseIterable, Sendable {
    case planned
    case early
    case cancelled
    case corrected
}

public struct LifeBoardFastingSessionValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var targetDuration: TimeInterval?
    public var reminderOffsets: [TimeInterval]
    public var note: String?
    /// Optional until the additive Wellness Core model is available. Keeping this
    /// optional also lets existing correction receipts decode without migration.
    public var completionKind: LifeBoardFastingCompletionKind?
    public var updatedAt: Date?

    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        targetDuration: TimeInterval? = nil,
        reminderOffsets: [TimeInterval] = [],
        note: String? = nil,
        completionKind: LifeBoardFastingCompletionKind? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.targetDuration = targetDuration
        self.reminderOffsets = reminderOffsets
        self.note = note
        self.completionKind = completionKind
        self.updatedAt = updatedAt
    }

    public func elapsed(at now: Date = Date()) -> TimeInterval {
        max(0, (endedAt ?? now).timeIntervalSince(startedAt))
    }

    public var targetEnd: Date? {
        targetDuration.map(startedAt.addingTimeInterval)
    }

    public func progress(at now: Date = Date()) -> Double? {
        guard let targetDuration, targetDuration > 0 else { return nil }
        return min(1, elapsed(at: now) / targetDuration)
    }
}

public struct LifeBoardHealthSnapshot: Equatable, Sendable {
    public enum Availability: Equatable, Sendable {
        case notRequested
        case unavailable
        case available
    }

    public var availability: Availability
    public var steps: Double?
    public var activeCalories: Double?
    public var bodyMassKilograms: Double?
    public var distanceMeters: Double?
    public var workouts: [WorkoutRecord]
    public var sleepNotes: [SleepNote]
    public var measuredAt: Date?

    public init(
        availability: Availability,
        steps: Double?,
        activeCalories: Double?,
        bodyMassKilograms: Double? = nil,
        distanceMeters: Double? = nil,
        workouts: [WorkoutRecord] = [],
        sleepNotes: [SleepNote] = [],
        measuredAt: Date?
    ) {
        self.availability = availability
        self.steps = steps
        self.activeCalories = activeCalories
        self.bodyMassKilograms = bodyMassKilograms
        self.distanceMeters = distanceMeters
        self.workouts = workouts
        self.sleepNotes = sleepNotes
        self.measuredAt = measuredAt
    }

    public static let notRequested = Self(
        availability: .notRequested,
        steps: nil,
        activeCalories: nil,
        measuredAt: nil
    )
}

// MARK: - Journal

public enum LifeBoardJournalBlockKind: String, Codable, CaseIterable, Sendable {
    case text
    case mood
    case audio
    case photo
    case prompt
    /// A transcript produced from a voice recording (OffRecord parity);
    /// rendered like text but attributed to speech capture.
    case voice
}

public enum LifeBoardJournalMediaKind: String, Codable, Sendable {
    case photo
    case audio
}

public enum LifeBoardJournalMediaSyncPolicy: String, Codable, Sendable {
    case privateCloud
    case protectedLocalOnly
}

public struct LifeBoardJournalMediaValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var dayID: UUID
    public var kind: LifeBoardJournalMediaKind
    public var payload: Data?
    public var relativePath: String?
    public var duration: TimeInterval?
    public var createdAt: Date
    public var syncPolicy: LifeBoardJournalMediaSyncPolicy

    public init(
        id: UUID = UUID(),
        dayID: UUID,
        kind: LifeBoardJournalMediaKind,
        payload: Data? = nil,
        relativePath: String? = nil,
        duration: TimeInterval? = nil,
        createdAt: Date = Date(),
        syncPolicy: LifeBoardJournalMediaSyncPolicy
    ) {
        self.id = id
        self.dayID = dayID
        self.kind = kind
        self.payload = payload
        self.relativePath = relativePath
        self.duration = duration
        self.createdAt = createdAt
        self.syncPolicy = syncPolicy
    }
}

public struct LifeBoardJournalBlockValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var dayID: UUID
    public var kind: LifeBoardJournalBlockKind
    public var text: String?
    public var mood: LifeBoardJournalMood?
    public var energy: Int?
    public var mediaID: UUID?
    public var promptID: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var ordinal: Int

    public init(
        id: UUID = UUID(),
        dayID: UUID,
        kind: LifeBoardJournalBlockKind,
        text: String? = nil,
        mood: LifeBoardJournalMood? = nil,
        energy: Int? = nil,
        mediaID: UUID? = nil,
        promptID: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        ordinal: Int = 0
    ) {
        self.id = id
        self.dayID = dayID
        self.kind = kind
        self.text = text
        self.mood = mood
        self.energy = energy
        self.mediaID = mediaID
        self.promptID = promptID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.ordinal = ordinal
    }
}

public struct LifeBoardJournalDayValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var day: Date
    public var summary: String?
    public var isStarred: Bool
    public var representativeCheckInID: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var blocks: [LifeBoardJournalBlockValue]
    public var media: [LifeBoardJournalMediaValue]
    /// Per-entry AI participation (shared JournalFoundation contract).
    /// Enforced at semantic-index ingest, reflection input, and Eva
    /// evidence assembly.
    public var aiExclusion: JournalAIExclusion

    public init(
        id: UUID = UUID(),
        day: Date,
        summary: String? = nil,
        isStarred: Bool = false,
        representativeCheckInID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        blocks: [LifeBoardJournalBlockValue] = [],
        media: [LifeBoardJournalMediaValue] = [],
        aiExclusion: JournalAIExclusion = .included
    ) {
        self.id = id
        // Preserve the caller's calendar-normalized day. Re-normalizing with
        // Calendar.current corrupts fixtures and synced values when the caller
        // is operating in a different time zone.
        self.day = day
        self.summary = summary
        self.isStarred = isStarred
        self.representativeCheckInID = representativeCheckInID
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.blocks = blocks.sorted {
            $0.ordinal == $1.ordinal ? $0.createdAt < $1.createdAt : $0.ordinal < $1.ordinal
        }
        self.media = media.sorted { $0.createdAt < $1.createdAt }
        self.aiExclusion = aiExclusion
    }

    /// Backward-compatible decoding: drafts and backups written before the
    /// AI-exclusion contract decode as `.included`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            day: try container.decode(Date.self, forKey: .day),
            summary: try container.decodeIfPresent(String.self, forKey: .summary),
            isStarred: try container.decodeIfPresent(Bool.self, forKey: .isStarred) ?? false,
            representativeCheckInID: try container.decodeIfPresent(UUID.self, forKey: .representativeCheckInID),
            createdAt: try container.decode(Date.self, forKey: .createdAt),
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            blocks: try container.decodeIfPresent([LifeBoardJournalBlockValue].self, forKey: .blocks) ?? [],
            media: try container.decodeIfPresent([LifeBoardJournalMediaValue].self, forKey: .media) ?? [],
            aiExclusion: try container.decodeIfPresent(JournalAIExclusion.self, forKey: .aiExclusion) ?? .included
        )
    }

    public var displayText: String {
        blocks.compactMap(\.text).joined(separator: "\n")
    }

    public var latestMood: LifeBoardJournalMood? {
        blocks.reversed().compactMap(\.mood).first
    }
}

public struct JournalMediaReconciliation: Equatable, Sendable {
    public var day: LifeBoardJournalDayValue
    public var removedMedia: [LifeBoardJournalMediaValue]

    public init(day: LifeBoardJournalDayValue, removedMedia: [LifeBoardJournalMediaValue]) {
        self.day = day
        self.removedMedia = removedMedia
    }
}

public enum JournalMediaReconciler {
    /// Removes media records that no block references and media blocks whose
    /// backing record is absent. The caller persists the repaired day before
    /// deleting any protected file, so interrupted cleanup remains recoverable.
    public static func reconcile(_ input: LifeBoardJournalDayValue) -> JournalMediaReconciliation {
        var day = input
        let knownMediaIDs = Set(day.media.map(\.id))
        day.blocks.removeAll { block in
            guard block.kind == .photo || block.kind == .audio else { return false }
            guard let mediaID = block.mediaID else { return true }
            return knownMediaIDs.contains(mediaID) == false
        }
        let referencedMediaIDs = Set(day.blocks.compactMap(\.mediaID))
        let removed = day.media.filter { referencedMediaIDs.contains($0.id) == false }
        day.media.removeAll { referencedMediaIDs.contains($0.id) == false }
        for index in day.blocks.indices { day.blocks[index].ordinal = index }
        if day != input { day.updatedAt = Date() }
        return JournalMediaReconciliation(day: day, removedMedia: removed)
    }
}

public struct LifeBoardJournalDraftValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var dayID: UUID
    public var day: Date
    public var text: String
    public var mood: LifeBoardJournalMood?
    public var energy: Int?
    public var photoPayloads: [Data]
    public var audioRelativePaths: [String]
    public var promptID: String?
    public var editPosition: Int?
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        dayID: UUID,
        day: Date,
        text: String = "",
        mood: LifeBoardJournalMood? = nil,
        energy: Int? = nil,
        photoPayloads: [Data] = [],
        audioRelativePaths: [String] = [],
        promptID: String? = nil,
        editPosition: Int? = nil,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.dayID = dayID
        self.day = day
        self.text = text
        self.mood = mood
        self.energy = energy
        self.photoPayloads = Array(photoPayloads.prefix(5))
        self.audioRelativePaths = audioRelativePaths
        self.promptID = promptID
        self.editPosition = editPosition
        self.updatedAt = updatedAt
    }
}

public struct LifeBoardJournalPrompt: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var supportiveCopy: String

    public static func contextual(daypart: ResolvedDaypart, hasEntry: Bool) -> Self {
        if hasEntry {
            return Self(id: "continue", title: "Anything else worth keeping?", supportiveCopy: "A sentence is enough.")
        }
        switch daypart {
        case .morning:
            return Self(id: "morning", title: "What would make today feel kind?", supportiveCopy: "Name one thing, not the whole plan.")
        case .afternoon:
            return Self(id: "afternoon", title: "What is taking up space right now?", supportiveCopy: "You do not have to solve it here.")
        case .evening:
            return Self(id: "evening", title: "What stayed with you today?", supportiveCopy: "Keep the part that mattered.")
        case .night:
            return Self(id: "night", title: "What can you set down for tonight?", supportiveCopy: "Nothing needs to be polished.")
        }
    }
}

public struct LifeBoardJournalInsightSnapshot: Equatable, Sendable {
    public var daysWritten: Int
    public var currentStreak: Int
    public var totalWords: Int
    public var dominantMood: LifeBoardJournalMood?
    public var averageEnergy: Double?
    public var evidenceDayIDs: [UUID]

    public static let empty = Self(daysWritten: 0, currentStreak: 0, totalWords: 0, dominantMood: nil, averageEnergy: nil, evidenceDayIDs: [])
}

// MARK: Journal public contracts

public struct JournalMediaAttachment: Identifiable, Codable, Hashable, Sendable {
    public enum ProcessingState: String, Codable, CaseIterable, Sendable {
        case queued
        case ready
        case transcribing
        case transcriptionComplete
        case transcriptionFailed
        case manualTranscription
        case discarded
        case missing
    }

    public let id: UUID
    public var kind: LifeBoardJournalMediaKind
    public var localRelativePath: String?
    public var duration: TimeInterval?
    public var transcription: String?
    public var processingState: ProcessingState
    public var syncPolicy: LifeBoardJournalMediaSyncPolicy
    public var createdAt: Date

    public init(
        id: UUID,
        kind: LifeBoardJournalMediaKind,
        localRelativePath: String?,
        duration: TimeInterval?,
        transcription: String? = nil,
        processingState: ProcessingState = .ready,
        syncPolicy: LifeBoardJournalMediaSyncPolicy,
        createdAt: Date
    ) {
        self.id = id
        self.kind = kind
        self.localRelativePath = localRelativePath
        self.duration = duration
        self.transcription = transcription
        self.processingState = processingState
        self.syncPolicy = syncPolicy
        self.createdAt = createdAt
    }
}

public struct JournalEntrySnapshot: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var date: Date
    public var title: String?
    public var text: String
    public var mood: LifeBoardJournalMood?
    public var energy: Int?
    public var isStarred: Bool
    public var attachments: [JournalMediaAttachment]
    public var updatedAt: Date
    /// Per-entry AI participation, carried into every derived surface.
    public var aiExclusion: JournalAIExclusion

    public init(
        id: UUID,
        date: Date,
        title: String?,
        text: String,
        mood: LifeBoardJournalMood?,
        energy: Int?,
        isStarred: Bool,
        attachments: [JournalMediaAttachment],
        updatedAt: Date,
        aiExclusion: JournalAIExclusion = .included
    ) {
        self.id = id
        self.date = date
        self.title = title
        self.text = text
        self.mood = mood
        self.energy = energy
        self.isStarred = isStarred
        self.attachments = attachments
        self.updatedAt = updatedAt
        self.aiExclusion = aiExclusion
    }

    public init(day: LifeBoardJournalDayValue) {
        id = day.id
        date = day.day
        title = day.summary
        text = day.displayText
        mood = day.latestMood
        energy = day.blocks.reversed().compactMap(\.energy).first
        isStarred = day.isStarred
        let transcriptionByMediaID: [UUID: String] = Dictionary(
            uniqueKeysWithValues: day.blocks.compactMap { block in
                guard block.kind == .audio,
                      let mediaID = block.mediaID,
                      let text = block.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      text.isEmpty == false else { return nil }
                return (mediaID, text)
            }
        )
        attachments = day.media.map { media in
            let transcription = transcriptionByMediaID[media.id]
            return JournalMediaAttachment(
                id: media.id,
                kind: media.kind,
                localRelativePath: media.relativePath,
                duration: media.duration,
                transcription: transcription,
                processingState: media.kind == .audio && transcription != nil ? .transcriptionComplete : .ready,
                syncPolicy: media.syncPolicy,
                createdAt: media.createdAt
            )
        }
        updatedAt = day.updatedAt
        aiExclusion = day.aiExclusion
    }

    /// Derived payloads written before the AI-exclusion contract decode as
    /// `.included`; the derived index is rebuildable regardless.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try container.decode(UUID.self, forKey: .id),
            date: try container.decode(Date.self, forKey: .date),
            title: try container.decodeIfPresent(String.self, forKey: .title),
            text: try container.decode(String.self, forKey: .text),
            mood: try container.decodeIfPresent(LifeBoardJournalMood.self, forKey: .mood),
            energy: try container.decodeIfPresent(Int.self, forKey: .energy),
            isStarred: try container.decodeIfPresent(Bool.self, forKey: .isStarred) ?? false,
            attachments: try container.decodeIfPresent([JournalMediaAttachment].self, forKey: .attachments) ?? [],
            updatedAt: try container.decode(Date.self, forKey: .updatedAt),
            aiExclusion: try container.decodeIfPresent(JournalAIExclusion.self, forKey: .aiExclusion) ?? .included
        )
    }
}

public struct JournalEvidenceReference: Identifiable, Codable, Hashable, Sendable {
    public enum MatchReason: String, Codable, CaseIterable, Sendable {
        case exact
        case meaning
        case topic
        case recent
    }

    public let id: String
    public var entryID: UUID
    public var date: Date
    public var snippet: String
    public var score: Double
    public var matchReason: MatchReason

    public init(
        id: String,
        entryID: UUID,
        date: Date,
        snippet: String,
        score: Double,
        matchReason: MatchReason
    ) {
        self.id = id
        self.entryID = entryID
        self.date = date
        self.snippet = snippet
        self.score = min(1, max(0, score))
        self.matchReason = matchReason
    }
}

public enum JournalSearchState: Equatable, Sendable {
    case idle
    case searching
    case building(progress: Double, message: String)
    case ready([JournalEvidenceReference])
    case unavailable(String)
    case failed(String)
}

public protocol JournalDerivedIndexRepository: Sendable {
    func rebuild(entries: [JournalEntrySnapshot]) async throws
    func upsert(entry: JournalEntrySnapshot) async throws
    func remove(entryID: UUID) async throws
    func search(query: String, limit: Int) async throws -> [JournalEvidenceReference]
    func invalidate() async throws
}

public struct WeeklyReflectionSourceSelection: Codable, Hashable, Sendable {
    public var includedEntryIDs: Set<UUID>
    public var excludesSensitiveEntries: Bool

    public init(includedEntryIDs: Set<UUID>, excludesSensitiveEntries: Bool = true) {
        self.includedEntryIDs = includedEntryIDs
        self.excludesSensitiveEntries = excludesSensitiveEntries
    }
}

public struct WeeklyReflectionReport: Identifiable, Codable, Hashable, Sendable {
    public enum Density: String, Codable, CaseIterable, Sendable {
        case empty
        case light
        case full
    }

    public let id: UUID
    public var weekStart: Date
    public var weekEnd: Date
    public var density: Density
    public var summary: String
    public var takeaway: String?
    public var sourceSelection: WeeklyReflectionSourceSelection
    public var version: Int
    public var createdAt: Date
    public var dismissedAt: Date?

    public init(
        id: UUID = UUID(),
        weekStart: Date,
        weekEnd: Date,
        density: Density,
        summary: String,
        takeaway: String? = nil,
        sourceSelection: WeeklyReflectionSourceSelection,
        version: Int = 1,
        createdAt: Date = Date(),
        dismissedAt: Date? = nil
    ) {
        self.id = id
        self.weekStart = weekStart
        self.weekEnd = weekEnd
        self.density = density
        self.summary = summary
        self.takeaway = takeaway
        self.sourceSelection = sourceSelection
        self.version = max(1, version)
        self.createdAt = createdAt
        self.dismissedAt = dismissedAt
    }
}

public protocol WeeklyReflectionHistoryRepository: Sendable {
    func reports(weekContaining date: Date?) async throws -> [WeeklyReflectionReport]
    func save(_ report: WeeklyReflectionReport) async throws
    func delete(id: UUID) async throws
    func replaceAll(_ reports: [WeeklyReflectionReport]) async throws
}

public enum WeeklyReflectionEngine {
    public static func makeReport(
        entries: [JournalEntrySnapshot],
        weekContaining date: Date = Date(),
        calendar inputCalendar: Calendar = .current,
        previousVersions: [WeeklyReflectionReport] = []
    ) -> WeeklyReflectionReport {
        var calendar = inputCalendar
        calendar.firstWeekday = 2 // Monday
        calendar.minimumDaysInFirstWeek = 4
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysSinceMonday = (weekday + 5) % 7
        let weekStart = calendar.date(byAdding: .day, value: -daysSinceMonday, to: startOfDay) ?? startOfDay
        let exclusiveEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart.addingTimeInterval(7 * 86_400)
        let weekEnd = calendar.date(byAdding: .second, value: -1, to: exclusiveEnd) ?? exclusiveEnd
        let included = entries
            .filter { $0.date >= weekStart && $0.date < exclusiveEnd && $0.aiExclusion.permitsReflection }
            .sorted { $0.date < $1.date }
        let nonempty = included.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        let sharedSnapshots = nonempty.map {
            ReflectionKit.WeeklyReflectionEntrySnapshot(
                id: $0.id,
                date: $0.date,
                updatedAt: $0.updatedAt,
                mood: $0.mood?.rawValue,
                text: $0.text,
                sourceType: $0.attachments.contains(where: { $0.kind == .audio }) ? .voiceTranscript : .text
            )
        }
        let sharedEligibility = WeeklyReflectionEligibilityEngine.evaluate(
            entries: sharedSnapshots,
            in: .init(start: weekStart, end: weekEnd)
        )
        let wordCount = sharedEligibility.wordCount
        let activeDays = Set(nonempty.map { calendar.startOfDay(for: $0.date) }).count
        let density: WeeklyReflectionReport.Density
        switch sharedEligibility.kind {
        case .empty: density = .empty
        case .light: density = .light
        case .full: density = .full
        }

        let moods = nonempty.compactMap(\.mood).filter { $0 != .none }
        let moodGroups: [LifeBoardJournalMood: [LifeBoardJournalMood]] = Dictionary(grouping: moods, by: { $0 })
        let moodCounts: [(mood: LifeBoardJournalMood, count: Int)] = moodGroups.map { (mood: $0.key, count: $0.value.count) }
        let rankedMoods = moodCounts.sorted { lhs, rhs in
            lhs.count == rhs.count ? lhs.mood.rawValue < rhs.mood.rawValue : lhs.count > rhs.count
        }
        let dominantMood = rankedMoods.first?.mood
        let energies = nonempty.compactMap(\.energy)
        let averageEnergy = energies.isEmpty ? nil : Double(energies.reduce(0, +)) / Double(energies.count)

        let summary: String
        switch density {
        case .empty:
            summary = "There is not enough Journal evidence to summarize this week yet."
        case .light:
            summary = "You kept \(activeDays) day\(activeDays == 1 ? "" : "s") and \(wordCount) words this week. " + evidenceSentence(dominantMood: dominantMood, averageEnergy: averageEnergy)
        case .full:
            summary = "Across \(activeDays) Journal days and \(wordCount) words, " + evidenceSentence(dominantMood: dominantMood, averageEnergy: averageEnergy)
        }
        let matchingVersions = previousVersions.filter { calendar.isDate($0.weekStart, inSameDayAs: weekStart) }
        let nextVersion = (matchingVersions.map(\.version).max() ?? 0) + 1

        return WeeklyReflectionReport(
            weekStart: weekStart,
            weekEnd: weekEnd,
            density: density,
            summary: summary,
            sourceSelection: WeeklyReflectionSourceSelection(includedEntryIDs: Set(nonempty.map(\.id))),
            version: nextVersion
        )
    }

    private static func evidenceSentence(dominantMood: LifeBoardJournalMood?, averageEnergy: Double?) -> String {
        let moodText = dominantMood.map { "\($0.title) appeared most often" } ?? "mood evidence stayed varied"
        let energyText = averageEnergy.map { "average recorded energy was \(String(format: "%.1f", $0)) out of 5" }
            ?? "energy was not recorded often enough to summarize"
        return "\(moodText), and \(energyText). This is a reflection of recorded evidence, not a diagnosis."
    }
}

public enum JournalExportFormat: String, Codable, CaseIterable, Sendable {
    case json
    case markdown
    case csv
    case pdf
}

public struct JournalExportRequest: Sendable {
    public var report: WeeklyReflectionReport
    public var entries: [JournalEntrySnapshot]
    public var format: JournalExportFormat
    public var includesSensitiveFields: Bool

    public init(
        report: WeeklyReflectionReport,
        entries: [JournalEntrySnapshot],
        format: JournalExportFormat,
        includesSensitiveFields: Bool = false
    ) {
        self.report = report
        self.entries = entries
        self.format = format
        self.includesSensitiveFields = includesSensitiveFields
    }
}

public struct JournalExportReceipt: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var fileURL: URL
    public var format: JournalExportFormat
    public var exportedAt: Date
    public var redactedSensitiveFields: Bool

    public init(
        id: UUID = UUID(),
        fileURL: URL,
        format: JournalExportFormat,
        exportedAt: Date = Date(),
        redactedSensitiveFields: Bool
    ) {
        self.id = id
        self.fileURL = fileURL
        self.format = format
        self.exportedAt = exportedAt
        self.redactedSensitiveFields = redactedSensitiveFields
    }
}

public protocol JournalExporting: Sendable {
    func export(_ request: JournalExportRequest) async throws -> JournalExportReceipt
}

public enum JournalExportFailure: LocalizedError, Equatable, Sendable {
    case noSelectedEvidence
    case encodingFailed
    case unableToCreateProtectedFile

    public var errorDescription: String? {
        switch self {
        case .noSelectedEvidence: "No selected Journal evidence is available for this reflection."
        case .encodingFailed: "LifeBoard could not prepare this Journal export."
        case .unableToCreateProtectedFile: "LifeBoard could not create a protected export file."
        }
    }
}

public enum JournalBackupDuplicatePolicy: String, Codable, CaseIterable, Sendable {
    case keepExisting
    case replaceExisting
    case duplicateWithNewIDs
}

public struct JournalBackupArchive: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var createdAt: Date
    public var appVersion: String
    public var days: [LifeBoardJournalDayValue]
    public var reflectionReports: [WeeklyReflectionReport]
    public var audioPayloads: [UUID: Data]

    public init(
        schemaVersion: Int = 1,
        createdAt: Date = Date(),
        appVersion: String,
        days: [LifeBoardJournalDayValue],
        reflectionReports: [WeeklyReflectionReport],
        audioPayloads: [UUID: Data] = [:]
    ) {
        self.schemaVersion = schemaVersion
        self.createdAt = createdAt
        self.appVersion = appVersion
        self.days = days
        self.reflectionReports = reflectionReports
        self.audioPayloads = audioPayloads
    }
}

public struct JournalBackupReceipt: Identifiable, Equatable, Sendable {
    public var id: UUID
    public var fileURL: URL
    public var createdAt: Date
    public var dayCount: Int
    public var audioCount: Int

    public init(id: UUID = UUID(), fileURL: URL, createdAt: Date = Date(), dayCount: Int, audioCount: Int) {
        self.id = id
        self.fileURL = fileURL
        self.createdAt = createdAt
        self.dayCount = dayCount
        self.audioCount = audioCount
    }
}

public struct JournalImportReceipt: Equatable, Sendable {
    public var insertedDayIDs: [UUID]
    public var replacedDayIDs: [UUID]
    public var skippedDayIDs: [UUID]

    public init(insertedDayIDs: [UUID], replacedDayIDs: [UUID], skippedDayIDs: [UUID]) {
        self.insertedDayIDs = insertedDayIDs
        self.replacedDayIDs = replacedDayIDs
        self.skippedDayIDs = skippedDayIDs
    }
}

public protocol JournalBackupImportApplying: Sendable {
    func importJournalDays(
        _ days: [LifeBoardJournalDayValue],
        duplicatePolicy: JournalBackupDuplicatePolicy
    ) async throws -> JournalImportReceipt
}

public protocol JournalBackupServicing: Sendable {
    func createBackup(
        days: [LifeBoardJournalDayValue],
        reflections: [WeeklyReflectionReport],
        passphrase: String
    ) async throws -> JournalBackupReceipt
    func restoreBackup(
        from fileURL: URL,
        passphrase: String,
        duplicatePolicy: JournalBackupDuplicatePolicy,
        applyingTo applier: any JournalBackupImportApplying,
        reflectionRepository: any WeeklyReflectionHistoryRepository
    ) async throws -> JournalImportReceipt
}

public enum JournalBackupFailure: LocalizedError, Equatable, Sendable {
    case weakPassphrase
    case unsupportedVersion
    case malformedArchive
    case authenticationFailed
    case invalidIdentity
    case unsafeMediaPath
    case payloadTooLarge
    case protectedFileFailure

    public var errorDescription: String? {
        switch self {
        case .weakPassphrase: "Use a backup passphrase with at least eight characters."
        case .unsupportedVersion: "This Journal backup version is not supported."
        case .malformedArchive: "The Journal backup is malformed or incomplete."
        case .authenticationFailed: "The passphrase is incorrect or the backup was modified."
        case .invalidIdentity: "The backup contains conflicting Journal identities."
        case .unsafeMediaPath: "The backup contains an unsafe media path."
        case .payloadTooLarge: "The backup contains media larger than LifeBoard can safely import."
        case .protectedFileFailure: "LifeBoard could not create the protected backup or restore its media."
        }
    }
}

public struct JournalPrivacyPolicy: Codable, Hashable, Sendable {
    public var requiresAuthentication: Bool
    public var shieldsAppSwitcher: Bool
    public var excludesSensitiveEntriesFromExport: Bool
    public var permitsJournalEvidenceForEva: Bool

    public init(
        requiresAuthentication: Bool = false,
        shieldsAppSwitcher: Bool = true,
        excludesSensitiveEntriesFromExport: Bool = true,
        permitsJournalEvidenceForEva: Bool = false
    ) {
        self.requiresAuthentication = requiresAuthentication
        self.shieldsAppSwitcher = shieldsAppSwitcher
        self.excludesSensitiveEntriesFromExport = excludesSensitiveEntriesFromExport
        self.permitsJournalEvidenceForEva = permitsJournalEvidenceForEva
    }
}

public enum JournalPrivacyPolicyPersistence {
    public static let defaultsKey = "lifeboard.journal.privacy-policy.v1"

    public static func load(from defaults: UserDefaults) -> JournalPrivacyPolicy {
        guard let data = defaults.data(forKey: defaultsKey),
              let value = try? JSONDecoder().decode(JournalPrivacyPolicy.self, from: data) else {
            return JournalPrivacyPolicy()
        }
        return value
    }

    public static func save(_ policy: JournalPrivacyPolicy, to defaults: UserDefaults) throws {
        defaults.set(try JSONEncoder().encode(policy), forKey: defaultsKey)
    }
}

public enum JournalPrivacyGateState: Equatable, Sendable {
    case unlocked
    case locked
    case authenticating
    case recoveryRequired(String)
}

// MARK: - Structured notes

public enum LifeBoardKnowledgeBlockKind: String, Codable, CaseIterable, Sendable {
    case paragraph
    case heading1
    case heading2
    case bulletedList
    case numberedList
    case checklist
    case quote
    case callout
    case code
    case divider
    case table
    case collapsible
    case image
    case file
    case bookmark
    case noteLink
}

public struct LifeBoardKnowledgeSpaceValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var icon: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(id: UUID = UUID(), title: String, icon: String = "square.grid.2x2", createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.icon = icon
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct LifeBoardKnowledgeFolderValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var spaceID: UUID
    public var parentFolderID: UUID?
    public var title: String
    public var ordinal: Int

    public init(id: UUID = UUID(), spaceID: UUID, parentFolderID: UUID? = nil, title: String, ordinal: Int = 0) {
        self.id = id
        self.spaceID = spaceID
        self.parentFolderID = parentFolderID
        self.title = title
        self.ordinal = ordinal
    }
}

public enum KnowledgeFolderHierarchy {
    public static func path(
        to folderID: UUID?,
        in folders: [LifeBoardKnowledgeFolderValue]
    ) -> [LifeBoardKnowledgeFolderValue] {
        guard let folderID else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
        var result: [LifeBoardKnowledgeFolderValue] = []
        var cursor: UUID? = folderID
        var visited: Set<UUID> = []
        while let id = cursor, visited.insert(id).inserted, let folder = byID[id] {
            result.append(folder)
            cursor = folder.parentFolderID
        }
        return result.reversed()
    }

    public static func canMove(
        folderID: UUID,
        to parentID: UUID?,
        in folders: [LifeBoardKnowledgeFolderValue]
    ) -> Bool {
        guard folderID != parentID else { return false }
        guard let parentID else { return true }
        return path(to: parentID, in: folders).contains(where: { $0.id == folderID }) == false
    }
}

public struct LifeBoardKnowledgeBlockValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var noteID: UUID
    public var kind: LifeBoardKnowledgeBlockKind
    public var text: String
    public var metadata: Data?
    public var ordinal: Int
    public var isChecked: Bool

    public init(
        id: UUID = UUID(),
        noteID: UUID,
        kind: LifeBoardKnowledgeBlockKind = .paragraph,
        text: String = "",
        metadata: Data? = nil,
        ordinal: Int = 0,
        isChecked: Bool = false
    ) {
        self.id = id
        self.noteID = noteID
        self.kind = kind
        self.text = text
        self.metadata = metadata
        self.ordinal = ordinal
        self.isChecked = isChecked
    }
}

public struct KnowledgeBlockPayload: Codable, Hashable, Sendable {
    public struct Table: Codable, Hashable, Sendable {
        public var rows: [[String]]

        public init(rows: [[String]] = [["", ""], ["", ""]]) {
            let width = max(1, rows.map(\.count).max() ?? 1)
            self.rows = (rows.isEmpty ? [[""]] : rows).map { row in
                row + Array(repeating: "", count: max(0, width - row.count))
            }
        }
    }

    public struct Bookmark: Codable, Hashable, Sendable {
        public var url: URL?
        public var title: String?
        public var summary: String?

        public init(url: URL? = nil, title: String? = nil, summary: String? = nil) {
            self.url = url
            self.title = title
            self.summary = summary
        }
    }

    public struct NoteLink: Codable, Hashable, Sendable {
        public var noteID: UUID
        public var cachedTitle: String?

        public init(noteID: UUID, cachedTitle: String? = nil) {
            self.noteID = noteID
            self.cachedTitle = cachedTitle
        }
    }

    public struct Attachment: Codable, Hashable, Sendable {
        public var attachmentID: UUID
        public var fileName: String

        public init(attachmentID: UUID, fileName: String) {
            self.attachmentID = attachmentID
            self.fileName = fileName
        }
    }

    public var version: Int
    public var table: Table?
    public var bookmark: Bookmark?
    public var noteLink: NoteLink?
    public var attachment: Attachment?

    public init(
        version: Int = 1,
        table: Table? = nil,
        bookmark: Bookmark? = nil,
        noteLink: NoteLink? = nil,
        attachment: Attachment? = nil
    ) {
        self.version = version
        self.table = table
        self.bookmark = bookmark
        self.noteLink = noteLink
        self.attachment = attachment
    }

    public static func decode(from block: LifeBoardKnowledgeBlockValue) -> KnowledgeBlockPayload {
        if let metadata = block.metadata,
           let decoded = try? JSONDecoder().decode(KnowledgeBlockPayload.self, from: metadata) {
            return decoded
        }
        switch block.kind {
        case .table:
            let rows = block.text.split(separator: "\n", omittingEmptySubsequences: false).map { line in
                line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            }
            return KnowledgeBlockPayload(table: .init(rows: rows))
        case .bookmark:
            return KnowledgeBlockPayload(bookmark: .init(url: URL(string: block.text)))
        case .noteLink:
            return UUID(uuidString: block.text).map { KnowledgeBlockPayload(noteLink: .init(noteID: $0)) } ?? KnowledgeBlockPayload()
        default:
            return KnowledgeBlockPayload()
        }
    }

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }
}

public struct LifeBoardKnowledgeNoteValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var spaceID: UUID
    public var folderID: UUID?
    public var title: String
    public var isPinned: Bool
    public var isFavorite: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var blocks: [LifeBoardKnowledgeBlockValue]
    public var tagIDs: Set<UUID>

    public init(
        id: UUID = UUID(),
        spaceID: UUID,
        folderID: UUID? = nil,
        title: String,
        isPinned: Bool = false,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        blocks: [LifeBoardKnowledgeBlockValue] = [],
        tagIDs: Set<UUID> = []
    ) {
        self.id = id
        self.spaceID = spaceID
        self.folderID = folderID
        self.title = title
        self.isPinned = isPinned
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.blocks = blocks.sorted { $0.ordinal < $1.ordinal }
        self.tagIDs = tagIDs
    }

    public var plainText: String {
        blocks.map(\.text).joined(separator: "\n")
    }
}

public struct LifeBoardKnowledgeTagValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var colorHex: String?

    public init(id: UUID = UUID(), name: String, colorHex: String? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}

public struct LifeBoardKnowledgeLinkValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var sourceNoteID: UUID
    public var destinationNoteID: UUID
    public var label: String?

    public init(id: UUID = UUID(), sourceNoteID: UUID, destinationNoteID: UUID, label: String? = nil) {
        self.id = id
        self.sourceNoteID = sourceNoteID
        self.destinationNoteID = destinationNoteID
        self.label = label
    }
}

public struct LifeBoardKnowledgeAttachmentValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var noteID: UUID
    public var kind: String
    public var fileName: String
    public var payload: Data
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        noteID: UUID,
        kind: String,
        fileName: String,
        payload: Data,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.noteID = noteID
        self.kind = kind
        self.fileName = fileName
        self.payload = payload
        self.createdAt = createdAt
    }
}

public protocol KnowledgeAttachmentFileRepository: Sendable {
    func persist(_ attachment: LifeBoardKnowledgeAttachmentValue) async throws -> URL
    func resolvedURL(for attachment: LifeBoardKnowledgeAttachmentValue) async throws -> URL
    func deleteFile(for attachment: LifeBoardKnowledgeAttachmentValue) async throws
}

public protocol KnowledgeBookmarkMetadataFetching: Sendable {
    func metadata(for url: URL) async throws -> KnowledgeBlockPayload.Bookmark
}

public struct LifeBoardKnowledgeGraphSnapshot: Equatable, Sendable {
    public var notes: [LifeBoardKnowledgeNoteValue]
    public var links: [LifeBoardKnowledgeLinkValue]
}

// MARK: - Repository contract

public protocol LifeBoardPhaseIIRepository: Sendable {
    func fetchTrackers() async throws -> [LifeBoardTrackerDefinitionValue]
    func saveTracker(_ value: LifeBoardTrackerDefinitionValue) async throws
    func deleteTracker(id: UUID) async throws
    func fetchTrackerEntries(trackerID: UUID?) async throws -> [LifeBoardTrackerEntryValue]
    func saveTrackerEntry(_ value: LifeBoardTrackerEntryValue) async throws

    func fetchMoodCheckIns(from: Date?, to: Date?) async throws -> [LifeBoardMoodEnergyCheckInValue]
    func saveMoodCheckIn(_ value: LifeBoardMoodEnergyCheckInValue) async throws
    func deleteMoodCheckIn(id: UUID) async throws

    func fetchMedications() async throws -> [LifeBoardMedicationDefinitionValue]
    func saveMedication(_ value: LifeBoardMedicationDefinitionValue) async throws
    func deleteMedication(id: UUID) async throws
    func fetchMedicationSchedules(medicationID: UUID?) async throws -> [LifeBoardMedicationScheduleValue]
    func saveMedicationSchedule(_ value: LifeBoardMedicationScheduleValue) async throws
    func fetchMedicationEvents(from: Date, to: Date) async throws -> [LifeBoardMedicationEventValue]
    func saveMedicationEvent(_ value: LifeBoardMedicationEventValue) async throws

    func fetchFastingSessions(limit: Int) async throws -> [LifeBoardFastingSessionValue]
    func saveFastingSession(_ value: LifeBoardFastingSessionValue) async throws

    func fetchJournalDays(search: String?, starredOnly: Bool, mood: LifeBoardJournalMood?) async throws -> [LifeBoardJournalDayValue]
    func fetchJournalDay(containing date: Date) async throws -> LifeBoardJournalDayValue?
    func saveJournalDay(_ value: LifeBoardJournalDayValue) async throws
    func deleteJournalDay(id: UUID) async throws
    func fetchJournalDraft(dayID: UUID?) async throws -> LifeBoardJournalDraftValue?
    func saveJournalDraft(_ value: LifeBoardJournalDraftValue) async throws
    func deleteJournalDraft(id: UUID) async throws

    func fetchKnowledgeSpaces() async throws -> [LifeBoardKnowledgeSpaceValue]
    func saveKnowledgeSpace(_ value: LifeBoardKnowledgeSpaceValue) async throws
    func fetchKnowledgeFolders(spaceID: UUID?) async throws -> [LifeBoardKnowledgeFolderValue]
    func saveKnowledgeFolder(_ value: LifeBoardKnowledgeFolderValue) async throws
    func fetchKnowledgeNotes(search: String?, spaceID: UUID?) async throws -> [LifeBoardKnowledgeNoteValue]
    func saveKnowledgeNote(_ value: LifeBoardKnowledgeNoteValue) async throws
    func deleteKnowledgeNote(id: UUID) async throws
    func fetchKnowledgeTags() async throws -> [LifeBoardKnowledgeTagValue]
    func saveKnowledgeTag(_ value: LifeBoardKnowledgeTagValue) async throws
    func fetchKnowledgeLinks() async throws -> [LifeBoardKnowledgeLinkValue]
    func saveKnowledgeLink(_ value: LifeBoardKnowledgeLinkValue) async throws
    func deleteKnowledgeLink(id: UUID) async throws
    func fetchKnowledgeAttachments(noteID: UUID) async throws -> [LifeBoardKnowledgeAttachmentValue]
    func saveKnowledgeAttachment(_ value: LifeBoardKnowledgeAttachmentValue) async throws
    func deleteKnowledgeAttachment(id: UUID) async throws
}

public struct JournalHomeContextCandidateProvider: HomeContextCandidateProvider {
    public let providerID = "journal"
    private let repository: any LifeBoardPhaseIIRepository

    public init(repository: any LifeBoardPhaseIIRepository) { self.repository = repository }

    public func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        let calendar = Calendar.current
        let hour = calendar.component(.hour, from: context.date)
        guard hour >= 17,
              (try? await repository.fetchJournalDay(containing: context.date)) == nil else { return [] }
        return [.init(
            id: "evening-reflection:\(calendar.startOfDay(for: context.date).timeIntervalSince1970)",
            widgetKind: .journal,
            title: "Keep one moment from today",
            reason: .init(message: "Evening is a natural pause, and today does not have a journal moment yet.", signal: "time of day"),
            destination: .track,
            sensitivity: .privateSensitive,
            priority: 180,
            relevantFrom: context.date
        )]
    }
}

/// Suggests the Weekly Reflection once the week is winding down and the week
/// actually contains journal material to reflect on.
public struct WeeklyReflectionHomeContextCandidateProvider: HomeContextCandidateProvider {
    public let providerID = "weekly-reflection"
    private let repository: any LifeBoardPhaseIIRepository

    public init(repository: any LifeBoardPhaseIIRepository) { self.repository = repository }

    public func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        var calendar = Calendar.current
        calendar.firstWeekday = Calendar.current.firstWeekday
        let weekday = calendar.component(.weekday, from: context.date)
        let lastWeekday = ((calendar.firstWeekday + 5) % 7) + 1
        guard weekday == lastWeekday else { return [] }
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: context.date),
              let days = try? await repository.fetchJournalDays(search: nil, starredOnly: false, mood: nil),
              days.contains(where: { weekInterval.contains($0.day) }) else { return [] }
        return [.init(
            id: "weekly-reflection:\(Int(weekInterval.start.timeIntervalSince1970))",
            widgetKind: .journal,
            title: "Your week is ready to reflect on",
            reason: .init(
                message: "This week has journal moments, and the week is closing.",
                signal: "end of week"
            ),
            destination: .track,
            sensitivity: .privateSensitive,
            priority: 260,
            relevantFrom: context.date,
            relevantUntil: weekInterval.end
        )]
    }
}

/// Resurfaces a journal day from exactly one year ago — a gentle memory, only
/// when the user permits sensitive content on Home, and never with content in
/// the candidate itself.
public struct JournalMemoryHomeContextCandidateProvider: HomeContextCandidateProvider {
    public let providerID = "journal-memory"
    private let repository: any LifeBoardPhaseIIRepository

    public init(repository: any LifeBoardPhaseIIRepository) { self.repository = repository }

    public func candidates(context: HomeContextCandidateContext) async -> [HomeContextCandidate] {
        let calendar = Calendar.current
        guard let lastYear = calendar.date(byAdding: .year, value: -1, to: context.date),
              let memory = try? await repository.fetchJournalDay(containing: lastYear) else { return [] }
        return [.init(
            id: "journal-memory:\(memory.id.uuidString)",
            widgetKind: .journal,
            title: "A year ago today",
            reason: .init(
                message: "You kept a journal moment on this day last year. Open it privately when you like.",
                signal: "on this day"
            ),
            destination: .track,
            sensitivity: .privateSensitive,
            priority: 150,
            relevantFrom: context.date,
            relevantUntil: calendar.startOfDay(for: context.date).addingTimeInterval(24 * 60 * 60)
        )]
    }
}
