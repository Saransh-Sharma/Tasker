//
//  AddTaskViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 04/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import CoreData
import FSCalendar
import FluentUI
import MaterialComponents.MaterialTextControls_FilledTextAreas
import MaterialComponents.MaterialTextControls_FilledTextFields
import MaterialComponents.MaterialTextControls_OutlinedTextAreas
import MaterialComponents.MaterialTextControls_OutlinedTextFields
import Combine

// Import Clean Architecture components
@_exported import Foundation
// The ViewModels and Protocols should be available via dependency injection

// MARK: - Clean Architecture Protocol Definitions
// Temporary protocol definitions until module issues are resolved

/// Protocol for AddTaskViewController to receive ViewModel
protocol AddTaskViewControllerProtocol: AnyObject {
    var viewModel: AddTaskViewModel? { get set }
}

/// Placeholder for AddTaskViewModel until proper import is resolved
class AddTaskViewModel {
    // Placeholder implementation
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var availableProjects: [Project] = []
    
    func createTask(request: CreateTaskRequest, completion: @escaping (Result<Task, Error>) -> Void) {
        // Placeholder implementation
        completion(.failure(NSError(domain: "AddTaskViewModel", code: 1, userInfo: [NSLocalizedDescriptionKey: "ViewModel not properly injected"])))
    }
}

class AddTaskViewController: UIViewController, UITextFieldDelegate, PillButtonBarDelegate, UIScrollViewDelegate, TaskRepositoryDependent, AddTaskViewControllerProtocol {
    
    // Delegate for communicating back to the presenter
    weak var delegate: AddTaskViewControllerDelegate?
    
    // MARK: - Repository Dependency
    var taskRepository: TaskRepository!
    
    /// AddTaskViewModel dependency (injected) - Clean Architecture
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
    // let cancelButton = UIView() // This seemed unused, removed for now. Add back if needed.
    let eveningSwitch = UISwitch()
    // var prioritySC =  UISegmentedControl() // This is initialized in AddTaskForedropView extension

    let switchSetContainer = UIView()
    let switchBackground = UIView()
    let eveningLabel = UILabel()

    var addTaskTextBox_Material = MDCFilledTextField()
    let nCancelButton = UIButton()
    let fab_doneTask = MDCFloatingButton(shape: .default)
    let p = ["None", "Low", "High", "Max"] // Used by AddTaskForedropView extension - shortened "Highest" to "Max" to prevent text wrapping

    var tabsSegmentedControl = UISegmentedControl() // Initialized in AddTaskForedropView extension

    var todoColors = ToDoColors()
    var todoFont = ToDoFont()
    var todoTimeUtils = ToDoTimeUtils()

    let homeDate_Day = UILabel()
    let homeDate_WeekDay = UILabel()
    let homeDate_Month = UILabel()

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
        
        // Check Clean Architecture vs Legacy injection state
        if viewModel != nil {
            print("✅ AddTaskViewController: ViewModel properly injected - Using Clean Architecture")
            print("📊 AddTaskViewController: ViewModel type: \(String(describing: type(of: viewModel)))")
            setupViewModelBindings()
        } else {
            print("⚠️ AddTaskViewController: ViewModel is nil - Using Legacy Mode")
        }
        
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
        setupDoneButton()
        
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
        
        // Done button visibility is controlled by text field content
        self.fab_doneTask.translatesAutoresizingMaskIntoConstraints = false
        self.foredropStackContainer.addArrangedSubview(self.fab_doneTask)

        addTaskTextBox_Material.becomeFirstResponder()
        addTaskTextBox_Material.keyboardType = .default
        addTaskTextBox_Material.autocorrectionType = .yes
        addTaskTextBox_Material.smartDashesType = .yes
        addTaskTextBox_Material.smartQuotesType = .yes
        addTaskTextBox_Material.smartInsertDeleteType = .yes
        addTaskTextBox_Material.delegate = self
    }
    
    // MARK: - Clean Architecture Methods
    
    /// Setup ViewModel bindings for reactive UI
    private func setupViewModelBindings() {
        guard let viewModel = viewModel else { return }
        
        // Bind loading state
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                // Update UI loading state (e.g., disable done button while loading)
                self?.fab_doneTask.isEnabled = !isLoading
            }
            .store(in: &cancellables)
        
        // Bind error messages
        viewModel.$errorMessage
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { [weak self] error in
                self?.showError(error)
            }
            .store(in: &cancellables)
        
        // Bind available projects
        viewModel.$availableProjects
            .receive(on: DispatchQueue.main)
            .sink { [weak self] projects in
                // Update project selection UI if needed
                self?.updateProjectSelection(projects)
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
            // fab_doneTask and tabsSegmentedControl are properties of AddTaskViewController (self)
            // and are assumed to be correctly initialized/managed by the extension methods.
            self.fab_doneTask.isHidden = isEmpty
            self.tabsSegmentedControl.isHidden = isEmpty
            self.fab_doneTask.isEnabled = !isEmpty
        }
        return true
    }
    
    // MARK: - Setup Methods
    
    func setupNavigationBar() {
        // Setup navigation bar similar to home screen
        nCancelButton.setTitle("Cancel", for: .normal)
        nCancelButton.setTitleColor(.white, for: .normal)
        nCancelButton.titleLabel?.font = todoFont.setFont(fontSize: 16, fontweight: .medium, fontDesign: .default)
        nCancelButton.frame = CGRect(x: UIScreen.main.bounds.maxX - 80, y: 50, width: 70, height: 35)
        view.addSubview(nCancelButton)
        nCancelButton.addTarget(self, action: #selector(self.cancelAddTaskAction), for: .touchUpInside)
        
        // Setup date display in navigation bar
        setHomeViewDate()
        homeTopBar.addSubview(homeDate_Day)
        homeTopBar.addSubview(homeDate_WeekDay)
        homeTopBar.addSubview(homeDate_Month)
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
    
    func buildSamplePillBarData() {
        // Use empty list for now - will be populated via Clean Architecture
        samplePillBarItems = [] // Reset the list
        
        // Add default Inbox project
        let inboxTitle = "Inbox"
        
        // Remove any existing "Inbox" to avoid duplicates before re-inserting at correct position
        samplePillBarItems.removeAll(where: { $0.title.lowercased() == inboxTitle.lowercased() })
        
        // Insert "Inbox" at the beginning
        samplePillBarItems.insert(PillButtonBarItem(title: inboxTitle), at: 0)
        
        // Log the final list for verification
        print("Final samplePillBarItems for AddTaskScreen setup:")
        for (index, value) in samplePillBarItems.enumerated() {
            print("--- AT INDEX \(index) value is \(value.title)")
        }
    }
    
    func createSamplePillBar(items: [PillButtonBarItem], centerAligned: Bool = false) -> UIView {
        let bar = PillButtonBar(pillButtonStyle: .primary)
        bar.items = items
        
        // Default to "Inbox" (index 0) since we ensure Inbox is first in buildSamplePillBarData
        if !items.isEmpty {
            _ = bar.selectItem(atIndex: 0) // Default to Inbox
            // Update current selected project to the first item (usually "Inbox")
            self.currenttProjectForAddTaskView = items[0].title
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
            // Update current project based on pill selection
            print("Sample pill bar item selected: \(item.title) at index \(index)")
            self.currenttProjectForAddTaskView = item.title
            return
        }
        
        // Only handle sample pill bar - no project pill bar logic needed
        
        
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


