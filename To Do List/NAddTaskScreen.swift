//
//  NAddTaskScreen.swift
//  To Do List
//
//  Created by Saransh Sharma on 07/05/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import CoreData
import CircleMenu
import MaterialComponents.MaterialTextControls_FilledTextAreas
import MaterialComponents.MaterialTextControls_FilledTextFields
import MaterialComponents.MaterialTextControls_OutlinedTextAreas
import MaterialComponents.MaterialTextControls_OutlinedTextFields

class NAddTaskScreen: UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, CircleMenuDelegate
{
    // MARK: Theming
    var primaryColor =  #colorLiteral(red: 0.6941176471, green: 0.9294117647, blue: 0.9098039216, alpha: 1)
    var secondryColor =  #colorLiteral(red: 0.2039215686, green: 0, blue: 0.4078431373, alpha: 1)
    
    // MARK:- DAY Picker Delegate Methods
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
        
        print("DAY: \(dataArray[row])")
        print("DAY ROW: \(row)")
        taskDayFromPicker = dataArray[row]
        
    }
    
    
    let dataArray = ["Set Date", "Today", "Tomorrow", "Weekend", "Next Week"]
    
    
    // MARK: TASK METADATA
    var isThisEveningTask: Bool = false
    var taskDayFromPicker: String =  "Today"//change datatype tp task type
    
    
    //MARK: Positioning
    var textBoxEndY:CGFloat = UIScreen.main.bounds.minY+UIScreen.main.bounds.maxY/4
    var topHeaderEndY:CGFloat = UIScreen.main.bounds.minY+UIScreen.main.bounds.maxY/4
    var standardHeight: CGFloat = UIScreen.main.bounds.maxY/10
    let menuEndPointX: CGFloat = 32+50
    let menuEndPoinY: CGFloat = 64
    let notchOffSet: CGFloat = 30
    
    // MARK: CIRCLE MENU POSITIONING
    let circleMenuRadius:CGFloat = 30
    let circleMenuOuterRadius:Float = 50
    let circleMenuStartX:CGFloat = 32
    let circleMenuStartY:CGFloat = 40
    
    // MARK: picker + switch init + cancel task
    let UIPicker: UIPickerView = UIPickerView()
    let eveningSwitch = UISwitch()
    
    let fab_cancelTask = MDCFloatingButton(shape: .mini)
    let fab_doneTask = MDCFloatingButton(shape: .default)
    
    
    
    
    let seperatorCellID = "seperator" // TODO: remove
    
    
    
    // MARK:- Outlets
    
    @IBOutlet weak var addTaskTextField: UITextField!
    @IBOutlet weak var addTaskButton: UIButton!
    @IBOutlet weak var cancelAddTaskButton: UIButton!
    @IBAction func addTaskButtonAction(_ sender: Any) {
    }
    
    
    //MARK: DONE BUTTON Tapped
    @IBAction func doneButtonTappedAction(_ sender: UIButton) {
        isThisEveningTask = isEveningSwitchOn(sender: eveningSwitch)
        if addTaskTextField.text != nil && addTaskTextField.text != "" {
            
            TaskManager.sharedInstance.addNewTask(name: addTaskTextField.text!, taskType: getTaskType(), taskPriority: 2)
        }
        
        dismiss(animated: true)
    }
    
    // MARK:- VIEW DID LOAD
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // MARK: Add Task Title (not being used)
        let addTaskTTitlePositionStartX:CGFloat = circleMenuStartX+50
        let addTaskTTitlePositionStartY:CGFloat = circleMenuStartY-10
        let titleFontSize:CGFloat = 30
        
        view.addSubview(setupAddTaskPageHeader(titleStartX: addTaskTTitlePositionStartX, titleStartY: addTaskTTitlePositionStartY, titleFontSize: titleFontSize))
        
        
//        let circleMenuButton = CircleMenu(
//                   frame: CGRect(x: circleMenuStartX, y: circleMenuStartY, width: circleMenuRadius, height: circleMenuRadius),
        //MARK: circle menu frame
        let circleMenuButton = CircleMenu(
            frame: CGRect(x: 10, y: circleMenuStartY, width: 38, height: 38),
            normalIcon:"icon_menu",
            selectedIcon:"material_close",
            buttonsCount: 5, // 2 hidden
            duration: 1,
            distance: circleMenuOuterRadius)
        
        circleMenuButton.backgroundColor = primaryColor
        circleMenuButton.delegate = self
        circleMenuButton.layer.cornerRadius = circleMenuButton.frame.size.width / 2.0
        view.addSubview(circleMenuButton)
        
        
        
        
        //---Floating Action Button MATERIAL CANCEL TASK - Material
        
        
        let buttonB = MDCFloatingButton(shape: .default)
        //        buttonB
        let buttonc = MDCFloatingButton(shape: .mini)
        
        // fab_cancelTask.setMode(.normal, animated: true)
        fab_cancelTask.accessibilityLabel = "Cancel Task"
        fab_cancelTask.minimumSize = CGSize(width: 32, height: 24)
        let kMinimumAccessibleButtonSizeHeeight: CGFloat = 24
        let kMinimumAccessibleButtonSizeWidth:CGFloat = 32
        
        let buttonVerticalInset =
            min(0, -(kMinimumAccessibleButtonSizeHeeight - fab_cancelTask.bounds.height) / 2);
        let buttonHorizontalInset =
            min(0, -(kMinimumAccessibleButtonSizeWidth - fab_cancelTask.bounds.width) / 2);
        fab_cancelTask.hitAreaInsets =
            UIEdgeInsets(top: buttonVerticalInset, left: buttonHorizontalInset,
                         bottom: buttonVerticalInset, right: buttonHorizontalInset);
        
        
        //MARK: cancel button position
        
        fab_cancelTask.frame = CGRect(x: UIScreen.main.bounds.maxX-UIScreen.main.bounds.maxX/8, y: UIScreen.main.bounds.minY+40, width: 25, height: 25)
        
        let addTaskIcon = UIImage(named: "material_close")
        fab_cancelTask.setImage(addTaskIcon, for: .normal)
        fab_cancelTask.backgroundColor = primaryColor
        fab_cancelTask.sizeToFit()
        view.addSubview(fab_cancelTask)
        fab_cancelTask.addTarget(self, action: #selector(cancelAddTaskAction), for: .touchUpInside)
        
        
        //---Floating Action Button - Material - DONE
        
        
        // MARK:---Floating Action Button MATERIAL DONE TASK - Material
        
        let doneButtonHeightWidth: CGFloat = 50
//        let doneButtonY = 4*(standardHeight)+standardHeight/2-(doneButtonHeightWidth/2)
          let doneButtonY = 4*(standardHeight)+standardHeight-(doneButtonHeightWidth/2)
        print("Placing done button at: \(doneButtonY)")
        
        fab_doneTask.mode = .expanded
        fab_doneTask.setTitle("done", for: .normal)
        fab_doneTask.setTitle("nice !", for: .highlighted)
        fab_doneTask.titleLabel?.text = "Done"
        fab_doneTask.titleColor(for: .normal)
        fab_doneTask.frame = CGRect(x: UIScreen.main.bounds.maxX-2.5*doneButtonHeightWidth, y: doneButtonY, width: 2.5*doneButtonHeightWidth, height: doneButtonHeightWidth)
        let doneTaskIconNormalImage = UIImage(named: "material_done_White")
        fab_doneTask.setImage(doneTaskIconNormalImage, for: .normal)
        // material_evening_White
        if (isEveningSwitchOn(sender: eveningSwitch)) {
            let doneTaskIconNormalImage = UIImage(named: "material_evening_White")
            fab_doneTask.setImage(doneTaskIconNormalImage, for: .highlighted)
        } else {
            let doneTaskIconNormalImage = UIImage(named: "material_day_White")
            fab_doneTask.setImage(doneTaskIconNormalImage, for: .highlighted)
        }
        
        fab_doneTask.backgroundColor = secondryColor
        fab_doneTask.sizeToFit()
        view.addSubview(fab_doneTask)
        fab_doneTask.addTarget(self, action: #selector(doneAddTaskAction), for: .touchUpInside)
        
        
        
        
        
        
        
        
        // MARK: SETUP ALL VIEWS
        
        view.addSubview(setupFirstSeperator())
        view.addSubview(setupAddTaskTextField(textFeild: addTaskTextField))
       // _ = setupAddTaskButtonDone(addTaskButtonDone: addTaskButton)
        view.addSubview(setupEveningTaskSwitch())
        view.addSubview(setupSecondSeperator())
        view.addSubview(setupPrioritySC())
        
        
        UIPicker.delegate = self as UIPickerViewDelegate
        UIPicker.dataSource = self as UIPickerViewDataSource
        UIPicker.center = self.view.center
        
        view.addSubview(setupDayPicker(picker: UIPicker))
        view.addSubview(setupFinalFiller())
        
        view.bringSubviewToFront(circleMenuButton)
        view.bringSubviewToFront(addTaskButton)
        view.bringSubviewToFront(fab_cancelTask)
        view.bringSubviewToFront(fab_doneTask)
        
        addTaskTextField.font = UIFont(name: "HelveticaNeue-Medium", size: 40)
        addTaskTextField.textColor = primaryColor
        addTaskTextField.becomeFirstResponder()
        
    }
    
    //MARK:- DONE TASK ACTION
    
    @objc func doneAddTaskAction() {
        
        //       tap DONE --> add new task + nav homeScreen
        
        //MARK:- ADD TASK
        isThisEveningTask = isEveningSwitchOn(sender: eveningSwitch)
        if addTaskTextField.text != nil && addTaskTextField.text != "" {
            
            TaskManager.sharedInstance.addNewTask(name: addTaskTextField.text!, taskType: getTaskType(), taskPriority: 2)
        }
        
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let newViewController = storyBoard.instantiateViewController(withIdentifier: "homeScreen") as! ViewController
        newViewController.modalPresentationStyle = .fullScreen
        self.present(newViewController, animated: true, completion: nil)
        
        
        
        //                    dismiss(animated: true)
        
        
    }
    
    //MARK:- CALCEL TASK ACTION
    
    @objc func cancelAddTaskAction() {
        
        //       tap CANCEL --> homeScreen
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let newViewController = storyBoard.instantiateViewController(withIdentifier: "homeScreen") as! ViewController
        newViewController.modalPresentationStyle = .fullScreen
        self.present(newViewController, animated: true, completion: nil)
    }
    
    
    // MARK: MAKE final filler
    func setupFinalFiller() -> UIView {
        
        let mView = UIView()
        let diff = UIScreen.main.bounds.height-(standardHeight+standardHeight+standardHeight+standardHeight+standardHeight/2)
        mView.frame = CGRect(x: 0, y: standardHeight+standardHeight+standardHeight+standardHeight+standardHeight/2, width: UIScreen.main.bounds.width, height: diff)
        mView.backgroundColor = primaryColor
        return mView
    }
    
    
    // MARK: MAKE Day Picker
    
    func setupDayPicker(picker: UIPickerView) -> UIView {
        
        let mView = UIView()
        mView.frame = CGRect(x: 0, y: standardHeight+standardHeight+standardHeight+standardHeight/2, width: UIScreen.main.bounds.width, height: standardHeight)
        mView.backgroundColor = primaryColor
        picker.frame = CGRect(x: 0, y: mView.bounds.minY, width: mView.bounds.width, height: mView.bounds.height)
        picker.selectRow(1, inComponent: 0, animated: true)
        mView.addSubview(picker)
        return mView
    }
    
    
    // MARK: MAKE Priority SC
    
    func setupPrioritySC() -> UIView {
        
        let mView = UIView()
        let p = ["None", "Low", "High", "Highest"]
        let prioritySC = UISegmentedControl(items: p)
        
        mView.frame = CGRect(x: 0, y: standardHeight+standardHeight+standardHeight, width: UIScreen.main.bounds.width, height: standardHeight/2)
        
        mView.backgroundColor = primaryColor
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
        seperatorImage.backgroundColor = primaryColor
        mview.addSubview(seperatorImage)
        super.view.sendSubviewToBack(mview)
        return mview
    }
    
    // MARK: MAKE Evening Switch
    
    func setupEveningTaskSwitch() -> UIView {
        let mView = UIView()
        let switchBackground = UIImageView()
        let eveningLabel = UILabel()
        
        mView.frame = CGRect(x: 0, y: standardHeight+standardHeight, width: UIScreen.main.bounds.width, height: standardHeight/2)
        switchBackground.frame = CGRect(x: 0, y: mView.bounds.minY, width: mView.bounds.width, height: mView.bounds.height)
        switchBackground.backgroundColor = secondryColor
        mView.addSubview(switchBackground)
        
        eveningLabel.frame = CGRect(x: 10, y: 0, width: UIScreen.main.bounds.width/2, height: mView.bounds.maxY)
        eveningLabel.text = "evening task"
        eveningLabel.adjustsFontSizeToFitWidth = true
        eveningLabel.font = eveningLabel.font.withSize(mView.bounds.height/2)
        eveningLabel.textColor = primaryColor
        mView.addSubview(eveningLabel)
        
        eveningSwitch.frame = CGRect(x: UIScreen.main.bounds.maxX-70, y:mView.bounds.midY-((mView.bounds.midY/2)+5), width: UIScreen.main.bounds.width/4, height: mView.bounds.height-10)
        
        // Colors
        eveningSwitch.onTintColor = primaryColor
        eveningSwitch.addTarget(self, action: #selector(NAddTaskScreen.isEveningSwitchOn(sender:)), for: .valueChanged)
        mView.addSubview(eveningSwitch)
        
        return mView
    }
    
    
    @objc func isEveningSwitchOn(sender:UISwitch!) -> Bool {
        if (sender.isOn == true){
            print("SWITCH: on")
            return true
        }
        else{
            print("SWITCH: off")
            return false
        }
    }
    
    // MARK: MAKE First Seperator
    
    func setupFirstSeperator() -> UIView {
        let mview = UIView()
        let seperatorImage = UIImageView()
        
        mview.frame = CGRect(x: 0, y: standardHeight+standardHeight/2, width: UIScreen.main.bounds.width, height: standardHeight/2)
        seperatorImage.frame = CGRect(x: 0, y: mview.bounds.minY, width: mview.bounds.width, height: mview.bounds.height)
        seperatorImage.backgroundColor = primaryColor
        mview.addSubview(seperatorImage)
        super.view.sendSubviewToBack(mview)
        return mview
    }
    
    
    // MARK: OLD make AddTask Button - This is Hidden
    
    func setupAddTaskButtonDone(addTaskButtonDone: UIButton) -> UIView{
        
        let doneButtonHeightWidth: CGFloat = 50
        let doneButtonY = 4*(standardHeight)+standardHeight/2-(doneButtonHeightWidth/2)
        print("Placing done button at: \(doneButtonY)")
        
        addTaskButtonDone.frame = CGRect(x: UIScreen.main.bounds.maxX-UIScreen.main.bounds.maxX/5, y: doneButtonY, width: doneButtonHeightWidth, height: doneButtonHeightWidth)
        
        addTaskButtonDone.titleLabel?.textColor = primaryColor
        addTaskButtonDone.titleLabel?.textAlignment = .center
        addTaskButtonDone.titleLabel?.numberOfLines = 0
        addTaskButtonDone.backgroundColor = secondryColor
        addTaskButtonDone.layer.cornerRadius = addTaskButtonDone.bounds.size.width/2;
        addTaskButtonDone.layer.masksToBounds = true
        
        return addTaskButtonDone
    }
    
    // MARK: MAKE AddTask TextFeild
    
    func setupAddTaskTextField(textFeild: UITextField) -> UIView {
        
        let mView = UIView()
        mView.frame = CGRect(x: 0, y: standardHeight, width: UIScreen.main.bounds.width, height: standardHeight/2)
        mView.backgroundColor = secondryColor
        
        //        textFeild.frame = CGRect(x: circleMenuStartX+circleMenuRadius/2, y: 0, width: UIScreen.main.bounds.maxX-70, height: standardHeight/2)
        
        //--------MATERIAL TEXT FEILD
        let estimatedFrame = CGRect(x: circleMenuStartX+circleMenuRadius/2, y: 0, width: UIScreen.main.bounds.maxX-(10+70+circleMenuRadius/2), height: standardHeight/2)
        let textField = MDCFilledTextField(frame: estimatedFrame)
        textField.label.text = "add task & tap done"
        textField.clearButtonMode = .whileEditing
        textField.placeholder = "get coffee"
        textField.leadingAssistiveLabel.text = "This is helper text"
        textField.sizeToFit()
        mView.addSubview(textField)
        
        
        textBoxEndY = textFeild.bounds.height
        
        print("-------------------------------------------")
        print("textFeild maxY: \(textFeild.bounds.maxY)")
        print("textFeild MID: \(textFeild.bounds.midY)")
        print("textFeild MIN: \(textFeild.bounds.minY)")
        print("textFeild MAX + HEIGHT: \(textFeild.bounds.maxY-textFeild.bounds.height)")
        print("textFeild HEIGHT: \(textFeild.bounds.height)")
        print("-------------------------------------------")
        
        mView.addSubview(textFeild)
        mView.bringSubviewToFront(textFeild)
        return mView
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
        let view = UIView()
        view.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: standardHeight+standardHeight/2)
        let title = UILabel()
        view.backgroundColor = secondryColor
        title.frame = CGRect(x: titleStartX, y: titleStartY, width: UIScreen.main.bounds.width, height: standardHeight/2)
        title.font = UIFont(name: "HelveticaNeue-Medium", size: titleFontSize)
        title.backgroundColor = .clear
        title.textColor = primaryColor
        title.adjustsFontSizeToFitWidth = true
        view.addSubview(title)
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
    
    func getTaskType() -> Int { //extend this to return for inbox & upcoming/someday
        if eveningSwitch.isOn {
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






