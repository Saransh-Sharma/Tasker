//
//  NewProjectViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 24/06/20.
//  Copyright 2020 saransh1337. All rights reserved.
//

import UIKit
import FluentUI
import MaterialComponents.MaterialTextControls_OutlinedTextFields

extension String {
    func trimmingLeadingAndTrailingSpaces(using characterSet: CharacterSet = .whitespacesAndNewlines) -> String {
        return trimmingCharacters(in: characterSet)
    }
}

class NewProjectViewController: UIViewController, UITextFieldDelegate {
    
    //    var peoplePickers: [PeoplePicker] = []
    var todoColors = ToDoColors()
    
    //    var description = Label(style: .subhead, colorStyle: .regular)
    
    static let verticalSpacing: CGFloat = 16
    static let margin: CGFloat = 16
    
    var projectNameTextField = MDCOutlinedTextField()
    var projecDescriptionTextField = MDCOutlinedTextField()
    
    let button = Button()
    
    var currentProjectInTexField = ""
    var currentDescriptionInTexField = ""
    //    var projecDescriptionTextField = MDCOutlinedTextField()
    
    
    let addProjectContainer: UIStackView = createVerticalContainer()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //        view.backgroundColor = .green
        
        addProjectContainer.frame =  CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        //CGRect(x: 0, y: yVal , width: Int(UIScreen.main.bounds.width), height: Int(UIScreen.main.bounds.height))
        
        view.addSubview(addProjectContainer)
        
        addProjectContainer.backgroundColor = todoColors.backgroundColor
        _ = addSpacer()
        _ = addLabel(text: "Add new project")
        _ = addLabel(text: "Add new project & set it's description")
        _ = addSeparator()
        _ = addSpacer()
        
        addProjectNameTexField()
        _ = addSpacer()
        //        addProjectContainer.addArrangedSubview(Separator())
        //        addProjectContainer.addArrangedSubview(UIView())
        
        
        addProjectDesccriptionTexField()
        _ = addSpacer()
        _ = addSeparator()
        _ = addSpacer()
        
        
        addProjectDoneButton()
        _ = addSpacer()
        
        projectNameTextField.becomeFirstResponder()
        
        
        
        
        // Do any additional setup after loading the view.
    }
    
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let oldText = textField.text!
        print("old text is: \(oldText)")
        let stringRange = Range(range, in:oldText)!
        let newText = oldText.replacingCharacters(in: stringRange, with: string)
        print("new text is: \(newText)")
        
        
        if textField.tag == 0 {
            currentProjectInTexField = newText
        } else if textField.tag == 1 {
            currentDescriptionInTexField = newText
        }
        
        if newText.isEmpty {
            print("EMPTY")
            button.isEnabled = false
        } else {
            print("NOT EMPTY")
            button.isEnabled = true
            
        }
        return true
    }
    
    func addProjectDoneButton() {
        
        button.setTitle("Add Project", for: UIControl.State.normal)
        button.titleLabel?.numberOfLines = 0
        button.addTarget(self, action: #selector(addOrModProject), for: UIControl.Event.touchUpInside)
        
        addProjectContainer.addArrangedSubview(button)
        
    }
    
    
    
    @objc func addOrModProject() {
        if currentProjectInTexField != "" {
            button.isEnabled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {}
            
            let allProjects = ProjectManager.sharedInstance.displayedProjects
            var allProjectList = [String]()
            
            for e in allProjects {
                if let projectName = e.projectName {
                    allProjectList.append(projectName)
                }
            }
            
            currentProjectInTexField = currentProjectInTexField.trimmingLeadingAndTrailingSpaces()
            if !allProjectList.contains(currentProjectInTexField) {
                ProjectManager.sharedInstance.addNewProject(with: currentProjectInTexField, and: currentProjectInTexField)
                HUD.shared.showSuccess(from: self, with: "New Project\n\(currentProjectInTexField)")
            } else {
                HUD.shared.showFailure(from: self, with: "\(currentProjectInTexField) already exists !")
            }
            
        } else {
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {}
            HUD.shared.showFailure(from: self, with: "No New Project")
            
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            
            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let newViewController = storyBoard.instantiateViewController(withIdentifier: "addNewTask") as! AddTaskViewController
            newViewController.modalPresentationStyle = .fullScreen
            self.present(newViewController, animated: true, completion: { () in
                print("SUCCESS !!!")
                //                HUD.shared.showSuccess(from: self, with: "Success")
            })
        }
    }
    
    @discardableResult
    func addLabel(text: String, alignment: NSTextAlignment = .natural) -> Label {
        let label = Label()
        label.textAlignment = alignment
        label.text = text
        addProjectContainer.addArrangedSubview(label)
        return label
    }
    
    func addSeparator() -> Separator {
        let separator = Separator()
        addProjectContainer.addArrangedSubview(separator)
        return separator
    }
    
    func addSpacer() -> UIView {
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: NewProjectViewController.margin).isActive = true
        addProjectContainer.addArrangedSubview(spacer)
        return spacer
    }
    
    func showMessage(_ message: String, autoDismiss: Bool = true, completion: (() -> Void)? = nil) {
        let alert = UIAlertController(title: message, message: nil, preferredStyle: .alert)
        present(alert, animated: true)
        
        if autoDismiss {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.dismiss(animated: true)
            }
        } else {
            let okAction = UIAlertAction(title: "OK", style: .default) { _ in
                self.dismiss(animated: true, completion: completion)
            }
            let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
            alert.addAction(okAction)
            alert.addAction(cancelAction)
        }
        
    }
    
    // MARK: MAKE project name text field
    func addProjectNameTexField() {
        
        let estimatedFrame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 25)
        projectNameTextField = MDCOutlinedTextField(frame: estimatedFrame)
        projectNameTextField.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 25)
        projectNameTextField.label.text = "project name"
        projectNameTextField.leadingAssistiveLabel.text = "Fill in the new project name"
        projectNameTextField.font = UIFont(name: "HelveticaNeue", size: 18)
        projectNameTextField.delegate = self
        projectNameTextField.clearButtonMode = .whileEditing
        let placeholderTextArray = ["New York Trip",
                                    "Finances",
                                    "To Watch",
                                    "Reading List",
                                    "Writing"]
        projectNameTextField.placeholder = placeholderTextArray.randomElement()!
        projectNameTextField.sizeToFit()
        
        projectNameTextField.tag = 0
        
        projectNameTextField.backgroundColor = .clear
        
        
        addProjectContainer.addArrangedSubview(projectNameTextField)
        
        
    }
    
    // MARK: MAKE project description ext field
    func addProjectDesccriptionTexField() {
        
        let estimatedFrame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 25)
        projecDescriptionTextField = MDCOutlinedTextField(frame: estimatedFrame)
        projecDescriptionTextField.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 25)
        projecDescriptionTextField.label.text = "add description"
        projecDescriptionTextField.leadingAssistiveLabel.text = "Add project description"
        projecDescriptionTextField.font = UIFont(name: "HelveticaNeue", size: 18)
        projecDescriptionTextField.delegate = self
        projecDescriptionTextField.clearButtonMode = .whileEditing
        
        projecDescriptionTextField.sizeToFit()
        
        projecDescriptionTextField.tag = 1
        
        projecDescriptionTextField.backgroundColor = .clear
        
        
        addProjectContainer.addArrangedSubview(projecDescriptionTextField)
        
        
    }
    
    
    
    class func createVerticalContainer() -> UIStackView {
        let container = UIStackView(frame: .zero)
        container.axis = .vertical
        container.layoutMargins = UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
        container.isLayoutMarginsRelativeArrangement = true
        container.spacing = verticalSpacing
        return container
    }
    
    
    
    
    
}
