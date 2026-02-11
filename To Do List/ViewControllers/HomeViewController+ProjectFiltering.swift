//
//  HomeViewController+ProjectFiltering.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import CoreData

// MARK: - Project Repository Access
// Use shared repository from EnhancedDependencyContainer instead of inline implementation

extension HomeViewController {

    /// Access to shared project repository via dependency container
    /// Prefer this over creating inline repositories
    var projectRepository: ProjectRepositoryProtocol {
        return EnhancedDependencyContainer.shared.projectRepository
    }

    // Method to set the project value for filtering
    func setProjectForViewValue(projectName: String) {
        projectForTheView = projectName

        // TODO: Update ViewModel once Presentation folder is added to target
        // viewModel?.selectProject(projectName)
    }

    // Method to set the date value for filtering
    func setDateForViewValue(dateToSetForView: Date) {
        dateForTheView = dateToSetForView

        // TODO: Update ViewModel once Presentation folder is added to target
        // viewModel?.selectDate(dateToSetForView)
    }

    /// Calculate today's score synchronously using cached value
    /// NOTE: For accurate real-time score, use calculateTodaysScore(completion:) instead
    /// This synchronous version returns the last cached score or 0 if not available
    func calculateTodaysScore() -> Int {
        // TODO: Re-enable when ViewModel is available
        // Use ViewModel's published dailyScore property if available
        // if let viewModel = viewModel {
        //     return viewModel.dailyScore
        // }

        // IMPORTANT: Synchronous score calculation is not possible with async repository.
        // Return 0 here - callers should use calculateTodaysScore(completion:) for accurate scores.
        // This is a known limitation pending full ViewModel migration.
        print("⚠️ calculateTodaysScore() sync version called - use async version for accurate score")
        return 0
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

        // TODO: Use ViewModel to load projects once Presentation folder is added to target
        // For now, load projects directly from shared repository
        var domainProjects: [Project] = []

        // Load projects from shared repository via dependency container
        let dispatchGroup = DispatchGroup()
        dispatchGroup.enter()
        projectRepository.fetchAllProjects { result in
            if case .success(let projects) = result {
                domainProjects = projects
            }
            dispatchGroup.leave()
        }
        dispatchGroup.wait()

        // Determine which projects to display
        let projectsToFilter: [Project]

        switch currentViewType {
            case .allProjectsGrouped:
                projectsToFilter = domainProjects
            case .selectedProjectsGrouped:
                projectsToFilter = domainProjects.filter { project in
                    selectedProjectNamesForFilter.contains(project.name)
                }
            default:
                return // Not a project-grouped view
        }

        // Fetch tasks for each project using repository (respects Clean Architecture)
        for project in projectsToFilter {
            let projectName = project.name
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
                                 // Convert domain Project to Projects entity for backwards compatibility
                                 // TODO: Refactor UI to work directly with domain models
                                 if let projectEntity = self?.convertDomainProjectToEntity(project) {
                                     self?.projectsToDisplayAsSections.append(projectEntity)
                                     self?.tasksGroupedByProject[projectName] = fetchedTasks
                                 }
                             }
                         }
                     }
                 }
             }
        }
    }

    /// Temporary helper to convert domain Project to Projects entity
    /// TODO: Remove this once UI is fully migrated to use domain models
    /// Uses a temporary in-memory context to avoid polluting the main viewContext
    /// Internal access to allow use from other HomeViewController extensions
    func convertDomainProjectToEntity(_ project: Project) -> Projects? {
        // Create an in-memory context that won't persist or affect the main context
        guard (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer != nil else {
            return nil
        }

        // Create a temporary context with no parent - changes won't be saved
        let tempContext = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        tempContext.persistentStoreCoordinator = nil // No persistent store - purely in-memory

        // Create entity in temporary context
        let entity = Projects(context: tempContext)
        entity.projectID = project.id
        entity.projectName = project.name
        entity.projectDescription = project.projectDescription
        // Note: This entity exists only in the temp context and won't be saved
        return entity
    }
    
    func updateViewForHome(viewType: ToDoListViewType, dateForView: Date? = nil) {
        // Update view type and date
        currentViewType = viewType
        if let date = dateForView {
            dateForTheView = date
        }

        // TODO: Re-enable when ViewModel is available
        // Use Clean Architecture ViewModel if available, otherwise fallback to legacy
        // if let viewModel = viewModel {
        //     print("✅ Using Clean Architecture ViewModel for data loading")
        //     updateViewUsingViewModel(viewType: viewType)
        // } else {
            print("⚠️ ViewModel not available, using legacy data loading")
            updateViewUsingLegacyMethod(viewType: viewType)
        // }

        // Refresh UI
        reloadToDoListWithAnimation()
        reloadTinyPicChartWithAnimation()
    }
    
    /// Clean Architecture data loading using ViewModel
    /// TODO: Re-enable when ViewModel is available
    private func updateViewUsingViewModel(viewType: ToDoListViewType) {
        // guard let vm = viewModel else { return }
        //
        // // Use reflection-based approach to safely call ViewModel methods
        // // This avoids type conflicts while maintaining Clean Architecture patterns
        //
        // // Update UI based on view type
        // switch viewType {
        // case .todayHomeView:
        //     toDoListHeaderLabel.text = "Today"
        //     dateForTheView = Date.today()
        //     print("🏗️ Clean Architecture: Loading today's tasks via ViewModel")
        //     callViewModelMethod(vm, methodName: "loadTodayTasks")
        //
        // case .customDateView:
        //     let formatter = DateFormatter()
        //     formatter.dateFormat = "E, MMM d"
        //     toDoListHeaderLabel.text = formatter.string(from: dateForTheView)
        //     print("🏗️ Clean Architecture: Loading tasks for \(dateForTheView) via ViewModel")
        //     callViewModelMethod(vm, methodName: "selectDate", parameter: dateForTheView)
        //     callViewModelMethod(vm, methodName: "loadTasksForSelectedDate")
        //
        // case .projectView:
        //     toDoListHeaderLabel.text = projectForTheView
        //     print("🏗️ Clean Architecture: Loading tasks for project '\(projectForTheView)' via ViewModel")
        //     callViewModelMethod(vm, methodName: "selectProject", parameter: projectForTheView)
        //
        // case .upcomingView:
        //     toDoListHeaderLabel.text = "Upcoming"
        //     print("🏗️ Clean Architecture: Loading upcoming tasks via ViewModel")
        //     // ViewModel will handle upcoming tasks
        //
        // case .historyView:
        //     toDoListHeaderLabel.text = "History"
        //     print("🏗️ Clean Architecture: Loading history via ViewModel")
        //     // ViewModel will handle history
        //
        // case .allProjectsGrouped:
        //     toDoListHeaderLabel.text = "All Projects"
        //     print("🏗️ Clean Architecture: Loading all projects via ViewModel")
        //     callViewModelMethod(vm, methodName: "loadProjects")
        //
        // case .selectedProjectsGrouped:
        //     toDoListHeaderLabel.text = "Selected Projects"
        //     print("🏗️ Clean Architecture: Loading selected projects via ViewModel")
        //     callViewModelMethod(vm, methodName: "loadProjects")
        // }
        print("⚠️ updateViewUsingViewModel disabled - TODO: Re-enable when ViewModel is available")
    }
    
    /// Legacy data loading method (fallback)
    private func updateViewUsingLegacyMethod(viewType: ToDoListViewType) {
        // Update UI based on view type
        switch viewType {
        case .todayHomeView:
            toDoListHeaderLabel.text = "Today"
            dateForTheView = Date.today()
            print("🔧 Legacy: Loading today's tasks")
            loadTasksForDateGroupedByProject()
            
        case .customDateView:
            let formatter = DateFormatter()
            formatter.dateFormat = "E, MMM d"
            toDoListHeaderLabel.text = formatter.string(from: dateForTheView)
            print("🔧 Legacy: Loading tasks for \(dateForTheView)")
            loadTasksForDateGroupedByProject()
            
        case .projectView:
            toDoListHeaderLabel.text = projectForTheView
            print("🔧 Legacy: Loading project view")
            
        case .upcomingView:
            toDoListHeaderLabel.text = "Upcoming"
            print("🔧 Legacy: Loading upcoming view")
            
        case .historyView:
            toDoListHeaderLabel.text = "History"
            print("🔧 Legacy: Loading history view")
            
        case .allProjectsGrouped:
            toDoListHeaderLabel.text = "All Projects"
            print("🔧 Legacy: Loading all projects grouped")
            prepareAndFetchTasksForProjectGroupedView()
            
        case .selectedProjectsGrouped:
            toDoListHeaderLabel.text = "Selected Projects"
            print("🔧 Legacy: Loading selected projects grouped")
            prepareAndFetchTasksForProjectGroupedView()
        }
    }
    

    
    func loadTasksForDateGroupedByProject() {
        // Clear existing sections
        ToDoListSections.removeAll()

        print("\n=== LOADING TASKS FOR DATE: \(dateForTheView) ===")

        // TODO: Use ViewModel to get tasks once Presentation folder is added to target
        // For now, use direct CoreData fetch
        print("⚠️ Using direct CoreData fetch (TODO: migrate to ViewModel)")

        // Direct CoreData fetch as fallback
        if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()

            // Fetch tasks for the selected date
            let calendar = Calendar.current
            let startOfDay = calendar.startOfDay(for: dateForTheView)
            let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

            request.predicate = NSPredicate(format: "dueDate >= %@ AND dueDate < %@", startOfDay as NSDate, endOfDay as NSDate)
            request.sortDescriptors = [NSSortDescriptor(key: "taskPriority", ascending: true)]

            do {
                let allTasksForDate = try context.fetch(request)
                print("📅 Found \(allTasksForDate.count) total tasks for \(dateForTheView) via CoreData")
                processTasksForDisplay(allTasksForDate)
            } catch {
                print("❌ Error fetching tasks: \(error)")
                processTasksForDisplay([])
            }
        } else {
            print("❌ No context available")
            processTasksForDisplay([])
        }
    }

    /// Process tasks and create sections for display
    private func processTasksForDisplay(_ allTasksForDate: [NTask]) {
        
        // Print all tasks found for debugging
        print("\n📋 TASK DETAILS:")
        let addedDateFormatter = DateFormatter()
        addedDateFormatter.dateStyle = .short
        addedDateFormatter.timeStyle = .short

        for (index, task) in allTasksForDate.enumerated() {
            let status = task.isComplete ? "✅" : "⏳"
            let priorityModel = TaskPriority(rawValue: task.taskPriority)
            let priority = "\(priorityModel.displayName) (\(priorityModel.code))"
            let taskName = task.name ?? "Untitled Task"
            let addedDate = (task.dateAdded as Date?) ?? Date()
            let addedDateText = addedDateFormatter.string(from: addedDate)
            print("  \(index + 1). \(status) '\(taskName)' [\(priority)] - Project: '\(task.project ?? "Unknown")' - Added: \(addedDateText)")
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
