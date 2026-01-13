import UIKit
import CoreData

/// A generic task list view controller for efficient UI updates (Clean Architecture)
/// TODO: Migrate away from NSFetchedResultsController to use repository pattern
/// This class serves as a template for other task list views in the app
class TaskListViewController: UIViewController, TaskRepositoryDependent {
    
    // MARK: - Properties
    
    /// Table view for displaying tasks
    private let tableView = UITableView(frame: .zero, style: .plain)
    
    /// Fetched results controller for efficient Core Data UI integration
    private var fetchedResultsController: NSFetchedResultsController<NTask>?
    
    /// Task repository dependency (injected)
    var taskRepository: TaskRepository!
    
    /// Core Data view context (injected)
    var viewContext: NSManagedObjectContext!
    
    /// Task type filter (optional)
    private var taskType: Int32? // TaskType raw value
    
    /// Project name filter (optional)
    private var projectName: String?
    
    private func applyTaskTypeFilter(_ type: Int32) -> NSPredicate { // TaskType raw value
        return NSPredicate(format: "taskType == %d", type)
    }
    
    /// Selected date filter (defaults to today)
    private var selectedDate: Date = Date()
    
    /// Completion status filter (defaults to showing all)
    private var showCompleted = true
    
    // MARK: - Initialization
    
    /// Creates a new task list controller with optional filters
    /// - Parameters:
    ///   - taskType: Optional task type filter
    ///   - projectName: Optional project name filter
    ///   - date: Date to show tasks for, defaults to today
    ///   - showCompleted: Whether to show completed tasks, defaults to true
    init(taskType: Int32? = nil, projectName: String? = nil, date: Date = Date(), showCompleted: Bool = true) {
        self.taskType = taskType
        self.projectName = projectName
        self.selectedDate = date
        self.showCompleted = showCompleted
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    // MARK: - Lifecycle Methods
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Ensure dependencies are injected
        guard taskRepository != nil && viewContext != nil else {
            fatalError("TaskListViewController requires taskRepository and viewContext to be injected")
        }
        
        setupUI()
        setupFetchedResultsController()
        
        // Start fetching data
        try? fetchedResultsController?.performFetch()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Refresh data if needed
        if fetchedResultsController == nil {
            setupFetchedResultsController()
            try? fetchedResultsController?.performFetch()
        }
        
        tableView.reloadData()
    }
    
    // MARK: - Setup Methods
    
    private func setupUI() {
        // Configure table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(TaskCell.self, forCellReuseIdentifier: "TaskCell")
        
        // Add to view hierarchy
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }
    
    private func setupFetchedResultsController() {
        // Create fetch request
        let fetchRequest: NSFetchRequest<NTask> = NTask.fetchRequest()
        
        // Build predicate based on filters
        var predicates: [NSPredicate] = []
        
        // Filter by task type if specified
        if let taskType = taskType {
            predicates.append(applyTaskTypeFilter(taskType))
        }
        
        // Filter by project name if specified
        if let projectName = projectName {
            predicates.append(NSPredicate(format: "project ==[c] %@", projectName))
        }
        
        // Filter by date range
        let startOfDay = selectedDate.startOfDay
        let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // For today, include overdue items
        if Calendar.current.isDateInToday(selectedDate) {
            // If showing incomplete tasks
            if !showCompleted {
                // Include both due today and overdue
                let dueTodayPredicate = NSPredicate(
                    format: "dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
                    startOfDay as NSDate,
                    endOfDay as NSDate
                )
                
                let overduePredicate = NSPredicate(
                    format: "dueDate < %@ AND isComplete == NO",
                    startOfDay as NSDate
                )
                
                predicates.append(NSCompoundPredicate(
                    orPredicateWithSubpredicates: [dueTodayPredicate, overduePredicate]
                ))
            } else {
                // Show both incomplete and those completed today
                let dueTodayPredicate = NSPredicate(
                    format: "dueDate >= %@ AND dueDate < %@",
                    startOfDay as NSDate,
                    endOfDay as NSDate
                )
                
                let overduePredicate = NSPredicate(
                    format: "dueDate < %@ AND isComplete == NO",
                    startOfDay as NSDate
                )
                
                let completedTodayPredicate = NSPredicate(
                    format: "dateCompleted >= %@ AND dateCompleted < %@ AND isComplete == YES",
                    startOfDay as NSDate,
                    endOfDay as NSDate
                )
                
                predicates.append(NSCompoundPredicate(
                    orPredicateWithSubpredicates: [dueTodayPredicate, overduePredicate, completedTodayPredicate]
                ))
            }
        } else {
            // For other dates, just show tasks for that specific day
            if showCompleted {
                // Both completed and incomplete
                let dueDatePredicate = NSPredicate(
                    format: "dueDate >= %@ AND dueDate < %@",
                    startOfDay as NSDate,
                    endOfDay as NSDate
                )
                
                let completedOnDatePredicate = NSPredicate(
                    format: "dateCompleted >= %@ AND dateCompleted < %@ AND isComplete == YES",
                    startOfDay as NSDate,
                    endOfDay as NSDate
                )
                
                predicates.append(NSCompoundPredicate(
                    orPredicateWithSubpredicates: [dueDatePredicate, completedOnDatePredicate]
                ))
            } else {
                // Only incomplete
                predicates.append(NSPredicate(
                    format: "dueDate >= %@ AND dueDate < %@ AND isComplete == NO",
                    startOfDay as NSDate,
                    endOfDay as NSDate
                ))
            }
        }
        
        // Combine all predicates with AND
        if predicates.count > 1 {
            fetchRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        } else if predicates.count == 1 {
            fetchRequest.predicate = predicates.first
        }
        
        // Set sort descriptors - priority first, then due date
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "taskPriority.rawValue", ascending: false),  // Higher priority first
            NSSortDescriptor(key: "dueDate", ascending: true)                  // Earlier due date first
        ]
        
        // Create fetched results controller
        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: viewContext,
            sectionNameKeyPath: nil,  // Could use "project" to section by project
            cacheName: nil            // Don't cache results
        )
        
        // Set delegate
        fetchedResultsController?.delegate = self
    }
    
    // MARK: - Public Methods
    
    /// Changes the selected date and refreshes the task list
    /// - Parameter date: New date to filter tasks by
    func setDate(_ date: Date) {
        self.selectedDate = date
        setupFetchedResultsController()
        try? fetchedResultsController?.performFetch()
        tableView.reloadData()
    }
    
    /// Toggles showing completed tasks
    func toggleShowCompleted() {
        showCompleted.toggle()
        setupFetchedResultsController()
        try? fetchedResultsController?.performFetch()
        tableView.reloadData()
    }
    
    /// Changes the task type filter
    /// - Parameter taskType: New task type to filter by, or nil for all types
    func setTaskType(_ type: Int32) { // TaskType raw value
        self.taskType = type
        setupFetchedResultsController()
        try? fetchedResultsController?.performFetch()
        tableView.reloadData()
    }
    
    /// Changes the project filter
    /// - Parameter projectName: New project name to filter by, or nil for all projects
    func setProject(_ projectName: String?) {
        self.projectName = projectName
        setupFetchedResultsController()
        try? fetchedResultsController?.performFetch()
        tableView.reloadData()
    }
}

// MARK: - UITableViewDataSource
extension TaskListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController?.sections?[section].numberOfObjects ?? 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "TaskCell", for: indexPath) as! TaskCell
        
        if let task = fetchedResultsController?.object(at: indexPath) {
            cell.configure(with: task)
        }
        
        return cell
    }
}

// MARK: - UITableViewDelegate
extension TaskListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if let task = fetchedResultsController?.object(at: indexPath) {
            // Toggle task completion
            taskRepository.toggleComplete(taskID: task.objectID) { [weak self] result in
                switch result {
                case .success:
                    // The UI will update automatically through NSFetchedResultsController
                    break
                case .failure(let error):
                    // Show error
                    let alert = UIAlertController(
                        title: "Error",
                        message: "Failed to update task: \(error.localizedDescription)",
                        preferredStyle: .alert
                    )
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self?.present(alert, animated: true)
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        guard let task = fetchedResultsController?.object(at: indexPath) else {
            return nil
        }
        
        // Delete action
        let deleteAction = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.taskRepository.deleteTask(taskID: task.objectID) { result in
                switch result {
                case .success:
                    completion(true)
                case .failure:
                    completion(false)
                }
            }
        }
        
        // Reschedule action
        let rescheduleAction = UIContextualAction(style: .normal, title: "Reschedule") { [weak self] _, _, completion in
            // Show date picker or action sheet for rescheduling
            // This is just a placeholder - you'd implement a proper date selection UI
            let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
            
            self?.taskRepository.reschedule(taskID: task.objectID, to: tomorrow) { result in
                switch result {
                case .success:
                    completion(true)
                case .failure:
                    completion(false)
                }
            }
        }
        
        rescheduleAction.backgroundColor = .systemBlue
        
        return UISwipeActionsConfiguration(actions: [deleteAction, rescheduleAction])
    }
}

// MARK: - NSFetchedResultsControllerDelegate
extension TaskListViewController: NSFetchedResultsControllerDelegate {
    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }
    
    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, 
                   didChange anObject: Any, 
                   at indexPath: IndexPath?, 
                   for type: NSFetchedResultsChangeType, 
                   newIndexPath: IndexPath?) {
        
        switch type {
        case .insert:
            guard let newIndexPath = newIndexPath else { return }
            tableView.insertRows(at: [newIndexPath], with: .automatic)
            
        case .delete:
            guard let indexPath = indexPath else { return }
            tableView.deleteRows(at: [indexPath], with: .automatic)
            
        case .update:
            guard let indexPath = indexPath else { return }
            if let cell = tableView.cellForRow(at: indexPath) as? TaskCell,
               let task = controller.object(at: indexPath) as? NTask {
                cell.configure(with: task)
            }
            
        case .move:
            guard let indexPath = indexPath, let newIndexPath = newIndexPath else { return }
            tableView.moveRow(at: indexPath, to: newIndexPath)
            
        @unknown default:
            break
        }
    }
    
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}

// MARK: - TaskCell
class TaskCell: UITableViewCell {
    // A simple cell for displaying tasks
    
    private let titleLabel = UILabel()
    private let detailsLabel = UILabel()
    private let priorityIndicator = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // Priority indicator
        priorityIndicator.translatesAutoresizingMaskIntoConstraints = false
        priorityIndicator.layer.cornerRadius = 4
        contentView.addSubview(priorityIndicator)
        
        // Title label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        contentView.addSubview(titleLabel)
        
        // Details label
        detailsLabel.translatesAutoresizingMaskIntoConstraints = false
        detailsLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        detailsLabel.textColor = .gray
        contentView.addSubview(detailsLabel)
        
        // Layout
        NSLayoutConstraint.activate([
            // Priority indicator
            priorityIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
            priorityIndicator.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            priorityIndicator.widthAnchor.constraint(equalToConstant: 8),
            priorityIndicator.heightAnchor.constraint(equalToConstant: 8),
            
            // Title label
            titleLabel.leadingAnchor.constraint(equalTo: priorityIndicator.trailingAnchor, constant: 15),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            
            // Details label
            detailsLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            detailsLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            detailsLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -15),
            detailsLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -10)
        ])
    }
    
    func configure(with task: NTask) {
        // Set title with strikethrough if completed
        let title = task.name ?? "Untitled Task"
        if task.isComplete {
            let attributedTitle = NSAttributedString(string: title, attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue])
            titleLabel.attributedText = attributedTitle
            titleLabel.textColor = .gray
        } else {
            titleLabel.text = title
            titleLabel.textColor = .black
        }
        
        // Set details text
        var details: [String] = []
        
        // Format due date
        if let dueDate = task.dueDate as Date? {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            details.append(formatter.string(from: dueDate))
        }
        
        // Add project name if not "Inbox"
        if let project = task.project, project.lowercased() != "inbox" {
            details.append(project)
        }
        
        detailsLabel.text = details.joined(separator: " • ")
        
        // Set priority color based on the Int32 raw value
        switch task.taskPriority {
        case 2: // TaskPriority.high.rawValue
            priorityIndicator.backgroundColor = .systemRed
        case 3: // TaskPriority.high.rawValue
            priorityIndicator.backgroundColor = .systemOrange
        case 4: // TaskPriority.low.rawValue
            priorityIndicator.backgroundColor = .systemBlue
        default:
            priorityIndicator.backgroundColor = .systemGray
        }
    }
}
