import Foundation
import Observation
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class LifeBoardKnowledgeStore {
    private(set) var spaces: [LifeBoardKnowledgeSpaceValue] = []
    private(set) var folders: [LifeBoardKnowledgeFolderValue] = []
    private(set) var notes: [LifeBoardKnowledgeNoteValue] = []
    private(set) var tags: [LifeBoardKnowledgeTagValue] = []
    private(set) var links: [LifeBoardKnowledgeLinkValue] = []
    private(set) var isLoading = false
    var selectedSpaceID: UUID?
    var selectedFolderID: UUID?
    var searchText = ""
    var errorMessage: String?

    let repository: any LifeBoardPhaseIIRepository
    let attachmentFiles: any KnowledgeAttachmentFileRepository

    init(
        repository: any LifeBoardPhaseIIRepository,
        initialFolderID: UUID? = nil,
        attachmentFiles: (any KnowledgeAttachmentFileRepository)? = nil
    ) {
        self.repository = repository
        self.attachmentFiles = attachmentFiles ?? ProtectedKnowledgeAttachmentFiles()
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
            async let noteValues = repository.fetchKnowledgeNotes(search: searchText, spaceID: selectedSpaceID)
            async let tagValues = repository.fetchKnowledgeTags()
            async let linkValues = repository.fetchKnowledgeLinks()
            (folders, notes, tags, links) = try await (folderValues, noteValues, tagValues, linkValues)
        } catch { errorMessage = error.localizedDescription }
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

    func createNote(folderID: UUID? = nil) -> LifeBoardKnowledgeNoteValue? {
        guard let selectedSpaceID else { return nil }
        let noteID = UUID()
        return .init(
            id: noteID,
            spaceID: selectedSpaceID,
            folderID: folderID,
            title: "Untitled",
            blocks: [.init(noteID: noteID)]
        )
    }

    func save(_ note: LifeBoardKnowledgeNoteValue) async {
        do {
            try await repository.saveKnowledgeNote(note)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    func delete(_ note: LifeBoardKnowledgeNoteValue) async {
        do {
            try await repository.deleteKnowledgeNote(id: note.id)
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
            let attachment = LifeBoardKnowledgeAttachmentValue(
                noteID: noteID,
                kind: url.pathExtension.lowercased(),
                fileName: url.lastPathComponent,
                payload: data
            )
            try await repository.saveKnowledgeAttachment(attachment)
            _ = try await attachmentFiles.persist(attachment)
            return attachment
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
}

struct LifeBoardKnowledgeModuleView: View {
    private enum Section: String, CaseIterable, Identifiable { case library = "Library", graph = "Graph"; var id: String { rawValue } }

    @State private var store: LifeBoardKnowledgeStore
    @State private var section: Section = .library
    @State private var editingNote: LifeBoardKnowledgeNoteValue?
    @State private var confirmsDelete: LifeBoardKnowledgeNoteValue?
    @State private var showsNewSpace = false
    @State private var showsNewFolder = false
    @State private var draftName = ""
    @Environment(LifeBoardPresentationPreferences.self) private var preferences

    init(repository: any LifeBoardPhaseIIRepository, initialFolderID: UUID? = nil) {
        _store = State(initialValue: LifeBoardKnowledgeStore(repository: repository, initialFolderID: initialFolderID))
    }

    var body: some View {
        let palette = LifeBoardDaypartTokens.palette(for: preferences.resolvedDaypart())
        VStack(spacing: 0) {
            sectionPicker
            switch section {
            case .library: library(palette: palette)
            case .graph:
                LifeBoardKnowledgeGraphView(
                    notes: Array(store.notes.prefix(150)),
                    links: store.links,
                    folders: store.folders,
                    tags: store.tags
                ) { editingNote = $0 }
            }
        }
        .task { await store.load() }
        .onChange(of: store.searchText) { _, _ in Task { await store.load() } }
        .onChange(of: store.selectedSpaceID) { _, _ in Task { await store.load() } }
        .sheet(item: $editingNote) { note in
            noteEditor(note)
        }
        .alert("New Space", isPresented: $showsNewSpace, actions: newSpaceActions)
        .alert("New Folder", isPresented: $showsNewFolder, actions: newFolderActions)
        .alert("Delete note?", isPresented: Binding(
            get: { confirmsDelete != nil },
            set: { if !$0 { confirmsDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let note = confirmsDelete { Task { await store.delete(note) } }
                confirmsDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmsDelete = nil }
        } message: { Text("This removes the note, its blocks, links, and attachments.") }
        .alert("Notes are unavailable", isPresented: Binding(
            get: { store.errorMessage != nil },
            set: { if !$0 { store.errorMessage = nil } }
        )) { Button("OK", role: .cancel) {} } message: { Text(presentedErrorMessage) }
    }

    private var presentedErrorMessage: String { store.errorMessage ?? "" }

    private var sectionPicker: some View {
        Picker("Notes section", selection: $section) {
            Text("Library").tag(Section.library)
            Text("Graph").tag(Section.graph)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }

    private func noteEditor(_ note: LifeBoardKnowledgeNoteValue) -> some View {
        let repository = store.repository
        let notes = store.notes
        let tags = store.tags
        let links = store.links
        return LifeBoardKnowledgeNoteEditor(
            note: note,
            allNotes: notes,
            tags: tags,
            links: links,
            repository: repository,
            attachmentFiles: store.attachmentFiles,
            onSave: saveNote,
            onCreateTag: createTag,
            onConnect: { destination in connect(noteID: note.id, destination: destination) },
            onDisconnect: disconnect,
            onAttach: { url in await store.addAttachment(noteID: note.id, url: url) }
        )
    }

    private func saveNote(_ note: LifeBoardKnowledgeNoteValue) {
        Task { await store.save(note) }
    }

    private func createTag(_ name: String) async -> LifeBoardKnowledgeTagValue? {
        await store.saveTag(name: name)
    }

    private func connect(noteID: UUID, destination: UUID) {
        Task { await store.connect(source: noteID, destination: destination) }
    }

    private func disconnect(_ link: LifeBoardKnowledgeLinkValue) {
        Task { await store.disconnect(link) }
    }

    private func library(palette: LifeBoardDaypartPalette) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                HStack {
                    if store.selectedFolderID != nil {
                        Button {
                            store.navigateUp()
                        } label: {
                            Image(systemName: "chevron.left")
                                .frame(width: 44, height: 44)
                        }
                        .accessibilityLabel("Back to parent folder")
                    }
                    Menu {
                        ForEach(store.spaces) { space in
                            Button(space.title, systemImage: space.icon) { store.selectedSpaceID = space.id }
                        }
                        Divider()
                        Button("New Space", systemImage: "plus") { draftName = ""; showsNewSpace = true }
                    } label: {
                        Label(store.spaces.first(where: { $0.id == store.selectedSpaceID })?.title ?? "Space", systemImage: "square.grid.2x2")
                    }
                    Spacer()
                    Menu {
                        Button("New Note", systemImage: "square.and.pencil") {
                            editingNote = store.createNote(folderID: store.selectedFolderID)
                        }
                        Button("New Folder", systemImage: "folder.badge.plus") { draftName = ""; showsNewFolder = true }
                    } label: { Image(systemName: "plus.circle.fill").font(.title2).frame(width: 44, height: 44) }
                    .accessibilityLabel("Add note or folder")
                }
                TextField("Search notes", text: $store.searchText)
                    .textFieldStyle(.roundedBorder)
                if store.selectedFolderID != nil {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            Button("All Notes") { store.selectedFolderID = nil }
                            ForEach(store.selectedFolderPath) { folder in
                                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
                                Button(folder.title) { store.selectedFolderID = folder.id }
                            }
                        }
                        .font(.subheadline.weight(.medium))
                    }
                    .accessibilityLabel("Folder path")
                }
                let visibleFolders = store.folders.filter { $0.parentFolderID == store.selectedFolderID }
                if !visibleFolders.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(store.selectedFolderID == nil ? "Folders" : "Subfolders").font(.headline)
                        ForEach(visibleFolders) { folder in
                            Button {
                                store.selectedFolderID = folder.id
                            } label: {
                                HStack {
                                    Image(systemName: "folder.fill")
                                    Text(folder.title)
                                    Spacer()
                                    Text("\(store.notes.filter { $0.folderID == folder.id }.count)").foregroundStyle(.secondary)
                                }
                                .frame(minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { folderMoveMenu(folder) }
                        }
                    }
                    .padding(16)
                    .lifeBoardPaperCard()
                }
                let visibleNotes = store.notes.filter { note in
                    note.folderID == store.selectedFolderID
                }
                if visibleNotes.isEmpty {
                    ContentUnavailableView("No notes yet", systemImage: "note.text", description: Text("Create a note for an idea, reference, checklist, or plan."))
                        .padding(.top, 36)
                } else {
                    ForEach(visibleNotes) { note in
                        Button { editingNote = note } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    if note.isPinned { Image(systemName: "pin.fill").accessibilityLabel("Pinned") }
                                    Text(note.title.isEmpty ? "Untitled" : note.title).font(.headline)
                                    Spacer()
                                    if note.isFavorite { Image(systemName: "star.fill").accessibilityLabel("Favorite") }
                                }
                                if !note.plainText.isEmpty {
                                    Text(note.plainText).font(.subheadline).foregroundStyle(palette.color(for: .foregroundSecondary)).lineLimit(2)
                                }
                                Text(note.updatedAt.formatted(.relative(presentation: .named))).font(.caption).foregroundStyle(palette.color(for: .foregroundSecondary))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .lifeBoardPaperCard()
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            noteMoveMenu(note)
                            Button("Delete", systemImage: "trash", role: .destructive) { confirmsDelete = note }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .refreshable { await store.load() }
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
        Button("Move to All Notes", systemImage: "tray") { Task { await store.move(folder, to: nil) } }
            .disabled(folder.parentFolderID == nil)
        Menu("Move to Folder", systemImage: "folder") {
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
            Button("All Notes", systemImage: "tray") { Task { await store.move(note, to: nil) } }
                .disabled(note.folderID == nil)
            ForEach(store.folders) { folder in
                Button(folder.title) { Task { await store.move(note, to: folder.id) } }
                    .disabled(note.folderID == folder.id)
            }
        }
    }
}

private struct LifeBoardKnowledgeNoteEditor: View {
    @State private var draft: LifeBoardKnowledgeNoteValue
    @State private var attachments: [LifeBoardKnowledgeAttachmentValue] = []
    @State private var newTag = ""
    @State private var showsFileImporter = false
    @State private var showsLinkPicker = false
    @State private var isLoadingAttachments = false
    @State private var previewAttachmentURL: URL?
    @State private var attachmentFailures: Set<UUID> = []
    let allNotes: [LifeBoardKnowledgeNoteValue]
    let tags: [LifeBoardKnowledgeTagValue]
    let links: [LifeBoardKnowledgeLinkValue]
    let repository: any LifeBoardPhaseIIRepository
    let attachmentFiles: any KnowledgeAttachmentFileRepository
    let onSave: (LifeBoardKnowledgeNoteValue) -> Void
    let onCreateTag: (String) async -> LifeBoardKnowledgeTagValue?
    let onConnect: (UUID) -> Void
    let onDisconnect: (LifeBoardKnowledgeLinkValue) -> Void
    let onAttach: (URL) async -> LifeBoardKnowledgeAttachmentValue?
    @Environment(\.dismiss) private var dismiss

    init(
        note: LifeBoardKnowledgeNoteValue,
        allNotes: [LifeBoardKnowledgeNoteValue],
        tags: [LifeBoardKnowledgeTagValue],
        links: [LifeBoardKnowledgeLinkValue],
        repository: any LifeBoardPhaseIIRepository,
        attachmentFiles: any KnowledgeAttachmentFileRepository,
        onSave: @escaping (LifeBoardKnowledgeNoteValue) -> Void,
        onCreateTag: @escaping (String) async -> LifeBoardKnowledgeTagValue?,
        onConnect: @escaping (UUID) -> Void,
        onDisconnect: @escaping (LifeBoardKnowledgeLinkValue) -> Void,
        onAttach: @escaping (URL) async -> LifeBoardKnowledgeAttachmentValue?
    ) {
        _draft = State(initialValue: note)
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
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    TextField("Note title", text: $draft.title)
                        .font(.largeTitle.weight(.semibold))
                        .textFieldStyle(.plain)
                    HStack {
                        Toggle(isOn: $draft.isPinned) { Label("Pinned", systemImage: "pin") }.toggleStyle(.button)
                        Toggle(isOn: $draft.isFavorite) { Label("Favorite", systemImage: "star") }.toggleStyle(.button)
                    }
                    tagRail
                    ForEach($draft.blocks) { $block in
                        LifeBoardKnowledgeBlockEditor(
                            block: $block,
                            allNotes: allNotes.filter { $0.id != draft.id },
                            attachments: attachments,
                            onDelete: { deleteBlock(block) }
                        )
                    }
                    addBlockMenu
                    Divider().padding(.vertical, 4)
                    relationships
                    attachmentsSection
                }
                .padding(20)
            }
            .navigationTitle("Note")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        draft.updatedAt = Date()
                        normalizeOrdinals()
                        onSave(draft)
                        dismiss()
                    }
                }
            }
            .fileImporter(isPresented: $showsFileImporter, allowedContentTypes: [.data, .image, .pdf, .plainText], allowsMultipleSelection: false) { result in
                if let url = try? result.get().first {
                    Task {
                        if let attachment = await onAttach(url) {
                            addAttachmentBlock(attachment)
                        }
                        await loadAttachments()
                    }
                }
            }
            .quickLookPreview($previewAttachmentURL)
            .sheet(isPresented: $showsLinkPicker) {
                NavigationStack {
                    List(allNotes.filter { $0.id != draft.id }) { note in
                        Button(note.title.isEmpty ? "Untitled" : note.title) { onConnect(note.id); showsLinkPicker = false }
                    }
                    .navigationTitle("Link a Note")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showsLinkPicker = false } } }
                }
            }
            .task { await loadAttachments() }
        }
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
                }
            }
            HStack {
                TextField("New tag", text: $newTag).textFieldStyle(.roundedBorder)
                Button("Add") {
                    Task {
                        if let tag = await onCreateTag(newTag) { draft.tagIDs.insert(tag.id); newTag = "" }
                    }
                }
                .disabled(newTag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private var addBlockMenu: some View {
        Menu {
            ForEach(LifeBoardKnowledgeBlockKind.allCases, id: \.self) { kind in
                Button(kindTitle(kind), systemImage: kindSymbol(kind)) { addBlock(kind) }
            }
        } label: {
            Label("Add block", systemImage: "plus.circle").frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered)
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
        draft.blocks.append(.init(noteID: draft.id, kind: kind, ordinal: draft.blocks.count))
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

private struct LifeBoardKnowledgeBlockEditor: View {
    @Binding var block: LifeBoardKnowledgeBlockValue
    let allNotes: [LifeBoardKnowledgeNoteValue]
    let attachments: [LifeBoardKnowledgeAttachmentValue]
    let onDelete: () -> Void
    @State private var expanded = true
    @State private var bookmarkIsLoading = false
    @State private var bookmarkError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Menu(block.kind.rawValue.capitalized) {
                    ForEach(LifeBoardKnowledgeBlockKind.allCases, id: \.self) { kind in
                        Button(kind.rawValue.capitalized) { block.kind = kind }
                    }
                }
                .font(.caption.weight(.medium))
                Spacer()
                Button(role: .destructive, action: onDelete) { Image(systemName: "trash") }
                    .accessibilityLabel("Delete block")
            }
            switch block.kind {
            case .divider:
                Divider().padding(.vertical, 8)
            case .checklist:
                HStack(alignment: .top) {
                    Toggle("Complete", isOn: $block.isChecked).labelsHidden()
                    TextField("Checklist item", text: $block.text, axis: .vertical)
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
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.separator.opacity(0.35)))
        .task(id: block.text) {
            guard block.kind == .bookmark else { return }
            do { try await Task.sleep(for: .milliseconds(350)) } catch { return }
            await refreshBookmark()
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
            .buttonStyle(.bordered)
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
        .buttonStyle(.bordered)
    }
}
