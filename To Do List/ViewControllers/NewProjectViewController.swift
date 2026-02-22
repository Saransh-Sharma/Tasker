//
//  NewProjectViewController.swift
//  To Do List
//
//  Created by Saransh Sharma on 24/06/20.
//  Copyright 2020 saransh1337. All rights reserved.
//

import UIKit
import SwiftUI
import MaterialComponents.MaterialTextControls_OutlinedTextFields

extension String {
    /// Executes trimmingLeadingAndTrailingSpaces.
    func trimmingLeadingAndTrailingSpaces(using characterSet: CharacterSet = .whitespacesAndNewlines) -> String {
        return trimmingCharacters(in: characterSet)
    }
}

class NewProjectViewController: UIViewController, UITextFieldDelegate, UseCaseCoordinatorInjectable, PresentationDependencyContainerAware {
    
    //    var peoplePickers: [PeoplePicker] = []
    private var todoColors: TaskerColorTokens {
        TaskerThemeManager.shared.currentTheme.tokens.color
    }
    
    //    var description = UILabel()
    
    static let verticalSpacing: CGFloat = 16
    static let margin: CGFloat = 16
    
    var projectNameTextField = MDCOutlinedTextField()
    var projecDescriptionTextField = MDCOutlinedTextField()
    
    let button = UIButton(type: .system)
    
    var currentProjectInTexField = ""
    var currentDescriptionInTexField = ""
    //    var projecDescriptionTextField = MDCOutlinedTextField()
    
    
    let addProjectContainer: UIStackView = createVerticalContainer()
    var useCaseCoordinator: UseCaseCoordinator!
    var presentationDependencyContainer: PresentationDependencyContainer?
    
    /// Executes viewDidLoad.
    override func viewDidLoad() {
        super.viewDidLoad()
        guard useCaseCoordinator != nil else {
            fatalError("NewProjectViewController requires injected UseCaseCoordinator")
        }
        guard presentationDependencyContainer != nil else {
            fatalError("NewProjectViewController requires injected PresentationDependencyContainer")
        }
        
        //        view.backgroundColor = .green
        
        addProjectContainer.frame =  CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height)
        //CGRect(x: 0, y: yVal , width: Int(UIScreen.main.bounds.width), height: Int(UIScreen.main.bounds.height))
        
        view.addSubview(addProjectContainer)
        
        addProjectContainer.backgroundColor = todoColors.bgCanvas
        _ = addSpacer()
        _ = addLabel(text: "Create project")
        _ = addLabel(text: "Add a clear name and optional description.")
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
    
    /// Executes textField.
    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        let oldText = textField.text!
        logDebug("old text is: \(oldText)")
        let stringRange = Range(range, in:oldText)!
        let newText = oldText.replacingCharacters(in: stringRange, with: string)
        logDebug("new text is: \(newText)")
        
        
        if textField.tag == 0 {
            currentProjectInTexField = newText
        } else if textField.tag == 1 {
            currentDescriptionInTexField = newText
        }
        
        if newText.isEmpty {
            logDebug("EMPTY")
            button.isEnabled = false
        } else {
            logDebug("NOT EMPTY")
            button.isEnabled = true
            
        }
        return true
    }
    
    /// Executes addProjectDoneButton.
    func addProjectDoneButton() {
        
        button.setTitle("Create project", for: UIControl.State.normal)
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.font = .tasker.button
        button.backgroundColor = todoColors.accentPrimary
        button.tintColor = todoColors.accentOnPrimary
        button.layer.cornerRadius = TaskerUIKitTokens.corner.r2
        button.layer.cornerCurve = .continuous
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: TaskerUIKitTokens.interaction.minInteractiveSize).isActive = true
        button.addTarget(self, action: #selector(addOrModProject), for: UIControl.Event.touchUpInside)
        
        addProjectContainer.addArrangedSubview(button)
        
    }
    
    
    
    /// Executes addOrModProject.
    @objc func addOrModProject() {
        if currentProjectInTexField != "" {
            button.isEnabled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {}

            // Create project using V2 coordinator
            // Trim and normalize project name
            currentProjectInTexField = currentProjectInTexField.trimmingLeadingAndTrailingSpaces()

            // Create project using UseCaseCoordinator
            let projectRequest = CreateProjectRequest(
                name: currentProjectInTexField,
                description: currentDescriptionInTexField.isEmpty ? nil : currentDescriptionInTexField
            )

            logDebug("🆕 [NEW PROJECT] Creating new project...")
            logDebug("   Name: '\(currentProjectInTexField)'")
            logDebug("   Description: '\(currentDescriptionInTexField.isEmpty ? "none" : currentDescriptionInTexField)'")

            useCaseCoordinator.manageProjects.createProject(request: projectRequest) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    switch result {
                    case .success(let project):
                        logDebug("✅ [NEW PROJECT] Successfully created project!")
                        logDebug("   Project Name: '\(project.name)'")
                        logDebug("   Project UUID: \(project.id.uuidString)'")
                        logDebug("🆕 [NEW PROJECT] ==================")
                        self.showMessage("Project created\n\(project.name)")

                        // Navigate to add task screen
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            guard let presentationDependencyContainer = self.presentationDependencyContainer else {
                                fatalError("NewProjectViewController missing PresentationDependencyContainer")
                            }
                            let vm = presentationDependencyContainer.makeNewAddTaskViewModel()
                            let sheet = AddTaskSheetView(viewModel: vm)
                            let hostingVC = UIHostingController(rootView: sheet)
                            hostingVC.modalPresentationStyle = .pageSheet
                            if let sheetController = hostingVC.sheetPresentationController {
                                sheetController.detents = [.medium(), .large()]
                                sheetController.prefersGrabberVisible = true
                                sheetController.prefersScrollingExpandsWhenScrolledToEdge = false
                            }
                            self.present(hostingVC, animated: true) {
                                logDebug("SUCCESS - Navigated to Add Task")
                            }
                        }

                    case .failure(let error):
                        logError(" Failed to create project: \(error)")
                        self.showMessage(TaskerCopy.Errors.projectCreateFailed)
                    }
                }
            }

        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {}
            showMessage("Please enter a project name.")
            return
        }
    }
    
    /// Executes addLabel.
    @discardableResult
    func addLabel(text: String, alignment: NSTextAlignment = .natural) -> UILabel {
        let label = UILabel()
        label.font = UIFont.tasker.body
        label.textColor = todoColors.textPrimary
        label.textAlignment = alignment
        label.text = text
        label.numberOfLines = 0
        addProjectContainer.addArrangedSubview(label)
        return label
    }
    
    /// Executes addSeparator.
    func addSeparator() -> UIView {
        let separator = UIView()
        separator.backgroundColor = .separator
        separator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale).isActive = true
        addProjectContainer.addArrangedSubview(separator)
        return separator
    }
    
    /// Executes addSpacer.
    func addSpacer() -> UIView {
        let spacer = UIView()
        spacer.heightAnchor.constraint(equalToConstant: NewProjectViewController.margin).isActive = true
        addProjectContainer.addArrangedSubview(spacer)
        return spacer
    }
    
    /// Executes showMessage.
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
    /// Executes addProjectNameTexField.
    func addProjectNameTexField() {
        
        let estimatedFrame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 25)
        projectNameTextField = MDCOutlinedTextField(frame: estimatedFrame)
        projectNameTextField.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 25)
        projectNameTextField.label.text = "Project name"
        projectNameTextField.leadingAssistiveLabel.text = "Enter a project name."
        projectNameTextField.font = UIFont.tasker.body
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
    /// Executes addProjectDesccriptionTexField.
    func addProjectDesccriptionTexField() {
        
        let estimatedFrame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 25)
        projecDescriptionTextField = MDCOutlinedTextField(frame: estimatedFrame)
        projecDescriptionTextField.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 25)
        projecDescriptionTextField.label.text = "Description"
        projecDescriptionTextField.leadingAssistiveLabel.text = "Optional description."
        projecDescriptionTextField.font = UIFont.tasker.body
        projecDescriptionTextField.delegate = self
        projecDescriptionTextField.clearButtonMode = .whileEditing
        
        projecDescriptionTextField.sizeToFit()
        
        projecDescriptionTextField.tag = 1
        
        projecDescriptionTextField.backgroundColor = .clear
        
        
        addProjectContainer.addArrangedSubview(projecDescriptionTextField)
        
        
    }



    /// Executes createVerticalContainer.
    static func createVerticalContainer() -> UIStackView {
        let container = UIStackView(frame: .zero)
        container.axis = .vertical
        container.layoutMargins = UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
        container.isLayoutMarginsRelativeArrangement = true
        container.spacing = verticalSpacing
        return container
    }
    
    
    
    
    
}
