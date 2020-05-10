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
import TableViewReloadAnimation
import CircleMenu
import MaterialComponents.MaterialButtons
import MaterialComponents.MaterialButtons_Theming
//import StrikethroughLabel


extension UIColor {
    static func color(_ red: Int, green: Int, blue: Int, alpha: Float) -> UIColor {
        return UIColor(
            red: 1.0 / 255.0 * CGFloat(red),
            green: 1.0 / 255.0 * CGFloat(green),
            blue: 1.0 / 255.0 * CGFloat(blue),
            alpha: CGFloat(alpha))
    }
}

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, CircleMenuDelegate {
    
    let colors = [UIColor.red, UIColor.gray, UIColor.green, UIColor.purple]
    let items: [(icon: String, color: UIColor)] = [
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
    //    @IBOutlet weak var scoreButton: UIBarButtonItem!
    
    var primaryColor =  #colorLiteral(red: 0.6941176471, green: 0.9294117647, blue: 0.9098039216, alpha: 1)
    var secondryColor =  #colorLiteral(red: 0.2039215686, green: 0, blue: 0.4078431373, alpha: 1)
    var scoreForTheDay: UILabel! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        view.addSubview(servePageHeader())
        
        
             //---Floating Action Button - Material
                let fab_AddTask = MDCFloatingButton()
                fab_AddTask.accessibilityLabel = "Add Task"
                fab_AddTask.minimumSize = CGSize(width: 64, height: 48)
                let kMinimumAccessibleButtonSizeHeeight: CGFloat = 48
                let kMinimumAccessibleButtonSizeWidth:CGFloat = 64
                
                let buttonVerticalInset =
                min(0, -(kMinimumAccessibleButtonSizeHeeight - fab_AddTask.bounds.height) / 2);
                let buttonHorizontalInset =
                min(0, -(kMinimumAccessibleButtonSizeWidth - fab_AddTask.bounds.width) / 2);
                fab_AddTask.hitAreaInsets =
                    UIEdgeInsets(top: buttonVerticalInset, left: buttonHorizontalInset,
                                 bottom: buttonVerticalInset, right: buttonHorizontalInset);
                fab_AddTask.frame = CGRect(x: UIScreen.main.bounds.maxX-UIScreen.main.bounds.maxX/5, y: UIScreen.main.bounds.maxY-300, width: 50, height: 50)
        
        let addTaskIcon = UIImage(named: "material_add_White")
        fab_AddTask.setImage(addTaskIcon, for: .normal)
        fab_AddTask.backgroundColor = secondryColor
                  fab_AddTask.sizeToFit()
                view.addSubview(fab_AddTask)
        
        //---Floating Action Button - Material - DONE
        
        
        
        //MARK: circle menu frame
        let circleMenuButton = CircleMenu(
            frame: CGRect(x: 32, y: 64, width: 30, height: 30),
            normalIcon:"icon_menu",
//            selectedIcon:"icon_close",
            selectedIcon:"material_close",
            buttonsCount: 5,
            duration: 1,
            distance: 50)
        circleMenuButton.backgroundColor = primaryColor
    
        circleMenuButton.delegate = self
        circleMenuButton.layer.cornerRadius = circleMenuButton.frame.size.width / 2.0
        view.addSubview(circleMenuButton)
        
        view.addSubview(serveAddTaskButton(addTaskButton: addTaskButton))
        
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
    
    func serveAddTaskButton(addTaskButton: UIButton) -> UIView {
        

//        addTaskButton.frame = CGRect(x: UIScreen.main.bounds.maxX-80, y: UIScreen.main.bounds.maxY-80, width: 50, height: 50)
            addTaskButton.frame = CGRect(x: UIScreen.main.bounds.maxX-UIScreen.main.bounds.maxX/5, y: UIScreen.main.bounds.maxY-UIScreen.main.bounds.maxY/11, width: 50, height: 50)
//        addTaskButton.titleLabel?.text = "+"
        addTaskButton.titleLabel?.textColor = primaryColor
        addTaskButton.titleLabel?.textAlignment = .center
        addTaskButton.titleLabel?.numberOfLines = 0
        addTaskButton.backgroundColor = secondryColor
        addTaskButton.layer.cornerRadius = addTaskButton.bounds.size.width/2;
        addTaskButton.layer.masksToBounds = true
        
        return addTaskButton
    }
    
    func servePageHeader() -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 128)
        view.backgroundColor = secondryColor
        
        let homeTitle = UILabel()
//        homeTitle.frame = CGRect(x: view.frame.minX+84, y: view.frame.maxY-60, width: view.frame.width/2+20, height: 64)
        homeTitle.frame = CGRect(x: (view.frame.minX+view.frame.maxX/5)+3, y: view.frame.maxY-60, width: view.frame.width/2+view.frame.width/8, height: 64)
        homeTitle.text = "Today's score is "
        homeTitle.textColor = primaryColor
        homeTitle.textAlignment = .left
        homeTitle.font = UIFont(name: "HelveticaNeue-Medium", size: 30)
        view.addSubview(homeTitle)
        
        scoreForTheDay = UILabel()
//        scoreForTheDay.frame = CGRect(x: view.frame.maxX-90, y: view.frame.maxY-60, width: 80, height: 64)
        scoreForTheDay.frame = CGRect(x: (view.frame.maxX-view.frame.maxX/6)-10, y: view.frame.maxY-60, width: 80, height: 64)
        scoreForTheDay.text = "13"
        scoreForTheDay.textColor = primaryColor
        scoreForTheDay.textAlignment = .center
        scoreForTheDay.font = UIFont(name: "HelveticaNeue-Medium", size: 40)
        view.addSubview(scoreForTheDay)
        
        return view
    }
    
    // MARK:- CircleMenuDelegate
    
    func circleMenu(_: CircleMenu, willDisplay button: UIButton, atIndex: Int) {
        button.backgroundColor = items[atIndex].color
        
        button.setImage(UIImage(named: items[atIndex].icon), for: .normal)
        
        // set highlited image
        let highlightedImage = UIImage(named: items[atIndex].icon)?.withRenderingMode(.alwaysTemplate)
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
        view.backgroundColor = primaryColor
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
        eveningLabel.textColor =  secondryColor
        eveningLabel.frame = CGRect(x: frameForView.minX+40, y: frameForView.minY+85, width: frameForView.width-100, height: frameForView.height/8)
        
        let eveningSwitch = UISwitch() //Evening Switch
        view.addSubview(eveningSwitch)
        eveningSwitch.onTintColor = secondryColor
        
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
        prioritySegmentedControl.selectedSegmentTintColor =  secondryColor
        
        
        
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
            currentTask = TaskManager.sharedInstance.getMorningTasks[indexPath.row]
        case 1:
            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
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
        tableView.reloadData(
            with: .spring(duration: 0.45, damping: 0.65, velocity: 1, direction: .right(useCellsFrame: false),
                          constantDelay: 0))
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
            view.backgroundColor =  primaryColor
        }
    }
    
    // MARK: calculate today's score
    /*
     Calculates daily productivity score
     */
    func calculateTodaysScore() -> Int { //TODO change this to handle NTASKs
        var score = 0
        for each in TaskManager.sharedInstance.getMorningTasks {
            
            if each.isComplete {
                
                score = score + each.getTaskScore(task: each)
            }
        }
        for each in TaskManager.sharedInstance.getEveningTasks {
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
            return TaskManager.sharedInstance.getMorningTasks.count
        case 1:
            //            print("Items in evening: \(TaskManager.sharedInstance.getEveningTasks.count)")
            return TaskManager.sharedInstance.getEveningTasks.count
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
            //            print("morning section index is: \(indexPath.row)")
            currentTask = TaskManager.sharedInstance.getMorningTasks[indexPath.row]
        case 1:
            //            print("evening section index is: \(indexPath.row)")
            currentTask = TaskManager.sharedInstance.getEveningTasks[indexPath.row]
        default:
            break
        }
        
        
        completedTaskCell.textLabel!.text = currentTask.name
        completedTaskCell.backgroundColor = UIColor.clear
        
        openTaskCell.textLabel!.text = currentTask.name
        openTaskCell.backgroundColor = UIColor.clear
        
        if currentTask.isComplete {
            completedTaskCell.textLabel?.textColor = UIColor.lightGray
            completedTaskCell.accessoryType = .checkmark
            
            return completedTaskCell
        } else {
            
            openTaskCell.textLabel?.textColor = UIColor.black
            //            cell.accessoryType = .detailButton
            openTaskCell.accessoryType = .disclosureIndicator
            //            cell.accessoryType = .disclosureIndicator
            return openTaskCell
        }
        
    }
    
    // MARK:- SWIPE ACTIONS
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        
        
        let completeTaskAction = UIContextualAction(style: .normal, title: "Complete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
            switch indexPath.section {
            case 0:
                TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: TaskManager.sharedInstance.getMorningTasks[indexPath.row])].isComplete = true
                TaskManager.sharedInstance.saveContext()
                
            case 1:
                
                TaskManager.sharedInstance.getAllTasks[self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: TaskManager.sharedInstance.getEveningTasks[indexPath.row])].isComplete = true
                TaskManager.sharedInstance.saveContext()
                
            default:
                break
            }
            
            self.scoreForTheDay.text = "\(self.calculateTodaysScore())"
            //            tableView.reloadData()
            
            // right spring animation
            tableView.reloadData(
                with: .spring(duration: 0.45, damping: 0.65, velocity: 1, direction: .right(useCellsFrame: false),
                              constantDelay: 0))
            
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
                
                switch indexPath.section {
                case 0:
                    
                    TaskManager.sharedInstance.removeTaskAtIndex(index: self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: TaskManager.sharedInstance.getMorningTasks[indexPath.row]))
                case 1:
                    TaskManager.sharedInstance.removeTaskAtIndex(index: self.getGlobalTaskIndexFromSubTaskCollection(morningOrEveningTask: TaskManager.sharedInstance.getEveningTasks[indexPath.row]))
                default:
                    break
                }
                
                //                tableView.reloadData()
                tableView.reloadData(
                    with: .simple(duration: 0.45, direction: .rotation3D(type: .captainMarvel),
                                  constantDelay: 0))
                
                
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
}

