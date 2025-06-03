//
//  HomeViewController+ProjectFiltering.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit

extension HomeViewController {
    
    // Method to set the project value for filtering
    func setProjectForViewValue(projectName: String) {
        projectForTheView = projectName
    }
    
    // Method to set the date value for filtering
    func setDateForViewValue(dateToSetForView: Date) {
        dateForTheView = dateToSetForView
    }
    
    // Method to calculate today's score
    func calculateTodaysScore() -> Int {
        // Get tasks for the current date
        let morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: dateForTheView)
        let eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
        
        // Calculate score based on completed tasks
        let completedTasks = morningTasks.filter { $0.isComplete } + eveningTasks.filter { $0.isComplete }
        return completedTasks.count
    }
    
    // Note: updateHomeDateLabel is implemented elsewhere
    
    func prepareAndFetchTasksForProjectGroupedView() {
        self.projectsToDisplayAsSections.removeAll()
        self.tasksGroupedByProject.removeAll()

        let projectsToFilter: [Projects]
        
        switch currentViewType {
            case .allProjectsGrouped:
                // Get all projects
                projectsToFilter = ProjectManager.sharedInstance.getAllProjects()
            case .selectedProjectsGrouped:
                // Get only the selected projects
                projectsToFilter = ProjectManager.sharedInstance.getAllProjects().filter { project in
                    guard let projectName = project.projectName else { return false }
                    return selectedProjectNamesForFilter.contains(projectName)
                }
            default:
                return // Not a project-grouped view
        }
        
        for project in projectsToFilter {
            guard let projectName = project.projectName else { continue }
            // Fetch ONLY OPEN tasks for the current 'dateForTheView'
            let openTasksForProject = TaskManager.sharedInstance.getTasksByProjectNameAndDate(
                projectName: projectName, 
                date: dateForTheView
            )

            if !openTasksForProject.isEmpty {
                self.projectsToDisplayAsSections.append(project) // This array defines section order
                self.tasksGroupedByProject[projectName] = openTasksForProject
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
            print("\n=== SWITCHING TO TODAY VIEW ===")
            print("Date set to: \(dateForTheView)")
            loadTasksForDateGroupedByProject()
            
        case .customDateView:
            // Update header with date
            let formatter = DateFormatter()
            formatter.dateFormat = "E, MMM d"
            toDoListHeaderLabel.text = formatter.string(from: dateForTheView)
            print("\n=== SWITCHING TO CUSTOM DATE VIEW ===")
            print("Date set to: \(dateForTheView)")
            print("Header text: \(formatter.string(from: dateForTheView))")
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
    
    func reloadTinyPicChartWithAnimation() {
        // Update and animate tiny pie chart - REMOVED
        // toDoAnimations.animateTinyPieChartAtHome(pieChartView: tinyPieChartView)
    }
    
    func loadTasksForDateGroupedByProject() {
        // Clear existing sections
        ToDoListSections.removeAll()
        
        print("\n=== LOADING TASKS FOR DATE: \(dateForTheView) ===")
        
        // Get all tasks for the selected date
        let allTasksForDate = TaskManager.sharedInstance.getAllTasksForDate(date: dateForTheView)
        
        print("📅 Found \(allTasksForDate.count) total tasks for \(dateForTheView)")
        
        // Print all tasks found for debugging
        print("\n📋 TASK DETAILS:")
        for (index, task) in allTasksForDate.enumerated() {
            let status = task.isComplete ? "✅" : "⏳"
            let priority = ["🔴 P0", "🟠 P1", "🟡 P2", "🟢 P3"][Int(task.taskPriority - 1)] ?? "⚪ Unknown"
            print("  \(index + 1). \(status) '\(task.name ?? "Unknown")' [\(priority)] - Project: '\(task.project ?? "nil")' - Added: \(task.dateAdded ?? Date() as NSDate)")
        }
        
        // Group tasks by project
        var tasksByProject: [String: [NTask]] = [:]
        
        for task in allTasksForDate {
            let projectName = task.project?.lowercased() ?? ProjectManager.sharedInstance.defaultProject
            if tasksByProject[projectName] == nil {
                tasksByProject[projectName] = []
            }
            tasksByProject[projectName]?.append(task)
        }
        
        print("\n📊 TASK COUNT BY PROJECT:")
        let inboxProjectName = ProjectManager.sharedInstance.defaultProject
        
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
        // First add Inbox section if it has tasks
        if let inboxTasks = tasksByProject[inboxProjectName], !inboxTasks.isEmpty {
            let inboxTaskItems = inboxTasks.map { task in
                let taskItem = ToDoListData.TaskListItem(
                    text1: task.name ?? "Untitled Task",
                    text2: task.taskDetails ?? "",
                    text3: "",
                    image: ""
                )
                print("Created TaskListItem for Inbox: '\(taskItem.TaskTitle)'")
                return taskItem
            }
            
            let inboxSection = ToDoListData.Section(
                title: "Inbox",
                taskListItems: inboxTaskItems
            )
            ToDoListSections.append(inboxSection)
            print("HomeViewController: Added Inbox section with \(inboxTaskItems.count) tasks")
        }
        
        // Then add other project sections
        for projectName in sortedProjects {
            guard let projectTasks = tasksByProject[projectName], !projectTasks.isEmpty else { continue }
            
            let projectTaskItems = projectTasks.map { task in
                let taskItem = ToDoListData.TaskListItem(
                    text1: task.name ?? "Untitled Task",
                    text2: task.taskDetails ?? "",
                    text3: "",
                    image: ""
                )
                print("Created TaskListItem for \(projectName): '\(taskItem.TaskTitle)'")
                return taskItem
            }
            
            // Get the display name for the project (capitalize first letter)
            let displayName = projectName.capitalized
            
            let projectSection = ToDoListData.Section(
                title: displayName,
                taskListItems: projectTaskItems
            )
            ToDoListSections.append(projectSection)
            print("HomeViewController: Added \(displayName) section with \(projectTaskItems.count) tasks")
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
            self.tableView.reloadData()
        }
    }
    
    func reloadToDoListWithAnimation() {
        tableView.reloadData()
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
