//
//  FluentUIToDoTableViewController.swift
//  To Do List
//
//  Created by AI Assistant
//  Copyright 2024 saransh1337. All rights reserved.
//

import UIKit
import FluentUI
import SemiModalViewController
import MaterialComponents.MaterialTextControls_FilledTextFields

// MARK: - FluentUIToDoTableViewController Delegate Protocol

protocol FluentUIToDoTableViewControllerDelegate: AnyObject {
    func fluentToDoTableViewControllerDidCompleteTask(_ controller: FluentUIToDoTableViewController, task: NTask)
    func fluentToDoTableViewControllerDidUpdateTask(_ controller: FluentUIToDoTableViewController, task: NTask)
    func fluentToDoTableViewControllerDidDeleteTask(_ controller: FluentUIToDoTableViewController, task: NTask)
}

// MARK: - FluentUIToDoTableViewController

class FluentUIToDoTableViewController: UITableViewController {
    
    // MARK: - Properties
    
    weak var delegate: FluentUIToDoTableViewControllerDelegate?
    private var toDoData: [(String, [NTask])] = []
    private var selectedDate: Date = Date.today()
    
    // Modal form elements - stored as instance variables for reliability
    private var currentModalTaskNameTextField: MDCFilledTextField?
    private var currentModalDescriptionTextField: MDCFilledTextField?
    private var currentModalProjectPillBar: UIView?
    private var currentModalPrioritySegmentedControl: SegmentedControl?
    private var currentModalTask: NTask?
    private var currentModalIndexPath: IndexPath?
    
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
        setupToDoData(for: selectedDate)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Force header background refresh to ensure transparency
        // This fixes the issue where headers show white background on first load
        DispatchQueue.main.async {
            self.refreshHeaderBackgrounds()
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Additional refresh after view appears to ensure proper styling
        refreshHeaderBackgrounds()
    }
    
    // MARK: - Setup Methods
    
    private func setupTableView() {
        // Register FluentUI cells and headers
        tableView.register(TableViewCell.self, forCellReuseIdentifier: TableViewCell.identifier)
        tableView.register(TableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: TableViewHeaderFooterView.identifier)
        
        // Configure table view appearance with transparent background
        tableView.backgroundColor = UIColor.clear
        tableView.separatorStyle = .singleLine
        tableView.sectionFooterHeight = 0
        
        // Set dynamic title based on selected date
        updateNavigationTitle(for: selectedDate)
    }
    
    private func setupToDoData(for date: Date) {
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
        
        // Update data and reload table view atomically on main thread
        DispatchQueue.main.async {
            self.toDoData = sections
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Public Methods
    
    func updateData(for date: Date) {
        selectedDate = date
        updateNavigationTitle(for: date)
        setupToDoData(for: date)
    }
    
    // MARK: - Private Methods
    
    private func updateNavigationTitle(for date: Date) {
        let calendar = Calendar.current
        let today = Date.today()
        
        if calendar.isDate(date, inSameDayAs: today) {
            title = "Today"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: -1, to: today)!) {
            title = "Yesterday"
        } else if calendar.isDate(date, inSameDayAs: calendar.date(byAdding: .day, value: 1, to: today)!) {
            title = "Tomorrow"
        } else {
            // Format as "Weekday, Ordinal" (e.g., "Friday, 13th" or "Monday, 3rd")
            let weekdayFormatter = DateFormatter()
            weekdayFormatter.dateFormat = "EEEE" // Full weekday name
            
            let dayFormatter = DateFormatter()
            dayFormatter.dateFormat = "d" // Day number
            
            let weekday = weekdayFormatter.string(from: date)
            let day = Int(dayFormatter.string(from: date)) ?? 1
            let ordinalDay = formatDayWithOrdinalSuffix(day)
            
            title = "\(weekday), \(ordinalDay)"
        }
    }
    
    // Helper method to add ordinal suffix to day numbers
    private func formatDayWithOrdinalSuffix(_ day: Int) -> String {
        let suffix: String
        
        switch day {
        case 11, 12, 13:
            suffix = "th" // Special cases for 11th, 12th, 13th
        default:
            switch day % 10 {
            case 1:
                suffix = "st"
            case 2:
                suffix = "nd"
            case 3:
                suffix = "rd"
            default:
                suffix = "th"
            }
        }
        
        return "\(day)\(suffix)"
    }
    
    func updateDataWithSearchResults(_ searchSections: [ToDoListData.Section]) {
        // Convert ToDoListData.Section to the format expected by toDoData
        var convertedSections: [(String, [NTask])] = []
        
        for section in searchSections {
            // For search results, we need to extract the actual NTask objects
            // Since search results don't contain the actual NTask objects, we need to find them
            var tasksForSection: [NTask] = []
            
            // Get all tasks and match them by name and details
            let allTasks = TaskManager.sharedInstance.getAllTasks
            
            for taskItem in section.items {
                if let matchingTask = allTasks.first(where: { task in
                    task.name == taskItem.TaskTitle && 
                    (task.taskDetails ?? "") == taskItem.text2
                }) {
                    tasksForSection.append(matchingTask)
                }
            }
            
            convertedSections.append((section.sectionTitle, tasksForSection))
        }
        
        // Update data and reload table view on main thread
        DispatchQueue.main.async {
            self.toDoData = convertedSections
            self.tableView.reloadData()
        }
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
        
        // Check if due date is today and make label empty
        let today = Date().startOfDay
        if dueDate.startOfDay == today {
            label.text = ""
        } else {
            label.text = dueDate.toTaskDisplayString()
        }
        
        // Configure label to be right-aligned and compress to fit text
        label.textAlignment = .right
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // Return label directly for both overdue and regular tasks
        
        return label
    }
    
    // MARK: - Visual Effects
    
    private func createFrostedGlassView() -> UIView {
        let clearView = UIView()
        clearView.backgroundColor = UIColor.clear
        
        // Ensure the view is completely transparent
        clearView.isOpaque = false
        clearView.alpha = 1.0
        
        return clearView
    }
    
    private func refreshHeaderBackgrounds() {
        // Force refresh of all visible header views to ensure transparent backgrounds
        for section in 0..<tableView.numberOfSections {
            if let headerView = tableView.headerView(forSection: section) as? TableViewHeaderFooterView {
                // Explicitly set the background to transparent
                headerView.backgroundView = createFrostedGlassView()
                
                // Also ensure the header view itself has no background
                headerView.backgroundColor = UIColor.clear
                
                // Force layout update
                headerView.setNeedsLayout()
                headerView.layoutIfNeeded()
            }
        }
    }
    
    private func createCheckBox(for task: NTask, at indexPath: IndexPath) -> UIButton {
        let checkBox = UIButton(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        
        // Configure checkbox appearance
        checkBox.layer.cornerRadius = 16 // Make it circular
        checkBox.layer.borderWidth = 1.5
        checkBox.layer.borderColor = ToDoColors().primaryColor.cgColor
        checkBox.backgroundColor = task.isComplete ? UIColor.clear : UIColor.clear
        
        // Set checkbox image based on completion state
        let checkmarkImage = UIImage(systemName: "checkmark")
        checkBox.setImage(task.isComplete ? checkmarkImage : nil, for: .normal)
        checkBox.tintColor = UIColor.white

        
        
        // Set tag for identification
        checkBox.tag = indexPath.section * 1000 + indexPath.row
        
        // Add target for tap action
        checkBox.addTarget(self, action: #selector(checkBoxTapped(_:)), for: .touchUpInside)
        
        return checkBox
    }
    
    @objc private func checkBoxTapped(_ sender: UIButton) {
        // Find the task based on the checkbox tag
        let section = sender.tag / 1000
        let row = sender.tag % 1000
        
        guard section < toDoData.count,
              row < toDoData[section].1.count else {
            return
        }
        
        let task = toDoData[section].1[row]
        
        // Toggle task completion status using central TaskManager helper so that
        // dateCompleted is always maintained correctly and notifications are posted
        TaskManager.sharedInstance.toggleTaskComplete(task: task)
        
        // Update checkbox appearance based on the new completion state
        updateCheckBoxAppearance(sender, isComplete: task.isComplete)
        
        // Notify delegate of task completion change
        delegate?.fluentToDoTableViewControllerDidCompleteTask(self, task: task)
        
        // Reconfigure cell to update appearance without position shift
        let indexPath = IndexPath(row: row, section: section)
        reconfigureCell(at: indexPath)
    }
    
    private func updateCheckBoxAppearance(_ checkBox: UIButton, isComplete: Bool) {
        UIView.animate(withDuration: 0.7) {
            checkBox.backgroundColor = isComplete ? UIColor.clear : UIColor.clear
            let checkmarkImage = UIImage(systemName: "checkmark")
            checkBox.setImage(isComplete ? checkmarkImage : nil, for: .normal)
        }
    }
}

// MARK: - Cell Configuration Helper

extension FluentUIToDoTableViewController {
    
    private func reconfigureCell(at indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) as? TableViewCell,
              let fluentTheme = view?.fluentTheme else { return }
        
        let sectionData = toDoData[indexPath.section]
        guard indexPath.row < sectionData.1.count else { return }
        
        let task = sectionData.1[indexPath.row]
        
        // Find existing checkbox instead of creating a new one
        var existingCheckBox: UIButton?
        if let accessoryView = cell.accessoryView {
            // Look for UIButton checkbox in the accessory view
            if let checkBox = accessoryView as? UIButton {
                existingCheckBox = checkBox
            } else {
                // Search in subviews if accessory view is a container
                for subview in accessoryView.subviews {
                    if let checkBox = subview as? UIButton {
                        existingCheckBox = checkBox
                        break
                    }
                }
            }
        }
        
        // Update existing checkbox state or create new one if not found
        let checkBox = existingCheckBox ?? createCheckBox(for: task, at: indexPath)
        updateCheckBoxAppearance(checkBox, isComplete: task.isComplete)
        
        // Configure cell based on completion status
        if task.isComplete {
            // Style for completed tasks
            let attributedTitle = NSAttributedString(
                string: task.name ?? "Untitled Task",
                attributes: [
                    .font: fluentTheme.typography(.body2),
                    .foregroundColor: fluentTheme.color(.foreground2),
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue
                ]
            )
            
            let attributedSubtitle = NSAttributedString(
                string: task.taskDetails ?? "Completed",
                attributes: [
                    .font: fluentTheme.typography(.caption2),
                    .foregroundColor: fluentTheme.color(.foreground3),
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue
                ]
            )
            
            cell.setup(
                attributedTitle: attributedTitle,
                attributedSubtitle: attributedSubtitle,
                customView: checkBox,
                accessoryType: .none
            )
            
        } else {
            // Style for active tasks
            let taskTitle = task.name ?? "Untitled Task"
            let taskSubtitle = task.taskDetails ?? "No details"
            
            let checkBox = createCheckBox(for: task, at: indexPath)
            
            cell.setup(
                title: taskTitle,
                subtitle: taskSubtitle,
                customView: checkBox,
                accessoryType: .none
            )
        }
        
        // Add accessory views (priority emoji removed)
        cell.subtitleTrailingAccessoryView = createDueDateAccessoryView(for: task)
        
        cell.backgroundColor = fluentTheme.color(.background1)
    }
}

// MARK: - UITableViewDataSource

extension FluentUIToDoTableViewController {
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return toDoData.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        let sectionData = toDoData[section]
        return max(sectionData.1.count, 1) // At least 1 row for empty state
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: TableViewCell.identifier) as? TableViewCell,
              let fluentTheme = view?.fluentTheme else {
            return UITableViewCell()
        }
        
        let sectionData = toDoData[indexPath.section]
        
        // Handle empty sections (placeholder)
        if sectionData.1.isEmpty {
            let emptyStateImageView = UIImageView(image: UIImage(systemName: "calendar.badge.plus"))
            emptyStateImageView.tintColor = fluentTheme.color(.foreground3)
            cell.setup(
                title: "No tasks due for this date",
                subtitle: "Add tasks to see them here",
                customView: emptyStateImageView,
                accessoryType: .none
            )
            
            // Style for empty state - Note: titleLabel and subtitleLabel are internal
            // Using alternative styling approach
            cell.backgroundColor = fluentTheme.color(.background1)
            cell.selectionStyle = .none
            
            return cell
        }
        
        // Ensure we don't access array out of bounds
        guard indexPath.row < sectionData.1.count else {
            // Return empty cell if somehow we get here
            return UITableViewCell()
        }
        let task = sectionData.1[indexPath.row]
        
        // Configure cell based on completion status
        if task.isComplete {
            // Style for completed tasks
            let attributedTitle = NSAttributedString(
                string: task.name ?? "Untitled Task",
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
            
            let checkBox = createCheckBox(for: task, at: indexPath)
            cell.setup(
                attributedTitle: attributedTitle,
                attributedSubtitle: attributedSubtitle,
                customView: checkBox,
                accessoryType: .none
            )
            
            // Note: customView is internal, using alternative approach
            cell.backgroundColor = fluentTheme.color(.background1)
            
        } else {
            // Style for active tasks
            let taskTitle = task.name ?? "Untitled Task"
            let taskSubtitle = task.taskDetails ?? "No details"
            
            let checkBox = createCheckBox(for: task, at: indexPath)
            
            cell.setup(
                title: taskTitle,
                subtitle: taskSubtitle,
                customView: checkBox,
                accessoryType: .none
            )
            
            // Note: customView is internal, priority colors will be handled through other means
            cell.backgroundColor = fluentTheme.color(.background1)
        }
        
        // Add accessory views (priority emoji removed)
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
//        cell.isUnreadDotVisible = isTaskOverdue(task) && !task.isComplete
        
        
        return cell
    }
}

// MARK: - UITableViewDelegate

extension FluentUIToDoTableViewController {
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        // Return consistent height for all cells
        return 50.0
    }
    
    override func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        // Return consistent estimated height for all cells
        return 50.0
    }
    
    override func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        guard let header = tableView.dequeueReusableHeaderFooterView(withIdentifier: TableViewHeaderFooterView.identifier) as? TableViewHeaderFooterView else {
            return nil
        }
        
        let sectionData = toDoData[section]
        let taskCount = sectionData.1.count
        
        // Create header title with task count
        let headerTitle = taskCount > 0 ? "\(sectionData.0) (\(taskCount))" : sectionData.0
        
        // Apply FluentUI typography title2 to header text
        if let fluentTheme = view?.fluentTheme {
            let attributedTitle = NSAttributedString(
                string: headerTitle,
                attributes: [
                    .font: fluentTheme.typography(.body1Strong),
                    .foregroundColor: fluentTheme.color(.foreground1)
                ]
            )
            
            header.setup(
                style: .header,
                attributedTitle: attributedTitle
            )
        } else {
            header.setup(
                style: .header,
                title: headerTitle
            )
        }
        
        header.tableViewCellStyle = .grouped
        
        // Apply transparent frosted glass effect to header
        header.backgroundView = createFrostedGlassView()
        
        // Explicitly ensure header background is transparent
        header.backgroundColor = UIColor.clear
        
        // Force immediate layout to prevent white flash
        header.setNeedsLayout()
        header.layoutIfNeeded()
        
        return header
    }
    
    // MARK: - Swipe Actions
    
    override func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let sectionData = toDoData[indexPath.section]
        
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
        
        // Delete action (left to right swipe)
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (action, view, completionHandler) in
            self?.deleteTask(task)
            completionHandler(true)
        }
        deleteAction.backgroundColor = UIColor.systemRed
        deleteAction.image = UIImage(systemName: "trash")
        actions.append(deleteAction)
        
        let configuration = UISwipeActionsConfiguration(actions: actions)
        configuration.performsFirstActionWithFullSwipe = false
        return configuration
    }
    
    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let sectionData = toDoData[indexPath.section]
        
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
        
        print("🔵 SEMI-MODAL APPROACH: FluentUIToDoTableViewController didSelectRowAt called")
        
        let sectionData = toDoData[indexPath.section]
        
        // Don't handle selection for empty sections
        guard !sectionData.1.isEmpty else { return }
        
        let task = sectionData.1[indexPath.row]
        
        print("🔵 SEMI-MODAL: About to present semi-modal for task: \(task.name ?? "Unknown")")
        
        // Create and present SemiModalView with task details
        presentTaskDetailSemiModal(for: task, at: indexPath)
    }
    
    // MARK: - Modal Presentation
    
    private func presentTaskDetailSemiModal(for task: NTask, at indexPath: IndexPath) {
        print("[DEBUG] === Starting presentTaskDetailSemiModal ===")
        print("[DEBUG] Task: \(task.name ?? "Unknown")")
        print("[DEBUG] IndexPath: section=\(indexPath.section), row=\(indexPath.row)")
        print("[DEBUG] Calculated tag: \(indexPath.section * 1000 + indexPath.row)")
        
        // Create a modal view controller
        let modalViewController = UIViewController()
        modalViewController.modalPresentationStyle = .pageSheet
        modalViewController.modalTransitionStyle = .coverVertical
        print("[DEBUG] Created modalViewController: \(modalViewController)")
        
        // Create a container view for the modal content
        let modalView = UIView()
        modalView.backgroundColor = .systemBackground
        modalView.translatesAutoresizingMaskIntoConstraints = false
        modalViewController.view.addSubview(modalView)
        print("[DEBUG] Created modalView: \(modalView)")
        print("[DEBUG] Added modalView to modalViewController.view")
        
        // Create scroll view for content
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        modalView.addSubview(scrollView)
        
        // Create main content stack view
        let mainStackView = UIStackView()
        mainStackView.axis = .vertical
        mainStackView.spacing = 0
        mainStackView.distribution = .fill
        mainStackView.alignment = .fill
        mainStackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(mainStackView)
        
        // Create text fields stack view with 30pt spacing
        let textFieldsStackView = UIStackView()
        textFieldsStackView.axis = .vertical
        textFieldsStackView.spacing = 30
        textFieldsStackView.distribution = .fill
        textFieldsStackView.alignment = .fill
        textFieldsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create bottom elements stack view with 20pt spacing
        let bottomElementsStackView = UIStackView()
        bottomElementsStackView.axis = .vertical
        bottomElementsStackView.spacing = 20
        bottomElementsStackView.distribution = .fill
        bottomElementsStackView.alignment = .fill
        bottomElementsStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Add drag indicator
        let dragIndicator = UIView()
        dragIndicator.backgroundColor = .systemGray3
        dragIndicator.layer.cornerRadius = 2
        dragIndicator.translatesAutoresizingMaskIntoConstraints = false
        modalView.addSubview(dragIndicator)
        
        // Task name text field (Material Design)
        let taskNameTextField = MDCFilledTextField()
        taskNameTextField.label.text = "Task"
        taskNameTextField.leadingAssistiveLabel.text = "Edit task"
        taskNameTextField.text = task.name
        taskNameTextField.clearButtonMode = .whileEditing
        taskNameTextField.backgroundColor = .clear
        taskNameTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Description text field (Material Design)
        let descriptionTextField = MDCFilledTextField()
        descriptionTextField.label.text = "Description (optional)"
        descriptionTextField.leadingAssistiveLabel.text = "Add task details"
        descriptionTextField.text = task.taskDetails ?? ""
        descriptionTextField.placeholder = "Enter task description..."
        descriptionTextField.clearButtonMode = .whileEditing
        descriptionTextField.backgroundColor = .clear
        descriptionTextField.translatesAutoresizingMaskIntoConstraints = false
        
        // Project pill bar
        let projectPillBar = createProjectPillBar(selectedProject: task.project ?? "Inbox")
        projectPillBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Priority selector (Segmented Control)
        let priorityItems = ["None", "Low", "High", "Highest"]
        let prioritySegmentedControl = SegmentedControl(items: priorityItems.map { SegmentItem(title: $0) })
        
        // Set selected priority based on task priority
        let priorityIndex: Int
        switch Int(task.taskPriority) {
        case 4: priorityIndex = 0 // None
        case 3: priorityIndex = 1 // Low
        case 2: priorityIndex = 2 // High
        case 1: priorityIndex = 3 // Highest
        default: priorityIndex = 1 // Default to Low
        }
        prioritySegmentedControl.selectedSegmentIndex = priorityIndex
        prioritySegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        
        // Action buttons container
        let buttonStackView = UIStackView()
        buttonStackView.axis = .horizontal
        buttonStackView.distribution = .fillEqually
        buttonStackView.spacing = 12
        buttonStackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Save button
        let saveButton = UIButton(type: .system)
        saveButton.setTitle("Save Changes", for: .normal)
        saveButton.backgroundColor = .systemBlue
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.layer.cornerRadius = 8
        saveButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        saveButton.addTarget(self, action: #selector(saveTaskChanges(_:)), for: .touchUpInside)
        saveButton.tag = indexPath.section * 1000 + indexPath.row
        
        // Complete/Incomplete button
        let toggleButton = UIButton(type: .system)
        toggleButton.setTitle(task.isComplete ? "Mark Incomplete" : "Mark Complete", for: .normal)
        toggleButton.backgroundColor = task.isComplete ? .systemOrange : .systemGreen
        toggleButton.setTitleColor(.white, for: .normal)
        toggleButton.layer.cornerRadius = 8
        toggleButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        toggleButton.addTarget(self, action: #selector(toggleTaskCompletion(_:)), for: .touchUpInside)
        toggleButton.tag = indexPath.section * 1000 + indexPath.row
        
        // Cancel button
        let cancelButton = UIButton(type: .system)
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.backgroundColor = .systemGray5
        cancelButton.setTitleColor(.label, for: .normal)
        cancelButton.layer.cornerRadius = 8
        cancelButton.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        cancelButton.addTarget(self, action: #selector(closeSemiModal), for: .touchUpInside)
        
        // Add buttons to button stack
        buttonStackView.addArrangedSubview(saveButton)
        buttonStackView.addArrangedSubview(toggleButton)
        
        // Add text fields to text fields stack view
        textFieldsStackView.addArrangedSubview(taskNameTextField)
        textFieldsStackView.addArrangedSubview(descriptionTextField)
        
        // Add remaining elements to bottom elements stack view
        bottomElementsStackView.addArrangedSubview(projectPillBar)
        bottomElementsStackView.addArrangedSubview(prioritySegmentedControl)
        bottomElementsStackView.addArrangedSubview(buttonStackView)
        bottomElementsStackView.addArrangedSubview(cancelButton)
        
        // Add both stack views to main stack view with custom spacing
        mainStackView.addArrangedSubview(textFieldsStackView)
        mainStackView.setCustomSpacing(30, after: textFieldsStackView)
        mainStackView.addArrangedSubview(bottomElementsStackView)
        
        // Set up constraints
        NSLayoutConstraint.activate([
            // Drag indicator
            dragIndicator.topAnchor.constraint(equalTo: modalView.topAnchor, constant: 8),
            dragIndicator.centerXAnchor.constraint(equalTo: modalView.centerXAnchor),
            dragIndicator.widthAnchor.constraint(equalToConstant: 36),
            dragIndicator.heightAnchor.constraint(equalToConstant: 4),
            
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: dragIndicator.bottomAnchor, constant: 20),
            scrollView.leadingAnchor.constraint(equalTo: modalView.leadingAnchor, constant: 20),
            scrollView.trailingAnchor.constraint(equalTo: modalView.trailingAnchor, constant: -20),
            scrollView.bottomAnchor.constraint(equalTo: modalView.bottomAnchor, constant: -20),
            
            // Main stack view
            mainStackView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            mainStackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            mainStackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            mainStackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            mainStackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Text field heights
            taskNameTextField.heightAnchor.constraint(equalToConstant: 56),
            descriptionTextField.heightAnchor.constraint(equalToConstant: 56),
            
            // Priority segmented control height
            prioritySegmentedControl.heightAnchor.constraint(equalToConstant: 44),
            
            // Button heights
            saveButton.heightAnchor.constraint(equalToConstant: 44),
            toggleButton.heightAnchor.constraint(equalToConstant: 44),
            cancelButton.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        // Store references for button actions
        modalView.tag = indexPath.section * 1000 + indexPath.row
        print("[DEBUG] Set modalView.tag to: \(modalView.tag)")
        
        // Store form elements as instance variables for reliable access
        self.currentModalTaskNameTextField = taskNameTextField
        self.currentModalDescriptionTextField = descriptionTextField
        self.currentModalProjectPillBar = projectPillBar
        self.currentModalPrioritySegmentedControl = prioritySegmentedControl
        self.currentModalTask = task
        self.currentModalIndexPath = indexPath
        print("[DEBUG] Stored form elements as instance variables:")
        print("[DEBUG] - taskNameTextField: \(taskNameTextField)")
        print("[DEBUG] - task: \(task.name ?? "nil")")
        print("[DEBUG] - indexPath: \(indexPath)")
        print("[DEBUG] - descriptionTextField: \(descriptionTextField)")
        print("[DEBUG] - projectPillBar: \(projectPillBar)")
        print("[DEBUG] - prioritySegmentedControl: \(prioritySegmentedControl)")
        
        // Set up modal view constraints
        NSLayoutConstraint.activate([
            modalView.topAnchor.constraint(equalTo: modalViewController.view.safeAreaLayoutGuide.topAnchor),
            modalView.leadingAnchor.constraint(equalTo: modalViewController.view.leadingAnchor),
            modalView.trailingAnchor.constraint(equalTo: modalViewController.view.trailingAnchor),
            modalView.bottomAnchor.constraint(equalTo: modalViewController.view.bottomAnchor)
        ])
        
        // Store the modal view controller for later access
        objc_setAssociatedObject(modalView, "modalViewController", modalViewController, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        
        // Present the modal
        present(modalViewController, animated: true) {
            print("Task detail modal presented")
        }
    }
    
    @objc private func toggleTaskCompletion(_ sender: UIButton) {
        let tag = sender.tag
        let sectionIndex = tag / 1000
        let rowIndex = tag % 1000
        
        guard sectionIndex < toDoData.count,
              rowIndex < toDoData[sectionIndex].1.count else { return }
        
        let task = toDoData[sectionIndex].1[rowIndex]
        
        // Use TaskManager helper so that dateCompleted is set/cleared correctly
        TaskManager.sharedInstance.toggleTaskComplete(task: task)
        
        // Notify delegate of task completion change
        delegate?.fluentToDoTableViewControllerDidCompleteTask(self, task: task)
        
        // Refresh data and UI
        setupToDoData(for: selectedDate)
        clearModalReferences()
        dismiss(animated: true)
    }
    
    @objc private func saveTaskChanges(_ sender: UIButton) {
        print("[DEBUG] === Starting saveTaskChanges ===")
        
        // Use instance variables instead of associated objects for reliability
        guard let taskNameTextField = currentModalTaskNameTextField,
              let descriptionTextField = currentModalDescriptionTextField,
              let prioritySegmentedControl = currentModalPrioritySegmentedControl,
              let projectPillBar = currentModalProjectPillBar,
              let task = currentModalTask else {
            print("[DEBUG] Could not find form elements - instance variables are nil")
            return
        }
        
        print("[DEBUG] All form elements found successfully from instance variables!")
        print("[DEBUG] Task: \(task.name ?? "Unknown")")
        
        // Update task with new values
        if let newName = taskNameTextField.text, !newName.isEmpty {
            task.name = newName
        }
        
        task.taskDetails = descriptionTextField.text
        
        // Update project based on pill bar selection
        if let pillBar = projectPillBar.subviews.first(where: { $0 is PillButtonBar }) as? PillButtonBar,
           let selectedItem = pillBar.selectedItem {
            task.project = selectedItem.title
        }
        
        // Update priority based on segmented control selection
        switch prioritySegmentedControl.selectedSegmentIndex {
        case 0: task.taskPriority = 4 // None
        case 1: task.taskPriority = 3 // Low
        case 2: task.taskPriority = 2 // High
        case 3: task.taskPriority = 1 // Highest
        default: task.taskPriority = 3 // Default to Low
        }
        
        // Save changes
        do {
            try task.managedObjectContext?.save()
            setupToDoData(for: selectedDate)
            clearModalReferences()
            dismiss(animated: true)
        } catch {
            print("Error saving task changes: \(error)")
        }
    }
    
    @objc private func closeSemiModal() {
        clearModalReferences()
        dismiss(animated: true)
    }
    
    private func clearModalReferences() {
        currentModalTaskNameTextField = nil
        currentModalDescriptionTextField = nil
        currentModalProjectPillBar = nil
        currentModalPrioritySegmentedControl = nil
        currentModalTask = nil
        currentModalIndexPath = nil
        print("[DEBUG] Cleared modal instance variables")
    }
    
    // MARK: - Project Pill Bar Helper Methods
    
    private func createProjectPillBar(selectedProject: String) -> UIView {
        let pillBarItems = buildProjectPillBarData()
        let bar = PillButtonBar(pillButtonStyle: .primary)
        bar.items = pillBarItems
        
        // Find and select the current project
        if let selectedIndex = pillBarItems.firstIndex(where: { $0.title == selectedProject }) {
            _ = bar.selectItem(atIndex: selectedIndex)
        } else {
            // Default to "Inbox" (index 0)
            if !pillBarItems.isEmpty {
                _ = bar.selectItem(atIndex: 0)
            }
        }
        
        bar.barDelegate = self
        bar.centerAligned = false
        
        let backgroundView = UIView()
        backgroundView.backgroundColor = .clear
        backgroundView.addSubview(bar)
        
        // Set up constraints for the pill bar
        bar.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: backgroundView.topAnchor, constant: 8),
            bar.leadingAnchor.constraint(equalTo: backgroundView.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: backgroundView.trailingAnchor),
            bar.bottomAnchor.constraint(lessThanOrEqualTo: backgroundView.bottomAnchor, constant: -8)
        ])
        
        return backgroundView
    }
    
    private func buildProjectPillBarData() -> [PillButtonBarItem] {
        var pillBarItems: [PillButtonBarItem] = []
        
        // Use actual project data from ProjectManager
        let allDisplayProjects = ProjectManager.sharedInstance.displayedProjects
        
        // Add all existing projects
        for project in allDisplayProjects {
            if let projectName = project.projectName {
                pillBarItems.append(PillButtonBarItem(title: projectName))
            }
        }
        
        // Ensure "Inbox" is present and positioned first if it exists
        let inboxTitle = ProjectManager.sharedInstance.defaultProject // "Inbox"
        
        // Remove any existing "Inbox" to avoid duplicates before re-inserting at correct position
        pillBarItems.removeAll(where: { $0.title.lowercased() == inboxTitle.lowercased() })
        
        // Insert "Inbox" at the beginning
        pillBarItems.insert(PillButtonBarItem(title: inboxTitle), at: 0)
        
        return pillBarItems
    }
    
    override func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    // MARK: - Task Actions
    
    private func markTaskComplete(_ task: NTask) {
        task.isComplete = true
        task.dateCompleted = Date() as NSDate  // Set completion date for scoring
        print("🎯 Task completed: '\(task.name ?? "Unknown")' at \(Date())")
        saveTask(task)
        delegate?.fluentToDoTableViewControllerDidCompleteTask(self, task: task)
        
        // Notify that charts should be refreshed
        NotificationCenter.default.post(name: NSNotification.Name("TaskCompletionChanged"), object: nil)
        print("📡 FluentUI: Posted TaskCompletionChanged notification")
    }
    
    private func markTaskIncomplete(_ task: NTask) {
        task.isComplete = false
        task.dateCompleted = nil  // Clear completion date when marking incomplete
        print("↩️ Task marked incomplete: '\(task.name ?? "Unknown")'")
        saveTask(task)
        delegate?.fluentToDoTableViewControllerDidCompleteTask(self, task: task)
        
        // Notify that charts should be refreshed
        NotificationCenter.default.post(name: NSNotification.Name("TaskCompletionChanged"), object: nil)
        print("📡 FluentUI: Posted TaskCompletionChanged notification")
    }
    
    private func deleteTask(_ task: NTask) {
        // Delete the task from Core Data context
        guard let context = task.managedObjectContext else {
            print("Error: Task has no managed object context")
            return
        }
        
        context.delete(task)
        
        do {
            try context.save()
            // Notify delegate before refreshing data
            delegate?.fluentToDoTableViewControllerDidDeleteTask(self, task: task)
            // Refresh the data to remove the deleted task from the view
            setupToDoData(for: selectedDate)
            
            // Update any charts or scoring calculations that depend on this task
            // The task deletion will automatically remove its score from daily calculations
            // since the task no longer exists in the data source
            
        } catch {
            print("Error deleting task: \(error)")
            // Show error alert
            let alert = UIAlertController(
                title: "Error",
                message: "Failed to delete task. Please try again.",
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
        }
    }
    
    @objc private func saveTaskToDatabase(_ sender: UIButton) {
        let tag = sender.tag
        let sectionIndex = tag / 1000
        let rowIndex = tag % 1000
        
        guard sectionIndex < toDoData.count,
              rowIndex < toDoData[sectionIndex].1.count else { return }
        
        let task = toDoData[sectionIndex].1[rowIndex]
        
        do {
            try task.managedObjectContext?.save()
            // Refresh the data and reload the specific cell
            setupToDoData(for: selectedDate)
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
    
    private func saveTask(_ task: NTask) {
        do {
            try task.managedObjectContext?.save()
            // Refresh the data
            setupToDoData(for: selectedDate)
        } catch {
            print("Error saving task: \(error)")
            // Show error alert
            let alert = UIAlertController(
                title: "Error",
                message: "Failed to save task. Please try again.",
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
        saveTask(task)
        
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
        let components = calendar.dateComponents([.weekday], from: today)
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
        let components = calendar.dateComponents([.weekday], from: today)
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

// MARK: - PillButtonBarDelegate

extension FluentUIToDoTableViewController: PillButtonBarDelegate {
    func pillBar(_ pillBar: PillButtonBar, didSelectItem item: PillButtonBarItem, atIndex index: Int) {
        print("Project pill bar item selected: \(item.title) at index \(index)")
        // Store the selected project for saving later
        // The project selection will be handled when the user taps "Save Changes"
    }
}

// MARK: - Date Extension

extension Date {
    static func today() -> Date {
        return Date()
    }
    
    // Note: startOfDay is already defined in DateUtils.swift
}
