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


class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    // MARK: Outlets
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var todaysScoreCounter: UILabel!
    @IBOutlet weak var switchState: UISwitch!
    @IBOutlet weak var addTaskAtHome: UIButton!
    @IBOutlet weak var scoreButton: UIBarButtonItem!
    
    
    @IBAction func showStuff(_ sender: Any) {
         let view = UIView(frame: UIScreen.main.bounds)
            view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 300)
            view.backgroundColor = UIColor.blue
            
            let options: [SemiModalOption : Any] = [
                SemiModalOption.pushParentBack: true
            ]
            
            presentSemiView(view, options: options) {
                print("Completed!")
            }
    }
    //    var todaysTasks = [Task]()
    //    var eveningTasks = [Task]()
    
    //    var globalTaskList: [Task] = []
    
    //    func makeTask(name: String, type: TaskType, completed: Bool, lastCompleted: NSDate?, taskCreationDate: NSDate?, priority: TaskPriority? ) -> Task {
    //        return Task(name: name, type: type, completed: completed, lastCompleted: lastCompleted, taskCreationDate: taskCreationDate, priority: priority)
    //      }
    
    //    func addTaskToGlobalTasksList(taskToBeadded: Task, globalTasks: [Task]) -> [Task] {
    //        var mTasks: [Task]
    //        mTasks = globalTasks
    //        mTasks.append(taskToBeadded)
    //        return mTasks
    //    }
    
    //    func getTodayMorningTasks(globalTasksList: [Task]) -> [Task] {
    //
    //        var todayMorning: [Task]
    //
    //
    //        for each in globalTasksList {
    //           // each.lastCompleted = isToaf
    //            let today = Calendar.current.isDateInToday(each.lastCompleted! as Date)
    //        }
    //    }
    
    
    // MARK:- View Lifecycle methods
    
    override func viewWillAppear(_ animated: Bool) {
        // right spring animation
        tableView.reloadData(
            with: .spring(duration: 0.45, damping: 0.65, velocity: 1, direction: .right(useCellsFrame: false),
            constantDelay: 0))
    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        enableDarkModeIfPreset()
        todaysScoreCounter.text = "\(calculateTodaysScore())"
        self.title = "This Day \(calculateTodaysScore())"
        //navigationItem.prompt = NSLocalizedString("Your productivity score for the day is", comment: "")
        
        //        print("OLD count is: \(OLD_TodoManager.sharedInstance.count)")
        print("NEW count is: \(TaskManager.sharedInstance.count)")
        
        
        //set nav bar to black with white text
        self.navigationController!.navigationBar.barStyle = .black
        self.navigationController!.navigationBar.backgroundColor = #colorLiteral(red: 0.2039215686, green: 0, blue: 0.4078431373, alpha: 1)
        self.navigationController!.navigationBar.isTranslucent = false
        self.navigationController!.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        //        self.navigationController!.navigationBar.tintColor = #colorLiteral(red: 1, green: 0.99997437, blue: 0.9999912977, alpha: 1)
        
        self.navigationController!.navigationBar.prefersLargeTitles = true
        
        scoreButton.title = "99"
        
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
            view.backgroundColor =  #colorLiteral(red: 0.6941176471, green: 0.9294117647, blue: 0.9098039216, alpha: 1)
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
    
    // MARK:- DID SELECT ROW AT
    /*
     Prints logs on selecting a row
     */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("You selected row \(indexPath.row) from section \(indexPath.section)")
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
            openTaskCell.accessoryType = .detailDisclosureButton
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
            
            self.todaysScoreCounter.text = "\(self.calculateTodaysScore())"
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

