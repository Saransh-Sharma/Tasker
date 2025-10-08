//
//  NewProjectViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 24/06/20.
//  Copyright 2020 saransh1337. All rights reserved.
//

import UIKit
import CoreData
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

            // CRITICAL FIX: Proper duplicate detection and UUID assignment
            let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext
            guard let context = context else {
                print("❌ Failed to get Core Data context")
                return
            }

            // Trim and normalize project name
            currentProjectInTexField = currentProjectInTexField.trimmingLeadingAndTrailingSpaces()

            // Check for existing project (case-insensitive)
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(format: "projectName ==[c] %@", currentProjectInTexField)
            request.fetchLimit = 1

            do {
                let existingProjects = try context.fetch(request)

                if let existingProject = existingProjects.first {
                    // CRITICAL FIX: Project with this name already exists
                    // Don't create duplicate - ensure it has UUID and use it
                    if existingProject.projectID == nil {
                        existingProject.projectID = UUID()
                        print("✅ Assigned UUID to existing project: \(currentProjectInTexField)")
                        try context.save()
                    }

                    HUD.shared.showSuccess(from: self, with: "Using existing project\n\(currentProjectInTexField)")
                    print("ℹ️ Project '\(currentProjectInTexField)' already exists with UUID: \(existingProject.projectID?.uuidString ?? "nil")")
                } else {
                    // CRITICAL FIX: Create new project with UUID
                    let newProject = Projects(context: context)
                    newProject.projectID = UUID()  // ✅ ALWAYS assign UUID to new projects!
                    newProject.projectName = currentProjectInTexField
                    newProject.projecDescription = currentDescriptionInTexField.isEmpty ? nil : currentDescriptionInTexField

                    try context.save()
                    print("✅ Created new project '\(currentProjectInTexField)' with UUID: \(newProject.projectID?.uuidString ?? "nil")")
                    HUD.shared.showSuccess(from: self, with: "New Project\n\(currentProjectInTexField)")
                }
            } catch {
                print("❌ Failed to check/save project: \(error)")
                HUD.shared.showFailure(from: self, with: "Failed to create project")
                return
            }

        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {}
            HUD.shared.showFailure(from: self, with: "No New Project")
            return
        }

        // Navigate to add task screen
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            let newViewController = storyBoard.instantiateViewController(withIdentifier: "addNewTask") as! AddTaskViewController
            // Inject repository dependency using dependency container
            DependencyContainer.shared.inject(into: newViewController)
            newViewController.modalPresentationStyle = .fullScreen
            self.present(newViewController, animated: true, completion: { () in
                print("SUCCESS - Navigated to Add Task")
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
