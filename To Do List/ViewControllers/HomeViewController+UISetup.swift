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
        lineChartView.frame = CGRect(x: 20, y: 120, width: view.bounds.width - 40, height: 400)
        lineChartView.backgroundColor = .clear
        lineChartView.delegate = self
        
        // Setup pie chart - REMOVED
        // tinyPieChartView.frame = CGRect(x: view.bounds.width - 90, y: 20, width: 70, height: 70)
        // tinyPieChartView.backgroundColor = .clear
        
        backdropContainer.addSubview(lineChartView)
        // backdropContainer.addSubview(tinyPieChartView) - REMOVED
        
        // Configure chart appearance and data
        setupCharts()
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
        
        // Setup FluentUI table view in foredrop (main tableView removed)
        setupTableViewInForedrop()
    }
    
    func setupTopBarInForedrop() {
        homeTopBar = UIView(frame: CGRect(x: 0, y: 0, width: foredropContainer.bounds.width, height: 50))
        homeTopBar.backgroundColor = UIColor.clear//todoColors.backgroundColor
        
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
        // This method now sets up the FluentUI table view in foredrop
        // Initialize FluentUI sample table view controller if not already done
        if fluentToDoTableViewController == nil {
            fluentToDoTableViewController = FluentUIToDoTableViewController(style: .insetGrouped)
        }
        
        // Setup the FluentUI table to fill the foredrop
        setupSampleTableView(for: dateForTheView)
        
        print("FluentUI table view setup in foredrop completed")
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
            // Animate the chart axes when showing charts
            animateLineChart(chartView: lineChartView)
        }
    }
    
    func setupSampleTableView(for date: Date = Date.today()) {
        print("\n=== SETTING UP FLUENT UI SAMPLE TABLE VIEW FOR DATE: \(date) ===")
        
        // Initialize FluentUI sample table view controller if not already done
        if fluentToDoTableViewController == nil {
            fluentToDoTableViewController = FluentUIToDoTableViewController(style: .insetGrouped)
        }
        
        // Update data for the selected date
        fluentToDoTableViewController?.updateData(for: date)
        
        // Position the FluentUI sample table view to fill the entire foredrop container
        // Account for bottom app bar height
        let bottomBarHeight = bottomAppBar.bounds.height
        let availableHeight = foredropContainer.bounds.height - bottomBarHeight
        
        fluentToDoTableViewController?.view.frame = CGRect(
            x: 0,
            y: 0,
            width: self.foredropContainer.bounds.width,
            height: availableHeight
        )
        
        // Add FluentUI sample table view to foredrop container
        if let fluentView = fluentToDoTableViewController?.view {
            // Remove any existing views (legacy cleanup)
            // self.sampleTableView.removeFromSuperview() // Already removed from HomeViewController
            
            // Setup foredrop background before adding the table view
//            setupForedropBackground()
            
            // Add the FluentUI table view
            self.foredropContainer.addSubview(fluentView)
            
            // Make the table view background transparent so the foredrop shows through
            fluentView.backgroundColor = UIColor.clear
            fluentToDoTableViewController?.tableView.backgroundColor = UIColor.clear
            
            // Add as child view controller for proper lifecycle management
            self.addChild(fluentToDoTableViewController!)
            fluentToDoTableViewController?.didMove(toParent: self)
        }
        
        print("=== END FLUENT UI SAMPLE TABLE VIEW SETUP ===")
    }
    
    func setupForedropBackground() {
        // Setup the foredrop background image view
        backdropForeImageView.frame = CGRect(x: 0, y: 0, width: foredropContainer.bounds.width, height: foredropContainer.bounds.height)
        backdropForeImageView.image = backdropForeImage?.withRenderingMode(.alwaysTemplate)
//        backdropForeImageView.tintColor = .systemBackground
        backdropForeImageView.backgroundColor = .clear
        
        // Add shadow effects
        backdropForeImageView.layer.shadowColor = UIColor.black.cgColor
        backdropForeImageView.layer.shadowOpacity = 0.8
        backdropForeImageView.layer.shadowOffset = CGSize(width: -5.0, height: -5.0)
        backdropForeImageView.layer.shadowRadius = 10
        
        // Add the foredrop background to the container (behind the table view)
        foredropContainer.addSubview(backdropForeImageView)
        foredropContainer.sendSubviewToBack(backdropForeImageView)
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
        // FluentUI table view will automatically reload when updateData is called
    }
}
