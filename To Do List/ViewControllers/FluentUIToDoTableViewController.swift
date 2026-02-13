//
//  FluentUIToDoTableViewController.swift
//  To Do List
//
//  Created by AI Assistant
//  Copyright 2024 saransh1337. All rights reserved.
//

import UIKit
import SwiftUI
import FluentUI
import SemiModalViewController
import MaterialComponents.MaterialTextControls_FilledTextFields
import CoreData  // TODO: Migrate away from NSFetchRequest to use repository pattern

// MARK: - FluentUIToDoTableViewController Delegate Protocol

protocol FluentUIToDoTableViewControllerDelegate: AnyObject {
    func fluentToDoTableViewControllerDidCompleteTask(_ controller: FluentUIToDoTableViewController, task: NTask)
    func fluentToDoTableViewControllerDidUpdateTask(_ controller: FluentUIToDoTableViewController, task: NTask)
    func fluentToDoTableViewControllerDidDeleteTask(_ controller: FluentUIToDoTableViewController, task: NTask)
}

// MARK: - FluentUIToDoTableViewController

class FluentUIToDoTableViewController: UITableViewController {

    // MARK: - Properties

    /// Task repository for data access (Clean Architecture)
    var taskRepository: TaskRepository!

    /// ViewModel for reactive state (optional, for future migration)
    /// TODO: Re-enable when ViewModel is available
    // var viewModel: HomeViewModel?
    
    weak var delegate: FluentUIToDoTableViewControllerDelegate?
    private var toDoData: [(String, [NTask])] = []
    private var selectedDate: Date = Date.today()
    
    private var themeColors: TaskerColorTokens { TaskerThemeManager.shared.currentTheme.tokens.color }
    
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

        // TODO: Use repository once it has getTasksForDate method
        // For now, use direct CoreData access
        if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()

            // Fetch tasks for the selected date
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: date)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            request.predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@", startOfDay as NSDate, endOfDay as NSDate)
            request.sortDescriptors = [NSSortDescriptor(key: "taskPriority", ascending: true)]

            do {
                let allTasksForDate = try context.fetch(request)
                DispatchQueue.main.async { [weak self] in
                    print("📅 Found \(allTasksForDate.count) total tasks for \(date)")
                    print("🔍 [TABLE VIEW] Fetched tasks breakdown:")
                    for (index, task) in allTasksForDate.enumerated() {
                        print("  Task \(index + 1): '\(task.name ?? "NO NAME")' | dueDate: \(task.dueDate ?? NSDate()) | isComplete: \(task.isComplete)")
                    }

                    self?.processTasksForDisplay(allTasksForDate, date: date)
                }
            } catch {
                print("❌ Error fetching tasks: \(error)")
                DispatchQueue.main.async { [weak self] in
                    self?.processTasksForDisplay([], date: date)
                }
            }
        } else {
            print("❌ No context available")
            processTasksForDisplay([], date: date)
        }
    }

    /// Process fetched tasks and organize them for display
    private func processTasksForDisplay(_ allTasksForDate: [NTask], date: Date) {
        
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

    private func saveContext() {
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            return
        }

        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            print("Error saving Core Data context: \(error)")
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

            // TODO: Use repository once it has fetchAllTasks method
            // For now, use direct CoreData access
            if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
                let request: NSFetchRequest<NTask> = NTask.fetchRequest()

                do {
                    let allTasks = try context.fetch(request)
                    for taskItem in section.items {
                        if let matchingTask = allTasks.first(where: { task in
                            task.name == taskItem.TaskTitle &&
                            (task.taskDetails ?? "") == taskItem.text2
                        }) {
                            tasksForSection.append(matchingTask)
                        }
                    }
                } catch {
                    print("❌ Error fetching all tasks: \(error)")
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
        switch TaskPriority(rawValue: Int32(priority)) {
        case .max: return "🔴"
        case .high: return "🟠"
        case .low: return "🟢"
        case .none: return "⚪"
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
        checkBox.layer.borderColor = TaskerThemeManager.shared.currentTheme.tokens.color.taskCheckboxBorder.cgColor
        checkBox.backgroundColor = task.isComplete ? UIColor.clear : UIColor.clear
        
        // Set checkbox image based on completion state
        let checkmarkImage = UIImage(systemName: "checkmark")
        checkBox.setImage(task.isComplete ? checkmarkImage : nil, for: .normal)
        checkBox.tintColor = TaskerThemeManager.shared.currentTheme.tokens.color.accentOnPrimary

        
        
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
        
        // Toggle task completion status
        task.isComplete.toggle()
        task.dateCompleted = task.isComplete ? Date() as NSDate : nil
        saveContext()
        
        // Update checkbox appearance based on the new completion state
        updateCheckBoxAppearance(sender, isComplete: task.isComplete)
        
        // Notify delegate of task completion change
        delegate?.fluentToDoTableViewControllerDidCompleteTask(self, task: task)
        
        // Reconfigure cell to update appearance without position shift
        let indexPath = IndexPath(row: row, section: section)
        reconfigureCell(at: indexPath)
    }
    
    private func updateCheckBoxAppearance(_ checkBox: UIButton, isComplete: Bool) {
        if isComplete {
            // Bounce + checkmark draw animation + haptic
            TaskerHaptic.success()
            checkBox.transform = CGAffineTransform(scaleX: 0.7, y: 0.7)
            UIView.taskerSpringAnimate(TaskerAnimation.uiBouncy) {
                checkBox.transform = .identity
                checkBox.backgroundColor = UIColor.clear
                let checkmarkImage = UIImage(systemName: "checkmark")
                checkBox.setImage(checkmarkImage, for: .normal)
            }
        } else {
            TaskerHaptic.selection()
            UIView.taskerSpringAnimate(TaskerAnimation.uiSnappy) {
                checkBox.backgroundColor = UIColor.clear
                checkBox.setImage(nil, for: .normal)
            }
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
            let taskSubtitle = task.taskDetails ?? ""
            
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
            let taskSubtitle = task.taskDetails ?? ""
            
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

        // Set accessibility identifier for testing
        cell.accessibilityIdentifier = "home.taskCell.\(indexPath.section).\(indexPath.row)"

        // Staggered fade-in from bottom
        cell.alpha = 0
        cell.transform = CGAffineTransform(translationX: 0, y: 10)
        let delay = Double(indexPath.row) * TaskerAnimation.staggerInterval
        UIView.taskerSpringAnimate(TaskerAnimation.uiGentle, delay: delay) {
            cell.alpha = 1
            cell.transform = .identity
        }

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
        rescheduleAction.backgroundColor = themeColors.accentPrimary
        rescheduleAction.image = UIImage(systemName: "calendar")
        actions.append(rescheduleAction)
        
        // Delete action (left to right swipe)
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] (action, view, completionHandler) in
            // Use delegate pattern to notify parent controller
            guard let self = self else { return }
            self.delegate?.fluentToDoTableViewControllerDidDeleteTask(self, task: task)
            completionHandler(true)
        }
        deleteAction.backgroundColor = themeColors.statusDanger
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
                // Use delegate pattern to notify parent controller
                guard let self = self else { return }
                self.delegate?.fluentToDoTableViewControllerDidCompleteTask(self, task: task)
                completionHandler(true)
            }
            doneAction.backgroundColor = themeColors.statusSuccess
            doneAction.image = UIImage(systemName: "checkmark")
            actions.append(doneAction)
        } else {
            // Reopen action for completed tasks
            let reopenAction = UIContextualAction(style: .normal, title: "Reopen") { [weak self] (action, view, completionHandler) in
                // Use delegate pattern to notify parent controller
                guard let self = self else { return }
                self.delegate?.fluentToDoTableViewControllerDidCompleteTask(self, task: task)
                completionHandler(true)
            }
            reopenAction.backgroundColor = themeColors.statusWarning
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
    
    // MARK: - Task Detail Sheet Presentation

    private func presentTaskDetailSemiModal(for task: NTask, at indexPath: IndexPath) {
        let detailView = TaskDetailSheetView(
            task: task,
            projectNames: buildProjectChipData(),
            onSave: { [weak self] in
                guard let self else { return }
                self.setupToDoData(for: self.selectedDate)
                self.delegate?.fluentToDoTableViewControllerDidUpdateTask(self, task: task)
            },
            onToggleComplete: { [weak self] in
                guard let self else { return }
                try? task.managedObjectContext?.save()
                self.delegate?.fluentToDoTableViewControllerDidCompleteTask(self, task: task)
                self.setupToDoData(for: self.selectedDate)
            },
            onDismiss: nil,
            onDelete: nil
        )

        let hostingController = UIHostingController(rootView: detailView)
        hostingController.view.backgroundColor = TaskerThemeManager.shared.currentTheme.tokens.color.bgCanvas
        hostingController.modalPresentationStyle = UIModalPresentationStyle.pageSheet

        if let sheet = hostingController.sheetPresentationController {
            sheet.detents = [UISheetPresentationController.Detent.medium(), UISheetPresentationController.Detent.large()]
            sheet.preferredCornerRadius = TaskerThemeManager.shared.currentTheme.tokens.corner.modal
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }

        present(hostingController, animated: true)
    }


    // MARK: - Project Chip Helper Methods

    private func createProjectChipGroup(selectedProject: String) -> TaskerProjectChipGroupView {
        let projectNames = buildProjectChipData()
        return TaskerProjectChipGroupView(
            projectNames: projectNames,
            selectedProject: selectedProject
        )
    }

    private func buildProjectChipData() -> [String] {
        var projectNames: [String] = []

        // TODO: Use ViewModel/UseCaseCoordinator once Presentation/State folders are in target
        // For now, fetch projects directly from CoreData
        if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "projectName", ascending: true)]

            do {
                let projects = try context.fetch(request)
                for project in projects {
                    if let projectName = project.projectName {
                        projectNames.append(projectName)
                    }
                }
            } catch {
                print("❌ Error fetching projects: \(error)")
            }
        }

        // Ensure "Inbox" is present and positioned first if it exists
        let inboxTitle = "Inbox"

        // Remove any existing "Inbox" to avoid duplicates before re-inserting at correct position
        projectNames.removeAll(where: { $0.lowercased() == inboxTitle.lowercased() })

        // Insert "Inbox" at the beginning
        projectNames.insert(inboxTitle, at: 0)

        return projectNames
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
        
        // DIRECT CALL: Refresh charts immediately (more reliable than notification)
        if let homeVC = delegate as? HomeViewController {
            print("🔄 FluentUI: Calling HomeViewController chart refresh directly")
            homeVC.refreshChartsAfterTaskCompletion()
        }
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
        
        // DIRECT CALL: Refresh charts immediately (more reliable than notification)
        if let homeVC = delegate as? HomeViewController {
            print("🔄 FluentUI: Calling HomeViewController chart refresh directly")
            homeVC.refreshChartsAfterTaskCompletion()
        }
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
        let taskName = task.name ?? "Untitled Task"
        
        let alert = UIAlertController(
            title: "Task Rescheduled",
            message: "'\(taskName)' has been rescheduled to \(formatter.string(from: date))",
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
    private var themeColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }
    
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
        view.backgroundColor = themeColors.bgCanvas
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
        taskLabel.text = "Reschedule '\(task.name ?? "Untitled Task")'"
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
        button.backgroundColor = themeColors.accentPrimary
        button.setTitleColor(themeColors.accentOnPrimary, for: .normal)
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

// MARK: - Project Chip Group

private final class TaskerProjectChipGroupView: UIView {
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private var chips: [TaskerChipView] = []
    private let colors = TaskerThemeManager.shared.currentTheme.tokens.color

    private(set) var selectedTitle: String = "Inbox"

    init(projectNames: [String], selectedProject: String) {
        super.init(frame: .zero)
        selectedTitle = selectedProject
        setupUI(projectNames: projectNames)
        selectChip(named: selectedProject)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI(projectNames: [])
    }

    private func setupUI(projectNames: [String]) {
        backgroundColor = .clear

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.showsHorizontalScrollIndicator = false
        addSubview(scrollView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.spacing = TaskerThemeManager.shared.currentTheme.tokens.spacing.chipSpacing
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 8),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -8),
            stackView.heightAnchor.constraint(equalTo: scrollView.heightAnchor, constant: -16)
        ])

        for name in projectNames {
            let chip = TaskerChipView()
            chip.setTitle(name)
            chip.selectedStyle = .tinted
            chip.titleLabel.textColor = colors.textSecondary
            chip.addTarget(self, action: #selector(chipTapped(_:)), for: .touchUpInside)
            chips.append(chip)
            stackView.addArrangedSubview(chip)
        }
    }

    private func selectChip(named name: String) {
        if let matched = chips.first(where: { $0.titleLabel.text == name }) {
            updateSelection(for: matched)
            return
        }
        if let firstChip = chips.first {
            updateSelection(for: firstChip)
        }
    }

    @objc private func chipTapped(_ sender: TaskerChipView) {
        updateSelection(for: sender)
    }

    private func updateSelection(for selectedChip: TaskerChipView) {
        for chip in chips {
            chip.isSelected = chip === selectedChip
        }
        selectedTitle = selectedChip.titleLabel.text ?? "Inbox"
    }
}

// MARK: - Date Extension

extension Date {
    static func today() -> Date {
        return Date()
    }
    
    // Note: startOfDay is already defined in DateUtils.swift
}
