//
//  ProjectManagementViewController.swift
//  To Do List
//
//  Created on 27/05/2025.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit

class ProjectManagementViewController: UIViewController {
    // MARK: - Properties
    var projectsTableView: UITableView!
    var projects: [Projects] = []
    
    // Managers - removed, using Clean Architecture now
    
    // UI Elements
    var emptyStateLabel: UILabel?
    
    // HUD
    var todoColors = ToDoColors()
    
    // MARK: - Helper Methods
    private func saveContext() -> Bool {
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            return false
        }
        
        if context.hasChanges {
            do {
                try context.save()
                return true
            } catch {
                print("Error saving context: \(error)")
                return false
            }
        }
        return true
    }
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup navigation
        self.title = "Projects"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addProjectTapped))
        
        // Setup table view
        setupTableView()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadProjects()
    }
    
    // MARK: - UI Setup
    private func setupTableView() {
        projectsTableView = UITableView(frame: view.bounds, style: .insetGrouped)
        projectsTableView.delegate = self
        projectsTableView.dataSource = self
        projectsTableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        view.addSubview(projectsTableView)
    }
    
    private func updateEmptyStateVisibility() {
        // Only consider the project count minus the default "Inbox" project
        let customProjectCount = projects.count - 1
        
        if customProjectCount <= 0 {
            // Show empty state if no custom projects
            if emptyStateLabel == nil {
                emptyStateLabel = UILabel()
                emptyStateLabel!.text = "Tap '+' to add your first project"
                emptyStateLabel!.textAlignment = .center
                emptyStateLabel!.textColor = .gray
                emptyStateLabel!.font = UIFont.systemFont(ofSize: 16)
                emptyStateLabel!.translatesAutoresizingMaskIntoConstraints = false
                view.addSubview(emptyStateLabel!)
                
                NSLayoutConstraint.activate([
                    emptyStateLabel!.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    emptyStateLabel!.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    emptyStateLabel!.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                    emptyStateLabel!.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
                ])
            }
            emptyStateLabel!.isHidden = false
        } else {
            // Hide empty state if there are projects
            emptyStateLabel?.isHidden = true
        }
    }
    
    // MARK: - Data Management
    private func loadProjects() {
        // Load projects from Core Data
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<Projects> = Projects.fetchRequest()
        projects = (try? context?.fetch(request)) ?? []
        projectsTableView.reloadData()
        updateEmptyStateVisibility()
    }
    
    // MARK: - Actions
    @objc func addProjectTapped() {
        presentProjectAlert(title: "New Project", project: nil)
    }
    
    private func editProject(_ project: Projects) {
        presentProjectAlert(title: "Edit Project", project: project)
    }
    
    private func presentProjectAlert(title: String, project: Projects?) {
        let alertController = UIAlertController(title: title, message: nil, preferredStyle: .alert)
        
        alertController.addTextField { textField in
            textField.placeholder = "Project Name"
            textField.text = project?.projectName
        }
        
        alertController.addTextField { textField in
            textField.placeholder = "Project Description (Optional)"
            textField.text = project?.projecDescription
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self = self,
                  let nameTextField = alertController.textFields?[0],
                  let descriptionTextField = alertController.textFields?[1],
                  let projectName = nameTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !projectName.isEmpty else {
                self?.showError(message: "Project name cannot be empty")
                return
            }
            
            let projectDescription = descriptionTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            // Different handling for new vs existing project
            if let existingProject = project {
                // Update existing project
                // Update existing project
                existingProject.projectName = projectName
                existingProject.projecDescription = projectDescription
                let success = self.saveContext()
                if success {
                    self.showSuccess(message: "Project updated")
                    self.loadProjects()
                } else {
                    self.showError(message: "Failed to update project. Name may already be in use or cannot be 'Inbox'.")
                }
            } else {
                // Create new project
                // Create new project
                let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
                let newProject = Projects(context: context!)
                newProject.projectName = projectName
                newProject.projecDescription = projectDescription
                newProject.projectID = UUID().uuidString
                let success = self.saveContext()
                if success {
                    self.showSuccess(message: "Project created")
                    self.loadProjects()
                } else {
                    self.showError(message: "Failed to create project. Name may already be in use or cannot be 'Inbox'.")
                }
            }
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(saveAction)
        
        present(alertController, animated: true)
    }
    
    // MARK: - Utility Methods
    private func showSuccess(message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func deleteButtonTapped(_ sender: UIButton) {
        let project = projects[sender.tag]
        showDeleteAlert(for: project)
    }
    
    private func showDeleteAlert(for project: Projects) {
        let alert = UIAlertController(
            title: "Delete Project",
            message: "Delete '\(project.projectName ?? "")' project? Tasks will be moved to 'Inbox'.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
            let success = self.projectManager.deleteProject(project)
            if success {
                self.showSuccess(message: "Project deleted and tasks moved to Inbox")
                self.loadProjects()
            } else {
                self.showError(message: "Failed to delete project")
            }
        })
        present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource
extension ProjectManagementViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return projects.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "projectCell", for: indexPath)
        let project = projects[indexPath.row]
        let trimmed = project.projectName?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        cell.textLabel?.text = project.projectName
        cell.detailTextLabel?.text = project.projecDescription
        
        if trimmed == "inbox" {
            cell.textLabel?.textColor = .gray
            cell.accessoryView = nil
            cell.selectionStyle = .none
        } else {
            cell.textLabel?.textColor = .label
            
            let deleteBtn = UIButton(type: .system)
            deleteBtn.setImage(UIImage(systemName: "trash"), for: .normal)
            deleteBtn.tintColor = .systemRed
            deleteBtn.tag = indexPath.row
            deleteBtn.addTarget(self, action: #selector(deleteButtonTapped(_:)), for: .touchUpInside)
            deleteBtn.sizeToFit()
            cell.accessoryView = deleteBtn
            
            cell.selectionStyle = .default
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension ProjectManagementViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let project = projects[indexPath.row]
        
        // Don't allow editing the default Inbox project
        if project.projectName?.lowercased() == "inbox" {
            return
        }
        
        // Allow editing of other projects
        editProject(project)
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let project = projects[indexPath.row]
        
        // Don't allow deleting the default Inbox project
        if project.projectName?.lowercased() == "inbox" {
            return nil
        }
        
        // Create delete action for non-Inbox projects
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (_, _, completionHandler) in
            guard let self = self else {
                completionHandler(false)
                return
            }
            
            let alert = UIAlertController(
                title: "Delete Project",
                message: "Delete '\(project.projectName ?? "")' project? Tasks will be moved to 'Inbox'.",
                preferredStyle: .alert
            )
            
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { _ in
                completionHandler(false)
            }
            
            let confirmAction = UIAlertAction(title: "Delete", style: .destructive) { _ in
                // Delete project and move tasks to Inbox
                let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
                
                // Move all tasks from this project to Inbox
                let taskRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
                taskRequest.predicate = NSPredicate(format: "project == %@", project.projectName ?? "")
                if let tasks = try? context?.fetch(taskRequest) {
                    for task in tasks {
                        task.project = "Inbox"
                    }
                }
                
                // Delete the project
                context?.delete(project)
                let success = self.saveContext()
                if success {
                    self.showSuccess(message: "Project deleted and tasks moved to Inbox")
                    self.loadProjects()
                    completionHandler(true)
                } else {
                    self.showError(message: "Failed to delete project")
                    completionHandler(false)
                }
            }
            
            alert.addAction(cancelAction)
            alert.addAction(confirmAction)
            
            self.present(alert, animated: true)
        }
        
        return UISwipeActionsConfiguration(actions: [deleteAction])
    }
}
