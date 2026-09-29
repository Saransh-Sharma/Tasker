import CoreData
import Foundation
import LifeBoardDomain

extension CoreDataLifeBoardPhaseIIRepository {
    static func spaceValue(_ object: NSManagedObject) -> KnowledgeSpaceValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let title = object.value(forKey: "title") as? String else { return nil }
        return .init(id: id, title: title, icon: object.value(forKey: "icon") as? String ?? "square.grid.2x2", createdAt: object.value(forKey: "createdAt") as? Date ?? Date(), updatedAt: object.value(forKey: "updatedAt") as? Date ?? Date())
    }

    static func folderValue(_ object: NSManagedObject) -> KnowledgeFolderValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let spaceID = object.value(forKey: "spaceID") as? UUID,
              let title = object.value(forKey: "title") as? String else { return nil }
        return .init(id: id, spaceID: spaceID, parentFolderID: object.value(forKey: "parentFolderID") as? UUID, title: title, ordinal: (object.value(forKey: "ordinal") as? NSNumber)?.intValue ?? 0)
    }

    static func noteValue(_ object: NSManagedObject) -> KnowledgeNoteValue? {
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
            tagIDs: tagIDs,
            state: (object.value(forKey: "stateRaw") as? String).flatMap(KnowledgeNoteState.init(rawValue:)),
            deletedAt: object.value(forKey: "deletedAt") as? Date,
            lastOpenedAt: object.value(forKey: "lastOpenedAt") as? Date,
            manualSortOrder: (object.value(forKey: "manualSortOrder") as? NSNumber)?.doubleValue,
            templateID: object.value(forKey: "templateID") as? String,
            contentVersion: (object.value(forKey: "contentVersion") as? NSNumber)?.intValue,
            lockPolicy: (object.value(forKey: "lockPolicyRaw") as? String).flatMap(KnowledgeNoteLockPolicy.init(rawValue:))
        )
    }

    private static func knowledgeBlockValue(_ object: NSManagedObject) -> KnowledgeBlockValue? {
        guard let id = object.value(forKey: "id") as? UUID,
              let noteID = object.value(forKey: "noteID") as? UUID,
              let raw = object.value(forKey: "kindRaw") as? String,
              let kind = KnowledgeBlockKind(rawValue: raw) else { return nil }
        return .init(
            id: id,
            noteID: noteID,
            kind: kind,
            text: object.value(forKey: "text") as? String ?? "",
            metadata: object.value(forKey: "metadataData") as? Data,
            ordinal: (object.value(forKey: "ordinal") as? NSNumber)?.intValue ?? 0,
            isChecked: (object.value(forKey: "isChecked") as? NSNumber)?.boolValue ?? false,
            richTextData: object.value(forKey: "richTextData") as? Data,
            parentBlockID: object.value(forKey: "parentBlockID") as? UUID,
            indentLevel: (object.value(forKey: "indentLevel") as? NSNumber)?.intValue,
            isCollapsed: (object.value(forKey: "isCollapsed") as? NSNumber)?.boolValue,
            createdAt: object.value(forKey: "createdAt") as? Date,
            updatedAt: object.value(forKey: "updatedAt") as? Date
        )
    }
}
