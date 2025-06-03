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
            toDoListHeaderLabel.text = "Today"
            dateForTheView = Date.today()
            // Load today's tasks
            
        case .customDateView:
            // Update header with date
            let formatter = DateFormatter()
            formatter.dateFormat = "E, MMM d"
            toDoListHeaderLabel.text = formatter.string(from: dateForTheView)
            
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
        // Update and animate tiny pie chart
        toDoAnimations.animateTinyPieChartAtHome(pieChartView: tinyPieChartView)
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
