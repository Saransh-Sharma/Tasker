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
//import BEMCheckBox
import TinyConstraints
import MaterialComponents.MaterialButtons
import MaterialComponents.MaterialBottomAppBar
import SwiftUI // For UIHostingController and SettingsView
import MaterialComponents.MaterialButtons_Theming
import MaterialComponents.MaterialRipple


// ToDoListViewType enum definition moved to main class file for better visibility across extensions
enum ToDoListViewType {
    case todayHomeView
    case customDateView
    case projectView
    case upcomingView
    case historyView
    case allProjectsGrouped
    case selectedProjectsGrouped
}

class HomeViewController: UIViewController, ChartViewDelegate, MDCRippleTouchControllerDelegate, BadgeViewDelegate {
    
    var shouldAnimateCells = true
    
    //MARK:- Backdrop & Fordrop parent containers
    var backdropContainer = UIView()
    var foredropContainer = UIView()
    var bottomBarContainer = UIView()
    
    let lineSeparator = UIView()
    
    let notificationCenter = NotificationCenter.default
    
    //MARK:- Positioning
    var headerEndY: CGFloat = 128
    //    var headerEndY: CGFloat = UIScreen.main.bounds.height/6
    var todoColors = ToDoColors()
    var todoTimeUtils = ToDoTimeUtils()
    
    var editingTaskForDatePicker: NTask?
    var activeTaskDetailViewFluent: TaskDetailViewFluent?
    var editingTaskForProjectPicker: NTask?
    // Property to store the presented detail view and its overlay
    var presentedFluentDetailView: TaskDetailViewFluent?
    var overlayView: UIView?
    
    
    var filledBar: UIView?
    
    
    
    //init notification badge counter
    var notificationBadgeNumber:Int = 0
    
    let ultraLightConfiguration = UIImage.SymbolConfiguration(weight: .regular)
    var highestPrioritySymbol = UIImage()//UIImage(systemName: "circle.fill",withConfiguration: ultraLightConfiguration)?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal)
    var highPrioritySymbol = UIImage()//UIImage(systemName: "circle",withConfiguration: ultraLightConfiguration)?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal)
    
    
    func didSelectBadge(_ badge: BadgeView) {
    }
    
    var ToDoListSections: [ToDoListData.Section] = []
    var listSection: ToDoListData.Section? = nil
    
    var openTaskCheckboxTag = 0
    var currentIndex:IndexPath = [0,0]
    
    let toDoListHeaderLabel = UILabel()
    
    public var isGrouped: Bool = false {
        didSet {
            updateTableView()
        }
    }
    
    func createProjectsBar(
        items: [PillButtonBarItem],
        style: PillButtonStyle = .primary,
        centerAligned: Bool = false
    ) -> UIView {
        // 1) Create the bar with the valid style
        let bar = PillButtonBar(pillButtonStyle: style)
        bar.items = items
        _ = bar.selectItem(atIndex: 1)
        bar.barDelegate = self
        bar.centerAligned = centerAligned
        
        // 2) Wrap it in a FluentUI background view
        let backgroundStyle: ColoredPillBackgroundStyle = (style == .onBrand) ? .brandNavBar : .neutralNavBar
        let backgroundView = ColoredPillBackgroundView(style: backgroundStyle)
        backgroundView.addSubview(bar)
        let margins = UIEdgeInsets(top: 16.0, left: 0, bottom: 16.0, right: 0.0)
        fitViewIntoSuperview(bar, margins: margins)
        return backgroundView
    }
    
    var filterProjectsPillBar: UIView?
    var bar = PillButtonBar(pillButtonStyle: .primary)
    //    var currenttProjectForAddTaskView = "inbox"
    
    var pillBarProjectList: [PillButtonBarItem] = []
    
    static let margin: CGFloat = 16
    static let horizontalSpacing: CGFloat = 40
    static let verticalSpacing: CGFloat = 16
    static let rowTextWidth: CGFloat = 75
    
    class func createVerticalContainer() -> UIStackView {
        let container = UIStackView(frame: .zero)
        container.axis = .vertical
        container.layoutMargins = UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
        container.isLayoutMarginsRelativeArrangement = true
        container.spacing = verticalSpacing
        return container
    }
    
    class func createTopHeaderVerticalContainer() -> UIStackView {
        let container = UIStackView(frame: .zero)
        container.axis = .vertical
        container.layoutMargins = UIEdgeInsets(top: 4, left: 4, bottom: 4, right: 4)
        container.isLayoutMarginsRelativeArrangement = true
        container.spacing = verticalSpacing
        return container
    }
    
    func didTapSelectedBadge(_ badge: BadgeView) {
        badge.isSelected = false
        let alert = UIAlertController(title: "A selected badge was tapped", message: nil, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alert.addAction(action)
        present(alert, animated: true)
    }
    

    
    
    //MARK:- LINE CHART
    lazy var lineChartView: LineChartView = {
        let chartView = LineChartView()
        chartView.backgroundColor = .clear
        chartView.legend.form = .default
        
        
        chartView.rightAxis.enabled = false
        
        let yAxis = chartView.leftAxis
        yAxis.labelFont = .boldSystemFont(ofSize: 12)
        yAxis.labelTextColor = .secondaryLabel
        yAxis.axisLineColor = .tertiaryLabel
        yAxis.labelPosition = .outsideChart
        
        
        chartView.xAxis.labelPosition = .bottom
        chartView.xAxis.labelFont = .systemFont(ofSize: 8) //.boldSystemFont(ofSize: 8)
        chartView.xAxis.axisLineColor = .tertiaryLabel
        chartView.xAxis.labelTextColor = .label
        //        chartView.xAxis.setLabelCount(10, force: true)
        chartView.xAxis.labelRotationAngle = 0
        //        chartView.xAxis.text
        chartView.xAxis.valueFormatter = DayAxisValueFormatter(chart: chartView) //replace date labels here
        
        return chartView
    }()
    
    //MARK: Pie Chart Data Sections
    let tinyPieChartSections = [""]
    
    //MARK:- cuurentt task list date & project
    var dateForTheView = Date.today()
    var projectForTheView = ProjectManager.sharedInstance.defaultProject
    var currentViewType = ToDoListViewType.todayHomeView
    
    // Project filtering state variables
    var selectedProjectNamesForFilter: [String] = []
    var projectsToDisplayAsSections: [Projects] = []
    var tasksGroupedByProject: [String: [NTask]] = [:]
    
    var firstDay = Date.today()
    var nextDay = Date.today()
    
    //MARK:- score for day label
    var scoreForTheDay: UILabel! = nil
    
    //MARK:- Buttons + Views + Bottom bar
    var calendar: FSCalendar!
    let fab_revealCalAtHome = MDCFloatingButton(shape: .mini)
    let revealCalAtHomeButton = MDCButton()
    let revealChartsAtHomeButton = MDCButton()
    
    let homeDate_Day = UILabel()
    let homeDate_WeekDay = UILabel()
    let homeDate_Month = UILabel()
    
    //MARK: charts
    let tinyPieChartView = PieChartView()
    var shouldHideData: Bool = false
    var sliderX: UISlider!
    var sliderY: UISlider!
    var sliderTextX: UITextField!
    var sliderTextY: UITextField!
    
    var seperatorTopLineView = UIView()
    var backdropNochImageView = UIImageView()
    var backdropBackgroundImageView = UIImageView()
    var backdropForeImageView = UIImageView()
    let backdropForeImage = UIImage(named: "backdropFrontImage")
    var homeTopBar = UIView()
    let dateAtHomeLabel = UILabel()
    let scoreCounter = UILabel()
    let scoreAtHomeLabel = UILabel()
    var bottomAppBar = MDCBottomAppBarView()
    var isCalDown: Bool = false
    var isChartsDown: Bool = false
    
    let toDoAnimations:ToDoAnimations = ToDoAnimations()
    
    //MARK:- Circle menu init
    let circleMenuItems: [(icon: String, color: UIColor)] = [
        //        ("icon_home", UIColor(red: 0.19, green: 0.57, blue: 1, alpha: 1)),
        ("", .clear),
        ("icon_search", UIColor(red: 0.22, green: 0.74, blue: 0, alpha: 1)),
        ("notifications-btn", UIColor(red: 0.96, green: 0.23, blue: 0.21, alpha: 1)),
        ("settings-btn", UIColor(red: 0.51, green: 0.15, blue: 1, alpha: 1)),
        //        ("nearby-btn", UIColor(red: 1, green: 0.39, blue: 0, alpha: 1))
        ("", .clear)
    ]
    
    // MARK: Outlets
    @IBOutlet weak var addTaskButton: UIButton!
    //    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var switchState: UISwitch!
    
    public var tableView: UITableView!
    
    //MARK: Theming: text color
    var scoreInTinyPieChartColor:UIColor = UIColor.white
    
    //MARK: Fonts:
    //    var titleFont_1:UIFont = setFont
    //    var scoreNumberFont:UIFont = setFont(fontSize: 40, fontweight: .bold, fontDesign: .rounded)
    
    //MARK:- Elevation + Shadows:
    let bottomBarShadowElevation: ShadowElevation = ShadowElevation(rawValue: 8)
    
    /// where the foredrop started
    var originalForedropCenterY: CGFloat = 0
    /// how far we need to push it down
    var revealDistance: CGFloat    = 0
    /// are we currently “dropped”?
    var isBackdropRevealed: Bool   = false
    /// closed Y position of foredrop for hide animations
    var foredropClosedY: CGFloat   = 0
    
    func getTaskForTodayCount() -> Int {
        var morningTasks = [NTask]()
        var eveTasks = [NTask]()
        
        morningTasks = TaskManager.sharedInstance.getMorningTasksForToday()
        eveTasks = TaskManager.sharedInstance.getEveningTasksForToday()
        
        return morningTasks.count + eveTasks.count
    }
    
    
    //-------- NEW SET VIEW -----------------
    //-------- NEW SET VIEW -----------------
    //-------- NEW SET VIEW -----------------
    //-------- NEW SET VIEW -----------------
    
    
    
    
    public func setDateForViewValue(dateToSetForView: Date){
        dateForTheView = dateToSetForView
    }
    
    func setProjectForViewValue(projectName: String){ //check if the
        // projecct name exists in existing projeccts
        
        if projectName.lowercased() == ProjectManager.sharedInstance.defaultProject.lowercased() {
            projectForTheView = projectName
            print("woo : PROJCT IS DEFAULT - INBOX")
        } else {
            let projectsList = ProjectManager.sharedInstance.projects
        
            print("----------")
            for each in projectsList {
                
                print("project is: \(each.projectName! as String)")
                
            }
            print("----------")
            
            for each in projectsList {
                if projectName.lowercased() == each.projectName?.lowercased() {
                    print("woohoo ! project set to: \(String(describing: each.projectName?.lowercased()))")
                    projectForTheView = projectName
                }
            }
        }
        
    }
    
    //-------- NEW SET VIEW END -----------------
    //-------- NEW SET VIEW -----------------
    
    func prepareAndFetchTasksForProjectGroupedView() {
        self.projectsToDisplayAsSections.removeAll()
        self.tasksGroupedByProject.removeAll()

        let projectsToFilter: [Projects]
        let allManagedProjects = ProjectManager.sharedInstance.displayedProjects // Already sorted, includes "Inbox"

        switch self.currentViewType {
            case .allProjectsGrouped:
                projectsToFilter = allManagedProjects
            case .selectedProjectsGrouped:
                // Ensure "Inbox" is handled correctly if selected
                projectsToFilter = allManagedProjects.filter { project in
                    guard let projectName = project.projectName else { return false }
                    return selectedProjectNamesForFilter.contains(projectName)
                }
            default:
                return // Not a project-grouped view
        }

        for project in projectsToFilter {
            guard let projectName = project.projectName else { continue }
            // Fetch ONLY OPEN tasks for the current 'dateForTheView'
            let openTasksForProject = TaskManager.sharedInstance.getTasksForProjectByNameForDate_Open(
                projectName: projectName,
                date: self.dateForTheView
            )

            if !openTasksForProject.isEmpty {
                self.projectsToDisplayAsSections.append(project) // This array defines section order
                self.tasksGroupedByProject[projectName] = openTasksForProject
            }
        }
    }
    
    //-------- NEW SET VIEW  END-----------------
    func generateLineChartData() -> [ChartDataEntry] {
        
        var yValues: [ChartDataEntry] = []
        
        
        var calendar = Calendar.autoupdatingCurrent
        calendar.firstWeekday = 2 // Start on Monday (or 1 for Sunday)
        let today = Date.today()//calendar.startOfDay(for: Date())
        //        let firstJan = calendar.year
        var week = [Date]()
        if let weekInterval = calendar.dateInterval(of: .weekOfYear, for: today) {
            for i in 0...6 {
                if let day = calendar.date(byAdding: .day, value: i, to: weekInterval.start) {
                    week += [day]
                }
            }
        }
        
        
        
        let components2 = DateComponents(calendar: Calendar.current, year: 2021, month: 1, day: 1)
        let FirstJan = components2.date
        print("**calFixx: dd \(String(describing: FirstJan))")
        //print("**calFixx: DAYS SINCE \(daysSince(from: FirstJan!, to: Date.today()))")
        
        print("**calFixx: ---------------")
        for d in week {
            print("**calFixx START ------: \(d.dateString(in: .short))")
            print("**calFixx DAY IS ------: \(d.day)")
            print("**calFixx debug desc \(d.debugDescription)")
            //            yValues.append(ChartDataEntry(x: Double(d.day), y: Double(3)))
            
            let count2 = (daysSince(from: FirstJan!, to: d))
            print("**calFixx: date is : \(d.debugDescription)")
            print("**calFixx: DAYS SINCE REAL \(count2)")
            print("**calFixx: score for day : \(calculateScoreForDate(date: d))")
            yValues.append(ChartDataEntry(x: Double(count2+2), y: Double(calculateScoreForDate(date: d))))
            
            
            print("**calFixx END ------: ")
            
        }
        print("**calFixx: ---------------")
        print("**calFixx FINAL count is \(yValues.count)")
        
        return yValues
    }
    
    /// Returns the amount of days from another date
    func daysSince(from date: Date, to taegetDate: Date) -> Int {
        return Calendar.current.dateComponents([.day], from: date, to: taegetDate).day ?? 0
    }
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        
        print("You selected data: \(entry)")
    }
    
    
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        shouldAnimateCells = false
    }
    
    
    //MARK:- View did load
    override func viewDidLoad() {
        super.viewDidLoad()
        
        highestPrioritySymbol = (UIImage(systemName: "circle.fill",withConfiguration: ultraLightConfiguration)?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal))!
        highPrioritySymbol = (UIImage(systemName: "circle",withConfiguration: ultraLightConfiguration)?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal))!
        
        
        //--------
        view.addSubview(backdropContainer)
        dateForTheView = Date.today()
        
        setupBackdrop()
        
        
        
        tableView = UITableView(frame: view.bounds, style: .grouped)
        tableView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        tableView.register(TableViewCell.self, forCellReuseIdentifier: TableViewCell.identifier)
        tableView.register(TableViewHeaderFooterView.self, forHeaderFooterViewReuseIdentifier: TableViewHeaderFooterView.identifier)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.separatorStyle = .none
        tableView.sectionFooterHeight = 0
        updateTableView()
        
        
        
        view.addSubview(foredropContainer)
        setupHomeFordrop()
        
        
        
        setupBottomAppBar()
        view.addSubview(bottomAppBar)
        print("bottom height minY \(bottomAppBar.bounds.minY)")
        print("bottom height maxY \(bottomAppBar.bounds.maxY)")
        
        //fixes log table hiding under app bar
        tableView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height:  UIScreen.main.bounds.height - (headerEndY + headerEndY/2))
        
        view.bringSubviewToFront(bottomAppBar)
        
        //        setupBadgeCount()
        enableDarkModeIfPreset()
        
        
        
        
        notificationCenter.addObserver(self, selector: #selector(appMovedToForeground), name:UIApplication.willEnterForegroundNotification, object: nil)
        
        notificationCenter.addObserver(self, selector: #selector(appMovedToBackground), name:UIApplication.didEnterBackgroundNotification, object: nil)
        
        
        
        ProjectManager.sharedInstance.refreshAndPrepareProjects()
        
        print("Project count is: \(ProjectManager.sharedInstance.count)")
        
        
        
        ProjectManager.sharedInstance.refreshAndPrepareProjects()
        
        
        let mProjects = ProjectManager.sharedInstance.projects
        
        print("----------")
        for each in mProjects {
            
            print("project is: \(each.projectName! as String)")
            
        }
        print("----------")
        
        
        //        print("POST DELETE Project count: \(ProjectManager.sharedInstance.count)")
        
        //        fixMissingDataWithDefaults
        TaskManager.sharedInstance.fixMissingTasksDataWithDefaults()
        ProjectManager.sharedInstance.fixMissingProjecsDataWithDefaults()
        
        print("---------- DONE VIEW LOAD ------------")
        
        
    }
    @objc
    func appMovedToForeground() {
        print("App moved to ForeGround!")
        toDoAnimations.animateTinyPieChartAtHome(pieChartView: tinyPieChartView)
//        toDoAnimations.animateLineChartAtHome(lineChartView: lineChartView)
        
        updateLineChartData()
        
        updateHomeDateLabel(date: dateForTheView)
        
        if dateForTheView == Date.today() {
            print("###### Today !")
            
            
        } else if dateForTheView != Date.today() {
            print("###### NOT TODAY")
            
            
            updateHomeDateLabel(date: dateForTheView)
            calendar.reloadData()
            setupCalAppearence()
            calendar.appearance.calendar.reloadData()
            tableView.reloadData()
            
            
        }
        
        self.calendar.today = nil; // 1 this call order ensures today's circle moves
        self.calendar.today = Date.today() // 2 on date change a 12 AM
        
        
    }
    
    func createButton(title: String, action: Selector) -> FluentUI.Button {
        let button = Button()
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
        let constraints = [view.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: margins.left),
                           view.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: -margins.right),
                           view.topAnchor.constraint(equalTo: superview.topAnchor, constant: margins.top),
                           view.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: -margins.bottom)]
        
        NSLayoutConstraint.activate(constraints)
    }
    
    
    
    @objc
    func appMovedToBackground() {
        print("App moved to Background!")
        setupBadgeCount()
        
        
        
    }
    
    @objc
    func appTerminated() {
        print("App moved to DED !")
        
    }
    
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self, name:UIApplication.willResignActiveNotification, object: nil)
        NotificationCenter.default.removeObserver(self, name:UIApplication.willEnterForegroundNotification, object: nil)
    }
    
    
    
    // MARK:- View Lifecycle methods
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        // right spring animation
        //        tableView.reloadData(
        //            with: .spring(duration: 0.45, damping: 0.65, velocity: 1, direction: .right(useCellsFrame: false),
        //                          constantDelay: 0))
        tableView.reloadData()
        
        print("resume88")
        animateTableViewReload()
//        animateLineChart(chartView: self.lineChartView)
        //        UIView.animate(views: tableView.visibleCells, animations: animations, completion: {
        
        //        })
    }
    
    // MARK:- Build Page Header
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func createBadge(text: String, style: BadgeView.Style, isEnabled: Bool) -> BadgeView {
        let badge = BadgeView(dataSource: BadgeViewDataSource(text: text, style: style))
        badge.delegate = self
        badge.isActive = isEnabled
        return badge
    }
    
    func setupBadgeCount()  {
        //Badge number //BUG: badge is rest only after killing the app; minimising doesnt reset badge to correct value
        let application = UIApplication.shared
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.badge, .alert, .sound]) { (OnSuccess, OnError) in
            print("Success !")
        }
        if(getTaskForTodayCount() > 0) {
            
            application.applicationIconBadgeNumber = getTaskForTodayCount()
        } else {
            application.applicationIconBadgeNumber =  0
        }
        
        application.registerForRemoteNotifications()
    }
    
    
    
    func serveSemiViewRed() -> UIView {
        
        let view = UIView(frame: UIScreen.main.bounds)
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 300)
        view.backgroundColor =  #colorLiteral(red: 0.2039215686, green: 0, blue: 0.4078431373, alpha: 1)
        
        let mylabel = UILabel()
        mylabel.frame = CGRect(x: 20, y: 25, width: 370, height: 50)
        mylabel.text = "This is placeholder text"
        mylabel.textAlignment = .center
        mylabel.backgroundColor = .white
        view.addSubview(mylabel)
        
        return view
    }
    
    
    
    
    
    
    
    
    func serveSemiViewBlue(task: NTask) -> UIView { //TODO: put each of this in a tableview
        
        let view = UIView(frame: UIScreen.main.bounds)
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 300)
        //        view.backgroundColor =  #colorLiteral(red: 0.2039215686, green: 0, blue: 0.4078431373, alpha: 1)
        view.backgroundColor = todoColors.backgroundColor
        let frameForView = view.bounds
        
        let taskName = UILabel() //Task Name
        view.addSubview(taskName)
        taskName.frame = CGRect(x: frameForView.minX, y: frameForView.minY, width: frameForView.width, height: frameForView.height/5)
        taskName.text = task.name
        taskName.textAlignment = .center
        taskName.backgroundColor = .black
        taskName.textColor = UIColor.white
        
        let eveningLabel = UILabel() //Evening Label
        view.addSubview(eveningLabel)
        eveningLabel.text = "evening task"
        eveningLabel.textAlignment = .left
        eveningLabel.textColor =  todoColors.primaryColor
        eveningLabel.frame = CGRect(x: frameForView.minX+40, y: frameForView.minY+85, width: frameForView.width-100, height: frameForView.height/8)
        
        let eveningSwitch = UISwitch() //Evening Switch
        view.addSubview(eveningSwitch)
        eveningSwitch.onTintColor = todoColors.primaryColor
        
        if(Int(task.taskType) == 2) {
            print("Task type is evening; 2")
            eveningSwitch.setOn(true, animated: true)
        } else {
            print("Task type is NOT evening;")
            eveningSwitch.setOn(false, animated: true)
        }
        eveningSwitch.frame = CGRect(x: frameForView.maxX-80, y: frameForView.minY+85, width: frameForView.width-100, height: frameForView.height/8)
        
        
        let p = ["None", "Low", "High", "Highest"]
        let prioritySegmentedControl = UISegmentedControl(items: p) //Task Priority
        view.addSubview(prioritySegmentedControl)
        prioritySegmentedControl.selectedSegmentIndex = 1
        prioritySegmentedControl.backgroundColor = .white
        prioritySegmentedControl.selectedSegmentTintColor =  todoColors.primaryColor
        
        
        
        prioritySegmentedControl.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.white], for: UIControl.State.selected)
        
        prioritySegmentedControl.frame = CGRect(x: frameForView.minX+20, y: frameForView.minY+150, width: frameForView.width-40, height: frameForView.height/7)
        
        
        let datePicker = UIDatePicker() //DATE PICKER //there should not be a date picker here //there can be calendar icon instead
        view.addSubview(datePicker)
        datePicker.datePickerMode = .date
        datePicker.timeZone = NSTimeZone.local
        datePicker.backgroundColor = UIColor.white
        
        //Set minimum and Maximum Dates
        let calendar = Calendar(identifier: .gregorian)
        var comps = DateComponents()
        comps.month = 1
        let maxDate = calendar.date(byAdding: comps, to: Date())
        comps.month = 0
        comps.day = -1
        let minDate = calendar.date(byAdding: comps, to: Date())
        datePicker.maximumDate = maxDate
        datePicker.minimumDate = minDate
        datePicker.frame = CGRect(x: frameForView.minX+30, y: frameForView.minY+230, width: frameForView.width-60, height: frameForView.height/8)
        
        
        return view
    }
    
    
    
    func semiViewDefaultOptions(viewToBePrsented: UIView) {
        let options: [SemiModalOption : Any] = [
            SemiModalOption.pushParentBack: true,
            SemiModalOption.animationDuration: 0.2
        ]
        
        presentSemiView(viewToBePrsented, options: options) {
            print("Completed!")
        }
    }
    
    
    
    
    
    
    /*
     Checks & enables dark mode if user previously set such
     */
    func enableDarkModeIfPreset() {
        if UserDefaults.standard.bool(forKey: "isDarkModeOn") {
            //switchState.setOn(true, animated: true)
            //            print("HOME: DARK ON")
            view.backgroundColor = UIColor.darkGray
        } else {
            //            print("HOME: DARK OFF !!")
            view.backgroundColor =  todoColors.backgroundColor
        }
    }
    
    
    // MARK: calculate today's score
    /*
     Calculates daily productivity score
     */
    func calculateTodaysScore() -> Int { //TODO change this to handle NTASKs
        var score = 0
        
        let morningTasks: [NTask]
        if(dateForTheView == Date.today()) {
            print ("score: getting today's tasks")
            morningTasks = TaskManager.sharedInstance.getMorningTasksForToday()
        } else { //get morning tasks without rollover
            print ("score: getting custom date tasks")
            morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: dateForTheView)
        }
        let eveningTasks: [NTask]
        if(dateForTheView == Date.today()) {
            eveningTasks = TaskManager.sharedInstance.getEveningTasksForToday()
        } else { //get morning tasks without rollover
            eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
        }
        
        //        let morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: dateForTheView)
        //        let eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
        
        for each in morningTasks {
            
            if each.dateCompleted != nil {
                print("It has some value !")
                if each.isComplete && dateForTheView == each.dateCompleted! as Date {
                    
                    
                    score = score + each.getTaskScore(task: each)
                }
            } else {
                print("doesn't contain value")
            }
            
        }
        for each in eveningTasks {
            if each.isComplete {
                score = score + each.getTaskScore(task: each)
            }
        }
        return score;
    }
    
    // MARK: calculate today's score
    /*
     Calculates daily productivity score
     */
    func calculateScoreForDate(date: Date) -> Int { //TODO change this to handle NTASKs
        var score = 0
        let allTasks: [NTask]
        allTasks = TaskManager.sharedInstance.getAllTasks
        for d in allTasks {
            if d.dateCompleted != nil {
                if date == d.dateCompleted! as Date {
                    score = score + d.getTaskScore(task: d)
                }
            }
        }
        return score;
    }
    
    // MARK: calculate today's score
    /*
     Calculates daily productivity score
     */
    func calculateScoreForProject(project: String) -> Int { //TODO change this to handle NTASKs
        var score = 0
        //let projectTasks: [NTask]
        
        //        if project.lowercased() == ProjectManager.share {
        //            // show default home view
        //        }
        //projectTasks = TaskManager.sharedInstance.getTasksForProjectByName(projectName: project)
        
        
        let morningTasks: [NTask]
        if(dateForTheView == Date.today()) {
            morningTasks = TaskManager.sharedInstance.getMorningTasksForToday()
        } else { //get morning tasks without rollover
            morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: dateForTheView)
        }
        let eveningTasks: [NTask]
        if(dateForTheView == Date.today()) {
            eveningTasks = TaskManager.sharedInstance.getEveningTasksForToday()
        } else { //get morning tasks without rollover
            eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
        }
        
        //        let morningTasks = TaskManager.sharedInstance.getMorningTasksForDate(date: dateForTheView)
        //        let eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
        
        for each in morningTasks {
            
            if each.isComplete {
                
                score = score + each.getTaskScore(task: each)
            }
        }
        for each in eveningTasks {
            if each.isComplete {
                score = score + each.getTaskScore(task: each)
            }
        }
        return score;
    }
    
    
    
    // MARK: toggle dark mode
    
    
    /*
     Toggles Dark Mode
     */
    @IBAction func toggleDarkMode(_ sender: Any) {
        
        let mSwitch = sender as! UISwitch
        
        if mSwitch.isOn {
            view.backgroundColor = UIColor.darkGray
            
            UserDefaults.standard.set(true, forKey: "isDarkModeOn")
            
        } else {
            UserDefaults.standard.set(false, forKey: "isDarkModeOn")
            view.backgroundColor = UIColor.white
        }
    }
    
    
    
    
    @IBAction func changeBackground(_ sender: Any) {
        view.backgroundColor = UIColor.black
        
        let everything = view.subviews
        
        for each in everything {
            // is it a label
            if(each is UILabel) {
                let currenLabel = each as! UILabel
                currenLabel.textColor = UIColor.red
            }
            
            //each.backgroundColor = UIColor.red
        }
    }
    
    
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                  ANIMATION: MOVE BY OFFSETS
    //----------------------- *************************** -----------------------
    
    //MARK:- Animation Move Offses
    
    func moveRight(view: UIView) {
        view.center.x += 300
    }
    
    func moveLeft(view: UIView) {
        view.center.x -= 300
    }
    //----------------------- *************************** -----------------------
    //MARK:-                ANIMATION: MOVE FOR CAL
    //----------------------- *************************** -----------------------
    func moveDown_revealJustCal(view: UIView) {
        isCalDown = true
        print("move: Cal SHOW - down: \(UIScreen.main.bounds.height/6)")
        view.center.y += UIScreen.main.bounds.height/6
    }
    func moveUp_toHideCal(view: UIView) {
        isCalDown = false
        print("move: Cal HIDE - up: \(UIScreen.main.bounds.height/6)")
        view.center.y -= UIScreen.main.bounds.height/6
    }
    
    //    func moveUp_hideCalFurther(view: UIView) { //
    //           isCalDown = false
    //           view.center.y -= (150+50)
    //       }
    //----------------------- *************************** -----------------------
    //MARK:-                ANIMATION: MOVE FOR CHARTS
    //----------------------- *************************** -----------------------
    func moveDown_revealCharts(view: UIView) {
        isChartsDown = true
        print("move: CHARTS SHOW - down: \(UIScreen.main.bounds.height/2)")
        view.center.y += UIScreen.main.bounds.height/2
    }
    func moveDown_revealChartsKeepCal(view: UIView) {
        isChartsDown = true
        print("move: CHARTS SHOW, CAL SHOW - down some: \(UIScreen.main.bounds.height/4 + UIScreen.main.bounds.height/12)")
        view.center.y += (UIScreen.main.bounds.height/4 + UIScreen.main.bounds.height/12)
    }
    func moveUp_hideCharts(view: UIView) {
        isChartsDown = false
        print("move: CHARTS HIDE - up: \(UIScreen.main.bounds.height/2)")
        view.center.y -= UIScreen.main.bounds.height/2
    }
    func moveUp_hideChartsKeepCal(view: UIView) {
        isChartsDown = false
        print("move: CHARTS HIDE, CAL SHOW - up some: \(UIScreen.main.bounds.height/4 + UIScreen.main.bounds.height/4)")
        view.center.y -= (UIScreen.main.bounds.height/4 + UIScreen.main.bounds.height/4)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                ANIMATION: LINE CHART ANIMATION
    //----------------------- *************************** -----------------------
    
    
    func animateLineChart(chartView: LineChartView) {
        chartView.animate(yAxisDuration: 1.1, easingOption: .easeInOutBack)
    }
    //----------------------- *************************** -----------------------
    //MARK:-                ANIMATION: WHOLE TABLE VIEW RELOAD
    //----------------------- *************************** -----------------------
    
    
    
    //MARK: animations
    func animateTableViewReload() {
        let zoomAnimation = AnimationType.zoom(scale: 0.5)
        let rotateAnimation = AnimationType.rotate(angle: CGFloat.pi/6)
        
        UIView.animate(views: tableView.visibleCells,
                       animations: [zoomAnimation, rotateAnimation],
                       duration: 0.3)
    }
    
    func animateTableViewReloadSingleCell(cellAtIndexPathRow: Int) {
        let zoomAnimation = AnimationType.zoom(scale: 0.5)
        let rotateAnimation = AnimationType.rotate(angle: CGFloat.pi/6)
        
        print("Only animating cell at: \(cellAtIndexPathRow)")
        UIView.animate(views: tableView.visibleCells(in: cellAtIndexPathRow),
                       animations: [zoomAnimation, rotateAnimation],
                       duration: 0.3)
        
        //        UIView.animate(views: tableView.cellForRow(at: <#T##IndexPath#>),
        //                               animations: [zoomAnimation, rotateAnimation],
        //                               duration: 0.3)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                ANIMATION: TABLE CELL RELOAD
    //----------------------- *************************** -----------------------
    
    func animateTableCellReload() {
        // Combined animations example
        //           let fromAnimation = AnimationType.from(direction: .right, offset: 70.0)
        let zoomAnimation = AnimationType.zoom(scale: 0.5)
        let rotateAnimation = AnimationType.rotate(angle: CGFloat.pi/6)
        //           UIView.animate(views: collectionView.visibleCells,
        //                          animations: [zoomAnimation, rotateAnimation],
        //                          duration: 0.5)
        
        UIView.animate(views: tableView.visibleCells,
                       animations: [zoomAnimation, rotateAnimation],
                       duration: 0.3)
        
        //           UIView.animate(views: tableView.visibleCells,
        //                          animations: [fromAnimation, zoomAnimation], delay: 0.3)
    }
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                        BOTTOM BAR + FAB
    //----------------------- *************************** -----------------------
    
    //MARK:- setup bottom bar
    func setupBottomAppBar() {
        bottomAppBar.floatingButton.setImage(UIImage(named: "material_add_White"), for: .normal)
        bottomAppBar.floatingButton.backgroundColor = todoColors.secondaryAccentColor //.systemIndigo
        bottomAppBar.frame = CGRect(x: 0, y: UIScreen.main.bounds.maxY-100, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.maxY-100)
        
        bottomAppBar.shadowColor = todoColors.primaryColor
        
        bottomAppBar.barTintColor = todoColors.primaryColor//primaryColor
        
        let ultraLightConfiguration = UIImage.SymbolConfiguration(weight: .regular)
        
        let boldLargeConfig = UIImage.SymbolConfiguration(pointSize: UIFont.systemFontSize, weight: .bold, scale: .large)
        let smallConfig = UIImage.SymbolConfiguration(scale: .small)
        let boldSmallConfig = boldLargeConfig.applying(smallConfig)

        
        // The following lines of code are to define the buttons on the right and left side
        let barButtonMenu = UIBarButtonItem(
//            image: UIImage(named:"material_menu_White"), // Icon
            image: UIImage(systemName: "gearshape.fill", withConfiguration: boldLargeConfig)?.withTintColor(.systemGray5, renderingMode: .alwaysOriginal), // Settings icon
            //icon_menu
            style: .plain,
            target: self,
            action: #selector(onMenuButtonTapped))
        
        let barButtonSearch = UIBarButtonItem(
            image: UIImage(systemName: "waveform.path.ecg",withConfiguration: boldLargeConfig)?.withTintColor(.systemGray5, renderingMode: .alwaysOriginal), // Icon
            style: .plain,
            target: self,
            action: #selector(toggleCharts)
        )
        let barButtonInbox = UIBarButtonItem(
            image: UIImage(systemName: "calendar", withConfiguration: boldLargeConfig)?.withTintColor(.systemGray5, renderingMode: .alwaysOriginal), // Icon
            style: .plain,
            target: self,
            action: #selector(toggleCalendar)
        )
        bottomAppBar.leadingBarButtonItems = [barButtonSearch, barButtonInbox, barButtonMenu]
        //                 bottomAppBar.trailingBarButtonItems = [barButtonTrailingItem]
        bottomAppBar.elevation = ShadowElevation(rawValue: 8)
        bottomAppBar.floatingButtonPosition = .trailing
        
        
        
        bottomAppBar.floatingButton.addTarget(self, action: #selector(AddTaskAction), for: .touchUpInside)
    }
    
    
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                ACTION: BOTTOMBAR BUTTON STUBS
    //----------------------- *************************** -----------------------
    
    @objc
    func onMenuButtonTapped() {
        print("menu button tapped - Presenting SwiftUI Settings")
        // let settingsVC = SettingsPageViewController() // OLD
        let swiftUISettingsView = SettingsView() // NEW
        let hostingController = UIHostingController(rootView: swiftUISettingsView) // NEW
        
        // Option 2: More direct if SettingsView handles its own NavigationView correctly for modal presentation
        // The SettingsView already has a NavigationView.
        hostingController.modalPresentationStyle = .fullScreen // Present the hosting controller directly

        // self.present(navController, animated: true, completion: nil) // If using Option 1
        self.present(hostingController, animated: true, completion: nil) // If using Option 2
    }
    
    @objc
    func onNavigationButtonTapped() {
        print("NAV button tapped")
    }
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                        ACTION: ADD TASK
    //----------------------- *************************** -----------------------
    
    @objc func AddTaskAction() {
        
        //       tap add fab --> addTask
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        //        let newViewController = storyBoard.instantiateViewController(withIdentifier: "addTask") as! NAddTaskScreen
        let newViewController = storyBoard.instantiateViewController(withIdentifier: "addNewTask") as! AddTaskViewController
        newViewController.modalPresentationStyle = .fullScreen
        self.present(newViewController, animated: true, completion: nil)
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                          UTIL: text,
    //----------------------- *************************** -----------------------
    
    //Mark: Util: set font
    func setFont(fontSize: CGFloat, fontweight: UIFont.Weight, fontDesign: UIFontDescriptor.SystemDesign) -> UIFont {
        
        // Here we get San Francisco with the desired weight
        let systemFont = UIFont.systemFont(ofSize: fontSize, weight: fontweight)
        
        // Will be SF Compact or standard SF in case of failure.
        let font: UIFont
        
        if let descriptor = systemFont.fontDescriptor.withDesign(fontDesign) {
            font = UIFont(descriptor: descriptor, size: fontSize)
        } else {
            font = systemFont
        }
        return font
    }
    
    
    
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                            DATE
    //----------------------- *************************** -----------------------
    
    //MARK: set passed date as day, week, month label text
    func updateHomeDateLabel(date: Date) {
        
        if("\(date.day)".count < 2) {
            self.homeDate_Day.text = "0\(date.day)"
        } else {
            self.homeDate_Day.text = "\(date.day)"
        }
        self.homeDate_WeekDay.text = todoTimeUtils.getWeekday(date: date)
        self.homeDate_Month.text = todoTimeUtils.getMonth(date: date)
        
    }
    
    
    
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                      GET GLOBAL TASK
    //----------------------- *************************** -----------------------
    /*
     Pass this a morning or evening or inbox or upcoming task &
     this will give the index of that task in the global task array
     using that global task array index the element can then be removed
     or modded
     */
    func getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: NTask) -> Int {
        var tasks = [NTask]()
        var idxHolder = 0
        tasks = TaskManager.sharedInstance.getAllTasks
        
        
        
        print("sls tatget task is: \(morningOrEveningTask.name)")
        
        if let idx = tasks.firstIndex(where: { $0.name == morningOrEveningTask.name }) {
            
            print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
            print("sls Marking task as complete: \(TaskManager.sharedInstance.getAllTasks[idx].name)")
            print("func IDX is: \(idx)")
            print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
            idxHolder = idx
            
            
            
        }
        return idxHolder
    }
    
    
    
//    @objc
//    func toggleCalendar() {
//        if isCalDown {
//            moveUp_toHideCal(view: calendar)
//        } else {
//            moveDown_revealJustCal(view: calendar)
//        }
//    }
//    
//    @objc
//    func toggleCharts() {
//        if isChartsDown {
//            moveUp_hideCharts(view: tinyPieChartView)
//        } else {
//            moveDown_revealCharts(view: tinyPieChartView)
//        }
//    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if foredropClosedY == 0 {
            foredropClosedY = foredropContainer.frame.minY
        }
    }

    // MARK: –––––––––––––––––––––––––––––––––––––––––––––––––––
    // Swiping & Reloading Helpers (required by ToDoList.swift)
    // MARK: –––––––––––––––––––––––––––––––––––––––––––––––––––

    /// Reload tableView, calendar & charts after a row‐level change
    func updateToDoListAndCharts(tableView: UITableView, indexPath: IndexPath) {
        tableView.reloadData()
        calendar.reloadData()
        updateLineChartData()
        animateTableViewReloadSingleCell(cellAtIndexPathRow: indexPath.row)
    }

    /// Mark a task as open (undo complete)
    func markTaskOpenOnSwipe(task: NTask) {
        task.isComplete = false
        task.dateCompleted = nil
        TaskManager.sharedInstance.saveContext()
    }

    /// Delete a task permanently on swipe
    func deleteTaskOnSwipe(task: NTask) {
        let idx = getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: task)
        TaskManager.sharedInstance.removeTaskAtIndex(index: idx)
        TaskManager.sharedInstance.saveContext()
    }

    /// Show action sheet to pick new due dates (Tomorrow, Day After, Next Week)
    func rescheduleAlertActionMenu(tasks: [NTask], indexPath: IndexPath, tableView: UITableView) {
        let current = dateForTheView
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: current)!
        let dayAfter = Calendar.current.date(byAdding: .day, value: 2, to: current)!
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: current)!

        let controller = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        controller.addAction(UIAlertAction(title: "Tomorrow", style: .default) { _ in
            TaskManager.sharedInstance.reschedule(task: tasks[indexPath.row], to: tomorrow)
            self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
        })
        controller.addAction(UIAlertAction(title: "Day After Tomorrow", style: .default) { _ in
            TaskManager.sharedInstance.reschedule(task: tasks[indexPath.row], to: dayAfter)
            self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
        })
        controller.addAction(UIAlertAction(title: "Next Week", style: .default) { _ in
            TaskManager.sharedInstance.reschedule(task: tasks[indexPath.row], to: nextWeek)
            self.updateToDoListAndCharts(tableView: tableView, indexPath: indexPath)
        })
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
}

// MARK: - Task Detail Selection
extension HomeViewController {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let date = dateForTheView
        var nTask: NTask

        switch currentViewType {
        case .todayHomeView, .customDateView:
            let customProjectTasks = TaskManager.sharedInstance.getTasksForAllCustomProjectsByNameForDate_Open(date: date)
            let inboxTasks = TaskManager.sharedInstance.getTasksForProjectByNameForDate_Open(
                projectName: ProjectManager.sharedInstance.defaultProject,
                date: date
            )
            switch indexPath.section {
            case 1:
                guard indexPath.row < inboxTasks.count else {
                    tableView.deselectRow(at: indexPath, animated: true)
                    return
                }
                nTask = inboxTasks[indexPath.row]
            case 2:
                guard indexPath.row < customProjectTasks.count else {
                    tableView.deselectRow(at: indexPath, animated: true)
                    return
                }
                nTask = customProjectTasks[indexPath.row]
            default:
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }

        case .projectView:
            let projTasks = TaskManager.sharedInstance.getTasksForProjectByNameForDate_Open(
                projectName: projectForTheView,
                date: date
            )
            guard indexPath.row < projTasks.count else {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
            nTask = projTasks[indexPath.row]

        case .upcomingView:
            let allUpcoming = TaskManager.sharedInstance.getUpcomingTasks
            let upcoming = allUpcoming.filter { ($0.dueDate as! Date) == date }
            guard indexPath.row < upcoming.count else {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
            nTask = upcoming[indexPath.row]

        case .historyView:
            let allTasks = TaskManager.sharedInstance.getAllTasks
            let history = allTasks.filter { $0.isComplete && ($0.dateCompleted as! Date) == date }
            guard indexPath.row < history.count else {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
            nTask = history[indexPath.row]

        case .allProjectsGrouped, .selectedProjectsGrouped:
            guard indexPath.section > 0 else {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
            let projectIndex = indexPath.section - 1
            guard projectsToDisplayAsSections.indices.contains(projectIndex) else {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
            let project = projectsToDisplayAsSections[projectIndex]
            guard let projectName = project.projectName,
                  let tasksForProject = tasksGroupedByProject[projectName],
                  tasksForProject.indices.contains(indexPath.row) else {
                tableView.deselectRow(at: indexPath, animated: true)
                return
            }
            nTask = tasksForProject[indexPath.row]

        default:
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }

        // Show details
        // --- Start of new TaskDetailViewFluent presentation logic ---
        // Dismiss any existing fluent detail view first
        if let existingView = self.presentedFluentDetailView {
            existingView.removeFromSuperview()
            self.presentedFluentDetailView = nil
        }
        if let existingOverlay = self.overlayView {
            existingOverlay.removeFromSuperview()
            self.overlayView = nil
        }

        let fluentDetailView = TaskDetailViewFluent() // Frame will be set by AutoLayout
        let allProjects = ProjectManager.sharedInstance.displayedProjects
        fluentDetailView.configure(task: nTask, availableProjects: allProjects, delegate: self)

        // Add an overlay view to dim the background
        let newOverlayView = UIView(frame: self.view.bounds)
        newOverlayView.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        newOverlayView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.view.addSubview(newOverlayView)
        self.overlayView = newOverlayView // Store overlay

        // Position fluentDetailView using AutoLayout
        fluentDetailView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(fluentDetailView)
        
        // Initial alpha for animation
        fluentDetailView.alpha = 0
        newOverlayView.alpha = 0
        
        NSLayoutConstraint.activate([
            fluentDetailView.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
            fluentDetailView.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
            fluentDetailView.widthAnchor.constraint(equalTo: self.view.widthAnchor, multiplier: 0.9),
            fluentDetailView.heightAnchor.constraint(equalTo: self.view.heightAnchor, multiplier: 0.7)
        ])
        
        // Ensure the view has an initial size before animation
        self.view.layoutIfNeeded()
        self.presentedFluentDetailView = fluentDetailView // Store presented view
        
        // Add a tap gesture to the overlay to dismiss the detail view
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissFluentDetailView))
        newOverlayView.addGestureRecognizer(tapGesture)
        
        // Animate the appearance of the detail view and overlay
        UIView.animate(withDuration: 0.3) {
            fluentDetailView.alpha = 1.0
            newOverlayView.alpha = 1.0
        }
        // --- End of new TaskDetailViewFluent presentation logic ---
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

// MARK: - Home view update and reload helpers
extension HomeViewController {
    func updateViewForHome(viewType: ToDoListViewType, dateForView: Date? = nil) {
        // Update view type and optionally the date
        self.currentViewType = viewType
        if let date = dateForView { self.dateForTheView = date }
        if viewType == .allProjectsGrouped || viewType == .selectedProjectsGrouped {
            prepareAndFetchTasksForProjectGroupedView()
        }
        tableView.reloadData()
    }

    func reloadTinyPicChartWithAnimation() {
        // Animate or reload tiny pie chart view
        toDoAnimations.animateTinyPieChartAtHome(pieChartView: tinyPieChartView)
    }

    func reloadToDoListWithAnimation() {
        // Reload task list with animation
        self.tableView.reloadData()
        animateTableViewReload()
    }
    
    @objc func clearProjectFilterAndResetView() {
        selectedProjectNamesForFilter.removeAll()
        projectForTheView = ProjectManager.sharedInstance.defaultProject
        updateViewForHome(viewType: .todayHomeView, dateForView: Date.today())
    }
}

extension HomeViewController: TaskDetailViewFluentDelegate {
    func taskDetailViewFluentDidUpdateRequest(_ view: TaskDetailViewFluent, updatedTask: NTask) {
        TaskManager.sharedInstance.saveContext()
        self.tableView.reloadData()
        // self.updateLineChartData() // This method is not confirmed to exist in HomeViewController.swift
    }
    
    @objc func dismissFluentDetailView() {
        if let overlayView = self.overlayView {
            UIView.animate(withDuration: 0.3, animations: {
                self.presentedFluentDetailView?.alpha = 0
                overlayView.alpha = 0
            }, completion: { _ in
                self.presentedFluentDetailView?.removeFromSuperview()
                overlayView.removeFromSuperview()
                self.presentedFluentDetailView = nil
                self.overlayView = nil
            })
        }
    }

    func taskDetailViewFluentDidRequestDatePicker(_ view: TaskDetailViewFluent, for task: NTask, currentValue: Date?) {
        let dateTimePicker = FluentUI.DateTimePicker()
        dateTimePicker.delegate = self
        
        self.editingTaskForDatePicker = task
        self.activeTaskDetailViewFluent = view

        if let presentedVC = self.presentedViewController {
            if presentedVC is DateTimePicker || presentedVC is BottomSheetController {
                presentedVC.dismiss(animated: false, completion: nil)
            }
        }

        dateTimePicker.present(
            from: self,
            with: .dateTime,
            startDate: currentValue ?? Date()
        )
    }

    func taskDetailViewFluentDidRequestProjectPicker(_ view: TaskDetailViewFluent, for task: NTask, currentProject: Projects?, availableProjects: [Projects]) {
        if let presentedVC = self.presentedViewController {
             if presentedVC is DateTimePicker || presentedVC is BottomSheetController {
                presentedVC.dismiss(animated: false, completion: nil)
             }
        }
        
        let projectListVC = ProjectPickerViewController(projects: availableProjects, selectedProject: currentProject)
        projectListVC.onProjectSelected = { [weak self, weak view] selectedProjectEntity in
            guard let self = self, let view = view, let taskToUpdate = self.editingTaskForProjectPicker else { return }
            
            taskToUpdate.project = selectedProjectEntity?.projectName
            view.updateProjectButtonTitle(project: selectedProjectEntity?.projectName)
            
            TaskManager.sharedInstance.saveContext()
            self.tableView.reloadData()
            // self.updateLineChartData() // This method is not confirmed to exist.
            
            self.editingTaskForProjectPicker = nil
            self.activeTaskDetailViewFluent = nil
            
            self.presentedViewController?.dismiss(animated: true, completion: nil)
        }
        
        self.editingTaskForProjectPicker = task
        self.activeTaskDetailViewFluent = view

        let bottomSheetController = BottomSheetController(expandedContentView: projectListVC.view)
        bottomSheetController.preferredExpandedContentHeight = CGFloat(min(availableProjects.count, 5) * 50 + 20)
        // Don't directly assign to headerContentView as it's a let constant
        // Instead configure the controller before presenting it
        bottomSheetController.isHidden = false // Ensure it's not hidden by default
        
        self.present(bottomSheetController, animated: true)
    }
}

extension HomeViewController: DateTimePickerDelegate {
    func dateTimePicker(_ dateTimePicker: FluentUI.DateTimePicker, didPickStartDate startDate: Date, endDate: Date) {
        guard let task = self.editingTaskForDatePicker, let detailView = self.activeTaskDetailViewFluent else { return }
        
        let mode = dateTimePicker.mode ?? .date
        if mode.singleSelection {
            task.dueDate = startDate as NSDate
            detailView.updateDueDateButtonTitle(date: startDate)
            
            TaskManager.sharedInstance.saveContext()
            self.tableView.reloadData()
            // self.updateLineChartData() // This method is not confirmed to exist.
        }
        
        self.editingTaskForDatePicker = nil
        self.activeTaskDetailViewFluent = nil
        dateTimePicker.dismiss()
    }
    
    func dateTimePicker(_ dateTimePicker: DateTimePicker, didTapSelectedDate date: Date) {
        dateTimePicker.dismiss()
        self.editingTaskForDatePicker = nil
        self.activeTaskDetailViewFluent = nil
    }
}
