import LifeBoardContracts
import LifeBoardDomain
import LifeBoardTokens
import LifeBoardUI
import Foundation
import SwiftUI

/// Wraps the shared page container so the builder keeps its host navigation
/// chrome (title, Cancel, Save) exactly as the Notes module supplies it.
private struct ComposerScaffoldShim<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ComposerPage(
            subtitle: String(localized: "Updates as your notes change."),
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
        ComposerSection("Collection") {
            ComposerField(
                "Name",
                prompt: String(localized: "Collection name"),
                text: $name,
                showsLabel: false,
                identifier: "notes.smartCollection.name"
            )
            ComposerField("Words or phrase", prompt: "Optional", text: $terms)
        }
    }
}

private struct SmartCollectionLocationSection: View {
    @Binding var folderID: UUID?
    let folders: [KnowledgeFolderValue]
    let tags: [KnowledgeTagValue]
    @Binding var selectedTagIDs: Set<UUID>

    var body: some View {
        ComposerSection("Location") {
            MenuRow(
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
                        .foregroundStyle(Color(SemanticColorTokens.inkSecondary))
                    OptionFlow(spacing: 8) {
                        ForEach(tags) { tag in
                            let isOn = selectedTagIDs.contains(tag.id)
                            Button {
                                Haptic.pick.play()
                                if isOn { selectedTagIDs.remove(tag.id) } else { selectedTagIDs.insert(tag.id) }
                            } label: {
                                Text(tag.name)
                                    .font(.lifeboard(isOn ? .bodyStrong : .body))
                                    .foregroundStyle(Color(isOn
                                        ? SemanticColorTokens.inkPrimary
                                        : SemanticColorTokens.inkSecondary))
                                    .padding(.horizontal, 14)
                                    .frame(minHeight: 44)
                                    .lifeBoardClaySurface(
                                        isOn ? .raised : .well,
                                        cornerRadius: Radius.pill
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
        ComposerSection("Content") {
            Toggle("Has attachments", isOn: $requiresAttachments)
                .toggleStyle(.lifeBoardClay)
            OptionRail(
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
            OptionRail(
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
        ComposerSection("Refine") {
            Toggle("Favorites only", isOn: $favoritesOnly)
                .toggleStyle(.lifeBoardClay)
            Toggle("Pinned only", isOn: $pinnedOnly)
                .toggleStyle(.lifeBoardClay)
            Toggle("Edited last 30 days", isOn: $modifiedRecently)
                .toggleStyle(.lifeBoardClay)
        }
    }
}

struct SmartCollectionBuilder: View {
    let spaceID: UUID?
    let folders: [KnowledgeFolderValue]
    let tags: [KnowledgeTagValue]
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
            ComposerScaffoldShim {
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
            .navigationTitle("Smart collection")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
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
