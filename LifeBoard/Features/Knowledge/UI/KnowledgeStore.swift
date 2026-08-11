import LifeBoardContracts
import LifeBoardDomain
import LifeBoardPersistence
import LifeBoardTokens
import LifeBoardUI
import Foundation
import Observation
import PhotosUI
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class KnowledgeStore {
    enum Layout: String, CaseIterable { case list, grid }
    enum BatchOperation: Sendable {
        case favorite
        case pin
        case archive
        case trash
        case restore
    }

    private(set) var spaces: [KnowledgeSpaceValue] = []
    private(set) var folders: [KnowledgeFolderValue] = []
    private(set) var notes: [KnowledgeNoteValue] = []
    private(set) var tags: [KnowledgeTagValue] = []
    private(set) var links: [KnowledgeLinkValue] = []
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
    private var undoNotes: [KnowledgeNoteValue] = []
    private let searchIndex: (any KnowledgeSearchIndex)?
    private let secureNotes: (any KnowledgeSecureNoteService)?
    private var didSeedSearchIndex = false
    private var searchTask: Task<Void, Never>?

    let repository: any KnowledgeRepository
    let attachmentFiles: any KnowledgeAttachmentFileRepository

    init(
        repository: any KnowledgeRepository,
        initialFolderID: UUID? = nil,
        attachmentFiles: (any KnowledgeAttachmentFileRepository)? = nil
    ) {
        self.repository = repository
        self.attachmentFiles = attachmentFiles ?? ProtectedKnowledgeAttachmentFiles()
        searchIndex = KnowledgeFeatureFlags.searchIndexEnabled
            ? try? LocalKnowledgeSearchIndex()
            : nil
        secureNotes = KnowledgeFeatureFlags.securityEnabled
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
                let personal = KnowledgeSpaceValue(title: "Personal", icon: "person.crop.circle")
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

    var visibleNotes: [KnowledgeNoteValue] {
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

    var pinnedNotes: [KnowledgeNoteValue] {
        visibleNotes.filter(\.isPinned).sorted {
            let lhs = $0.manualSortOrder
            let rhs = $1.manualSortOrder
            if lhs != nil || rhs != nil {
                return (lhs ?? .greatestFiniteMagnitude) < (rhs ?? .greatestFiniteMagnitude)
            }
            return $0.updatedAt > $1.updatedAt
        }
    }

    var recentNotes: [KnowledgeNoteValue] {
        Array(visibleNotes.filter { !$0.isPinned }.prefix(8))
    }

    func createSpace(title: String) async {
        do {
            let value = KnowledgeSpaceValue(title: title)
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

    var selectedFolderPath: [KnowledgeFolderValue] {
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

    func move(_ folder: KnowledgeFolderValue, to parentID: UUID?) async {
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

    func move(_ note: KnowledgeNoteValue, to folderID: UUID?) async {
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
    ) -> KnowledgeNoteValue? {
        guard let selectedSpaceID else { return nil }
        let noteID = id ?? UUID()
        let blocks: [KnowledgeBlockValue]
        if let initialText, !initialText.isEmpty {
            blocks = [
                KnowledgeBlockValue(
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
                KnowledgeBlockValue(
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

    func save(_ note: KnowledgeNoteValue) async {
        do {
            try await repository.saveKnowledgeNote(note)
            try await reconcileBlockLinks(for: note)
            await index(note)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    private func reconcileBlockLinks(for note: KnowledgeNoteValue) async throws {
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

    func moveToTrash(_ note: KnowledgeNoteValue) async {
        var updated = note
        updated.state = .trashed
        updated.deletedAt = Date()
        updated.updatedAt = Date()
        undoNotes = [note]
        undoMessage = "Moved “\(note.displayTitle)” to Trash"
        await save(updated)
    }

    func restore(_ note: KnowledgeNoteValue) async {
        var updated = note
        updated.state = .active
        updated.deletedAt = nil
        updated.updatedAt = Date()
        await save(updated)
    }

    func archive(_ note: KnowledgeNoteValue) async {
        var updated = note
        updated.state = .archived
        updated.updatedAt = Date()
        undoNotes = [note]
        undoMessage = "Archived “\(note.displayTitle)”"
        await save(updated)
    }

    func duplicate(_ note: KnowledgeNoteValue) async {
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

    func deletePermanently(_ note: KnowledgeNoteValue) async {
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

    func saveTag(name: String) async -> KnowledgeTagValue? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let existing = tags.first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) { return existing }
        let tag = KnowledgeTagValue(name: trimmed)
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

    func disconnect(_ link: KnowledgeLinkValue) async {
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

    func addAttachment(noteID: UUID, url: URL) async -> KnowledgeAttachmentValue? {
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
    ) async -> KnowledgeAttachmentValue? {
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

    func lock(_ note: KnowledgeNoteValue) async {
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

    func unlock(_ note: KnowledgeNoteValue) async throws -> KnowledgeUnlockedNoteSession {
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

    private func index(_ note: KnowledgeNoteValue) async {
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
