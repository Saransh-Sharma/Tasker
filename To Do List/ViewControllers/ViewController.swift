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
import BEMCheckBox
import MaterialComponents.MaterialButtons
import MaterialComponents.MaterialBottomAppBar
import MaterialComponents.MaterialButtons_Theming


class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    
    //MARK:- Tableview animation style
    private let animations = [AnimationType.from(direction:.right , offset: 400.0)]
    
    //MARK:- Positioning
    var headerEndY: CGFloat = 128
    
    //MARK:- cuurentt task list date
    var dateForTheView = Date.today()
    var dateToDisplay = Date.today()
    
    //MARK:- score for day label
    var scoreForTheDay: UILabel! = nil
    
    
    //MARK:- Buttons + Views + Bottom bar
    fileprivate weak var calendar: FSCalendar!
    let fab_revealCalAtHome = MDCFloatingButton(shape: .mini)
    let revealCalAtHomeButton = MDCButton()
    
    let homeDate_Day = UILabel()
         let homeDate_WeekDay = UILabel()
         let homeDate_Month = UILabel()
    
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
    var primaryColor = UIColor.systemIndigo // #colorLiteral(red: 0.3843137255, green: 0, blue: 0.9333333333, alpha: 1) //UIColor(red: 98.0/255.0, green: 0.0/255.0, blue: 238.0/255.0, alpha: 1.0)
    var primaryColorDarker = UIColor.black//#colorLiteral(red: 0.2784313725, green: 0.007843137255, blue: 0.7568627451, alpha: 1) //UIColor(red: 71.0/255.0, green: 2.0/255.0, blue: 193.0/255.0, alpha: 1.0)
    var secondaryAccentColor = UIColor.systemOrange// #colorLiteral(red: 0.007843137255, green: 0.6352941176, blue: 0.6156862745, alpha: 1) //02A29D
    //          var primaryColor =  #colorLiteral(red: 0.6941176471, green: 0.9294117647, blue: 0.9098039216, alpha: 1)
    //          var secondryColor =  #colorLiteral(red: 0.2039215686, green: 0, blue: 0.4078431373, alpha: 1)
    
    //MARK: Fonts:
    //    var titleFont_1:UIFont = setFont
    //    var scoreNumberFont:UIFont = setFont(fontSize: 40, fontweight: .bold, fontDesign: .rounded)
    
    //MARK:- Elevation + Shadows:
    let bottomBarShadowElevation: ShadowElevation = ShadowElevation(rawValue: 8)
    
    //MARK: get name of the month
    func getMonth(date: Date) -> String {
        
        let dateFormatter_Month = DateFormatter()
        dateFormatter_Month.dateFormat = "LLL" //try MMM
        let nameOfMonth = dateFormatter_Month.string(from: date)
        return nameOfMonth
    }
    
    //MARK: get name of the weekday
    func getWeekday(date: Date) -> String {
        
        let dateFormatter_Weekday = DateFormatter()
        dateFormatter_Weekday.dateFormat = "EEE"
        let nameOfWeekday = dateFormatter_Weekday.string(from: date)
        return nameOfWeekday
    }
    
    //MARK:- TUESDAY, 5th May
    func setHomeViewDate() {
        
     
        
        
        
        let today = dateToDisplay //Date() //TODO: change this with view date
        
        
        if("\(today.day)".count < 2) {
            homeDate_Day.text = "0\(today.day)"
        } else {
            homeDate_Day.text = "\(today.day)"
        }
        homeDate_WeekDay.text = getWeekday(date: today)
        homeDate_Month.text = getMonth(date: today)
        
        
        homeDate_Day.numberOfLines = 1
        homeDate_WeekDay.numberOfLines = 1
        homeDate_Month.numberOfLines = 1
        
        homeDate_Day.textColor = .systemGray6
        homeDate_WeekDay.textColor = .systemGray6
        homeDate_Month.textColor = .systemGray6
        
        homeDate_Day.font =  setFont(fontSize: 50, fontweight: .medium, fontDesign: .rounded)
        homeDate_WeekDay.font =  setFont(fontSize: 24, fontweight: .thin, fontDesign: .rounded)
        homeDate_Month.font =  setFont(fontSize: 24, fontweight: .regular, fontDesign: .rounded)
        
        homeDate_Day.textAlignment = .left
        homeDate_WeekDay.textAlignment = .left
        homeDate_Month.textAlignment = .left
        
        
        homeDate_Day.frame = CGRect(x: 5, y: 18, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
        homeDate_WeekDay.frame = CGRect(x: 70, y: homeTopBar.bounds.minY+30, width: (homeTopBar.bounds.width/2)-100, height: homeTopBar.bounds.height)
        homeDate_Month.frame = CGRect(x: 70, y: homeTopBar.bounds.minY+10, width: (homeTopBar.bounds.width/2)-80, height: homeTopBar.bounds.height)
 
        
        homeDate_WeekDay.adjustsFontSizeToFitWidth = true
        homeDate_Month.adjustsFontSizeToFitWidth = true
        
        homeTopBar.addSubview(homeDate_Day)
        homeTopBar.addSubview(homeDate_WeekDay)
        homeTopBar.addSubview(homeDate_Month)
        
//        homeDate_WeekDay.translatesAutoresizingMaskIntoConstraints = false
//        homeDate_WeekDay.centerXAnchor.constraint(equalTo: homeDate_Day.centerXAnchor, constant: 20).isActive = true
//        homeDate_WeekDay.leadingAnchor.constraint(equalTo: homeDate_Day.trailingAnchor, constant: 20).isActive = true
//        homeDate_WeekDay.widthAnchor.constraint(equalToConstant: homeTopBar.bounds.width/2).isActive = true
//        homeDate_WeekDay.heightAnchor.constraint(equalToConstant: homeTopBar.bounds.height/4).isActive = true
 
    }
    
    //MARK:- setup cal button
    func setupCalButton()  {
        
        
//        let configuration = UIImage.SymbolConfiguration(scale: .large)
        let configuration = UIImage.SymbolConfiguration(pointSize: 30, weight: .regular, scale: .large)
        let smallSymbolImage = UIImage(systemName: "chevron.up.chevron.down", withConfiguration: configuration)
        let colouredCalPullDownImage = smallSymbolImage?.withTintColor(secondaryAccentColor, renderingMode: .alwaysOriginal)
        
        let calButton = colouredCalPullDownImage //UIImage(named: "cal_Icon")
//        revealCalAtHomeButton.frame = CGRect(x: (UIScreen.main.bounds.minX+UIScreen.main.bounds.width/4)+10 , y: UIScreen.main.bounds.minY+65, width: 50, height: 50)
//        revealCalAtHomeButton.frame = CGRect(x: (UIScreen.main.bounds.minX+UIScreen.main.bounds.width/2)-20 , y: UIScreen.main.bounds.minY+65, width: 50, height: 50)
//        revealCalAtHomeButton.frame = CGRect(x: (UIScreen.main.bounds.width/2)-50 , y: UIScreen.main.bounds.minY+65, width: 50, height: 50)
        revealCalAtHomeButton.frame = CGRect(x: (UIScreen.main.bounds.width/2)-60 , y: UIScreen.main.bounds.minY+55, width: 200, height: 200)
        revealCalAtHomeButton.setImage(calButton, for: .normal)
        revealCalAtHomeButton.backgroundColor = .clear
        revealCalAtHomeButton.titleLabel?.text = "GREEN"
        
        revealCalAtHomeButton.sizeToFit()
        revealCalAtHomeButton.addTarget(self, action: #selector(showCalMoreButtonnAction), for: .touchUpInside)
        view.addSubview(revealCalAtHomeButton)
        
    }
    
    func setupTopSeperator() {
        
        seperatorTopLineView = UIView(frame: CGRect(x: UIScreen.main.bounds.width/2, y: backdropNochImageView.bounds.height + 10, width: 1.0, height: homeTopBar.bounds.height/2))
        seperatorTopLineView.layer.borderWidth = 1.0
        //        seperatorTopLineView.layer.borderColor = UIColor.white.cgColor
        seperatorTopLineView.layer.borderColor = UIColor.gray.cgColor
        self.view.addSubview(seperatorTopLineView)
        
    }
    
    
    
    //MARK:- View did load
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //MARK: serve material backdrop
        headerEndY = 128
        setupBackdropBackground() //backdrop
        setupBackdropForeground() //foredrop
        setupBackdropNotch() //notch
        
        // cal
        setupCal()
        view.addSubview(calendar)
        calendar.isHidden = true //hidden by default
        //--- done top cal
        
        // table view
        tableView.frame = CGRect(x: 0, y: headerEndY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)
        view.addSubview(tableView)
        
        setupBottomAppBar()
        view.addSubview(bottomAppBar)
        setHomeViewDate()
        view.bringSubviewToFront(bottomAppBar)
        
        setupCalButton()
        setupTopSeperator()
        
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
        
        
        
        //        chec
        
        
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
        
        
        completedTaskCell.textLabel!.text = "\t\(currentTask.name)"
        completedTaskCell.backgroundColor = UIColor.clear
        
        //        openTaskCell.textLabel!.text = currentTask.name
        openTaskCell.textLabel!.text = "\t\(currentTask.name)"
        openTaskCell.backgroundColor = UIColor.clear
        
        if currentTask.isComplete {
            completedTaskCell.textLabel?.textColor = .tertiaryLabel
            //            completedTaskCell.accessoryType = .checkmark
            
            let checkBox:BEMCheckBox = BEMCheckBox.init(frame: CGRect(x: openTaskCell.bounds.minX+5, y: openTaskCell.bounds.minY+10, width: 20, height: 25))
            checkBox.lineWidth = 1.0
            checkBox.animationDuration = 0.45
            checkBox.setOn(true, animated: false)
            checkBox.boxType = .square
            checkBox.onAnimationType = .oneStroke
            checkBox.offAnimationType = .oneStroke
            
            
            
            completedTaskCell.addSubview(checkBox)
            
            //          let priorityLineView = UIView(frame: CGRect(x: completedTaskCell.bounds.minX, y: completedTaskCell.bounds.minY, width: 5.0, height: completedTaskCell.bounds.height))
            //            priorityLineView.clipsToBounds = true
            
            //            let priorityLineView_Right = UIView(frame: CGRect(x: completedTaskCell.bounds.maxX, y: completedTaskCell.bounds.minY, width: 5.0, height: completedTaskCell.bounds.height))
            //            priorityLineView_Right.clipsToBounds = true
            
            //1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is p4; default is 3(p2)
            if (currentTask.taskPriority == 1) { //p0
                
                //                          priorityLineView.backgroundColor = .systemRed
                //                        priorityLineView_Right.backgroundColor = .systemRed
                
            } else if (currentTask.taskPriority == 2) {
                
                //                          priorityLineView.backgroundColor = .systemOrange
                //                        priorityLineView_Right.backgroundColor = .systemOrange
                
            } else if (currentTask.taskPriority == 3) {
                
                //                          priorityLineView.backgroundColor = .systemYellow
                //                        priorityLineView_Right.backgroundColor = .systemYellow
                
            } else {
                //                          priorityLineView.backgroundColor = .systemGray3
                //                        priorityLineView_Right.backgroundColor = .systemGray3
            }
            //            completedTaskCell.addSubview(priorityLineView)
            //            completedTaskCell.addSubview(priorityLineView_Right)
            
            return completedTaskCell
            
        } else {
            
            
            
            openTaskCell.textLabel?.textColor = .label
            //            openTaskCell.accessoryType = .detailButton
            openTaskCell.accessoryType = .disclosureIndicator
            
            
            
            let checkBox:BEMCheckBox = BEMCheckBox.init(frame: CGRect(x: openTaskCell.bounds.minX+5, y: openTaskCell.bounds.minY+10, width: 20, height: 25))
            checkBox.lineWidth = 1.0
            checkBox.animationDuration = 0.45
            checkBox.setOn(false, animated: false)
            checkBox.boxType = .square
            checkBox.onAnimationType = .oneStroke
            checkBox.offAnimationType = .oneStroke
            
            openTaskCell.addSubview(checkBox)
            
            
            
            
            let priorityLineView_Right = UIView() //UIView(frame: CGPoint(x: openTaskCell.bounds.maxX, y: openTaskCell.bounds.midY))//(frame: CGRect(x: openTaskCell.bounds.maxX, y: openTaskCell.bounds.minY, width: 5.0, height: openTaskCell.bounds.height))
            
            
            priorityLineView_Right.clipsToBounds = true
            
            //1-4 where 1 is p0; 2 is p1; 3 is p2; 4 is p4; default is 3(p2)
            if (currentTask.taskPriority == 1) { //p0
                
                
                //                priorityLineView_Right.backgroundColor = .systemRed
                
            } else if (currentTask.taskPriority == 2) {
                
                
                //                priorityLineView_Right.backgroundColor = .systemOrange
                
            } else if (currentTask.taskPriority == 3) {
                
                
                //                priorityLineView_Right.backgroundColor = .systemYellow
                
            } else {
                
                //                priorityLineView_Right.backgroundColor = .systemGray3
            }
            
            
            //            openTaskCell.addSubview(priorityLineView_Right)
            
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
            
//            self.scoreForTheDay.text = "\(self.calculateTodaysScore())"
            print("SCORE IS: \(self.calculateTodaysScore())")
            self.scoreCounter.text = "\(self.calculateTodaysScore())"
            
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
    
    //MARK: Setup calendar appearence
    func setupCal() {
        let calendar = FSCalendar(frame: CGRect(x: 0, y: homeTopBar.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height/2))
        calendar.calendarHeaderView.backgroundColor = primaryColorDarker //UIColor.lightGray.withAlphaComponent(0.1)
        calendar.calendarWeekdayView.backgroundColor = primaryColorDarker //UIColor.lightGray.withAlphaComponent(0.1)
        calendar.appearance.weekdayTextColor = .white
        calendar.appearance.headerTitleColor = .white
        calendar.appearance.titleWeekendColor = .red
        calendar.appearance.caseOptions = .weekdayUsesUpperCase
        //        calendar.appearance.eventSelectionColor = secondaryAccentColor
        //        calendar.appearance.separators = .interRows
        //        calendar.appearance.selectionColor = secondaryAccentColor
        calendar.appearance.subtitleDefaultColor = .white
        //        calendar.appearance.subtitleTodayColor
        //        calendar.appearance.todayColor = .green
        
        
        calendar.dataSource = self
        calendar.delegate = self
        
        self.calendar = calendar
        self.calendar.scope = FSCalendarScope.week
        //        calendar.backgroundColor = .white
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
    
    
    //MARK:- Animation Move Offses
    
    func moveRight(view: UIView) {
        view.center.x += 300
    }
    
    func moveLeft(view: UIView) {
        view.center.x -= 300
    }
    func moveDown_revealCal(view: UIView) {
        isCalDown = true
        view.center.y += 150
    }
    func moveUp_hideCal(view: UIView) {
        isCalDown = false
        view.center.y -= 150
    }
    //    func moveDown_onCalReveal(view: UIView) {
    //        view.center.y -= 300
    //    }
    
    //MARK:- setup bottom bar
    func setupBottomAppBar() {
        bottomAppBar.floatingButton.setImage(UIImage(named: "material_add_White"), for: .normal)
        bottomAppBar.floatingButton.backgroundColor = secondaryAccentColor //.systemIndigo
        bottomAppBar.frame = CGRect(x: 0, y: UIScreen.main.bounds.maxY-100, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.maxY-100)
        bottomAppBar.barTintColor = primaryColor//primaryColor
        
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
    
    //MARK:- Setup Backdrop Notch
    func setupBackdropNotch() {
        backdropNochImageView.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 40)
        backdropNochImageView.backgroundColor = primaryColorDarker
        
        view.addSubview(backdropNochImageView)
    }
    
    //MARK:- Setup Backdrop Background - Today label + Score
    func setupBackdropBackground() {
        
        backdropBackgroundImageView.frame =  CGRect(x: 0, y: backdropNochImageView.bounds.height, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        backdropBackgroundImageView.backgroundColor = primaryColor
        homeTopBar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 120)
        backdropBackgroundImageView.addSubview(homeTopBar)
        
        
        //---------- score at home
        
        scoreAtHomeLabel.text = "\n\nscore"
        scoreAtHomeLabel.numberOfLines = 3
        scoreAtHomeLabel.textColor = .systemGray6
        scoreAtHomeLabel.font = setFont(fontSize: 20, fontweight: .regular, fontDesign: .monospaced)
        
        scoreAtHomeLabel.textAlignment = .center
        scoreAtHomeLabel.frame = CGRect(x: UIScreen.main.bounds.width - 150, y: 20, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
        
        homeTopBar.addSubview(scoreAtHomeLabel)
        
        //---- score
        
        scoreCounter.text = "\(self.calculateTodaysScore())"
        scoreCounter.numberOfLines = 1
        scoreCounter.textColor = .systemGray5
        scoreCounter.font = setFont(fontSize: 52, fontweight: .bold, fontDesign: .rounded)
        
        scoreCounter.textAlignment = .center
        scoreCounter.frame = CGRect(x: UIScreen.main.bounds.width - 150, y: 15, width: homeTopBar.bounds.width/2, height: homeTopBar.bounds.height)
        
        homeTopBar.addSubview(scoreCounter)
        
        view.addSubview(backdropBackgroundImageView)
        
        
    }
    
    //----------------------- *************************** -----------------------
    //MARK:-              BACKDROP PATTERN: SETUP FOREGROUND
    //----------------------- *************************** -----------------------
    
    //MARK: Setup forground
    func setupBackdropForeground() {
        //    func setupBackdropForeground() {
        
        print("Backdrop starts from: \(headerEndY)")
        backdropForeImageView.frame = CGRect(x: 0, y: headerEndY, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height-headerEndY)


        
        backdropForeImageView.image = backdropForeImage?.withRenderingMode(.alwaysTemplate)
        backdropForeImageView.tintColor = .systemGray6
        
                
        backdropForeImageView.layer.shadowColor = UIColor.black.cgColor
        backdropForeImageView.layer.shadowOpacity = 0.8
        backdropForeImageView.layer.shadowOffset = CGSize(width: -5.0, height: -5.0) //.zero
        backdropForeImageView.layer.shadowRadius = 10
        
        view.addSubview(backdropForeImageView)
        
    }
    

    
    //------------ circle delegate end
    
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
    //MARK:-                     ACTION: SHOW CALENDAR
    //----------------------- *************************** -----------------------
    
    //MARK:    showCalMoreButtonnAction
    
    @objc func showCalMoreButtonnAction() {
        
        print("Show cal !!")
        
        let delay: Double = 0.2
        let duration: Double = 1.2
        
        if(isCalDown) { //cal is out; it sldes back up
            
            
            self.view.bringSubviewToFront(self.tableView)
            self.view.sendSubviewToBack(calendar)
            self.view.sendSubviewToBack(backdropBackgroundImageView)
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_hideCal(view: self.tableView)
            }) { (_) in
                
            }
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveUp_hideCal(view: self.backdropForeImageView)
            }) { (_) in
                
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) { //adds delay
                
                // self.calendar.isHidden = true //todo: hide this after you are sure to do list is back up; commentig this fixes doubta tap cal hide bug
                
            }
            
            self.view.bringSubviewToFront(self.bottomAppBar)
            
        } else {
            self.view.bringSubviewToFront(self.tableView)
            self.view.sendSubviewToBack(calendar)
            self.view.sendSubviewToBack(backdropBackgroundImageView)
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealCal(view: self.tableView)
            }) { (_) in
                //            self.moveLeft(view: self.black4)
            }
            
            UIView.animate(withDuration: duration, delay: delay, usingSpringWithDamping: 0.5, initialSpringVelocity: 2, options: .curveLinear, animations: {
                self.moveDown_revealCal(view: self.backdropForeImageView)
            }) { (_) in
                //            self.moveLeft(view: self.black4)
            }
            
            self.view.bringSubviewToFront(self.tableView)
            self.view.bringSubviewToFront(self.bottomAppBar)
            self.calendar.isHidden = false
            
        }
        tableView.reloadData()
    }
    
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
    
    //----------------------- *************************** -----------------------
    //MARK:-                            CALENDAR
    //----------------------- *************************** -----------------------
    
    //MARK: Cal changes VIEW + SCORE on date change
    func calendar(_ calendar: FSCalendar, didSelect date: Date, at monthPosition: FSCalendarMonthPosition) {
        print("You selected Date: \(date.stringIn(dateStyle: .full, timeStyle: .none))")
        dateToDisplay = date
        dateForTheView = date
        
        updateHomeDate(date: dateToDisplay)
//        (self.calculateTodaysScore()
        self.scoreCounter.text = "\(self.calculateTodaysScore())"
        
        tableView.reloadData()
        animateTableViewReload()
    }
    
}

//----------------------- *************************** -----------------------
//MARK:-                            CALENDAR DELEGATE
//----------------------- *************************** -----------------------

//MARK:- CAL Extention: task count as day subtext
extension ViewController: FSCalendarDataSource, FSCalendarDelegate, FSCalendarDelegateAppearance {
    
    func calendar(_ calendar: FSCalendar, subtitleFor date: Date) -> String? {
        
        let morningTasks = TaskManager.sharedInstance.getMorningTaskByDate(date: date)
        let eveningTasks = TaskManager.sharedInstance.getEveningTaskByDate(date: date)
        let allTasks = morningTasks+eveningTasks
        
        if(allTasks.count == 0) {
            return "-"
        } else {
            return "\(allTasks.count) tasks"
        }
    }
}

extension ViewController: CircleMenuDelegate {
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

