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

class AddTaskViewController: UIViewController, UITextFieldDelegate {

    
    //MARK:- Backdrop & Fordrop parent containers
    var backdropContainer = UIView()
    var foredropContainer = UIView()
    var bottomBarContainer = UIView()
    
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
    
     var addTaskTextBox_Material = MDCFilledTextField()
    
    var todoColors = ToDoColors()
    var todoFont = ToDoFont()
    var todoTimeUtils = ToDoTimeUtils()
    
    let homeDate_Day = UILabel()
     let homeDate_WeekDay = UILabel()
     let homeDate_Month = UILabel()
    
    //MARK:- Buttons + Views + Bottom bar
    var calendar: FSCalendar!
//    let fab_revealCalAtHome = MDCFloatingButton(shape: .mini)
//    let revealCalAtHomeButton = MDCButton()
//    let revealChartsAtHomeButton = MDCButton()
    
    //MARK:- cuurentt task list date
    var dateForTheView = Date.today()
    
    override func viewDidLoad() {
        super.viewDidLoad()

        view.addSubview(backdropContainer)
        setupBackdrop()
        
        view.addSubview(foredropContainer)
        setupFordrop()
        
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

}
