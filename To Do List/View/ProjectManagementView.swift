import SwiftUI
import FluentUI // If specific FluentUI components will be used directly
// Potentially import CoreData if Projects entity is used directly

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
        NavigationView {
            VStack { // Use VStack to accommodate empty state view
                // Filter out the default "Inbox" project for the empty state check
                if projectManager.getAllProjects.filter({ $0.projectName?.lowercased() != projectManager.defaultProject.lowercased() }).isEmpty {
                    Text("Tap '+' to add your first custom project") // Modified empty state text
                        .foregroundColor(.gray)
                        .padding()
                    Spacer() // Push text to center or top
                } else {
                    List {
                        ForEach(projectManager.getAllProjects, id: \.objectID) { project in // Use objectID for stable identity
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
                                        editProjectDescription = project.projecDescription ?? "" // Corrected typo from projecDescription
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
            .navigationBarItems(trailing: Button(action: {
                // Reset fields before showing
                newProjectName = ""
                newProjectDescription = ""
                showingAddProjectAlert = true
            }) {
                Image(systemName: "plus")
                    .foregroundColor(Color(todoColors.primaryColor))
            })
            // As with SettingsView, .navigationBarTitle color is tricky.
            // Rely on global appearance or default.
            .alert("New Project", isPresented: $showingAddProjectAlert) { // Main alert for adding
                TextField("Project Name", text: $newProjectName)
                TextField("Description (Optional)", text: $newProjectDescription)
                Button("Save") {
                    let success = projectManager.addNewProject(with: newProjectName, and: newProjectDescription)
                    if success {
                        statusAlertTitle = "Success"
                        statusAlertMessage = "Project added successfully."
                    } else {
                        statusAlertTitle = "Error"
                        // ProjectManager.addNewProject has internal checks.
                        // A more specific error message could be derived if ProjectManager provided it.
                        statusAlertMessage = "Failed to add project. Name may be empty, 'Inbox', or already exist."
                    }
                    showingStatusAlert = true // Trigger the status alert
                }
                Button("Cancel", role: .cancel) { }
            }
            .alert(statusAlertTitle, isPresented: $showingStatusAlert) { // Status alert
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
                    projectToEdit = nil // Clear after use
                    editProjectName = "" // Reset field
                    editProjectDescription = "" // Reset field
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
                            // This should ideally not happen if "Inbox" is protected by context menu logic
                            statusAlertMessage = "Failed to delete project. The 'Inbox' project cannot be deleted."
                        }
                        showingStatusAlert = true
                    }
                    projectToDelete = nil // Clear after use
                }
                Button("Cancel", role: .cancel) { projectToDelete = nil }
            } message: {
                // Provide a default name if projectToDelete or its name is nil temporarily during alert presentation
                Text("Delete '\(projectToDelete?.projectName ?? "Selected")' project? Tasks will be moved to 'Inbox'.")
            }
            .onAppear {
                // Ensure projects (especially default "Inbox") are loaded and consistent when the view appears.
                // getAllProjects will be called by the ForEach, which in turn calls fetchProjects.
                // Calling fixMissingProjecsDataWithDefaults also calls fetchProjects and ensures Inbox integrity.
                projectManager.fixMissingProjecsDataWithDefaults()
            }
        }
    }
}

// Preview (Optional, but good practice)
struct ProjectManagementView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectManagementView()
    }
}
