import UIKit
import FluentUI

class ProjectPickerViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    let tableView = UITableView()
    let projects: [Projects]
    var selectedProject: Projects?
    var onProjectSelected: ((Projects?) -> Void)?

    init(projects: [Projects], selectedProject: Projects?) {
        self.projects = projects
        self.selectedProject = selectedProject
        super.init(nibName: nil, bundle: nil)
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(FluentUI.TableViewCell.self, forCellReuseIdentifier: "ProjectCell")
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return projects.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProjectCell", for: indexPath) as! FluentUI.TableViewCell
        let project = projects[indexPath.row]
        cell.setup(title: project.projectName ?? "Unnamed Project")
        // Compare by objectID if they are CoreData objects, otherwise by name or another unique ID.
        // Assuming 'Projects' is a class or struct with an 'objectID' or comparable unique identifier.
        if let selProject = selectedProject, selProject.objectID == project.objectID {
            cell.accessoryType = .checkmark
        } else {
            cell.accessoryType = .none
        }
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let project = projects[indexPath.row]
        onProjectSelected?(project)
        // The dismiss logic might need to be handled by the presenter of this BottomSheet, 
        // or ensure this view controller has a way to dismiss itself (e.g., if wrapped in a NavController).
        // For now, keeping dismiss(animated: true) as per the issue, assuming it's presented in a way this works.
        dismiss(animated: true) 
    }
}

// Mock for Projects if not available to worker - remove if actual class exists
/*
class Projects {
    var projectName: String?
    var objectID: NSManagedObjectID? // Or some other unique identifier
}
*/
