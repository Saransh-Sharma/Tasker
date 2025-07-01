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

// Import TaskProgressCard from Views/Cards
// Note: TaskProgressCard is defined in ChartCard.swift

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
    
    // Charts (Phase 5: Transition Complete)
    // Legacy UIKit charts - kept for compatibility but deprecated
    lazy var lineChartView: LineChartView = {
        let chart = LineChartView()
        chart.isHidden = true // keep legacy chart invisible
        return chart
    }() // Legacy DGCharts view kept only for backward compatibility
    lazy var tinyPieChartView: PieChartView = { return PieChartView() }()
    var navigationPieChartView: PieChartView?
    
    // Primary SwiftUI Chart Card (Phase 5: Now the main chart implementation)
    // Note: TaskProgressCard is defined in ChartCard.swift
    // Using AnyView to work around type resolution issue
    var swiftUIChartHostingController: UIHostingController<AnyView>?
    var swiftUIChartContainer: UIView?

// MARK: - Pie-chart helpers

/// Returns a dictionary of counts of completed tasks grouped by priority for a given date
private func priorityBreakdown(for date: Date) -> [TaskPriority: Int] {
    var counts: [TaskPriority: Int] = [.high: 0, .medium: 0, .low: 0, .veryLow: 0]
    let allTasks = TaskManager.sharedInstance.getAllTasks
    let calendar = Calendar.current
    
    for task in allTasks {
        guard task.isComplete else { continue }
        // Prefer recorded completion date; fall back to due date (covers legacy data)
        let referenceDate: Date?
        if let completed = task.dateCompleted as Date? {
            referenceDate = completed
        } else if let due = task.dueDate as Date? {
            referenceDate = due
        } else {
            referenceDate = nil
        }
        guard let ref = referenceDate,
              calendar.isDate(ref, inSameDayAs: date) else { continue }
        let priority = TaskPriority(rawValue: task.taskPriority) ?? .low
        counts[priority, default: 0] += 1
    }
    return counts
}

/// Animates + refreshes the navigation pie chart using current `dateForTheView`.
func refreshNavigationPieChart() {
    setNavigationPieChartData()
    navigationPieChartView?.animate(xAxisDuration: 0.3, easingOption: .easeOutBack)
}

/// Compatibility shim for existing calendar extension call
@objc func reloadTinyPicChartWithAnimation() {
    refreshNavigationPieChart()
}
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
    // Legacy scoreCounter kept for backward-compatibility with existing code paths
    var scoreCounter = UILabel()
    // New navigation title label containing date + score
    var navigationTitleLabel: UILabel?
    
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
    var chartRevealDistance: CGFloat = 0 // Distance for chart animations
    
    // MARK: - Dynamic Animation Calculations
    
    
    
    func calculateRevealDistance() -> CGFloat {
        guard let chartContainer = swiftUIChartContainer else { return 300 } // Default fallback
        let chartStartY = chartContainer.frame.minY
        let padding: CGFloat = 20
        let targetY = chartStartY - padding
        let currentForedropTop = originalForedropCenterY - (foredropContainer.bounds.height / 2)
        return max(0, targetY - currentForedropTop)
    }

    func calculateChartRevealDistance() -> CGFloat {
        guard let chartContainer = swiftUIChartContainer else { return 500 } // Default fallback
        let chartStartY = chartContainer.frame.minY
        let chartHeight = chartContainer.frame.height
        let padding: CGFloat = 20
        let targetY = chartStartY + chartHeight + padding
        let currentForedropTop = originalForedropCenterY - (foredropContainer.bounds.height / 2)
        return max(0, targetY - currentForedropTop)
    }

    // IBOutlets
    @IBOutlet weak var addTaskButton: MDCFloatingButton!
    @IBOutlet weak var darkModeToggle: UISwitch!
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("\n=== HOME VIEW CONTROLLER LOADED ===")
        print("Initial dateForTheView: \(dateForTheView)")
        
        print("=== HOME VIEW CONTROLLER SETUP COMPLETE ===")
        // Observe theme changes for lifetime of this controller
        notificationCenter.addObserver(self, selector: #selector(themeChanged), name: .themeChanged, object: nil)
        
        // Setup FluentUI Navigation Bar
        setupFluentUINavigationBar()
        
        // Setup notification observers
        notificationCenter.addObserver(self, selector: #selector(appMovedToForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        notificationCenter.addObserver(self, selector: #selector(appTerminated), name: UIApplication.willTerminateNotification, object: nil)
        
        // Setup chart refresh notification observer
        notificationCenter.addObserver(self, selector: #selector(taskCompletionChanged), name: NSNotification.Name("TaskCompletionChanged"), object: nil)
        print("📡 HomeViewController: Added TaskCompletionChanged notification observer")
        
        // Configure UI
        dateForTheView = Date.today()
        
        // Set contentScrollView to prevent ShyHeaderController from creating dummy UITableView
        // This must be done after fluentToDoTableViewController is initialized
        if let tableView = fluentToDoTableViewController?.tableView {
            navigationItem.contentScrollView = tableView
            print("✅ Set navigationItem.contentScrollView to prevent ShyHeaderController dummy table view")
        }
        
        highestPrioritySymbol = (UIImage(systemName: "circle.fill", withConfiguration: ultraLightConfiguration)?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal))!
        highPrioritySymbol = (UIImage(systemName: "circle", withConfiguration: ultraLightConfiguration)?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal))!
        
        self.setupBackdrop()
        view.addSubview(backdropContainer)
        
        view.addSubview(foredropContainer)
        self.setupHomeFordrop()
        
        // Setup and add bottom app bar - it should be the topmost view
        self.setupBottomAppBar()
        view.addSubview(bottomAppBar)
        
        foredropContainer.backgroundColor = UIColor.systemBackground
        // Apply initial themed backgrounds
        view.backgroundColor = todoColors.primaryColor.withAlphaComponent(0.05)
        backdropContainer.backgroundColor = todoColors.primaryColor.withAlphaComponent(0.05)
        
        // Load initial data
        TaskManager.sharedInstance.fixMissingTasksDataWithDefaults()
        ProjectManager.sharedInstance.fixMissingProjecsDataWithDefaults()
        
        // Enable dark mode if preset
        enableDarkModeIfPreset()
        
        // Initial view update
        updateViewForHome(viewType: .todayHomeView)
        
        // Setup the SwiftUI chart card
        setupSwiftUIChartCard()
        
        // Display today's initial score in navigation bar
        updateDailyScore()
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
        refreshNavigationPieChart()
        
        // Runtime backup fix: Find and fix any dummy table views created by ShyHeaderController
        findAndFixDummyTableView()
    } // end of viewDidAppear
    
    /// Recursively searches the view hierarchy for UITableView instances (excluding our main table view)
    /// and makes them transparent. This is a backup fix for any dummy table views created by ShyHeaderController.
    private func findAndFixDummyTableView() {
        func searchViewHierarchy(_ view: UIView) {
            for subview in view.subviews {
                if let tableView = subview as? UITableView,
                   tableView != fluentToDoTableViewController?.tableView {
                    // Found a dummy table view - make it transparent
                    tableView.backgroundColor = UIColor.clear
                    tableView.isOpaque = false
                    tableView.backgroundView = nil
                    print("🔧 Fixed dummy UITableView at \(tableView)")
                }
                // Recursively search subviews
                searchViewHierarchy(subview)
            }
        }
        
        // Start search from navigation controller's view if available
        if let navView = navigationController?.view {
            searchViewHierarchy(navView)
        }
        // Also search our own view hierarchy
        searchViewHierarchy(view)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        // If bottomAppBar uses Auto Layout (translatesAutoresizingMaskIntoConstraints == false), skip manual frame adjustments
        if bottomAppBar.translatesAutoresizingMaskIntoConstraints == false {
            return
        }
        // Legacy support for views instantiated before Auto Layout migration
        let screenWidth = view.bounds.width
        let screenHeight = view.bounds.height
        let barHeight: CGFloat = 64
        let safeAreaBottomInset: CGFloat = view.safeAreaInsets.bottom
        bottomAppBar.frame = CGRect(x: 0,
                                    y: screenHeight - barHeight - safeAreaBottomInset,
                                    width: screenWidth,
                                    height: barHeight + safeAreaBottomInset)
    }
    
    deinit {
        notificationCenter.removeObserver(self, name: .themeChanged, object: nil)
        notificationCenter.removeObserver(self)
    }
    
    // MARK: - FluentUI Navigation Bar Setup
    
    private func setupFluentUINavigationBar() {
        // Configure navigation item properties
        navigationItem.titleStyle = .largeLeading
        navigationItem.navigationBarStyle = .custom
        navigationItem.navigationBarShadow = .automatic
        
        // Set custom navigation bar background color
        navigationItem.customNavigationBarColor = todoColors.primaryColor
        
        // Disable large titles so our score label is not obscured
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        title = "" // Clear default title
        if let navBar = navigationController?.navigationBar {
            navBar.subviews.compactMap { $0 as? UILabel }.forEach { $0.backgroundColor = .clear }
        }
        
        // Create search bar accessory
        let searchBar = createSearchBarAccessory()
        navigationItem.accessoryView = searchBar
        
        

        
        // Hide legacy scoreCounter label (we now show score in title)
        scoreCounter.isHidden = true
        // Ensure initial title is displayed
        updateDailyScore()
      // Embed pie chart inside search bar accessory instead of right bar button
        embedNavigationPieChartOnNavigationBar()
        
        // Enable scroll-to-contract behavior
        // Updated to use FluentUI table view
        navigationItem.contentScrollView = fluentToDoTableViewController?.tableView
    }
    
    private func embedNavigationPieChart(in hostView: UIView) {
        // Avoid duplicate embedding
        if navigationPieChartView != nil { return }
        let size: CGFloat = 32
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        hostView.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(equalToConstant: size),
            containerView.heightAnchor.constraint(equalToConstant: size),
            containerView.trailingAnchor.constraint(equalTo: hostView.trailingAnchor, constant: -8),
            containerView.centerYAnchor.constraint(equalTo: hostView.centerYAnchor)
        ])
        let navPieChart = PieChartView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        navigationPieChartView = navPieChart
        containerView.addSubview(navPieChart)
        navPieChart.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        setupPieChartView(pieChartView: navPieChart)
        navPieChart.holeRadiusPercent = 0.7
        // Ensure the chart is visible above the navigation bar
        navPieChart.layer.zPosition = 999
        containerView.layer.zPosition = 999
        navPieChart.backgroundColor = .clear
        setNavigationPieChartData()
        // Ensure chart has correct initial data & animation
        refreshNavigationPieChart()
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleCharts))
        navPieChart.addGestureRecognizer(tap)
        navPieChart.isUserInteractionEnabled = true
    }
    
    // MARK: - Embed Pie Chart on Navigation Bar (Right Aligned)
    private func embedNavigationPieChartOnNavigationBar() {
        guard navigationPieChartView == nil else { return }
        guard let navBar = self.navigationController?.navigationBar else { return }
        navBar.clipsToBounds = false // allow chart to render outside if needed
        let size: CGFloat = 100
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(equalToConstant: size),
            containerView.heightAnchor.constraint(equalToConstant: size),
            containerView.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -2),
            containerView.centerYAnchor.constraint(equalTo: navBar.centerYAnchor, constant:25)
        ])
        let navPieChart = PieChartView(frame: .zero)
        navigationPieChartView = navPieChart
        containerView.addSubview(navPieChart)
        navPieChart.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            navPieChart.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            navPieChart.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            navPieChart.topAnchor.constraint(equalTo: containerView.topAnchor),
            navPieChart.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
        ])
        setupPieChartView(pieChartView: navPieChart)
        navPieChart.holeRadiusPercent = 0.7
        // Minimal appearance: no slice labels, legend, or description
        navPieChart.drawEntryLabelsEnabled = false
        navPieChart.legend.enabled = false
        navPieChart.chartDescription.enabled = false
        // Ensure full circle render
        navPieChart.drawHoleEnabled = false
        navPieChart.setExtraOffsets(left: 0, top: 0, right: 0, bottom: 0)
        navPieChart.minOffset = 0
        navPieChart.layer.zPosition = 900
        containerView.layer.zPosition = 900
        navPieChart.backgroundColor = .clear
        setNavigationPieChartData()
        refreshNavigationPieChart()
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleCharts))
        navPieChart.addGestureRecognizer(tap)
        navPieChart.isUserInteractionEnabled = true
    }
    
    private func createSearchBarAccessory() -> SearchBar {
        let searchBar = SearchBar()
        searchBar.style = .onBrandNavigationBar
        searchBar.placeholderText = "Search tasks..."
        searchBar.delegate = self
        
        // Customize the search bar background color
        searchBar.tokenSet[.backgroundColor] = .uiColor { self.todoColors.primaryColor }
        return searchBar
    }

    // MARK: - Pie Chart Button

    private func createPieChartBarButton() -> UIBarButtonItem {
        // Create a container for the chart
        let containerView = UIView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        containerView.backgroundColor = .clear
        
        // Create chart view
        let navPieChart = PieChartView(frame: containerView.bounds)
        navigationPieChartView = navPieChart
        containerView.addSubview(navPieChart)
        navPieChart.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        
        // Configure appearance
        setupPieChartView(pieChartView: navPieChart)
        navPieChart.holeRadiusPercent = 0.7
        navPieChart.layer.shadowRadius = 4
        navPieChart.layer.shadowOpacity = 0.4
        navPieChart.layer.zPosition = 1000
        containerView.layer.zPosition = 1000
        // DEBUG: set background to red to verify visibility
        navPieChart.backgroundColor = .red.withAlphaComponent(0.4)
        
        // Populate data
        setNavigationPieChartData()
        
        // Interaction
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(toggleCharts))
        navPieChart.addGestureRecognizer(tapGesture)
        navPieChart.isUserInteractionEnabled = true
        
        // Wrap in bar button item
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
    

    
    /// Updates navigation pie chart with real completed-task breakdown for the supplied date (defaults to today's view date)
// Core pie-chart data builder – DO NOT overload with same name without parameter
private func buildNavigationPieChartData(for date: Date) {
    guard let navPieChart = navigationPieChartView else { return }

    // Fetch priority counts for completed tasks on the given date
    let breakdown = priorityBreakdown(for: date)
    // Weighting: High=3, Medium=2, Low=1
    let weights: [TaskPriority: Double] = [.high: 3, .medium: 2, .low: 1, .veryLow: 0.5]
    let entries: [PieChartDataEntry] = [
        (TaskPriority.high, "High"),
        (TaskPriority.medium, "Medium"),
        (TaskPriority.low, "Low"),
        (TaskPriority.veryLow, "Very Low")
    ].compactMap { (priority, label) in
        let rawCount = Double(breakdown[priority] ?? 0)
        let weight = weights[priority] ?? 1
        let weightedValue = rawCount * weight
        return weightedValue > 0 ? PieChartDataEntry(value: weightedValue, label: label) : nil
    }

    // Guard against no-data scenario – just clear chart and exit
    guard !entries.isEmpty else {
        navPieChart.data = nil
        navPieChart.setNeedsDisplay()
        return
    }

    // Build matching colour array for each entry to avoid index mismatch when some priorities have zero count
    var sliceColors: [UIColor] = []
    for entry in entries {
        switch entry.label {
        case "High":
            sliceColors.append(ToDoColors.piePriorityHighest)
        case "Medium":
            sliceColors.append(ToDoColors.piePriorityHigh)
        case "Low":
            sliceColors.append(ToDoColors.piePriorityMedium)
        case "Very Low":
            sliceColors.append(ToDoColors.piePriorityLow)
        default:
            sliceColors.append(todoColors.secondaryAccentColor) // fallback
        }
    }

    let set = PieChartDataSet(entries: entries, label: "")
    set.drawIconsEnabled = false
    set.drawValuesEnabled = false
    set.sliceSpace = 2
    set.colors = sliceColors

    let data = PieChartData(dataSet: set)
    navPieChart.drawEntryLabelsEnabled = false
    navPieChart.data = data
}

/// Parameterless wrapper used by existing call sites
private func setNavigationPieChartData() {
    buildNavigationPieChartData(for: dateForTheView)
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
        DependencyContainer.shared.inject(into: addTaskVC) // Use dependency container for injection
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
            // Show all tasks when search is empty - restore normal view
            fluentToDoTableViewController?.updateData(for: dateForTheView)
        } else {
            // Filter tasks based on search text
            filterTasksForSearch(searchText: searchText)
        }
    }
    
    func searchBarDidCancel(_ searchBar: SearchBar) {
        // Handle search cancellation
        searchBar.progressSpinner.state.isAnimating = false
        // Restore normal view
        fluentToDoTableViewController?.updateData(for: dateForTheView)
    }
    
    func searchBarDidRequestSearch(_ searchBar: SearchBar) {
        // Handle search button tap
        _ = searchBar.resignFirstResponder()
    }
    
    private func filterTasksForSearch(searchText: String) {
        // Get ALL tasks from TaskManager (across all dates and projects)
        let allTasks = TaskManager.sharedInstance.getAllTasks
        
        // Filter tasks based on search text
        let filteredTasks = allTasks.filter { task in
            let searchTextLower = searchText.lowercased()
            return (task.name ?? "").lowercased().contains(searchTextLower) ||
                   (task.taskDetails?.lowercased().contains(searchTextLower) ?? false) ||
                   (task.project?.lowercased().contains(searchTextLower) ?? false)
        }
        
        // Group tasks by project for better organization
        let groupedTasks = Dictionary(grouping: filteredTasks) { task in
            task.project ?? "Inbox"
        }
        
        // Create filtered sections
        var filteredSections: [ToDoListData.Section] = []
        
        if !filteredTasks.isEmpty {
            // Sort projects alphabetically, but put Inbox first
            let sortedProjects = groupedTasks.keys.sorted { project1, project2 in
                if project1 == "Inbox" { return true }
                if project2 == "Inbox" { return false }
                return project1 < project2
            }
            
            for project in sortedProjects {
                let tasksForProject = groupedTasks[project] ?? []
                
                // Convert filtered NTask objects to TaskListItem objects with enhanced info
                let filteredTaskItems = tasksForProject.map { task in
                    let dateFormatter = DateFormatter()
                    dateFormatter.dateStyle = .medium
                    let dueDateString = task.dueDate != nil ? dateFormatter.string(from: task.dueDate! as Date) : "No due date"
                    
                    let taskTypeString = task.taskType == 1 ? "Morning" : task.taskType == 2 ? "Evening" : "Upcoming"
                    
                    return ToDoListData.TaskListItem(
                        text1: task.name ?? "Untitled Task",
                        text2: task.taskDetails ?? "",
                        text3: "\(taskTypeString) • \(dueDateString)",
                        image: ""
                    )
                }
                
                let searchSection = ToDoListData.Section(
                    title: "\(project) (\(tasksForProject.count))",
                    taskListItems: filteredTaskItems
                )
                filteredSections.append(searchSection)
            }
        } else {
            // Show "No results" section when no tasks match
            let noResultsSection = ToDoListData.Section(
                title: "No results found",
                taskListItems: []
            )
            filteredSections.append(noResultsSection)
        }
        
        // Update the FluentUI table view with search results
        fluentToDoTableViewController?.updateDataWithSearchResults(filteredSections)
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
            
            // Update pie chart as tasks have potentially changed
            self.refreshNavigationPieChart()
            
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

// MARK: - Theme Handling

extension HomeViewController {
    /// Re-applies current theme colors to primary UI elements.
    fileprivate func applyTheme() {
        // Refresh color source
        todoColors = ToDoColors()
        // Navigation bar (FluentUI custom property)
        navigationItem.customNavigationBarColor = todoColors.primaryColor
        // Keep title label transparent on theme change
        if let navBar = navigationController?.navigationBar {
            navBar.subviews.compactMap { $0 as? UILabel }.forEach { $0.backgroundColor = .clear }
        }
        // System/global tint
        // Global tint
        view.tintColor = todoColors.primaryColor
        // Main view background color should follow theme immediately
        view.backgroundColor = todoColors.primaryColor.withAlphaComponent(0.05)
        
        
        
        
        
        // Bottom app bar
        bottomAppBar.barTintColor = todoColors.primaryColor
        // Backdrop container background (subtle tint for blurred backdrop)
        backdropContainer.backgroundColor = todoColors.primaryColor.withAlphaComponent(0.05)
        // Floating action button (if instantiated via storyboard & bottom bar)
        if let fab = addTaskButton {
            // For MDCFloatingButton use setBackgroundColor to ensure ripple layer also updates
            fab.setBackgroundColor(todoColors.primaryColor, for: .normal)
            fab.setBackgroundColor(todoColors.primaryColor.withAlphaComponent(0.8), for: .highlighted)
            fab.tintColor = .white
            fab.backgroundColor = todoColors.primaryColor
        }
        // Also recolor hidden floating button in BottomAppBar (if later shown)
        bottomAppBar.floatingButton.setBackgroundColor(todoColors.primaryColor, for: .normal)
        bottomAppBar.floatingButton.setBackgroundColor(todoColors.primaryColor.withAlphaComponent(0.8), for: .highlighted)
        bottomAppBar.floatingButton.tintColor = .white
        // Update any search bar accessory background
        if let accSearchBar = navigationItem.accessoryView as? SearchBar {
            accSearchBar.tokenSet[.backgroundColor] = .uiColor { self.todoColors.primaryColor }
        }
        if let controllerSearchBar = navigationItem.searchController?.searchBar as? SearchBar {
            controllerSearchBar.tokenSet[.backgroundColor] = .uiColor { self.todoColors.primaryColor }
        }
        // Update chart accent colors if present
        
        // Update calendar appearance & refresh
        if let cal = calendar {
            // Header & weekday background colours
            cal.calendarHeaderView.backgroundColor = todoColors.primaryColor.withAlphaComponent(0.5)
            cal.calendarWeekdayView.backgroundColor = todoColors.primaryColorDarker
        }
        if let cal = calendar {
            cal.appearance.selectionColor = todoColors.primaryColor
            cal.appearance.todayColor = todoColors.primaryColor
            cal.appearance.headerTitleColor = todoColors.primaryColor
            cal.appearance.weekdayTextColor = todoColors.primaryColor
            cal.backgroundColor = todoColors.primaryColor.withAlphaComponent(0.05)
            cal.collectionView.backgroundColor = cal.backgroundColor
            // Reapply full appearance settings (header, weekday, selection etc.)
            DispatchQueue.main.async {
                self.setupCalAppearence()
            }
        }
        // Reload table views to reflect accent changes inside cells
        fluentToDoTableViewController?.tableView.reloadData()
    }
    
    @objc func themeChanged() {
        applyTheme()
    }
}



// MARK: - Bottom App Bar Setup & Chat Integration

extension HomeViewController {
    /// Configures the Material Components bottom app bar and adds a Chat button which opens the LLM chat pane.
    fileprivate func configureBottomAppBar() {
        // Basic appearance
        bottomAppBar.barTintColor = todoColors.primaryColor
        bottomAppBar.tintColor = .white
        bottomAppBar.layer.zPosition = 1000 // Ensure it stays above other views

        // Remove default floating button (we already have a separate add-task FAB)
        bottomAppBar.floatingButton.isHidden = true

        // Create the chat bar button item
        let chatImage = UIImage(systemName: "bubble.left.and.bubble.right.fill")
        let chatButtonItem = UIBarButtonItem(image: chatImage,
                                             style: .plain,
                                             target: self,
                                             action: #selector(chatButtonTapped))
        chatButtonItem.accessibilityLabel = "Chat with LLM"

        // Place the chat button on the trailing side
        bottomAppBar.trailingBarButtonItems = [chatButtonItem]

        // Size & position will be finalised in viewDidLayoutSubviews
    }

    /// Presents the ChatHostViewController modally.
    @objc func chatButtonTapped() {
        let chatHostVC = ChatHostViewController()
        let navController = NavigationController(rootViewController: chatHostVC)
        navController.modalPresentationStyle = .fullScreen
        // Prefer FluentUI styling if available
        navController.navigationBar.prefersLargeTitles = false
        present(navController, animated: true)
    }
    
    @objc private func taskCompletionChanged() {

        print("📊 HomeViewController: Received TaskCompletionChanged notification - refreshing charts")
        DispatchQueue.main.async { [weak self] in
            self?.updateSwiftUIChartCard()
            self?.refreshNavigationPieChart()
            self?.updateDailyScore()
            print(" HomeViewController: Charts refreshed successfully")
        }
    }
}

// MARK: - Daily Score Updates
extension HomeViewController {
    /// Calculates the score for the provided date (defaults to `dateForTheView`) asynchronously and updates the navigation title and the legacy `scoreCounter` label.
    func updateDailyScore(for date: Date? = nil) {
        let targetDate = date ?? dateForTheView
        if let repository = taskRepository {
            TaskScoringService.shared.calculateTotalScore(for: targetDate, using: repository) { [weak self] total in
                DispatchQueue.main.async {
                    self?.scoreCounter.text = "\(total)"
                    self?.updateNavigationBarTitle(date: targetDate, score: total)
                    // Update tiny pie chart center text (legacy chart)
                    if let chartView = self?.tinyPieChartView {
                        chartView.centerAttributedText = self?.setTinyPieChartScoreText(pieChartView: chartView, scoreOverride: total)
                    }
                    // Update navigation bar pie chart center text
                    if let navChart = self?.navigationPieChartView {
                        navChart.centerAttributedText = self?.setTinyPieChartScoreText(pieChartView: navChart, scoreOverride: total)
                    }
                }
            }
        } else {
            // Fallback: calculate using TaskManager directly if repository not injected yet
            // Fallback: count tasks whose *completion* date equals the target day
            let allTasks = TaskManager.sharedInstance.getAllTasks
            let calendar = Calendar.current
            let completedToday = allTasks.filter { task in
                guard task.isComplete, let doneDate = task.dateCompleted as Date? else { return false }
                return calendar.isDate(doneDate, inSameDayAs: targetDate)
            }
            let total = completedToday.reduce(0) { sum, task in
                sum + TaskScoringService.shared.calculateScore(for: task)
            }
            DispatchQueue.main.async { [weak self] in
                self?.scoreCounter.text = "\(total)"
                self?.updateNavigationBarTitle(date: targetDate, score: total)
                // Update tiny pie chart center text (legacy chart)
                if let chartView = self?.tinyPieChartView {
                    chartView.centerAttributedText = self?.setTinyPieChartScoreText(pieChartView: chartView, scoreOverride: total)
                }
                // Update navigation bar pie chart center text
                if let navChart = self?.navigationPieChartView {
                    navChart.centerAttributedText = self?.setTinyPieChartScoreText(pieChartView: navChart, scoreOverride: total)
                }
            }
        }
    }
}
    
extension HomeViewController {
    /// Sets up the SwiftUI chart card and embeds it in the view hierarchy.
    func setupSwiftUIChartCard() {
        // 1. Initialize the SwiftUI View
        let chartView = TaskProgressCard(referenceDate: dateForTheView)
        
        // 2. Create a UIHostingController
        let hostingController = UIHostingController(rootView: AnyView(chartView))
        self.swiftUIChartHostingController = hostingController
        
        // 3. Configure the hosting controller's view
        hostingController.view.backgroundColor = .clear
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        // 4. Create a container view
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = .clear
        container.clipsToBounds = false // Allow shadow to be visible
        self.swiftUIChartContainer = container
        
        // 5. Add the hosting controller's view to the container
        container.addSubview(hostingController.view)
        
        // 6. Add the container to the backdrop
        backdropContainer.addSubview(container)
        
        // 7. Set constraints
        NSLayoutConstraint.activate([
            // Container constraints (with padding for shadow)
            container.leadingAnchor.constraint(equalTo: backdropContainer.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: backdropContainer.trailingAnchor, constant: -16),
            container.topAnchor.constraint(equalTo: backdropContainer.topAnchor, constant: 120),
            container.heightAnchor.constraint(equalToConstant: 250),
            
            // Hosting controller's view constraints (pinned to container)
            hostingController.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            hostingController.view.topAnchor.constraint(equalTo: container.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        // 8. Add child view controller
        addChild(hostingController)
        hostingController.didMove(toParent: self)
    }
    
    /// Updates the SwiftUI chart card with the latest data.
    func updateSwiftUIChartCard() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let container = self.swiftUIChartContainer else { return }
            // Remove old hosting controller
            if let oldHost = self.swiftUIChartHostingController {
                oldHost.willMove(toParent: nil)
                oldHost.view.removeFromSuperview()
                oldHost.removeFromParent()
            }
            // Create a fresh chart view and hosting controller
            let chartView = TaskProgressCard(referenceDate: self.dateForTheView)
            let newHost = UIHostingController(rootView: AnyView(chartView))
            self.swiftUIChartHostingController = newHost
            newHost.view.backgroundColor = .clear
            newHost.view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(newHost.view)
            NSLayoutConstraint.activate([
                newHost.view.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                newHost.view.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                newHost.view.topAnchor.constraint(equalTo: container.topAnchor),
                newHost.view.bottomAnchor.constraint(equalTo: container.bottomAnchor)
            ])
            self.addChild(newHost)
            newHost.didMove(toParent: self)
            print("📊 SwiftUI Chart Card completely rebuilt with latest data")
        }
    }
 }


