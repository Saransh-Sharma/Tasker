//
//  AddTaskTableViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 29/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import CoreData

class AddTaskTableViewController: UITableViewController {
    
    // MARK:- Outlets
    @IBOutlet weak var addTaskTextField: UITextField!
    
    @IBOutlet weak var eveningTaskSwitch: UISwitch!
    @IBAction func doneButtonTapped(_ sender: Any) {
        navigationController?.popViewController(animated: true)
        
        if addTaskTextField.text != nil && addTaskTextField.text != "" {
            
            TaskManager.sharedInstance.addNewTask(name: addTaskTextField.text!, taskType: getTaskType(), taskPriority: 2)
            
            //OLD_TodoManager.sharedInstance.addTaskWithName(name: addTaskTextField.text!)
        }
    }
    
    func getTaskPriority() -> Int {
        return 2
    }
    
    func getTaskType() -> Int { //extend this to return for inbox & upcoming/someday
        if eveningTaskSwitch.isOn {
            return 2
        }
            //        else if isInboxTask {
            //
            //        }
            //        else if isUpcomingTask {
            //
            //        }
        else {
            //this is morning task
            return 1
        }
    }
    
    
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false
        
        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        //self.navigationItem.leftBarButtonItem = self.editButtonItem
        
        //set nav bar to black with white text
        self.navigationController!.navigationBar.barStyle = .black
        self.navigationController!.navigationBar.isTranslucent = true
        self.navigationController!.navigationBar.titleTextAttributes = [.foregroundColor: UIColor.white]
        self.navigationController!.navigationBar.tintColor = #colorLiteral(red: 1, green: 0.99997437, blue: 0.9999912977, alpha: 1)
        
        
        
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        addTaskTextField.becomeFirstResponder()
        
    }
    
    // MARK:- Actions
    //    @IBAction func done() {
    //    navigationController?.popViewController(animated: true) }
    
    
    // MARK: - Table view data source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return 1
    }
    
    /*
     override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
     let cell = tableView.dequeueReusableCell(withIdentifier: "reuseIdentifier", for: indexPath)
     
     // Configure the cell...
     
     return cell
     }
     */
    
    /*
     // Override to support conditional editing of the table view.
     override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
     // Return false if you do not want the specified item to be editable.
     return true
     }
     */
    
    /*
     // Override to support editing the table view.
     override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
     if editingStyle == .delete {
     // Delete the row from the data source
     tableView.deleteRows(at: [indexPath], with: .fade)
     } else if editingStyle == .insert {
     // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
     }
     }
     */
    
    /*
     // Override to support rearranging the table view.
     override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {
     
     }
     */
    
    /*
     // Override to support conditional rearranging of the table view.
     override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
     // Return false if you do not want the item to be re-orderable.
     return true
     }
     */
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
}
