import UIKit
import FluentUI // Ensure FluentUI is imported

// Delegate protocol to communicate changes back to the presenting controller
protocol TaskDetailViewFluentDelegate: AnyObject {
    func taskDetailViewFluentDidUpdateRequest(_ view: TaskDetailViewFluent, updatedTask: NTask)
    func taskDetailViewFluentDidRequestDatePicker(_ view: TaskDetailViewFluent, for task: NTask, currentValue: Date?)
    func taskDetailViewFluentDidRequestProjectPicker(_ view: TaskDetailViewFluent, for task: NTask, currentProject: Projects?, availableProjects: [Projects])
    func taskDetailViewFluentDidSave(_ view: TaskDetailViewFluent, savedTask: NTask)
    func dismissFluentDetailView()
}

class TaskDetailViewFluent: UIView, UITextViewDelegate {

    weak var delegate: TaskDetailViewFluentDelegate?
    private var currentTask: NTask?
    private var availableProjects: [Projects] = []
    private var taskRepository: TaskRepository?

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    // --- UI Elements ---
    // Title
    private let titleHeaderLabel = UILabel()
    private let titleTextField = UITextField()

    // Description
    private let descriptionHeaderLabel = UILabel()
    private let descriptionTextField = UITextView()

    // Due Date
    private let dueDateHeaderLabel = UILabel()
    private let dueDateButton = UIButton(type: .system)

    // Priority
    private let priorityHeaderLabel = UILabel()
    private let prioritySegmentOrder = TaskPriority.uiOrder
    private lazy var prioritySegmentedControl = UISegmentedControl(items: prioritySegmentOrder.map { $0.displayName })


    // Project
    private let projectHeaderLabel = UILabel()
    private let projectButton = UIButton(type: .system)
    
    // Save Button
    private let saveButton = UIButton(type: .system)
    
    // Track if changes have been made
    private var hasUnsavedChanges = false
    
    // Track current UI state
    private var currentDueDate: Date?
    private var currentProject: String?
    private var themeColors: TaskerColorTokens { TaskerThemeManager.shared.currentTheme.tokens.color }
    private var spacing: TaskerSpacingTokens { TaskerThemeManager.shared.currentTheme.tokens.spacing }
    private var corners: TaskerCornerTokens { TaskerThemeManager.shared.currentTheme.tokens.corner }

    // --- Initialization ---
    override init(frame: CGRect) {
        super.init(frame: frame)
        // Theme properties might not be fully available here if the view is not yet in a window.
        // Defer theme-dependent setup to layoutSubviews or didMoveToWindow if issues persist.
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        // Apply theme-dependent properties here if they weren't available during init
        // This ensures `self.fluentTheme` is accessible.
        self.backgroundColor = self.fluentTheme.color(.background2)
        self.layer.cornerRadius = self.fluentTheme.cornerRadius(.large)

        // Header Label Styling (done once)
        let headerLabels = [titleHeaderLabel, descriptionHeaderLabel, dueDateHeaderLabel, priorityHeaderLabel, projectHeaderLabel]
        for label in headerLabels {
            label.font = self.fluentTheme.typography(.caption1)
            label.textColor = self.fluentTheme.color(.foreground2) // Or another appropriate color token
        }
        
        // Spacing for stackView (can also be done here if theme access was an issue in init)
        stackView.spacing = self.fluentTheme.spacing(.medium)
        if let firstTopConstraint = stackView.constraints.first(where: { $0.firstAttribute == .top }) {
             firstTopConstraint.constant = self.fluentTheme.spacing(.large) // Using our extension
        }
        if let firstBottomConstraint = stackView.constraints.first(where: { $0.firstAttribute == .bottom }) {
             firstBottomConstraint.constant = -self.fluentTheme.spacing(.large) // Using our extension
        }
        // etc. for leading/trailing and custom spacings, or ensure stackView's layoutMargins use theme.
    }


    // --- UI Setup ---
    private func setupView() {
        // Initial background just in case theme is not ready, will be overridden in layoutSubviews
        self.backgroundColor = themeColors.bgCanvas

        // ScrollView
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: self.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: self.safeAreaLayoutGuide.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: self.safeAreaLayoutGuide.trailingAnchor)
        ])

        // StackView
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.alignment = .fill
        // stackView.spacing will be set in layoutSubviews
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            // Constants for spacing will be applied in layoutSubviews or dynamically
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: spacing.s20),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -spacing.s20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: spacing.screenHorizontal),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -spacing.screenHorizontal),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * spacing.screenHorizontal)
        ])

        // Configure and add elements to stackView
        setupTitleField()
        setupDescriptionField()
        setupDueDateDisplay()
        setupPriorityControl()
        setupProjectDisplay()
        setupSaveButton()
        
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(spacer)
    }

    private func setupTitleField() {
        titleHeaderLabel.text = "TITLE"
        stackView.addArrangedSubview(titleHeaderLabel)
        
        titleTextField.placeholder = "Enter task title"
        titleTextField.addTarget(self, action: #selector(titleTextFieldChanged(_:)), for: .editingChanged)
        stackView.addArrangedSubview(titleTextField)
        // Custom spacing applied in layoutSubviews or dynamically after elements are themed
    }

    private func setupDescriptionField() {
        descriptionHeaderLabel.text = "DESCRIPTION"
        stackView.addArrangedSubview(descriptionHeaderLabel)

        descriptionTextField.text = "Enter task description"
        descriptionTextField.font = UIFont.tasker.body
        descriptionTextField.layer.borderColor = themeColors.strokeHairline.cgColor
        descriptionTextField.layer.borderWidth = 1
        descriptionTextField.layer.cornerRadius = corners.input
        descriptionTextField.textContainerInset = UIEdgeInsets(top: spacing.s8, left: spacing.s8, bottom: spacing.s8, right: spacing.s8)
        descriptionTextField.delegate = self
        stackView.addArrangedSubview(descriptionTextField)
    }

    private func setupDueDateDisplay() {
        dueDateHeaderLabel.text = "DUE DATE"
        stackView.addArrangedSubview(dueDateHeaderLabel)

        dueDateButton.translatesAutoresizingMaskIntoConstraints = false
        dueDateButton.addTarget(self, action: #selector(didTapDueDateButton), for: .touchUpInside)
        dueDateButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        stackView.addArrangedSubview(dueDateButton)
    }

    private func setupPriorityControl() {
        priorityHeaderLabel.text = "PRIORITY"
        stackView.addArrangedSubview(priorityHeaderLabel)
        
        prioritySegmentedControl.addTarget(self, action: #selector(priorityChanged(_:)), for: .valueChanged)
        stackView.addArrangedSubview(prioritySegmentedControl)
    }

    private func setupProjectDisplay() {
        projectHeaderLabel.text = "PROJECT"
        stackView.addArrangedSubview(projectHeaderLabel)

        projectButton.translatesAutoresizingMaskIntoConstraints = false
        projectButton.addTarget(self, action: #selector(didTapProjectButton), for: .touchUpInside)
        projectButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        stackView.addArrangedSubview(projectButton)
    }
    
    private func setupSaveButton() {
        saveButton.translatesAutoresizingMaskIntoConstraints = false
        saveButton.setTitle("Save Changes", for: .normal)
        saveButton.addTarget(self, action: #selector(didTapSaveButton), for: .touchUpInside)
        saveButton.isEnabled = false // Initially disabled
        saveButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        stackView.addArrangedSubview(saveButton)
    }
    
    private func updateSaveButtonState() {
        saveButton.isEnabled = hasUnsavedChanges
        saveButton.setTitle(hasUnsavedChanges ? "Save Changes" : "No Changes", for: .normal)
    }
    
    // Dynamic spacing update after theming is applied
    private func updateStackViewSpacing() {
        guard stackView.arrangedSubviews.count > 0 else { return } // Ensure theme is available
        let xxxSmallSpacing = self.fluentTheme.spacing(.xxxSmall) // Using our extension
        let largeSpacing = self.fluentTheme.spacing(.large) // Using our extension

        stackView.setCustomSpacing(xxxSmallSpacing, after: titleHeaderLabel)
        stackView.setCustomSpacing(largeSpacing, after: titleTextField)
        stackView.setCustomSpacing(xxxSmallSpacing, after: descriptionHeaderLabel)
        stackView.setCustomSpacing(largeSpacing, after: descriptionTextField)
        stackView.setCustomSpacing(xxxSmallSpacing, after: dueDateHeaderLabel)
        stackView.setCustomSpacing(largeSpacing, after: dueDateButton)
        stackView.setCustomSpacing(xxxSmallSpacing, after: priorityHeaderLabel)
        stackView.setCustomSpacing(largeSpacing, after: prioritySegmentedControl)
        stackView.setCustomSpacing(xxxSmallSpacing, after: projectHeaderLabel)
        // No large spacing after projectButton as it's the last content item before spacer
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if self.window != nil {
            // Theme is now definitely available
            self.backgroundColor = self.fluentTheme.color(.background2)
            self.layer.cornerRadius = self.fluentTheme.cornerRadius(.large) // Using our extension
            
            // Update label styles
            let headerLabels = [titleHeaderLabel, descriptionHeaderLabel, dueDateHeaderLabel, priorityHeaderLabel, projectHeaderLabel]
            for label in headerLabels {
                label.font = self.fluentTheme.typography(.caption1)
                label.textColor = self.fluentTheme.color(.foreground2)
            }
            
            // Update stackview spacing
            stackView.spacing = self.fluentTheme.spacing(.medium) // Using our extension
            stackView.arrangedSubviews.first?.superview?.layoutMargins.top = self.fluentTheme.spacing(.large) // Using our extension // for top padding of stack
            stackView.arrangedSubviews.last?.superview?.layoutMargins.bottom = self.fluentTheme.spacing(.large) // Using our extension // for bottom padding of stack
            
            // Update constraints if they are placeholder values
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: self.fluentTheme.spacing(.medium)).isActive = true // Using our extension
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -self.fluentTheme.spacing(.medium)).isActive = true // Using our extension
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * self.fluentTheme.spacing(.medium)).isActive = true // Using our extension


            updateStackViewSpacing() // Update custom spacings
        }
    }


    // --- Configuration ---
    public func configure(task: NTask, availableProjects: [Projects], delegate: TaskDetailViewFluentDelegate, taskRepository: TaskRepository? = nil) {
        self.currentTask = task
        self.availableProjects = availableProjects
        self.delegate = delegate
        self.taskRepository = taskRepository
        
        // Reset unsaved changes flag
        self.hasUnsavedChanges = false
        updateSaveButtonState()
        
        // Initialize current UI state
        self.currentDueDate = task.dueDate as Date?
        self.currentProject = task.project

        titleTextField.text = task.name
        descriptionTextField.text = task.taskDetails ?? ""
        
        updateDueDateButtonTitle(date: task.dueDate as Date?)
        updateProjectButtonTitle(project: task.project) // Pass the String name

        let priority = TaskPriority(rawValue: task.taskPriority)
        prioritySegmentedControl.selectedSegmentIndex = priority.segmentIndex(order: prioritySegmentOrder)
        // Ensure view is laid out to apply theme before configuring sub-components that might depend on it
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
    
    // --- Public Update Methods (called by delegate callbacks) ---
    public func updateDueDateButtonTitle(date: Date?) {
        // Update the current due date
        self.currentDueDate = date
        
        if let date = date {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            dueDateButton.setTitle(df.string(from: date), for: .normal)
        } else {
            dueDateButton.setTitle("Set Due Date", for: .normal)
        }
        // Mark as changed if this is called after initial configuration
        if currentTask != nil {
            hasUnsavedChanges = true
            updateSaveButtonState()
        }
    }

    public func updateProjectButtonTitle(project: String?) {
        // Update the current project
        self.currentProject = project
        
        projectButton.setTitle(project ?? "Select Project", for: .normal)
        // Mark as changed if this is called after initial configuration
        if currentTask != nil {
            hasUnsavedChanges = true
            updateSaveButtonState()
        }
    }
    
    // --- Actions ---
    @objc private func didTapDueDateButton() {
        guard let task = currentTask else { return }
        delegate?.taskDetailViewFluentDidRequestDatePicker(self, for: task, currentValue: task.dueDate as Date?)
    }

    @objc private func didTapProjectButton() {
        guard let task = currentTask else { return }
        // Find the current Projects object based on the name string from task.project
        let currentProjectEntity = self.availableProjects.first(where: { $0.projectName == task.project })
        delegate?.taskDetailViewFluentDidRequestProjectPicker(self, for: task, currentProject: currentProjectEntity, availableProjects: self.availableProjects)
    }
    
    @objc private func didTapSaveButton() {
        guard let task = currentTask, hasUnsavedChanges else { return }
        
        // Update task directly using Core Data
        task.name = titleTextField.text ?? ""
        task.taskDetails = descriptionTextField.text
        
        // Update priority
        let selectedPriority = TaskPriority.fromSegmentIndex(prioritySegmentedControl.selectedSegmentIndex, order: prioritySegmentOrder)
        task.taskPriority = selectedPriority.rawValue
        
        // Update due date and project
        task.dueDate = (currentDueDate ?? Date()) as NSDate
        task.project = currentProject ?? "Inbox"
        
        // Reset the unsaved changes flag
        hasUnsavedChanges = false
        updateSaveButtonState()
        
        // Call the delegate to handle post-save actions
        delegate?.taskDetailViewFluentDidSave(self, savedTask: task)
    }
    
    private func saveContext() {
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            return
        }
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                print("Error saving context: \(error)")
            }
        }
    }
    
    // MARK: - Action Methods
    @objc private func titleTextFieldChanged(_ sender: UITextField) {
        guard currentTask != nil else { return }
        hasUnsavedChanges = true
        updateSaveButtonState()
    }
    
    @objc private func priorityChanged(_ sender: UISegmentedControl) {
        guard currentTask != nil else { return }
        hasUnsavedChanges = true
        updateSaveButtonState()
    }
    
    // MARK: - UITextViewDelegate
    func textViewDidChange(_ textView: UITextView) {
        guard currentTask != nil else { return }
        hasUnsavedChanges = true
        updateSaveButtonState()
    }
}

/*
 class NTask { // Mock
    var name: String = ""
    var taskDetails: String?
    var dueDate: NSDate? // In CoreData, this is likely NSDate
    var taskPriority: Int32 = TaskPriority.low.rawValue // Default to Low using enum
    var project: Projects? // Relationship to Projects entity
 }

 class Projects { // Mock
    var projectName: String?
    var objectID: NSManagedObjectID? // For comparison
 }
*/
