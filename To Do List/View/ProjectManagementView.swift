import SwiftUI
import FluentUI // If specific FluentUI components will be used directly

struct ProjectManagementView: View {
    let todoColors = ToDoColors() // Instantiate ToDoColors

    @ObservedObject var projectManager = ProjectManager.sharedInstance
    @State private var showingAddProjectAlert = false
    @State private var newProjectName = ""
    @State private var newProjectDescription = ""

    // For status alert after save attempt
    @State private var showingStatusAlert = false
    @State private var statusAlertTitle = ""
    @State private var statusAlertMessage = ""

    // States for Edit
    @State private var showingEditProjectAlert = false
    @State private var projectToEdit: Projects? = nil
    @State private var editProjectName = ""
    @State private var editProjectDescription = ""

    // States for Delete
    @State private var showingDeleteConfirmAlert = false
    @State private var projectToDelete: Projects? = nil

    var body: some View {
        // Note: NavigationView wrapper is removed from here, assuming it's part of SettingsView's navigation stack.
        VStack {
            // Use `projectManager.displayedProjects` which is a computed property
            // and does not trigger fetches on its own.
            if projectManager.displayedProjects.filter({ $0.projectName?.lowercased() != projectManager.defaultProject.lowercased() }).isEmpty && projectManager.projects.count <= 1 { // Check if only Inbox exists or it's truly empty
                Text("Tap '+' to add your first custom project") // Modified empty state text
                    .foregroundColor(.gray)
                    .padding()
                Spacer() // Push text to center or top
            } else {
                List {
                    ForEach(projectManager.displayedProjects, id: \.objectID) { project in
                        VStack(alignment: .leading) {
                                Text(project.projectName ?? "Unknown Project")
                                    .font(.headline)
                                // Display description only if it's not empty
                                if let description = project.projecDescription, !description.isEmpty {
                                    Text(description)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                        }
                        .contentShape(Rectangle()) // Ensure the whole area is tappable for context menu
                        .contextMenu {
                            if project.projectName?.lowercased() != projectManager.defaultProject.lowercased() {
                                Button("Edit") {
                                    projectToEdit = project
                                    editProjectName = project.projectName ?? ""
                                    editProjectDescription = project.projecDescription ?? ""
                                    showingEditProjectAlert = true
                                }
                                Button("Delete", role: .destructive) {
                                    projectToDelete = project
                                    showingDeleteConfirmAlert = true
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Projects")
        // .navigationBarTitleDisplayMode(.inline) // Optional: if you want a smaller title
        .navigationBarItems(trailing: Button(action: {
            // Reset fields before showing
            newProjectName = ""
            newProjectDescription = ""
            showingAddProjectAlert = true
        }) {
            Image(systemName: "plus")
                .foregroundColor(Color(todoColors.primaryColor))
        })
        .alert("New Project", isPresented: $showingAddProjectAlert) {
            TextField("Project Name", text: $newProjectName)
            TextField("Description (Optional)", text: $newProjectDescription)
            Button("Save") {
                let success = projectManager.addNewProject(with: newProjectName, and: newProjectDescription)
                if success {
                    statusAlertTitle = "Success"
                    statusAlertMessage = "Project added successfully."
                } else {
                    statusAlertTitle = "Error"
                    statusAlertMessage = "Failed to add project. Name may be empty, 'Inbox', or already exist."
                }
                showingStatusAlert = true
            }
            Button("Cancel", role: .cancel) { }
        }
        .alert(statusAlertTitle, isPresented: $showingStatusAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(statusAlertMessage)
        }
        .alert("Edit Project", isPresented: $showingEditProjectAlert) {
            TextField("Project Name", text: $editProjectName)
            TextField("Description (Optional)", text: $editProjectDescription)
            Button("Save") {
                if let project = projectToEdit {
                    let success = projectManager.updateProject(project, newName: editProjectName, newDescription: editProjectDescription)
                    if success {
                        statusAlertTitle = "Success"
                        statusAlertMessage = "Project updated."
                    } else {
                        statusAlertTitle = "Error"
                        statusAlertMessage = "Failed to update project. Name may be invalid, 'Inbox', or already exist."
                    }
                    showingStatusAlert = true
                }
                projectToEdit = nil
                editProjectName = ""
                editProjectDescription = ""
            }
            Button("Cancel", role: .cancel) {
                projectToEdit = nil
                editProjectName = ""
                editProjectDescription = ""
            }
        }
        .alert("Delete Project", isPresented: $showingDeleteConfirmAlert) {
            Button("Delete", role: .destructive) {
                if let project = projectToDelete {
                    let success = projectManager.deleteProject(project)
                    if success {
                        statusAlertTitle = "Success"
                        statusAlertMessage = "Project deleted and tasks moved to Inbox."
                    } else {
                        statusAlertTitle = "Error"
                        statusAlertMessage = "Failed to delete project."
                    }
                    showingStatusAlert = true
                }
                projectToDelete = nil
            }
            Button("Cancel", role: .cancel) { projectToDelete = nil }
        } message: {
            Text("Delete '\(projectToDelete?.projectName ?? "Selected")' project? Tasks will be moved to 'Inbox'.")
        }
        .onAppear {
            // Asynchronously call the centralized data loading and preparation method.
            DispatchQueue.main.async {
                projectManager.refreshAndPrepareProjects()
            }
        }
    }
}

// Preview (Optional, but helpful)
struct ProjectManagementView_Previews: PreviewProvider {
    static var previews: some View {
        // For the preview to work well, you might need to ensure ProjectManager.sharedInstance
        // has some mock data or its init/refreshAndPrepareProjects can run in a preview context.
        NavigationView { // Wrap in NavigationView for previewing navigation bar items
            ProjectManagementView()
        }
    }
}
