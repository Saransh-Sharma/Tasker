import Foundation

public enum KnowledgeNoteState: String, Codable, CaseIterable, Sendable {
    case active
    case archived
    case trashed
}

public enum KnowledgeNoteLockPolicy: String, Codable, CaseIterable, Sendable {
    case unlocked
    case deviceAuthentication
}

public enum KnowledgeNoteSort: String, Codable, CaseIterable, Sendable {
    case updatedDescending
    case createdDescending
    case titleAscending
    case manual
}

public enum KnowledgeChecklistFilter: String, Codable, CaseIterable, Sendable {
    case any
    case incomplete
    case completed
}

public enum KnowledgeLinkFilter: String, Codable, CaseIterable, Sendable {
    case any
    case incoming
    case outgoing
    case unlinked
}

public struct KnowledgeNoteCursor: Codable, Hashable, Sendable {
    public var updatedAt: Date
    public var noteID: UUID

    public init(updatedAt: Date, noteID: UUID) {
        self.updatedAt = updatedAt
        self.noteID = noteID
    }
}

public enum KnowledgeNoteCollection: String, Codable, CaseIterable, Identifiable, Sendable {
    case all
    case pinned
    case favorites
    case recent
    case unfiled
    case checklists
    case attachments
    case linked
    case archived
    case trash
    case connections

    public var id: String { rawValue }
}

public struct KnowledgeNoteQuery: Codable, Hashable, Sendable {
    public var collection: KnowledgeNoteCollection
    public var spaceID: UUID?
    public var folderID: UUID?
    public var tagIDs: Set<UUID>
    public var searchText: String
    public var sort: KnowledgeNoteSort
    public var modifiedAfter: Date?
    public var modifiedBefore: Date?
    public var attachmentKinds: Set<String>
    public var requiresAttachments: Bool?
    public var checklist: KnowledgeChecklistFilter?
    public var links: KnowledgeLinkFilter?
    public var pinned: Bool?
    public var favorite: Bool?
    public var limit: Int?
    public var cursor: KnowledgeNoteCursor?

    public init(
        collection: KnowledgeNoteCollection = .all,
        spaceID: UUID? = nil,
        folderID: UUID? = nil,
        tagIDs: Set<UUID> = [],
        searchText: String = "",
        sort: KnowledgeNoteSort = .updatedDescending,
        modifiedAfter: Date? = nil,
        modifiedBefore: Date? = nil,
        attachmentKinds: Set<String> = [],
        requiresAttachments: Bool? = nil,
        checklist: KnowledgeChecklistFilter? = nil,
        links: KnowledgeLinkFilter? = nil,
        pinned: Bool? = nil,
        favorite: Bool? = nil,
        limit: Int? = nil,
        cursor: KnowledgeNoteCursor? = nil
    ) {
        self.collection = collection
        self.spaceID = spaceID
        self.folderID = folderID
        self.tagIDs = tagIDs
        self.searchText = searchText
        self.sort = sort
        self.modifiedAfter = modifiedAfter
        self.modifiedBefore = modifiedBefore
        self.attachmentKinds = attachmentKinds
        self.requiresAttachments = requiresAttachments
        self.checklist = checklist
        self.links = links
        self.pinned = pinned
        self.favorite = favorite
        self.limit = limit
        self.cursor = cursor
    }

    public func apply(
        to values: [KnowledgeNoteValue],
        linkedNoteIDs: Set<UUID> = [],
        incomingNoteIDs: Set<UUID> = [],
        outgoingNoteIDs: Set<UUID> = []
    ) -> [KnowledgeNoteValue] {
        let needle = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let now = Date()
        let filtered = values.filter { note in
            guard spaceID.map({ note.spaceID == $0 }) ?? true,
                  folderID.map({ note.folderID == $0 }) ?? true,
                  tagIDs.isSubset(of: note.tagIDs),
                  modifiedAfter.map({ note.updatedAt >= $0 }) ?? true,
                  modifiedBefore.map({ note.updatedAt <= $0 }) ?? true,
                  pinned.map({ note.isPinned == $0 }) ?? true,
                  favorite.map({ note.isFavorite == $0 }) ?? true else { return false }
            let attachmentBlocks = note.blocks.filter { $0.kind == .image || $0.kind == .file }
            if let requiresAttachments, requiresAttachments != !attachmentBlocks.isEmpty { return false }
            if !attachmentKinds.isEmpty {
                let kinds = Set(attachmentBlocks.map { $0.kind.rawValue })
                guard !kinds.isDisjoint(with: attachmentKinds) else { return false }
            }
            if let checklist, checklist != .any {
                let checks = note.blocks.filter { $0.kind == .checklist }
                switch checklist {
                case .incomplete where !checks.contains(where: { !$0.isChecked }): return false
                case .completed where checks.isEmpty || checks.contains(where: { !$0.isChecked }): return false
                default: break
                }
            }
            if let links, links != .any {
                switch links {
                case .incoming where !incomingNoteIDs.contains(note.id): return false
                case .outgoing where !outgoingNoteIDs.contains(note.id): return false
                case .unlinked where linkedNoteIDs.contains(note.id): return false
                default: break
                }
            }
            if let cursor {
                guard note.updatedAt < cursor.updatedAt
                    || (note.updatedAt == cursor.updatedAt && note.id.uuidString > cursor.noteID.uuidString) else {
                    return false
                }
            }
            let stateMatches: Bool
            switch collection {
            case .archived:
                stateMatches = note.resolvedState == .archived
            case .trash:
                stateMatches = note.resolvedState == .trashed
            default:
                stateMatches = note.resolvedState == .active
            }
            guard stateMatches else { return false }
            let collectionMatches: Bool
            switch collection {
            case .all, .archived, .trash, .connections:
                collectionMatches = true
            case .pinned:
                collectionMatches = note.isPinned
            case .favorites:
                collectionMatches = note.isFavorite
            case .recent:
                collectionMatches = now.timeIntervalSince(note.updatedAt) <= 60 * 60 * 24 * 14
            case .unfiled:
                collectionMatches = note.folderID == nil
            case .checklists:
                collectionMatches = note.blocks.contains { $0.kind == .checklist }
            case .attachments:
                collectionMatches = note.blocks.contains { $0.kind == .image || $0.kind == .file }
            case .linked:
                collectionMatches = linkedNoteIDs.contains(note.id)
            }
            guard collectionMatches else { return false }
            guard !needle.isEmpty else { return true }
            let haystack = ([note.title, note.plainText] + note.blocks.compactMap(\.searchableMetadata))
                .joined(separator: "\n")
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            return haystack.contains(needle)
        }
        let sorted = filtered.sorted { lhs, rhs in
            if !needle.isEmpty {
                let lhsRank = searchRank(lhs, needle: needle)
                let rhsRank = searchRank(rhs, needle: needle)
                if lhsRank != rhsRank { return lhsRank > rhsRank }
            }
            if lhs.isPinned != rhs.isPinned, collection != .trash { return lhs.isPinned }
            switch sort {
            case .updatedDescending:
                return lhs.updatedAt > rhs.updatedAt
            case .createdDescending:
                return lhs.createdAt > rhs.createdAt
            case .titleAscending:
                return lhs.displayTitle.localizedStandardCompare(rhs.displayTitle) == .orderedAscending
            case .manual:
                return (lhs.manualSortOrder ?? 0) < (rhs.manualSortOrder ?? 0)
            }
        }
        if let limit, limit > 0 { return Array(sorted.prefix(limit)) }
        return sorted
    }

    private func searchRank(_ note: KnowledgeNoteValue, needle: String) -> Int {
        let title = note.title.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
        if title == needle { return 500 }
        if title.hasPrefix(needle) { return 400 }
        if title.contains(needle) { return 300 }
        if note.blocks.contains(where: {
            $0.searchableMetadata?
                .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
                .contains(needle) == true
        }) { return 220 }
        return 200
    }

    private enum CodingKeys: String, CodingKey {
        case collection, spaceID, folderID, tagIDs, searchText, sort
        case modifiedAfter, modifiedBefore, attachmentKinds, requiresAttachments
        case checklist, links, pinned, favorite, limit, cursor
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        collection = try values.decodeIfPresent(KnowledgeNoteCollection.self, forKey: .collection) ?? .all
        spaceID = try values.decodeIfPresent(UUID.self, forKey: .spaceID)
        folderID = try values.decodeIfPresent(UUID.self, forKey: .folderID)
        tagIDs = try values.decodeIfPresent(Set<UUID>.self, forKey: .tagIDs) ?? []
        searchText = try values.decodeIfPresent(String.self, forKey: .searchText) ?? ""
        sort = try values.decodeIfPresent(KnowledgeNoteSort.self, forKey: .sort) ?? .updatedDescending
        modifiedAfter = try values.decodeIfPresent(Date.self, forKey: .modifiedAfter)
        modifiedBefore = try values.decodeIfPresent(Date.self, forKey: .modifiedBefore)
        attachmentKinds = try values.decodeIfPresent(Set<String>.self, forKey: .attachmentKinds) ?? []
        requiresAttachments = try values.decodeIfPresent(Bool.self, forKey: .requiresAttachments)
        checklist = try values.decodeIfPresent(KnowledgeChecklistFilter.self, forKey: .checklist)
        links = try values.decodeIfPresent(KnowledgeLinkFilter.self, forKey: .links)
        pinned = try values.decodeIfPresent(Bool.self, forKey: .pinned)
        favorite = try values.decodeIfPresent(Bool.self, forKey: .favorite)
        limit = try values.decodeIfPresent(Int.self, forKey: .limit)
        cursor = try values.decodeIfPresent(KnowledgeNoteCursor.self, forKey: .cursor)
    }
}

public enum NotesLibraryDestination: Codable, Hashable, Sendable {
    case library(KnowledgeNoteQuery)
    case collection(KnowledgeNoteCollection)
    case folder(UUID)
    case tag(UUID)
    case search(String)
}

public struct KnowledgeRichTextPayload: Codable, Hashable, Sendable {
    public enum Mark: String, Codable, CaseIterable, Sendable {
        case bold
        case italic
        case underline
        case strikethrough
        case highlight
        case inlineCode
    }

    public enum SemanticColor: String, Codable, CaseIterable, Sendable {
        case cocoa
        case apricot
        case sage
        case rose
        case sky
        case secondary
    }

    public enum ParagraphSemantic: String, Codable, CaseIterable, Sendable {
        case body
        case heading1
        case heading2
        case quote
        case code
        case callout
    }

    public struct Run: Codable, Hashable, Sendable {
        public var location: Int
        public var length: Int
        public var marks: Set<Mark>
        public var link: URL?
        public var foreground: SemanticColor?
        public var background: SemanticColor?
        public var noteID: UUID?

        public init(
            location: Int,
            length: Int,
            marks: Set<Mark> = [],
            link: URL? = nil,
            foreground: SemanticColor? = nil,
            background: SemanticColor? = nil,
            noteID: UUID? = nil
        ) {
            self.location = location
            self.length = length
            self.marks = marks
            self.link = link
            self.foreground = foreground
            self.background = background
            self.noteID = noteID
        }
    }

    public var version: Int
    public var runs: [Run]
    public var paragraph: ParagraphSemantic?
    public var unsupportedVersion: Int? {
        version > Self.currentVersion ? version : nil
    }

    public static let currentVersion = 2

    public init(
        version: Int = KnowledgeRichTextPayload.currentVersion,
        runs: [Run] = [],
        paragraph: ParagraphSemantic? = nil
    ) {
        self.version = version
        self.runs = runs
        self.paragraph = paragraph
    }
}

public struct KnowledgeSmartCollectionValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var spaceID: UUID?
    public var name: String
    public var symbol: String
    public var query: KnowledgeNoteQuery
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        spaceID: UUID? = nil,
        name: String,
        symbol: String = "sparkle.magnifyingglass",
        query: KnowledgeNoteQuery,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.spaceID = spaceID
        self.name = name
        self.symbol = symbol
        self.query = query
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

public struct KnowledgeNoteDraftValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var noteID: UUID
    public var snapshot: Data
    public var createdAt: Date?
    public var updatedAt: Date
    public var baseContentVersion: Int?
    public var sceneID: String?

    public init(
        id: UUID = UUID(),
        noteID: UUID,
        snapshot: Data,
        createdAt: Date? = Date(),
        updatedAt: Date = Date(),
        baseContentVersion: Int? = nil,
        sceneID: String? = nil
    ) {
        self.id = id
        self.noteID = noteID
        self.snapshot = snapshot
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.baseContentVersion = baseContentVersion
        self.sceneID = sceneID
    }
}

public struct KnowledgeNoteRevisionValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var noteID: UUID
    public var snapshot: Data
    public var reason: String
    public var createdAt: Date
    public var baseContentVersion: Int?
    public var contentVersion: Int?
    public var sessionID: UUID?
    public var changeKind: String?

    public init(
        id: UUID = UUID(),
        noteID: UUID,
        snapshot: Data,
        reason: String,
        createdAt: Date = Date(),
        baseContentVersion: Int? = nil,
        contentVersion: Int? = nil,
        sessionID: UUID? = nil,
        changeKind: String? = nil
    ) {
        self.id = id
        self.noteID = noteID
        self.snapshot = snapshot
        self.reason = reason
        self.createdAt = createdAt
        self.baseContentVersion = baseContentVersion
        self.contentVersion = contentVersion
        self.sessionID = sessionID
        self.changeKind = changeKind
    }
}

public struct KnowledgeSecurePayloadValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var noteID: UUID
    public var ciphertext: Data
    public var updatedAt: Date
    public var contentVersion: Int
    public var algorithmVersion: Int
    public var keyIdentifier: String

    public init(
        id: UUID = UUID(),
        noteID: UUID,
        ciphertext: Data,
        updatedAt: Date = Date(),
        contentVersion: Int,
        algorithmVersion: Int,
        keyIdentifier: String
    ) {
        self.id = id
        self.noteID = noteID
        self.ciphertext = ciphertext
        self.updatedAt = updatedAt
        self.contentVersion = contentVersion
        self.algorithmVersion = algorithmVersion
        self.keyIdentifier = keyIdentifier
    }
}

public struct KnowledgeSecureAttachmentPayloadValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var noteID: UUID
    public var attachmentID: UUID
    public var ciphertext: Data
    public var checksum: String?
    public var byteCount: Int64
    public var algorithmVersion: Int
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        noteID: UUID,
        attachmentID: UUID,
        ciphertext: Data,
        checksum: String? = nil,
        byteCount: Int64,
        algorithmVersion: Int = 1,
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.noteID = noteID
        self.attachmentID = attachmentID
        self.ciphertext = ciphertext
        self.checksum = checksum
        self.byteCount = byteCount
        self.algorithmVersion = algorithmVersion
        self.updatedAt = updatedAt
    }
}

public struct KnowledgeNoteTemplate: Identifiable, Hashable, Sendable {
    public struct Block: Hashable, Sendable {
        public var kind: KnowledgeBlockKind
        public var text: String

        public init(_ kind: KnowledgeBlockKind, _ text: String) {
            self.kind = kind
            self.text = text
        }
    }

    public var id: String
    public var title: String
    public var subtitle: String
    public var symbol: String
    public var blocks: [Block]

    public static let library: [KnowledgeNoteTemplate] = [
        .init(id: "blank", title: "Blank", subtitle: "A quiet page", symbol: "doc", blocks: [.init(.paragraph, "")]),
        .init(id: "meeting", title: "Meeting", subtitle: "Decisions and next steps", symbol: "person.2", blocks: [.init(.heading2, "Context"), .init(.paragraph, ""), .init(.heading2, "Decisions"), .init(.bulletedList, ""), .init(.heading2, "Next steps"), .init(.checklist, "")]),
        .init(id: "project", title: "Project brief", subtitle: "Shape an idea into a plan", symbol: "square.stack.3d.up", blocks: [.init(.heading2, "Outcome"), .init(.paragraph, ""), .init(.heading2, "Why it matters"), .init(.paragraph, ""), .init(.heading2, "Next actions"), .init(.checklist, "")]),
        .init(id: "idea", title: "Idea", subtitle: "Capture the spark", symbol: "lightbulb", blocks: [.init(.callout, "The idea"), .init(.paragraph, ""), .init(.heading2, "What makes it interesting?"), .init(.paragraph, "")]),
        .init(id: "checklist", title: "Checklist", subtitle: "A focused list", symbol: "checklist", blocks: [.init(.checklist, ""), .init(.checklist, ""), .init(.checklist, "")]),
        .init(id: "research", title: "Research", subtitle: "Sources, findings, questions", symbol: "books.vertical", blocks: [.init(.heading2, "Question"), .init(.paragraph, ""), .init(.heading2, "Findings"), .init(.bulletedList, ""), .init(.heading2, "Sources"), .init(.bookmark, "")]),
        .init(id: "daily", title: "Daily notes", subtitle: "A practical day page", symbol: "sun.max", blocks: [.init(.heading2, "Today"), .init(.paragraph, ""), .init(.heading2, "To do"), .init(.checklist, ""), .init(.heading2, "Keep"), .init(.paragraph, "")])
    ]
}

public enum KnowledgeBlockKind: String, Codable, CaseIterable, Sendable {
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

public struct KnowledgeSpaceValue: Identifiable, Codable, Hashable, Sendable {
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

public struct KnowledgeFolderValue: Identifiable, Codable, Hashable, Sendable {
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
        in folders: [KnowledgeFolderValue]
    ) -> [KnowledgeFolderValue] {
        guard let folderID else { return [] }
        let byID = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })
        var result: [KnowledgeFolderValue] = []
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
        in folders: [KnowledgeFolderValue]
    ) -> Bool {
        guard folderID != parentID else { return false }
        guard let parentID else { return true }
        return path(to: parentID, in: folders).contains(where: { $0.id == folderID }) == false
    }
}

public struct KnowledgeBlockValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var noteID: UUID
    public var kind: KnowledgeBlockKind
    public var text: String
    public var metadata: Data?
    public var ordinal: Int
    public var isChecked: Bool
    public var richTextData: Data?
    public var parentBlockID: UUID?
    public var indentLevel: Int?
    public var isCollapsed: Bool?
    public var createdAt: Date?
    public var updatedAt: Date?

    public init(
        id: UUID = UUID(),
        noteID: UUID,
        kind: KnowledgeBlockKind = .paragraph,
        text: String = "",
        metadata: Data? = nil,
        ordinal: Int = 0,
        isChecked: Bool = false,
        richTextData: Data? = nil,
        parentBlockID: UUID? = nil,
        indentLevel: Int? = nil,
        isCollapsed: Bool? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.noteID = noteID
        self.kind = kind
        self.text = text
        self.metadata = metadata
        self.ordinal = ordinal
        self.isChecked = isChecked
        self.richTextData = richTextData
        self.parentBlockID = parentBlockID
        self.indentLevel = indentLevel
        self.isCollapsed = isCollapsed
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var searchableMetadata: String? {
        let payload = KnowledgeBlockPayload.decode(from: self)
        return [payload.bookmark?.title, payload.bookmark?.summary, payload.attachment?.fileName]
            .compactMap { $0 }
            .joined(separator: " ")
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

    public static func decode(from block: KnowledgeBlockValue) -> KnowledgeBlockPayload {
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

public struct KnowledgeNoteValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var spaceID: UUID
    public var folderID: UUID?
    public var title: String
    public var isPinned: Bool
    public var isFavorite: Bool
    public var createdAt: Date
    public var updatedAt: Date
    public var blocks: [KnowledgeBlockValue]
    public var tagIDs: Set<UUID>
    public var state: KnowledgeNoteState?
    public var deletedAt: Date?
    public var lastOpenedAt: Date?
    public var manualSortOrder: Double?
    public var templateID: String?
    public var contentVersion: Int?
    public var lockPolicy: KnowledgeNoteLockPolicy?

    public init(
        id: UUID = UUID(),
        spaceID: UUID,
        folderID: UUID? = nil,
        title: String,
        isPinned: Bool = false,
        isFavorite: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        blocks: [KnowledgeBlockValue] = [],
        tagIDs: Set<UUID> = [],
        state: KnowledgeNoteState? = nil,
        deletedAt: Date? = nil,
        lastOpenedAt: Date? = nil,
        manualSortOrder: Double? = nil,
        templateID: String? = nil,
        contentVersion: Int? = nil,
        lockPolicy: KnowledgeNoteLockPolicy? = nil
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
        self.state = state
        self.deletedAt = deletedAt
        self.lastOpenedAt = lastOpenedAt
        self.manualSortOrder = manualSortOrder
        self.templateID = templateID
        self.contentVersion = contentVersion
        self.lockPolicy = lockPolicy
    }

    public var plainText: String {
        blocks.map(\.text).joined(separator: "\n")
    }

    public var displayTitle: String {
        if resolvedLockPolicy != .unlocked { return "Locked note" }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    public var resolvedState: KnowledgeNoteState { state ?? .active }
    public var resolvedLockPolicy: KnowledgeNoteLockPolicy { lockPolicy ?? .unlocked }
    public var isMeaningful: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            || blocks.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || $0.kind == .image || $0.kind == .file }
    }
}

public struct KnowledgeTagValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var colorHex: String?

    public init(id: UUID = UUID(), name: String, colorHex: String? = nil) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
    }
}

public struct KnowledgeLinkValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var sourceNoteID: UUID
    public var destinationNoteID: UUID
    public var label: String?
    public var sourceBlockID: UUID?
    public var kind: String?

    public init(
        id: UUID = UUID(),
        sourceNoteID: UUID,
        destinationNoteID: UUID,
        label: String? = nil,
        sourceBlockID: UUID? = nil,
        kind: String? = nil
    ) {
        self.id = id
        self.sourceNoteID = sourceNoteID
        self.destinationNoteID = destinationNoteID
        self.label = label
        self.sourceBlockID = sourceBlockID
        self.kind = kind
    }
}

public struct KnowledgeAttachmentValue: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var noteID: UUID
    public var kind: String
    public var fileName: String
    public var payload: Data
    public var createdAt: Date
    public var contentType: String?
    public var checksum: String?
    public var byteCount: Int64?
    public var availability: String?
    public var duration: Double?
    public var thumbnail: Data?
    public var ocrText: String?
    public var transcript: String?
    public var modifiedAt: Date?
    public var sourceKind: String?
    public var processingState: String?
    public var processingErrorCode: String?
    public var protectedRelativePath: String?

    public init(
        id: UUID = UUID(),
        noteID: UUID,
        kind: String,
        fileName: String,
        payload: Data,
        createdAt: Date = Date(),
        contentType: String? = nil,
        checksum: String? = nil,
        byteCount: Int64? = nil,
        availability: String? = nil,
        duration: Double? = nil,
        thumbnail: Data? = nil,
        ocrText: String? = nil,
        transcript: String? = nil,
        modifiedAt: Date? = nil,
        sourceKind: String? = nil,
        processingState: String? = nil,
        processingErrorCode: String? = nil,
        protectedRelativePath: String? = nil
    ) {
        self.id = id
        self.noteID = noteID
        self.kind = kind
        self.fileName = fileName
        self.payload = payload
        self.createdAt = createdAt
        self.contentType = contentType
        self.checksum = checksum
        self.byteCount = byteCount
        self.availability = availability
        self.duration = duration
        self.thumbnail = thumbnail
        self.ocrText = ocrText
        self.transcript = transcript
        self.modifiedAt = modifiedAt
        self.sourceKind = sourceKind
        self.processingState = processingState
        self.processingErrorCode = processingErrorCode
        self.protectedRelativePath = protectedRelativePath
    }
}

public protocol KnowledgeAttachmentFileRepository: Sendable {
    func persist(_ attachment: KnowledgeAttachmentValue) async throws -> URL
    func resolvedURL(for attachment: KnowledgeAttachmentValue) async throws -> URL
    func deleteFile(for attachment: KnowledgeAttachmentValue) async throws
}

public protocol KnowledgeBookmarkMetadataFetching: Sendable {
    func metadata(for url: URL) async throws -> KnowledgeBlockPayload.Bookmark
}

public struct KnowledgeGraphSnapshot: Equatable, Sendable {
    public var notes: [KnowledgeNoteValue]
    public var links: [KnowledgeLinkValue]
}

public protocol KnowledgeRepository: Sendable {
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
