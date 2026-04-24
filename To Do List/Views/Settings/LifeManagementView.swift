import SwiftUI
import UIKit

private enum LifeManagementComposerRoute: Identifiable, Equatable {
    case area(LifeManagementLifeAreaDraft)
    case project(LifeManagementProjectDraft)

    var id: UUID {
        switch self {
        case .area(let draft):
            return draft.id
        case .project(let draft):
            return draft.id
        }
    }
}

private enum LifeManagementTreeInteractionMode {
    case push
    case select
}

struct LifeManagementView: View {
    @StateObject private var viewModel: LifeManagementViewModel
    @StateObject private var habitComposerViewModel = PresentationDependencyContainer.shared.makeNewAddHabitViewModel()
    @State private var habitComposerPresented = false
    @State private var selectedHabitRow: HabitLibraryRow?
    @State private var habitComposerSuccessFlash = false

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var accessibilityReduceMotion

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    init(viewModel: LifeManagementViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    private var activeComposerRoute: Binding<LifeManagementComposerRoute?> {
        Binding(
            get: {
                if let draft = viewModel.lifeAreaDraft {
                    return .area(draft)
                }
                if let draft = viewModel.projectDraft {
                    return .project(draft)
                }
                return nil
            },
            set: { newValue in
                switch newValue {
                case .area(let draft):
                    viewModel.lifeAreaDraft = draft
                    viewModel.projectDraft = nil
                case .project(let draft):
                    viewModel.projectDraft = draft
                    viewModel.lifeAreaDraft = nil
                case nil:
                    viewModel.dismissLifeAreaDraft()
                    viewModel.dismissProjectDraft()
                }
            }
        )
    }

    private var compactComposerRoute: Binding<LifeManagementComposerRoute?> {
        Binding(
            get: { layoutClass == .phone ? activeComposerRoute.wrappedValue : nil },
            set: { activeComposerRoute.wrappedValue = $0 }
        )
    }

    private var regularComposerRoute: Binding<LifeManagementComposerRoute?> {
        Binding(
            get: { layoutClass == .phone ? nil : activeComposerRoute.wrappedValue },
            set: { activeComposerRoute.wrappedValue = $0 }
        )
    }

    private var isSearching: Bool {
        viewModel.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }

    private var hasTreeContent: Bool {
        viewModel.treeSections.isEmpty == false
    }

    private var activeTreeIsEmpty: Bool {
        viewModel.treeSections.first(where: { $0.kind == .active })?.nodes.isEmpty != false
    }

    private var selectedAreaID: UUID? {
        guard case .area(let id) = viewModel.selectedNode else { return nil }
        return id
    }

    private var selectedProjectID: UUID? {
        guard case .project(let id) = viewModel.selectedNode else { return nil }
        return id
    }

    private var selectedAreaIsArchived: Bool {
        guard let selectedAreaID else { return false }
        return viewModel.areaRow(for: selectedAreaID)?.lifeArea.isArchived == true
    }

    private var selectedProjectAllowsChildHabits: Bool {
        guard let selectedProjectID, let row = viewModel.projectRow(for: selectedProjectID) else { return false }
        return row.project.isArchived == false && row.lifeArea?.isArchived != true
    }

    var body: some View {
        Group {
            if layoutClass.isPad {
                splitBrowser
            } else {
                compactBrowser
            }
        }
        .background(Color.tasker(.bgCanvas))
        .navigationTitle("Life Management")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.lifeManagement.view")
        .searchable(text: $viewModel.searchQuery, prompt: "Search areas, projects, habits")
        .toolbar { toolbarContent }
        .overlay {
            if viewModel.isLoading && hasTreeContent == false {
                ProgressView("Loading life management...")
                    .font(.tasker(.body))
                    .padding(.horizontal, spacing.s16)
                    .padding(.vertical, spacing.s12)
                    .background(
                        Color.tasker.surfacePrimary,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.isMutating {
                mutationPill
            }
        }
        .taskerSnackbar($viewModel.snackbar)
        .task {
            viewModel.loadIfNeeded()
        }
        .refreshable {
            viewModel.reload()
        }
        .fullScreenCover(item: compactComposerRoute) { route in
            composerDestination(for: route, containerMode: .sheet)
        }
        .sheet(item: regularComposerRoute) { route in
            composerDestination(for: route, containerMode: .inspector)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(Color.tasker(.bgElevated))
                .interactiveDismissDisabled(viewModel.isMutating)
        }
        .sheet(item: $viewModel.moveProjectDraft) { draft in
            ProjectMoveSheet(
                draft: draft,
                targets: viewModel.availableAreaTargets(excluding: viewModel.projectRow(for: draft.projectID)?.lifeArea?.id),
                isSaving: viewModel.isMutating,
                onSave: { updatedDraft in
                    viewModel.moveProjectDraft = updatedDraft
                    viewModel.moveProjectFromDraft()
                },
                onCancel: {
                    viewModel.dismissMoveProjectDraft()
                }
            )
        }
        .sheet(item: $viewModel.deleteAreaDraft) { draft in
            DeleteAreaSheet(
                draft: draft,
                targets: viewModel.availableAreaTargets(excluding: draft.areaID),
                isSaving: viewModel.isMutating,
                onSave: { updatedDraft in
                    viewModel.deleteAreaDraft = updatedDraft
                    viewModel.confirmDeleteArea()
                },
                onCancel: {
                    viewModel.dismissDeleteAreaDraft()
                }
            )
        }
        .sheet(item: $viewModel.deleteProjectDraft) { draft in
            DeleteProjectSheet(
                draft: draft,
                targets: viewModel.availableProjectDeleteTargets(excluding: draft.projectID),
                isSaving: viewModel.isMutating,
                onSave: { updatedDraft in
                    viewModel.deleteProjectDraft = updatedDraft
                    viewModel.confirmDeleteProject()
                },
                onCancel: {
                    viewModel.dismissDeleteProjectDraft()
                }
            )
        }
        .confirmationDialog(
            "Delete habit permanently?",
            isPresented: Binding(
                get: { viewModel.deleteHabitDraft != nil },
                set: { if !$0 { viewModel.dismissDeleteHabitDraft() } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                viewModel.confirmDeleteHabit()
            }
            Button("Cancel", role: .cancel) {
                viewModel.dismissDeleteHabitDraft()
            }
        } message: {
            Text("This removes the habit and its scheduling history.")
        }
        .sheet(isPresented: $habitComposerPresented) {
            habitComposerSheet
        }
        .sheet(item: $selectedHabitRow) { row in
            HabitDetailSheetView(
                viewModel: PresentationDependencyContainer.shared.makeHabitDetailViewModel(row: row),
                onMutation: {
                    viewModel.reload()
                }
            )
        }
    }

    private var compactBrowser: some View {
        ScrollView {
            browserContent(interactionMode: .push)
                .taskerReadableContent(maxWidth: 980, alignment: .center)
                .padding(.horizontal, spacing.screenHorizontal)
                .padding(.vertical, spacing.s16)
        }
        .navigationDestination(for: LifeManagementSelection.self) { selection in
            detailDestination(for: selection)
        }
    }

    private var splitBrowser: some View {
        NavigationSplitView {
            ScrollView {
                browserContent(interactionMode: .select)
                    .padding(.horizontal, spacing.screenHorizontal)
                    .padding(.vertical, spacing.s16)
            }
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
    }

    @ViewBuilder
    private func browserContent(interactionMode: LifeManagementTreeInteractionMode) -> some View {
        LazyVStack(spacing: spacing.s16, pinnedViews: []) {
            if let errorMessage = viewModel.errorMessage {
                errorCard(message: errorMessage)
            }

            lifeManagementPrimaryActionCard

            if isSearching && hasTreeContent == false {
                emptyStateCard(
                    title: "No matches",
                    body: "Try a different search across areas, projects, and habits.",
                    actionTitle: nil,
                    action: nil
                )
            } else if hasTreeContent == false && viewModel.isLoading == false {
                emptyStateCard(
                    title: "Start with a life area",
                    body: "Create an area first, then place projects and habits inside it.",
                    actionTitle: "Add Area",
                    action: {
                        viewModel.beginCreateLifeArea()
                    }
                )
            } else {
                ForEach(viewModel.treeSections) { section in
                    treeSection(section, interactionMode: interactionMode)
                }
            }
        }
    }

    private var lifeManagementPrimaryActionCard: some View {
        TaskerSettingsCard(active: true) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                HStack(alignment: .top, spacing: spacing.s8) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.tasker(.accentPrimary))
                        .frame(width: 22, height: 22)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: spacing.s4) {
                        Text("Life Areas")
                            .font(.tasker(.headline))
                            .foregroundStyle(Color.tasker(.textPrimary))

                        Text("Create a new area to organize related projects and habits.")
                            .font(.tasker(.callout))
                            .foregroundStyle(Color.tasker(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button {
                    viewModel.beginCreateLifeArea()
                } label: {
                    Label("Add Area", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.isMutating)
                .accessibilityIdentifier("settings.lifeManagement.addAreaButton")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.lifeManagement.addAreaCard")
    }

    private func treeSection(_ section: LifeManagementTreeSection, interactionMode: LifeManagementTreeInteractionMode) -> some View {
        TaskerSettingsCard(active: section.kind == .archived && viewModel.isSectionExpanded(section.kind)) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Button {
                    guard section.kind == .archived else { return }
                    withAnimation(accessibilityReduceMotion ? nil : TaskerAnimation.quick) {
                        viewModel.toggleSectionExpansion(section.kind)
                    }
                } label: {
                    HStack(spacing: spacing.s8) {
                        Text(section.title)
                            .font(.tasker(.headline))
                            .foregroundStyle(Color.tasker(.textPrimary))
                        Text("\(section.nodes.count)")
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker(.textSecondary))
                        Spacer()
                        if section.kind == .archived {
                            Image(systemName: viewModel.isSectionExpanded(section.kind) ? "chevron.down" : "chevron.right")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Color.tasker(.textTertiary))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
                .disabled(section.kind != .archived)

                if viewModel.isSectionExpanded(section.kind) {
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        ForEach(section.nodes) { node in
                            treeNode(node, depth: 0, interactionMode: interactionMode)
                        }
                    }
                }
            }
        }
        .accessibilityIdentifier(section.accessibilityIdentifier)
    }

    private func treeNode(
        _ node: LifeManagementTreeNode,
        depth: Int,
        interactionMode: LifeManagementTreeInteractionMode
    ) -> AnyView {
        AnyView(
            VStack(alignment: .leading, spacing: spacing.s8) {
                HStack(alignment: .top, spacing: spacing.s8) {
                    if node.isExpandable {
                        Button {
                            withAnimation(accessibilityReduceMotion ? nil : TaskerAnimation.quick) {
                                viewModel.toggleNodeExpansion(node.selection)
                            }
                        } label: {
                            Image(systemName: viewModel.isNodeExpanded(node.selection) ? "chevron.down" : "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.tasker(.textTertiary))
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear
                            .frame(width: 24, height: 24)
                    }

                    primaryNodeControl(node, interactionMode: interactionMode)

                    nodeMenu(node)
                }
                .padding(.leading, CGFloat(depth) * spacing.s16)

                if node.isExpandable && viewModel.isNodeExpanded(node.selection) {
                    VStack(alignment: .leading, spacing: spacing.s8) {
                        ForEach(node.children) { child in
                            treeNode(child, depth: depth + 1, interactionMode: interactionMode)
                        }
                    }
                }
            }
        )
    }

    @ViewBuilder
    private func primaryNodeControl(
        _ node: LifeManagementTreeNode,
        interactionMode: LifeManagementTreeInteractionMode
    ) -> some View {
        let content = nodeRowContent(node)

        switch (interactionMode, node.selection) {
        case (.push, .area), (.push, .project):
            NavigationLink(value: node.selection) {
                content
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                viewModel.selectNode(node.selection)
            })
        case (.select, _):
            Button {
                viewModel.selectNode(node.selection)
                if case .habit(let id) = node.selection, let row = viewModel.habitRow(for: id) {
                    selectedHabitRow = row.row
                }
            } label: {
                content
            }
            .buttonStyle(.plain)
        default:
            Button {
                viewModel.selectNode(node.selection)
                if case .habit(let id) = node.selection, let row = viewModel.habitRow(for: id) {
                    selectedHabitRow = row.row
                }
            } label: {
                content
            }
            .buttonStyle(.plain)
        }
    }

    private func nodeRowContent(_ node: LifeManagementTreeNode) -> some View {
        let isSelected = viewModel.selectedNode == node.selection
        return HStack(alignment: .top, spacing: spacing.s12) {
            AccentIconBadge(
                symbolName: node.symbolName,
                accentHex: node.accentHex
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(node.title)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(Color.tasker(.textPrimary))
                    if let badgeTitle = nodeBadgeTitle(node) {
                        InlineToneBadge(title: badgeTitle)
                    }
                }

                Text(node.subtitle)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(isSelected ? Color.tasker(.accentWash) : Color.tasker(.surfaceSecondary))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.tasker(.accentPrimary) : Color.tasker(.strokeHairline), lineWidth: isSelected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .accessibilityIdentifier(node.accessibilityIdentifier)
    }

    private func nodeBadgeTitle(_ node: LifeManagementTreeNode) -> String? {
        switch node.payload {
        case .area(let row):
            if row.lifeArea.isArchived || node.isArchived { return "Archived" }
            if row.isGeneral { return "Pinned" }
            return nil
        case .project(let row):
            if row.project.isArchived || node.isArchived { return "Archived" }
            if row.isInbox { return "Inbox" }
            return nil
        case .habit(let row):
            if row.row.isArchived || node.isArchived { return "Archived" }
            if row.row.isPaused { return "Paused" }
            return nil
        }
    }

    @ViewBuilder
    private func nodeMenu(_ node: LifeManagementTreeNode) -> some View {
        Menu {
            switch node.payload {
            case .area(let row):
                if row.lifeArea.isArchived {
                    Button("Restore", systemImage: "arrow.uturn.backward") {
                        viewModel.restoreLifeArea(row.id)
                    }
                    if row.isGeneral == false {
                        Button("Delete Permanently", systemImage: "trash", role: .destructive) {
                            viewModel.beginDeleteArea(row.id)
                        }
                    }
                } else {
                    Button("Edit", systemImage: "pencil") {
                        viewModel.beginEditLifeArea(row.id)
                    }
                    Button("Add Project", systemImage: "folder.badge.plus") {
                        viewModel.beginCreateProject(prefillLifeAreaID: row.id)
                    }
                    .disabled(row.lifeArea.isArchived || viewModel.isMutating)
                    Button("Add Habit", systemImage: "repeat") {
                        presentHabitComposer(prefill: AddHabitPrefillTemplate(title: "", lifeAreaID: row.id))
                    }
                    .disabled(row.lifeArea.isArchived || viewModel.isMutating)
                    if row.isGeneral == false {
                        Button("Archive", systemImage: "archivebox") {
                            viewModel.archiveLifeArea(row.id)
                        }
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            viewModel.beginDeleteArea(row.id)
                        }
                    }
                }
            case .project(let row):
                if row.project.isArchived || node.isArchived {
                    Button("Restore", systemImage: "arrow.uturn.backward") {
                        viewModel.restoreProject(row.id)
                    }
                    if row.project.isDefault == false {
                        Button("Delete Permanently", systemImage: "trash", role: .destructive) {
                            viewModel.beginDeleteProject(row.id)
                        }
                    }
                } else {
                    Button("Edit", systemImage: "pencil") {
                        viewModel.beginEditProject(row.id)
                    }
                    Button("Add Habit", systemImage: "repeat") {
                        presentHabitComposer(
                            prefill: AddHabitPrefillTemplate(
                                title: "",
                                lifeAreaID: row.project.lifeAreaID,
                                projectID: row.project.id
                            )
                        )
                    }
                    .disabled(row.project.isArchived || row.lifeArea?.isArchived == true || viewModel.isMutating)
                    if row.isMoveLocked == false {
                        Button("Move Project", systemImage: "arrow.left.arrow.right") {
                            viewModel.beginMoveProject(row.id)
                        }
                    }
                    if row.isInbox == false {
                        Button("Archive", systemImage: "archivebox") {
                            viewModel.archiveProject(row.id)
                        }
                    }
                    if row.project.isDefault == false {
                        Button("Delete", systemImage: "trash", role: .destructive) {
                            viewModel.beginDeleteProject(row.id)
                        }
                    }
                }
            case .habit(let row):
                Button("Open", systemImage: "slider.horizontal.3") {
                    selectedHabitRow = row.row
                    viewModel.selectNode(.habit(row.id))
                }
                if row.row.isArchived || node.isArchived {
                    Button("Restore", systemImage: "arrow.uturn.backward") {
                        viewModel.restoreHabit(row.id)
                    }
                    Button("Delete Permanently", systemImage: "trash", role: .destructive) {
                        viewModel.beginDeleteHabit(row.id)
                    }
                } else {
                    Button(row.row.isPaused ? "Resume" : "Pause", systemImage: row.row.isPaused ? "play.fill" : "pause.fill") {
                        viewModel.toggleHabitPause(row.id)
                    }
                    Button("Archive", systemImage: "archivebox") {
                        viewModel.archiveHabit(row.id)
                    }
                }
            }
        } label: {
            LifeManagementMenuLabel(title: "More actions", systemImage: "ellipsis.circle")
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var detailPane: some View {
        switch viewModel.selectedNode {
        case .area(let areaID):
            detailDestination(for: .area(areaID))
        case .project(let projectID):
            detailDestination(for: .project(projectID))
        case .habit:
            ContentUnavailableView(
                "Habit Editor Opened",
                systemImage: "repeat",
                description: Text("Habits open in the editor sheet so you can update cadence, notes, and status in one place.")
            )
        case nil:
            ContentUnavailableView(
                "Select a Life Area",
                systemImage: "square.grid.2x2",
                description: Text("Choose an area, project, or habit from the hierarchy to inspect or edit it.")
            )
        }
    }

    @ViewBuilder
    private func detailDestination(for selection: LifeManagementSelection) -> some View {
        if case .area(let areaID) = selection {
            LifeManagementAreaDetailView(
                snapshot: viewModel.areaDetailSnapshot(for: areaID),
                onEditArea: { areaID in
                    viewModel.beginEditLifeArea(areaID)
                },
                onOpenHabit: { row in
                    selectedHabitRow = row
                    viewModel.selectNode(.habit(row.habitID))
                },
                onCreateHabit: { template in
                    presentHabitComposer(prefill: template)
                },
                onArchiveArea: { areaID in
                    viewModel.archiveLifeArea(areaID)
                },
                onRestoreArea: { areaID in
                    viewModel.restoreLifeArea(areaID)
                },
                onDeleteArea: { areaID in
                    viewModel.beginDeleteArea(areaID)
                },
                onBeginCreateProject: { areaID in
                    viewModel.beginCreateProject(prefillLifeAreaID: areaID)
                }
            )
            .onAppear {
                viewModel.selectNode(selection)
            }
        } else if case .project(let projectID) = selection {
            LifeManagementProjectDetailView(
                snapshot: viewModel.projectDetailSnapshot(for: projectID),
                onEditProject: { projectID in
                    viewModel.beginEditProject(projectID)
                },
                onOpenHabit: { row in
                    selectedHabitRow = row
                    viewModel.selectNode(.habit(row.habitID))
                },
                onCreateHabit: { template in
                    presentHabitComposer(prefill: template)
                },
                onBeginMoveProject: { projectID in
                    viewModel.beginMoveProject(projectID)
                },
                onArchiveProject: { projectID in
                    viewModel.archiveProject(projectID)
                },
                onRestoreProject: { projectID in
                    viewModel.restoreProject(projectID)
                },
                onDeleteProject: { projectID in
                    viewModel.beginDeleteProject(projectID)
                }
            )
            .onAppear {
                viewModel.selectNode(selection)
            }
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private func composerDestination(for route: LifeManagementComposerRoute, containerMode: AddTaskContainerMode) -> some View {
        switch route {
        case .area(let draft):
            LifeManagementAreaComposerView(
                draft: draft,
                iconOptions: viewModel.lifeAreaIconCatalog,
                containerMode: containerMode,
                isSaving: viewModel.isMutating,
                errorMessage: viewModel.errorMessage,
                onSave: { updatedDraft in
                    viewModel.lifeAreaDraft = updatedDraft
                    viewModel.saveLifeAreaDraft()
                },
                onCancel: {
                    viewModel.dismissLifeAreaDraft()
                }
            )
        case .project(let draft):
            LifeManagementProjectComposerView(
                draft: draft,
                lifeAreas: viewModel.availableAreaTargets(excluding: nil),
                fallbackAreaRows: viewModel.areaRows,
                containerMode: containerMode,
                isSaving: viewModel.isMutating,
                errorMessage: viewModel.errorMessage,
                onSave: { updatedDraft in
                    viewModel.projectDraft = updatedDraft
                    viewModel.saveProjectDraft()
                },
                onCancel: {
                    viewModel.dismissProjectDraft()
                }
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                switch viewModel.selectedNode {
                case .area(let areaID):
                    Button("Add Project", systemImage: "folder.badge.plus") {
                        viewModel.beginCreateProject(prefillLifeAreaID: areaID)
                    }
                    .disabled(selectedAreaIsArchived || viewModel.isMutating)
                    Button("Add Habit", systemImage: "repeat") {
                        presentHabitComposer(prefill: AddHabitPrefillTemplate(title: "", lifeAreaID: areaID))
                    }
                    .disabled(selectedAreaIsArchived || viewModel.isMutating)
                case .project(let projectID):
                    let lifeAreaID = viewModel.projectRow(for: projectID)?.project.lifeAreaID
                    Button("Add Habit", systemImage: "repeat") {
                        presentHabitComposer(
                            prefill: AddHabitPrefillTemplate(
                                title: "",
                                lifeAreaID: lifeAreaID,
                                projectID: projectID
                            )
                        )
                    }
                    .disabled(selectedProjectAllowsChildHabits == false || viewModel.isMutating)
                default:
                    Button("Add Area", systemImage: "square.grid.2x2") {
                        viewModel.beginCreateLifeArea()
                    }
                }
            } label: {
                LifeManagementMenuLabel(title: "Add", systemImage: "plus")
            }
            .accessibilityIdentifier("settings.lifeManagement.addMenu")
        }
    }

    private func errorCard(message: String) -> some View {
        TaskerSettingsCard(active: true) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Label("Couldn’t complete the last action", systemImage: "exclamationmark.triangle.fill")
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker(.textPrimary))

                Text(message)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: spacing.s8) {
                    Button("Retry") {
                        viewModel.reload()
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Dismiss") {
                        viewModel.clearError()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func presentHabitComposer(prefill: AddHabitPrefillTemplate? = nil) {
        habitComposerViewModel.resetForm()
        if let prefill {
            habitComposerViewModel.applyPrefill(prefill)
        }
        habitComposerPresented = true
    }

    private func createHabitAndDismiss() {
        guard habitComposerViewModel.canSubmit, habitComposerViewModel.isSaving == false else { return }
        habitComposerViewModel.createHabit { result in
            guard case .success = result else { return }
            habitComposerPresented = false
            viewModel.reload()
        }
    }

    private var habitComposerSheet: some View {
        AddHabitForedropView(
            viewModel: habitComposerViewModel,
            containerMode: .sheet,
            showAddAnother: false,
            successFlash: $habitComposerSuccessFlash,
            onCancel: {
                habitComposerPresented = false
            },
            onCreate: {
                createHabitAndDismiss()
            },
            onAddAnother: {
                createHabitAndDismiss()
            },
            onExpandToLarge: {}
        )
        .background(Color.tasker(.bgCanvas))
    }

    private var mutationPill: some View {
        HStack(spacing: spacing.s8) {
            ProgressView()
                .controlSize(.small)
            Text("Updating life management...")
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .background(Color.tasker(.surfacePrimary), in: Capsule())
        .padding(.bottom, spacing.s8)
    }

    private func emptyStateCard(
        title: String,
        body: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        TaskerSettingsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text(title)
                    .font(.tasker(.headline))
                    .foregroundStyle(Color.tasker(.textPrimary))

                Text(body)
                    .font(.tasker(.callout))
                    .foregroundStyle(Color.tasker(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)

                if let actionTitle, let action {
                    Button(actionTitle) {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
    }
}
private struct LifeManagementMenuLabel: View {
    let title: String
    let systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .labelStyle(.iconOnly)
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(Color.tasker(.textSecondary))
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
            .accessibilityLabel(Text(title))
    }
}

private struct LifeManagementAppearanceLine: View {
    let title: String
    let accentHex: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(uiColor: UIColor(taskerHex: accentHex)))
                .frame(width: 12, height: 12)
                .accessibilityHidden(true)
            Text(title)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
            Spacer()
            Text(value)
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(Color.tasker(.textPrimary))
        }
    }
}

private func lifeManagementHabitStatusText(_ row: HabitLibraryRow) -> String {
    if row.isArchived { return String(localized: "Archived", defaultValue: "Archived") }
    if row.isPaused { return "Paused" }
    if row.currentStreak > 0 { return "\(row.currentStreak)d streak" }
    return lifeManagementHabitCadenceLabel(row.cadence)
}

private func lifeManagementAreaAccentHex(_ area: LifeArea?) -> String {
    guard let area else { return HabitColorFamily.green.canonicalHex }
    return LifeAreaColorPalette.normalizeOrMap(hex: area.color, for: area.id)
}

private func lifeManagementHabitCadenceLabel(_ cadence: HabitCadenceDraft) -> String {
    switch cadence {
    case .daily:
        return "Daily"
    case .weekly(let days, _, _):
        return days.count == 1 ? "Weekly" : "\(days.count)x weekly"
    }
}

private struct AreaListRow: View {
    let row: LifeManagementAreaRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AccentIconBadge(
                symbolName: row.lifeArea.icon ?? "square.grid.2x2",
                accentHex: lifeManagementAreaAccentHex(row.lifeArea)
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(row.lifeArea.name)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(Color.tasker(.textPrimary))
                    if row.isGeneral {
                        InlineToneBadge(title: "Pinned")
                    }
                }

                Text("\(row.projectCount) projects · \(row.habitCount) habits")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.tasker(.textTertiary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AreaSummaryRow: View {
    let row: LifeManagementAreaRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AccentIconBadge(
                symbolName: row.lifeArea.icon ?? "square.grid.2x2",
                accentHex: lifeManagementAreaAccentHex(row.lifeArea)
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(row.lifeArea.name)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundStyle(Color.tasker(.textPrimary))
                Text("\(row.projectCount) projects · \(row.habitCount) habits")
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ProjectListRow: View {
    let row: LifeManagementProjectRow
    let destination: LifeManagementSelection
    let onEdit: () -> Void
    let onMove: (() -> Void)?
    let onArchive: (() -> Void)?
    let onDelete: (() -> Void)?
    let onDrag: () -> NSItemProvider

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            NavigationLink(value: destination) {
                HStack(alignment: .top, spacing: 12) {
                    AccentIconBadge(
                        symbolName: row.project.icon.systemImageName,
                        accentHex: row.project.color.hexString
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.project.name)
                            .font(.tasker(.bodyEmphasis))
                            .foregroundStyle(Color.tasker(.textPrimary))
                        Text(projectSubtitle)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker(.textSecondary))
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Menu {
                Button("Edit", systemImage: "pencil") {
                    onEdit()
                }
                if let onMove {
                    Button("Move Project", systemImage: "arrow.left.arrow.right") {
                        onMove()
                    }
                }
                if let onArchive {
                    Button(String(localized: "Archive", defaultValue: "Archive"), systemImage: "archivebox") {
                        onArchive()
                    }
                }
                if let onDelete {
                    Button("Delete", systemImage: "trash", role: .destructive) {
                        onDelete()
                    }
                }
            } label: {
                LifeManagementMenuLabel(title: "More actions", systemImage: "ellipsis.circle")
            }
            .buttonStyle(.plain)
        }
        .onDrag {
            onDrag()
        }
    }

    private var projectSubtitle: String {
        if row.taskCount == 0 {
            return "Empty"
        }
        let owner = row.lifeArea?.name ?? "No Area"
        return "\(owner) · \(row.taskCount) open tasks"
    }
}

private struct ProjectSummaryRow: View {
    let row: LifeManagementProjectRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AccentIconBadge(
                symbolName: row.project.icon.systemImageName,
                accentHex: row.project.color.hexString
            )

            VStack(alignment: .leading, spacing: 4) {
                Text(row.project.name)
                    .font(.tasker(.bodyEmphasis))
                    .foregroundStyle(Color.tasker(.textPrimary))
                Text(summarySubtitle)
                    .font(.tasker(.caption1))
                    .foregroundStyle(Color.tasker(.textSecondary))
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var summarySubtitle: String {
        if row.taskCount == 0 {
            return "Empty"
        }
        return "\(row.lifeArea?.name ?? "No Area") · \(row.taskCount) open tasks"
    }
}

private struct HabitListRow: View {
    let row: LifeManagementHabitRow
    let onOpen: () -> Void
    let onTogglePause: () -> Void
    let onArchive: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button {
                onOpen()
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    AccentIconBadge(
                        symbolName: row.row.icon?.symbolName ?? "circle.dashed",
                        accentHex: row.row.colorHex ?? lifeManagementAreaAccentHex(row.lifeArea)
                    )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(row.row.title)
                            .font(.tasker(.bodyEmphasis))
                            .foregroundStyle(Color.tasker(.textPrimary))
                        Text(habitSubtitle)
                            .font(.tasker(.caption1))
                            .foregroundStyle(Color.tasker(.textSecondary))
                    }

                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)

            Menu {
                Button(row.row.isPaused ? "Resume" : "Pause", systemImage: row.row.isPaused ? "play.fill" : "pause.fill") {
                    onTogglePause()
                }
                Button(String(localized: "Archive", defaultValue: "Archive"), systemImage: "archivebox") {
                    onArchive()
                }
            } label: {
                LifeManagementMenuLabel(title: "More actions", systemImage: "ellipsis.circle")
            }
            .buttonStyle(.plain)
        }
    }

    private var habitSubtitle: String {
        var parts: [String] = [row.row.kind == .positive ? "Build" : "Quit"]
        parts.append(lifeManagementHabitStatusText(row.row))
        return parts.joined(separator: " · ")
    }
}

private struct HabitSummaryRow: View {
    let row: LifeManagementHabitRow
    let onOpen: () -> Void

    var body: some View {
        Button {
            onOpen()
        } label: {
            HStack(alignment: .top, spacing: 12) {
                AccentIconBadge(
                    symbolName: row.row.icon?.symbolName ?? "circle.dashed",
                    accentHex: row.row.colorHex ?? lifeManagementAreaAccentHex(row.lifeArea)
                )

                VStack(alignment: .leading, spacing: 4) {
                    Text(row.row.title)
                        .font(.tasker(.bodyEmphasis))
                        .foregroundStyle(Color.tasker(.textPrimary))
                    Text(lifeManagementHabitStatusText(row.row))
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker(.textSecondary))
                }
                Spacer(minLength: 0)
            }
        }
        .buttonStyle(.plain)
    }
}

private struct HabitArchiveRow: View {
    let row: LifeManagementHabitRow
    let onOpen: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HabitSummaryRow(row: row, onOpen: onOpen)

            Menu {
                Button("Restore", systemImage: "arrow.uturn.backward") {
                    onRestore()
                }
                Button("Delete Permanently", systemImage: "trash", role: .destructive) {
                    onDelete()
                }
            } label: {
                LifeManagementMenuLabel(title: "More actions", systemImage: "ellipsis.circle")
            }
            .buttonStyle(.plain)
        }
    }
}

private struct AccentIconBadge: View {
    let symbolName: String
    let accentHex: String

    var body: some View {
        let color = Color(uiColor: UIColor(taskerHex: accentHex))
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(color.opacity(0.14))
            Image(systemName: symbolName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
        }
        .frame(width: 44, height: 44)
        .accessibilityHidden(true)
    }
}

private struct InlineToneBadge: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.tasker(.caption1).weight(.semibold))
            .foregroundStyle(Color.tasker(.accentPrimary))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.tasker(.accentWash))
            )
    }
}

private struct LifeManagementAreaDetailView: View {
    let snapshot: LifeManagementAreaDetailSnapshot?
    let onEditArea: (UUID) -> Void
    let onOpenHabit: (HabitLibraryRow) -> Void
    let onCreateHabit: (AddHabitPrefillTemplate) -> Void
    let onArchiveArea: (UUID) -> Void
    let onRestoreArea: (UUID) -> Void
    let onDeleteArea: (UUID) -> Void
    let onBeginCreateProject: (UUID) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var body: some View {
        Group {
            if let snapshot {
                let row = snapshot.row
                ScrollView {
                    VStack(spacing: spacing.s16) {
                        TaskerSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                AreaSummaryRow(row: row)
                                LifeManagementAppearanceLine(
                                    title: "Appearance",
                                    accentHex: lifeManagementAreaAccentHex(row.lifeArea),
                                    value: "Palette color"
                                )
                                if row.lifeArea.isArchived == false {
                                    Button("Edit Area") {
                                        onEditArea(row.id)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }

                        TaskerSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                                        sectionTitle("Projects")
                                        Spacer()
                                        Button("Add Project") {
                                            onBeginCreateProject(row.id)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(row.lifeArea.isArchived)
                                    }

                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        sectionTitle("Projects")
                                        Button("Add Project") {
                                            onBeginCreateProject(row.id)
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(row.lifeArea.isArchived)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                if snapshot.projectRows.isEmpty {
                                    Text("No projects in this area yet.")
                                        .font(.tasker(.callout))
                                        .foregroundStyle(Color.tasker(.textSecondary))
                                } else {
                                    VStack(spacing: spacing.chipSpacing) {
                                        ForEach(snapshot.projectRows) { projectRow in
                                            NavigationLink(value: LifeManagementSelection.project(projectRow.id)) {
                                                ProjectSummaryRow(row: projectRow)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }

                        TaskerSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                                        sectionTitle("Habits")
                                        Spacer()
                                        Button("Add Habit") {
                                            onCreateHabit(
                                                AddHabitPrefillTemplate(
                                                    title: "",
                                                    lifeAreaID: row.id
                                                )
                                            )
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(row.lifeArea.isArchived)
                                    }

                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        sectionTitle("Habits")
                                        Button("Add Habit") {
                                            onCreateHabit(
                                                AddHabitPrefillTemplate(
                                                    title: "",
                                                    lifeAreaID: row.id
                                                )
                                            )
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(row.lifeArea.isArchived)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                if snapshot.habitRows.isEmpty {
                                    Text("No habits in this area yet.")
                                        .font(.tasker(.callout))
                                        .foregroundStyle(Color.tasker(.textSecondary))
                                } else {
                                    VStack(spacing: spacing.chipSpacing) {
                                        ForEach(snapshot.habitRows) { habitRow in
                                            HabitSummaryRow(row: habitRow) {
                                                onOpenHabit(habitRow.row)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        TaskerSettingsCard(active: true) {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                sectionTitle("Actions")

                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: spacing.s8) {
                                        areaActionButtons(row: row)
                                    }

                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        areaActionButtons(row: row)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, spacing.screenHorizontal)
                    .padding(.vertical, spacing.s16)
                    .taskerReadableContent(maxWidth: 920, alignment: .center)
                }
                .background(Color.tasker(.bgCanvas))
                .navigationTitle(row.lifeArea.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Color.tasker(.bgCanvas)
                    .overlay {
                        Text("This area is no longer available.")
                            .font(.tasker(.body))
                            .foregroundStyle(Color.tasker(.textSecondary))
                    }
            }
        }
    }

    private func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(.tasker(.headline))
            .foregroundStyle(Color.tasker(.textPrimary))
    }

    @ViewBuilder
    private func areaActionButtons(row: LifeManagementAreaRow) -> some View {
        if row.lifeArea.isArchived {
            Button("Restore") {
                onRestoreArea(row.id)
            }
            .buttonStyle(.borderedProminent)
        } else if row.isGeneral == false {
            Button("Archive Area") {
                onArchiveArea(row.id)
            }
            .buttonStyle(.bordered)
        }

        if row.isGeneral == false {
            Button("Delete Area", role: .destructive) {
                onDeleteArea(row.id)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct LifeManagementProjectDetailView: View {
    let snapshot: LifeManagementProjectDetailSnapshot?
    let onEditProject: (UUID) -> Void
    let onOpenHabit: (HabitLibraryRow) -> Void
    let onCreateHabit: (AddHabitPrefillTemplate) -> Void
    let onBeginMoveProject: (UUID) -> Void
    let onArchiveProject: (UUID) -> Void
    let onRestoreProject: (UUID) -> Void
    let onDeleteProject: (UUID) -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens {
        TaskerThemeManager.shared.tokens(for: layoutClass).spacing
    }

    var body: some View {
        Group {
            if let snapshot {
                let row = snapshot.row
                let canAddLinkedHabits = row.project.isArchived == false && row.lifeArea?.isArchived != true
                ScrollView {
                    VStack(spacing: spacing.s16) {
                        TaskerSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                ProjectSummaryRow(row: row)
                                Text("\(row.project.color.displayName) · \(row.project.icon.displayName)")
                                    .font(.tasker(.caption1))
                                    .foregroundStyle(Color.tasker(.textSecondary))
                                Text(row.project.projectDescription?.nilIfBlank ?? "No project description yet.")
                                    .font(.tasker(.callout))
                                    .foregroundStyle(Color.tasker(.textSecondary))
                                if row.project.isArchived == false {
                                    Button("Edit Project") {
                                        onEditProject(row.id)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }

                        TaskerSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                Text("Structure")
                                    .font(.tasker(.headline))
                                    .foregroundStyle(Color.tasker(.textPrimary))

                                detailLine(title: "Area", value: row.lifeArea?.name ?? "No Area")
                                detailLine(title: "Open tasks", value: "\(row.taskCount)")
                                detailLine(title: "Linked habits", value: "\(snapshot.linkedHabits.count)")
                            }
                        }

                        TaskerSettingsCard {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .firstTextBaseline, spacing: spacing.s8) {
                                        Text("Linked habits")
                                            .font(.tasker(.headline))
                                            .foregroundStyle(Color.tasker(.textPrimary))
                                        Spacer()
                                        Button("Add Habit") {
                                            onCreateHabit(
                                                AddHabitPrefillTemplate(
                                                    title: "",
                                                    lifeAreaID: row.project.lifeAreaID,
                                                    projectID: row.project.id
                                                )
                                            )
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(canAddLinkedHabits == false)
                                    }

                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        Text("Linked habits")
                                            .font(.tasker(.headline))
                                            .foregroundStyle(Color.tasker(.textPrimary))
                                        Button("Add Habit") {
                                            onCreateHabit(
                                                AddHabitPrefillTemplate(
                                                    title: "",
                                                    lifeAreaID: row.project.lifeAreaID,
                                                    projectID: row.project.id
                                                )
                                            )
                                        }
                                        .buttonStyle(.bordered)
                                        .disabled(canAddLinkedHabits == false)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                if snapshot.linkedHabits.isEmpty {
                                    Text("No habits are linked to this project.")
                                        .font(.tasker(.callout))
                                        .foregroundStyle(Color.tasker(.textSecondary))
                                } else {
                                    VStack(spacing: spacing.chipSpacing) {
                                        ForEach(snapshot.linkedHabits) { habitRow in
                                            HabitSummaryRow(row: habitRow) {
                                                onOpenHabit(habitRow.row)
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        TaskerSettingsCard(active: true) {
                            VStack(alignment: .leading, spacing: spacing.s12) {
                                Text("Actions")
                                    .font(.tasker(.headline))
                                    .foregroundStyle(Color.tasker(.textPrimary))

                                ViewThatFits(in: .horizontal) {
                                    HStack(spacing: spacing.s8) {
                                        projectActionButtons(row: row)
                                    }

                                    VStack(alignment: .leading, spacing: spacing.s8) {
                                        projectActionButtons(row: row)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, spacing.screenHorizontal)
                    .padding(.vertical, spacing.s16)
                    .taskerReadableContent(maxWidth: 920, alignment: .center)
                }
                .background(Color.tasker(.bgCanvas))
                .navigationTitle(row.project.name)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                Color.tasker(.bgCanvas)
                    .overlay {
                        Text("This project is no longer available.")
                            .font(.tasker(.body))
                            .foregroundStyle(Color.tasker(.textSecondary))
                    }
            }
        }
    }

    private func detailLine(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker(.textSecondary))
            Spacer()
            Text(value)
                .font(.tasker(.bodyEmphasis))
                .foregroundStyle(Color.tasker(.textPrimary))
        }
    }

    @ViewBuilder
    private func projectActionButtons(row: LifeManagementProjectRow) -> some View {
        if row.isMoveLocked == false {
            Button("Move Project") {
                onBeginMoveProject(row.id)
            }
            .buttonStyle(.bordered)
        }

        if row.project.isArchived {
            Button("Restore") {
                onRestoreProject(row.id)
            }
            .buttonStyle(.borderedProminent)
        } else if row.isInbox == false {
            Button("Archive Project") {
                onArchiveProject(row.id)
            }
            .buttonStyle(.bordered)
        }

        if row.project.isDefault == false {
            Button("Delete Project", role: .destructive) {
                onDeleteProject(row.id)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct LifeManagementAreaComposerView: View {
    @State private var draft: LifeManagementLifeAreaDraft
    @State private var errorShakeTrigger = false
    @FocusState private var titleFieldFocused: Bool

    let iconOptions: [LifeAreaIconOption]
    let containerMode: AddTaskContainerMode
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (LifeManagementLifeAreaDraft) -> Void
    let onCancel: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var readableWidth: CGFloat {
        switch containerMode {
        case .inspector:
            return layoutClass.isPad ? 860 : 760
        case .sheet:
            return 720
        }
    }

    init(
        draft: LifeManagementLifeAreaDraft,
        iconOptions: [LifeAreaIconOption],
        containerMode: AddTaskContainerMode,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (LifeManagementLifeAreaDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.iconOptions = iconOptions
        self.containerMode = containerMode
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var canSave: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && !isSaving
    }

    private var selectedColorTitle: String {
        lifeManagementAreaPaletteMatch(for: draft.colorHex)?.title
            ?? HabitColorFamily.family(for: draft.colorHex, fallback: .green).title
    }

    private var selectedIconTitle: String {
        lifeManagementAreaIconLabel(for: draft.iconSymbolName, options: iconOptions)
    }

    var body: some View {
        VStack(spacing: 0) {
            AddTaskNavigationBar(
                containerMode: containerMode,
                title: draft.isNew ? "New Area" : "Edit Area",
                canSave: canSave
            ) {
                onCancel()
            } onSave: {
                commit()
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)

            ScrollView {
                VStack(spacing: spacing.s16) {
                    LifeManagementComposerPreviewCard(
                        eyebrow: draft.isNew ? "Create area" : "Edit area",
                        title: draft.name.nilIfBlank ?? "New area",
                        subtitle: "Define the bucket that holds related projects and habits.",
                        iconName: draft.iconSymbolName,
                        accentColor: lifeManagementResolvedColor(hex: draft.colorHex, fallback: Color.tasker.accentPrimary),
                        metrics: [
                            LifeManagementComposerPreviewMetric(title: "Accent", value: selectedColorTitle),
                            LifeManagementComposerPreviewMetric(title: "Icon", value: selectedIconTitle)
                        ]
                    )
                    .enhancedStaggeredAppearance(index: 0)

                    AddTaskTitleField(
                        text: $draft.name,
                        isFocused: $titleFieldFocused,
                        placeholder: "Name this area",
                        helperText: "Use a clear bucket like Health, Career, or Home.",
                        onSubmit: commit
                    )
                    .enhancedStaggeredAppearance(index: 1)

                    LifeManagementComposerSectionCard(
                        title: "Appearance",
                        subtitle: "Pick an accent and icon so the area is easy to spot across the app.",
                        iconSystemName: "paintpalette.fill"
                    ) {
                        VStack(alignment: .leading, spacing: spacing.s16) {
                            LifeManagementComposerFieldLabel(
                                title: "Accent",
                                detail: "Choose from the same palette used for habit accents."
                            )

                            LifeManagementAreaSwatchPicker(
                                selectedHex: $draft.colorHex
                            )

                            LifeManagementComposerFieldLabel(
                                title: "Icon",
                                detail: "Choose the symbol that best represents this part of your life."
                            )

                            LifeManagementAreaIconPicker(
                                iconOptions: iconOptions,
                                selectedSymbolName: $draft.iconSymbolName
                            )
                        }
                    }
                    .enhancedStaggeredAppearance(index: 2)

                    if let errorMessage {
                        LifeManagementComposerInlineMessage(
                            title: "Couldn’t save area",
                            message: errorMessage
                        )
                        .bellShake(trigger: $errorShakeTrigger)
                        .enhancedStaggeredAppearance(index: 3)
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s24)
            }

            AddTaskCreateButton(
                isEnabled: canSave,
                isLoading: isSaving,
                successFlash: false,
                showAddAnother: false,
                buttonTitle: draft.isNew ? "Add Area" : "Save Area",
                onCreateAction: commit,
                onAddAnotherAction: {}
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, spacing.s16)
        }
        .background(Color.tasker.bgCanvas)
        .taskerReadableContent(maxWidth: readableWidth, alignment: .center)
        .accessibilityIdentifier("settings.lifeManagement.areaComposer")
        .onAppear {
            guard containerMode == .sheet else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                titleFieldFocused = true
            }
        }
        .onChange(of: errorMessage) { _, newValue in
            if newValue != nil {
                errorShakeTrigger.toggle()
            }
        }
    }

    private func commit() {
        guard canSave else { return }
        onSave(draft)
    }
}

private struct LifeManagementProjectComposerView: View {
    @State private var draft: LifeManagementProjectDraft
    @State private var errorShakeTrigger = false
    @FocusState private var titleFieldFocused: Bool

    let lifeAreas: [LifeManagementAreaRow]
    let fallbackAreaRows: [LifeManagementAreaRow]
    let containerMode: AddTaskContainerMode
    let isSaving: Bool
    let errorMessage: String?
    let onSave: (LifeManagementProjectDraft) -> Void
    let onCancel: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }
    private var readableWidth: CGFloat {
        switch containerMode {
        case .inspector:
            return layoutClass.isPad ? 860 : 760
        case .sheet:
            return 720
        }
    }

    private var availableAreas: [LifeManagementAreaRow] {
        lifeAreas.isEmpty ? fallbackAreaRows : lifeAreas
    }

    private var canSave: Bool {
        draft.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && !isSaving
    }

    init(
        draft: LifeManagementProjectDraft,
        lifeAreas: [LifeManagementAreaRow],
        fallbackAreaRows: [LifeManagementAreaRow],
        containerMode: AddTaskContainerMode,
        isSaving: Bool,
        errorMessage: String?,
        onSave: @escaping (LifeManagementProjectDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.lifeAreas = lifeAreas
        self.fallbackAreaRows = fallbackAreaRows
        self.containerMode = containerMode
        self.isSaving = isSaving
        self.errorMessage = errorMessage
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var selectedAreaName: String {
        availableAreas.first(where: { $0.id == draft.lifeAreaID })?.lifeArea.name ?? "No area yet"
    }

    var body: some View {
        VStack(spacing: 0) {
            AddTaskNavigationBar(
                containerMode: containerMode,
                title: draft.isNew ? "New Project" : "Edit Project",
                canSave: canSave
            ) {
                onCancel()
            } onSave: {
                commit()
            }
            .padding(.horizontal, spacing.s16)
            .padding(.top, spacing.s8)

            ScrollView {
                VStack(spacing: spacing.s16) {
                    LifeManagementComposerPreviewCard(
                        eyebrow: draft.isNew ? "Create project" : "Edit project",
                        title: draft.name.nilIfBlank ?? "New project",
                        subtitle: draft.description.nilIfBlank ?? "Projects group related tasks inside an area.",
                        iconName: draft.icon.systemImageName,
                        accentColor: lifeManagementResolvedColor(hex: draft.color.hexString, fallback: Color.tasker.accentPrimary),
                        metrics: [
                            LifeManagementComposerPreviewMetric(title: "Area", value: selectedAreaName),
                            LifeManagementComposerPreviewMetric(title: "Accent", value: draft.color.displayName)
                        ]
                    )
                    .enhancedStaggeredAppearance(index: 0)

                    AddTaskTitleField(
                        text: $draft.name,
                        isFocused: $titleFieldFocused,
                        placeholder: "Name this project",
                        helperText: "Keep it specific enough that it still makes sense later.",
                        onSubmit: commit
                    )
                    .enhancedStaggeredAppearance(index: 1)

                    LifeManagementComposerSectionCard(
                        title: "Essentials",
                        subtitle: "Set the project’s name, a short description, and where it belongs.",
                        iconSystemName: "text.alignleft"
                    ) {
                        VStack(alignment: .leading, spacing: spacing.s16) {
                            VStack(alignment: .leading, spacing: spacing.s8) {
                                LifeManagementComposerFieldLabel(
                                    title: "Description",
                                    detail: "Optional, but useful when the project name needs context."
                                )

                                TextField("What is this project for?", text: $draft.description, axis: .vertical)
                                    .textFieldStyle(TaskerTextFieldStyle())
                                    .lineLimit(3, reservesSpace: true)
                            }

                            AddTaskEntityPicker(
                                label: "Area",
                                items: availableAreas.map {
                                    AddTaskEntityPickerItem(
                                        id: $0.id,
                                        name: $0.lifeArea.name,
                                        icon: $0.lifeArea.icon,
                                        accentHex: LifeAreaColorPalette.normalizeOrMap(hex: $0.lifeArea.color, for: $0.id)
                                    )
                                },
                                selectedID: $draft.lifeAreaID
                            )
                        }
                    }
                    .enhancedStaggeredAppearance(index: 2)

                    LifeManagementComposerSectionCard(
                        title: "Appearance",
                        subtitle: "Choose an accent and icon that make this project easy to scan in lists.",
                        iconSystemName: "paintbrush.pointed.fill"
                    ) {
                        VStack(alignment: .leading, spacing: spacing.s16) {
                            LifeManagementComposerFieldLabel(
                                title: "Accent",
                                detail: "Project colors already map to the app’s built-in palette."
                            )

                            LifeManagementProjectColorPicker(selectedColor: $draft.color)

                            LifeManagementComposerFieldLabel(
                                title: "Icon",
                                detail: "Pick the symbol that fits this project best."
                            )

                            LifeManagementProjectIconPicker(selectedIcon: $draft.icon)
                        }
                    }
                    .enhancedStaggeredAppearance(index: 3)

                    if let errorMessage {
                        LifeManagementComposerInlineMessage(
                            title: "Couldn’t save project",
                            message: errorMessage
                        )
                        .bellShake(trigger: $errorShakeTrigger)
                        .enhancedStaggeredAppearance(index: 4)
                    }
                }
                .padding(.horizontal, spacing.s16)
                .padding(.top, spacing.s8)
                .padding(.bottom, spacing.s24)
            }

            AddTaskCreateButton(
                isEnabled: canSave,
                isLoading: isSaving,
                successFlash: false,
                showAddAnother: false,
                buttonTitle: draft.isNew ? "Add Project" : "Save Project",
                onCreateAction: commit,
                onAddAnotherAction: {}
            )
            .padding(.horizontal, spacing.s16)
            .padding(.bottom, spacing.s16)
        }
        .background(Color.tasker.bgCanvas)
        .taskerReadableContent(maxWidth: readableWidth, alignment: .center)
        .accessibilityIdentifier("settings.lifeManagement.projectComposer")
        .onAppear {
            guard containerMode == .sheet else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                titleFieldFocused = true
            }
        }
        .onChange(of: errorMessage) { _, newValue in
            if newValue != nil {
                errorShakeTrigger.toggle()
            }
        }
    }

    private func commit() {
        guard canSave else { return }
        onSave(draft)
    }
}

private struct LifeManagementComposerPreviewMetric: Identifiable, Equatable {
    let title: String
    let value: String

    var id: String { title }
}

private struct LifeManagementAreaPaletteOption: Identifiable, Equatable {
    let id: String
    let title: String
    let hex: String
}

private struct LifeManagementComposerPreviewCard: View {
    let eyebrow: String
    let title: String
    let subtitle: String
    let iconName: String
    let accentColor: Color
    let metrics: [LifeManagementComposerPreviewMetric]

    @Environment(\.taskerLayoutClass) private var layoutClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    private var previewSignature: String {
        "\(title)-\(subtitle)-\(iconName)-\(metrics.map(\.value).joined(separator: "|"))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.18))
                        .frame(width: 58, height: 58)

                    Group {
                        if reduceMotion {
                            Image(systemName: iconName)
                        } else {
                            Image(systemName: iconName)
                                .symbolEffect(.bounce, value: previewSignature)
                        }
                    }
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.white)
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(eyebrow)
                        .font(.tasker(.eyebrow))
                        .foregroundStyle(Color.white.opacity(0.78))

                    Text(title)
                        .font(.tasker(.title2).weight(.semibold))
                        .foregroundStyle(Color.white)
                        .contentTransition(.opacity)
                        .lineLimit(2)

                    Text(subtitle)
                        .font(.tasker(.callout))
                        .foregroundStyle(Color.white.opacity(0.84))
                        .contentTransition(.opacity)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if metrics.isEmpty == false {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: spacing.s8) {
                        ForEach(metrics) { metric in
                            LifeManagementComposerMetricTile(metric: metric)
                        }
                    }

                    VStack(spacing: spacing.s8) {
                        ForEach(metrics) { metric in
                            LifeManagementComposerMetricTile(metric: metric)
                        }
                    }
                }
            }
        }
        .padding(spacing.s16)
        .background(
            LinearGradient(
                colors: [
                    accentColor.opacity(0.92),
                    accentColor.opacity(0.58),
                    Color.tasker.surfacePrimary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            LinearGradient(
                colors: [
                    Color.black.opacity(0.10),
                    Color.black.opacity(0.03),
                    Color.white.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .taskerPremiumSurface(
            cornerRadius: TaskerTheme.CornerRadius.card,
            fillColor: .clear,
            strokeColor: Color.white.opacity(0.16),
            accentColor: accentColor,
            level: .e2
        )
        .animation(reduceMotion ? nil : TaskerAnimation.heroEmphasis, value: previewSignature)
    }
}

private struct LifeManagementComposerMetricTile: View {
    let metric: LifeManagementComposerPreviewMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(metric.title)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.white.opacity(0.72))

            Text(metric.value)
                .font(.tasker(.callout).weight(.semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

private struct LifeManagementComposerSectionCard<Content: View>: View {
    let title: String
    let subtitle: String
    let iconSystemName: String
    let content: Content

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    init(
        title: String,
        subtitle: String,
        iconSystemName: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconSystemName = iconSystemName
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s12) {
            HStack(alignment: .top, spacing: spacing.s8) {
                Image(systemName: iconSystemName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.tasker.accentPrimary)
                    .frame(width: 24, height: 24)

                VStack(alignment: .leading, spacing: spacing.s4) {
                    Text(title)
                        .font(.tasker(.headline))
                        .foregroundStyle(Color.tasker.textPrimary)

                    Text(subtitle)
                        .font(.tasker(.caption1))
                        .foregroundStyle(Color.tasker.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            content
        }
        .padding(spacing.s16)
        .taskerDenseSurface(cornerRadius: TaskerTheme.CornerRadius.card, fillColor: Color.tasker.surfacePrimary)
    }
}

private struct LifeManagementComposerFieldLabel: View {
    let title: String
    let detail: String

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text(title)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundStyle(Color.tasker.textPrimary)

            Text(detail)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)
        }
    }
}

private struct LifeManagementComposerInlineMessage: View {
    let title: String
    let message: String

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing.s4) {
            Text(title)
                .font(.tasker(.caption1).weight(.semibold))
                .foregroundStyle(Color.tasker.statusDanger)

            Text(message)
                .font(.tasker(.caption1))
                .foregroundStyle(Color.tasker.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(spacing.s12)
        .taskerDenseSurface(
            cornerRadius: TaskerTheme.CornerRadius.md,
            fillColor: Color.tasker.statusDanger.opacity(0.08),
            strokeColor: Color.tasker.statusDanger.opacity(0.18)
        )
    }
}

private struct LifeManagementAreaSwatchPicker: View {
    @Binding var selectedHex: String

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s8) {
                ForEach(lifeManagementAreaPaletteOptions()) { option in
                    LifeManagementColorSwatchButton(
                        title: option.title,
                        color: lifeManagementResolvedColor(hex: option.hex, fallback: Color.tasker.surfaceSecondary),
                        systemImage: nil,
                        isSelected: lifeManagementNormalizedHex(selectedHex) == lifeManagementNormalizedHex(option.hex)
                    ) {
                        withAnimation(TaskerAnimation.snappy) {
                            selectedHex = option.hex
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct LifeManagementProjectColorPicker: View {
    @Binding var selectedColor: ProjectColor

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: spacing.s8) {
                ForEach(ProjectColor.allCases, id: \.rawValue) { color in
                    LifeManagementColorSwatchButton(
                        title: color.displayName,
                        color: lifeManagementResolvedColor(hex: color.hexString, fallback: Color.tasker.accentPrimary),
                        systemImage: nil,
                        isSelected: selectedColor == color
                    ) {
                        withAnimation(TaskerAnimation.snappy) {
                            selectedColor = color
                        }
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }
}

private struct LifeManagementColorSwatchButton: View {
    let title: String
    let color: Color?
    let systemImage: String?
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        Button {
            TaskerFeedback.selection()
            action()
        } label: {
            VStack(spacing: spacing.s8) {
                ZStack {
                    Circle()
                        .fill(color ?? Color.tasker.surfaceSecondary)
                        .frame(width: 26, height: 26)

                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(color == nil ? Color.tasker.textSecondary : Color.white)
                    }
                }
                .overlay(
                    Circle()
                        .stroke(isSelected ? Color.tasker.accentPrimary : Color.tasker.strokeHairline, lineWidth: isSelected ? 2 : 1)
                )

                Text(title)
                    .font(.tasker(.caption1))
                    .foregroundStyle(isSelected ? Color.tasker.textPrimary : Color.tasker.textSecondary)
                    .lineLimit(1)
            }
            .frame(width: 74)
            .frame(minHeight: 76)
            .padding(.vertical, spacing.s8)
            .background(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                    .fill(isSelected ? Color.tasker.accentWash : Color.tasker.surfaceSecondary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.tasker.accentMuted : Color.tasker.strokeHairline.opacity(0.72), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .animation(reduceMotion ? nil : TaskerAnimation.quick, value: isSelected)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

private struct LifeManagementAreaIconPicker: View {
    let iconOptions: [LifeAreaIconOption]
    @Binding var selectedSymbolName: String

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 88 : 74), spacing: spacing.s8)],
            spacing: spacing.s8
        ) {
            ForEach(iconOptions) { option in
                LifeManagementIconTile(
                    systemImage: option.symbolName,
                    title: option.keywords.first?.capitalized ?? option.symbolName,
                    isSelected: selectedSymbolName == option.symbolName
                ) {
                    withAnimation(TaskerAnimation.snappy) {
                        selectedSymbolName = option.symbolName
                    }
                }
            }
        }
    }
}

private struct LifeManagementProjectIconPicker: View {
    @Binding var selectedIcon: ProjectIcon

    @Environment(\.taskerLayoutClass) private var layoutClass

    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: layoutClass.isPad ? 88 : 74), spacing: spacing.s8)],
            spacing: spacing.s8
        ) {
            ForEach(ProjectIcon.allCases, id: \.rawValue) { icon in
                LifeManagementIconTile(
                    systemImage: icon.systemImageName,
                    title: icon.displayName,
                    isSelected: selectedIcon == icon
                ) {
                    withAnimation(TaskerAnimation.snappy) {
                        selectedIcon = icon
                    }
                }
            }
        }
    }
}

private struct LifeManagementIconTile: View {
    let systemImage: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.taskerLayoutClass) private var layoutClass
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.tokens(for: layoutClass).spacing }

    var body: some View {
        Button {
            TaskerFeedback.selection()
            action()
        } label: {
            VStack(spacing: spacing.s8) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.tasker.accentWash : Color.tasker.surfaceSecondary)
                    .frame(height: 46)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(isSelected ? Color.tasker.accentPrimary : Color.tasker.textSecondary)
                    }

                Text(title)
                    .font(.tasker(.caption1))
                    .foregroundStyle(isSelected ? Color.tasker.textPrimary : Color.tasker.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            .padding(spacing.s8)
            .frame(minHeight: 96)
            .background(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                    .fill(Color.tasker.surfacePrimary)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TaskerTheme.CornerRadius.md, style: .continuous)
                    .stroke(isSelected ? Color.tasker.accentPrimary.opacity(0.34) : Color.tasker.strokeHairline.opacity(0.72), lineWidth: isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .scaleOnPress()
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }
}

@MainActor
private func lifeManagementAreaPaletteOptions() -> [LifeManagementAreaPaletteOption] {
    HabitColorFamily.allCases.map { family in
        LifeManagementAreaPaletteOption(
            id: family.rawValue,
            title: family.title,
            hex: family.canonicalHex
        )
    }
}

@MainActor
private func lifeManagementAreaPaletteMatch(for hex: String) -> LifeManagementAreaPaletteOption? {
    let normalizedHex = lifeManagementNormalizedHex(hex)
    return lifeManagementAreaPaletteOptions().first { option in
        lifeManagementNormalizedHex(option.hex) == normalizedHex
    }
}

private func lifeManagementResolvedColor(hex: String?, fallback: Color) -> Color {
    guard let normalizedHex = lifeManagementResolvedHex(hex) else { return fallback }
    return Color(uiColor: UIColor(taskerHex: normalizedHex))
}

private func lifeManagementResolvedHex(_ hex: String?) -> String? {
    let normalized = lifeManagementNormalizedHex(hex ?? "")
    guard normalized.isEmpty == false, normalized.count == 6 || normalized.count == 8 else {
        return nil
    }
    return normalized
}

private func lifeManagementNormalizedHex(_ hex: String) -> String {
    hex.trimmingCharacters(in: .whitespacesAndNewlines)
        .replacingOccurrences(of: "#", with: "")
        .uppercased()
}

private func lifeManagementAreaIconLabel(for symbolName: String, options: [LifeAreaIconOption]) -> String {
    options.first(where: { $0.symbolName == symbolName })?.keywords.first?.capitalized ?? symbolName
}

private struct ProjectMoveSheet: View {
    @State private var draft: LifeManagementProjectMoveDraft
    let targets: [LifeManagementAreaRow]
    let isSaving: Bool
    let onSave: (LifeManagementProjectMoveDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: LifeManagementProjectMoveDraft,
        targets: [LifeManagementAreaRow],
        isSaving: Bool,
        onSave: @escaping (LifeManagementProjectMoveDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.targets = targets
        self.isSaving = isSaving
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
                    Text(draft.projectName)
                }

                Section("Move to Area") {
                    Picker("Area", selection: $draft.targetLifeAreaID) {
                        ForEach(targets) { target in
                            Text(target.lifeArea.name).tag(Optional(target.id))
                        }
                    }
                }
            }
            .navigationTitle("Move Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Move") {
                        onSave(draft)
                    }
                    .disabled(isSaving || draft.targetLifeAreaID == nil)
                }
            }
        }
    }
}

private struct DeleteAreaSheet: View {
    @State private var draft: LifeManagementDeleteAreaDraft
    let targets: [LifeManagementAreaRow]
    let isSaving: Bool
    let onSave: (LifeManagementDeleteAreaDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: LifeManagementDeleteAreaDraft,
        targets: [LifeManagementAreaRow],
        isSaving: Bool,
        onSave: @escaping (LifeManagementDeleteAreaDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.targets = targets
        self.isSaving = isSaving
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Delete Area") {
                    Text("\(draft.areaName) has \(draft.projectCount) projects and \(draft.habitCount) habits. Move them to another area before you delete it.")
                }

                Section("Move items to") {
                    Picker("Destination", selection: $draft.destinationLifeAreaID) {
                        ForEach(targets) { target in
                            Text(target.lifeArea.name).tag(Optional(target.id))
                        }
                    }
                }
            }
            .navigationTitle("Delete Area")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete", role: .destructive) {
                        onSave(draft)
                    }
                    .disabled(isSaving || draft.destinationLifeAreaID == nil)
                }
            }
        }
    }
}

private struct DeleteProjectSheet: View {
    @State private var draft: LifeManagementDeleteProjectDraft
    let targets: [LifeManagementProjectRow]
    let isSaving: Bool
    let onSave: (LifeManagementDeleteProjectDraft) -> Void
    let onCancel: () -> Void

    init(
        draft: LifeManagementDeleteProjectDraft,
        targets: [LifeManagementProjectRow],
        isSaving: Bool,
        onSave: @escaping (LifeManagementDeleteProjectDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        _draft = State(initialValue: draft)
        self.targets = targets
        self.isSaving = isSaving
        self.onSave = onSave
        self.onCancel = onCancel
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Delete Project") {
                    Text("\(draft.projectName) has \(draft.taskCount) open tasks and \(draft.linkedHabitCount) linked habits. Move the open tasks before you delete it.")
                }

                Section("Move open tasks to") {
                    Picker("Project", selection: $draft.destinationProjectID) {
                        ForEach(targets) { target in
                            Text(target.project.name).tag(Optional(target.id))
                        }
                    }
                }
            }
            .navigationTitle("Delete Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Delete", role: .destructive) {
                        onSave(draft)
                    }
                    .disabled(isSaving || draft.destinationProjectID == nil)
                }
            }
        }
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
