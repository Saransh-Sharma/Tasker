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
import CoreData

// MARK: - Inline Project Repository
// Note: This inline implementation exists because State folder files aren't in the Xcode target
fileprivate class InlineProjectRepository: ProjectRepositoryProtocol {
    private let viewContext: NSManagedObjectContext

    init(container: NSPersistentContainer) {
        self.viewContext = container.viewContext
    }

    func fetchAllProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(key: "projectName", ascending: true)]
            do {
                let entities = try self.viewContext.fetch(request)
                let projects = ProjectMapper.toDomainArray(from: entities)
                DispatchQueue.main.async { completion(.success(projects)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func fetchProject(withId id: UUID, completion: @escaping (Result<Project?, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(format: "projectID == %@", id as CVarArg)
            request.fetchLimit = 1
            do {
                let entities = try self.viewContext.fetch(request)
                let project = entities.first.map { ProjectMapper.toDomain(from: $0) }
                DispatchQueue.main.async { completion(.success(project)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func fetchProject(withName name: String, completion: @escaping (Result<Project?, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(format: "projectName == %@", name)
            request.fetchLimit = 1
            do {
                let entities = try self.viewContext.fetch(request)
                let project = entities.first.map { ProjectMapper.toDomain(from: $0) }
                DispatchQueue.main.async { completion(.success(project)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func fetchInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        fetchProject(withId: ProjectConstants.inboxProjectID) { result in
            switch result {
            case .success(let project):
                if let project = project {
                    completion(.success(project))
                } else {
                    completion(.failure(NSError(domain: "ProjectRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Inbox project not found"])))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func fetchCustomProjects(completion: @escaping (Result<[Project], Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(format: "projectID != %@", ProjectConstants.inboxProjectID as CVarArg)
            request.sortDescriptors = [NSSortDescriptor(key: "projectName", ascending: true)]
            do {
                let entities = try self.viewContext.fetch(request)
                let projects = ProjectMapper.toDomainArray(from: entities)
                DispatchQueue.main.async { completion(.success(projects)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func createProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        // First check if the project name is available (prevent duplicates)
        isProjectNameAvailable(project.name, excludingId: nil) { [weak self] result in
            guard let self = self else {
                completion(.failure(NSError(domain: "ProjectRepository", code: 500, userInfo: [NSLocalizedDescriptionKey: "Repository deallocated"])))
                return
            }

            switch result {
            case .success(let isAvailable):
                if !isAvailable {
                    // Name already exists - return duplicate error
                    let error = NSError(
                        domain: "ProjectRepository",
                        code: 409, // HTTP Conflict
                        userInfo: [NSLocalizedDescriptionKey: "A project with the name '\(project.name)' already exists"]
                    )
                    DispatchQueue.main.async { completion(.failure(error)) }
                    return
                }

                // Name is available - proceed with creation
                self.viewContext.perform {
                    let entity = ProjectMapper.toEntity(from: project, in: self.viewContext)
                    do {
                        try self.viewContext.save()
                        let savedProject = ProjectMapper.toDomain(from: entity)
                        DispatchQueue.main.async { completion(.success(savedProject)) }
                    } catch {
                        DispatchQueue.main.async { completion(.failure(error)) }
                    }
                }

            case .failure(let error):
                // Failed to check name availability
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func ensureInboxProject(completion: @escaping (Result<Project, Error>) -> Void) {
        fetchInboxProject { result in
            switch result {
            case .success(let project):
                completion(.success(project))
            case .failure:
                let inbox = Project.createInbox()
                self.createProject(inbox, completion: completion)
            }
        }
    }

    func updateProject(_ project: Project, completion: @escaping (Result<Project, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(format: "projectID == %@", project.id as CVarArg)
            request.fetchLimit = 1
            do {
                if let entity = try self.viewContext.fetch(request).first {
                    ProjectMapper.updateEntity(entity, from: project)
                    try self.viewContext.save()
                    let updatedProject = ProjectMapper.toDomain(from: entity)
                    DispatchQueue.main.async { completion(.success(updatedProject)) }
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(NSError(domain: "ProjectRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])))
                    }
                }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func renameProject(withId id: UUID, to newName: String, completion: @escaping (Result<Project, Error>) -> Void) {
        fetchProject(withId: id) { result in
            switch result {
            case .success(let project):
                guard var project = project else {
                    completion(.failure(NSError(domain: "ProjectRepository", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])))
                    return
                }
                project.name = newName
                self.updateProject(project, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    func deleteProject(withId id: UUID, deleteTasks: Bool, completion: @escaping (Result<Void, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            request.predicate = NSPredicate(format: "projectID == %@", id as CVarArg)
            do {
                let entities = try self.viewContext.fetch(request)
                entities.forEach { self.viewContext.delete($0) }
                try self.viewContext.save()
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func getTaskCount(for projectId: UUID, completion: @escaping (Result<Int, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = NSPredicate(format: "projectID == %@", projectId as CVarArg)
            do {
                let count = try self.viewContext.count(for: request)
                DispatchQueue.main.async { completion(.success(count)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func getTasks(for projectId: UUID, completion: @escaping (Result<[Task], Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = NSPredicate(format: "projectID == %@", projectId as CVarArg)
            do {
                let entities = try self.viewContext.fetch(request)
                let tasks = TaskMapper.toDomainArray(from: entities)
                DispatchQueue.main.async { completion(.success(tasks)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func moveTasks(from sourceProjectId: UUID, to targetProjectId: UUID, completion: @escaping (Result<Void, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<NTask> = NTask.fetchRequest()
            request.predicate = NSPredicate(format: "projectID == %@", sourceProjectId as CVarArg)
            do {
                let tasks = try self.viewContext.fetch(request)
                tasks.forEach { $0.projectID = targetProjectId }
                try self.viewContext.save()
                DispatchQueue.main.async { completion(.success(())) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }

    func isProjectNameAvailable(_ name: String, excludingId: UUID?, completion: @escaping (Result<Bool, Error>) -> Void) {
        viewContext.perform {
            let request: NSFetchRequest<Projects> = Projects.fetchRequest()
            var predicates = [NSPredicate(format: "projectName == %@", name)]
            if let excludingId = excludingId {
                predicates.append(NSPredicate(format: "projectID != %@", excludingId as CVarArg))
            }
            request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            request.fetchLimit = 1
            do {
                let count = try self.viewContext.count(for: request)
                DispatchQueue.main.async { completion(.success(count == 0)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
}

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

            // Create project using Clean Architecture
            guard let taskRepo = DependencyContainer.shared.taskRepository as? TaskRepositoryProtocol,
                  let container = DependencyContainer.shared.persistentContainer else {
                print("❌ Failed to get dependencies")
                HUD.shared.showFailure(from: self, with: "Failed to create project")
                return
            }

            // Create inline project repository adapter since State folder isn't in target
            let projectRepo = InlineProjectRepository(container: container)
            let useCaseCoordinator = UseCaseCoordinator(
                taskRepository: taskRepo,
                projectRepository: projectRepo,
                cacheService: nil
            )

            // Trim and normalize project name
            currentProjectInTexField = currentProjectInTexField.trimmingLeadingAndTrailingSpaces()

            // Create project using UseCaseCoordinator
            let projectRequest = CreateProjectRequest(
                name: currentProjectInTexField,
                description: currentDescriptionInTexField.isEmpty ? nil : currentDescriptionInTexField
            )

            print("🆕 [NEW PROJECT] Creating new project...")
            print("   Name: '\(currentProjectInTexField)'")
            print("   Description: '\(currentDescriptionInTexField.isEmpty ? "none" : currentDescriptionInTexField)'")

            useCaseCoordinator.manageProjects.createProject(request: projectRequest) { [weak self] result in
                DispatchQueue.main.async {
                    guard let self = self else { return }

                    switch result {
                    case .success(let project):
                        print("✅ [NEW PROJECT] Successfully created project!")
                        print("   Project Name: '\(project.name)'")
                        print("   Project UUID: \(project.id.uuidString)'")
                        print("🆕 [NEW PROJECT] ==================")
                        HUD.shared.showSuccess(from: self, with: "Project created\n\(project.name)")

                        // Navigate to add task screen
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                            guard let newViewController = storyBoard.instantiateViewController(withIdentifier: "addNewTask") as? AddTaskViewController else {
                                print("❌ Failed to cast view controller to AddTaskViewController")
                                HUD.shared.showFailure(from: self, with: "Failed to open Add Task screen")
                                return
                            }
                            // Inject repository dependency using dependency container
                            DependencyContainer.shared.inject(into: newViewController)
                            newViewController.modalPresentationStyle = .fullScreen
                            self.present(newViewController, animated: true, completion: { () in
                                print("SUCCESS - Navigated to Add Task")
                            })
                        }

                    case .failure(let error):
                        print("❌ Failed to create project: \(error)")
                        HUD.shared.showFailure(from: self, with: "Failed to create project")
                    }
                }
            }

        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {}
            HUD.shared.showFailure(from: self, with: "No New Project")
            return
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



    static func createVerticalContainer() -> UIStackView {
        let container = UIStackView(frame: .zero)
        container.axis = .vertical
        container.layoutMargins = UIEdgeInsets(top: margin, left: margin, bottom: margin, right: margin)
        container.isLayoutMarginsRelativeArrangement = true
        container.spacing = verticalSpacing
        return container
    }
    
    
    
    
    
}
