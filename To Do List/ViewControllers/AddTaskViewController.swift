//
//  AddTaskViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 04/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import FSCalendar
import MaterialComponents.MaterialTextControls_FilledTextAreas
import MaterialComponents.MaterialTextControls_FilledTextFields
import MaterialComponents.MaterialTextControls_OutlinedTextAreas
import MaterialComponents.MaterialTextControls_OutlinedTextFields
import Combine

// Import Clean Architecture components
@_exported import Foundation

class AddTaskViewController: UIViewController, UITextFieldDelegate, PillButtonBarDelegate, UIScrollViewDelegate, AddTaskViewControllerProtocol, PresentationDependencyContainerAware {

    // Delegate for communicating back to the presenter
    weak var delegate: AddTaskViewControllerDelegate?

    /// AddTaskViewModel dependency (injected) - Clean Architecture
    /// Note: Optional to avoid crashes when ViewModel path is disabled
    var viewModel: AddTaskViewModel?
    var presentationDependencyContainer: PresentationDependencyContainer?

    /// Combine cancellables for reactive bindings
    private var cancellables = Set<AnyCancellable>()
    private var hasBoundViewModel = false

    //MARK:- Backdrop & Fordrop parent containers
    var backdropContainer = UIView()
    var foredropContainer = UIView()
    var bottomBarContainer = UIView()

    // Initialize foredropStackContainer using the static method
    let foredropStackContainer: UIStackView = AddTaskViewController.createVerticalContainer()

    static let verticalSpacing: CGFloat = 16
    static let margin: CGFloat = 16

    // MARK: TASK METADATA
    var currentTaskInMaterialTextBox: String = ""
    var currentTaskDescription: String = ""
    var isThisEveningTask: Bool = false
    var taskDayFromPicker: String =  "Unknown" //change datatype tp task type
    var currenttProjectForAddTaskView: String = ""
    var currentPriorityForAddTaskView: String = ""
    
    // New sample pill bar
    var samplePillBar: UIView?
    var samplePillBarItems: [PillButtonBarItem] = []

    var currentTaskPriority: TaskPriority = .low
    
    // Description text field
    var descriptionTextBox_Material = MDCFilledTextField()

    let addProjectString = "Add Project"

    //MARK:- Positioning
    var headerEndY: CGFloat = 128

    var seperatorTopLineView = UIView()
    var backdropNochImageView = UIImageView()
    var backdropBackgroundImageView = UIImageView()
    var backdropForeImageView = UIImageView()
    let backdropForeImage = UIImage(named: "backdropFrontImage")
    var homeTopBar = UIView()
    let dateAtHomeLabel = UILabel()
    let scoreCounter = UILabel()
    let scoreAtHomeLabel = UILabel()
    let eveningSwitch = UISwitch()
    // var prioritySC =  UISegmentedControl() // This is initialized in AddTaskForedropView extension

    let switchSetContainer = UIView()
    let switchBackground = UIView()
    let eveningLabel = UILabel()

    var addTaskTextBox_Material = MDCFilledTextField()
    let p = TaskPriority.uiOrder.map { $0.displayName }

    var tabsSegmentedControl = UISegmentedControl() // Legacy — kept for reference

    // MARK: - New Components (Obsidian & Gems)
    let metadataRow = AddTaskMetadataRowView()
    let priorityPicker = AddTaskPriorityPickerView()
    let advancedMetadataPanel = AddTaskAdvancedMetadataPanel()
    let inlineProjectCreator = AddTaskInlineProjectCreatorView()
    var alertReminderTime: Date?

    var todoColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }
    var todoTimeUtils = ToDoTimeUtils()

    let existingProjectCellID = "existingProject"
    let newProjectCellID = "newProject"

    //MARK:- Buttons + Views + Bottom bar
    var calendar: FSCalendar!

    //MARK:- current task list date
    var dateForAddTaskView = Date.today()
    var calendarTaskCountByDay: [Date: Int] = [:]




    func setProjecForView(name: String) {
        // currenttProjectForAddTaskView = name // Logic seems commented out
    }

//    //MARK:- DONE TASK ACTION (Stub for extension)
//    @objc func doneAddTaskAction() {
//        // This is just a stub that will be called from the extension
//        // The actual implementation is in AddTaskForedropView.swift extension
//        logDebug("AddTaskViewController: doneAddTaskAction (stub) called")
//    }
    
    // Correct: static func for creating the container
    static func createVerticalContainer() -> UIStackView {
        let container = UIStackView(frame: .zero)
        container.axis = .vertical
        // Use static members correctly
        container.layoutMargins = UIEdgeInsets(top: AddTaskViewController.margin, left: AddTaskViewController.margin, bottom: AddTaskViewController.margin, right: AddTaskViewController.margin)
        container.isLayoutMarginsRelativeArrangement = true
        container.spacing = AddTaskViewController.verticalSpacing
        return container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        logDebug("🚀 AddTaskViewController: viewDidLoad called")
        
        // ACTIVATE CLEAN ARCHITECTURE - Primary dependency injection
        logDebug("🏗️ Activating AddTask Clean Architecture")
        guard viewModel != nil else {
            fatalError("AddTaskViewController requires injected AddTaskViewModel")
        }
        guard presentationDependencyContainer != nil else {
            fatalError("AddTaskViewController requires injected PresentationDependencyContainer")
        }
        setupViewModelBindings()
        viewModel?.loadProjects()
        
        logDebug("🔍 AddTaskViewController: Checking dependency injection state...")
        if viewModel == nil {
            logError(
                event: "add_task_view_model_missing",
                message: "AddTaskViewModel missing in viewDidLoad"
            )
        }
        
        // Setup backdrop with navigation bar and calendar
        view.addSubview(backdropContainer)
        setupBackdrop()
        setupBackdropBackground()
        setupNavigationBar()
        setupCalendarWidget()
        
        // Setup foredrop with form - setupAddTaskForedrop will add foredropStackContainer to foredropContainer
        self.setupAddTaskForedrop()
        
        // Setup form components
        setupAddTaskTextField()
        setupDescriptionTextField()
        setupMetadataRow()
        setupSamplePillBar()
        setupInlineProjectCreator()
        setupPriorityPicker()
        setupAdvancedMetadataPanel()

        // Add components to foredrop stack in order
        // 1. Title field
        addTaskTextBox_Material.isHidden = false
        addTaskTextBox_Material.translatesAutoresizingMaskIntoConstraints = false
        foredropStackContainer.addArrangedSubview(addTaskTextBox_Material)

        // 2. Description field
        descriptionTextBox_Material.isHidden = false
        descriptionTextBox_Material.translatesAutoresizingMaskIntoConstraints = false
        foredropStackContainer.addArrangedSubview(descriptionTextBox_Material)

        // 3. Metadata row (date / reminder / morning-evening chips)
        metadataRow.translatesAutoresizingMaskIntoConstraints = false
        foredropStackContainer.addArrangedSubview(metadataRow)

        // 4. Project pill bar
        if let samplePillBar = samplePillBar {
            samplePillBar.isHidden = false
            samplePillBar.translatesAutoresizingMaskIntoConstraints = false
            foredropStackContainer.addArrangedSubview(samplePillBar)
        }

        // 5. Inline project creator (hidden by default)
        inlineProjectCreator.translatesAutoresizingMaskIntoConstraints = false
        foredropStackContainer.addArrangedSubview(inlineProjectCreator)

        // 6. Advanced metadata panel (life area / section / tags / hierarchy / dependencies)
        advancedMetadataPanel.translatesAutoresizingMaskIntoConstraints = false
        foredropStackContainer.addArrangedSubview(advancedMetadataPanel)

        // 7. Priority picker (jewel-tone pills)
        priorityPicker.translatesAutoresizingMaskIntoConstraints = false
        foredropStackContainer.addArrangedSubview(priorityPicker)

        addTaskTextBox_Material.accessibilityIdentifier = "addTask.titleField"
        addTaskTextBox_Material.becomeFirstResponder()
        addTaskTextBox_Material.keyboardType = .default
        addTaskTextBox_Material.autocorrectionType = .yes
        addTaskTextBox_Material.smartDashesType = .yes
        addTaskTextBox_Material.smartQuotesType = .yes
        addTaskTextBox_Material.smartInsertDeleteType = .yes
        addTaskTextBox_Material.delegate = self

        // Setup foredrop view accessibility
        foredropContainer.accessibilityIdentifier = "addTask.view"

        // Wire delegates for new components
        metadataRow.delegate = self
        priorityPicker.delegate = self
        inlineProjectCreator.delegate = self

        TaskerThemeManager.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshBackdropAppearanceForCurrentTheme()
            }
            .store(in: &cancellables)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        refreshBackdropGradientForCurrentTheme(deferredIfNeeded: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Staggered entrance for new components
        metadataRow.staggerEntrance(baseDelay: 0.1)
        priorityPicker.staggerEntrance(baseDelay: 0.2)
    }

    // MARK: - Clean Architecture Methods
    
    /// Setup ViewModel bindings for reactive UI
    private func setupViewModelBindings() {
        guard hasBoundViewModel == false, let viewModel else { return }
        hasBoundViewModel = true

        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.navigationItem.rightBarButtonItem?.isEnabled = !isLoading
            }
            .store(in: &cancellables)

        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.showError(error)
            }
            .store(in: &cancellables)

        viewModel.$projects
            .receive(on: DispatchQueue.main)
            .sink { [weak self] projects in
                self?.applyProjectsToPillBar(projects)
                self?.refreshMetadataPanel()
            }
            .store(in: &cancellables)

        viewModel.$lifeAreas
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMetadataPanel()
            }
            .store(in: &cancellables)

        viewModel.$sections
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMetadataPanel()
            }
            .store(in: &cancellables)

        viewModel.$tags
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMetadataPanel()
            }
            .store(in: &cancellables)

        viewModel.$selectedLifeAreaID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMetadataPanel()
            }
            .store(in: &cancellables)

        viewModel.$selectedSectionID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMetadataPanel()
            }
            .store(in: &cancellables)

        viewModel.$selectedTagIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMetadataPanel()
            }
            .store(in: &cancellables)

        viewModel.$selectedParentTaskID
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMetadataPanel()
            }
            .store(in: &cancellables)

        viewModel.$selectedDependencyTaskIDs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMetadataPanel()
            }
            .store(in: &cancellables)

        viewModel.$availableParentTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMetadataPanel()
            }
            .store(in: &cancellables)

        viewModel.$availableDependencyTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshMetadataPanel()
            }
            .store(in: &cancellables)

        viewModel.$isTaskCreated
            .receive(on: DispatchQueue.main)
            .dropFirst()
            .filter { $0 }
            .sink { [weak self] _ in
                guard let self else { return }
                self.dismiss(animated: true) {
                    self.delegate?.didCreateTask()
                }
            }
            .store(in: &cancellables)
    }
    
    /// Check if using Clean Architecture or legacy
    var isUsingCleanArchitecture: Bool {
        return viewModel != nil
    }
    
    /// Show error message to user
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    /// Update project selection UI
    private func updateProjectSelection(_ projects: [Project]) {
        applyProjectsToPillBar(projects)
    }

    private func applyProjectsToPillBar(_ projects: [Project]) {
        samplePillBarItems = [PillButtonBarItem(title: addProjectString)]

        let sortedProjects = projects.sorted { lhs, rhs in
            if lhs.id == ProjectConstants.inboxProjectID { return true }
            if rhs.id == ProjectConstants.inboxProjectID { return false }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }

        for project in sortedProjects {
            samplePillBarItems.append(PillButtonBarItem(title: project.name))
        }

        if samplePillBarItems.count == 1 {
            samplePillBarItems.append(PillButtonBarItem(title: ProjectConstants.inboxProjectName))
        }

        let preferredProject: String
        if samplePillBarItems.contains(where: { $0.title == currenttProjectForAddTaskView }),
           currenttProjectForAddTaskView != addProjectString {
            preferredProject = currenttProjectForAddTaskView
        } else if let viewModel,
                  samplePillBarItems.contains(where: { $0.title == viewModel.selectedProject }) {
            preferredProject = viewModel.selectedProject
        } else if let inbox = samplePillBarItems.first(where: { $0.title.caseInsensitiveCompare(ProjectConstants.inboxProjectName) == .orderedSame }) {
            preferredProject = inbox.title
        } else {
            preferredProject = samplePillBarItems.dropFirst().first?.title ?? ProjectConstants.inboxProjectName
        }

        updatePillBarUI(selectProject: preferredProject)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        logDebug("👁️ AddTaskViewController: viewWillAppear called")
        guard viewModel != nil else {
            fatalError("AddTaskViewController requires injected AddTaskViewModel before appearing")
        }
        viewModel?.loadProjects()
        
        // Set default project to Inbox
        currenttProjectForAddTaskView = "Inbox"
        logDebug("📁 AddTaskViewController: Default project set to: \(currenttProjectForAddTaskView)")
    }
    
    // MARK:- Build Page Header
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent // Or .default depending on your background
    }
    
    // MARK: - UITextFieldDelegate
    // This function is called when you click return key in the text field.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        logDebug("textFieldShouldReturn called")
        textField.resignFirstResponder()
        self.doneAddTaskAction() // Call the action defined in the extension
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let oldText = textField.text, let stringRange = Range(range, in: oldText) {
            let newText = oldText.replacingCharacters(in: stringRange, with: string)
            logDebug("AddTaskViewController: new text is: \(newText)")
            
            if textField == addTaskTextBox_Material {
                currentTaskInMaterialTextBox = newText
            } else if textField == descriptionTextBox_Material {
                currentTaskDescription = newText
                // UIKit compatibility: if title field is not focusable in current layout,
                // allow description entry to bootstrap task creation.
                if currentTaskInMaterialTextBox.isEmpty {
                    currentTaskInMaterialTextBox = newText
                }
            }
            
            let isEmpty = currentTaskInMaterialTextBox.isEmpty
            // Enable/disable navigation bar Done button based on text field content
            navigationItem.rightBarButtonItem?.isEnabled = !isEmpty
            // Show/hide priority picker based on text field content
            self.priorityPicker.isHidden = isEmpty
        }
        return true
    }
    
    // MARK: - Setup Methods
    
    func setupNavigationBar() {
        // Setup liquid glass navigation bar with Cancel and Done buttons
        guard let navController = navigationController else {
            logWarning(
                event: "add_task_navigation_controller_missing",
                message: "Navigation controller unavailable during Add Task setup"
            )
            return
        }

        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = todoColors.accentPrimary
        appearance.titleTextAttributes = [
            .foregroundColor: todoColors.accentOnPrimary,
            .font: TaskerThemeManager.shared.currentTheme.tokens.typography.button
        ]

        navController.navigationBar.standardAppearance = appearance
        navController.navigationBar.scrollEdgeAppearance = appearance
        navController.navigationBar.compactAppearance = appearance
        navController.navigationBar.prefersLargeTitles = false

        // Set title to show date
        title = todoTimeUtils.getFormattedDate(dateForAddTaskView)

        // Create Cancel button (left) — plain text style
        let cancelItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(self.cancelAddTaskAction)
        )
        TaskerNavButtonStyle.apply(to: cancelItem, context: .onGradient, emphasis: .normal)
        cancelItem.accessibilityIdentifier = "addTask.cancelButton"
        navigationItem.leftBarButtonItem = cancelItem

        // Create Done button (right) — bold text style
        let doneItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(self.doneAddTaskAction)
        )
        TaskerNavButtonStyle.apply(to: doneItem, context: .onGradient, emphasis: .done)
        doneItem.accessibilityIdentifier = "addTask.saveButton"
        navigationItem.rightBarButtonItem = doneItem
    }
    
    func setupCalendarWidget() {
        // Setup calendar widget similar to home screen
        setupCalAtAddTask()
        backdropContainer.addSubview(calendar)
    }
    
    func setupDescriptionTextField() {
        let estimatedFrame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 80)
        self.descriptionTextBox_Material = MDCFilledTextField(frame: estimatedFrame)
        self.descriptionTextBox_Material.label.text = "Description (optional)"
        self.descriptionTextBox_Material.leadingAssistiveLabel.text = "Add task details"
        self.descriptionTextBox_Material.placeholder = "Enter task description..."
        self.descriptionTextBox_Material.accessibilityIdentifier = "addTask.descriptionField"
        self.descriptionTextBox_Material.sizeToFit()
        self.descriptionTextBox_Material.delegate = self
        self.descriptionTextBox_Material.clearButtonMode = .whileEditing

        // Token-based styling: iOS-native filled field look
        styleFilledTextField(self.descriptionTextBox_Material)

        // Don't add to stack container here - it's added in viewDidLoad
    }
    
    // MARK: - Sample Pill Bar Setup
    func setupSamplePillBar() {
        buildSamplePillBarData()
        
        let pillBar = createSamplePillBar(items: samplePillBarItems, centerAligned: false)
        samplePillBar?.removeFromSuperview()
        
        samplePillBar = pillBar
        // Don't add to stack container here - it's added in viewDidLoad
    }

    // MARK: - Metadata Row Setup
    func setupMetadataRow() {
        metadataRow.updateDate(dateForAddTaskView)
    }

    // MARK: - Priority Picker Setup
    func setupPriorityPicker() {
        priorityPicker.selectedPriority = currentTaskPriority
    }

    // MARK: - Inline Project Creator Setup
    func setupInlineProjectCreator() {
        // Hidden by default — shown when "Add Project" pill is tapped
    }

    // MARK: - Advanced Metadata Setup
    func setupAdvancedMetadataPanel() {
        advancedMetadataPanel.onLifeAreaTapped = { [weak self] in
            self?.presentLifeAreaSelector()
        }
        advancedMetadataPanel.onSectionTapped = { [weak self] in
            self?.presentSectionSelector()
        }
        advancedMetadataPanel.onTagsTapped = { [weak self] in
            self?.presentTagSelector()
        }
        advancedMetadataPanel.onParentTapped = { [weak self] in
            self?.presentParentTaskSelector()
        }
        advancedMetadataPanel.onDependenciesTapped = { [weak self] in
            self?.presentDependenciesSelector()
        }
        refreshMetadataPanel()
    }

    private func refreshMetadataPanel() {
        guard let viewModel else { return }
        advancedMetadataPanel.update(
            lifeAreas: viewModel.lifeAreas,
            selectedLifeAreaID: viewModel.selectedLifeAreaID,
            sections: viewModel.sections,
            selectedSectionID: viewModel.selectedSectionID,
            tags: viewModel.tags,
            selectedTagIDs: viewModel.selectedTagIDs,
            parentTasks: viewModel.availableParentTasks,
            selectedParentTaskID: viewModel.selectedParentTaskID,
            dependencyTasks: viewModel.availableDependencyTasks,
            selectedDependencyTaskIDs: viewModel.selectedDependencyTaskIDs
        )
    }

    private func configureActionSheetPopover(_ alert: UIAlertController, sourceView: UIView) {
        guard let popover = alert.popoverPresentationController else { return }
        popover.sourceView = sourceView
        popover.sourceRect = sourceView.bounds
        popover.permittedArrowDirections = [.up, .down]
    }

    private func presentLifeAreaSelector() {
        guard let viewModel else { return }
        guard !viewModel.lifeAreas.isEmpty else {
            showError("No life areas available")
            return
        }
        let alert = UIAlertController(title: "Select Life Area", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "None", style: .default) { [weak self] _ in
            self?.viewModel?.selectedLifeAreaID = nil
            self?.refreshMetadataPanel()
        })
        viewModel.lifeAreas.forEach { area in
            let selected = viewModel.selectedLifeAreaID == area.id ? "✓ " : ""
            alert.addAction(UIAlertAction(title: selected + area.name, style: .default) { [weak self] _ in
                self?.viewModel?.selectedLifeAreaID = area.id
                self?.refreshMetadataPanel()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        configureActionSheetPopover(alert, sourceView: advancedMetadataPanel)
        present(alert, animated: true)
    }

    private func presentSectionSelector() {
        guard let viewModel else { return }
        guard !viewModel.sections.isEmpty else {
            showError("No sections available for the selected project")
            return
        }
        let alert = UIAlertController(title: "Select Section", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "None", style: .default) { [weak self] _ in
            self?.viewModel?.selectedSectionID = nil
            self?.refreshMetadataPanel()
        })
        viewModel.sections.forEach { section in
            let selected = viewModel.selectedSectionID == section.id ? "✓ " : ""
            alert.addAction(UIAlertAction(title: selected + section.name, style: .default) { [weak self] _ in
                self?.viewModel?.selectedSectionID = section.id
                self?.refreshMetadataPanel()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        configureActionSheetPopover(alert, sourceView: advancedMetadataPanel)
        present(alert, animated: true)
    }

    private func presentTagSelector() {
        guard let viewModel else { return }
        guard !viewModel.tags.isEmpty else {
            showError("No tags available")
            return
        }
        let alert = UIAlertController(
            title: "Select Tags",
            message: "Tap tags to toggle selection",
            preferredStyle: .actionSheet
        )
        viewModel.tags.forEach { tag in
            let selected = viewModel.selectedTagIDs.contains(tag.id) ? "✓ " : ""
            alert.addAction(UIAlertAction(title: selected + tag.name, style: .default) { [weak self] _ in
                guard let self, let viewModel = self.viewModel else { return }
                if viewModel.selectedTagIDs.contains(tag.id) {
                    viewModel.selectedTagIDs.remove(tag.id)
                } else {
                    viewModel.selectedTagIDs.insert(tag.id)
                }
                self.refreshMetadataPanel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.presentTagSelector()
                }
            })
        }
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        configureActionSheetPopover(alert, sourceView: advancedMetadataPanel)
        present(alert, animated: true)
    }

    private func presentParentTaskSelector() {
        guard let viewModel else { return }
        let alert = UIAlertController(title: "Select Parent Task", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "None", style: .default) { [weak self] _ in
            self?.viewModel?.selectedParentTaskID = nil
            self?.refreshMetadataPanel()
        })
        viewModel.availableParentTasks.forEach { task in
            let selected = viewModel.selectedParentTaskID == task.id ? "✓ " : ""
            alert.addAction(UIAlertAction(title: selected + task.title, style: .default) { [weak self] _ in
                self?.viewModel?.selectedParentTaskID = task.id
                self?.refreshMetadataPanel()
            })
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        configureActionSheetPopover(alert, sourceView: advancedMetadataPanel)
        present(alert, animated: true)
    }

    private func presentDependenciesSelector() {
        guard let viewModel else { return }
        guard !viewModel.availableDependencyTasks.isEmpty else {
            showError("No dependency candidates available for the selected project")
            return
        }
        let alert = UIAlertController(
            title: "Select Dependencies",
            message: "Tap tasks to toggle selection",
            preferredStyle: .actionSheet
        )
        viewModel.availableDependencyTasks.forEach { task in
            let selected = viewModel.selectedDependencyTaskIDs.contains(task.id) ? "✓ " : ""
            alert.addAction(UIAlertAction(title: selected + task.title, style: .default) { [weak self] _ in
                guard let self, let viewModel = self.viewModel else { return }
                if viewModel.selectedDependencyTaskIDs.contains(task.id) {
                    viewModel.selectedDependencyTaskIDs.remove(task.id)
                } else {
                    viewModel.selectedDependencyTaskIDs.insert(task.id)
                }
                self.refreshMetadataPanel()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.presentDependenciesSelector()
                }
            })
        }
        alert.addAction(UIAlertAction(title: "Done", style: .cancel))
        configureActionSheetPopover(alert, sourceView: advancedMetadataPanel)
        present(alert, animated: true)
    }

    func buildSamplePillBarData() {
        if let viewModel {
            applyProjectsToPillBar(viewModel.projects)
        } else {
            samplePillBarItems = [
                PillButtonBarItem(title: addProjectString),
                PillButtonBarItem(title: ProjectConstants.inboxProjectName)
            ]
            updatePillBarUI(selectProject: ProjectConstants.inboxProjectName)
        }
    }
    
    func createSamplePillBar(items: [PillButtonBarItem], centerAligned: Bool = false) -> UIView {
        let bar = PillButtonBar(pillButtonStyle: .primary)
        bar.items = items

        // PHASE 3: Find and pre-select Inbox (should be at index 1, after "Add Project")
        if !items.isEmpty {
            // Find the index of Inbox - must validate index exists before accessing
            if let inboxIndex = items.firstIndex(where: { $0.title.lowercased() == "inbox" }) {
                _ = bar.selectItem(atIndex: inboxIndex) // Pre-select Inbox
                self.currenttProjectForAddTaskView = items[inboxIndex].title
                logDebug("✅ Phase 3: Pre-selected '\(items[inboxIndex].title)' at index \(inboxIndex)")
            } else if items.count > 1 {
                // Fallback to second item if Inbox not found and array has more than 1 element
                _ = bar.selectItem(atIndex: 1)
                self.currenttProjectForAddTaskView = items[1].title
                logDebug("✅ Phase 3: Pre-selected '\(items[1].title)' at index 1")
            } else {
                // Only "Add Project" item exists - select first item
                _ = bar.selectItem(atIndex: 0)
                self.currenttProjectForAddTaskView = items[0].title
                logDebug("✅ Phase 3: Pre-selected '\(items[0].title)' at index 0")
            }
        }

        bar.barDelegate = self
        bar.centerAligned = centerAligned
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = .clear
        
        backgroundView.addSubview(bar)
        let margins = UIEdgeInsets(top: 8.0, left: 0, bottom: 8.0, right: 0.0)
        fitViewIntoSuperview(bar, margins: margins)
        return backgroundView
    }
    
    // fitViewIntoSuperview method is defined in AddTaskForedropView.swift extension

    // @objc func cancelAddTaskAction() is now only in AddTaskForedropView.swift extension

} // This is the main closing brace for AddTaskViewController

// MARK: - PillButtonBarDemoController: PillButtonBarDelegate

extension AddTaskViewController {
    func pillBar(_ pillBar: PillButtonBar, didSelectItem item: PillButtonBarItem, atIndex index: Int) {
        // Check if this is the sample pill bar
        if let samplePillBarView = samplePillBar,
           let samplePillBarComponent = samplePillBarView.subviews.first as? PillButtonBar,
           pillBar === samplePillBarComponent {
            
            // PHASE 3: Check if "Add Project" was tapped
            if item.title == addProjectString {
                logDebug("🎯 'Add Project' button tapped — showing inline creator")
                inlineProjectCreator.show()
                
                // Re-select the previously selected project (don't leave "Add Project" selected)
                if let previousProjectIndex = samplePillBarItems.firstIndex(where: { $0.title == currenttProjectForAddTaskView }) {
                    _ = pillBar.selectItem(atIndex: previousProjectIndex)
                } else {
                    // Default to Inbox if no previous selection
                    if let inboxIndex = samplePillBarItems.firstIndex(where: { $0.title.lowercased() == "inbox" }) {
                        _ = pillBar.selectItem(atIndex: inboxIndex)
                        self.currenttProjectForAddTaskView = "Inbox"
                    }
                }
                return
            }
            
            // Update current project based on pill selection
            logDebug("Sample pill bar item selected: \(item.title) at index \(index)")
            self.currenttProjectForAddTaskView = item.title
            self.viewModel?.selectedProject = item.title
            self.refreshMetadataPanel()
            return
        }
        
        // Only handle sample pill bar - no project pill bar logic needed
        
        
    }
    
    // PHASE 3: Present dialog to add a new project
    private func presentAddProjectDialog() {
        let alertController = UIAlertController(
            title: "New Project",
            message: "Enter project name and description",
            preferredStyle: .alert
        )
        
        // Add text fields
        alertController.addTextField { textField in
            textField.placeholder = "Project Name"
            textField.autocapitalizationType = .words
        }
        
        alertController.addTextField { textField in
            textField.placeholder = "Description (Optional)"
            textField.autocapitalizationType = .sentences
        }
        
        // Cancel action
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        // Save action
        let saveAction = UIAlertAction(title: "Create", style: .default) { [weak self, weak alertController] _ in
            guard let self = self,
                  let nameField = alertController?.textFields?[0],
                  let descriptionField = alertController?.textFields?[1],
                  let projectName = nameField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !projectName.isEmpty else {
                self?.showProjectError(message: "Project name cannot be empty")
                return
            }
            
            // Check if project name is "Inbox" (reserved)
            if projectName.lowercased() == "inbox" {
                self.showProjectError(message: "'Inbox' is a reserved project name")
                return
            }
            
            // Create the project
            self.createNewProject(name: projectName, description: descriptionField.text)
        }
        
        alertController.addAction(cancelAction)
        alertController.addAction(saveAction)
        
        present(alertController, animated: true)
    }
    
    // PHASE 3: Create a new project using Clean Architecture
    private func createNewProject(name: String, description: String?) {
        guard let viewModel else {
            showProjectError(message: "Project service unavailable")
            return
        }

        _ = description // Reserved for future project description support in view model API.
        currenttProjectForAddTaskView = name
        viewModel.createProject(name: name)
    }
    
    // Update the pill bar UI with current items (does NOT reload from database)
    // Use this after loadProjectsFallback() has already populated samplePillBarItems
    private func updatePillBarUI(selectProject projectName: String) {
        // Recreate the pill bar with current items
        let newPillBar = createSamplePillBar(items: samplePillBarItems, centerAligned: false)

        // Replace the old pill bar
        samplePillBar?.removeFromSuperview()
        samplePillBar = newPillBar

        // Add to the view hierarchy
        let stackView = foredropStackContainer
        // Find correct position (after metadata row, before priority)
        var insertIndex: Int
        if let metadataIndex = stackView.arrangedSubviews.firstIndex(where: { $0 === metadataRow }) {
            insertIndex = metadataIndex + 1
        } else {
            insertIndex = min(3, stackView.arrangedSubviews.count)
        }
        stackView.insertArrangedSubview(newPillBar, at: insertIndex)

        // Select the specified project
        if let pillBarComponent = newPillBar.subviews.first as? PillButtonBar,
           let projectIndex = samplePillBarItems.firstIndex(where: { $0.title == projectName }) {
            _ = pillBarComponent.selectItem(atIndex: projectIndex)
            self.currenttProjectForAddTaskView = projectName
            self.viewModel?.selectedProject = projectName
            self.refreshMetadataPanel()
            logDebug("✅ Pre-selected project '\(projectName)' at index \(projectIndex)")
        }
    }

    // PHASE 3: Add newly created project directly to pill bar (avoids Core Data context merge timing issues)
    private func addNewProjectToPillBar(project: Project) {
        // Create new pill item for the project
        let newProjectItem = PillButtonBarItem(title: project.name)

        // Check if project already exists (avoid duplicates)
        if samplePillBarItems.contains(where: { $0.title == project.name }) {
            self.currenttProjectForAddTaskView = project.name
            updatePillBarUI(selectProject: project.name)
            return
        }

        // Find correct insertion position
        // Order: Add Project button (index 0) → Inbox (index 1) → Custom projects alphabetically
        if let inboxIndex = samplePillBarItems.firstIndex(where: { $0.title.lowercased() == "inbox" }) {
            // Insert after Inbox, maintaining alphabetical order with other custom projects
            var insertPosition = inboxIndex + 1
            for i in insertPosition..<samplePillBarItems.count {
                let existingName = samplePillBarItems[i].title
                if existingName.compare(project.name) == .orderedDescending {
                    insertPosition = i
                    break
                }
            }
            samplePillBarItems.insert(newProjectItem, at: insertPosition)
            logDebug("✅ Added project '\(project.name)' to pill bar at index \(insertPosition)")
        } else {
            // No Inbox found, append to end
            samplePillBarItems.append(newProjectItem)
            logDebug("✅ Added project '\(project.name)' to end of pill bar")
        }

        // Update current selection and UI
        self.currenttProjectForAddTaskView = project.name
        updatePillBarUI(selectProject: project.name)
    }

    // PHASE 3: Refresh the pill bar after creating a new project (reloads from database)
    private func refreshProjectPillBar(selectProject projectName: String) {
        // Store the project name to select FIRST, before triggering async load
        // This ensures loadProjectsFallback() completion reads the correct value
        self.currenttProjectForAddTaskView = projectName

        // Rebuild pill bar data from database (triggers async loadProjectsFallback)
        buildSamplePillBarData()
    }
    
    // PHASE 3: Show error message
    private func showProjectError(message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // PHASE 3: Show success message
    private func showProjectSuccess(message: String) {
        let alert = UIAlertController(title: "Success", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - AddTaskMetadataRowDelegate

extension AddTaskViewController: AddTaskMetadataRowDelegate {
    func metadataRow(_ row: AddTaskMetadataRowView, didSelectDate date: Date) {
        dateForAddTaskView = date
        // Sync FSCalendar selection
        calendar?.select(date, scrollToDate: true)
        // Update nav title
        title = todoTimeUtils.getFormattedDate(date)
    }

    func metadataRow(_ row: AddTaskMetadataRowView, didSetReminder time: Date?) {
        alertReminderTime = time
    }

    func metadataRow(_ row: AddTaskMetadataRowView, didToggleEvening isEvening: Bool) {
        isThisEveningTask = isEvening
    }
}

// MARK: - AddTaskPriorityPickerDelegate

extension AddTaskViewController: AddTaskPriorityPickerDelegate {
    func priorityPicker(_ picker: AddTaskPriorityPickerView, didSelect priority: TaskPriority) {
        currentTaskPriority = priority
    }
}

// MARK: - InlineProjectCreatorDelegate

extension AddTaskViewController: InlineProjectCreatorDelegate {
    func inlineProjectCreator(_ creator: AddTaskInlineProjectCreatorView, didCreate projectName: String) {
        // Validate reserved name
        if projectName.lowercased() == "inbox" {
            creator.showValidationError()
            return
        }

        // Check for duplicates
        if samplePillBarItems.contains(where: { $0.title.lowercased() == projectName.lowercased() }) {
            creator.showValidationError()
            return
        }

        // Create project using existing Clean Architecture flow
        createNewProject(name: projectName, description: nil)
        creator.hide(success: true)
    }

    func inlineProjectCreatorDidCancel(_ creator: AddTaskInlineProjectCreatorView) {
        creator.hide()
    }
}

class ProjectCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    func setup() {
        self.backgroundColor = UIColor.tasker.surfaceSecondary
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("FATAL Error on my collectionview")
    }
}

class AddNewProjectCell: UICollectionViewCell {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    
    
    func setup() {
        self.backgroundColor = UIColor.tasker.surfaceSecondary
        
        self.addSubview(addProjectImageView)
        self.addSubview(addProjectLabel)
        
        addProjectImageView.anchor(top: topAnchor, left: leftAnchor, bottom: nil, right: rightAnchor, paddingTop: 0, paddingLeft: 5, paddingBottom: 5, paddingRight: 5, width: 0, height: 30)
        
        addProjectLabel.anchor(top: nil, left: leftAnchor, bottom: bottomAnchor, right: rightAnchor, paddingTop: 5, paddingLeft: 5, paddingBottom: 0, paddingRight: 5, width: 0, height: 20)
    }
    
    let addProjectImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = UIColor.tasker.accentPrimary
        iv.image = #imageLiteral(resourceName: "material_add_White")
        return iv
    }()
    
    let addProjectLabel: UILabel = {
        let label = UILabel()
        label.text = "Add \nProject"
        label.textColor = .label
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        return label
    }()
    
    required init?(coder: NSCoder) {
        fatalError("FATAL Error on my collectionview")
    }
}

extension UIView {
    func anchor(
        top: NSLayoutYAxisAnchor?,
        left: NSLayoutXAxisAnchor?,
        bottom: NSLayoutYAxisAnchor?,
        right: NSLayoutXAxisAnchor?,
        paddingTop: CGFloat, paddingLeft: CGFloat,
        paddingBottom: CGFloat,
        paddingRight: CGFloat,
        width: CGFloat = 0,
        height: CGFloat = 0) {
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        if let top = top {
            self.topAnchor.constraint(equalTo: top, constant: paddingTop).isActive = true
        }
        
        if let left = left {
            self.leftAnchor.constraint(equalTo: left, constant: paddingLeft).isActive = true
        }
        
        if let bottom = bottom {
            self.bottomAnchor.constraint(equalTo: bottom, constant: paddingBottom).isActive = true
        }
        
        if let right = right {
            self.rightAnchor.constraint(equalTo: right, constant: -paddingRight).isActive = true
        }
        
        if width != 0 {
            self.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        
        if height != 0 {
            self.heightAnchor.constraint(equalToConstant: height).isActive = true
        }
    }
    
    var safeTopAnchor: NSLayoutYAxisAnchor {
        if #available(iOS 11.0, *) {
            return safeAreaLayoutGuide.topAnchor
        }
        return topAnchor
    }
    
    var safeLeftAnchor: NSLayoutXAxisAnchor {
        if #available(iOS 11.0, *) {
            return safeAreaLayoutGuide.leftAnchor
        }
        return leftAnchor
    }
    
    var safeBottomAnchor: NSLayoutYAxisAnchor {
        if #available(iOS 11.0, *) {
            return safeAreaLayoutGuide.bottomAnchor
        }
        return bottomAnchor
    }
    
    var safeRightAnchor: NSLayoutXAxisAnchor {
        if #available(iOS 11.0, *) {
            return safeAreaLayoutGuide.rightAnchor
        }
        return rightAnchor
    }
    
}
