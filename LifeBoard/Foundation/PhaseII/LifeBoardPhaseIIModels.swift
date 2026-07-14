import Foundation

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

public struct LifeBoardFastingSessionValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var startedAt: Date
    public var endedAt: Date?
    public var targetDuration: TimeInterval?
    public var reminderOffsets: [TimeInterval]
    public var note: String?

    public init(
        id: UUID = UUID(),
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        targetDuration: TimeInterval? = nil,
        reminderOffsets: [TimeInterval] = [],
        note: String? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.targetDuration = targetDuration
        self.reminderOffsets = reminderOffsets
        self.note = note
    }

    public func elapsed(at now: Date = Date()) -> TimeInterval {
        max(0, (endedAt ?? now).timeIntervalSince(startedAt))
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
    public var measuredAt: Date?

    public static let notRequested = Self(availability: .notRequested, steps: nil, activeCalories: nil, measuredAt: nil)
}

// MARK: - Journal

public enum LifeBoardJournalBlockKind: String, Codable, CaseIterable, Sendable {
    case text
    case mood
    case audio
    case photo
    case prompt
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

    public init(
        id: UUID = UUID(),
        day: Date,
        summary: String? = nil,
        isStarred: Bool = false,
        representativeCheckInID: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        blocks: [LifeBoardJournalBlockValue] = [],
        media: [LifeBoardJournalMediaValue] = []
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
    }

    public var displayText: String {
        blocks.compactMap(\.text).joined(separator: "\n")
    }

    public var latestMood: LifeBoardJournalMood? {
        blocks.reversed().compactMap(\.mood).first
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

public struct LifeBoardKnowledgeGraphSnapshot: Equatable, Sendable {
    public var notes: [LifeBoardKnowledgeNoteValue]
    public var links: [LifeBoardKnowledgeLinkValue]
}

// MARK: - Repository contract

public protocol LifeBoardPhaseIIRepository: Sendable {
    func fetchTrackers() async throws -> [LifeBoardTrackerDefinitionValue]
    func saveTracker(_ value: LifeBoardTrackerDefinitionValue) async throws
    func fetchTrackerEntries(trackerID: UUID?) async throws -> [LifeBoardTrackerEntryValue]
    func saveTrackerEntry(_ value: LifeBoardTrackerEntryValue) async throws

    func fetchMoodCheckIns(from: Date?, to: Date?) async throws -> [LifeBoardMoodEnergyCheckInValue]
    func saveMoodCheckIn(_ value: LifeBoardMoodEnergyCheckInValue) async throws

    func fetchMedications() async throws -> [LifeBoardMedicationDefinitionValue]
    func saveMedication(_ value: LifeBoardMedicationDefinitionValue) async throws
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
