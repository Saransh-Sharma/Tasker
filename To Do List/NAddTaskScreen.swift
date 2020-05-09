//
//  NAddTaskScreen.swift
//  To Do List
//
//  Created by Saransh Sharma on 07/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import CircleMenu

class NAddTaskScreen: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, CircleMenuDelegate
{
    
    
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return dataArray.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        let row = dataArray[row]
        return row
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        
        taskDayFromPicker = dataArray[row]
        
    }
    
    
    let dataArray = ["Set Date", "Today", "Tomorrow", "Weekend", "Next Week"]
    var primaryColor =  #colorLiteral(red: 0.6941176471, green: 0.9294117647, blue: 0.9098039216, alpha: 1)
    var secondryColor =  #colorLiteral(red: 0.2039215686, green: 0, blue: 0.4078431373, alpha: 1)
    
    
    //MARK: Positioning
    var textBoxEndY:CGFloat = UIScreen.main.bounds.minY+UIScreen.main.bounds.maxY/4
    var topHeaderEndY:CGFloat = UIScreen.main.bounds.minY+UIScreen.main.bounds.maxY/4
    //    var standardHeight: CGFloat = UIScreen.main.bounds.maxY/6
    var standardHeight: CGFloat = UIScreen.main.bounds.maxY/10
    let menuEndPointX: CGFloat = 32+50
    let menuEndPoinY: CGFloat = 64
    let notchOffSet: CGFloat = 30
    
    //picker
    let UIPicker: UIPickerView = UIPickerView()
    var taskDayFromPicker: String =  "Today"//change datatype tp task type
    
    
    
    
    let seperatorCellID = "seperator" // TODO: remove
    // MARK:- Outlets
    
    @IBOutlet weak var addTaskTextField: UITextField!
    @IBOutlet weak var addTaskButton: UIButton!
    
    @IBAction func addTaskButtonAction(_ sender: Any) {
    }
    
    
    //    override func loadView() {
    //        super.loadView()
    ////        view.addSubview(servePageHeader())
    ////        setupTableView()
    //    }
    
    
 
    
    // MARK:- VIEW DID LOAD
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // MARK: CIRCLE MENU POSITIONNINNG
         
           let circleMenuRadius:CGFloat = 30
                 let circleMenuOuterRadius:Float = 50
                 let circleMenuStartX:CGFloat = 32
         //        let circleMenuStartY:CGFloat = 2*circleMenuStart
                 let circleMenuStartY:CGFloat = 40
        
         
         // MARK: Add Task Title

         let addTaskTTitlePositionStartX:CGFloat = circleMenuStartX+50
        let addTaskTTitlePositionStartY:CGFloat = circleMenuStartY-10
        let titleFontSize:CGFloat = 30
        
        
        
        
        
        
        
        
        view.addSubview(setupAddTaskPageHeader(titleStartX: addTaskTTitlePositionStartX, titleStartY: addTaskTTitlePositionStartY, titleFontSize: titleFontSize))
        
      
        
        
        // Original points
//        let circleMenuRadius:CGFloat = 30
//               let circleMenuOuterRadius:Float = 50
//               let circleMenuStartX:CGFloat = 32
//               let circleMenuStartY:CGFloat = 2*circleMenuStartX
        
        
        //        frame: CGRect(x: 32, y: 64, width: 30, height: 30),
        //MARK: circle menu frame
        let circleMenuButton = CircleMenu(
            frame: CGRect(x: circleMenuStartX, y: circleMenuStartY, width: circleMenuRadius, height: circleMenuRadius),
            normalIcon:"icon_menu",
            selectedIcon:"icon_close",
            buttonsCount: 5, // 2 hidden
            duration: 1,
            distance: circleMenuOuterRadius)
        circleMenuButton.backgroundColor = primaryColor
        circleMenuButton.delegate = self
        circleMenuButton.layer.cornerRadius = circleMenuButton.frame.size.width / 2.0
        view.addSubview(circleMenuButton)
        
        
        view.addSubview(setupFirstSeperator())
        setupAddTaskTextField(textFeild: addTaskTextField)
        setupAddTaskButtonDone(addTaskButtonDone: addTaskButton)
        view.addSubview(setupEveningTaskSwitch())
        view.addSubview(setupSecondSeperator())
        view.addSubview(setupPrioritySC())
        
        
        UIPicker.delegate = self as UIPickerViewDelegate
        UIPicker.dataSource = self as UIPickerViewDataSource
        UIPicker.center = self.view.center
        
        view.addSubview(setupDayPicker(picker: UIPicker))
        view.addSubview(setupFinalFiller())
        
        
        
        
        
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        
        if (indexPath.row == 0) {
            return standardHeight/2
        }
        return UITableView.automaticDimension
    }
    
    // MARK: MAKE final filler
    func setupFinalFiller() -> UIView {
        
        let mView = UIView()
        let diff = UIScreen.main.bounds.height-(standardHeight+standardHeight+standardHeight+standardHeight+standardHeight)
        mView.frame = CGRect(x: 0, y: standardHeight+standardHeight+standardHeight+standardHeight+standardHeight, width: UIScreen.main.bounds.width, height: diff)
        mView.backgroundColor = primaryColor
        return mView
    }
    
    
    // MARK: MAKE Day Picker
    
    func setupDayPicker(picker: UIPickerView) -> UIView {
        
        let mView = UIView()
        mView.frame = CGRect(x: 0, y: standardHeight+standardHeight+standardHeight+standardHeight, width: UIScreen.main.bounds.width, height: standardHeight)
        //        mView.backgroundColor = primaryColor
        mView.backgroundColor = .green
        
        picker.frame = CGRect(x: 0, y: mView.bounds.minY, width: mView.bounds.width, height: mView.bounds.height)
        
        picker.selectRow(1, inComponent: 0, animated: true)
        
        //        picker.didselect
        //        picker.setva
        
        mView.addSubview(picker)
        
        return mView
    }
    
    
    // MARK: MAKE Priority SC
    
    func setupPrioritySC() -> UIView {
        
        let mView = UIView()
        let p = ["None", "Low", "High", "Highest"]
        let prioritySC = UISegmentedControl(items: p)
        
        //this is twice as wide so it also has the 3rd seperator built in
        mView.frame = CGRect(x: 0, y: standardHeight+standardHeight+standardHeight+standardHeight/2, width: UIScreen.main.bounds.width, height: standardHeight/2)
        
        //        mView.backgroundColor = primaryColor
        mView.backgroundColor = .blue
        
        
        prioritySC.frame = CGRect(x: 0, y: mView.bounds.minY, width: mView.bounds.width, height: mView.bounds.height)
        
        
        //Task Priority
        
        prioritySC.selectedSegmentIndex = 1
        prioritySC.backgroundColor = .white
        prioritySC.selectedSegmentTintColor =  secondryColor
        prioritySC.setTitleTextAttributes([NSAttributedString.Key.foregroundColor: UIColor.white], for: UIControl.State.selected)
        mView.addSubview(prioritySC)
        
        
        
        
        
        
        
        
        return mView
        
    }
    
    // MARK: MAKE Second Seperator
    
    func setupSecondSeperator() -> UIView {
        let mview = UIView()
        let seperatorImage = UIImageView()
        
        mview.frame = CGRect(x: 0, y: standardHeight+standardHeight+standardHeight/2, width: UIScreen.main.bounds.width, height: standardHeight/2)
        
        
        
        seperatorImage.frame = CGRect(x: 0, y: mview.bounds.minY, width: mview.bounds.width, height: mview.bounds.height)
        seperatorImage.backgroundColor = .brown
        //        seperatorImage.backgroundColor = primaryColor
        mview.addSubview(seperatorImage)
        
        super.view.sendSubviewToBack(mview)
        
        
        //        CGRect(x: 0, y: standardHeight, width: UIScreen.main.bounds.width, height: standardHeight/2)
        
        return mview
    }
    
    // MARK: MAKE Eveninng Switch
    
    func setupEveningTaskSwitch() -> UIView {
        let mView = UIView()
        let switchBackground = UIImageView()
        let eveningLabel = UILabel()
        let eveningSwitch = UISwitch()
        
        mView.frame = CGRect(x: 0, y: standardHeight+standardHeight, width: UIScreen.main.bounds.width, height: standardHeight/2)
        
        switchBackground.frame = CGRect(x: 0, y: mView.bounds.minY, width: mView.bounds.width, height: mView.bounds.height)
        switchBackground.backgroundColor = .darkGray
        //        switchBackground.backgroundColor = secondryColor
        mView.addSubview(switchBackground)
        
        eveningLabel.frame = CGRect(x: 10, y: 0, width: UIScreen.main.bounds.width/2, height: mView.bounds.maxY)
        eveningLabel.text = "evening task"
        eveningLabel.adjustsFontSizeToFitWidth = true
        eveningLabel.font = eveningLabel.font.withSize(mView.bounds.height/3)
        eveningLabel.textColor = primaryColor
        mView.addSubview(eveningLabel)
        
        //        eveningSwitch.frame = CGRect(x: UIScreen.main.bounds.maxX-60, y: mView.bounds.midY-mView.bounds.midY/2, width: UIScreen.main.bounds.width/4, height: mView.bounds.height)
        
        eveningSwitch.frame = CGRect(x: UIScreen.main.bounds.maxX-70, y: mView.bounds.midY-mView.bounds.midY/2, width: UIScreen.main.bounds.width/4, height: mView.bounds.height)
        
        mView.addSubview(eveningSwitch)
        
        return mView
    }
    
    // MARK: MAKE First Seperator
    
    func setupFirstSeperator() -> UIView {
        let mview = UIView()
        let seperatorImage = UIImageView()
        
        mview.frame = CGRect(x: 0, y: standardHeight+standardHeight/2, width: UIScreen.main.bounds.width, height: standardHeight/2)
        
        
        
        seperatorImage.frame = CGRect(x: 0, y: mview.bounds.minY, width: mview.bounds.width, height: mview.bounds.height)
        //        seperatorImage.backgroundColor = .black
        seperatorImage.backgroundColor = primaryColor
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
        
        
        addTaskButtonDone.titleLabel?.textColor = primaryColor
        addTaskButtonDone.titleLabel?.textAlignment = .center
        addTaskButtonDone.titleLabel?.numberOfLines = 0
        //        addTaskButtonDone.backgroundColor = secondryColor
        //        addTaskButtonDone.backgroundColor = .red
        addTaskButtonDone.backgroundColor = .red
        addTaskButtonDone.layer.cornerRadius = addTaskButtonDone.bounds.size.width/2;
        addTaskButtonDone.layer.masksToBounds = true
        
        
        super.view.bringSubviewToFront(addTaskButtonDone)
        
    }
    
    // MARK: MAKE AddTask TextFeild
    
    func setupAddTaskTextField(textFeild: UITextField) {
        
        //        let mView = UIView()
        
        textFeild.frame = CGRect(x: 0, y: standardHeight, width: UIScreen.main.bounds.width, height: standardHeight/2)
        let placeholderString =
            NSAttributedString.init(string: "Type in & tap done", attributes: [NSAttributedString.Key.foregroundColor : primaryColor])
        textFeild.attributedPlaceholder = placeholderString
        //        textFeild.backgroundColor = UIColor.blue
        textFeild.backgroundColor = secondryColor
        let clearAddTaskTextFieldButton = UIButton(type: .custom)
        let roundedImage =  UIImage( named: "icon_close" )!.rounded!
        clearAddTaskTextFieldButton.setImage(roundedImage, for: UIControl.State.normal)
        textFeild.rightView = clearAddTaskTextFieldButton
        textFeild.rightViewMode = .whileEditing
        clearAddTaskTextFieldButton.addTarget(self, action: #selector(clearButtonAction), for: .touchUpInside)
        clearAddTaskTextFieldButton.tag = 1
        
        textBoxEndY = textFeild.bounds.height
        
        
        //        textFeild
        
        
        
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
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func setupAddTaskPageHeader(titleStartX: CGFloat, titleStartY: CGFloat, titleFontSize: CGFloat) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        
        let title = UILabel()
        
        //        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: standardHeight+notchOffSet)
  
        //        view.backgroundColor = secondryColor
        view.backgroundColor = .darkGray
        
        //        title.font.withSize(110)
       
        
              
//        title.frame = CGRect(x: titleStartX, y: titleStartY, width: UIScreen.main.bounds.width/3+UIScreen.main.bounds.width/3, height: standardHeight/2)
        
         title.frame = CGRect(x: titleStartX, y: titleStartY, width: UIScreen.main.bounds.width, height: standardHeight/2)
        
        title.text = "Add Task"
        title.font = UIFont(name: "HelveticaNeue-Medium", size: titleFontSize)
        //        title.font = UIFont(name: "Zapfino", size: 30)!
        //        title.font = UIFont(name: "Thonburi-Bold", size: 20)!
        title.backgroundColor = .clear
        title.textColor = .green
        title.adjustsFontSizeToFitWidth = true
        view.addSubview(title)
        //        view.bringSubviewToFront(title)
        
        
        
        
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
    
    
    // MARK:- CircleMenuDelegate
    
    func circleMenu(_: CircleMenu, willDisplay button: UIButton, atIndex: Int) {
        button.backgroundColor = items[atIndex].color
        
        button.setImage(UIImage(named: items[atIndex].icon), for: .normal)
        
        // set highlited image
        let highlightedImage = UIImage(named: items[atIndex].icon)?.withRenderingMode(.alwaysTemplate)
        button.setImage(highlightedImage, for: .highlighted)
        
        
        button.tintColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.3)
    }
    
    func circleMenu(_: CircleMenu, buttonWillSelected _: UIButton, atIndex: Int) {
        print("button will selected: \(atIndex)")
        if (atIndex == 3) { //Opens settings menu
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { //adds delay
                // your code here
                let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                let newViewController = storyBoard.instantiateViewController(withIdentifier: "settingsPage")
                self.present(newViewController, animated: true, completion: nil)
            }
            
            
        }
    }
    
    let colors = [UIColor.red, UIColor.gray, UIColor.green, UIColor.purple]
    let items: [(icon: String, color: UIColor)] = [
        //        ("icon_home", UIColor(red: 0.19, green: 0.57, blue: 1, alpha: 1)),
        ("", .clear),
        ("icon_search", UIColor(red: 0.22, green: 0.74, blue: 0, alpha: 1)),
        ("notifications-btn", UIColor(red: 0.96, green: 0.23, blue: 0.21, alpha: 1)),
        ("settings-btn", UIColor(red: 0.51, green: 0.15, blue: 1, alpha: 1)),
        //        ("nearby-btn", UIColor(red: 1, green: 0.39, blue: 0, alpha: 1))
        ("", .clear)
    ]
    
    
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






