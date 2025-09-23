// LGHomeViewController.swift
// Liquid Glass Home Screen - Phase 3 Implementation
// Modern MVVM architecture with Liquid Glass UI components

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import CoreData

class LGHomeViewController: UIViewController {
    
    // MARK: - Dependencies
    private var viewModel: LGHomeViewModel!
    private let disposeBag = DisposeBag()
    
    // MARK: - UI Components
    
    // Navigation and Header
    private let navigationGlassView = LGBaseView()
    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let progressView = LGProgressBar()
    
    // Search and Filters
    private let searchBar = LGSearchBar()
    private let filterScrollView = UIScrollView()
    private let filterStackView = UIStackView()
    private var projectPills: [LGProjectPill] = []
    
    // Task List
    private let taskListContainer = LGBaseView()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let emptyStateView = LGBaseView()
    private let emptyStateLabel = UILabel()
    
    // Floating Action Button
    private let fab = LGFloatingActionButton()
    
    // Loading and Error States
    private let loadingView = LGBaseView()
    private let loadingIndicator = UIActivityIndicatorView(style: .large)
    
    // MARK: - Properties
    private var taskCards: [LGTaskCard] = []
    private let refreshControl = UIRefreshControl()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewModel()
        setupUI()
        setupConstraints()
        setupBindings()
        setupGestures()
        
        // Load initial data
        viewModel.loadInitialData()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Apply current theme
        applyTheme()
        
        // Refresh data
        viewModel.refreshData()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        // Animate entrance
        animateEntrance()
    }
    
    // MARK: - Setup
    
    private func setupViewModel() {
        // Get Core Data context from existing architecture
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        viewModel = LGHomeViewModel(context: context)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        // Setup navigation glass view
        setupNavigationView()
        
        // Setup search and filters
        setupSearchAndFilters()
        
        // Setup task list
        setupTaskList()
        
        // Setup floating action button
        setupFloatingActionButton()
        
        // Setup loading view
        setupLoadingView()
        
        // Setup empty state
        setupEmptyState()
    }
    
    private func setupNavigationView() {
        navigationGlassView.glassIntensity = 0.9
        navigationGlassView.cornerRadius = 0
        navigationGlassView.enableGlassBorder = false
        
        // Title
        titleLabel.text = "Tasks"
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.largeTitleFontSize, weight: .bold)
        titleLabel.textColor = .label
        
        // Date
        dateLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .medium)
        dateLabel.textColor = .secondaryLabel
        updateDateLabel()
        
        // Progress bar
        progressView.shimmerEnabled = true
        progressView.cornerRadius = 4
        
        navigationGlassView.addSubview(titleLabel)
        navigationGlassView.addSubview(dateLabel)
        navigationGlassView.addSubview(progressView)
        
        view.addSubview(navigationGlassView)
    }
    
    private func setupSearchAndFilters() {
        searchBar.placeholder = "Search tasks..."
        searchBar.suggestionsEnabled = true
        
        filterScrollView.showsHorizontalScrollIndicator = false
        filterScrollView.contentInset = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        
        filterStackView.axis = .horizontal
        filterStackView.spacing = 12
        filterStackView.alignment = .center
        
        filterScrollView.addSubview(filterStackView)
        
        view.addSubview(searchBar)
        view.addSubview(filterScrollView)
    }
    
    private func setupTaskList() {
        taskListContainer.glassIntensity = 0.3
        taskListContainer.cornerRadius = LGDevice.isIPad ? 16 : 12
        taskListContainer.enableGlassBorder = true
        
        scrollView.backgroundColor = .clear
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 100, right: 0)
        
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        
        // Add refresh control
        refreshControl.tintColor = LGThemeManager.shared.primaryGlassColor
        scrollView.refreshControl = refreshControl
        
        scrollView.addSubview(stackView)
        taskListContainer.addSubview(scrollView)
        view.addSubview(taskListContainer)
    }
    
    private func setupFloatingActionButton() {
        fab.icon = UIImage(systemName: "plus")
        fab.rippleEffectEnabled = true
        fab.expandableActionsEnabled = false
        
        view.addSubview(fab)
    }
    
    private func setupLoadingView() {
        loadingView.glassIntensity = 0.8
        loadingView.cornerRadius = 16
        loadingView.isHidden = true
        
        loadingIndicator.color = LGThemeManager.shared.primaryGlassColor
        
        loadingView.addSubview(loadingIndicator)
        view.addSubview(loadingView)
    }
    
    private func setupEmptyState() {
        emptyStateView.glassIntensity = 0.2
        emptyStateView.cornerRadius = 12
        emptyStateView.isHidden = true
        
        emptyStateLabel.text = "No tasks found\nTap + to create your first task"
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
        emptyStateLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        emptyStateLabel.textColor = .secondaryLabel
        
        emptyStateView.addSubview(emptyStateLabel)
        taskListContainer.addSubview(emptyStateView)
    }
    
    // MARK: - Constraints
    
    private func setupConstraints() {
        // Navigation view
        navigationGlassView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top).offset(120)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-50)
        }
        
        dateLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
        }
        
        progressView.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalToSuperview().offset(-16)
            make.height.equalTo(8)
        }
        
        // Search bar
        searchBar.snp.makeConstraints { make in
            make.top.equalTo(navigationGlassView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(LGDevice.isIPad ? 48 : 44)
        }
        
        // Filter scroll view
        filterScrollView.snp.makeConstraints { make in
            make.top.equalTo(searchBar.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
            make.height.equalTo(40)
        }
        
        filterStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalToSuperview()
        }
        
        // Task list container
        taskListContainer.snp.makeConstraints { make in
            make.top.equalTo(filterScrollView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.bottom.equalTo(view.safeAreaLayoutGuide)
        }
        
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
            make.width.equalTo(scrollView).offset(-32)
        }
        
        // Empty state
        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.8)
            make.height.equalTo(120)
        }
        
        emptyStateLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(20)
        }
        
        // FAB
        fab.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.size.equalTo(LGDevice.isIPad ? 64 : 56)
        }
        
        // Loading view
        loadingView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(100)
        }
        
        loadingIndicator.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
    }
    
    // MARK: - Bindings
    
    private func setupBindings() {
        // Loading state
        viewModel.isLoading
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] isLoading in
                self?.updateLoadingState(isLoading)
            })
            .disposed(by: disposeBag)
        
        // Tasks
        viewModel.filteredTasks
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] tasks in
                self?.updateTaskList(tasks)
            })
            .disposed(by: disposeBag)
        
        // Progress
        viewModel.dailyProgress
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] progress in
                self?.updateProgress(progress)
            })
            .disposed(by: disposeBag)
        
        // Projects for filters
        viewModel.projects
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] projects in
                self?.updateProjectFilters(projects)
            })
            .disposed(by: disposeBag)
        
        // Search text binding
        searchBar.rx.text.orEmpty
            .debounce(.milliseconds(300), scheduler: MainScheduler.instance)
            .bind(to: viewModel.searchText)
            .disposed(by: disposeBag)
        
        // Error handling
        viewModel.error
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] error in
                self?.showError(error)
            })
            .disposed(by: disposeBag)
        
        // Refresh control
        refreshControl.rx.controlEvent(.valueChanged)
            .subscribe(onNext: { [weak self] in
                self?.viewModel.refreshData()
            })
            .disposed(by: disposeBag)
        
        // FAB tap
        fab.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.createNewTask()
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Gestures
    
    private func setupGestures() {
        // Add pull-to-refresh gesture to navigation view
        let pullGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePullGesture(_:)))
        navigationGlassView.addGestureRecognizer(pullGesture)
    }
    
    @objc private func handlePullGesture(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: view)
        
        switch gesture.state {
        case .changed:
            if translation.y > 0 {
                // Morphing effect during pull
                navigationGlassView.morphGlass(to: .expanding, config: .subtle)
            }
        case .ended:
            if translation.y > 100 {
                // Trigger refresh
                viewModel.refreshData()
                navigationGlassView.morphGlass(to: .shimmerPulse, config: .default) {
                    self.navigationGlassView.morphGlass(to: .idle, config: .subtle)
                }
            } else {
                navigationGlassView.morphGlass(to: .idle, config: .subtle)
            }
        default:
            break
        }
    }
    
    // MARK: - UI Updates
    
    private func updateLoadingState(_ isLoading: Bool) {
        if isLoading {
            loadingView.isHidden = false
            loadingIndicator.startAnimating()
            loadingView.morphGlass(to: .shimmerPulse, config: .subtle)
        } else {
            loadingView.morphGlass(to: .idle, config: .subtle) {
                self.loadingView.isHidden = true
                self.loadingIndicator.stopAnimating()
            }
            refreshControl.endRefreshing()
        }
    }
    
    private func updateTaskList(_ tasks: [NTask]) {
        // Clear existing task cards
        taskCards.forEach { $0.removeFromSuperview() }
        taskCards.removeAll()
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Show/hide empty state
        emptyStateView.isHidden = !tasks.isEmpty
        
        if tasks.isEmpty {
            emptyStateView.morphGlass(to: .shimmerPulse, config: .subtle)
            return
        }
        
        // Create task cards
        for (index, task) in tasks.enumerated() {
            let taskCard = createTaskCard(for: task)
            taskCards.append(taskCard)
            stackView.addArrangedSubview(taskCard)
            
            taskCard.snp.makeConstraints { make in
                make.height.equalTo(LGDevice.isIPad ? 100 : 80)
            }
            
            // Animate card entrance
            taskCard.alpha = 0
            taskCard.transform = CGAffineTransform(translationX: 0, y: 20)
            
            UIView.animate(withDuration: 0.3, delay: TimeInterval(index) * 0.05, options: .curveEaseOut) {
                taskCard.alpha = 1
                taskCard.transform = .identity
            }
        }
    }
    
    private func createTaskCard(for task: NTask) -> LGTaskCard {
        let taskCard = LGTaskCard()
        
        // Configure task data
        let taskData = TaskCardData(
            id: task.objectID.uriRepresentation().absoluteString,
            title: task.taskName ?? "Untitled Task",
            description: task.taskDescription ?? "",
            dueDate: task.dueDate,
            priority: TaskPriority(rawValue: Int(task.taskPriority)) ?? .medium,
            project: nil, // TODO: Map project data
            progress: task.isComplete ? 1.0 : 0.0,
            isCompleted: task.isComplete
        )
        
        taskCard.task = taskData
        
        // Setup callbacks
        taskCard.onTaskToggle = { [weak self] isCompleted in
            self?.viewModel.toggleTaskCompletion(task)
            
            // Morphing effect for completion
            if isCompleted {
                taskCard.morphGlass(to: .shimmerPulse, config: .default) {
                    taskCard.morphGlass(to: .idle, config: .subtle)
                }
            }
        }
        
        taskCard.onTaskTap = { [weak self] in
            self?.showTaskDetail(task)
        }
        
        return taskCard
    }
    
    private func updateProgress(_ progress: Float) {
        progressView.setProgressWithMorphing(progress, morphState: .liquidWave, animated: true)
        
        // Celebrate completion
        if progress >= 1.0 {
            progressView.celebrateCompletion()
        }
    }
    
    private func updateProjectFilters(_ projects: [Projects]) {
        // Clear existing pills
        projectPills.forEach { $0.removeFromSuperview() }
        projectPills.removeAll()
        
        // Add "All" pill
        let allPill = LGProjectPill()
        let allProjectData = ProjectData(
            id: "all",
            name: "All",
            color: .systemBlue,
            iconName: "list.bullet",
            taskCount: viewModel.tasks.value.count,
            completedCount: viewModel.tasks.value.filter { $0.isComplete }.count
        )
        allPill.configure(with: allProjectData)
        allPill.onTap = { [weak self] in
            self?.viewModel.selectProject(nil)
            self?.updatePillSelection(selectedPill: allPill)
        }
        
        filterStackView.addArrangedSubview(allPill)
        projectPills.append(allPill)
        
        // Add project pills
        for project in projects {
            let pill = LGProjectPill()
            let projectTasks = viewModel.tasks.value.filter { $0.taskProject == project }
            let projectData = ProjectData(
                id: project.objectID.uriRepresentation().absoluteString,
                name: project.projectName ?? "Untitled Project",
                color: UIColor(named: project.projectColor ?? "systemBlue") ?? .systemBlue,
                iconName: project.projectIcon ?? "folder.fill",
                taskCount: projectTasks.count,
                completedCount: projectTasks.filter { $0.isComplete }.count
            )
            
            pill.configure(with: projectData)
            pill.onTap = { [weak self] in
                self?.viewModel.selectProject(project)
                self?.updatePillSelection(selectedPill: pill)
            }
            
            filterStackView.addArrangedSubview(pill)
            projectPills.append(pill)
        }
        
        // Select "All" by default
        updatePillSelection(selectedPill: allPill)
    }
    
    private func updatePillSelection(selectedPill: LGProjectPill) {
        projectPills.forEach { pill in
            if pill == selectedPill {
                pill.morphGlass(to: .pressed, config: .subtle)
            } else {
                pill.morphGlass(to: .idle, config: .subtle)
            }
        }
    }
    
    private func updateDateLabel() {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        dateLabel.text = formatter.string(from: viewModel.selectedDate.value)
    }
    
    // MARK: - Actions
    
    private func createNewTask() {
        fab.morphButton(to: .expanding) {
            self.fab.morphButton(to: .idle)
        }
        
        let newTask = viewModel.createNewTask()
        showTaskDetail(newTask)
    }
    
    private func showTaskDetail(_ task: NTask) {
        // TODO: Present task detail view
        // For now, just show an alert
        let alert = UIAlertController(title: "Task Detail", message: task.taskName, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func showError(_ error: Error) {
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    // MARK: - Theme
    
    private func applyTheme() {
        view.backgroundColor = LGThemeManager.shared.backgroundColor
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        dateLabel.textColor = LGThemeManager.shared.secondaryTextColor
        
        // Update glass intensities based on theme
        let isDarkMode = traitCollection.userInterfaceStyle == .dark
        navigationGlassView.glassIntensity = isDarkMode ? 0.7 : 0.9
        taskListContainer.glassIntensity = isDarkMode ? 0.2 : 0.3
    }
    
    // MARK: - Animations
    
    private func animateEntrance() {
        // Animate navigation view
        navigationGlassView.morphGlass(to: .shimmerPulse, config: .subtle) {
            self.navigationGlassView.morphGlass(to: .idle, config: .subtle)
        }
        
        // Animate search bar
        searchBar.alpha = 0
        searchBar.transform = CGAffineTransform(translationX: 0, y: -20)
        
        UIView.animate(withDuration: 0.4, delay: 0.1, options: .curveEaseOut) {
            self.searchBar.alpha = 1
            self.searchBar.transform = .identity
        }
        
        // Animate filter scroll view
        filterScrollView.alpha = 0
        filterScrollView.transform = CGAffineTransform(translationX: -20, y: 0)
        
        UIView.animate(withDuration: 0.4, delay: 0.2, options: .curveEaseOut) {
            self.filterScrollView.alpha = 1
            self.filterScrollView.transform = .identity
        }
        
        // Animate task list container
        taskListContainer.morphGlass(to: .expanding, config: .subtle) {
            self.taskListContainer.morphGlass(to: .idle, config: .subtle)
        }
        
        // Animate FAB
        fab.alpha = 0
        fab.transform = CGAffineTransform(scaleX: 0.5, y: 0.5)
        
        UIView.animate(withDuration: 0.5, delay: 0.4, usingSpringWithDamping: 0.7, initialSpringVelocity: 0.5, options: .curveEaseOut) {
            self.fab.alpha = 1
            self.fab.transform = .identity
        }
    }
    
    // MARK: - Trait Collection
    
    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        
        if traitCollection.hasDifferentColorAppearance(comparedTo: previousTraitCollection) {
            applyTheme()
        }
    }
}

// MARK: - Extensions

// MARK: - Reactive Extensions

extension Reactive where Base: LGFloatingActionButton {
    var tap: ControlEvent<Void> {
        let source = base.rx.methodInvoked(#selector(Base.touchUpInside)).map { _ in }
        return ControlEvent(events: source)
    }
}

extension LGFloatingActionButton {
    @objc private func touchUpInside() {
        onTap?()
    }
}
