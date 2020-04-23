//
//  WeeklyViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 23/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit

class WeeklyViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Week"
        // Do any additional setup after loading the view.
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 15
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let inboxCell = UITableViewCell()
        
        inboxCell.textLabel?.text = "This is weekly cell \(indexPath.row)"
        
        return inboxCell
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
