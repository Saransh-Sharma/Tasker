import CoreData
import Foundation

public final class CoreDataLifeBoardPhaseIIRepository: LifeBoardPhaseIIRepository, @unchecked Sendable {
    private let container: NSPersistentContainer

    public init(container: NSPersistentContainer) {
        self.container = container
    }

    // MARK: Trackers

    public func fetchTrackers() async throws -> [LifeBoardTrackerDefinitionValue] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "TrackerDefinition")
            request.predicate = NSPredicate(format: "isArchived == NO")
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return try context.fetch(request).compactMap(Self.trackerValue)
        }
    }

    public func saveTracker(_ value: LifeBoardTrackerDefinitionValue) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "TrackerDefinition", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.title.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "title")
            object.setValue(value.kind.rawValue, forKey: "kindRaw")
            object.setValue(value.unitLabel, forKey: "unitLabel")
            object.setValue(value.targetValue.map(NSNumber.init(value:)), forKey: "targetValue")
            object.setValue(try Self.encode(value.schedule), forKey: "scheduleData")
            object.setValue(value.reminderMinutes.map(NSNumber.init(value:)), forKey: "reminderMinutes")
            object.setValue(value.isArchived, forKey: "isArchived")
            object.setValue(value.createdAt, forKey: "createdAt")
            object.setValue(value.updatedAt, forKey: "updatedAt")
            object.setValue(1, forKey: "version")
        }
    }

    public func fetchTrackerEntries(trackerID: UUID?) async throws -> [LifeBoardTrackerEntryValue] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "TrackerEntry")
            if let trackerID {
                request.predicate = NSPredicate(format: "trackerID == %@", trackerID as CVarArg)
            }
            request.sortDescriptors = [NSSortDescriptor(key: "timestamp", ascending: false)]
            request.fetchBatchSize = 100
            return try context.fetch(request).compactMap(Self.trackerEntryValue)
        }
    }

    public func saveTrackerEntry(_ value: LifeBoardTrackerEntryValue) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "TrackerEntry", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.trackerID, forKey: "trackerID")
            object.setValue(value.timestamp, forKey: "timestamp")
            object.setValue(value.numericValue.map(NSNumber.init(value:)), forKey: "numericValue")
            object.setValue(value.booleanValue.map(NSNumber.init(value:)), forKey: "booleanValue")
            object.setValue(value.note, forKey: "note")
            object.setValue(Date(), forKey: "createdAt")
            object.setValue(try Self.fetchOne(entity: "TrackerDefinition", id: value.trackerID, in: context), forKey: "tracker")
        }
    }

    // MARK: Mood and energy

    public func fetchMoodCheckIns(from: Date?, to: Date?) async throws -> [LifeBoardMoodEnergyCheckInValue] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "MoodEnergyCheckIn")
            var predicates: [NSPredicate] = []
            if let from { predicates.append(NSPredicate(format: "createdAt >= %@", from as NSDate)) }
            if let to { predicates.append(NSPredicate(format: "createdAt < %@", to as NSDate)) }
            request.predicate = predicates.isEmpty ? nil : NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
            return try context.fetch(request).compactMap(Self.moodValue)
        }
    }

    public func saveMoodCheckIn(_ value: LifeBoardMoodEnergyCheckInValue) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "MoodEnergyCheckIn", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.mood.rawValue, forKey: "moodRaw")
            object.setValue(value.energy.map(NSNumber.init(value:)), forKey: "energy")
            object.setValue(value.createdAt, forKey: "createdAt")
            object.setValue(value.representativeDay, forKey: "representativeDay")
            object.setValue(value.isRepresentative, forKey: "isRepresentative")
        }
    }

    // MARK: Medication

    public func fetchMedications() async throws -> [LifeBoardMedicationDefinitionValue] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "MedicationDefinition")
            request.predicate = NSPredicate(format: "isArchived == NO")
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            return try context.fetch(request).compactMap(Self.medicationValue)
        }
    }

    public func saveMedication(_ value: LifeBoardMedicationDefinitionValue) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "MedicationDefinition", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "name")
            object.setValue(value.dosageText, forKey: "dosageText")
            object.setValue(value.instructions, forKey: "instructions")
            object.setValue(value.healthCorrelationID, forKey: "healthCorrelationID")
            object.setValue(value.isArchived, forKey: "isArchived")
            object.setValue(value.createdAt, forKey: "createdAt")
            object.setValue(value.updatedAt, forKey: "updatedAt")
        }
    }

    public func fetchMedicationSchedules(medicationID: UUID?) async throws -> [LifeBoardMedicationScheduleValue] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "MedicationSchedule")
            if let medicationID {
                request.predicate = NSPredicate(format: "medicationID == %@", medicationID as CVarArg)
            }
            request.sortDescriptors = [NSSortDescriptor(key: "windowStartMinutes", ascending: true)]
            return try context.fetch(request).compactMap(Self.medicationScheduleValue)
        }
    }

    public func saveMedicationSchedule(_ value: LifeBoardMedicationScheduleValue) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "MedicationSchedule", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.medicationID, forKey: "medicationID")
            object.setValue(value.windowStartMinutes, forKey: "windowStartMinutes")
            object.setValue(value.windowEndMinutes, forKey: "windowEndMinutes")
            object.setValue(try Self.encode(value.weekdays), forKey: "weekdaysData")
            object.setValue(value.reminderEnabled, forKey: "reminderEnabled")
            object.setValue(Date(), forKey: "createdAt")
            object.setValue(try Self.fetchOne(entity: "MedicationDefinition", id: value.medicationID, in: context), forKey: "medication")
        }
    }

    public func fetchMedicationEvents(from: Date, to: Date) async throws -> [LifeBoardMedicationEventValue] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "MedicationEvent")
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "scheduledAt >= %@", from as NSDate),
                NSPredicate(format: "scheduledAt < %@", to as NSDate)
            ])
            request.sortDescriptors = [NSSortDescriptor(key: "scheduledAt", ascending: true)]
            return try context.fetch(request).compactMap(Self.medicationEventValue)
        }
    }

    public func saveMedicationEvent(_ value: LifeBoardMedicationEventValue) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "MedicationEvent", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.medicationID, forKey: "medicationID")
            object.setValue(value.scheduledAt, forKey: "scheduledAt")
            object.setValue(value.status.rawValue, forKey: "statusRaw")
            object.setValue(value.resolvedAt, forKey: "resolvedAt")
            object.setValue(value.note, forKey: "note")
            object.setValue(Date(), forKey: "createdAt")
            object.setValue(try Self.fetchOne(entity: "MedicationDefinition", id: value.medicationID, in: context), forKey: "medication")
        }
    }

    // MARK: Fasting

    public func fetchFastingSessions(limit: Int) async throws -> [LifeBoardFastingSessionValue] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "FastingSession")
            request.sortDescriptors = [NSSortDescriptor(key: "startedAt", ascending: false)]
            request.fetchLimit = max(1, limit)
            return try context.fetch(request).compactMap(Self.fastingValue)
        }
    }

    public func saveFastingSession(_ value: LifeBoardFastingSessionValue) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "FastingSession", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.startedAt, forKey: "startedAt")
            object.setValue(value.endedAt, forKey: "endedAt")
            object.setValue(value.targetDuration.map(NSNumber.init(value:)), forKey: "targetDuration")
            object.setValue(try Self.encode(value.reminderOffsets), forKey: "reminderOffsetsData")
            object.setValue(value.note, forKey: "note")
            object.setValue(value.startedAt, forKey: "createdAt")
        }
    }

    // MARK: Journal

    public func fetchJournalDays(
        search: String?,
        starredOnly: Bool,
        mood: LifeBoardJournalMood?
    ) async throws -> [LifeBoardJournalDayValue] {
        let values = try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "JournalDay")
            request.predicate = starredOnly ? NSPredicate(format: "isStarred == YES") : nil
            request.sortDescriptors = [NSSortDescriptor(key: "day", ascending: false)]
            request.relationshipKeyPathsForPrefetching = ["blocks", "media"]
            request.fetchBatchSize = 40
            return try context.fetch(request).compactMap(Self.journalDayValue)
        }
        let query = search?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        return values.filter { value in
            let matchesSearch = query.isEmpty
                || value.displayText.lowercased().contains(query)
                || (value.summary?.lowercased().contains(query) == true)
            let matchesMood = mood == nil || value.blocks.contains(where: { $0.mood == mood })
            return matchesSearch && matchesMood
        }
    }

    public func fetchJournalDay(containing date: Date) async throws -> LifeBoardJournalDayValue? {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "JournalDay")
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
                NSPredicate(format: "day >= %@", start as NSDate),
                NSPredicate(format: "day < %@", end as NSDate)
            ])
            request.relationshipKeyPathsForPrefetching = ["blocks", "media"]
            request.fetchLimit = 1
            return try context.fetch(request).first.flatMap(Self.journalDayValue)
        }
    }

    public func saveJournalDay(_ value: LifeBoardJournalDayValue) async throws {
        try await write { context in
            let day = try Self.upsert(entity: "JournalDay", id: value.id, in: context)
            day.setValue(value.id, forKey: "id")
            day.setValue(Calendar.current.startOfDay(for: value.day), forKey: "day")
            day.setValue(value.summary, forKey: "summary")
            day.setValue(value.isStarred, forKey: "isStarred")
            day.setValue(value.representativeCheckInID, forKey: "representativeCheckInID")
            day.setValue(value.createdAt, forKey: "createdAt")
            day.setValue(value.updatedAt, forKey: "updatedAt")

            Self.deleteChildren(of: day, key: "blocks", in: context)
            Self.deleteChildren(of: day, key: "media", in: context)

            for blockValue in value.blocks {
                let block = NSEntityDescription.insertNewObject(forEntityName: "JournalBlock", into: context)
                block.setValue(blockValue.id, forKey: "id")
                block.setValue(value.id, forKey: "dayID")
                block.setValue(blockValue.kind.rawValue, forKey: "kindRaw")
                block.setValue(blockValue.text, forKey: "text")
                block.setValue(blockValue.mood?.rawValue, forKey: "moodRaw")
                block.setValue(blockValue.energy.map(NSNumber.init(value:)), forKey: "energy")
                block.setValue(blockValue.mediaID, forKey: "mediaID")
                block.setValue(blockValue.promptID, forKey: "promptID")
                block.setValue(blockValue.createdAt, forKey: "createdAt")
                block.setValue(blockValue.updatedAt, forKey: "updatedAt")
                block.setValue(blockValue.ordinal, forKey: "ordinal")
                block.setValue(day, forKey: "day")
            }

            for mediaValue in value.media {
                let media = NSEntityDescription.insertNewObject(forEntityName: "JournalMediaAttachment", into: context)
                media.setValue(mediaValue.id, forKey: "id")
                media.setValue(value.id, forKey: "dayID")
                media.setValue(mediaValue.kind.rawValue, forKey: "kindRaw")
                media.setValue(mediaValue.kind == .photo ? mediaValue.payload : nil, forKey: "payloadData")
                media.setValue(mediaValue.relativePath, forKey: "relativePath")
                media.setValue(mediaValue.duration.map(NSNumber.init(value:)), forKey: "duration")
                media.setValue(mediaValue.createdAt, forKey: "createdAt")
                media.setValue(mediaValue.syncPolicy.rawValue, forKey: "syncPolicyRaw")
                media.setValue(day, forKey: "day")
            }
        }
    }

    public func deleteJournalDay(id: UUID) async throws {
        try await write { context in
            if let day = try Self.fetchOne(entity: "JournalDay", id: id, in: context) {
                context.delete(day)
            }
        }
    }

    // MARK: Knowledge

    public func fetchKnowledgeSpaces() async throws -> [LifeBoardKnowledgeSpaceValue] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "KnowledgeSpace")
            request.sortDescriptors = [NSSortDescriptor(key: "updatedAt", ascending: false)]
            return try context.fetch(request).compactMap(Self.spaceValue)
        }
    }

    public func saveKnowledgeSpace(_ value: LifeBoardKnowledgeSpaceValue) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "KnowledgeSpace", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.title, forKey: "title")
            object.setValue(value.icon, forKey: "icon")
            object.setValue(value.createdAt, forKey: "createdAt")
            object.setValue(value.updatedAt, forKey: "updatedAt")
        }
    }

    public func fetchKnowledgeFolders(spaceID: UUID?) async throws -> [LifeBoardKnowledgeFolderValue] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "KnowledgeFolder")
            if let spaceID { request.predicate = NSPredicate(format: "spaceID == %@", spaceID as CVarArg) }
            request.sortDescriptors = [NSSortDescriptor(key: "ordinal", ascending: true), NSSortDescriptor(key: "title", ascending: true)]
            return try context.fetch(request).compactMap(Self.folderValue)
        }
    }

    public func saveKnowledgeFolder(_ value: LifeBoardKnowledgeFolderValue) async throws {
        try await write { context in
            let object = try Self.upsert(entity: "KnowledgeFolder", id: value.id, in: context)
            object.setValue(value.id, forKey: "id")
            object.setValue(value.spaceID, forKey: "spaceID")
            object.setValue(value.parentFolderID, forKey: "parentFolderID")
            object.setValue(value.title, forKey: "title")
            object.setValue(value.ordinal, forKey: "ordinal")
            object.setValue(try Self.fetchOne(entity: "KnowledgeSpace", id: value.spaceID, in: context), forKey: "space")
        }
    }

    public func fetchKnowledgeNotes(search: String?, spaceID: UUID?) async throws -> [LifeBoardKnowledgeNoteValue] {
        let values = try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "KnowledgeNote")
            if let spaceID { request.predicate = NSPredicate(format: "spaceID == %@", spaceID as CVarArg) }
            request.relationshipKeyPathsForPrefetching = ["blocks", "tagLinks"]
            request.sortDescriptors = [NSSortDescriptor(key: "isPinned", ascending: false), NSSortDescriptor(key: "updatedAt", ascending: false)]
            request.fetchBatchSize = 50
            return try context.fetch(request).compactMap(Self.noteValue)
        }
        let query = search?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        guard !query.isEmpty else { return values }
        return values.filter { $0.title.lowercased().contains(query) || $0.plainText.lowercased().contains(query) }
    }

    public func saveKnowledgeNote(_ value: LifeBoardKnowledgeNoteValue) async throws {
        try await write { context in
            let note = try Self.upsert(entity: "KnowledgeNote", id: value.id, in: context)
            note.setValue(value.id, forKey: "id")
            note.setValue(value.spaceID, forKey: "spaceID")
            note.setValue(value.folderID, forKey: "folderID")
            note.setValue(value.title, forKey: "title")
            note.setValue(value.isPinned, forKey: "isPinned")
            note.setValue(value.isFavorite, forKey: "isFavorite")
            note.setValue(value.createdAt, forKey: "createdAt")
            note.setValue(value.updatedAt, forKey: "updatedAt")
            note.setValue(try Self.fetchOne(entity: "KnowledgeSpace", id: value.spaceID, in: context), forKey: "space")
            if let folderID = value.folderID {
                note.setValue(try Self.fetchOne(entity: "KnowledgeFolder", id: folderID, in: context), forKey: "folder")
            } else {
                note.setValue(nil, forKey: "folder")
            }

            Self.deleteChildren(of: note, key: "blocks", in: context)
            Self.deleteChildren(of: note, key: "tagLinks", in: context)

            for blockValue in value.blocks {
                let block = NSEntityDescription.insertNewObject(forEntityName: "KnowledgeBlock", into: context)
                block.setValue(blockValue.id, forKey: "id")
                block.setValue(value.id, forKey: "noteID")
                block.setValue(blockValue.kind.rawValue, forKey: "kindRaw")
                block.setValue(blockValue.text, forKey: "text")
                block.setValue(blockValue.metadata, forKey: "metadataData")
                block.setValue(blockValue.ordinal, forKey: "ordinal")
                block.setValue(blockValue.isChecked, forKey: "isChecked")
                block.setValue(note, forKey: "note")
            }

            for tagID in value.tagIDs {
                guard let tag = try Self.fetchOne(entity: "KnowledgeTag", id: tagID, in: context) else { continue }
                let link = NSEntityDescription.insertNewObject(forEntityName: "KnowledgeNoteTagLink", into: context)
                link.setValue(UUID(), forKey: "id")
                link.setValue(value.id, forKey: "noteID")
                link.setValue(tagID, forKey: "tagID")
                link.setValue(note, forKey: "note")
                link.setValue(tag, forKey: "tag")
            }
        }
    }

    public func deleteKnowledgeNote(id: UUID) async throws {
        try await write { context in
            if let note = try Self.fetchOne(entity: "KnowledgeNote", id: id, in: context) { context.delete(note) }
        }
    }

    public func fetchKnowledgeTags() async throws -> [LifeBoardKnowledgeTagValue] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "KnowledgeTag")
            request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
            return try context.fetch(request).compactMap(Self.tagValue)
        }
    }

    public func saveKnowledgeTag(_ value: LifeBoardKnowledgeTagValue) async throws {
        try await write { context in
            let tag = try Self.upsert(entity: "KnowledgeTag", id: value.id, in: context)
            tag.setValue(value.id, forKey: "id")
            tag.setValue(value.name, forKey: "name")
            tag.setValue(value.colorHex, forKey: "colorHex")
        }
    }

    public func fetchKnowledgeLinks() async throws -> [LifeBoardKnowledgeLinkValue] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "KnowledgeLink")
            return try context.fetch(request).compactMap(Self.linkValue)
        }
    }

    public func saveKnowledgeLink(_ value: LifeBoardKnowledgeLinkValue) async throws {
        guard value.sourceNoteID != value.destinationNoteID else { return }
        try await write { context in
            let link = try Self.upsert(entity: "KnowledgeLink", id: value.id, in: context)
            link.setValue(value.id, forKey: "id")
            link.setValue(value.sourceNoteID, forKey: "sourceNoteID")
            link.setValue(value.destinationNoteID, forKey: "destinationNoteID")
            link.setValue(value.label, forKey: "label")
            link.setValue(try Self.fetchOne(entity: "KnowledgeNote", id: value.sourceNoteID, in: context), forKey: "sourceNote")
            link.setValue(try Self.fetchOne(entity: "KnowledgeNote", id: value.destinationNoteID, in: context), forKey: "destinationNote")
        }
    }

    public func deleteKnowledgeLink(id: UUID) async throws {
        try await write { context in
            if let link = try Self.fetchOne(entity: "KnowledgeLink", id: id, in: context) { context.delete(link) }
        }
    }

    public func fetchKnowledgeAttachments(noteID: UUID) async throws -> [LifeBoardKnowledgeAttachmentValue] {
        try await read { context in
            let request = NSFetchRequest<NSManagedObject>(entityName: "KnowledgeAttachment")
            request.predicate = NSPredicate(format: "noteID == %@", noteID as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: true)]
            return try context.fetch(request).compactMap(Self.attachmentValue)
        }
    }

    public func saveKnowledgeAttachment(_ value: LifeBoardKnowledgeAttachmentValue) async throws {
        try await write { context in
            let attachment = try Self.upsert(entity: "KnowledgeAttachment", id: value.id, in: context)
            attachment.setValue(value.id, forKey: "id")
            attachment.setValue(value.noteID, forKey: "noteID")
            attachment.setValue(value.kind, forKey: "kindRaw")
            attachment.setValue(value.fileName, forKey: "fileName")
            attachment.setValue(value.payload, forKey: "payloadData")
            attachment.setValue(value.createdAt, forKey: "createdAt")
            attachment.setValue(try Self.fetchOne(entity: "KnowledgeNote", id: value.noteID, in: context), forKey: "note")
        }
    }

    public func deleteKnowledgeAttachment(id: UUID) async throws {
        try await write { context in
            if let attachment = try Self.fetchOne(entity: "KnowledgeAttachment", id: id, in: context) { context.delete(attachment) }
        }
    }

    // MARK: Context helpers

    private func read<T: Sendable>(_ operation: @escaping @Sendable (NSManagedObjectContext) throws -> T) async throws -> T {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        return try await context.perform { try operation(context) }
    }

    private func write(_ operation: @escaping @Sendable (NSManagedObjectContext) throws -> Void) async throws {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)
        try await context.perform {
            try operation(context)
            if context.hasChanges { try context.save() }
        }
    }

    private static func fetchOne(entity: String, id: UUID, in context: NSManagedObjectContext) throws -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try context.fetch(request).first
    }

    private static func upsert(entity: String, id: UUID, in context: NSManagedObjectContext) throws -> NSManagedObject {
        if let existing = try fetchOne(entity: entity, id: id, in: context) { return existing }
        return NSEntityDescription.insertNewObject(forEntityName: entity, into: context)
    }

    private static func deleteChildren(of object: NSManagedObject, key: String, in context: NSManagedObjectContext) {
        let children = (object.value(forKey: key) as? Set<NSManagedObject>) ?? []
        children.forEach(context.delete)
    }

    private static func encode<T: Encodable>(_ value: T) throws -> Data { try JSONEncoder().encode(value) }
    private static func decode<T: Decodable>(_ type: T.Type, from data: Data?) -> T? {
        guard let data else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: Value mappers

    private static func trackerValue(_ object: NSManagedObject) -> LifeBoardTrackerDefinitionValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let title = object.value(forKey: "title") as? String,
              let raw = object.value(forKey: "kindRaw") as? String,
              let kind = LifeBoardTrackerKind(rawValue: raw) else { return nil }
        return .init(
            id: id,
            title: title,
            kind: kind,
            unitLabel: object.value(forKey: "unitLabel") as? String,
            targetValue: (object.value(forKey: "targetValue") as? NSNumber)?.doubleValue,
            schedule: decode(Set<Int>.self, from: object.value(forKey: "scheduleData") as? Data) ?? Set(1...7),
            reminderMinutes: (object.value(forKey: "reminderMinutes") as? NSNumber)?.intValue,
            isArchived: (object.value(forKey: "isArchived") as? NSNumber)?.boolValue ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private static func trackerEntryValue(_ object: NSManagedObject) -> LifeBoardTrackerEntryValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let trackerID = object.value(forKey: "trackerID") as? UUID else { return nil }
        return .init(
            id: id,
            trackerID: trackerID,
            timestamp: object.value(forKey: "timestamp") as? Date ?? Date(),
            numericValue: (object.value(forKey: "numericValue") as? NSNumber)?.doubleValue,
            booleanValue: (object.value(forKey: "booleanValue") as? NSNumber)?.boolValue,
            note: object.value(forKey: "note") as? String
        )
    }

    private static func moodValue(_ object: NSManagedObject) -> LifeBoardMoodEnergyCheckInValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let raw = object.value(forKey: "moodRaw") as? String,
              let mood = LifeBoardJournalMood(rawValue: raw) else { return nil }
        return .init(
            id: id,
            mood: mood,
            energy: (object.value(forKey: "energy") as? NSNumber)?.intValue,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            representativeDay: object.value(forKey: "representativeDay") as? Date,
            isRepresentative: (object.value(forKey: "isRepresentative") as? NSNumber)?.boolValue ?? false
        )
    }

    private static func medicationValue(_ object: NSManagedObject) -> LifeBoardMedicationDefinitionValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let name = object.value(forKey: "name") as? String else { return nil }
        return .init(
            id: id,
            name: name,
            dosageText: object.value(forKey: "dosageText") as? String,
            instructions: object.value(forKey: "instructions") as? String,
            healthCorrelationID: object.value(forKey: "healthCorrelationID") as? String,
            isArchived: (object.value(forKey: "isArchived") as? NSNumber)?.boolValue ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date()
        )
    }

    private static func medicationScheduleValue(_ object: NSManagedObject) -> LifeBoardMedicationScheduleValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let medicationID = object.value(forKey: "medicationID") as? UUID else { return nil }
        return .init(
            id: id,
            medicationID: medicationID,
            windowStartMinutes: (object.value(forKey: "windowStartMinutes") as? NSNumber)?.intValue ?? 0,
            windowEndMinutes: (object.value(forKey: "windowEndMinutes") as? NSNumber)?.intValue ?? 0,
            weekdays: decode(Set<Int>.self, from: object.value(forKey: "weekdaysData") as? Data) ?? Set(1...7),
            reminderEnabled: (object.value(forKey: "reminderEnabled") as? NSNumber)?.boolValue ?? true
        )
    }

    private static func medicationEventValue(_ object: NSManagedObject) -> LifeBoardMedicationEventValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let medicationID = object.value(forKey: "medicationID") as? UUID,
              let scheduledAt = object.value(forKey: "scheduledAt") as? Date,
              let raw = object.value(forKey: "statusRaw") as? String,
              let status = LifeBoardMedicationEventStatus(rawValue: raw) else { return nil }
        return .init(
            id: id,
            medicationID: medicationID,
            scheduledAt: scheduledAt,
            status: status,
            resolvedAt: object.value(forKey: "resolvedAt") as? Date,
            note: object.value(forKey: "note") as? String
        )
    }

    private static func fastingValue(_ object: NSManagedObject) -> LifeBoardFastingSessionValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let startedAt = object.value(forKey: "startedAt") as? Date else { return nil }
        return .init(
            id: id,
            startedAt: startedAt,
            endedAt: object.value(forKey: "endedAt") as? Date,
            targetDuration: (object.value(forKey: "targetDuration") as? NSNumber)?.doubleValue,
            reminderOffsets: decode([TimeInterval].self, from: object.value(forKey: "reminderOffsetsData") as? Data) ?? [],
            note: object.value(forKey: "note") as? String
        )
    }

    private static func journalDayValue(_ object: NSManagedObject) -> LifeBoardJournalDayValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let day = object.value(forKey: "day") as? Date else { return nil }
        let blockObjects = (object.value(forKey: "blocks") as? Set<NSManagedObject>) ?? []
        let mediaObjects = (object.value(forKey: "media") as? Set<NSManagedObject>) ?? []
        return .init(
            id: id,
            day: day,
            summary: object.value(forKey: "summary") as? String,
            isStarred: (object.value(forKey: "isStarred") as? NSNumber)?.boolValue ?? false,
            representativeCheckInID: object.value(forKey: "representativeCheckInID") as? UUID,
            createdAt: object.value(forKey: "createdAt") as? Date ?? day,
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? day,
            blocks: blockObjects.compactMap(journalBlockValue),
            media: mediaObjects.compactMap(journalMediaValue)
        )
    }

    private static func journalBlockValue(_ object: NSManagedObject) -> LifeBoardJournalBlockValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let dayID = object.value(forKey: "dayID") as? UUID,
              let raw = object.value(forKey: "kindRaw") as? String,
              let kind = LifeBoardJournalBlockKind(rawValue: raw) else { return nil }
        let mood = (object.value(forKey: "moodRaw") as? String).flatMap(LifeBoardJournalMood.init(rawValue:))
        return .init(
            id: id,
            dayID: dayID,
            kind: kind,
            text: object.value(forKey: "text") as? String,
            mood: mood,
            energy: (object.value(forKey: "energy") as? NSNumber)?.intValue,
            mediaID: object.value(forKey: "mediaID") as? UUID,
            promptID: object.value(forKey: "promptID") as? String,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date(),
            ordinal: (object.value(forKey: "ordinal") as? NSNumber)?.intValue ?? 0
        )
    }

    private static func journalMediaValue(_ object: NSManagedObject) -> LifeBoardJournalMediaValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let dayID = object.value(forKey: "dayID") as? UUID,
              let raw = object.value(forKey: "kindRaw") as? String,
              let kind = LifeBoardJournalMediaKind(rawValue: raw) else { return nil }
        let policyRaw = object.value(forKey: "syncPolicyRaw") as? String
        return .init(
            id: id,
            dayID: dayID,
            kind: kind,
            payload: object.value(forKey: "payloadData") as? Data,
            relativePath: object.value(forKey: "relativePath") as? String,
            duration: (object.value(forKey: "duration") as? NSNumber)?.doubleValue,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            syncPolicy: policyRaw.flatMap(LifeBoardJournalMediaSyncPolicy.init(rawValue:)) ?? (kind == .audio ? .protectedLocalOnly : .privateCloud)
        )
    }

    private static func spaceValue(_ object: NSManagedObject) -> LifeBoardKnowledgeSpaceValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let title = object.value(forKey: "title") as? String else { return nil }
        return .init(id: id, title: title, icon: object.value(forKey: "icon") as? String ?? "square.grid.2x2", createdAt: object.value(forKey: "createdAt") as? Date ?? Date(), updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date())
    }

    private static func folderValue(_ object: NSManagedObject) -> LifeBoardKnowledgeFolderValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let spaceID = object.value(forKey: "spaceID") as? UUID,
              let title = object.value(forKey: "title") as? String else { return nil }
        return .init(id: id, spaceID: spaceID, parentFolderID: object.value(forKey: "parentFolderID") as? UUID, title: title, ordinal: (object.value(forKey: "ordinal") as? NSNumber)?.intValue ?? 0)
    }

    private static func noteValue(_ object: NSManagedObject) -> LifeBoardKnowledgeNoteValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let spaceID = object.value(forKey: "spaceID") as? UUID,
              let title = object.value(forKey: "title") as? String else { return nil }
        let blocks = ((object.value(forKey: "blocks") as? Set<NSManagedObject>) ?? []).compactMap(knowledgeBlockValue)
        let links = (object.value(forKey: "tagLinks") as? Set<NSManagedObject>) ?? []
        let tagIDs = Set(links.compactMap { $0.value(forKey: "tagID") as? UUID })
        return .init(
            id: id,
            spaceID: spaceID,
            folderID: object.value(forKey: "folderID") as? UUID,
            title: title,
            isPinned: (object.value(forKey: "isPinned") as? NSNumber)?.boolValue ?? false,
            isFavorite: (object.value(forKey: "isFavorite") as? NSNumber)?.boolValue ?? false,
            createdAt: object.value(forKey: "createdAt") as? Date ?? Date(),
            updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date(),
            blocks: blocks,
            tagIDs: tagIDs
        )
    }

    private static func knowledgeBlockValue(_ object: NSManagedObject) -> LifeBoardKnowledgeBlockValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let noteID = object.value(forKey: "noteID") as? UUID,
              let raw = object.value(forKey: "kindRaw") as? String,
              let kind = LifeBoardKnowledgeBlockKind(rawValue: raw) else { return nil }
        return .init(
            id: id,
            noteID: noteID,
            kind: kind,
            text: object.value(forKey: "text") as? String ?? "",
            metadata: object.value(forKey: "metadataData") as? Data,
            ordinal: (object.value(forKey: "ordinal") as? NSNumber)?.intValue ?? 0,
            isChecked: (object.value(forKey: "isChecked") as? NSNumber)?.boolValue ?? false
        )
    }

    private static func tagValue(_ object: NSManagedObject) -> LifeBoardKnowledgeTagValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let name = object.value(forKey: "name") as? String else { return nil }
        return .init(id: id, name: name, colorHex: object.value(forKey: "colorHex") as? String)
    }

    private static func linkValue(_ object: NSManagedObject) -> LifeBoardKnowledgeLinkValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let source = object.value(forKey: "sourceNoteID") as? UUID,
              let destination = object.value(forKey: "destinationNoteID") as? UUID else { return nil }
        return .init(id: id, sourceNoteID: source, destinationNoteID: destination, label: object.value(forKey: "label") as? String)
    }

    private static func attachmentValue(_ object: NSManagedObject) -> LifeBoardKnowledgeAttachmentValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let noteID = object.value(forKey: "noteID") as? UUID,
              let kind = object.value(forKey: "kindRaw") as? String,
              let fileName = object.value(forKey: "fileName") as? String,
              let payload = object.value(forKey: "payloadData") as? Data else { return nil }
        return .init(id: id, noteID: noteID, kind: kind, fileName: fileName, payload: payload, createdAt: object.value(forKey: "createdAt") as? Date ?? Date())
    }
}
