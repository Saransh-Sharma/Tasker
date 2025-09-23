// Liquid Glass Split View Controller
// Provides iPad-optimized split view with glass effects

import UIKit

class LGSplitViewController: UISplitViewController {
    
    // MARK: - Properties
    private var masterViewController: UIViewController?
    private var detailViewController: UIViewController?
    
    // MARK: - Initialization
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSplitView()
        setupGlassEffects()
    }
    
    // MARK: - Setup
    private func setupSplitView() {
        // Configure split view behavior
        preferredDisplayMode = .oneBesideSecondary
        preferredSplitBehavior = .tile
        
        // Set minimum width for primary column
        minimumPrimaryColumnWidth = 320
        maximumPrimaryColumnWidth = 400
        preferredPrimaryColumnWidthFraction = 0.35
        
        // Configure delegate
        delegate = self
        
        // Only use split view on iPad
        if !LGDevice.isIPad {
            preferredDisplayMode = .secondaryOnly
        }
    }
    
    private func setupGlassEffects() {
        // Add glass effect to split view divider
        if let dividerView = view.subviews.first(where: { $0.frame.width < 10 }) {
            let glassEffect = UIVisualEffectView(effect: UIBlurEffect(style: LGThemeManager.shared.glassBlurStyle))
            glassEffect.frame = dividerView.bounds
            glassEffect.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            dividerView.addSubview(glassEffect)
        }
    }
    
    // MARK: - Public Methods
    func setMasterViewController(_ viewController: UIViewController) {
        masterViewController = viewController
        
        // Wrap in navigation controller if needed
        let navController: UINavigationController
        if let nav = viewController as? UINavigationController {
            navController = nav
        } else {
            navController = LGAdaptiveNavigationController(rootViewController: viewController)
        }
        
        setViewController(navController, for: .primary)
    }
    
    func setDetailViewController(_ viewController: UIViewController) {
        detailViewController = viewController
        
        // Wrap in navigation controller if needed
        let navController: UINavigationController
        if let nav = viewController as? UINavigationController {
            navController = nav
        } else {
            navController = LGAdaptiveNavigationController(rootViewController: viewController)
        }
        
        setViewController(navController, for: .secondary)
    }
    
    func showDetailViewController(_ viewController: UIViewController, animated: Bool = true) {
        setDetailViewController(viewController)
        
        if LGDevice.isIPad && traitCollection.horizontalSizeClass == .compact {
            // On compact iPad, present modally
            let navController = LGAdaptiveNavigationController(rootViewController: viewController)
            present(navController, animated: animated)
        }
    }
}

// MARK: - UISplitViewControllerDelegate
extension LGSplitViewController: UISplitViewControllerDelegate {
    
    func splitViewController(_ splitViewController: UISplitViewController, 
                           collapseSecondary secondaryViewController: UIViewController, 
                           onto primaryViewController: UIViewController) -> Bool {
        // Return true to indicate that we have handled the collapse by doing nothing
        // This prevents the secondary view from being pushed onto the primary navigation stack
        return true
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, 
                           separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
        // Return the detail view controller when expanding
        return detailViewController
    }
    
    func splitViewController(_ splitViewController: UISplitViewController, 
                           showDetail vc: UIViewController, 
                           sender: Any?) -> Bool {
        // Handle showing detail view controller
        setDetailViewController(vc)
        return true
    }
}

// MARK: - iPad-Specific Task List Master View
class LGTaskListMasterViewController: UIViewController {
    
    // MARK: - UI Elements
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let searchController = UISearchController(searchResultsController: nil)
    
    // MARK: - Properties
    weak var parentSplitViewController: LGSplitViewController?
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "Tasks"
        view.backgroundColor = .systemBackground
        
        // Setup search
        searchController.searchResultsUpdater = self
        searchController.obscuresBackgroundDuringPresentation = false
        searchController.searchBar.placeholder = "Search tasks..."
        navigationItem.searchController = searchController
        navigationItem.hidesSearchBarWhenScrolling = false
        
        // Setup table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = .clear
        
        view.addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

// MARK: - Table View Data Source & Delegate
extension LGTaskListMasterViewController: UITableViewDataSource, UITableViewDelegate {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 3 // Today, Upcoming, Completed
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 5 // Placeholder
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Today"
        case 1: return "Upcoming"
        case 2: return "Completed"
        default: return nil
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .subtitle, reuseIdentifier: "TaskCell")
        
        // Create glass effect cell
        let glassView = LGAdaptiveView()
        glassView.cornerRadius = 12
        glassView.translatesAutoresizingMaskIntoConstraints = false
        
        cell.contentView.addSubview(glassView)
        NSLayoutConstraint.activate([
            glassView.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
            glassView.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor, constant: 16),
            glassView.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor, constant: -16),
            glassView.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4)
        ])
        
        // Add task content
        let titleLabel = UILabel()
        titleLabel.text = "Sample Task \(indexPath.row + 1)"
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .medium)
        titleLabel.textColor = .label
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = "Due today at 3:00 PM"
        subtitleLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize)
        subtitleLabel.textColor = .secondaryLabel
        
        glassView.addSubview(titleLabel)
        glassView.addSubview(subtitleLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: glassView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: glassView.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: glassView.trailingAnchor, constant: -16),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: glassView.leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: glassView.trailingAnchor, constant: -16),
            subtitleLabel.bottomAnchor.constraint(equalTo: glassView.bottomAnchor, constant: -12)
        ])
        
        cell.backgroundColor = .clear
        cell.selectionStyle = .none
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Show task detail in split view
        let detailVC = LGTaskDetailViewController()
        detailVC.title = "Task Details"
        
        parentSplitViewController?.showDetailViewController(detailVC)
    }
}

// MARK: - Search Results Updating
extension LGTaskListMasterViewController: UISearchResultsUpdating {
    
    func updateSearchResults(for searchController: UISearchController) {
        // Implement search functionality
        guard let searchText = searchController.searchBar.text, !searchText.isEmpty else {
            // Show all tasks
            return
        }
        
        // Filter tasks based on search text
        // This will be connected to the actual task repository in later phases
    }
}

// MARK: - iPad-Specific Task Detail View
class LGTaskDetailViewController: UIViewController {
    
    // MARK: - UI Elements
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let glassContainer = LGAdaptiveView()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Add edit button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .edit,
            target: self,
            action: #selector(editTapped)
        )
        
        // Setup scroll view
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        contentView.addSubview(glassContainer)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        glassContainer.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            glassContainer.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            glassContainer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: LGLayoutConstants.horizontalMargin),
            glassContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -LGLayoutConstants.horizontalMargin),
            glassContainer.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20),
            glassContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 400)
        ])
        
        setupTaskDetailContent()
    }
    
    private func setupTaskDetailContent() {
        // Task title
        let titleLabel = UILabel()
        titleLabel.text = "Complete Project Presentation"
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.titleFontSize, weight: .bold)
        titleLabel.textColor = .label
        titleLabel.numberOfLines = 0
        
        // Task description
        let descriptionLabel = UILabel()
        descriptionLabel.text = "Prepare slides for the quarterly review meeting. Include project milestones, budget analysis, and future roadmap."
        descriptionLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        descriptionLabel.textColor = .secondaryLabel
        descriptionLabel.numberOfLines = 0
        
        // Due date
        let dueDateLabel = UILabel()
        dueDateLabel.text = "Due: Today at 3:00 PM"
        dueDateLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .medium)
        dueDateLabel.textColor = LGThemeManager.shared.accentColor
        
        // Priority indicator
        let priorityView = UIView()
        priorityView.backgroundColor = UIColor.systemRed
        priorityView.layer.cornerRadius = 4
        
        let priorityLabel = UILabel()
        priorityLabel.text = "High Priority"
        priorityLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize, weight: .medium)
        priorityLabel.textColor = .white
        
        priorityView.addSubview(priorityLabel)
        
        // Add all elements to glass container
        [titleLabel, descriptionLabel, dueDateLabel, priorityView].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            glassContainer.addSubview($0)
        }
        
        priorityLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: glassContainer.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: glassContainer.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: glassContainer.trailingAnchor, constant: -24),
            
            descriptionLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            descriptionLabel.leadingAnchor.constraint(equalTo: glassContainer.leadingAnchor, constant: 24),
            descriptionLabel.trailingAnchor.constraint(equalTo: glassContainer.trailingAnchor, constant: -24),
            
            dueDateLabel.topAnchor.constraint(equalTo: descriptionLabel.bottomAnchor, constant: 20),
            dueDateLabel.leadingAnchor.constraint(equalTo: glassContainer.leadingAnchor, constant: 24),
            dueDateLabel.trailingAnchor.constraint(equalTo: glassContainer.trailingAnchor, constant: -24),
            
            priorityView.topAnchor.constraint(equalTo: dueDateLabel.bottomAnchor, constant: 16),
            priorityView.leadingAnchor.constraint(equalTo: glassContainer.leadingAnchor, constant: 24),
            priorityView.heightAnchor.constraint(equalToConstant: 28),
            
            priorityLabel.centerXAnchor.constraint(equalTo: priorityView.centerXAnchor),
            priorityLabel.centerYAnchor.constraint(equalTo: priorityView.centerYAnchor),
            priorityLabel.leadingAnchor.constraint(equalTo: priorityView.leadingAnchor, constant: 12),
            priorityLabel.trailingAnchor.constraint(equalTo: priorityView.trailingAnchor, constant: -12)
        ])
    }
    
    @objc private func editTapped() {
        // Show edit task screen
        let editVC = LGEditTaskViewController()
        presentAdaptively(editVC)
    }
}

// MARK: - Edit Task View Controller
class LGEditTaskViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Edit Task"
        view.backgroundColor = .systemBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(cancelTapped)
        )
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .save,
            target: self,
            action: #selector(saveTapped)
        )
        
        // Add placeholder content
        let label = UILabel()
        label.text = "Edit Task Form\n(To be implemented in Phase 4)"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        label.textColor = .secondaryLabel
        
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }
    
    @objc private func cancelTapped() {
        dismiss(animated: true)
    }
    
    @objc private func saveTapped() {
        dismiss(animated: true)
    }
}
