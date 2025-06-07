//
//  HomeViewController+UISetup.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import FluentUI
import MaterialComponents.MaterialBottomAppBar
import TinyConstraints
import SemiModalViewController
import FSCalendar
import UserNotifications

extension HomeViewController: BadgeViewDelegate {
    
    // MARK: - BadgeViewDelegate Methods
    
    func didSelectBadge(_ badge: BadgeView) {
        // Called when the badge becomes 'selected'.
        // You can leave this empty or handle selection styling if needed.
    }
    
    func didTapSelectedBadge(_ badge: BadgeView) {
        // Called when user taps on an already-selected badge.
        badge.isSelected = false
        let alert = UIAlertController(title: "A selected badge was tapped",
                                     message: nil,
                                     preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
    
    // MARK: - Backdrop & Foredrop Setup
    
    func setupBackdrop() {
        backdropContainer.frame = view.bounds
        backdropContainer.backgroundColor = todoColors.backgroundColor
        
        // Add calendar and charts to backdrop
        setupCalendarInBackdrop()
        setupChartsInBackdrop()
        
        view.addSubview(backdropContainer)
    }
    
    func setupCalendarInBackdrop() {
        // Initialize calendar if not already done
        if calendar == nil {
            calendar = FSCalendar(frame: CGRect(x: 0, y: -5, width: view.bounds.width, height: 300))
            calendar.dataSource = self
            calendar.delegate = self
            calendar.backgroundColor = .clear
            calendar.appearance.headerTitleColor = todoColors.primaryTextColor
            calendar.appearance.weekdayTextColor = todoColors.primaryTextColor
            calendar.appearance.titleDefaultColor = todoColors.primaryTextColor
            calendar.appearance.todayColor = todoColors.secondaryAccentColor//todoColors.primaryColor
            calendar.appearance.selectionColor = todoColors.secondaryAccentColor
            
            // Ensure calendar starts in week mode
            calendar.scope = .week
        }
        
        backdropContainer.addSubview(calendar)
    }
    
    func setupChartsInBackdrop() {
        // Setup line chart
        lineChartView.frame = CGRect(x: 20, y: 420, width: view.bounds.width - 40, height: 200)
        lineChartView.backgroundColor = .clear
        lineChartView.delegate = self
        
        // Setup pie chart - REMOVED
        // tinyPieChartView.frame = CGRect(x: view.bounds.width - 90, y: 20, width: 70, height: 70)
        // tinyPieChartView.backgroundColor = .clear
        
        backdropContainer.addSubview(lineChartView)
        // backdropContainer.addSubview(tinyPieChartView) - REMOVED
    }
    
    func setupHomeFordrop() {
        // Calculate dimensions
        let screenWidth = view.bounds.width
        let screenHeight = view.bounds.height
        let foredropHeight = screenHeight * 0.85 // Adjust to match your design
        
        // Calculate bottom safe area inset
        let safeAreaBottomInset: CGFloat
        if #available(iOS 11.0, *) {
            safeAreaBottomInset = view.safeAreaInsets.bottom
        } else {
            safeAreaBottomInset = 0
        }
        
        // Account for bottom app bar height (standard 64pt)
        let bottomBarHeight: CGFloat = 64 + safeAreaBottomInset
        
        // Position foredrop container - leave space for the bottom bar
        foredropContainer.frame = CGRect(x: 0, 
                                      y: screenHeight - foredropHeight - bottomBarHeight + 24, 
                                      width: screenWidth, 
                                      height: foredropHeight)
        foredropContainer.backgroundColor = todoColors.backgroundColor
        foredropContainer.layer.cornerRadius = 24
        foredropContainer.clipsToBounds = true
        
        // Add shadows or other styling to foredrop
        foredropContainer.layer.shadowColor = UIColor.black.cgColor
        foredropContainer.layer.shadowOffset = CGSize(width: 0, height: -3)
        foredropContainer.layer.shadowOpacity = 0.1
        foredropContainer.layer.shadowRadius = 10
        foredropContainer.layer.masksToBounds = false
        
        // Setup top section with "Today" title
        setupTopBarInForedrop()
        
        // Setup new sample table view at the top
        setupSampleTableView()
        
        // Setup and add tableView to foredrop
        setupTableViewInForedrop()
    }
    
    func setupTopBarInForedrop() {
        homeTopBar = UIView(frame: CGRect(x: 0, y: 0, width: foredropContainer.bounds.width, height: 50))
        homeTopBar.backgroundColor = todoColors.backgroundColor
        
        // Set up the header label ("Today")
        toDoListHeaderLabel.frame = CGRect(x: 0, y: 0, width: homeTopBar.bounds.width, height: homeTopBar.bounds.height)
        toDoListHeaderLabel.text = "Today"
        toDoListHeaderLabel.textAlignment = .center
        toDoListHeaderLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        toDoListHeaderLabel.textColor = todoColors.primaryTextColor
        
        homeTopBar.addSubview(toDoListHeaderLabel)
        foredropContainer.addSubview(homeTopBar)
    }
    
    func setupTableViewInForedrop() {
        // Make sure we don't add the table view multiple times
//        tableView.removeFromSuperview()
        
        // registration already done; just wire delegates
        tableView.dataSource = self            // ← ADD
        tableView.delegate   = self            // ← ADD
        
        
        

        tableView.register(TableViewCell.self, forCellReuseIdentifier: cellReuseID)
        tableView.register(TableViewHeaderFooterView.self,forHeaderFooterViewReuseIdentifier: headerReuseID)


        
        // Configure table view dimensions - position below sample table view
        let topBarHeight = homeTopBar.bounds.height
        let sampleTableHeight: CGFloat = 300 // Same height as sample table
        let tableViewY = topBarHeight + sampleTableHeight
        
        tableView.frame = CGRect(x: 0, y: tableViewY, 
                               width: foredropContainer.bounds.width,
                               height: foredropContainer.bounds.height - tableViewY)
        
        tableView.backgroundView?.backgroundColor = UIColor.clear
        
        // Add table view to foredrop
        foredropContainer.addSubview(tableView)
    }
    
    func setupBottomAppBar() {
        // Calculate position for the bottom app bar
        let screenWidth = view.bounds.width
        let screenHeight = view.bounds.height
        let barHeight: CGFloat = 64 // Standard height for bottom app bar
        
        // Account for safe area insets to avoid being cut off at the bottom
        let safeAreaBottomInset: CGFloat
        if #available(iOS 11.0, *) {
            safeAreaBottomInset = view.safeAreaInsets.bottom
        } else {
            safeAreaBottomInset = 0
        }
        
        // Configure the bottom app bar - position it correctly with safe area insets
        bottomAppBar = MDCBottomAppBarView(frame: CGRect(x: 0, y: screenHeight - barHeight - safeAreaBottomInset, width: screenWidth, height: barHeight))
        bottomAppBar.barTintColor = todoColors.primaryColor
        bottomAppBar.shadowColor = UIColor.black.withAlphaComponent(0.4)
        bottomAppBar.autoresizingMask = [.flexibleWidth, .flexibleTopMargin] // Keep it at the bottom when screen resizes
        
        // Configure floating action button
        let fab = bottomAppBar.floatingButton
        // Use a system plus icon if custom icon is missing
        let addTaskImage = UIImage(named: "add_task") ?? UIImage(systemName: "plus")
        fab.setImage(addTaskImage, for: .normal)
        fab.backgroundColor = todoColors.secondaryAccentColor
        fab.addTarget(self, action: #selector(AddTaskAction), for: .touchUpInside)
        bottomAppBar.floatingButtonPosition = .center
        
        // Add navigation items for leading side (left)
        let calendarImage = UIImage(systemName: "calendar")
        let calendarItem = UIBarButtonItem(image: calendarImage, style: .plain, target: self, action: #selector(toggleCalendar))
        calendarItem.tintColor = UIColor.white
        
        let chartImage = UIImage(systemName: "chart.bar")
        let chartItem = UIBarButtonItem(image: chartImage, style: .plain, target: self, action: #selector(toggleCharts))
        chartItem.tintColor = UIColor.white
        
        bottomAppBar.leadingBarButtonItems = [calendarItem, chartItem]
        
        // Add navigation items for trailing side (right)
        let menuImage = UIImage(named: "menu_icon") ?? UIImage(systemName: "line.horizontal.3")
        let settingsItem = UIBarButtonItem(image: menuImage, style: .plain, target: self, action: #selector(onMenuButtonTapped))
        settingsItem.tintColor = UIColor.white
        
        bottomAppBar.trailingBarButtonItems = [settingsItem]
    }
    
    func createButton(title: String, action: Selector) -> FluentUI.Button {
        let button = FluentUI.Button()
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body) // Plan Step C: Replaced todoFont
        button.titleLabel?.textAlignment = .center
        button.titleLabel?.numberOfLines = 0
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }
    
    func fitViewIntoSuperview(_ view: UIView, margins: UIEdgeInsets) {
        guard let superview = view.superview else {
            return
        }
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            view.topAnchor.constraint(equalTo: superview.topAnchor, constant: margins.top),
            view.leftAnchor.constraint(equalTo: superview.leftAnchor, constant: margins.left),
            view.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -margins.bottom),
            view.rightAnchor.constraint(equalTo: superview.rightAnchor, constant: -margins.right)
        ])
    }
    
    func createBadge(text: String, labelStyle: BadgeView.Style = .default, size: BadgeView.SizeCategory = .medium, isEnabled: Bool = true) -> BadgeView { // Plan Step E: Updated signature
        let dataSource = BadgeViewDataSource(
            text: text,
            style: labelStyle,
            sizeCategory: size
        )
        let badge = BadgeView(dataSource: dataSource)
        badge.isActive = isEnabled
        if isEnabled {
            badge.delegate = self
        }
        return badge
    }
    
    // MARK: - Badge Setup
    
    func setupBadgeCount() {
        // Badge count setup implementation
        notificationBadgeNumber = getTaskForTodayCount()
        
        if UIApplication.shared.delegate is AppDelegate {
            if self.todoTimeUtils.isNightTime(date: Date()) == false { // Updated to use date parameter
                UIApplication.shared.applicationIconBadgeNumber = getTaskForTodayCount() // Plan Step G
            } else {
                UIApplication.shared.applicationIconBadgeNumber = 0 // Plan Step G
            }
            
            UIApplication.shared.registerForRemoteNotifications() // Plan Step G
        }
    }
    
    // MARK: - App Lifecycle
    
    @objc
    func appMovedToForeground() {
        print("App moved to ForeGround!")
        // toDoAnimations.animateTinyPieChartAtHome(pieChartView: tinyPieChartView) - REMOVED
        
        updateLineChartData()
        updateHomeDateLabel(date: dateForTheView)
        
        if dateForTheView == Date.today() {
            print("###### Today !")
        }
    }
    
    @objc
    func appMovedToBackground() {
        print("App moved to Background!")
        // Perform any background tasks here
    }
    
    @objc
    func appTerminated() {
        print("App is terminating!")
        // Save state or perform cleanup before termination
    }
    
    // MARK: - Calendar and Charts Toggles
    
    @objc func toggleCalendar() {
        if isCalDown {
            // Calendar is currently showing (monthly) - hide it and switch to weekly
            // Reset calendar to week scope BEFORE hiding animation
            calendar.setScope(.week, animated: true)
            // Hide calendar (foredrop goes up)
            UIView.animate(withDuration: 0.2) {
                self.moveUp_toHideCal(view: self.foredropContainer)
            }
        } else {
            // Calendar is currently hidden - show it in monthly view
            // Show calendar (foredrop goes down)
            UIView.animate(withDuration: 0.2) {
                self.moveDown_revealJustCal(view: self.foredropContainer)
            }
            // Expand calendar to month scope when showing
            calendar.setScope(.week, animated: true)
        }
    }
    
    @objc func toggleCharts() {
        if isChartsDown {
            // Hide charts
            UIView.animate(withDuration: 0.3) {
                self.moveUp_hideCharts(view: self.foredropContainer)
            }
        } else {
            // Show charts
            UIView.animate(withDuration: 0.3) {
                self.moveDown_revealCharts(view: self.foredropContainer)
            }
        }
    }
    
    func setupSampleTableView(for date: Date = Date.today()) {
        print("\n=== SETTING UP SAMPLE TABLE VIEW FOR DATE: \(date) ===")
        
        // Get all tasks for the selected date (same logic as main table view)
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
        
        // Helper function to check if a task is overdue
        func isTaskOverdue(_ task: NTask) -> Bool {
            guard let dueDate = task.dueDate as Date?, !task.isComplete else { return false }
            let today = Date().startOfDay
            return dueDate < today
        }
        
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
            sections.append(("Inbox", sortedInboxTasks))
            print("SampleTableView: Added Inbox section with \(sortedInboxTasks.count) tasks")
        }
        
        // Then add other project sections
        for projectName in sortedProjects {
            guard let projectTasks = tasksByProject[projectName], !projectTasks.isEmpty else { continue }
            let displayName = projectName.capitalized
            let sortedProjectTasks = createSortedTasks(from: projectTasks)
            sections.append((displayName, sortedProjectTasks))
            print("SampleTableView: Added \(displayName) section with \(sortedProjectTasks.count) tasks")
        }
        
        // If no tasks, show a placeholder with empty task array
        if sections.isEmpty {
            sections.append(("📥 No Tasks", []))
        }
        
        print("\nSampleTableView sections summary:")
        for (index, section) in sections.enumerated() {
            print("Section \(index): '\(section.0)' with \(section.1.count) tasks")
        }
        print("=== END SAMPLE TABLE VIEW SETUP ===")
        
        self.sampleData = sections
        
        // Configure sample table view
        self.sampleTableView.dataSource = self
        self.sampleTableView.delegate = self
        self.sampleTableView.backgroundColor = UIColor.systemBackground
        self.sampleTableView.separatorStyle = .singleLine
        self.sampleTableView.register(UITableViewCell.self, forCellReuseIdentifier: "SampleCell")
        
        // Position the sample table view at the top of foredrop container
        let topBarHeight = self.homeTopBar.bounds.height
        let sampleTableHeight: CGFloat = 300 // Fixed height for sample table
        
        self.sampleTableView.frame = CGRect(
            x: 0,
            y: topBarHeight,
            width: self.foredropContainer.bounds.width,
            height: sampleTableHeight
        )
        
        // Add sample table view to foredrop container
        self.foredropContainer.addSubview(self.sampleTableView)
    }
    
    func getPriorityIcon(for priority: Int) -> String {
        switch priority {
        case 1: return "🔴" // P0 - Highest
        case 2: return "🟠" // P1 - High
        case 3: return "🟡" // P2 - Medium
        case 4: return "🟢" // P3 - Low
        default: return "⚪" // Unknown
        }
    }
    
    func refreshSampleTableView(for date: Date) {
        setupSampleTableView(for: date)
        sampleTableView.reloadData()
    }
}
