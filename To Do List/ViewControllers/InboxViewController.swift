//
//  SecondViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 22/04/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import ViewAnimator
//import TableViewReloadAnimation

class InboxViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    @IBOutlet weak var inboxTableView: UITableView!
    
    private let animations = [AnimationType.from(direction: .bottom, offset: 30.0)] //
    override func viewWillAppear(_ animated: Bool) {
        // right spring animation
//        inboxTableView.reloadData(
//            with: .spring(duration: 0.45, damping: 0.65, velocity: 1, direction: .right(useCellsFrame: false),
//            constantDelay: 0))
        
//        tableView.reloadData()
//        UIView.animate(views: tableView.visibleCells, animations: self.animations, completion: {
//
//               })
        
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Inbox"
        
        // Do any additional setup after loading the view.
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 15
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let inboxCell = UITableViewCell()
        
        inboxCell.textLabel?.text = "This is inbox cell \(indexPath.row)"
        
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
