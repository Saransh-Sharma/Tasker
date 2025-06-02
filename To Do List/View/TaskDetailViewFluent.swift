import UIKit
import FluentUI // Ensure FluentUI is imported

// Delegate protocol to communicate changes back to the presenting controller
protocol TaskDetailViewFluentDelegate: AnyObject {
    func taskDetailViewFluentDidUpdateRequest(_ view: TaskDetailViewFluent, updatedTask: NTask) // For simplicity, pass back the whole task or individual fields
    func taskDetailViewFluentDidRequestDatePicker(_ view: TaskDetailViewFluent, for task: NTask, currentValue: Date?)
    func taskDetailViewFluentDidRequestProjectPicker(_ view: TaskDetailViewFluent, for task: NTask, currentProject: Projects?, availableProjects: [Projects])
    // Optional: func taskDetailViewFluentDidRequestDismiss(_ view: TaskDetailViewFluent)
}

class TaskDetailViewFluent: UIView {

    weak var delegate: TaskDetailViewFluentDelegate?
    private var currentTask: NTask?
    private var availableProjects: [Projects] = []

    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    // --- UI Elements ---
    // Title
    private let titleHeaderLabel = Label(style: .caption1, colorStyle: .secondary)
    private let titleTextField = TextField()

    // Description
    private let descriptionHeaderLabel = Label(style: .caption1, colorStyle: .secondary)
    private let descriptionTextField = TextField() // To be configured for multiline

    // Due Date
    private let dueDateHeaderLabel = Label(style: .caption1, colorStyle: .secondary)
    private let dueDateButton = Button(style: .outline) // Or use ListItemView

    // Priority
    private let priorityHeaderLabel = Label(style: .caption1, colorStyle: .secondary)
    private let prioritySegmentedControl = SegmentedControl(items: [
        SegmentItem(title: "Low"),
        SegmentItem(title: "Medium"),
        SegmentItem(title: "High")
        // Map these to priority values 4, 3, 2, 1 (or as defined in NTask)
    ])
    private let priorityMapping: [Int32] = [4, 3, 2, 1] // Example: Low(4) to Highest(1)

    // Project
    private let projectHeaderLabel = Label(style: .caption1, colorStyle: .secondary)
    private let projectButton = Button(style: .outline) // Or use ListItemView

    // --- Initialization ---
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // --- UI Setup ---
    private func setupView() {
        self.backgroundColor = FluentUITheme.shared.color(.background2)
        self.layer.cornerRadius = FluentUITheme.shared.cornerRadius(.large)
        // Consider adding FluentUI elevation/shadow if Card component isn't used directly

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
        stackView.spacing = FluentUITheme.shared.spacing(.medium)
        scrollView.addSubview(stackView)
        
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: FluentUITheme.shared.spacing(.large)),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -FluentUITheme.shared.spacing(.large)),
            stackView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: FluentUITheme.shared.spacing(.medium)),
            stackView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -FluentUITheme.shared.spacing(.medium)),
            stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * FluentUITheme.shared.spacing(.medium))
        ])

        // Configure and add elements to stackView
        setupTitleField()
        setupDescriptionField()
        setupDueDateDisplay()
        setupPriorityControl()
        setupProjectDisplay()
        
        // Add a spacer at the bottom if content is short, or rely on scroll view constraints
        let spacer = UIView()
        spacer.setContentHuggingPriority(.defaultLow, for: .vertical)
        stackView.addArrangedSubview(spacer)
    }

    private func setupTitleField() {
        titleHeaderLabel.text = "TITLE"
        stackView.addArrangedSubview(titleHeaderLabel)
        
        titleTextField.placeholder = "Enter task title"
        // titleTextField.tokenSet.replaceAllOverrides(with: perControlOverrideTextFieldTokens) // Optional: For custom theming like in demo
        titleTextField.onDidEndEditing = { [weak self] textField in
            guard let self = self, let task = self.currentTask else { return }
            task.name = textField.inputText ?? ""
            self.delegate?.taskDetailViewFluentDidUpdateRequest(self, updatedTask: task)
        }
        stackView.addArrangedSubview(titleTextField)
        stackView.setCustomSpacing(FluentUITheme.shared.spacing(.xxxSmall), after: titleHeaderLabel)
        stackView.setCustomSpacing(FluentUITheme.shared.spacing(.large), after: titleTextField)

    }

    private func setupDescriptionField() {
        descriptionHeaderLabel.text = "DESCRIPTION"
        stackView.addArrangedSubview(descriptionHeaderLabel)

        descriptionTextField.placeholder = "Enter task description"
        descriptionTextField.isMultiline = true
        descriptionTextField.maxNumberOfLines = 5
        // descriptionTextField.tokenSet.replaceAllOverrides(with: perControlOverrideTextFieldTokens) // Optional
         descriptionTextField.onDidEndEditing = { [weak self] textField in
            guard let self = self, let task = self.currentTask else { return }
            task.taskDetails = textField.inputText
            self.delegate?.taskDetailViewFluentDidUpdateRequest(self, updatedTask: task)
        }
        stackView.addArrangedSubview(descriptionTextField)
        stackView.setCustomSpacing(FluentUITheme.shared.spacing(.xxxSmall), after: descriptionHeaderLabel)
        stackView.setCustomSpacing(FluentUITheme.shared.spacing(.large), after: descriptionTextField)
    }

    private func setupDueDateDisplay() {
        dueDateHeaderLabel.text = "DUE DATE"
        stackView.addArrangedSubview(dueDateHeaderLabel)

        dueDateButton.addTarget(self, action: #selector(didTapDueDateButton), for: .touchUpInside)
        stackView.addArrangedSubview(dueDateButton)
        stackView.setCustomSpacing(FluentUITheme.shared.spacing(.xxxSmall), after: dueDateHeaderLabel)
        stackView.setCustomSpacing(FluentUITheme.shared.spacing(.large), after: dueDateButton)
    }

    private func setupPriorityControl() {
        priorityHeaderLabel.text = "PRIORITY"
        stackView.addArrangedSubview(priorityHeaderLabel)
        
        prioritySegmentedControl.onSelectAction = { [weak self] (item, selectedIndex) in
            guard let self = self, let task = self.currentTask else { return }
            let priorityMap = [0: Int32(4), 1: Int32(3), 2: Int32(2)] // Low, Medium, High
            if let newPriority = priorityMap[selectedIndex] {
                 task.taskPriority = newPriority
                 self.delegate?.taskDetailViewFluentDidUpdateRequest(self, updatedTask: task)
            }
        }
        stackView.addArrangedSubview(prioritySegmentedControl)
        stackView.setCustomSpacing(FluentUITheme.shared.spacing(.xxxSmall), after: priorityHeaderLabel)
        stackView.setCustomSpacing(FluentUITheme.shared.spacing(.large), after: prioritySegmentedControl)
    }

    private func setupProjectDisplay() {
        projectHeaderLabel.text = "PROJECT"
        stackView.addArrangedSubview(projectHeaderLabel)

        projectButton.addTarget(self, action: #selector(didTapProjectButton), for: .touchUpInside)
        stackView.addArrangedSubview(projectButton)
        stackView.setCustomSpacing(FluentUITheme.shared.spacing(.xxxSmall), after: projectHeaderLabel)
    }

    // --- Configuration ---
    public func configure(task: NTask, availableProjects: [Projects], delegate: TaskDetailViewFluentDelegate) {
        self.currentTask = task
        self.availableProjects = availableProjects
        self.delegate = delegate

        titleTextField.inputText = task.name
        descriptionTextField.inputText = task.taskDetails ?? ""
        
        updateDueDateButtonTitle(date: task.dueDate as Date?)
        updateProjectButtonTitle(project: task.project?.projectName) 

        let priorityMapFromValueToIndex = [Int32(4): 0, Int32(3): 1, Int32(2): 2]
        if let index = priorityMapFromValueToIndex[task.taskPriority] {
            prioritySegmentedControl.selectedSegmentIndex = index
        } else {
            prioritySegmentedControl.selectedSegmentIndex = 1
        }
    }
    
    // --- Public Update Methods (called by delegate callbacks) ---
    public func updateDueDateButtonTitle(date: Date?) {
        if let date = date {
            let df = DateFormatter()
            df.dateStyle = .medium
            df.timeStyle = .short
            dueDateButton.title = df.string(from: date)
        } else {
            dueDateButton.title = "Set Due Date"
        }
    }

    public func updateProjectButtonTitle(project: String?) { 
        projectButton.title = project ?? "Select Project"
    }
    
    // --- Actions ---
    @objc private func didTapDueDateButton() {
        guard let task = currentTask else { return }
        delegate?.taskDetailViewFluentDidRequestDatePicker(self, for: task, currentValue: task.dueDate as Date?)
    }

    @objc private func didTapProjectButton() {
        guard let task = currentTask else { return }
        delegate?.taskDetailViewFluentDidRequestProjectPicker(self, for: task, currentProject: task.project, availableProjects: self.availableProjects)
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
