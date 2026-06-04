import SwiftUI
import UIKit

extension LifeManagementView {
    @ViewBuilder
    func nodeMenu(_ node: LifeManagementTreeNode) -> some View {
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
    var detailPane: some View {
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
    func detailDestination(for selection: LifeManagementSelection) -> some View {
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
    func composerDestination(for route: LifeManagementComposerRoute, containerMode: AddTaskContainerMode) -> some View {
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
    var toolbarContent: some ToolbarContent {
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

    func errorCard(message: String) -> some View {
        LifeBoardSettingsCard(active: true) {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Label("Couldn’t complete the last action", systemImage: "exclamationmark.triangle.fill")
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard(.textPrimary))

                Text(message)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
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

    func presentHabitComposer(prefill: AddHabitPrefillTemplate? = nil) {
        habitComposerViewModel.resetForm()
        if let prefill {
            habitComposerViewModel.applyPrefill(prefill)
        }
        habitComposerPresented = true
    }

    var habitComposerSheet: some View {
        SunriseAddHabitSheetView(
            viewModel: habitComposerViewModel,
            onHabitCreated: { _ in
                habitComposerPresented = false
                viewModel.reload()
            },
            onDismissWithoutHabit: {
                habitComposerPresented = false
            }
        )
    }

    var mutationPill: some View {
        HStack(spacing: spacing.s8) {
            ProgressView()
                .controlSize(.small)
            Text("Updating life management...")
                .font(.lifeboard(.caption1))
                .foregroundStyle(Color.lifeboard(.textSecondary))
        }
        .padding(.horizontal, spacing.s12)
        .padding(.vertical, spacing.s8)
        .background(Color.lifeboard(.surfacePrimary), in: Capsule())
        .padding(.bottom, spacing.s8)
    }

    func emptyStateCard(
        title: String,
        body: String,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        LifeBoardSettingsCard {
            VStack(alignment: .leading, spacing: spacing.s12) {
                Text(title)
                    .font(.lifeboard(.headline))
                    .foregroundStyle(Color.lifeboard(.textPrimary))

                Text(body)
                    .font(.lifeboard(.callout))
                    .foregroundStyle(Color.lifeboard(.textSecondary))
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
