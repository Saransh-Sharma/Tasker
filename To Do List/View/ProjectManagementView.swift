import SwiftUI

struct ProjectManagementView: View {
    /// Initializes a new instance.
    @StateObject private var viewModel: ProjectManagementViewModel
    @Environment(\.taskerLayoutClass) private var layoutClass
    @State private var showingCreateDialog = false
    @State private var newProjectName = ""
    @State private var newProjectDescription = ""
    @State private var selectedProjectID: UUID?

    private var supportsIPadSplit: Bool {
        layoutClass.isPad
    }

    private var selectedProjectEntry: ProjectWithStats? {
        guard let selectedProjectID else { return nil }
        return viewModel.filteredProjects.first(where: { $0.project.id == selectedProjectID })
    }

    init(viewModel: ProjectManagementViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        Group {
            if supportsIPadSplit {
                NavigationSplitView {
                    projectList(selection: $selectedProjectID)
                        .navigationTitle("Projects")
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                createButton
                            }
                        }
                } detail: {
                    projectDetailPanel
                }
                .navigationSplitViewStyle(.balanced)
                .onChange(of: selectedProjectID) { _, newValue in
                    guard let newValue else { return }
                    if let selected = viewModel.filteredProjects.first(where: { $0.project.id == newValue }) {
                        viewModel.selectProject(selected)
                    }
                }
            } else {
                projectList(selection: .constant(nil))
                    .navigationTitle("Projects")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            createButton
                        }
                    }
                    .overlay {
                        if viewModel.filteredProjects.filter({ $0.project.id != ProjectConstants.inboxProjectID }).isEmpty {
                            ContentUnavailableView(
                                "No Custom Projects",
                                systemImage: "folder.badge.plus",
                                description: Text("Tap + to create your first custom project")
                            )
                        }
                    }
            }
        }
        .accessibilityIdentifier("projectManagement.view")
        .alert("New Project", isPresented: $showingCreateDialog) {
            TextField("Project Name", text: $newProjectName)
            TextField("Description (Optional)", text: $newProjectDescription)
            Button("Cancel", role: .cancel) {
                resetDraft()
            }
            Button("Create") {
                let trimmedName = newProjectName.trimmingCharacters(in: .whitespacesAndNewlines)
                guard trimmedName.isEmpty == false else { return }
                viewModel.createProject(name: trimmedName, description: normalizedDescription())
                resetDraft()
            }
        } message: {
            Text("Create a new project under your life areas.")
        }
        .task {
            viewModel.loadProjects()
            if supportsIPadSplit {
                autoSelectFirstProjectIfNeeded()
            }
        }
        .onChange(of: viewModel.filteredProjects.map(\.project.id)) { _, _ in
            guard supportsIPadSplit else { return }
            autoSelectFirstProjectIfNeeded()
        }
    }

    @ViewBuilder
    private func projectList(selection: Binding<UUID?>) -> some View {
        List(selection: selection) {
            ForEach(viewModel.filteredProjects, id: \.project.id) { entry in
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.project.name)
                        .font(.headline)
                    if let description = entry.project.projectDescription, description.isEmpty == false {
                        Text(description)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(entry.taskCount) tasks")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .tag(entry.project.id)
            }
            .onDelete(perform: deleteProjects)
        }
        .accessibilityIdentifier("projectManagement.projectsList")
    }

    @ViewBuilder
    private var projectDetailPanel: some View {
        if let selected = selectedProjectEntry {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(selected.project.name)
                        .font(.title2.weight(.semibold))

                    if let description = selected.project.projectDescription, description.isEmpty == false {
                        Text(description)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        projectMetricCard(
                            title: "Open",
                            value: "\(max(0, selected.taskCount - selected.completedTaskCount))"
                        )
                        projectMetricCard(
                            title: "Completed",
                            value: "\(selected.completedTaskCount)"
                        )
                        projectMetricCard(
                            title: "Total",
                            value: "\(selected.taskCount)"
                        )
                    }

                    if selected.project.id == ProjectConstants.inboxProjectID {
                        Text("Inbox is your capture project and cannot be deleted.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("Swipe left on the project in the list to delete it.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .taskerReadableContent(maxWidth: 860, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .background(Color.tasker(.bgCanvas))
            .navigationTitle(selected.project.name)
        } else {
            ContentUnavailableView(
                "Select a Project",
                systemImage: "folder",
                description: Text("Choose a project from the sidebar to inspect details.")
            )
        }
    }

    private var createButton: some View {
        Button {
            showingCreateDialog = true
        } label: {
            Image(systemName: "plus")
        }
        .accessibilityIdentifier("projectManagement.addProjectButton")
    }

    private func projectMetricCard(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
                .foregroundColor(.tasker(.textPrimary))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.tasker(.surfaceSecondary), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func autoSelectFirstProjectIfNeeded() {
        guard selectedProjectID == nil else { return }
        guard let firstProject = viewModel.filteredProjects.first else { return }
        selectedProjectID = firstProject.project.id
        viewModel.selectProject(firstProject)
    }

    /// Executes deleteProjects.
    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            guard viewModel.filteredProjects.indices.contains(index) else { continue }
            let entry = viewModel.filteredProjects[index]
            guard entry.project.id != ProjectConstants.inboxProjectID else { continue }
            viewModel.deleteProject(entry, strategy: .moveToInbox)
        }
    }

    /// Executes normalizedDescription.
    private func normalizedDescription() -> String? {
        let trimmed = newProjectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Executes resetDraft.
    private func resetDraft() {
        newProjectName = ""
        newProjectDescription = ""
    }
}

struct ProjectManagementView_Previews: PreviewProvider {
    static var previews: some View {
        Text("ProjectManagementView preview requires an injected ProjectManagementViewModel.")
    }
}
