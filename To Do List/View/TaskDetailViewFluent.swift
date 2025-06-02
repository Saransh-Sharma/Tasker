import UIKit
import FluentUI // Ensure FluentUI is imported

// Delegate protocol to communicate changes back to the presenting controller
protocol TaskDetailViewFluentDelegate: AnyObject {
    func taskDetailViewFluentDidUpdateRequest(_ view: TaskDetailViewFluent, updatedTask: NTask)
    func taskDetailViewFluentDidRequestDatePicker(_ view: TaskDetailViewFluent, for task: NTask, currentValue: Date?)
    func taskDetailViewFluentDidRequestProjectPicker(_ view: TaskDetailViewFluent, for task: NTask, currentProject: Projects?, availableProjects: [Projects])
    func dismissFluentDetailView()
}

class TaskDetailViewFluent: UIView {

    weak var delegate: TaskDetailViewFluentDelegate?
    private var currentTask: NTask?
    private var availableProjects: [Projects] = []

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    // --- UI Elements ---
    // Title
    private let titleHeaderLabel = FluentUI.Label()
    private let titleTextField = FluentUI.FluentTextField()

    // Description
    private let descriptionHeaderLabel = FluentUI.Label()
    private let descriptionTextField = FluentUI.FluentTextField()

    // Due Date
    private let dueDateHeaderLabel = FluentUI.Label()
    private let dueDateButton = FluentUI.Button(style: .outline) // Using a standard style

    // Priority
    private let priorityHeaderLabel = FluentUI.Label()
    private let prioritySegmentedControl = FluentUI.SegmentedControl(items: [
        SegmentItem(title: "Low"),
        SegmentItem(title: "Medium"),
        SegmentItem(title: "High")
    ])
    // Priority mapping: NTask priority values (e.g., 4 for Low, 3 for Med, 2 for High)
    // Assuming your NTask stores priorities like P0=1 (Highest), P1=2 (High), P2=3 (Medium), P3=4 (Low)
    // SegmentedControl indices: Low (0), Medium (1), High (2)
    private let segmentedControlIndexToPriority: [Int: Int32] = [0: 4, 1: 3, 2: 2] // Maps Segment Index to NTask Priority
    private let priorityToSegmentedControlIndex: [Int32: Int] = [4: 0, 3: 1, 2: 2] // Maps NTask Priority to Segment Index


    // Project
    private let projectHeaderLabel = FluentUI.Label()
    private let projectButton = FluentUI.Button(style: .outlineNeutral) // Using a standard style

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
        self.backgroundColor = UIColor.systemGroupedBackground

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
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20), // Placeholder
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20), // Placeholder
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 16), // Placeholder
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -16), // Placeholder
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32) // Placeholder
        ])

        // Configure and add elements to stackView
        setupTitleField()
        setupDescriptionField()
        setupDueDateDisplay()
        setupPriorityControl()
        setupProjectDisplay()
        
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(spacer)
    }

    private func setupTitleField() {
        titleHeaderLabel.text = "TITLE"
        stackView.addArrangedSubview(titleHeaderLabel)
        
        titleTextField.placeholder = "Enter task title"
        titleTextField.onEditingChanged = { fluentTextField in
            guard let task = self.currentTask else { return }
            task.name = fluentTextField.inputText ?? ""
            self.delegate?.taskDetailViewFluentDidUpdateRequest(self, updatedTask: task)
        }
        stackView.addArrangedSubview(titleTextField)
        // Custom spacing applied in layoutSubviews or dynamically after elements are themed
    }

    private func setupDescriptionField() {
        descriptionHeaderLabel.text = "DESCRIPTION"
        stackView.addArrangedSubview(descriptionHeaderLabel)

        descriptionTextField.placeholder = "Enter task description"
        // Set multiline properties using our extension
        descriptionTextField.isMultiline = true
        descriptionTextField.maxNumberOfLines = 5
        descriptionTextField.onEditingChanged = { fluentTextField in
            guard let task = self.currentTask else { return }
            task.taskDetails = fluentTextField.inputText
            self.delegate?.taskDetailViewFluentDidUpdateRequest(self, updatedTask: task)
        }
        stackView.addArrangedSubview(descriptionTextField)
    }

    private func setupDueDateDisplay() {
        dueDateHeaderLabel.text = "DUE DATE"
        stackView.addArrangedSubview(dueDateHeaderLabel)

        dueDateButton.addTarget(self, action: #selector(didTapDueDateButton), for: .touchUpInside)
        stackView.addArrangedSubview(dueDateButton)
    }

    private func setupPriorityControl() {
        priorityHeaderLabel.text = "PRIORITY"
        stackView.addArrangedSubview(priorityHeaderLabel)
        
        prioritySegmentedControl.onSelectAction = { [weak self] (item, selectedIndex) in
            guard let self = self, let task = self.currentTask else { return }
            if let newPriority = self.segmentedControlIndexToPriority[selectedIndex] {
                 task.taskPriority = newPriority
                 self.delegate?.taskDetailViewFluentDidUpdateRequest(self, updatedTask: task)
            }
        }
        stackView.addArrangedSubview(prioritySegmentedControl)
    }

    private func setupProjectDisplay() {
        projectHeaderLabel.text = "PROJECT"
        stackView.addArrangedSubview(projectHeaderLabel)

        projectButton.addTarget(self, action: #selector(didTapProjectButton), for: .touchUpInside)
        stackView.addArrangedSubview(projectButton)
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
    public func configure(task: NTask, availableProjects: [Projects], delegate: TaskDetailViewFluentDelegate) {
        self.currentTask = task
        self.availableProjects = availableProjects
        self.delegate = delegate

        titleTextField.inputText = task.name
        descriptionTextField.inputText = task.taskDetails ?? ""
        
        updateDueDateButtonTitle(date: task.dueDate as Date?)
        updateProjectButtonTitle(project: task.project) // Pass the String name

        if let index = priorityToSegmentedControlIndex[task.taskPriority] {
            prioritySegmentedControl.selectedSegmentIndex = index
        } else {
            // Default to "Medium" (index 1) if priority is not in map (e.g. 0 or other undefined)
            prioritySegmentedControl.selectedSegmentIndex = 1
            // Optionally, update task.taskPriority to the default if it was invalid
            if let defaultPriority = segmentedControlIndexToPriority[1] {
                task.taskPriority = defaultPriority
            }
        }
        // Ensure view is laid out to apply theme before configuring sub-components that might depend on it
        self.setNeedsLayout()
        self.layoutIfNeeded()
    }
    
    // --- Public Update Methods (called by delegate callbacks) ---
    public func updateDueDateButtonTitle(date: Date?) {
        if let date = date {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            dueDateButton.setTitle(df.string(from: date), for: .normal)
        } else {
            dueDateButton.setTitle("Set Due Date", for: .normal)
        }
    }

    public func updateProjectButtonTitle(project: String?) {
        projectButton.setTitle(project ?? "Select Project", for: .normal)
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
}

/*
 class NTask { // Mock
    var name: String = ""
    var taskDetails: String?
    var dueDate: NSDate? // In CoreData, this is likely NSDate
    var taskPriority: Int32 = 3 // Default to Medium
    var project: Projects? // Relationship to Projects entity
 }

 class Projects { // Mock
    var projectName: String?
    var objectID: NSManagedObjectID? // For comparison
 }
*/
