//
//  FluentUISampleTableViewController.swift
//  To Do List
//
//  Created by AI Assistant
//  Copyright 2024 saransh1337. All rights reserved.
//

import UIKit
import FluentUI

// MARK: - FluentUISampleTableViewController

class FluentUISampleTableViewController: UITableViewController {
    
    // MARK: - Properties
    
    private var sampleData: [(String, [NTask])] = []
    private var selectedDate: Date = Date.today()
    
    // MARK: - Initialization
    
    override init(style: UITableView.Style) {
        super.init(style: .insetGrouped)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTableView()
        setupSampleData(for: selectedDate)
    }
    
    // MARK: - Setup Methods
    
    private func setupTableView() {
        // Register FluentUI cells and headers
        tableView.register(TableViewCell.self, forCellReuseIdentifier: TableViewCell.identifier)
        tableView.register(TableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: TableViewHeaderFooterView.identifier)
        
        // Configure table view appearance
        tableView.backgroundColor = TableViewCell.tableBackgroundGroupedColor
        tableView.separatorStyle = .none
        tableView.sectionFooterHeight = 0
        
        // Set title
        title = "Tasks Overview"
    }
    
    private func setupSampleData(for date: Date) {
        print("\n=== SETTING UP FLUENT UI SAMPLE TABLE VIEW FOR DATE: \(date) ===")
        
        // Get all tasks for the selected date
        let allTasksForDate = TaskManager.sharedInstance.getAllTasksForDate(date: date)
        
        print("📅 Found \(allTasksForDate.count) total tasks for \(date)")
        
        // Group tasks by project (case-insensitive)
        var tasksByProject: [String: [NTask]] = [:]
        let inboxProjectName = "inbox"
        
        for task in allTasksForDate {
            let projectName = (task.project?.lowercased() ?? inboxProjectName)
            if tasksByProject[projectName] == nil {
                tasksByProject[projectName] = []
            }
            tasksByProject[projectName]?.append(task)
        }
        
        // Sort project names (excluding inbox)
        let sortedProjects = tasksByProject.keys.filter { $0 != inboxProjectName }.sorted()
        
        // Helper function to create sorted task items
        func createSortedTasks(from tasks: [NTask]) -> [NTask] {
            return tasks.sorted { task1, task2 in
                // First sort by priority (higher priority first)
                if task1.taskPriority != task2.taskPriority {
                    return task1.taskPriority > task2.taskPriority
                }
                
                // If priorities are equal, sort by due date (earlier dates first)
                guard let date1 = task1.dueDate as Date?, let date2 = task2.dueDate as Date? else {
                    return task1.dueDate != nil
                }
                return date1 < date2
            }
        }
        
        // Create sections based on task data
        var sections: [(String, [NTask])] = []
        
        // First add Inbox section if it has tasks
        if let inboxTasks = tasksByProject[inboxProjectName], !inboxTasks.isEmpty {
            let sortedInboxTasks = createSortedTasks(from: inboxTasks)
            sections.append(("📥 Inbox", sortedInboxTasks))
            print("FluentUI SampleTableView: Added Inbox section with \(sortedInboxTasks.count) tasks")
        }
        
        // Then add other project sections
        for projectName in sortedProjects {
            guard let projectTasks = tasksByProject[projectName], !projectTasks.isEmpty else { continue }
            let displayName = "📁 \(projectName.capitalized)"
            let sortedProjectTasks = createSortedTasks(from: projectTasks)
            sections.append((displayName, sortedProjectTasks))
            print("FluentUI SampleTableView: Added \(displayName) section with \(sortedProjectTasks.count) tasks")
        }
        
        // If no tasks, show a placeholder with empty task array
        if sections.isEmpty {
            sections.append(("📅 No Tasks for \(formatDate(date))", []))
        }
        
        print("\nFluentUI SampleTableView sections summary:")
        for (index, section) in sections.enumerated() {
            print("Section \(index): '\(section.0)' with \(section.1.count) tasks")
        }
        print("=== END FLUENT UI SAMPLE TABLE VIEW SETUP ===")
        
        self.sampleData = sections
        
        // Reload table view
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Public Methods
    
    func updateData(for date: Date) {
        selectedDate = date
        setupSampleData(for: date)
    }
    
    // MARK: - Helper Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func getPriorityIcon(for priority: Int) -> String {
        switch priority {
        case 1: return "🔴" // P0 - Highest
        case 2: return "🟠" // P1 - High
        case 3: return "🟡" // P2 - Medium
        case 4: return "🟢" // P3 - Low
        default: return "⚪" // Unknown
        }
    }
    
    private func isTaskOverdue(_ task: NTask) -> Bool {
        guard let dueDate = task.dueDate as Date?, !task.isComplete else { return false }
        let today = Date().startOfDay
        return dueDate < today
    }
    
    private func createPriorityAccessoryView(for task: NTask) -> UIView? {
        let priorityIcon = getPriorityIcon(for: Int(task.taskPriority))
        let label = Label(textStyle: .caption1, colorStyle: .secondary)
        label.text = priorityIcon
        return label
    }
    
    private func createDueDateAccessoryView(for task: NTask) -> UIView? {
        guard let dueDate = task.dueDate as Date? else { return nil }
        
        let label = Label(textStyle: .caption2, colorStyle: isTaskOverdue(task) ? .error : .secondary)
        label.text = dueDate.toTaskDisplayString()
        
        if isTaskOverdue(task) {
            // Add border for overdue tasks
            let container = UIView()
            container.layer.borderWidth = 1.0
            container.layer.borderColor = UIColor.systemRed.cgColor
            container.layer.cornerRadius = 4
            container.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
            
            label.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: container.topAnchor, constant: 2),
                label.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -2),
                label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4)
            ])
            
            return container
        }
        
        return label
    }
    
    private func createCompletionAccessoryView(for task: NTask) -> UIView? {
        if task.isComplete {
            let imageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
            imageView.tintColor = UIColor.systemGreen
            imageView.contentMode = .scaleAspectFit
            return imageView
        }
        return nil
    }
}

// MARK: - UITableViewDataSource

extension FluentUISampleTableViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return sampleData.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionData = sampleData[section]
        return max(sectionData.1.count, 1) // At least 1 row for empty state
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier) as? TableViewCell,
              let fluentTheme = view?.fluentTheme else {
            return UITableViewCell()
        }
        
        let sectionData = sampleData[indexPath.section]
        
        // Handle empty sections (placeholder)
        if sectionData.1.isEmpty {
            cell.setup(
                title: "No tasks due for this date",
                subtitle: "Add tasks to see them here",
                customView: UIImageView(image: UIImage(systemName: "calendar.badge.plus")),
                accessoryType: .none
            )
            
            // Style for empty state - Note: titleLabel and subtitleLabel are internal
            // Using alternative styling approach
            cell.backgroundColor = fluentTheme.color(.background1)
            cell.selectionStyle = .none
            
            return cell
        }
        
        let task = sectionData.1[indexPath.row]
        let priorityIcon = getPriorityIcon(for: Int(task.taskPriority))
        
        // Configure cell based on completion status
        if task.isComplete {
            // Style for completed tasks
            let attributedTitle = NSAttributedString(
                string: "\(priorityIcon) \(task.name)",
                attributes: [
                    .font: fluentTheme.typography(.body1),
                    .foregroundColor: fluentTheme.color(.foreground2),
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue
                ]
            )
            
            let attributedSubtitle = NSAttributedString(
                string: task.taskDetails ?? "Completed",
                attributes: [
                    .font: fluentTheme.typography(.caption1),
                    .foregroundColor: fluentTheme.color(.foreground3),
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue
                ]
            )
            
            cell.setup(
                attributedTitle: attributedTitle,
                attributedSubtitle: attributedSubtitle,
                customView: UIImageView(image: UIImage(systemName: "checkmark.circle.fill")),
                accessoryType: .none
            )
            
            // Note: customView is internal, using alternative approach
            cell.backgroundColor = fluentTheme.color(.background1)
            
        } else {
            // Style for active tasks
            let taskTitle = "\(priorityIcon) \(task.name)"
            let taskSubtitle = task.taskDetails ?? "No details"
            
            cell.setup(
                title: taskTitle,
                subtitle: taskSubtitle,
                customView: UIImageView(image: UIImage(systemName: "circle")),
                accessoryType: .disclosureIndicator
            )
            
            // Note: customView is internal, priority colors will be handled through other means
            cell.backgroundColor = fluentTheme.color(.background1)
        }
        
        // Add accessory views
        cell.titleTrailingAccessoryView = createPriorityAccessoryView(for: task)
        cell.subtitleTrailingAccessoryView = createDueDateAccessoryView(for: task)
        
        // Configure cell appearance
        cell.backgroundStyleType = .grouped
        cell.topSeparatorType = indexPath.row == 0 ? .full : .none
        
        if indexPath.row == tableView.numberOfRows(inSection: indexPath.section) - 1 {
            cell.bottomSeparatorType = .none
        } else {
            cell.bottomSeparatorType = .inset
        }
        
        // Add unread dot for overdue tasks
        cell.isUnreadDotVisible = isTaskOverdue(task) && !task.isComplete
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension FluentUISampleTableViewController {
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: TableViewHeaderFooterView.identifier) as? TableViewHeaderFooterView else {
            return nil
        }
        
        let sectionData = sampleData[section]
        let taskCount = sectionData.1.count
        
        // Create header title with task count
        let headerTitle = taskCount > 0 ? "\(sectionData.0) (\(taskCount))" : sectionData.0
        
        header.setup(
            style: .header,
            title: headerTitle
        )
        
        header.tableViewCellStyle = .grouped
        
        return header
    }
    
    // MARK: - Swipe Actions
    
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let sectionData = sampleData[indexPath.section]
        
        // Don't show swipe actions for empty sections
        guard !sectionData.1.isEmpty else { return nil }
        
        let task = sectionData.1[indexPath.row]
        
        var actions: [UIContextualAction] = []
        
        // Reschedule action (left to right swipe)
        let rescheduleAction = UIContextualAction(style: .normal, title: "Reschedule") { [weak self] (action, view, completionHandler) in
            self?.showRescheduleOptions(for: task)
            completionHandler(true)
        }
        rescheduleAction.backgroundColor = UIColor.systemBlue
        rescheduleAction.image = UIImage(systemName: "calendar")
        actions.append(rescheduleAction)
        
        // Done action (left to right swipe)
        if !task.isComplete {
            let doneAction = UIContextualAction(style: .normal, title: "Done") { [weak self] (action, view, completionHandler) in
                self?.markTaskComplete(task)
                completionHandler(true)
            }
            doneAction.backgroundColor = UIColor.systemGreen
            doneAction.image = UIImage(systemName: "checkmark")
            actions.append(doneAction)
        }
        
        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let sectionData = sampleData[indexPath.section]
        
        // Don't show swipe actions for empty sections
        guard !sectionData.1.isEmpty else { return nil }
        
        let task = sectionData.1[indexPath.row]
        
        var actions: [UIContextualAction] = []
        
        // Done action (right to left swipe)
        if !task.isComplete {
            let doneAction = UIContextualAction(style: .normal, title: "Done") { [weak self] (action, view, completionHandler) in
                self?.markTaskComplete(task)
                completionHandler(true)
            }
            doneAction.backgroundColor = UIColor.systemGreen
            doneAction.image = UIImage(systemName: "checkmark")
            actions.append(doneAction)
        } else {
            // Reopen action for completed tasks
            let reopenAction = UIContextualAction(style: .normal, title: "Reopen") { [weak self] (action, view, completionHandler) in
                self?.markTaskIncomplete(task)
                completionHandler(true)
            }
            reopenAction.backgroundColor = UIColor.systemOrange
            reopenAction.image = UIImage(systemName: "arrow.counterclockwise")
            actions.append(reopenAction)
        }
        
        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = true
        return configuration
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let sectionData = sampleData[indexPath.section]
        
        // Don't handle selection for empty sections
        guard !sectionData.1.isEmpty else { return }
        
        let task = sectionData.1[indexPath.row]
        
        // Show task details or toggle completion
        let alert = UIAlertController(
            title: task.name,
            message: "\(task.taskDetails ?? "No details")\n\nDue: \((task.dueDate as Date?)?.toTaskDisplayString() ?? "No due date")\nPriority: \(getPriorityIcon(for: Int(task.taskPriority)))",
            preferredStyle: .alert
        )
        
        // Add toggle completion action
        let toggleAction = UIAlertAction(
            title: task.isComplete ? "Mark as Incomplete" : "Mark as Complete",
            style: .default
        ) { _ in
            // Toggle task completion
            task.isComplete.toggle()
            
            // Save the context
            do {
                try task.managedObjectContext?.save()
                // Refresh the data
                self.setupSampleData(for: self.selectedDate)
            } catch {
                print("Error saving task completion: \(error)")
            }
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(toggleAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    // MARK: - Task Actions
    
    private func markTaskComplete(_ task: NTask) {
        task.isComplete = true
        saveTaskChanges(task)
    }
    
    private func markTaskIncomplete(_ task: NTask) {
        task.isComplete = false
        saveTaskChanges(task)
    }
    
    private func saveTaskChanges(_ task: NTask) {
        do {
            try task.managedObjectContext?.save()
            // Refresh the data and reload the specific cell
            setupSampleData(for: selectedDate)
        } catch {
            print("Error saving task changes: \(error)")
            // Show error alert
            let alert = UIAlertController(
                title: "Error",
                message: "Failed to save task changes. Please try again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    private func showRescheduleOptions(for task: NTask) {
        let rescheduleVC = RescheduleViewController(task: task) { [weak self] selectedDate in
            self?.rescheduleTask(task, to: selectedDate)
        }
        
        let navController = UINavigationController(rootViewController: rescheduleVC)
        navController.modalPresentationStyle = .pageSheet
        
        // For iPad support
        if let popover = navController.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(navController, animated: true)
    }
    
    private func showCustomDatePicker(for task: NTask) {
        let alert = UIAlertController(
            title: "Select Custom Date",
            message: "\n\n\n\n\n\n\n\n", // Space for date picker
            preferredStyle: .alert
        )
        
        let datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.minimumDate = Date()
        
        // Set initial date to current due date or tomorrow
        if let currentDueDate = task.dueDate as Date? {
            datePicker.date = currentDueDate
        } else {
            datePicker.date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }
        
        alert.setValue(datePicker, forKey: "contentViewController")
        
        let selectAction = UIAlertAction(title: "Reschedule", style: .default) { [weak self] _ in
            self?.rescheduleTask(task, to: datePicker.date)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(selectAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func rescheduleTask(_ task: NTask, to date: Date) {
        task.dueDate = date as NSDate
        saveTaskChanges(task)
        
        // Show confirmation
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        let alert = UIAlertController(
            title: "Task Rescheduled",
            message: "'\(task.name)' has been rescheduled to \(formatter.string(from: date))",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func getNextMonday() -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        // Find next Monday
        var components = calendar.dateComponents([.weekday], from: today)
        let daysUntilMonday = (9 - (components.weekday ?? 1)) % 7
        let daysToAdd = daysUntilMonday == 0 ? 7 : daysUntilMonday // If today is Monday, go to next Monday
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: today) ?? today
    }
}

// MARK: - RescheduleViewController

class RescheduleViewController: UIViewController {
    private let task: NTask
    private let onDateSelected: (Date) -> Void
    private var datePicker: UIDatePicker!
    
    init(task: NTask, onDateSelected: @escaping (Date) -> Void) {
        self.task = task
        self.onDateSelected = onDateSelected
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        title = "Reschedule Task"
        
        // Navigation bar buttons
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Done",
            style: .done,
            target: self,
            action: #selector(doneTapped)
        )
        
        // Main stack view
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stackView)
        
        // Task name label
        let taskLabel = UILabel()
        taskLabel.text = "Reschedule '\(task.name)'"
        taskLabel.font = .systemFont(ofSize: 18, weight: .medium)
        taskLabel.textAlignment = .center
        taskLabel.numberOfLines = 0
        stackView.addArrangedSubview(taskLabel)
        
        // Quick options section
        let quickOptionsLabel = UILabel()
        quickOptionsLabel.text = "Quick Options"
        quickOptionsLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        quickOptionsLabel.textColor = .secondaryLabel
        stackView.addArrangedSubview(quickOptionsLabel)
        
        // Quick option buttons
        let buttonStackView = UIStackView()
        buttonStackView.axis = .vertical
        buttonStackView.spacing = 12
        buttonStackView.distribution = .fillEqually
        
        let tomorrowButton = createQuickOptionButton(title: "Tomorrow") {
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
            self.selectDate(tomorrow)
        }
        
        let dayAfterButton = createQuickOptionButton(title: "Day After Tomorrow") {
            let dayAfter = Calendar.current.date(byAdding: .day, value: 2, to: Date()) ?? Date()
            self.selectDate(dayAfter)
        }
        
        let nextWeekButton = createQuickOptionButton(title: "Next Week") {
            let nextMonday = self.getNextMonday()
            self.selectDate(nextMonday)
        }
        
        buttonStackView.addArrangedSubview(tomorrowButton)
        buttonStackView.addArrangedSubview(dayAfterButton)
        buttonStackView.addArrangedSubview(nextWeekButton)
        
        stackView.addArrangedSubview(buttonStackView)
        
        // Custom date section
        let customDateLabel = UILabel()
        customDateLabel.text = "Or Choose Custom Date"
        customDateLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        customDateLabel.textColor = .secondaryLabel
        stackView.addArrangedSubview(customDateLabel)
        
        // Date picker
        datePicker = UIDatePicker()
        datePicker.datePickerMode = .dateAndTime
        datePicker.preferredDatePickerStyle = .wheels
        datePicker.minimumDate = Date()
        
        // Set initial date to current due date or tomorrow
        if let currentDueDate = task.dueDate as Date? {
            datePicker.date = currentDueDate
        } else {
            datePicker.date = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()
        }
        
        stackView.addArrangedSubview(datePicker)
        
        // Constraints
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20)
        ])
    }
    
    private func createQuickOptionButton(title: String, action: @escaping () -> Void) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = .systemBlue
        button.setTitleColor(.white, for: .normal)
        button.layer.cornerRadius = 8
        button.heightAnchor.constraint(equalToConstant: 44).isActive = true
        
        button.addAction(UIAction { _ in action() }, for: .touchUpInside)
        
        return button
    }
    
    private func selectDate(_ date: Date) {
        onDateSelected(date)
        dismiss(animated: true)
    }
    
    private func getNextMonday() -> Date {
        let calendar = Calendar.current
        let today = Date()
        
        // Find next Monday
        var components = calendar.dateComponents([.weekday], from: today)
        let daysUntilMonday = (9 - (components.weekday ?? 1)) % 7
        let daysToAdd = daysUntilMonday == 0 ? 7 : daysUntilMonday // If today is Monday, go to next Monday
        
        return calendar.date(byAdding: .day, value: daysToAdd, to: today) ?? today
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func doneTapped() {
        selectDate(datePicker.date)
    }
}

// MARK: - Date Extension

extension Date {
    static func today() -> Date {
        return Date()
    }
    
    // Note: startOfDay is already defined in DateUtils.swift
}