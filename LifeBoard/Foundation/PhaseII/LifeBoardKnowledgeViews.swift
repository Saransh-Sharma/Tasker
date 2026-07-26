import Foundation
import Observation
import QuickLook
import SwiftUI
import UniformTypeIdentifiers

@MainActor
@Observable
final class LifeBoardKnowledgeStore {
    enum Layout: String, CaseIterable { case list, grid }

    private(set) var spaces: [LifeBoardKnowledgeSpaceValue] = []
    private(set) var folders: [LifeBoardKnowledgeFolderValue] = []
    private(set) var notes: [LifeBoardKnowledgeNoteValue] = []
    private(set) var tags: [LifeBoardKnowledgeTagValue] = []
    private(set) var links: [LifeBoardKnowledgeLinkValue] = []
    private(set) var smartCollections: [KnowledgeSmartCollectionValue] = []
    private(set) var isLoading = false
    var selectedSpaceID: UUID?
    var selectedFolderID: UUID?
    var selectedTagIDs: Set<UUID> = []
    var selectedCollection: KnowledgeNoteCollection = .all
    var sort: KnowledgeNoteSort = .updatedDescending
    var layout: Layout = .list
    var searchText = ""
    var errorMessage: String?
    var undoMessage: String?
    private var undoNote: LifeBoardKnowledgeNoteValue?

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
            async let noteValues = repository.fetchKnowledgeNotes(search: nil, spaceID: selectedSpaceID)
            async let tagValues = repository.fetchKnowledgeTags()
            async let linkValues = repository.fetchKnowledgeLinks()
            async let collectionValues = repository.fetchKnowledgeSmartCollections(spaceID: selectedSpaceID)
            (folders, notes, tags, links, smartCollections) = try await (
                folderValues, noteValues, tagValues, linkValues, collectionValues
            )
            try? await repository.pruneKnowledgeRecovery(now: Date())
        } catch { errorMessage = error.localizedDescription }
    }

    var visibleNotes: [LifeBoardKnowledgeNoteValue] {
        KnowledgeNoteQuery(
            collection: selectedCollection,
            spaceID: selectedSpaceID,
            folderID: selectedFolderID,
            tagIDs: selectedTagIDs,
            searchText: searchText,
            sort: sort
        ).apply(
            to: notes,
            linkedNoteIDs: Set(links.flatMap { [$0.sourceNoteID, $0.destinationNoteID] })
        )
    }

    var pinnedNotes: [LifeBoardKnowledgeNoteValue] {
        visibleNotes.filter(\.isPinned)
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
        template: KnowledgeNoteTemplate = KnowledgeNoteTemplate.library[0]
    ) -> LifeBoardKnowledgeNoteValue? {
        guard let selectedSpaceID else { return nil }
        let noteID = id ?? UUID()
        let blocks = template.blocks.enumerated().map { index, block in
            LifeBoardKnowledgeBlockValue(
                noteID: noteID,
                kind: block.kind,
                text: block.text,
                ordinal: index,
                createdAt: Date(),
                updatedAt: Date()
            )
        }
        return .init(
            id: noteID,
            spaceID: selectedSpaceID,
            folderID: folderID,
            title: template.id == "blank" ? "" : template.title,
            blocks: blocks,
            templateID: template.id,
            contentVersion: 1
        )
    }

    func save(_ note: LifeBoardKnowledgeNoteValue) async {
        do {
            try await repository.saveKnowledgeNote(note)
            try await reconcileBlockLinks(for: note)
            await load()
        } catch { errorMessage = error.localizedDescription }
    }

    private func reconcileBlockLinks(for note: LifeBoardKnowledgeNoteValue) async throws {
        let desired = Set(note.blocks.compactMap {
            KnowledgeBlockPayload.decode(from: $0).noteLink?.noteID
        }).subtracting([note.id])
        let generated = links.filter {
            $0.sourceNoteID == note.id && $0.label == "note-block"
        }
        let existingDestinations = Set(generated.map(\.destinationNoteID))
        for destination in desired.subtracting(existingDestinations) {
            try await repository.saveKnowledgeLink(.init(
                sourceNoteID: note.id,
                destinationNoteID: destination,
                label: "note-block"
            ))
        }
        for stale in generated where !desired.contains(stale.destinationNoteID) {
            try await repository.deleteKnowledgeLink(id: stale.id)
        }
    }

    func moveToTrash(_ note: LifeBoardKnowledgeNoteValue) async {
        var updated = note
        updated.state = .trashed
        updated.deletedAt = Date()
        updated.updatedAt = Date()
        undoNote = note
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
        undoNote = note
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
        guard let undoNote else { return }
        self.undoNote = nil
        undoMessage = nil
        await save(undoNote)
    }

    func deletePermanently(_ note: LifeBoardKnowledgeNoteValue) async {
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
    @State private var store: LifeBoardKnowledgeStore
    @State private var editingNote: LifeBoardKnowledgeNoteValue?
    @State private var confirmsDelete: LifeBoardKnowledgeNoteValue?
    @State private var showsNewSpace = false
    @State private var showsNewFolder = false
    @State private var showsTemplates = false
    @State private var draftName = ""
    @State private var hasOpenedInitialNote = false
    @Namespace private var noteTransition
    @Environment(LifeBoardPresentationPreferences.self) private var preferences
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let initialNoteID: UUID?
    private let initialDestination: NotesLibraryDestination?
    private let startsWithNewNote: Bool
    private let captureDraftID: UUID?

    init(
        repository: any LifeBoardPhaseIIRepository,
        initialFolderID: UUID? = nil,
        initialNoteID: UUID? = nil,
        initialDestination: NotesLibraryDestination? = nil,
        startsWithNewNote: Bool = false,
        captureDraftID: UUID? = nil
    ) {
        _store = State(initialValue: LifeBoardKnowledgeStore(
            repository: repository,
            initialFolderID: initialFolderID
        ))
        self.initialNoteID = initialNoteID
        self.initialDestination = initialDestination
        self.startsWithNewNote = startsWithNewNote
        self.captureDraftID = captureDraftID
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
            if let message = store.undoMessage {
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
            }

            HStack(spacing: 10) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    TextField("Search titles, text, tags, and attachments", text: $store.searchText)
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .accessibilityIdentifier("notes.search")
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
                        Label(collection.label, systemImage: collection.symbol)
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 13)
                            .frame(minHeight: 40)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(store.selectedCollection == collection ? Color.primary : Color.secondary)
                    .background {
                        if store.selectedCollection == collection {
                            Capsule().fill(Color.primary.opacity(0.09))
                        }
                    }
                    .accessibilityAddTraits(store.selectedCollection == collection ? .isSelected : [])
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
        Button { editingNote = note } label: {
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
        Button { editingNote = note } label: {
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
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: note.id, in: noteTransition)
        .contextMenu { noteActions(note) }
        .accessibilityIdentifier("notes.note.\(note.id.uuidString)")
        .accessibilityLabel("\(note.displayTitle), edited \(note.updatedAt.formatted(.relative(presentation: .named)))")
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

    private func noteEditor(_ note: LifeBoardKnowledgeNoteValue) -> some View {
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
            onAttach: { url in await store.addAttachment(noteID: note.id, url: url) }
        )
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
            editingNote = store.createNote(id: captureDraftID)
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
    @Environment(\.dismiss) private var dismiss

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
        onAttach: @escaping (URL) async -> LifeBoardKnowledgeAttachmentValue?
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
            .background(Color(uiColor: .systemBackground))
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
                        Button("Attach a file", systemImage: "paperclip") { showsFileImporter = true }
                        Button("Version history", systemImage: "clock.arrow.circlepath") { showsHistory = true }
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
            .sheet(isPresented: $showsLinkPicker) {
                NavigationStack {
                    List(allNotes.filter { $0.id != draft.id }) { note in
                        Button(note.title.isEmpty ? "Untitled" : note.title) { onConnect(note.id); showsLinkPicker = false }
                    }
                    .navigationTitle("Link a Note")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showsLinkPicker = false } } }
                }
            }
            .sheet(isPresented: $showsHistory) {
                LifeBoardNoteHistoryView(
                    revisions: revisions,
                    onRestore: restoreRevision,
                    onDismiss: { showsHistory = false }
                )
            }
            .task {
                await restoreDraftIfNeeded()
                await loadAttachments()
                revisions = (try? await repository.fetchKnowledgeRevisions(noteID: draft.id)) ?? []
                if !draft.isMeaningful { titleIsFocused = true }
            }
            .onChange(of: draft) { _, _ in scheduleAutosave() }
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
            HStack(spacing: 4) {
                Menu {
                    ForEach(LifeBoardKnowledgeBlockKind.allCases, id: \.self) { kind in
                        Button(kindTitle(kind), systemImage: kindSymbol(kind)) { addBlock(kind) }
                    }
                } label: {
                    Label("Insert", systemImage: "plus")
                }
                commandButton("Checklist", symbol: "checklist") { addBlock(.checklist) }
                commandButton("Photo or file", symbol: "paperclip") { showsFileImporter = true }
                commandButton("Link note", symbol: "link") { showsLinkPicker = true }
                Spacer(minLength: 0)
                Menu {
                    Button("Paragraph", systemImage: "text.alignleft") { addBlock(.paragraph) }
                    Button("Heading", systemImage: "textformat.size") { addBlock(.heading2) }
                    Button("Quote", systemImage: "quote.opening") { addBlock(.quote) }
                    Button("Code", systemImage: "chevron.left.forwardslash.chevron.right") { addBlock(.code) }
                    Button("Table", systemImage: "tablecells") { addBlock(.table) }
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

    private var noteDateLine: String {
        let date = draft.updatedAt.formatted(date: .abbreviated, time: .shortened)
        let count = draft.plainText.split(whereSeparator: \.isWhitespace).count
        return count == 0 ? "Edited \(date)" : "\(count) words  •  Edited \(date)"
    }

    private var markdownExport: String {
        var lines = ["# \(draft.displayTitle)", ""]
        for block in draft.blocks {
            switch block.kind {
            case .heading1: lines.append("# \(block.text)")
            case .heading2: lines.append("## \(block.text)")
            case .bulletedList: lines.append("- \(block.text)")
            case .numberedList: lines.append("1. \(block.text)")
            case .checklist: lines.append("- [\(block.isChecked ? "x" : " ")] \(block.text)")
            case .quote: lines.append("> \(block.text)")
            case .code: lines.append("```\n\(block.text)\n```")
            case .divider: lines.append("---")
            case .bookmark: lines.append("[\(block.text)](\(block.text))")
            case .noteLink:
                let title = KnowledgeBlockPayload.decode(from: block).noteLink?.cachedTitle ?? "Linked note"
                lines.append("[[\(title)]]")
            default: lines.append(block.text)
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    private var originalWasMeaningful: Bool {
        guard let originalSnapshot,
              let note = try? JSONDecoder().decode(LifeBoardKnowledgeNoteValue.self, from: originalSnapshot) else {
            return false
        }
        return note.isMeaningful
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
        let imported = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        for line in imported where !line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let kind: LifeBoardKnowledgeBlockKind
            let content: String
            if line.hasPrefix("## ") {
                kind = .heading2
                content = String(line.dropFirst(3))
            } else if line.hasPrefix("# ") {
                kind = .heading1
                content = String(line.dropFirst(2))
            } else if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") {
                kind = .checklist
                content = String(line.dropFirst(6))
            } else if line.hasPrefix("- ") {
                kind = .bulletedList
                content = String(line.dropFirst(2))
            } else if line.hasPrefix("> ") {
                kind = .quote
                content = String(line.dropFirst(2))
            } else {
                kind = .paragraph
                content = line
            }
            draft.blocks.append(.init(
                noteID: draft.id,
                kind: kind,
                text: content,
                ordinal: draft.blocks.count,
                createdAt: Date(),
                updatedAt: Date()
            ))
        }
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
