//
//  HomeViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright 2020 saransh1337. All rights reserved.
//

import UIKit
import CoreData
import SemiModalViewController
import ViewAnimator
import FSCalendar
import DGCharts
import FluentUI
import UserNotifications
import TinyConstraints
import MaterialComponents.MaterialButtons
import MaterialComponents.MaterialBottomAppBar
import SwiftUI
import MaterialComponents.MaterialButtons_Theming
import MaterialComponents.MaterialRipple
// Import the delegate protocol
import Foundation

class HomeViewController: UIViewController, ChartViewDelegate, MDCRippleTouchControllerDelegate, UITableViewDataSource, UITableViewDelegate, SearchBarDelegate, TaskRepositoryDependent {
    
    // MARK: - Stored Properties
    
    /// Task repository dependency (injected)
    var taskRepository: TaskRepository!
    
    let cellReuseID = TableViewCell.identifier   // FluentUI's own ID
    let headerReuseID = TableViewHeaderFooterView.identifier
    
    // View containers
    var backdropContainer = UIView()
    var foredropContainer = UIView()
    var bottomBarContainer = UIView()
    let lineSeparator = UIView()
    
    // Utilities
    let notificationCenter = NotificationCenter.default
    var headerEndY: CGFloat = 128
    var todoColors = ToDoColors()
    var todoTimeUtils = ToDoTimeUtils()
    
    // Task editing state
    var editingTaskForDatePicker: NTask?
    var activeTaskDetailViewFluent: TaskDetailViewFluent?
    var editingTaskForProjectPicker: NTask?
    var presentedFluentDetailView: TaskDetailViewFluent?
    var overlayView: UIView?
    
    // UI Elements
    var homeTopBar: UIView = UIView()
    var filledBar: UIView?
    var notificationBadgeNumber: Int = 0
    let ultraLightConfiguration = UIImage.SymbolConfiguration(weight: .regular)
    var highestPrioritySymbol = UIImage()
    var highPrioritySymbol = UIImage()
    
    // Table view state
    var shouldAnimateCells = true
    var ToDoListSections: [ToDoListData.Section] = []
    var listSection: ToDoListData.Section? = nil
    var openTaskCheckboxTag = 0
    var currentIndex: IndexPath = [0,0]
    let toDoListHeaderLabel = UILabel()
    // Added properties for backdrop/foredrop UI elements (Plan Step K)
    let revealCalAtHomeButton    = UIButton(type: .system)
    let revealChartsAtHomeButton = UIButton(type: .system)
    let backdropBackgroundImageView = UIImageView()
    let backdropNochImageView       = UIImageView()
    var backdropForeImageView = UIImageView()
    let backdropForeImage = UIImage(named: "backdropFrontImage")
    var seperatorTopLineView = UIView()
    let homeDate_Day     = UILabel()
    let homeDate_WeekDay = UILabel()
    let homeDate_Month   = UILabel()
    
    // UI Components
    var filterProjectsPillBar: UIView?
    var bar = PillButtonBar(pillButtonStyle: .primary)
    var pillBarProjectList: [PillButtonBarItem] = []
    
    // Constants
    static let margin: CGFloat = 16
    static let horizontalSpacing: CGFloat = 40
    static let verticalSpacing: CGFloat = 16
    static let rowTextWidth: CGFloat = 75
    
    // Charts
    lazy var lineChartView: LineChartView = { return LineChartView() }()
    lazy var tinyPieChartView: PieChartView = { return PieChartView() }()
    var navigationPieChartView: PieChartView?
    var shouldHideData: Bool = false
    var tinyPieChartSections: [String] = ["Done", "In Progress", "Not Started", "Overdue"]
    
    // Calendar and FluentUI TableView
    var calendar: FSCalendar!
    // Removed main tableView - using only FluentUI table now
    
    // Legacy properties removed - sampleTableView and sampleData
    // var sampleTableView = UITableView(frame: .zero, style: .grouped)
    // var sampleData: [(String, [NTask])] = []
    
    // FluentUI To Do TableView Controller
    var fluentToDoTableViewController: FluentUIToDoTableViewController?
    
    // View state
    var projectForTheView = ProjectManager.sharedInstance.defaultProject
    var currentViewType = ToDoListViewType.todayHomeView
    var selectedProjectNamesForFilter: [String] = []
    var projectsToDisplayAsSections: [Projects] = []
    var tasksGroupedByProject: [String: [NTask]] = [:]
    
    // Date handling
    var firstDay = Date.today()
    var nextDay = Date.today()
    var dateForTheView = Date.today()
    
    // Scores and labels
    var scoreForTheDay: UILabel! = nil
    let scoreAtHomeLabel = UILabel()
    var scoreCounter = UILabel()
    
    // Bottom app bar
    var bottomAppBar = MDCBottomAppBarView()
    var isCalDown: Bool = false
    var isChartsDown: Bool = false
    
    // Animations
    let toDoAnimations: ToDoAnimations = ToDoAnimations()
    
    
//     State flags
    var isGrouped: Bool = false {
        didSet {
            // Updated to use FluentUI table view
            fluentToDoTableViewController?.tableView.reloadData()
            animateTableViewReload()
        }
    }
    var isBackdropRevealed: Bool = false
    var foredropClosedY: CGFloat = 0
    var revealDistance: CGFloat = 0
    var originalForedropCenterY: CGFloat = .zero // Added (Plan Step K)
    
    // IBOutlets
    @IBOutlet weak var addTaskButton: MDCFloatingButton!
    @IBOutlet weak var darkModeToggle: UISwitch!
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("\n=== HOME VIEW CONTROLLER LOADED ===")
        print("Initial dateForTheView: \(dateForTheView)")
        
        print("=== HOME VIEW CONTROLLER SETUP COMPLETE ===")
        
        // Setup FluentUI Navigation Bar
        setupFluentUINavigationBar()
        
        // Setup notification observers
        notificationCenter.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appTerminated), name: UIApplication.willTerminateNotification, object: nil)
        
        // Configure UI
        dateForTheView = Date.today()
        
        highestPrioritySymbol = (UIImage(systemName: "circle.fill", withConfiguration: ultraLightConfiguration)?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal))!
        highPrioritySymbol = (UIImage(systemName: "circle", withConfiguration: ultraLightConfiguration)?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal))!
        
        self.setupBackdrop()
        view.addSubview(backdropContainer)
        
        view.addSubview(foredropContainer)
        self.setupHomeFordrop()
        
        // Setup and add bottom app bar - it should be the topmost view
        self.setupBottomAppBar()
        view.addSubview(bottomAppBar)
        
        foredropContainer.backgroundColor = todoColors.backgroundColor
        backdropContainer.backgroundColor = UIColor.clear
        
        // Load initial data
        TaskManager.sharedInstance.fixMissingTasksDataWithDefaults()
        ProjectManager.sharedInstance.fixMissingProjecsDataWithDefaults()
        
        // Enable dark mode if preset
        enableDarkModeIfPreset()
        
        // Initial view update
        updateViewForHome(viewType: .todayHomeView)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        
        
        DispatchQueue.main.async { [weak self] in 
            self?.fluentToDoTableViewController?.tableView.reloadData()
            // Animate table view reload
//            self?.animateTableViewReload()
        }

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        shouldAnimateCells = false
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // Reposition bottom app bar with correct safe area insets
        let bottomAppBar = self.bottomAppBar
            let screenWidth = view.bounds.width
            let screenHeight = view.bounds.height
            let barHeight: CGFloat = 64
            let safeAreaBottomInset: CGFloat
            
            if #available(iOS 11.0, *) {
                safeAreaBottomInset = view.safeAreaInsets.bottom
            } else {
                safeAreaBottomInset = 0
            }
            
            // Ensure the bottom bar is properly positioned above the safe area
            bottomAppBar.frame = CGRect(x: 0, 
                                        y: screenHeight - barHeight - safeAreaBottomInset, 
                                        width: screenWidth, 
                                        height: barHeight + safeAreaBottomInset)
    }
    
    deinit {
        notificationCenter.removeObserver(self)
    }
    
    // MARK: - FluentUI Navigation Bar Setup
    
    private func setupFluentUINavigationBar() {
        // Configure navigation item properties
        navigationItem.titleStyle = .largeLeading
        navigationItem.navigationBarStyle = .primary
        navigationItem.navigationBarShadow = .automatic
        
        // Set title
        title = "Today"
        
        // Create search bar accessory
        let searchBar = createSearchBarAccessory()
        navigationItem.accessoryView = searchBar
        
        // Create custom leading button (menu/hamburger)
        let menuButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "line.horizontal.3"),
            style: .plain,
            target: self,
            action: #selector(onMenuButtonTapped)
        )
        menuButtonItem.accessibilityLabel = "Menu"
        navigationItem.leftBarButtonItem = menuButtonItem
        
        // Removed pie chart button from navigation bar
        
        // Enable scroll-to-contract behavior
        // Updated to use FluentUI table view
        navigationItem.contentScrollView = fluentToDoTableViewController?.tableView
    }
    
    private func createSearchBarAccessory() -> SearchBar {
        let searchBar = SearchBar()
        searchBar.style = .onBrandNavigationBar
        searchBar.placeholderText = "Search tasks..."
        searchBar.delegate = self
        return searchBar
    }
    
    private func createPieChartBarButton() -> UIBarButtonItem {
        // Create a container view for the pie chart
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        containerView.backgroundColor = UIColor.clear
        
        // Create a smaller pie chart view for the navigation bar
        let navPieChart = PieChartView(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        
        // Store reference for later updates
        navigationPieChartView = navPieChart
        
        // Setup the navigation pie chart with the same configuration as the main one
        setupPieChartView(pieChartView: navPieChart)
        
        // Make it smaller and more suitable for navigation bar
        navPieChart.holeRadiusPercent = 0.7
        navPieChart.layer.shadowRadius = 4
        navPieChart.layer.shadowOpacity = 0.4
        
        // Ensure the chart is visible above other elements
        navPieChart.layer.zPosition = 1000
        containerView.layer.zPosition = 1000
        navPieChart.backgroundColor = UIColor.clear
        
        // Populate with data
        setNavigationPieChartData()
        
        // Add tap gesture to show/hide charts
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleCharts))
        navPieChart.addGestureRecognizer(tapGesture)
        navPieChart.isUserInteractionEnabled = true
        
        containerView.addSubview(navPieChart)
        
        // Create bar button item with custom view
        let barButtonItem = UIBarButtonItem(customView: containerView)
        barButtonItem.accessibilityLabel = "Charts"
        
        return barButtonItem
    }
    
    // MARK: - Navigation Actions
    
    @objc func onMenuButtonTapped() {
        // Handle menu button tap
        // This might open a side menu or settings panel
        presentSideDrawer()
    }
    

    
    private func setNavigationPieChartData() {
        guard let navPieChart = navigationPieChartView else { return }
        
        let count = 4
        let range: UInt32 = 40
        
        let entries = (0..<count).map { (i) -> PieChartDataEntry in
            let randomValue = Double(arc4random_uniform(range) + range / 5)
            // Ensure value is valid and not NaN or infinite
            let safeValue = randomValue.isNaN || randomValue.isInfinite ? 1.0 : max(1.0, randomValue)
            
            return PieChartDataEntry(value: safeValue,
                                     label: tinyPieChartSections[i % tinyPieChartSections.count],
                                     icon: #imageLiteral(resourceName: "material_done_White"))
        }
        
        let set = PieChartDataSet(entries: entries, label: "")
        set.drawIconsEnabled = false
        set.drawValuesEnabled = false
        set.sliceSpace = 2
        set.colors = ChartColorTemplates.vordiplom()
        
        let data = PieChartData(dataSet: set)
        
        navPieChart.drawEntryLabelsEnabled = false
        navPieChart.data = data
    }
    
    private func presentSideDrawer() {
        // Create the settings page view controller
        let settingsVC = SettingsPageViewController()
        
        // Embed it in a navigation controller for proper navigation
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.navigationBar.prefersLargeTitles = false
        
        // Create the drawer controller with the settings navigation controller
        let controller = DrawerController(sourceView: view, sourceRect: .zero, presentationDirection: .fromLeading)
        controller.contentController = navController
        controller.preferredContentSize.width = 350
        controller.resizingBehavior = .dismiss
        
        present(controller, animated: true)
    }
    
    @objc func AddTaskAction() {
        // Present add task interface
        let addTaskVC = AddTaskViewController()
        addTaskVC.delegate = self
        addTaskVC.modalPresentationStyle = .fullScreen
        present(addTaskVC, animated: true, completion: nil)
    }
    

    
    // MARK: - ChartViewDelegate
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        // Handle chart value selection
    }
    
    // MARK: - MDCRippleTouchControllerDelegate
    
    func rippleTouchController(_ rippleTouchController: MDCRippleTouchController, didProcessRippleView rippleView: MDCRippleView) {
        // Handle ripple touch
    }
    
    // MARK: - Helper method to update view
    
    private func refreshHomeView() {
        // Reload data for current view type
        updateViewForHome(viewType: currentViewType)
        
        // Animate table view reload
        animateTableViewReload()
    }
}

// MARK: - SearchBarDelegate Extension

extension HomeViewController {
    func searchBarDidBeginEditing(_ searchBar: SearchBar) {
        // Handle when search begins
        searchBar.progressSpinner.state.isAnimating = false
    }
    
    func searchBar(_ searchBar: SearchBar, didUpdateSearchText newSearchText: String?) {
        // Handle search text changes
        let searchText = newSearchText?.lowercased() ?? ""
        
        if searchText.isEmpty {
            // Show all tasks when search is empty
            updateViewForHome(viewType: currentViewType)
        } else {
            // Filter tasks based on search text
            filterTasksForSearch(searchText: searchText)
        }
    }
    
    func searchBarDidCancel(_ searchBar: SearchBar) {
        // Handle search cancellation
        searchBar.progressSpinner.state.isAnimating = false
        updateViewForHome(viewType: currentViewType)
    }
    
    func searchBarDidRequestSearch(_ searchBar: SearchBar) {
        // Handle search button tap
        _ = searchBar.resignFirstResponder()
    }
    
    private func filterTasksForSearch(searchText: String) {
        // Get all tasks from TaskManager to search across everything
        let allMorningTasks = TaskManager.sharedInstance.getMorningTasks(for: dateForTheView)
        let allEveningTasks = TaskManager.sharedInstance.getEveningTasksForToday()
        let allTasks = allMorningTasks + allEveningTasks
        
        // Filter tasks based on search text
        let filteredTasks = allTasks.filter { task in
            let searchTextLower = searchText.lowercased()
            return task.name.lowercased().contains(searchTextLower) ||
                   (task.taskDetails?.lowercased().contains(searchTextLower) ?? false) ||
                   (task.project?.lowercased().contains(searchTextLower) ?? false)
        }
        
        // Create filtered sections
        var filteredSections: [ToDoListData.Section] = []
        
        if !filteredTasks.isEmpty {
            // Convert filtered NTask objects to TaskListItem objects
            let filteredTaskItems = filteredTasks.map { task in
                ToDoListData.TaskListItem(
                    text1: task.name,
                    text2: task.taskDetails ?? "",
                    text3: "",
                    image: ""
                )
            }
            
            let searchSection = ToDoListData.Section(
                title: "Search Results (\(filteredTasks.count))",
                taskListItems: filteredTaskItems
            )
            filteredSections.append(searchSection)
        }
        
        ToDoListSections = filteredSections
        // Updated to use FluentUI table view
        fluentToDoTableViewController?.tableView.reloadData()
        animateTableViewReload()
    }
}

// MARK: - AddTaskViewControllerDelegate Extension

extension HomeViewController: AddTaskViewControllerDelegate {
    func didAddTask(_ task: NTask) {
        print("🔄 AddTask: didAddTask called for task: \(task.name) with due date: \(task.dueDate ?? Date() as NSDate)")
        
        // Step 1: Save the Core Data context to ensure the new task is persisted
        do {
            try TaskManager.sharedInstance.context.save()
            print("💾 AddTask: Context saved successfully")
        } catch {
            print("❌ AddTask: Failed to save context: \(error)")
            return // Exit early if save fails
        }
        
        // Step 2: Refresh the context to get the latest data from persistent store
        TaskManager.sharedInstance.context.refreshAllObjects()
        
        // Step 3: Process pending changes to ensure consistency
        TaskManager.sharedInstance.context.processPendingChanges()
        
        // Step 4: Update the view on the main queue
        DispatchQueue.main.async {
            print("🔄 AddTask: Updating view on main queue")
            
            // Compare dates properly using startOfDay to ignore time differences
            let todayStartOfDay = Date.today().startOfDay
            let viewDateStartOfDay = self.dateForTheView.startOfDay
            let taskDueDateStartOfDay = (task.dueDate as Date?)?.startOfDay ?? Date().startOfDay
            
            print("📅 AddTask: Today: \(todayStartOfDay)")
            print("📅 AddTask: View date: \(viewDateStartOfDay)")
            print("📅 AddTask: Task due date: \(taskDueDateStartOfDay)")
            
            // Step 5: Determine the correct view type and update accordingly
            // Ensure the view is updated with the correct date context before reloading data.
            // This will repopulate ToDoListSections which is the datasource for the table.
            if self.currentViewType == .todayHomeView && taskDueDateStartOfDay == todayStartOfDay {
                print("🔄 AddTask: Refreshing TODAY view for a new task due today")
                self.updateViewForHome(viewType: .todayHomeView)
            } else if self.currentViewType == .customDateView && taskDueDateStartOfDay == viewDateStartOfDay {
                print("🔄 AddTask: Refreshing CUSTOM DATE view for a new task due on this custom date: \(self.dateForTheView)")
                self.updateViewForHome(viewType: .customDateView, dateForView: self.dateForTheView)
            } else if self.currentViewType == .allProjectsGrouped {
                 print("🔄 AddTask: Refreshing ALL PROJECTS GROUPED view")
                 self.updateViewForHome(viewType: .allProjectsGrouped)
            } else if self.currentViewType == .projectView {
                print("🔄 AddTask: Refreshing PROJECT view for project: \(self.projectForTheView)")
                 self.updateViewForHome(viewType: .projectView)
            } else {
                // Fallback: If the task is for today and current view is today, refresh today view.
                // Otherwise, if task is for the currently viewed date, refresh that.
                // This handles cases where currentViewType might not be explicitly today/custom but the new task is relevant.
                if taskDueDateStartOfDay == todayStartOfDay {
                     print("🔄 AddTask: Fallback - Refreshing TODAY view as task is for today")
                     self.updateViewForHome(viewType: .todayHomeView)
                } else if taskDueDateStartOfDay == viewDateStartOfDay {
                    print("🔄 AddTask: Fallback - Refreshing CUSTOM DATE view as task is for \(self.dateForTheView)")
                    self.updateViewForHome(viewType: .customDateView, dateForView: self.dateForTheView)
                } else {
                    print("ℹ️ AddTask: New task is not for the current view's date (Today or \(viewDateStartOfDay)). Current view might not immediately show it unless it's an 'All Tasks' or relevant project view.")
                    // Optionally, you could switch the view to the task's due date if desired UX
                    // For now, we just ensure the current view is refreshed based on its existing context.
                    // The task will appear if the user navigates to its due date or an encompassing view.
                    self.updateViewForHome(viewType: self.currentViewType, dateForView: self.dateForTheView) // Refresh current view
                }
            }
            
            // Step 6: Force reload the table view to ensure UI is updated with the potentially new data from updateViewForHome
            print("🔄 AddTask: Reloading table data")
            // Sync FluentUI table data with updated tasks
            self.fluentToDoTableViewController?.updateData(for: self.dateForTheView)
            self.fluentToDoTableViewController?.tableView.reloadData()
            
            // Step 7: Check if the new task should be visible in current view (logging purpose)
            if taskDueDateStartOfDay == viewDateStartOfDay {
                print("✅ AddTask: New task *should* be visible if current view is for \(viewDateStartOfDay)")
            } else {
                print("ℹ️ AddTask: New task due on \(taskDueDateStartOfDay) won't appear in view for \(viewDateStartOfDay) unless it's a broader view type (e.g., All Tasks).")
            }
            
            print("🔄 AddTask: View update completed")
        }
    }
}
