// LGProjectDetailViewController.swift
// Project detail view with glass morphism - Phase 6 Implementation
// Displays comprehensive project information with Clean Architecture

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import CoreData

class LGProjectDetailViewController: UIViewController {
    
    // MARK: - Properties
    
    private let project: Projects
    private let context: NSManagedObjectContext
    private let disposeBag = DisposeBag()
    
    var onProjectUpdated: (() -> Void)?
    var onProjectDeleted: (() -> Void)?
    
    // MARK: - UI Components
    
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let stackView = UIStackView()
    
    // Header
    private let headerCard = LGBaseView()
    private let projectNameLabel = UILabel()
    private let projectDescriptionLabel = UILabel()
    private let editButton = LGButton(style: .ghost, size: .small)
    
    // Stats
    private let statsContainer = UIView()
    private let progressCard = LGProjectStatsCard()
    private let tasksCard = LGProjectStatsCard()
    private let deadlineCard = LGProjectStatsCard()
    
    // Tasks Section
    private let tasksHeaderView = UIView()
    private let tasksLabel = UILabel()
    private let addTaskButton = LGButton(style: .primary, size: .small)
    private let tasksTableView = UITableView()
    
    // Activity Section
    private let activityCard = LGBaseView()
    private let activityLabel = UILabel()
    private let activityStackView = UIStackView()
    
    private var tasks: [NTask] = []
    
    // MARK: - Initialization
    
    init(project: Projects, context: NSManagedObjectContext) {
        self.project = project
        self.context = context
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupBindings()
        loadProjectData()
        applyTheme()
        
        // Optimize performance
        LGPerformanceOptimizer.shared.optimizePresentation(for: self)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        animateEntrance()
    }
    
    // MARK: - Setup
    
    private func setupUI() {
        view.backgroundColor = LGThemeManager.shared.backgroundColor
        title = project.name
        
        // Navigation items
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            style: .plain,
            target: self,
            action: #selector(showMoreOptions)
        )
        
        // Scroll view
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(top: 20, left: 0, bottom: 40, right: 0)
        
        // Stack view
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.alignment = .fill
        
        // Header card
        headerCard.glassIntensity = 0.7
        headerCard.cornerRadius = 16
        
        projectNameLabel.font = .systemFont(ofSize: LGLayoutConstants.titleFontSize, weight: .bold)
        projectNameLabel.textColor = LGThemeManager.shared.primaryTextColor
        projectNameLabel.numberOfLines = 0
        
        projectDescriptionLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        projectDescriptionLabel.textColor = LGThemeManager.shared.secondaryTextColor
        projectDescriptionLabel.numberOfLines = 0
        
        editButton.setTitle("Edit", for: .normal)
        editButton.icon = UIImage(systemName: "pencil")
        
        headerCard.addSubview(projectNameLabel)
        headerCard.addSubview(projectDescriptionLabel)
        headerCard.addSubview(editButton)
        
        // Stats cards
        setupStatsCards()
        
        // Tasks section
        tasksLabel.text = "Tasks"
        tasksLabel.font = .systemFont(ofSize: LGLayoutConstants.headlineFontSize, weight: .semibold)
        tasksLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        addTaskButton.setTitle("Add Task", for: .normal)
        addTaskButton.icon = UIImage(systemName: "plus")
        
        tasksHeaderView.addSubview(tasksLabel)
        tasksHeaderView.addSubview(addTaskButton)
        
        tasksTableView.backgroundColor = .clear
        tasksTableView.separatorStyle = .none
        tasksTableView.register(ProjectTaskCell.self, forCellReuseIdentifier: "ProjectTaskCell")
        tasksTableView.delegate = self
        tasksTableView.dataSource = self
        tasksTableView.isScrollEnabled = false
        
        // Activity section
        activityCard.glassIntensity = 0.5
        activityCard.cornerRadius = 16
        
        activityLabel.text = "Recent Activity"
        activityLabel.font = .systemFont(ofSize: LGLayoutConstants.headlineFontSize, weight: .semibold)
        activityLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        activityStackView.axis = .vertical
        activityStackView.spacing = 12
        
        activityCard.addSubview(activityLabel)
        activityCard.addSubview(activityStackView)
        
        // Add to stack view
        stackView.addArrangedSubview(headerCard)
        stackView.addArrangedSubview(statsContainer)
        stackView.addArrangedSubview(tasksHeaderView)
        stackView.addArrangedSubview(tasksTableView)
        stackView.addArrangedSubview(activityCard)
        
        contentView.addSubview(stackView)
        scrollView.addSubview(contentView)
        view.addSubview(scrollView)
    }
    
    private func setupStatsCards() {
        let statsStack = UIStackView()
        statsStack.axis = .horizontal
        statsStack.distribution = .fillEqually
        statsStack.spacing = 12
        
        progressCard.configure(
            title: "Progress",
            value: "0%",
            icon: UIImage(systemName: "chart.pie.fill"),
            color: .systemBlue
        )
        
        tasksCard.configure(
            title: "Tasks",
            value: "0",
            icon: UIImage(systemName: "checklist"),
            color: .systemGreen
        )
        
        deadlineCard.configure(
            title: "Deadline",
            value: "None",
            icon: UIImage(systemName: "calendar"),
            color: .systemOrange
        )
        
        statsStack.addArrangedSubview(progressCard)
        statsStack.addArrangedSubview(tasksCard)
        statsStack.addArrangedSubview(deadlineCard)
        
        statsContainer.addSubview(statsStack)
        
        statsStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(100)
        }
    }
    
    private func setupConstraints() {
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(scrollView)
        }
        
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
        
        // Header card
        projectNameLabel.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(20)
            make.trailing.equalTo(editButton.snp.leading).offset(-12)
        }
        
        projectDescriptionLabel.snp.makeConstraints { make in
            make.top.equalTo(projectNameLabel.snp.bottom).offset(8)
            make.leading.trailing.equalTo(projectNameLabel)
            make.bottom.equalToSuperview().offset(-20)
        }
        
        editButton.snp.makeConstraints { make in
            make.top.trailing.equalToSuperview().inset(20)
            make.width.equalTo(80)
        }
        
        // Tasks header
        tasksLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        
        addTaskButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.equalTo(100)
        }
        
        tasksHeaderView.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        
        // Activity card
        activityLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(20)
        }
        
        activityStackView.snp.makeConstraints { make in
            make.top.equalTo(activityLabel.snp.bottom).offset(16)
            make.leading.trailing.bottom.equalToSuperview().inset(20)
        }
    }
    
    private func setupBindings() {
        editButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.editProject()
            })
            .disposed(by: disposeBag)
        
        addTaskButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.addNewTask()
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Data Loading
    
    private func loadProjectData() {
        // Load project details
        projectNameLabel.text = project.name
        projectDescriptionLabel.text = project.projectDescription ?? "No description"
        
        // Load tasks
        if let projectTasks = project.tasks?.allObjects as? [NTask] {
            tasks = projectTasks.sorted { ($0.dateCreated ?? Date.distantPast) > ($1.dateCreated ?? Date.distantPast) }
        }
        
        // Update stats
        updateStats()
        
        // Load recent activity
        loadRecentActivity()
        
        // Update table view height
        updateTableViewHeight()
    }
    
    private func updateStats() {
        let totalTasks = tasks.count
        let completedTasks = tasks.filter { $0.isComplete }.count
        let progress = totalTasks > 0 ? Float(completedTasks) / Float(totalTasks) : 0
        
        progressCard.configure(
            title: "Progress",
            value: "\(Int(progress * 100))%",
            icon: UIImage(systemName: "chart.pie.fill"),
            color: .systemBlue
        )
        
        tasksCard.configure(
            title: "Tasks",
            value: "\(totalTasks)",
            icon: UIImage(systemName: "checklist"),
            color: .systemGreen
        )
        
        // Find earliest deadline
        let upcomingDeadlines = tasks
            .compactMap { $0.dueDate }
            .filter { $0 > Date() }
            .sorted()
        
        if let nextDeadline = upcomingDeadlines.first {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            deadlineCard.configure(
                title: "Next Due",
                value: formatter.string(from: nextDeadline),
                icon: UIImage(systemName: "calendar"),
                color: .systemOrange
            )
        } else {
            deadlineCard.configure(
                title: "Deadline",
                value: "None",
                icon: UIImage(systemName: "calendar"),
                color: .systemGray
            )
        }
        
        // Show trend
        if completedTasks > 0 {
            progressCard.showTrend(true)
        }
    }
    
    private func loadRecentActivity() {
        // Clear existing activity
        activityStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Add recent task completions
        let recentCompletions = tasks
            .filter { $0.isComplete && $0.dateCompleted != nil }
            .sorted { ($0.dateCompleted ?? Date.distantPast) > ($1.dateCompleted ?? Date.distantPast) }
            .prefix(3)
        
        for task in recentCompletions {
            let activityView = createActivityView(
                icon: "checkmark.circle.fill",
                title: task.name ?? "Task",
                subtitle: "Completed",
                date: task.dateCompleted ?? Date(),
                color: .systemGreen
            )
            activityStackView.addArrangedSubview(activityView)
        }
        
        // Add recent additions
        let recentAdditions = tasks
            .sorted { ($0.dateCreated ?? Date.distantPast) > ($1.dateCreated ?? Date.distantPast) }
            .prefix(2)
        
        for task in recentAdditions {
            let activityView = createActivityView(
                icon: "plus.circle.fill",
                title: task.name ?? "Task",
                subtitle: "Added",
                date: task.dateCreated ?? Date(),
                color: .systemBlue
            )
            activityStackView.addArrangedSubview(activityView)
        }
        
        if activityStackView.arrangedSubviews.isEmpty {
            let emptyLabel = UILabel()
            emptyLabel.text = "No recent activity"
            emptyLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize)
            emptyLabel.textColor = LGThemeManager.shared.tertiaryTextColor
            emptyLabel.textAlignment = .center
            activityStackView.addArrangedSubview(emptyLabel)
        }
    }
    
    private func createActivityView(icon: String, title: String, subtitle: String, date: Date, color: UIColor) -> UIView {
        let view = UIView()
        
        let iconImageView = UIImageView()
        iconImageView.image = UIImage(systemName: icon)
        iconImageView.tintColor = color
        iconImageView.contentMode = .scaleAspectFit
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .medium)
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize)
        subtitleLabel.textColor = LGThemeManager.shared.secondaryTextColor
        
        let dateLabel = UILabel()
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        dateLabel.text = formatter.localizedString(for: date, relativeTo: Date())
        dateLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize)
        dateLabel.textColor = LGThemeManager.shared.tertiaryTextColor
        
        view.addSubview(iconImageView)
        view.addSubview(titleLabel)
        view.addSubview(subtitleLabel)
        view.addSubview(dateLabel)
        
        iconImageView.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.size.equalTo(20)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(iconImageView.snp.trailing).offset(12)
            make.top.equalToSuperview()
            make.trailing.equalTo(dateLabel.snp.leading).offset(-8)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(2)
            make.bottom.equalToSuperview()
        }
        
        dateLabel.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
        }
        
        view.snp.makeConstraints { make in
            make.height.equalTo(44)
        }
        
        return view
    }
    
    private func updateTableViewHeight() {
        let height = CGFloat(tasks.count * 80)
        tasksTableView.snp.updateConstraints { make in
            make.height.equalTo(height)
        }
    }
    
    // MARK: - Actions
    
    @objc private func showMoreOptions() {
        let alert = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Archive Project", style: .default) { [weak self] _ in
            self?.archiveProject()
        })
        
        alert.addAction(UIAlertAction(title: "Duplicate Project", style: .default) { [weak self] _ in
            self?.duplicateProject()
        })
        
        alert.addAction(UIAlertAction(title: "Delete Project", style: .destructive) { [weak self] _ in
            self?.deleteProject()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(alert, animated: true)
    }
    
    private func editProject() {
        // Present edit project view controller
        let editVC = LGEditProjectViewController(project: project, context: context)
        editVC.onProjectUpdated = { [weak self] in
            self?.loadProjectData()
            self?.onProjectUpdated?()
        }
        
        let navController = UINavigationController(rootViewController: editVC)
        present(navController, animated: true)
    }
    
    private func addNewTask() {
        // Use integration coordinator to navigate
        if let coordinator = (UIApplication.shared.delegate as? AppDelegate)?.integrationCoordinator {
            coordinator.navigateToAddTask(project: project)
        }
    }
    
    private func archiveProject() {
        project.isArchived = true
        project.dateArchived = Date()
        
        do {
            try context.save()
            onProjectUpdated?()
            navigationController?.popViewController(animated: true)
        } catch {
            showError("Failed to archive project")
        }
    }
    
    private func duplicateProject() {
        let newProject = Projects(context: context)
        newProject.name = "\(project.name ?? "Project") Copy"
        newProject.projectDescription = project.projectDescription
        newProject.color = project.color
        newProject.dateCreated = Date()
        
        do {
            try context.save()
            onProjectUpdated?()
            
            // Navigate to new project
            let detailVC = LGProjectDetailViewController(project: newProject, context: context)
            navigationController?.pushViewController(detailVC, animated: true)
        } catch {
            showError("Failed to duplicate project")
        }
    }
    
    private func deleteProject() {
        let alert = UIAlertController(
            title: "Delete Project",
            message: "Are you sure you want to delete this project? This action cannot be undone.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            self?.performDelete()
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        present(alert, animated: true)
    }
    
    private func performDelete() {
        context.delete(project)
        
        do {
            try context.save()
            onProjectDeleted?()
            navigationController?.popViewController(animated: true)
        } catch {
            showError("Failed to delete project")
        }
    }
    
    private func showError(_ message: String) {
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Theme & Animation
    
    private func applyTheme() {
        view.backgroundColor = LGThemeManager.shared.backgroundColor
        projectNameLabel.textColor = LGThemeManager.shared.primaryTextColor
        projectDescriptionLabel.textColor = LGThemeManager.shared.secondaryTextColor
        tasksLabel.textColor = LGThemeManager.shared.primaryTextColor
        activityLabel.textColor = LGThemeManager.shared.primaryTextColor
    }
    
    private func animateEntrance() {
        let views = [headerCard, statsContainer, tasksHeaderView, tasksTableView, activityCard]
        LGAnimationRefinement.shared.animateListItems(views, delay: 0.05)
    }
}

// MARK: - UITableViewDataSource

extension LGProjectDetailViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tasks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProjectTaskCell", for: indexPath) as! ProjectTaskCell
        let task = tasks[indexPath.row]
        cell.configure(with: task)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension LGProjectDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let task = tasks[indexPath.row]
        
        // Navigate to task detail
        if let coordinator = (UIApplication.shared.delegate as? AppDelegate)?.integrationCoordinator {
            coordinator.navigateToTaskDetail(task)
        }
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 80
    }
}

// MARK: - Project Task Cell

class ProjectTaskCell: UITableViewCell {
    
    private let containerView = LGBaseView()
    private let checkButton = UIButton()
    private let titleLabel = UILabel()
    private let dueDateLabel = UILabel()
    private let priorityIndicator = UIView()
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupCell()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupCell()
    }
    
    private func setupCell() {
        backgroundColor = .clear
        selectionStyle = .none
        
        containerView.glassIntensity = 0.4
        containerView.cornerRadius = 12
        
        checkButton.setImage(UIImage(systemName: "circle"), for: .normal)
        checkButton.setImage(UIImage(systemName: "checkmark.circle.fill"), for: .selected)
        checkButton.tintColor = LGThemeManager.shared.primaryGlassColor
        
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .medium)
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        dueDateLabel.font = .systemFont(ofSize: LGLayoutConstants.captionFontSize)
        dueDateLabel.textColor = LGThemeManager.shared.secondaryTextColor
        
        priorityIndicator.layer.cornerRadius = 2
        
        contentView.addSubview(containerView)
        containerView.addSubview(checkButton)
        containerView.addSubview(titleLabel)
        containerView.addSubview(dueDateLabel)
        containerView.addSubview(priorityIndicator)
        
        containerView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 4, left: 0, bottom: 4, right: 0))
        }
        
        checkButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(16)
            make.centerY.equalToSuperview()
            make.size.equalTo(24)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(checkButton.snp.trailing).offset(12)
            make.trailing.equalTo(priorityIndicator.snp.leading).offset(-12)
            make.top.equalToSuperview().offset(16)
        }
        
        dueDateLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
        }
        
        priorityIndicator.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(4)
            make.height.equalTo(30)
        }
    }
    
    func configure(with task: NTask) {
        checkButton.isSelected = task.isComplete
        titleLabel.text = task.name
        
        if task.isComplete {
            titleLabel.textColor = LGThemeManager.shared.secondaryTextColor
            titleLabel.attributedText = NSAttributedString(
                string: task.name ?? "",
                attributes: [.strikethroughStyle: NSUnderlineStyle.single.rawValue]
            )
        } else {
            titleLabel.textColor = LGThemeManager.shared.primaryTextColor
            titleLabel.attributedText = nil
            titleLabel.text = task.name
        }
        
        if let dueDate = task.dueDate {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            dueDateLabel.text = "Due: \(formatter.string(from: dueDate))"
        } else {
            dueDateLabel.text = "No due date"
        }
        
        // Priority color
        switch task.priority {
        case 3: // High
            priorityIndicator.backgroundColor = .systemRed
        case 2: // Medium
            priorityIndicator.backgroundColor = .systemOrange
        case 1: // Low
            priorityIndicator.backgroundColor = .systemGreen
        default:
            priorityIndicator.backgroundColor = .systemGray
        }
    }
}
