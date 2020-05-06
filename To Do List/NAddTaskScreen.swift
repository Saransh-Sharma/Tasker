//
//  NAddTaskScreen.swift
//  To Do List
//
//  Created by Saransh Sharma on 07/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit

class NAddTaskScreen: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    var primaryColor =  #colorLiteral(red: 0.6941176471, green: 0.9294117647, blue: 0.9098039216, alpha: 1)
    var secondryColor =  #colorLiteral(red: 0.2039215686, green: 0, blue: 0.4078431373, alpha: 1)
    
    
    let addTaskTextField = UITextView()
    let seperatorCellID = "seperator"
    // MARK:- Outlets
    
    @IBOutlet weak var weeklyTableView: UITableView!
    
 
    
    
    
//    override func loadView() {
//        super.loadView()
////        view.addSubview(servePageHeader())
////        setupTableView()
//    }
    
     override func viewDidLoad() {
            super.viewDidLoad()
        
            view.addSubview(setupAddTaskPageHeader())
            weeklyTableView.delegate = self
            weeklyTableView.dataSource = self
            
        }
        
        func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
            if (indexPath.row == 0) {
                return view.bounds.height/10
            }
            return UITableView.automaticDimension
        }

        func tableView(_ tableView: UITableView, estimatedHeightForRowAt indexPath: IndexPath) -> CGFloat {
            return UITableView.automaticDimension
        }
        
        func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return 5
        }
        
        func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            
            var cell = UITableViewCell()
            cell.textLabel?.numberOfLines = 0
            
            
            
            if (indexPath.row == 0) {
                cell = tableView.dequeueReusableCell(withIdentifier: seperatorCellID, for: indexPath)
                cell.backgroundColor = secondryColor
                
//               // cell.textLabel?.text = "This is compact \(indexPath.row)"
//                cell.backgroundColor = secondryColor
////                addTaskTextField.placeholde
//
//                let textField = UITextField()
////                textField.frame = CGRect(x: cell.bounds.minX, y: cell.bounds.minY, width: cell.bounds.width, height: cell.bounds.width)
//                let placeholderString =
//                    NSAttributedString.init(string: "UITextField Demo", attributes: [NSAttributedString.Key.foregroundColor : primaryColor])
//
//                textField.attributedPlaceholder = placeholderString
//                cell.addSubview(textField)
                
                
                
            } else {
                cell.textLabel?.text = "This is a really long title that has no hope of fittinng in. blah blah blah.... blah blah blah.... blah blah blah.... \(indexPath.row)"
            }
            
            
    //        weeklyTaskTitleLabel.text = "This is weekly Cell \(indexPath.row)"
            //inboxCell.textLabel?.text = "This is weekly cell \(indexPath.row)"
            
            return cell
        }
    
//    func setupTableView() {
//        view.addSubview(tableView)
//        tableView.translatesAutoresizingMaskIntoConstraints = false
//        tableView.topAnchor.constraint(equalTo: view.topAnchor).isActive = true
//        tableView.leftAnchor.constraint(equalTo: view.leftAnchor).isActive = true
//        tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor).isActive = true
//        tableView.rightAnchor.constraint(equalTo: view.rightAnchor).isActive = true
//        
//        tableView.register(UITableViewCell.self, forCellReuseIdentifier: seperatorCellID)
//    }
    
    
    
    func setupAddTaskPageHeader() -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
//        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 128)
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height/7+10)
//        view.backgroundColor = secondryColor
        view.backgroundColor = .green
        
        //            let homeTitle = UILabel()
        //            homeTitle.frame = CGRect(x: (view.frame.minX+view.frame.maxX/5)+3, y: view.frame.maxY-60, width: view.frame.width/2+view.frame.width/8, height: 64)
        //            homeTitle.text = "Today's score is "
        //            homeTitle.textColor = primaryColor
        //            homeTitle.textAlignment = .left
        //            homeTitle.font = UIFont(name: "HelveticaNeue-Medium", size: 30)
        //            view.addSubview(homeTitle)
        
        return view
    }
    
    
    
}


    
    
    


