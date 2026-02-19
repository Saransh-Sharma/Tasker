import SwiftUI

struct ProjectManagementView: View {
    @StateObject private var viewModel: ProjectManagementViewModel
    @State private var showingCreateDialog = false
    @State private var newProjectName = ""
    @State private var newProjectDescription = ""

    init(viewModel: ProjectManagementViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        List {
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
            }
            .onDelete(perform: deleteProjects)
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
        .navigationTitle("Projects")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreateDialog = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
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
        }
    }

    private func deleteProjects(at offsets: IndexSet) {
        for index in offsets {
            guard viewModel.filteredProjects.indices.contains(index) else { continue }
            let entry = viewModel.filteredProjects[index]
            guard entry.project.id != ProjectConstants.inboxProjectID else { continue }
            viewModel.deleteProject(entry, strategy: .moveToInbox)
        }
    }

    private func normalizedDescription() -> String? {
        let trimmed = newProjectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

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
