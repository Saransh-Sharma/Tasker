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
import EasyPeasy
import MaterialComponents.MaterialButtons
import MaterialComponents.MaterialBottomAppBar
import MaterialComponents.MaterialButtons_Theming




class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CircleMenuDelegate {
    
    
    //MARK:- Tablevieew animation style
    private let animations = [AnimationType.from(direction:.right , offset: 400.0)]
    
    //MARK:- Positioning
    var headerEndY: CGFloat = 128
    
    //MARK:- cuurentt task list date
    var dateForTheView = Date.today()
    
    //MARK:- score for day label
    var scoreForTheDay: UILabel! = nil
    
    //MARK:- Buttons + Views + Bottom bar
    fileprivate weak var calendar: FSCalendar!
    let fab_revealCalAtHome = MDCFloatingButton(shape: .mini)
    //    let dateButton = MDCButton()
    var backdropNochImageView = UIImageView()
    var backdropBackgroundImageView = UIImageView()
    var backdropForeImageView = UIImageView()
    let backdropForeImage = UIImage(named: "backdropFrontImage")
    var homeTopBar = UIView()
    let dateAtHomeLabel = UILabel()
    var bottomAppBar = MDCBottomAppBarView()
    
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
    
    
    
    
    //MARK: Theming: COLOURS
    
    var backgroundColor = UIColor.systemGray5
    var primaryColor =  #colorLiteral(red: 0.3843137255, green: 0, blue: 0.9333333333, alpha: 1) //UIColor(red: 98.0/255.0, green: 0.0/255.0, blue: 238.0/255.0, alpha: 1.0)
    var primaryColorDarker = #colorLiteral(red: 0.2784313725, green: 0.007843137255, blue: 0.7568627451, alpha: 1) //UIColor(red: 71.0/255.0, green: 2.0/255.0, blue: 193.0/255.0, alpha: 1.0)
    
    var secondaryAccentColor = #colorLiteral(red: 0.007843137255, green: 0.6352941176, blue: 0.6156862745, alpha: 1) //02A29D
    
    //          var primaryColor =  #colorLiteral(red: 0.6941176471, green: 0.9294117647, blue: 0.9098039216, alpha: 1)
    //          var secondryColor =  #colorLiteral(red: 0.2039215686, green: 0, blue: 0.4078431373, alpha: 1)
    
    
    
    
    //MARK:- setup bottom bar
    func setupBottomAppBar() {
        
        bottomAppBar.floatingButton.setImage(UIImage(named: "material_add_White"), for: .normal)
        bottomAppBar.floatingButton.backgroundColor = secondaryAccentColor //.systemIndigo
        bottomAppBar.frame = CGRect(x: 0, y: UIScreen.main.bounds.maxY-100, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.maxY-100)
        bottomAppBar.barTintColor = primaryColor//primaryColor
        bottomAppBar.easy.layout(Edges())
        

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
        bottomAppBar.elevation = ShadowElevation(rawValue: 5)
        bottomAppBar.floatingButtonPosition = .trailing
        
        
        bottomAppBar.floatingButton.addTarget(self, action: #selector(AddTaskAction), for: .touchUpInside)
        
        
        //        return bottomAppBar
    }
    
    
    func setupBackdropNotch() {
        backdropNochImageView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 40)
        backdropNochImageView.backgroundColor = primaryColorDarker
        
        view.addSubview(backdropNochImageView)
    }
    
    func setupBackdropBackground() {
        //        view.backgroundColor = secondryColor
        backdropBackgroundImageView.frame =  CGRect(x: 0, y: backdropNochImageView.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        backdropBackgroundImageView.backgroundColor = primaryColor
        
        homeTopBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
        //        homeTopBar.backgroundColor = .green
        backdropBackgroundImageView.addSubview(homeTopBar)
        //        homeTopBar.
        
        
        
        
        
        // Monday, 5th May
        
        
        
        
        
        dateAtHomeLabel.text = "Monday, \n5th May"
        
        print("Date: \(Date.today().day)")
        print("Date: \(Date.today().month)")
        print("Date: \(Date.today().year)")
        
        print("Date: \(Date.today().dateString(in: .short))")
        print("Date: \(Date.today().dateString(in: .medium))")
        print("Date: \(Date.today().dateString(in: .long))")
        print("Date: \(Date.today().dateString(in: .full))")
        print("Date: \(Date(year: Date.today().year, month: Date.today().month, day: Date.today().day))")
        print("Date: \(Date.today().stringIn(dateStyle: .full, timeStyle: .full))")
        
        let date: String = "\(Date(year: Date.today().year, month: Date.today().month, day: Date.today().day))"
        
        let dateArray = date.components(separatedBy: ",")
        print("count \(dateArray.count)")
        //        print("FINAL  Date: \(dateArray[0]), \(dateArray[1])")
        
        dateAtHomeLabel.numberOfLines = 2
        dateAtHomeLabel.textColor = .systemGray6
        //        dateAtHomeLabel.font = UIFont(name: "Futura Medium", size: 30)
        dateAtHomeLabel.font =  UIFont(name: "HelveticaNeue-Medium", size: 20)
        //NewYorkMedium-Regular
        
        //        dateAtHomeLabel.adjustsFontSizeToFitWidth = true
        dateAtHomeLabel.frame = CGRect(x: 5, y: 20, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
        
        //----------
        
        homeTopBar.addSubview(dateAtHomeLabel)
        
        view.addSubview(backdropBackgroundImageView)
        
        
    }
    
    func setupBackdropForeground() {
        //    func setupBackdropForeground() {
        
        
        
        print("Backdrop starts from: \(headerEndY)")
        backdropForeImageView.frame = CGRect(x: 0, y: headerEndY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        backdropForeImageView.image = backdropForeImage //set foredrop image
        backdropForeImageView.image?.withTintColor(.systemGray6, renderingMode: .alwaysTemplate)
        
        //        //CGRect(x: 0, y: headerEndY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        //         tableView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        //        backdropForeImageView.addSubview(tableView)
        
        //        backdropForeImageView.layer.shadowColor = UIColor.black.cgColor
        backdropForeImageView.layer.shadowColor = UIColor.black.cgColor
        backdropForeImageView.layer.shadowOpacity = 1
        backdropForeImageView.layer.shadowOffset = .zero
        backdropForeImageView.layer.shadowRadius = 20
        
        view.addSubview(backdropForeImageView)
        
    }
    
    @objc
    func onMenuButtonTapped() {
        print("menu buttoon tapped")
    }
    
    @objc
    func onNavigationButtonTapped() {
        print("nav buttoon tapped")
    }
    
    
    
    //MARK:- View did load
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //        view.addSubview(servePageHeader())
        view.addSubview(serveNewPageHeader())
        //        tableView.frame = CGRect(x: 0, y: headerEndY+10, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        
        
        //MARK: serve material backdrop
        
        setupBackdropBackground()
        setupBackdropForeground()
        
        
        //CGRect(x: 0, y: headerEndY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        //CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        //               backdropForeImageView.addSubview(tableView)
        
        
        tableView.frame = CGRect(x: 0, y: headerEndY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        view.addSubview(tableView)
        
        
        
        setupBackdropNotch()
        
        //MARK:--top cal
        
        let calendar = FSCalendar(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 400))
        calendar.dataSource = self
        calendar.delegate = self
        
        self.calendar = calendar
        self.calendar.scope = FSCalendarScope.week
        
        //        view.addSubview(calendar)
        
        //--- done top cal
        
        setupBottomAppBar()
        view.addSubview(bottomAppBar)
        view.bringSubviewToFront(bottomAppBar)
        
        
        //---Floating Action Button - Material - DONE
        
        
        //---Floating Action Button - Material - MORE CAL
        
        
        fab_revealCalAtHome.minimumSize = CGSize(width: 32, height: 24)
        let kMinimumAccessibleButtonSizeHeeight: CGFloat = 24
        let kMinimumAccessibleButtonSizeWidth:CGFloat = 32
        let buttonVerticalInset =
            min(0, -(kMinimumAccessibleButtonSizeHeeight - fab_revealCalAtHome.bounds.height) / 2);
        let buttonHorizontalInset =
            min(0, -(kMinimumAccessibleButtonSizeWidth - fab_revealCalAtHome.bounds.width) / 2);
        fab_revealCalAtHome.hitAreaInsets =
            UIEdgeInsets(top: buttonVerticalInset, left: buttonHorizontalInset,
                         bottom: buttonVerticalInset, right: buttonHorizontalInset);
        
        
        // fab_revealCalAtHome button position
        //        fab_revealCalAtHome.frame = CGRect(x: UIScreen.main.bounds.width - UIScreen.main.bounds.width/8 , y: UIScreen.main.bounds.minY+60, width: 25, height: 25)
        
        fab_revealCalAtHome.frame = CGRect(x: (UIScreen.main.bounds.minX+UIScreen.main.bounds.width/4)+10 , y: UIScreen.main.bounds.minY+60, width: 25, height: 25)
        
        let addTaskIcon = UIImage(named: "fab_revealCalAtHome")
        
        fab_revealCalAtHome.setImage(addTaskIcon, for: .normal)
        //        fab_revealCalAtHome.backgroundColor = primaryColor //this keeps style consistent between screens
        fab_revealCalAtHome.backgroundColor = primaryColor
        fab_revealCalAtHome.sizeToFit()
        view.addSubview(fab_revealCalAtHome)
        fab_revealCalAtHome.addTarget(self, action: #selector(showCalMoreButtonnAction), for: .touchUpInside)
        
        let showCalNormalImage = UIImage(named: "cal_Icon")
               fab_revealCalAtHome.setImage(showCalNormalImage, for: .normal)
        
//
        
        //        showCalMoreButtonnAction
        
        //MARK: circle menu frame
        let circleMenuButton = CircleMenu(
            frame: CGRect(x: 32, y: 64, width: 30, height: 30),
            normalIcon:"icon_menu",
            //            selectedIcon:"icon_close",
            selectedIcon:"material_close",
            buttonsCount: 5,
            duration: 1,
            distance: 50)
        circleMenuButton.backgroundColor = backgroundColor
        
        circleMenuButton.delegate = self
        circleMenuButton.layer.cornerRadius = circleMenuButton.frame.size.width / 2.0
        //        view.addSubview(circleMenuButton) TODO: reconsider the top circle menu
        
        
        enableDarkModeIfPreset()
    }
    
    //    showCalMoreButtonnAction
    
    @objc func showCalMoreButtonnAction() {
        
        print("Show cal !!")
        //        dateForTheView = Date.tomorrow() //todo remove this
        
        
        
        
        let delay: Double = 1.0
        let duration: Double = 2.0

                UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                    self.moveUp_onCalHide(view: self.tableView)
                }) { (_) in
        //            self.moveLeft(view: self.black4)
                }
        
        view.addSubview(calendar)
        
        tableView.reloadData()
        animateTableViewReload()
        
    }
    
    @objc func AddTaskAction() {
        
        //       tap add fab --> addTask
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let newViewController = storyBoard.instantiateViewController(withIdentifier: "addTask") as! NAddTaskScreen
        newViewController.modalPresentationStyle = .fullScreen
        self.present(newViewController, animated: true, completion: nil)
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
    
    // MARK:- Build Page Header
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func serveNewPageHeader() -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 128)
        view.backgroundColor = .clear
        headerEndY = view.frame.maxY
        
        
        print("Header end point is: \(headerEndY)")
        
        
        let homeTitle = UILabel()
        
        //        homeTitle.frame = CGRect(x: 5, y: 30, width: view.frame.width/2+view.frame.width/8, height: 64)
        homeTitle.frame = CGRect(x: 5, y: 30, width: view.frame.width/2, height: 40)
        homeTitle.text = "Today's score"
        homeTitle.textColor = .label
        homeTitle.textAlignment = .left
        
        homeTitle.font = UIFont(name: "HelveticaNeue-Medium", size: 30)
        //        homeTitle.font = UIFont.preferredFont(forTextStyle: .largeTitle)
        homeTitle.adjustsFontSizeToFitWidth = true
        //        view.addSubview(homeTitle)
        
        
        //MARK:-- date button
        //        dateButton
        
        //        let buttonVerticalInset =
        //        min(0, -(kMinimumAccessibleButtonSize.height - button.bounds.height) / 2);
        //        let buttonHorizontalInset =
        //        min(0, -(kMinimumAccessibleButtonSize.width - button.bounds.width) / 2);
        //        button.hitAreaInsets =
        //        UIEdgeInsetsMake(buttonVerticalInset, buttonHorizontalInset,
        //        buttonVerticalInset, buttonHorizontalInset);
        
        
        //----date button done
        
        
        
        let todaysDateLabel = UILabel()
        todaysDateLabel.frame = CGRect(x: 5, y: 70, width: view.frame.width/2, height: 40)
        todaysDateLabel.text = dateForTheView.dateString(in: .medium)
        todaysDateLabel.textColor = .secondaryLabel
        todaysDateLabel.textAlignment = .left
        todaysDateLabel.adjustsFontSizeToFitWidth = true
        view.addSubview(todaysDateLabel)
        
        
        
        scoreForTheDay = UILabel()
        scoreForTheDay.frame = CGRect(x: homeTitle.bounds.maxX, y: homeTitle.bounds.midY, width: 80, height: 64)
        scoreForTheDay.text = "13"
        //        scoreForTheDay.textColor = primaryColor
        scoreForTheDay.textColor = .secondaryLabel
        scoreForTheDay.textAlignment = .center
        scoreForTheDay.font = UIFont(name: "HelveticaNeue-Medium", size: 50)
        //        scoreForTheDay.font = UIFont.preferredFont(forTextStyle: .headline)
        scoreForTheDay.adjustsFontSizeToFitWidth = true
        view.addSubview(scoreForTheDay)
        
        return view
    }
    
    //MARK:- Serve Page Header
    func servePageHeader() -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 128)
        view.backgroundColor = primaryColor
        headerEndY = view.frame.maxY
        
        print("Header end point is: \(headerEndY)")
        
        let homeTitle = UILabel()
        //        homeTitle.frame = CGRect(x: view.frame.minX+84, y: view.frame.maxY-60, width: view.frame.width/2+20, height: 64)
        homeTitle.frame = CGRect(x: (view.frame.minX+view.frame.maxX/5)+3, y: view.frame.maxY-60, width: view.frame.width/2+view.frame.width/8, height: 64)
        homeTitle.text = "Today's score is "
        homeTitle.textColor = backgroundColor
        homeTitle.textAlignment = .left
        homeTitle.font = UIFont(name: "HelveticaNeue-Medium", size: 30)
        view.addSubview(homeTitle)
        
        scoreForTheDay = UILabel()
        //        scoreForTheDay.frame = CGRect(x: view.frame.maxX-90, y: view.frame.maxY-60, width: 80, height: 64)
        scoreForTheDay.frame = CGRect(x: (view.frame.maxX-view.frame.maxX/6)-10, y: view.frame.maxY-60, width: 80, height: 64)
        scoreForTheDay.text = "13"
        scoreForTheDay.textColor = backgroundColor
        scoreForTheDay.textAlignment = .center
        scoreForTheDay.font = UIFont(name: "HelveticaNeue-Medium", size: 40)
        view.addSubview(scoreForTheDay)
        
        return view
    }
    
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
    
    func serveSemiViewBlue(task: NTask) -> UIView { //TODO: put each of this in a tableview
        
        let view = UIView(frame: UIScreen.main.bounds)
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 300)
        //        view.backgroundColor =  #colorLiteral(red: 0.2039215686, green: 0, blue: 0.4078431373, alpha: 1)
        view.backgroundColor = backgroundColor
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
        eveningLabel.textColor =  primaryColor
        eveningLabel.frame = CGRect(x: frameForView.minX+40, y: frameForView.minY+85, width: frameForView.width-100, height: frameForView.height/8)
        
        let eveningSwitch = UISwitch() //Evening Switch
        view.addSubview(eveningSwitch)
        eveningSwitch.onTintColor = primaryColor
        
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
        prioritySegmentedControl.selectedSegmentTintColor =  primaryColor
        
        
        
        prioritySegmentedControl.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.white], for: UIControl.State.selected)
        
        prioritySegmentedControl.frame = CGRect(x: frameForView.minX+20, y: frameForView.minY+150, width: frameForView.width-40, height: frameForView.height/7)
        
        
        let datePicker = UIDatePicker() //DATE PICKER //there should not be a date picker here //there can be calender icon instead
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
    
    // MARK:- DID SELECT ROW AT
    /*
     Prints logs on selecting a row
     */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("You selected row \(indexPath.row) from section \(indexPath.section)")
        
        var currentTask: NTask!
        //        semiViewDefaultOptions(viewToBePrsented: serveViewBlue())
        switch indexPath.section {
        case 0:
            //            currentTask = TaskManager.sharedInstance.getMorningTasks[indexPath.row]
            let Tasks = TaskManager.sharedInstance.getMorningTaskByDate(date: dateForTheView)
            currentTask = Tasks[indexPath.row]
        case 1:
            //            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
            let Tasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
            currentTask = Tasks[indexPath.row]
        default:
            break
        }
        
        //        semiViewDefaultOptions(viewToBePrsented: serveSemiViewRed())
        
        semiViewDefaultOptions(viewToBePrsented: serveSemiViewBlue(task: currentTask))
        
        //        semiViewDefaultOptions(viewToBePrsented: serveSemiViewGreen(task: currentTask))
        
        
        
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
    
    // MARK:- View Lifecycle methods
    
    override func viewWillAppear(_ animated: Bool) {
        // right spring animation
        //        tableView.reloadData(
        //            with: .spring(duration: 0.45, damping: 0.65, velocity: 1, direction: .right(useCellsFrame: false),
        //                          constantDelay: 0))
        tableView.reloadData()
        
        animateTableViewReload()
        //        UIView.animate(views: tableView.visibleCells, animations: animations, completion: {
        
        //        })
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
            view.backgroundColor =  backgroundColor
        }
    }
    
    // MARK: calculate today's score
    /*
     Calculates daily productivity score
     */
    func calculateTodaysScore() -> Int { //TODO change this to handle NTASKs
        var score = 0
        
        let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: dateForTheView)
        let eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
        
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
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let myLabel = UILabel()
        myLabel.frame = CGRect(x:5, y: 0, width: UIScreen.main.bounds.width/2, height: 30)
        //myLabel.font = UIFont.boldSystemFont(ofSize: 18)
        myLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 20)
        myLabel.textColor = .secondaryLabel
        myLabel.text = self.tableView(tableView, titleForHeaderInSection: section)
        
        let headerView = UIView()
        headerView.addSubview(myLabel)
        
        return headerView
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Today's Tasks"
        case 1:
            return "Evening"
        default:
            return nil
        }
    }
    
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        
        switch section {
        case 0:
            //            print("Items in morning: \(TaskManager.sharedInstance.getMorningTasks.count)")
            //            return TaskManager.sharedInstance.getMorningTasks.count
            let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: dateForTheView)
            return morningTasks.count
        case 1:
            //            print("Items in evening: \(TaskManager.sharedInstance.getEveningTasks.count)")
            //            return TaskManager.sharedInstance.getEveningTasks.count
            let eveTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
            return eveTasks.count
        default:
            return 0;
        }
    }
    
    // MARK:- CELL AT ROW
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        
        var currentTask: NTask!
        let completedTaskCell = tableView.dequeueReusableCell(withIdentifier: "completedTaskCell", for: indexPath)
        let openTaskCell = tableView.dequeueReusableCell(withIdentifier: "openTaskCell", for: indexPath)
        
        //        print("NTASK count is: \(TaskManager.sharedInstance.count)")
        //        print("morning section index is: \(indexPath.row)")
        
        switch indexPath.section {
        case 0:
            print("morning section index is: \(indexPath.row)")
            
            //            let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: Date.today())
            //            currentTask = TaskManager.sharedInstance.getMorningTasks[indexPath.row]
            
            
            let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: dateForTheView)
            currentTask = morningTasks[indexPath.row]
            
        case 1:
            print("evening section index is: \(indexPath.row)")
            
            //            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
            
            //            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
            
            let evenningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: dateForTheView)
            currentTask = evenningTasks[indexPath.row]
            
        default:
            break
        }
        
        
        completedTaskCell.textLabel!.text = currentTask.name
        completedTaskCell.backgroundColor = UIColor.clear
        
        openTaskCell.textLabel!.text = currentTask.name
        openTaskCell.backgroundColor = UIColor.clear
        
        if currentTask.isComplete {
            completedTaskCell.textLabel?.textColor = .tertiaryLabel
            completedTaskCell.accessoryType = .checkmark
            return completedTaskCell
        } else {
            openTaskCell.textLabel?.textColor = .label
            openTaskCell.accessoryType = .disclosureIndicator
            return openTaskCell
        }
    }
    
    // MARK:- SWIPE ACTIONS
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let completeTaskAction = UIContextualAction(style: .normal, title: "Complete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
            let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: self.dateForTheView)
            let eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: self.dateForTheView)
            
            switch indexPath.section {
            case 0:
                
                //                TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: TaskManager.sharedInstance.getMorningTasks[indexPath.row])].isComplete = true
                
                TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: morningTasks[indexPath.row])].isComplete = true
                
                TaskManager.sharedInstance.saveContext()
                
            case 1:
                
                //                TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: TaskManager.sharedInstance.getEveningTasks[indexPath.row])].isComplete = true
                TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: eveningTasks[indexPath.row])].isComplete = true
                TaskManager.sharedInstance.saveContext()
                
            default:
                break
            }
            
            self.scoreForTheDay.text = "\(self.calculateTodaysScore())"
            
            tableView.reloadData()
            self.animateTableViewReload()
            //            UIView.animate(views: tableView.visibleCells, animations: self.animations, completion: {
            //
            //                   })
            
            // right spring animation
            //            tableView.reloadData(
            //                with: .spring(duration: 0.45, damping: 0.65, velocity: 1, direction: .right(useCellsFrame: false),
            //                              constantDelay: 0))
            
            self.title = "\(self.calculateTodaysScore())"
            actionPerformed(true)
        }
        
        return UISwipeActionsConfiguration(actions: [completeTaskAction])
    }
    
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
            
            print("Marking task as complete: \(TaskManager.sharedInstance.getAllTasks[idx].name)")
            print("func IDX is: \(idx)")
            idxHolder = idx
            
        }
        return idxHolder
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let deleteTaskAction = UIContextualAction(style: .destructive, title: "Delete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
            let confirmDelete = UIAlertController(title: "Are you sure?", message: "This will delete this task", preferredStyle: .alert)
            
            let yesDeleteAction = UIAlertAction(title: "Yes", style: .destructive)
            {
                (UIAlertAction) in
                
                let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: self.dateForTheView)
                let eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: self.dateForTheView)
                
                switch indexPath.section {
                case 0:
                    
                    //                    TaskManager.sharedInstance.removeTaskAtIndex(index: self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: TaskManager.sharedInstance.getMorningTasks[indexPath.row]))
                    TaskManager.sharedInstance.removeTaskAtIndex(index: self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: morningTasks[indexPath.row]))
                case 1:
                    //                    TaskManager.sharedInstance.removeTaskAtIndex(index: self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: TaskManager.sharedInstance.getEveningTasks[indexPath.row]))
                    
                    TaskManager.sharedInstance.removeTaskAtIndex(index: self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: eveningTasks[indexPath.row]))
                default:
                    break
                }
                
                //                tableView.reloadData()
                //                tableView.reloadData(
                //                    with: .simple(duration: 0.45, direction: .rotation3D(type: .captainMarvel),
                //                                  constantDelay: 0))
                
                tableView.reloadData()
                self.animateTableViewReload()
                //                UIView.animate(views: tableView.visibleCells, animations: self.animations, completion: {
                //
                //                       })
                
                
            }
            let noDeleteAction = UIAlertAction(title: "No", style: .cancel)
            { (UIAlertAction) in
                
                print("That was a close one. No deletion.")
            }
            
            //add actions to alert controller
            confirmDelete.addAction(yesDeleteAction)
            confirmDelete.addAction(noDeleteAction)
            
            //show it
            self.present(confirmDelete ,animated: true, completion: nil)
            
            self.title = "\(self.calculateTodaysScore())"
            actionPerformed(true)
        }
        
        
        return UISwipeActionsConfiguration(actions: [deleteTaskAction])
    }
    
    
    //    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
    //        // We'll assume that there is only one section for now.
    //
    //          if section == 0 {
    //
    //              let imageView: UIImageView = UIImageView()
    //              //imageView.clipsToBounds = true
    //              //imageView.contentMode = .scaleAspectFill
    //            imageView.heightAnchor.constraint(lessThanOrEqualToConstant: 50)
    //              imageView.image =  UIImage(named: "Star")!
    //              return imageView
    //          }
    //
    //          return nil
    //    }
    //
    
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
    
    //MARK: animations
    func animateTableViewReload() {
        let zoomAnimation = AnimationType.zoom(scale: 0.5)
        let rotateAnimation = AnimationType.rotate(angle: CGFloat.pi/6)
        
        UIView.animate(views: tableView.visibleCells,
                       animations: [zoomAnimation, rotateAnimation],
                       duration: 0.3)
    }
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
    
      
    func moveRight(view: UIView) {
         view.center.x += 300
     }
     
     func moveLeft(view: UIView) {
         view.center.x -= 300
     }
    func moveUp_onCalHide(view: UIView) {
        view.center.y += 300
    }
    
    func moveDown_onCalReveal(view: UIView) {
        view.center.y -= 300
    }
    
}

extension ViewController: FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance {
    
    func calendar(_ calendar: FSCalendar, subtitleFor date: Date) -> String? {
        
        let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: date)
        let eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: date)
        let allTasks = morningTasks+eveningTasks
        
        if(allTasks.count == 0) {
            return "-"
        } else {
            return "\(allTasks.count)"
        }
    }
    
    
    
}

