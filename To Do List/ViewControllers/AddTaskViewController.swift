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
import MaterialComponents.MaterialTextControls_FilledTextAreas
import MaterialComponents.MaterialTextControls_FilledTextFields
import MaterialComponents.MaterialTextControls_OutlinedTextAreas
import MaterialComponents.MaterialTextControls_OutlinedTextFields

class AddTaskViewController: UIViewController, UITextFieldDelegate, UICollectionViewDataSource, UICollectionViewDelegate {

    
    
    
    
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
    
    let cellId = "cellId"
    
    //MARK:- Buttons + Views + Bottom bar
    var calendar: FSCalendar!
    //    let fab_revealCalAtHome = MDCFloatingButton(shape: .mini)
    //    let revealCalAtHomeButton = MDCButton()
    //    let revealChartsAtHomeButton = MDCButton()
    
    //MARK:- cuurentt task list date
    var dateForAddTaskView = Date.today()
    
    
    let collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 15
        layout.sectionInset.top = 20
        layout.sectionInset.bottom = 20

        let cv = UICollectionView(frame: CGRect(x: 0, y: 100, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.width/3), collectionViewLayout: layout)
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.backgroundColor = UIColor(named: "background")
        cv.register(TeamCell.self, forCellWithReuseIdentifier: "cellId")
        return cv
    }()
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 16
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: cellId, for: indexPath) as! TeamCell
        return cell
    }

    
    override func viewDidLoad() {
        super.viewDidLoad()
        

        
        collectionView.delegate = self
        collectionView.dataSource = self
//        view.addSubview(collectionView)
        
        
        
        view.addSubview(backdropContainer)
        setupBackdrop()
        
        view.addSubview(foredropContainer)
        setupFordrop()
        
//        view.bringSubviewToFront(collectionView)
        
        
        
        
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

class TeamCell: UICollectionViewCell {
    
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
