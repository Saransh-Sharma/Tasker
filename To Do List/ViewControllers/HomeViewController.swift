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

class HomeViewController: UIViewController, ChartViewDelegate, MDCRippleTouchControllerDelegate, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: - Stored Properties
    
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
    var shouldHideData: Bool = false
    var tinyPieChartSections: [String] = ["Done", "In Progress", "Not Started", "Overdue"]
    
    // Calendar and TableView
    var calendar: FSCalendar!
    var tableView = UITableView()
    
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
    
    
    // State flags
    var isGrouped: Bool = false {
        didSet {
            tableView.reloadData()
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
        
        // Setup table view
        self.setupTableView()
        
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
        tableView.reloadData()
        animateTableViewReload()
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
    
    // MARK: - Navigation Actions
    
    @objc func onMenuButtonTapped() {
        // Handle menu button tap
        // This might open a side menu or settings panel
    }
    
    @objc func AddTaskAction() {
        // Present add task interface
        let addTaskVC = AddTaskViewController()
        addTaskVC.delegate = self
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
        tableView.reloadData()
        animateTableViewReload()
    }
}

// MARK: - AddTaskViewControllerDelegate Extension

extension HomeViewController: AddTaskViewControllerDelegate {
    func didAddTask(_ task: NTask) {
        // Handle new task added
        // Refresh the current view with the new task
        refreshHomeView()
    }
}
