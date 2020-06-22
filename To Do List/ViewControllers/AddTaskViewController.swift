//
//  AddTaskViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 04/06/20.
//  Copyright © 2020 saransh1337. All rights reserved.
//

import UIKit
import CoreData
import FSCalendar
import FluentUI
import MaterialComponents.MaterialTextControls_FilledTextAreas
import MaterialComponents.MaterialTextControls_FilledTextFields
import MaterialComponents.MaterialTextControls_OutlinedTextAreas
import MaterialComponents.MaterialTextControls_OutlinedTextFields

class AddTaskViewController: UIViewController, UITextFieldDelegate {
    
    
    
    
    
    //MARK:- Backdrop & Fordrop parent containers
    var backdropContainer = UIView()
    var foredropContainer = UIView()
    var bottomBarContainer = UIView()
    
    
    // MARK: TASK METADATA
    var currentTaskInMaterialTextBox: String = ""
    var isThisEveningTask: Bool = false
    var taskDayFromPicker: String =  "Unknown"//change datatype tp task type
    var currentTaskPriority: Int = 3
    
    //MARK:- Positioning
    var headerEndY: CGFloat = 128
    
    var seperatorTopLineView = UIView()
    var backdropNochImageView = UIImageView()
    var backdropBackgroundImageView = UIImageView()
    var backdropForeImageView = UIImageView()
    let backdropForeImage = UIImage(named: "backdropFrontImage")
    var homeTopBar = UIView()
    let dateAtHomeLabel = UILabel()
    let scoreCounter = UILabel()
    let scoreAtHomeLabel = UILabel()
    let cancelButton = UIView()
    let eveningSwitch = UISwitch()
    var prioritySC =  UISegmentedControl()
    
    let switchSetContainer = UIView()
    let switchBackground = UIView()
    let eveningLabel = UILabel()
    
    var addTaskTextBox_Material = MDCFilledTextField()
    let fab_cancelTask = MDCFloatingButton(shape: .mini)
    let fab_doneTask = MDCFloatingButton(shape: .default)
    
    var todoColors = ToDoColors()
    var todoFont = ToDoFont()
    var todoTimeUtils = ToDoTimeUtils()
    
    let homeDate_Day = UILabel()
    let homeDate_WeekDay = UILabel()
    let homeDate_Month = UILabel()
    
    let existingProjectCellID = "existingProject"
    let newProjectCellID = "newProject"
    
//    var controlLabels = [SegmentedControl: Label]() {
//         didSet {
//             controlLabels.forEach { updateLabel(forControl: $0.key) }
//         }
//     }

    
    //MARK:- Buttons + Views + Bottom bar
    var calendar: FSCalendar!
    //    let fab_revealCalAtHome = MDCFloatingButton(shape: .mini)
    //    let revealCalAtHomeButton = MDCButton()
    //    let revealChartsAtHomeButton = MDCButton()
    
    //MARK:- cuurentt task list date
    var dateForAddTaskView = Date.today()
    
    var items: [PillButtonBarItem] = [PillButtonBarItem(title: "Add Project +"),
                                      PillButtonBarItem(title: "Inbox"),
                                      PillButtonBarItem(title: "People"),
                                      PillButtonBarItem(title: "Other"),
                                      PillButtonBarItem(title: "Templates"),
                                      PillButtonBarItem(title: "Actions"),
                                      PillButtonBarItem(title: "More")]
    
    
    
    var filledBar: UIView?
    
    
 
    
    //    let collectionView: UICollectionView = {
    //        let layout = UICollectionViewFlowLayout()
    //        layout.scrollDirection = .horizontal
    //        layout.minimumLineSpacing = 5
    //        layout.sectionInset.top = 10
    //        layout.sectionInset.bottom = 10
    //
    //        let cv = UICollectionView(frame: CGRect(x: 0, y: 100, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width/3), collectionViewLayout: layout)
    //        cv.translatesAutoresizingMaskIntoConstraints = false
    //        cv.backgroundColor = .clear
    //        cv.register(ProjectCell.self, forCellWithReuseIdentifier: "existingProject")
    //        cv.register(AddNewProjectCell.self, forCellWithReuseIdentifier: "newProject")
    //        return cv
    //    }()
    //
    //    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
    //        return 16
    //    }
    //
    //    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
    //        //        let existingProjectCell = collectionView.dequeueReusableCell(withReuseIdentifier: existingProjectCellID, for: indexPath) as! ProjectCell
    //        //        let newProjectCell = collectionView.dequeueReusableCell(withReuseIdentifier: newProjectCellID, for: indexPath) as! AddNewProjectCell
    //
    //        //        print("Index cell is: \(indexPath.row)")
    //
    //        switch indexPath.row {
    //        case 0:
    //            let newProjectCell = collectionView.dequeueReusableCell(withReuseIdentifier: newProjectCellID, for: indexPath) as! AddNewProjectCell
    //            return newProjectCell
    //        default:
    //            let existingProjectCell = collectionView.dequeueReusableCell(withReuseIdentifier: existingProjectCellID, for: indexPath) as! ProjectCell
    //            return existingProjectCell
    //        }
    //
    //
    //        //        return existingProjectCell
    //    }
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
    
        
        
        
        
        
        view.addSubview(backdropContainer)
        setupBackdrop()
        
        view.addSubview(foredropContainer)
        setupFordrop()
        
        
//        view.bringSubviewToFront(filledBar)
        
        
        
        
        // Do any additional setup after loading the view.
    }
    
    // MARK:- Build Page Header
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    
    /*
     // MARK: - Navigation
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
     // Get the new view controller using segue.destination.
     // Pass the selected object to the new view controller.
     }
     */
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let oldText = textField.text!
        print("old text is: \(oldText)")
        let stringRange = Range(range, in:oldText)!
        let newText = oldText.replacingCharacters(in: stringRange, with: string)
        print("new text is: \(newText)")
        
        currentTaskInMaterialTextBox = newText
        
        if newText.isEmpty {
            print("EMPTY")
            fab_doneTask.isEnabled = false
        } else {
            print("NOT EMPTY")
            fab_doneTask.isEnabled = true
            
        }
        return true
    }
    
}

// MARK: - PillButtonBarDemoController: PillButtonBarDelegate

extension AddTaskViewController: PillButtonBarDelegate {
    func pillBar(_ pillBar: PillButtonBar, didSelectItem item: PillButtonBarItem, atIndex index: Int) {
        let alert = UIAlertController(title: "Item \(item.title) was selected", message: nil, preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alert.addAction(action)
        present(alert, animated: true)
    }
}

class ProjectCell: UICollectionViewCell {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    func setup() {
        self.backgroundColor = .red
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("FATAL Error on my collectionview")
    }
}

class AddNewProjectCell: UICollectionViewCell {
    
    var todoFont = ToDoFont()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    
    
    func setup() {
        self.backgroundColor = .blue
        
        self.addSubview(addProjectImageView)
        self.addSubview(addProjectLabel)
        
        addProjectImageView.anchor(top: topAnchor, left: leftAnchor, bottom: nil, right: rightAnchor, paddingTop: 0, paddingLeft: 5, paddingBottom: 5, paddingRight: 5, width: 0, height: 30)
        
        addProjectLabel.anchor(top: nil, left: leftAnchor, bottom: bottomAnchor, right: rightAnchor, paddingTop: 5, paddingLeft: 5, paddingBottom: 0, paddingRight: 5, width: 0, height: 20)
    }
    
    let addProjectImageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFit
        iv.backgroundColor = .green
        iv.image = #imageLiteral(resourceName: "material_add_White")
        return iv
    }()
    
    let addProjectLabel: UILabel = {
        let label = UILabel()
        label.text = "Add \nProject"
        label.textColor = .label
        label.font = UIFont.boldSystemFont(ofSize: 16)
        label.textAlignment = .center
        return label
    }()
    
    required init?(coder: NSCoder) {
        fatalError("FATAL Error on my collectionview")
    }
}

extension UIView {
    func anchor(
        top: NSLayoutYAxisAnchor?,
        left: NSLayoutXAxisAnchor?,
        bottom: NSLayoutYAxisAnchor?,
        right: NSLayoutXAxisAnchor?,
        paddingTop: CGFloat, paddingLeft: CGFloat,
        paddingBottom: CGFloat,
        paddingRight: CGFloat,
        width: CGFloat = 0,
        height: CGFloat = 0) {
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        if let top = top {
            self.topAnchor.constraint(equalTo: top, constant: paddingTop).isActive = true
        }
        
        if let left = left {
            self.leftAnchor.constraint(equalTo: left, constant: paddingLeft).isActive = true
        }
        
        if let bottom = bottom {
            self.bottomAnchor.constraint(equalTo: bottom, constant: paddingBottom).isActive = true
        }
        
        if let right = right {
            self.rightAnchor.constraint(equalTo: right, constant: -paddingRight).isActive = true
        }
        
        if width != 0 {
            self.widthAnchor.constraint(equalToConstant: width).isActive = true
        }
        
        if height != 0 {
            self.heightAnchor.constraint(equalToConstant: height).isActive = true
        }
    }
    
    var safeTopAnchor: NSLayoutYAxisAnchor {
        if #available(iOS 11.0, *) {
            return safeAreaLayoutGuide.topAnchor
        }
        return topAnchor
    }
    
    var safeLeftAnchor: NSLayoutXAxisAnchor {
        if #available(iOS 11.0, *) {
            return safeAreaLayoutGuide.leftAnchor
        }
        return leftAnchor
    }
    
    var safeBottomAnchor: NSLayoutYAxisAnchor {
        if #available(iOS 11.0, *) {
            return safeAreaLayoutGuide.bottomAnchor
        }
        return bottomAnchor
    }
    
    var safeRightAnchor: NSLayoutXAxisAnchor {
        if #available(iOS 11.0, *) {
            return safeAreaLayoutGuide.rightAnchor
        }
        return rightAnchor
    }
    
}
