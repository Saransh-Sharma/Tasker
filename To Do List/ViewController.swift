//
//  ViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit


class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var todaysScoreCounter: UILabel!
    @IBOutlet weak var switchState: UISwitch!
    @IBOutlet weak var addTaskAtHome: UIButton!
    
    var todaysTasks = [Task]()
    var eveningTasks = [Task]()
    
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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    
        enableDarkModeIfPreset()
        
        todaysScoreCounter.text = "\(calculateTodaysScore())"
        self.title = "This Day"
        
        
        let mTask1 = Task(withName: "Swipe me to left to complete your first task !", withPriority: TaskPriority.p0)
        let mTask2 = Task(withName: "Create your first task by clicking on the + sign", withPriority: TaskPriority.p1)
        let mTask3 = Task(withName: "Delete me by swiping to the right", withPriority: TaskPriority.p2)
        
        let mTask4 = Task(withName: "Meet Batman", withPriority: TaskPriority.p3)
        
        
        

        todaysTasks.append(mTask1)
        todaysTasks.append(mTask2)
        todaysTasks.append(mTask3)
        eveningTasks.append(mTask4)
        
    }
    
    /*
     Checks & enables dark mode if user previously set such
     */
    func enableDarkModeIfPreset() {
        if UserDefaults.standard.bool(forKey: "isDarkModeOn") {
                //switchState.setOn(true, animated: true)
                print("HOME: DARK ON")
                view.backgroundColor = UIColor.darkGray
            } else {
                print("HOME: DARK OFF !!")
            }
    }
    
    //    func buildEveningTasks(<#parameters#>) -> <#return type#> {
    //        <#function body#>
    //    }
    //
    //    func buildDayTasks(<#parameters#>) -> <#return type#> {
    //          <#function body#>
    //      }
    
    /*
     Calculates daily productivity score
     */
    func calculateTodaysScore() -> Int {
        var score = 0
        for each in todaysTasks {
            
            if each.completed {
                
                score = score + each.getTaskScore(task: each)
            }
        }
        for each in eveningTasks {
            if each.completed {
                score = score + each.getTaskScore(task: each)
            }
        }
        return score;
    }
    
    /*
     Prints logs on selecting a row
     */
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("You selected row \(indexPath.row) from section \(indexPath.section)")
    }
    
    
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
            return todaysTasks.count
        case 1:
            return eveningTasks.count
        default:
            return 0;
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        
        var currentTask: Task!
        let completedTaskCell = tableView.dequeueReusableCell(withIdentifier: "completedTaskCell", for: indexPath)
        let openTaskCell = tableView.dequeueReusableCell(withIdentifier: "openTaskCell", for: indexPath)
        
        
        switch indexPath.section {
        case 0:
            //cell.imageView
            currentTask = todaysTasks[indexPath.row]
        case 1:
            currentTask = eveningTasks[indexPath.row]
        default:
            break
        }
        
        completedTaskCell.textLabel!.text = currentTask.name
        completedTaskCell.backgroundColor = UIColor.clear
        
        openTaskCell.textLabel!.text = currentTask.name
        openTaskCell.backgroundColor = UIColor.clear
        
        if currentTask.completed {
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
        
        //        return completedTaskCell
        
    }
    
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let completeTaskAction = UIContextualAction(style: .normal, title: "Complete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
            switch indexPath.section {
            case 0:
                self.todaysTasks[indexPath.row].completed = true
            case 1:
                self.eveningTasks[indexPath.row].completed = true
            default:
                break
            }
            
            self.todaysScoreCounter.text = "\(self.calculateTodaysScore())"
            tableView.reloadData()
            actionPerformed(true)
        }
        
        //todaysScoreCounter.text = "\(calculateTodaysScore())"
        return UISwipeActionsConfiguration(actions: [completeTaskAction])
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let deleteTaskAction = UIContextualAction(style: .destructive, title: "Delete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
            let confirmDelete = UIAlertController(title: "Are you sure?", message: "This will delete this task", preferredStyle: .alert)
            
            let yesDeleteAction = UIAlertAction(title: "Yes", style: .destructive)
            {
                (UIAlertAction) in
                
                switch indexPath.section {
                case 0:
                    self.todaysTasks.remove(at: indexPath.row)
                case 1:
                    self.eveningTasks.remove(at: indexPath.row)
                default:
                    break
                }
                
                tableView.reloadData()
                
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

