import Foundation
import LifeBoardDomain

// MARK: - Trackers and care

public enum TrackerKind: String, Codable, CaseIterable, Hashable, Sendable {
    case boolean
    case count
    case quantity
    case rating
    case duration
    case text
    case choice
    case timestamp
}
public enum TrackerValue: Codable, Hashable, Sendable {
    case boolean(Bool)
    case count(Int)
    case quantity(Double, unit: String?)
    case rating(Double)
    case duration(TimeInterval)
    case text(String)
    case choice(String)
    case timestamp(Date)
}

public enum TrackerAggregation: String, Codable, CaseIterable, Hashable, Sendable {
    case latest
    case sum
    case average
    case minimum
    case maximum
    case count
}

public enum TrackerPrivacyClass: String, Codable, CaseIterable, Hashable, Sendable {
    case standard
    case personal
    case sensitive
}

public struct TrackerDefinitionValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var kind: TrackerKind
    public var unitLabel: String?
    public var targetValue: Double?
    public var schedule: Set<Int>
    public var reminderMinutes: Int?
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var valueType: TrackerKind?
    public var rangeMin: Double?
    public var rangeMax: Double?
    public var aggregation: TrackerAggregation?
    public var privacyClass: TrackerPrivacyClass?
    public var isHomeEligible: Bool?
    public var choiceOptions: [String]?

    public init(
        id: UUID = UUID(),
        title: String,
        kind: TrackerKind,
        unitLabel: String? = nil,
        targetValue: Double? = nil,
        schedule: Set<Int> = Set(1...7),
        reminderMinutes: Int? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        valueType: TrackerKind? = nil,
        rangeMin: Double? = nil,
        rangeMax: Double? = nil,
        aggregation: TrackerAggregation? = nil,
        privacyClass: TrackerPrivacyClass? = nil,
        isHomeEligible: Bool? = nil,
        choiceOptions: [String]? = nil
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
        self.valueType = valueType
        self.rangeMin = rangeMin
        self.rangeMax = rangeMax
        self.aggregation = aggregation
        self.privacyClass = privacyClass
        self.isHomeEligible = isHomeEligible
        self.choiceOptions = choiceOptions
    }

    public var effectiveValueType: TrackerKind { valueType ?? kind }
    public var effectiveAggregation: TrackerAggregation { aggregation ?? .latest }
    public var effectivePrivacyClass: TrackerPrivacyClass { privacyClass ?? .sensitive }
    public var permitsHomeProjection: Bool {
        effectivePrivacyClass != .sensitive && isHomeEligible == true
    }
}

public struct TrackerEntryValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var trackerID: UUID
    public var timestamp: Date
    public var numericValue: Double?
    public var booleanValue: Bool?
    public var note: String?
    public var value: TrackerValue?

    public init(
        id: UUID = UUID(),
        trackerID: UUID,
        timestamp: Date = Date(),
        numericValue: Double? = nil,
        booleanValue: Bool? = nil,
        note: String? = nil,
        value: TrackerValue? = nil
    ) {
        self.id = id
        self.trackerID = trackerID
        self.timestamp = timestamp
        self.numericValue = numericValue
        self.booleanValue = booleanValue
        self.note = note
        self.value = value
    }
}

public enum TrackerTemplate: String, CaseIterable, Identifiable, Hashable, Sendable {
    case pain
    case symptoms
    case caffeine
    case reading
    case spending
    case screenTime

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .pain: "Pain note"
        case .symptoms: "Symptom note"
        case .caffeine: "Caffeine"
        case .reading: "Reading"
        case .spending: "Spending"
        case .screenTime: "Screen time"
        }
    }

    public var detail: String {
        switch self {
        case .pain: String(localized: "Rate it from 0 to 10.")
        case .symptoms: String(localized: "Describe it in your words.")
        case .caffeine: String(localized: "Amount in mg.")
        case .reading: String(localized: "Minutes read.")
        case .spending: String(localized: "Amount in your currency.")
        case .screenTime: String(localized: "Minutes on screen.")
        }
    }

    public var isHealthLike: Bool {
        self == .pain || self == .symptoms
    }

    public func instantiate(at date: Date = Date()) -> TrackerDefinitionValue {
        switch self {
        case .pain:
            TrackerDefinitionValue(
                title: title,
                kind: .rating,
                targetValue: nil,
                createdAt: date,
                updatedAt: date,
                valueType: .rating,
                rangeMin: 0,
                rangeMax: 10,
                aggregation: .average,
                privacyClass: .sensitive,
                isHomeEligible: false
            )
        case .symptoms:
            TrackerDefinitionValue(
                title: title,
                kind: .text,
                targetValue: nil,
                createdAt: date,
                updatedAt: date,
                valueType: .text,
                aggregation: .latest,
                privacyClass: .sensitive,
                isHomeEligible: false
            )
        case .caffeine:
            TrackerDefinitionValue(
                title: title,
                kind: .quantity,
                unitLabel: "mg",
                targetValue: nil,
                createdAt: date,
                updatedAt: date,
                valueType: .quantity,
                aggregation: .sum,
                privacyClass: .personal,
                isHomeEligible: false
            )
        case .reading:
            TrackerDefinitionValue(
                title: title,
                kind: .duration,
                unitLabel: "minutes",
                targetValue: nil,
                createdAt: date,
                updatedAt: date,
                valueType: .duration,
                aggregation: .sum,
                privacyClass: .personal,
                isHomeEligible: true
            )
        case .spending:
            TrackerDefinitionValue(
                title: title,
                kind: .quantity,
                unitLabel: "currency",
                targetValue: nil,
                createdAt: date,
                updatedAt: date,
                valueType: .quantity,
                aggregation: .sum,
                privacyClass: .personal,
                isHomeEligible: false
            )
        case .screenTime:
            TrackerDefinitionValue(
                title: title,
                kind: .duration,
                unitLabel: "minutes",
                targetValue: nil,
                createdAt: date,
                updatedAt: date,
                valueType: .duration,
                aggregation: .sum,
                privacyClass: .personal,
                isHomeEligible: false
            )
        }
    }
}

public struct MoodEnergyCheckInValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var mood: JournalMood
    public var energy: Int?
    public var createdAt: Date
    public var representativeDay: Date?
    public var isRepresentative: Bool

    public init(
        id: UUID = UUID(),
        mood: JournalMood,
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

public enum MedicationEventStatus: String, Codable, CaseIterable, Hashable, Sendable {
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

public struct MedicationDefinitionValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var dosageText: String?
    public var instructions: String?
    public var healthCorrelationID: String?
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var formRaw: String?
    public var startDate: Date?
    public var endDate: Date?
    public var refillQuantity: Double?
    public var refillRemaining: Double?
    public var refillThreshold: Double?
    public var lastRefilledAt: Date?

    public init(
        id: UUID = UUID(),
        name: String,
        dosageText: String? = nil,
        instructions: String? = nil,
        healthCorrelationID: String? = nil,
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        formRaw: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        refillQuantity: Double? = nil,
        refillRemaining: Double? = nil,
        refillThreshold: Double? = nil,
        lastRefilledAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.dosageText = dosageText
        self.instructions = instructions
        self.healthCorrelationID = healthCorrelationID
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.formRaw = formRaw
        self.startDate = startDate
        self.endDate = endDate
        self.refillQuantity = refillQuantity
        self.refillRemaining = refillRemaining
        self.refillThreshold = refillThreshold
        self.lastRefilledAt = lastRefilledAt
    }
}

public struct MedicationScheduleValue: Identifiable, Codable, Hashable, Sendable {
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

public struct MedicationEventValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var medicationID: UUID
    public var scheduledAt: Date
    public var status: MedicationEventStatus
    public var resolvedAt: Date?
    public var note: String?

    public init(
        id: UUID = UUID(),
        medicationID: UUID,
        scheduledAt: Date,
        status: MedicationEventStatus = .scheduled,
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

public enum FastingCompletionKind: String, Codable, CaseIterable, Sendable {
    case planned
    case early
    case cancelled
    case corrected
}

public struct FastingSessionValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var templateID: UUID?
    public var startedAt: Date
    public var endedAt: Date?
    public var targetDuration: TimeInterval?
    public var reminderOffsets: [TimeInterval]
    public var note: String?
    /// Optional until the additive Wellness Core model is available. Keeping this
    /// optional also lets existing correction receipts decode without migration.
    public var completionKind: FastingCompletionKind?
    public var updatedAt: Date?

    public init(
        id: UUID = UUID(),
        templateID: UUID? = nil,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        targetDuration: TimeInterval? = nil,
        reminderOffsets: [TimeInterval] = [],
        note: String? = nil,
        completionKind: FastingCompletionKind? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.templateID = templateID
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

public struct FastingDisplayPreferences: Codable, Hashable, Sendable {
    public var showsElapsedTime: Bool
    public var showsTargetProgress: Bool

    public init(showsElapsedTime: Bool = true, showsTargetProgress: Bool = true) {
        self.showsElapsedTime = showsElapsedTime
        self.showsTargetProgress = showsTargetProgress
    }
}

public struct FastingTemplateValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var label: String
    public var targetDuration: TimeInterval?
    public var reminderOffsets: [TimeInterval]
    public var displayPreferences: FastingDisplayPreferences
    public var isArchived: Bool
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        label: String,
        targetDuration: TimeInterval? = nil,
        reminderOffsets: [TimeInterval] = [],
        displayPreferences: FastingDisplayPreferences = .init(),
        isArchived: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) throws {
        let normalizedLabel = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedLabel.isEmpty,
              targetDuration.map({ $0.isFinite && $0 > 0 }) ?? true,
              reminderOffsets.allSatisfy({ offset in
                  offset.isFinite && offset >= 0 && (targetDuration.map { offset <= $0 } ?? true)
              }) else { throw FastingTimerStoreError.invalidTarget }
        self.id = id
        self.label = normalizedLabel
        self.targetDuration = targetDuration
        self.reminderOffsets = Array(Set(reminderOffsets)).sorted()
        self.displayPreferences = displayPreferences
        self.isArchived = isArchived
        self.createdAt = createdAt
        self.updatedAt = max(updatedAt, createdAt)
    }
}

public struct HealthSnapshot: Equatable, Sendable {
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

public enum JournalBlockKind: String, Codable, CaseIterable, Sendable {
    case text
    case mood
    case audio
    case photo
    case prompt
    /// A transcript produced from a voice recording (OffRecord parity);
    /// rendered like text but attributed to speech capture.
    case voice
    /// The Day Close reflection, mirrored into the journal (string-backed
    /// `kindRaw`; older builds skip it). See `JournalDayCloseWriter`.
    case dayClose
}


public struct JournalMediaValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var dayID: UUID
    public var kind: JournalMediaKind
    public var payload: Data?
    public var relativePath: String?
    public var duration: TimeInterval?
    public var createdAt: Date
    public var syncPolicy: JournalMediaSyncPolicy

    public init(
        id: UUID = UUID(),
        dayID: UUID,
        kind: JournalMediaKind,
        payload: Data? = nil,
        relativePath: String? = nil,
        duration: TimeInterval? = nil,
        createdAt: Date = Date(),
        syncPolicy: JournalMediaSyncPolicy
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

public struct JournalBlockValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var dayID: UUID
    public var kind: JournalBlockKind
    public var text: String?
    public var mood: JournalMood?
    public var energy: Int?
    public var mediaID: UUID?
    public var promptID: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var ordinal: Int

    public init(
        id: UUID = UUID(),
        dayID: UUID,
        kind: JournalBlockKind,
        text: String? = nil,
        mood: JournalMood? = nil,
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

public struct JournalDayValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var day: Date
    public var summary: String?
    public var isStarred: Bool
    public var representativeCheckInID: UUID?
    public var createdAt: Date
    public var updatedAt: Date
    public var blocks: [JournalBlockValue]
    public var media: [JournalMediaValue]
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
        blocks: [JournalBlockValue] = [],
        media: [JournalMediaValue] = [],
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
            blocks: try container.decodeIfPresent([JournalBlockValue].self, forKey: .blocks) ?? [],
            media: try container.decodeIfPresent([JournalMediaValue].self, forKey: .media) ?? [],
            aiExclusion: try container.decodeIfPresent(JournalAIExclusion.self, forKey: .aiExclusion) ?? .included
        )
    }

    public var displayText: String {
        // Mood reasons ride on the mood block's text as `reasons:…`; they
        // are chips, not prose.
        blocks.compactMap { JournalMoodReasons.isEncoded($0.text) ? nil : $0.text }.joined(separator: "\n")
    }

    public var latestMood: JournalMood? {
        blocks.reversed().compactMap(\.mood).first
    }
}

public struct JournalMediaReconciliation: Equatable, Sendable {
    public var day: JournalDayValue
    public var removedMedia: [JournalMediaValue]

    public init(day: JournalDayValue, removedMedia: [JournalMediaValue]) {
        self.day = day
        self.removedMedia = removedMedia
    }
}

public enum JournalMediaReconciler {
    /// Removes media records that no block references and media blocks whose
    /// backing record is absent. The caller persists the repaired day before
    /// deleting any protected file, so interrupted cleanup remains recoverable.
    public static func reconcile(_ input: JournalDayValue) -> JournalMediaReconciliation {
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

public struct JournalDraftValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var dayID: UUID
    public var day: Date
    public var text: String
    public var mood: JournalMood?
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
        mood: JournalMood? = nil,
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

public struct JournalPrompt: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var title: String
    public var supportiveCopy: String

    public static func contextual(daypart: ResolvedDaypart, hasEntry: Bool) -> Self {
        if hasEntry {
            return Self(id: "continue", title: String(localized: "Anything else?"), supportiveCopy: String(localized: "A sentence is enough."))
        }
        switch daypart {
        case .morning:
            return Self(id: "morning", title: String(localized: "What matters most today?"), supportiveCopy: String(localized: "One thing."))
        case .afternoon:
            return Self(id: "afternoon", title: String(localized: "What’s on your mind?"), supportiveCopy: String(localized: "Name it."))
        case .evening:
            return Self(id: "evening", title: String(localized: "What stayed with you today?"), supportiveCopy: String(localized: "What stood out."))
        case .night:
            return Self(id: "night", title: String(localized: "What can wait until tomorrow?"), supportiveCopy: String(localized: "It can wait."))
        }
    }
}

public struct JournalInsightSnapshot: Equatable, Sendable {
    public var daysWritten: Int
    public var totalWords: Int
    public var dominantMood: JournalMood?
    public var averageEnergy: Double?
    public var evidenceDayIDs: [UUID]

    public static let empty = Self(daysWritten: 0, totalWords: 0, dominantMood: nil, averageEnergy: nil, evidenceDayIDs: [])
}


public extension JournalEntrySnapshot {
    init(day: JournalDayValue) {
        let transcriptionByMediaID: [UUID: String] = Dictionary(
            uniqueKeysWithValues: day.blocks.compactMap { block in
                guard block.kind == .audio,
                      let mediaID = block.mediaID,
                      let text = block.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                      text.isEmpty == false else { return nil }
                return (mediaID, text)
            }
        )
        let attachments = day.media.map { media in
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
        self.init(
            id: day.id,
            date: day.day,
            title: day.summary,
            text: day.displayText,
            mood: day.latestMood,
            energy: day.blocks.reversed().compactMap(\.energy).first,
            isStarred: day.isStarred,
            attachments: attachments,
            updatedAt: day.updatedAt,
            aiExclusion: day.aiExclusion
        )
    }
}
// MARK: Journal public contracts


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

public enum WeeklyReflectionService {
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
            WeeklyReflectionEntrySnapshot(
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
        let moodGroups: [JournalMood: [JournalMood]] = Dictionary(grouping: moods, by: { $0 })
        let moodCounts: [(mood: JournalMood, count: Int)] = moodGroups.map { (mood: $0.key, count: $0.value.count) }
        let rankedMoods = moodCounts.sorted { lhs, rhs in
            lhs.count == rhs.count ? lhs.mood.rawValue < rhs.mood.rawValue : lhs.count > rhs.count
        }
        let dominantMood = rankedMoods.first?.mood
        let energies = nonempty.compactMap(\.energy)
        let averageEnergy = energies.isEmpty ? nil : Double(energies.reduce(0, +)) / Double(energies.count)

        let summary: String
        switch density {
        case .empty:
            summary = String(localized: "Not enough entries to summarize yet.")
        case .light, .full:
            let dayText = activeDays == 1 ? String(localized: "1 day") : String(localized: "\(activeDays) days")
            let wordText = wordCount == 1 ? String(localized: "1 word") : String(localized: "\(wordCount) words")
            summary = String(localized: "\(dayText), \(wordText) this week.") + " " + evidenceSentence(dominantMood: dominantMood, averageEnergy: averageEnergy)
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

    private static func evidenceSentence(dominantMood: JournalMood?, averageEnergy: Double?) -> String {
        let moodText = dominantMood.map { String(localized: "Most common mood: \($0.displayName).") }
            ?? String(localized: "Mood varied.")
        guard let averageEnergy else { return moodText }
        let energy = averageEnergy.formatted(.number.precision(.fractionLength(1)))
        return moodText + " " + String(localized: "Average energy \(energy) of 5.")
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
        case .noSelectedEvidence: String(localized: "Couldn’t export. Select at least 1 day.")
        case .encodingFailed: String(localized: "Couldn’t prepare export.")
        case .unableToCreateProtectedFile: String(localized: "Couldn’t create export file.")
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
    public var days: [JournalDayValue]
    public var reflectionReports: [WeeklyReflectionReport]
    public var audioPayloads: [UUID: Data]

    public init(
        schemaVersion: Int = 1,
        createdAt: Date = Date(),
        appVersion: String,
        days: [JournalDayValue],
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
        _ days: [JournalDayValue],
        duplicatePolicy: JournalBackupDuplicatePolicy
    ) async throws -> JournalImportReceipt
}

public protocol JournalBackupServicing: Sendable {
    func createBackup(
        days: [JournalDayValue],
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
        case .weakPassphrase: String(localized: "Use at least 8 characters.")
        case .unsupportedVersion: String(localized: "Couldn’t read this backup version.")
        case .malformedArchive: String(localized: "Couldn’t read backup. It may be incomplete.")
        case .authenticationFailed: String(localized: "Wrong passphrase, or the backup was changed.")
        case .invalidIdentity: String(localized: "Couldn’t import backup. Some entries conflict.")
        case .unsafeMediaPath: String(localized: "Couldn’t import backup. A media file is unsafe.")
        case .payloadTooLarge: String(localized: "Couldn’t import backup. A media file is too large.")
        case .protectedFileFailure: String(localized: "Couldn’t save backup files.")
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


// MARK: - Repository contract

public struct JournalEvidenceSummary: Sendable {
    public let id: UUID
    public let day: Date
    public let updatedAt: Date
    public let aiExclusion: JournalAIExclusion
}

public protocol PhaseIIRepository: KnowledgeRepository, Sendable {
    func fetchTrackers() async throws -> [TrackerDefinitionValue]
    func saveTracker(_ value: TrackerDefinitionValue) async throws
    func deleteTracker(id: UUID) async throws
    func fetchTrackerEntries(trackerID: UUID?) async throws -> [TrackerEntryValue]
    func fetchTrackerEntries(trackerID: UUID?, from: Date, to: Date) async throws -> [TrackerEntryValue]
    func fetchJournalDays(from: Date, to: Date) async throws -> [JournalDayValue]
    func fetchJournalEvidence(from: Date, to: Date) async throws -> [JournalEvidenceSummary]
    func saveTrackerEntry(_ value: TrackerEntryValue) async throws
    func deleteTrackerEntry(id: UUID) async throws

    func fetchMoodCheckIns(from: Date?, to: Date?) async throws -> [MoodEnergyCheckInValue]
    func saveMoodCheckIn(_ value: MoodEnergyCheckInValue) async throws
    func deleteMoodCheckIn(id: UUID) async throws

    func fetchMedications() async throws -> [MedicationDefinitionValue]
    func saveMedication(_ value: MedicationDefinitionValue) async throws
    func deleteMedication(id: UUID) async throws
    func fetchMedicationSchedules(medicationID: UUID?) async throws -> [MedicationScheduleValue]
    func saveMedicationSchedule(_ value: MedicationScheduleValue) async throws
    func fetchMedicationEvents(from: Date, to: Date) async throws -> [MedicationEventValue]
    func saveMedicationEvent(_ value: MedicationEventValue) async throws

    func fetchFastingSessions(limit: Int) async throws -> [FastingSessionValue]
    func saveFastingSession(_ value: FastingSessionValue) async throws
    func fetchFastingTemplates(includeArchived: Bool) async throws -> [FastingTemplateValue]
    func saveFastingTemplate(_ value: FastingTemplateValue) async throws

    func fetchJournalDays(search: String?, starredOnly: Bool, mood: JournalMood?) async throws -> [JournalDayValue]
    func fetchJournalDay(containing date: Date) async throws -> JournalDayValue?
    func saveJournalDay(_ value: JournalDayValue) async throws
    func deleteJournalDay(id: UUID) async throws
    func fetchJournalDraft(dayID: UUID?) async throws -> JournalDraftValue?
    func saveJournalDraft(_ value: JournalDraftValue) async throws
    func deleteJournalDraft(id: UUID) async throws

    func fetchKnowledgeSpaces() async throws -> [KnowledgeSpaceValue]
    func saveKnowledgeSpace(_ value: KnowledgeSpaceValue) async throws
    func fetchKnowledgeFolders(spaceID: UUID?) async throws -> [KnowledgeFolderValue]
    func saveKnowledgeFolder(_ value: KnowledgeFolderValue) async throws
    func fetchKnowledgeNotes(search: String?, spaceID: UUID?) async throws -> [KnowledgeNoteValue]
    func saveKnowledgeNote(_ value: KnowledgeNoteValue) async throws
    func deleteKnowledgeNote(id: UUID) async throws
    func fetchKnowledgeTags() async throws -> [KnowledgeTagValue]
    func saveKnowledgeTag(_ value: KnowledgeTagValue) async throws
    func fetchKnowledgeLinks() async throws -> [KnowledgeLinkValue]
    func saveKnowledgeLink(_ value: KnowledgeLinkValue) async throws
    func deleteKnowledgeLink(id: UUID) async throws
    func fetchKnowledgeAttachments(noteID: UUID) async throws -> [KnowledgeAttachmentValue]
    func saveKnowledgeAttachment(_ value: KnowledgeAttachmentValue) async throws
    func deleteKnowledgeAttachment(id: UUID) async throws

    func fetchKnowledgeNotes(query: KnowledgeNoteQuery) async throws -> [KnowledgeNoteValue]
    func fetchKnowledgeSmartCollections(spaceID: UUID?) async throws -> [KnowledgeSmartCollectionValue]
    func saveKnowledgeSmartCollection(_ value: KnowledgeSmartCollectionValue) async throws
    func deleteKnowledgeSmartCollection(id: UUID) async throws
    func fetchKnowledgeDraft(noteID: UUID) async throws -> KnowledgeNoteDraftValue?
    func saveKnowledgeDraft(_ value: KnowledgeNoteDraftValue) async throws
    func deleteKnowledgeDraft(noteID: UUID) async throws
    func fetchKnowledgeRevisions(noteID: UUID) async throws -> [KnowledgeNoteRevisionValue]
    func saveKnowledgeRevision(_ value: KnowledgeNoteRevisionValue) async throws
    func lockKnowledgeNote(
        redacted: KnowledgeNoteValue,
        payload: KnowledgeSecurePayloadValue,
        attachments: [KnowledgeSecureAttachmentPayloadValue]
    ) async throws
    func fetchKnowledgeSecurePayload(
        noteID: UUID
    ) async throws -> (KnowledgeSecurePayloadValue, [KnowledgeSecureAttachmentPayloadValue])?
    func restoreUnlockedKnowledgeNote(
        _ note: KnowledgeNoteValue,
        attachments: [KnowledgeAttachmentValue]
    ) async throws
    func pruneKnowledgeRecovery(now: Date) async throws
}

public extension PhaseIIRepository {
    func fetchJournalEvidence(from: Date, to: Date) async throws -> [JournalEvidenceSummary] {
        try await fetchJournalDays(from: from, to: to).map {
            JournalEvidenceSummary(id: $0.id, day: $0.day, updatedAt: $0.updatedAt, aiExclusion: $0.aiExclusion)
        }
    }

    func fetchTrackerEntries(trackerID: UUID?, from: Date, to: Date) async throws -> [TrackerEntryValue] {
        try await fetchTrackerEntries(trackerID: trackerID).filter { $0.timestamp >= from && $0.timestamp < to }
    }

    func fetchJournalDays(from: Date, to: Date) async throws -> [JournalDayValue] {
        try await fetchJournalDays(search: nil, starredOnly: false, mood: nil).filter { $0.day >= from && $0.day < to }
    }

    func deleteTrackerEntry(id: UUID) async throws {
        throw CocoaError(.featureUnsupported)
    }

    func fetchKnowledgeNotes(query: KnowledgeNoteQuery) async throws -> [KnowledgeNoteValue] {
        let values = try await fetchKnowledgeNotes(search: nil, spaceID: query.spaceID)
        let links = try await fetchKnowledgeLinks()
        return query.apply(
            to: values,
            linkedNoteIDs: Set(links.flatMap { [$0.sourceNoteID, $0.destinationNoteID] }),
            incomingNoteIDs: Set(links.map(\.destinationNoteID)),
            outgoingNoteIDs: Set(links.map(\.sourceNoteID))
        )
    }

    func fetchKnowledgeSmartCollections(spaceID: UUID?) async throws -> [KnowledgeSmartCollectionValue] { [] }
    func saveKnowledgeSmartCollection(_ value: KnowledgeSmartCollectionValue) async throws {}
    func deleteKnowledgeSmartCollection(id: UUID) async throws {}
    func fetchKnowledgeDraft(noteID: UUID) async throws -> KnowledgeNoteDraftValue? { nil }
    func saveKnowledgeDraft(_ value: KnowledgeNoteDraftValue) async throws {}
    func deleteKnowledgeDraft(noteID: UUID) async throws {}
    func fetchKnowledgeRevisions(noteID: UUID) async throws -> [KnowledgeNoteRevisionValue] { [] }
    func saveKnowledgeRevision(_ value: KnowledgeNoteRevisionValue) async throws {}
    func lockKnowledgeNote(
        redacted: KnowledgeNoteValue,
        payload: KnowledgeSecurePayloadValue,
        attachments: [KnowledgeSecureAttachmentPayloadValue]
    ) async throws {
        throw CocoaError(.featureUnsupported)
    }
    func fetchKnowledgeSecurePayload(
        noteID: UUID
    ) async throws -> (KnowledgeSecurePayloadValue, [KnowledgeSecureAttachmentPayloadValue])? { nil }
    func restoreUnlockedKnowledgeNote(
        _ note: KnowledgeNoteValue,
        attachments: [KnowledgeAttachmentValue]
    ) async throws {
        try await saveKnowledgeNote(note)
        for attachment in attachments { try await saveKnowledgeAttachment(attachment) }
    }
    func pruneKnowledgeRecovery(now: Date = Date()) async throws {}
}
