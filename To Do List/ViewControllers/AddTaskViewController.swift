//
//  AddTaskViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 04/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import FSCalendar
import FluentUI
import MaterialComponents.MaterialTextControls_FilledTextAreas
import MaterialComponents.MaterialTextControls_FilledTextFields
import MaterialComponents.MaterialTextControls_OutlinedTextAreas
import MaterialComponents.MaterialTextControls_OutlinedTextFields
import Combine

// Import Clean Architecture components
@_exported import Foundation

class AddTaskViewController: UIViewController, UITextFieldDelegate, PillButtonBarDelegate, UIScrollViewDelegate, TaskRepositoryDependent, AddTaskViewControllerProtocol {

    // Delegate for communicating back to the presenter
    weak var delegate: AddTaskViewControllerDelegate?

    // MARK: - Repository Dependency
    var taskRepository: TaskRepository!

    /// AddTaskViewModel dependency (injected) - Clean Architecture
    /// Note: Optional to avoid crashes when ViewModel path is disabled
    var viewModel: AddTaskViewModel?

    /// Combine cancellables for reactive bindings
    private var cancellables = Set<AnyCancellable>()

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
    let p = ["None", "Low", "High", "Max"] // Used by AddTaskForedropView extension - shortened "Highest" to "Max" to prevent text wrapping

    var tabsSegmentedControl = UISegmentedControl() // Initialized in AddTaskForedropView extension

    var todoColors = ToDoColors()
    var todoFont = ToDoFont()
    var todoTimeUtils = ToDoTimeUtils()

    let existingProjectCellID = "existingProject"
    let newProjectCellID = "newProject"

    //MARK:- Buttons + Views + Bottom bar
    var calendar: FSCalendar!

    //MARK:- current task list date
    var dateForAddTaskView = Date.today()




    func setProjecForView(name: String) {
        // currenttProjectForAddTaskView = name // Logic seems commented out
    }

//    //MARK:- DONE TASK ACTION (Stub for extension)
//    @objc func doneAddTaskAction() {
//        // This is just a stub that will be called from the extension
//        // The actual implementation is in AddTaskForedropView.swift extension
//        print("AddTaskViewController: doneAddTaskAction (stub) called")
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
        print("🚀 AddTaskViewController: viewDidLoad called")
        
        // ACTIVATE CLEAN ARCHITECTURE - Primary dependency injection
        print("🏗️ Activating AddTask Clean Architecture")
        // Use legacy injection for now until module issues are resolved
        DependencyContainer.shared.inject(into: self)
        
        print("🔍 AddTaskViewController: Checking dependency injection state...")
        
        // TODO: Re-enable when ViewModel is available
        // Check Clean Architecture vs Legacy injection state
        // if viewModel != nil {
        //     print("✅ AddTaskViewController: ViewModel properly injected - Using Clean Architecture")
        //     print("📊 AddTaskViewController: ViewModel type: \(String(describing: type(of: viewModel)))")
        //     setupViewModelBindings()
        // } else {
            print("⚠️ AddTaskViewController: ViewModel is nil - Using Legacy Mode")
        // }
        
        // Check legacy repository injection
        if taskRepository == nil {
            print("❌ AddTaskViewController: taskRepository is nil in viewDidLoad!")
            print("🔧 AddTaskViewController: This indicates dependency injection hasn't happened yet")
        } else {
            print("✅ AddTaskViewController: taskRepository is properly injected")
            print("📊 AddTaskViewController: Repository type: \(String(describing: type(of: taskRepository)))")
        }
        
        print("🤝 AddTaskViewController: Delegate state: \(delegate != nil ? "Set" : "Nil")")
        if let delegate = delegate {
            print("📊 AddTaskViewController: Delegate type: \(String(describing: type(of: delegate)))")
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
        setupSamplePillBar() // New sample pill bar
        setupPrioritySC()
        // OLD: setupDoneButton() - removed, now using navigation bar Done button

        // Add components to foredrop stack container in order
        // Ensure all components are visible and properly configured
        self.addTaskTextBox_Material.isHidden = false
        self.addTaskTextBox_Material.translatesAutoresizingMaskIntoConstraints = false
        self.foredropStackContainer.addArrangedSubview(self.addTaskTextBox_Material)

        self.descriptionTextBox_Material.isHidden = false
        self.descriptionTextBox_Material.translatesAutoresizingMaskIntoConstraints = false
        self.foredropStackContainer.addArrangedSubview(self.descriptionTextBox_Material)

        // Add the new sample pill bar after description text field
        if let samplePillBar = self.samplePillBar {
            samplePillBar.isHidden = false
            samplePillBar.translatesAutoresizingMaskIntoConstraints = false
            self.foredropStackContainer.addArrangedSubview(samplePillBar)
        }

        self.tabsSegmentedControl.isHidden = false
        self.tabsSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        self.foredropStackContainer.addArrangedSubview(self.tabsSegmentedControl)

        // OLD: Done button FAB removed - now using navigation bar button
        // self.fab_doneTask.translatesAutoresizingMaskIntoConstraints = false
        // self.foredropStackContainer.addArrangedSubview(self.fab_doneTask)

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
    }
    
    // MARK: - Clean Architecture Methods
    
    /// Setup ViewModel bindings for reactive UI
    /// TODO: Re-enable when ViewModel is available
    private func setupViewModelBindings() {
        // guard let viewModel = viewModel else { return }
        //
        // // TODO: Bindings commented out until real ViewModel with @Published properties is integrated
        // /*
        // // Bind loading state
        // viewModel.$isLoading
        //     .receive(on: DispatchQueue.main)
        //     .sink { [weak self] isLoading in
        //         // Update UI loading state - disable navigation bar Done button while loading
        //         self?.navigationItem.rightBarButtonItem?.isEnabled = !isLoading
        //     }
        //     .store(in: &cancellables)
        //
        // // Bind error messages
        // viewModel.$errorMessage
        //     .receive(on: DispatchQueue.main)
        //     .compactMap { $0 }
        //     .sink { [weak self] error in
        //         self?.showError(error)
        //     }
        //     .store(in: &cancellables)
        //
        // // Bind available projects
        // viewModel.$availableProjects
        //     .receive(on: DispatchQueue.main)
        //     .sink { [weak self] projects in
        //         // Update project selection UI if needed
        //         self?.updateProjectSelection(projects)
        //     }
        //     .store(in: &cancellables)
        // */
        print("⚠️ setupViewModelBindings disabled - TODO: Re-enable when ViewModel is available")
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
        // Update pill bar or other project selection UI based on available projects
        // This can be enhanced based on your specific UI needs
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("👁️ AddTaskViewController: viewWillAppear called")
        
        // Re-check dependency injection state before view appears
        print("🔍 AddTaskViewController: Re-checking dependency injection state...")
        if taskRepository == nil {
            print("❌ AddTaskViewController: taskRepository is STILL nil in viewWillAppear!")
            print("🚨 AddTaskViewController: This is a critical issue - attempting fallback injection")
            
            // Try to inject dependencies as a fallback
            DependencyContainer.shared.inject(into: self)
            
            if taskRepository != nil {
                print("✅ AddTaskViewController: Fallback injection successful")
            } else {
                print("💥 AddTaskViewController: Fallback injection FAILED - this will likely cause crashes")
            }
        } else {
            print("✅ AddTaskViewController: taskRepository is properly available")
        }
        
        print("🤝 AddTaskViewController: Delegate state: \(delegate != nil ? "Set" : "Nil")")
        
        // Set default project to Inbox
        currenttProjectForAddTaskView = "Inbox"
        print("📁 AddTaskViewController: Default project set to: \(currenttProjectForAddTaskView)")
    }
    
    // MARK:- Build Page Header
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent // Or .default depending on your background
    }
    
    // MARK: - UITextFieldDelegate
    // This function is called when you click return key in the text field.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn called")
        textField.resignFirstResponder()
        self.doneAddTaskAction() // Call the action defined in the extension
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let oldText = textField.text, let stringRange = Range(range, in: oldText) {
            let newText = oldText.replacingCharacters(in: stringRange, with: string)
            print("AddTaskViewController: new text is: \(newText)")
            
            if textField == addTaskTextBox_Material {
                currentTaskInMaterialTextBox = newText
            } else if textField == descriptionTextBox_Material {
                currentTaskDescription = newText
            }
            
            let isEmpty = currentTaskInMaterialTextBox.isEmpty
            // Enable/disable navigation bar Done button based on text field content
            navigationItem.rightBarButtonItem?.isEnabled = !isEmpty
            // Show/hide priority segmented control based on text field content
            self.tabsSegmentedControl.isHidden = isEmpty
        }
        return true
    }
    
    // MARK: - Setup Methods
    
    func setupNavigationBar() {
        // Setup liquid glass navigation bar with Cancel and Done buttons
        guard let navController = navigationController else {
            print("⚠️ AddTaskViewController: No navigation controller found")
            return
        }

        // Configure navigation bar appearance
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = todoColors.primaryColor
        appearance.titleTextAttributes = [
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]

        navController.navigationBar.standardAppearance = appearance
        navController.navigationBar.scrollEdgeAppearance = appearance
        navController.navigationBar.compactAppearance = appearance
        navController.navigationBar.prefersLargeTitles = false

        // Set title to show date
        title = todoTimeUtils.getFormattedDate(dateForAddTaskView)

        // Create Cancel button (left)
        let cancelButton = createLiquidGlassBarButton(
            title: "Cancel",
            image: UIImage(systemName: "xmark"),
            action: #selector(self.cancelAddTaskAction)
        )
        if let customView = cancelButton.customView {
            customView.accessibilityIdentifier = "addTask.cancelButton"
        }
        navigationItem.leftBarButtonItem = cancelButton

        // Create Done button (right)
        let doneButton = createLiquidGlassBarButton(
            title: "Done",
            image: UIImage(systemName: "checkmark"),
            action: #selector(self.doneAddTaskAction)
        )
        if let customView = doneButton.customView {
            customView.accessibilityIdentifier = "addTask.saveButton"
        }
        navigationItem.rightBarButtonItem = doneButton
    }

    /// Creates a UIBarButtonItem with liquid glass styling
    private func createLiquidGlassBarButton(
        title: String,
        image: UIImage?,
        action: Selector
    ) -> UIBarButtonItem {
        // Create container with glass effect
        let containerView = LGBaseView(frame: CGRect(x: 0, y: 0, width: 90, height: 36))
        containerView.cornerRadius = 18
        containerView.glassBlurStyle = .systemUltraThinMaterial
        containerView.glassOpacity = 0.9
        containerView.borderColor = .white.withAlphaComponent(0.3)

        // Create button inside container
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setImage(image, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.tintColor = .white
        button.addTarget(self, action: action, for: .touchUpInside)

        // Configure button layout (icon + text)
        button.semanticContentAttribute = .forceLeftToRight
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -4, bottom: 0, right: 4)
        button.titleEdgeInsets = UIEdgeInsets(top: 0, left: 4, bottom: 0, right: -4)

        // Add button to container
        containerView.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 8),
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -8),
            button.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -6)
        ])

        return UIBarButtonItem(customView: containerView)
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
        self.descriptionTextBox_Material.backgroundColor = .clear

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
    
    /// Load projects via fallback using CoreDataProjectRepository
    /// Called when ViewModel is not available
    private func loadProjectsFallback() {
        print("⚠️ ViewModel not available, using fallback to load projects")

        guard let container = DependencyContainer.shared.persistentContainer else {
            print("❌ Failed to get persistentContainer for project fallback")
            samplePillBarItems.append(PillButtonBarItem(title: "Inbox"))
            return
        }

        // Use CoreDataProjectRepository from State layer to fetch all projects
        let projectRepo = CoreDataProjectRepository(container: container)

        // Fetch all projects asynchronously
        projectRepo.fetchAllProjects { [weak self] result in
            guard let self = self else { return }

            DispatchQueue.main.async {
                switch result {
                case .success(let domainProjects):
                    // Reset the list with "Add Project" button as first item
                    self.samplePillBarItems = []
                    self.samplePillBarItems.append(PillButtonBarItem(title: self.addProjectString))

                    // Separate Inbox from other projects
                    let inboxProject = domainProjects.first { $0.name.lowercased() == "inbox" }
                    let customProjects = domainProjects.filter { $0.name.lowercased() != "inbox" }
                        .sorted { $0.name < $1.name }

                    // Add Inbox as second item (index 1) - always present
                    let inboxTitle = inboxProject?.name ?? "Inbox"
                    self.samplePillBarItems.append(PillButtonBarItem(title: inboxTitle))

                    // Add all custom projects after Inbox
                    for project in customProjects {
                        self.samplePillBarItems.append(PillButtonBarItem(title: project.name))
                        print("✅ Added custom project to pill bar: \(project.name)")
                    }

                    print("✅ Loaded \(customProjects.count) custom projects via fallback")

                    // Refresh the pill bar with the loaded projects
                    self.refreshProjectPillBar(selectProject: inboxTitle)

                case .failure(let error):
                    print("❌ Failed to load projects via fallback: \(error)")
                    // Ensure at least Inbox is present
                    self.samplePillBarItems = []
                    self.samplePillBarItems.append(PillButtonBarItem(title: self.addProjectString))
                    self.samplePillBarItems.append(PillButtonBarItem(title: "Inbox"))
                    self.refreshProjectPillBar(selectProject: "Inbox")
                }
            }
        }
    }

    func buildSamplePillBarData() {
        // Reset the list
        samplePillBarItems = []

        // PHASE 3: Add "Add Project" button as the first pill (index 0)
        samplePillBarItems.append(PillButtonBarItem(title: addProjectString))

        // Use fallback to load all projects (since ViewModel is not available)
        loadProjectsFallback()
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
                print("✅ Phase 3: Pre-selected '\(items[inboxIndex].title)' at index \(inboxIndex)")
            } else if items.count > 1 {
                // Fallback to second item if Inbox not found and array has more than 1 element
                _ = bar.selectItem(atIndex: 1)
                self.currenttProjectForAddTaskView = items[1].title
                print("✅ Phase 3: Pre-selected '\(items[1].title)' at index 1")
            } else {
                // Only "Add Project" item exists - select first item
                _ = bar.selectItem(atIndex: 0)
                self.currenttProjectForAddTaskView = items[0].title
                print("✅ Phase 3: Pre-selected '\(items[0].title)' at index 0")
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
                print("🎯 Phase 3: 'Add Project' button tapped")
                presentAddProjectDialog()
                
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
            print("Sample pill bar item selected: \(item.title) at index \(index)")
            self.currenttProjectForAddTaskView = item.title
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
    /// TODO: Re-enable when ViewModel is available
    private func createNewProject(name: String, description: String?) {
        // Use ViewModel to create project (Clean Architecture)
        // guard let viewModel = viewModel else {
        //     print("⚠️ ViewModel not available")
        //     showProjectError(message: "Failed to create project")
        //     return
        // }
        //
        // // Create request for new project
        // let request = CreateProjectRequest(name: name, description: description)
        //
        // // Use UseCaseCoordinator through ViewModel
        // // Note: AddTaskViewModel should have a createProject method that calls UseCaseCoordinator.manageProjects
        // print("🆕 Creating project '\(name)' using Clean Architecture")

        print("⚠️ Creating project using legacy method - TODO: Re-enable Clean Architecture when ViewModel is available")

        // Create request for new project
        let request = CreateProjectRequest(name: name, description: description)

        // Temporary: Create UseCaseCoordinator locally until proper DI is set up
        // TODO: Add createProject method to AddTaskViewModel
        guard let taskRepo = DependencyContainer.shared.taskRepository as? TaskRepositoryProtocol,
              let container = DependencyContainer.shared.persistentContainer else {
            print("❌ Failed to get dependencies")
            showProjectError(message: "Failed to create project")
            return
        }

        // Use CoreDataProjectRepository from State layer
        let projectRepo = CoreDataProjectRepository(container: container)
        let useCaseCoordinator = UseCaseCoordinator(
            taskRepository: taskRepo,
            projectRepository: projectRepo,
            cacheService: nil
        )

        useCaseCoordinator.manageProjects.createProject(request: request) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let project):
                    print("✅ Phase 3: Successfully created project '\(project.name)'")
                    self?.showProjectSuccess(message: "Project '\(project.name)' created")
                    self?.refreshProjectPillBar(selectProject: project.name)

                case .failure(let error):
                    print("❌ Phase 3: Failed to create project: \(error)")
                    self?.showProjectError(message: "Failed to create project")
                }
            }
        }
    }
    
    // PHASE 3: Refresh the pill bar after creating a new project
    private func refreshProjectPillBar(selectProject projectName: String) {
        // Rebuild pill bar data
        buildSamplePillBarData()
        
        // Recreate the pill bar
        let newPillBar = createSamplePillBar(items: samplePillBarItems, centerAligned: false)
        
        // Replace the old pill bar
        samplePillBar?.removeFromSuperview()
        samplePillBar = newPillBar
        
        // Add back to the view hierarchy (find its position in the stack)
        if let stackView = foredropStackContainer as? UIStackView {
            // Find where the old pill bar was (should be after description field)
            var insertIndex = 2 // Default position after text fields
            for (index, view) in stackView.arrangedSubviews.enumerated() {
                if view === samplePillBar {
                    insertIndex = index
                    break
                }
            }
            
            stackView.insertArrangedSubview(newPillBar, at: insertIndex)
        }
        
        // Select the newly created project
        if let pillBarComponent = newPillBar.subviews.first as? PillButtonBar,
           let projectIndex = samplePillBarItems.firstIndex(where: { $0.title == projectName }) {
            _ = pillBarComponent.selectItem(atIndex: projectIndex)
            self.currenttProjectForAddTaskView = projectName
            print("✅ Phase 3: Selected newly created project '\(projectName)'")
        }
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

class ProjectCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    func setup() {
        self.backgroundColor = .red
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("FATAL Error on my collectionview")
    }
}

class AddNewProjectCell: UICollectionViewCell {
    
    var todoFont = ToDoFont()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    
    
    func setup() {
        self.backgroundColor = .blue
        
        self.addSubview(addProjectImageView)
        self.addSubview(addProjectLabel)
        
        addProjectImageView.anchor(top: topAnchor, left: leftAnchor, bottom: nil, right: rightAnchor, paddingTop: 0, paddingLeft: 5, paddingBottom: 5, paddingRight: 5, width: 0, height: 30)
        
        addProjectLabel.anchor(top: nil, left: leftAnchor, bottom: bottomAnchor, right: rightAnchor, paddingTop: 5, paddingLeft: 5, paddingBottom: 0, paddingRight: 5, width: 0, height: 20)
    }
    
    let addProjectImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .green
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


