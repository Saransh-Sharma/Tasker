//
//  HomeViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright 2020 saransh1337. All rights reserved.
//

import UIKit
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
import CoreData  // TODO: Remove once all NSFetchRequest calls are migrated to repository pattern

// MARK: - Clean Architecture Integration
// Import actual Clean Architecture types from Presentation layer
// - HomeViewControllerProtocol: Protocol for DI to inject HomeViewModel
// - HomeViewModel: ViewModel for business logic and state management
// - PresentationDependencyContainer: Dependency injection container

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
        b.backgroundColor = .clear
        b.tintColor = .label
        b.layer.cornerRadius = 28
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
        let tokens = TaskerThemeManager.shared.currentTheme.tokens
        floatingButton.backgroundColor = tokens.color.accentPrimary
        floatingButton.tintColor = tokens.color.accentOnPrimary
        floatingButton.applyTaskerElevation(.e2)

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
        let fallbackTint = TaskerThemeManager.shared.currentTheme.tokens.color.accentOnPrimary
        let normalColor = (tintColor ?? fallbackTint).withAlphaComponent(0.6)
        appearance.stackedLayoutAppearance.normal.iconColor = normalColor
        appearance.inlineLayoutAppearance.normal.iconColor = normalColor
        appearance.compactInlineLayoutAppearance.normal.iconColor = normalColor

        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }
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
        initializeCleanArchitecture()

        guard let homeViewModel = viewModel else {
            print("HOME_DI home.setup viewModel=nil")

            // Keep repository available for task detail + selection flows.
            if taskRepository == nil,
               let appDelegate = UIApplication.shared.delegate as? AppDelegate {
                taskRepository = CoreDataTaskRepository(container: appDelegate.persistentContainer, defaultProject: "Inbox")
            }
            return
        }

        print("HOME_DI home.setup viewModel=non_nil")
        setupViewModelBindingsIfNeeded(homeViewModel)
        if !hasLoadedInitialViewModelData {
            loadInitialDataViaViewModel(homeViewModel)
            hasLoadedInitialViewModelData = true
        }
    }
    
    /// Setup Combine bindings with HomeViewModel
    private func setupViewModelBindingsIfNeeded(_ viewModel: HomeViewModel) {
        guard !hasBoundHomeViewModel else { return }
        hasBoundHomeViewModel = true

        // Bind ViewModel state to UI updates
        viewModel.$morningTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.updateMorningTasksUI(tasks)
            }
            .store(in: &cancellables)

        // Bind evening tasks
        viewModel.$eveningTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.updateEveningTasksUI(tasks)
            }
            .store(in: &cancellables)

        // Bind overdue tasks
        viewModel.$overdueTasks
            .receive(on: DispatchQueue.main)
            .sink { [weak self] tasks in
                self?.updateOverdueTasksUI(tasks)
            }
            .store(in: &cancellables)

        // Bind projects
        viewModel.$projects
            .receive(on: DispatchQueue.main)
            .sink { [weak self] projects in
                self?.updateProjectsUI(projects)
            }
            .store(in: &cancellables)

        viewModel.$activeFilterState
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshQuickFilterMenuContent()
            }
            .store(in: &cancellables)

        viewModel.$quickViewCounts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshQuickFilterMenuContent()
            }
            .store(in: &cancellables)

        viewModel.$savedHomeViews
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshQuickFilterMenuContent()
            }
            .store(in: &cancellables)

        viewModel.$pointsPotential
            .receive(on: DispatchQueue.main)
            .sink { [weak self] points in
                self?.focusPotentialLabel.text = points > 0 ? "Potential \(points) pts" : nil
            }
            .store(in: &cancellables)

        // Bind loading state
        viewModel.$isLoading
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isLoading in
                self?.updateLoadingState(isLoading)
            }
            .store(in: &cancellables)

        // Bind error messages
        viewModel.$errorMessage
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.showError(error)
            }
            .store(in: &cancellables)

        // Bind daily score
        viewModel.$dailyScore
            .receive(on: DispatchQueue.main)
            .sink { [weak self] score in
                self?.updateScoreDisplay(score)
            }
            .store(in: &cancellables)

        print("HOME_DI home.bindings ready")
    }
    
    /// Load initial data via ViewModel
    private func loadInitialDataViaViewModel(_ viewModel: HomeViewModel) {
        // Load today's tasks and projects
        viewModel.loadTodayTasks()
        viewModel.loadProjects()
        print("✅ HomeViewController: Initial data loading via ViewModel")
    }
    
    /// Update morning tasks UI from ViewModel
    private func updateMorningTasksUI(_ tasks: [Task]) {
        print("📋 Updating morning tasks: \(tasks.count) tasks")
        refreshTableView()
    }
    
    /// Update evening tasks UI from ViewModel
    private func updateEveningTasksUI(_ tasks: [Task]) {
        print("🌙 Updating evening tasks: \(tasks.count) tasks")
        refreshTableView()
    }

    /// Update overdue tasks UI from ViewModel
    private func updateOverdueTasksUI(_ tasks: [Task]) {
        print("⏰ Updating overdue tasks: \(tasks.count) tasks")
        refreshTableView()
    }

    /// Update projects UI from ViewModel
    private func updateProjectsUI(_ projects: [Project]) {
        print("📁 Updating projects: \(projects.count) projects")
        refreshQuickFilterMenuContent()
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
        refreshHomeTaskList(reason: "viewModelPublish")
    }

    struct HomeTaskListInput {
        let morning: [DomainTask]
        let evening: [DomainTask]
        let overdue: [DomainTask]
        let projects: [Project]
        let doneTimeline: [DomainTask]
        let activeQuickView: HomeQuickView?
        let emptyStateMessage: String?
        let emptyStateActionTitle: String?
    }

    func refreshHomeTaskList(reason: String = "manual") {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.setupTaskListViewInForedrop()
            self.layoutForedropListViews()
            print("HOME_UI_MODE renderer=TaskListView reason=\(reason) mode=\(self.currentViewType)")
        }
    }
    
    // MARK: - Legacy Properties & Methods
    
    /// Task repository dependency (injected)
    var taskRepository: TaskRepository!
    
    /// HomeViewModel dependency (injected) - Clean Architecture
    var viewModel: HomeViewModel!

    /// Combine cancellables for ViewModel bindings
    private var cancellables = Set<AnyCancellable>()
    private var hasBoundHomeViewModel = false
    private var hasLoadedInitialViewModelData = false
    
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
    var todoColors: TaskerColorTokens = TaskerThemeManager.shared.currentTheme.tokens.color
    var todoTimeUtils = ToDoTimeUtils()
    
    // UI Elements
    var homeTopBar: UIView = UIView()
    var homeTitleRow = UIView()
    var focusPotentialLabel = UILabel()
    var homeAdvancedFilterButton = UIButton(type: .system)
    var quickFilterMenuBackdrop = UIView()
    var quickFilterMenuContainer = UIView()
    var quickFilterMenuScrollView = UIScrollView()
    var quickFilterMenuContentStack = UIStackView()
    var quickFilterMenuQuickSectionLabel = UILabel()
    var quickFilterMenuProjectSectionLabel = UILabel()
    var quickFilterMenuQuickScrollView = UIScrollView()
    var quickFilterMenuQuickStack = UIStackView()
    var quickFilterMenuProjectScrollView = UIScrollView()
    var quickFilterMenuProjectStack = UIStackView()
    var quickFilterMenuAdvancedButton = UIButton(type: .system)
    var isQuickFilterMenuVisible = false
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

    // Radar Chart Card (Phase 6: Project breakdown chart)
    var radarChartHostingController: UIHostingController<AnyView>?
    var radarChartContainer: UIView?

    // Horizontally Scrollable Chart Cards (Phase 7: Unified chart view)
    var chartScrollHostingController: UIHostingController<AnyView>?
    var chartScrollContainer: UIView?

    // Legacy properties removed - sampleTableView and sampleData
    // var sampleTableView = UITableView(frame: .zero, style: .grouped)
    // var sampleData: [(String, [NTask])] = []
    
    // FluentUI To Do TableView Controller
    var fluentToDoTableViewController: FluentUIToDoTableViewController?
    var taskListHostingController: TransparentHostingController<TaskListView>?
    
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
            refreshHomeTaskList(reason: "isGrouped.didSet")
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
    @IBOutlet weak var addTaskButton: MDCFloatingButton! {
        didSet {
            addTaskButton?.accessibilityIdentifier = "home.addTaskButton"
        }
    }
    @IBOutlet weak var darkModeToggle: UISwitch!
    
    // MARK: - Clean Architecture Integration
    
    /// Initialize Clean Architecture components
    private func initializeCleanArchitecture() {
        print("HOME_DI home.inject start")
        DependencyContainer.shared.inject(into: self)

        if viewModel == nil {
            PresentationDependencyContainer.shared.inject(into: self)
        }

        print("HOME_DI home.inject viewModel=\(viewModel != nil)")
    }

    /// Internal setup method - now delegated to setupCleanArchitecture
    private func setupCleanArchitectureInternal() {
        // Clean Architecture setup is now handled in setupCleanArchitecture()
        // This method is kept for compatibility with existing code
    }

    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup Clean Architecture if available
        setupCleanArchitecture()
        print("HOME_DI viewDidLoad viewModel=\(viewModel != nil)")
        
        // Legacy setup continues...
        
        print("\n=== HOME VIEW CONTROLLER LOADED ===")
        print("Initial dateForTheView: \(dateForTheView)")
        
        // Fix invalid priority values in database
        fixInvalidTaskPriorities()
        
        print("=== HOME VIEW CONTROLLER SETUP COMPLETE ===")
        TaskerThemeManager.shared.publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.applyTheme()
            }
            .store(in: &cancellables)
        
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
        
        highestPrioritySymbol = (UIImage(systemName: "circle.fill", withConfiguration: ultraLightConfiguration)?.withTintColor(todoColors.accentMuted, renderingMode: .alwaysOriginal))!
        highPrioritySymbol = (UIImage(systemName: "circle", withConfiguration: ultraLightConfiguration)?.withTintColor(todoColors.accentMuted, renderingMode: .alwaysOriginal))!
        
        self.setupBackdrop()
        view.addSubview(backdropContainer)
        
        view.addSubview(foredropContainer)
        foredropContainer.accessibilityIdentifier = "home.view"
        self.setupHomeFordrop()
        
        // Setup and add bottom app bar - it should be the topmost view
        self.configureLiquidGlassBottomAppBar()
        if let lgBottomBar = liquidGlassBottomBar {
            view.addSubview(lgBottomBar)
            // Set up constraints immediately after adding to view hierarchy
            setupLiquidGlassBottomBarConstraints(lgBottomBar)
        }
        
        foredropContainer.backgroundColor = todoColors.surfacePrimary
        // Apply initial themed backgrounds
        view.backgroundColor = todoColors.accentPrimary.withAlphaComponent(0.05)
        backdropContainer.backgroundColor = todoColors.accentPrimary.withAlphaComponent(0.05)
        
        // Initial data loading handled by setupCleanArchitectureIfAvailable()
        
        // Enable dark mode if preset
        enableDarkModeIfPreset()
        
        // Initial view update
        updateViewForHome(viewType: .todayHomeView)

        // Phase 7: Old single chart removed - now using chartScrollContainer with horizontal scrolling
        // setupSwiftUIChartCard()

        // Initialize foredrop state manager after all views are set up
        initializeForedropStateManager()
        
        // Display today's initial score in navigation bar
        updateDailyScore()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        
        
        
        DispatchQueue.main.async { [weak self] in 
            guard let self else { return }
            self.refreshHomeTaskList(reason: "viewWillAppear")
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

        // Resize/reapply header gradient layers to match current bounds
        refreshBackdropGradientForCurrentTheme(deferredIfNeeded: false)

        // Liquid Glass bottom app bar uses Auto Layout constraints set up in viewDidLoad

        // Update foredrop state manager layout
        foredropStateManager?.updateLayout()

        // Keep title/list layout in sync after bounds changes (rotation, split view).
        layoutForedropListViews()
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
        notificationCenter.removeObserver(self)
    }
    
    // MARK: - FluentUI Navigation Bar Setup
    
    private func setupFluentUINavigationBar() {
        // Set FluentUI custom navigation bar color - this is the correct way to set color with FluentUI
        navigationItem.fluentConfiguration.customNavigationBarColor = todoColors.accentPrimary
        navigationItem.fluentConfiguration.navigationBarStyle = .custom

        // Configure navigation bar appearance using standard iOS APIs
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = todoColors.accentPrimary
        appearance.titleTextAttributes = [.foregroundColor: todoColors.accentOnPrimary]
        appearance.largeTitleTextAttributes = [.foregroundColor: todoColors.accentOnPrimary]

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

        // Add settings menu button on left side
        let settingsButton = UIBarButtonItem(
            image: UIImage(systemName: "list.bullet"),
            style: .plain,
            target: self,
            action: #selector(onMenuButtonTapped)
        )
        settingsButton.tintColor = todoColors.accentOnPrimary
        settingsButton.accessibilityLabel = "Settings"
        settingsButton.accessibilityIdentifier = "home.settingsButton"
        navigationItem.leftBarButtonItem = settingsButton

        let filterButton = UIBarButtonItem(
            image: UIImage(systemName: "line.3.horizontal.decrease.circle"),
            style: .plain,
            target: self,
            action: #selector(toggleQuickFilterMenu)
        )
        filterButton.tintColor = todoColors.accentOnPrimary
        filterButton.accessibilityIdentifier = "home.focus.menu.button.nav"
        navigationItem.rightBarButtonItem = filterButton

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
        navPieChart.layer.borderWidth = 0
        navPieChart.layer.borderColor = UIColor.clear.cgColor
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
        navPieChart.layer.borderWidth = 0
        navPieChart.layer.borderColor = UIColor.clear.cgColor
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
        textField.backgroundColor = todoColors.accentOnPrimary.withAlphaComponent(0.20)
        textField.textColor = todoColors.accentOnPrimary
        textField.attributedPlaceholder = NSAttributedString(
            string: "Search tasks...",
            attributes: [NSAttributedString.Key.foregroundColor: todoColors.accentOnPrimary.withAlphaComponent(0.7)]
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
        navPieChart.layer.borderWidth = 0
        navPieChart.layer.borderColor = UIColor.clear.cgColor
        setTinyChartShadow(chartView: navPieChart)
        navPieChart.layer.zPosition = 1000
        containerView.layer.zPosition = 1000
        navPieChart.backgroundColor = .clear
        
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
            sliceColors.append(todoColors.accentMuted) // fallback
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

        DependencyContainer.shared.inject(into: addTaskVC)
        PresentationDependencyContainer.shared.inject(into: addTaskVC)

        // Wrap in navigation controller to support navigation bar buttons
        let navController = UINavigationController(rootViewController: addTaskVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true, completion: nil)
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
            updateViewForHome(viewType: currentViewType, dateForView: dateForTheView)
        } else {
            // Filter tasks based on search text
            filterTasksForSearch(searchText: searchText)
        }
    }
    
    func searchBarDidCancel(_ searchBar: SearchBar) {
        // Handle search cancellation
        searchBar.progressSpinner.state.isAnimating = false
        updateViewForHome(viewType: currentViewType, dateForView: dateForTheView)
    }
    
    func searchBarDidRequestSearch(_ searchBar: SearchBar) {
        // Handle search button tap
        _ = searchBar.resignFirstResponder()
    }
    
    private func filterTasksForSearch(searchText: String) {
        // TODO: Use repository once it has fetchAllTasks method
        // For now, use direct CoreData access
        if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "dateAdded", ascending: false)]

            do {
                let allTasks = try context.fetch(request)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    // Filter tasks based on search text
                    let filteredTasks = allTasks.filter { task in
                        let searchTextLower = searchText.lowercased()
                        return (task.name ?? "").lowercased().contains(searchTextLower) ||
                               (task.taskDetails?.lowercased().contains(searchTextLower) ?? false) ||
                               (task.project?.lowercased().contains(searchTextLower) ?? false)
                    }

                    self.processSearchResults(filteredTasks)
                }
            } catch {
                print("❌ Error fetching tasks for search: \(error)")
            }
        }
    }

    /// Process search results and update UI
    private func processSearchResults(_ filteredTasks: [NTask]) {
        let domainTasks = filteredTasks.map { TaskMapper.toDomain(from: $0) }
        let nonOverdueTasks = domainTasks.filter { !$0.isOverdue }
        let overdueTasks = domainTasks.filter(\.isOverdue)
        let eveningTasks = nonOverdueTasks.filter { $0.type == .evening }
        let morningTasks = nonOverdueTasks.filter { $0.type != .evening }

        let searchListView = TaskListView(
            morningTasks: morningTasks,
            eveningTasks: eveningTasks,
            overdueTasks: overdueTasks,
            projects: viewModel?.projects ?? [],
            onTaskTap: { [weak self] task in
                self?.handleRevampedTaskTap(task)
            },
            onToggleComplete: { [weak self] task in
                self?.handleRevampedTaskToggleComplete(task)
            },
            onDeleteTask: { [weak self] task in
                self?.handleRevampedTaskDelete(task)
            },
            onRescheduleTask: { [weak self] task in
                self?.handleRevampedTaskReschedule(task)
            }
        )

        if taskListHostingController == nil {
            setupTaskListViewInForedrop()
        }
        taskListHostingController?.rootView = searchListView
        taskListHostingController?.view.isHidden = false
        fluentToDoTableViewController?.view.isHidden = true
        print("HOME_DATA mode=search morning=\(morningTasks.count) evening=\(eveningTasks.count) overdue=\(overdueTasks.count)")
    }
}

// MARK: - AddTaskViewControllerDelegate Extension

extension HomeViewController: AddTaskViewControllerDelegate {
    func didAddTask(_ task: NTask) {
        let taskName = task.name ?? "Untitled Task"
        let dueDateText: String
        if let dueDate = task.dueDate as Date? {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            dueDateText = formatter.string(from: dueDate)
        } else {
            dueDateText = "No due date"
        }
        print("🔄 AddTask: didAddTask called for task: \(taskName) with due date: \(dueDateText)")

        // TODO: Use ViewModel to refresh once Presentation folder is added to target
        // if let viewModel = viewModel {
        //     print("✅ Using ViewModel to refresh after task addition")
        //     viewModel.loadTodayTasks()
        // }
        
        // Step 4: Update the view on the main queue
        DispatchQueue.main.async {
            print("🔄 AddTask: Updating view on main queue")
            self.viewModel?.invalidateTaskCaches()
            
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
    fileprivate func refreshBackdropGradientForCurrentTheme(deferredIfNeeded: Bool = true) {
        let bounds = backdropContainer.bounds
        guard bounds.width > 0, bounds.height > 0 else {
            guard deferredIfNeeded else { return }
            DispatchQueue.main.async { [weak self] in
                self?.refreshBackdropGradientForCurrentTheme(deferredIfNeeded: false)
            }
            return
        }

        TaskerHeaderGradient.apply(
            to: backdropContainer.layer,
            bounds: bounds,
            traits: traitCollection
        )
    }

    /// Re-applies current theme colors to primary UI elements.
    fileprivate func applyTheme() {
        // Refresh color source
        todoColors = TaskerThemeManager.shared.currentTheme.tokens.color

        // Update FluentUI navigation bar color via custom property - this is the correct way with FluentUI
        navigationItem.fluentConfiguration.customNavigationBarColor = todoColors.accentPrimary
        navigationItem.fluentConfiguration.navigationBarStyle = .custom

        // Navigation bar (using standard iOS appearance)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = todoColors.accentPrimary
        navigationController?.navigationBar.standardAppearance = appearance
        navigationController?.navigationBar.scrollEdgeAppearance = appearance
        navigationController?.navigationBar.compactAppearance = appearance
        // Keep title label transparent on theme change
        if let navBar = navigationController?.navigationBar {
            navBar.subviews.compactMap { $0 as? UILabel }.forEach { $0.backgroundColor = .clear }
        }
        // System/global tint
        // Global tint
        view.tintColor = todoColors.accentPrimary
        // Main view background color should follow theme immediately
        view.backgroundColor = todoColors.accentPrimary.withAlphaComponent(0.05)
        
        
        
        
        
        // Bottom app bar - update Liquid Glass version
        if let lgBottomBar = liquidGlassBottomBar {
            lgBottomBar.tintColor = todoColors.accentOnPrimary
            // Liquid Glass bottom bar automatically updates its appearance based on theme
        }
        // Backdrop container background (subtle tint for blurred backdrop)
        backdropContainer.backgroundColor = todoColors.accentPrimary.withAlphaComponent(0.05)
        // Floating action button (if instantiated via storyboard & bottom bar)
        if let fab = addTaskButton {
            // For MDCFloatingButton use setBackgroundColor to ensure ripple layer also updates
            fab.setBackgroundColor(todoColors.accentPrimary, for: .normal)
            fab.setBackgroundColor(todoColors.accentPrimary.withAlphaComponent(0.8), for: .highlighted)
            fab.tintColor = todoColors.accentOnPrimary
            fab.backgroundColor = todoColors.accentPrimary
        }
        // Custom floating button color handled in setupLiquidGlassBottomBar
        // Update any search bar accessory background (keep transparent)
        if let accSearchBar = navigationItem.titleView as? UISearchBar {
            accSearchBar.backgroundColor = UIColor.clear
            accSearchBar.barTintColor = UIColor.clear
            // Update the search field styling
            let textField = accSearchBar.searchTextField
            textField.backgroundColor = todoColors.accentOnPrimary.withAlphaComponent(0.20)
            textField.textColor = todoColors.accentOnPrimary
            textField.attributedPlaceholder = NSAttributedString(
                string: "Search tasks...",
                attributes: [NSAttributedString.Key.foregroundColor: todoColors.accentOnPrimary.withAlphaComponent(0.7)]
            )
        }
        if let controllerSearchBar = navigationItem.searchController?.searchBar {
            controllerSearchBar.backgroundColor = UIColor.clear
            controllerSearchBar.barTintColor = UIColor.clear
        }
        // Update chart accent colors if present
        refreshBackdropGradientForCurrentTheme()
        
        // Update calendar appearance & refresh
        if let cal = self.calendar {
            // Header & weekday background colours
            cal.calendarHeaderView.backgroundColor = todoColors.accentPrimary.withAlphaComponent(0.5)
            cal.calendarWeekdayView.backgroundColor = todoColors.accentPrimaryPressed
        }
        if let cal = self.calendar {
            cal.appearance.selectionColor = todoColors.accentPrimary
            cal.appearance.todayColor = todoColors.accentPrimary
            cal.appearance.headerTitleColor = todoColors.accentPrimary
            cal.appearance.weekdayTextColor = todoColors.accentPrimary
            cal.backgroundColor = todoColors.accentPrimary.withAlphaComponent(0.05)
            cal.collectionView.backgroundColor = cal.backgroundColor
            // Reapply full appearance settings (header, weekday, selection etc.)
            DispatchQueue.main.async {
                self.setupCalAppearence()
            }
        }
        // Reload task list to reflect accent changes.
        refreshHomeTaskList(reason: "applyTheme")
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
        
        // Calendar button - Using 3D icon
        let calendarImage = UIImage(named: "cal")
        let calendarImageResized = calendarImage?.resized(to: iconSize)
        let calendarItem = UIBarButtonItem(image: calendarImageResized?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(toggleCalendar))
        calendarItem.accessibilityLabel = "Calendar"
        calendarItem.accessibilityIdentifier = "home.calendarButton"

        // Charts/Analytics button - Using 3D icon
        let chartImage = UIImage(named: "charts")
        let chartImageResized = chartImage?.resized(to: iconSize)
        let chartItem = UIBarButtonItem(image: chartImageResized?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(toggleCharts))
        chartItem.accessibilityLabel = "Analytics"
        chartItem.accessibilityIdentifier = "home.chartsButton"

        // Search button - Using 3D icon
        let searchImage = UIImage(named: "search")
        let searchImageResized = searchImage?.resized(to: iconSize)
        let searchItem = UIBarButtonItem(image: searchImageResized?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(searchButtonTapped))
        searchItem.accessibilityLabel = "Search Tasks"
        searchItem.accessibilityIdentifier = "home.searchButton"

        // Chat button (rightmost) - Using 3D icon
        let chatImage = UIImage(named: "chat")
        let chatImageResized = chatImage?.resized(to: iconSize)
        let chatButtonItem = UIBarButtonItem(image: chatImageResized?.withRenderingMode(.alwaysOriginal), style: .plain, target: self, action: #selector(chatButtonTapped))
        chatButtonItem.accessibilityLabel = "Chat with LLM"
        chatButtonItem.accessibilityIdentifier = "home.chatButton"

        // Configure the bottom app bar with 4 buttons (removed settings)
        lgBottomBar.configureStandardAppBar(
            leadingItems: [calendarItem, chartItem, searchItem, chatButtonItem],
            trailingItems: [],
            showFloatingButton: true
        )
        
        // Configure floating action button
        let fab = lgBottomBar.floatingButton
        let addTaskImage = UIImage(named: "add_task") ?? UIImage(systemName: "plus")
        fab.setImage(addTaskImage, for: .normal)
        fab.backgroundColor = todoColors.accentMuted
        fab.addTarget(self, action: #selector(AddTaskAction), for: .touchUpInside)
        fab.tintColor = todoColors.accentOnPrimary
        fab.accessibilityIdentifier = "home.addTaskButton"

        // Set tint color to match theme
        lgBottomBar.tintColor = todoColors.accentOnPrimary
        
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

        // Phase 7: Update horizontally scrollable chart cards (line + radar) and daily score
        print("📊 Updating Chart Cards ScrollView (Line + Radar) and daily score...")
        self.updateChartCardsScrollView()
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
        // TODO: Use repository once it has fetchAllTasks method
        // For now, use direct CoreData access
        if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()

            do {
                let allTasks = try context.fetch(request)
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
                    try context.save()
                    print("✅ Fixed \(fixedCount) tasks with invalid priorities")
                } else {
                    print("✅ All task priorities are valid")
                }
            } catch {
                print("❌ Error fixing invalid priorities: \(error)")
            }
        }
    }
    
    /// Returns a dictionary of counts of completed tasks grouped by priority for a given date
    /// Priorities: 1=None, 2=Low, 3=High, 4=Max
    func priorityBreakdown(for date: Date) -> [Int32: Int] {
        // Use raw values to avoid enum compilation issues
        var counts: [Int32: Int] = [1: 0, 2: 0, 3: 0, 4: 0] // none, low, high, max

        // TODO: Use repository once it has fetchAllTasks method
        // For now, use direct CoreData access
        var allTasks: [NTask] = []
        if let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            allTasks = (try? context.fetch(request)) ?? []
        }

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
            // Fallback: Use TaskScoringService with a default repository if none exists
            // This should never happen in production but provides safety
            print("⚠️ Warning: taskRepository is nil in updateDailyScore, this should not happen")
            // Fallback to 0 score to avoid crashing
            DispatchQueue.main.async { [weak self] in
                self?.scoreCounter.text = "0"
                self?.updateNavigationBarTitle(date: targetDate, score: 0)
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

        // Phase 7: Hide this old single chart - we now use chartScrollContainer with horizontal scrolling
        container.isHidden = true
    }

    /// Updates the horizontally scrollable chart cards (line + radar) with the latest data.
    func updateChartCardsScrollView() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self,
                  let container = self.chartScrollContainer else {
                print("⚠️ updateChartCardsScrollView: chartScrollContainer is nil")
                return
            }

            // Remove old hosting controller
            if let oldHost = self.chartScrollHostingController {
                oldHost.willMove(toParent: nil)
                oldHost.view.removeFromSuperview()
                oldHost.removeFromParent()
            }

            // Create a fresh chart scroll view and hosting controller with updated data
            let chartScrollView = ChartCardsScrollView(referenceDate: self.dateForTheView)
            let newHost = UIHostingController(rootView: AnyView(chartScrollView))
            self.chartScrollHostingController = newHost

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

            print("📊 Chart Cards ScrollView (Line + Radar) completely rebuilt with latest data")
        }
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
