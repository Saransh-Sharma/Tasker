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
    private let notificationPreferencesStore = TaskerNotificationPreferencesStore.shared
    private var notificationPreferences = TaskerNotificationPreferences()
    private var notificationPermissionStatus: TaskerNotificationAuthorizationStatus = .notDetermined

    private let notificationsSectionTitle = "Notifications"
    private let notificationsTaskReminderTitle = "Task Reminders"
    private let notificationsDueSoonTitle = "Due Soon Nudges"
    private let notificationsOverdueTitle = "Overdue Nudges"
    private let notificationsMorningEnabledTitle = "Morning Agenda"
    private let notificationsNightlyEnabledTitle = "Nightly Retrospective"
    private let notificationsMorningTimeTitle = "Morning Agenda Time"
    private let notificationsNightlyTimeTitle = "Nightly Retrospective Time"
    private let notificationsPermissionTitle = "Permission"
    
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
        notificationPreferences = notificationPreferencesStore.load()
        refreshNotificationPermissionStatus()
        
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
        notificationPreferences = notificationPreferencesStore.load()
        refreshNotificationPermissionStatus()
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
            SettingsSection(title: notificationsSectionTitle, items: [
                SettingsItem(title: notificationsTaskReminderTitle, iconName: "bell.badge.fill", action: nil),
                SettingsItem(title: notificationsDueSoonTitle, iconName: "clock.badge.exclamationmark", action: nil),
                SettingsItem(title: notificationsOverdueTitle, iconName: "exclamationmark.triangle.fill", action: nil),
                SettingsItem(title: notificationsMorningEnabledTitle, iconName: "sunrise.fill", action: nil),
                SettingsItem(title: notificationsNightlyEnabledTitle, iconName: "moon.stars.fill", action: nil),
                SettingsItem(
                    title: notificationsMorningTimeTitle,
                    iconName: "sunrise.fill",
                    action: { [weak self] in
                        self?.presentNotificationTimePicker(forMorning: true)
                    },
                    detailText: formattedTime(
                        hour: notificationPreferences.morningHour,
                        minute: notificationPreferences.morningMinute
                    )
                ),
                SettingsItem(
                    title: notificationsNightlyTimeTitle,
                    iconName: "moon.stars.fill",
                    action: { [weak self] in
                        self?.presentNotificationTimePicker(forMorning: false)
                    },
                    detailText: formattedTime(
                        hour: notificationPreferences.nightlyHour,
                        minute: notificationPreferences.nightlyMinute
                    )
                ),
                SettingsItem(
                    title: notificationsPermissionTitle,
                    iconName: "checkmark.shield.fill",
                    action: { [weak self] in
                        self?.handleNotificationPermissionTapped()
                    },
                    detailText: notificationPermissionDetailText()
                )
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

        // MARK: Notifications
        if sectionTitle == notificationsSectionTitle {
            let item = sections[indexPath.section].items[indexPath.row]
            let disabledByPermission = notificationPermissionStatus == .denied && item.title != notificationsPermissionTitle
            let disabledByMasterToggle =
                (item.title == notificationsMorningTimeTitle && !notificationPreferences.morningAgendaEnabled) ||
                (item.title == notificationsNightlyTimeTitle && !notificationPreferences.nightlyRetrospectiveEnabled)
            let notificationsDisabled = disabledByPermission || disabledByMasterToggle
            let cell = UITableViewCell(style: .value1, reuseIdentifier: "settingsCell")
            cell.textLabel?.text = item.title
            cell.textLabel?.font = TaskerUIKitTokens.typography.body
            cell.textLabel?.textColor = colors.textPrimary
            cell.backgroundColor = colors.surfacePrimary

            if let iconName = item.iconName {
                let config = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
                cell.imageView?.image = UIImage(systemName: iconName, withConfiguration: config)
                cell.imageView?.tintColor = colors.accentPrimary
            }

            if let toggle = notificationToggleIfNeeded(for: item.title, indexPath: indexPath) {
                toggle.isEnabled = !notificationsDisabled
                cell.accessoryView = toggle
                cell.accessoryType = .none
                cell.selectionStyle = .none
                cell.detailTextLabel?.text = nil
            } else {
                cell.accessoryType = notificationsDisabled ? .none : (item.action != nil ? .disclosureIndicator : .none)
                cell.selectionStyle = notificationsDisabled ? .none : .default
                if let detailText = item.detailText {
                    cell.detailTextLabel?.text = detailText
                    cell.detailTextLabel?.textColor = colors.textTertiary
                    cell.detailTextLabel?.font = TaskerUIKitTokens.typography.callout
                }
            }
            cell.contentView.alpha = notificationsDisabled ? 0.5 : 1.0
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
        if sections[indexPath.section].title == notificationsSectionTitle &&
            notificationPermissionStatus == .denied &&
            item.title != notificationsPermissionTitle {
            return
        }
        if sections[indexPath.section].title == notificationsSectionTitle &&
            ((item.title == notificationsMorningTimeTitle && !notificationPreferences.morningAgendaEnabled) ||
             (item.title == notificationsNightlyTimeTitle && !notificationPreferences.nightlyRetrospectiveEnabled)) {
            return
        }
        if let action = item.action {
            action()
        }
    }
}

extension SettingsPageViewController {
    private func notificationToggleIfNeeded(for itemTitle: String, indexPath: IndexPath) -> UISwitch? {
        let isOn: Bool
        switch itemTitle {
        case notificationsTaskReminderTitle:
            isOn = notificationPreferences.taskRemindersEnabled
        case notificationsDueSoonTitle:
            isOn = notificationPreferences.dueSoonEnabled
        case notificationsOverdueTitle:
            isOn = notificationPreferences.overdueNudgesEnabled
        case notificationsMorningEnabledTitle:
            isOn = notificationPreferences.morningAgendaEnabled
        case notificationsNightlyEnabledTitle:
            isOn = notificationPreferences.nightlyRetrospectiveEnabled
        default:
            return nil
        }

        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.tag = indexPath.section * 1000 + indexPath.row
        toggle.addTarget(self, action: #selector(notificationToggleChanged(_:)), for: .valueChanged)
        return toggle
    }

    @objc private func notificationToggleChanged(_ sender: UISwitch) {
        let section = sender.tag / 1000
        let row = sender.tag % 1000
        guard sections.indices.contains(section),
              sections[section].items.indices.contains(row)
        else {
            return
        }

        let itemTitle = sections[section].items[row].title
        notificationPreferencesStore.update { preferences in
            switch itemTitle {
            case notificationsTaskReminderTitle:
                preferences.taskRemindersEnabled = sender.isOn
            case notificationsDueSoonTitle:
                preferences.dueSoonEnabled = sender.isOn
            case notificationsOverdueTitle:
                preferences.overdueNudgesEnabled = sender.isOn
            case notificationsMorningEnabledTitle:
                preferences.morningAgendaEnabled = sender.isOn
            case notificationsNightlyEnabledTitle:
                preferences.nightlyRetrospectiveEnabled = sender.isOn
            default:
                break
            }
            notificationPreferences = preferences
        }

        setupSettingsSections()
        settingsTableView.reloadData()
        reconcileNotifications(reason: "settings_toggle_changed")
    }

    private func presentNotificationTimePicker(forMorning: Bool) {
        let title = forMorning ? notificationsMorningTimeTitle : notificationsNightlyTimeTitle
        let alert = UIAlertController(title: "\(title)\n\n\n\n\n\n\n", message: nil, preferredStyle: .actionSheet)

        let picker = UIDatePicker(frame: CGRect(x: 16, y: 36, width: view.bounds.width - 64, height: 160))
        picker.datePickerMode = .time
        if #available(iOS 14.0, *) {
            picker.preferredDatePickerStyle = .wheels
        }
        let hour = forMorning ? notificationPreferences.morningHour : notificationPreferences.nightlyHour
        let minute = forMorning ? notificationPreferences.morningMinute : notificationPreferences.nightlyMinute
        picker.date = dateFrom(hour: hour, minute: minute)
        alert.view.addSubview(picker)

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default, handler: { [weak self] _ in
            guard let self else { return }
            let components = Calendar.current.dateComponents([.hour, .minute], from: picker.date)
            let selectedHour = components.hour ?? hour
            let selectedMinute = components.minute ?? minute

            self.notificationPreferencesStore.update { preferences in
                if forMorning {
                    preferences.morningHour = selectedHour
                    preferences.morningMinute = selectedMinute
                } else {
                    preferences.nightlyHour = selectedHour
                    preferences.nightlyMinute = selectedMinute
                }
                self.notificationPreferences = preferences
            }

            self.setupSettingsSections()
            self.settingsTableView.reloadData()
            self.reconcileNotifications(reason: "settings_time_changed")
        }))

        if let popover = alert.popoverPresentationController,
           let indexPath = indexPath(forNotificationItemTitle: title) {
            popover.sourceView = settingsTableView
            popover.sourceRect = settingsTableView.rectForRow(at: indexPath)
        }

        present(alert, animated: true)
    }

    private func dateFrom(hour: Int, minute: Int) -> Date {
        let components = DateComponents(hour: hour, minute: minute)
        return Calendar.current.date(from: components) ?? Date()
    }

    private func indexPath(forNotificationItemTitle title: String) -> IndexPath? {
        guard let section = sections.firstIndex(where: { $0.title == notificationsSectionTitle }),
              let row = sections[section].items.firstIndex(where: { $0.title == title })
        else {
            return nil
        }
        return IndexPath(row: row, section: section)
    }

    private func formattedTime(hour: Int, minute: Int) -> String {
        var components = DateComponents()
        components.hour = hour
        components.minute = minute
        let date = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }

    private func notificationPermissionDetailText() -> String {
        switch notificationPermissionStatus {
        case .authorized:
            return "Authorized"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Ephemeral"
        case .notDetermined:
            return "Not Determined"
        case .denied:
            return "Denied"
        }
    }

    private func refreshNotificationPermissionStatus() {
        guard let service = EnhancedDependencyContainer.shared.notificationService else {
            notificationPermissionStatus = .notDetermined
            return
        }
        service.fetchAuthorizationStatus { [weak self] status in
            DispatchQueue.main.async {
                self?.notificationPermissionStatus = status
                self?.setupSettingsSections()
                self?.settingsTableView?.reloadData()
            }
        }
    }

    private func handleNotificationPermissionTapped() {
        guard let service = EnhancedDependencyContainer.shared.notificationService else { return }
        switch notificationPermissionStatus {
        case .denied:
            guard let url = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(url)
            else {
                return
            }
            UIApplication.shared.open(url)
        case .notDetermined:
            service.requestPermission { [weak self] granted in
                DispatchQueue.main.async {
                    self?.refreshNotificationPermissionStatus()
                    if granted {
                        self?.reconcileNotifications(reason: "settings_permission_granted")
                    }
                }
            }
        case .authorized, .provisional, .ephemeral:
            break
        }
    }

    private func reconcileNotifications(reason: String) {
        (UIApplication.shared.delegate as? AppDelegate)?.reconcileNotifications(reason: reason)
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
