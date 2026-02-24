//
//  SettingsPageViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 26/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import SwiftUI
import Combine

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

class SettingsPageViewController: UIViewController, PresentationDependencyContainerAware {
    // Properties
    var settingsTableView: UITableView!
    var sections: [SettingsSection] = [] // Data source for the table
    // LLM/AI Manager
    let appManager = AppManager()
    let llmEvaluator = LLMRuntimeCoordinator.shared.evaluator
    
    // Track the current mode state
    private var isDarkMode: Bool = false
    
    private var themeCancellable: AnyCancellable?
    var presentationDependencyContainer: PresentationDependencyContainer?
    
    // Manager instances - removed, using Clean Architecture now
    
    // MARK: - Backdrop compatibility properties (needed for SettingsBackdrop.swift)
    var backdropContainer = UIView()
    var headerEndY: CGFloat = 128
    var backdropBackgroundImageView = UIImageView()
    var homeTopBar = UIView()
    
    // MARK: - Lifecycle Methods
    /// Executes viewDidLoad.
    override func viewDidLoad() {
        super.viewDidLoad()

        // Set accessibility identifier for the main view
        view.accessibilityIdentifier = "settings.view"

        // Set up navigation items
        self.title = "Settings"
        let doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(doneTapped))
        doneButton.accessibilityIdentifier = "settings.doneButton"
        self.navigationItem.rightBarButtonItem = doneButton
        
        // Initialize dark mode state
        isDarkMode = UIScreen.main.traitCollection.userInterfaceStyle == .dark
        
        // Set up table view
        setupTableView()
        
        // Set up table data
        setupSettingsSections()

        themeCancellable = TaskerThemeManager.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }

        applyTheme()
    }
    
    /// Executes viewWillAppear.
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Refresh table data when view appears
        setupSettingsSections()
        settingsTableView.reloadData()
    }
    
    /// Executes viewWillDisappear.
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    // MARK: - UI Setup
    /// Executes setupTableView.
    private func setupTableView() {
        // Create and configure the table view
        settingsTableView = UITableView(frame: view.bounds, style: .insetGrouped)
        settingsTableView.delegate = self
        settingsTableView.dataSource = self
        settingsTableView.register(UITableViewCell.self, forCellReuseIdentifier: "settingsCell")
        settingsTableView.register(UnifiedThemePickerCell.self, forCellReuseIdentifier: UnifiedThemePickerCell.reuseID)
        settingsTableView.register(DarkModeToggleCell.self, forCellReuseIdentifier: DarkModeToggleCell.reuseID)
        settingsTableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Add to view hierarchy
        view.addSubview(settingsTableView)
    }
    
    // MARK: - Data Setup
    /// Executes setupSettingsSections.
    private func setupSettingsSections() {
        // Compute LLM model display name to show as badge/detail
        let modelDisplayName = appManager.modelDisplayName(appManager.currentModelName ?? "")

        sections = [
            SettingsSection(title: "Projects", items: [
                SettingsItem(title: "Project Management", iconName: "folder.fill", action: { [weak self] in
                    self?.navigateToProjectManagement()
                })
            ]),
            SettingsSection(title: "Appearance", items: [
                SettingsItem(title: "Dark Mode", iconName: nil, action: nil),  // Handled by DarkModeToggleCell
                SettingsItem(title: "Theme", iconName: nil, action: nil)       // Handled by UnifiedThemePickerCell
            ]),
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
    /// Executes doneTapped.
    @objc func doneTapped() {
        self.dismiss(animated: true, completion: nil)
    }
    
    // MARK: - Theme Navigation
    /// Executes navigateToThemeSelection.
    private func navigateToThemeSelection() {
        let vc = ThemeSelectionViewController()
        self.navigationController?.pushViewController(vc, animated: true)
    }

    // MARK: - LLM Navigation
    /// Executes navigateToLLMChatsSettings.
    private func navigateToLLMChatsSettings() {
        let view = ChatsSettingsView(currentThread: .constant(nil))
            .environmentObject(appManager)
            .environment(llmEvaluator)
        let vc = UIHostingController(rootView: view)
        vc.title = "Chats"
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    /// Executes navigateToLLMModelsSettings.
    private func navigateToLLMModelsSettings() {
        let view = ModelsSettingsView()
            .environmentObject(appManager)
            .environment(llmEvaluator)
        let vc = UIHostingController(rootView: view)
        vc.title = "Models"
        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    /// Executes navigateToProjectManagement.
    private func navigateToProjectManagement() {
        guard let presentationDependencyContainer else {
            assertionFailure("SettingsPageViewController requires injected PresentationDependencyContainer")
            return
        }
        let viewModel = presentationDependencyContainer.makeProjectManagementViewModel()
        let view = SettingsProjectManagementV2View(viewModel: viewModel)
        let controller = UIHostingController(rootView: view)
        controller.title = "Projects"
        navigationController?.pushViewController(controller, animated: true)
    }
    
    /// Executes showNotImplementedAlert.
    private func showNotImplementedAlert() {
        let alert = UIAlertController(title: "Coming Soon", message: "This feature is not yet implemented", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true)
    }
    
    /// Executes showVersionInfo.
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
    /// Executes numberOfSections.
    func numberOfSections(in tableView: UITableView) -> Int {
        return sections.count
    }
    
    /// Executes tableView.
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sections[section].items.count
    }
    
    /// Executes tableView.
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return sections[section].title
    }
    
    /// Executes tableView.
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let sectionTitle = sections[indexPath.section].title
        let itemTitle = sections[indexPath.section].items[indexPath.row].title
        let colors = TaskerThemeManager.shared.currentTheme.tokens.color

        // MARK: Appearance – Dark Mode toggle
        if sectionTitle == "Appearance" && itemTitle == "Dark Mode" {
            let cell = tableView.dequeueReusableCell(withIdentifier: DarkModeToggleCell.reuseID, for: indexPath) as! DarkModeToggleCell
            cell.delegate = self
            cell.update(isDarkMode: isDarkMode)
            cell.backgroundColor = colors.surfacePrimary
            return cell
        }

        // MARK: Appearance – Theme gallery
        if sectionTitle == "Appearance" && itemTitle == "Theme" {
            let cell = tableView.dequeueReusableCell(withIdentifier: UnifiedThemePickerCell.reuseID, for: indexPath)
            cell.selectionStyle = .none
            cell.textLabel?.text = nil
            cell.backgroundColor = colors.surfacePrimary
            return cell
        }

        // MARK: Default rows – token-based styling
        let cell = UITableViewCell(style: .value1, reuseIdentifier: "settingsCell")
        let item = sections[indexPath.section].items[indexPath.row]

        cell.textLabel?.text = item.title
        cell.textLabel?.font = TaskerUIKitTokens.typography.body
        cell.textLabel?.textColor = colors.textPrimary
        cell.accessoryType = item.action != nil ? .disclosureIndicator : .none
        cell.backgroundColor = colors.surfacePrimary

        if let iconName = item.iconName {
            let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
            cell.imageView?.image = UIImage(systemName: iconName, withConfiguration: config)
            cell.imageView?.tintColor = colors.accentPrimary
        }

        if let detailText = item.detailText {
            cell.detailTextLabel?.text = detailText
            cell.detailTextLabel?.textColor = colors.textTertiary
            cell.detailTextLabel?.font = TaskerUIKitTokens.typography.callout
        }

        return cell
    }
}

// MARK: - UITableViewDelegate
extension SettingsPageViewController: UITableViewDelegate {
    /// Executes tableView.
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        guard sections[indexPath.section].title == "Appearance" else {
            return UITableView.automaticDimension
        }
        let itemTitle = sections[indexPath.section].items[indexPath.row].title
        if itemTitle == "Theme" { return 128 }
        if itemTitle == "Dark Mode" { return 52 }
        return UITableView.automaticDimension
    }
    /// Executes tableView.
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        // Execute the action if available
        let item = sections[indexPath.section].items[indexPath.row]
        // Ignore selection for Appearance rows (handled by their own controls)
        if sections[indexPath.section].title == "Appearance" {
            return
        }
        if let action = item.action {
            action()
        }
    }
}

private struct SettingsProjectManagementV2View: View {
    @ObservedObject var viewModel: ProjectManagementViewModel
    @State private var showingCreateDialog = false
    @State private var newProjectName = ""
    @State private var newProjectDescription = ""

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

// MARK: - DarkModeToggleCellDelegate
extension SettingsPageViewController: DarkModeToggleCellDelegate {
    /// Executes darkModeToggleCell.
    func darkModeToggleCell(_ cell: DarkModeToggleCell, didToggle isDark: Bool) {
        isDarkMode = isDark
        let newStyle: UIUserInterfaceStyle = isDark ? .dark : .light

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { $0.overrideUserInterfaceStyle = newStyle }
        }

        setupSettingsSections()
        applyTheme()
    }
}

// MARK: - Theme Change Handling
extension SettingsPageViewController {
    /// Executes applyTheme.
    private func applyTheme() {
        let colors = TaskerThemeManager.shared.currentTheme.tokens.color
        view.tintColor = colors.accentPrimary
        view.backgroundColor = colors.bgCanvas
        settingsTableView.backgroundColor = colors.bgCanvas
        settingsTableView.reloadData()
    }
}
