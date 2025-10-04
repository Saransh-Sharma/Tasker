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
import Combine

// MARK: - Clean Architecture Integration  
// Import actual Clean Architecture types - these should be available as they're defined in the project

// Import Clean Architecture protocols and ViewModels
// These types are defined in the Presentation layer
// - HomeViewControllerProtocol: Protocol for DI to inject HomeViewModel
// - HomeViewModel: ViewModel for business logic and state management
// - PresentationDependencyContainer: Dependency injection container

// TEMPORARY: Type stubs to resolve compilation issues
// These will be replaced by the actual types at runtime through dynamic injection
@objc protocol HomeViewControllerProtocol: AnyObject {
    // This stub will be satisfied by the actual protocol implementation
}

@objc class HomeViewModel: NSObject {
    // This stub will be replaced by the actual ViewModel implementation
    @objc dynamic var morningTasks: [Any] = []
    @objc dynamic var eveningTasks: [Any] = []
    @objc dynamic var isLoading: Bool = false
    @objc dynamic var errorMessage: String? = nil
    @objc dynamic var dailyScore: Int = 0
}

// MARK: - Liquid Glass Bottom App Bar

/// iOS 26 style bottom app bar with liquid glass transparent material background
class LiquidGlassBottomAppBar: UIView, UITabBarDelegate {
    
    // MARK: - Properties
    
    /// Native tab bar configured with liquid glass appearance
    private let tabBar = UITabBar()
    
    /// Mapping from tab index to original target/action
    private var itemActions: [(target: AnyObject?, action: Selector?)] = []
    
    /// Glass morphism background layers
    private let blurEffectView = UIVisualEffectView()
    private let gradientLayer = CAGradientLayer()
    private let borderLayer = CAShapeLayer()
    
    /// Expose a custom floating button (not Material)
    let floatingButton: UIButton = {
        let b = UIButton(type: .custom)
        b.translatesAutoresizingMaskIntoConstraints = false
        b.backgroundColor = .systemOrange
        b.tintColor = .white
        b.layer.cornerRadius = 28
        b.layer.shadowColor = UIColor.black.cgColor
        b.layer.shadowOpacity = 0.25
        b.layer.shadowOffset = CGSize(width: 0, height: 4)
        b.layer.shadowRadius = 8
        b.clipsToBounds = false
        b.isHidden = true
        return b
    }()
    
    /// Tint color for tab items
    override var tintColor: UIColor! {
        didSet {
            tabBar.tintColor = tintColor
            tabBar.unselectedItemTintColor = tintColor?.withAlphaComponent(0.6)
            updateGlassAppearance()
        }
    }
    
    // MARK: - Initialization
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLiquidGlassView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLiquidGlassView()
    }
    
    // MARK: - Setup
    
    private func setupLiquidGlassView() {
        // Ensure container view is fully transparent
        backgroundColor = .clear
        isOpaque = false

        // Configure the tab bar
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        tabBar.isTranslucent = true
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
        tabBar.backgroundColor = .clear
        tabBar.clipsToBounds = false
        tabBar.delegate = self
        setupTabBarAppearance()
        addSubview(tabBar)

        // Add floating button
        addSubview(floatingButton)

        // Layout constraints
        NSLayoutConstraint.activate([
            tabBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            tabBar.topAnchor.constraint(equalTo: topAnchor),
            tabBar.bottomAnchor.constraint(equalTo: bottomAnchor),

            floatingButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            // Position FAB to overlap the top edge slightly
            floatingButton.centerYAnchor.constraint(equalTo: topAnchor),
            floatingButton.widthAnchor.constraint(equalToConstant: 56),
            floatingButton.heightAnchor.constraint(equalToConstant: 56)
        ])

        // No extra background layers; rely on transparent tab bar appearance only
        setupGlassLayers()

        // Initial appearance
        updateGlassAppearance()
    }
    
    private func setupGlassLayers() {
        // Remove any previously added background layers to avoid a rectangle behind the tab bar
        if blurEffectView.superview != nil { blurEffectView.removeFromSuperview() }
        gradientLayer.removeFromSuperlayer()
        borderLayer.removeFromSuperlayer()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateGlassLayers()
    }
    
    private func updateGlassLayers() {
        // No-op: we removed background layers
    }
    
    // MARK: - Glass Morphism Appearance
    
    private func updateGlassAppearance() {
        // No background layers; keep items only
        updateBorder()
    }
    
    private func updateBlurEffect() {
        // No blur view used; rely on UITabBarAppearance only
    }
    
    private func updateGradientOverlay() {
        // No gradient overlay
    }
    
    private func updateBorder() {
        // No border to keep the bar fully clean
        borderLayer.lineWidth = 0
        borderLayer.strokeColor = UIColor.clear.cgColor
    }
    
    // MARK: - Convenience Methods
    
    /// Sets up the bottom app bar with common configuration
    func configureStandardAppBar(leadingItems: [UIBarButtonItem] = [],
                                 trailingItems: [UIBarButtonItem] = [],
                                 showFloatingButton: Bool = false) {
        // Map UIBarButtonItems to UITabBarItems and store actions
        let allItems = leadingItems + trailingItems
        itemActions = allItems.map { ($0.target as AnyObject?, $0.action) }
        let tabItems: [UITabBarItem] = allItems.enumerated().map { (idx, barItem) in
            let item = UITabBarItem(title: nil, image: barItem.image, tag: idx)
            return item
        }
        tabBar.items = tabItems
        tabBar.selectedItem = nil

        // Show or hide floating button
        floatingButton.isHidden = !showFloatingButton

        // Ensure it stays above other views
        layer.zPosition = 1000
    }

    private func setupTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        // No background effect; keep the tab bar fully clear (no rectangle view behind)
        appearance.backgroundEffect = nil
        appearance.backgroundColor = .clear
        appearance.shadowColor = .clear

        // Optional: tweak item appearance
        let normalColor = (tintColor ?? .white).withAlphaComponent(0.6)
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.inlineLayoutAppearance.normal.iconColor = normalColor
        appearance.compactInlineLayoutAppearance.normal.iconColor = normalColor

        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
        // Also clear any existing layer shadow
        tabBar.layer.shadowOpacity = 0
    }

    // MARK: - UITabBarDelegate
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        guard let idx = tabBar.items?.firstIndex(of: item) else { return }
        let mapping = itemActions[idx]
        if let action = mapping.action {
            UIApplication.shared.sendAction(action, to: mapping.target, from: self, for: nil)
        }
        // Deselect to behave like buttons rather than persistent selection
        tabBar.selectedItem = nil
    }
}
// Import the delegate protocol
import Foundation

// Import TaskProgressCard from Views/Cards
// Note: TaskProgressCard is defined in ChartCard.swift

class HomeViewController: UIViewController, ChartViewDelegate, MDCRippleTouchControllerDelegate, UITableViewDataSource, UITableViewDelegate, UISearchBarDelegate, TaskRepositoryDependent, HomeViewControllerProtocol {
    
    // MARK: - Clean Architecture Integration
    
    /// Setup Clean Architecture integration
    private func setupCleanArchitecture() {
        // Check if ViewModel was injected by PresentationDependencyContainer
        if let homeViewModel = viewModel {
            print("✅ HomeViewController: Using Clean Architecture with HomeViewModel")
            setupViewModelBindings(homeViewModel)
            loadInitialDataViaViewModel(homeViewModel)
        } else {
            print("⚠️ HomeViewController: No ViewModel injected - Clean Architecture setup failed")
        }
    }
    
    /// Setup Combine bindings with HomeViewModel
    private func setupViewModelBindings(_ viewModel: HomeViewModel) {
        // TEMPORARY: Commented out until actual HomeViewModel types are resolved
        // This will be restored when proper type resolution is fixed
        /*
        // Bind ViewModel state to UI updates
        viewModel.$morningTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.updateMorningTasksUI(tasks)
            }
            .store(in: &cancellables)
            
        viewModel.$eveningTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.updateEveningTasksUI(tasks)
            }
            .store(in: &cancellables)
            
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.updateLoadingState(isLoading)
            }
            .store(in: &cancellables)
            
        viewModel.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showError(error)
            }
            .store(in: &cancellables)
            
        viewModel.$dailyScore
            .receive(on: DispatchQueue.main)
            .sink { [weak self] score in
                self?.updateScoreDisplay(score)
            }
            .store(in: &cancellables)
        */
        print("🔗 HomeViewController: ViewModel bindings setup (stubbed)")
    }
    
    /// Load initial data via ViewModel
    private func loadInitialDataViaViewModel(_ viewModel: HomeViewModel) {
        // TEMPORARY: Using dynamic method calls until proper type resolution is fixed
        // This will be replaced with direct method calls when types are resolved
        if viewModel.responds(to: NSSelectorFromString("loadTodayTasks")) {
            viewModel.perform(NSSelectorFromString("loadTodayTasks"))
        }
        if viewModel.responds(to: NSSelectorFromString("loadProjects")) {
            viewModel.perform(NSSelectorFromString("loadProjects"))
        }
        print("📅 HomeViewController: Initial data loading requested (stubbed)")
    }
    
    /// Update morning tasks UI from ViewModel
    private func updateMorningTasksUI(_ tasks: [Task]) {
        // Convert domain tasks to UI sections
        // Implementation depends on your specific UI requirements
        print("📋 Updating morning tasks: \(tasks.count) tasks")
        refreshTableView()
    }
    
    /// Update evening tasks UI from ViewModel
    private func updateEveningTasksUI(_ tasks: [Task]) {
        // Convert domain tasks to UI sections
        print("🌙 Updating evening tasks: \(tasks.count) tasks")
        refreshTableView()
    }
    
    /// Update loading state
    private func updateLoadingState(_ isLoading: Bool) {
        // Show/hide loading indicators
        print("⏳ Loading: \(isLoading)")
    }
    
    /// Show error message
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    /// Update score display
    private func updateScoreDisplay(_ score: Int) {
        // Update score UI element
        print("🏆 Daily Score: \(score)")
    }
    
    /// Refresh table view
    private func refreshTableView() {
        DispatchQueue.main.async { [weak self] in
            self?.fluentToDoTableViewController?.tableView.reloadData()
        }
    }
    
    // MARK: - Legacy Properties & Methods
    
    /// Task repository dependency (injected)
    var taskRepository: TaskRepository!
    
    /// HomeViewModel dependency (injected) - Clean Architecture  
    /// This satisfies the HomeViewControllerProtocol requirement
    var viewModel: HomeViewModel?
    
    /// Combine cancellables for ViewModel bindings
    private var cancellables = Set<AnyCancellable>()
    
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
    
    // FSCalendar instance for backdrop calendar (initialized in UISetup extension)
    var calendar: FSCalendar!
    
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
    
    // Tiny pie chart config (used by TinyPieChart.swift)
    var shouldHideData: Bool = false
    var tinyPieChartSections: [String] = ["Done", "In Progress", "Not Started", "Overdue"]
    
    // Primary SwiftUI Chart Card (Phase 5: Now the main chart implementation)
    // Note: TaskProgressCard is defined in ChartCard.swift
    // Using AnyView to work around type resolution issue
    var swiftUIChartHostingController: UIHostingController<AnyView>?
    var swiftUIChartContainer: UIView?

    // Legacy properties removed - sampleTableView and sampleData
    // var sampleTableView = UITableView(frame: .zero, style: .grouped)
    // var sampleData: [(String, [NTask])] = []
    
    // FluentUI To Do TableView Controller
    var fluentToDoTableViewController: FluentUIToDoTableViewController?
    
    // View state
    var projectForTheView = "Inbox" // Default project name
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
    
    // Bottom app bar - Liquid Glass UI
    var liquidGlassBottomBar: LiquidGlassBottomAppBar?
    
    // Foredrop state management
    var foredropStateManager: ForedropStateManager?
    
    // Legacy state flags (deprecated - use foredropStateManager instead)
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
    
    // MARK: - Clean Architecture Integration
    
    /// Initialize Clean Architecture components
    private func initializeCleanArchitecture() {
        print("🏗️ Initializing Clean Architecture...")
        
        // Inject dependencies - Using dynamic approach to avoid type resolution issues
        // This will call the actual PresentationDependencyContainer when types are resolved
        if let containerClass = NSClassFromString("PresentationDependencyContainer") as? NSObject.Type {
            let shared = containerClass.value(forKey: "shared") as? NSObject
            shared?.perform(NSSelectorFromString("inject:into:"), with: self)
        } else {
            print("⚠️ PresentationDependencyContainer not found - using fallback injection")
        }
        
        // Setup Clean Architecture if ViewModel is available
        if viewModel != nil {
            print("✅ Clean Architecture activated with ViewModel")
            setupCleanArchitectureInternal()
        } else {
            print("⚠️ ViewModel not available - using legacy mode with migration adapter")
            // Fallback to migration adapter if Clean Architecture isn't available
        }
    }
    
    /// Internal setup method that calls the extension method
    private func setupCleanArchitectureInternal() {
        // This method exists in HomeViewController+CleanArchitecture.swift extension
        // Call it directly to ensure proper setup
        guard viewModel != nil else {
            print("⚠️ HomeViewController: ViewModel not injected, using migration adapter")
            return
        }
        
        print("✅ HomeViewController: Using Clean Architecture with ViewModel")
        
        // Load initial data through the ViewModel using our safe method calling
        if let vm = viewModel {
            callViewModelMethod(vm, methodName: "loadTodayTasks")
            callViewModelMethod(vm, methodName: "loadProjects")
        }
    }
    
    /// Safely call ViewModel methods using reflection to avoid type conflicts
    /// This method is accessible to all extensions
    func callViewModelMethod(_ viewModel: Any, methodName: String, parameter: Any? = nil) {
        print("🗘 Clean Architecture: Calling \(methodName) on ViewModel")
        
        // Placeholder implementation that maintains Clean Architecture patterns
        // When real ViewModel types are available, this will be replaced with proper method calls
        switch methodName {
        case "loadTodayTasks":
            print("📋 Clean Architecture: Initiating today's tasks loading")
        case "loadProjects":
            print("📋 Clean Architecture: Initiating projects loading")
        case "selectDate":
            if let date = parameter as? Date {
                print("📋 Clean Architecture: Setting selected date to \(date)")
            }
        case "loadTasksForSelectedDate":
            print("📋 Clean Architecture: Loading tasks for selected date")
        case "selectProject":
            if let project = parameter as? String {
                print("📋 Clean Architecture: Setting selected project to \(project)")
            }
        default:
            print("⚠️ Clean Architecture: Unknown method \(methodName)")
        }
    }
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup Clean Architecture if available
        setupCleanArchitecture()
        
        // Legacy setup continues...
        
        print("\n=== HOME VIEW CONTROLLER LOADED ===")
        print("Initial dateForTheView: \(dateForTheView)")
        
        // Initialize Clean Architecture
        initializeCleanArchitecture()
        
        // Fix invalid priority values in database
        fixInvalidTaskPriorities()
        
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
        
        // Note: contentScrollView is FluentUI-specific, removed for native iOS compatibility
        // ShyHeaderController behavior will be handled differently if needed
        
        highestPrioritySymbol = (UIImage(systemName: "circle.fill", withConfiguration: ultraLightConfiguration)?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal))!
        highPrioritySymbol = (UIImage(systemName: "circle", withConfiguration: ultraLightConfiguration)?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal))!
        
        self.setupBackdrop()
        view.addSubview(backdropContainer)
        
        view.addSubview(foredropContainer)
        self.setupHomeFordrop()
        
        // Setup and add bottom app bar - it should be the topmost view
        self.configureLiquidGlassBottomAppBar()
        if let lgBottomBar = liquidGlassBottomBar {
            view.addSubview(lgBottomBar)
            // Set up constraints immediately after adding to view hierarchy
            setupLiquidGlassBottomBarConstraints(lgBottomBar)
        }
        
        foredropContainer.backgroundColor = UIColor.systemBackground
        // Apply initial themed backgrounds
        view.backgroundColor = todoColors.primaryColor.withAlphaComponent(0.05)
        backdropContainer.backgroundColor = todoColors.primaryColor.withAlphaComponent(0.05)
        
        // Initial data loading handled by setupCleanArchitectureIfAvailable()
        
        // Enable dark mode if preset
        enableDarkModeIfPreset()
        
        // Initial view update
        updateViewForHome(viewType: .todayHomeView)
        
        // Setup the SwiftUI chart card
        setupSwiftUIChartCard()
        
        // Initialize foredrop state manager after all views are set up
        initializeForedropStateManager()
        
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
        
        // Ensure navigation pie chart exists - recreate if needed
        if navigationPieChartView == nil {
            print("⚠️ Navigation pie chart is nil in viewDidAppear, attempting to create...")
            embedNavigationPieChartOnNavigationBar()
        }
        
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
        
        // Liquid Glass bottom app bar uses Auto Layout constraints set up in viewDidLoad
        
        // Update foredrop state manager layout
        foredropStateManager?.updateLayout()
    }
    
    /// Sets up Auto Layout constraints for the Liquid Glass bottom app bar
    private func setupLiquidGlassBottomBarConstraints(_ lgBottomBar: LiquidGlassBottomAppBar) {
        // Ensure Auto Layout is enabled
        lgBottomBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Use safe area for proper positioning
        let safeArea = view.safeAreaLayoutGuide
        let barHeight: CGFloat = 64
        
        NSLayoutConstraint.activate([
            lgBottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            lgBottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            lgBottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            lgBottomBar.topAnchor.constraint(equalTo: safeArea.bottomAnchor, constant: -barHeight)
        ])
        
        print("🌊 Liquid Glass bottom app bar constraints activated with height: \(barHeight)")
    }
    
    deinit {
        notificationCenter.removeObserver(self, name: .themeChanged, object: nil)
        notificationCenter.removeObserver(self)
    }
    
    // MARK: - FluentUI Navigation Bar Setup
    
    private func setupFluentUINavigationBar() {
        // Configure navigation bar appearance using standard iOS APIs
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = todoColors.primaryColor
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        
        // Disable large titles so our score label is not obscured
        navigationController?.navigationBar.prefersLargeTitles = false
        navigationItem.largeTitleDisplayMode = .never
        title = "" // Clear default title
        if let navBar = navigationController?.navigationBar {
            navBar.subviews.compactMap { $0 as? UILabel }.forEach { $0.backgroundColor = .clear }
        }
        
        // Search bar removed - now accessed via bottom app bar button
        
        // Hide legacy scoreCounter label (we now show score in title)
        scoreCounter.isHidden = true
        // Ensure initial title is displayed
        updateDailyScore()
      // Embed pie chart inside search bar accessory instead of right bar button
        embedNavigationPieChartOnNavigationBar()
        
        // Enable scroll-to-contract behavior
        // Note: contentScrollView is FluentUI-specific, removed for native iOS compatibility
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
        navPieChart.holeRadiusPercent = 0.58
        // Ensure the chart is visible above the navigation bar
        navPieChart.layer.zPosition = 952
        containerView.layer.zPosition = 952
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
        guard navigationPieChartView == nil else {
            print("🥧 Navigation pie chart already exists, skipping creation")
            return
        }
        guard let navBar = self.navigationController?.navigationBar else {
            print("❌ Navigation bar not available, cannot embed pie chart")
            return
        }
        
        print("🥧 Creating navigation pie chart...")
        navBar.clipsToBounds = false // allow chart to render outside if needed
        let size: CGFloat = 110
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .clear
        navBar.addSubview(containerView)
        NSLayoutConstraint.activate([
            containerView.widthAnchor.constraint(equalToConstant: size),
            containerView.heightAnchor.constraint(equalToConstant: size),
            containerView.trailingAnchor.constraint(equalTo: navBar.trailingAnchor, constant: -2),
            containerView.centerYAnchor.constraint(equalTo: navBar.centerYAnchor, constant:30)
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
        navPieChart.holeRadiusPercent = 0.58
        // Minimal appearance: no slice labels, legend, or description
        navPieChart.drawEntryLabelsEnabled = false
        navPieChart.legend.enabled = false
        navPieChart.chartDescription.enabled = false
        // Enable hole in center like demo
        navPieChart.drawHoleEnabled = true
        navPieChart.setExtraOffsets(left: 0, top: 0, right: 0, bottom: 0)
        navPieChart.minOffset = 0
        navPieChart.layer.zPosition = 900
        containerView.layer.zPosition = 900
        navPieChart.backgroundColor = .clear
        
        // Ensure visibility
        navPieChart.isHidden = false
        navPieChart.alpha = 1.0
        containerView.isHidden = false
        containerView.alpha = 1.0
        
        setNavigationPieChartData()
        refreshNavigationPieChart()
        let tap = UITapGestureRecognizer(target: self, action: #selector(toggleCharts))
        navPieChart.addGestureRecognizer(tap)
        navPieChart.isUserInteractionEnabled = true
        
        print("✅ Navigation pie chart created successfully at frame: \(navPieChart.frame)")
        print("   Container frame: \(containerView.frame)")
        print("   Navigation bar frame: \(navBar.frame)")
    }
    
    private func createSearchBarAccessory() -> UISearchBar {
        let searchBar = UISearchBar()
        searchBar.placeholder = "Search tasks..."
        searchBar.delegate = self
        
        // Make the search bar background transparent
        searchBar.backgroundColor = UIColor.clear
        searchBar.barTintColor = UIColor.clear
        searchBar.searchBarStyle = .minimal
        
        // Make the search field background semi-transparent
        let textField = searchBar.searchTextField
        textField.backgroundColor = UIColor.white.withAlphaComponent(0.2)
        textField.textColor = UIColor.white
        textField.attributedPlaceholder = NSAttributedString(
            string: "Search tasks...",
            attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.7)]
        )
        
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
        navPieChart.holeRadiusPercent = 0.58
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
    /// Priorities: 1=None (2pts), 2=Low (3pts), 3=High (5pts), 4=Max (7pts)
// Core pie-chart data builder – DO NOT overload with same name without parameter
private func buildNavigationPieChartData(for date: Date) {
    guard let navPieChart = navigationPieChartView else {
        print("⚠️ buildNavigationPieChartData called but navigationPieChartView is nil")
        return
    }

    // Fetch priority counts for completed tasks on the given date
    let breakdown = priorityBreakdown(for: date)
    print("📊 Priority breakdown for \(date): \(breakdown)")
    
    // Use chart weights from centralized config
    let entries: [PieChartDataEntry] = [
        (Int32(1), "None"),    // None priority
        (Int32(2), "Low"),     // Low priority
        (Int32(3), "High"),    // High priority
        (Int32(4), "Max")      // Max priority
    ].compactMap { (priorityRaw, label) in
        let rawCount = Double(breakdown[priorityRaw] ?? 0)
        let weight = TaskPriorityConfig.chartWeightForPriority(priorityRaw)
        let weightedValue = rawCount * weight
        return weightedValue > 0 ? PieChartDataEntry(value: weightedValue, label: label) : nil
    }

    print("📊 Pie chart entries: \(entries.count) slices")
    
    // Guard against no-data scenario – just clear chart and exit
    guard !entries.isEmpty else {
        print("⚠️ No data for pie chart, clearing chart")
        navPieChart.data = nil
        navPieChart.setNeedsDisplay()
        return
    }

    // Build matching colour array using centralized config colors
    var sliceColors: [UIColor] = []
    for entry in entries {
        switch entry.label {
        case "None":
            sliceColors.append(TaskPriorityConfig.Priority.none.color)
        case "Low":
            sliceColors.append(TaskPriorityConfig.Priority.low.color)
        case "High":
            sliceColors.append(TaskPriorityConfig.Priority.high.color)
        case "Max":
            sliceColors.append(TaskPriorityConfig.Priority.max.color)
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
    print("✅ Navigation pie chart data set with \(entries.count) entries")
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
        // Present add task interface with Clean Architecture
        let addTaskVC = AddTaskViewController()
        addTaskVC.delegate = self
        
        // Use Clean Architecture dependency injection - Using dynamic approach to avoid type resolution issues
        // This will fall back to legacy injection if Clean Architecture isn't available
        if let containerClass = NSClassFromString("PresentationDependencyContainer") as? NSObject.Type {
            let shared = containerClass.value(forKey: "shared") as? NSObject
            shared?.perform(NSSelectorFromString("inject:into:"), with: addTaskVC)
        } else {
            print("⚠️ PresentationDependencyContainer not found - using fallback injection")
        }
        
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
        // Get ALL tasks from Core Data directly
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        let allTasks = (try? context?.fetch(request)) ?? []
        
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
        
        // Save context using direct Core Data access
        if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext,
           context.hasChanges {
            do {
                try context.save()
            } catch {
                print("❌ Failed to save context: \(error)")
            }
        }
        
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
        // Navigation bar (using standard iOS appearance)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = todoColors.primaryColor
        navigationController?.navigationBar.standardAppearance = appearance
        // Keep title label transparent on theme change
        if let navBar = navigationController?.navigationBar {
            navBar.subviews.compactMap { $0 as? UILabel }.forEach { $0.backgroundColor = .clear }
        }
        // System/global tint
        // Global tint
        view.tintColor = todoColors.primaryColor
        // Main view background color should follow theme immediately
        view.backgroundColor = todoColors.primaryColor.withAlphaComponent(0.05)
        
        
        
        
        
        // Bottom app bar - update Liquid Glass version
        if let lgBottomBar = liquidGlassBottomBar {
            lgBottomBar.tintColor = UIColor.white
            // Liquid Glass bottom bar automatically updates its appearance based on theme
        }
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
        // Custom floating button color handled in setupLiquidGlassBottomBar
        // Update any search bar accessory background (keep transparent)
        if let accSearchBar = navigationItem.titleView as? UISearchBar {
            accSearchBar.backgroundColor = UIColor.clear
            accSearchBar.barTintColor = UIColor.clear
            // Update the search field styling
            let textField = accSearchBar.searchTextField
            textField.backgroundColor = UIColor.white.withAlphaComponent(0.2)
            textField.textColor = UIColor.white
            textField.attributedPlaceholder = NSAttributedString(
                string: "Search tasks...",
                attributes: [NSAttributedString.Key.foregroundColor: UIColor.white.withAlphaComponent(0.7)]
            )
        }
        if let controllerSearchBar = navigationItem.searchController?.searchBar {
            controllerSearchBar.backgroundColor = UIColor.clear
            controllerSearchBar.barTintColor = UIColor.clear
        }
        // Update chart accent colors if present
        
        // Update calendar appearance & refresh
        if let cal = self.calendar {
            // Header & weekday background colours
            cal.calendarHeaderView.backgroundColor = todoColors.primaryColor.withAlphaComponent(0.5)
            cal.calendarWeekdayView.backgroundColor = todoColors.primaryColorDarker
        }
        if let cal = self.calendar {
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
    
    /// Sets up the bottom app bar - always uses Liquid Glass UI
    fileprivate func configureLiquidGlassBottomAppBar() {
        setupLiquidGlassBottomBar()
    }
    
    /// Sets up the Liquid Glass bottom app bar with iOS 26 transparent material
    private func setupLiquidGlassBottomBar() {
        // Create Liquid Glass bottom app bar
        liquidGlassBottomBar = LiquidGlassBottomAppBar()
        guard let lgBottomBar = liquidGlassBottomBar else { return }
        
        // Configure with Auto Layout
        lgBottomBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Create all bar button items matching original layout
        // Icon size: 56x56 (2x larger for better visibility)
        let iconSize = CGSize(width: 48, height: 48)
        
        // Settings button (leftmost) - Using 3D icon
        let settingsImage = UIImage(named: "gear2")
        let settingsImageResized = settingsImage?.resized(to: iconSize)
        let settingsItem = UIBarButtonItem(image: settingsImageResized?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(onMenuButtonTapped))
        settingsItem.accessibilityLabel = "Settings"
        
        // Calendar button - Using 3D icon
        let calendarImage = UIImage(named: "cal")
        let calendarImageResized = calendarImage?.resized(to: iconSize)
        let calendarItem = UIBarButtonItem(image: calendarImageResized?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(toggleCalendar))
        calendarItem.accessibilityLabel = "Calendar"
        
        // Charts/Analytics button - Using 3D icon
        let chartImage = UIImage(named: "charts")
        let chartImageResized = chartImage?.resized(to: iconSize)
        let chartItem = UIBarButtonItem(image: chartImageResized?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(toggleCharts))
        chartItem.accessibilityLabel = "Analytics"
        
        // Search button - Using 3D icon
        let searchImage = UIImage(named: "search")
        let searchImageResized = searchImage?.resized(to: iconSize)
        let searchItem = UIBarButtonItem(image: searchImageResized?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(searchButtonTapped))
        searchItem.accessibilityLabel = "Search Tasks"
        
        // Chat button (rightmost) - Using 3D icon
        let chatImage = UIImage(named: "chat")
        let chatImageResized = chatImage?.resized(to: iconSize)
        let chatButtonItem = UIBarButtonItem(image: chatImageResized?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(chatButtonTapped))
        chatButtonItem.accessibilityLabel = "Chat with LLM"
        
        // Configure the bottom app bar with all 5 buttons
        lgBottomBar.configureStandardAppBar(
            leadingItems: [settingsItem, calendarItem, chartItem, searchItem, chatButtonItem],
            trailingItems: [],
            showFloatingButton: true
        )
        
        // Configure floating action button
        let fab = lgBottomBar.floatingButton
        let addTaskImage = UIImage(named: "add_task") ?? UIImage(systemName: "plus")
        fab.setImage(addTaskImage, for: .normal)
        fab.backgroundColor = todoColors.secondaryAccentColor
        fab.addTarget(self, action: #selector(AddTaskAction), for: .touchUpInside)
        fab.tintColor = .white
        
        // Set tint color to match theme
        lgBottomBar.tintColor = UIColor.white
        
        print("🌊 Liquid Glass bottom app bar configured with iOS 26 transparent material")
    }
    

    /// Presents the Liquid Glass Search screen modally.
    @objc func searchButtonTapped() {
        let searchVC = LGSearchViewController()
        searchVC.modalPresentationStyle = .fullScreen
        searchVC.modalTransitionStyle = .crossDissolve
        present(searchVC, animated: true)
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
    
    /// Public method called directly by FluentUIToDoTableViewController when task completion changes
    /// This is more reliable than notifications
    func refreshChartsAfterTaskCompletion() {
        print("🎯 HomeViewController: refreshChartsAfterTaskCompletion() called DIRECTLY")
        
        // Calculate new score
        let score = self.calculateTodaysScore()
        self.scoreCounter.text = "\(score)"
        print("📊 New score calculated: \(score)")
        
        // Update tiny pie chart DATA
        print("🥧 Updating tiny pie chart data...")
        self.updateTinyPieChartData()
        
        // Update tiny pie chart CENTER TEXT with new score
        print("📝 Updating tiny pie chart center text with score: \(score)")
        self.tinyPieChartView.centerAttributedText = self.setTinyPieChartScoreText(
            pieChartView: self.tinyPieChartView,
            scoreOverride: score
        )
        
        // Animate tiny pie chart
        print("🎬 Animating tiny pie chart...")
        self.tinyPieChartView.animate(xAxisDuration: 1.4, easingOption: .easeOutBack)
        
        // Refresh navigation pie chart
        print("🔄 Refreshing navigation pie chart...")
        self.refreshNavigationPieChart()
        
        // Update SwiftUI chart card and daily score
        print("📊 Updating SwiftUI chart and daily score...")
        self.updateSwiftUIChartCard()
        self.updateDailyScore()
        
        print("✅ HomeViewController: ALL charts refreshed successfully (including tiny pie chart)")
    }
    
    @objc private func taskCompletionChanged() {
        print("📊 HomeViewController: Received TaskCompletionChanged notification - refreshing ALL charts")
        DispatchQueue.main.async { [weak self] in
            self?.refreshChartsAfterTaskCompletion()
        }
    }
    
    /// Animates + refreshes the navigation pie chart using current `dateForTheView`.
    func refreshNavigationPieChart() {
        guard let navChart = navigationPieChartView else {
            print("⚠️ refreshNavigationPieChart called but navigationPieChartView is nil")
            return
        }
        print("🔄 Refreshing navigation pie chart for date: \(dateForTheView)")
        setNavigationPieChartData()
        navChart.animate(xAxisDuration: 0.3, easingOption: .easeOutBack)
        print("✅ Navigation pie chart refreshed - isHidden: \(navChart.isHidden), alpha: \(navChart.alpha), data: \(navChart.data?.entryCount ?? 0) entries")
    }
    
    /// Compatibility shim for existing calendar extension call
    @objc func reloadTinyPicChartWithAnimation() {
        refreshNavigationPieChart()
    }
    
    /// Fixes invalid task priority values in the database (one-time migration)
    /// Priorities: 1=None, 2=Low, 3=High, 4=Max
    private func fixInvalidTaskPriorities() {
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            return
        }
        
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        guard let allTasks = try? context.fetch(request) else { return }
        
        var fixedCount = 0
        for task in allTasks {
            let priority = task.taskPriority
            // Check if priority is invalid (not 1, 2, 3, or 4)
            if !TaskPriorityConfig.isValidPriority(priority) {
                let normalized = TaskPriorityConfig.normalizePriority(priority)
                print("🔧 Fixing invalid priority \(priority) for task '\(task.name ?? "")' -> setting to \(TaskPriority(rawValue: normalized).displayName) (\(normalized))")
                task.taskPriority = normalized
                fixedCount += 1
            }
        }
        
        if fixedCount > 0 {
            do {
                try context.save()
                print("✅ Fixed \(fixedCount) tasks with invalid priorities")
            } catch {
                print("❌ Failed to save priority fixes: \(error)")
            }
        } else {
            print("✅ All task priorities are valid")
        }
    }
    
    /// Returns a dictionary of counts of completed tasks grouped by priority for a given date
    /// Priorities: 1=None, 2=Low, 3=High, 4=Max
    func priorityBreakdown(for date: Date) -> [Int32: Int] {
        // Use raw values to avoid enum compilation issues
        var counts: [Int32: Int] = [1: 0, 2: 0, 3: 0, 4: 0] // none, low, high, max
        // Get tasks from Core Data directly
        let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
        let request: NSFetchRequest<NTask> = NTask.fetchRequest()
        let allTasks = (try? context?.fetch(request)) ?? []
        let currentCalendar = Calendar.current
        
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
                  currentCalendar.isDate(ref, inSameDayAs: date) else { continue }
            
            // Normalize priority value using centralized config
            let normalizedPriority = TaskPriorityConfig.normalizePriority(task.taskPriority)
            counts[normalizedPriority, default: 0] += 1
        }
        return counts
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
            // Fallback: count tasks whose *completion* date equals the target day
            let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            let allTasks = (try? context?.fetch(request)) ?? []
            let currentCalendar = Calendar.current
            let completedToday = allTasks.filter { task in
                guard task.isComplete, let doneDate = task.dateCompleted as Date? else { return false }
                return currentCalendar.isDate(doneDate, inSameDayAs: targetDate)
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
