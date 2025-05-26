//
//  ViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
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
import MaterialComponents.MaterialButtons_Theming
import MaterialComponents.MaterialRipple


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
    
    
    var filledBar: UIView?
    
    
    
    //init notification badge counter
    var notificationBadgeNumber:Int = 0
    
    let ultraLightConfiguration = UIImage.SymbolConfiguration(weight: .regular)
    var highestPrioritySymbol = UIImage()//UIImage(systemName: "circle.fill",withConfiguration: ultraLightConfiguration)?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal)
    var highPrioritySymbol = UIImage()//UIImage(systemName: "circle",withConfiguration: ultraLightConfiguration)?.withTintColor(todoColors.secondaryAccentColor, renderingMode: .alwaysOriginal)
    
    
    func didSelectBadge(_ badge: BadgeView) {
    }
    
    var ToDoListSections: [ToDoListData.Section] = TableViewCellSampleData.DateForViewSections
    var listSection: ToDoListData.Section? = nil
    
    var openTaskCheckboxTag = 0
    var currentIndex:IndexPath = [0,0]
    
    let toDoListHeaderLabel = UILabel()
    
    public var isGrouped: Bool = false {
        didSet {
            updateTableView()
        }
    }
    
    func createProjectsBar(items: [PillButtonBarItem], style: PillButtonStyle = .outline, centerAligned: Bool = false) -> UIView {
        bar = PillButtonBar(pillButtonStyle: style)
        bar.items = items
        _ = bar.selectItem(atIndex: 1)
        bar.barDelegate = self
        bar.centerAligned = centerAligned
        
        let backgroundView = UIView()
        if style == .outline {
            backgroundView.backgroundColor = .clear
        }
        backgroundView.addSubview(bar)
        let margins = UIEdgeInsets(top: 16.0, left: 0, bottom: 16.0, right: 0.0)
        fitViewIntoSuperview(bar, margins: margins)
        return backgroundView
    }
    
    var filterProjectsPillBar: UIView?
    var bar = PillButtonBar(pillButtonStyle: .filled)
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
            let projectsList = ProjectManager.sharedInstance.getAllProjects
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
        
        
        
        ProjectManager.sharedInstance.fetchProjects()
        
        print("Project count is: \(ProjectManager.sharedInstance.count)")
        
        
        
        ProjectManager.sharedInstance.fetchProjects()
        
        
        let mProjects = ProjectManager.sharedInstance.getAllProjects
        
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
    
    func createButton(title: String, action: Selector) -> Button {
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
    
    func createBadge(text: String, style: BadgeView.Style, size: BadgeView.Size, isEnabled: Bool) -> BadgeView {
        let badge = BadgeView(dataSource: BadgeViewDataSource(text: text, style: style, size: size))
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
            action: #selector(self.onMenuButtonTapped))
        
        let barButtonSearch = UIBarButtonItem(
            image: UIImage(systemName: "waveform.path.ecg",withConfiguration: boldLargeConfig)?.withTintColor(.systemGray5, renderingMode: .alwaysOriginal), // Icon
            style: .plain,
            target: self,
            action: #selector(self.showChartsHHomeButton_Action))
        let barButtonInbox = UIBarButtonItem(
            image: UIImage(systemName: "calendar", withConfiguration: boldLargeConfig)?.withTintColor(.systemGray5, renderingMode: .alwaysOriginal), // Icon
            style: .plain,
            target: self,
            action: #selector(self.showCalMoreButtonnAction))
        
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
        print("menu button tapped")
        let settingsVC = SettingsPageViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        navController.modalPresentationStyle = .fullScreen
        self.present(navController, animated: true, completion: nil)
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
    
    
    
}



    
    
    


//----------------------- *************************** -----------------------
//MARK:-                        DETECT NOTCH
//----------------------- *************************** -----------------------



extension UIDevice {
    var hasNotch: Bool {
        if #available(iOS 11.0, *) {
            if UIApplication.shared.windows.count == 0 { return false }          // Should never occur, but…
            let top = UIApplication.shared.windows[0].safeAreaInsets.top
            return top > 20          // That seem to be the minimum top when no notch…
        } else {
            // Fallback on earlier versions
            return false
        }
    }
}

class openTask: UITableViewCell {
    
    var todoFont = ToDoFont()
    
    //    override init(frame: CGRect) {
    //        super.init(frame: frame)
    //        setup()
    //    }
    
    // MARK: - Initialization
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        setupUI()
    }
    
    // MARK: - Properties
    lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont(name: "HelveticaNeue", size: 20)
        label.textColor = .systemBlue
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    
    
    
    
    func setupUI() {
        self.backgroundColor = .blue
        
        self.addSubview(addProjectImageView)
        self.addSubview(addProjectLabel)
        
        addProjectImageView.anchor(top: topAnchor, left: leftAnchor, bottom: nil, right: rightAnchor, paddingTop: 0, paddingLeft: 5, paddingBottom: 5, paddingRight: 5, width: 0, height: 30)
        
        addProjectLabel.anchor(top: nil, left: leftAnchor, bottom: bottomAnchor, right: rightAnchor, paddingTop: 5, paddingLeft: 5, paddingBottom: 0, paddingRight: 5, width: 0, height: 20)
    }
    
    let addProjectImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .green
        iv.image = #imageLiteral(resourceName: "selection-on")
        return iv
    }()
    
    let addProjectLabel: UILabel = {
        let label = UILabel()
        label.text = "Add Project !!"
        label.textColor = .label
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        return label
    }()
    
    
}
