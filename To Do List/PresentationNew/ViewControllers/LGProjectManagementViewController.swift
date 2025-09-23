// LGProjectManagementViewController.swift
// Project Management Screen with Liquid Glass UI - Phase 5 Implementation
// Advanced project management with glass morphism effects and interactive elements

import UIKit
import SnapKit
import RxSwift
import RxCocoa
import CoreData

class LGProjectManagementViewController: UIViewController {
    
    // MARK: - Dependencies
    private var viewModel: LGProjectManagementViewModel!
    private let disposeBag = DisposeBag()
    
    // MARK: - UI Components
    
    // Navigation and Header
    private let navigationGlassView = LGBaseView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let addProjectButton = LGButton(style: .primary, size: .medium)
    private let searchButton = LGButton(style: .ghost, size: .medium)
    
    // Stats Overview
    private let statsContainer = LGBaseView()
    private let totalProjectsCard = LGProjectStatsCard()
    private let activeProjectsCard = LGProjectStatsCard()
    private let completedProjectsCard = LGProjectStatsCard()
    
    // Filter and Sort
    private let filterContainer = LGBaseView()
    private let filterScrollView = UIScrollView()
    private let filterStackView = UIStackView()
    private let sortButton = LGButton(style: .ghost, size: .small)
    private let viewModeButton = LGButton(style: .ghost, size: .small)
    
    // Project List
    private let contentContainer = LGBaseView()
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()
    private let emptyStateView = LGBaseView()
    private let emptyStateLabel = UILabel()
    
    // Floating Actions
    private let fab = LGFloatingActionButton()
    private let quickActionsContainer = LGBaseView()
    
    // MARK: - Properties
    private var projectCards: [LGProjectCard] = []
    private let refreshControl = UIRefreshControl()
    private var currentViewMode: ViewMode = .list
    
    enum ViewMode {
        case list, grid, kanban
    }
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViewModel()
        setupUI()
        setupConstraints()
        setupBindings()
        applyTheme()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        viewModel.refreshProjects()
        animateEntrance()
    }
    
    // MARK: - Setup
    
    private func setupViewModel() {
        let context = (UIApplication.shared.delegate as! AppDelegate).persistentContainer.viewContext
        viewModel = LGProjectManagementViewModel(context: context)
    }
    
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        setupNavigationView()
        setupStatsOverview()
        setupFilterSection()
        setupContentContainer()
        setupEmptyState()
        setupFAB()
    }
    
    private func setupNavigationView() {
        navigationGlassView.glassIntensity = 0.9
        navigationGlassView.cornerRadius = 0
        
        titleLabel.text = "Projects"
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.largeTitleFontSize, weight: .bold)
        titleLabel.textColor = .label
        
        subtitleLabel.text = "Manage your projects"
        subtitleLabel.font = .systemFont(ofSize: LGLayoutConstants.bodyFontSize, weight: .medium)
        subtitleLabel.textColor = .secondaryLabel
        
        addProjectButton.setTitle("New Project", for: .normal)
        addProjectButton.icon = UIImage(systemName: "plus.circle.fill")
        
        searchButton.icon = UIImage(systemName: "magnifyingglass")
        
        navigationGlassView.addSubview(titleLabel)
        navigationGlassView.addSubview(subtitleLabel)
        navigationGlassView.addSubview(addProjectButton)
        navigationGlassView.addSubview(searchButton)
        view.addSubview(navigationGlassView)
    }
    
    private func setupStatsOverview() {
        statsContainer.glassIntensity = 0.2
        statsContainer.cornerRadius = 16
        
        totalProjectsCard.configure(
            title: "Total Projects",
            value: "0",
            icon: UIImage(systemName: "folder.fill"),
            color: .systemBlue
        )
        
        activeProjectsCard.configure(
            title: "Active",
            value: "0",
            icon: UIImage(systemName: "play.circle.fill"),
            color: .systemGreen
        )
        
        completedProjectsCard.configure(
            title: "Completed",
            value: "0",
            icon: UIImage(systemName: "checkmark.circle.fill"),
            color: .systemOrange
        )
        
        let statsStackView = UIStackView(arrangedSubviews: [
            totalProjectsCard, activeProjectsCard, completedProjectsCard
        ])
        statsStackView.axis = .horizontal
        statsStackView.distribution = .fillEqually
        statsStackView.spacing = 12
        
        statsContainer.addSubview(statsStackView)
        view.addSubview(statsContainer)
        
        statsStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
    }
    
    private func setupFilterSection() {
        filterContainer.glassIntensity = 0.1
        filterContainer.cornerRadius = 12
        
        filterScrollView.showsHorizontalScrollIndicator = false
        filterStackView.axis = .horizontal
        filterStackView.spacing = 8
        
        sortButton.setTitle("Sort", for: .normal)
        sortButton.icon = UIImage(systemName: "arrow.up.arrow.down")
        
        viewModeButton.setTitle("List", for: .normal)
        viewModeButton.icon = UIImage(systemName: "list.bullet")
        
        filterScrollView.addSubview(filterStackView)
        filterContainer.addSubview(filterScrollView)
        filterContainer.addSubview(sortButton)
        filterContainer.addSubview(viewModeButton)
        view.addSubview(filterContainer)
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
        
        emptyStateLabel.text = "No projects yet\nTap + to create your first project"
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.numberOfLines = 0
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
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.top).offset(120)
        }
        
        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-50)
        }
        
        subtitleLabel.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(4)
        }
        
        addProjectButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-20)
            make.centerY.equalTo(titleLabel)
            make.width.equalTo(120)
        }
        
        searchButton.snp.makeConstraints { make in
            make.trailing.equalTo(addProjectButton.snp.leading).offset(-12)
            make.centerY.equalTo(titleLabel)
            make.width.equalTo(44)
        }
        
        statsContainer.snp.makeConstraints { make in
            make.top.equalTo(navigationGlassView.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(LGDevice.isIPad ? 120 : 100)
        }
        
        filterContainer.snp.makeConstraints { make in
            make.top.equalTo(statsContainer.snp.bottom).offset(16)
            make.leading.trailing.equalToSuperview().inset(16)
            make.height.equalTo(50)
        }
        
        filterScrollView.snp.makeConstraints { make in
            make.leading.top.bottom.equalToSuperview()
            make.trailing.equalTo(sortButton.snp.leading).offset(-12)
        }
        
        filterStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
            make.height.equalTo(34)
        }
        
        sortButton.snp.makeConstraints { make in
            make.trailing.equalTo(viewModeButton.snp.leading).offset(-8)
            make.centerY.equalToSuperview()
            make.width.equalTo(60)
        }
        
        viewModeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-8)
            make.centerY.equalToSuperview()
            make.width.equalTo(60)
        }
        
        contentContainer.snp.makeConstraints { make in
            make.top.equalTo(filterContainer.snp.bottom).offset(8)
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
            make.height.equalTo(150)
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
        // Projects
        viewModel.projects
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] projects in
                self?.updateProjectList(projects)
            })
            .disposed(by: disposeBag)
        
        // Stats
        viewModel.totalProjects
            .map { "\($0)" }
            .bind(to: totalProjectsCard.rx.value)
            .disposed(by: disposeBag)
        
        viewModel.activeProjects
            .map { "\($0)" }
            .bind(to: activeProjectsCard.rx.value)
            .disposed(by: disposeBag)
        
        viewModel.completedProjects
            .map { "\($0)" }
            .bind(to: completedProjectsCard.rx.value)
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
        
        // Actions
        addProjectButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.presentAddProject()
            })
            .disposed(by: disposeBag)
        
        fab.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.presentAddProject()
            })
            .disposed(by: disposeBag)
        
        searchButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.presentSearch()
            })
            .disposed(by: disposeBag)
        
        sortButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.showSortOptions()
            })
            .disposed(by: disposeBag)
        
        viewModeButton.rx.tap
            .subscribe(onNext: { [weak self] in
                self?.toggleViewMode()
            })
            .disposed(by: disposeBag)
        
        refreshControl.rx.controlEvent(.valueChanged)
            .subscribe(onNext: { [weak self] in
                self?.viewModel.refreshProjects()
            })
            .disposed(by: disposeBag)
    }
    
    // MARK: - Project List Updates
    
    private func updateProjectList(_ projects: [Projects]) {
        // Clear existing cards
        projectCards.forEach { $0.removeFromSuperview() }
        projectCards.removeAll()
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Show/hide empty state
        emptyStateView.isHidden = !projects.isEmpty
        
        if projects.isEmpty {
            emptyStateView.morphGlass(to: .shimmerPulse, config: .subtle)
            return
        }
        
        // Create project cards based on view mode
        switch currentViewMode {
        case .list:
            createListView(projects)
        case .grid:
            createGridView(projects)
        case .kanban:
            createKanbanView(projects)
        }
    }
    
    private func createListView(_ projects: [Projects]) {
        for (index, project) in projects.enumerated() {
            let projectCard = LGProjectCard(style: .list)
            projectCard.project = project
            
            projectCard.onProjectTap = { [weak self] in
                self?.presentProjectDetail(project)
            }
            
            projectCard.onEditTap = { [weak self] in
                self?.presentEditProject(project)
            }
            
            projectCards.append(projectCard)
            stackView.addArrangedSubview(projectCard)
            
            projectCard.snp.makeConstraints { make in
                make.height.equalTo(LGDevice.isIPad ? 120 : 100)
            }
            
            // Animate entrance
            projectCard.alpha = 0
            projectCard.transform = CGAffineTransform(translationX: 0, y: 20)
            
            UIView.animate(withDuration: 0.3, delay: TimeInterval(index) * 0.05, options: .curveEaseOut) {
                projectCard.alpha = 1
                projectCard.transform = .identity
            }
        }
    }
    
    private func createGridView(_ projects: [Projects]) {
        // Create grid layout with 2 columns on iPhone, 3 on iPad
        let columns = LGDevice.isIPad ? 3 : 2
        let rows = (projects.count + columns - 1) / columns
        
        for row in 0..<rows {
            let rowStackView = UIStackView()
            rowStackView.axis = .horizontal
            rowStackView.distribution = .fillEqually
            rowStackView.spacing = 12
            
            for col in 0..<columns {
                let index = row * columns + col
                if index < projects.count {
                    let project = projects[index]
                    let projectCard = LGProjectCard(style: .grid)
                    projectCard.project = project
                    
                    projectCard.onProjectTap = { [weak self] in
                        self?.presentProjectDetail(project)
                    }
                    
                    projectCards.append(projectCard)
                    rowStackView.addArrangedSubview(projectCard)
                } else {
                    // Add spacer for incomplete rows
                    let spacer = UIView()
                    rowStackView.addArrangedSubview(spacer)
                }
            }
            
            stackView.addArrangedSubview(rowStackView)
            rowStackView.snp.makeConstraints { make in
                make.height.equalTo(LGDevice.isIPad ? 180 : 150)
            }
        }
    }
    
    private func createKanbanView(_ projects: [Projects]) {
        // Group projects by status
        let groupedProjects = Dictionary(grouping: projects) { project in
            return project.isCompleted ? "Completed" : "Active"
        }
        
        let kanbanScrollView = UIScrollView()
        kanbanScrollView.showsHorizontalScrollIndicator = false
        
        let kanbanStackView = UIStackView()
        kanbanStackView.axis = .horizontal
        kanbanStackView.spacing = 16
        
        for status in ["Active", "Completed"] {
            let columnView = createKanbanColumn(title: status, projects: groupedProjects[status] ?? [])
            kanbanStackView.addArrangedSubview(columnView)
        }
        
        kanbanScrollView.addSubview(kanbanStackView)
        stackView.addArrangedSubview(kanbanScrollView)
        
        kanbanStackView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.height.equalTo(kanbanScrollView)
        }
        
        kanbanScrollView.snp.makeConstraints { make in
            make.height.equalTo(400)
        }
    }
    
    private func createKanbanColumn(title: String, projects: [Projects]) -> UIView {
        let columnContainer = LGBaseView()
        columnContainer.glassIntensity = 0.2
        columnContainer.cornerRadius = 12
        
        let titleLabel = UILabel()
        titleLabel.text = "\(title) (\(projects.count))"
        titleLabel.font = .systemFont(ofSize: LGLayoutConstants.headlineFontSize, weight: .semibold)
        titleLabel.textColor = LGThemeManager.shared.primaryTextColor
        
        let columnStackView = UIStackView()
        columnStackView.axis = .vertical
        columnStackView.spacing = 8
        
        for project in projects {
            let projectCard = LGProjectCard(style: .kanban)
            projectCard.project = project
            columnStackView.addArrangedSubview(projectCard)
            projectCards.append(projectCard)
        }
        
        columnContainer.addSubview(titleLabel)
        columnContainer.addSubview(columnStackView)
        
        titleLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview().inset(16)
        }
        
        columnStackView.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(12)
            make.leading.trailing.bottom.equalToSuperview().inset(16)
        }
        
        columnContainer.snp.makeConstraints { make in
            make.width.equalTo(LGDevice.isIPad ? 300 : 250)
        }
        
        return columnContainer
    }
    
    // MARK: - Actions
    
    private func presentAddProject() {
        let addProjectVC = LGAddProjectViewController()
        let navController = UINavigationController(rootViewController: addProjectVC)
        present(navController, animated: true)
    }
    
    private func presentProjectDetail(_ project: Projects) {
        let detailVC = LGProjectDetailViewController(project: project)
        present(detailVC, animated: true)
    }
    
    private func presentEditProject(_ project: Projects) {
        let editVC = LGAddProjectViewController(editingProject: project)
        let navController = UINavigationController(rootViewController: editVC)
        present(navController, animated: true)
    }
    
    private func presentSearch() {
        let searchVC = LGProjectSearchViewController()
        present(searchVC, animated: true)
    }
    
    private func showSortOptions() {
        let alert = UIAlertController(title: "Sort Projects", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Name A-Z", style: .default) { _ in
            self.viewModel.setSortOption(.nameAscending)
        })
        
        alert.addAction(UIAlertAction(title: "Name Z-A", style: .default) { _ in
            self.viewModel.setSortOption(.nameDescending)
        })
        
        alert.addAction(UIAlertAction(title: "Date Created", style: .default) { _ in
            self.viewModel.setSortOption(.dateCreated)
        })
        
        alert.addAction(UIAlertAction(title: "Progress", style: .default) { _ in
            self.viewModel.setSortOption(.progress)
        })
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alert.popoverPresentationController {
            popover.sourceView = sortButton
            popover.sourceRect = sortButton.bounds
        }
        
        present(alert, animated: true)
    }
    
    private func toggleViewMode() {
        switch currentViewMode {
        case .list:
            currentViewMode = .grid
            viewModeButton.setTitle("Grid", for: .normal)
            viewModeButton.icon = UIImage(systemName: "square.grid.2x2")
        case .grid:
            currentViewMode = .kanban
            viewModeButton.setTitle("Kanban", for: .normal)
            viewModeButton.icon = UIImage(systemName: "rectangle.3.offgrid")
        case .kanban:
            currentViewMode = .list
            viewModeButton.setTitle("List", for: .normal)
            viewModeButton.icon = UIImage(systemName: "list.bullet")
        }
        
        viewModel.refreshProjects()
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
        
        statsContainer.morphGlass(to: .expanding, config: .default) {
            self.statsContainer.morphGlass(to: .idle, config: .subtle)
        }
    }
}
