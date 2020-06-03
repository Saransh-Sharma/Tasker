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
import CircleMenu
import ViewAnimator
import FSCalendar
import Charts
import UserNotifications
import TinyConstraints
import MaterialComponents.MaterialButtons
import MaterialComponents.MaterialBottomAppBar
import MaterialComponents.MaterialButtons_Theming
import MaterialComponents.MaterialRipple


class HomeViewController: UIViewController, ChartViewDelegate, MDCRippleTouchControllerDelegate {
    
    //MARK:- Backdrop & Fordrop parent containers
    var backdropContainer = UIView()
    var foredropContainer = UIView()
    var bottomBarContainer = UIView()
    
    //MARK:- Positioning
    var headerEndY: CGFloat = 128
    var todoColors = ToDoColors()
    
    
    
    
    //init notification badge counter
    var notificationBadgeNumber:Int = 0
    
    
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
        chartView.xAxis.setLabelCount(10, force: true)
        chartView.xAxis.labelRotationAngle = 0
        //        chartView.xAxis.text
        chartView.xAxis.valueFormatter = DayAxisValueFormatter(chart: chartView) //replace date labels here
        
        return chartView
    }()
    
    //MARK: Pie Chart Data Sections
    let tinyPieChartSections = [""]
    
    //MARK:- cuurentt task list date
    var dateForTheView = Date.today()
    
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
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var switchState: UISwitch!
    
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
    
    
    func generateLineChartData() -> [ChartDataEntry] {
        
        var yValues: [ChartDataEntry] = []
        //        for day in daysOfWeek {
        //            let mEntry = ChartDataEntry(x: Double(Int.random(in: 0 ..< 10)), y: Double(Int.random(in: 0 ..< 10)))
        //            yValues.append(ChartDataEntry(x: Double(Int.random(in: 0 ..< 10)), y: Double(Int.random(in: 0 ..< 10))))
        //            print("Set data for day \(day): \(mEntry)")
        //            print("----------------")
        //        }
        
        //TODO: This cal should show this week + last week in default view
        // so if today is wednesday show: last 7 days from last week + this week up till today(mon, tue, wed)
        
        
        yValues.append(ChartDataEntry(x: Double(1.0), y: Double(3)))
        yValues.append(ChartDataEntry(x: Double(2.0), y: Double(3)))
        yValues.append(ChartDataEntry(x: Double(3.0), y: Double(7)))
        yValues.append(ChartDataEntry(x: Double(4.0), y: Double(3)))
        yValues.append(ChartDataEntry(x: Double(5.0), y: Double(7.5)))
        yValues.append(ChartDataEntry(x: Double(6.0), y: Double(8)))
        yValues.append(ChartDataEntry(x: Double(7.0), y: Double(9)))
        yValues.append(ChartDataEntry(x: Double(8.0), y: Double(4.0)))
        yValues.append(ChartDataEntry(x: Double(9.0), y: Double(6)))
        yValues.append(ChartDataEntry(x: Double(10.0), y: Double(7)))
        
        
        return yValues
    }
    
    func chartValueSelected(_ chartView: ChartViewBase, entry: ChartDataEntry, highlight: Highlight) {
        
        print("You selected data: \(entry)")
    }
    

    
    //MARK:- View did load
    override func viewDidLoad() {
        super.viewDidLoad()
        
      //--------
        view.addSubview(backdropContainer)
        setupBackdrop()
        
        
        view.addSubview(foredropContainer)
        setupFordrop()
        
        setupBottomAppBar()
        view.addSubview(bottomAppBar)
        view.bringSubviewToFront(bottomAppBar)

        setupBadgeCount()
        enableDarkModeIfPreset()
    }
    
    // MARK:- View Lifecycle methods
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(true)
        // right spring animation
        //        tableView.reloadData(
        //            with: .spring(duration: 0.45, damping: 0.65, velocity: 1, direction: .right(useCellsFrame: false),
        //                          constantDelay: 0))
        tableView.reloadData()
        
        animateTableViewReload()
        //        UIView.animate(views: tableView.visibleCells, animations: animations, completion: {
        
        //        })
    }
    
    // MARK:- Build Page Header
     override var preferredStatusBarStyle: UIStatusBarStyle {
         return .lightContent
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
    
 
    
    func serveNewPageHeader() -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 128)
        view.backgroundColor = .clear
        headerEndY = view.frame.maxY
        
        
        print("Header end point is: \(headerEndY)")
        
        
        let todaysDateLabel = UILabel()
        todaysDateLabel.frame = CGRect(x: 5, y: 70, width: view.frame.width/2, height: 40)
        todaysDateLabel.text = dateForTheView.dateString(in: .medium)
        todaysDateLabel.textColor = .secondaryLabel
        todaysDateLabel.textAlignment = .left
        todaysDateLabel.adjustsFontSizeToFitWidth = true
        view.addSubview(todaysDateLabel)
        
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
    
    // MARK: SECTIONS
    func numberOfSections(in tableView: UITableView) -> Int {
        
        tableView.backgroundColor = UIColor.clear
        return 2;
    }
    
    
    
    //----------------------- *************************** -----------------------
    //MARK:-                  TABLEVIEW: HEADER VIEW
    //TODO: build filter here
    // has today, yesterday, tomorrw, project A, Prject B
    //
    //----------------------- *************************** -----------------------
    
    //        func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    //            // We'll assume that there is only one section for now.
    //
    //              if section == 0 {
    //
    ////                  let imageView: UIImageView = UIImageView()
    //                  //imageView.clipsToBounds = true
    //                  //imageView.contentMode = .scaleAspectFill
    //                let filterHeaderView = UIView()
    //
    ////                imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 50)
    ////                  imageView.image =  UIImage(named: "Star")!
    ////                  return imageView
    //              }
    //
    //              return nil
    //        }
    
    
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
        bottomAppBar.barTintColor = todoColors.primaryColor//primaryColor
        
        // The following lines of code are to define the buttons on the right and left side
        let barButtonMenu = UIBarButtonItem(
            image: UIImage(named:"material_menu_White"), // Icon
            style: .plain,
            target: self,
            action: #selector(self.onMenuButtonTapped))
        
        let barButtonSearch = UIBarButtonItem(
            image: UIImage(named: "material_search_White"), // Icon
            style: .plain,
            target: self,
            action: #selector(self.onNavigationButtonTapped))
        let barButtonInbox = UIBarButtonItem(
            image: UIImage(named: "material_inbox_White"), // Icon
            style: .plain,
            target: self,
            action: #selector(self.onNavigationButtonTapped))
        bottomAppBar.leadingBarButtonItems = [barButtonMenu, barButtonSearch, barButtonInbox]
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
        print("menu buttoon tapped")
    }
    
    @objc
    func onNavigationButtonTapped() {
        print("nav buttoon tapped")
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                     IS BACKDROP DOWN
    //----------------------- *************************** -----------------------
    //TODO: Improve this; make more resilient; if this breaks, the view breaks
    //    func isBackdropDown() -> Bool{
    //        print("---------------------------------------------")
    //        print("backdrop midY:\(backdropForeImageView.bounds.midY)")
    //        print("backdrop minY:\(backdropForeImageView.bounds.minY)")
    //        print("backdrop maxY:\(backdropForeImageView.bounds.maxY)")
    //        print("backdrop screen height:\(UIScreen.main.bounds.height-headerEndY)")
    //        print("backdrop headerEndY:\(headerEndY)")
    //
    ////        if backdropForeImageView.bounds.maxY == UIScreen.main.bounds.height-headerEndY {
    ////
    ////            print("isBackdropDown: NOT DOWN - Header INIT positio exact match !")
    ////            return false
    ////
    ////        } else {
    ////            print("isBackdropDown: YES DOWN -  !")
    ////            return true
    ////        }
    //
    //
    //    }
    
    //----------------------- *************************** -----------------------
    //MARK:-                        ACTION: ADD TASK
    //----------------------- *************************** -----------------------
    
    @objc func AddTaskAction() {
        
        //       tap add fab --> addTask
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let newViewController = storyBoard.instantiateViewController(withIdentifier: "addTask") as! NAddTaskScreen
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
    func updateHomeDate(date: Date) {
        
        if("\(date.day)".count < 2) {
            self.homeDate_Day.text = "0\(date.day)"
        } else {
            self.homeDate_Day.text = "\(date.day)"
        }
        self.homeDate_WeekDay.text = getWeekday(date: date)
        self.homeDate_Month.text = getMonth(date: date)
        
    }
    

    
    //    //----------------------- *************************** -----------------------
    //    //MARK:-              BACKDROP PATTERN 1: SETUP BACKGROUND
    //    //----------------------- *************************** -----------------------
    //
    //    //MARK:- Setup Backdrop Background - Today label + Score
    //    func setupBackdropBackground() {
    //
    //        backdropBackgroundImageView.frame =  CGRect(x: 0, y: backdropNochImageView.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
    //        backdropBackgroundImageView.backgroundColor = todoColors.primaryColor
    //        homeTopBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
    //        backdropBackgroundImageView.addSubview(homeTopBar)
    //
    //
    //        //---------- score at home
    //
    //        scoreAtHomeLabel.text = "\n\nscore"
    //        scoreAtHomeLabel.numberOfLines = 3
    //        scoreAtHomeLabel.textColor = .label
    //        scoreAtHomeLabel.font = setFont(fontSize: 20, fontweight: .regular, fontDesign: .monospaced)
    //
    //
    //        scoreAtHomeLabel.textAlignment = .center
    //        scoreAtHomeLabel.frame = CGRect(x: UIScreen.main.bounds.width - 150, y: 20, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
    //
    //        //        homeTopBar.addSubview(scoreAtHomeLabel)
    //
    //        //---- score
    //
    //        scoreCounter.text = "\(self.calculateTodaysScore())"
    //        scoreCounter.numberOfLines = 1
    //        scoreCounter.textColor = .systemGray5
    //        scoreCounter.font = setFont(fontSize: 52, fontweight: .bold, fontDesign: .rounded)
    //
    //        scoreCounter.textAlignment = .center
    //        scoreCounter.frame = CGRect(x: UIScreen.main.bounds.width - 150, y: 15, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
    //
    //        //        homeTopBar.addSubview(scoreCounter)
    //
    //        view.addSubview(backdropBackgroundImageView)
    //
    //
    //    }
    
//    //----------------------- *************************** -----------------------
//    //MARK:-              BACKDROP PATTERN 2: SETUP FOREGROUND
//    //----------------------- *************************** -----------------------
//
//    //MARK: Setup forground
//    func setupBackdropForeground() {
//        //    func setupBackdropForeground() {
//
//        print("Backdrop starts from: \(headerEndY)") //this is key to the whole view; charts, cal, animations, all
//        backdropForeImageView.frame = CGRect(x: 0, y: headerEndY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
//
//
//
//        backdropForeImageView.image = backdropForeImage?.withRenderingMode(.alwaysTemplate)
//        backdropForeImageView.tintColor = .systemGray6
//
//
//        backdropForeImageView.layer.shadowColor = UIColor.black.cgColor
//        backdropForeImageView.layer.shadowOpacity = 0.8
//        backdropForeImageView.layer.shadowOffset = CGSize(width: -5.0, height: -5.0) //.zero
//        backdropForeImageView.layer.shadowRadius = 10
//
//        view.addSubview(backdropForeImageView)
//
//    }
    
   
    
    
    
    
    
    
    
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
        if let idx = tasks.firstIndex(where: { $0 === morningOrEveningTask }) {
            
            print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
            print("Marking task as complete: \(TaskManager.sharedInstance.getAllTasks[idx].name)")
            print("func IDX is: \(idx)")
            print("%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%")
            idxHolder = idx
            
        }
        return idxHolder
    }
    
    
    
}


//----------------------- *************************** -----------------------
//MARK:-                      CIRCLE MENU DELEGATE
//----------------------- *************************** -----------------------

extension HomeViewController: CircleMenuDelegate {
    // MARK:- CircleMenuDelegate
    
    func circleMenu(_: CircleMenu, willDisplay button: UIButton, atIndex: Int) {
        button.backgroundColor = circleMenuItems[atIndex].color
        
        button.setImage(UIImage(named: circleMenuItems[atIndex].icon), for: .normal)
        
        // set highlited image
        let highlightedImage = UIImage(named: circleMenuItems[atIndex].icon)?.withRenderingMode(.alwaysTemplate)
        button.setImage(highlightedImage, for: .highlighted)
        button.tintColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3)
    }
    
    func circleMenu(_: CircleMenu, buttonWillSelected _: UIButton, atIndex: Int) {
        print("button will selected: \(atIndex)")
        if (atIndex == 3) { //Opens settings menu
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { //adds delay
                // your code here
                let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                let newViewController = storyBoard.instantiateViewController(withIdentifier: "settingsPage")
                self.present(newViewController, animated: true, completion: nil)
            }
            
            
        }
    }
    
    func circleMenu(_: CircleMenu, buttonDidSelected _: UIButton, atIndex: Int) {
        print("button did selected: \(atIndex)")
    }
    
    
    
    
    
}

//----------------------- *************************** -----------------------
//MARK:-                        DETECT NOTCH
//----------------------- *************************** -----------------------

//extension UIDevice {
//    var hasNotch: Bool {
//        let bottom = UIApplication.shared.keyWindow?.safeAreaInsets.bottom ?? 0
//        return bottom > 0
//    }
//}

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

