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
    
    
    //MARK: Positioning
    var textBoxEndY:CGFloat = UIScreen.main.bounds.minY+UIScreen.main.bounds.maxY/4
    var topHeaderEndY:CGFloat = UIScreen.main.bounds.minY+UIScreen.main.bounds.maxY/4
    var standardHeight: CGFloat = UIScreen.main.bounds.maxY/6
    
    
    let seperatorCellID = "seperator"
    // MARK:- Outlets
    
    @IBOutlet weak var weeklyTableView: UITableView!
    
    @IBOutlet weak var addTaskTextField: UITextField!
    @IBOutlet weak var addTaskButton: UIButton!
    
    @IBAction func addTaskButtonAction(_ sender: Any) {
    }
    
    
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
        
        setupAddTaskTextField(textFeild: addTaskTextField)
        setupAddTaskButtonDone(addTaskButtonDone: addTaskButton)
//        view.bringSubviewToFront(<#T##view: UIView##UIView#>)
        
        view.addSubview(setupFirstSeperator())
        
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if (indexPath.row == 0) {
            return standardHeight/2
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
    
    // MARK: MAKE Seperator
    
    func setupFirstSeperator() -> UIView {
        let mview = UIView()
        let seperatorImage = UIImageView()
        
        mview.frame = CGRect(x: 0, y: standardHeight+standardHeight/2, width: UIScreen.main.bounds.width, height: standardHeight/2)
        
        mview.backgroundColor = .brown
       
        seperatorImage.frame = CGRect(x: 0, y: mview.bounds.minY, width: mview.bounds.width, height: mview.bounds.height)
        seperatorImage.backgroundColor = .black
        mview.addSubview(seperatorImage)
        
        super.view.sendSubviewToBack(mview)
        
        
//        CGRect(x: 0, y: standardHeight, width: UIScreen.main.bounds.width, height: standardHeight/2)
        
        return mview
    }
    
    
    // MARK: MAKE AddTask Button
    
    func setupAddTaskButtonDone(addTaskButtonDone: UIButton) {

        let doneButtonHeightWidth: CGFloat = 50
        let doneButtonY = (standardHeight+standardHeight/2)-(doneButtonHeightWidth/2)
        
        print("Placing done button at: \(doneButtonY)")
        addTaskButtonDone.frame = CGRect(x: UIScreen.main.bounds.maxX-UIScreen.main.bounds.maxX/5, y: doneButtonY, width: doneButtonHeightWidth, height: doneButtonHeightWidth)
        
        //        addTaskButton.titleLabel?.text = "+"
        addTaskButtonDone.titleLabel?.textColor = primaryColor
        addTaskButtonDone.titleLabel?.textAlignment = .center
        addTaskButtonDone.titleLabel?.numberOfLines = 0
//        addTaskButtonDone.backgroundColor = secondryColor
        addTaskButtonDone.backgroundColor = .red
        addTaskButtonDone.layer.cornerRadius = addTaskButtonDone.bounds.size.width/2;
        addTaskButtonDone.layer.masksToBounds = true
        
        super.view.bringSubviewToFront(addTaskButtonDone)
        
        
        //                return addTaskButton
    }
    
    // MARK: MAKE AddTask TextFeild
    
    func setupAddTaskTextField(textFeild: UITextField) {
        
        textFeild.frame = CGRect(x: 0, y: standardHeight, width: UIScreen.main.bounds.width, height: standardHeight/2)
        let placeholderString =
            NSAttributedString.init(string: "Type in & tap done", attributes: [NSAttributedString.Key.foregroundColor : primaryColor])
        textFeild.attributedPlaceholder = placeholderString
        textFeild.backgroundColor = UIColor.blue
        let clearAddTaskTextFieldButton = UIButton(type: .custom)
        let roundedImage =  UIImage( named: "icon_close" )!.rounded!
        clearAddTaskTextFieldButton.setImage(roundedImage, for: UIControl.State.normal)
        textFeild.rightView = clearAddTaskTextFieldButton
        textFeild.rightViewMode = .whileEditing
        clearAddTaskTextFieldButton.addTarget(self, action: #selector(clearButtonAction), for: .touchUpInside)
        clearAddTaskTextFieldButton.tag = 1
        
        textBoxEndY = textFeild.bounds.height
//        textBoxEndY = textFeild.bounds.maxY-textFeild.bounds.height
        print("-------------------------------------------")
        print("textFeild maxY: \(textFeild.bounds.maxY)")
        print("textFeild MID: \(textFeild.bounds.midY)")
        print("textFeild MIN: \(textFeild.bounds.minY)")
        print("textFeild MAX + HEIGHT: \(textFeild.bounds.maxY-textFeild.bounds.height)")
        print("textFeild HEIGHT: \(textFeild.bounds.height)")
        print("-------------------------------------------")
    }
    
    /*
     Clears add task text feild on tapping the X button to the right
     */
    @objc func clearButtonAction(sender: UIButton!) {
        let buttonSenderTag = sender.tag
        if(buttonSenderTag == 1) {
            addTaskTextField.text = ""
        }
    }
    
    
    // MARK: MAKE TopHeader
    
    func setupAddTaskPageHeader() -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        //        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 128)
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: standardHeight)
        //        view.backgroundColor = secondryColor
        view.backgroundColor = .green
        
        //            let homeTitle = UILabel()
        //            homeTitle.frame = CGRect(x: (view.frame.minX+view.frame.maxX/5)+3, y: view.frame.maxY-60, width: view.frame.width/2+view.frame.width/8, height: 64)
        //            homeTitle.text = "Today's score is "
        //            homeTitle.textColor = primaryColor
        //            homeTitle.textAlignment = .left
        //            homeTitle.font = UIFont(name: "HelveticaNeue-Medium", size: 30)
        //            view.addSubview(homeTitle)
        
        topHeaderEndY = view.bounds.height
        print("-------------------------------------------")
        print("topHeader maxY: \(view.bounds.maxY)")
               print("topHeader MID: \(view.bounds.midY)")
               print("topHeader MIN: \(view.bounds.minY)")
               print("topHeader MAX + HEIGHT: \(view.bounds.maxY-view.bounds.height)")
        print("topHeader HEIGHT: \(view.bounds.height)")
        
        print("-------------------------------------------")
        return view
    }
    
    
    
}

extension UIImage
{
    /// Return a version of this image cropped to a circle.
    /// Assumes image is a square to start with
    var rounded:UIImage? {
        UIGraphicsBeginImageContext(size)
        UIBezierPath( ovalIn: CGRect( origin: .zero, size: size )).addClip()
        self.draw(at: .zero)
        return UIGraphicsGetImageFromCurrentImageContext()
    }
}






