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

class AddTaskViewController: UIViewController, UITextFieldDelegate, PillButtonBarDelegate, UIScrollViewDelegate {
    
    // Delegate for communicating back to the presenter
    weak var delegate: AddTaskViewControllerDelegate?

    //MARK:- Backdrop & Fordrop parent containers
    var backdropContainer = UIView()
    var foredropContainer = UIView()
    var bottomBarContainer = UIView()

    // Initialize foredropStackContainer using the static method
    let foredropStackContainer: UIStackView = AddTaskViewController.createVerticalContainer()

    static let verticalSpacing: CGFloat = 16
    static let margin: CGFloat = 16

    // MARK: TASK METADATA
    var currentTaskInMaterialTextBox: String = ""
    var currentTaskDescription: String = ""
    var isThisEveningTask: Bool = false
    var taskDayFromPicker: String =  "Unknown" //change datatype tp task type
    var currentTaskPriority: Int = 3
    
    // Description text field
    var descriptionTextBox_Material = MDCFilledTextField()

    let addProjectString = "Add Project"

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
    // let cancelButton = UIView() // This seemed unused, removed for now. Add back if needed.
    let eveningSwitch = UISwitch()
    // var prioritySC =  UISegmentedControl() // This is initialized in AddTaskForedropView extension

    let switchSetContainer = UIView()
    let switchBackground = UIView()
    let eveningLabel = UILabel()

    var addTaskTextBox_Material = MDCFilledTextField()
    let nCancelButton = UIButton()
    let fab_doneTask = MDCFloatingButton(shape: .default)
    let p = ["None", "Low", "High", "Highest"] // Used by AddTaskForedropView extension

    var tabsSegmentedControl = SegmentedControl() // Initialized in AddTaskForedropView extension

    var todoColors = ToDoColors()
    var todoFont = ToDoFont()
    var todoTimeUtils = ToDoTimeUtils()

    let homeDate_Day = UILabel()
    let homeDate_WeekDay = UILabel()
    let homeDate_Month = UILabel()

    let existingProjectCellID = "existingProject"
    let newProjectCellID = "newProject"

    //MARK:- Buttons + Views + Bottom bar
    var calendar: FSCalendar!

    //MARK:- current task list date
    var dateForAddTaskView = Date.today()

    var pillBarProjectList: [PillButtonBarItem] = [PillButtonBarItem(title: "Add Project")]
    var currenttProjectForAddTaskView = "Inbox"

    var filledBar: UIView?


    func setProjecForView(name: String) {
        // currenttProjectForAddTaskView = name // Logic seems commented out
    }

//    //MARK:- DONE TASK ACTION (Stub for extension)
//    @objc func doneAddTaskAction() {
//        // This is just a stub that will be called from the extension
//        // The actual implementation is in AddTaskForedropView.swift extension
//        print("AddTaskViewController: doneAddTaskAction (stub) called")
//    }
    
    // Correct: static func for creating the container
    static func createVerticalContainer() -> UIStackView {
        let container = UIStackView(frame: .zero)
        container.axis = .vertical
        // Use static members correctly
        container.layoutMargins = UIEdgeInsets(top: AddTaskViewController.margin, left: AddTaskViewController.margin, bottom: AddTaskViewController.margin, right: AddTaskViewController.margin)
        container.isLayoutMarginsRelativeArrangement = true
        container.spacing = AddTaskViewController.verticalSpacing
        return container
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Setup backdrop with navigation bar and calendar
        view.addSubview(backdropContainer)
        setupBackdrop()
        setupBackdropBackground()
        setupNavigationBar()
        setupCalendarWidget()
        
        // Setup foredrop with form - setupAddTaskForedrop will add foredropStackContainer to foredropContainer
        self.setupAddTaskForedrop()
        
        // Setup form components
        setupAddTaskTextField()
        setupDescriptionTextField()
        setupProjectsPillBar()
        setupPrioritySC()
        setupDoneButton()
        
        // Add components to foredrop stack container in order
        // Ensure all components are visible and properly configured
        self.addTaskTextBox_Material.isHidden = false
        self.addTaskTextBox_Material.translatesAutoresizingMaskIntoConstraints = false
        self.foredropStackContainer.addArrangedSubview(self.addTaskTextBox_Material)
        
        self.descriptionTextBox_Material.isHidden = false
        self.descriptionTextBox_Material.translatesAutoresizingMaskIntoConstraints = false
        self.foredropStackContainer.addArrangedSubview(self.descriptionTextBox_Material)
        
        if let pillBar = self.filledBar {
            pillBar.isHidden = false
            pillBar.translatesAutoresizingMaskIntoConstraints = false
            self.foredropStackContainer.addArrangedSubview(pillBar)
        }
        
        self.tabsSegmentedControl.isHidden = false
        self.tabsSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        self.foredropStackContainer.addArrangedSubview(self.tabsSegmentedControl)
        
        // Done button visibility is controlled by text field content
        self.fab_doneTask.translatesAutoresizingMaskIntoConstraints = false
        self.foredropStackContainer.addArrangedSubview(self.fab_doneTask)

        addTaskTextBox_Material.becomeFirstResponder()
        addTaskTextBox_Material.keyboardType = .default
        addTaskTextBox_Material.autocorrectionType = .yes
        addTaskTextBox_Material.smartDashesType = .yes
        addTaskTextBox_Material.smartQuotesType = .yes
        addTaskTextBox_Material.smartInsertDeleteType = .yes
        addTaskTextBox_Material.delegate = self
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        print("AddTaskViewController: viewWillAppear called")
        
        // Refresh project data
        ProjectManager.sharedInstance.refreshAndPrepareProjects()

        // Re-setup or update the pill bar as project list might have changed.
        // This will call buildProojectsPillBarData from the extension.
        // NOTE: setupProjectsPillBar is defined in the AddTaskForedropView extension.
        self.setupProjectsPillBar() 

        // Default selection logic for PillBar
        if let bar = self.filledBar?.subviews.first(where: { $0 is PillButtonBar }) as? PillButtonBar {
            let inboxProjectName = "Inbox"
            var defaultSelectionIndex = pillBarProjectList.firstIndex(where: { $0.title == inboxProjectName })

            // If Inbox not found, try to select the first item if list is not empty (could be "Add Project")
            if defaultSelectionIndex == nil && !pillBarProjectList.isEmpty {
                 defaultSelectionIndex = 0 
            }

            if let indexToSelect = defaultSelectionIndex, indexToSelect < pillBarProjectList.count {
                _ = bar.selectItem(atIndex: indexToSelect)
                currenttProjectForAddTaskView = pillBarProjectList[indexToSelect].title
            } else if !pillBarProjectList.isEmpty { // Fallback if no specific item found but list is not empty
                 _ = bar.selectItem(atIndex: 0)
                currenttProjectForAddTaskView = pillBarProjectList[0].title
            }
            print("AddTaskViewController: viewWillAppear - Selected project in pill bar: \(currenttProjectForAddTaskView)")
        }
    }
    
    // MARK:- Build Page Header
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent // Or .default depending on your background
    }
    
    // MARK: - UITextFieldDelegate
    // This function is called when you click return key in the text field.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        print("textFieldShouldReturn called")
        textField.resignFirstResponder()
        self.doneAddTaskAction() // Call the action defined in the extension
        return true
    }

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        if let oldText = textField.text, let stringRange = Range(range, in: oldText) {
            let newText = oldText.replacingCharacters(in: stringRange, with: string)
            print("AddTaskViewController: new text is: \(newText)")
            
            if textField == addTaskTextBox_Material {
                currentTaskInMaterialTextBox = newText
            } else if textField == descriptionTextBox_Material {
                currentTaskDescription = newText
            }
            
            let isEmpty = currentTaskInMaterialTextBox.isEmpty
            // fab_doneTask, tabsSegmentedControl, and filledBar are properties of AddTaskViewController (self)
            // and are assumed to be correctly initialized/managed by the extension methods.
            self.fab_doneTask.isHidden = isEmpty
            self.tabsSegmentedControl.isHidden = isEmpty
            self.filledBar?.isHidden = isEmpty
            self.fab_doneTask.isEnabled = !isEmpty
        }
        return true
    }
    
    // MARK: - Setup Methods
    
    func setupNavigationBar() {
        // Setup navigation bar similar to home screen
        nCancelButton.setTitle("Cancel", for: .normal)
        nCancelButton.setTitleColor(.white, for: .normal)
        nCancelButton.titleLabel?.font = todoFont.setFont(fontSize: 16, fontweight: .medium, fontDesign: .default)
        nCancelButton.frame = CGRect(x: UIScreen.main.bounds.maxX - 80, y: 50, width: 70, height: 35)
        view.addSubview(nCancelButton)
        nCancelButton.addTarget(self, action: #selector(self.cancelAddTaskAction), for: .touchUpInside)
        
        // Setup date display in navigation bar
        setHomeViewDate()
        homeTopBar.addSubview(homeDate_Day)
        homeTopBar.addSubview(homeDate_WeekDay)
        homeTopBar.addSubview(homeDate_Month)
    }
    
    func setupCalendarWidget() {
        // Setup calendar widget similar to home screen
        setupCalAtAddTask()
        backdropContainer.addSubview(calendar)
    }
    
    func setupDescriptionTextField() {
        let estimatedFrame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 80)
        self.descriptionTextBox_Material = MDCFilledTextField(frame: estimatedFrame)
        self.descriptionTextBox_Material.label.text = "Description (optional)"
        self.descriptionTextBox_Material.leadingAssistiveLabel.text = "Add task details"
        self.descriptionTextBox_Material.placeholder = "Enter task description..."
        self.descriptionTextBox_Material.sizeToFit()
        self.descriptionTextBox_Material.delegate = self
        self.descriptionTextBox_Material.clearButtonMode = .whileEditing
        self.descriptionTextBox_Material.backgroundColor = .clear
        
        // Don't add to stack container here - it's added in viewDidLoad
    }

    // @objc func cancelAddTaskAction() is now only in AddTaskForedropView.swift extension

} // This is the main closing brace for AddTaskViewController

// MARK: - PillButtonBarDemoController: PillButtonBarDelegate

extension AddTaskViewController {
    func pillBar(_ pillBar: PillButtonBar, didSelectItem item: PillButtonBarItem, atIndex index: Int) {
        currenttProjectForAddTaskView = item.title
        print("Project is: \(currenttProjectForAddTaskView)")
        
        if(item.title.contains(addProjectString)) {
            
            //            medmel//Open add project VC
            
            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let newViewController = storyBoard.instantiateViewController(withIdentifier: "newProject") as! NewProjectViewController
            newViewController.modalPresentationStyle = .popover
            //        self.present(newViewController, animated: true, completion: nil)
            self.present(newViewController, animated: true, completion: { () in
                print("SUCCESS !!!")
                //                HUD.shared.showSuccess(from: self, with: "Success")
                
            })
            
        } else {
            //
            //            let alert = UIAlertController(title: "Item \(item.title) was selected", message: nil, preferredStyle: .alert)
            //            let action = UIAlertAction(title: "OK", style: .default)
            //            alert.addAction(action)
            //            present(alert, animated: true)
        }
        
        
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


