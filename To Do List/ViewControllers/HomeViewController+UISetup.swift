//
//  HomeViewController+UISetup.swift
//  To Do List
//
//  Created by Saransh Sharma on 02/06/25.
//  Copyright 2025 saransh1337. All rights reserved.
//

import UIKit
import FluentUI
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
        backdropContainer.backgroundColor = todoColors.primaryColor
        
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
    
    
    
    func setupHomeFordrop() {
        // Calculate dimensions
        let screenWidth = view.bounds.width
        let screenHeight = view.bounds.height
        
        // Get the navigation bar height
        let navigationBarHeight = navigationController?.navigationBar.frame.height ?? 0

        // Total top area height (status bar + navigation bar)
        let totalTopHeight = navigationBarHeight
        
        let foredropHeight = screenHeight-totalTopHeight
        // Calculate bottom safe area inset
        let safeAreaBottomInset: CGFloat
        if #available(iOS 11.0, *) {
            safeAreaBottomInset = view.safeAreaInsets.bottom
        } else {
            safeAreaBottomInset = 0
        }
        
        // Allow content to extend under the Liquid Glass bottom bar (no reserved space)
        // Keep a small top offset for styling, but do not subtract the bar height.
        foredropContainer.frame = CGRect(x: 0,
                                         y: screenHeight - foredropHeight + 24,
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
        
        // Store the original foredrop center Y position for animations
        originalForedropCenterY = foredropContainer.center.y
    }
    
    func setupTopBarInForedrop() {
        homeTopBar = UIView(frame: CGRect(x: 0, y: 0, width: foredropContainer.bounds.width, height: 25))
        homeTopBar.backgroundColor = UIColor.clear//todoColors.backgroundColor
        
        // Set up the header label ("Today")
        toDoListHeaderLabel.frame = CGRect(x: 0, y: 10, width: homeTopBar.bounds.width, height: homeTopBar.bounds.height)
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
            fluentToDoTableViewController?.delegate = self
        }
        
        // Setup the FluentUI table to fill the foredrop
        setupSampleTableView(for: dateForTheView)
        
        print("FluentUI table view setup in foredrop completed")
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
        
        updateSwiftUIChartCard()
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
        if isChartsDown {
            // Charts are down, need two-step animation: return to original then show calendar
            returnToOriginalThenRevealCalendar()
        } else if isCalDown {
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
        if isCalDown {
            // Calendar is down, need two-step animation: return to original then show charts
            returnToOriginalThenRevealCharts()
        } else if isChartsDown {
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
        print("\n=== SETTING UP FLUENT UI SAMPLE TABLE VIEW FOR DATE: \(date) ===")
        
        // Initialize FluentUI sample table view controller if not already done
        if fluentToDoTableViewController == nil {
            fluentToDoTableViewController = FluentUIToDoTableViewController(style: .insetGrouped)
            fluentToDoTableViewController?.delegate = self
        }
        
        // Update data for the selected date
        fluentToDoTableViewController?.updateData(for: date)
        
        // Calculate the top bar height dynamically
        let topBarHeight = homeTopBar.bounds.height ?? 0
        
        // Position the FluentUI sample table view to fill the available space
        // With Liquid Glass bar, content may extend underneath; do not reserve space
        let availableHeight = foredropContainer.bounds.height - topBarHeight
        
        fluentToDoTableViewController?.view.frame = CGRect(
            x: 0,
            y: topBarHeight,
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
            fluentToDoTableViewController?.tableView.isOpaque = false
            fluentToDoTableViewController?.tableView.backgroundView = nil
            fluentToDoTableViewController?.tableView.separatorStyle = .none
            
            // Add as child view controller for proper lifecycle management
            self.addChild(fluentToDoTableViewController!)
            fluentToDoTableViewController?.didMove(toParent: self)
        }
        
        print("=== END FLUENT UI SAMPLE TABLE VIEW SETUP with top bar height: \(topBarHeight) ===")
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
    
    // MARK: - Two-Step Animation Helper Functions
    
    private func returnToOriginalThenRevealCalendar() {
        // First animation: Hide charts and return to original position
        UIView.animate(withDuration: 0.2, animations: {
            self.moveUp_hideCharts(view: self.foredropContainer)
        }) { _ in
            // Second animation: Show calendar
            UIView.animate(withDuration: 0.2) {
                self.moveDown_revealJustCal(view: self.foredropContainer)
            }
            // Expand calendar to week scope when showing
            self.calendar.setScope(.week, animated: true)
        }
    }
    
    private func returnToOriginalThenRevealCharts() {
        // First animation: Hide calendar and return to original position
        self.calendar.setScope(.week, animated: true)
        UIView.animate(withDuration: 0.2, animations: {
            self.moveUp_toHideCal(view: self.foredropContainer)
        }) { _ in
            // Second animation: Show charts
            UIView.animate(withDuration: 0.3) {
                self.moveDown_revealCharts(view: self.foredropContainer)
            }
            // Animate the chart axes when showing charts
            self.animateLineChart(chartView: self.lineChartView)
        }
    }
}
