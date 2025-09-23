//
//  SettingsPageViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 26/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import SwiftUI
import CoreData

// Data structures for settings table view
struct SettingsItem {
    let title: String
    let iconName: String? // System SF Symbol name
    let action: (() -> Void)?
    var detailText: String? = nil // For displaying things like version
}

struct SettingsSection {
    let title: String? // Optional section header
    let items: [SettingsItem]
}

class SettingsPageViewController: UIViewController {
    // Properties
    var settingsTableView: UITableView!
    var sections: [SettingsSection] = [] // Data source for the table
    // LLM/AI Manager
    let appManager = AppManager()
    
    // Track the current mode state
    private var isDarkMode: Bool = false
    
    // Colors and fonts
    var todoColors = ToDoColors()
    var todoFont = ToDoFont()
    
    // Manager instances - removed, using Clean Architecture now
    
    // MARK: - Backdrop compatibility properties (needed for SettingsBackdrop.swift)
    var backdropContainer = UIView()
    var headerEndY: CGFloat = 128
    var backdropBackgroundImageView = UIImageView()
    var homeTopBar = UIView()
    
    // MARK: - Lifecycle Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Set up navigation items
        self.title = "Settings"
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        
        // Initialize dark mode state
        isDarkMode = UIScreen.main.traitCollection.userInterfaceStyle == .dark
        
        // Set up table view
        setupTableView()
        
        // Set up table data
        setupSettingsSections()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Add observer for theme changes
        NotificationCenter.default.addObserver(self, selector: #selector(themeChanged), name: .themeChanged, object: nil)
        
        // Refresh table data when view appears
        setupSettingsSections()
        todoColors = ToDoColors()
        settingsTableView.reloadData()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Remove observer to avoid memory leaks
        NotificationCenter.default.removeObserver(self, name: .themeChanged, object: nil)
    }
    
    // MARK: - UI Setup
    private func setupTableView() {
        // Create and configure the table view
        settingsTableView = UITableView(frame: view.bounds, style: .insetGrouped)
        settingsTableView.delegate = self
        settingsTableView.dataSource = self
        settingsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "settingsCell")
        settingsTableView.register(ThemeSelectionCell.self, forCellReuseIdentifier: ThemeSelectionCell.reuseID)
        settingsTableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Add to view hierarchy
        view.addSubview(settingsTableView)
    }
    
    // MARK: - Data Setup
    private func setupSettingsSections() {
        // Determine dynamic titles/icons
        let modeTitle = isDarkMode ? "Light Mode" : "Dark Mode"
        let modeIcon = isDarkMode ? "sun.max.fill" : "moon.fill"
        
        // Compute LLM model display name to show as badge/detail
        let modelDisplayName = appManager.modelDisplayName(appManager.currentModelName ?? "")
        
        sections = [
            SettingsSection(title: "Projects", items: [
                SettingsItem(title: "Project Management", iconName: "folder.fill", action: { [weak self] in
                    self?.navigateToProjectManagement()
                })
            ]),
            SettingsSection(title: "Appearance", items: [
                SettingsItem(title: modeTitle, iconName: modeIcon, action: { [weak self] in
                    self?.toggleDarkMode()
                }),
                SettingsItem(title: "Theme", iconName: nil, action: nil)
            ]),
            // LLM Settings
            SettingsSection(title: "LLM Settings", items: [
                SettingsItem(title: "Chats", iconName: "message", action: { [weak self] in
                    self?.navigateToLLMChatsSettings()
                }),
                SettingsItem(title: "Models", iconName: "brain.filled.head.profile", action: { [weak self] in
                    self?.navigateToLLMModelsSettings()
                }, detailText: modelDisplayName)
            ]),
            SettingsSection(title: "About", items: [
                SettingsItem(title: "Version", iconName: "info.circle.fill", action: { [weak self] in
                    self?.showVersionInfo()
                }, detailText: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
            ])
        ]
    }
    
    // MARK: - Actions
    @objc func doneTapped() {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Theme Navigation
    private func navigateToThemeSelection() {
        let vc = ThemeSelectionViewController()
        self.navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - LLM Navigation
    private func navigateToLLMChatsSettings() {
        let view = ChatsSettingsView(currentThread: .constant(nil))
            .environmentObject(appManager)
            .environment(LLMEvaluator())
        let vc = UIHostingController(rootView: view)
        vc.title = "Chats"
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    private func navigateToLLMModelsSettings() {
        let view = ModelsSettingsView()
            .environmentObject(appManager)
            .environment(LLMEvaluator())
        let vc = UIHostingController(rootView: view)
        vc.title = "Models"
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    private func navigateToProjectManagement() {
        // Create ProjectManagementViewController directly
        let projectVC = ProjectManagementViewControllerEmbedded()
        self.navigationController?.pushViewController(projectVC, animated: true)
    }
    
    private func showNotImplementedAlert() {
        let alert = UIAlertController(title: "Coming Soon", message: "This feature is not yet implemented", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
    
    private func toggleDarkMode() {
        // Toggle our tracked dark mode state
        isDarkMode = !isDarkMode
        
        // Toggle between light and dark mode
        if #available(iOS 13.0, *) {
            let newStyle: UIUserInterfaceStyle = isDarkMode ? .dark : .light
            
            // Apply to all windows for consistent appearance
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                windowScene.windows.forEach { window in
                    window.overrideUserInterfaceStyle = newStyle
                }
            }
            
            // Show confirmation toast
            let message = isDarkMode ? "Dark Mode Enabled" : "Light Mode Enabled"
            let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            
            // Update settings sections to reflect the new mode
            setupSettingsSections()
            
            // Refresh the table to update appearance changes and button text/icon
            settingsTableView.reloadData()
        } else {
            showNotImplementedAlert()
        }
    }
    
    private func showVersionInfo() {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        
        let alert = UIAlertController(
            title: "App Version",
            message: "Version: \(version)\nBuild: \(buildNumber)",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Status Bar Style
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
}

// MARK: - UITableViewDataSource
extension SettingsPageViewController: UITableViewDataSource {
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Provide custom theme picker cell for the "Theme" item under the Appearance section
        if sections[indexPath.section].title == "Appearance" && sections[indexPath.section].items[indexPath.row].title == "Theme" {
            let themeCell = tableView.dequeueReusableCell(withIdentifier: ThemeSelectionCell.reuseID, for: indexPath)
            themeCell.selectionStyle = .none
            // Hide the default text label so only the collection view is visible
            themeCell.textLabel?.text = nil
            return themeCell
        }

        let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath)
        let item = sections[indexPath.section].items[indexPath.row]
        
        // Configure cell
        cell.textLabel?.text = item.title
        cell.accessoryType = item.action != nil ? .disclosureIndicator : .none
        
        // Configure icon if available
        if let iconName = item.iconName {
            cell.imageView?.image = UIImage(systemName: iconName)
            cell.imageView?.tintColor = todoColors.primaryColor
        }
        
        // Configure detail text if available
        if let detailText = item.detailText {
            cell.detailTextLabel?.text = detailText
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension SettingsPageViewController: UITableViewDelegate {
    // Provide taller height for theme picker cell
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if sections[indexPath.section].title == "Appearance" && sections[indexPath.section].items[indexPath.row].title == "Theme" {
            return 110
        }
        return UITableView.automaticDimension
    }
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Execute the action if available
        let item = sections[indexPath.section].items[indexPath.row]
        // Ignore selection for theme picker row
        if item.title == "Theme" && sections[indexPath.section].title == "Appearance" {
            return
        }
        if let action = item.action {
            action()
        }
    }
}

// MARK: - Embedded Project Management

class ProjectManagementViewControllerEmbedded: UIViewController {
    // MARK: - Properties
    var projectsTableView: UITableView!
    var projects: [Projects] = []
    
    // Managers - removed, using Clean Architecture now
    
    // UI Elements
    var emptyStateLabel: UILabel?
    
    // Colors
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
        // Data refresh handled by Core Data
        loadProjects()
    }
    
    // MARK: - UI Setup
    private func setupTableView() {
        projectsTableView = UITableView(frame: view.bounds, style: .insetGrouped)
        projectsTableView.delegate = self
        projectsTableView.dataSource = self
        projectsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "projectCell")
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
}

// MARK: - Theme Change Handling
extension SettingsPageViewController {
    @objc func themeChanged() {
        todoColors = ToDoColors()
        view.tintColor = todoColors.primaryColor
        settingsTableView.reloadData()
    }
}

// MARK: - ProjectManagementViewControllerEmbedded TableView DataSource
extension ProjectManagementViewControllerEmbedded: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return projects.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Use the subtitle style to show project description
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "projectCell")
        let project = projects[indexPath.row]
        
        // Configure cell
        cell.textLabel?.text = project.projectName
        cell.detailTextLabel?.text = project.projecDescription
        
        // Special styling for default "Inbox" project
        if project.projectName?.lowercased() == "inbox" {
            cell.textLabel?.textColor = .gray
            cell.accessoryType = .none
            cell.selectionStyle = .none
        } else {
            cell.textLabel?.textColor = .label
            cell.accessoryType = .disclosureIndicator
            cell.selectionStyle = .default
        }
        
        return cell
    }
}

// MARK: - ProjectManagementViewControllerEmbedded TableView Delegate
extension ProjectManagementViewControllerEmbedded: UITableViewDelegate {
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
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (action: UIContextualAction, view: UIView, completionHandler: @escaping (Bool) -> Void) in
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
                    // Data refresh handled by Core Data
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
