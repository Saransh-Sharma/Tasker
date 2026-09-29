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

public struct KnowledgeModuleView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var store: KnowledgeStore
    @State private var editingNote: KnowledgeNoteValue?
    @State private var confirmsDelete: KnowledgeNoteValue?
    @State private var showsNewSpace = false
    @State private var showsNewFolder = false
    @State private var showsTemplates = false
    @State private var showsSmartCollectionBuilder = false
    @State private var draftName = ""
    @State private var hasOpenedInitialNote = false
    @State private var isSelecting = false
    @State private var selectedNoteIDs: Set<UUID> = []
    @State private var pinnedDropTargetID: UUID?
    // The module's own width, not the window's: the capture sheet hosts this
    // view in a form-sized sheet on a wide iPad, where the environment still
    // says `.padExpanded` but there is no room for a second pane.
    @State private var availableWidth: CGFloat = 0
    @Namespace private var noteTransition
    @Environment(\.lifeboardLayoutClass) private var layoutClass
    // Light-only `palette(for:)` painted light-appearance ink (#6F6252)
    // on the dark canvas; the palette has to follow the appearance.
    @Environment(\.colorScheme) private var colorScheme

    private let initialNoteID: UUID?
    private let initialDestination: NotesLibraryDestination?
    private let startsWithNewNote: Bool
    private let captureDraftID: UUID?
    private let initialText: String?
    private let resolveDaypart: @Sendable () -> ResolvedDaypart

    public init(
        repository: any KnowledgeRepository,
        initialFolderID: UUID? = nil,
        initialNoteID: UUID? = nil,
        initialDestination: NotesLibraryDestination? = nil,
        startsWithNewNote: Bool = false,
        captureDraftID: UUID? = nil,
        initialText: String? = nil,
        resolveDaypart: @escaping @Sendable () -> ResolvedDaypart = {
            switch Calendar.current.component(.hour, from: Date()) {
            case 5..<12: .morning
            case 12..<17: .afternoon
            case 17..<21: .evening
            default: .night
            }
        }
    ) {
        _store = State(initialValue: KnowledgeStore(
            repository: repository,
            initialFolderID: initialFolderID
        ))
        self.initialNoteID = initialNoteID
        self.initialDestination = initialDestination
        self.startsWithNewNote = startsWithNewNote
        self.captureDraftID = captureDraftID
        self.initialText = initialText
        self.resolveDaypart = resolveDaypart
    }

    public var body: some View {
        // No NavigationSplitView: every host (the shell's routes, Track, the
        // capture sheet) already pushes this inside a NavigationStack, and a
        // split nested in a stack showed the list twice and still opened notes
        // in a sheet. Wide layouts get a plain two-pane HStack instead.
        Group {
            if usesNotePane {
                HStack(spacing: 0) {
                    notesWorkspace
                        .frame(width: libraryPaneWidth)
                    Divider()
                        .ignoresSafeArea(edges: .bottom)
                    notePane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                notesWorkspace
            }
        }
        .onGeometryChange(for: CGFloat.self) { proxy in
            proxy.size.width
        } action: { width in
            availableWidth = width
        }
        .onChange(of: isSelecting) { _, selecting in
            // Batch actions save whole notes; closing the pane first lets its
            // editor flush before a batch can overwrite (or be overwritten by)
            // the same note.
            if selecting, paneNote != nil { editingNote = nil }
        }
        .task {
            await store.load()
            if let initialDestination {
                store.restore(initialDestination)
            }
            openInitialNoteIfNeeded()
        }
        .onChange(of: store.selectedSpaceID) { _, _ in Task { await store.load() } }
        .sheet(item: sheetNote) { note in
            noteEditor(note)
                .navigationTransition(.zoom(sourceID: note.id, in: noteTransition))
                .presentationDetents([.large])
                // A writing surface, not a form: on iPad `.large` alone gave a
                // form-width card; `.page` gives the editor a page's width.
                .presentationSizing(.page)
                .presentationDragIndicator(.hidden)
        }
        .sheet(isPresented: $showsTemplates) {
            templatePicker
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showsSmartCollectionBuilder) {
            SmartCollectionBuilder(
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
        .alert("New space", isPresented: $showsNewSpace, actions: newSpaceActions)
        .alert("New folder", isPresented: $showsNewFolder, actions: newFolderActions)
        // Only a permanent delete asks first. Moving to Trash is reversible,
        // so it runs at once and the receipt below offers Undo.
        .alert(
            "Delete permanently?",
            isPresented: Binding(
                get: { confirmsDelete != nil },
                set: { if !$0 { confirmsDelete = nil } }
            )
        ) {
            Button("Delete permanently", role: .destructive) {
                guard let note = confirmsDelete else { return }
                Task { await store.deletePermanently(note) }
                confirmsDelete = nil
            }
            Button("Cancel", role: .cancel) { confirmsDelete = nil }
        } message: {
            Text("“\(confirmsDelete?.displayTitle ?? "This note")” and its attachments are deleted for good. This can’t be undone.")
        }
        .alert("Couldn’t finish that", isPresented: Binding(
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
                // Clay's transient-overlay depth: DESIGN.md allows one glass
                // hero per screen, and here that is the batch action bar.
                .lifeBoardClaySurface(.floating, cornerRadius: Radius.pill)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .lifeBoardMotion(.selection, value: store.undoMessage)
    }

    private var notesWorkspace: some View {
        let palette = DaypartTokens.appearancePalette(for: resolveDaypart(), colorScheme: colorScheme)
        return VStack(spacing: 0) {
            notesHeader(palette: palette)
            if store.selectedCollection == .connections {
                KnowledgeGraphView(
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

    private func notesHeader(palette: DaypartPalette) -> some View {
        VStack(spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(collectionTitle)
                        .lifeboardFont(.heroDisplay)
                        .foregroundStyle(palette.color(for: .foreground))
                    if let collectionSubtitle {
                        Text(collectionSubtitle)
                            .font(.subheadline)
                            .foregroundStyle(palette.color(for: .foregroundSecondary))
                    }
                }
                Spacer()
                Menu {
                    Button("New note", systemImage: "square.and.pencil") {
                        editingNote = store.createNote(folderID: store.selectedFolderID)
                    }
                    Button("Use a template", systemImage: "rectangle.stack.badge.plus") {
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
                        .lifeboardFont(.title2)
                        .frame(width: 46, height: 46)
                }
                // Ink on a solid clay disc: it sits on the celestial disc, where
                // the amber tint read poorly on the gold sun and a second glass
                // control would break the one-hero rule.
                .foregroundStyle(Color(SemanticColorTokens.inkPrimary))
                .lifeBoardClaySurface(.raised, cornerRadius: Radius.pill)
                .accessibilityLabel("New")
                .accessibilityIdentifier("notes.create")
                if !store.visibleNotes.isEmpty {
                    Button(isSelecting ? "Done" : "Select") {
                        withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                            isSelecting.toggle()
                            if !isSelecting { selectedNoteIDs.removeAll() }
                        }
                    }
                    // On its own surface: as bare tinted text it sat on the
                    // celestial disc, amber on gold in dark appearance.
                    .buttonStyle(.lifeBoardChip)
                    .fixedSize()
                    .accessibilityIdentifier("notes.select")
                }
            }

            HStack(spacing: 12) {
                HStack(spacing: 9) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                    TextField("Search notes", text: $store.searchText, prompt: Text("Search notes").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                        .textFieldStyle(.plain)
                        .submitLabel(.search)
                        .accessibilityIdentifier("notes.search")
                        .onChange(of: store.searchText) { _, _ in store.search() }
                    if !store.searchText.isEmpty {
                        Button {
                            store.searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clear search")
                    }
                }
                .padding(.horizontal, 14)
                .frame(minHeight: 46)
                // An input is carved into the page, like the graph's search.
                .lifeBoardClaySurface(.well, cornerRadius: Radius.pill)

                Menu {
                    Picker("Sort notes", selection: $store.sort) {
                        Label("Last edited", systemImage: "clock").tag(KnowledgeNoteSort.updatedDescending)
                        Label("Date created", systemImage: "calendar").tag(KnowledgeNoteSort.createdDescending)
                        Label("Title", systemImage: "textformat").tag(KnowledgeNoteSort.titleAscending)
                    }
                    Divider()
                    Picker("Layout", selection: $store.layout) {
                        Label("List", systemImage: "list.bullet").tag(KnowledgeStore.Layout.list)
                        Label("Grid", systemImage: "square.grid.2x2").tag(KnowledgeStore.Layout.grid)
                    }
                    if layoutClass.isPad {
                        browseSections
                    }
                } label: {
                    Image(systemName: store.layout == .list ? "line.3.horizontal.decrease" : "square.grid.2x2")
                        .frame(width: 46, height: 46)
                }
                .lifeBoardClaySurface(.raised, cornerRadius: Radius.pill)
                .accessibilityLabel("Sort and view")
            }

            collectionRail
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 14)
    }

    private var collectionRail: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(railCollections) { collection in
                    Button {
                        withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
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
                                ? SemanticColorTokens.inkPrimary
                                : SemanticColorTokens.inkSecondary))
                            .padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .lifeBoardClaySurface(
                                store.selectedCollection == collection ? .raised : .well,
                                cornerRadius: Radius.pill
                            )
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(store.selectedCollection == collection ? [.isButton, .isSelected] : .isButton)
                }
            }
        }
    }

    // MARK: Two-pane layout

    /// Whether the module has room for the editor beside the library. Both
    /// must hold: a pad-class window, and a module at least as wide as the
    /// pad-regular floor (see `availableWidth`).
    private var usesNotePane: Bool {
        layoutClass.isPad && availableWidth >= LayoutResolver.padCompactUpperBound
    }

    /// Wide enough for the grid's two columns, narrow enough that the editor
    /// keeps the larger share of a pad-regular window.
    private var libraryPaneWidth: CGFloat {
        min(420, max(320, availableWidth * 0.38))
    }

    /// The note the trailing pane shows. Locked notes stay in a sheet: their
    /// editor owns a privacy shield and an authentication flow that assume a
    /// presentation of their own.
    private var paneNote: KnowledgeNoteValue? {
        guard usesNotePane, let note = editingNote,
              note.resolvedLockPolicy != .deviceAuthentication else { return nil }
        return note
    }

    /// `editingNote` stays the one record of "the open note", so every opener
    /// (rows, templates, the graph, the initial route) works at any width; this
    /// only decides whether that note is presented as a sheet.
    private var sheetNote: Binding<KnowledgeNoteValue?> {
        Binding(
            get: { paneNote == nil ? editingNote : nil },
            set: { editingNote = $0 }
        )
    }

    @ViewBuilder
    private var notePane: some View {
        if let note = paneNote {
            noteEditor(note, hosting: .pane(onClose: { editingNote = nil }))
                // A fresh identity per note, so the draft, autosave and
                // attachments restart instead of carrying over from the last.
                .id(note.id)
        } else {
            ContentUnavailableView {
                Label("No note open", systemImage: "note.text")
            } description: {
                Text("Pick a note from the list.")
            } actions: {
                Button("New note") {
                    editingNote = store.createNote(folderID: store.selectedFolderID)
                }
                .buttonStyle(.lifeBoardPrimaryCompact)
            }
            .accessibilityIdentifier("notes.pane.empty")
        }
    }

    /// What the removed sidebar held beyond the rail: smart collections and
    /// tags. Pad-only, so the phone menu is unchanged.
    @ViewBuilder
    private var browseSections: some View {
        if !store.smartCollections.isEmpty || !store.tags.isEmpty {
            Divider()
        }
        if !store.smartCollections.isEmpty {
            Menu("Smart collections", systemImage: "sparkle.magnifyingglass") {
                ForEach(store.smartCollections) { collection in
                    Button {
                        store.restore(.library(collection.query))
                    } label: {
                        Label(collection.name, systemImage: collection.symbol)
                    }
                }
            }
        }
        if !store.tags.isEmpty {
            Menu("Tags", systemImage: "number") {
                ForEach(store.tags.prefix(12)) { tag in
                    Button {
                        store.restore(.tag(tag.id))
                    } label: {
                        Label(tag.name, systemImage: store.selectedTagIDs.contains(tag.id) ? "checkmark" : "number")
                    }
                }
            }
        }
    }

    private func library(palette: DaypartPalette) -> some View {
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
    private func folderStrip(palette: DaypartPalette) -> some View {
        let visibleFolders = store.folders.filter { $0.parentFolderID == store.selectedFolderID }
        if store.selectedFolderID != nil || !visibleFolders.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
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
                                .foregroundStyle(Color.lifeboard(.textTertiary))
                            Text(folder.title)
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .foregroundStyle(palette.color(for: .foregroundSecondary))
                }
                if !visibleFolders.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(visibleFolders) { folder in
                                Button {
                                    withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
                                        store.selectedFolderID = folder.id
                                    }
                                } label: {
                                    HStack(spacing: 9) {
                                        Image(systemName: "folder.fill")
                                            .foregroundStyle(.tint)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(folder.title)
                                                .font(.subheadline.weight(.semibold))
                                            Text("^[\(store.notes.filter { $0.folderID == folder.id && $0.resolvedState == .active }.count) note](inflect: true)")
                                                .font(.caption2)
                                                .foregroundStyle(Color.lifeboard(.textSecondary))
                                        }
                                    }
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 58)
                                    .background(Color.lifeboard(.bgElevated).opacity(0.7), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
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

    private func pinnedSection(palette: DaypartPalette) -> some View {
        VStack(alignment: .leading, spacing: 12) {
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
                                withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
                                    pinnedDropTargetID = targeted ? note.id : nil
                                }
                            }
                    }
                }
            }
        }
    }

    private func notesSection(palette: DaypartPalette) -> some View {
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
                .foregroundStyle(Color.lifeboard(.textSecondary))
            Spacer()
        }
    }


    private func selectionMark(for note: KnowledgeNoteValue) -> some View {
        Image(systemName: selectedNoteIDs.contains(note.id) ? "checkmark.circle.fill" : "circle")
            .font(.title3.weight(.semibold))
            .foregroundStyle(selectedNoteIDs.contains(note.id) ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.textSecondary))
            .symbolEffect(.bounce, value: selectedNoteIDs.contains(note.id))
            .accessibilityLabel(selectedNoteIDs.contains(note.id) ? "Selected" : "Not selected")
    }

    private var batchActionBar: some View {
        HStack(spacing: 4) {
            Text("\(selectedNoteIDs.count) selected")
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .padding(.leading, 12)
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
        .padding(.horizontal, 12)
        .frame(maxWidth: 660, minHeight: 54)
        .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
    }

    private func batchButton(
        _ label: String,
        symbol: String,
        role: ButtonRole? = nil,
        operation: @escaping () -> KnowledgeStore.BatchOperation
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
    private func noteKindMarks(_ note: KnowledgeNoteValue) -> some View {
        HStack(spacing: 8) {
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
                .lifeboardFont(.heroDisplay)
                .foregroundStyle(.tint)
            Text(emptyTitle)
                .lifeboardFont(.sectionTitle)
            if let emptyMessage {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 330)
            }
            if store.selectedCollection != .trash && store.selectedCollection != .archived {
                // A blank note, straight away; templates stay in the + menu.
                Button("New note") {
                    editingNote = store.createNote(folderID: store.selectedFolderID)
                }
                    .buttonStyle(.lifeBoardPrimaryCompact)
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
                                    .background(Color.lifeboard(.accentPrimary).opacity(0.10), in: RoundedRectangle(cornerRadius: 13))
                                Text(template.title)
                                    .font(.headline)
                                    .foregroundStyle(Color.lifeboard(.textPrimary))
                                Text(template.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(Color.lifeboard(.textSecondary))
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
            .navigationTitle("Choose a template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showsTemplates = false }
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
    }

    @ViewBuilder
    private func noteEditor(
        _ note: KnowledgeNoteValue,
        hosting: KnowledgeNoteEditor.Hosting = .sheet
    ) -> some View {
        if note.resolvedLockPolicy == .deviceAuthentication {
            LockedKnowledgeNoteEditor(
                placeholder: note,
                onUnlock: { try await store.unlock(note) },
                onSave: { try await store.saveLocked($0) }
            )
        } else {
            KnowledgeNoteEditor(
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
                },
                hosting: hosting
            )
        }
    }

    @ViewBuilder
    private func noteActions(_ note: KnowledgeNoteValue) -> some View {
        // The pane's editor autosaves its whole draft, so a list-side change
        // to the note it has open would be overwritten by the next autosave
        // (an archived note would come back active). A sheet covered the list,
        // so this only arises beside the pane; close the note to change it.
        let isOpenInPane = paneNote?.id == note.id
        if store.selectedCollection == .trash {
            Group {
                Button("Restore", systemImage: "arrow.uturn.backward") { Task { await store.restore(note) } }
                Button("Delete permanently", systemImage: "trash.slash", role: .destructive) { confirmsDelete = note }
            }
            .disabled(isOpenInPane)
        } else {
            Group {
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
                if note.resolvedLockPolicy == .unlocked, KnowledgeFeatureFlags.securityEnabled {
                    Button("Lock note", systemImage: "lock") { Task { await store.lock(note) } }
                }
            }
            .disabled(isOpenInPane)
            Button("Duplicate", systemImage: "plus.square.on.square") { Task { await store.duplicate(note) } }
            Group {
                noteMoveMenu(note)
                Button("Archive", systemImage: "archivebox") { Task { await store.archive(note) } }
                Button("Move to Trash", systemImage: "trash", role: .destructive) { Task { await store.moveToTrash(note) } }
            }
            .disabled(isOpenInPane)
        }
    }

    @ViewBuilder private func newSpaceActions() -> some View {
        TextField("Name", text: $draftName, prompt: Text("Name").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
        Button("Save") {
            let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { await store.createSpace(title: name) }
            draftName = ""
        }
        .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Button("Cancel", role: .cancel) { draftName = "" }
    }

    @ViewBuilder private func newFolderActions() -> some View {
        TextField("Name", text: $draftName, prompt: Text("Name").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
        Button("Save") {
            let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
            Task { await store.createFolder(title: name, parentID: store.selectedFolderID) }
            draftName = ""
        }
        .disabled(draftName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        Button("Cancel", role: .cancel) { draftName = "" }
    }

    @ViewBuilder private func folderMoveMenu(_ folder: KnowledgeFolderValue) -> some View {
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

    @ViewBuilder private func noteMoveMenu(_ note: KnowledgeNoteValue) -> some View {
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

    private var primaryCollections: [KnowledgeNoteCollection] {
        [.all, .pinned, .favorites, .recent, .unfiled, .checklists, .attachments, .linked]
    }

    /// The pad rail also carries the destinations the removed sidebar held, so
    /// Connections, Archive and Trash stay one tap away. The phone rail is
    /// unchanged.
    private var railCollections: [KnowledgeNoteCollection] {
        layoutClass.isPad ? primaryCollections + [.connections, .archived, .trash] : primaryCollections
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

    /// A fact the title doesn't already say, or nothing.
    private var collectionSubtitle: String? {
        if !store.searchText.isEmpty {
            let count = store.visibleNotes.count
            return count == 1 ? String(localized: "1 result") : String(localized: "\(count) results")
        }
        return switch store.selectedCollection {
        case .recent: String(localized: "Edited in the last 14 days")
        case .unfiled: String(localized: "Unfiled notes")
        case .checklists: String(localized: "Notes with checklists")
        case .attachments: String(localized: "Notes with files or images")
        case .linked: String(localized: "Notes with links")
        case .trash: String(localized: "Deleted after 30 days")
        case .all, .pinned, .favorites, .archived, .connections: nil
        }
    }

    private var emptyTitle: String {
        return switch store.selectedCollection {
        case .trash: String(localized: "Trash is empty")
        case .archived: String(localized: "Nothing archived")
        default: store.searchText.isEmpty ? String(localized: "No notes yet") : String(localized: "No results")
        }
    }

    private var emptyMessage: String? {
        if !store.searchText.isEmpty { return String(localized: "Try another search.") }
        if store.selectedCollection == .trash { return String(localized: "Deleted notes stay here for 30 days.") }
        return nil
    }
}

// The note cell builders, in an extension so `KnowledgeModuleView` itself stays
// under the file-size ratchet's per-type ceiling — the metric that predicts the
// `-Onone` launch crash. Same file, so `private` members remain visible.
private extension KnowledgeModuleView {
    func noteCard(
        _ note: KnowledgeNoteValue,
        palette: DaypartPalette,
        compact: Bool
    ) -> some View {
        Button { openOrSelect(note) } label: {
            VStack(alignment: .leading, spacing: 12) {
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
                            .foregroundStyle(Color(SemanticColorTokens.foundationSunInk))
                    }
                }
                Text(note.displayTitle)
                    .lifeboardFont(.headline)
                    .foregroundStyle(palette.color(for: .foreground))
                    .lineLimit(2)
                Text(note.plainText.isEmpty ? String(localized: "Empty note") : note.plainText)
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
                .foregroundStyle(Color.lifeboard(.textSecondary))
            }
            .frame(maxWidth: .infinity, minHeight: compact ? 154 : 176, alignment: .topLeading)
            .padding(16)
            .lifeBoardPaperCard()
            .overlay {
                // Beside the pane, the list is the only place that says which
                // note the editor is showing.
                if paneNote?.id == note.id {
                    RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
                        .strokeBorder(Color.lifeboard(.accentPrimary), lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                if isSelecting {
                    selectionMark(for: note)
                        .padding(12)
                }
            }
        }
        .buttonStyle(.plain)
        .lifeBoardScrollEntrance()
        .matchedTransitionSource(id: note.id, in: noteTransition)
        .contextMenu { noteActions(note) }
        .accessibilityIdentifier("notes.note.\(note.id.uuidString)")
        .accessibilityLabel("\(note.displayTitle), edited \(note.updatedAt.formatted(.relative(presentation: .named)))")
        .accessibilityAddTraits(paneNote?.id == note.id ? .isSelected : [])
    }

    func noteRow(
        _ note: KnowledgeNoteValue,
        palette: DaypartPalette
    ) -> some View {
        Button { openOrSelect(note) } label: {
            HStack(spacing: 14) {
                RoundedRectangle(cornerRadius: Radius.field, style: .continuous)
                    .fill(Color.lifeboard(.accentPrimary).opacity(0.10))
                    .frame(width: 46, height: 54)
                    .overlay {
                        Image(systemName: note.blocks.contains(where: { $0.kind == .checklist }) ? "checklist" : "note.text")
                            .foregroundStyle(.tint)
                    }
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        if note.isPinned { Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.tint) }
                        Text(note.displayTitle)
                            .font(.headline)
                            .foregroundStyle(palette.color(for: .foreground))
                            .lineLimit(1)
                        if note.isFavorite { Image(systemName: "star.fill").font(.caption2).foregroundStyle(Color(SemanticColorTokens.foundationSunInk)) }
                    }
                    Text(note.plainText.isEmpty ? String(localized: "Empty note") : note.plainText)
                        .font(.subheadline)
                        .foregroundStyle(palette.color(for: .foregroundSecondary))
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(note.updatedAt.formatted(.relative(presentation: .named)))
                        if !note.tagIDs.isEmpty { Text("•  ^[\(note.tagIDs.count) tag](inflect: true)") }
                    }
                    .font(.caption2)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Color.lifeboard(.textTertiary))
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 82)
            // `Radius.row` rather than 19, which is off DESIGN.md's shape
            // vocabulary; the open-note ring below has to trace the same shape.
            .background(
                RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                    .fill(Color.lifeboard(.surfaceSecondary).opacity(0.84))
            )
            .overlay {
                if paneNote?.id == note.id {
                    RoundedRectangle(cornerRadius: Radius.row, style: .continuous)
                        .strokeBorder(Color.lifeboard(.accentPrimary), lineWidth: 2)
                }
            }
            .overlay(alignment: .trailing) {
                if isSelecting {
                    selectionMark(for: note)
                        .padding(.trailing, 14)
                }
            }
        }
        .buttonStyle(.plain)
        .lifeBoardScrollEntrance()
        .matchedTransitionSource(id: note.id, in: noteTransition)
        .contextMenu { noteActions(note) }
        .accessibilityIdentifier("notes.note.\(note.id.uuidString)")
        .accessibilityLabel("\(note.displayTitle), edited \(note.updatedAt.formatted(.relative(presentation: .named)))")
        .accessibilityAddTraits(paneNote?.id == note.id ? .isSelected : [])
    }

    func openOrSelect(_ note: KnowledgeNoteValue) {
        if isSelecting {
            if !selectedNoteIDs.insert(note.id).inserted {
                selectedNoteIDs.remove(note.id)
            }
        } else {
            editingNote = note
        }
    }
}

private extension KnowledgeNoteCollection {
    var label: String {
        switch self {
        case .all: "All notes"
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

struct KnowledgeNoteEditor: View {
    /// Where the editor lives. A sheet owns its NavigationStack and dismisses
    /// itself. A pane sits beside the library inside the shell's stack, so it
    /// must not nest a second stack, its controls cannot go in the shell's
    /// toolbar, and `dismiss()` there would pop the whole Notes screen.
    enum Hosting {
        case sheet
        case pane(onClose: () -> Void)
    }

    private enum SaveState: Equatable {
        case idle
        case saving
        case saved(Date)
        case failed
    }

    @State private var draft: KnowledgeNoteValue
    @State private var originalSnapshot: Data?
    @State private var attachments: [KnowledgeAttachmentValue] = []
    @State private var newTag = ""
    @State private var showsTagComposer = false
    @State private var showsFileImporter = false
    @State private var showsLinkPicker = false
    @State private var showsHistory = false
    @State private var isLoadingAttachments = false
    @State private var previewAttachmentURL: URL?
    @State private var attachmentFailures: Set<UUID> = []
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Deleting an attachment removes the file for good, so it asks first.
    @State private var attachmentPendingDeletion: KnowledgeAttachmentValue?
    @State private var attachmentDeleteFailed = false
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
    let allNotes: [KnowledgeNoteValue]
    let tags: [KnowledgeTagValue]
    let links: [KnowledgeLinkValue]
    let repository: any KnowledgeRepository
    let attachmentFiles: any KnowledgeAttachmentFileRepository
    let onSave: (KnowledgeNoteValue) async -> Void
    let onCreateTag: (String) async -> KnowledgeTagValue?
    let onConnect: (UUID) -> Void
    let onDisconnect: (KnowledgeLinkValue) -> Void
    let onAttach: (URL) async -> KnowledgeAttachmentValue?
    let onAttachData: (Data, String, String?, String) async -> KnowledgeAttachmentValue?
    let hosting: Hosting
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(
        note: KnowledgeNoteValue,
        allNotes: [KnowledgeNoteValue],
        tags: [KnowledgeTagValue],
        links: [KnowledgeLinkValue],
        repository: any KnowledgeRepository,
        attachmentFiles: any KnowledgeAttachmentFileRepository,
        onSave: @escaping (KnowledgeNoteValue) async -> Void,
        onCreateTag: @escaping (String) async -> KnowledgeTagValue?,
        onConnect: @escaping (UUID) -> Void,
        onDisconnect: @escaping (KnowledgeLinkValue) -> Void,
        onAttach: @escaping (URL) async -> KnowledgeAttachmentValue?,
        onAttachData: @escaping (Data, String, String?, String) async -> KnowledgeAttachmentValue?,
        hosting: Hosting = .sheet
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
        self.hosting = hosting
    }

    var body: some View {
        switch hosting {
        case .sheet:
            NavigationStack {
                editorSurface
                    .navigationTitle("")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            closeButton(side: 36)
                                .keyboardShortcut(.cancelAction)
                        }
                        ToolbarItem(placement: .principal) {
                            saveStatus
                        }
                        ToolbarItemGroup(placement: .confirmationAction) {
                            pinButton()
                            favoriteButton()
                            moreMenu()
                        }
                    }
            }
            .escapeCancels { Task { await flushAndClose() } }
            .modifier(attachmentDeletionConfirmation)
        case .pane:
            VStack(spacing: 0) {
                paneHeader
                Divider()
                editorSurface
            }
            .modifier(attachmentDeletionConfirmation)
        }
    }

    private var attachmentDeletionConfirmation: KnowledgeAttachmentDeletionConfirmation {
        KnowledgeAttachmentDeletionConfirmation(
            pending: $attachmentPendingDeletion,
            failed: $attachmentDeleteFailed,
            onDelete: { attachment in Task { await deleteAttachment(attachment) } }
        )
    }

    /// The sheet's toolbar, as a row: the pane has no navigation bar of its own.
    private var paneHeader: some View {
        HStack(spacing: 8) {
            closeButton(side: 44)
            saveStatus
            Spacer(minLength: 0)
            pinButton(side: 44)
            favoriteButton(side: 44)
            moreMenu(side: 44)
        }
        .padding(.horizontal, 8)
        .background { GrainedCanvas() }
    }

    private func closeButton(side: CGFloat) -> some View {
        Button {
            Task {
                await flushAndClose()
            }
        } label: {
            Image(systemName: "xmark")
                .frame(width: side, height: side)
        }
        .accessibilityLabel("Close note")
    }

    // `side` is nil in the sheet's toolbar, which sizes its own items; the
    // pane's header row needs the 44pt hit target set explicitly.
    private func pinButton(side: CGFloat? = nil) -> some View {
        Button {
            draft.isPinned.toggle()
        } label: {
            Image(systemName: draft.isPinned ? "pin.fill" : "pin")
                .frame(width: side, height: side)
        }
        .accessibilityLabel(draft.isPinned ? "Unpin note" : "Pin note")
    }

    private func favoriteButton(side: CGFloat? = nil) -> some View {
        Button {
            draft.isFavorite.toggle()
        } label: {
            Image(systemName: draft.isFavorite ? "star.fill" : "star")
                .frame(width: side, height: side)
        }
        .accessibilityLabel(draft.isFavorite ? "Remove favorite" : "Favorite note")
    }

    private func moreMenu(side: CGFloat? = nil) -> some View {
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
            if KnowledgeFeatureFlags.evaEnabled {
                Menu("Ask Eva", systemImage: "sparkles") {
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
                .frame(width: side, height: side)
        }
    }

    private var editorSurface: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                TextField("Note title", text: $draft.title, prompt: Text("Note title").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                    .lifeboardFont(.heroDisplay)
                    .textFieldStyle(.plain)
                    .focused($titleIsFocused)
                    .accessibilityLabel("Note title")
                    .accessibilityIdentifier("notes.editor.title")
                Text(noteDateLine)
                    .font(.caption)
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                tagRail
                if KnowledgeFeatureFlags.textKitEditorEnabled {
                    UnifiedNoteEditor(
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
                        KnowledgeBlockEditor(
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
            // DESIGN.md's prose cap: past ~680pt a line of body text gets
            // too long to track back to its start.
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.top, 26)
            .padding(.bottom, 110)
            .frame(maxWidth: .infinity)
        }
        .background {
            GrainedCanvas()
        }
        .accessibilityIdentifier("notes.editor")
        .scrollDismissesKeyboard(.interactively)
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
                .navigationTitle(wikiLinkQuery == nil ? "Link a note" : "Mention a note")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { showsLinkPicker = false }.keyboardShortcut(.cancelAction) } }
            }
        }
        .confirmationDialog("Insert a block", isPresented: $showsSlashCommands, titleVisibility: .visible) {
            ForEach(KnowledgeBlockKind.allCases, id: \.self) { kind in
                Button(kindTitle(kind), systemImage: kindSymbol(kind)) {
                    richEditorCommand = .init(command: .block(kind))
                }
            }
        }
        .sheet(isPresented: $showsHistory) {
            NoteHistoryView(
                revisions: revisions,
                onRestore: restoreRevision,
                onDismiss: { showsHistory = false }
            )
        }
        .sheet(item: $aiProposal) { proposal in
            NoteAIProposalReview(
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
                    Color.lifeboard(.overlayScrim).opacity(0.25).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Eva is thinking…")
                            .font(.subheadline.weight(.semibold))
                    }
                    .padding(22)
                    // Clay's transient-overlay depth: the command bar is this
                    // screen's one glass control.
                    .lifeBoardClaySurface(.floating)
                }
                .transition(.opacity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Eva is thinking")
            }
        }
        .alert("Couldn’t finish that", isPresented: Binding(
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

    private var saveStatus: some View {
        HStack(spacing: 8) {
            switch saveState {
            case .idle:
                EmptyView()
            case .saving:
                ProgressView()
                    .controlSize(.mini)
                Text("Saving")
            case .saved:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.lifeboard(.statusSuccess))
                    .contentTransition(.symbolEffect(.replace))
                Text("Saved")
            case .failed:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.lifeboard(.statusWarning))
                Text("Not saved")
            }
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(Color.lifeboard(.textSecondary))
        .accessibilityElement(children: .combine)
    }

    private var editorCommandBar: some View {
        GlassEffectContainer(spacing: 8) {
            if KnowledgeFeatureFlags.textKitEditorEnabled, !richEditorIsFocused, !titleIsFocused {
                Button {
                    richEditorIsFocused = true
                } label: {
                    Label("Edit note", systemImage: "pencil")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 46)
                }
                // Clay, not glass: the command bar it stands in for is this
                // screen's one glass control.
                .buttonStyle(.lifeBoardClay(.floating, cornerRadius: Radius.pill))
                .padding(.vertical, 8)
                .transition(.scale(scale: 0.92).combined(with: .opacity))
            } else {
                HStack(spacing: 4) {
                Menu {
                    ForEach(KnowledgeBlockKind.allCases, id: \.self) { kind in
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
                if KnowledgeFeatureFlags.textKitEditorEnabled {
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
            .padding(.horizontal, 12)
            .frame(maxWidth: 680, minHeight: 54)
            .lifeBoardSystemGlass(.regular, in: Capsule(), interactive: true)
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
            }
        }
        .lifeBoardMotion(.selection, value: richEditorIsFocused)
    }
}

extension KnowledgeNoteEditor {
    private var linksForDraft: [KnowledgeLinkValue] {
        links.filter { $0.sourceNoteID == draft.id || $0.destinationNoteID == draft.id }
    }

    private var linkPickerNotes: [KnowledgeNoteValue] {
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
        return count == 0 ? String(localized: "Edited \(date)") : (count == 1 ? String(localized: "1 word  •  Edited \(date)") : String(localized: "\(count) words  •  Edited \(date)"))
    }

    private var markdownExport: String {
        KnowledgeMarkdownCodec.render(draft)
    }

    private var originalWasMeaningful: Bool {
        guard let originalSnapshot,
              let note = try? JSONDecoder().decode(KnowledgeNoteValue.self, from: originalSnapshot) else {
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
            aiErrorMessage = String(localized: "Couldn’t import photo. The note is unchanged.")
        }
    }

    @MainActor
    private func requestAIProposal(_ action: NoteAIAction) async {
        guard !aiIsPreparing else { return }
        aiIsPreparing = true
        defer { aiIsPreparing = false }
        do {
            aiProposal = try await ModelsNoteAIProposalService().propose(
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
            aiErrorMessage = String(localized: "The note changed. Ask Eva again.")
            return
        }
        let preview = editedPreview.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !preview.isEmpty else {
            aiErrorMessage = String(localized: "Keep at least 1 line to apply it.")
            return
        }
        if let snapshot = try? JSONEncoder().encode(draft) {
            try? await repository.saveKnowledgeRevision(
                .init(
                    noteID: draft.id,
                    snapshot: snapshot,
                    reason: "Before applying a suggestion from Eva",
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

    private func preparedDraft() -> KnowledgeNoteValue {
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
    private func persist(_ value: KnowledgeNoteValue) async {
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
              let value = try? JSONDecoder().decode(KnowledgeNoteValue.self, from: recovered.snapshot) else {
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
        switch hosting {
        case .sheet: dismiss()
        case .pane(let onClose): onClose()
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
                    Button {
                        withAnimation(MotionProfile.selection.animation(reduceMotion: reduceMotion)) {
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
                    TextField("Tag name", text: $newTag, prompt: Text("Tag name").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                        .textFieldStyle(.plain)
                        .padding(.horizontal, 12)
                        .frame(minHeight: 42)
                        .background(Color.lifeboard(.textPrimary).opacity(0.05), in: Capsule())
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
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Links").font(.headline)
                Spacer()
                Button("Connect", systemImage: "link.badge.plus") { showsLinkPicker = true }
            }
            let related = links.filter { $0.sourceNoteID == draft.id || $0.destinationNoteID == draft.id }
            if related.isEmpty { Text("No linked notes").foregroundStyle(Color.lifeboard(.textSecondary)) }
            ForEach(related) { link in
                let otherID = link.sourceNoteID == draft.id ? link.destinationNoteID : link.sourceNoteID
                HStack {
                    Image(systemName: link.sourceNoteID == draft.id ? "arrow.up.right" : "arrow.down.left")
                    Text(allNotes.first(where: { $0.id == otherID })?.title ?? String(localized: "Missing note"))
                    Spacer()
                    Button(role: .destructive) { onDisconnect(link) } label: {
                        Image(systemName: "xmark.circle")
                            .minimumHitTarget()
                    }
                    .accessibilityLabel("Disconnect note")
                }
            }
        }
        .padding(16)
        .background(Color.lifeboard(.bgElevated), in: RoundedRectangle(cornerRadius: 16))
    }

    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                        attachmentPendingDeletion = attachment
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Delete \(attachment.fileName)")
                }
            }
        }
        .padding(16)
        .background(Color.lifeboard(.bgElevated), in: RoundedRectangle(cornerRadius: 16))
    }

    private func addBlock(_ kind: KnowledgeBlockKind) {
        if KnowledgeFeatureFlags.textKitEditorEnabled {
            performEditorCommand(.insertBlock(kind))
        } else {
            draft.blocks.append(.init(noteID: draft.id, kind: kind, ordinal: draft.blocks.count))
        }
    }

    private func performEditorCommand(_ command: KnowledgeEditorCommand) {
        if KnowledgeFeatureFlags.textKitEditorEnabled {
            richEditorCommand = .init(command: command)
            richEditorIsFocused = true
        } else if case let .block(kind) = command {
            draft.blocks.append(.init(noteID: draft.id, kind: kind, ordinal: draft.blocks.count))
        }
    }

    private func deleteBlock(_ block: KnowledgeBlockValue) {
        guard draft.blocks.count > 1 else { return }
        if let attachmentID = KnowledgeBlockPayload.decode(from: block).attachment?.attachmentID,
           let attachment = attachments.first(where: { $0.id == attachmentID }) {
            attachmentPendingDeletion = attachment
            return
        }
        draft.blocks.removeAll { $0.id == block.id }
        normalizeOrdinals()
    }

    private func moveBlock(_ id: UUID, offset: Int) {
        guard let source = draft.blocks.firstIndex(where: { $0.id == id }) else { return }
        let destination = source + offset
        guard draft.blocks.indices.contains(destination) else { return }
        withAnimation(MotionProfile.cardReflow.animation(reduceMotion: reduceMotion)) {
            draft.blocks.swapAt(source, destination)
            normalizeOrdinals()
        }
    }

    private func addAttachmentBlock(_ attachment: KnowledgeAttachmentValue) {
        let imageExtensions = Set(["jpg", "jpeg", "png", "heic", "heif", "gif", "webp"])
        let kind: KnowledgeBlockKind = imageExtensions.contains(attachment.kind.lowercased()) ? .image : .file
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
        guard let restored = try? JSONDecoder().decode(KnowledgeNoteValue.self, from: revision.snapshot) else {
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

    private func deleteAttachment(_ attachment: KnowledgeAttachmentValue) async {
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
            // Keep the attachment visible so the user can retry instead of
            // pretending deletion succeeded, and say so.
            Haptic.fail.play()
            attachmentDeleteFailed = true
        }
    }

    private func openAttachment(_ attachment: KnowledgeAttachmentValue) async {
        do {
            previewAttachmentURL = try await attachmentFiles.resolvedURL(for: attachment)
            attachmentFailures.remove(attachment.id)
        } catch {
            attachmentFailures.insert(attachment.id)
        }
    }
}

private struct NoteAIProposalReview: View {
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
                    Label("Review before applying", systemImage: "checkmark.shield")
                        .font(.headline)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                    Text(proposal.explanation)
                        .font(.subheadline)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                    TextEditor(text: $editedPreview)
                        .font(.body)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 260)
                        .padding(16)
                        .background(
                            Color.lifeboard(.surfaceSecondary),
                            in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .stroke(Color.lifeboard(.textPrimary).opacity(0.07), lineWidth: 1)
                        }
                        .accessibilityLabel("Eva suggestion")
                    if isStale {
                        Label(
                            "The note changed. Discard this and ask again.",
                            systemImage: "exclamationmark.triangle.fill"
                        )
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(Color.lifeboard(.statusWarning))
                    } else {
                        Label(
                            "Only this text is applied. You can edit it.",
                            systemImage: "hand.raised"
                        )
                        .font(.footnote)
                        .foregroundStyle(Color.lifeboard(.textSecondary))
                    }
                }
                .frame(maxWidth: 680, alignment: .leading)
                .padding(24)
                .frame(maxWidth: .infinity)
            }
            .background(Color(SemanticColorTokens.foundationCanvas))
            .navigationTitle("Eva suggestion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Discard", role: .destructive, action: onDiscard)
                    .keyboardShortcut(.cancelAction)
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

private struct NoteHistoryView: View {
    let revisions: [KnowledgeNoteRevisionValue]
    let onRestore: (KnowledgeNoteRevisionValue) -> Void
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            Group {
                if revisions.isEmpty {
                    // `StatusSurface` would be right here, but it lives in the
                    // app target and this file is in the `KnowledgeFeature`
                    // package, which cannot see it. See the note on
                    // LifeBoardAtmosphereRenderer.
                    ContentUnavailableView(
                        "No earlier versions",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Versions appear as you edit.").foregroundColor(Color(SemanticColorTokens.inkSecondary))
                    )
                } else {
                    List(revisions) { revision in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(revision.reason)
                                .font(.headline)
                            Text(revision.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundStyle(Color.lifeboard(.textSecondary))
                            Button("Restore this version") { onRestore(revision) }
                                .font(.subheadline.weight(.semibold))
                        }
                        .padding(.vertical, 8)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Version history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                }
            }
        }
    }
}

private struct LockedKnowledgeNoteEditor: View {
    let placeholder: KnowledgeNoteValue
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
                Color(SemanticColorTokens.foundationCanvas).ignoresSafeArea()
                SceneCaptureMonitor(isCaptured: $isCaptured)
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
                            .minimumHitTarget()
                    }
                    .accessibilityLabel("Close")
                    .keyboardShortcut(.cancelAction)
                }
                ToolbarItem(placement: .principal) {
                    Label("Locked", systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.lifeboard(.textSecondary))
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
            .alert("Couldn’t open note", isPresented: Binding(
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
                    .fill(Color(SemanticColorTokens.foundationApricotAccent).opacity(0.24))
                    .frame(width: 88, height: 88)
                Image(systemName: "lock.fill")
                    .lifeboardFont(.heroDisplay)
                    .foregroundStyle(Color(SemanticColorTokens.foundationApricotInk))
                    .symbolEffect(.breathe, options: .nonRepeating)
            }
            Text("Locked note")
                .lifeboardFont(.screenTitle)
            Text("Locked notes stay out of search and previews.")
                .font(.body)
                .foregroundStyle(Color.lifeboard(.textSecondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 390)
            Button {
                Task { await unlock() }
            } label: {
                HStack(spacing: 12) {
                    if isUnlocking { ProgressView().controlSize(.small) }
                    Label(isUnlocking ? "Unlocking…" : "Unlock note", systemImage: "faceid")
                        .fontWeight(.semibold)
                }
                .padding(.horizontal, 20)
                .frame(minHeight: 50)
            }
            .disabled(isUnlocking)
            // A content action, so clay: glass is for chrome, and the unlocked
            // state's formatting bar is this screen's one glass control.
            .buttonStyle(.lifeBoardClay(.raised, cornerRadius: Radius.pill))
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
                ), prompt: Text("Note title").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
                .lifeboardFont(.heroDisplay)
                .textFieldStyle(.plain)
                .accessibilityLabel("Note title")

                UnifiedNoteEditor(
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
                    Text("Attachments")
                        .font(.headline)
                    ForEach(current.attachments) { attachment in
                        Label(attachment.fileName, systemImage: "lock.doc")
                            .font(.subheadline)
                            .foregroundStyle(Color.lifeboard(.textSecondary))
                    }
                }
            }
            // The same prose cap as the unlocked editor.
            .frame(maxWidth: 680, alignment: .leading)
            .padding(.horizontal, 24)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 8) {
                editorButton("Bold", "bold", .bold)
                editorButton("Italic", "italic", .italic)
                editorButton("Highlight", "highlighter", .highlight)
                Divider().frame(height: 22)
                editorButton("Checklist", "checklist", .block(.checklist))
                editorButton("Heading", "textformat.size", .block(.heading2))
                Spacer()
                switch saveState {
                case .saving: ProgressView().controlSize(.small)
                case .saved: Image(systemName: "checkmark.circle.fill").foregroundStyle(Color.lifeboard(.statusSuccess))
                case .failed: Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Color.lifeboard(.statusWarning))
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
            Image(systemName: symbol).minimumHitTarget()
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
        .foregroundStyle(Color.lifeboard(.textSecondary))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(SemanticColorTokens.foundationCanvas))
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

private struct SceneCaptureMonitor: UIViewRepresentable {
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

private struct KnowledgeBlockEditor: View {
    @Binding var block: KnowledgeBlockValue
    let allNotes: [KnowledgeNoteValue]
    let attachments: [KnowledgeAttachmentValue]
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var expanded = true
    @State private var bookmarkIsLoading = false
    @State private var bookmarkError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(blockLabel, systemImage: blockSymbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
                Spacer()
                Menu {
                    ForEach(KnowledgeBlockKind.allCases, id: \.self) { kind in
                        Button(kind.displayTitle) { block.kind = kind }
                    }
                    Divider()
                    Button("Move up", systemImage: "arrow.up", action: onMoveUp)
                    Button("Move down", systemImage: "arrow.down", action: onMoveDown)
                    Divider()
                    Button("Delete block", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis")
                        .minimumHitTarget()
                }
                .accessibilityLabel("Block options")
            }
            switch block.kind {
            case .divider:
                Divider().padding(.vertical, 8)
            case .checklist:
                HStack(alignment: .top) {
                    Button {
                        withAnimation(MotionProfile.localState.animation(reduceMotion: reduceMotion)) {
                            block.isChecked.toggle()
                        }
                    } label: {
                        Image(systemName: block.isChecked ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(block.isChecked ? Color.lifeboard(.accentPrimary) : Color.lifeboard(.textSecondary))
                            .contentTransition(.symbolEffect(.replace))
                            .minimumHitTarget()
                    }
                    .buttonStyle(.plain)
                    .sensoryFeedback(.success, trigger: block.isChecked)
                    .accessibilityLabel(block.isChecked ? "Mark incomplete" : "Mark complete")
                    TextField("Checklist item", text: $block.text, prompt: Text("Checklist item").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical)
                        .strikethrough(block.isChecked, color: .secondary)
                        .foregroundStyle(block.isChecked ? Color.lifeboard(.textSecondary) : Color.lifeboard(.textPrimary))
                }
            case .collapsible:
                DisclosureGroup(isExpanded: $expanded) {
                    TextEditor(text: $block.text).frame(minHeight: 80)
                } label: { Text(block.text.split(separator: "\n").first.map(String.init) ?? "Collapsible section") }
            case .heading1:
                TextField("Heading", text: $block.text, prompt: Text("Heading").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical).font(.title2.weight(.semibold))
            case .heading2:
                TextField("Heading", text: $block.text, prompt: Text("Heading").foregroundColor(Color(SemanticColorTokens.inkSecondary)), axis: .vertical).font(.title3.weight(.semibold))
            case .code:
                TextEditor(text: $block.text).font(.system(.body, design: .monospaced)).frame(minHeight: 100)
            case .table:
                KnowledgeTableEditor(block: $block)
            case .bookmark:
                VStack(alignment: .leading, spacing: 8) {
                    TextField("https://example.com", text: $block.text, prompt: Text("https://example.com").foregroundColor(Color(SemanticColorTokens.inkSecondary)))
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
                                    Text(summary).font(.caption).foregroundStyle(Color.lifeboard(.textSecondary)).lineLimit(3)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                        if bookmarkIsLoading { ProgressView("Loading…") }
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
                        .clipShape(RoundedRectangle(cornerRadius: Radius.field))
                        .accessibilityLabel(attachment.fileName)
                } else {
                    Label(block.text.isEmpty ? "Image unavailable" : block.text, systemImage: "photo.badge.exclamationmark")
                        .foregroundStyle(Color.lifeboard(.textSecondary))
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
                    .fill(Color.lifeboard(.textPrimary).opacity(0.045))
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
        default: block.kind.displayTitle
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
        default: "Start writing…"
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

    private var attachmentForBlock: KnowledgeAttachmentValue? {
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

private struct KnowledgeTableEditor: View {
    @Binding var block: KnowledgeBlockValue

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
        .accessibilityLabel("Table")
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


/// The confirmation before an attachment's file is deleted for good, and the
/// alert when that delete fails.
private struct KnowledgeAttachmentDeletionConfirmation: ViewModifier {
    @Binding var pending: KnowledgeAttachmentValue?
    @Binding var failed: Bool
    let onDelete: (KnowledgeAttachmentValue) -> Void

    func body(content: Content) -> some View {
        content
            .confirmationDialog(
                "Delete this attachment?",
                isPresented: Binding(
                    get: { pending != nil },
                    set: { if $0 == false { pending = nil } }
                ),
                titleVisibility: .visible,
                presenting: pending
            ) { attachment in
                Button("Delete attachment", role: .destructive) {
                    pending = nil
                    onDelete(attachment)
                }
                Button("Cancel", role: .cancel) { pending = nil }
            } message: { attachment in
                Text("It’s deleted from this device. This can’t be undone.")
            }
            .alert("Couldn’t delete attachment", isPresented: $failed) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("It’s still in this note. Try again.")
            }
    }
}
