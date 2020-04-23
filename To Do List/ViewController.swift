//
//  ViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 14/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    let dailyTasks = ["make breakfast",
                      "clean study desk",
                      "workout"]
    
    let weeklyTasks = ["do laundry",
                       "meet batman",
                       "get supplies"]
    
    let monthlyTasks = ["Deep clean the carpet",
                        "pay rent",
                        "prep montly report"]
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        print("You selected row \(indexPath.row) from section \(indexPath.section)")
    }
   
//    func tableView(_ tableView: UITableView, leadingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
//        let action = UIContextualAction(style: .normal, title: "bla") { (action, view, success) in
//            success(true)
//        }
//        return UISwipeActionsConfiguration(actions: [action])
//    }
      
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3;
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "Daily Tasks:"
        case 1:
            return "Weekly Tasks:"
        case 2:
            return "Monthly Tasks:"
        default:
            return nil
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    
        switch section {
        case 0:
            return dailyTasks.count
        case 1:
        return weeklyTasks.count
        case 2:
        return monthlyTasks.count
        default:
            return 0;
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
//        let cell = UITableViewCell()
        let cell = tableView.dequeueReusableCell(withIdentifier: "normalCell", for: indexPath)
        //cell.textLabel?.text = "This is row number \(indexPath.row)"
        //return cell;
        
        switch indexPath.section {
        case 0:
            //cell.imageView
            cell.textLabel?.text = dailyTasks[indexPath.row]
        case 1:
            cell.textLabel?.text = weeklyTasks[indexPath.row]
        case 2:
            cell.textLabel?.text = monthlyTasks[indexPath.row]
        default:
            cell.textLabel?.text = "This should not happen !"
        }
        
        return cell
        
    }
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.title = "Today"
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
    
    @IBAction func changeBackgroundBackToLight(_ sender: Any) {
        
        view.backgroundColor = UIColor.white
            
            let everything = view.subviews
            
            for each in everything {
                //each.backgroundColor = UIColor.white
                if(each is UILabel) {
                         let currenLabel = each as! UILabel
                    currenLabel.textColor = UIColor.black
                    
                    
                     }
            }
    }
    @IBAction func changeLabelButton(_ sender: Any) {
        
    }
    @IBOutlet weak var labelToBeChanged: UILabel!
    
}

