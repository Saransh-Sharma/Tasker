// LGBaseListViewController.swift
// Base class for task list variations - Phase 4 Implementation
// Shared functionality for Today, Upcoming, Weekly, and Completed views

import UIKit
import SnapKit
import RxSwift
import RxCocoa

class LGBaseListViewController: UIViewController {
    
    // MARK: - Dependencies
    protected var viewModel: LGTaskListViewModel!
    protected let disposeBag = DisposeBag()
    
    // MARK: - UI Components
    protected let navigationGlassView = LGBaseView()
    protected let titleLabel = UILabel()
    protected let subtitleLabel = UILabel()
    protected let filterButton = LGButton(style: .ghost, size: .medium)
    
    protected let contentContainer = LGBaseView()
    protected let scrollView = UIScrollView()
    protected let stackView = UIStackView()
    
    protected let emptyStateView = LGBaseView()
    protected let emptyStateLabel = UILabel()
    
    protected let fab = LGFloatingActionButton()
    
    // MARK: - Properties
    protected var taskCards: [LGTaskCard] = []
    protected let refreshControl = UIRefreshControl()
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupBindings()
        applyTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.refreshTasks()
        animateEntrance()
    }
    
    // MARK: - Setup (Override in subclasses)
    
    protected func setupViewModel() {
        // Override in subclasses
        fatalError("setupViewModel must be overridden")
    }
    
    protected func configureTitle() {
        // Override in subclasses
        titleLabel.text = "Tasks"
        subtitleLabel.text = "All tasks"
    }
    
    // MARK: - UI Setup
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        setupNavigationView()
        setupContentContainer()
        setupEmptyState()
        setupFAB()
        configureTitle()
    }
    
    private func setupNavigationView() {
        navigationGlassView.glassIntensity = 0.9
        navigationGlassView.cornerRadius = 0
        
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.largeTitleFontSize, weight: .bold)
        titleLabel.textColor = .label
        
        subtitleLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        
        filterButton.setTitle("Filter", for: .normal)
        filterButton.icon = UIImage(systemName: "line.3.horizontal.decrease.circle")
        
        navigationGlassView.addSubview(titleLabel)
        navigationGlassView.addSubview(subtitleLabel)
        navigationGlassView.addSubview(filterButton)
        view.addSubview(navigationGlassView)
    }
    
    private func setupContentContainer() {
        contentContainer.glassIntensity = 0.1
        contentContainer.cornerRadius = 0
        
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInset = UIEdgeInsets(top: 16, left: 0, bottom: 100, right: 0)
        
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill
        
        refreshControl.tintColor = LGThemeManager.shared.primaryGlassColor
        scrollView.refreshControl = refreshControl
        
        scrollView.addSubview(stackView)
        contentContainer.addSubview(scrollView)
        view.addSubview(contentContainer)
    }
    
    private func setupEmptyState() {
        emptyStateView.glassIntensity = 0.2
        emptyStateView.cornerRadius = 12
        emptyStateView.isHidden = true
        
        emptyStateLabel.text = "No tasks found"
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize)
        emptyStateLabel.textColor = .secondaryLabel
        
        emptyStateView.addSubview(emptyStateLabel)
        contentContainer.addSubview(emptyStateView)
    }
    
    private func setupFAB() {
        fab.icon = UIImage(systemName: "plus")
        fab.rippleEffectEnabled = true
        view.addSubview(fab)
    }
    
    // MARK: - Constraints
    
    private func setupConstraints() {
        navigationGlassView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top).offset(100)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-40)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
        }
        
        filterButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(titleLabel)
            make.width.equalTo(80)
        }
        
        contentContainer.snp.makeConstraints { make in
            make.top.equalTo(navigationGlassView.snp.bottom)
            make.leading.trailing.bottom.equalToSuperview()
        }
        
        scrollView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        stackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
            make.width.equalTo(scrollView).offset(-32)
        }
        
        emptyStateView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalToSuperview().multipliedBy(0.8)
            make.height.equalTo(120)
        }
        
        emptyStateLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        fab.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.bottom.equalTo(view.safeAreaLayoutGuide).offset(-20)
            make.size.equalTo(LGDevice.isIPad ? 64 : 56)
        }
    }
    
    // MARK: - Bindings
    
    private func setupBindings() {
        // Tasks
        viewModel.filteredTasks
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] tasks in
                self?.updateTaskList(tasks)
            })
            .disposed(by: disposeBag)
        
        // Loading
        viewModel.isLoading
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] isLoading in
                if !isLoading {
                    self?.refreshControl.endRefreshing()
                }
            })
            .disposed(by: disposeBag)
        
        // Refresh
        refreshControl.rx.controlEvent(.valueChanged)
            .subscribe(onNext: { [weak self] in
                self?.viewModel.refreshTasks()
            })
            .disposed(by: disposeBag)
        
        // FAB
        fab.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.presentAddTask()
            })
            .disposed(by: disposeBag)
        
        // Filter
        filterButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.showFilterOptions()
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Task List Updates
    
    protected func updateTaskList(_ tasks: [NTask]) {
        // Clear existing cards
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
            
            // Animate entrance
            taskCard.alpha = 0
            taskCard.transform = CGAffineTransform(translationX: 0, y: 20)
            
            UIView.animate(withDuration: 0.3, delay: TimeInterval(index) * 0.05, options: .curveEaseOut) {
                taskCard.alpha = 1
                taskCard.transform = .identity
            }
        }
    }
    
    protected func createTaskCard(for task: NTask) -> LGTaskCard {
        let taskCard = LGTaskCard()
        taskCard.task = task.taskCardData
        
        taskCard.onTaskToggle = { [weak self] isCompleted in
            self?.viewModel.toggleTaskCompletion(task)
        }
        
        taskCard.onTaskTap = { [weak self] in
            self?.presentTaskDetail(task)
        }
        
        return taskCard
    }
    
    // MARK: - Actions
    
    private func presentAddTask() {
        let addTaskVC = LGAddTaskViewController()
        let navController = UINavigationController(rootViewController: addTaskVC)
        present(navController, animated: true)
    }
    
    private func presentTaskDetail(_ task: NTask) {
        let detailVC = LGTaskDetailViewController(task: task)
        present(detailVC, animated: true)
    }
    
    private func showFilterOptions() {
        // Override in subclasses for specific filters
    }
    
    // MARK: - Theme & Animations
    
    private func applyTheme() {
        view.backgroundColor = LGThemeManager.shared.backgroundColor
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        subtitleLabel.textColor = LGThemeManager.shared.secondaryTextColor
    }
    
    private func animateEntrance() {
        navigationGlassView.morphGlass(to: .shimmerPulse, config: .subtle) {
            self.navigationGlassView.morphGlass(to: .idle, config: .subtle)
        }
    }
}

// MARK: - Task List ViewModel

class LGTaskListViewModel {
    
    // MARK: - Dependencies
    protected let context: NSManagedObjectContext
    private let disposeBag = DisposeBag()
    
    // MARK: - Properties
    let tasks = BehaviorRelay<[NTask]>(value: [])
    let filteredTasks = BehaviorRelay<[NTask]>(value: [])
    let isLoading = BehaviorRelay<Bool>(value: false)
    let error = PublishRelay<Error>()
    
    // MARK: - Initialization
    
    init(context: NSManagedObjectContext) {
        self.context = context
        setupBindings()
    }
    
    private func setupBindings() {
        tasks
            .map { [weak self] tasks in
                return self?.filterTasks(tasks) ?? []
            }
            .bind(to: filteredTasks)
            .disposed(by: disposeBag)
    }
    
    // MARK: - Override Points
    
    protected func filterTasks(_ tasks: [NTask]) -> [NTask] {
        // Override in subclasses
        return tasks
    }
    
    protected func createFetchRequest() -> NSFetchRequest<NTask> {
        // Override in subclasses
        return NTask.fetchRequest()
    }
    
    // MARK: - Public Methods
    
    func refreshTasks() {
        isLoading.accept(true)
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            do {
                let request = self.createFetchRequest()
                let fetchedTasks = try self.context.fetch(request)
                
                DispatchQueue.main.async {
                    self.tasks.accept(fetchedTasks)
                    self.isLoading.accept(false)
                }
            } catch {
                DispatchQueue.main.async {
                    self.error.accept(error)
                    self.isLoading.accept(false)
                }
            }
        }
    }
    
    func toggleTaskCompletion(_ task: NTask) {
        task.isComplete.toggle()
        if task.isComplete {
            task.dateCompleted = Date()
        } else {
            task.dateCompleted = nil
        }
        
        do {
            try context.save()
            refreshTasks()
        } catch {
            self.error.accept(error)
        }
    }
}
