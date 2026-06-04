import SwiftUI
import UIKit

struct LifeManagementView: View {


    @StateObject var viewModel: LifeManagementViewModel

    @StateObject var habitComposerViewModel = PresentationDependencyContainer.shared.makeNewAddHabitViewModel()

    @State var habitComposerPresented = false

    @State var selectedHabitRow: HabitLibraryRow?

    @Environment(\.lifeboardLayoutClass) var layoutClass

    @Environment(\.accessibilityReduceMotion) var accessibilityReduceMotion

    init(viewModel: LifeManagementViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if layoutClass.isPad {
                splitBrowser
            } else {
                compactBrowser
            }
        }
        .background(Color.lifeboard(.bgCanvas))
        .navigationTitle("Life Management")
        .navigationBarTitleDisplayMode(.inline)
        .accessibilityIdentifier("settings.lifeManagement.view")
        .searchable(text: $viewModel.searchQuery, prompt: "Search areas, projects, habits")
        .toolbar { toolbarContent }
        .overlay {
            if viewModel.isLoading && hasTreeContent == false {
                ProgressView("Loading life management...")
                    .font(.lifeboard(.body))
                    .padding(.horizontal, spacing.s16)
                    .padding(.vertical, spacing.s12)
                    .background(
                        Color.lifeboard.surfacePrimary,
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                    )
            }
        }
        .safeAreaInset(edge: .bottom) {
            if viewModel.isMutating {
                mutationPill
            }
        }
        .lifeboardSnackbar($viewModel.snackbar)
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
                .presentationBackground(Color.lifeboard(.bgElevated))
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
            SunriseHabitDetailScreen(
                viewModel: PresentationDependencyContainer.shared.makeHabitDetailViewModel(row: row),
                onMutation: {
                    viewModel.reload()
                }
            )
        }
    }
}
