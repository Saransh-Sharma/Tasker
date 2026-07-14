import Foundation
import Observation
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
    var searchText = ""
    var errorMessage: String?

    let repository: any LifeBoardPhaseIIRepository

    init(repository: any LifeBoardPhaseIIRepository) { self.repository = repository }

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

    func addAttachment(noteID: UUID, url: URL) async {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        do {
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            guard data.count <= 20_000_000 else {
                errorMessage = "Files larger than 20 MB are not supported."
                return
            }
            try await repository.saveKnowledgeAttachment(.init(
                noteID: noteID,
                kind: url.pathExtension.lowercased(),
                fileName: url.lastPathComponent,
                payload: data
            ))
        } catch { errorMessage = error.localizedDescription }
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

    init(repository: any LifeBoardPhaseIIRepository) {
        _store = State(initialValue: LifeBoardKnowledgeStore(repository: repository))
    }

    var body: some View {
        let palette = LifeBoardDaypartTokens.palette(for: preferences.resolvedDaypart())
        VStack(spacing: 0) {
            sectionPicker
            switch section {
            case .library: library(palette: palette)
            case .graph:
                LifeBoardKnowledgeGraphView(notes: Array(store.notes.prefix(150)), links: store.links) { editingNote = $0 }
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
            onSave: saveNote,
            onCreateTag: createTag,
            onConnect: { destination in connect(noteID: note.id, destination: destination) },
            onDisconnect: disconnect,
            onAttach: { url in attach(noteID: note.id, url: url) }
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

    private func attach(noteID: UUID, url: URL) {
        Task { await store.addAttachment(noteID: noteID, url: url) }
    }

    private func library(palette: LifeBoardDaypartPalette) -> some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                HStack {
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
                        Button("New Note", systemImage: "square.and.pencil") { editingNote = store.createNote() }
                        Button("New Folder", systemImage: "folder.badge.plus") { draftName = ""; showsNewFolder = true }
                    } label: { Image(systemName: "plus.circle.fill").font(.title2).frame(width: 44, height: 44) }
                    .accessibilityLabel("Add note or folder")
                }
                TextField("Search notes", text: $store.searchText)
                    .textFieldStyle(.roundedBorder)
                if !store.folders.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Folders").font(.headline)
                        ForEach(store.folders) { folder in
                            Button {
                                if let note = store.notes.first(where: { $0.folderID == folder.id }) { editingNote = note }
                                else { editingNote = store.createNote(folderID: folder.id) }
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
                        }
                    }
                    .padding(16)
                    .lifeBoardPaperCard()
                }
                if store.notes.isEmpty {
                    ContentUnavailableView("No notes yet", systemImage: "note.text", description: Text("Create a note for an idea, reference, checklist, or plan."))
                        .padding(.top, 36)
                } else {
                    ForEach(store.notes) { note in
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
            Task { await store.createFolder(title: name) }
            draftName = ""
        }
        .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Button("Cancel", role: .cancel) { draftName = "" }
    }
}

private struct LifeBoardKnowledgeNoteEditor: View {
    @State private var draft: LifeBoardKnowledgeNoteValue
    @State private var attachments: [LifeBoardKnowledgeAttachmentValue] = []
    @State private var newTag = ""
    @State private var showsFileImporter = false
    @State private var showsLinkPicker = false
    @State private var isLoadingAttachments = false
    let allNotes: [LifeBoardKnowledgeNoteValue]
    let tags: [LifeBoardKnowledgeTagValue]
    let links: [LifeBoardKnowledgeLinkValue]
    let repository: any LifeBoardPhaseIIRepository
    let onSave: (LifeBoardKnowledgeNoteValue) -> Void
    let onCreateTag: (String) async -> LifeBoardKnowledgeTagValue?
    let onConnect: (UUID) -> Void
    let onDisconnect: (LifeBoardKnowledgeLinkValue) -> Void
    let onAttach: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    init(
        note: LifeBoardKnowledgeNoteValue,
        allNotes: [LifeBoardKnowledgeNoteValue],
        tags: [LifeBoardKnowledgeTagValue],
        links: [LifeBoardKnowledgeLinkValue],
        repository: any LifeBoardPhaseIIRepository,
        onSave: @escaping (LifeBoardKnowledgeNoteValue) -> Void,
        onCreateTag: @escaping (String) async -> LifeBoardKnowledgeTagValue?,
        onConnect: @escaping (UUID) -> Void,
        onDisconnect: @escaping (LifeBoardKnowledgeLinkValue) -> Void,
        onAttach: @escaping (URL) -> Void
    ) {
        _draft = State(initialValue: note)
        self.allNotes = allNotes
        self.tags = tags
        self.links = links
        self.repository = repository
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
                        LifeBoardKnowledgeBlockEditor(block: $block, onDelete: { deleteBlock(block.id) })
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
                if let url = try? result.get().first { onAttach(url); Task { await loadAttachments() } }
            }
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
                Label(attachment.fileName, systemImage: attachment.kind == "pdf" ? "doc.richtext" : "doc")
                    .lineLimit(1)
            }
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
    }

    private func addBlock(_ kind: LifeBoardKnowledgeBlockKind) {
        draft.blocks.append(.init(noteID: draft.id, kind: kind, ordinal: draft.blocks.count))
    }

    private func deleteBlock(_ id: UUID) {
        guard draft.blocks.count > 1 else { return }
        draft.blocks.removeAll { $0.id == id }
        normalizeOrdinals()
    }

    private func normalizeOrdinals() {
        for index in draft.blocks.indices { draft.blocks[index].ordinal = index }
    }

    private func loadAttachments() async {
        isLoadingAttachments = true
        attachments = (try? await repository.fetchKnowledgeAttachments(noteID: draft.id)) ?? []
        isLoadingAttachments = false
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
    let onDelete: () -> Void
    @State private var expanded = true

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
                TextEditor(text: $block.text).font(.system(.body, design: .monospaced)).frame(minHeight: 90)
                    .accessibilityHint("Enter rows on new lines and separate columns with commas")
            default:
                TextField(placeholder, text: $block.text, axis: .vertical).lineLimit(2...12)
            }
        }
        .padding(14)
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(.separator.opacity(0.35)))
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
}

private struct LifeBoardKnowledgeGraphView: View {
    let notes: [LifeBoardKnowledgeNoteValue]
    let links: [LifeBoardKnowledgeLinkValue]
    let onOpen: (LifeBoardKnowledgeNoteValue) -> Void
    @State private var scale = 1.0
    @State private var offset = CGSize.zero

    var body: some View {
        GeometryReader { proxy in
            if notes.isEmpty {
                ContentUnavailableView("No graph yet", systemImage: "point.3.connected.trianglepath.dotted", description: Text("Create and connect notes to form a graph."))
            } else {
                let positions = graphPositions(in: proxy.size)
                ZStack {
                    Canvas { context, _ in
                        for link in links {
                            guard let start = positions[link.sourceNoteID], let end = positions[link.destinationNoteID] else { continue }
                            var path = Path(); path.move(to: start); path.addLine(to: end)
                            context.stroke(path, with: .color(Color.primary.opacity(0.24)), lineWidth: 1.5)
                        }
                    }
                    ForEach(notes) { note in
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
                .accessibilityLabel("Knowledge graph with \(notes.count) notes and \(links.count) links")
            }
        }
        .padding(12)
    }

    private func graphPositions(in size: CGSize) -> [UUID: CGPoint] {
        let radius = max(70, min(size.width, size.height) * 0.34)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        return Dictionary(uniqueKeysWithValues: notes.enumerated().map { index, note in
            let angle = (Double(index) / Double(max(1, notes.count))) * .pi * 2 - .pi / 2
            let ring = index < 12 ? radius * 0.62 : radius
            return (note.id, CGPoint(x: center.x + cos(angle) * ring, y: center.y + sin(angle) * ring))
        })
    }
}
