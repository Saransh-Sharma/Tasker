//
//  WeeklyViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 23/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit

class WeeklyViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var weeklyTableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Week"
        // Do any additional setup after loading the view.
        
        weeklyTableView.delegate = self
        weeklyTableView.dataSource = self
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
    
        return UITableView.automaticDimension
    }

    func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
        return UITableView.automaticDimension
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "weeklyTaskCell", for: indexPath)
        
        cell.textLabel?.text = "This is a really long title that has no hope of fittinng in. blah blah blah.... blah blah blah.... blah blah blah.... \(indexPath.row)"
        
        if (indexPath.row == 3) {
            cell.textLabel?.text = "This is compact \(indexPath.row)"
        }
        
        cell.textLabel?.numberOfLines = 0
//        weeklyTaskTitleLabel.text = "This is weekly Cell \(indexPath.row)"
        //inboxCell.textLabel?.text = "This is weekly cell \(indexPath.row)"
        
        return cell
    }
    
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
}
