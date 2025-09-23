//
//  HomeViewController+ProjectFiltering.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import CoreData

extension HomeViewController {
    
    // Method to set the project value for filtering
    func setProjectForViewValue(projectName: String) {
        projectForTheView = projectName
    }
    
    // Method to set the date value for filtering
    func setDateForViewValue(dateToSetForView: Date) {
        dateForTheView = dateToSetForView
    }
    
    // Method to calculate today's score (synchronous, main-context)
    // Returns the total score for tasks whose *completion* date is the same as `dateForTheView`.
    // This is used for instant UI updates right after a checkbox tap.
    func calculateTodaysScore() -> Int {
        let targetDate = dateForTheView
        let calendar = Calendar.current
        // Use direct Core Data access instead of TaskManager
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        let allTasks = (try? context?.fetch(request)) ?? []
        let completedToday = allTasks.filter { task in
            guard task.isComplete, let doneDate = task.dateCompleted as Date? else { return false }
            return calendar.isDate(doneDate, inSameDayAs: targetDate)
        }
        return completedToday.reduce(0) { partial, task in
            partial + TaskScoringService.shared.calculateScore(for: task)
        }
    }
    
    /// Async version of calculateTodaysScore that uses the repository pattern
    func calculateTodaysScore(completion: @escaping (Int) -> Void) {
        var morningCompletedCount = 0
        var eveningCompletedCount = 0
        let group = DispatchGroup()
        
        group.enter()
        taskRepository.getMorningTasks(for: dateForTheView) { tasks in
            morningCompletedCount = tasks.filter { $0.isComplete }.count
            group.leave()
        }
        
        group.enter()
        taskRepository.getEveningTasks(for: dateForTheView) { tasks in
            eveningCompletedCount = tasks.filter { $0.isComplete }.count
            group.leave()
        }
        
        group.notify(queue: .main) {
            completion(morningCompletedCount + eveningCompletedCount)
        }
    }
    
    // Note: updateHomeDateLabel is implemented elsewhere
    
    func prepareAndFetchTasksForProjectGroupedView() {
        self.projectsToDisplayAsSections.removeAll()
        self.tasksGroupedByProject.removeAll()

        let projectsToFilter: [Projects]
        
        // Use direct Core Data access instead of migration adapters
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let projectRequest: NSFetchRequest<Projects> = Projects.fetchRequest()
        let allProjects = (try? context?.fetch(projectRequest)) ?? []
        
        switch currentViewType {
            case .allProjectsGrouped:
                projectsToFilter = allProjects
            case .selectedProjectsGrouped:
                projectsToFilter = allProjects.filter { project in
                    guard let projectName = project.projectName else { return false }
                    return selectedProjectNamesForFilter.contains(projectName)
                }
            default:
                return // Not a project-grouped view
        }
        
        for project in projectsToFilter {
            guard let projectName = project.projectName else { continue }
            // Fetch ONLY OPEN tasks for the current 'dateForTheView' using repository
             taskRepository.getTasksForProjectOpen(projectName: projectName, date: dateForTheView) { [weak self] taskData in
                 DispatchQueue.main.async {
                     if !taskData.isEmpty {
                         // For now, we'll need to fetch the NTask objects using the repository
                         // This is a temporary bridge until the UI is fully migrated to use TaskData
                         var fetchedTasks: [NTask] = []
                         let group = DispatchGroup()
                         
                         for data in taskData {
                             guard let taskID = data.id else { continue }
                             group.enter()
                             self?.taskRepository.fetchTask(by: taskID) { result in
                                 if case .success(let task) = result {
                                     fetchedTasks.append(task)
                                 }
                                 group.leave()
                             }
                         }
                         
                         group.notify(queue: .main) {
                             if !fetchedTasks.isEmpty {
                                 self?.projectsToDisplayAsSections.append(project)
                                 self?.tasksGroupedByProject[projectName] = fetchedTasks
                             }
                         }
                     }
                 }
             }
        }
    }
    
    func updateViewForHome(viewType: ToDoListViewType, dateForView: Date? = nil) {
        // Update view type and date
        currentViewType = viewType
        if let date = dateForView {
            dateForTheView = date
        }
        
        // Update UI based on view type
        switch viewType {
        case .todayHomeView:
            // Update header
            toDoListHeaderLabel.text = "Today"
            dateForTheView = Date.today()
            print("\n AddTask === SWITCHING TO TODAY VIEW ===")
            print("AddTask Date set to: \(dateForTheView)")
            loadTasksForDateGroupedByProject()
            
        case .customDateView:
            // Update header with date
            let formatter = DateFormatter()
            formatter.dateFormat = "E, MMM d"
            toDoListHeaderLabel.text = formatter.string(from: dateForTheView)
            print("\nAddTask === SWITCHING TO CUSTOM DATE VIEW ===")
            print("AddTask Date set to: \(dateForTheView)")
            print("AddTask Header text: \(formatter.string(from: dateForTheView))")
            loadTasksForDateGroupedByProject()
            
        case .projectView:
            toDoListHeaderLabel.text = projectForTheView
            
        case .upcomingView:
            toDoListHeaderLabel.text = "Upcoming"
            
        case .historyView:
            toDoListHeaderLabel.text = "History"
            
        case .allProjectsGrouped:
            toDoListHeaderLabel.text = "All Projects"
            prepareAndFetchTasksForProjectGroupedView()
            
        case .selectedProjectsGrouped:
            toDoListHeaderLabel.text = "Selected Projects"
            prepareAndFetchTasksForProjectGroupedView()
        }
        
        // Refresh UI
        reloadToDoListWithAnimation()
        reloadTinyPicChartWithAnimation()
    }
    

    
    func loadTasksForDateGroupedByProject() {
        // Clear existing sections
        ToDoListSections.removeAll()
        
        print("\n=== LOADING TASKS FOR DATE: \(dateForTheView) ===")
        
        // Get all tasks for the selected date using direct Core Data access
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: dateForTheView)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        request.predicate = NSPredicate(
            format: "dueDate >= %@ AND dueDate < %@",
            startOfDay as NSDate, endOfDay as NSDate
        )
        
        let allTasksForDate = (try? context?.fetch(request)) ?? []
        
        print("📅 Found \(allTasksForDate.count) total tasks for \(dateForTheView)")
        
        // Print all tasks found for debugging
        print("\n📋 TASK DETAILS:")
        for (index, task) in allTasksForDate.enumerated() {
            let status = task.isComplete ? "✅" : "⏳"
            let priority = ["🔴 P0", "🟠 P1", "🟡 P2", "🟢 P3"][Int(task.taskPriority - 1)] ?? "⚪ Unknown"
            print("  \(index + 1). \(status) '\(task.name)' [\(priority)] - Project: '\(task.project ?? "Unknown")' - Added: \(task.dateAdded ?? Date() as NSDate)")
        }
        
        // Group tasks by project
        var tasksByProject: [String: [NTask]] = [:]
        
        for task in allTasksForDate {
            let projectName = task.project?.lowercased() ?? "inbox"
            if tasksByProject[projectName] == nil {
                tasksByProject[projectName] = []
            }
            tasksByProject[projectName]?.append(task)
        }
        
        print("\n📊 TASK COUNT BY PROJECT:")
        let inboxProjectName = "inbox"
        
        // Show Inbox count first
        if let inboxTasks = tasksByProject[inboxProjectName] {
            let completedCount = inboxTasks.filter { $0.isComplete }.count
            let pendingCount = inboxTasks.count - completedCount
            print("  📥 Inbox: \(inboxTasks.count) tasks (\(pendingCount) pending, \(completedCount) completed)")
        } else {
            print("  📥 Inbox: 0 tasks")
        }
        
        // Show other projects
        let sortedProjects = tasksByProject.keys.sorted().filter { $0 != inboxProjectName }
        for projectName in sortedProjects {
            if let projectTasks = tasksByProject[projectName] {
                let completedCount = projectTasks.filter { $0.isComplete }.count
                let pendingCount = projectTasks.count - completedCount
                print("  📁 \(projectName.capitalized): \(projectTasks.count) tasks (\(pendingCount) pending, \(completedCount) completed)")
            }
        }
        
        print("\nProjects with tasks:")
        for (project, tasks) in tasksByProject {
            print("  \(project): \(tasks.count) tasks")
        }
        
        // Create sections for each project with tasks
        // Helper function to create task items from NTask array
        func createTaskItems(from tasks: [NTask]) -> [ToDoListData.TaskListItem] {
            // Sort tasks by priority (high to low) and then by due date
            let sortedTasks = tasks.sorted { task1, task2 in
                // First sort by priority (higher priority first)
                if task1.taskPriority != task2.taskPriority {
                    return task1.taskPriority > task2.taskPriority
                }
                
                // If priorities are equal, sort by due date (earlier dates first)
                guard let date1 = task1.dueDate as Date?, let date2 = task2.dueDate as Date? else {
                    // If one has no due date, put it after the one with due date
                    return task1.dueDate != nil
                }
                return date1 < date2
            }
            
            return sortedTasks.map { task in
                ToDoListData.TaskListItem(
                    text1: task.name ?? "Untitled Task",
                    text2: task.taskDetails ?? "",
                    text3: "",
                    image: ""
                )
            }
        }
        
        // Helper function to check if a task is overdue
        func isTaskOverdue(_ task: NTask) -> Bool {
            guard let dueDate = task.dueDate as Date?, !task.isComplete else { return false }
            let today = Date().startOfDay
            return dueDate < today
        }
        
        // Helper function to add sections for a project
        func addSectionsForProject(projectName: String, displayName: String, tasks: [NTask], includeOverdue: Bool = true) {
            // Separate tasks into categories
            let overdueTasks = includeOverdue ? tasks.filter { isTaskOverdue($0) } : []
            let activeTasks = tasks.filter { !$0.isComplete && !isTaskOverdue($0) }
            let completedTasks = tasks.filter { $0.isComplete }
            
            // Add overdue tasks section if not empty and includeOverdue is true
            if !overdueTasks.isEmpty && includeOverdue {
                let overdueTaskItems = createTaskItems(from: overdueTasks)
                let overdueSection = ToDoListData.Section(
                    title: "\(displayName) – Overdue",
                    taskListItems: overdueTaskItems
                )
                ToDoListSections.append(overdueSection)
                print("HomeViewController: Added \(displayName) – Overdue section with \(overdueTaskItems.count) overdue tasks")
            }
            
            // Add active tasks section if not empty
            if !activeTasks.isEmpty {
                let activeTaskItems = createTaskItems(from: activeTasks)
                let activeSection = ToDoListData.Section(
                    title: displayName,
                    taskListItems: activeTaskItems
                )
                ToDoListSections.append(activeSection)
                print("HomeViewController: Added \(displayName) section with \(activeTaskItems.count) active tasks")
            }
            
            // Add completed tasks section if not empty
            if !completedTasks.isEmpty {
                let completedTaskItems = createTaskItems(from: completedTasks)
                let completedSection = ToDoListData.Section(
                    title: "\(displayName) – Completed",
                    taskListItems: completedTaskItems
                )
                ToDoListSections.append(completedSection)
                print("HomeViewController: Added \(displayName) – Completed section with \(completedTaskItems.count) completed tasks")
            }
        }
        
        // Collect all overdue tasks across all projects for a dedicated overdue section
        let allOverdueTasks = allTasksForDate.filter { isTaskOverdue($0) }
        
        // Add dedicated overdue section at the top if there are overdue tasks
        if !allOverdueTasks.isEmpty {
            let overdueTaskItems = createTaskItems(from: allOverdueTasks)
            let overdueSection = ToDoListData.Section(
                title: "⚠️ Overdue",
                taskListItems: overdueTaskItems
            )
            ToDoListSections.append(overdueSection)
            print("HomeViewController: Added dedicated Overdue section with \(overdueTaskItems.count) overdue tasks")
        }
        
        // First add Inbox sections if it has tasks (excluding overdue since they're in dedicated section)
        if let inboxTasks = tasksByProject[inboxProjectName], !inboxTasks.isEmpty {
            addSectionsForProject(projectName: inboxProjectName, displayName: "Inbox", tasks: inboxTasks, includeOverdue: false)
        }
        
        // Then add other project sections (excluding overdue since they're in dedicated section)
        for projectName in sortedProjects {
            guard let projectTasks = tasksByProject[projectName], !projectTasks.isEmpty else { continue }
            let displayName = projectName.capitalized
            addSectionsForProject(projectName: projectName, displayName: displayName, tasks: projectTasks, includeOverdue: false)
        }
        
        print("\nFinal ToDoListSections summary:")
        for (index, section) in ToDoListSections.enumerated() {
            print("Section \(index): '\(section.sectionTitle)' with \(section.items.count) items")
            for (itemIndex, item) in section.items.enumerated() {
                print("  Item \(itemIndex): '\(item.TaskTitle)'")
            }
        }
        print("=== END TASK LOADING ===")
        
        // Reload table view with new data
        DispatchQueue.main.async {
            // Updated to use FluentUI table view
        self.fluentToDoTableViewController?.tableView.reloadData()
        }
    }
    
    func reloadToDoListWithAnimation() {
        // Updated to use FluentUI table view
        fluentToDoTableViewController?.tableView.reloadData()
        animateTableViewReload()
    }
    
    @objc func clearProjectFilterAndResetView() {
        // Clear project filter selections
        selectedProjectNamesForFilter.removeAll()
        
        // Reset to home view
        updateViewForHome(viewType: .todayHomeView)
        
        // Clear any project filter UI elements
        if let filterBar = filterProjectsPillBar {
            filterBar.removeFromSuperview()
            filterProjectsPillBar = nil
        }
    }
}
