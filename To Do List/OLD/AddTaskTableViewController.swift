//
//  AddTaskTableViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 29/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import CoreData


class AddTaskTableViewController: UIViewController {
    
    var primaryColor =  #colorLiteral(red: 0.6941176471, green: 0.9294117647, blue: 0.9098039216, alpha: 1)
    var secondryColor =  #colorLiteral(red: 0.2039215686, green: 0, blue: 0.4078431373, alpha: 1)
    
    
    let tableView = UITableView()
    var characters = ["Link", "Zelda", "Ganondorf", "Midna"]
    let cellId = "cell_ID"
    // MARK:- Outlets
    
    //
   
     
    
    
    
    
    override func loadView() {
        super.loadView()
        view.addSubview(servePageHeader())
        setupTableView()
    }
    
    func setupTableView() {
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: cellId)
    }
    
  
    
}

extension AddTaskTableViewController: UITableViewDataSource {
      
      func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
          return characters.count
      }
      func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
          let cell = tableView.dequeueReusableCell(withIdentifier: cellId, for: indexPath)
           cell.textLabel?.text = "Hello, World"
          
        
        cell.backgroundColor = UIColor.red
          return cell
      }
  }



//MARK:- SERVE PAGE HEADER

func servePageHeader() -> UIView {
    let view = UIView(frame: UIScreen.main.bounds)
    view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 128)
    view.backgroundColor = UIColor.green
    
    //            let homeTitle = UILabel()
    //            homeTitle.frame = CGRect(x: (view.frame.minX+view.frame.maxX/5)+3, y: view.frame.maxY-60, width: view.frame.width/2+view.frame.width/8, height: 64)
    //            homeTitle.text = "Today's score is "
    //            homeTitle.textColor = primaryColor
    //            homeTitle.textAlignment = .left
    //            homeTitle.font = UIFont(name: "HelveticaNeue-Medium", size: 30)
    //            view.addSubview(homeTitle)
    
    return view
}




// MARK:- OLD Outlets
//-------------------------------------------------------
//    @IBOutlet var addTaskTableView: UITableView!
//    @IBOutlet weak var dayPicker: UIPickerView!
//    @IBOutlet weak var addTaskTextField: UITextField!
//    @IBOutlet weak var doneButton: UIBarButtonItem!
//    @IBOutlet weak var eveningTaskSwitch: UISwitch!
//    @IBOutlet weak var segmentedPriority: UISegmentedControl!
//    @IBAction func prioritySelected(_ sender: UISegmentedControl) {
//        //sender.segm
//    }
//-------------------------------------------------------



//    @IBAction func doneButtonTapped(_ sender: Any) {
//        if addTaskTextField.text != nil && addTaskTextField.text != "" {
//
//            TaskManager.sharedInstance.addNewTask(name: addTaskTextField.text!, taskType: getTaskType(), taskPriority: 2)
//        }
//
//        dismiss(animated: true)
//    }

//    func getTaskPriority() -> Int {
//        return 2
//    }

//    func getTaskType() -> Int { //extend this to return for inbox & upcoming/someday
//        if eveningTaskSwitch.isOn {
//            return 2
//        }
//            //        else if isInboxTask {
//            //
//            //        }
//            //        else if isUpcomingTask {
//            //
//            //        }
//        else {
//            //this is morning task
//            return 1
//        }
//    }






//    func buildDayPicker() {
//        //dayPicker.title
//    }

//    override func viewWillAppear(_ animated: Bool) {
//        super.viewWillAppear(animated)
//        //        addTaskTextField.becomeFirstResponder()
//        
//    }

// MARK: - Table view data source



// MARK:- Text Field Delegates
//
//    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
//        let oldText = textField.text!
//        print("old text is: \(oldText)")
//        let stringRange = Range(range, in:oldText)!
//        let newText = oldText.replacingCharacters(in: stringRange, with: string)
//        print("new text is: \(newText)")
//        if newText.isEmpty {
//            print("EMPTY")
//            doneButton.isEnabled = false
//        } else {
//            print("NOT EMPTY")
//            doneButton.isEnabled = true }
//        return true
//    }



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




////////------------------------------------------------


//    override func viewDidLoad() {
//          super.viewDidLoad()
//          //        self.addTaskTableView.separatorColor = UIColor.clear
//          //        self.addTaskTableView.alwaysBounceVertical = false
//          //        self.addTaskTableView.allowsSelection = false
//
//          view.addSubview(servePageHeader())
//
//          //        self.segmentedPriority.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.white], for: UIControl.State.selected)
//          //
//          //        self.segmentedPriority.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.red], for: UIControl.State.normal)
//
//
//      }

