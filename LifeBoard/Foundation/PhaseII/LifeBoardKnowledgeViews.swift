import Foundation
import Observation
import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class LifeBoardKnowledgeStore {
    enum Layout: String, CaseIterable { case list, grid }
    enum BatchOperation: Sendable {
        case favorite
        case pin
        case archive
        case trash
        case restore
    }

    private(set) var spaces: [LifeBoardKnowledgeSpaceValue] = []
    private(set) var folders: [LifeBoardKnowledgeFolderValue] = []
    private(set) var notes: [LifeBoardKnowledgeNoteValue] = []
    private(set) var tags: [LifeBoardKnowledgeTagValue] = []
    private(set) var links: [LifeBoardKnowledgeLinkValue] = []
    private(set) var smartCollections: [KnowledgeSmartCollectionValue] = []
    private(set) var isLoading = false
    private(set) var isSearching = false
    private(set) var searchIndexStatus: KnowledgeSearchIndexStatus = .unavailable
    private(set) var rankedSearchIDs: [UUID] = []
    var selectedSpaceID: UUID?
    var selectedFolderID: UUID?
    var selectedTagIDs: Set<UUID> = []
    var selectedCollection: KnowledgeNoteCollection = .all
    var sort: KnowledgeNoteSort = .updatedDescending
    var layout: Layout = .list
    var searchText = ""
    var errorMessage: String?
    var undoMessage: String?
    private var undoNotes: [LifeBoardKnowledgeNoteValue] = []
    private let searchIndex: (any KnowledgeSearchIndex)?
    private let secureNotes: (any KnowledgeSecureNoteService)?
    private var didSeedSearchIndex = false
    private var searchTask: Task<Void, Never>?

    let repository: any LifeBoardPhaseIIRepository
    let attachmentFiles: any KnowledgeAttachmentFileRepository

    init(
        repository: any LifeBoardPhaseIIRepository,
        initialFolderID: UUID? = nil,
        attachmentFiles: (any KnowledgeAttachmentFileRepository)? = nil
    ) {
        self.repository = repository
        self.attachmentFiles = attachmentFiles ?? ProtectedKnowledgeAttachmentFiles()
        searchIndex = V2FeatureFlags.knowledgeNotesSearchIndexV2Enabled
            ? try? LocalKnowledgeSearchIndex()
            : nil
        secureNotes = V2FeatureFlags.knowledgeNotesSecurityV1Enabled
            ? DefaultKnowledgeSecureNoteService()
            : nil
        selectedFolderID = initialFolderID
    }

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            var loadedSpaces = try await repository.fetchKnowledgeSpaces()
            if loadedSpaces.isEmpty {
                let personal = LifeBoardKnowledgeSpaceValue(title: "Personal", icon: "person.crop.circle")
                try await repository.saveKnowledgeSpace(personal)
                loadedSpaces = [personal]
            }
            spaces = loadedSpaces
            if selectedSpaceID == nil { selectedSpaceID = spaces.first?.id }
            async let folderValues = repository.fetchKnowledgeFolders(spaceID: selectedSpaceID)
            async let noteValues = repository.fetchKnowledgeNotes(search: nil, spaceID: selectedSpaceID)
            async let tagValues = repository.fetchKnowledgeTags()
            async let linkValues = repository.fetchKnowledgeLinks()
            async let collectionValues = repository.fetchKnowledgeSmartCollections(spaceID: selectedSpaceID)
            (folders, notes, tags, links, smartCollections) = try await (
                folderValues, noteValues, tagValues, linkValues, collectionValues
            )
            if searchIndex != nil, !didSeedSearchIndex {
                didSeedSearchIndex = true
                await rebuildSearchIndex()
            }
            try? await repository.pruneKnowledgeRecovery(now: Date())
        } catch { errorMessage = error.localizedDescription }
    }

    var visibleNotes: [LifeBoardKnowledgeNoteValue] {
        let filtered = KnowledgeNoteQuery(
            collection: selectedCollection,
            spaceID: selectedSpaceID,
            folderID: selectedFolderID,
            tagIDs: selectedTagIDs,
            searchText: searchIndex == nil ? searchText : "",
            sort: sort
        ).apply(
            to: notes,
            linkedNoteIDs: Set(links.flatMap { [$0.sourceNoteID, $0.destinationNoteID] }),
            incomingNoteIDs: Set(links.map(\.destinationNoteID)),
            outgoingNoteIDs: Set(links.map(\.sourceNoteID))
        )
        guard searchIndex != nil, !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return filtered
        }
        let rank = Dictionary(uniqueKeysWithValues: rankedSearchIDs.enumerated().map { ($0.element, $0.offset) })
        return filtered.filter { rank[$0.id] != nil }.sorted {
            (rank[$0.id] ?? .max) < (rank[$1.id] ?? .max)
        }
    }

    var pinnedNotes: [LifeBoardKnowledgeNoteValue] {
        visibleNotes.filter(\.isPinned).sorted {
            let lhs = $0.manualSortOrder
            let rhs = $1.manualSortOrder
            if lhs != nil || rhs != nil {
                return (lhs ?? .greatestFiniteMagnitude) < (rhs ?? .greatestFiniteMagnitude)
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    var recentNotes: [LifeBoardKnowledgeNoteValue] {
        Array(visibleNotes.filter { !$0.isPinned }.prefix(8))
    }

    func createSpace(title: String) async {
        do {
            let value = LifeBoardKnowledgeSpaceValue(title: title)
            try await repository.saveKnowledgeSpace(value)
            selectedSpaceID = value.id
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func createFolder(title: String, parentID: UUID? = nil) async {
        guard let selectedSpaceID else { return }
        do {
            try await repository.saveKnowledgeFolder(.init(spaceID: selectedSpaceID, parentFolderID: parentID, title: title, ordinal: folders.count))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    var selectedFolderPath: [LifeBoardKnowledgeFolderValue] {
        KnowledgeFolderHierarchy.path(to: selectedFolderID, in: folders)
    }

    func navigateUp() {
        guard let selectedFolderID,
              let folder = folders.first(where: { $0.id == selectedFolderID }) else {
            self.selectedFolderID = nil
            return
        }
        self.selectedFolderID = folder.parentFolderID
    }

    func move(_ folder: LifeBoardKnowledgeFolderValue, to parentID: UUID?) async {
        guard KnowledgeFolderHierarchy.canMove(folderID: folder.id, to: parentID, in: folders) else {
            errorMessage = "A folder can’t be moved inside itself or one of its subfolders."
            return
        }
        var updated = folder
        updated.parentFolderID = parentID
        do {
            try await repository.saveKnowledgeFolder(updated)
            if selectedFolderID == folder.id { selectedFolderID = folder.id }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func move(_ note: LifeBoardKnowledgeNoteValue, to folderID: UUID?) async {
        var updated = note
        updated.folderID = folderID
        updated.updatedAt = Date()
        await save(updated)
    }

    func createNote(
        id: UUID? = nil,
        folderID: UUID? = nil,
        template: KnowledgeNoteTemplate = KnowledgeNoteTemplate.library[0],
        initialTitle: String = "",
        initialText: String? = nil
    ) -> LifeBoardKnowledgeNoteValue? {
        guard let selectedSpaceID else { return nil }
        let noteID = id ?? UUID()
        let blocks: [LifeBoardKnowledgeBlockValue]
        if let initialText, !initialText.isEmpty {
            blocks = [
                LifeBoardKnowledgeBlockValue(
                    noteID: noteID,
                    kind: .paragraph,
                    text: initialText,
                    ordinal: 0,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ]
        } else {
            blocks = template.blocks.enumerated().map { index, block in
                LifeBoardKnowledgeBlockValue(
                    noteID: noteID,
                    kind: block.kind,
                    text: block.text,
                    ordinal: index,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            }
        }
        let resolvedTitle = !initialTitle.isEmpty ? initialTitle : (template.id == "blank" ? "" : template.title)
        return .init(
            id: noteID,
            spaceID: selectedSpaceID,
            folderID: folderID,
            title: resolvedTitle,
            blocks: blocks,
            templateID: template.id,
            contentVersion: 1
        )
    }

    func save(_ note: LifeBoardKnowledgeNoteValue) async {
        do {
            try await repository.saveKnowledgeNote(note)
            try await reconcileBlockLinks(for: note)
            await index(note)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    private func reconcileBlockLinks(for note: LifeBoardKnowledgeNoteValue) async throws {
        let desired = note.blocks.compactMap { block -> (blockID: UUID, destinationID: UUID)? in
            guard let destinationID = KnowledgeBlockPayload.decode(from: block).noteLink?.noteID,
                  destinationID != note.id else { return nil }
            return (block.id, destinationID)
        }
        let generated = links.filter {
            $0.sourceNoteID == note.id && ($0.kind == "blockReference" || $0.label == "note-block")
        }
        for reference in desired where !generated.contains(where: {
            $0.sourceBlockID == reference.blockID && $0.destinationNoteID == reference.destinationID
        }) {
            try await repository.saveKnowledgeLink(.init(
                sourceNoteID: note.id,
                destinationNoteID: reference.destinationID,
                label: "note-block",
                sourceBlockID: reference.blockID,
                kind: "blockReference"
            ))
        }
        for stale in generated where !desired.contains(where: {
            $0.blockID == stale.sourceBlockID && $0.destinationID == stale.destinationNoteID
        }) {
            try await repository.deleteKnowledgeLink(id: stale.id)
        }
    }

    func moveToTrash(_ note: LifeBoardKnowledgeNoteValue) async {
        var updated = note
        updated.state = .trashed
        updated.deletedAt = Date()
        updated.updatedAt = Date()
        undoNotes = [note]
        undoMessage = "Moved “\(note.displayTitle)” to Trash"
        await save(updated)
    }

    func restore(_ note: LifeBoardKnowledgeNoteValue) async {
        var updated = note
        updated.state = .active
        updated.deletedAt = nil
        updated.updatedAt = Date()
        await save(updated)
    }

    func archive(_ note: LifeBoardKnowledgeNoteValue) async {
        var updated = note
        updated.state = .archived
        updated.updatedAt = Date()
        undoNotes = [note]
        undoMessage = "Archived “\(note.displayTitle)”"
        await save(updated)
    }

    func duplicate(_ note: LifeBoardKnowledgeNoteValue) async {
        let newID = UUID()
        var copy = note
        copy.id = newID
        copy.title = "\(note.displayTitle) Copy"
        copy.isPinned = false
        copy.createdAt = Date()
        copy.updatedAt = Date()
        copy.blocks = note.blocks.enumerated().map { index, block in
            var value = block
            value.id = UUID()
            value.noteID = newID
            value.ordinal = index
            value.createdAt = Date()
            value.updatedAt = Date()
            return value
        }
        await save(copy)
    }

    func undoLastMutation() async {
        guard !undoNotes.isEmpty else { return }
        let values = undoNotes
        undoNotes = []
        undoMessage = nil
        do {
            for note in values {
                try await repository.saveKnowledgeNote(note)
                await index(note)
            }
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func performBatch(_ operation: BatchOperation, noteIDs: Set<UUID>) async {
        let originals = notes.filter { noteIDs.contains($0.id) }
        guard !originals.isEmpty else { return }
        do {
            undoNotes = originals
            for original in originals {
                var updated = original
                updated.updatedAt = Date()
                switch operation {
                case .favorite: updated.isFavorite = true
                case .pin: updated.isPinned = true
                case .archive: updated.state = .archived
                case .trash:
                    updated.state = .trashed
                    updated.deletedAt = Date()
                case .restore:
                    updated.state = .active
                    updated.deletedAt = nil
                }
                try await repository.saveKnowledgeNote(updated)
                try await reconcileBlockLinks(for: updated)
                await index(updated)
            }
            undoMessage = switch operation {
            case .favorite: "Added \(originals.count) notes to Favorites"
            case .pin: "Pinned \(originals.count) notes"
            case .archive: "Archived \(originals.count) notes"
            case .trash: "Moved \(originals.count) notes to Trash"
            case .restore: "Restored \(originals.count) notes"
            }
            await load()
        } catch {
            undoNotes = []
            errorMessage = error.localizedDescription
        }
    }

    func reorderPinned(noteID: UUID, before destinationID: UUID) async {
        guard noteID != destinationID else { return }
        var ordered = pinnedNotes
        guard let source = ordered.firstIndex(where: { $0.id == noteID }),
              let destination = ordered.firstIndex(where: { $0.id == destinationID }) else { return }
        let originals = ordered
        let moved = ordered.remove(at: source)
        ordered.insert(moved, at: destination)
        do {
            undoNotes = originals
            for index in ordered.indices {
                ordered[index].manualSortOrder = Double(index)
                try await repository.saveKnowledgeNote(ordered[index])
            }
            undoMessage = "Reordered pinned notes"
            await load()
        } catch {
            undoNotes = []
            errorMessage = error.localizedDescription
        }
    }

    func deletePermanently(_ note: LifeBoardKnowledgeNoteValue) async {
        do {
            let attachments = try await repository.fetchKnowledgeAttachments(noteID: note.id)
            let securePayload = try await repository.fetchKnowledgeSecurePayload(noteID: note.id)?.0
            try await repository.deleteKnowledgeNote(id: note.id)
            try? await searchIndex?.remove(noteID: note.id)
            for attachment in attachments {
                try? await attachmentFiles.deleteFile(for: attachment)
            }
            if let securePayload {
                try? await secureNotes?.deleteKey(identifier: securePayload.keyIdentifier)
            }
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func saveTag(name: String) async -> LifeBoardKnowledgeTagValue? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let existing = tags.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) { return existing }
        let tag = LifeBoardKnowledgeTagValue(name: trimmed)
        do {
            try await repository.saveKnowledgeTag(tag)
            await load()
            return tag
        } catch { errorMessage = error.localizedDescription; return nil }
    }

    func saveSmartCollection(name: String, query: KnowledgeNoteQuery) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            try await repository.saveKnowledgeSmartCollection(
                .init(spaceID: selectedSpaceID, name: trimmed, query: query)
            )
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func connect(source: UUID, destination: UUID) async {
        guard source != destination,
              !links.contains(where: { $0.sourceNoteID == source && $0.destinationNoteID == destination }) else { return }
        do {
            try await repository.saveKnowledgeLink(.init(sourceNoteID: source, destinationNoteID: destination))
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func disconnect(_ link: LifeBoardKnowledgeLinkValue) async {
        do {
            try await repository.deleteKnowledgeLink(id: link.id)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func restore(_ destination: NotesLibraryDestination) {
        switch destination {
        case .library(let query):
            selectedCollection = query.collection
            selectedFolderID = query.folderID
            selectedTagIDs = query.tagIDs
            searchText = query.searchText
            sort = query.sort
        case .collection(let collection):
            selectedCollection = collection
            selectedFolderID = nil
            selectedTagIDs = []
        case .folder(let folderID):
            selectedCollection = .all
            selectedFolderID = folderID
            selectedTagIDs = []
        case .tag(let tagID):
            selectedCollection = .all
            selectedFolderID = nil
            selectedTagIDs = [tagID]
        case .search(let terms):
            selectedCollection = .all
            selectedFolderID = nil
            selectedTagIDs = []
            searchText = terms
        }
    }

    func addAttachment(noteID: UUID, url: URL) async -> LifeBoardKnowledgeAttachmentValue? {
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "LifeBoard couldn’t access that file. Choose it again to retry."
            return nil
        }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 20_000_000 else {
                errorMessage = "Files larger than 20 MB are not supported."
                return nil
            }
            return await addAttachment(
                noteID: noteID,
                data: data,
                fileName: url.lastPathComponent,
                contentType: UTType(filenameExtension: url.pathExtension)?.preferredMIMEType,
                sourceKind: "file"
            )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func addAttachment(
        noteID: UUID,
        data: Data,
        fileName: String,
        contentType: String?,
        sourceKind: String
    ) async -> LifeBoardKnowledgeAttachmentValue? {
        guard data.count <= 20_000_000 else {
            errorMessage = "Attachments larger than 20 MB are not supported."
            return nil
        }
        do {
            return try await LocalKnowledgeAttachmentPipeline(repository: repository, files: attachmentFiles)
                .ingest(
                    data: data,
                    fileName: fileName,
                    contentType: contentType,
                    sourceKind: sourceKind,
                    noteID: noteID
                )
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func lock(_ note: LifeBoardKnowledgeNoteValue) async {
        guard let secureNotes else {
            errorMessage = "Locked notes are not enabled in this build."
            return
        }
        do {
            let attachments = try await repository.fetchKnowledgeAttachments(noteID: note.id)
            let encryptedLinks = links.filter {
                $0.sourceNoteID == note.id || $0.destinationNoteID == note.id
            }
            let envelope = try await secureNotes.lock(
                note: note,
                attachments: attachments,
                links: encryptedLinks,
                reason: "Lock “\(note.displayTitle)”"
            )
            var redacted = note
            redacted.title = ""
            redacted.blocks = []
            redacted.tagIDs = []
            redacted.lockPolicy = .deviceAuthentication
            redacted.updatedAt = Date()
            let payload = KnowledgeSecurePayloadValue(
                noteID: note.id,
                ciphertext: envelope.ciphertext,
                contentVersion: envelope.contentVersion,
                algorithmVersion: envelope.algorithmVersion,
                keyIdentifier: envelope.keyIdentifier
            )
            let secureAttachments = attachments.compactMap { attachment -> KnowledgeSecureAttachmentPayloadValue? in
                guard let ciphertext = envelope.attachmentCiphertexts[attachment.id] else { return nil }
                return .init(
                    noteID: note.id,
                    attachmentID: attachment.id,
                    ciphertext: ciphertext,
                    checksum: attachment.checksum,
                    byteCount: attachment.byteCount ?? Int64(attachment.payload.count)
                )
            }
            try await repository.lockKnowledgeNote(
                redacted: redacted,
                payload: payload,
                attachments: secureAttachments
            )
            try? await searchIndex?.remove(noteID: note.id)
            await load()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unlock(_ note: LifeBoardKnowledgeNoteValue) async throws -> KnowledgeUnlockedNoteSession {
        guard let secureNotes,
              let (payload, attachments) = try await repository.fetchKnowledgeSecurePayload(noteID: note.id) else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        let envelope = KnowledgeSecureEnvelope(
            noteID: note.id,
            keyIdentifier: payload.keyIdentifier,
            algorithmVersion: payload.algorithmVersion,
            contentVersion: payload.contentVersion,
            ciphertext: payload.ciphertext,
            attachmentCiphertexts: Dictionary(uniqueKeysWithValues: attachments.map { ($0.attachmentID, $0.ciphertext) })
        )
        let unlocked = try await secureNotes.unlock(envelope, reason: "Unlock this note")
        return .init(
            note: unlocked.0,
            attachments: unlocked.1,
            links: unlocked.2,
            keyIdentifier: payload.keyIdentifier
        )
    }

    func saveLocked(_ session: KnowledgeUnlockedNoteSession) async throws {
        guard let secureNotes else { throw CocoaError(.featureUnsupported) }
        var note = session.note
        note.lockPolicy = .deviceAuthentication
        note.updatedAt = Date()
        note.contentVersion = max(1, note.contentVersion ?? 1) + 1
        let envelope = try await secureNotes.reseal(
            note: note,
            attachments: session.attachments,
            links: session.links,
            keyIdentifier: session.keyIdentifier
        )
        var redacted = note
        redacted.title = ""
        redacted.blocks = []
        redacted.tagIDs = []
        let payload = KnowledgeSecurePayloadValue(
            noteID: note.id,
            ciphertext: envelope.ciphertext,
            contentVersion: envelope.contentVersion,
            algorithmVersion: envelope.algorithmVersion,
            keyIdentifier: envelope.keyIdentifier
        )
        let secureAttachments = session.attachments.compactMap { attachment -> KnowledgeSecureAttachmentPayloadValue? in
            guard let ciphertext = envelope.attachmentCiphertexts[attachment.id] else { return nil }
            return .init(
                noteID: note.id,
                attachmentID: attachment.id,
                ciphertext: ciphertext,
                checksum: attachment.checksum,
                byteCount: attachment.byteCount ?? Int64(attachment.payload.count)
            )
        }
        try await repository.lockKnowledgeNote(redacted: redacted, payload: payload, attachments: secureAttachments)
    }

    func search() {
        searchTask?.cancel()
        let terms = searchText
        guard let searchIndex else {
            rankedSearchIDs = []
            return
        }
        guard !terms.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            rankedSearchIDs = []
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            do {
                let results = try await searchIndex.search(terms, limit: 1_000)
                guard !Task.isCancelled else { return }
                rankedSearchIDs = results.map(\.noteID)
                searchIndexStatus = await searchIndex.status()
            } catch {
                errorMessage = "Search is rebuilding. Your notes are still available."
                rankedSearchIDs = KnowledgeNoteQuery(searchText: terms).apply(to: notes).map(\.id)
            }
            isSearching = false
        }
    }

    private func rebuildSearchIndex() async {
        guard let searchIndex else { return }
        let tagNames = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
        let documents = notes.map { note in
            KnowledgeSearchDocument(
                noteID: note.id,
                title: note.title,
                body: note.plainText,
                tags: note.tagIDs.compactMap { tagNames[$0] }.joined(separator: " "),
                attachments: note.blocks.compactMap(\.searchableMetadata).joined(separator: " "),
                updatedAt: note.updatedAt,
                isLocked: note.resolvedLockPolicy != .unlocked || note.resolvedState == .trashed
            )
        }
        do {
            try await searchIndex.rebuild(documents)
            searchIndexStatus = await searchIndex.status()
            if !searchText.isEmpty { search() }
        } catch {
            searchIndexStatus = .failed(error.localizedDescription)
        }
    }

    private func index(_ note: LifeBoardKnowledgeNoteValue) async {
        guard let searchIndex else { return }
        if note.resolvedLockPolicy != .unlocked || note.resolvedState == .trashed {
            try? await searchIndex.remove(noteID: note.id)
            return
        }
        let tagNames = Dictionary(uniqueKeysWithValues: tags.map { ($0.id, $0.name) })
        let attachments = (try? await repository.fetchKnowledgeAttachments(noteID: note.id)) ?? []
        let metadata = (
            note.blocks.compactMap(\.searchableMetadata)
                + attachments.flatMap { [$0.fileName, $0.ocrText, $0.transcript].compactMap { $0 } }
        ).joined(separator: " ")
        try? await searchIndex.upsert(
            .init(
                noteID: note.id,
                title: note.title,
                body: note.plainText,
                tags: note.tagIDs.compactMap { tagNames[$0] }.joined(separator: " "),
                attachments: metadata,
                updatedAt: note.updatedAt,
                isLocked: false
            )
        )
        if !searchText.isEmpty { search() }
    }
}

struct LifeBoardKnowledgeModuleView: View {
    @State private var store: LifeBoardKnowledgeStore
    @State private var editingNote: LifeBoardKnowledgeNoteValue?
    @State private var confirmsDelete: LifeBoardKnowledgeNoteValue?
    @State private var showsNewSpace = false
    @State private var showsNewFolder = false
    @State private var showsTemplates = false
    @State private var showsSmartCollectionBuilder = false
    @State private var draftName = ""
    @State private var hasOpenedInitialNote = false
    @State private var isSelecting = false
    @State private var selectedNoteIDs: Set<UUID> = []
    @State private var pinnedDropTargetID: UUID?
    @Namespace private var noteTransition
    @Environment(LifeBoardPresentationPreferences.self) private var preferences
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let initialNoteID: UUID?
    private let initialDestination: NotesLibraryDestination?
    private let startsWithNewNote: Bool
    private let captureDraftID: UUID?
    private let initialText: String?

    init(
        repository: any LifeBoardPhaseIIRepository,
        initialFolderID: UUID? = nil,
        initialNoteID: UUID? = nil,
        initialDestination: NotesLibraryDestination? = nil,
        startsWithNewNote: Bool = false,
        captureDraftID: UUID? = nil,
        initialText: String? = nil
    ) {
        _store = State(initialValue: LifeBoardKnowledgeStore(
            repository: repository,
            initialFolderID: initialFolderID
        ))
        self.initialNoteID = initialNoteID
        self.initialDestination = initialDestination
        self.startsWithNewNote = startsWithNewNote
        self.captureDraftID = captureDraftID
        self.initialText = initialText
    }

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    notesSidebar
                        .navigationTitle("Notes")
                } detail: {
                    notesWorkspace
                }
            } else {
                notesWorkspace
            }
        }
        .task {
            await store.load()
            if let initialDestination {
                store.restore(initialDestination)
            }
            openInitialNoteIfNeeded()
        }
        .onChange(of: store.selectedSpaceID) { _, _ in Task { await store.load() } }
        .sheet(item: $editingNote) { note in
            noteEditor(note)
                .navigationTransition(.zoom(sourceID: note.id, in: noteTransition))
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showsTemplates) {
            templatePicker
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsSmartCollectionBuilder) {
            LifeBoardSmartCollectionBuilder(
                spaceID: store.selectedSpaceID,
                folders: store.folders,
                tags: store.tags,
                onSave: { name, query in
                    await store.saveSmartCollection(name: name, query: query)
                    showsSmartCollectionBuilder = false
                },
                onCancel: { showsSmartCollectionBuilder = false }
            )
        }
        .alert("New Space", isPresented: $showsNewSpace, actions: newSpaceActions)
        .alert("New Folder", isPresented: $showsNewFolder, actions: newFolderActions)
        .alert(
            store.selectedCollection == .trash ? "Delete permanently?" : "Move to Trash?",
            isPresented: Binding(
                get: { confirmsDelete != nil },
                set: { if !$0 { confirmsDelete = nil } }
            )
        ) {
            Button(store.selectedCollection == .trash ? "Delete Permanently" : "Move to Trash", role: .destructive) {
                guard let note = confirmsDelete else { return }
                Task {
                    if store.selectedCollection == .trash {
                        await store.deletePermanently(note)
                    } else {
                        await store.moveToTrash(note)
                    }
                }
                confirmsDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmsDelete = nil }
        } message: {
            Text(store.selectedCollection == .trash
                 ? "This cannot be undone."
                 : "The note stays in Trash for 30 days and can be restored.")
        }
        .alert("Notes are unavailable", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(store.errorMessage ?? "") }
        .safeAreaInset(edge: .bottom) {
            if isSelecting {
                batchActionBar
            } else if let message = store.undoMessage {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .lineLimit(1)
                    Spacer()
                    Button("Undo") { Task { await store.undoLastMutation() } }
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 16)
                .frame(minHeight: 52)
                .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(LifeBoardAnimation.selection, value: store.undoMessage)
    }

    private var notesWorkspace: some View {
        let palette = LifeBoardDaypartTokens.palette(for: preferences.resolvedDaypart())
        return VStack(spacing: 0) {
            notesHeader(palette: palette)
            if store.selectedCollection == .connections {
                LifeBoardKnowledgeGraphView(
                    notes: Array(store.notes.filter { $0.resolvedState == .active }.prefix(150)),
                    links: store.links,
                    folders: store.folders,
                    tags: store.tags
                ) { editingNote = $0 }
            } else {
                library(palette: palette)
            }
        }
        .background(Color.clear)
        .accessibilityIdentifier("notes.workspace")
    }

    private func notesHeader(palette: LifeBoardDaypartPalette) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(collectionTitle)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .foregroundStyle(palette.color(for: .foreground))
                    Text(collectionSubtitle)
                        .font(.subheadline)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
                Spacer()
                Menu {
                    Button("New note", systemImage: "square.and.pencil") {
                        editingNote = store.createNote(folderID: store.selectedFolderID)
                    }
                    Button("Start with a template", systemImage: "rectangle.stack.badge.plus") {
                        showsTemplates = true
                    }
                    Button("New folder", systemImage: "folder.badge.plus") {
                        draftName = ""
                        showsNewFolder = true
                    }
                    Button("New smart collection", systemImage: "sparkle.magnifyingglass") {
                        showsSmartCollectionBuilder = true
                    }
                    Divider()
                    Button("New space", systemImage: "square.grid.2x2") {
                        draftName = ""
                        showsNewSpace = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: 46, height: 46)
                }
                .lifeBoardSystemGlass(.regular, in: Circle(), interactive: true)
                .accessibilityLabel("Create a note or folder")
                .accessibilityIdentifier("notes.create")
                if !store.visibleNotes.isEmpty {
                    Button(isSelecting ? "Done" : "Select") {
                        withAnimation(LifeBoardAnimation.selection) {
                            isSelecting.toggle()
                            if !isSelecting { selectedNoteIDs.removeAll() }
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("notes.select")
                }
            }

            HStack(spacing: 10) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    TextField("Search titles, text, tags, and attachments", text: $store.searchText)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .accessibilityIdentifier("notes.search")
                        .onChange(of: store.searchText) { _, _ in store.search() }
                    if !store.searchText.isEmpty {
                        Button {
                            store.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
                .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)

                Menu {
                    Picker("Sort notes", selection: $store.sort) {
                        Label("Last edited", systemImage: "clock").tag(KnowledgeNoteSort.updatedDescending)
                        Label("Date created", systemImage: "calendar").tag(KnowledgeNoteSort.createdDescending)
                        Label("Title", systemImage: "textformat").tag(KnowledgeNoteSort.titleAscending)
                    }
                    Divider()
                    Picker("Layout", selection: $store.layout) {
                        Label("List", systemImage: "list.bullet").tag(LifeBoardKnowledgeStore.Layout.list)
                        Label("Grid", systemImage: "square.grid.2x2").tag(LifeBoardKnowledgeStore.Layout.grid)
                    }
                } label: {
                    Image(systemName: store.layout == .list ? "line.3.horizontal.decrease" : "square.grid.2x2")
                        .frame(width: 46, height: 46)
                }
                .lifeBoardSystemGlass(.regular, in: Circle(), interactive: true)
                .accessibilityLabel("Sort and view options")
            }

            if horizontalSizeClass != .regular {
                collectionRail
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var collectionRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(primaryCollections) { collection in
                    Button {
                        withAnimation(LifeBoardAnimation.selection) {
                            store.selectedCollection = collection
                            store.selectedFolderID = nil
                            store.selectedTagIDs = []
                        }
                    } label: {
                        // Depth carries selection, not a 9%-opacity grey wash:
                        // the old treatment was invisible in greyscale and
                        // belonged to no palette in this app.
                        Label(collection.label, systemImage: collection.symbol)
                            .font(.lifeboard(store.selectedCollection == collection ? .bodyStrong : .body))
                            .foregroundStyle(Color(store.selectedCollection == collection
                                ? LifeBoardColorTokens.inkPrimary
                                : LifeBoardColorTokens.inkSecondary))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .lifeBoardClaySurface(
                                store.selectedCollection == collection ? .raised : .well,
                                cornerRadius: LifeBoardFoundationRadius.pill
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(store.selectedCollection == collection ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    private var notesSidebar: some View {
        List {
            Section("Library") {
                ForEach(primaryCollections) { collection in
                    sidebarButton(collection)
                }
            }
            Section("Organize") {
                sidebarButton(.connections)
                ForEach(store.smartCollections) { collection in
                    Button {
                        store.restore(.library(collection.query))
                    } label: {
                        Label(collection.name, systemImage: collection.symbol)
                    }
                }
            }
            if !store.folders.isEmpty {
                Section("Folders") {
                    Button {
                        store.selectedFolderID = nil
                        store.selectedTagIDs = []
                        store.selectedCollection = .all
                    } label: {
                        Label("All folders", systemImage: "folder")
                    }
                    ForEach(store.folders.filter { $0.parentFolderID == nil }) { folder in
                        Button {
                            store.selectedFolderID = folder.id
                            store.selectedTagIDs = []
                            store.selectedCollection = .all
                        } label: {
                            Label(folder.title, systemImage: "folder.fill")
                        }
                    }
                }
            }
            if !store.tags.isEmpty {
                Section("Tags") {
                    ForEach(store.tags.prefix(12)) { tag in
                        Button {
                            store.restore(.tag(tag.id))
                        } label: {
                            Label(tag.name, systemImage: "number")
                        }
                        .accessibilityAddTraits(
                            store.selectedTagIDs.contains(tag.id) ? .isSelected : []
                        )
                    }
                }
            }
            Section {
                sidebarButton(.archived)
                sidebarButton(.trash)
            }
        }
        .listStyle(.sidebar)
    }

    private func sidebarButton(_ collection: KnowledgeNoteCollection) -> some View {
        Button {
            store.selectedCollection = collection
            store.selectedFolderID = nil
            store.selectedTagIDs = []
        } label: {
            HStack {
                Label(collection.label, systemImage: collection.symbol)
                Spacer()
                if collection != .connections {
                    Text("\(count(for: collection))")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .accessibilityAddTraits(store.selectedCollection == collection ? .isSelected : [])
    }

    private func library(palette: LifeBoardDaypartPalette) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                folderStrip(palette: palette)
                if !store.pinnedNotes.isEmpty, store.selectedCollection == .all {
                    pinnedSection(palette: palette)
                }
                notesSection(palette: palette)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 38)
        }
        .scrollDismissesKeyboard(.interactively)
        .refreshable { await store.load() }
    }

    @ViewBuilder
    private func folderStrip(palette: LifeBoardDaypartPalette) -> some View {
        let visibleFolders = store.folders.filter { $0.parentFolderID == store.selectedFolderID }
        if store.selectedFolderID != nil || !visibleFolders.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                if store.selectedFolderID != nil {
                    HStack(spacing: 7) {
                        Button {
                            store.navigateUp()
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .buttonStyle(.plain)
                        ForEach(store.selectedFolderPath) { folder in
                            Image(systemName: "chevron.right")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.tertiary)
                            Text(folder.title)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
                if !visibleFolders.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(visibleFolders) { folder in
                                Button {
                                    withAnimation(LifeBoardAnimation.selection) {
                                        store.selectedFolderID = folder.id
                                    }
                                } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: "folder.fill")
                                            .foregroundStyle(.tint)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(folder.title)
                                                .font(.subheadline.weight(.semibold))
                                            Text("\(store.notes.filter { $0.folderID == folder.id && $0.resolvedState == .active }.count) notes")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 58)
                                    .background(.background.opacity(0.7), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                                }
                                .buttonStyle(.plain)
                                .contextMenu { folderMoveMenu(folder) }
                            }
                        }
                    }
                }
            }
        }
    }

    private func pinnedSection(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading("Pinned", symbol: "pin.fill", count: store.pinnedNotes.count)
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 12) {
                    ForEach(store.pinnedNotes) { note in
                        noteCard(note, palette: palette, compact: true)
                            .frame(width: 236)
                            .rotationEffect(.degrees(pinnedDropTargetID == note.id ? 3 : 0))
                            .scaleEffect(pinnedDropTargetID == note.id ? 1.025 : 1)
                            .draggable(note.id.uuidString)
                            .dropDestination(for: String.self) { values, _ in
                                guard let raw = values.first, let sourceID = UUID(uuidString: raw) else { return false }
                                Task { await store.reorderPinned(noteID: sourceID, before: note.id) }
                                return true
                            } isTargeted: { targeted in
                                withAnimation(LifeBoardAnimation.cardReflow) {
                                    pinnedDropTargetID = targeted ? note.id : nil
                                }
                            }
                    }
                }
            }
        }
    }

    private func notesSection(palette: LifeBoardDaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 11) {
            sectionHeading(
                store.selectedCollection == .all ? (store.selectedFolderID == nil ? "Recently edited" : "In this folder") : collectionTitle,
                symbol: store.selectedCollection.symbol,
                count: store.visibleNotes.count
            )
            if store.visibleNotes.isEmpty {
                notesEmptyState
            } else if store.layout == .grid {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                    ForEach(store.visibleNotes) { note in
                        noteCard(note, palette: palette, compact: false)
                    }
                }
            } else {
                LazyVStack(spacing: 9) {
                    ForEach(store.visibleNotes) { note in
                        noteRow(note, palette: palette)
                    }
                }
            }
        }
    }

    private func sectionHeading(_ title: String, symbol: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.caption.weight(.bold))
                .foregroundStyle(.tint)
            Text(title)
                .font(.headline)
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    private func noteCard(
        _ note: LifeBoardKnowledgeNoteValue,
        palette: LifeBoardDaypartPalette,
        compact: Bool
    ) -> some View {
        Button { openOrSelect(note) } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    if note.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundStyle(.tint)
                    }
                    Spacer()
                    if note.isFavorite {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
                Text(note.displayTitle)
                    .font(.system(.headline, design: .rounded, weight: .semibold))
                    .foregroundStyle(palette.color(for: .foreground))
                    .lineLimit(2)
                Text(note.plainText.isEmpty ? "A quiet page, ready when you are." : note.plainText)
                    .font(.subheadline)
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                    .lineLimit(compact ? 3 : 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 2)
                HStack {
                    Text(note.updatedAt.formatted(.relative(presentation: .named)))
                    Spacer()
                    noteKindMarks(note)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 154 : 176, alignment: .topLeading)
            .padding(16)
            .lifeBoardPaperCard()
            .overlay(alignment: .topTrailing) {
                if isSelecting {
                    selectionMark(for: note)
                        .padding(12)
                }
            }
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: note.id, in: noteTransition)
        .contextMenu { noteActions(note) }
        .accessibilityIdentifier("notes.note.\(note.id.uuidString)")
        .accessibilityLabel("\(note.displayTitle), edited \(note.updatedAt.formatted(.relative(presentation: .named)))")
    }

    private func noteRow(
        _ note: LifeBoardKnowledgeNoteValue,
        palette: LifeBoardDaypartPalette
    ) -> some View {
        Button { openOrSelect(note) } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.accentColor.opacity(0.10))
                    .frame(width: 46, height: 54)
                    .overlay {
                        Image(systemName: note.blocks.contains(where: { $0.kind == .checklist }) ? "checklist" : "note.text")
                            .foregroundStyle(.tint)
                    }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        if note.isPinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.tint) }
                        Text(note.displayTitle)
                            .font(.headline)
                            .foregroundStyle(palette.color(for: .foreground))
                            .lineLimit(1)
                        if note.isFavorite { Image(systemName: "star.fill").font(.caption2).foregroundStyle(.orange) }
                    }
                    Text(note.plainText.isEmpty ? "A quiet page, ready when you are." : note.plainText)
                        .font(.subheadline)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(note.updatedAt.formatted(.relative(presentation: .named)))
                        if !note.tagIDs.isEmpty { Text("•  \(note.tagIDs.count) tags") }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 82)
            .background(
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemBackground).opacity(0.84))
            )
            .overlay(alignment: .trailing) {
                if isSelecting {
                    selectionMark(for: note)
                        .padding(.trailing, 14)
                }
            }
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: note.id, in: noteTransition)
        .contextMenu { noteActions(note) }
        .accessibilityIdentifier("notes.note.\(note.id.uuidString)")
        .accessibilityLabel("\(note.displayTitle), edited \(note.updatedAt.formatted(.relative(presentation: .named)))")
    }

    private func openOrSelect(_ note: LifeBoardKnowledgeNoteValue) {
        if isSelecting {
            if !selectedNoteIDs.insert(note.id).inserted {
                selectedNoteIDs.remove(note.id)
            }
        } else {
            editingNote = note
        }
    }

    private func selectionMark(for note: LifeBoardKnowledgeNoteValue) -> some View {
        Image(systemName: selectedNoteIDs.contains(note.id) ? "checkmark.circle.fill" : "circle")
            .font(.title3.weight(.semibold))
            .foregroundStyle(selectedNoteIDs.contains(note.id) ? Color.accentColor : Color.secondary)
            .symbolEffect(.bounce, value: selectedNoteIDs.contains(note.id))
            .accessibilityLabel(selectedNoteIDs.contains(note.id) ? "Selected" : "Not selected")
    }

    private var batchActionBar: some View {
        HStack(spacing: 4) {
            Text("\(selectedNoteIDs.count) selected")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .padding(.leading, 10)
            Spacer()
            batchButton("Favorite", symbol: "star") { .favorite }
            batchButton("Pin", symbol: "pin") { .pin }
            if store.selectedCollection == .trash {
                batchButton("Restore", symbol: "arrow.uturn.backward") { .restore }
            } else {
                batchButton("Archive", symbol: "archivebox") { .archive }
                batchButton("Trash", symbol: "trash", role: .destructive) { .trash }
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: 660, minHeight: 54)
        .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    private func batchButton(
        _ label: String,
        symbol: String,
        role: ButtonRole? = nil,
        operation: @escaping () -> LifeBoardKnowledgeStore.BatchOperation
    ) -> some View {
        Button(role: role) {
            let ids = selectedNoteIDs
            Task {
                await store.performBatch(operation(), noteIDs: ids)
                selectedNoteIDs.removeAll()
                isSelecting = false
            }
        } label: {
            Image(systemName: symbol)
                .frame(width: 42, height: 42)
        }
        .disabled(selectedNoteIDs.isEmpty)
        .accessibilityLabel(label)
    }

    @ViewBuilder
    private func noteKindMarks(_ note: LifeBoardKnowledgeNoteValue) -> some View {
        HStack(spacing: 6) {
            if note.blocks.contains(where: { $0.kind == .checklist }) {
                Image(systemName: "checklist")
            }
            if note.blocks.contains(where: { $0.kind == .image || $0.kind == .file }) {
                Image(systemName: "paperclip")
            }
            if store.links.contains(where: { $0.sourceNoteID == note.id || $0.destinationNoteID == note.id }) {
                Image(systemName: "link")
            }
        }
    }

    private var notesEmptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: store.selectedCollection == .trash ? "trash" : "note.text.badge.plus")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.tint)
            Text(emptyTitle)
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text(emptyMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 330)
            if store.selectedCollection != .trash && store.selectedCollection != .archived {
                Button("Create a note") { showsTemplates = true }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 54)
    }

    private var templatePicker: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(KnowledgeNoteTemplate.library) { template in
                        Button {
                            editingNote = store.createNote(
                                folderID: store.selectedFolderID,
                                template: template
                            )
                            showsTemplates = false
                        } label: {
                            VStack(alignment: .leading, spacing: 12) {
                                Image(systemName: template.symbol)
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                                    .frame(width: 42, height: 42)
                                    .background(Color.accentColor.opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
                                Text(template.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(template.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, minHeight: 146, alignment: .topLeading)
                            .padding(15)
                            .lifeBoardPaperCard()
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("notes.template.\(template.id)")
                    }
                }
                .padding(20)
            }
            .navigationTitle("Begin with a shape")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showsTemplates = false }
                }
            }
        }
    }

    @ViewBuilder
    private func noteEditor(_ note: LifeBoardKnowledgeNoteValue) -> some View {
        if note.resolvedLockPolicy == .deviceAuthentication {
            LifeBoardLockedKnowledgeNoteEditor(
                placeholder: note,
                onUnlock: { try await store.unlock(note) },
                onSave: { try await store.saveLocked($0) }
            )
        } else {
            LifeBoardKnowledgeNoteEditor(
                note: note,
                allNotes: store.notes,
                tags: store.tags,
                links: store.links,
                repository: store.repository,
                attachmentFiles: store.attachmentFiles,
                onSave: { value in await store.save(value) },
                onCreateTag: { name in await store.saveTag(name: name) },
                onConnect: { destination in
                    Task { await store.connect(source: note.id, destination: destination) }
                },
                onDisconnect: { link in Task { await store.disconnect(link) } },
                onAttach: { url in await store.addAttachment(noteID: note.id, url: url) },
                onAttachData: { data, fileName, contentType, sourceKind in
                    await store.addAttachment(
                        noteID: note.id,
                        data: data,
                        fileName: fileName,
                        contentType: contentType,
                        sourceKind: sourceKind
                    )
                }
            )
        }
    }

    @ViewBuilder
    private func noteActions(_ note: LifeBoardKnowledgeNoteValue) -> some View {
        if store.selectedCollection == .trash {
            Button("Restore", systemImage: "arrow.uturn.backward") { Task { await store.restore(note) } }
            Button("Delete permanently", systemImage: "trash.slash", role: .destructive) { confirmsDelete = note }
        } else {
            Button(note.isPinned ? "Unpin" : "Pin", systemImage: note.isPinned ? "pin.slash" : "pin") {
                var updated = note
                updated.isPinned.toggle()
                updated.updatedAt = Date()
                Task { await store.save(updated) }
            }
            Button(note.isFavorite ? "Remove favorite" : "Favorite", systemImage: note.isFavorite ? "star.slash" : "star") {
                var updated = note
                updated.isFavorite.toggle()
                updated.updatedAt = Date()
                Task { await store.save(updated) }
            }
            if note.resolvedLockPolicy == .unlocked, V2FeatureFlags.knowledgeNotesSecurityV1Enabled {
                Button("Lock note", systemImage: "lock") { Task { await store.lock(note) } }
            }
            Button("Duplicate", systemImage: "plus.square.on.square") { Task { await store.duplicate(note) } }
            noteMoveMenu(note)
            Button("Archive", systemImage: "archivebox") { Task { await store.archive(note) } }
            Button("Move to Trash", systemImage: "trash", role: .destructive) { confirmsDelete = note }
        }
    }

    @ViewBuilder private func newSpaceActions() -> some View {
        TextField("Name", text: $draftName)
        Button("Save") {
            let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { await store.createSpace(title: name) }
            draftName = ""
        }
        .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Button("Cancel", role: .cancel) { draftName = "" }
    }

    @ViewBuilder private func newFolderActions() -> some View {
        TextField("Name", text: $draftName)
        Button("Save") {
            let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { await store.createFolder(title: name, parentID: store.selectedFolderID) }
            draftName = ""
        }
        .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Button("Cancel", role: .cancel) { draftName = "" }
    }

    @ViewBuilder private func folderMoveMenu(_ folder: LifeBoardKnowledgeFolderValue) -> some View {
        Button("Move to top level", systemImage: "tray") { Task { await store.move(folder, to: nil) } }
            .disabled(folder.parentFolderID == nil)
        Menu("Move to folder", systemImage: "folder") {
            ForEach(store.folders.filter {
                $0.id != folder.id && KnowledgeFolderHierarchy.canMove(folderID: folder.id, to: $0.id, in: store.folders)
            }) { destination in
                Button(destination.title) { Task { await store.move(folder, to: destination.id) } }
                    .disabled(folder.parentFolderID == destination.id)
            }
        }
    }

    @ViewBuilder private func noteMoveMenu(_ note: LifeBoardKnowledgeNoteValue) -> some View {
        Menu("Move", systemImage: "folder") {
            Button("Unfiled", systemImage: "tray") { Task { await store.move(note, to: nil) } }
                .disabled(note.folderID == nil)
            ForEach(store.folders) { folder in
                Button(folder.title) { Task { await store.move(note, to: folder.id) } }
                    .disabled(note.folderID == folder.id)
            }
        }
    }

    private func openInitialNoteIfNeeded() {
        guard !hasOpenedInitialNote else { return }
        hasOpenedInitialNote = true
        if let initialNoteID {
            editingNote = store.notes.first(where: { $0.id == initialNoteID })
        } else if startsWithNewNote {
            editingNote = store.createNote(id: captureDraftID, initialText: initialText)
        }
    }

    private func count(for collection: KnowledgeNoteCollection) -> Int {
        KnowledgeNoteQuery(collection: collection, spaceID: store.selectedSpaceID)
            .apply(
                to: store.notes,
                linkedNoteIDs: Set(store.links.flatMap { [$0.sourceNoteID, $0.destinationNoteID] })
            )
            .count
    }

    private var primaryCollections: [KnowledgeNoteCollection] {
        [.all, .pinned, .favorites, .recent, .unfiled, .checklists, .attachments, .linked]
    }

    private var collectionTitle: String {
        if let tagID = store.selectedTagIDs.first,
           let tag = store.tags.first(where: { $0.id == tagID }) {
            return "#\(tag.name)"
        }
        if let folderID = store.selectedFolderID,
           let folder = store.folders.first(where: { $0.id == folderID }) {
            return folder.title
        }
        return store.selectedCollection.label
    }

    private var collectionSubtitle: String {
        if !store.searchText.isEmpty { return "\(store.visibleNotes.count) matching notes" }
        return switch store.selectedCollection {
        case .all: "Ideas, references, and things worth keeping"
        case .pinned: "The notes you want close"
        case .favorites: "Notes that matter a little more"
        case .recent: "Your last two weeks of thinking"
        case .unfiled: "Loose notes, ready to find a home"
        case .checklists: "Plans with something to complete"
        case .attachments: "Notes carrying files, scans, and images"
        case .linked: "Thoughts connected to other thoughts"
        case .archived: "Quietly kept out of the way"
        case .trash: "Recoverable for 30 days"
        case .connections: "A map of how your notes relate"
        }
    }

    private var emptyTitle: String {
        return switch store.selectedCollection {
        case .trash: "Trash is empty"
        case .archived: "Nothing archived"
        default: store.searchText.isEmpty ? "A fresh page awaits" : "No notes found"
        }
    }

    private var emptyMessage: String {
        if !store.searchText.isEmpty { return "Try another phrase, folder, or collection." }
        if store.selectedCollection == .trash { return "Notes moved here remain recoverable for 30 days." }
        return "Capture an idea in a few words. You can shape it as you go."
    }
}

private extension KnowledgeNoteCollection {
    var label: String {
        switch self {
        case .all: "All Notes"
        case .pinned: "Pinned"
        case .favorites: "Favorites"
        case .recent: "Recent"
        case .unfiled: "Unfiled"
        case .checklists: "Checklists"
        case .attachments: "Attachments"
        case .linked: "Linked"
        case .archived: "Archive"
        case .trash: "Trash"
        case .connections: "Connections"
        }
    }

    var symbol: String {
        switch self {
        case .all: "note.text"
        case .pinned: "pin"
        case .favorites: "star"
        case .recent: "clock"
        case .unfiled: "tray"
        case .checklists: "checklist"
        case .attachments: "paperclip"
        case .linked: "link"
        case .archived: "archivebox"
        case .trash: "trash"
        case .connections: "point.3.connected.trianglepath.dotted"
        }
    }
}

private struct LifeBoardKnowledgeNoteEditor: View {
    private enum SaveState: Equatable {
        case idle
        case saving
        case saved(Date)
        case failed
    }

    @State private var draft: LifeBoardKnowledgeNoteValue
    @State private var originalSnapshot: Data?
    @State private var attachments: [LifeBoardKnowledgeAttachmentValue] = []
    @State private var newTag = ""
    @State private var showsTagComposer = false
    @State private var showsFileImporter = false
    @State private var showsLinkPicker = false
    @State private var showsHistory = false
    @State private var isLoadingAttachments = false
    @State private var previewAttachmentURL: URL?
    @State private var attachmentFailures: Set<UUID> = []
    @State private var saveState: SaveState = .idle
    @State private var autosaveTask: Task<Void, Never>?
    @State private var didWriteRevision = false
    @State private var revisions: [KnowledgeNoteRevisionValue] = []
    @State private var richSelection = NSRange(location: 0, length: 0)
    @State private var richEditorIsFocused = false
    @State private var richEditorCommand: KnowledgeEditorCommandInvocation?
    @State private var showsSlashCommands = false
    @State private var wikiLinkQuery: String?
    @State private var photoSelection: PhotosPickerItem?
    @State private var isImportingPhoto = false
    @State private var aiProposal: NoteAIProposal?
    @State private var aiIsPreparing = false
    @State private var aiErrorMessage: String?
    @FocusState private var titleIsFocused: Bool
    let allNotes: [LifeBoardKnowledgeNoteValue]
    let tags: [LifeBoardKnowledgeTagValue]
    let links: [LifeBoardKnowledgeLinkValue]
    let repository: any LifeBoardPhaseIIRepository
    let attachmentFiles: any KnowledgeAttachmentFileRepository
    let onSave: (LifeBoardKnowledgeNoteValue) async -> Void
    let onCreateTag: (String) async -> LifeBoardKnowledgeTagValue?
    let onConnect: (UUID) -> Void
    let onDisconnect: (LifeBoardKnowledgeLinkValue) -> Void
    let onAttach: (URL) async -> LifeBoardKnowledgeAttachmentValue?
    let onAttachData: (Data, String, String?, String) async -> LifeBoardKnowledgeAttachmentValue?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(
        note: LifeBoardKnowledgeNoteValue,
        allNotes: [LifeBoardKnowledgeNoteValue],
        tags: [LifeBoardKnowledgeTagValue],
        links: [LifeBoardKnowledgeLinkValue],
        repository: any LifeBoardPhaseIIRepository,
        attachmentFiles: any KnowledgeAttachmentFileRepository,
        onSave: @escaping (LifeBoardKnowledgeNoteValue) async -> Void,
        onCreateTag: @escaping (String) async -> LifeBoardKnowledgeTagValue?,
        onConnect: @escaping (UUID) -> Void,
        onDisconnect: @escaping (LifeBoardKnowledgeLinkValue) -> Void,
        onAttach: @escaping (URL) async -> LifeBoardKnowledgeAttachmentValue?,
        onAttachData: @escaping (Data, String, String?, String) async -> LifeBoardKnowledgeAttachmentValue?
    ) {
        _draft = State(initialValue: note)
        _originalSnapshot = State(initialValue: try? JSONEncoder().encode(note))
        self.allNotes = allNotes
        self.tags = tags
        self.links = links
        self.repository = repository
        self.attachmentFiles = attachmentFiles
        self.onSave = onSave
        self.onCreateTag = onCreateTag
        self.onConnect = onConnect
        self.onDisconnect = onDisconnect
        self.onAttach = onAttach
        self.onAttachData = onAttachData
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    TextField("Note title", text: $draft.title)
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .textFieldStyle(.plain)
                        .focused($titleIsFocused)
                        .accessibilityLabel("Note title")
                        .accessibilityIdentifier("notes.editor.title")
                    Text(noteDateLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    tagRail
                    if V2FeatureFlags.knowledgeNotesTextKitEditorV2Enabled {
                        LifeBoardUnifiedNoteEditor(
                            note: $draft,
                            selection: $richSelection,
                            isFocused: $richEditorIsFocused,
                            command: richEditorCommand,
                            onSlashCommand: {
                                showsSlashCommands = true
                            },
                            onWikiLink: { query in
                                wikiLinkQuery = query
                                showsLinkPicker = true
                            }
                        )
                        .frame(minHeight: 280)
                        .accessibilityIdentifier("notes.editor.textkit2")
                    } else {
                        ForEach($draft.blocks) { $block in
                            LifeBoardKnowledgeBlockEditor(
                                block: $block,
                                allNotes: allNotes.filter { $0.id != draft.id },
                                attachments: attachments,
                                onMoveUp: { moveBlock(block.id, offset: -1) },
                                onMoveDown: { moveBlock(block.id, offset: 1) },
                                onDelete: { deleteBlock(block) }
                            )
                        }
                    }
                    if !linksForDraft.isEmpty || !attachments.isEmpty {
                        Divider().padding(.vertical, 4)
                    }
                    if !linksForDraft.isEmpty { relationships }
                    if !attachments.isEmpty { attachmentsSection }
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.top, 26)
                .padding(.bottom, 110)
                .frame(maxWidth: .infinity)
            }
            .background {
                LifeBoardGrainedCanvas()
            }
            .accessibilityIdentifier("notes.editor")
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Task {
                            await flushAndClose()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Close note")
                }
                ToolbarItem(placement: .principal) {
                    saveStatus
                }
                ToolbarItemGroup(placement: .confirmationAction) {
                    Button {
                        draft.isPinned.toggle()
                    } label: {
                        Image(systemName: draft.isPinned ? "pin.fill" : "pin")
                    }
                    .accessibilityLabel(draft.isPinned ? "Unpin note" : "Pin note")
                    Button {
                        draft.isFavorite.toggle()
                    } label: {
                        Image(systemName: draft.isFavorite ? "star.fill" : "star")
                    }
                    .accessibilityLabel(draft.isFavorite ? "Remove favorite" : "Favorite note")
                    Menu {
                        Button("Link another note", systemImage: "link.badge.plus") { showsLinkPicker = true }
                        PhotosPicker(
                            selection: $photoSelection,
                            matching: .images,
                            preferredItemEncoding: .current
                        ) {
                            Label("Choose a photo", systemImage: "photo")
                        }
                        Button("Attach a file", systemImage: "paperclip") { showsFileImporter = true }
                        Button("Version history", systemImage: "clock.arrow.circlepath") { showsHistory = true }
                        if V2FeatureFlags.knowledgeNotesEVAV1Enabled {
                            Menu("Ask EVA", systemImage: "sparkles") {
                                ForEach(NoteAIAction.allCases, id: \.self) { action in
                                    Button(aiActionTitle(action), systemImage: aiActionSymbol(action)) {
                                        Task { await requestAIProposal(action) }
                                    }
                                }
                            }
                        }
                        ShareLink(item: markdownExport) {
                            Label("Share as Markdown", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button("Close", systemImage: "checkmark") { Task { await flushAndClose() } }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                editorCommandBar
            }
            .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.data, .image, .pdf, .plainText], allowsMultipleSelection: false) { result in
                if let url = try? result.get().first {
                    Task {
                        let textExtensions = Set(["txt", "md", "markdown"])
                        if textExtensions.contains(url.pathExtension.lowercased()) {
                            await importText(from: url)
                        } else {
                            if let attachment = await onAttach(url) {
                                addAttachmentBlock(attachment)
                            }
                            await loadAttachments()
                        }
                    }
                }
            }
            .quickLookPreview($previewAttachmentURL)
            .sheet(isPresented: $showsLinkPicker, onDismiss: { wikiLinkQuery = nil }) {
                NavigationStack {
                    List(linkPickerNotes) { note in
                        Button(note.title.isEmpty ? "Untitled" : note.title) {
                            if wikiLinkQuery != nil {
                                richEditorCommand = .init(command: .insertWikiLink(noteID: note.id, title: note.displayTitle))
                            }
                            onConnect(note.id)
                            wikiLinkQuery = nil
                            showsLinkPicker = false
                        }
                    }
                    .navigationTitle(wikiLinkQuery == nil ? "Link a Note" : "Mention a Note")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showsLinkPicker = false } } }
                }
            }
            .confirmationDialog("Insert a block", isPresented: $showsSlashCommands, titleVisibility: .visible) {
                ForEach(LifeBoardKnowledgeBlockKind.allCases, id: \.self) { kind in
                    Button(kindTitle(kind), systemImage: kindSymbol(kind)) {
                        richEditorCommand = .init(command: .block(kind))
                    }
                }
            }
            .sheet(isPresented: $showsHistory) {
                LifeBoardNoteHistoryView(
                    revisions: revisions,
                    onRestore: restoreRevision,
                    onDismiss: { showsHistory = false }
                )
            }
            .sheet(item: $aiProposal) { proposal in
                LifeBoardNoteAIProposalReview(
                    proposal: proposal,
                    currentContentVersion: draft.contentVersion ?? 1,
                    onApply: { editedPreview in
                        await applyAIProposal(proposal, editedPreview: editedPreview)
                    },
                    onDiscard: { aiProposal = nil }
                )
            }
            .overlay {
                if aiIsPreparing {
                    ZStack {
                        Color.black.opacity(0.08).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("EVA is preparing a private proposal…")
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(22)
                        .lifeBoardSystemGlass(.regular, in: RoundedRectangle(cornerRadius: 22), interactive: false)
                    }
                    .transition(.opacity)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("EVA is preparing a proposal")
                }
            }
            .alert("EVA couldn’t prepare that", isPresented: Binding(
                get: { aiErrorMessage != nil },
                set: { if !$0 { aiErrorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(aiErrorMessage ?? "")
            }
            .task {
                await restoreDraftIfNeeded()
                await loadAttachments()
                revisions = (try? await repository.fetchKnowledgeRevisions(noteID: draft.id)) ?? []
                if !draft.isMeaningful { titleIsFocused = true }
            }
            .onChange(of: photoSelection) { _, item in
                guard let item else { return }
                Task { await importPhoto(item) }
            }
            .onChange(of: draft) { _, _ in scheduleAutosave() }
            .onChange(of: scenePhase) { _, phase in
                guard phase != .active else { return }
                autosaveTask?.cancel()
                let value = preparedDraft()
                Task { await persist(value) }
            }
            .onDisappear {
                autosaveTask?.cancel()
                guard draft.isMeaningful else { return }
                let value = preparedDraft()
                Task {
                    await onSave(value)
                    try? await repository.deleteKnowledgeDraft(noteID: value.id)
                }
            }
        }
    }

    private var saveStatus: some View {
        HStack(spacing: 6) {
            switch saveState {
            case .idle:
                EmptyView()
            case .saving:
                ProgressView()
                    .controlSize(.mini)
                Text("Saving")
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .contentTransition(.symbolEffect(.replace))
                Text("Saved")
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Not saved")
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .accessibilityElement(children: .combine)
    }

    private var editorCommandBar: some View {
        GlassEffectContainer(spacing: 8) {
            if V2FeatureFlags.knowledgeNotesTextKitEditorV2Enabled, !richEditorIsFocused, !titleIsFocused {
                Button {
                    richEditorIsFocused = true
                } label: {
                    Label("Edit note", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 46)
                }
                .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)
                .padding(.vertical, 8)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else {
                HStack(spacing: 4) {
                Menu {
                    ForEach(LifeBoardKnowledgeBlockKind.allCases, id: \.self) { kind in
                        Button(kindTitle(kind), systemImage: kindSymbol(kind)) { addBlock(kind) }
                    }
                } label: {
                    Label("Insert", systemImage: "plus")
                }
                commandButton("Checklist", symbol: "checklist") { addBlock(.checklist) }
                if isImportingPhoto {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 42, height: 42)
                        .accessibilityLabel("Importing photo")
                } else {
                    PhotosPicker(
                        selection: $photoSelection,
                        matching: .images,
                        preferredItemEncoding: .current
                    ) {
                        Image(systemName: "photo").frame(width: 42, height: 42)
                    }
                    .accessibilityLabel("Choose a photo")
                }
                commandButton("Photo or file", symbol: "paperclip") { showsFileImporter = true }
                commandButton("Link note", symbol: "link") { showsLinkPicker = true }
                Spacer(minLength: 0)
                if V2FeatureFlags.knowledgeNotesTextKitEditorV2Enabled {
                    commandButton("Bold", symbol: "bold") { performEditorCommand(.bold) }
                    commandButton("Italic", symbol: "italic") { performEditorCommand(.italic) }
                    commandButton("Highlight", symbol: "highlighter") { performEditorCommand(.highlight) }
                }
                Menu {
                    Button("Paragraph", systemImage: "text.alignleft") { performEditorCommand(.block(.paragraph)) }
                    Button("Heading", systemImage: "textformat.size") { performEditorCommand(.block(.heading2)) }
                    Button("Quote", systemImage: "quote.opening") { performEditorCommand(.block(.quote)) }
                    Button("Code", systemImage: "chevron.left.forwardslash.chevron.right") { performEditorCommand(.block(.code)) }
                    Button("Indent", systemImage: "increase.indent") { performEditorCommand(.indent(1)) }
                    Button("Outdent", systemImage: "decrease.indent") { performEditorCommand(.indent(-1)) }
                    Divider()
                    Button("Underline", systemImage: "underline") { performEditorCommand(.underline) }
                    Button("Strike", systemImage: "strikethrough") { performEditorCommand(.strikethrough) }
                    Button("Inline code", systemImage: "chevron.left.forwardslash.chevron.right") { performEditorCommand(.inlineCode) }
                } label: {
                    Image(systemName: "textformat")
                        .frame(width: 42, height: 42)
                }
                .accessibilityLabel("Formatting and blocks")
            }
            .padding(.horizontal, 10)
            .frame(maxWidth: 680, minHeight: 54)
            .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            }
        }
        .animation(LifeBoardAnimation.selection, value: richEditorIsFocused)
    }

    private func commandButton(
        _ label: String,
        symbol: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .frame(width: 42, height: 42)
        }
        .accessibilityLabel(label)
    }

    private var linksForDraft: [LifeBoardKnowledgeLinkValue] {
        links.filter { $0.sourceNoteID == draft.id || $0.destinationNoteID == draft.id }
    }

    private var linkPickerNotes: [LifeBoardKnowledgeNoteValue] {
        let available = allNotes.filter { $0.id != draft.id && $0.resolvedState == .active }
        let query = wikiLinkQuery?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !query.isEmpty else { return available }
        return available.sorted {
            let lhs = $0.displayTitle.localizedCaseInsensitiveCompare(query) == .orderedSame ? 0
                : ($0.displayTitle.localizedCaseInsensitiveContains(query) ? 1 : 2)
            let rhs = $1.displayTitle.localizedCaseInsensitiveCompare(query) == .orderedSame ? 0
                : ($1.displayTitle.localizedCaseInsensitiveContains(query) ? 1 : 2)
            if lhs != rhs { return lhs < rhs }
            return $0.updatedAt > $1.updatedAt
        }
    }

    private var noteDateLine: String {
        let date = draft.updatedAt.formatted(date: .abbreviated, time: .shortened)
        let count = draft.plainText.split(whereSeparator: \.isWhitespace).count
        return count == 0 ? "Edited \(date)" : "\(count) words  •  Edited \(date)"
    }

    private var markdownExport: String {
        KnowledgeMarkdownCodec.render(draft)
    }

    private var originalWasMeaningful: Bool {
        guard let originalSnapshot,
              let note = try? JSONDecoder().decode(LifeBoardKnowledgeNoteValue.self, from: originalSnapshot) else {
            return false
        }
        return note.isMeaningful
    }

    @MainActor
    private func importPhoto(_ item: PhotosPickerItem) async {
        isImportingPhoto = true
        defer {
            isImportingPhoto = false
            photoSelection = nil
        }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                throw CocoaError(.fileReadCorruptFile)
            }
            guard let attachment = await onAttachData(
                data,
                "Photo-\(UUID().uuidString).jpg",
                "image/*",
                "photoLibrary"
            ) else { return }
            addAttachmentBlock(attachment)
            await loadAttachments()
        } catch {
            aiErrorMessage = "That photo couldn’t be imported. The note was not changed."
        }
    }

    @MainActor
    private func requestAIProposal(_ action: NoteAIAction) async {
        guard !aiIsPreparing else { return }
        aiIsPreparing = true
        defer { aiIsPreparing = false }
        do {
            aiProposal = try await FoundationModelsNoteAIProposalService().propose(
                action: action,
                note: draft,
                selectedText: selectedEditorText
            )
        } catch {
            aiErrorMessage = error.localizedDescription
        }
    }

    private var selectedEditorText: String? {
        guard richSelection.length > 0 else { return nil }
        let text = KnowledgeNoteDocument(note: draft).attributedString.string as NSString
        guard richSelection.location >= 0, NSMaxRange(richSelection) <= text.length else { return nil }
        let value = text.substring(with: richSelection).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    @MainActor
    private func applyAIProposal(_ proposal: NoteAIProposal, editedPreview: String) async {
        guard !proposal.isStale(for: draft) else {
            aiProposal = nil
            aiErrorMessage = "This note changed while the proposal was open. Ask EVA again to avoid overwriting newer work."
            return
        }
        let preview = editedPreview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !preview.isEmpty else {
            aiErrorMessage = "Keep at least one line in the proposal before applying it."
            return
        }
        if let snapshot = try? JSONEncoder().encode(draft) {
            try? await repository.saveKnowledgeRevision(
                .init(
                    noteID: draft.id,
                    snapshot: snapshot,
                    reason: "Before applying an EVA proposal",
                    baseContentVersion: draft.contentVersion,
                    contentVersion: draft.contentVersion,
                    changeKind: "eva"
                )
            )
        }

        switch proposal.action {
        case .summarize:
            draft.blocks.insert(.init(noteID: draft.id, kind: .callout, text: preview), at: 0)
        case .cleanUp:
            var replacement = draft.blocks.first ?? .init(noteID: draft.id)
            replacement.kind = .paragraph
            replacement.text = preview
            replacement.richTextData = nil
            draft.blocks = [replacement]
        case .continueWriting:
            draft.blocks.append(.init(noteID: draft.id, kind: .paragraph, text: preview))
        case .extractTasks:
            for line in aiProposalLines(preview) {
                draft.blocks.append(.init(noteID: draft.id, kind: .checklist, text: line))
            }
        case .suggestTags:
            for name in aiProposalLines(preview).prefix(5) {
                if let existing = tags.first(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
                    draft.tagIDs.insert(existing.id)
                } else if let created = await onCreateTag(name) {
                    draft.tagIDs.insert(created.id)
                }
            }
        case .suggestLinks:
            let lowered = preview.lowercased()
            for note in allNotes where note.id != draft.id && lowered.contains(note.displayTitle.lowercased()) {
                onConnect(note.id)
            }
        }
        normalizeOrdinals()
        draft.updatedAt = Date()
        draft.contentVersion = max(1, draft.contentVersion ?? 1) + 1
        aiProposal = nil
        await persist(preparedDraft())
    }

    private func aiProposalLines(_ value: String) -> [String] {
        value
            .split(whereSeparator: \.isNewline)
            .map {
                String($0)
                    .trimmingCharacters(in: CharacterSet.whitespaces.union(CharacterSet(charactersIn: "-•0123456789.[]")))
            }
            .filter { !$0.isEmpty }
    }

    private func aiActionTitle(_ action: NoteAIAction) -> String {
        switch action {
        case .summarize: "Summarize"
        case .cleanUp: "Clean up writing"
        case .continueWriting: "Continue writing"
        case .extractTasks: "Extract checklists"
        case .suggestTags: "Suggest tags"
        case .suggestLinks: "Suggest links"
        }
    }

    private func aiActionSymbol(_ action: NoteAIAction) -> String {
        switch action {
        case .summarize: "text.badge.star"
        case .cleanUp: "wand.and.sparkles"
        case .continueWriting: "text.append"
        case .extractTasks: "checklist"
        case .suggestTags: "tag"
        case .suggestLinks: "link"
        }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        let snapshot = preparedDraft()
        saveState = .saving
        autosaveTask = Task {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? await repository.saveKnowledgeDraft(.init(noteID: snapshot.id, snapshot: data))
            }
            do {
                try await Task.sleep(for: .milliseconds(450))
            } catch {
                return
            }
            guard !Task.isCancelled else { return }
            await persist(snapshot)
        }
    }

    private func preparedDraft() -> LifeBoardKnowledgeNoteValue {
        var value = draft
        value.updatedAt = Date()
        value.lastOpenedAt = Date()
        value.contentVersion = max(1, value.contentVersion ?? 1)
        for index in value.blocks.indices {
            value.blocks[index].ordinal = index
            value.blocks[index].updatedAt = value.updatedAt
            if value.blocks[index].createdAt == nil {
                value.blocks[index].createdAt = value.createdAt
            }
        }
        return value
    }

    @MainActor
    private func persist(_ value: LifeBoardKnowledgeNoteValue) async {
        guard value.isMeaningful || originalWasMeaningful else {
            saveState = .idle
            return
        }
        if !didWriteRevision, originalWasMeaningful, let originalSnapshot {
            try? await repository.saveKnowledgeRevision(.init(
                noteID: value.id,
                snapshot: originalSnapshot,
                reason: "Before editing"
            ))
            didWriteRevision = true
        }
        await onSave(value)
        try? await repository.deleteKnowledgeDraft(noteID: value.id)
        saveState = .saved(Date())
    }

    @MainActor
    private func restoreDraftIfNeeded() async {
        guard let recovered = try? await repository.fetchKnowledgeDraft(noteID: draft.id),
              recovered.updatedAt > draft.updatedAt,
              let value = try? JSONDecoder().decode(LifeBoardKnowledgeNoteValue.self, from: recovered.snapshot) else {
            return
        }
        draft = value
        saveState = .saving
    }

    @MainActor
    private func flushAndClose() async {
        autosaveTask?.cancel()
        let value = preparedDraft()
        if value.isMeaningful || originalWasMeaningful {
            await persist(value)
        } else {
            try? await repository.deleteKnowledgeDraft(noteID: value.id)
            try? await repository.deleteKnowledgeNote(id: value.id)
        }
        dismiss()
    }

    private var tagRail: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(tags) { tag in
                        Toggle(tag.name, isOn: Binding(
                            get: { draft.tagIDs.contains(tag.id) },
                            set: { enabled in if enabled { draft.tagIDs.insert(tag.id) } else { draft.tagIDs.remove(tag.id) } }
                        ))
                        .toggleStyle(.button)
                    }
                    Button {
                        withAnimation(LifeBoardAnimation.selection) {
                            showsTagComposer.toggle()
                        }
                    } label: {
                        Label(draft.tagIDs.isEmpty ? "Add tags" : "New tag", systemImage: "number")
                    }
                    .buttonStyle(.borderless)
                    .font(.subheadline.weight(.semibold))
                }
            }
            if showsTagComposer {
                HStack {
                    TextField("Tag name", text: $newTag)
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 42)
                        .background(Color.primary.opacity(0.05), in: Capsule())
                    Button("Add") {
                        Task {
                            if let tag = await onCreateTag(newTag) {
                                draft.tagIDs.insert(tag.id)
                                newTag = ""
                                showsTagComposer = false
                            }
                        }
                    }
                    .fontWeight(.semibold)
                    .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var relationships: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Links & backlinks").font(.headline)
                Spacer()
                Button("Connect", systemImage: "link.badge.plus") { showsLinkPicker = true }
            }
            let related = links.filter { $0.sourceNoteID == draft.id || $0.destinationNoteID == draft.id }
            if related.isEmpty { Text("No linked notes").foregroundStyle(.secondary) }
            ForEach(related) { link in
                let otherID = link.sourceNoteID == draft.id ? link.destinationNoteID : link.sourceNoteID
                HStack {
                    Image(systemName: link.sourceNoteID == draft.id ? "arrow.up.right" : "arrow.down.left")
                    Text(allNotes.first(where: { $0.id == otherID })?.title ?? "Unavailable note")
                    Spacer()
                    Button(role: .destructive) { onDisconnect(link) } label: { Image(systemName: "xmark.circle") }
                        .accessibilityLabel("Disconnect note")
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Attachments").font(.headline)
                Spacer()
                Button("Attach", systemImage: "paperclip") { showsFileImporter = true }
            }
            if isLoadingAttachments { ProgressView() }
            ForEach(attachments) { attachment in
                HStack {
                    Button {
                        Task { await openAttachment(attachment) }
                    } label: {
                        Label(attachment.fileName, systemImage: attachment.kind == "pdf" ? "doc.richtext" : "doc")
                            .lineLimit(1)
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    if attachmentFailures.contains(attachment.id) {
                        Button("Retry", systemImage: "arrow.clockwise") {
                            Task { await openAttachment(attachment) }
                        }
                        .labelStyle(.iconOnly)
                        .accessibilityLabel("Retry opening \(attachment.fileName)")
                    }
                    Button(role: .destructive) {
                        Task { await deleteAttachment(attachment) }
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Delete \(attachment.fileName)")
                }
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func addBlock(_ kind: LifeBoardKnowledgeBlockKind) {
        if V2FeatureFlags.knowledgeNotesTextKitEditorV2Enabled {
            performEditorCommand(.insertBlock(kind))
        } else {
            draft.blocks.append(.init(noteID: draft.id, kind: kind, ordinal: draft.blocks.count))
        }
    }

    private func performEditorCommand(_ command: KnowledgeEditorCommand) {
        if V2FeatureFlags.knowledgeNotesTextKitEditorV2Enabled {
            richEditorCommand = .init(command: command)
            richEditorIsFocused = true
        } else if case let .block(kind) = command {
            draft.blocks.append(.init(noteID: draft.id, kind: kind, ordinal: draft.blocks.count))
        }
    }

    private func deleteBlock(_ block: LifeBoardKnowledgeBlockValue) {
        guard draft.blocks.count > 1 else { return }
        if let attachmentID = KnowledgeBlockPayload.decode(from: block).attachment?.attachmentID,
           let attachment = attachments.first(where: { $0.id == attachmentID }) {
            Task { await deleteAttachment(attachment) }
            return
        }
        draft.blocks.removeAll { $0.id == block.id }
        normalizeOrdinals()
    }

    private func moveBlock(_ id: UUID, offset: Int) {
        guard let source = draft.blocks.firstIndex(where: { $0.id == id }) else { return }
        let destination = source + offset
        guard draft.blocks.indices.contains(destination) else { return }
        withAnimation(LifeBoardAnimation.cardReflow) {
            draft.blocks.swapAt(source, destination)
            normalizeOrdinals()
        }
    }

    private func addAttachmentBlock(_ attachment: LifeBoardKnowledgeAttachmentValue) {
        let imageExtensions = Set(["jpg", "jpeg", "png", "heic", "heif", "gif", "webp"])
        let kind: LifeBoardKnowledgeBlockKind = imageExtensions.contains(attachment.kind.lowercased()) ? .image : .file
        let payload = KnowledgeBlockPayload(attachment: .init(
            attachmentID: attachment.id,
            fileName: attachment.fileName
        ))
        draft.blocks.append(.init(
            noteID: draft.id,
            kind: kind,
            text: attachment.fileName,
            metadata: payload.encoded(),
            ordinal: draft.blocks.count
        ))
    }

    @MainActor
    private func importText(from url: URL) async {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return }
        if let snapshot = try? JSONEncoder().encode(draft) {
            try? await repository.saveKnowledgeRevision(
                .init(
                    noteID: draft.id,
                    snapshot: snapshot,
                    reason: "Before importing \(url.lastPathComponent)",
                    baseContentVersion: draft.contentVersion,
                    contentVersion: draft.contentVersion,
                    changeKind: "import"
                )
            )
        }
        draft.blocks.append(contentsOf: KnowledgeMarkdownCodec.parse(
            text,
            noteID: draft.id,
            startingOrdinal: draft.blocks.count
        ))
        normalizeOrdinals()
        if draft.title.isEmpty {
            draft.title = url.deletingPathExtension().lastPathComponent
        }
    }

    @MainActor
    private func restoreRevision(_ revision: KnowledgeNoteRevisionValue) {
        guard let restored = try? JSONDecoder().decode(LifeBoardKnowledgeNoteValue.self, from: revision.snapshot) else {
            return
        }
        if let current = try? JSONEncoder().encode(draft) {
            Task {
                try? await repository.saveKnowledgeRevision(.init(
                    noteID: draft.id,
                    snapshot: current,
                    reason: "Before restoring a version"
                ))
            }
        }
        draft = restored
        draft.updatedAt = Date()
        showsHistory = false
    }

    private func normalizeOrdinals() {
        for index in draft.blocks.indices { draft.blocks[index].ordinal = index }
    }

    private func loadAttachments() async {
        isLoadingAttachments = true
        attachments = (try? await repository.fetchKnowledgeAttachments(noteID: draft.id)) ?? []
        isLoadingAttachments = false
    }

    private func deleteAttachment(_ attachment: LifeBoardKnowledgeAttachmentValue) async {
        do {
            try await attachmentFiles.deleteFile(for: attachment)
            try await repository.deleteKnowledgeAttachment(id: attachment.id)
            attachmentFailures.remove(attachment.id)
            draft.blocks.removeAll {
                KnowledgeBlockPayload.decode(from: $0).attachment?.attachmentID == attachment.id
            }
            if draft.blocks.isEmpty { draft.blocks = [.init(noteID: draft.id)] }
            normalizeOrdinals()
            await loadAttachments()
        } catch {
            // Keep the attachment visible so the user can retry instead of pretending deletion succeeded.
        }
    }

    private func openAttachment(_ attachment: LifeBoardKnowledgeAttachmentValue) async {
        do {
            previewAttachmentURL = try await attachmentFiles.resolvedURL(for: attachment)
            attachmentFailures.remove(attachment.id)
        } catch {
            attachmentFailures.insert(attachment.id)
        }
    }

    private func kindTitle(_ kind: LifeBoardKnowledgeBlockKind) -> String {
        switch kind {
        case .heading1: "Heading 1"
        case .heading2: "Heading 2"
        case .bulletedList: "Bulleted List"
        case .numberedList: "Numbered List"
        case .noteLink: "Note Link"
        default: kind.rawValue.capitalized
        }
    }

    private func kindSymbol(_ kind: LifeBoardKnowledgeBlockKind) -> String {
        switch kind {
        case .paragraph: "text.alignleft"
        case .heading1, .heading2: "textformat.size"
        case .bulletedList: "list.bullet"
        case .numberedList: "list.number"
        case .checklist: "checklist"
        case .quote: "quote.opening"
        case .callout: "exclamationmark.bubble"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .divider: "minus"
        case .table: "tablecells"
        case .collapsible: "chevron.down.square"
        case .image: "photo"
        case .file: "doc"
        case .bookmark: "bookmark"
        case .noteLink: "link"
        }
    }
}

private struct LifeBoardNoteAIProposalReview: View {
    let proposal: NoteAIProposal
    let currentContentVersion: Int
    let onApply: (String) async -> Void
    let onDiscard: () -> Void

    @State private var editedPreview: String
    @State private var isApplying = false

    init(
        proposal: NoteAIProposal,
        currentContentVersion: Int,
        onApply: @escaping (String) async -> Void,
        onDiscard: @escaping () -> Void
    ) {
        self.proposal = proposal
        self.currentContentVersion = currentContentVersion
        self.onApply = onApply
        self.onDiscard = onDiscard
        _editedPreview = State(initialValue: proposal.preview)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Label("Review before anything changes", systemImage: "checkmark.shield")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(proposal.explanation)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    TextEditor(text: $editedPreview)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 260)
                        .padding(16)
                        .background(
                            Color(uiColor: .secondarySystemBackground),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.primary.opacity(0.07), lineWidth: 1)
                        }
                        .accessibilityLabel("Editable EVA proposal")
                    if isStale {
                        Label(
                            "This proposal is stale because the note changed. Discard it and ask again.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.orange)
                    } else {
                        Label(
                            "Only the text shown here will be applied. You can edit it first.",
                            systemImage: "hand.raised"
                        )
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(Color(LifeBoardColorTokens.foundationCanvas))
            .navigationTitle("EVA Proposal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive, action: onDiscard)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isApplying = true
                        Task {
                            await onApply(editedPreview)
                            isApplying = false
                        }
                    } label: {
                        if isApplying {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Apply").fontWeight(.semibold)
                        }
                    }
                    .disabled(isApplying || isStale || editedPreview.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .interactiveDismissDisabled(isApplying)
    }

    private var isStale: Bool {
        currentContentVersion != proposal.baseContentVersion
    }
}

private struct LifeBoardNoteHistoryView: View {
    let revisions: [KnowledgeNoteRevisionValue]
    let onRestore: (KnowledgeNoteRevisionValue) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if revisions.isEmpty {
                    ContentUnavailableView(
                        "No earlier versions",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("LifeBoard keeps meaningful editing checkpoints here.")
                    )
                } else {
                    List(revisions) { revision in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(revision.reason)
                                .font(.headline)
                            Text(revision.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Button("Restore this version") { onRestore(revision) }
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.vertical, 6)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Version History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                }
            }
        }
    }
}

private struct LifeBoardLockedKnowledgeNoteEditor: View {
    let placeholder: LifeBoardKnowledgeNoteValue
    let onUnlock: () async throws -> KnowledgeUnlockedNoteSession
    let onSave: (KnowledgeUnlockedNoteSession) async throws -> Void

    @State private var session: KnowledgeUnlockedNoteSession?
    @State private var isUnlocking = false
    @State private var errorMessage: String?
    @State private var selection = NSRange(location: 0, length: 0)
    @State private var isFocused = false
    @State private var command: KnowledgeEditorCommandInvocation?
    @State private var saveTask: Task<Void, Never>?
    @State private var saveState: NoteEditorSaveState = .idle
    @State private var isCaptured = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ZStack {
                Color(LifeBoardColorTokens.foundationCanvas).ignoresSafeArea()
                LifeBoardSceneCaptureMonitor(isCaptured: $isCaptured)
                    .frame(width: 0, height: 0)
                if let session {
                    unlockedContent(session)
                } else {
                    lockedPlaceholder
                }
                if scenePhase != .active || isCaptured {
                    privacyShield
                        .transition(.opacity)
                        .zIndex(10)
                }
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        Task { await saveAndDismiss() }
                    } label: {
                        Image(systemName: "xmark")
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel("Close locked note")
                }
                ToolbarItem(placement: .principal) {
                    Label("Locked", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase != .active else { return }
                saveTask?.cancel()
                Task { await saveCurrentSession() }
            }
            .onDisappear {
                saveTask?.cancel()
                Task { await saveCurrentSession() }
            }
            .alert("Locked note unavailable", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var lockedPlaceholder: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 88, height: 88)
                Image(systemName: "lock.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(.orange)
                    .symbolEffect(.breathe, options: .nonRepeating)
            }
            Text("A private page")
                .font(.system(.title, design: .rounded, weight: .bold))
            Text("Authenticate to read or edit this note. Its title, text, links, and attachments stay out of search and previews.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 390)
            Button {
                Task { await unlock() }
            } label: {
                HStack(spacing: 10) {
                    if isUnlocking { ProgressView().controlSize(.small) }
                    Label(isUnlocking ? "Unlocking" : "Unlock note", systemImage: "faceid")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .frame(minHeight: 50)
            }
            .disabled(isUnlocking)
            .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)
            .accessibilityIdentifier("notes.locked.unlock")
        }
        .padding(30)
    }

    private func unlockedContent(_ current: KnowledgeUnlockedNoteSession) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                TextField("Note title", text: Binding(
                    get: { session?.note.title ?? "" },
                    set: { value in
                        session?.note.title = value
                        scheduleSave()
                    }
                ))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .textFieldStyle(.plain)
                .accessibilityLabel("Note title")

                LifeBoardUnifiedNoteEditor(
                    note: Binding(
                        get: { session?.note ?? current.note },
                        set: { value in
                            session?.note = value
                            scheduleSave()
                        }
                    ),
                    selection: $selection,
                    isFocused: $isFocused,
                    command: command,
                    onSlashCommand: {},
                    onWikiLink: { _ in }
                )
                .frame(minHeight: 320)

                if !current.attachments.isEmpty {
                    Divider().padding(.vertical, 8)
                    Text("Encrypted attachments")
                        .font(.headline)
                    ForEach(current.attachments) { attachment in
                        Label(attachment.fileName, systemImage: "lock.doc")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 6) {
                editorButton("Bold", "bold", .bold)
                editorButton("Italic", "italic", .italic)
                editorButton("Highlight", "highlighter", .highlight)
                Divider().frame(height: 22)
                editorButton("Checklist", "checklist", .block(.checklist))
                editorButton("Heading", "textformat.size", .block(.heading2))
                Spacer()
                switch saveState {
                case .saving: ProgressView().controlSize(.small)
                case .saved: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                default: EmptyView()
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: 620, minHeight: 52)
            .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)
            .padding(12)
        }
    }

    private func editorButton(
        _ label: String,
        _ symbol: String,
        _ editorCommand: KnowledgeEditorCommand
    ) -> some View {
        Button {
            command = .init(command: editorCommand)
            isFocused = true
        } label: {
            Image(systemName: symbol).frame(width: 40, height: 40)
        }
        .accessibilityLabel(label)
    }

    private var privacyShield: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.largeTitle)
            Text("Locked note")
                .font(.headline)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(LifeBoardColorTokens.foundationCanvas))
        .accessibilityElement(children: .combine)
    }

    @MainActor
    private func unlock() async {
        isUnlocking = true
        defer { isUnlocking = false }
        do {
            session = try await onUnlock()
            isFocused = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveState = .saving
        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(450))
            guard !Task.isCancelled else { return }
            await saveCurrentSession()
        }
    }

    @MainActor
    private func saveCurrentSession() async {
        guard let session else { return }
        do {
            try await onSave(session)
            saveState = .saved(Date())
        } catch {
            saveState = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func saveAndDismiss() async {
        saveTask?.cancel()
        await saveCurrentSession()
        session = nil
        dismiss()
    }
}

private struct LifeBoardSceneCaptureMonitor: UIViewRepresentable {
    @Binding var isCaptured: Bool

    func makeUIView(context: Context) -> CaptureView {
        let view = CaptureView()
        view.onChange = { isCaptured = $0 }
        return view
    }

    func updateUIView(_ uiView: CaptureView, context: Context) {
        uiView.onChange = { isCaptured = $0 }
        uiView.publish()
    }

    final class CaptureView: UIView {
        var onChange: ((Bool) -> Void)?
        private var observesCaptureState = false

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if !observesCaptureState {
                observesCaptureState = true
                registerForTraitChanges([UITraitSceneCaptureState.self]) { (view: CaptureView, _) in
                    view.publish()
                }
            }
            publish()
        }

        func publish() {
            let captured = traitCollection.sceneCaptureState == .active
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in self?.onChange?(captured) }
        }
    }
}

private struct LifeBoardKnowledgeBlockEditor: View {
    @Binding var block: LifeBoardKnowledgeBlockValue
    let allNotes: [LifeBoardKnowledgeNoteValue]
    let attachments: [LifeBoardKnowledgeAttachmentValue]
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    @State private var expanded = true
    @State private var bookmarkIsLoading = false
    @State private var bookmarkError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(blockLabel, systemImage: blockSymbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Menu {
                    ForEach(LifeBoardKnowledgeBlockKind.allCases, id: \.self) { kind in
                        Button(kind.rawValue.capitalized) { block.kind = kind }
                    }
                    Divider()
                    Button("Move up", systemImage: "arrow.up", action: onMoveUp)
                    Button("Move down", systemImage: "arrow.down", action: onMoveDown)
                    Divider()
                    Button("Delete block", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 36, height: 30)
                }
                .accessibilityLabel("Block options")
            }
            switch block.kind {
            case .divider:
                Divider().padding(.vertical, 8)
            case .checklist:
                HStack(alignment: .top) {
                    Button {
                        withAnimation(LifeBoardAnimation.roleLocalState) {
                            block.isChecked.toggle()
                        }
                    } label: {
                        Image(systemName: block.isChecked ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(block.isChecked ? Color.accentColor : Color.secondary)
                            .contentTransition(.symbolEffect(.replace))
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.success, trigger: block.isChecked)
                    .accessibilityLabel(block.isChecked ? "Mark incomplete" : "Mark complete")
                    TextField("Checklist item", text: $block.text, axis: .vertical)
                        .strikethrough(block.isChecked, color: .secondary)
                        .foregroundStyle(block.isChecked ? Color.secondary : Color.primary)
                }
            case .collapsible:
                DisclosureGroup(isExpanded: $expanded) {
                    TextEditor(text: $block.text).frame(minHeight: 80)
                } label: { Text(block.text.split(separator: "\n").first.map(String.init) ?? "Collapsible section") }
            case .heading1:
                TextField("Heading", text: $block.text, axis: .vertical).font(.title2.weight(.semibold))
            case .heading2:
                TextField("Heading", text: $block.text, axis: .vertical).font(.title3.weight(.semibold))
            case .code:
                TextEditor(text: $block.text).font(.system(.body, design: .monospaced)).frame(minHeight: 100)
            case .table:
                LifeBoardKnowledgeTableEditor(block: $block)
            case .bookmark:
                VStack(alignment: .leading, spacing: 8) {
                    TextField("https://example.com", text: $block.text)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.URL)
                        .onChange(of: block.text) { _, value in
                            var payload = KnowledgeBlockPayload.decode(from: block)
                            payload.bookmark = .init(url: URL(string: value), title: payload.bookmark?.title, summary: payload.bookmark?.summary)
                            block.metadata = payload.encoded()
                        }
                    if let url = KnowledgeBlockPayload.decode(from: block).bookmark?.url {
                        Link(destination: url) {
                            VStack(alignment: .leading, spacing: 4) {
                                let bookmark = KnowledgeBlockPayload.decode(from: block).bookmark
                                Label(bookmark?.title ?? url.host() ?? url.absoluteString, systemImage: "safari")
                                    .font(.headline)
                                if let summary = bookmark?.summary {
                                    Text(summary).font(.caption).foregroundStyle(.secondary).lineLimit(3)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        if bookmarkIsLoading { ProgressView("Loading preview") }
                        if bookmarkError != nil {
                            Button("Retry preview", systemImage: "arrow.clockwise") { Task { await refreshBookmark() } }
                                .font(.caption.weight(.semibold))
                        }
                    }
                }
            case .noteLink:
                Picker("Linked note", selection: noteLinkSelection) {
                    Text("Choose a note").tag(UUID?.none)
                    ForEach(allNotes) { note in
                        Text(note.title.isEmpty ? "Untitled" : note.title).tag(Optional(note.id))
                    }
                }
                .pickerStyle(.menu)
            case .image:
                if let attachment = attachmentForBlock, let image = UIImage(data: attachment.payload) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 260)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityLabel(attachment.fileName)
                } else {
                    Label(block.text.isEmpty ? "Unavailable image" : block.text, systemImage: "photo.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                }
            case .file:
                Label(attachmentForBlock?.fileName ?? block.text, systemImage: attachmentForBlock == nil ? "doc.badge.ellipsis" : "doc")
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            default:
                TextField(placeholder, text: $block.text, axis: .vertical).lineLimit(2...12)
            }
        }
        .padding(.horizontal, usesInsetSurface ? 14 : 2)
        .padding(.vertical, usesInsetSurface ? 12 : 6)
        .background {
            if usesInsetSurface {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            }
        }
        .task(id: block.text) {
            guard block.kind == .bookmark else { return }
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            await refreshBookmark()
        }
    }

    private var usesInsetSurface: Bool {
        [.callout, .code, .table, .bookmark, .image, .file, .noteLink].contains(block.kind)
    }

    private var blockLabel: String {
        switch block.kind {
        case .heading1: "Title"
        case .heading2: "Heading"
        case .bulletedList: "Bulleted list"
        case .numberedList: "Numbered list"
        case .noteLink: "Linked note"
        default: block.kind.rawValue.capitalized
        }
    }

    private var blockSymbol: String {
        switch block.kind {
        case .paragraph: "text.alignleft"
        case .heading1, .heading2: "textformat.size"
        case .bulletedList: "list.bullet"
        case .numberedList: "list.number"
        case .checklist: "checklist"
        case .quote: "quote.opening"
        case .callout: "bubble.left"
        case .code: "chevron.left.forwardslash.chevron.right"
        case .divider: "minus"
        case .table: "tablecells"
        case .collapsible: "chevron.down"
        case .image: "photo"
        case .file: "doc"
        case .bookmark: "bookmark"
        case .noteLink: "link"
        }
    }

    private var placeholder: String {
        switch block.kind {
        case .quote: "Quote"
        case .callout: "Callout"
        case .bookmark: "Paste a URL"
        case .noteLink: "Linked note"
        default: "Write something"
        }
    }

    private var noteLinkSelection: Binding<UUID?> {
        Binding(
            get: { KnowledgeBlockPayload.decode(from: block).noteLink?.noteID },
            set: { noteID in
                var payload = KnowledgeBlockPayload.decode(from: block)
                payload.noteLink = noteID.map { id in
                    .init(noteID: id, cachedTitle: allNotes.first(where: { $0.id == id })?.title)
                }
                block.metadata = payload.encoded()
                block.text = noteID?.uuidString ?? ""
            }
        )
    }

    private var attachmentForBlock: LifeBoardKnowledgeAttachmentValue? {
        guard let id = KnowledgeBlockPayload.decode(from: block).attachment?.attachmentID else { return nil }
        return attachments.first(where: { $0.id == id })
    }

    @MainActor
    private func refreshBookmark() async {
        guard let url = URL(string: block.text), ["http", "https"].contains(url.scheme?.lowercased() ?? "") else {
            bookmarkError = "Enter a valid web address."
            return
        }
        bookmarkIsLoading = true
        bookmarkError = nil
        defer { bookmarkIsLoading = false }
        do {
            let bookmark = try await URLSessionKnowledgeBookmarkMetadataFetcher.shared.metadata(for: url)
            var payload = KnowledgeBlockPayload.decode(from: block)
            payload.bookmark = bookmark
            block.metadata = payload.encoded()
        } catch is CancellationError {
            return
        } catch {
            bookmarkError = error.localizedDescription
        }
    }
}

private struct LifeBoardKnowledgeTableEditor: View {
    @Binding var block: LifeBoardKnowledgeBlockValue

    private var table: KnowledgeBlockPayload.Table {
        KnowledgeBlockPayload.decode(from: block).table ?? .init()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal) {
                Grid(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(table.rows.indices, id: \.self) { row in
                        GridRow {
                            ForEach(table.rows[row].indices, id: \.self) { column in
                                TextField("Cell", text: cellBinding(row: row, column: column))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(minWidth: 120)
                            }
                            Button(role: .destructive) { deleteRow(row) } label: {
                                Image(systemName: "minus.circle")
                                    .frame(width: 44, height: 44)
                            }
                            .disabled(table.rows.count == 1)
                            .accessibilityLabel("Delete row \(row + 1)")
                        }
                    }
                }
            }
            HStack {
                Button("Add row", systemImage: "plus") { addRow() }
                Button("Add column", systemImage: "rectangle.split.3x1") { addColumn() }
                Button("Remove column", systemImage: "minus") { removeColumn() }
                    .disabled((table.rows.first?.count ?? 1) == 1)
            }
            .buttonStyle(.lifeBoardChip)
            .controlSize(.small)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Editable table")
    }

    private func cellBinding(row: Int, column: Int) -> Binding<String> {
        Binding(
            get: {
                let rows = table.rows
                guard rows.indices.contains(row), rows[row].indices.contains(column) else { return "" }
                return rows[row][column]
            },
            set: { value in mutate { $0.rows[row][column] = value } }
        )
    }

    private func addRow() {
        mutate { $0.rows.append(Array(repeating: "", count: $0.rows.first?.count ?? 1)) }
    }

    private func deleteRow(_ row: Int) {
        mutate { if $0.rows.count > 1 { $0.rows.remove(at: row) } }
    }

    private func addColumn() {
        mutate { table in for row in table.rows.indices { table.rows[row].append("") } }
    }

    private func removeColumn() {
        mutate { table in
            guard (table.rows.first?.count ?? 1) > 1 else { return }
            for row in table.rows.indices { table.rows[row].removeLast() }
        }
    }

    private func mutate(_ change: (inout KnowledgeBlockPayload.Table) -> Void) {
        var payload = KnowledgeBlockPayload.decode(from: block)
        var value = payload.table ?? .init()
        change(&value)
        payload.table = value
        block.metadata = payload.encoded()
        block.text = value.rows.map { $0.joined(separator: ",") }.joined(separator: "\n")
    }
}


/// Wraps the shared page container so the builder keeps its host navigation
/// chrome (title, Cancel, Save) exactly as the Notes module supplies it.
private struct LifeBoardComposerScaffoldShim<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        LifeBoardComposerPage(
            subtitle: "Saved collections update automatically as your notes change.",
            identifier: "notes.smartCollection"
        ) {
            content
        } commit: {
            EmptyView()
        }
    }
}

private struct SmartCollectionIdentitySection: View {
    @Binding var name: String
    @Binding var terms: String

    var body: some View {
        LifeBoardComposerSection("Collection") {
            LifeBoardComposerField(
                "Name",
                prompt: "What to call it",
                text: $name,
                showsLabel: false,
                identifier: "notes.smartCollection.name"
            )
            LifeBoardComposerField("Words or phrase", prompt: "Optional", text: $terms)
        }
    }
}

private struct SmartCollectionLocationSection: View {
    @Binding var folderID: UUID?
    let folders: [LifeBoardKnowledgeFolderValue]
    let tags: [LifeBoardKnowledgeTagValue]
    @Binding var selectedTagIDs: Set<UUID>

    var body: some View {
        LifeBoardComposerSection("Location") {
            LifeBoardMenuRow(
                "Folder",
                selection: $folderID,
                values: [UUID?.none] + folders.map { UUID?.some($0.id) },
                title: { id in
                    guard let id else { return "Any folder" }
                    return folders.first { $0.id == id }?.title ?? "Any folder"
                },
                identifier: "notes.smartCollection.folder"
            )
            if tags.isEmpty == false {
                VStack(alignment: .leading, spacing: 8) {
                    Text(selectedTagIDs.isEmpty ? "Tags" : "Tags · \(selectedTagIDs.count)")
                        .font(.lifeboard(.meta))
                        .foregroundStyle(Color(LifeBoardColorTokens.inkSecondary))
                    LifeBoardOptionFlow(spacing: 8) {
                        ForEach(tags) { tag in
                            let isOn = selectedTagIDs.contains(tag.id)
                            Button {
                                LifeBoardHaptic.pick.play()
                                if isOn { selectedTagIDs.remove(tag.id) } else { selectedTagIDs.insert(tag.id) }
                            } label: {
                                Text(tag.name)
                                    .font(.lifeboard(isOn ? .bodyStrong : .body))
                                    .foregroundStyle(Color(isOn
                                        ? LifeBoardColorTokens.inkPrimary
                                        : LifeBoardColorTokens.inkSecondary))
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 44)
                                    .lifeBoardClaySurface(
                                        isOn ? .raised : .well,
                                        cornerRadius: LifeBoardFoundationRadius.pill
                                    )
                                    .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
                        }
                    }
                }
            }
        }
    }
}

private struct SmartCollectionContentSection: View {
    @Binding var requiresAttachments: Bool
    @Binding var checklist: KnowledgeChecklistFilter
    @Binding var linkFilter: KnowledgeLinkFilter

    var body: some View {
        LifeBoardComposerSection("Content") {
            Toggle("Has attachments", isOn: $requiresAttachments)
                .toggleStyle(.lifeBoardClay)
            LifeBoardOptionRail(
                "Checklists",
                selection: $checklist,
                values: [.any, .incomplete, .completed],
                identifierPrefix: "notes.smartCollection.checklist",
                title: {
                    switch $0 {
                    case .incomplete: "Has incomplete items"
                    case .completed: "All completed"
                    default: "Any"
                    }
                }
            )
            LifeBoardOptionRail(
                "Connections",
                selection: $linkFilter,
                values: [.any, .incoming, .outgoing, .unlinked],
                identifierPrefix: "notes.smartCollection.links",
                title: {
                    switch $0 {
                    case .incoming: "Incoming links"
                    case .outgoing: "Outgoing links"
                    case .unlinked: "Unlinked"
                    default: "Any"
                    }
                }
            )
        }
    }
}

private struct SmartCollectionRefineSection: View {
    @Binding var favoritesOnly: Bool
    @Binding var pinnedOnly: Bool
    @Binding var modifiedRecently: Bool

    var body: some View {
        LifeBoardComposerSection("Refine") {
            Toggle("Favorites only", isOn: $favoritesOnly)
                .toggleStyle(.lifeBoardClay)
            Toggle("Pinned only", isOn: $pinnedOnly)
                .toggleStyle(.lifeBoardClay)
            Toggle("Edited in the last 30 days", isOn: $modifiedRecently)
                .toggleStyle(.lifeBoardClay)
        }
    }
}

private struct LifeBoardSmartCollectionBuilder: View {
    let spaceID: UUID?
    let folders: [LifeBoardKnowledgeFolderValue]
    let tags: [LifeBoardKnowledgeTagValue]
    let onSave: (String, KnowledgeNoteQuery) async -> Void
    let onCancel: () -> Void

    @State private var name = ""
    @State private var terms = ""
    @State private var folderID: UUID?
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var requiresAttachments = false
    @State private var checklist: KnowledgeChecklistFilter = .any
    @State private var linkFilter: KnowledgeLinkFilter = .any
    @State private var favoritesOnly = false
    @State private var pinnedOnly = false
    @State private var modifiedRecently = false
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            LifeBoardComposerScaffoldShim {
                SmartCollectionIdentitySection(name: $name, terms: $terms)
                SmartCollectionLocationSection(
                    folderID: $folderID,
                    folders: folders,
                    tags: tags,
                    selectedTagIDs: $selectedTagIDs
                )
                SmartCollectionContentSection(
                    requiresAttachments: $requiresAttachments,
                    checklist: $checklist,
                    linkFilter: $linkFilter
                )
                SmartCollectionRefineSection(
                    favoritesOnly: $favoritesOnly,
                    pinnedOnly: $pinnedOnly,
                    modifiedRecently: $modifiedRecently
                )
            }
            .navigationTitle("Smart Collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        isSaving = true
                        let query = KnowledgeNoteQuery(
                            collection: .all,
                            spaceID: spaceID,
                            folderID: folderID,
                            tagIDs: selectedTagIDs,
                            searchText: terms,
                            modifiedAfter: modifiedRecently
                                ? Calendar.current.date(byAdding: .day, value: -30, to: Date())
                                : nil,
                            requiresAttachments: requiresAttachments ? true : nil,
                            checklist: checklist == .any ? nil : checklist,
                            links: linkFilter == .any ? nil : linkFilter,
                            pinned: pinnedOnly ? true : nil,
                            favorite: favoritesOnly ? true : nil
                        )
                        Task {
                            await onSave(name, query)
                            isSaving = false
                        }
                    } label: {
                        if isSaving { ProgressView().controlSize(.small) }
                        else { Text("Save").fontWeight(.semibold) }
                    }
                    .disabled(isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .interactiveDismissDisabled(isSaving)
    }
}

private struct LifeBoardKnowledgeGraphView: View {
    let notes: [LifeBoardKnowledgeNoteValue]
    let links: [LifeBoardKnowledgeLinkValue]
    let folders: [LifeBoardKnowledgeFolderValue]
    let tags: [LifeBoardKnowledgeTagValue]
    let onOpen: (LifeBoardKnowledgeNoteValue) -> Void
    @State private var scale = 1.0
    @State private var offset = CGSize.zero
    @State private var searchText = ""
    @State private var selectedFolderID: UUID?
    @State private var selectedTagID: UUID?
    @State private var prefersList = false
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    private var filteredNotes: [LifeBoardKnowledgeNoteValue] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return notes.filter { note in
            (query.isEmpty || note.title.lowercased().contains(query) || note.plainText.lowercased().contains(query))
                && (selectedFolderID == nil || note.folderID == selectedFolderID)
                && (selectedTagID.map { note.tagIDs.contains($0) } ?? true)
        }
    }

    private var filteredLinks: [LifeBoardKnowledgeLinkValue] {
        let ids = Set(filteredNotes.map(\.id))
        return links.filter { ids.contains($0.sourceNoteID) && ids.contains($0.destinationNoteID) }
    }

    var body: some View {
        VStack(spacing: 10) {
            TextField("Search graph", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 20)
            HStack {
                filterMenu(title: "Folder", selection: $selectedFolderID, values: folders.map { ($0.id, $0.title) })
                filterMenu(title: "Tag", selection: $selectedTagID, values: tags.map { ($0.id, $0.name) })
                Spacer()
                Button(prefersList ? "Graph" : "List", systemImage: prefersList ? "point.3.connected.trianglepath.dotted" : "list.bullet") {
                    prefersList.toggle()
                }
            }
            .padding(.horizontal, 20)
            if prefersList || voiceOverEnabled {
                List(filteredNotes) { note in
                    Button { onOpen(note) } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(note.title.isEmpty ? "Untitled" : note.title).font(.headline)
                            Text(note.plainText).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                    }
                }
                .listStyle(.plain)
            } else {
                graph
            }
        }
    }

    private var graph: some View {
        GeometryReader { proxy in
            if filteredNotes.isEmpty {
                ContentUnavailableView("No graph yet", systemImage: "point.3.connected.trianglepath.dotted", description: Text("Create and connect notes to form a graph."))
            } else {
                let positions = graphPositions(for: filteredNotes, in: proxy.size)
                ZStack {
                    Canvas { context, _ in
                        for link in filteredLinks {
                            guard let start = positions[link.sourceNoteID], let end = positions[link.destinationNoteID] else { continue }
                            var path = Path(); path.move(to: start); path.addLine(to: end)
                            context.stroke(path, with: .color(Color.primary.opacity(0.24)), lineWidth: 1.5)
                        }
                    }
                    ForEach(filteredNotes) { note in
                        if let position = positions[note.id] {
                            Button { onOpen(note) } label: {
                                VStack(spacing: 4) {
                                    Circle().fill(.tint).frame(width: note.isPinned ? 34 : 26, height: note.isPinned ? 34 : 26)
                                    Text(note.title.isEmpty ? "Untitled" : note.title).font(.caption2).lineLimit(1).frame(width: 88)
                                }
                            }
                            .buttonStyle(.plain)
                            .position(position)
                        }
                    }
                }
                .scaleEffect(scale)
                .offset(offset)
                .gesture(MagnifyGesture().onChanged { scale = min(2.5, max(0.6, $0.magnification)) })
                .simultaneousGesture(DragGesture().onChanged { offset = $0.translation })
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Knowledge graph with \(filteredNotes.count) notes and \(filteredLinks.count) links")
            }
        }
        .padding(12)
    }

    private func graphPositions(for notes: [LifeBoardKnowledgeNoteValue], in size: CGSize) -> [UUID: CGPoint] {
        let radius = max(70, min(size.width, size.height) * 0.34)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        return Dictionary(uniqueKeysWithValues: notes.enumerated().map { index, note in
            let angle = (Double(index) / Double(max(1, notes.count))) * .pi * 2 - .pi / 2
            let ring = index < 12 ? radius * 0.62 : radius
            return (note.id, CGPoint(x: center.x + cos(angle) * ring, y: center.y + sin(angle) * ring))
        })
    }

    private func filterMenu(
        title: String,
        selection: Binding<UUID?>,
        values: [(id: UUID, title: String)]
    ) -> some View {
        Menu {
            Button("All") { selection.wrappedValue = nil }
            ForEach(values, id: \.id) { value in
                Button(value.title) { selection.wrappedValue = value.id }
            }
        } label: {
            Label(title, systemImage: selection.wrappedValue == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
        }
        .buttonStyle(.lifeBoardChip)
    }
}
