import SwiftUI
import CoreData
import FluentUI

struct ProjectManagementView: View {
    let todoColors = ToDoColors()
    
    @State private var projects: [Projects] = []
    @State private var showingAddProjectAlert = false
    @State private var newProjectName = ""
    @State private var newProjectDescription = ""
    
    init() {
        // Use direct Core Data access instead of complex dependencies
    }

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
        VStack {
            // Use direct Core Data access
            if projects.filter({ $0.projectName?.lowercased() != "inbox" }).isEmpty && projects.count <= 1 {
                Text("Tap '+' to add your first custom project")
                    .foregroundColor(.gray)
                    .padding()
                Spacer()
            } else {
                List {
                    ForEach(projects, id: \.objectID) { project in
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
                            if project.projectName?.lowercased() != "inbox" {
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
                let success = createProject(name: newProjectName, description: newProjectDescription)
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
                    let success = updateProject(project, newName: editProjectName, newDescription: editProjectDescription)
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
                    let success = deleteProject(project)
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
            loadProjects()
        }
    }
    
    // MARK: - Core Data Helper Methods

    private func loadProjects() {
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<Projects> = Projects.fetchRequest()
        let fetchedProjects = (try? context?.fetch(request)) ?? []

        // Deduplicate projects by name (case-insensitive)
        var uniqueProjects: [Projects] = []
        var seenNames: Set<String> = []

        for project in fetchedProjects {
            let name = project.projectName?.lowercased() ?? ""
            if !seenNames.contains(name) {
                uniqueProjects.append(project)
                seenNames.insert(name)
            }
        }

        // Sort: Inbox first, then alphabetically
        projects = uniqueProjects.sorted { (p1, p2) -> Bool in
            let name1 = p1.projectName?.lowercased() ?? ""
            let name2 = p2.projectName?.lowercased() ?? ""

            // Inbox should always be first
            if name1 == "inbox" {
                return true
            }
            if name2 == "inbox" {
                return false
            }

            // Otherwise, sort alphabetically
            return name1 < name2
        }
    }
    
    private func createProject(name: String, description: String) -> Bool {
        guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.lowercased() != "inbox" else { return false }
        
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        guard let context = context else { return false }
        
        // Check if project already exists
        let request: NSFetchRequest<Projects> = Projects.fetchRequest()
        request.predicate = NSPredicate(format: "projectName == %@", name)
        if let existingProjects = try? context.fetch(request), !existingProjects.isEmpty {
            return false
        }
        
        let newProject = Projects(context: context)
        newProject.projectName = name
        newProject.projecDescription = description
        
        do {
            try context.save()
            loadProjects() // Refresh the list
            return true
        } catch {
            print("❌ Failed to create project: \(error)")
            return false
        }
    }
    
    private func updateProject(_ project: Projects, newName: String, newDescription: String) -> Bool {
        guard !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              newName.lowercased() != "inbox" else { return false }
        
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        guard let context = context else { return false }
        
        // Check if another project with this name already exists
        let request: NSFetchRequest<Projects> = Projects.fetchRequest()
        request.predicate = NSPredicate(format: "projectName == %@ AND objectID != %@", newName, project.objectID)
        if let existingProjects = try? context.fetch(request), !existingProjects.isEmpty {
            return false
        }
        
        project.projectName = newName
        project.projecDescription = newDescription
        
        do {
            try context.save()
            loadProjects() // Refresh the list
            return true
        } catch {
            print("❌ Failed to update project: \(error)")
            return false
        }
    }
    
    private func deleteProject(_ project: Projects) -> Bool {
        guard project.projectName?.lowercased() != "inbox" else { return false }
        
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        guard let context = context else { return false }
        
        // Move tasks to Inbox before deleting project
        let taskRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
        taskRequest.predicate = NSPredicate(format: "project == %@", project.projectName ?? "")
        if let tasks = try? context.fetch(taskRequest) {
            for task in tasks {
                task.project = "Inbox"
            }
        }
        
        context.delete(project)
        
        do {
            try context.save()
            loadProjects() // Refresh the list
            return true
        } catch {
            print("❌ Failed to delete project: \(error)")
            return false
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
