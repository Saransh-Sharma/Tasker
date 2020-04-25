//
//  ViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.title = "Today"
    }
    
    var todaysTasks = [
        Task(name: "make breakfast", type: TaskType.today, completed: true, lastCompleted: nil, taskCreationDate: nil, priority: TaskPriority.p0),
        Task(name: "clean study desk", type: TaskType.today, completed: true, lastCompleted: nil, taskCreationDate: nil, priority: TaskPriority.p1),
        Task(name: "workout", type: TaskType.today, completed: false, lastCompleted: nil, taskCreationDate: nil, priority: TaskPriority.p2),
        Task(name: "water plants", type: TaskType.today, completed: false, lastCompleted: nil, taskCreationDate: nil, priority: TaskPriority.p3),
        Task(name: "push code for to do app", type: TaskType.today, completed: false, lastCompleted: nil, taskCreationDate: nil, priority: TaskPriority.p2)
    ]
    
    
    var eveningTasks = [
    Task(name: "do laundry", type: TaskType.today, completed: false, lastCompleted: nil, taskCreationDate: nil, priority: TaskPriority.p1),
    Task(name: "meet batman", type: TaskType.today, completed: false, lastCompleted: nil, taskCreationDate: nil, priority: TaskPriority.p2),
    Task(name: "get supplies", type: TaskType.today, completed: false, lastCompleted: nil, taskCreationDate: nil, priority: TaskPriority.p2),
    Task(name: "invent covid-19 vaccine", type: TaskType.today, completed: false, lastCompleted: nil, taskCreationDate: nil, priority: TaskPriority.p3),
    ]

    @IBOutlet weak var addTaskAtHome: UIButton!
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("You selected row \(indexPath.row) from section \(indexPath.section)")
    }
      
    @IBAction func toggleDarkMode(_ sender: Any) {
        
        let mSwitch = sender as! UISwitch
        
        if mSwitch.isOn {
            view.backgroundColor = UIColor.darkGray
        } else {
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "normalCell", for: indexPath)
        
        
        
        switch indexPath.section {
        case 0:
            //cell.imageView
            currentTask = todaysTasks[indexPath.row]
        case 1:
            currentTask = eveningTasks[indexPath.row]
        default:
            break
        }
        cell.textLabel!.text = currentTask.name
        cell.backgroundColor = UIColor.clear
        
        if currentTask.completed {
            cell.textLabel?.textColor = UIColor.lightGray
            cell.accessoryType = .checkmark
        } else {
            
            cell.textLabel?.textColor = UIColor.black
            cell.accessoryType = .none
        }
        
        return cell
        
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
            
            tableView.reloadData()
            actionPerformed(true)
        }
        
        return UISwipeActionsConfiguration(actions: [completeTaskAction])
    }
    
    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        
        let deleteTaskAction = UIContextualAction(style: .destructive, title: "Delete") { (action: UIContextualAction, sourceView: UIView, actionPerformed: (Bool) -> Void) in
            
            switch indexPath.section {
            case 0:
                self.todaysTasks.remove(at: indexPath.row)
            case 1:
                self.todaysTasks.remove(at: indexPath.row)
            default:
                break
            }
            tableView.reloadData()
            actionPerformed(true)
        }
        
        return UISwipeActionsConfiguration(actions: [deleteTaskAction])
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
}

